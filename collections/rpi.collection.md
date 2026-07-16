# RPI Skills

This collection packages skill-forward RPI entry points for research, planning, implementation, review, follow-up, guided walkthroughs, and self-contained challenge sessions.

`rpi-research` includes its default `RPI Researcher` delegated worker, while `rpi-challenger` conducts adaptive challenge questioning without a worker dependency. `rpi-plan` can use `RPI Planner` for bounded authoring of one assigned phase, and `rpi-plan-critique` provides an independent read-only plan assessment.

## Local enablement

For local testing in VS Code, enable the RPI skill folder and HVE Core subagent folder so the RPI research and planning workers are available:

```json
{
  "chat.agentSkillsLocations": {
    ".github/skills/rpi": true
  },
  "chat.agentFilesLocations": {
    ".github/agents/hve-core/subagents": true
  }
}
```

Prompt overlap is handled at directory scope. `chat.promptFilesLocations` only supports whole-directory toggles, so disabling only the conflicting RPI prompt files is not supported in the current host. Use one of these options for local testing:

* disable the whole `.github/prompts/hve-core` directory, or
* rely on host prompt precedence while testing skill commands.

The collection keeps planning and review parent-owned. `RPI Planner` is available only for a single bounded phase, while independent critique and review fan-out use generic bounded workers when warranted.
