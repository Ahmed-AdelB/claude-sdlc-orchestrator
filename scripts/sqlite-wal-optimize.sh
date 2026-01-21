#!/bin/bash
# SQLite WAL Mode Optimization Script for Tri-Agent System
# Addresses DB lock contention by enabling WAL mode and setting optimal pragmas
#
# Usage:
#   ./sqlite-wal-optimize.sh              # Optimize all databases
#   ./sqlite-wal-optimize.sh --verify     # Verify current settings
#   ./sqlite-wal-optimize.sh --checkpoint # Run WAL checkpoint on all DBs
#
# Author: Ahmed Adel Bakr Alderai

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
DATABASES=(
    "${STATE_DIR}/ai-usage.db"
    "${STATE_DIR}/test-ai-usage.db"
    "${STATE_DIR}/tri-agent.db"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Persistent WAL settings (survive across connections)
set_persistent_pragmas() {
    local db="$1"
    sqlite3 "$db" "PRAGMA journal_mode=WAL;"
}

# Runtime settings (must be set per connection)
# These are documented here for applications to use
get_runtime_pragmas() {
    cat << 'EOF'
-- Runtime PRAGMA settings for optimal WAL performance
-- Set these on each database connection:
PRAGMA busy_timeout=5000;        -- Wait 5 seconds before SQLITE_BUSY
PRAGMA synchronous=NORMAL;       -- Safe for WAL mode, better performance
PRAGMA cache_size=-64000;        -- 64MB cache
PRAGMA wal_autocheckpoint=1000;  -- Checkpoint every 1000 pages
PRAGMA temp_store=MEMORY;        -- Store temp tables in memory
PRAGMA mmap_size=268435456;      -- 256MB memory-mapped I/O
EOF
}

# Apply runtime pragmas to a database
apply_runtime_pragmas() {
    local db="$1"
    sqlite3 "$db" << 'EOF'
PRAGMA busy_timeout=5000;
PRAGMA synchronous=NORMAL;
PRAGMA cache_size=-64000;
PRAGMA wal_autocheckpoint=1000;
PRAGMA temp_store=MEMORY;
PRAGMA mmap_size=268435456;
EOF
}

# Verify database settings
verify_database() {
    local db="$1"
    local db_name=$(basename "$db")

    echo "=== ${db_name} ==="

    if [[ ! -f "$db" ]]; then
        log_error "Database not found: $db"
        return 1
    fi

    local journal_mode=$(sqlite3 "$db" "PRAGMA journal_mode;")
    local integrity=$(sqlite3 "$db" "PRAGMA integrity_check;")
    local page_count=$(sqlite3 "$db" "PRAGMA page_count;")
    local page_size=$(sqlite3 "$db" "PRAGMA page_size;")
    local size_kb=$((page_count * page_size / 1024))

    echo "  Journal Mode: ${journal_mode}"
    echo "  Integrity: ${integrity}"
    echo "  Size: ${size_kb} KB (${page_count} pages x ${page_size} bytes)"

    # Check for WAL files
    if [[ -f "${db}-wal" ]]; then
        local wal_size=$(stat -c%s "${db}-wal" 2>/dev/null || echo 0)
        echo "  WAL File: ${wal_size} bytes"
    else
        echo "  WAL File: Not present (created on first write)"
    fi

    if [[ -f "${db}-shm" ]]; then
        echo "  SHM File: Present"
    fi

    if [[ "$journal_mode" == "wal" ]]; then
        log_info "WAL mode enabled"
        return 0
    else
        log_warn "WAL mode NOT enabled (current: ${journal_mode})"
        return 1
    fi
}

# Run WAL checkpoint
checkpoint_database() {
    local db="$1"
    local db_name=$(basename "$db")

    if [[ ! -f "$db" ]]; then
        log_error "Database not found: $db"
        return 1
    fi

    log_info "Checkpointing ${db_name}..."
    local result=$(sqlite3 "$db" "PRAGMA wal_checkpoint(TRUNCATE);")
    echo "  Result: ${result}"
}

# Optimize a single database
optimize_database() {
    local db="$1"
    local db_name=$(basename "$db")

    if [[ ! -f "$db" ]]; then
        log_error "Database not found: $db"
        return 1
    fi

    log_info "Optimizing ${db_name}..."

    # Check current mode
    local current_mode=$(sqlite3 "$db" "PRAGMA journal_mode;")

    if [[ "$current_mode" != "wal" ]]; then
        log_info "  Enabling WAL mode (was: ${current_mode})"
        set_persistent_pragmas "$db"
    else
        log_info "  WAL mode already enabled"
    fi

    # Apply runtime pragmas for this session
    apply_runtime_pragmas "$db"

    # Run analyze for query optimization
    sqlite3 "$db" "ANALYZE;"

    log_info "  Optimization complete"
}

# Main execution
main() {
    local mode="${1:-optimize}"

    echo "=========================================="
    echo " SQLite WAL Mode Optimization"
    echo " Tri-Agent System Database Optimizer"
    echo "=========================================="
    echo ""

    case "$mode" in
        --verify|-v)
            echo "Verifying database settings..."
            echo ""
            for db in "${DATABASES[@]}"; do
                if [[ -f "$db" ]]; then
                    verify_database "$db"
                    echo ""
                fi
            done
            ;;
        --checkpoint|-c)
            echo "Running WAL checkpoints..."
            echo ""
            for db in "${DATABASES[@]}"; do
                if [[ -f "$db" ]]; then
                    checkpoint_database "$db"
                fi
            done
            ;;
        --runtime-pragmas|-r)
            echo "Runtime PRAGMA settings for application use:"
            echo ""
            get_runtime_pragmas
            ;;
        --help|-h)
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  (none)           Optimize all databases (enable WAL mode)"
            echo "  --verify, -v     Verify current database settings"
            echo "  --checkpoint, -c Run WAL checkpoint on all databases"
            echo "  --runtime-pragmas, -r  Show runtime PRAGMA settings"
            echo "  --help, -h       Show this help message"
            ;;
        *)
            echo "Optimizing databases..."
            echo ""
            for db in "${DATABASES[@]}"; do
                if [[ -f "$db" ]]; then
                    optimize_database "$db"
                    echo ""
                fi
            done

            echo "=========================================="
            echo " Optimization Summary"
            echo "=========================================="
            echo ""
            echo "Databases optimized:"
            for db in "${DATABASES[@]}"; do
                if [[ -f "$db" ]]; then
                    local mode=$(sqlite3 "$db" "PRAGMA journal_mode;")
                    echo "  - $(basename "$db"): journal_mode=${mode}"
                fi
            done
            echo ""
            echo "Note: busy_timeout and other runtime settings must be"
            echo "set by each application on connection. Use --runtime-pragmas"
            echo "to see recommended settings."
            ;;
    esac
}

main "$@"
