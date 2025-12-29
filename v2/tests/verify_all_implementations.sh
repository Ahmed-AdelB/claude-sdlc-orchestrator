#!/bin/bash
#===============================================================================
# tests/verify_all_implementations.sh
# Final verification script for TRI-24 System
#===============================================================================

# Set up logging and output
LOG_FILE="verification_report.log"
JSON_OUTPUT="verification_report.json"
echo "Starting verification at $(date)" > "$LOG_FILE"

# Start JSON
{
  echo "{"
  echo "  \"timestamp\": \"$(date -Iseconds)\","
  echo "  \"checks\": ["
} > "$JSON_OUTPUT"

first_check=true

# Function to add check result to JSON
add_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    local details="$4"

    if [ "$first_check" = true ]; then
        first_check=false
    else
        echo "," >> "$JSON_OUTPUT"
    fi

    # Escape quotes in message and details
    message="${message//\"/\\\"}"
    details="${details//\"/\\\"}"

    echo "    {" >> "$JSON_OUTPUT"
    echo "      \"name\": \"$name\"," >> "$JSON_OUTPUT"
    echo "      \"status\": \"$status\"," >> "$JSON_OUTPUT"
    echo "      \"message\": \"$message\"," >> "$JSON_OUTPUT"
    echo "      \"details\": \"$details\"" >> "$JSON_OUTPUT"
    echo "    }" >> "$JSON_OUTPUT"
    
    echo "[$status] $name: $message" | tee -a "$LOG_FILE"
}

#===============================================================================
# 1. Source all lib/*.sh files and check for syntax errors
#===============================================================================
echo "Checking libraries..." | tee -a "$LOG_FILE"
LIB_ERRORS=0
LIB_DETAILS=""

