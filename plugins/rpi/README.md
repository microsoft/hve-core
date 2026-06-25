<!-- markdownlint-disable-file -->
# RPI Skills

Skill-forward Research, Plan, Implement, and Review entry points with an umbrella RPI skill and existing subagent dispatch.

## Overview

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

## Install

```bash
copilot plugin install rpi@hve-core
```

## Agents

| Agent                    | Description                                                                                                                              |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| researcher-subagent      | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                              |
| plan-validator           | Validates implementation plans against research documents with severity-graded findings                                                  |
| phase-implementor        | Executes a single implementation phase from a plan with full codebase access and change tracking                                         |
| implementation-validator | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings |
| rpi-validator            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase                  |

## Instructions

| Instruction                   | Description                                                                                                                                 |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| copilot-tracking.instructions | Shared .copilot-tracking conventions for intermediate artifacts, file paths, and subagent handoffs across the RPI and prompt-builder skills |

## Skills

| Skill         | Description                                                                                                                                                                                                                             |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-quick     | Umbrella RPI playbook that sequences Research, Plan, Implement, Review, and Discover for one-shot task execution with quality gates.                                                                                                    |
| rpi-research  | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first. |
| rpi-plan      | Create implementation-ready planning artifacts and validation evidence for RPI tasks.                                                                                                                                                   |
| rpi-implement | Execute approved implementation phases, update tracking artifacts, and hand off review-ready results.                                                                                                                                   |
| rpi-review    | Review-only RPI playbook that validates implementation evidence, checks phase completion, and closes the loop with explicit next steps. Use when the user needs review coverage or acceptance evidence.                                 |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

