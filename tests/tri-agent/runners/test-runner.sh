#!/bin/bash
# Tri-Agent Daemon Test Runner
# Version: 1.0.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${TEST_ROOT}/config.yaml"
RESULTS_DIR="${TEST_ROOT}/results"
LOGS_DIR="${TEST_ROOT}/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Timestamp for this run
RUN_ID=$(date +%Y%m%d_%H%M%S)
RUN_TIMESTAMP=$(date -Iseconds)

# Initialize logging
LOG_FILE="${LOGS_DIR}/test-run-${RUN_ID}.log"
mkdir -p "${LOGS_DIR}" "${RESULTS_DIR}"

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date -Iseconds)
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"

    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} ${message}" ;;
        PASS)  echo -e "${GREEN}[PASS]${NC} ${message}" ;;
        FAIL)  echo -e "${RED}[FAIL]${NC} ${message}" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} ${message}" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} ${message}" ;;
    esac
}

# Parse command line arguments
parse_args() {
    FILTER_CATEGORY=""
    FILTER_PRIORITY=""
    FILTER_TAGS=""
    PARALLEL=false
    FAIL_FAST=false
    VERBOSE=false
    DRY_RUN=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --category=*)
                FILTER_CATEGORY="${1#*=}"
                shift
                ;;
            --priority=*)
                FILTER_PRIORITY="${1#*=}"
                shift
                ;;
            --tags=*)
                FILTER_TAGS="${1#*=}"
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --fail-fast)
                FAIL_FAST=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Tri-Agent Daemon Test Runner

Usage: $(basename "$0") [OPTIONS]

Options:
    --category=NAME     Run tests from specific category
    --priority=LEVEL    Run tests with specific priority (critical, high, medium, low)
    --tags=TAG1,TAG2    Run tests with specific tags
    --parallel          Run tests in parallel
    --fail-fast         Stop on first failure
    --verbose, -v       Verbose output
    --dry-run           Show which tests would run without executing
    --help, -h          Show this help message

Examples:
    $(basename "$0") --category=daemon-lifecycle
    $(basename "$0") --priority=critical --fail-fast
    $(basename "$0") --tags=core,smoke --parallel
EOF
}

# Discover test cases
discover_tests() {
    local cases_dir="${TEST_ROOT}/cases"
    local test_files=()

    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$cases_dir" -name "TAT-*.yaml" -print0 | sort -z)

    echo "${test_files[@]}"
}

# Parse YAML test case (simplified parser)
parse_test_case() {
    local file=$1
    local field=$2

    # Use yq if available, otherwise basic grep
    if command -v yq &> /dev/null; then
        yq eval ".$field" "$file" 2>/dev/null || echo ""
    else
        grep "^${field}:" "$file" | head -1 | sed 's/^[^:]*: *//' | tr -d '"'
    fi
}

# Check if test should be skipped
should_skip_test() {
    local file=$1

    # Check skip flag
    local skip_enabled=$(parse_test_case "$file" "skip.enabled")
    if [[ "$skip_enabled" == "true" ]]; then
        return 0
    fi

    # Check category filter
    if [[ -n "$FILTER_CATEGORY" ]]; then
        local category=$(parse_test_case "$file" "category")
        if [[ "$category" != "$FILTER_CATEGORY" ]]; then
            return 0
        fi
    fi

    # Check priority filter
    if [[ -n "$FILTER_PRIORITY" ]]; then
        local priority=$(parse_test_case "$file" "priority")
        if [[ "$priority" != "$FILTER_PRIORITY" ]]; then
            return 0
        fi
    fi

    return 1
}

# Run setup phase
run_setup() {
    local file=$1
    log INFO "Running setup for $(basename "$file")"

    # Execute setup commands
    local setup_commands=$(parse_test_case "$file" "setup.commands")
    if [[ -n "$setup_commands" && "$setup_commands" != "null" ]]; then
        eval "$setup_commands" 2>&1 || {
            log ERROR "Setup failed"
            return 1
        }
    fi

    return 0
}

# Run test execution
run_test_execution() {
    local file=$1
    local test_id=$(parse_test_case "$file" "id")
    local timeout=$(parse_test_case "$file" "timeout.execution")
    timeout=${timeout:-300}

    log INFO "Executing test ${test_id} (timeout: ${timeout}s)"

    # Get input type and execute accordingly
    local input_type=$(parse_test_case "$file" "input.type")

    case $input_type in
        command)
            run_command_test "$file" "$timeout"
            ;;
        event)
            run_event_test "$file" "$timeout"
            ;;
        api)
            run_api_test "$file" "$timeout"
            ;;
        task)
            run_task_test "$file" "$timeout"
            ;;
        *)
            log ERROR "Unknown input type: $input_type"
            return 1
            ;;
    esac
}

