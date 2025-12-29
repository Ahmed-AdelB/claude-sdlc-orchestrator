#!/bin/bash
# =============================================================================
# escalation.sh - Human Escalation Protocol
# =============================================================================
# Handles triggers that require human intervention:
# 1. Stops autonomous operation.
# 2. Alerts the user.
# 3. Preserves state for debugging.
# =============================================================================

ESCALATION_DIR="$HOME/.claude/autonomous/escalation"
NOTIFY_CMD="notify-send" # Linux specific

mkdir -p "$ESCALATION_DIR"

trigger_escalation() {
    local reason="$1"
    local context="$2" # Optional file or ID
    local severity="${3:-HIGH}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local ticket_file="$ESCALATION_DIR/incident_${timestamp}.json"
    
    # 1. Create Incident Report
    cat <<EOF > "$ticket_file"
{
  "timestamp": "$(date -Iseconds)",
  "reason": "$reason",
  "context": "$context",
  "severity": "$severity",
  "status": "OPEN"
}
EOF

    # 2. Stop Autonomous Loop (Soft Stop)
    # Assuming there's a control file or service
    touch "$HOME/.claude/autonomous/PAUSE_REQUESTED"
    
    # 3. Notify User
    log_escalation "ESCALATION TRIGGERED: $reason"
    
    if command -v $NOTIFY_CMD &> /dev/null; then
        $NOTIFY_CMD "⚠️ Claude Autonomous Halted" "$reason" -u critical
    fi
    
    echo "Escalation triggered. See $ticket_file"
}

log_escalation() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$HOME/.claude/autonomous/logs/escalation.log"
}

export -f trigger_escalation
