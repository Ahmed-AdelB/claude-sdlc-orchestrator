#!/bin/bash
set -euo pipefail

# Scripts/lint-task.sh - Validates task markdown files against project standards
# Exit codes:
# 0: Pass
# 1: Lint validation failed
# 2: Usage error (invalid file, arguments)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

log_pass() {
    echo -e "${GREEN}Pass:${NC} $1"
}

# 1. Input Validation
if [ "$#" -ne 1 ]; then
    log_error "Usage: $0 <task-file.md>"
    exit 2
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    log_error "File not found: $FILE"
    exit 2
fi

if [ ! -r "$FILE" ]; then
    log_error "File not readable: $FILE"
    exit 2
fi

if [[ "$FILE" != *.md ]]; then
    log_error "File must have .md extension: $FILE"
    exit 2
fi

FAILURES=0

# 2. Check for Required Sections
REQUIRED_SECTIONS=("## TODO List" "## User Approval Gate" "## Verification Protocol")

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -Fq -- "$section" "$FILE"; then
        log_error "Missing required section: '$section'"
        FAILURES=$((FAILURES + 1))
    fi
done

# 3. Validate TODO List Table Headers
# Looking for standard headers: Task ID | Description | Status | Dependency
# Allow for flexible spacing
if grep -Fq -- "## TODO List" "$FILE"; then
    # Get lines after TODO List until next header, search for table header
    # We look for a line starting with | and containing the required columns
    if ! grep -A 10 -- "## TODO List" "$FILE" | grep -Eq '\|[[:space:]]*Task ID[[:space:]]*\|[[:space:]]*Description[[:space:]]*\|[[:space:]]*Status[[:space:]]*\|'; then
         log_error "TODO List table missing valid headers (Expected: | Task ID | Description | Status | ...)"
         FAILURES=$((FAILURES + 1))
    fi
fi

# 4. Check Verification Protocol Template Fields
# Required fields from CLAUDE.md: Scope, Change summary, Expected behavior, Repro steps, Evidence, Risk notes
VERIFY_FIELDS=("Scope" "Change summary" "Expected behavior" "Repro steps" "Evidence" "Risk notes")

if grep -Fq -- "## Verification Protocol" "$FILE"; then
    VERIFY_CONTENT=$(grep -A 20 -- "## Verification Protocol" "$FILE")

    for field in "${VERIFY_FIELDS[@]}"; do
        if ! echo "$VERIFY_CONTENT" | grep -Fiq -- "$field"; then
            log_error "Verification Protocol missing field: '$field'"
            FAILURES=$((FAILURES + 1))
        fi
    done
fi

# 5. Final Report
if [ "$FAILURES" -eq 0 ]; then
    log_pass "Task file '$FILE' passed validation."
    exit 0
else
    echo -e "${RED}Validation failed with $FAILURES errors.${NC}"
    exit 1
fi
