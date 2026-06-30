# RPI Skills

This collection packages the skill-forward RPI entry points for research, planning, implementation, and review. It keeps the current RPI agent-first workflow intact while making the slash-command family /rpi-quick, /rpi-research, /rpi-plan, /rpi-implement, and /rpi-review available as standalone packaged entry points.

## Local enablement

For local testing in VS Code, enable the new skill folder and the existing subagent folder in your workspace settings:

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
* rely on host prompt precedence until Phase 6 runtime validation confirms the final slash-command behavior.

The collection intentionally delegates phase work to the existing RPI subagents so the skills stay compact and the packaging model remains additive.
