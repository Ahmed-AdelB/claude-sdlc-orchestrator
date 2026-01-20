#!/bin/bash
#
# Context Compressor - Reduce large context while preserving critical information
#
# Usage:
#   context-compressor.sh <input-file> [target-tokens] [options]
#   cat large-file.txt | context-compressor.sh - [target-tokens]
#
# Options:
#   --dry-run       Estimate compression without executing
#   --strategy=X    Force strategy: summarize|window|semantic|auto (default: auto)
#   --preserve=X    Comma-separated preservation priorities
#   --output=X      Output file (default: stdout)
#   --verbose       Show progress and statistics
#
# Environment:
#   STRATEGY        Override strategy detection
#   GEMINI_MODEL    Gemini model to use (default: gemini-3-pro-preview)
#   GEMINI_TIMEOUT  Timeout in seconds (default: 300)
#
# Examples:
#   context-compressor.sh session.txt 50000
#   context-compressor.sh codebase.txt 80000 --strategy=semantic
#   cat logs.txt | context-compressor.sh - 30000 --preserve=errors,timestamps
#
# Author: Ahmed Adel Bakr Alderai
# Version: 1.0.0

set -euo pipefail

# Configuration
GEMINI_MODEL="${GEMINI_MODEL:-gemini-3-pro-preview}"
GEMINI_TIMEOUT="${GEMINI_TIMEOUT:-300}"
CHARS_PER_TOKEN=4  # Approximate conversion factor

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }

# Parse arguments
INPUT_FILE=""
TARGET_TOKENS=50000
DRY_RUN=false
STRATEGY="${STRATEGY:-auto}"
PRESERVE="decisions,code,constraints,errors"
OUTPUT_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --strategy=*)
            STRATEGY="${1#*=}"
            shift
            ;;
        --preserve=*)
            PRESERVE="${1#*=}"
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            head -40 "$0" | tail -35
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ "$TARGET_TOKENS" == "50000" ]]; then
                TARGET_TOKENS="$1"
            fi
            shift
            ;;
    esac
done

# Validate input
if [[ -z "$INPUT_FILE" ]]; then
    log_error "No input file specified"
    echo "Usage: context-compressor.sh <input-file> [target-tokens]" >&2
    exit 1
fi

# Read input (file or stdin)
read_input() {
    if [[ "$INPUT_FILE" == "-" ]]; then
        cat
    else
        if [[ ! -f "$INPUT_FILE" ]]; then
            log_error "File not found: $INPUT_FILE"
            exit 1
        fi
        cat "$INPUT_FILE"
    fi
}

# Estimate token count (approximate)
estimate_tokens() {
    local chars=$1
    echo $((chars / CHARS_PER_TOKEN))
}

# Detect content type and best strategy
detect_strategy() {
    local content="$1"
    local first_500
    first_500=$(echo "$content" | head -c 2000)

    # Check for code patterns
    if echo "$first_500" | grep -qE '(function|class|import|export|def |async |const |let |var )'; then
        echo "semantic"
        return
    fi

    # Check for JSON/structured data
    if echo "$first_500" | grep -qE '^\s*[\[{]'; then
        echo "summarize"
        return
    fi

    # Check for log patterns
    if echo "$first_500" | grep -qE '^\[?[0-9]{4}-[0-9]{2}-[0-9]{2}|^\[?(INFO|WARN|ERROR|DEBUG)\]?'; then
        echo "window"
        return
    fi

    # Check for conversation/chat patterns
    if echo "$first_500" | grep -qE '^(User:|Assistant:|Human:|AI:|Claude:|>)'; then
        echo "summarize"
        return
    fi

    # Default to summarization
    echo "summarize"
}

