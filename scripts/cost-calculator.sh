#!/bin/bash
#
# Token Cost Calculator for Tri-Agent System
# Estimates costs for Claude, Codex, and Gemini models
#
# Usage: tri-agent cost-estimate "task description"
#        ./cost-calculator.sh "task description"
#
# Author: Ahmed Adel Bakr Alderai
# Version: 1.2.0
#

set -uo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Pricing per 1M tokens (as of Jan 2026)
# Format: "name|input_price|output_price|context_limit"

CLAUDE_OPUS="Claude Opus 4|15.00|75.00|200000"
CLAUDE_SONNET="Claude Sonnet 4|3.00|15.00|200000"
CODEX_GPT52="GPT-5.2-Codex|10.00|30.00|400000"
CODEX_O3="o3 (Reasoning)|15.00|60.00|200000"
GEMINI_3_PRO="Gemini 3 Pro|0.50|1.50|1000000"
GEMINI_25_PRO="Gemini 2.5 Pro|0.35|1.05|1000000"

ALL_MODELS="CLAUDE_OPUS CLAUDE_SONNET CODEX_GPT52 CODEX_O3 GEMINI_3_PRO GEMINI_25_PRO"

# Complexity keywords and multipliers
# High complexity (3x)
HIGH_KEYWORDS="architecture security refactor migration distributed microservices authentication authorization cryptography optimization"
# Medium complexity (2x)
MEDIUM_KEYWORDS="implement feature integration api database testing debug performance frontend backend"
# Standard complexity (1.5x)
STANDARD_KEYWORDS="fix update modify add change config"
# Low complexity (1x)
LOW_KEYWORDS="review analyze document explain format"

# Base token estimates
BASE_INPUT_TOKENS=5000
BASE_OUTPUT_TOKENS=2000
CONTEXT_FACTOR="1.5"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# AWK-based floating point operations
calc() {
    awk "BEGIN { printf \"%.6f\", $1 }"
}

calc_int() {
    awk "BEGIN { printf \"%.0f\", $1 }"
}

compare_gt() {
    awk "BEGIN { exit !($1 > $2) }"
}

compare_gte() {
    awk "BEGIN { exit !($1 >= $2) }"
}

# Get model field by index
get_model_field() {
    local model_data="$1"
    local field="$2"
    echo "$model_data" | cut -d'|' -f"$field"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${BOLD}${CYAN}"
    echo "=============================================================================="
    echo "                    TRI-AGENT TOKEN COST CALCULATOR"
    echo "=============================================================================="
    echo -e "${NC}"
}

print_usage() {
    cat << 'EOF'
Usage: cost-calculator.sh "task description"

Options:
  -h, --help       Show this help message
  -v, --verbose    Show detailed breakdown
  -j, --json       Output in JSON format
  -m, --model      Estimate for specific model only

Examples:
  ./cost-calculator.sh "implement OAuth2 authentication with PKCE"
  ./cost-calculator.sh --verbose "refactor database layer for better performance"
  ./cost-calculator.sh --model opus "security audit of payment module"

Supported models: opus, sonnet, codex, o3, gemini3, gemini25
EOF
}

# Calculate complexity multiplier from task description
# Returns: "multiplier|keyword1 keyword2 ..."
calculate_complexity() {
    local task="$1"
    local task_lower
    task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')
    local max_multiplier=1
    local found_list=""

    # Check high complexity keywords (3x)
    for keyword in $HIGH_KEYWORDS; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            found_list="${found_list}${keyword}(3) "
            if compare_gt 3 "$max_multiplier"; then
                max_multiplier=3
            fi
        fi
    done

    # Check medium complexity keywords (2x)
    for keyword in $MEDIUM_KEYWORDS; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            found_list="${found_list}${keyword}(2) "
            if compare_gt 2 "$max_multiplier"; then
                max_multiplier=2
            fi
        fi
    done

    # Check standard complexity keywords (1.5x)
    for keyword in $STANDARD_KEYWORDS; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            found_list="${found_list}${keyword}(1.5) "
            if compare_gt 1.5 "$max_multiplier"; then
                max_multiplier="1.5"
            fi
        fi
    done

    # Check low complexity keywords (1x)
    for keyword in $LOW_KEYWORDS; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            found_list="${found_list}${keyword}(1) "
        fi
    done

    # Trim trailing space and set default if empty
    found_list="${found_list% }"
    if [[ -z "$found_list" ]]; then
        found_list="none"
    fi

    # Return both multiplier and keywords separated by |
    echo "${max_multiplier}|${found_list}"
}

