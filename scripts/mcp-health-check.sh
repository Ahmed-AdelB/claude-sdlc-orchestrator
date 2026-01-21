#!/bin/bash
#
# MCP Server Health Check & Auto-Recovery System
# Comprehensive monitoring of all 13 MCP servers configured in ~/.claude/mcp.json
#
# Author: Ahmed Adel Bakr Alderai
# Version: 1.0.0
# Created: 2026-01-21
#
# Features:
#   - Individual health checks for each MCP server
#   - Aggregate health status reporting
#   - Auto-recovery for failed servers
#   - Prometheus-compatible metrics export
#   - Integration with existing tri-agent monitoring
#
# Usage:
#   ./mcp-health-check.sh                    # Run all checks
#   ./mcp-health-check.sh --server git       # Check specific server
#   ./mcp-health-check.sh --format json      # JSON output
#   ./mcp-health-check.sh --auto-recover     # Enable auto-recovery
#   ./mcp-health-check.sh --watch            # Continuous monitoring mode
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directories
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
MCP_CONFIG="${CLAUDE_HOME}/mcp.json"
LOG_DIR="${CLAUDE_HOME}/logs/mcp"
METRICS_DIR="${CLAUDE_HOME}/metrics"
STATE_DIR="${CLAUDE_HOME}/state"

# Log files
HEALTH_LOG="${LOG_DIR}/mcp-health.log"
METRICS_FILE="${METRICS_DIR}/mcp-health.prom"
STATE_FILE="${STATE_DIR}/mcp-health-state.json"

# Timeouts (seconds)
STARTUP_TIMEOUT=10
CONNECTIVITY_TIMEOUT=5
RECOVERY_COOLDOWN=60

# Colors (if terminal supports them)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' RESET=''
fi

# MCP Server definitions (extracted from mcp.json)
declare -A MCP_SERVERS=(
    ["git"]="uvx:mcp-server-git@2025.4.8"
    ["github"]="npx:@modelcontextprotocol/server-github@2025.4.8"
    ["filesystem"]="npx:@modelcontextprotocol/server-filesystem@2025.12.18"
    ["memory"]="npx:@modelcontextprotocol/server-memory@2025.11.25"
    ["fetch"]="npx:@modelcontextprotocol/server-fetch@2025.4.8"
    ["sequential-thinking"]="npx:@modelcontextprotocol/server-sequential-thinking@2025.12.18"
    ["puppeteer"]="npx:@modelcontextprotocol/server-puppeteer@2025.5.12"
    ["playwright"]="npx:@playwright/mcp@0.0.54"
    ["postgres"]="npx:@modelcontextprotocol/server-postgres@0.6.2"
    ["redis"]="npx:@modelcontextprotocol/server-redis@2025.4.25"
    ["supabase"]="npx:@supabase/mcp-server@0.2.0"
    ["gemini-cli"]="npx:mcp-gemini-cli@0.3.1"
    ["context7"]="npx:@upstash/context7-mcp@2.0.1"
)

# Required environment variables for specific servers
declare -A MCP_ENV_VARS=(
    ["github"]="GITHUB_TOKEN"
    ["postgres"]="POSTGRES_URL,POSTGRES_HOST"
    ["redis"]="REDIS_URL,REDIS_HOST"
    ["supabase"]="SUPABASE_TOKEN"
    ["context7"]="CONTEXT7_API_KEY"
)

# External service dependencies
declare -A MCP_EXTERNAL_DEPS=(
    ["postgres"]="postgresql"
    ["redis"]="redis"
    ["supabase"]="supabase-api"
)

# Health status tracking
declare -A HEALTH_STATUS=()
declare -A HEALTH_MESSAGES=()
declare -A HEALTH_LATENCY=()
declare -A RECOVERY_ATTEMPTS=()

# Runtime options
OUTPUT_FORMAT="text"
AUTO_RECOVER=false
WATCH_MODE=false
WATCH_INTERVAL=60
VERBOSE=false
SPECIFIC_SERVER=""

