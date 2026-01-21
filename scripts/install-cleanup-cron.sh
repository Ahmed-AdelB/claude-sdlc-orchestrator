#!/bin/bash
# ==============================================================================
# Tri-Agent Cleanup System Installation Script
# ==============================================================================
# Version: 1.0.0
# Author: Ahmed Adel Bakr Alderai
# Created: 2026-01-21
#
# This script installs the automated cleanup cron jobs safely.
#
# USAGE:
#   ./install-cleanup-cron.sh [OPTIONS]
#
# OPTIONS:
#   --install     Install cron jobs (default action)
#   --remove      Remove tri-agent cron jobs
#   --status      Show current cron job status
#   --test        Test scripts without installing
#   -h, --help    Show help
#
# ==============================================================================

set -euo pipefail

readonly CLAUDE_DIR="${HOME}/.claude"
readonly SCRIPTS_DIR="${CLAUDE_DIR}/scripts"
readonly CRON_CONFIG="${CLAUDE_DIR}/cron/auto-cleanup.cron"
readonly LOG_DIR="${CLAUDE_DIR}/logs"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_help() {
    cat << 'EOF'
Tri-Agent Cleanup System Installation Script

USAGE:
    install-cleanup-cron.sh [OPTIONS]

OPTIONS:
    --install     Install cron jobs (default)
    --remove      Remove tri-agent cron jobs from crontab
    --status      Show current cron job status
    --test        Test scripts without installing
    -h, --help    Show this help

WHAT THIS INSTALLS:
    1. Daily cleanup at 3:00 AM
    2. Checkpoint cleanup every 8 hours
    3. Disk monitoring every 4 hours
    4. Business hours monitoring (9 AM - 6 PM, weekdays)
    5. Weekly log rotation

EXAMPLES:
    # Install cron jobs
    ./install-cleanup-cron.sh --install

    # Check status
    ./install-cleanup-cron.sh --status

    # Test scripts first
    ./install-cleanup-cron.sh --test

    # Remove all tri-agent cron jobs
    ./install-cleanup-cron.sh --remove
EOF
}

# ==============================================================================
# VERIFICATION FUNCTIONS
# ==============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local errors=0

    # Check scripts exist
    if [[ -x "${SCRIPTS_DIR}/auto-cleanup.sh" ]]; then
        print_success "auto-cleanup.sh is executable"
    else
        print_error "auto-cleanup.sh not found or not executable"
        ((errors++))
    fi

    if [[ -x "${SCRIPTS_DIR}/disk-monitor.sh" ]]; then
        print_success "disk-monitor.sh is executable"
    else
        print_error "disk-monitor.sh not found or not executable"
        ((errors++))
    fi

    # Check cron config exists
    if [[ -f "$CRON_CONFIG" ]]; then
        print_success "Cron configuration file exists"
    else
        print_error "Cron configuration not found at $CRON_CONFIG"
        ((errors++))
    fi

    # Check crontab is available
    if command -v crontab &>/dev/null; then
        print_success "crontab command available"
    else
        print_error "crontab command not found"
        ((errors++))
    fi

    # Check log directory
    if [[ -d "$LOG_DIR" ]]; then
        print_success "Log directory exists"
    else
        print_warning "Log directory does not exist, will create"
        mkdir -p "$LOG_DIR"
    fi

    # Check sqlite3 for database operations
    if command -v sqlite3 &>/dev/null; then
        print_success "sqlite3 available"
    else
        print_warning "sqlite3 not found - database maintenance may fail"
    fi

    # Check notify-send for desktop notifications
    if command -v notify-send &>/dev/null; then
        print_success "notify-send available for desktop notifications"
    else
        print_warning "notify-send not found - desktop notifications disabled"
    fi

    echo ""
    return $errors
}

test_scripts() {
    print_header "Testing Scripts (Dry Run)"

    local errors=0

    # Test auto-cleanup script
    print_info "Testing auto-cleanup.sh..."
    if "${SCRIPTS_DIR}/auto-cleanup.sh" --dry-run --verbose 2>&1 | head -50; then
        print_success "auto-cleanup.sh dry run completed"
    else
        print_error "auto-cleanup.sh test failed"
        ((errors++))
    fi

    echo ""

    # Test disk monitor
    print_info "Testing disk-monitor.sh..."
    if "${SCRIPTS_DIR}/disk-monitor.sh" 2>&1; then
        print_success "disk-monitor.sh test completed"
    else
        print_error "disk-monitor.sh test failed"
        ((errors++))
    fi

    echo ""

    if [[ $errors -eq 0 ]]; then
        print_success "All script tests passed"
    else
        print_error "$errors test(s) failed"
    fi

    return $errors
}

# ==============================================================================
# CRON MANAGEMENT
# ==============================================================================

