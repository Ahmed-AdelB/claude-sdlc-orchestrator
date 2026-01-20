# Context Compression Strategies

> **Purpose:** Manage large context windows efficiently across tri-agent workflows
> **Primary Tool:** Gemini (1M token context) for compression operations
> **Target:** Reduce context while preserving critical information

## Overview

Context compression is essential when:

- Session context exceeds model limits (Claude 150K, Codex 300K)
- Handoff between models requires context reduction
- Long-running sessions accumulate conversation history
- Large codebases need selective loading

---

## Strategy 1: Summarization (Gemini-First Handoff)

**Best for:** Passing analysis results between AI models

### Concept

Use Gemini's 1M context window to ingest large content, then summarize to a target size for handoff to Claude or Codex.

### Implementation

```bash
# Step 1: Gemini ingests full context and summarizes
SUMMARY=$(gemini -m gemini-3-pro-preview --approval-mode yolo "
Summarize this codebase analysis for handoff to Claude.
Preserve: architectural decisions, security constraints, key interfaces.
Target: 30K tokens max.

Context:
$(cat /path/to/large-context.txt)
")

# Step 2: Claude receives compressed context
# (Use in Claude Code session or via API)
echo "$SUMMARY" | claude-context-prime
```

### Preservation Rules

| Category    | Must Preserve              | Can Summarize          | Can Omit           |
| ----------- | -------------------------- | ---------------------- | ------------------ |
| Decisions   | All architectural choices  | Reasoning details      | Draft alternatives |
| Code        | Critical interfaces, types | Implementation details | Test helpers       |
| Constraints | Security requirements      | Full rationale         | Rejected options   |
| Errors      | Active blockers            | Resolution attempts    | Resolved issues    |

### Token Reduction Targets

| Input Size | Target Output | Compression Ratio |
| ---------- | ------------- | ----------------- |
| 100K-200K  | 30K-50K       | 3:1 to 4:1        |
| 200K-500K  | 50K-80K       | 4:1 to 6:1        |
| 500K-1M    | 80K-120K      | 6:1 to 8:1        |

---

## Strategy 2: Sliding Window Analysis

**Best for:** Iterative code review, large file processing

### Concept

Process large content in overlapping windows, maintaining continuity through summary anchors.

### Implementation

```bash
#!/bin/bash
# Sliding window with 20% overlap
WINDOW_SIZE=50000  # characters (~12K tokens)
OVERLAP=10000      # 20% overlap for context continuity

FILE="$1"
TOTAL_SIZE=$(wc -c < "$FILE")
OFFSET=0
WINDOW_NUM=1
ACCUMULATED_SUMMARY=""

while [ $OFFSET -lt $TOTAL_SIZE ]; do
    # Extract window
    WINDOW=$(dd if="$FILE" bs=1 skip=$OFFSET count=$WINDOW_SIZE 2>/dev/null)

    # Analyze with accumulated context
    WINDOW_RESULT=$(gemini -m gemini-3-pro-preview --approval-mode yolo "
Previous summary: $ACCUMULATED_SUMMARY

Analyze window $WINDOW_NUM of file. Report:
- Key findings
- Dependencies on previous/next sections
- Critical code patterns

Window content:
$WINDOW
")

    # Update accumulated summary
    ACCUMULATED_SUMMARY="$ACCUMULATED_SUMMARY
Window $WINDOW_NUM: $WINDOW_RESULT"

    # Advance with overlap
    OFFSET=$((OFFSET + WINDOW_SIZE - OVERLAP))
    WINDOW_NUM=$((WINDOW_NUM + 1))
done

echo "$ACCUMULATED_SUMMARY"
```

### Window Configuration by Content Type

| Content Type  | Window Size | Overlap | Notes                        |
| ------------- | ----------- | ------- | ---------------------------- |
| Source code   | 50K chars   | 20%     | Preserve function boundaries |
| Documentation | 80K chars   | 10%     | Section-aware splitting      |
| Logs          | 100K chars  | 5%      | Timestamp-based windows      |
| JSON/Config   | 30K chars   | 30%     | Preserve object integrity    |

### Anchor Points

Between windows, preserve these anchors:

```yaml
anchors:
  - function_signatures: "All exported functions from previous window"
  - import_statements: "Dependencies referenced but not yet seen"
  - open_blocks: "Unclosed braces, parentheses, tags"
  - pending_references: "Variables/types used but not defined"
  - error_context: "Active error state if mid-stack-trace"
```