# =============================================================================
# Logging Functions
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "$HEALTH_LOG"

    case "$level" in
        INFO)  [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[INFO]${RESET} ${message}" ;;
        OK)    echo -e "${GREEN}[OK]${RESET} ${message}" ;;
        WARN)  echo -e "${YELLOW}[WARN]${RESET} ${message}" ;;
        ERROR) echo -e "${RED}[ERROR]${RESET} ${message}" ;;
        DEBUG) [[ "$VERBOSE" == "true" ]] && echo -e "${MAGENTA}[DEBUG]${RESET} ${message}" ;;
    esac
}

log_metric() {
    local metric="$1"
    local value="$2"
    local labels="${3:-}"

    if [[ -n "$labels" ]]; then
        echo "mcp_${metric}{${labels}} ${value}" >> "$METRICS_FILE"
    else
        echo "mcp_${metric} ${value}" >> "$METRICS_FILE"
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat <<EOF
${BOLD}MCP Server Health Check v${VERSION}${RESET}

${BOLD}USAGE:${RESET}
    $SCRIPT_NAME [OPTIONS]

${BOLD}DESCRIPTION:${RESET}
    Comprehensive health monitoring for all 13 MCP servers configured
    in ~/.claude/mcp.json. Includes auto-recovery capabilities.

${BOLD}OPTIONS:${RESET}
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -s, --server <name>     Check specific server only
    -f, --format <format>   Output format: text, json, prometheus (default: text)
    -o, --output <file>     Write output to file
    -a, --auto-recover      Enable auto-recovery for failed servers
    -w, --watch             Continuous monitoring mode
    -i, --interval <secs>   Watch interval in seconds (default: 60)
    --list                  List all configured MCP servers

${BOLD}SERVERS (13):${RESET}
    git, github, filesystem, memory, fetch, sequential-thinking,
    puppeteer, playwright, postgres, redis, supabase, gemini-cli, context7

${BOLD}EXAMPLES:${RESET}
    # Run all health checks
    $SCRIPT_NAME

    # Check specific server
    $SCRIPT_NAME --server github

    # JSON output for integration
    $SCRIPT_NAME --format json

    # Auto-recovery mode
    $SCRIPT_NAME --auto-recover

    # Continuous monitoring
    $SCRIPT_NAME --watch --interval 30 --auto-recover

    # Prometheus metrics export
    $SCRIPT_NAME --format prometheus > /tmp/mcp-metrics.prom

${BOLD}EXIT CODES:${RESET}
    0 - All servers healthy
    1 - Some servers have warnings
    2 - Critical issues detected
    3 - Configuration error

EOF
    exit 0
}

list_servers() {
    echo -e "${BOLD}Configured MCP Servers (${#MCP_SERVERS[@]}):${RESET}"
    echo ""
    for server in "${!MCP_SERVERS[@]}"; do
        local spec="${MCP_SERVERS[$server]}"
        local runner="${spec%%:*}"
        local package="${spec#*:}"
        local env_vars="${MCP_ENV_VARS[$server]:-none}"
        local deps="${MCP_EXTERNAL_DEPS[$server]:-none}"

        printf "  ${CYAN}%-20s${RESET} runner: %-4s  package: %s\n" "$server" "$runner" "$package"
        [[ "$env_vars" != "none" ]] && printf "                       env: %s\n" "$env_vars"
        [[ "$deps" != "none" ]] && printf "                       deps: %s\n" "$deps"
    done
    echo ""
    exit 0
}

ensure_directories() {
    mkdir -p "$LOG_DIR" "$METRICS_DIR" "$STATE_DIR" 2>/dev/null || true
}

check_dependencies() {
    local missing=()

    command -v node &>/dev/null || missing+=("node")
    command -v npx &>/dev/null || missing+=("npx")
    command -v jq &>/dev/null || missing+=("jq")

    # Check for uvx (uv's package runner)
    if ! command -v uvx &>/dev/null; then
        if command -v uv &>/dev/null; then
            log DEBUG "uvx not found but uv is available"
        else
            missing+=("uvx/uv")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log ERROR "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

load_mcp_config() {
    if [[ ! -f "$MCP_CONFIG" ]]; then
        log ERROR "MCP config not found: $MCP_CONFIG"
        return 1
    fi

    if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
        log ERROR "Invalid JSON in MCP config"
        return 1
    fi

    log DEBUG "Loaded MCP config from $MCP_CONFIG"
    return 0
}

# =============================================================================
# Health Check Functions
# =============================================================================

check_runner_available() {
    local server="$1"
    local spec="${MCP_SERVERS[$server]}"
    local runner="${spec%%:*}"

    case "$runner" in
        npx)
            if command -v npx &>/dev/null; then
                return 0
            fi
            ;;
        uvx)
            if command -v uvx &>/dev/null; then
                return 0
            elif command -v uv &>/dev/null; then
                # uv can run uvx commands via "uv tool run"
                return 0
            fi
            ;;
    esac

    return 1
}