install_cron_jobs() {
    print_header "Installing Cron Jobs"

    # Backup existing crontab
    local backup_file="${CLAUDE_DIR}/cron/crontab-backup-$(date +%Y%m%d%H%M%S)"
    if crontab -l &>/dev/null; then
        crontab -l > "$backup_file"
        print_info "Backed up existing crontab to: $backup_file"
    fi

    # Check if tri-agent jobs already exist
    if crontab -l 2>/dev/null | grep -q "auto-cleanup.sh"; then
        print_warning "Tri-agent cleanup jobs already exist in crontab"
        read -p "Do you want to replace them? (y/N): " response
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            print_info "Installation cancelled"
            return 1
        fi
        # Remove existing tri-agent entries
        crontab -l 2>/dev/null | grep -v "auto-cleanup.sh" | grep -v "disk-monitor.sh" | grep -v "tri-agent" > /tmp/crontab-cleaned 2>/dev/null || true
    else
        crontab -l > /tmp/crontab-cleaned 2>/dev/null || touch /tmp/crontab-cleaned
    fi

    # Add new entries
    cat >> /tmp/crontab-cleaned << EOF

# ==============================================================================
# Tri-Agent Automated Cleanup System
# Installed: $(date -Iseconds)
# ==============================================================================

# Daily cleanup at 3:00 AM
0 3 * * * ${SCRIPTS_DIR}/auto-cleanup.sh >> ${LOG_DIR}/auto-cleanup.log 2>&1

# Checkpoint cleanup every 8 hours
0 */8 * * * ${SCRIPTS_DIR}/auto-cleanup.sh --quiet >> ${LOG_DIR}/auto-cleanup.log 2>&1

# Disk monitoring every 4 hours
0 */4 * * * ${SCRIPTS_DIR}/disk-monitor.sh >> ${LOG_DIR}/disk-monitor.log 2>&1

# Business hours monitoring (9 AM - 6 PM, weekdays)
0 9-18 * * 1-5 ${SCRIPTS_DIR}/disk-monitor.sh --quiet >> ${LOG_DIR}/disk-monitor.log 2>&1

# Weekly log rotation (Sunday 4:00 AM)
0 4 * * 0 find ${LOG_DIR} -name "*.log" -size +10M -exec gzip {} \\; 2>/dev/null

# Weekly database maintenance (Sunday 5:00 AM)
0 5 * * 0 for db in ${CLAUDE_DIR}/state/*.db; do sqlite3 "\$db" "VACUUM; PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null; done

# ==============================================================================
EOF

    # Install new crontab
    if crontab /tmp/crontab-cleaned; then
        print_success "Cron jobs installed successfully"
        rm -f /tmp/crontab-cleaned
    else
        print_error "Failed to install cron jobs"
        rm -f /tmp/crontab-cleaned
        return 1
    fi

    # Show installed jobs
    echo ""
    print_info "Installed cron jobs:"
    crontab -l | grep -E "(auto-cleanup|disk-monitor|tri-agent)" | while read -r line; do
        echo "  $line"
    done

    echo ""
    print_success "Installation complete!"
    print_info "Logs will be written to: $LOG_DIR"
}

remove_cron_jobs() {
    print_header "Removing Tri-Agent Cron Jobs"

    # Backup existing crontab
    local backup_file="${CLAUDE_DIR}/cron/crontab-backup-$(date +%Y%m%d%H%M%S)"
    crontab -l > "$backup_file" 2>/dev/null || true
    print_info "Backed up existing crontab to: $backup_file"

    # Remove tri-agent entries
    crontab -l 2>/dev/null | \
        grep -v "auto-cleanup.sh" | \
        grep -v "disk-monitor.sh" | \
        grep -v "# Tri-Agent" | \
        grep -v "# tri-agent" | \
        grep -v "# Installed:" | \
        grep -v "# Daily cleanup" | \
        grep -v "# Checkpoint cleanup" | \
        grep -v "# Disk monitoring" | \
        grep -v "# Business hours" | \
        grep -v "# Weekly log rotation" | \
        grep -v "# Weekly database" | \
        sed '/^[[:space:]]*$/d' > /tmp/crontab-cleaned 2>/dev/null || touch /tmp/crontab-cleaned

    if crontab /tmp/crontab-cleaned; then
        print_success "Tri-agent cron jobs removed"
        rm -f /tmp/crontab-cleaned
    else
        print_error "Failed to update crontab"
        rm -f /tmp/crontab-cleaned
        return 1
    fi
}

show_status() {
    print_header "Cron Job Status"

    # Check crontab entries
    print_info "Current tri-agent cron entries:"
    local count
    count=$(crontab -l 2>/dev/null | grep -cE "(auto-cleanup|disk-monitor)" || echo 0)

    if [[ $count -eq 0 ]]; then
        print_warning "No tri-agent cron jobs found"
    else
        crontab -l 2>/dev/null | grep -E "(auto-cleanup|disk-monitor|Tri-Agent)" | while read -r line; do
            echo "  $line"
        done
        echo ""
        print_success "$count tri-agent cron job(s) installed"
    fi

    echo ""

    # Check last run times (from log files)
    print_info "Last run times:"

    if [[ -f "${LOG_DIR}/auto-cleanup.log" ]]; then
        local last_cleanup
        last_cleanup=$(tail -1 "${LOG_DIR}/auto-cleanup.log" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' || echo "N/A")
        echo "  auto-cleanup: $last_cleanup"
    else
        echo "  auto-cleanup: Never (log not found)"
    fi

    if [[ -f "${LOG_DIR}/disk-monitor.log" ]]; then
        local last_monitor
        last_monitor=$(tail -1 "${LOG_DIR}/disk-monitor.log" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' || echo "N/A")
        echo "  disk-monitor: $last_monitor"
    else
        echo "  disk-monitor: Never (log not found)"
    fi

    echo ""

    # Show disk space
    print_info "Current disk space:"
    local available_gb
    available_gb=$(df -BG "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')
    local claude_size
    claude_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)

    echo "  Available: ${available_gb}GB"
    echo "  .claude size: ${claude_size}"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    local action="install"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                action="install"
                shift
                ;;
            --remove)
                action="remove"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --test)
                action="test"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    case "$action" in
        install)
            check_prerequisites || exit 1
            test_scripts || {
                print_error "Script tests failed. Fix errors before installing."
                exit 1
            }
            install_cron_jobs
            ;;
        remove)
            remove_cron_jobs
            ;;
        status)
            show_status
            ;;
        test)
            check_prerequisites
            test_scripts
            ;;
    esac
}

main "$@"
