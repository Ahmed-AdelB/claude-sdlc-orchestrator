# Progress File Format Specification

**File:** `claude-progress.txt` (or `*.md`)
**Purpose:** Tracks the state of autonomous sessions to ensure continuity across restarts and context resets.

## Structure

The file uses a Markdown-based format with key-value headers and lists.

### Header Section
Must contain the following fields:
- **Last Updated:** ISO 8601 Timestamp (e.g., `2026-01-04T05:09:07+00:00`)
- **Session ID:** Unique identifier for the current/last session.
- **Checkpoint Reason:** Why the progress was saved (e.g., `manual`, `context_limit`, `task_complete`).

### Sections

#### 1. `### Completed Tasks:`
A bulleted list of tasks completed in the current or previous sessions.
- Format: `- Task description`

#### 2. `### Current State:`
Key-value pairs describing the git and workspace state.
- **Active branch:** The git branch currently checked out.
- **Uncommitted changes:** Number or description of modified files.
- **Last checkpoint:** Timestamp of the last verified state.

#### 3. `### Token Usage:`
(Optional) Stats on token consumption.

#### 4. `### Next Actions:`
A bulleted list of immediate next steps for the agent to pick up.
- Format: `- [ ] Action item`

## Example

```markdown
# Session Progress Log
## Last Updated: 2026-01-04T12:00:00+00:00
## Session ID: tri-20260104-abc
## Checkpoint Reason: context_limit

### Completed Tasks:
- Created initial directory structure
- Configured logging

### Current State:
- Active branch: main
- Uncommitted changes: 2
- Last checkpoint: 2026-01-04T11:55:00+00:00

### Next Actions:
- [ ] Implement user auth
- [ ] Write tests for auth
```
