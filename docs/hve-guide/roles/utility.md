---
title: Utility Reference
description: Cross-cutting HVE Core utilities for documentation, media, Git workflows, durable workflow state, and diagnostics
sidebar_position: 10
author: Microsoft
ms.date: 2026-07-15
ms.topic: reference
keywords:
  - utility
  - workflow state
  - documentation
  - Git workflows
  - cross-cutting
estimated_reading_time: 8
---

Use these cross-cutting utilities when your workflow spans multiple roles or lifecycle stages. These tools handle documentation maintenance, media processing, Git workflows, installation management, and diagnostics. Each stateful workflow resumes from its own durable artifacts rather than a general memory or checkpoint capability.

## Utility Categories

| Category      | Purpose                                               |
|---------------|-------------------------------------------------------|
| Continuity    | Resume from each workflow's durable artifacts         |
| Documentation | Documentation audit, drift, authoring, and validation |
| Media         | Video-to-GIF conversion with FFmpeg optimization      |
| Git           | Commit messages, merge workflows, PR creation         |
| Installation  | Collection installation and environment setup         |
| Diagnostics   | Build information retrieval and CI/CD status checks   |

## Usage Patterns

### Workflow Continuity

Resume a workflow from the state and evidence files it owns. For RPI, reference the dated research, plan, phase details, changes, and review artifacts with the same stable task ID. Backlog managers and planning agents use their domain-specific state files and handoff records.

```text
/rpi Continue task authentication-refactor from the latest dated plan,
phase details, changes record, and review evidence. Resume the next
incomplete task without repeating completed research.
```

### Documentation Operations

The **documentation** agent handles documentation audit, drift, authoring, and validation through its four modes. Resume a documentation session from its durable session artifacts when available.

Select **documentation** agent:

```text
Update documentation for the notification service. The v2.3 release added
WebSocket support for real-time notifications. Update the API reference in
docs/api/notifications.md and add a WebSocket connection example to the
getting started guide.
```

```text
Select documentation agent in drift mode. Sync docs with recent changes.
```

### Media Processing

The video-to-gif skill converts video files to optimized GIF format using FFmpeg two-pass encoding. Invoke the skill directly when you need this conversion.

Refer to the [video-to-gif skill](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/video-to-gif/SKILL.md) for detailed usage, parameters, and optimization options.

### Git Workflows

Git utilities manage commit messages, merge operations, and pull request creation across all roles.

| Prompt             | Purpose                                 | Invoke                |
|--------------------|-----------------------------------------|-----------------------|
| git-commit         | Conventional commit message generation  | `/git-commit`         |
| git-commit-message | Commit message from staged changes      | `/git-commit-message` |
| git-merge          | Merge, rebase, and conflict resolution  | `/git-merge`          |
| pull-request       | Pull request creation with templates    | `/pull-request`       |
| git-setup          | Git configuration and environment setup | `/git-setup`          |

### Asset Resolution

When you reference a prompt, instruction, agent, or skill that does not exist in the current project directory, Copilot falls back to the hve-core repository location. This resolution follows the `hve-core-location.instructions.md` pattern, walking up the directory tree until the asset is found.

This fallback activates automatically. No manual configuration is needed.

## Full Asset Reference

### Agents

| Agent             | Category      | Description                                           |
|-------------------|---------------|-------------------------------------------------------|
| **documentation** | Documentation | Documentation audit, drift, authoring, and validation |

### Prompts

| Prompt             | Category    | Invoke                | Description                                      |
|--------------------|-------------|-----------------------|--------------------------------------------------|
| git-commit         | Git         | `/git-commit`         | Conventional commit message generation           |
| git-commit-message | Git         | `/git-commit-message` | Commit message from staged changes               |
| git-merge          | Git         | `/git-merge`          | Merge, rebase, and conflict resolution workflows |
| pull-request       | Git         | `/pull-request`       | Pull request creation with template support      |
| git-setup          | Git         | `/git-setup`          | Git configuration and environment setup          |
| ado-get-build-info | Diagnostics | `/ado-get-build-info` | Azure DevOps build status and log retrieval      |

### Skills

| Skill        | Category     | Description                             |
|--------------|--------------|-----------------------------------------|
| installer    | Installation | HVE Core customized installation        |
| video-to-gif | Media        | FFmpeg two-pass video-to-GIF conversion |

## Tips

| Do                                                                         | Don't                                                      |
|----------------------------------------------------------------------------|------------------------------------------------------------|
| Resume from the durable artifacts owned by each workflow                   | Rely on a conversation transcript as authoritative state   |
| Use `/git-commit` for all commits to maintain conventions                  | Write ad-hoc commit messages that skip conventional format |
| Ask any agent "help me customize hve-core installation" to configure setup | Install `hve-core-all` when you only need one collection   |
| Refer to the skill docs for media processing parameters                    | Guess at FFmpeg options without consulting the skill file  |

## Next Steps

> [!TIP]
> Find your role-specific guide: [Role Guides Overview](./)
> Explore collection options: [Role Overview](./#role-overview)
> Get started with installation: [Install Guide](../../getting-started/install.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
