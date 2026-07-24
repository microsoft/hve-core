<!-- markdownlint-disable-file -->
# RPI Skills

Skill-forward Research, Plan, Implement, Review, and Follow-up entry points with bounded planning and critique support.

## Overview

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

## Install

```bash
copilot plugin install rpi@hve-core
```

## Agents

| Agent          | Description                                                                                                                                           |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-researcher | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |
| rpi-planner    | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.     |

## Instructions

| Instruction                   | Description                                                                                    |
|-------------------------------|------------------------------------------------------------------------------------------------|
| copilot-tracking.instructions | Shared .copilot-tracking conventions for RPI, HVE Builder, and compatibility workflow evidence |

## Skills

| Skill             | Description                                                                                                                                                                                                                                                                                  |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-quick         | Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle.                                                                                                                                              |
| rpi-challenger    | Challenge a confirmed task, decision, plan, or artifact through adaptive skeptical questions. Use when you need to expose assumptions before acting.                                                                                                                                         |
| rpi-research      | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                      |
| rpi-plan          | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                        |
| rpi-plan-critique | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                     |
| rpi-implement     | Execute an approved RPI plan, preserve amendments, and record evidence-led changes. Use when implementation is ready to begin or resume.                                                                                                                                                     |
| rpi-review        | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                      |
| rpi-walkthrough   | Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

