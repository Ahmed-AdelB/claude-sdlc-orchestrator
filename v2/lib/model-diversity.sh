#!/bin/bash
# =============================================================================
# model-diversity.sh - Enforce model family diversity
# =============================================================================
# Provides:
# - Model family mapping (Anthropic, Google, OpenAI)
# - Diversity scoring
# - Fallback routing if a family is unavailable
# =============================================================================

: "${AUTONOMOUS_ROOT:=${HOME}/.claude/autonomous}"
: "${BIN_DIR:=${AUTONOMOUS_ROOT}/bin}"

_div_log() {
    local level="$1"
    shift
    if type -t log_info >/dev/null 2>&1; then
        case "$level" in
            INFO) log_info "$*" ;;
            WARN) log_warn "$*" ;;
            ERROR) log_error "$*" ;;
            *) log_info "$*" ;;
        esac
    else
        echo "[$level] $*" >&2
    fi
}

normalize_model_name() {
    local model
    model=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
    case "$model" in
        *claude*) echo "claude" ;;
        *gemini*) echo "gemini" ;;
        *codex*) echo "codex" ;;
        *gpt*) echo "codex" ;;
        *opus*) echo "claude" ;;
        *pro*) echo "gemini" ;;
        *) echo "$model" ;;
    esac
}

model_family() {
    local model
    model=$(normalize_model_name "$1")
    case "$model" in
        claude|opus|anthropic) echo "anthropic" ;;
        gemini|pro|google) echo "google" ;;
        codex|gpt|openai) echo "openai" ;;
        *) echo "unknown" ;;
    esac
}

_model_env_override() {
    local model
    model=$(normalize_model_name "$1")
    local key
    key=$(echo "MODEL_${model^^}_AVAILABLE" | tr '-' '_')
    if [[ -n "${!key:-}" ]]; then
        echo "${!key}"
        return 0
    fi
    return 1
}

model_is_available() {
    local model
    model=$(normalize_model_name "$1")

    local override
    if override=$(_model_env_override "$model"); then
        case "${override}" in
            1|true|TRUE|yes|YES) return 0 ;;
            0|false|FALSE|no|NO) return 1 ;;
        esac
    fi

    case "$model" in
        claude)
            [[ -x "${BIN_DIR}/claude-delegate" ]] && return 0
            command -v claude >/dev/null 2>&1 && return 0
            ;;
        gemini)
            [[ -x "${BIN_DIR}/gemini-delegate" ]] && return 0
            command -v gemini >/dev/null 2>&1 && return 0
            ;;
        codex)
            [[ -x "${BIN_DIR}/codex-delegate" ]] && return 0
            command -v codex >/dev/null 2>&1 && return 0
            ;;
    esac

    return 1
}

diversity_score() {
    local models=("$@")
    if [[ ${#models[@]} -eq 0 ]]; then
        echo "0.00"
        return 0
    fi

    local families=()
    local model
    for model in "${models[@]}"; do
        local fam
        fam=$(model_family "$model")
        local seen=false
        local f
        for f in "${families[@]}"; do
            [[ "$f" == "$fam" ]] && seen=true
        done
        if [[ "$seen" == "false" ]]; then
            families+=("$fam")
        fi
    done

    local unique=${#families[@]}
    local total=${#models[@]}
    awk -v u="$unique" -v t="$total" 'BEGIN { if (t==0) print "0.00"; else printf "%.2f", u/t }'
}

diversity_select() {
    local desired="${1:-3}"
    shift || true
    local candidates=("$@")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        candidates=("claude" "gemini" "codex")
    fi

    local selected=()
    local families=()
    local model
    for model in "${candidates[@]}"; do
        model=$(normalize_model_name "$model")
        model_is_available "$model" || continue
        local fam
        fam=$(model_family "$model")
        local seen=false
        local f
        for f in "${families[@]}"; do
            [[ "$f" == "$fam" ]] && seen=true
        done
        if [[ "$seen" == "false" ]]; then
            selected+=("$model")
            families+=("$fam")
        fi
        [[ ${#selected[@]} -ge $desired ]] && break
    done

    if [[ ${#selected[@]} -lt $desired ]]; then
        for model in "${candidates[@]}"; do
            model=$(normalize_model_name "$model")
            model_is_available "$model" || continue
            local already=false
            local s
            for s in "${selected[@]}"; do
                [[ "$s" == "$model" ]] && already=true
            done
            if [[ "$already" == "false" ]]; then
                selected+=("$model")
            fi
            [[ ${#selected[@]} -ge $desired ]] && break
        done
    fi

    echo "${selected[*]}"
}

diversity_report() {
    local desired="${1:-3}"
    shift || true
    local selected
    selected=$(diversity_select "$desired" "$@")
    local score
    score=$(diversity_score $selected)

    local families=()
    local model
    for model in $selected; do
        families+=("$(model_family "$model")")
    done

    printf '{"models":[%s],"families":[%s],"score":%s}' \
        "$(printf '"%s",' $selected | sed 's/,$//')" \
        "$(printf '"%s",' ${families[@]} | sed 's/,$//')" \
        "$score"
}
