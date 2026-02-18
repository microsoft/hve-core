---
title: New Contributor Guide
description: Guided onboarding path from first install through autonomous AI-assisted engineering with HVE Core
author: Microsoft
ms.date: 2026-02-18
ms.topic: tutorial
keywords:
  - onboarding
  - getting started
  - new contributor
  - learning path
estimated_reading_time: 12
---

This guide helps you get started with HVE Core from your first install through independent, AI-assisted engineering. Follow the four milestones below to progressively build fluency with agents, prompts, and workflows.

## Recommended Collections

> [!TIP]
> Install the starter collection:
>
> ```text
> @hve-core-installer install rpi
> ```
>
> The `rpi` collection is the recommended starting point. It provides the core research, planning, implementation, and review agents that you will use throughout onboarding and beyond.

## What HVE Core Does for You

1. Provides guided workflows that structure your first contributions
2. Teaches AI-assisted engineering patterns through progressive exposure
3. Offers research, planning, and implementation agents that work at every skill level
4. Includes memory persistence so your preferences and context carry across sessions
5. Activates coding standards automatically so you follow project conventions from the start

## Your Onboarding Path

Progress through four milestones at your own pace. Each milestone builds on the previous one and introduces new tools and workflows.

### Milestone 1: Setup and Exploration

Install HVE Core and run your first agent interaction.

1. Follow the [installation guide](../getting-started/install.md) to set up your development environment.
2. Install the `rpi` collection using `@hve-core-installer install rpi`.
3. Open a chat and invoke `@memory` to verify agent responsiveness.
4. Run `@task-researcher` against a file or concept in the codebase to see research output.

Start with `/rpi mode=guided` for step-by-step workflow assistance, then transition to `/rpi` as you gain confidence.

Checkpoint: You can invoke agents, see their output, and understand the chat-based interaction model.

### Milestone 2: Guided Workflow

Complete a full research-plan-implement cycle with hand-holding.

1. Pick a small, well-defined task (a bug fix or documentation update works well).
2. Research the task with `@task-researcher` to understand the codebase context.
3. Plan the implementation with `@task-planner` to create a structured approach.
4. Implement the change with `@task-implementor` following the plan.
5. Review your changes with `@task-reviewer` before committing.
6. Commit using `/git-commit` for a conventional commit message.

Checkpoint: You have completed one full RPI cycle and understand how phases connect.

### Milestone 3: Independent Workflow

Use agents selectively and combine workflows for larger tasks.

1. Use `/rpi mode=auto` for end-to-end automation on a multi-file change.
2. Explore additional agents from the [Engineer Guide](engineer.md) or your role guide.
3. Install a second collection relevant to your work (see the [Collection Quick Reference](README.md#collection-quick-reference)).
4. Use `@memory` to save preferences and context that persist across sessions.

Checkpoint: You choose which agents to use based on task needs and work with multiple collections.

### Milestone 4: Autonomous Engineering

Work fluently with HVE Core as an integrated part of your engineering practice.

1. Combine agents across collections for complex, multi-stage workflows.
2. Create custom prompts or instructions tailored to your team's patterns.
3. Contribute improvements back to HVE Core through pull requests.
4. Mentor other contributors on AI-assisted engineering practices.

Checkpoint: You use HVE Core tools naturally, customize workflows, and help others onboard.

## Starter Prompts

```text
@task-researcher Research {topic} in this codebase
```

```text
@task-planner Plan the implementation for {task}
```

```text
@task-implementor Implement the plan
```

```text
/rpi mode=auto Implement {task description}
```

```text
/git-commit Commit changes with a conventional message
```

## Key Agents and Workflows

| Agent           | Purpose                                     | Invoke             | When to Use       |
|-----------------|---------------------------------------------|--------------------|--------------------|
| task-researcher | Codebase and context research               | `@task-researcher` | Milestone 1+       |
| task-planner    | Structured implementation planning          | `@task-planner`    | Milestone 2+       |
| task-implementor | Phase-based code implementation            | `@task-implementor`| Milestone 2+       |
| task-reviewer   | Code review and quality validation          | `@task-reviewer`   | Milestone 2+       |
| rpi-agent       | Full RPI orchestration in one agent         | `@rpi-agent`       | Milestone 3+       |
| memory          | Session context and preference persistence  | `@memory`          | Milestone 1+       |

## Tips

| Do                                                          | Don't                                                       |
|-------------------------------------------------------------|-------------------------------------------------------------|
| Follow the milestones in order for your first project       | Skip to Milestone 4 without understanding the fundamentals  |
| Start with small, well-defined tasks                        | Tackle large refactors before completing Milestone 2        |
| Read agent output carefully to learn patterns               | Blindly accept all agent suggestions without understanding  |
| Use `/git-commit` to learn conventional commit conventions  | Write commit messages manually until you know the format    |
| Ask for help in the repository discussions                  | Struggle silently when stuck on tooling or workflow issues   |

## Related Roles

* New Contributor to Engineer: After completing all four milestones, you have the skills and tooling fluency described in the [Engineer Guide](engineer.md). Transition to that guide for advanced engineering workflows.
* New Contributor to Any Role: The onboarding milestones build foundational skills applicable to every role. After Milestone 2, explore the role guide that matches your work (TPM, Data Scientist, SRE, and more).

## Next Steps

> [!TIP]
> Start with installation: [Install Guide](../getting-started/install.md)
> Run your first workflow: [First Workflow Guide](../getting-started/first-workflow.md)
> Explore the RPI methodology: [RPI Documentation](../rpi/README.md)
> Find your role: [Role Guides Overview](README.md)

---

> [!NOTE]
> Environment validation automation (GAP-07) and good-first-issue discovery filtering (GAP-10) are planned improvements. Current workflows rely on manual environment checks after installation and manual issue browsing for contributor-friendly tasks.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
