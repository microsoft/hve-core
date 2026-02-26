---
title: Creating Custom Prompts
description: Author reusable prompt templates with variables, agent delegation, and mode configuration for team workflows
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - prompts
  - prompt templates
  - variables
  - copilot
estimated_reading_time: 6
---

## Prompt Basics

Prompts are single-session workflow definitions. You invoke a prompt, Copilot executes it, and the task completes in one shot. This distinguishes prompts from agents (multi-turn conversations) and instructions (passive guidance applied to file edits).

Prompt files (`.prompt.md`) live in `.github/prompts/{collection-id}/`:

```text
.github/prompts/
├── contoso/
│   ├── sprint-summary.prompt.md
│   └── release-notes.prompt.md
└── shared/
    └── git-commit-message.prompt.md
```

You invoke prompts through the `/` command picker in Copilot Chat. Each prompt appears by its filename, making descriptive naming essential.

## Creating a Prompt File

A prompt file combines YAML frontmatter with a Markdown body that serves as the prompt template.

Here is a complete example for generating release notes:

```markdown
---
description: "Generates release notes from recent commits and merged pull requests"
---

# Generate Release Notes

Analyze the recent commit history and merged pull requests to produce
release notes.

## Requirements

1. Group changes by category: Features, Bug Fixes, Breaking Changes,
   Documentation.
2. Include PR numbers and brief descriptions for each entry.
3. Highlight breaking changes at the top with migration guidance.
4. Use past tense for all entries.
```

Frontmatter fields:

* `description` (required): A one-line summary displayed in the prompt picker
* `agent` (optional): Delegates execution to a specific custom agent
* `tools` (optional): Restricts available tools for the prompt
* `mode` (optional): Changes Copilot behavior mode

The body contains the actual instructions Copilot follows, including any structured sections, requirements, or constraints.

## Accelerating with Prompt Builder

The Prompt Builder agent automates prompt creation, evaluation, and refinement. Use its three commands instead of authoring prompt files entirely by hand.

Create a new prompt or improve an existing one with `/prompt-build`:

```text
/prompt-build files=.github/prompts/contoso/sprint-summary.prompt.md promptFiles=.github/prompts/contoso/release-notes.prompt.md
```

Provide `files` for reference context (existing prompts to use as patterns, instruction files, agent files the prompt delegates to) and `promptFiles` for the prompt files to create or update.

Evaluate a prompt's quality with `/prompt-analyze`:

```text
/prompt-analyze promptFiles=.github/prompts/contoso/release-notes.prompt.md
```

The report covers purpose, capabilities, issues by severity, and overall quality. Run this before sharing prompts with the team.

Consolidate overlapping prompts with `/prompt-refactor`:

```text
/prompt-refactor promptFiles=.github/prompts/contoso/*.prompt.md requirements="merge similar reporting prompts into one parameterized template"
```

> [!TIP]
> Run `/prompt-analyze` on existing prompts before creating new ones. The quality report often reveals that an existing prompt can be improved rather than replaced.

## Variables and Dynamic Content

Prompts accept user-provided values through input variables. The syntax uses `${input:varName}` for required inputs and `${input:varName:defaultValue}` for optional inputs with defaults.

```markdown
---
description: "Creates a structured code review for a specific module"
---

# Code Review: ${input:moduleName}

Review the module at ${input:modulePath:src/} for the following criteria:

* Adherence to ${input:styleguide:TypeScript} conventions
* Error handling completeness
* Test coverage gaps
```

In this example:

* `${input:moduleName}` is required. Copilot infers it from the user's conversation or attached files.
* `${input:modulePath:src/}` defaults to `src/` if the user does not specify a path.
* `${input:styleguide:TypeScript}` defaults to `TypeScript` as the style standard.

Document variables in an Inputs section so users know what they can provide:

```markdown
## Inputs

* ${input:moduleName}: (Required) Name of the module to review.
* ${input:modulePath:src/}: (Optional, defaults to src/) Path to the module directory.
* ${input:styleguide:TypeScript}: (Optional, defaults to TypeScript) Style guide to evaluate against.
```

Use `#file:path/to/file.md` when the prompt needs the full contents of another file injected at runtime:

```markdown
Review the changes in #file:src/api/handlers.ts against the standards
defined in #file:.github/instructions/coding-standards/typescript.instructions.md.
```

## Agent Delegation from Prompts

The `agent:` frontmatter field delegates prompt execution to a custom agent. The value uses the agent's human-readable `name:` from its frontmatter.

```yaml
---
description: "Plans implementation tasks from a requirements document"
agent: Task Planner
---
```

When a prompt delegates to an agent, the agent's full protocol (phases, steps, tool restrictions) governs execution. The prompt body provides additional context or scoping without duplicating the agent's workflow.

```markdown
---
description: "Plans the next sprint using gathered requirements"
agent: Task Planner
---

# Sprint Planning

## Requirements

1. Focus on the requirements in #file:docs/requirements/sprint-14.md.
2. Limit the plan to work that fits within a two-week sprint.
3. Flag any requirements that need clarification before planning.
```

This approach separates the reusable agent logic from the specific context of each prompt invocation.

## Mode Configuration

The `mode:` frontmatter field changes Copilot's behavior for the duration of the prompt. Modes control how Copilot interprets the task and which interaction patterns it follows.

```yaml
---
description: "Performs a security audit of authentication flows"
mode: agent
---
```

Mode configuration is useful when a prompt needs Copilot to operate differently than the default chat mode, such as using an agent-style protocol for a single-shot security scan or a focused editing mode for refactoring tasks.

## Role Scenarios

**Adventure Works' PM** creates a sprint-planning prompt at `.github/prompts/adventure-works/sprint-planning.prompt.md`. The prompt takes a `${input:sprintNumber}` variable, delegates to the Task Planner agent, and scopes the plan to requirements tagged for the specified sprint. PMs across the team invoke `/sprint-planning` and provide only the sprint number.

**Fabrikam's Data Scientist** builds a notebook-review prompt that analyzes Jupyter notebooks for reproducibility issues. The prompt checks for hardcoded paths, missing dependency declarations, and undocumented data transformations. It uses `#file:` references to pull in the team's notebook conventions.

**Contoso's Tech Lead** authors a design-document prompt that generates architecture proposals from a set of requirements. The prompt delegates to a custom design agent and restricts tools to read-only operations so that it produces documentation without modifying source code.

For full frontmatter schema, naming conventions, and validation rules, see [Contributing: Prompts](../contributing/prompts.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
