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

# =============================================================================
# RAG Ingestion Pipeline - Directory Walker and Indexing
# =============================================================================

# Default file extensions to index
RAG_INDEX_EXTENSIONS="${RAG_INDEX_EXTENSIONS:-sh,py,js,ts,jsx,tsx,md,txt,json,yaml,yml,toml,cfg,conf,ini,html,css,sql,go,rs,rb,java,c,cpp,h,hpp}"

# Maximum file size to index (default 1MB)
RAG_MAX_FILE_SIZE="${RAG_MAX_FILE_SIZE:-1048576}"

# Cron schedule file location
RAG_CRON_FILE="${RAG_CRON_FILE:-${STATE_DIR}/rag/cron_schedule}"

# Initialize file tracking table for change detection
rag_init_files_table() {
    rag_init || return 1

    sqlite3 "$RAG_DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS indexed_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filepath TEXT UNIQUE NOT NULL,
    content_hash TEXT NOT NULL,
    file_size INTEGER,
    context_id INTEGER,
    indexed_at TEXT NOT NULL,
    FOREIGN KEY (context_id) REFERENCES contexts(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_indexed_files_filepath ON indexed_files(filepath);
CREATE INDEX IF NOT EXISTS idx_indexed_files_hash ON indexed_files(content_hash);
SQL
}

# Compute SHA256 hash of file content
rag_file_hash() {
    local filepath="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$filepath" 2>/dev/null | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$filepath" 2>/dev/null | cut -d' ' -f1
    else
        # Fallback: use md5sum if available
        if command -v md5sum >/dev/null 2>&1; then
            md5sum "$filepath" 2>/dev/null | cut -d' ' -f1
        else
            _rag_log WARN "No hash utility found, using file mtime as hash"
            stat -c %Y "$filepath" 2>/dev/null || stat -f %m "$filepath" 2>/dev/null
        fi
    fi
}

# Check if file should be indexed based on extension
rag_should_index_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local ext="${filename##*.}"

    # Handle files without extension
    if [[ "$ext" == "$filename" ]]; then
        # Check for common extensionless files
        case "$filename" in
            Makefile|Dockerfile|Vagrantfile|Gemfile|Rakefile|Procfile)
                return 0
                ;;
            .bashrc|.zshrc|.profile|.gitignore|.dockerignore|.env.example)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi

    # Convert extension list to pattern and check
    local ext_lower
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    local pattern
    pattern=$(echo "$RAG_INDEX_EXTENSIONS" | tr ',' '|')

    if echo "$ext_lower" | grep -qE "^($pattern)$"; then
        return 0
    fi
    return 1
}

# Check if file has changed since last indexing
rag_file_changed() {
    local filepath="$1"
    local current_hash="$2"

    rag_init_files_table || return 0

    local filepath_esc
    filepath_esc=$(rag_sql_escape "$filepath")

    local stored_hash
    stored_hash=$(sqlite3 "$RAG_DB_PATH" "SELECT content_hash FROM indexed_files WHERE filepath='$filepath_esc';")

    if [[ -z "$stored_hash" ]]; then
        # File not indexed yet
        return 0
    fi

    if [[ "$stored_hash" != "$current_hash" ]]; then
        # Hash changed
        return 0
    fi

    # File unchanged
    return 1
}

# Extract tags from filepath (directory structure and file type)
rag_extract_tags() {
    local filepath="$1"
    local base_dir="$2"

    local relative_path="${filepath#$base_dir/}"
    local dir_path
    dir_path=$(dirname "$relative_path")
    local filename
    filename=$(basename "$filepath")
    local ext="${filename##*.}"

    local tags=""

    # Add extension as tag
    if [[ "$ext" != "$filename" ]]; then
        tags="$ext"
    fi

    # Add directory components as tags (limit to 3 levels)
    if [[ "$dir_path" != "." ]]; then
        local dir_tags
        dir_tags=$(echo "$dir_path" | tr '/' ',' | cut -d',' -f1-3)
        if [[ -n "$tags" ]]; then
            tags="$tags,$dir_tags"
        else
            tags="$dir_tags"
        fi
    fi

    printf '%s' "$tags"
}