# Estimate tokens based on task description
estimate_tokens() {
    local complexity="$1"

    # Calculate estimated tokens
    local input_tokens
    local output_tokens
    input_tokens=$(calc_int "$BASE_INPUT_TOKENS * $complexity * $CONTEXT_FACTOR")
    output_tokens=$(calc_int "$BASE_OUTPUT_TOKENS * $complexity")

    echo "$input_tokens $output_tokens"
}

# Calculate cost for a specific model
calculate_model_cost() {
    local input_tokens="$1"
    local output_tokens="$2"
    local input_price="$3"
    local output_price="$4"

    # Cost = (tokens / 1,000,000) * price_per_million
    local input_cost
    local output_cost
    local total_cost

    input_cost=$(calc "$input_tokens / 1000000 * $input_price")
    output_cost=$(calc "$output_tokens / 1000000 * $output_price")
    total_cost=$(calc "$input_cost + $output_cost")

    echo "$input_cost $output_cost $total_cost"
}

# Format currency
format_currency() {
    local value="${1:-0}"
    # Handle empty or invalid input
    if [[ -z "$value" ]] || [[ "$value" == "0" ]]; then
        printf "\$0.0000"
    else
        printf "\$%.4f" "$value"
    fi
}

# Print cost table
print_cost_table() {
    local input_tokens="$1"
    local output_tokens="$2"

    echo -e "${BOLD}${BLUE}Cost Comparison Table${NC}"
    echo "------------------------------------------------------------------------------"
    printf "%-20s %12s %12s %12s %12s\n" "Model" "Input Cost" "Output Cost" "Total Cost" "Context"
    echo "------------------------------------------------------------------------------"

    for model_var in $ALL_MODELS; do
        local model_data="${!model_var}"
        local name
        local input_price
        local output_price
        local context

        name=$(get_model_field "$model_data" 1)
        input_price=$(get_model_field "$model_data" 2)
        output_price=$(get_model_field "$model_data" 3)
        context=$(get_model_field "$model_data" 4)

        local costs
        costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$input_price" "$output_price")
        local input_cost
        local output_cost
        local total_cost

        input_cost=$(echo "$costs" | cut -d' ' -f1)
        output_cost=$(echo "$costs" | cut -d' ' -f2)
        total_cost=$(echo "$costs" | cut -d' ' -f3)

        # Color code by cost tier
        local color=$NC
        if compare_gt 0.10 "$total_cost"; then
            color=$GREEN
        elif compare_gt 0.50 "$total_cost"; then
            color=$YELLOW
        else
            color=$RED
        fi

        local context_k=$((context / 1000))

        printf "${color}%-20s %12s %12s %12s %10sK${NC}\n" \
            "$name" \
            "$(format_currency "$input_cost")" \
            "$(format_currency "$output_cost")" \
            "$(format_currency "$total_cost")" \
            "$context_k"
    done

    echo "------------------------------------------------------------------------------"
}

