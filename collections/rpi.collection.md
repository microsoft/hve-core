# RPI Skills

This collection packages the `rpi-research` skill, Task Researcher, and skill-forward RPI entry points for research, planning, implementation, review, and guided walkthroughs.

## Local enablement

For local testing in VS Code, enable the RPI skill folder, Task Researcher agent folder, and existing subagent folder in your workspace settings:

```json
{
  "chat.agentSkillsLocations": {
    ".github/skills/rpi": true
  },
  "chat.agentFilesLocations": {
    ".github/agents/hve-core": true,
    ".github/agents/hve-core/subagents": true
  }
}
```

Prompt overlap is handled at directory scope. `chat.promptFilesLocations` only supports whole-directory toggles, so disabling only the conflicting RPI prompt files is not supported in the current host. Use one of these options for local testing:

* disable the whole `.github/prompts/hve-core` directory, or
* rely on host prompt precedence while testing skill commands.

The collection intentionally delegates phase work to the existing RPI subagents so the skills stay compact and the packaging model remains additive.
