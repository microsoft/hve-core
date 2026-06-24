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

These beats are informational except present_options, which blocks until the user decides and returns the chosen id for the agent to act on.
