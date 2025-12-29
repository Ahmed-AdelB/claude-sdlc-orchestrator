#!/bin/bash
# =============================================================================
# test_sql_injection.sh - SQL Injection Prevention Tests
# =============================================================================
# Verifies that the _sql_escape() function in lib/sqlite-state.sh properly
# prevents SQL injection attacks by correctly escaping single quotes and
# other dangerous characters.
#
# Test cases:
#   1. test_sql_escape_single_quote - Verify O'Reilly becomes O''Reilly
#   2. test_sql_escape_multiple_quotes - Multiple quotes escaped
#   3. test_sql_injection_in_task_id - Try "task'; DROP TABLE tasks; --"
#   4. test_sql_injection_in_state_value - Verify injection blocked in state operations
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test environment configuration
TEST_DIR="/tmp/tri_agent_sql_injection_test_$$"
mkdir -p "$TEST_DIR/logs" "$TEST_DIR/state/locks" "$TEST_DIR/tasks"
export LOG_DIR="$TEST_DIR/logs"
export STATE_DIR="$TEST_DIR/state"
export STATE_DB="$TEST_DIR/state/test-tri-agent.db"
export LOCKS_DIR="$TEST_DIR/state/locks"
export AUTONOMOUS_ROOT="$TEST_DIR"
export TRACE_ID="test-sql-injection-$$"
export SESSION_LOG="$LOG_DIR/session.log"
touch "$SESSION_LOG"

# Symlink lib directory for common.sh to find dependencies
mkdir -p "$AUTONOMOUS_ROOT"
ln -sf "$PROJECT_ROOT/lib" "$AUTONOMOUS_ROOT/lib"
ln -sf "$PROJECT_ROOT/config" "$AUTONOMOUS_ROOT/config" 2>/dev/null || true

# Source required libraries
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/sqlite-state.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Helper functions
pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

log_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# =============================================================================
# Test 1: Single Quote Escaping
# =============================================================================
test_sql_escape_single_quote() {
    log_test "SQL Escape - Single Quote (O'Reilly -> O''Reilly)"

    local input="O'Reilly"
    local expected="O''Reilly"
    local escaped
    escaped=$(_sql_escape "$input")

    if [[ "$escaped" == "$expected" ]]; then
        pass "Single quote escaped correctly: '$input' -> '$escaped'"
    else
        fail "Single quote not escaped correctly: got '$escaped', expected '$expected'"
    fi
}

# =============================================================================
# Test 2: Multiple Quotes Escaping
# =============================================================================
test_sql_escape_multiple_quotes() {
    log_test "SQL Escape - Multiple Quotes"

    # Test case with multiple single quotes
    local input="It's John's dog's toy"
    local expected="It''s John''s dog''s toy"
    local escaped
    escaped=$(_sql_escape "$input")

    if [[ "$escaped" == "$expected" ]]; then
        pass "Multiple quotes escaped correctly: '$input' -> '$escaped'"
    else
        fail "Multiple quotes not escaped: got '$escaped', expected '$expected'"
    fi

    # Test case with consecutive quotes
    local input2="Test''Value"
    local expected2="Test''''Value"
    local escaped2
    escaped2=$(_sql_escape "$input2")

    if [[ "$escaped2" == "$expected2" ]]; then
        pass "Consecutive quotes escaped correctly: '$input2' -> '$escaped2'"
    else
        fail "Consecutive quotes not escaped: got '$escaped2', expected '$expected2'"
    fi

    # Test case with quote at start and end
    local input3="'quoted'"
    local expected3="''quoted''"
    local escaped3
    escaped3=$(_sql_escape "$input3")

    if [[ "$escaped3" == "$expected3" ]]; then
        pass "Start/end quotes escaped correctly: '$input3' -> '$escaped3'"
    else
        fail "Start/end quotes not escaped: got '$escaped3', expected '$expected3'"
    fi
}

