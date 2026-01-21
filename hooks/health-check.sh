#!/bin/bash

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOG_DIR="$CLAUDE_DIR/logs"
LOG_FILE="$HOOKS_DIR/health-check.log"
STALE_LOCK_MINUTES=1440

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

mkdir -p "$HOOKS_DIR"

echo "Starting Hook Health Check..." | tee "$LOG_FILE"
echo "Hooks Directory: $HOOKS_DIR" | tee -a "$LOG_FILE"
echo "Logs Directory: $LOG_DIR" | tee -a "$LOG_FILE"

# 0. Check log directory existence
echo "Checking log directory..." | tee -a "$LOG_FILE"
if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}[OK] Log directory exists.${NC}" | tee -a "$LOG_FILE"
else
    echo -n "[MISSING] Creating log directory... " | tee -a "$LOG_FILE"
    mkdir -p "$LOG_DIR"
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}Created${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Failed to create log directory${NC}" | tee -a "$LOG_FILE"
    fi
fi

# 1. Check dependencies
echo "Checking dependencies..." | tee -a "$LOG_FILE"
HAS_JQ=false
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR] jq is not installed. Hooks relying on JSON parsing will fail.${NC}" | tee -a "$LOG_FILE"
else
    HAS_JQ=true
    echo -e "${GREEN}[OK] jq is installed.${NC}" | tee -a "$LOG_FILE"
fi

# 2. Check Hooks
echo "Scanning hooks..." | tee -a "$LOG_FILE"
find "$HOOKS_DIR" -name "*.sh" -print0 | while IFS= read -r -d '' hook_file; do
    hook_name=$(basename "$hook_file")
    
    # Skip self
    if [ "$hook_name" == "health-check.sh" ]; then
        continue
    fi

    echo -n "Checking $hook_name... " | tee -a "$LOG_FILE"
    
    # Check permissions
    if [ ! -x "$hook_file" ]; then
        echo -n "[FIXING PERMISSIONS] " | tee -a "$LOG_FILE"
        chmod +x "$hook_file"
        if [ $? -eq 0 ]; then
             echo -e "${YELLOW}Fixed${NC}" | tee -a "$LOG_FILE"
        else
             echo -e "${RED}Failed to fix permissions${NC}" | tee -a "$LOG_FILE"
        fi
    fi

    # Check Syntax
    if bash -n "$hook_file"; then
        echo -e "${GREEN}[SYNTAX OK]${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[SYNTAX ERROR]${NC}" | tee -a "$LOG_FILE"
        bash -n "$hook_file" 2>&1 | tee -a "$LOG_FILE"
    fi
done

# 3. Check JSON files (if any exist in the hooks dir or subdirs)
echo "Scanning JSON configuration files in hooks..." | tee -a "$LOG_FILE"
found_json=false
while IFS= read -r -d '' json_file; do
    found_json=true
    json_name=$(basename "$json_file")
    echo -n "Checking $json_name... " | tee -a "$LOG_FILE"

    if [ ! -s "$json_file" ]; then
        echo -n "[EMPTY FILE] Initializing... " | tee -a "$LOG_FILE"
        echo "{}" > "$json_file"
        echo -e "${YELLOW}Fixed${NC}" | tee -a "$LOG_FILE"
    else
        if [ "$HAS_JQ" = true ] && jq empty "$json_file" 2>/dev/null; then
             echo -e "${GREEN}[VALID]${NC}" | tee -a "$LOG_FILE"
        elif [ "$HAS_JQ" = true ]; then
             echo -e "${RED}[INVALID JSON]${NC}" | tee -a "$LOG_FILE"
        else
             echo -e "${YELLOW}[SKIPPED: jq missing]${NC}" | tee -a "$LOG_FILE"
        fi
    fi
done < <(find "$HOOKS_DIR" -name "*.json" -print0)

if [ "$found_json" = false ]; then
    echo -e "${GREEN}[OK] No JSON configuration files found in hooks.${NC}" | tee -a "$LOG_FILE"
fi

# 4. Check JSON files in logs directory
echo "Scanning JSON files in logs..." | tee -a "$LOG_FILE"
found_log_json=false
while IFS= read -r -d '' json_file; do
    found_log_json=true
    json_name=$(basename "$json_file")
    echo -n "Checking $json_name... " | tee -a "$LOG_FILE"

    if [ ! -s "$json_file" ]; then
        echo -n "[EMPTY FILE] Initializing... " | tee -a "$LOG_FILE"
        echo "{}" > "$json_file"
        echo -e "${YELLOW}Fixed${NC}" | tee -a "$LOG_FILE"
    else
        if [ "$HAS_JQ" = true ] && jq empty "$json_file" 2>/dev/null; then
             echo -e "${GREEN}[VALID]${NC}" | tee -a "$LOG_FILE"
        elif [ "$HAS_JQ" = true ]; then
             echo -e "${RED}[INVALID JSON]${NC}" | tee -a "$LOG_FILE"
        else
             echo -e "${YELLOW}[SKIPPED: jq missing]${NC}" | tee -a "$LOG_FILE"
        fi
    fi
done < <(find "$LOG_DIR" -name "*.json" -print0)

if [ "$found_log_json" = false ]; then
    echo -e "${GREEN}[OK] No JSON files found in logs.${NC}" | tee -a "$LOG_FILE"
fi

# 5. Cleanup stale lock files
echo "Cleaning stale lock files (older than ${STALE_LOCK_MINUTES} minutes)..." | tee -a "$LOG_FILE"
LOCK_CHECK_TOOL="none"
if command -v lsof &> /dev/null; then
    LOCK_CHECK_TOOL="lsof"
elif command -v fuser &> /dev/null; then
    LOCK_CHECK_TOOL="fuser"
else
    echo -e "${YELLOW}[WARN] Neither lsof nor fuser found; using age only.${NC}" | tee -a "$LOG_FILE"
fi

found_locks=false
while IFS= read -r -d '' lock_file; do
    found_locks=true
    if [ "$LOCK_CHECK_TOOL" = "lsof" ]; then
        if lsof "$lock_file" >/dev/null 2>&1; then
            echo -e "${YELLOW}[IN USE] ${lock_file}${NC}" | tee -a "$LOG_FILE"
            continue
        fi
    elif [ "$LOCK_CHECK_TOOL" = "fuser" ]; then
        if fuser "$lock_file" >/dev/null 2>&1; then
            echo -e "${YELLOW}[IN USE] ${lock_file}${NC}" | tee -a "$LOG_FILE"
            continue
        fi
    fi

    rm -f "$lock_file"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[REMOVED] ${lock_file}${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[FAILED] ${lock_file}${NC}" | tee -a "$LOG_FILE"
    fi
done < <(find "$CLAUDE_DIR" -type f -name "*.lock" -mmin +"$STALE_LOCK_MINUTES" -print0)

if [ "$found_locks" = false ]; then
    echo -e "${GREEN}[OK] No stale lock files found.${NC}" | tee -a "$LOG_FILE"
fi

echo "Health Check Complete. Log saved to $LOG_FILE"