check_env_vars() {
    local server="$1"
    local required="${MCP_ENV_VARS[$server]:-}"

    if [[ -z "$required" ]]; then
        return 0
    fi

    local missing=()
    IFS=',' read -ra vars <<< "$required"

    for var in "${vars[@]}"; do
        var=$(echo "$var" | tr -d ' ')
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        HEALTH_MESSAGES[$server]="Missing env vars: ${missing[*]}"
        return 1
    fi

    return 0
}

check_external_dependency() {
    local server="$1"
    local dep="${MCP_EXTERNAL_DEPS[$server]:-}"

    if [[ -z "$dep" ]]; then
        return 0
    fi

    case "$dep" in
        postgresql)
            # Check if PostgreSQL is reachable
            local pg_host="${POSTGRES_HOST:-localhost}"
            local pg_port="${POSTGRES_PORT:-5432}"

            if timeout "$CONNECTIVITY_TIMEOUT" bash -c ">/dev/tcp/$pg_host/$pg_port" 2>/dev/null; then
                return 0
            else
                HEALTH_MESSAGES[$server]="PostgreSQL unreachable at $pg_host:$pg_port"
                return 1
            fi
            ;;
        redis)
            # Check if Redis is reachable
            local redis_host="${REDIS_HOST:-localhost}"
            local redis_port="${REDIS_PORT:-6379}"

            if timeout "$CONNECTIVITY_TIMEOUT" bash -c ">/dev/tcp/$redis_host/$redis_port" 2>/dev/null; then
                return 0
            else
                HEALTH_MESSAGES[$server]="Redis unreachable at $redis_host:$redis_port"
                return 1
            fi
            ;;
        supabase-api)
            # Check Supabase API availability
            if curl -sf --max-time "$CONNECTIVITY_TIMEOUT" "https://api.supabase.com" &>/dev/null; then
                return 0
            else
                HEALTH_MESSAGES[$server]="Supabase API unreachable"
                return 1
            fi
            ;;
    esac

    return 0
}

check_package_installed() {
    local server="$1"
    local spec="${MCP_SERVERS[$server]}"
    local runner="${spec%%:*}"
    local package="${spec#*:}"

    case "$runner" in
        npx)
            # Check if package can be resolved (npm cache or registry)
            local pkg_name="${package%%@*}"
            if npm view "$pkg_name" version &>/dev/null; then
                return 0
            fi
            ;;
        uvx)
            # For uvx, packages are fetched on demand
            return 0
            ;;
    esac

    HEALTH_MESSAGES[$server]="Package not resolvable: $package"
    return 1
}

check_server_startable() {
    local server="$1"
    local spec="${MCP_SERVERS[$server]}"
    local runner="${spec%%:*}"
    local package="${spec#*:}"
    local start_time
    local end_time
    local latency

    start_time=$(date +%s%3N)

    # Try to start the server briefly and check if it runs
    local test_cmd=""
    local test_output=""
    local test_exit=0

    case "$runner" in
        npx)
            # For npx servers, we can check if the package has a help flag
            test_cmd="timeout ${STARTUP_TIMEOUT}s npx -y ${package} --help 2>&1 || true"
            ;;
        uvx)
            test_cmd="timeout ${STARTUP_TIMEOUT}s uvx ${package} --help 2>&1 || true"
            ;;
    esac

    if [[ -n "$test_cmd" ]]; then
        test_output=$(eval "$test_cmd" 2>&1) || test_exit=$?

        # Check for common error patterns
        if echo "$test_output" | grep -qiE "error|not found|cannot find|ENOENT"; then
            HEALTH_MESSAGES[$server]="Server startup failed: $(echo "$test_output" | head -1)"
            end_time=$(date +%s%3N)
            HEALTH_LATENCY[$server]=$((end_time - start_time))
            return 1
        fi
    fi

    end_time=$(date +%s%3N)
    HEALTH_LATENCY[$server]=$((end_time - start_time))

    return 0
}

