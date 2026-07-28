---
title: Creating Custom Prompts
description: Author reusable prompt templates with variables, agent delegation, and tool restrictions for team workflows
author: Microsoft
ms.date: 2026-07-15
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

Prompt files live under `.github/prompts/`. They are commonly organized into
collection-scoped subdirectories such as `.github/prompts/hve-core/` or
`.github/prompts/security/`, though the repository also contains top-level prompt files:

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
* `name` (optional): A human-readable identifier for the prompt
* `argument-hint` (optional): Hint text shown in the prompt picker for expected inputs
* `agent` (optional): Delegates execution to a specific custom agent
* `model` (optional): Pins the prompt to a specific model or prioritized model list
* `tools` (optional): Restricts available tools for the prompt

The body contains the actual instructions Copilot follows, including any structured sections, requirements, or constraints.

## Authoring with HVE Builder

Use `hve-builder` create or improve mode to author a prompt and run its quality
gates through one lifecycle:

```text
Use hve-builder with mode=create,
targets=.github/prompts/contoso/release-notes.prompt.md, and
requirements="Use sprint-summary.prompt.md as a known structural reference".
```

Provide existing prompts, applicable instructions, and any target agent as
known references during intake.

Use review mode for read-only assessment:

```text
Use hve-builder with mode=review and
targets=.github/prompts/contoso/release-notes.prompt.md.
```

The report covers purpose, activation, architecture, issues by severity, and
the overall outcome. Review it before sharing prompts with the team.

Use refactor mode to consolidate overlapping prompts without intentionally
changing their supported behavior:

```text
Use hve-builder with mode=refactor,
targets=.github/prompts/contoso/*.prompt.md, and requirements="merge similar
reporting prompts into one parameterized template".
```

> [!TIP]
> Run `hve-builder` review mode on existing prompts before creating new ones.
> The evidence often shows that an existing prompt can be improved instead.

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
agent: RPI Agent
---
```

When a prompt delegates to an agent, the agent's full protocol (phases, steps, tool restrictions) governs execution. The prompt body provides additional context or scoping without duplicating the agent's workflow.

```markdown
---
description: "Plans the next sprint using gathered requirements"
agent: RPI Agent
---

# Sprint Planning

## Requirements

1. Focus on the requirements in #file:docs/requirements/sprint-14.md.
2. Limit the plan to work that fits within a two-week sprint.
3. Flag any requirements that need clarification before planning.
```

This approach separates the reusable agent logic from the specific context of each prompt invocation.

## Role Scenarios

**Adventure Works' PM** creates a sprint-planning prompt at `.github/prompts/adventure-works/sprint-planning.prompt.md`. The prompt takes a `${input:sprintNumber}` variable, delegates to RPI Agent, and requires the `rpi-plan` phase to scope work to requirements tagged for the specified sprint. PMs across the team invoke `/sprint-planning` and provide only the sprint number.

**Fabrikam's Data Scientist** builds a notebook-review prompt that analyzes Jupyter notebooks for reproducibility issues. The prompt checks for hardcoded paths, missing dependency declarations, and undocumented data transformations. It uses `#file:` references to pull in the team's notebook conventions.

**Contoso's Tech Lead** authors a design-document prompt that generates architecture proposals from a set of requirements. The prompt delegates to a custom design agent and restricts tools to read-only operations so that it produces documentation without modifying source code.

For full frontmatter schema, naming conventions, and validation rules, see [Contributing: Prompts](../contributing/prompts.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
