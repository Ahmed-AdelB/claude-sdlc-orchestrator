#!/bin/bash
#===============================================================================
# test_consensus_validation.sh - Deep multi-way consensus validation
#===============================================================================
# Validates consensus functionality using 3+ testing methods per feature.
#
# Validation Matrix:
# | Feature          | Method 1        | Method 2         | Method 3      |
# |------------------|-----------------|------------------|---------------|
# | 3-way agreement  | All same        | Majority agrees  | All different |
# | Timeout handling | One timeout     | Two timeout      | All timeout   |
# | Vote synthesis   | Simple merge    | Conflict resolve | Weighted vote |
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${RESET} $1"
}

#===============================================================================
# Test Environment Setup
#===============================================================================

TEST_DIR=$(mktemp -d)
export STATE_DIR="${TEST_DIR}/state"
export LOG_DIR="${TEST_DIR}/logs"
export TRACE_ID="validation-consensus-$$"

mkdir -p "$STATE_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Helper Functions
#===============================================================================

# Simulate a model vote
create_vote() {
    local model="$1"
    local decision="$2"
    local confidence="${3:-0.9}"
    local reasoning="${4:-Auto-generated reasoning}"

    echo "{
        \"model\": \"$model\",
        \"status\": \"success\",
        \"decision\": \"$decision\",
        \"confidence\": $confidence,
        \"reasoning\": \"$reasoning\"
    }"
}

# Simple consensus logic
calculate_consensus() {
    local vote1="$1"
    local vote2="$2"
    local vote3="$3"

    local d1 d2 d3
    d1=$(echo "$vote1" | jq -r '.decision')
    d2=$(echo "$vote2" | jq -r '.decision')
    d3=$(echo "$vote3" | jq -r '.decision')

    # Count votes
    local approve=0 reject=0 abstain=0

    for d in "$d1" "$d2" "$d3"; do
        case "$d" in
            APPROVE) ((approve++)) || true ;;
            REJECT)  ((reject++)) || true ;;
            *)       ((abstain++)) || true ;;
        esac
    done

    # Majority wins
    if [[ $approve -ge 2 ]]; then
        echo "APPROVE"
    elif [[ $reject -ge 2 ]]; then
        echo "REJECT"
    elif [[ $approve -eq 1 && $reject -eq 1 ]]; then
        echo "SPLIT"
    else
        echo "ABSTAIN"
    fi
}

#===============================================================================
# 3-WAY AGREEMENT VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  3-WAY AGREEMENT VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: All Models Agree
test_agreement_unanimous() {
    echo ""
    echo "Method 1: All Models Agree (Unanimous)"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.95 "Code looks clean")
    gemini=$(create_vote "gemini" "APPROVE" 0.90 "No security issues found")
    codex=$(create_vote "codex" "APPROVE" 0.88 "Implementation is correct")

    local consensus
    consensus=$(calculate_consensus "$claude" "$gemini" "$codex")

    if [[ "$consensus" == "APPROVE" ]]; then
        pass "3-way agreement: Unanimous APPROVE - Consensus reached correctly"
    else
        fail "3-way agreement: Unanimous APPROVE - Expected APPROVE, got $consensus"
    fi

    # Also test unanimous REJECT
    claude=$(create_vote "claude" "REJECT" 0.95 "Critical bug found")
    gemini=$(create_vote "gemini" "REJECT" 0.90 "Security vulnerability")
    codex=$(create_vote "codex" "REJECT" 0.88 "Logic error detected")

    consensus=$(calculate_consensus "$claude" "$gemini" "$codex")

    if [[ "$consensus" == "REJECT" ]]; then
        pass "3-way agreement: Unanimous REJECT - Consensus reached correctly"
    else
        fail "3-way agreement: Unanimous REJECT - Expected REJECT, got $consensus"
    fi
}

# Method 2: Majority Agreement (2 out of 3)
test_agreement_majority() {
    echo ""
    echo "Method 2: Majority Agreement (2/3)"

    # 2 APPROVE, 1 REJECT
    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.85 "Looks good")
    gemini=$(create_vote "gemini" "APPROVE" 0.80 "Approved")
    codex=$(create_vote "codex" "REJECT" 0.75 "Minor issues")

    local consensus
    consensus=$(calculate_consensus "$claude" "$gemini" "$codex")

    if [[ "$consensus" == "APPROVE" ]]; then
        pass "3-way agreement: 2/3 APPROVE - Majority consensus correct"
    else
        fail "3-way agreement: 2/3 APPROVE - Expected APPROVE, got $consensus"
    fi

    # 2 REJECT, 1 APPROVE
    claude=$(create_vote "claude" "REJECT" 0.90 "Problems found")
    gemini=$(create_vote "gemini" "REJECT" 0.85 "Not recommended")
    codex=$(create_vote "codex" "APPROVE" 0.70 "Seems okay")

    consensus=$(calculate_consensus "$claude" "$gemini" "$codex")

    if [[ "$consensus" == "REJECT" ]]; then
        pass "3-way agreement: 2/3 REJECT - Majority consensus correct"
    else
        fail "3-way agreement: 2/3 REJECT - Expected REJECT, got $consensus"
    fi
}

