<!-- markdownlint-disable-file -->
# RPI Skills

Skill-forward Research, Plan, Implement, and Review entry points with an umbrella RPI skill and existing subagent dispatch.

## Overview

This collection packages the skill-forward RPI entry points for research, planning, implementation, and review. It keeps the current RPI agent-first workflow intact while making the five new phase skills and the umbrella `rpi` skill available as standalone, packageable entry points.

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

| Instruction                    | Description                                                                                       |
|--------------------------------|---------------------------------------------------------------------------------------------------|
| rpi-skill-forward.instructions | Shared guidance for RPI skill-forward artifacts, subagent dispatch, and tracking-file conventions |

## Skills

| Skill            | Description                                                                                                                                                                                                              |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| task-researcher  | Research-only RPI playbook that gathers task evidence, writes .copilot-tracking/research/ notes, and returns compact synthesis before planning. Use when the user needs evidence, alternatives, or task framing first.   |
| task-planner     | Planning-only RPI playbook that turns research into a concrete plan, details notes, and planning log, then validates the plan before implementation. Use when the user needs scope, sequencing, and validation evidence. |
| task-implementor | Implementation-only RPI playbook that applies the approved plan, updates .copilot-tracking/changes/, and dispatches validation when the phase is blocked or needs review. Use when the user needs bounded code changes.  |
| task-reviewer    | Review-only RPI playbook that validates implementation evidence, checks phase completion, and closes the loop with explicit next steps. Use when the user needs review coverage or acceptance evidence.                  |
| rpi              | Umbrella RPI playbook that sequences research, planning, implementation, and review for one-shot task execution with explicit stop rules and phased handoffs.                                                            |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

