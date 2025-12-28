---
description: Delegate large-context analysis to Gemini (gemini-ask).
---

When invoked:
1) Treat any arguments after the slash command as the task description.
2) If no task is provided, ask for one.
3) Run: `gemini-ask "<task>"`.
4) If specific files are referenced, pass them via `-f`.
5) Summarize the output and incorporate it into the response.