# Index a single file
rag_index_file() {
    local filepath="$1"
    local base_dir="${2:-.}"
    local force="${3:-0}"

    # Validate file exists and is readable
    if [[ ! -f "$filepath" ]] || [[ ! -r "$filepath" ]]; then
        _rag_log WARN "Cannot read file: $filepath"
        return 1
    fi

    # Check file size
    local file_size
    file_size=$(stat -c %s "$filepath" 2>/dev/null || stat -f %z "$filepath" 2>/dev/null || echo 0)
    if [[ "$file_size" -gt "$RAG_MAX_FILE_SIZE" ]]; then
        _rag_log WARN "File too large to index ($file_size bytes): $filepath"
        return 1
    fi

    # Skip empty files
    if [[ "$file_size" -eq 0 ]]; then
        return 0
    fi

    # Compute hash
    local content_hash
    content_hash=$(rag_file_hash "$filepath")
    if [[ -z "$content_hash" ]]; then
        _rag_log WARN "Failed to compute hash for: $filepath"
        return 1
    fi

    # Check if file changed
    if [[ "$force" != "1" ]] && ! rag_file_changed "$filepath" "$content_hash"; then
        _rag_log INFO "Skipping unchanged file: $filepath"
        return 0
    fi

    # Read file content
    local content
    content=$(cat "$filepath" 2>/dev/null)
    if [[ -z "$content" ]]; then
        return 0
    fi

    # Extract tags
    local tags
    tags=$(rag_extract_tags "$filepath" "$base_dir")

    local now
    now=$(date -Iseconds)
    local filepath_esc content_hash_esc
    filepath_esc=$(rag_sql_escape "$filepath")
    content_hash_esc=$(rag_sql_escape "$content_hash")

    # Check if file was previously indexed
    local existing_context_id
    existing_context_id=$(sqlite3 "$RAG_DB_PATH" "SELECT context_id FROM indexed_files WHERE filepath='$filepath_esc';")

    local context_id
    if [[ -n "$existing_context_id" ]]; then
        # Update existing context
        rag_update_context "$existing_context_id" "$content" "$tags"
        context_id="$existing_context_id"

        # Update file record
        sqlite3 "$RAG_DB_PATH" "UPDATE indexed_files SET content_hash='$content_hash_esc', file_size=$file_size, indexed_at='$now' WHERE filepath='$filepath_esc';"
        _rag_log INFO "Updated indexed file: $filepath"
    else
        # Add new context
        context_id=$(rag_add_context "$filepath" "$content" "$tags")

        # Record file in tracking table
        sqlite3 "$RAG_DB_PATH" "INSERT INTO indexed_files (filepath, content_hash, file_size, context_id, indexed_at) VALUES ('$filepath_esc', '$content_hash_esc', $file_size, $context_id, '$now');"
        _rag_log INFO "Indexed new file: $filepath"
    fi

    echo "$context_id"
}

# Walk directory recursively and index files
# Usage: rag_ingest_directory <directory> [force=0] [max_files=1000]
rag_ingest_directory() {
    local directory="${1:-.}"
    local force="${2:-0}"
    local max_files="${3:-1000}"

    # Validate directory
    if [[ ! -d "$directory" ]]; then
        _rag_log ERROR "Directory does not exist: $directory"
        return 1
    fi

    # Get absolute path
    local abs_dir
    abs_dir=$(cd "$directory" && pwd)

    rag_init_files_table || return 1

    _rag_log INFO "Starting directory ingestion: $abs_dir (force=$force, max=$max_files)"

    local indexed_count=0
    local skipped_count=0
    local error_count=0

    # Build find command with extension filters
    local find_args=()
    find_args+=("$abs_dir")
    find_args+=("-type" "f")
    find_args+=("-size" "-${RAG_MAX_FILE_SIZE}c")

    # Exclude common non-code directories
    find_args+=("-not" "-path" "*/.git/*")
    find_args+=("-not" "-path" "*/node_modules/*")
    find_args+=("-not" "-path" "*/__pycache__/*")
    find_args+=("-not" "-path" "*/.venv/*")
    find_args+=("-not" "-path" "*/venv/*")
    find_args+=("-not" "-path" "*/.cache/*")
    find_args+=("-not" "-path" "*/dist/*")
    find_args+=("-not" "-path" "*/build/*")
    find_args+=("-not" "-path" "*/.tox/*")
    find_args+=("-not" "-path" "*/.eggs/*")
    find_args+=("-not" "-path" "*/*.egg-info/*")

    while IFS= read -r filepath; do
        # Check max files limit
        if [[ "$indexed_count" -ge "$max_files" ]]; then
            _rag_log WARN "Reached max files limit ($max_files), stopping"
            break
        fi

        # Check if file should be indexed
        if ! rag_should_index_file "$filepath"; then
            ((skipped_count++)) || true
            continue
        fi

        # Index the file
        if rag_index_file "$filepath" "$abs_dir" "$force" >/dev/null 2>&1; then
            ((indexed_count++)) || true
        else
            ((error_count++)) || true
        fi

    done < <(find "${find_args[@]}" 2>/dev/null | sort)

    _rag_log INFO "Ingestion complete: indexed=$indexed_count, skipped=$skipped_count, errors=$error_count"

    # Return stats as JSON
    printf '{"indexed": %d, "skipped": %d, "errors": %d, "directory": "%s"}\n' \
        "$indexed_count" "$skipped_count" "$error_count" "$abs_dir"
}