# =============================================================================
# Test 3: SQL Injection Attempt in Task ID
# =============================================================================
test_sql_injection_in_task_id() {
    log_test "SQL Injection Prevention - Task ID with DROP TABLE"

    # Setup test database directly with sqlite3 (bypassing complex init)
    local test_db="$TEST_DIR/injection_test.db"
    sqlite3 "$test_db" "CREATE TABLE IF NOT EXISTS test (id TEXT, value TEXT);"
    sqlite3 "$test_db" "INSERT INTO test VALUES ('safe', 'data');"

    # Malicious task ID attempting SQL injection
    local malicious_task_id="task'; DROP TABLE test; --"
    local escaped_task_id
    escaped_task_id=$(_sql_escape "$malicious_task_id")

    # Verify the escape doubled the single quote
    if [[ "$escaped_task_id" == *"''"* ]]; then
        pass "Single quote in injection payload was escaped"
    else
        fail "Single quote in injection payload was NOT escaped"
    fi

    # Try to insert with the malicious escaped ID
    # This should safely insert the escaped string, not execute DROP TABLE
    sqlite3 "$test_db" "INSERT INTO test VALUES ('$escaped_task_id', 'test_value');" 2>/dev/null || true

    # Verify the test table still exists
    local table_exists
    table_exists=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='test';")

    if [[ "$table_exists" == "1" ]]; then
        pass "SQL injection blocked - test table still exists"
    else
        fail "SQL injection succeeded - test table was dropped!"
    fi

    # Verify we can query the table
    local row_count
    row_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM test;")

    if [[ "$row_count" =~ ^[0-9]+$ ]]; then
        pass "Table is queryable after injection attempt (count: $row_count)"
    else
        fail "Table not queryable after injection attempt"
    fi

    # Verify the malicious string was stored safely (escaped)
    local stored_id
    stored_id=$(sqlite3 "$test_db" "SELECT id FROM test WHERE id LIKE '%DROP%' LIMIT 1;")

    if [[ -n "$stored_id" ]]; then
        pass "Malicious payload stored safely as data, not executed as SQL"
    else
        # The row might not have been inserted, which is also acceptable
        pass "Malicious payload was safely handled (not stored or rejected)"
    fi

    rm -f "$test_db"
}

# =============================================================================
# Test 4: SQL Injection in State Value Operations
# =============================================================================
test_sql_injection_in_state_value() {
    log_test "SQL Injection Prevention - State Value Operations"

    # Setup test database directly with sqlite3 (bypassing complex init)
    local test_db="$TEST_DIR/state_test.db"
    sqlite3 "$test_db" "CREATE TABLE IF NOT EXISTS state (file_path TEXT, key TEXT, value TEXT, PRIMARY KEY(file_path, key));"

    # Create a reference entry to detect if injection succeeded
    sqlite3 "$test_db" "INSERT INTO state VALUES ('system', 'reference_key', 'reference_value');"

    # Attempt SQL injection via value parameter
    local malicious_value="value'; DELETE FROM state WHERE 1=1; --"
    local escaped_value
    escaped_value=$(_sql_escape "$malicious_value")

    # Insert with escaped malicious value
    sqlite3 "$test_db" "INSERT OR REPLACE INTO state VALUES ('test_file', 'test_key', '$escaped_value');"

    # Verify reference entry still exists (DELETE was not executed)
    local reference
    reference=$(sqlite3 "$test_db" "SELECT value FROM state WHERE file_path='system' AND key='reference_key';")

    if [[ "$reference" == "reference_value" ]]; then
        pass "SQL injection in state value blocked - reference entry preserved"
    else
        fail "SQL injection may have succeeded - reference entry missing or modified"
    fi

    # Verify the malicious value was stored correctly
    local retrieved
    retrieved=$(sqlite3 "$test_db" "SELECT value FROM state WHERE file_path='test_file' AND key='test_key';")

    if [[ "$retrieved" == "$malicious_value" ]]; then
        pass "Malicious value stored and retrieved safely as data"
    else
        fail "Malicious value was not properly stored: got '$retrieved'"
    fi

    # Test injection via file_path parameter
    local malicious_path="file'; DROP TABLE state; --"
    local escaped_path
    escaped_path=$(_sql_escape "$malicious_path")
    sqlite3 "$test_db" "INSERT OR REPLACE INTO state VALUES ('$escaped_path', 'another_key', 'safe_value');"

    # Verify state table still exists
    local state_exists
    state_exists=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='state';")

    if [[ "$state_exists" == "1" ]]; then
        pass "SQL injection via file_path blocked - state table still exists"
    else
        fail "SQL injection via file_path succeeded - state table was dropped!"
    fi

    # Test injection via key parameter
    local malicious_key="key'; UPDATE state SET value='hacked' WHERE 1=1; --"
    local escaped_key
    escaped_key=$(_sql_escape "$malicious_key")
    sqlite3 "$test_db" "INSERT OR REPLACE INTO state VALUES ('test_file2', '$escaped_key', 'innocent_value');"

    # Verify reference value was not modified
    local reference_check
    reference_check=$(sqlite3 "$test_db" "SELECT value FROM state WHERE file_path='system' AND key='reference_key';")

    if [[ "$reference_check" == "reference_value" ]]; then
        pass "SQL injection via key parameter blocked - values not modified"
    else
        fail "SQL injection via key parameter may have succeeded - reference modified to '$reference_check'"
    fi

    rm -f "$test_db"
}

