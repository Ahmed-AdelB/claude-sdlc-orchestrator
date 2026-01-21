# Hook Performance Optimization Report

**Date:** 2026-01-21  
**Author:** Ahmed Adel Bakr Alderai  
**Scope:** `/home/aadel/.claude/hooks/`

---

## Executive Summary

Analysis of Claude Code hook scripts identified **~690-890ms total latency per tool call** from hooks, significantly exceeding the target of <150ms. This report details root causes and provides actionable optimizations that can reduce latency by 60-80%.

---

## Baseline Performance Measurements

| Hook Script | Execution Time | Called On |
|-------------|----------------|-----------|
| `audit-pretool.sh` | 212ms | Every tool (pre) |
| `audit-posttool.sh` | 319ms | Every tool (post) |
| `guard-bash.sh` | 159ms | Bash tool |
| `guard-files.sh` | 196ms | Read/Edit/Write |
| `guard-web.sh` | ~150ms (est.) | WebSearch/WebFetch |

### Total Hook Overhead by Tool Type

| Tool | Hooks Executed | Total Overhead |
|------|----------------|----------------|
| **Bash** | audit-pretool + guard-bash + audit-posttool | ~690ms |
| **Read/Edit/Write** | audit-pretool + guard-files + audit-posttool | ~727ms |
| **Task** | audit-pretool + triagent-pre-task + audit-posttool | ~750ms |
| **WebSearch** | audit-pretool + guard-web + audit-posttool | ~681ms |

---

## Root Cause Analysis

### 1. Excessive Subprocess Spawning (CRITICAL)

**Impact:** ~100-150ms per hook

Each hook spawns multiple subprocesses for basic operations:

```bash
# audit-pretool.sh - 6+ subprocesses per call
SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"')    # jq
TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"')      # jq
TOOL_INPUT=$(echo "$TOOL_DATA" | jq -c '.tool_input // {}')           # jq
TIMESTAMP=$(date -Iseconds)                                            # date
AUDIT_FILE="${AUDIT_DIR}/audit-$(date +%Y%m%d).jsonl"                 # date
find "$AUDIT_DIR" -name "audit-*.jsonl" -mtime +7 -delete             # find
```

**Problem:** Each subprocess fork costs ~5-15ms (jq is particularly heavy at ~20-50ms).

### 2. Log Rotation on Hot Path (HIGH)

**Impact:** ~30-50ms per call

File in: `audit-pretool.sh` (line 66)
```bash
find "$AUDIT_DIR" -name "audit-*.jsonl" -mtime +7 -delete 2>/dev/null || true
```

**Problem:** Filesystem scan runs on EVERY tool call. Should be periodic (daily cron).

### 3. Multiple File Lock Operations (MEDIUM)

**Impact:** ~20-40ms per hook

```bash
# audit-pretool.sh has 2 flock operations
(flock -x 200; ...) 200>"${AUDIT_FILE}.lock"
(flock -x 200; ...) 200>"${STATS_FILE}.lock"
```

**Problem:** Lock acquisition and I/O wait add latency, especially under contention.

### 4. Pattern Matching via grep Loops (MEDIUM)

**Impact:** ~30-60ms in guard scripts

```bash
# guard-bash.sh - 15 grep subprocesses
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then ...
done
```

**Problem:** Loop spawns new grep process per pattern instead of single regex.

### 5. Redundant Directory Creation (LOW)

**Impact:** ~5-10ms per hook

```bash
mkdir -p "$AUDIT_DIR"  # Every call
mkdir -p "$LOG_DIR"    # Every call
```

**Problem:** Directory existence check is fast but syscall overhead adds up.

### 6. JSON Escaping Overhead (MEDIUM)

**Impact:** ~40-60ms in audit-posttool.sh

```bash
TOOL_RESULT_ESCAPED=$(echo "$TOOL_RESULT" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//')
AUDIT_ENTRY=$(jq -n --arg ts "$TIMESTAMP" ...)  # Complex jq invocation
```

**Problem:** Multiple jq/sed invocations for JSON construction.

---

## Optimization Strategies

### Strategy 1: Single-Pass JSON Parsing (CRITICAL)

**Before:** Multiple jq invocations (~100ms)
```bash
SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$TOOL_DATA" | jq -c '.tool_input // {}')
```

**After:** Single jq call with multiple outputs (~30ms)
```bash
read -r SESSION_ID TOOL_NAME TOOL_INPUT < <(echo "$TOOL_DATA" | jq -r '[.session_id // "unknown", .tool_name // "unknown", (.tool_input // {} | @json)] | @tsv')
```

**Expected Savings:** 60-70ms per hook

### Strategy 2: Move Cleanup to Cron (CRITICAL)

**Before:** Log rotation on every call
```bash
find "$AUDIT_DIR" -name "audit-*.jsonl" -mtime +7 -delete
```

**After:** Remove from hook, add cron job
```bash
# Add to crontab: 0 3 * * * ~/.claude/scripts/cleanup.sh
```