perform_health_check() {
    local server="$1"
    local status="UNKNOWN"
    local message=""

    log DEBUG "Checking server: $server"

    # Step 1: Check if runner is available
    if ! check_runner_available "$server"; then
        HEALTH_STATUS[$server]="ERROR"
        HEALTH_MESSAGES[$server]="Runner not available"
        return
    fi

    # Step 2: Check environment variables
    if ! check_env_vars "$server"; then
        HEALTH_STATUS[$server]="WARN"
        # Message already set by check_env_vars
        return
    fi

    # Step 3: Check external dependencies
    if ! check_external_dependency "$server"; then
        HEALTH_STATUS[$server]="ERROR"
        # Message already set by check_external_dependency
        return
    fi

    # Step 4: Check if package is resolvable (skip for speed in most cases)
    # This is an expensive check, so we only do it on verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        if ! check_package_installed "$server"; then
            HEALTH_STATUS[$server]="WARN"
            return
        fi
    fi

    # If all checks pass
    HEALTH_STATUS[$server]="OK"
    HEALTH_MESSAGES[$server]="Server ready"
    HEALTH_LATENCY[$server]="${HEALTH_LATENCY[$server]:-0}"
}

# =============================================================================
# Recovery Functions
# =============================================================================

attempt_recovery() {
    local server="$1"
    local status="${HEALTH_STATUS[$server]}"
    local attempts="${RECOVERY_ATTEMPTS[$server]:-0}"

    # Only recover from ERROR or CRITICAL states
    if [[ "$status" != "ERROR" && "$status" != "CRITICAL" ]]; then
        return 0
    fi

    # Check cooldown
    if [[ $attempts -ge 3 ]]; then
        log WARN "Recovery limit reached for $server (${attempts} attempts)"
        return 1
    fi

    log INFO "Attempting recovery for $server (attempt $((attempts + 1)))"
    RECOVERY_ATTEMPTS[$server]=$((attempts + 1))

    local spec="${MCP_SERVERS[$server]}"
    local runner="${spec%%:*}"
    local package="${spec#*:}"

    case "$runner" in
        npx)
            # Clear npm cache for the package
            local pkg_name="${package%%@*}"
            log DEBUG "Clearing npm cache for $pkg_name"
            npm cache clean --force "$pkg_name" 2>/dev/null || true

            # Pre-fetch the package
            log DEBUG "Pre-fetching package: $package"
            npx -y "$package" --help &>/dev/null || true
            ;;
        uvx)
            # For uvx, reinstall the tool
            log DEBUG "Reinstalling uvx tool: $package"
            uvx "$package" --help &>/dev/null || true
            ;;
    esac

    # Verify recovery
    sleep 2
    perform_health_check "$server"

    if [[ "${HEALTH_STATUS[$server]}" == "OK" ]]; then
        log OK "Recovery successful for $server"
        RECOVERY_ATTEMPTS[$server]=0
        return 0
    else
        log WARN "Recovery failed for $server"
        return 1
    fi
}

recover_external_service() {
    local server="$1"
    local dep="${MCP_EXTERNAL_DEPS[$server]:-}"

    case "$dep" in
        postgresql)
            log INFO "Attempting to restart PostgreSQL..."
            sudo systemctl restart postgresql 2>/dev/null || \
            pg_ctl restart -D "$PGDATA" 2>/dev/null || \
            log WARN "Could not restart PostgreSQL automatically"
            ;;
        redis)
            log INFO "Attempting to restart Redis..."
            sudo systemctl restart redis-server 2>/dev/null || \
            sudo systemctl restart redis 2>/dev/null || \
            redis-server --daemonize yes 2>/dev/null || \
            log WARN "Could not restart Redis automatically"
            ;;
    esac
}

# =============================================================================
# Report Generation
# =============================================================================