---

## Strategy 3: Semantic Indexing

**Best for:** Large codebases, search-driven context loading

### Concept

Build a semantic index of the codebase, then load only relevant sections based on query similarity.

### Implementation

```bash
# Step 1: Build semantic index (run once or on changes)
~/.claude/scripts/build-semantic-index.sh /path/to/codebase

# Step 2: Query-driven loading
QUERY="authentication flow with JWT refresh"
RELEVANT_FILES=$(gemini -m gemini-3-pro-preview --approval-mode yolo "
Given this semantic index, return the top 10 most relevant files for the query.
Output as newline-separated file paths only.

Query: $QUERY

Index:
$(cat ~/.claude/indices/codebase-semantic.json)
")

# Step 3: Load only relevant context
CONTEXT=$(echo "$RELEVANT_FILES" | while read -r file; do
    echo "=== $file ==="
    cat "$file"
done)

# Step 4: Use compressed context
codex exec -m gpt-5.2-codex -s workspace-write "
Implement based on these relevant code sections:

$CONTEXT

Task: $QUERY
"
```

### Index Structure

```json
{
  "files": {
    "src/auth/jwt.ts": {
      "summary": "JWT token generation and validation",
      "exports": ["generateToken", "validateToken", "refreshToken"],
      "imports": ["crypto", "jsonwebtoken"],
      "keywords": ["authentication", "JWT", "token", "refresh", "security"],
      "lines": 245,
      "complexity": "medium"
    }
  },
  "clusters": {
    "authentication": [
      "src/auth/jwt.ts",
      "src/auth/oauth.ts",
      "src/middleware/auth.ts"
    ],
    "database": ["src/db/connection.ts", "src/db/models/*.ts"]
  },
  "dependencies": {
    "src/auth/jwt.ts": ["src/config/secrets.ts", "src/types/user.ts"]
  }
}
```

### Relevance Scoring

| Factor              | Weight | Description                         |
| ------------------- | ------ | ----------------------------------- |
| Keyword match       | 30%    | Direct term overlap                 |
| Semantic similarity | 40%    | Embedding distance                  |
| Dependency chain    | 20%    | Files that import/export to matches |
| Recency             | 10%    | Recently modified files             |

---

## Strategy 4: Progressive Disclosure

**Best for:** Interactive sessions, ask-driven exploration

### Concept

Start with minimal context, expand on demand based on Claude's requests.

### Implementation

```bash
# Initial minimal context
CORE_CONTEXT=$(cat <<'EOF'
# Project Overview
- Framework: Next.js 14 with App Router
- Database: PostgreSQL with Prisma ORM
- Auth: NextAuth.js with JWT sessions

# Available Files (request with: LOAD_FILE:path)
- src/app/api/** (API routes)
- src/lib/** (Utility functions)
- src/components/** (React components)
- prisma/schema.prisma (Database schema)

# Request Format
Reply with LOAD_FILE:path/to/file to load specific files.
Reply with SEARCH:keyword to find relevant files.
Reply with EXPAND:topic for detailed documentation.
EOF
)

# Claude session with progressive loading
while true; do
    # Get Claude's response
    RESPONSE=$(claude --context "$CORE_CONTEXT" --message "$USER_QUERY")

    # Check for expansion requests
    if echo "$RESPONSE" | grep -q "LOAD_FILE:"; then
        FILE_PATH=$(echo "$RESPONSE" | grep -oP 'LOAD_FILE:\K[^\s]+')
        CORE_CONTEXT="$CORE_CONTEXT

=== Loaded: $FILE_PATH ===
$(cat "$FILE_PATH" 2>/dev/null || echo "File not found")"
    fi

    if echo "$RESPONSE" | grep -q "SEARCH:"; then
        KEYWORD=$(echo "$RESPONSE" | grep -oP 'SEARCH:\K[^\s]+')
        SEARCH_RESULTS=$(grep -rl "$KEYWORD" src/ --include="*.ts" | head -20)
        CORE_CONTEXT="$CORE_CONTEXT

=== Search results for: $KEYWORD ===
$SEARCH_RESULTS"
    fi

    if echo "$RESPONSE" | grep -q "EXPAND:"; then
        TOPIC=$(echo "$RESPONSE" | grep -oP 'EXPAND:\K[^\s]+')
        EXPANSION=$(gemini -m gemini-3-pro-preview --approval-mode yolo "
Provide detailed documentation about: $TOPIC
Context: This is a Next.js application.
")
        CORE_CONTEXT="$CORE_CONTEXT

=== Documentation: $TOPIC ===
$EXPANSION"
    fi
done
```

