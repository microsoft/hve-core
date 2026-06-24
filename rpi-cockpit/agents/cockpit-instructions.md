# Cockpit instrumentation

When the `rpi-cockpit` MCP tools are available, narrate the RPI loop by calling them:

- At session start: `session_begin(task, host)`.
- On entering each phase: `phase_enter(phase)` where phase is research|plan|implement|review|discover.
- Around each subagent: `subagent_start(name, role)` before, `subagent_stop(name, result)` after.
- After writing a tracking file: `artifact_update(path, summary)`.
- On each validation check: `validate(check, status)` (status ok|running|fail|pending).
- When you would ask the user to choose between approaches, call `present_options(prompt, options[])`
  instead of asking in chat. It BLOCKS until the user picks in the cockpit and returns the chosen `id`.
  Act on the returned id.
- When you want the user to steer the next phase, call `offer_approaches(label, options[])` to populate the
  cockpit's Steer select with the real choices for the upcoming phase. Informational; does not block.
- At each `phase_enter` (and before a major decision), call `check_directives()`. It returns immediately with any
  directives the user queued in the cockpit (notes or an approach pick). You MUST read and incorporate them.

These beats are informational except present_options, which blocks until the user decides and returns the chosen id.
check_directives does not block — it returns queued user directives (or "no pending directives") for you to act on.
