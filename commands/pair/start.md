---
name: pair:start
scope: command
version: 1.0.0
summary: Start a pair-programming session with state tracking and continuous suggestions.
args:
  - name: file
    type: string
    required: false
    description: Path to the current file (defaults to active editor file).
  - name: cursor
    type: string
    required: false
    description: Cursor position as line:column (defaults to editor cursor).
  - name: verbosity
    type: string
    required: false
    default: balanced
    enum: ["brief", "balanced", "verbose"]
    description: Controls how much explanation is provided.
  - name: suggestions
    type: string
    required: false
    default: on
    enum: ["on", "off"]
    description: Enables continuous suggestion mode.
  - name: track
    type: string
    required: false
    default: on
    enum: ["on", "off"]
    description: Track and summarize changes for review.
  - name: agent
    type: string
    required: false
    default: pair-programmer
    description: Agent to coordinate with for pairing.
---

# /pair:start

Starts a structured pair-programming session with context parsing, session state tracking, continuous suggestions, verbosity control, and change tracking.

## Usage

/pair:start [--file path] [--cursor line:col] [--verbosity brief|balanced|verbose] [--suggestions on|off] [--track on|off] [--agent name]

## Arguments

- file: Path to the current file. If omitted, use the active editor file.
- cursor: Cursor position as line:column. If omitted, use the editor cursor.
- verbosity: Controls explanation depth.
- suggestions: Enables continuous suggestion mode.
- track: Enables change tracking and review summary.
- agent: Pair-programmer agent name or identifier.

## Process

1. Parse context
   - Resolve file and cursor (from args or editor state).
   - Read a focused window around the cursor (e.g., +/- 200 lines).
   - Detect language, framework, and project conventions.
2. Initialize session state
   - Create a session id and start timestamp.
   - Record file, cursor, and detected stack.
   - Initialize a change log (diff-based or note-based).
3. Enable continuous suggestion mode
   - Provide incremental suggestions as the user types/edits.
   - Highlight potential issues, edge cases, and tests.
   - Respect the selected verbosity level.
4. Configure verbosity and explanation level
   - brief: short directives and minimal rationale.
   - balanced: concise rationale and key tradeoffs.
   - verbose: detailed reasoning and alternatives.
5. Track changes for review
   - Record edits with timestamps and short descriptions.
   - Summarize changes when requested or at session end.

## Integration: pair-programmer agent

- Route ideation and review tasks to the pair-programmer agent.
- Maintain a shared session log:
  - current file and cursor
  - active goals and constraints
  - change list and pending review items
- The agent should:
  - propose next steps or patches
  - ask clarifying questions when context is unclear
  - flag risks, regressions, or missing tests

## Output

- Session started message with id and active settings.
- Ongoing suggestions aligned with verbosity.
- Change log entries as edits occur.
- Review summary on request.

## Notes

- This command does not apply edits by itself; it coordinates the pairing workflow.
- Use /pair:stop to end the session and emit a final review summary.
