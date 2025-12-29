#!/bin/bash
# =============================================================================
# rag-context.sh - SQLite FTS5-backed context store
# =============================================================================
# Provides:
# - Context storage with FTS5 for semantic search
# - Context injection helpers
# - Memory summarization utilities
#
# This file is safe to source from common.sh or other scripts.
# It defines functions only and performs no actions on import.
# =============================================================================

: "${AUTONOMOUS_ROOT:=${HOME}/.claude/autonomous}"
: "${STATE_DIR:=${AUTONOMOUS_ROOT}/state}"

RAG_DB_PATH="${RAG_DB_PATH:-${STATE_DIR}/rag/context.db}"
RAG_MAX_SUMMARY_CHARS="${RAG_MAX_SUMMARY_CHARS:-400}"
RAG_INJECT_FULL="${RAG_INJECT_FULL:-0}"

_rag_log() {
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

_rag_ensure_dir() {
    local dir="$1"
    if type -t ensure_dir >/dev/null 2>&1; then
        ensure_dir "$dir"
    else
        mkdir -p "$dir"
    fi
}

rag_require_sqlite() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        _rag_log ERROR "sqlite3 is required for RAG context store"
        return 1
    fi
    return 0
}

rag_sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

rag_check_fts() {
    rag_require_sqlite || return 1
    if ! sqlite3 :memory: "CREATE VIRTUAL TABLE t USING fts5(content);" >/dev/null 2>&1; then
        _rag_log ERROR "SQLite FTS5 support not available"
        return 1
    fi
    return 0
}

rag_init() {
    rag_require_sqlite || return 1
    rag_check_fts || return 1

    local db_dir
    db_dir=$(dirname "$RAG_DB_PATH")
    _rag_ensure_dir "$db_dir"

    sqlite3 "$RAG_DB_PATH" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS contexts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT,
    content TEXT NOT NULL,
    summary TEXT,
    tags TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS contexts_fts USING fts5(
    content,
    summary,
    tags,
    content='contexts',
    content_rowid='id'
);

CREATE TRIGGER IF NOT EXISTS contexts_ai AFTER INSERT ON contexts BEGIN
    INSERT INTO contexts_fts(rowid, content, summary, tags)
    VALUES (new.id, new.content, new.summary, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS contexts_au AFTER UPDATE ON contexts BEGIN
    INSERT INTO contexts_fts(contexts_fts, rowid, content, summary, tags)
    VALUES('delete', old.id, old.content, old.summary, old.tags);
    INSERT INTO contexts_fts(rowid, content, summary, tags)
    VALUES (new.id, new.content, new.summary, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS contexts_ad AFTER DELETE ON contexts BEGIN
    INSERT INTO contexts_fts(contexts_fts, rowid, content, summary, tags)
    VALUES('delete', old.id, old.content, old.summary, old.tags);
END;
SQL
}

rag_rebuild_fts() {
    rag_init || return 1
    sqlite3 "$RAG_DB_PATH" "INSERT INTO contexts_fts(contexts_fts) VALUES('rebuild');" >/dev/null 2>&1 || true
}

rag_summarize() {
    local content="$1"

    if [[ -n "${RAG_SUMMARIZER_CMD:-}" ]]; then
        local summary
        summary=$(printf '%s' "$content" | ${RAG_SUMMARIZER_CMD} 2>/dev/null | head -c "$RAG_MAX_SUMMARY_CHARS")
        if [[ -n "$summary" ]]; then
            printf '%s' "$summary"
            return 0
        fi
    fi

    local cleaned
    cleaned=$(printf '%s' "$content" | tr '\n' ' ' | tr -s ' ')
    local summary
    summary=$(printf '%s' "$cleaned" | cut -c1-"$RAG_MAX_SUMMARY_CHARS")
    printf '%s' "$summary"
}

rag_add_context() {
    local source="$1"
    local content="$2"
    local tags="${3:-}"

    rag_init || return 1

    local summary
    summary=$(rag_summarize "$content")
    local now
    now=$(date -Iseconds)

    local source_esc summary_esc content_esc tags_esc
    source_esc=$(rag_sql_escape "$source")
    content_esc=$(rag_sql_escape "$content")
    summary_esc=$(rag_sql_escape "$summary")
    tags_esc=$(rag_sql_escape "$tags")

    sqlite3 "$RAG_DB_PATH" "INSERT INTO contexts (source, content, summary, tags, created_at, updated_at) VALUES ('$source_esc', '$content_esc', '$summary_esc', '$tags_esc', '$now', '$now');"
    sqlite3 "$RAG_DB_PATH" "SELECT last_insert_rowid();"
}

rag_update_context() {
    local id="$1"
    local content="$2"
    local tags="${3:-}"

    rag_init || return 1

    local summary
    summary=$(rag_summarize "$content")
    local now
    now=$(date -Iseconds)

    local content_esc summary_esc tags_esc
    content_esc=$(rag_sql_escape "$content")
    summary_esc=$(rag_sql_escape "$summary")
    tags_esc=$(rag_sql_escape "$tags")

    sqlite3 "$RAG_DB_PATH" "UPDATE contexts SET content='$content_esc', summary='$summary_esc', tags='$tags_esc', updated_at='$now' WHERE id=$id;"
}

rag_delete_context() {
    local id="$1"
    rag_init || return 1
    sqlite3 "$RAG_DB_PATH" "DELETE FROM contexts WHERE id=$id;"
}

rag_get_context() {
    local id="$1"
    rag_init || return 1
    sqlite3 -separator $'\t' "$RAG_DB_PATH" "SELECT id, source, content, summary, tags, created_at, updated_at FROM contexts WHERE id=$id;"
}

rag_search() {
    local query="$1"
    local limit="${2:-5}"

    rag_init || return 1

    local q
    q=$(rag_sql_escape "$query")

    sqlite3 -separator $'\t' "$RAG_DB_PATH" \
        "SELECT id, bm25(contexts_fts) AS score, source, COALESCE(summary, ''), COALESCE(tags, '') FROM contexts_fts WHERE contexts_fts MATCH '$q' ORDER BY score LIMIT $limit;"
}

rag_inject_context() {
    local query="$1"
    local limit="${2:-5}"
    local use_full="${3:-$RAG_INJECT_FULL}"

    rag_init || return 1

    local output=""
    while IFS=$'\t' read -r id score source summary tags; do
        [[ -n "$id" ]] || continue
        local body="$summary"
        if [[ "$use_full" == "1" ]]; then
            body=$(sqlite3 "$RAG_DB_PATH" "SELECT content FROM contexts WHERE id=$id;")
        fi

        output+="[${id}] ${source} (${tags})\n"
        output+="${body}\n\n"
    done < <(rag_search "$query" "$limit")

    printf '%b' "$output"
}

rag_memory_rollup() {
    local limit="${1:-20}"
    local max_chars="${2:-2000}"

    rag_init || return 1

    local combined
    combined=$(sqlite3 "$RAG_DB_PATH" "SELECT COALESCE(summary, substr(content,1,200)) FROM contexts ORDER BY updated_at DESC LIMIT $limit;")
    local rolled
    rolled=$(printf '%s\n' "$combined" | tr '\n' ' ' | tr -s ' ' | cut -c1-"$max_chars")
    printf '%s' "$rolled"
}

rag_stats() {
    rag_init || return 1
    sqlite3 "$RAG_DB_PATH" "SELECT COUNT(*) FROM contexts;"
}