# Determine optimal model recommendation
get_recommendation() {
    local task="$1"
    local complexity="$2"
    local input_tokens="$3"
    local task_lower
    task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')

    local recommended=""
    local reason=""
    local alternative=""
    local alt_reason=""

    # Check for specific task patterns
    if [[ "$task_lower" == *"security"* ]] || [[ "$task_lower" == *"auth"* ]] || [[ "$task_lower" == *"cryptograph"* ]]; then
        recommended="Claude Opus 4"
        reason="Security-sensitive tasks require deepest analysis"
        alternative="GPT-5.2-Codex"
        alt_reason="Strong security analysis with verification"
    elif [[ "$task_lower" == *"architecture"* ]] || [[ "$task_lower" == *"design"* ]] || [[ "$task_lower" == *"refactor"* ]]; then
        recommended="Claude Opus 4"
        reason="Complex architectural decisions benefit from extended thinking"
        alternative="Gemini 3 Pro"
        alt_reason="1M context for full codebase analysis"
    elif [[ "$task_lower" == *"analyze"* ]] || [[ "$task_lower" == *"review"* ]] || [[ "$task_lower" == *"codebase"* ]]; then
        recommended="Gemini 3 Pro"
        reason="1M token context ideal for large codebase analysis"
        alternative="Claude Sonnet 4"
        alt_reason="Cost-effective for smaller codebases"
    elif [[ "$task_lower" == *"implement"* ]] || [[ "$task_lower" == *"feature"* ]] || [[ "$task_lower" == *"api"* ]]; then
        recommended="GPT-5.2-Codex"
        reason="Fast implementation with xhigh reasoning"
        alternative="Claude Sonnet 4"
        alt_reason="Balanced quality and cost"
    elif [[ "$task_lower" == *"document"* ]] || [[ "$task_lower" == *"docs"* ]] || [[ "$task_lower" == *"readme"* ]]; then
        recommended="Gemini 3 Pro"
        reason="Cost-effective for documentation tasks"
        alternative="Claude Sonnet 4"
        alt_reason="Higher quality prose"
    elif [[ "$task_lower" == *"debug"* ]] || [[ "$task_lower" == *"fix"* ]] || [[ "$task_lower" == *"bug"* ]]; then
        recommended="GPT-5.2-Codex"
        reason="Strong debugging capabilities with reasoning"
        alternative="Claude Sonnet 4"
        alt_reason="Good at root cause analysis"
    elif [[ "$task_lower" == *"test"* ]]; then
        recommended="GPT-5.2-Codex"
        reason="Efficient test generation"
        alternative="Gemini 3 Pro"
        alt_reason="Can analyze existing test patterns with large context"
    else
        # Default based on complexity
        if compare_gte "$complexity" 3; then
            recommended="Claude Opus 4"
            reason="High complexity tasks benefit from extended thinking"
            alternative="GPT-5.2-Codex"
            alt_reason="Strong alternative with xhigh reasoning"
        elif compare_gte "$complexity" 2; then
            recommended="Claude Sonnet 4"
            reason="Best quality/cost balance for medium complexity"
            alternative="GPT-5.2-Codex"
            alt_reason="Faster iteration"
        else
            recommended="Gemini 3 Pro"
            reason="Most cost-effective for simple tasks"
            alternative="Claude Sonnet 4"
            alt_reason="Higher quality if needed"
        fi
    fi

    # Check if context requirements exceed model limits
    if [[ "$input_tokens" -gt 200000 ]]; then
        if [[ "$recommended" != "Gemini"* ]] && [[ "$recommended" != "GPT-5.2"* ]]; then
            echo -e "${YELLOW}Warning: Task may exceed Claude context limit. Consider Gemini (1M) or Codex (400K).${NC}"
        fi
    fi

    echo ""
    echo -e "${BOLD}${GREEN}RECOMMENDATION${NC}"
    echo "------------------------------------------------------------------------------"
    echo -e "Primary:     ${BOLD}$recommended${NC}"
    echo -e "Reason:      $reason"
    echo ""
    echo -e "Alternative: ${BOLD}$alternative${NC}"
    echo -e "Reason:      $alt_reason"
    echo "------------------------------------------------------------------------------"
}

