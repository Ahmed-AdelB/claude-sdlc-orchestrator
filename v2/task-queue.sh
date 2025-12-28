#!/bin/bash
#===============================================================================
# task-queue.sh - Process multiple tasks through Claude Code sequentially
#===============================================================================

set -e

QUEUE_DIR="$HOME/.claude/autonomous/tasks/queue"
COMPLETED_DIR="$HOME/.claude/autonomous/tasks/completed"
FAILED_DIR="$HOME/.claude/autonomous/tasks/failed"
LOG_DIR="$HOME/.claude/autonomous/logs"
SETTINGS_FILE="$HOME/.claude/autonomous/settings-autonomous.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize directories
mkdir -p "$QUEUE_DIR" "$COMPLETED_DIR" "$FAILED_DIR" "$LOG_DIR"

# Get next task number
get_next_number() {
    local max=0
    while IFS= read -r f; do
        if [[ -f "$f" ]]; then
            local num
            num=$(basename "$f" .md | grep -oE '^[0-9]+' || echo "0")
            if [[ $num -gt $max ]]; then
                max=$num
            fi
        fi
    done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
    echo $((max + 1))
}

# Add task from string
add_task() {
    local task="$1"
    local num
    num=$(get_next_number)
    local task_file="$QUEUE_DIR/$(printf '%04d' "$num")_task.md"

    cat > "$task_file" << TASKEOF
# Task $num
Created: $(date '+%Y-%m-%d %H:%M:%S')

## Instructions
$task

## Requirements
- Complete the task fully before marking as done
- Run tests if applicable
- Ensure code quality (lint, type-check)
- Create a brief summary when complete
TASKEOF

    echo -e "${GREEN}[+] Task $num added:${NC} $task_file"
    echo -e "${CYAN}    Preview:${NC} ${task:0:80}..."
}

# Add task from file
add_file() {
    local source_file="$1"
    if [[ ! -f "$source_file" ]]; then
        echo -e "${RED}[!] File not found:${NC} $source_file"
        exit 1
    fi

    local num
    num=$(get_next_number)
    local task_file="$QUEUE_DIR/$(printf '%04d' "$num")_$(basename "$source_file")"
    cp "$source_file" "$task_file"
    echo -e "${GREEN}[+] Task $num added from file:${NC} $task_file"
}

# List all tasks
list_tasks() {
    echo -e "\n${BLUE}=== Task Queue ===${NC}\n"

    local count=0
    while IFS= read -r f; do
        if [[ -f "$f" ]]; then
            count=$((count + 1))
            local name
            name=$(basename "$f")
            local preview
            preview=$(head -10 "$f" | grep -v '^#' | grep -v '^$' | head -1)
            echo -e "  ${CYAN}$count.${NC} $name"
            echo -e "     ${preview:0:70}..."
            echo ""
        fi
    done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort || true)

    if [[ $count -eq 0 ]]; then
        echo -e "  ${YELLOW}(Queue is empty)${NC}"
    else
        echo -e "  ${GREEN}Total: $count task(s) pending${NC}"
    fi

    # Show completed
    local completed
    completed=$(find "$COMPLETED_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l || echo "0")
    local failed
    failed=$(find "$FAILED_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l || echo "0")
    echo -e "\n  ${GREEN}Completed:${NC} $completed  |  ${RED}Failed:${NC} $failed"
    echo ""
}

# Process all tasks in queue
process_queue() {
    local project_dir="${1:-$(pwd)}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$LOG_DIR/queue_$timestamp.log"

    echo -e "${BLUE}=== Processing Task Queue ===${NC}"
    echo -e "Project: $project_dir"
    echo -e "Log: $log_file\n"

    cd "$project_dir"

    local has_tasks=false
    while IFS= read -r task_file; do
        if [[ ! -f "$task_file" ]]; then
            continue
        fi
        has_tasks=true

        local task_name
        task_name=$(basename "$task_file")
        echo -e "\n${CYAN}>>> Processing: $task_name${NC}"
        echo "=== Task: $task_name ===" >> "$log_file"
        echo "Started: $(date)" >> "$log_file"

        # Read task content
        local task_content
        task_content=$(cat "$task_file")

        # Run Claude with the task
        if claude --dangerously-skip-permissions \
                  --settings "$SETTINGS_FILE" \
                  --model opus \
                  -p "$task_content" \
                  2>&1 | tee -a "$log_file"; then

            echo -e "${GREEN}[OK] Completed: $task_name${NC}"
            mv "$task_file" "$COMPLETED_DIR/"
            echo "Completed: $(date)" >> "$log_file"
        else
            echo -e "${RED}[FAIL] Failed: $task_name${NC}"
            mv "$task_file" "$FAILED_DIR/"
            echo "Failed: $(date)" >> "$log_file"
        fi

        echo "" >> "$log_file"

        # Brief pause between tasks
        sleep 2
    done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort || true)

    if [[ "$has_tasks" == "false" ]]; then
        echo -e "${YELLOW}No tasks in queue${NC}"
    else
        echo -e "\n${GREEN}=== Queue processing complete ===${NC}"
    fi
}

# Clear the queue
clear_queue() {
    read -p "Clear all pending tasks? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$QUEUE_DIR" -maxdepth 1 -name "*.md" -type f -delete 2>/dev/null || true
        echo -e "${GREEN}Queue cleared${NC}"
    fi
}

# Show status
show_status() {
    local pending
    pending=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l || echo "0")
    local completed
    completed=$(find "$COMPLETED_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l || echo "0")
    local failed
    failed=$(find "$FAILED_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l || echo "0")

    echo -e "\n${BLUE}=== Task Queue Status ===${NC}\n"
    echo -e "  ${YELLOW}Pending:${NC}   $pending"
    echo -e "  ${GREEN}Completed:${NC} $completed"
    echo -e "  ${RED}Failed:${NC}    $failed"
    echo ""

    # Show most recent log
    local latest_log
    latest_log=$(find "$LOG_DIR" -maxdepth 1 -name "queue_*.log" -type f 2>/dev/null | sort -r | head -1 || true)
    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        echo -e "  ${CYAN}Latest Log:${NC} $latest_log"
        echo -e "  ${CYAN}Last 5 lines:${NC}"
        tail -5 "$latest_log" | sed 's/^/    /'
    fi
    echo ""
}

# Retry failed tasks
retry_failed() {
    local count=0
    while IFS= read -r f; do
        if [[ -f "$f" ]]; then
            mv "$f" "$QUEUE_DIR/"
            count=$((count + 1))
        fi
    done < <(find "$FAILED_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
    echo -e "${GREEN}Moved $count failed task(s) back to queue${NC}"
}

# Main
case "${1:-}" in
    add)
        shift
        if [[ -z "$*" ]]; then
            echo "Usage: task-queue.sh add \"task description\""
            exit 1
        fi
        add_task "$*"
        ;;
    add-file)
        if [[ -z "$2" ]]; then
            echo "Usage: task-queue.sh add-file path/to/task.md"
            exit 1
        fi
        add_file "$2"
        ;;
    list)
        list_tasks
        ;;
    process)
        process_queue "$2"
        ;;
    clear)
        clear_queue
        ;;
    status)
        show_status
        ;;
    retry)
        retry_failed
        ;;
    *)
        echo "Usage: task-queue.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  add \"task\"      Add a task from string"
        echo "  add-file FILE   Add a task from file"
        echo "  list            List all pending tasks"
        echo "  process [DIR]   Process all tasks in queue"
        echo "  status          Show queue status"
        echo "  clear           Clear pending tasks"
        echo "  retry           Move failed tasks back to queue"
        ;;
esac
