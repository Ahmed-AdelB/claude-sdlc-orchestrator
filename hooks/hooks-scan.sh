#!/bin/bash
# Auto-Discovery for Claude Code Hook Vulnerabilities
# Scans for set -e, unsafe grep, and brittle JSON construction

HOOKS_DIR="${HOME}/.claude/hooks"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Scanning hooks in $HOOKS_DIR..."
echo "----------------------------------------"

for hook in "$HOOKS_DIR"/*.sh; do
    [[ -f "$hook" ]] || continue
    name=$(basename "$hook")
    
    # Skip self
    [[ "$name" == "hooks-scan.sh" || "$name" == "hooks-harden.sh" ]] && continue

    issues=()
    score=0

    # Check 1: Strict Mode (set -e)
    # Match set -e, set -eu, set -euo (but ensure 'e' is in the flag group, not in arguments like pipefail)
    if grep -qE "^\s*set\s+-[a-zA-Z]*e" "$hook"; then
        issues+=("${RED}[CRITICAL] Uses set -e (crashes on non-fatal errors)${NC}")
        score=$((score + 5))
    fi

    # Check 2: Unsafe Grep (grep without if/||, likely to crash under set -e)
    # Looking for grep that is NOT preceded by 'if' or followed by '||'
    # This is a heuristic
    if grep -qE "^\s*if.*grep" "$hook"; then
        : # Safe usage in if
    elif grep -qE "grep.*\|\|" "$hook"; then
        : # Safe usage with OR
    elif grep -q "grep" "$hook"; then
        if grep -qE "set -.*e" "$hook"; then
            issues+=("${RED}[CRITICAL] unsafe grep usage with set -e${NC}")
            score=$((score + 5))
        else
            issues+=("${YELLOW}[WARN] grep usage (check exit code handling)${NC}")
            score=$((score + 1))
        fi
    fi

    # Check 3: Brittle JSON construction (echo "{...}")
    if grep -qE "echo.*\{.*\".*\}" "$hook"; then
        issues+=("${YELLOW}[WARN] Manual JSON construction (vulnerable to injection)${NC}")
        score=$((score + 2))
    fi

    # Check 4: Unsafe Input Reading
    if grep -q "TOOL_DATA=\$(cat)" "$hook"; then
         issues+=("${YELLOW}[WARN] Blocking input read (TOOL_DATA=\$(cat))${NC}")
         score=$((score + 1))
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}[OK]${NC} $name"
    else
        echo -e "issues found in $name (Risk Score: $score):"
        for issue in "${issues[@]}"; do
            echo -e "  - $issue"
        done
    fi
done