# Remove orphaned entries (files that no longer exist)
rag_cleanup_orphans() {
    rag_init_files_table || return 1

    local removed_count=0

    while IFS=$'\t' read -r id filepath context_id; do
        [[ -n "$id" ]] || continue

        if [[ ! -f "$filepath" ]]; then
            # Remove from indexed_files
            sqlite3 "$RAG_DB_PATH" "DELETE FROM indexed_files WHERE id=$id;"

            # Remove associated context if exists
            if [[ -n "$context_id" ]]; then
                sqlite3 "$RAG_DB_PATH" "DELETE FROM contexts WHERE id=$context_id;"
            fi

            _rag_log INFO "Removed orphan: $filepath"
            ((removed_count++)) || true
        fi
    done < <(sqlite3 -separator $'\t' "$RAG_DB_PATH" "SELECT id, filepath, context_id FROM indexed_files;")

    _rag_log INFO "Cleanup complete: removed $removed_count orphan(s)"
    echo "$removed_count"
}

# Get list of indexed files
rag_list_indexed() {
    local limit="${1:-100}"
    rag_init_files_table || return 1
    sqlite3 -separator $'\t' "$RAG_DB_PATH" "SELECT filepath, content_hash, file_size, indexed_at FROM indexed_files ORDER BY indexed_at DESC LIMIT $limit;"
}