**Expected Savings:** 30-50ms per call

### Strategy 3: Bash Native Pattern Matching (HIGH)

**Before:** grep loop
```bash
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
```

**After:** Bash regex with combined pattern
```bash
DANGEROUS_REGEX='rm -rf /|rm -rf ~|sudo rm -rf|:\(\)\{ :\|:& \};:|chmod 777|...'
if [[ "$COMMAND" =~ $DANGEROUS_REGEX ]]; then
```

**Expected Savings:** 40-50ms per guard hook

### Strategy 4: Cached Timestamps (MEDIUM)

**Before:** Multiple date calls
```bash
TIMESTAMP=$(date -Iseconds)
AUDIT_FILE="${AUDIT_DIR}/audit-$(date +%Y%m%d).jsonl"
EPOCH_NOW=$(date +%s)
```

**After:** Single date call with multiple formats
```bash
eval $(date +'TIMESTAMP=%FT%T%z AUDIT_DATE=%Y%m%d EPOCH_NOW=%s')
AUDIT_FILE="${AUDIT_DIR}/audit-${AUDIT_DATE}.jsonl"
```

**Expected Savings:** 10-20ms per hook

### Strategy 5: Asynchronous Logging (HIGH)

**Before:** Synchronous file writes with flock
```bash
(flock -x 200; echo "$ENTRY" >> "$FILE") 200>"$FILE.lock"
```

**After:** Buffered async write via named pipe or background job
```bash
# Fire-and-forget to background logger
echo "$ENTRY" >> "$LOG_BUFFER" &
```

**Expected Savings:** 20-30ms per hook (removes blocking I/O)

### Strategy 6: Skip Hooks on Bypass Mode Early (MEDIUM)

**Before:** Full JSON parsing before bypass check
```bash
TOOL_DATA=$(cat)
SESSION_ID=$(echo "$TOOL_DATA" | jq ...)
PERMISSION_MODE=$(echo "$TOOL_DATA" | jq -r '.permission_mode // empty')
if [[ "$PERMISSION_MODE" == "bypassPermissions" ]]; then
    echo '{"continue": true}'; exit 0
fi
```

**After:** Check bypass first with minimal parsing
```bash
TOOL_DATA=$(cat)
if [[ "$TOOL_DATA" == *'"permission_mode":"bypassPermissions"'* ]]; then
    echo '{"continue": true}'; exit 0
fi
```

**Expected Savings:** Full hook time when bypass enabled

### Strategy 7: Pre-create Directories Once (LOW)

**Before:** mkdir on every call
```bash
mkdir -p "$LOG_DIR" "$AUDIT_DIR"
```

**After:** Check existence first
```bash
[[ -d "$AUDIT_DIR" ]] || mkdir -p "$AUDIT_DIR"
```

**Expected Savings:** 2-5ms per hook

---

## Implementation Priority

| Priority | Optimization | Effort | Impact |
|----------|-------------|--------|--------|
| P0 | Single-pass jq parsing | Medium | -70ms |
| P0 | Move cleanup to cron | Low | -40ms |
| P1 | Bash native pattern matching | Medium | -50ms |
| P1 | Async logging | High | -25ms |
| P2 | Cached timestamps | Low | -15ms |
| P2 | Early bypass check | Low | -10ms |
| P3 | Pre-create directories | Low | -5ms |

**Total Expected Savings:** 150-215ms per tool call (60-80% reduction)

---

## Quick Wins Implemented

### 1. Created optimized audit-pretool-fast.sh

Location: `/home/aadel/.claude/hooks/audit-pretool-fast.sh`

Key changes:
- Single jq invocation for all fields
- Removed find cleanup from hot path
- Cached timestamp
- Early bypass check

### 2. Created optimized guard-bash-fast.sh

Location: `/home/aadel/.claude/hooks/guard-bash-fast.sh`

Key changes:
- Combined regex pattern (single match)
- Bash native pattern matching
- No subprocess spawning for pattern check

### 3. Created cleanup cron script

Location: `/home/aadel/.claude/scripts/hook-cleanup.sh`

Should be scheduled: `0 3 * * * ~/.claude/scripts/hook-cleanup.sh`

---

## Benchmark Comparison

| Hook | Original | Optimized | Savings |
|------|----------|-----------|---------|
| audit-pretool | 212ms | ~80ms | 62% |
| guard-bash | 159ms | ~45ms | 72% |
| guard-files | 196ms | ~60ms | 69% |
| audit-posttool | 319ms | ~120ms | 62% |

**Total per Bash tool:** 690ms -> ~245ms (65% reduction)

---

## Recommendations

### Immediate Actions

1. **Replace hot-path hooks with optimized versions**
   ```bash
   cd ~/.claude/hooks
   cp audit-pretool.sh audit-pretool.sh.bak
   cp audit-pretool-fast.sh audit-pretool.sh
   ```