# Using ls to avoid globe issues if empty
for lib in lib/*.sh; do
    if bash -n "$lib"; then
        # Try sourcing it in a subshell to check for runtime errors during load
        # We ignore output to avoid cluttering logs with security warnings
        if (source "$lib" >/dev/null 2>&1); then
            :
        else
            LIB_ERRORS=$((LIB_ERRORS + 1))
            LIB_DETAILS="${LIB_DETAILS}Failed to source $lib; "
        fi
    else
        LIB_ERRORS=$((LIB_ERRORS + 1))
        LIB_DETAILS="${LIB_DETAILS}Syntax error in $lib; "
    fi
done

if [ "$LIB_ERRORS" -eq 0 ]; then
    add_result "Library Integrity" "PASS" "All libraries syntax checked and sourced successfully" ""
else
    add_result "Library Integrity" "FAIL" "Found $LIB_ERRORS library errors" "$LIB_DETAILS"
fi

#===============================================================================
# 2. Verify all SEC-* functions are exported
#===============================================================================
echo "Checking Security functions..." | tee -a "$LOG_FILE"
# Source security lib explicitly
source lib/security.sh >/dev/null 2>&1

REQUIRED_SEC_FUNCS=(
    "init_security_log"
    "log_security_event"
    "validate_input_length"
    "sanitize_input"
    "check_dangerous_patterns"
    "check_secrets"
    "redact_secrets"
    "validate_path"
    "secure_read"
    "secure_write"
    "shell_escape"
    "json_escape"
    "validate_json"
    "validate_json_size"
    "validate_json_depth"
    "validate_json_general_size"
    "safe_parse_json"
    "validate_task_payload"
    "safe_parse_task"
    "validate_array_items"
    "validate_task_queue_item"
    "secure_random"
    "hash_sensitive"
    "verify_integrity"
    "secure_tempfile"
    "validate_input"
    "get_security_status"
)

MISSING_FUNCS=0
MISSING_LIST=""

for func in "${REQUIRED_SEC_FUNCS[@]}"; do
    if ! declare -F "$func" > /dev/null; then
        MISSING_FUNCS=$((MISSING_FUNCS + 1))
        MISSING_LIST="${MISSING_LIST}$func "
    fi
done

if [ "$MISSING_FUNCS" -eq 0 ]; then
    add_result "Security Functions" "PASS" "All SEC-* functions exported" ""
else
    add_result "Security Functions" "FAIL" "Missing $MISSING_FUNCS functions" "$MISSING_LIST"
fi

#===============================================================================
# 3. Check M1-M5 implementations
#===============================================================================
echo "Checking M1-M5 implementations..." | tee -a "$LOG_FILE"

# M1 Checks (Should be complete)
M1_FILES=(
    "bin/tri-agent-worker"
    "bin/tri-agent-queue-watcher"
    "bin/budget-watchdog"
)
M1_STATUS="PASS"
M1_DETAILS=""

for file in "${M1_FILES[@]}"; do
    if [ ! -x "$file" ]; then
        M1_STATUS="FAIL"
        M1_DETAILS="${M1_DETAILS}Missing or non-executable: $file; "
    fi
done

# Check for SQLite logic in worker (Corrected check)
if ! grep -q "sqlite_claim_task" bin/tri-agent-worker; then
    M1_STATUS="FAIL"
    M1_DETAILS="${M1_DETAILS}M1-001: sqlite_claim_task not found in worker; "
fi

add_result "M1 Implementation" "$M1_STATUS" "Critical stabilization tasks" "$M1_DETAILS"

# M2 Checks (Core Autonomy)
M2_FILES=(
    "lib/sdlc-phases.sh"
    "bin/tri-agent-supervisor"
    "lib/supervisor-approver.sh"
)
M2_STATUS="PASS" 
M2_DETAILS=""
for file in "${M2_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        M2_STATUS="WARN"
        M2_DETAILS="${M2_DETAILS}Missing file: $file; "
    fi
done
add_result "M2 Implementation" "$M2_STATUS" "Core autonomy files check" "$M2_DETAILS"

# M3 Checks (Self Healing)
M3_FILES=(
    "bin/claude-delegate"
    "bin/codex-delegate"
    "lib/event-store.sh"
)
M3_STATUS="PASS"
M3_DETAILS=""
for file in "${M3_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        M3_STATUS="WARN"
        M3_DETAILS="${M3_DETAILS}Missing file: $file; "
    fi
done
add_result "M3 Implementation" "$M3_STATUS" "Self-healing files check" "$M3_DETAILS"

# M4 Checks (Security Hardening)
# We already checked lib/security.sh exports. Check for usage in common.sh
if grep -q "sanitize_input" lib/common.sh; then
    M4_STATUS="PASS"
    M4_MSG="Security integration detected in common.sh"
else
    M4_STATUS="WARN"
    M4_MSG="Security integration not clearly found in common.sh"
fi
add_result "M4 Implementation" "$M4_STATUS" "$M4_MSG" ""

# M5 Checks (Scale & UX)
M5_FILES=(
    "tests/security/test_security_fixes.sh"
    "bin/tri-agent-dashboard"
)
M5_STATUS="PASS"
M5_DETAILS=""
for file in "${M5_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        M5_STATUS="WARN"
        M5_DETAILS="${M5_DETAILS}Missing file: $file; "
    fi
done
add_result "M5 Implementation" "$M5_STATUS" "Scale & UX files check" "$M5_DETAILS"

#===============================================================================
# 4. Quick Integration Test (Queue Watcher Dry Run)
#===============================================================================
echo "Running integration checks..." | tee -a "$LOG_FILE"

if [ -x "bin/tri-agent-queue-watcher" ]; then
    if ./bin/tri-agent-queue-watcher --help > /dev/null 2>&1; then
        add_result "Integration: Queue Watcher" "PASS" "Queue watcher help command runs" ""
    else
        add_result "Integration: Queue Watcher" "FAIL" "Queue watcher help command failed" "Exit code $?"
    fi
else
    add_result "Integration: Queue Watcher" "SKIP" "Binary not found" ""
fi

# Check Budget Watchdog
if [ -x "bin/budget-watchdog" ]; then
    if ./bin/budget-watchdog --status > /dev/null 2>&1; then
        add_result "Integration: Budget Watchdog" "PASS" "Budget watchdog status command runs" ""
    else
        add_result "Integration: Budget Watchdog" "FAIL" "Budget watchdog status command failed" "Exit code $?"
    fi
else
    add_result "Integration: Budget Watchdog" "SKIP" "Binary not found" ""
fi

# Close JSON
echo "  ]" >> "$JSON_OUTPUT"
echo "}" >> "$JSON_OUTPUT"

echo "Verification complete. Report saved to $JSON_OUTPUT"
cat "$JSON_OUTPUT"