# Print tri-agent cost estimate
print_triagent_estimate() {
    local input_tokens="$1"
    local output_tokens="$2"

    echo ""
    echo -e "${BOLD}${CYAN}TRI-AGENT WORKFLOW ESTIMATE${NC}"
    echo "------------------------------------------------------------------------------"
    echo "Standard tri-agent workflow uses 27 agent invocations across 3 phases:"
    echo "  - Planning:       9 agents (3 Claude + 3 Codex + 3 Gemini)"
    echo "  - Implementation: 9 agents (3 Claude + 3 Codex + 3 Gemini)"
    echo "  - Verification:   9 agents (3 Claude + 3 Codex + 3 Gemini)"
    echo ""

    # Calculate per-model costs
    local opus_input
    local opus_output
    local sonnet_input
    local sonnet_output
    local codex_input
    local codex_output
    local gemini_input
    local gemini_output

    opus_input=$(get_model_field "$CLAUDE_OPUS" 2)
    opus_output=$(get_model_field "$CLAUDE_OPUS" 3)
    sonnet_input=$(get_model_field "$CLAUDE_SONNET" 2)
    sonnet_output=$(get_model_field "$CLAUDE_SONNET" 3)
    codex_input=$(get_model_field "$CODEX_GPT52" 2)
    codex_output=$(get_model_field "$CODEX_GPT52" 3)
    gemini_input=$(get_model_field "$GEMINI_3_PRO" 2)
    gemini_output=$(get_model_field "$GEMINI_3_PRO" 3)

    local opus_costs
    local sonnet_costs
    local codex_costs
    local gemini_costs

    opus_costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$opus_input" "$opus_output")
    sonnet_costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$sonnet_input" "$sonnet_output")
    codex_costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$codex_input" "$codex_output")
    gemini_costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$gemini_input" "$gemini_output")

    local opus_total
    local sonnet_total
    local codex_total
    local gemini_total

    opus_total=$(echo "$opus_costs" | cut -d' ' -f3)
    sonnet_total=$(echo "$sonnet_costs" | cut -d' ' -f3)
    codex_total=$(echo "$codex_costs" | cut -d' ' -f3)
    gemini_total=$(echo "$gemini_costs" | cut -d' ' -f3)

    # Typical distribution: 1 Opus (security), 2 Sonnet, 3 Codex, 3 Gemini per phase
    # 3 phases = 3 Opus, 6 Sonnet, 9 Codex, 9 Gemini
    local claude_cost
    local codex_cost
    local gemini_cost
    local total_cost

    claude_cost=$(calc "($opus_total * 3) + ($sonnet_total * 6)")
    codex_cost=$(calc "$codex_total * 9")
    gemini_cost=$(calc "$gemini_total * 9")
    total_cost=$(calc "$claude_cost + $codex_cost + $gemini_cost")

    printf "%-30s %15s\n" "Claude (3 Opus + 6 Sonnet):" "$(format_currency "$claude_cost")"
    printf "%-30s %15s\n" "Codex (9 GPT-5.2):" "$(format_currency "$codex_cost")"
    printf "%-30s %15s\n" "Gemini (9 Gemini 3 Pro):" "$(format_currency "$gemini_cost")"
    echo "------------------------------------------------------------------------------"
    printf "${BOLD}%-30s %15s${NC}\n" "TOTAL TRI-AGENT COST:" "$(format_currency "$total_cost")"
    echo "------------------------------------------------------------------------------"
}

