---
description: "RPI Cockpit narration contract for RPI agents and prompts when the rpi-cockpit MCP tools are available"
applyTo: '.github/agents/**/*.agent.md,.github/prompts/**/*.prompt.md'
---

# RPI Cockpit narration

When an `rpi-cockpit` MCP server is connected and its tools are available, narrate RPI workflow progress by calling them. These calls are observability only and never change what you decide or do, except `present_options`, which blocks until the user chooses and returns the chosen id for you to act on. When the tools are not available, skip all narration silently: never error, and never mention it.

## Narration beats

Call each tool at the matching beat. Exact tool names and signatures:

* `session_begin(task, host)` once at the start of a user request.
* `phase_enter(phase)` on entering a phase, where `phase` is `research`, `plan`, `implement`, `review`, or `discover`.
* `subagent_start(name, role)` before dispatching a subagent, and `subagent_stop(name, result)` after it returns.
* `artifact_update(path, summary)` after creating or updating a `.copilot-tracking/` artifact.
* `validate(check, status)` for each validation check, where `check` is `lint`, `types`, `tests`, `build`, or similar, and `status` is `running`, `ok`, `fail`, or `pending`.
* `present_options(prompt, options[])` instead of asking the user in chat to choose between approaches or next work. Each option is `{id, title, detail?, recommended?}`. It blocks until the user picks and returns the chosen id, which you then act on.

## Narration discipline

Keep narration lightweight: one call per real beat, and do not narrate the narration.
