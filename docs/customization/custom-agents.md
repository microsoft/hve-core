---
title: Creating Custom Agents
description: Build specialized agents with tool restrictions, subagent delegation, and mode-based workflows for your team
author: Microsoft
ms.date: 2026-07-15
ms.topic: how-to
keywords:
  - agents
  - custom agents
  - subagents
  - copilot
estimated_reading_time: 7
---

## Agent Architecture

Agents are specialized Copilot configurations that define behavior, available tools, and domain-specific instructions for complex workflows. In the artifact hierarchy, agents sit between prompts (single-shot tasks) and skills (knowledge packages):

* Prompts invoke agents for one-shot execution
* Agents orchestrate multi-turn conversations or autonomous task execution
* Instructions provide scoped guidance that agents inherit automatically
* Skills supply domain knowledge that agents reference on demand

An agent file (`.agent.md`) contains YAML frontmatter and a Markdown body. The frontmatter declares metadata, optional tool restrictions, subagent dependencies, and handoff configurations. The body defines the agent's protocol: its purpose, steps or phases, and response format.

A minimal agent requires only `name` and `description` in frontmatter:

```yaml
---
name: Code Review Assistant
description: "Reviews pull request changes for style, correctness, and security concerns - Brought to you by contoso/engineering"
---
```