### Disclosure Levels

| Level               | Content Loaded                    | Typical Size |
| ------------------- | --------------------------------- | ------------ |
| L0 - Overview       | Project structure, tech stack     | 2K tokens    |
| L1 - Index          | File listing, function signatures | 10K tokens   |
| L2 - Interfaces     | Types, API contracts, exports     | 30K tokens   |
| L3 - Implementation | Full source files on demand       | Variable     |
| L4 - History        | Git history, related PRs          | Variable     |

### Trigger Phrases

```yaml
expansion_triggers:
  - "I need to see": Load specific file
  - "What does X do": Expand with implementation
  - "How is X connected to": Load dependency chain
  - "Show me examples": Load test files
  - "What changed": Load git diff
```

---

## Combined Strategy: Adaptive Compression

For complex tasks, combine strategies based on context type.

```bash
#!/bin/bash
# ~/.claude/scripts/adaptive-compress.sh

INPUT_FILE="$1"
TARGET_TOKENS="${2:-50000}"

# Detect content type
if file "$INPUT_FILE" | grep -q "text"; then
    if head -100 "$INPUT_FILE" | grep -qE '(function|class|import|export)'; then
        STRATEGY="semantic"
    elif head -100 "$INPUT_FILE" | grep -qE '^\[.*\]|^{.*}'; then
        STRATEGY="summarize"
    else
        STRATEGY="window"
    fi
else
    STRATEGY="summarize"
fi

case "$STRATEGY" in
    semantic)
        # Extract key structures, summarize implementation
        gemini -m gemini-3-pro-preview --approval-mode yolo "
Extract from this code:
1. All exported functions/classes with signatures
2. Type definitions
3. Key architectural patterns
4. Security-relevant code blocks (verbatim)

Summarize everything else. Target: $TARGET_TOKENS tokens.

$(cat "$INPUT_FILE")
"
        ;;
    window)
        # Use sliding window with progressive summarization
        ~/.claude/scripts/sliding-window.sh "$INPUT_FILE" "$TARGET_TOKENS"
        ;;
    summarize)
        # Direct summarization
        gemini -m gemini-3-pro-preview --approval-mode yolo "
Summarize this content, preserving:
- All decisions and their rationale
- Numerical data and metrics
- Action items and blockers
- Key conclusions

Target: $TARGET_TOKENS tokens.

$(cat "$INPUT_FILE")
"
        ;;
esac
```

---

## Quick Reference

### Compression Ratios by Content Type

| Content              | Achievable Ratio | Information Loss           |
| -------------------- | ---------------- | -------------------------- |
| Conversation history | 10:1             | Low (keep decisions)       |
| Source code          | 4:1              | Medium (lose impl details) |
| Documentation        | 6:1              | Low (structure preserved)  |
| Logs/Debug output    | 20:1             | Medium (keep errors)       |
| JSON data            | 5:1              | Low (schema preserved)     |

### Model Context Limits

| Model         | Context Limit | Safe Working Limit |
| ------------- | ------------- | ------------------ |
| Claude Sonnet | 200K          | 150K               |
| Claude Opus   | 200K          | 150K               |
| Codex GPT-5.2 | 400K          | 300K               |
| Gemini 3 Pro  | 1M            | 750K               |

### Emergency Compression

When context overflow is imminent:

```bash
# Quick 80% reduction - preserves only critical info
gemini -m gemini-3-pro-preview --approval-mode yolo "
EMERGENCY COMPRESSION - preserve only:
1. Current task definition
2. Active blockers/errors
3. Critical constraints
4. Most recent decisions (last 3)

Discard all other context.

$(cat context.txt)
" > compressed-emergency.txt
```

---

## Usage with context-compressor.sh

```bash
# Basic usage
~/.claude/scripts/context-compressor.sh input.txt 50000

# With strategy override
STRATEGY=semantic ~/.claude/scripts/context-compressor.sh large-codebase.txt 80000

# Pipe mode
cat session-history.jsonl | ~/.claude/scripts/context-compressor.sh - 30000

# Dry run (estimate only)
~/.claude/scripts/context-compressor.sh input.txt 50000 --dry-run
```