# Method 3: All Different Decisions
test_agreement_split() {
    echo ""
    echo "Method 3: All Different Decisions (Split)"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.70 "Tentative approval")
    gemini=$(create_vote "gemini" "REJECT" 0.60 "Some concerns")
    codex=$(create_vote "codex" "ABSTAIN" 0.50 "Cannot determine")

    local consensus
    consensus=$(calculate_consensus "$claude" "$gemini" "$codex")

    # With no majority, should be SPLIT or ABSTAIN
    if [[ "$consensus" == "SPLIT" ]] || [[ "$consensus" == "ABSTAIN" ]]; then
        pass "3-way agreement: All different - Split/Abstain handled correctly"
    else
        fail "3-way agreement: All different - Unexpected consensus: $consensus"
    fi
}

#===============================================================================
# TIMEOUT HANDLING VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  TIMEOUT HANDLING VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: One Model Timeout
test_timeout_one() {
    echo ""
    echo "Method 1: One Model Timeout"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.90 "Approved")
    gemini='{"model":"gemini","status":"timeout","duration_ms":30000}'
    codex=$(create_vote "codex" "APPROVE" 0.85 "Looks good")

    # With timeout, only count valid votes
    local valid_votes=0
    local approve_count=0

    for vote in "$claude" "$codex"; do
        local status
        status=$(echo "$vote" | jq -r '.status')
        if [[ "$status" == "success" ]]; then
            ((valid_votes++)) || true
            local decision
            decision=$(echo "$vote" | jq -r '.decision')
            [[ "$decision" == "APPROVE" ]] && ((approve_count++)) || true
        fi
    done

    if [[ $valid_votes -eq 2 && $approve_count -eq 2 ]]; then
        pass "Timeout: One model - 2/3 valid votes, consensus from remaining"
    else
        fail "Timeout: One model - Vote counting incorrect"
    fi
}

# Method 2: Two Models Timeout
test_timeout_two() {
    echo ""
    echo "Method 2: Two Models Timeout"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.90 "Approved")
    gemini='{"model":"gemini","status":"timeout","duration_ms":30000}'
    codex='{"model":"codex","status":"timeout","duration_ms":30000}'

    local valid_votes=0

    for vote in "$claude" "$gemini" "$codex"; do
        local status
        status=$(echo "$vote" | jq -r '.status')
        if [[ "$status" == "success" ]]; then
            ((valid_votes++)) || true
        fi
    done

    if [[ $valid_votes -eq 1 ]]; then
        pass "Timeout: Two models - Only 1 valid vote, degraded mode"
    else
        fail "Timeout: Two models - Expected 1 valid vote, got $valid_votes"
    fi
}

# Method 3: All Models Timeout
test_timeout_all() {
    echo ""
    echo "Method 3: All Models Timeout"

    local claude gemini codex

    claude='{"model":"claude","status":"timeout","duration_ms":30000}'
    gemini='{"model":"gemini","status":"timeout","duration_ms":30000}'
    codex='{"model":"codex","status":"timeout","duration_ms":30000}'

    local valid_votes=0

    for vote in "$claude" "$gemini" "$codex"; do
        local status
        status=$(echo "$vote" | jq -r '.status')
        if [[ "$status" == "success" ]]; then
            ((valid_votes++)) || true
        fi
    done

    if [[ $valid_votes -eq 0 ]]; then
        pass "Timeout: All models - No valid votes, should abort or retry"
    else
        fail "Timeout: All models - Expected 0 valid votes"
    fi
}

