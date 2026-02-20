---
title: Engineer Guide
description: HVE Core support for engineers building features, fixing bugs, and shipping code with AI-assisted workflows
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - engineer
  - development
  - RPI
  - coding standards
estimated_reading_time: 10
---

This guide is for you if you write code, implement features, fix bugs, review pull requests, or maintain production systems. Engineers get the deepest tooling in HVE Core, with 28+ addressable assets spanning research, planning, implementation, review, and delivery.

## Recommended Collections

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collections are `rpi` (research, planning, implementation, and review agents) and `coding-standards` (language-specific instructions that auto-apply based on file type). For clone-based setups, use the **hve-core-installer** agent with `install rpi coding-standards`.

## What HVE Core Does for You

1. Researches codebase patterns, external APIs, and architecture before you write code
2. Creates structured implementation plans with step-by-step task breakdowns
3. Implements features following plans with phase-based execution and progress tracking
4. Reviews code changes against standards, patterns, and architectural guidelines
5. Generates conventional commit messages and pull request descriptions
6. Activates language-specific coding standards automatically based on file type (C#, Python, Bash, Bicep, Terraform, GitHub Actions)
7. Manages Git workflows including merge, rebase, and conflict resolution

## Your Lifecycle Stages

> [!NOTE]
> Engineers primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research requirements, investigate codebase, gather context
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Transform research into structured implementation plans
> [Stage 6: Implementation](../lifecycle/implementation.md): Build features, write code, execute plans
> [Stage 7: Review](../lifecycle/review.md): Review code, validate changes, ensure quality
> [Stage 8: Delivery](../lifecycle/delivery.md): Commit, create PRs, merge changes

## Stage Walkthrough

1. Stage 2: Discovery. Start with the **task-researcher** agent to investigate requirements, explore codebase patterns, and gather evidence for your approach.
2. Stage 3: Product Definition. Use the **task-planner** agent to transform research into a structured implementation plan with phases, steps, and success criteria.
3. Stage 6: Implementation. Execute the plan with the **task-implementor** agent or `/rpi mode=auto` for automated phase-based implementation with progress tracking.
4. Stage 7: Review. Run the **task-reviewer** agent to validate implementation against the plan, check coding standards, and ensure architectural compliance.
5. Stage 8: Delivery. Use `/git-commit` for conventional commit messages, `/pull-request` for PR creation, and `/git-merge` for merge workflows.

## Starter Prompts

```text
/rpi Implement the user notification preferences API endpoint from work
item #4523. Follow the REST conventions in src/api/handlers/ and add
integration tests covering email, SMS, and push notification channels.
```

Select **task-researcher** agent:

```text
Research the best approach for implementing a rate limiter in the API
gateway. Compare token bucket vs sliding window algorithms, evaluate
Redis vs in-memory storage for distributed deployments, and review
existing patterns in src/middleware/.
```

Select **task-planner** agent and attach the research document:

```text
Create an implementation plan for the webhook delivery system. Include
phases for the event dispatcher, retry queue, and dead-letter handling.
Reference patterns in src/services/.
```

Select **task-implementor** agent and attach the plan instructions file:

```text
Implement the webhook delivery system following the attached plan. Start
with the event dispatcher phase and execute the retry queue phase
second.
```

Select **task-reviewer** agent and attach the changes log:

```text
Review my webhook delivery system implementation. Check for error
handling gaps, verify retry logic correctness, and validate compliance
with coding standards.
```

```text
/git-commit Commit changes with a conventional message
```

```text
/pull-request Create a PR for the current changes
```

## Key Agents and Workflows

| Agent                | Purpose                                        | Docs                                              |
|----------------------|------------------------------------------------|---------------------------------------------------|
| **task-researcher**  | Deep codebase and API research                 | [Task Researcher](../../rpi/task-researcher.md)   |
| **task-planner**     | Structured implementation planning             | [Task Planner](../../rpi/task-planner.md)         |
| **task-implementor** | Phase-based code implementation                | [Task Implementor](../../rpi/task-implementor.md) |
| **task-reviewer**    | Code review and quality validation             | [Task Reviewer](../../rpi/task-reviewer.md)       |
| **rpi-agent**        | Full RPI orchestration in one agent            | [RPI Overview](../../rpi/README.md)               |
| **pr-review**        | Pull request review automation                 | Agent file                                        |
| **memory**           | Session context and preference persistence     | Agent file                                        |
| **prompt-builder**   | Create and refine prompt engineering artifacts | Agent file                                        |

Auto-activated instructions apply coding standards based on file type: C# (`*.cs`), Python (`*.py`), Bash (`*.sh`), Bicep (`bicep/**`), Terraform (`*.tf`), and GitHub Actions workflows (`*.yml`).

## Tips

| Do                                                         | Don't                                                      |
|------------------------------------------------------------|------------------------------------------------------------|
| Research before implementing multi-file changes            | Jump straight to coding complex features                   |
| Use `/rpi mode=auto` for planned, multi-step work          | Manually coordinate research, planning, and implementation |
| Let coding standards auto-activate by file type            | Override or skip language-specific instructions            |
| Review the research doc before starting the planning phase | Skip research for unfamiliar codebases or APIs             |
| Clear context between RPI phases with `/clear`             | Carry stale context across research, plan, and implement   |

## Related Roles

* Engineer + Tech Lead: Feature development benefits from architecture review and standards enforcement. The Tech Lead validates design decisions while the Engineer implements. See the [Tech Lead Guide](tech-lead.md).
* Engineer + Data Scientist: Analytics pipeline development pairs data specification and notebook prototyping with production-grade integration. See the [Data Scientist Guide](data-scientist.md).
* New Contributor to Engineer: Contributors progress from guided mode through autonomous engineering. See the [New Contributor Guide](new-contributor.md).

## Next Steps

> [!TIP]
> Run your first RPI workflow: [First Workflow Guide](../../getting-started/first-workflow.md)
> Explore the full RPI methodology: [RPI Documentation](../../rpi/README.md)
> See how your stages connect: [AI-Assisted Project Lifecycle](../lifecycle/)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
