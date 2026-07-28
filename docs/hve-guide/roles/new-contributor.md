---
title: New Contributor Guide
description: Guided onboarding path from first install through autonomous AI-assisted engineering with HVE Core
sidebar_position: 2
author: Microsoft
ms.date: 2026-07-15
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
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace for the flagship RPI workflow and core artifacts with zero configuration.
>
> For custom installations, install the [HVE Core Installer extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) and ask any agent:
>
> ```text
> help me customize hve-core installation
> ```
>
> The `hve-core` collection is the recommended starting point. It provides `RPI Agent` and the direct research, planning, implementation, and review skills that you will use throughout onboarding and beyond.

## What HVE Core Does for You

1. Provides guided workflows that structure your first contributions
2. Teaches AI-assisted engineering patterns through progressive exposure
3. Offers RPI skills for research, planning, implementation, and review at every experience level
4. Preserves workflow state in durable artifacts so work can resume across sessions
5. Activates coding standards automatically so you follow project conventions from the start

## Your Onboarding Path

Progress through four milestones at your own pace. Each milestone builds on the previous one and introduces new tools and workflows.

### Milestone 1: Setup and Exploration

Install HVE Core and run your first agent interaction.

1. Follow the [installation guide](../../getting-started/install.md) to set up your development environment.
2. Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace. This is the recommended method: zero configuration, automatic updates, and works in local, devcontainer, and Codespaces environments.
3. Open a chat and select **RPI Agent** to verify agent responsiveness.
4. Run `/rpi-research` against a file or concept in the codebase to see evidence-focused research output.

Start with `RPI Agent` and ask it to explain each lifecycle transition. Use `/rpi` directly as you gain confidence.

Checkpoint: You can invoke agents, see their output, and understand the chat-based interaction model.

### Milestone 2: Guided Workflow

Complete a full research-plan-implement cycle with hand-holding.

1. Pick a small, well-defined task (a bug fix or documentation update works well).
2. Research the task with `/rpi-research` when the available evidence has a demonstrated gap.
3. Plan the implementation with `/rpi-plan` to create a structured approach.
4. Implement the approved work with `/rpi-implement` following the plan.
5. Review your changes with `/rpi-review` before committing.
6. Commit using `/git-commit` for a conventional commit message.

Checkpoint: You have completed one full RPI cycle and understand how phases connect.

### Milestone 3: Independent Workflow

Use agents selectively and combine workflows for larger tasks.

1. Use `/rpi` for end-to-end coordination on a multi-file change.
2. Explore additional agents from the [Engineer Guide](engineer.md) or your role guide.
3. Explore agents from additional collections within the extension, or use the installer skill to select agent bundles in a clone setup (see the [Role Overview](./#role-overview)).
4. Resume longer workflows from their dated research, plan, details, changes, and review artifacts.

Checkpoint: You choose which agents to use based on task needs and work with multiple collections.

### Milestone 4: Autonomous Engineering

Work fluently with HVE Core as an integrated part of your engineering practice.

1. Combine agents across collections for complex, multi-stage workflows.
2. Create custom prompts or instructions tailored to your team's patterns.
3. Contribute improvements back to HVE Core through pull requests.
4. Mentor other contributors on AI-assisted engineering practices.

Checkpoint: You use HVE Core tools naturally, customize workflows, and help others onboard.

## Starter Prompts

Use `/rpi-research`:

```text
Research how error handling works in this codebase. Look at exception
hierarchies in src/errors/, how validation errors propagate from API
handlers to responses, and logging patterns including structured logging
and correlation IDs.
```

Use `/rpi-plan`:

```text
Plan the implementation for adding CSV export to the reporting API. The
endpoint should accept date range parameters, stream results for large
datasets, and follow existing response format patterns in
src/api/handlers/reports.py.
```

Use `/rpi-implement`:

```text
Implement the approved plan in .copilot-tracking/plans/ and use the
matching phase details. Follow the implementation order specified in
the plan and run tests after each component.
```

Use `/rpi-review` and reference the changes record:

```text
Review my implementation. Check for error handling gaps, verify
correctness against the plan, and validate compliance with coding
standards.
```

```text
/rpi task="Implement the input validation helpers for the user
registration form. Add email format checking, password strength rules
matching the policy in docs/security/password-policy.md, and unit tests
for each validator."
```

```text
/git-commit Commit changes with a conventional message
```

```text
/pull-request Create a pull request for the current changes
```

## Key Agents and Workflows

| Agent or skill    | Purpose                                   | When to Use  |
|-------------------|-------------------------------------------|--------------|
| **rpi-research**  | Codebase and context research             | Milestone 1+ |
| **rpi-plan**      | Structured implementation planning        | Milestone 2+ |
| **rpi-implement** | Evidence-led implementation               | Milestone 2+ |
| **rpi-review**    | Implementation review and outcome routing | Milestone 2+ |
| **RPI Agent**     | Full RPI lifecycle coordination           | Milestone 3+ |

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
> Explore the RPI methodology: [RPI Documentation](../../rpi/)
> Find your role: [Role Guides Overview](./)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