# Strategy: Summarization
compress_summarize() {
    local content="$1"
    local target_chars=$((TARGET_TOKENS * CHARS_PER_TOKEN))

    $VERBOSE && log_info "Using summarization strategy"

    gemini -m "$GEMINI_MODEL" --approval-mode yolo "
You are a context compression specialist. Compress the following content to approximately $TARGET_TOKENS tokens.

PRESERVATION PRIORITIES (in order):
$(echo "$PRESERVE" | tr ',' '\n' | sed 's/^/- /')

COMPRESSION RULES:
1. PRESERVE VERBATIM:
   - All decisions and their final outcomes
   - Security constraints and requirements
   - Critical code interfaces (function signatures, types)
   - Active errors and blockers
   - Numerical data and metrics

2. SUMMARIZE (reduce but keep meaning):
   - Reasoning chains (keep conclusion, summarize path)
   - Implementation details (keep pattern, omit repetition)
   - Discussion threads (keep resolution, omit back-and-forth)

3. OMIT ENTIRELY:
   - Draft alternatives that were rejected
   - Resolved issues (unless pattern is relevant)
   - Redundant explanations
   - Verbose formatting

OUTPUT FORMAT:
- Use structured sections with clear headers
- Preserve code blocks with language tags
- Use bullet points for lists
- Include [COMPRESSED] markers where significant content was reduced

---
CONTENT TO COMPRESS:

$content
"
}

