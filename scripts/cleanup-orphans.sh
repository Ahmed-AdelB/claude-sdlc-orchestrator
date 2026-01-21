#!/bin/bash
# Claude Code Orphan Process Cleanup Script
# Location: ~/.claude/scripts/cleanup-orphans.sh
# Usage: bash ~/.claude/scripts/cleanup-orphans.sh

set -e

echo "========================================"
echo "  Claude Code Orphan Process Detector"
echo "========================================"
echo ""

# Find all Claude processes
echo "=== All Claude Processes ==="
ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | head -1
ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | grep -E 'claude.*(resume|skip-permissions|--resume)' | grep -v grep || echo "No Claude processes found."
echo ""

# Find orphaned processes (PPID=1)
echo "=== Orphaned Processes (PPID=1, lost parent) ==="
ORPHANS=$(ps -eo pid,ppid,tty,etime,cmd 2>/dev/null | grep claude | awk '$2==1 {print $1}')
if [ -n "$ORPHANS" ]; then
    ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | head -1
    for pid in $ORPHANS; do
        ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | grep "^[[:space:]]*$pid[[:space:]]"
    done
    echo ""
    echo "Found $(echo "$ORPHANS" | wc -w) orphaned process(es)."
else
    echo "No orphaned processes found."
fi
echo ""

# Find processes with no TTY
echo "=== Processes with No Terminal (TTY=?) ==="
NO_TTY=$(ps -eo pid,ppid,tty,cmd 2>/dev/null | grep claude | grep '\s?\s' | awk '{print $1}')
if [ -n "$NO_TTY" ]; then
    ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | head -1
    for pid in $NO_TTY; do
        ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd 2>/dev/null | grep "^[[:space:]]*$pid[[:space:]]" 2>/dev/null || true
    done
else
    echo "All processes have controlling terminals."
fi
echo ""

# Find stopped processes (state T)
echo "=== Stopped/Suspended Processes (State=T) ==="
STOPPED=$(ps aux 2>/dev/null | grep claude | grep -v grep | awk '$8 ~ /T/ {print $2}')
if [ -n "$STOPPED" ]; then
    for pid in $STOPPED; do
        ps -eo pid,ppid,tty,stat,etime,cmd 2>/dev/null | grep "^[[:space:]]*$pid[[:space:]]"
    done
else
    echo "No stopped processes found."
fi
echo ""

# Combine all problematic PIDs
KILL_CANDIDATES=""
[ -n "$ORPHANS" ] && KILL_CANDIDATES="$ORPHANS"
[ -n "$STOPPED" ] && KILL_CANDIDATES="$KILL_CANDIDATES $STOPPED"
KILL_CANDIDATES=$(echo "$KILL_CANDIDATES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -n "$KILL_CANDIDATES" ] && [ "$KILL_CANDIDATES" != " " ]; then
    echo "========================================"
    echo "  Cleanup Candidates: $KILL_CANDIDATES"
    echo "========================================"
    echo ""
    read -p "Kill these processes? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for pid in $KILL_CANDIDATES; do
            echo "Killing PID $pid..."
            kill "$pid" 2>/dev/null || echo "  Failed (may already be dead)"
        done
        echo ""
        echo "Cleanup complete. Waiting 2 seconds..."
        sleep 2

        # Verify
        echo ""
        echo "=== Remaining Claude Processes ==="
        ps aux | grep claude | grep -v grep || echo "No Claude processes running."
    else
        echo "Aborted. No processes killed."
    fi
else
    echo "========================================"
    echo "  No cleanup needed!"
    echo "========================================"
fi