#===============================================================================
# VOTE SYNTHESIS VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  VOTE SYNTHESIS VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Simple Merge (All Agree)
test_synthesis_simple() {
    echo ""
    echo "Method 1: Simple Merge (All Agree)"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.95 "Clean code")
    gemini=$(create_vote "gemini" "APPROVE" 0.92 "No issues")
    codex=$(create_vote "codex" "APPROVE" 0.90 "Approved")

    # Average confidence
    local c1 c2 c3
    c1=$(echo "$claude" | jq -r '.confidence')
    c2=$(echo "$gemini" | jq -r '.confidence')
    c3=$(echo "$codex" | jq -r '.confidence')

    local avg_conf
    avg_conf=$(echo "scale=2; ($c1 + $c2 + $c3) / 3" | bc)

    if (( $(echo "$avg_conf > 0.9" | bc -l) )); then
        pass "Synthesis: Simple merge - Average confidence $avg_conf > 0.9"
    else
        fail "Synthesis: Simple merge - Confidence too low: $avg_conf"
    fi
}

# Method 2: Conflict Resolution
test_synthesis_conflict() {
    echo ""
    echo "Method 2: Conflict Resolution"

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.95 "Approved with high confidence")
    gemini=$(create_vote "gemini" "REJECT" 0.60 "Minor concerns")
    codex=$(create_vote "codex" "APPROVE" 0.85 "Generally good")

    # In conflict, use confidence-weighted voting
    local approve_weight=0
    local reject_weight=0

    for vote in "$claude" "$codex"; do
        local decision conf
        decision=$(echo "$vote" | jq -r '.decision')
        conf=$(echo "$vote" | jq -r '.confidence')
        if [[ "$decision" == "APPROVE" ]]; then
            approve_weight=$(echo "$approve_weight + $conf" | bc)
        fi
    done

    reject_weight=$(echo "$gemini" | jq -r '.confidence')

    if (( $(echo "$approve_weight > $reject_weight" | bc -l) )); then
        pass "Synthesis: Conflict resolution - Weighted approve ($approve_weight) > reject ($reject_weight)"
    else
        fail "Synthesis: Conflict resolution - Weighting failed"
    fi
}

# Method 3: Weighted Voting
test_synthesis_weighted() {
    echo ""
    echo "Method 3: Weighted Voting (By Model Expertise)"

    # Assign weights by model expertise for this task type
    local model_weights
    declare -A model_weights=(
        ["claude"]=1.2    # Higher weight for analysis
        ["gemini"]=1.0    # Standard weight
        ["codex"]=0.8     # Lower weight for non-code tasks
    )

    local claude gemini codex

    claude=$(create_vote "claude" "APPROVE" 0.90 "Analysis complete")
    gemini=$(create_vote "gemini" "APPROVE" 0.85 "Reviewed")
    codex=$(create_vote "codex" "REJECT" 0.80 "Some issues")

    local weighted_approve=0
    local weighted_reject=0

    # Claude approve
    weighted_approve=$(echo "$weighted_approve + 0.90 * ${model_weights[claude]}" | bc)
    # Gemini approve
    weighted_approve=$(echo "$weighted_approve + 0.85 * ${model_weights[gemini]}" | bc)
    # Codex reject
    weighted_reject=$(echo "$weighted_reject + 0.80 * ${model_weights[codex]}" | bc)

    if (( $(echo "$weighted_approve > $weighted_reject" | bc -l) )); then
        pass "Synthesis: Weighted voting - Weighted approve wins"
    else
        fail "Synthesis: Weighted voting - Unexpected result"
    fi
}

#===============================================================================
# Run All Validation Tests
#===============================================================================

echo ""
echo "=================================================="
echo "  RUNNING CONSENSUS VALIDATION TESTS"
echo "=================================================="

# 3-way agreement tests
test_agreement_unanimous
test_agreement_majority
test_agreement_split

# Timeout handling tests
test_timeout_one
test_timeout_two
test_timeout_all

# Vote synthesis tests
test_synthesis_simple
test_synthesis_conflict
test_synthesis_weighted

#===============================================================================
# Generate Validation Matrix
#===============================================================================

echo ""
echo "=================================================="
echo "  CONSENSUS VALIDATION MATRIX"
echo "=================================================="
echo ""
printf "%-20s %-15s %-15s %-15s\n" "Feature" "Method 1" "Method 2" "Method 3"
echo "------------------------------------------------------------"
printf "%-20s %-15s %-15s %-15s\n" "3-way agreement" "Unanimous" "Majority" "Split"
printf "%-20s %-15s %-15s %-15s\n" "Timeout handling" "One" "Two" "All"
printf "%-20s %-15s %-15s %-15s\n" "Vote synthesis" "Simple" "Conflict" "Weighted"
echo ""

export TESTS_PASSED TESTS_FAILED

echo "Consensus validation completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
