---
title: Creating Custom Agents
description: Build specialized agents with tool restrictions, subagent delegation, and mode-based workflows for your team
author: Microsoft
ms.date: 2026-02-24
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

* **Prompts** invoke agents for one-shot execution
* **Agents** orchestrate multi-turn conversations or autonomous task execution
* **Instructions** provide scoped guidance that agents inherit automatically
* **Skills** supply domain knowledge that agents reference on demand

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

## Creating Your First Agent

Walk through creating a code review agent for Contoso's engineering team using Prompt Builder.

**Step 1:** Create the agent file at `.github/agents/contoso/code-reviewer.agent.md` with minimal frontmatter:

```yaml
---
name: Contoso Code Reviewer
description: "Reviews code changes for Contoso's TypeScript API standards - Brought to you by contoso/engineering"
---
```

**Step 2:** Use `/prompt-build` to generate the agent body. Provide existing agents as reference context with `files` and specify the target file with `promptFiles`:

```text
/prompt-build files=.github/agents/hve-core/implementation-validator.agent.md promptFiles=.github/agents/contoso/code-reviewer.agent.md
```

Prompt Builder analyzes the reference agents, generates the protocol body with purpose, steps, and response format, and validates the result against repository conventions.

**Step 3:** Evaluate the generated agent with `/prompt-analyze`:

```text
/prompt-analyze promptFiles=.github/agents/contoso/code-reviewer.agent.md
```

This produces a structured report covering purpose, capabilities, issues organized by severity, and an overall quality assessment. Address any critical or major findings before committing.

**Step 4:** Iterate with `/prompt-build` to apply fixes identified by the analysis:

```text
/prompt-build files=.github/agents/contoso/code-reviewer.agent.md promptFiles=.github/agents/contoso/code-reviewer.agent.md
```

When `promptFiles` points to an existing file, Prompt Builder refines it rather than starting from scratch.

> [!TIP]
> Run `/prompt-analyze` first to identify quality issues, then use `/prompt-build` to apply fixes. This two-step pattern produces consistent, well-structured agents.

**Step 5:** Invoke the agent in Copilot Chat by selecting it from the agent picker or referencing it by name.

### Consolidating Agents

Use `/prompt-refactor` to merge overlapping agents or clean up related agent files:

```text
/prompt-refactor promptFiles=.github/agents/contoso/*.agent.md requirements="merge overlapping review agents into a single orchestrator"
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

**When to use subagents vs. inline logic:**

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

* **Security**: Prevent agents from modifying files, running terminal commands, or accessing external services when their role is read-only.
* **Focus**: Reduce noise from irrelevant tool suggestions. A documentation agent does not need terminal access.

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

HVE Core includes several mode-based agents you can study as patterns: task planners for research-plan-implement workflows, PR analyzers for autonomous review, and design thinking coaches for facilitated multi-turn sessions.

## Role Scenarios

**Northwind Traders' architect** creates a design-review agent that evaluates proposed system changes against their microservices architecture standards. The agent reads architecture decision records, checks for service boundary violations, and produces a compatibility assessment. It restricts tools to read-only operations since it should never modify source code.

**Woodgrove Bank's security lead** builds an authentication audit agent that scans OAuth configurations, token handling patterns, and session management code. The agent delegates credential scanning to a subagent and produces a consolidated report with severity ratings.

**Tailspin Toys' engineering manager** authors a PR triage agent that categorizes incoming pull requests by area (frontend, backend, infrastructure), estimates review complexity, and suggests appropriate reviewers based on file ownership patterns.

For full frontmatter schema, naming conventions, and contribution requirements, see [Contributing: Custom Agents](../contributing/custom-agents.md).

## Frontmatter Reference

Agent frontmatter supports these fields:

| Field                      | Type    | Required | Purpose                                                      |
|----------------------------|---------|----------|--------------------------------------------------------------|
| `name`                     | string  | Yes      | Human-readable name shown in the agent picker                |
| `description`              | string  | Yes      | One-line purpose with attribution suffix                     |
| `tools`                    | array   | No       | Restrict available tools; omit for full access               |
| `agents`                   | array   | No       | Human-readable names of subagent dependencies                |
| `handoffs`                 | array   | No       | Structured transitions to other agents                       |
| `disable-model-invocation` | boolean | No       | Set `true` for orchestrators that only delegate to subagents |
| `user-invocable`           | boolean | No       | Set `false` for subagents not meant for direct invocation    |

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

### agents

Declares subagent dependencies using their human-readable `name` values. Reference subagents in the body using glob paths so resolution works regardless of nesting depth:

```yaml
agents:
  - Researcher Subagent
  - Phase Implementor
```

```markdown
Delegate research to the researcher subagent
at `.github/agents/**/researcher-subagent.agent.md`.
```

### handoffs

Defines structured transitions between agents. Each entry specifies a label (shown to the user), the target agent name, an optional prompt template, and whether to send the prompt automatically:

```yaml
handoffs:
  - label: "Research Topic"
    agent: "Researcher Subagent"
    prompt: "Research the following topic"
    send: true
  - label: "Review Changes"
    agent: "Implementation Validator"
    prompt: "Validate the implementation against the plan"
    send: true
```

### disable-model-invocation

Set to `true` for orchestrator agents that coordinate subagents without performing direct work themselves:

```yaml
disable-model-invocation: true
agents:
  - Researcher Subagent
  - Phase Implementor
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