More complex agents add `tools`, `agents`, `handoffs`, and `disable-model-invocation` fields. See the [Frontmatter Reference](#frontmatter-reference) section for the complete field set.

Agent files live in `.github/agents/{collection-id}/`. Subagents go in a `subagents/` subdirectory within their collection folder:

```text
.github/agents/
├── contoso/
│   ├── code-reviewer.agent.md
│   └── subagents/
│       └── security-checker.agent.md
```

## Improving an Existing Agent

Walk through improving the current RPI Planner subagent using `hve-builder`.

### Step 1: Identify the target and requirements

```text
RPI Planner target: .github/agents/hve-core/subagents/rpi-planner.agent.md
Requirements: Preserve bounded phase ownership, marker-based addressing, and
the structured response contract.
```

### Step 2: Run HVE Builder in improve mode

```text
Use hve-builder with mode=improve and
targets=.github/agents/hve-core/subagents/rpi-planner.agent.md. Preserve its
existing capability-bearing frontmatter and the rpi-plan phase contract.
```

HVE Builder reads the known target and applicable conventions, confirms the
write boundary, then authors within the current `rpi-plan` architecture.

### Step 3: Review the evidence

Review HVE Builder's independent static verdict, behavior-test disposition,
host validation result, and overall outcome. Address actionable findings before
committing.

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

Subagents handle specialized subtasks that a parent agent delegates. The parent declares subagent dependencies in its `agents:` frontmatter using human-readable names. Orchestrator agents that only delegate work set `disable-model-invocation: true`:

```yaml
---
name: Full Stack Reviewer
description: "Orchestrates frontend and backend code review - Brought to you by contoso/engineering"
disable-model-invocation: true
agents:
  - Contoso Security Checker
  - Contoso Style Validator
---
```

Agents that perform direct work alongside subagent delegation omit `disable-model-invocation` and optionally restrict their own tools:

```yaml
---
name: Full Stack Reviewer
description: "Orchestrates frontend and backend code review - Brought to you by contoso/engineering"
agents:
  - Contoso Security Checker
  - Contoso Style Validator
tools:
  - read
  - search
  - web
---
```

The parent references subagents using glob paths so resolution works regardless of nesting depth:

```markdown
Delegate security analysis to the security checker subagent
at `.github/agents/**/security-checker.agent.md`.
```

Subagent files include `user-invocable: false` in frontmatter to prevent direct user invocation:

```yaml
---
name: Contoso Security Checker
description: "Scans code for common security vulnerabilities - Brought to you by contoso/engineering"
user-invocable: false
tools:
  - read_file
  - grep_search
---
```

### When to use subagents vs. inline logic

* Use subagents when the subtask has its own distinct tool requirements or produces a structured output that the parent consumes.
* Keep logic inline when the task is a simple step within the parent's protocol and does not benefit from isolation.
* Subagents cannot invoke their own subagents. Only the parent agent orchestrates subagent calls.

## Tool Restrictions

The `tools:` frontmatter field limits which tools an agent can access. Omitting `tools:` grants access to all available tools. Specifying a list restricts the agent to only those tools.

```yaml
tools:
  - read_file
  - grep_search
  - semantic_search
```

Tool restrictions serve two purposes:

* Agents with read-only roles cannot modify files, run terminal commands, or access external services
* Restricting irrelevant tools reduces noise. A documentation agent does not need terminal access.

> [!IMPORTANT]
> Agents that modify files or run commands require explicit tool grants. Read-only agents should omit tools like `run_in_terminal`, `replace_string_in_file`, and `create_file` to enforce safe operation.

## Mode-Based Workflows

Agents support both conversational and autonomous modes. The mode is conveyed through protocol structure rather than a dedicated frontmatter field.

**Conversational agents** use phase-based protocols for multi-turn interactions. Users guide the conversation through distinct stages:

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

**Autonomous agents** use step-based protocols for bounded task execution. The agent receives instructions and completes the work with minimal interaction:

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

## Role Scenarios

**Northwind Traders' architect** creates a design-review agent that evaluates proposed system changes against their microservices architecture standards. The agent reads architecture decision records, checks for service boundary violations, and produces a compatibility assessment. It restricts tools to read-only operations since it should never modify source code.

**Woodgrove Bank's security lead** builds an authentication audit agent that scans OAuth configurations, token handling patterns, and session management code. The agent delegates credential scanning to a subagent and produces a consolidated report with severity ratings.

**Tailspin Toys' engineering manager** authors a PR triage agent that categorizes incoming pull requests by area (frontend, backend, infrastructure), estimates review complexity, and suggests appropriate reviewers based on file ownership patterns.

For full frontmatter schema, naming conventions, and contribution requirements, see [Contributing: Custom Agents](../contributing/custom-agents).

## Frontmatter Reference

Agent frontmatter supports these fields:

| Field                      | Type           | Required | Purpose                                                                          |
|----------------------------|----------------|----------|----------------------------------------------------------------------------------|
| `name`                     | string         | Yes      | Human-readable name shown in the agent picker                                    |
| `description`              | string         | Yes      | One-line purpose with attribution suffix                                         |
| `tools`                    | array          | No       | Restrict available tools; omit for full access                                   |
| `agents`                   | array          | No       | Human-readable names of subagent dependencies                                    |
| `handoffs`                 | array          | No       | Structured transitions to other agents                                           |
| `model`                    | string / array | No       | Preferred model(s); array tried in order until one is available; omit to inherit |
| `disable-model-invocation` | boolean        | No       | Set `true` for orchestrators that only delegate to subagents                     |
| `user-invocable`           | boolean        | No       | Set `false` for subagents not meant for direct invocation                        |

### model

Specifies a preferred AI model as a single string or prioritized fallback array. The system tries each entry in order until one is available. When omitted, the agent inherits the parent conversation model.

```yaml
# Single model
model: Claude Sonnet 4.6 (copilot)
```

```yaml
# Prioritized fallback array
model:
  - Claude Haiku 4.5 (copilot)
  - GPT-5.4 mini (copilot)
```

Subagents that perform read-only or validation tasks should use fast-tier models for cost optimization. Accepted models are those in `scripts/linting/model-catalog.json` whose provider appears in `providerAllowlist` and whose status is `ga` or `preview`. Run `npm run lint:models` to validate references.

### description

Include attribution to identify the source organization or repository:

```yaml
description: "Reviews code for API standards - Brought to you by contoso/engineering"
```

### tools

Tool values support four naming patterns:

| Pattern           | Example                                       |
|-------------------|-----------------------------------------------|
| Individual tools  | `read_file`, `grep_search`, `semantic_search` |
| Category          | `read`, `search`, `edit`, `web`, `agent`      |
| Category-specific | `edit/createFile`, `execute/runInTerminal`    |
| Wildcard          | `github/*`, `ado/*`                           |

The set of available tools evolves with GitHub Copilot and VS Code. For the authoritative, current list, see the official [VS Code custom agents documentation](https://code.visualstudio.com/docs/copilot/customization/custom-agents). To invoke a granted tool from the agent body, use the `#tool:` reference syntax (for example, `#tool:codebase`); see [Contributing: Custom Agents](../contributing/custom-agents) for details.

### agents

Declares subagent dependencies using their human-readable `name` values. Reference subagents in the body using glob paths so resolution works regardless of nesting depth:

```yaml
agents:
  - Contoso Research Analyst
  - RPI Planner
```

```markdown
Activate `rpi-research` for open-ended or decision-critical research. Dispatch
the RPI Planner only from the canonical `rpi-plan` workflow when bounded phase
authoring is required.
```

### handoffs

Defines structured transitions between agents. Each entry specifies a label (shown to the user), the target agent name, an optional prompt template, and whether to send the prompt automatically:

```yaml
handoffs:
  - label: "Coordinate RPI Work"
    agent: "RPI Agent"
    prompt: "Coordinate this task through the applicable RPI phases"
    send: true
```

### disable-model-invocation

Set to `true` for orchestrator agents that coordinate subagents without performing direct work themselves:

```yaml
disable-model-invocation: true
agents:
  - Contoso Security Checker
  - Contoso Style Validator
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