calculate_overall_status() {
    local has_critical=false
    local has_error=false
    local has_warn=false

    for server in "${!HEALTH_STATUS[@]}"; do
        case "${HEALTH_STATUS[$server]}" in
            CRITICAL) has_critical=true ;;
            ERROR) has_error=true ;;
            WARN) has_warn=true ;;
        esac
    done

    if [[ "$has_critical" == "true" ]]; then
        echo "CRITICAL"
    elif [[ "$has_error" == "true" ]]; then
        echo "ERROR"
    elif [[ "$has_warn" == "true" ]]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

generate_report_text() {
    local overall
    overall=$(calculate_overall_status)
    local healthy_count=0
    local warn_count=0
    local error_count=0

    echo ""
    echo "=============================================="
    echo "     MCP Server Health Report"
    echo "=============================================="
    echo ""
    echo "Timestamp: $(date -Iseconds)"
    echo "Overall Status: ${overall}"
    echo "Config: ${MCP_CONFIG}"
    echo ""
    echo "Server Status (${#MCP_SERVERS[@]} servers):"
    echo "----------------------------------------------"

    for server in $(echo "${!MCP_SERVERS[@]}" | tr ' ' '\n' | sort); do
        local status="${HEALTH_STATUS[$server]:-UNKNOWN}"
        local message="${HEALTH_MESSAGES[$server]:-No data}"
        local latency="${HEALTH_LATENCY[$server]:-0}"
        local status_icon=""

        case "$status" in
            OK) status_icon="${GREEN}[OK]${RESET}"; ((healthy_count++)) || true ;;
            WARN) status_icon="${YELLOW}[WARN]${RESET}"; ((warn_count++)) || true ;;
            ERROR|CRITICAL) status_icon="${RED}[${status}]${RESET}"; ((error_count++)) || true ;;
            *) status_icon="${MAGENTA}[?]${RESET}" ;;
        esac

        printf "  %-22s %s  %s (${latency}ms)\n" "$server" "$status_icon" "$message"
    done

    echo ""
    echo "Summary:"
    echo "  Healthy: ${healthy_count}/${#MCP_SERVERS[@]}"
    echo "  Warnings: ${warn_count}"
    echo "  Errors: ${error_count}"
    echo ""
    echo "=============================================="
}

generate_report_json() {
    local overall
    overall=$(calculate_overall_status)
    local timestamp
    timestamp=$(date -Iseconds)

    local servers_json="{"
    local first=true

    for server in "${!MCP_SERVERS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            servers_json+=","
        fi

        local status="${HEALTH_STATUS[$server]:-UNKNOWN}"
        local message="${HEALTH_MESSAGES[$server]:-}"
        local latency="${HEALTH_LATENCY[$server]:-0}"

        servers_json+="\"${server}\":{\"status\":\"${status}\",\"message\":\"${message}\",\"latency_ms\":${latency}}"
    done
    servers_json+="}"

    cat <<EOF
{
  "timestamp": "$timestamp",
  "overall_status": "$overall",
  "total_servers": ${#MCP_SERVERS[@]},
  "config_path": "$MCP_CONFIG",
  "servers": $servers_json
}
EOF
}

generate_report_prometheus() {
    local timestamp
    timestamp=$(date +%s)

    # Clear previous metrics
    : > "$METRICS_FILE"

    echo "# HELP mcp_server_health MCP server health status (0=unknown, 1=ok, 2=warn, 3=error, 4=critical)"
    echo "# TYPE mcp_server_health gauge"

    for server in "${!MCP_SERVERS[@]}"; do
        local status="${HEALTH_STATUS[$server]:-UNKNOWN}"
        local value=0

        case "$status" in
            OK) value=1 ;;
            WARN) value=2 ;;
            ERROR) value=3 ;;
            CRITICAL) value=4 ;;
        esac

        echo "mcp_server_health{server=\"$server\"} $value"
    done

    echo ""
    echo "# HELP mcp_server_latency_ms MCP server check latency in milliseconds"
    echo "# TYPE mcp_server_latency_ms gauge"

    for server in "${!MCP_SERVERS[@]}"; do
        local latency="${HEALTH_LATENCY[$server]:-0}"
        echo "mcp_server_latency_ms{server=\"$server\"} $latency"
    done

    echo ""
    echo "# HELP mcp_servers_total Total number of MCP servers configured"
    echo "# TYPE mcp_servers_total gauge"
    echo "mcp_servers_total ${#MCP_SERVERS[@]}"

    local healthy_count=0
    for server in "${!HEALTH_STATUS[@]}"; do
        [[ "${HEALTH_STATUS[$server]}" == "OK" ]] && ((healthy_count++)) || true
    done

    echo ""
    echo "# HELP mcp_servers_healthy Number of healthy MCP servers"
    echo "# TYPE mcp_servers_healthy gauge"
    echo "mcp_servers_healthy $healthy_count"

    echo ""
    echo "# HELP mcp_health_check_timestamp Unix timestamp of last health check"
    echo "# TYPE mcp_health_check_timestamp gauge"
    echo "mcp_health_check_timestamp $timestamp"
}

