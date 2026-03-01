---
title: Tech Lead Guide
description: HVE Core support for tech leads and architects driving architecture, code quality, and prompt engineering standards
sidebar_position: 4
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - tech lead
  - architect
  - code review
  - prompt engineering
estimated_reading_time: 10
---

This guide is for you if you make architecture decisions, set coding standards, review designs and code, or curate AI prompt engineering practices. Tech leads span both engineering and planning, with 23+ addressable assets across design, standards, review, and prompt management.

## Recommended Collections

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collections are `rpi` (research and review workflows), `coding-standards` (language-specific rules), and `project-planning` (architecture decision records and planning). For clone-based setups, use the **hve-core-installer** agent with `install rpi coding-standards project-planning`.

## What HVE Core Does for You

1. Creates architecture decision records (ADRs) capturing design rationale and trade-offs
2. Generates architecture diagrams from codebase analysis
3. Reviews code and pull requests against architectural guidelines and coding standards
4. Activates language-specific coding standards automatically based on file type
5. Builds, analyzes, and refactors prompt engineering artifacts (prompts, agents, instructions, skills)
6. Manages research and planning workflows that feed into engineering implementation

## Your Lifecycle Stages

> [!NOTE]
> Tech leads primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research architecture, evaluate design options, gather evidence
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Define architecture decisions and design specifications
> [Stage 6: Implementation](../lifecycle/implementation.md): Guide implementation, enforce standards
> [Stage 7: Review](../lifecycle/review.md): Review designs, code, and architectural compliance
> [Stage 9: Operations](../lifecycle/operations.md): Maintain standards, evolve architecture

## Stage Walkthrough

1. Stage 2: Discovery. Use the **task-researcher** agent to evaluate design options, research external patterns, and gather architectural evidence.
2. Stage 3: Product Definition. Create architecture decision records with the **adr-creation** agent and generate diagrams with the **arch-diagram-builder** agent.
3. Stage 6: Implementation. Guide engineers using coding standards (auto-activated by file type) and prompt engineering tools for AI artifact creation.
4. Stage 7: Review. Run the **pr-review** agent for automated pull request feedback and the **task-reviewer** agent for implementation-against-plan validation.
5. Stage 9: Operations. Use `/prompt-analyze` and `/prompt-refactor` to maintain and evolve prompt engineering artifacts as team practices mature.

## Starter Prompts

Select **adr-creation** agent:

```text
Create an ADR for adopting OpenTelemetry as our observability standard,
replacing the current custom tracing library. Cover decision drivers
around vendor neutrality and auto-instrumentation support, alternatives
like Datadog APM and Jaeger, and migration impact on existing services.
```

Select **arch-diagram-builder** agent:

```text
Generate an architecture diagram for the event-driven order processing
pipeline. Show the message flow from API gateway through the event bus
to worker services, including the dead-letter queue and monitoring
integration. Use mermaid flowchart syntax.
```

Select **pr-review** agent:

```text
Review the current pull request focusing on architecture alignment with
docs/architecture/ patterns, API contract consistency with existing
endpoints, test coverage for new code paths, and performance implications
of any new database queries.
```

```text
/prompt-build Create a new instructions file for Python data pipeline
development. Cover pandas conventions, type hinting requirements,
virtual environment setup with uv, and testing patterns using pytest.
```

```text
/prompt-analyze Analyze .github/instructions/coding-standards/python-script.instructions.md
for quality. Check frontmatter schema, applyTo coverage, instruction
specificity, and alignment with repository conventions.
```

## Key Agents and Workflows

| Agent                    | Purpose                                    | Docs                                            |
|--------------------------|--------------------------------------------|-------------------------------------------------|
| **adr-creation**         | Architecture decision record creation      | Agent file                                      |
| **arch-diagram-builder** | Mermaid architecture diagram generation    | Agent file                                      |
| **pr-review**            | Pull request review automation             | Agent file                                      |
| **task-reviewer**        | Implementation review against plan         | [Task Reviewer](../../rpi/task-reviewer.md)     |
| **prompt-builder**       | Prompt engineering artifact creation       | Agent file                                      |
| **task-researcher**      | Deep codebase and architecture research    | [Task Researcher](../../rpi/task-researcher.md) |
| **task-planner**         | Structured implementation planning         | [Task Planner](../../rpi/task-planner.md)       |
| **doc-ops**              | Documentation operations and maintenance   | Agent file                                      |
| **memory**               | Session context and preference persistence | Agent file                                      |

Prompts complement the agents for cross-cutting workflows:

| Prompt       | Purpose                                                       | Invoke          |
|--------------|---------------------------------------------------------------|-----------------|
| git-commit   | Stage and commit changes with conventional message formatting | `/git-commit`   |
| pull-request | Create a pull request with structured description             | `/pull-request` |

Auto-activated instructions apply coding standards based on file type: C# (`*.cs`), Python (`*.py`), Bash (`*.sh`), Bicep (`bicep/**`), Terraform (`*.tf`), and GitHub Actions workflows (`*.yml`).

## Tips

| Do                                                                      | Don't                                                          |
|-------------------------------------------------------------------------|----------------------------------------------------------------|
| Create ADRs for significant design decisions                            | Make architectural choices without documented rationale        |
| Use the **pr-review** agent to supplement manual code reviews           | Rely solely on automated review without human judgment         |
| Let coding standards auto-activate based on file type                   | Manually apply rules that already have instruction files       |
| Use `/prompt-analyze` before refactoring AI artifacts                   | Rewrite prompts without understanding their current structure  |
| Research with the **task-researcher** agent before architecture changes | Design without investigating existing patterns and constraints |

## Related Roles

* Tech Lead + Engineer: Architecture decisions feed implementation. Tech leads set standards and review while engineers build. See the [Engineer Guide](engineer.md).
* Tech Lead + Security Architect: Security architecture integrates with overall system design. Threat models inform architecture decisions. See the [Security Architect Guide](security-architect.md).
* Tech Lead + TPM: Architecture shapes product requirements and vice versa. Design decisions affect decomposition and sprint planning. See the [TPM Guide](tpm.md).

## Next Steps

> [!TIP]
> See the full project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)
> Explore prompt engineering practices: [Prompt Engineering Contribution Guide](../../contributing/prompts.md)
> Review coding standards: [Coding Standards Collection](https://github.com/microsoft/hve-core/blob/main/collections/coding-standards.collection.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