# Schedule periodic indexing via cron
# Usage: rag_schedule_indexing <directory> [interval_minutes=60]
rag_schedule_indexing() {
    local directory="${1:-.}"
    local interval="${2:-60}"

    # Validate directory
    if [[ ! -d "$directory" ]]; then
        _rag_log ERROR "Directory does not exist: $directory"
        return 1
    fi

    local abs_dir
    abs_dir=$(cd "$directory" && pwd)

    # Ensure cron directory exists
    local cron_dir
    cron_dir=$(dirname "$RAG_CRON_FILE")
    _rag_ensure_dir "$cron_dir"

    # Determine script path for cron job
    local script_path="${BASH_SOURCE[0]}"
    if [[ ! "$script_path" = /* ]]; then
        script_path="$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
    fi

    # Create wrapper script for cron execution
    local wrapper_script="${cron_dir}/rag_cron_ingest.sh"
    cat > "$wrapper_script" <<EOF
#!/bin/bash
# Auto-generated RAG ingestion cron script
# Generated: $(date -Iseconds)

export AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT}"
export STATE_DIR="${STATE_DIR}"
export RAG_DB_PATH="${RAG_DB_PATH}"
export RAG_INDEX_EXTENSIONS="${RAG_INDEX_EXTENSIONS}"
export RAG_MAX_FILE_SIZE="${RAG_MAX_FILE_SIZE}"

source "$script_path"

# Run ingestion
rag_ingest_directory "$abs_dir" 0 1000

# Cleanup orphans
rag_cleanup_orphans
EOF
    chmod +x "$wrapper_script"

    # Calculate cron schedule
    local cron_schedule
    if [[ "$interval" -lt 60 ]]; then
        # Run every N minutes
        cron_schedule="*/$interval * * * *"
    elif [[ "$interval" -eq 60 ]]; then
        # Run every hour
        cron_schedule="0 * * * *"
    elif [[ "$interval" -lt 1440 ]]; then
        # Run every N hours
        local hours=$((interval / 60))
        cron_schedule="0 */$hours * * *"
    else
        # Run daily
        cron_schedule="0 0 * * *"
    fi

    local cron_entry="$cron_schedule $wrapper_script >> ${cron_dir}/rag_ingest.log 2>&1"

    # Save schedule info
    cat > "$RAG_CRON_FILE" <<EOF
# RAG Indexing Schedule
# Directory: $abs_dir
# Interval: $interval minutes
# Created: $(date -Iseconds)

CRON_ENTRY=$cron_entry
WRAPPER_SCRIPT=$wrapper_script
DIRECTORY=$abs_dir
INTERVAL=$interval
EOF

    _rag_log INFO "Created cron schedule file: $RAG_CRON_FILE"
    _rag_log INFO "Cron entry: $cron_entry"

    # Attempt to install crontab entry (non-destructive)
    if command -v crontab >/dev/null 2>&1; then
        # Check if entry already exists
        local current_crontab
        current_crontab=$(crontab -l 2>/dev/null || true)

        if echo "$current_crontab" | grep -qF "$wrapper_script"; then
            _rag_log INFO "Cron entry already exists"
        else
            # Add to crontab
            {
                echo "$current_crontab"
                echo "# RAG Auto-Indexing for $abs_dir"
                echo "$cron_entry"
            } | crontab -
            _rag_log INFO "Installed cron entry"
        fi
    else
        _rag_log WARN "crontab not available, manual installation required"
        _rag_log INFO "Add this to your crontab: $cron_entry"
    fi

    printf '{"schedule": "%s", "directory": "%s", "interval_minutes": %d, "wrapper": "%s"}\n' \
        "$cron_schedule" "$abs_dir" "$interval" "$wrapper_script"
}

# Remove scheduled indexing
rag_unschedule_indexing() {
    if [[ ! -f "$RAG_CRON_FILE" ]]; then
        _rag_log WARN "No scheduled indexing found"
        return 0
    fi

    # Read wrapper script path
    local wrapper_script
    wrapper_script=$(grep "^WRAPPER_SCRIPT=" "$RAG_CRON_FILE" | cut -d= -f2)

    if [[ -n "$wrapper_script" ]] && command -v crontab >/dev/null 2>&1; then
        # Remove from crontab
        local new_crontab
        new_crontab=$(crontab -l 2>/dev/null | grep -vF "$wrapper_script" || true)
        echo "$new_crontab" | crontab -
        _rag_log INFO "Removed cron entry"
    fi

    # Remove files
    if [[ -f "$wrapper_script" ]]; then
        rm -f "$wrapper_script"
    fi
    rm -f "$RAG_CRON_FILE"

    _rag_log INFO "Unscheduled indexing"
}

# Show indexing schedule status
rag_schedule_status() {
    if [[ ! -f "$RAG_CRON_FILE" ]]; then
        echo "No scheduled indexing configured"
        return 0
    fi

    cat "$RAG_CRON_FILE"

    echo ""
    echo "Current crontab entries:"
    crontab -l 2>/dev/null | grep -i "rag" || echo "(none)"
}

# Quick stats including file counts
rag_full_stats() {
    rag_init_files_table || return 1

    local context_count file_count total_size
    context_count=$(sqlite3 "$RAG_DB_PATH" "SELECT COUNT(*) FROM contexts;")
    file_count=$(sqlite3 "$RAG_DB_PATH" "SELECT COUNT(*) FROM indexed_files;")
    total_size=$(sqlite3 "$RAG_DB_PATH" "SELECT COALESCE(SUM(file_size), 0) FROM indexed_files;")

    printf '{"contexts": %d, "indexed_files": %d, "total_size_bytes": %d}\n' \
        "$context_count" "$file_count" "$total_size"
}
