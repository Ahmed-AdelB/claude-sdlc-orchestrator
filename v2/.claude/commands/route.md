---
description: Route a task to the best model with tri-agent-route.
---

When invoked:
1) Treat any arguments after the slash command as the task description.
2) If none are provided, ask the user for a concise task description.
3) Run: `tri-agent-route "<task>"`.
4) Summarize the output and recommend next steps.