2. **Add cleanup cron job**
   ```bash
   (crontab -l 2>/dev/null; echo "0 3 * * * ~/.claude/scripts/hook-cleanup.sh") | crontab -
   ```

3. **Disable non-essential hooks during performance-critical work**
   Set `CLAUDE_HOOK_MODE=disabled` in environment

### Long-term Improvements

1. **Rewrite hooks in a compiled language** (Go/Rust) for sub-10ms execution
2. **Implement hook daemon** with Unix socket for zero-fork overhead
3. **Use SQLite for audit logging** instead of JSONL (faster appends with WAL mode)
4. **Implement hook caching** for repeated patterns

---

## Files Referenced

| File | Path | Size |
|------|------|------|
| audit-pretool.sh | `/home/aadel/.claude/hooks/audit-pretool.sh` | 1.9KB |
| audit-posttool.sh | `/home/aadel/.claude/hooks/audit-posttool.sh` | 2.7KB |
| guard-bash.sh | `/home/aadel/.claude/hooks/guard-bash.sh` | 2.0KB |
| guard-files.sh | `/home/aadel/.claude/hooks/guard-files.sh` | 2.0KB |
| guard-web.sh | `/home/aadel/.claude/hooks/guard-web.sh` | 2.1KB |
| periodic-checkpoint.sh | `/home/aadel/.claude/hooks/periodic-checkpoint.sh` | 4.5KB |
| post-edit.sh | `/home/aadel/.claude/hooks/post-edit.sh` | 5.9KB |
| quality-gate.sh | `/home/aadel/.claude/hooks/quality-gate.sh` | 6.6KB |

---

Ahmed Adel Bakr Alderai

---

## Actual Benchmark Results (Post-Optimization)

Benchmarks run on 2026-01-21:

| Hook | Original | Optimized | Improvement |
|------|----------|-----------|-------------|
| audit-pretool.sh | 212ms | **49ms** | **77% faster** |
| guard-bash.sh | 159ms | **60ms** | **62% faster** |
| guard-files.sh | 196ms | **52ms** | **73% faster** |
| audit-posttool.sh | 319ms | **155ms** | **51% faster** |

### Total Latency per Tool Type

| Tool | Original Total | Optimized Total | Improvement |
|------|----------------|-----------------|-------------|
| **Bash** | 690ms | **264ms** | **62% reduction** |
| **Read/Edit/Write** | 727ms | **256ms** | **65% reduction** |

### Target Achievement

- **Original Target:** <150ms per tool call
- **Actual Achieved:** ~250-265ms per tool call
- **Status:** Significant improvement; further optimization possible with compiled hooks

---

## Deployment Instructions

### Quick Deployment (Swap Hooks)

```bash
# Backup originals
cd ~/.claude/hooks
for f in audit-pretool audit-posttool guard-bash guard-files; do
    cp "${f}.sh" "${f}.sh.backup-$(date +%Y%m%d)"
done

# Deploy optimized versions
cp audit-pretool-fast.sh audit-pretool.sh
cp audit-posttool-fast.sh audit-posttool.sh
cp guard-bash-fast.sh guard-bash.sh
cp guard-files-fast.sh guard-files.sh

echo "Optimized hooks deployed"
```

### Add Cleanup Cron Job

```bash
# Add to crontab (runs at 3 AM daily)
(crontab -l 2>/dev/null | grep -v 'hook-cleanup.sh'; echo "0 3 * * * ~/.claude/scripts/hook-cleanup.sh >> ~/.claude/logs/cleanup.log 2>&1") | crontab -

# Verify
crontab -l | grep hook-cleanup
```

### Rollback (If Issues)

```bash
cd ~/.claude/hooks
for f in audit-pretool audit-posttool guard-bash guard-files; do
    BACKUP=$(ls -t "${f}.sh.backup-"* 2>/dev/null | head -1)
    if [[ -f "$BACKUP" ]]; then
        cp "$BACKUP" "${f}.sh"
        echo "Restored $f from $BACKUP"
    fi
done
```

---

## Optimized Files Created

| File | Path |
|------|------|
| audit-pretool-fast.sh | `/home/aadel/.claude/hooks/audit-pretool-fast.sh` |
| audit-posttool-fast.sh | `/home/aadel/.claude/hooks/audit-posttool-fast.sh` |
| guard-bash-fast.sh | `/home/aadel/.claude/hooks/guard-bash-fast.sh` |
| guard-files-fast.sh | `/home/aadel/.claude/hooks/guard-files-fast.sh` |
| hook-cleanup.sh | `/home/aadel/.claude/scripts/hook-cleanup.sh` |

---

## Next Steps for Further Optimization

1. **Compiled Hook Daemon** - Rewrite in Go/Rust with Unix socket for <10ms execution
2. **SQLite Audit Log** - Replace JSONL with SQLite WAL mode for faster appends
3. **Shared Memory Buffer** - Use tmpfs/ramdisk for intermediate logging
4. **Hook Caching** - Cache security pattern checks for repeated commands

---

Ahmed Adel Bakr Alderai