# Strategy: Sliding Window
compress_window() {
    local content="$1"
    local window_size=50000  # characters
    local overlap=10000
    local total_size=${#content}
    local offset=0
    local window_num=1
    local accumulated=""

    $VERBOSE && log_info "Using sliding window strategy (window: ${window_size}c, overlap: ${overlap}c)"

    while [[ $offset -lt $total_size ]]; do
        local window="${content:$offset:$window_size}"

        $VERBOSE && log_info "Processing window $window_num (offset: $offset)"

        local window_summary
        window_summary=$(gemini -m "$GEMINI_MODEL" --approval-mode yolo "
You are analyzing window $window_num of a large document.

PREVIOUS WINDOWS SUMMARY:
$accumulated

CURRENT WINDOW CONTENT:
$window

TASK:
1. Extract key information from this window
2. Note any dependencies on previous/next sections
3. Preserve: errors, decisions, critical data
4. Summarize implementation details

OUTPUT: Concise summary of this window (max 2000 tokens)
" 2>/dev/null || echo "[Window $window_num: Processing failed]")

        accumulated="$accumulated
=== Window $window_num ===
$window_summary"

        offset=$((offset + window_size - overlap))
        window_num=$((window_num + 1))
    done

    # Final consolidation
    $VERBOSE && log_info "Consolidating $((window_num - 1)) windows"

    gemini -m "$GEMINI_MODEL" --approval-mode yolo "
Consolidate these window summaries into a coherent compressed context.
Target size: $TARGET_TOKENS tokens.

Preserve all:
$(echo "$PRESERVE" | tr ',' '\n' | sed 's/^/- /')

WINDOW SUMMARIES:
$accumulated

OUTPUT: Single coherent document preserving critical information.
"
}

# Strategy: Semantic (for code)
compress_semantic() {
    local content="$1"

    $VERBOSE && log_info "Using semantic compression strategy for code"

    gemini -m "$GEMINI_MODEL" --approval-mode yolo "
You are compressing a codebase context. Target: $TARGET_TOKENS tokens.

EXTRACT VERBATIM:
1. All exported function/class signatures with JSDoc/docstrings
2. Type definitions and interfaces
3. Security-critical code blocks (auth, crypto, validation)
4. Configuration schemas
5. Error handling patterns

SUMMARIZE:
1. Implementation details (note pattern, omit repetition)
2. Test files (list what is tested, omit assertions)
3. Utility functions (signature + one-line purpose)

ORGANIZE OUTPUT:
\`\`\`
# Architecture Overview
[Brief description]

# Key Interfaces
[Exported types and functions with signatures]

# Security-Critical Code
[Verbatim security-relevant blocks]

# Implementation Patterns
[Summarized patterns]

# Dependencies
[Key imports and their purpose]
\`\`\`

---
CODEBASE CONTENT:

$content
"
}

# Main compression function
compress_context() {
    local content="$1"
    local input_chars=${#content}
    local input_tokens
    input_tokens=$(estimate_tokens "$input_chars")

    # Check if compression is needed
    if [[ $input_tokens -le $TARGET_TOKENS ]]; then
        log_info "Input ($input_tokens tokens) already within target ($TARGET_TOKENS tokens)"
        echo "$content"
        return 0
    fi

    local compression_ratio
    compression_ratio=$(echo "scale=1; $input_tokens / $TARGET_TOKENS" | bc)
    $VERBOSE && log_info "Compression ratio needed: ${compression_ratio}:1"

    # Detect or use forced strategy
    local selected_strategy
    if [[ "$STRATEGY" == "auto" ]]; then
        selected_strategy=$(detect_strategy "$content")
        $VERBOSE && log_info "Auto-detected strategy: $selected_strategy"
    else
        selected_strategy="$STRATEGY"
        $VERBOSE && log_info "Using forced strategy: $selected_strategy"
    fi

    # Execute compression
    case "$selected_strategy" in
        summarize)
            compress_summarize "$content"
            ;;
        window)
            compress_window "$content"
            ;;
        semantic)
            compress_semantic "$content"
            ;;
        *)
            log_error "Unknown strategy: $selected_strategy"
            exit 1
            ;;
    esac
}

# Dry run mode - estimate only
dry_run() {
    local content="$1"
    local input_chars=${#content}
    local input_tokens
    input_tokens=$(estimate_tokens "$input_chars")

    local strategy
    if [[ "$STRATEGY" == "auto" ]]; then
        strategy=$(detect_strategy "$content")
    else
        strategy="$STRATEGY"
    fi

    echo "=== Context Compression Estimate ==="
    echo ""
    echo "Input:"
    echo "  File: $INPUT_FILE"
    echo "  Size: $input_chars characters"
    echo "  Estimated tokens: $input_tokens"
    echo ""
    echo "Target:"
    echo "  Tokens: $TARGET_TOKENS"
    echo "  Characters: $((TARGET_TOKENS * CHARS_PER_TOKEN))"
    echo ""
    echo "Compression:"
    echo "  Strategy: $strategy"
    echo "  Ratio needed: $(echo "scale=1; $input_tokens / $TARGET_TOKENS" | bc):1"
    echo "  Preservation: $PRESERVE"
    echo ""

    if [[ $input_tokens -le $TARGET_TOKENS ]]; then
        echo "Status: NO COMPRESSION NEEDED"
    else
        echo "Status: COMPRESSION REQUIRED"

        # Estimate quality loss
        local ratio
        ratio=$(echo "scale=2; $input_tokens / $TARGET_TOKENS" | bc)
        if (( $(echo "$ratio < 3" | bc -l) )); then
            echo "Expected quality: HIGH (minimal information loss)"
        elif (( $(echo "$ratio < 6" | bc -l) )); then
            echo "Expected quality: MEDIUM (some detail loss)"
        else
            echo "Expected quality: LOW (significant summarization)"
        fi
    fi
}

# Main execution
main() {
    # Verify Gemini is available
    if ! command -v gemini &> /dev/null; then
        log_error "Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
        exit 1
    fi

    # Read input
    $VERBOSE && log_info "Reading input from: $INPUT_FILE"
    local content
    content=$(read_input)

    if [[ -z "$content" ]]; then
        log_error "Empty input"
        exit 1
    fi

    local input_chars=${#content}
    local input_tokens
    input_tokens=$(estimate_tokens "$input_chars")

    $VERBOSE && log_info "Input size: $input_chars chars (~$input_tokens tokens)"
    $VERBOSE && log_info "Target: $TARGET_TOKENS tokens"

    # Dry run or compress
    if $DRY_RUN; then
        dry_run "$content"
        exit 0
    fi

    # Perform compression
    local result
    result=$(compress_context "$content")

    # Output result
    local output_chars=${#result}
    local output_tokens
    output_tokens=$(estimate_tokens "$output_chars")

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$result" > "$OUTPUT_FILE"
        log_success "Compressed: $input_tokens -> $output_tokens tokens (saved to $OUTPUT_FILE)"
    else
        echo "$result"
        $VERBOSE && log_success "Compressed: $input_tokens -> $output_tokens tokens"
    fi

    # Warn if output exceeds target
    if [[ $output_tokens -gt $TARGET_TOKENS ]]; then
        local overage=$((output_tokens - TARGET_TOKENS))
        log_warn "Output exceeds target by ~$overage tokens. Consider re-running with lower target."
    fi
}

# Execute
main