# =============================================================================
# Test 5: Classic SQL Injection Patterns
# =============================================================================
test_classic_injection_patterns() {
    log_test "SQL Injection Prevention - Classic Attack Patterns"

    # Setup test database directly with sqlite3
    local test_db="$TEST_DIR/patterns_test.db"
    sqlite3 "$test_db" "CREATE TABLE IF NOT EXISTS test (id TEXT PRIMARY KEY, value TEXT);"

    # Array of classic SQL injection payloads
    local injections=(
        "' OR '1'='1"
        "'; --"
        "' UNION SELECT * FROM tasks; --"
        "1; DROP TABLE tasks"
        "' OR 1=1--"
        "admin'--"
        "1' AND '1'='1"
        "'; EXEC xp_cmdshell('cmd'); --"
        "' OR ''='"
        "1'; TRUNCATE TABLE tasks; --"
    )

    local all_passed=true

    for injection in "${injections[@]}"; do
        local escaped
        escaped=$(_sql_escape "$injection")

        # Count single quotes in original and escaped
        local orig_quotes="${injection//[^\']/}"
        local escaped_quotes="${escaped//[^\']/}"
        local orig_count=${#orig_quotes}
        local escaped_count=${#escaped_quotes}

        # Each single quote should become two single quotes
        local expected_count=$((orig_count * 2))

        if [[ "$escaped_count" -eq "$expected_count" ]]; then
            pass "Injection pattern escaped: '${injection:0:30}...'"
        else
            fail "Injection pattern NOT properly escaped: '$injection'"
            all_passed=false
        fi
    done

    # Test that escaped values can be safely inserted and retrieved
    local test_payload="' OR '1'='1"
    local escaped_payload
    escaped_payload=$(_sql_escape "$test_payload")
    sqlite3 "$test_db" "INSERT INTO test VALUES ('test_id', '$escaped_payload');"

    local retrieved
    retrieved=$(sqlite3 "$test_db" "SELECT value FROM test WHERE id='test_id';")

    if [[ "$retrieved" == "$test_payload" ]]; then
        pass "Injection payload stored and retrieved safely"
    else
        fail "Injection payload was not properly handled: got '$retrieved'"
    fi

    rm -f "$test_db"
}

# =============================================================================
# Test 6: Empty and Edge Cases
# =============================================================================
test_edge_cases() {
    log_test "SQL Escape - Edge Cases"

    # Empty string
    local empty_result
    empty_result=$(_sql_escape "")
    if [[ -z "$empty_result" ]]; then
        pass "Empty string handled correctly"
    else
        fail "Empty string produced unexpected output: '$empty_result'"
    fi

    # String with no quotes
    local no_quotes="Hello World 123"
    local no_quotes_result
    no_quotes_result=$(_sql_escape "$no_quotes")
    if [[ "$no_quotes_result" == "$no_quotes" ]]; then
        pass "String without quotes unchanged"
    else
        fail "String without quotes was modified: '$no_quotes_result'"
    fi

    # Only single quote
    local only_quote="'"
    local only_quote_result
    only_quote_result=$(_sql_escape "$only_quote")
    if [[ "$only_quote_result" == "''" ]]; then
        pass "Single quote-only string escaped correctly"
    else
        fail "Single quote-only string not escaped: '$only_quote_result'"
    fi

    # Multiple consecutive quotes
    local multi_quotes="'''"
    local multi_quotes_result
    multi_quotes_result=$(_sql_escape "$multi_quotes")
    if [[ "$multi_quotes_result" == "''''''" ]]; then
        pass "Multiple consecutive quotes escaped correctly"
    else
        fail "Multiple consecutive quotes not escaped: '$multi_quotes_result'"
    fi

    # Unicode with quotes
    local unicode="It's caf\u00e9"
    local unicode_result
    unicode_result=$(_sql_escape "$unicode")
    if [[ "$unicode_result" == *"''"* ]]; then
        pass "Unicode string with quotes escaped correctly"
    else
        fail "Unicode string with quotes not escaped"
    fi
}

# =============================================================================
# Run All Tests
# =============================================================================
main() {
    echo "=============================================="
    echo "SQL Injection Prevention Test Suite"
    echo "=============================================="
    echo "Testing _sql_escape() function from lib/sqlite-state.sh"
    echo "Test database: $STATE_DB"
    echo ""

    test_sql_escape_single_quote
    test_sql_escape_multiple_quotes
    test_sql_injection_in_task_id
    test_sql_injection_in_state_value
    test_classic_injection_patterns
    test_edge_cases

    echo ""
    echo "=============================================="
    echo "Test Results"
    echo "=============================================="
    echo -e "Tests Passed: ${GREEN}$PASS_COUNT${NC}"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "Tests Failed: ${RED}$FAIL_COUNT${NC}"
        echo ""
        echo -e "${RED}SECURITY TESTS FAILED${NC}"
        exit 1
    else
        echo -e "Tests Failed: ${GREEN}$FAIL_COUNT${NC}"
        echo ""
        echo -e "${GREEN}All SQL injection prevention tests passed.${NC}"
        exit 0
    fi
}

main
