---
title: Tech Lead Guide
description: HVE Core support for tech leads and architects driving architecture, code quality, and prompt engineering standards
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
> Install the collections that match your workflow:
>
> ```text
> Minimum: @hve-core-installer install rpi coding-standards project-planning
> Full:    @hve-core-installer install rpi coding-standards project-planning prompt-engineering
> ```
>
> The `rpi` collection provides research and review workflows. Adding `coding-standards` activates language-specific rules. The `prompt-engineering` collection adds tools for creating and analyzing AI prompts, instructions, and agent definitions.

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

1. Stage 2: Discovery. Use `@task-researcher` to evaluate design options, research external patterns, and gather architectural evidence.
2. Stage 3: Product Definition. Create architecture decision records with `@adr-creation` and generate diagrams with `@arch-diagram-builder`.
3. Stage 6: Implementation. Guide engineers using coding standards (auto-activated by file type) and prompt engineering tools for AI artifact creation.
4. Stage 7: Review. Run `@pr-review` for automated pull request feedback and `@task-reviewer` for implementation-against-plan validation.
5. Stage 9: Operations. Use `/prompt-analyze` and `/prompt-refactor` to maintain and evolve prompt engineering artifacts as team practices mature.

## Starter Prompts

```text
@adr-creation Create an ADR for {design decision}
```

```text
@arch-diagram-builder Generate architecture diagram for {component}
```

```text
@pr-review Review the current pull request
```

```text
/prompt-build Create a new {type} for {purpose}
```

```text
/prompt-analyze Analyze {prompt file} for quality
```

## Key Agents and Workflows

| Agent              | Purpose                                          | Invoke              | Docs                                                   |
|--------------------|--------------------------------------------------|----------------------|--------------------------------------------------------|
| adr-creation       | Architecture decision record creation            | `@adr-creation`      | Agent file                                             |
| arch-diagram-builder | Mermaid architecture diagram generation         | `@arch-diagram-builder` | Agent file                                          |
| pr-review          | Pull request review automation                   | `@pr-review`         | Agent file                                             |
| task-reviewer      | Implementation review against plan               | `@task-reviewer`     | [Task Reviewer](../rpi/task-reviewer.md)               |
| prompt-builder     | Prompt engineering artifact creation             | `@prompt-builder`    | Agent file                                             |
| task-researcher    | Deep codebase and architecture research          | `@task-researcher`   | [Task Researcher](../rpi/task-researcher.md)           |
| task-planner       | Structured implementation planning               | `@task-planner`      | [Task Planner](../rpi/task-planner.md)                 |
| doc-ops            | Documentation operations and maintenance         | `@doc-ops`           | Agent file                                             |
| memory             | Session context and preference persistence       | `@memory`            | Agent file                                             |

Auto-activated instructions apply coding standards based on file type: C# (`*.cs`), Python (`*.py`), Bash (`*.sh`), Bicep (`bicep/**`), Terraform (`*.tf`), and GitHub Actions workflows (`*.yml`).

## Tips

| Do                                                           | Don't                                                          |
|--------------------------------------------------------------|----------------------------------------------------------------|
| Create ADRs for significant design decisions                 | Make architectural choices without documented rationale         |
| Use `@pr-review` to supplement manual code reviews           | Rely solely on automated review without human judgment         |
| Let coding standards auto-activate based on file type        | Manually apply rules that already have instruction files       |
| Use `/prompt-analyze` before refactoring AI artifacts        | Rewrite prompts without understanding their current structure  |
| Research with `@task-researcher` before architecture changes | Design without investigating existing patterns and constraints |

## Related Roles

* Tech Lead + Engineer: Architecture decisions feed implementation. Tech leads set standards and review while engineers build. See the [Engineer Guide](engineer.md).
* Tech Lead + Security Architect: Security architecture integrates with overall system design. Threat models inform architecture decisions. See the [Security Architect Guide](security-architect.md).
* Tech Lead + TPM: Architecture shapes product requirements and vice versa. Design decisions affect decomposition and sprint planning. See the [TPM Guide](tpm.md).

## Next Steps

> [!TIP]
> See the full project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)
> Explore prompt engineering practices: [Prompt Engineering Contribution Guide](../contributing/prompts.md)
> Review coding standards: [Coding Standards Collection](../../collections/coding-standards.collection.md)

---

> [!NOTE]
> Prompt engineering maturity scoring (GAP-06) and automated standards enforcement dashboards are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