save_state() {
    local state_json
    state_json=$(generate_report_json)
    echo "$state_json" > "$STATE_FILE"
    log DEBUG "State saved to $STATE_FILE"
}

# =============================================================================
# Main Functions
# =============================================================================

run_health_checks() {
    local servers_to_check=()

    if [[ -n "$SPECIFIC_SERVER" ]]; then
        if [[ -z "${MCP_SERVERS[$SPECIFIC_SERVER]:-}" ]]; then
            log ERROR "Unknown server: $SPECIFIC_SERVER"
            exit 3
        fi
        servers_to_check=("$SPECIFIC_SERVER")
    else
        servers_to_check=("${!MCP_SERVERS[@]}")
    fi

    log INFO "Starting MCP health checks for ${#servers_to_check[@]} server(s)..."

    for server in "${servers_to_check[@]}"; do
        perform_health_check "$server"

        # Auto-recovery if enabled and server is unhealthy
        if [[ "$AUTO_RECOVER" == "true" ]]; then
            if [[ "${HEALTH_STATUS[$server]}" == "ERROR" || "${HEALTH_STATUS[$server]}" == "CRITICAL" ]]; then
                attempt_recovery "$server"
            fi
        fi
    done

    log INFO "Health checks completed"
}

watch_loop() {
    log INFO "Starting watch mode with ${WATCH_INTERVAL}s interval"

    while true; do
        clear 2>/dev/null || true
        run_health_checks

        case "$OUTPUT_FORMAT" in
            text) generate_report_text ;;
            json) generate_report_json ;;
            prometheus) generate_report_prometheus ;;
        esac

        save_state

        echo ""
        echo "Next check in ${WATCH_INTERVAL}s... (Press Ctrl+C to stop)"
        sleep "$WATCH_INTERVAL"
    done
}

main() {
    local output_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--server)
                SPECIFIC_SERVER="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -a|--auto-recover)
                AUTO_RECOVER=true
                shift
                ;;
            -w|--watch)
                WATCH_MODE=true
                shift
                ;;
            -i|--interval)
                WATCH_INTERVAL="$2"
                shift 2
                ;;
            --list)
                list_servers
                ;;
            *)
                log ERROR "Unknown option: $1"
                echo "Use --help for usage information"
                exit 3
                ;;
        esac
    done

    # Initialize
    ensure_directories

    if ! check_dependencies; then
        exit 3
    fi

    if ! load_mcp_config; then
        exit 3
    fi

    # Run in watch mode or single check
    if [[ "$WATCH_MODE" == "true" ]]; then
        watch_loop
    else
        run_health_checks

        local output=""
        case "$OUTPUT_FORMAT" in
            text) output=$(generate_report_text) ;;
            json) output=$(generate_report_json) ;;
            prometheus) output=$(generate_report_prometheus) ;;
        esac

        if [[ -n "$output_file" ]]; then
            echo "$output" > "$output_file"
            echo "Report saved to: $output_file"
        else
            echo "$output"
        fi

        save_state
    fi

    # Determine exit code
    local overall
    overall=$(calculate_overall_status)

    case "$overall" in
        OK) exit 0 ;;
        WARNING) exit 1 ;;
        ERROR|CRITICAL) exit 2 ;;
        *) exit 3 ;;
    esac
}

# Run main
main "$@"
