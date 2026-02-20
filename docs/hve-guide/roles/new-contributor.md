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

This guide helps you get started with HVE Core from your first install through independent, AI-assisted engineering. HVE Core provides 10 addressable assets tailored for new contributors. Follow the four milestones below to progressively build fluency with agents, prompts, and workflows.

## Recommended Collections

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> For custom installations, select the **hve-core-installer** agent and install the starter collection:
>
> ```text
> install rpi
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

1. Follow the [installation guide](../../getting-started/install.md) to set up your development environment.
2. Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace. This is the recommended method: zero configuration, automatic updates, and works in local, devcontainer, and Codespaces environments. For custom installations, use the **hve-core-installer** agent instead.
3. Open a chat and select the **memory** agent to verify agent responsiveness.
4. Run the **task-researcher** agent against a file or concept in the codebase to see research output.

Start with `/rpi mode=guided` for step-by-step workflow assistance, then transition to `/rpi` as you gain confidence.

Checkpoint: You can invoke agents, see their output, and understand the chat-based interaction model.

### Milestone 2: Guided Workflow

Complete a full research-plan-implement cycle with hand-holding.

1. Pick a small, well-defined task (a bug fix or documentation update works well).
2. Research the task with the **task-researcher** agent to understand the codebase context.
3. Plan the implementation with the **task-planner** agent to create a structured approach.
4. Implement the change with the **task-implementor** agent following the plan.
5. Review your changes with the **task-reviewer** agent before committing.
6. Commit using `/git-commit` for a conventional commit message.

Checkpoint: You have completed one full RPI cycle and understand how phases connect.

### Milestone 3: Independent Workflow

Use agents selectively and combine workflows for larger tasks.

1. Use `/rpi mode=auto` for end-to-end automation on a multi-file change.
2. Explore additional agents from the [Engineer Guide](engineer.md) or your role guide.
3. Install a second collection relevant to your work (see the [Collection Quick Reference](README.md#collection-quick-reference)).
4. Use the **memory** agent to save preferences and context that persist across sessions.

Checkpoint: You choose which agents to use based on task needs and work with multiple collections.

### Milestone 4: Autonomous Engineering

Work fluently with HVE Core as an integrated part of your engineering practice.

1. Combine agents across collections for complex, multi-stage workflows.
2. Create custom prompts or instructions tailored to your team's patterns.
3. Contribute improvements back to HVE Core through pull requests.
4. Mentor other contributors on AI-assisted engineering practices.

Checkpoint: You use HVE Core tools naturally, customize workflows, and help others onboard.

## Starter Prompts

Select **task-researcher** agent:

```text
Research how error handling works in this codebase. Look at exception
hierarchies in src/errors/, how validation errors propagate from API
handlers to responses, and logging patterns including structured logging
and correlation IDs.
```

Select **task-planner** agent:

```text
Plan the implementation for adding CSV export to the reporting API. The
endpoint should accept date range parameters, stream results for large
datasets, and follow existing response format patterns in
src/api/handlers/reports.py.
```

Select **task-implementor** agent:

```text
Implement the plan from the latest task-planner output in
.copilot-tracking/plans/. Follow the implementation order specified
in the plan and run tests after each component.
```

Select **task-reviewer** agent and attach the changes log:

```text
Review my implementation. Check for error handling gaps, verify
correctness against the plan, and validate compliance with coding
standards.
```

```text
/rpi mode=auto Implement the input validation helpers for the user
registration form. Add email format checking, password strength rules
matching the policy in docs/security/password-policy.md, and unit tests
for each validator.
```

```text
/git-commit Commit changes with a conventional message
```

```text
/pull-request Create a pull request for the current changes
```

## Key Agents and Workflows

| Agent                | Purpose                                    | When to Use  |
|----------------------|--------------------------------------------|--------------|
| **task-researcher**  | Codebase and context research              | Milestone 1+ |
| **task-planner**     | Structured implementation planning         | Milestone 2+ |
| **task-implementor** | Phase-based code implementation            | Milestone 2+ |
| **task-reviewer**    | Code review and quality validation         | Milestone 2+ |
| **rpi-agent**        | Full RPI orchestration in one agent        | Milestone 3+ |
| **memory**           | Session context and preference persistence | Milestone 1+ |

## Tips

| Do                                                         | Don't                                                      |
|------------------------------------------------------------|------------------------------------------------------------|
| Follow the milestones in order for your first project      | Skip to Milestone 4 without understanding the fundamentals |
| Start with small, well-defined tasks                       | Tackle large refactors before completing Milestone 2       |
| Read agent output carefully to learn patterns              | Blindly accept all agent suggestions without understanding |
| Use `/git-commit` to learn conventional commit conventions | Write commit messages manually until you know the format   |
| Ask for help in the repository discussions                 | Struggle silently when stuck on tooling or workflow issues |

## Related Roles

* New Contributor to Engineer: After completing all four milestones, you have the skills and tooling fluency described in the [Engineer Guide](engineer.md). Transition to that guide for advanced engineering workflows.
* New Contributor to Any Role: The onboarding milestones build foundational skills applicable to every role. After Milestone 2, explore the role guide that matches your work (TPM, Data Scientist, SRE, and more).

## Next Steps

> [!TIP]
> Start with installation: [Install Guide](../../getting-started/install.md)
> Run your first workflow: [First Workflow Guide](../../getting-started/first-workflow.md)
> Explore the RPI methodology: [RPI Documentation](../../rpi/README.md)
> Find your role: [Role Guides Overview](README.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