# Execute command type test
run_command_test() {
    local file=$1
    local timeout=$2

    local cmd_name=$(parse_test_case "$file" "input.command.name")
    local cmd_args=$(parse_test_case "$file" "input.command.args")

    # Build command
    local full_cmd="${cmd_name} ${cmd_args}"

    # Execute with timeout
    local output
    local exit_code

    if output=$(timeout "${timeout}s" bash -c "$full_cmd" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # Store output for validation
    echo "$output" > "/tmp/tri-agent-test-output-$$.txt"
    echo "$exit_code" > "/tmp/tri-agent-test-exitcode-$$.txt"

    return 0
}

# Validate test results
validate_results() {
    local file=$1
    local test_id=$(parse_test_case "$file" "id")

    log INFO "Validating results for ${test_id}"

    local output_file="/tmp/tri-agent-test-output-$$.txt"
    local exitcode_file="/tmp/tri-agent-test-exitcode-$$.txt"

    # Check exit code
    local expected_exit_code=$(parse_test_case "$file" "expected.exit_code")
    expected_exit_code=${expected_exit_code:-0}

    local actual_exit_code=$(cat "$exitcode_file" 2>/dev/null || echo "1")

    if [[ "$actual_exit_code" != "$expected_exit_code" ]]; then
        log FAIL "Exit code mismatch: expected ${expected_exit_code}, got ${actual_exit_code}"
        return 1
    fi

    # Check stdout contains expected strings
    local stdout_contains=$(parse_test_case "$file" "expected.stdout.contains")
    if [[ -n "$stdout_contains" && "$stdout_contains" != "null" ]]; then
        while IFS= read -r expected; do
            if ! grep -q "$expected" "$output_file"; then
                log FAIL "Expected output not found: $expected"
                return 1
            fi
        done <<< "$stdout_contains"
    fi

    log PASS "All validations passed"
    return 0
}

# Run teardown phase
run_teardown() {
    local file=$1
    log INFO "Running teardown for $(basename "$file")"

    local teardown_commands=$(parse_test_case "$file" "teardown.commands")
    if [[ -n "$teardown_commands" && "$teardown_commands" != "null" ]]; then
        eval "$teardown_commands" 2>&1 || true  # Don't fail on teardown errors
    fi

    # Cleanup temp files
    rm -f /tmp/tri-agent-test-output-$$.txt
    rm -f /tmp/tri-agent-test-exitcode-$$.txt

    return 0
}

# Run single test with retry logic
run_single_test() {
    local file=$1
    local test_id=$(parse_test_case "$file" "id")
    local test_name=$(parse_test_case "$file" "name")
    local max_attempts=$(parse_test_case "$file" "retry.max_attempts")
    max_attempts=${max_attempts:-3}

    local backoff_base=$(parse_test_case "$file" "retry.backoff.base_seconds")
    backoff_base=${backoff_base:-2}

    log INFO "=========================================="
    log INFO "Running: ${test_id} - ${test_name}"
    log INFO "=========================================="

    local attempt=1
    local success=false

    while [[ $attempt -le $max_attempts ]]; do
        log INFO "Attempt ${attempt}/${max_attempts}"

        # Run setup
        if ! run_setup "$file"; then
            log WARN "Setup failed, retrying..."
            ((attempt++))
            sleep $((backoff_base ** (attempt - 1)))
            continue
        fi

        # Run execution
        if ! run_test_execution "$file"; then
            log WARN "Execution failed, retrying..."
            run_teardown "$file"
            ((attempt++))
            sleep $((backoff_base ** (attempt - 1)))
            continue
        fi

        # Validate results
        if validate_results "$file"; then
            success=true
            break
        fi

        # Retry logic
        log WARN "Validation failed, attempt ${attempt}/${max_attempts}"
        run_teardown "$file"

        if [[ $attempt -lt $max_attempts ]]; then
            local wait_time=$((backoff_base ** attempt))
            log INFO "Waiting ${wait_time}s before retry..."
            sleep "$wait_time"
        fi

        ((attempt++))
    done

    # Always run teardown
    run_teardown "$file"

    if $success; then
        return 0
    else
        return 1
    fi
}

# Generate test report
generate_report() {
    local report_file="${RESULTS_DIR}/report-${RUN_ID}.json"

    cat > "$report_file" << EOF
{
    "run_id": "${RUN_ID}",
    "timestamp": "${RUN_TIMESTAMP}",
    "summary": {
        "total": ${TOTAL_TESTS},
        "passed": ${PASSED_TESTS},
        "failed": ${FAILED_TESTS},
        "skipped": ${SKIPPED_TESTS},
        "pass_rate": $(echo "scale=2; ${PASSED_TESTS} * 100 / ${TOTAL_TESTS}" | bc 2>/dev/null || echo "0")
    },
    "filters": {
        "category": "${FILTER_CATEGORY:-all}",
        "priority": "${FILTER_PRIORITY:-all}",
        "tags": "${FILTER_TAGS:-all}"
    },
    "log_file": "${LOG_FILE}"
}
EOF

    log INFO "Report generated: ${report_file}"
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "           TEST RUN SUMMARY"
    echo "=========================================="
    echo -e "Total:   ${TOTAL_TESTS}"
    echo -e "Passed:  ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:  ${RED}${FAILED_TESTS}${NC}"
    echo -e "Skipped: ${YELLOW}${SKIPPED_TESTS}${NC}"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed.${NC}"
        echo "See log file: ${LOG_FILE}"
    fi
    echo "=========================================="
}

# Main execution
main() {
    parse_args "$@"

    log INFO "Starting Tri-Agent Daemon Test Run"
    log INFO "Run ID: ${RUN_ID}"

    # Discover tests
    local test_files
    readarray -t test_files < <(discover_tests)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log ERROR "No test cases found"
        exit 1
    fi

    log INFO "Discovered ${#test_files[@]} test cases"

    # Run tests
    for file in "${test_files[@]}"; do
        ((TOTAL_TESTS++))

        if should_skip_test "$file"; then
            log WARN "Skipping: $(basename "$file")"
            ((SKIPPED_TESTS++))
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "Would run: $(basename "$file")"
            continue
        fi

        if run_single_test "$file"; then
            ((PASSED_TESTS++))
        else
            ((FAILED_TESTS++))

            if [[ "$FAIL_FAST" == "true" ]]; then
                log ERROR "Fail-fast triggered, stopping test run"
                break
            fi
        fi
    done

    # Generate report and summary
    generate_report
    print_summary

    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# Run main
main "$@"