# Output in JSON format
output_json() {
    local task="$1"
    local complexity="$2"
    local input_tokens="$3"
    local output_tokens="$4"

    local escaped_task
    escaped_task=$(echo "$task" | sed 's/"/\\"/g')

    cat << EOF
{
  "task": "$escaped_task",
  "complexity": $complexity,
  "estimated_tokens": {
    "input": $input_tokens,
    "output": $output_tokens,
    "total": $((input_tokens + output_tokens))
  },
  "models": {
EOF

    local first=true
    for model_var in $ALL_MODELS; do
        local model_data="${!model_var}"
        local name
        local input_price
        local output_price
        local context

        name=$(get_model_field "$model_data" 1)
        input_price=$(get_model_field "$model_data" 2)
        output_price=$(get_model_field "$model_data" 3)
        context=$(get_model_field "$model_data" 4)

        local costs
        costs=$(calculate_model_cost "$input_tokens" "$output_tokens" "$input_price" "$output_price")
        local input_cost
        local output_cost
        local total_cost

        input_cost=$(echo "$costs" | cut -d' ' -f1)
        output_cost=$(echo "$costs" | cut -d' ' -f2)
        total_cost=$(echo "$costs" | cut -d' ' -f3)

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        echo -n "    \"$name\": {"
        echo -n "\"input_cost\": $input_cost, "
        echo -n "\"output_cost\": $output_cost, "
        echo -n "\"total_cost\": $total_cost, "
        echo -n "\"context_limit\": $context"
        echo -n "}"
    done

    cat << EOF

  },
  "timestamp": "$(date -Iseconds)"
}
EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local verbose=false
    local json_output=false
    local specific_model=""
    local task=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -j|--json)
                json_output=true
                shift
                ;;
            -m|--model)
                specific_model="$2"
                shift 2
                ;;
            *)
                task="$1"
                shift
                ;;
        esac
    done

    # Validate input
    if [[ -z "$task" ]]; then
        echo -e "${RED}Error: Task description required${NC}"
        echo ""
        print_usage
        exit 1
    fi

    # Calculate complexity and keywords
    local complexity_result
    complexity_result=$(calculate_complexity "$task")

    local complexity
    local found_keywords
    complexity=$(echo "$complexity_result" | cut -d'|' -f1)
    found_keywords=$(echo "$complexity_result" | cut -d'|' -f2)

    local tokens
    tokens=$(estimate_tokens "$complexity")

    local input_tokens
    local output_tokens
    input_tokens=$(echo "$tokens" | cut -d' ' -f1)
    output_tokens=$(echo "$tokens" | cut -d' ' -f2)

    # JSON output mode
    if [ "$json_output" = true ]; then
        output_json "$task" "$complexity" "$input_tokens" "$output_tokens"
        exit 0
    fi

    # Standard output
    print_header

    echo -e "${BOLD}Task:${NC} $task"
    echo ""

    echo -e "${BOLD}${BLUE}Token Estimation${NC}"
    echo "------------------------------------------------------------------------------"
    printf "%-30s %10s\n" "Complexity Multiplier:" "${complexity}x"
    if [ "$verbose" = true ]; then
        printf "%-30s %s\n" "Keywords Found:" "$found_keywords"
    fi
    printf "%-30s %10s\n" "Estimated Input Tokens:" "$input_tokens"
    printf "%-30s %10s\n" "Estimated Output Tokens:" "$output_tokens"
    printf "%-30s %10s\n" "Total Tokens:" "$((input_tokens + output_tokens))"
    echo "------------------------------------------------------------------------------"
    echo ""

    # Print cost table
    print_cost_table "$input_tokens" "$output_tokens"

    # Print recommendation
    get_recommendation "$task" "$complexity" "$input_tokens"

    # Print tri-agent estimate
    print_triagent_estimate "$input_tokens" "$output_tokens"

    # Verbose output
    if [ "$verbose" = true ]; then
        echo ""
        echo -e "${BOLD}${YELLOW}Verbose Details${NC}"
        echo "------------------------------------------------------------------------------"
        echo "Base input tokens:    $BASE_INPUT_TOKENS"
        echo "Base output tokens:   $BASE_OUTPUT_TOKENS"
        echo "Context factor:       $CONTEXT_FACTOR"
        echo "Task word count:      $(echo "$task" | wc -w)"
        echo "Detected keywords:    $found_keywords"
        echo "------------------------------------------------------------------------------"
    fi

    echo ""
    echo -e "${CYAN}Note: Estimates are approximate. Actual costs vary based on context size and response length.${NC}"
}

# Run main function
main "$@"
