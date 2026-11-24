---
title: Creating Custom Agents
description: Build specialized agents with tool lists, preloaded skills, and subagent delegation for your team
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - agents
  - custom agents
  - subagents
  - skills
  - copilot
estimated_reading_time: 8
---

## Agent Architecture

Agents are specialized Copilot configurations that define a role, the tools it can use, and the protocol it follows. A user selects an agent in the agent picker, or a parent agent starts it as a subagent. Agents work with the other artifact types:

* Skills carry reusable workflows, shared protocols, and slash commands. An agent preloads the skills it needs at start and activates others by name.
* Instructions apply their conventions once the agent reads or edits a file that matches their `applyTo` glob.
* Subagents take isolated subtasks that a parent dispatches through the `task` tool.

An agent file (`.agent.md`) contains YAML frontmatter and a Markdown body. The frontmatter declares metadata, the tool list, preloaded skills, and invocation controls. The body defines the agent's protocol: its purpose, steps or phases, the subagents it uses, and its response format.

A minimal agent requires only `name` and `description` in frontmatter:

```yaml
---
name: Code Review Assistant
description: "Reviews pull request changes for style, correctness, and security concerns - Brought to you by contoso/engineering"
---
```

More complex agents add `tools`, `skills`, `model`, and invocation fields such as `user-invocable` and `disable-model-invocation`. See the [Frontmatter Reference](#frontmatter-reference) section for the complete field set.

Agent files live in `.github/agents/{package-id}/`. Subagents go in a `subagents/` subdirectory within their package folder. Copilot discovers `.github/agents` at any folder depth, so these folders need no settings:

```text
.github/agents/
├── contoso/
│   ├── code-reviewer.agent.md
│   └── subagents/
│       └── security-checker.agent.md
```

## Loading Skills and Instructions

The Copilot harness does not load `#file:` directives, so an agent reaches skills and instructions by name:

* List a skill under `skills:` when the agent needs it from the start. Copilot injects the skill's `SKILL.md` body when the session starts. Files that the skill links load only when the agent reads them.
* Activate any other skill by name when the workflow reaches it. The agent needs `skill` in its `tools` list to do this.
* Read an instruction file by name when the agent depends on its rules before it touches a matching file. Copilot applies an instruction with `applyTo` only after a matching file is read or edited.

```markdown
---
name: Contoso Release Planner
description: "Plans Contoso service releases against the release checklist - Brought to you by contoso/engineering"
tools:
  - read
  - edit
  - search
  - skill
  - ask_user
skills:
  - contoso-release-conventions
---

# Contoso Release Planner

At session start, activate the `contoso-risk-register` skill. Before you edit
a release plan, read `contoso-release.instructions.md`.
```

HVE Core's ADR Creator follows the same pattern. It preloads `disclaimer-language`, activates the `adr-author` skill, and reads `adr-standards.instructions.md` when it enters a phase that needs those rules.

## Improving an Existing Agent

Walk through improving the current RPI Researcher subagent using `hve-builder`.

### Step 1: Identify the target and requirements

```text
RPI Researcher target: .github/agents/hve-core/subagents/rpi-researcher.agent.md
Requirements: Preserve its read-only, return-only contract, the source-pointer
return shape, and the structured response contract.
```

### Step 2: Run HVE Builder in improve mode

```text
Use hve-builder with mode=improve and
targets=.github/agents/hve-core/subagents/rpi-researcher.agent.md. Preserve its
existing capability-bearing frontmatter and the rpi-research extension contract.
```

HVE Builder reads the known target and applicable conventions, confirms the
write boundary, then authors within the current `rpi-research` architecture.

### Step 3: Review the evidence

Review HVE Builder's review verdict, host validation result, and overall
outcome. Address actionable findings before committing.

> [!TIP]
> Use `hve-builder` review mode for read-only assessment. Use improve mode only
> when source changes are approved.

### Consolidating Agents

Use `hve-builder` refactor mode to merge overlapping agents or clean up related
agent files without intentionally changing behavior:

```text
Use hve-builder with mode=refactor,
targets=.github/agents/contoso/*.agent.md, and requirements="merge overlapping
review agents into a single orchestrator without changing supported behavior".
```

## Subagent Patterns

Subagents handle specialized subtasks that a parent agent delegates. The parent starts a subagent with the `task` tool, which selects the subagent by its `name` value. The parent's body names each subagent it uses, so nesting depth under `.github/agents` does not matter. A parent with a `tools` list needs `agent` in it.

Set `disable-model-invocation: true` on a user-selected orchestrator so that other agents cannot start it as a subagent. The setting does not stop the orchestrator from dispatching its own subagents:

```yaml
---
name: Full Stack Reviewer
description: "Orchestrates frontend and backend code review - Brought to you by contoso/engineering"
disable-model-invocation: true
tools:
  - read
  - search
  - agent
  - ask_user
---
```

The body names each subagent and says what every dispatch carries:

```markdown
## Delegation

Dispatch Contoso Security Checker for each changed service and Contoso Style
Validator for the frontend files. Include the diff path, the review checklist,
and the findings format in each dispatch.
```

Subagent files set `user-invocable: false` to stay out of the agent picker:

```yaml
---
name: Contoso Security Checker
description: "Scans code for common security vulnerabilities - Brought to you by contoso/engineering"
user-invocable: false
tools:
  - read
  - search
  - skill
skills:
  - contoso-security-rules
---
```

A subagent receives no repository instructions, so its rules come from its own body, a preloaded skill such as `contoso-security-rules`, or the parent's dispatch prompt. Subagents never receive `ask_user`, so write a subagent to return open questions to its parent.

### When to use subagents vs. inline logic

* Delegate a subtask that benefits from isolation, parallel runs, a fresh context, or a different model, such as one with its own tool needs or one that returns a structured output the parent consumes.
* Keep logic inline when the task is a simple step within the parent's protocol and does not benefit from isolation.
* Leave `agent` out of a subagent's `tools` list when it must not dispatch further subagents.

## Tool Restrictions

The `tools:` frontmatter field limits which tools an agent can access. Omitting `tools:`, or giving an empty list, grants every available tool. A list with entries restricts the agent to the tools it names:

```yaml
tools:
  - read
  - search
  - skill
```

Copilot recognizes these names:

| Name                      | Grants                                            |
|---------------------------|---------------------------------------------------|
| `read`                    | Reading files                                     |
| `edit`                    | Creating and editing files                        |
| `search`                  | Searching the workspace                           |
| `execute`                 | Running shell commands                            |
| `web`                     | Web access                                        |
| `agent`                   | Dispatching subagents through the `task` tool     |
| `skill`                   | Activating skills by name                         |
| `ask_user`                | Asking the user questions; subagents never get it |
| `server/tool`, `server/*` | One MCP tool, or every tool from an MCP server    |

Copilot ignores names it does not recognize, so tool names from VS Code's older Local harness, such as `read_file` or `runSubagent`, grant nothing. Replace them with the names above.

Tool restrictions serve two purposes:

* Agents with read-only roles cannot modify files, run terminal commands, or access external services
* Restricting irrelevant tools reduces noise. A documentation agent does not need terminal access.

> [!IMPORTANT]
> A `tools` list is an allowlist. Leave `edit` and `execute` out of a read-only agent so it cannot change files or run commands, and leave `agent` out of an agent that should not delegate.

## Mode-Based Workflows

Agents support both conversational and autonomous modes. The mode is conveyed through protocol structure rather than a dedicated frontmatter field.

Conversational agents use phase-based protocols for multi-turn interactions. Users guide the conversation through distinct stages, and the agent lists `ask_user` in its tools so it can ask the user questions:

```markdown
## Phases

### Phase 1: Requirements Gathering

Ask the user about project constraints, target audience,
and success criteria.

### Phase 2: Design Proposal

Present architecture options based on gathered requirements.
Wait for user feedback before proceeding.

### Phase 3: Implementation Plan

Generate a step-by-step plan incorporating user decisions.
```

Autonomous agents use step-based protocols for bounded task execution. The agent receives instructions and completes the work with minimal interaction:

```markdown
## Required Steps

### Step 1: Analyze Input

Read the provided files and extract requirements.

### Step 2: Generate Output

Create the requested artifacts based on analysis.

### Step 3: Validate

Run validation commands and report results.
```

HVE Core includes several mode-based agents you can study as patterns: RPI Agent for lifecycle coordination, PR analyzers for autonomous review, and Design Thinking coaches for facilitated multi-turn sessions.

### Pointing to the Next Step

Copilot has no handoff buttons, so an agent's body tells the user where to go next. Name the skill to invoke or the agent to switch to:

```markdown
## Completion

When the user approves the design, tell them to switch to the Contoso Release
Planner agent to schedule the work, or to run `/release-notes` after it ships.
```

In HVE Core, the RPI Agent coordinates phase changes itself, and users can also move between phases by invoking the next skill, such as `/rpi-plan`.

## Role Scenarios

**Northwind Traders' architect** creates a design-review agent that evaluates proposed system changes against their microservices architecture standards. The agent reads architecture decision records, checks for service boundary violations, and produces a compatibility assessment. Its `tools` list holds only `read` and `search`, since it should never modify source code.

**Woodgrove Bank's security lead** builds an authentication audit agent that scans OAuth configurations, token handling patterns, and session management code. The agent delegates credential scanning to a subagent and produces a consolidated report with severity ratings.

**Tailspin Toys' engineering manager** authors a PR triage agent that categorizes incoming pull requests by area (frontend, backend, infrastructure), estimates review complexity, and suggests appropriate reviewers based on file ownership patterns.

For full frontmatter schema, naming conventions, and contribution requirements, see [Contributing: Custom Agents](../contributing/custom-agents).

## Frontmatter Reference

Agent frontmatter supports these fields:

| Field                      | Type    | Required | Purpose                                                             |
|----------------------------|---------|----------|---------------------------------------------------------------------|
| `name`                     | string  | Yes      | Human-readable name shown in the agent picker and used for dispatch |
| `description`              | string  | Yes      | One-line purpose describing what the agent does and when to use it  |
| `tools`                    | array   | No       | Tool names the agent can use; omit for every tool                   |
| `skills`                   | array   | No       | Skills whose `SKILL.md` bodies load when the agent starts           |
| `model`                    | string  | No       | One preferred model; omit to inherit                                |
| `reasoning-effort`         | string  | No       | `low`, `medium`, `high`, `xhigh`, or `max` for the agent's model    |
| `user-invocable`           | boolean | No       | Set `false` for subagents not meant for direct invocation           |
| `disable-model-invocation` | boolean | No       | Set `true` so other agents cannot start this agent as a subagent    |
| `target`                   | string  | No       | Host execution target, `vscode` or `github-copilot`                 |

Agents also accept `hooks` for preview lifecycle hooks, and `mcp-servers` for MCP server declarations, which VS Code does not forward to Copilot sessions. The Copilot harness does not support `handoffs`, `agents`, or `argument-hint` on agents, and `npm run lint:frontmatter` rejects them. Name the subagents to delegate to, and the next agent or skill for the user, in the body.

### model

Specifies a preferred AI model as a single string. When omitted, a subagent inherits the invoking parent's model, and a directly invoked agent uses the current session or model-picker selection.

```yaml
# Single model
model: GPT-6 Sol (copilot)
```

The [official custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration) defines `model` as `string` for GitHub.com, the Copilot CLI, and supported IDEs, and HVE Core's frontmatter schema accepts only a string.
Copilot CLI versions before the fix for [github/copilot-cli#2133](https://github.com/github/copilot-cli/issues/2133) rejected an array of fallback models with `model: Expected string, received array` and dropped the agent, so a single value is the portable choice.

Omit `model` unless the agent needs a stable Medium or Low profile; High-responsibility agents inherit the user's selection. Low, such as `GPT-6 Luna (copilot)`, fits bounded, literal, mechanical execution, and Medium, such as `GPT-6 Sol (copilot)`, fits semantic discovery, authoring, or calibrated review. Resolve current model names from GitHub's Copilot model documentation rather than copying them from another agent.
Accepted models are those in `scripts/linting/model-catalog.json` whose provider appears in `providerAllowlist` and whose status is `ga` or `preview`. Run `npm run lint:models` to validate.

`reasoning-effort` sets the reasoning effort for the agent's model. Omit it to let a value from the dispatcher, the session, or the model default apply.

### description

Write a concise, single-sentence purpose statement that a parent or user can use to decide when to invoke the agent:

```yaml
description: "Reviews code changes for API standards conformance"
```

### tools

Tool values use the names listed under [Tool Restrictions](#tool-restrictions). MCP tools use the `server/tool` form, such as `ado/wit_get_work_item`, and `server/*` grants every tool from one server, such as `workiq/*`:

```yaml
tools:
  - read
  - search
  - skill
  - ado/wit_get_work_item
  - workiq/*
```

The set of available tools evolves with GitHub Copilot. For the current alias list, see the tools section of the [custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration).

### skills

Lists the skills to preload when the agent starts. Each entry is a skill's folder name in lowercase kebab-case. Copilot injects each `SKILL.md` body into the agent's context at session start, and files the skill links load only when the agent reads them:

```yaml
skills:
  - disclaimer-language
  - untrusted-content-boundary
```

Preload only the skills the agent needs on every run. Activate the rest by name in the body, which requires `skill` in `tools`.

### disable-model-invocation

Set to `true` on a user-selected orchestrator so that other agents cannot start it as a subagent. HVE Core sets it on the RPI Agent, Code Review, and Documentation agents. It does not stop the agent from dispatching its own subagents:

```yaml
disable-model-invocation: true
```

### user-invocable

Set to `false` for subagents intended only for programmatic invocation by parent agents. These agents do not appear in the user-facing agent picker:

```yaml
user-invocable: false
```

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
