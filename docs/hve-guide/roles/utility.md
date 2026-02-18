---
title: Utility Reference
description: Cross-cutting HVE Core utilities for memory, documentation, media, Git workflows, and diagnostic operations
author: Microsoft
ms.date: 2026-02-18
ms.topic: reference
keywords:
  - utility
  - memory
  - documentation
  - Git workflows
  - cross-cutting
estimated_reading_time: 8
---

Use these cross-cutting utilities when your workflow spans multiple roles or lifecycle stages. These tools handle memory persistence, documentation maintenance, media processing, Git workflows, and installation management. Use them alongside your role-specific agents and prompts.

## Utility Categories

| Category      | Assets | Purpose                                             |
|---------------|--------|-----------------------------------------------------|
| Memory        | 1      | Session context and preference persistence          |
| Documentation | 2      | Documentation operations and checkpoint summaries   |
| Media         | 1      | Video-to-GIF conversion with FFmpeg optimization    |
| Git           | 3      | Commit messages, merge workflows, PR creation       |
| Installation  | 1      | Collection installation and environment setup       |
| Diagnostics   | 1      | Build information retrieval and CI/CD status checks |

## Usage Patterns

### Memory Persistence

The `@memory` agent stores preferences, context, and notes that persist across sessions. Use it to save coding preferences, project-specific conventions, or working state that should carry forward.

```text
@memory Save my preference for {convention}
```

```text
@memory What do you know about {topic}?
```

### Documentation Operations

The `@doc-ops` agent handles documentation updates, link validation, and content maintenance. The `/checkpoint` prompt creates session summaries for complex multi-step workflows.

```text
@doc-ops Update documentation for {component}
```

```text
/doc-ops-update Sync docs with recent changes
```

```text
/checkpoint Summarize progress on {task}
```

### Media Processing

The video-to-gif skill converts video files to optimized GIF format using FFmpeg two-pass encoding. This skill activates through the `@memory` or general chat context.

Refer to the [video-to-gif skill](../../.github/skills/video-to-gif/SKILL.md) for detailed usage, parameters, and optimization options.

### Git Workflows

Git utilities manage commit messages, merge operations, and pull request creation across all roles.

| Prompt             | Purpose                                 | Invoke                |
|--------------------|-----------------------------------------|-----------------------|
| git-commit         | Conventional commit message generation  | `/git-commit`         |
| git-commit-message | Commit message from staged changes      | `/git-commit-message` |
| git-merge          | Merge, rebase, and conflict resolution  | `/git-merge`          |
| pull-request       | Pull request creation with templates    | `/pull-request`       |
| git-setup          | Git configuration and environment setup | `/git-setup`          |

### Installation and Setup

The `@hve-core-installer` agent manages collection installation. Use it to install, update, or verify collections.

```text
@hve-core-installer install {collection-name}
```

```text
@hve-core-installer install rpi coding-standards
```

See the [Collection Quick Reference](README.md#collection-quick-reference) for available collections and their primary roles.

### Asset Resolution

When you reference a prompt, instruction, agent, or skill that does not exist in the current project directory, Copilot falls back to the hve-core repository location. This resolution follows the `hve-core-location.instructions.md` pattern, walking up the directory tree until the asset is found.

This fallback activates automatically. No manual configuration is needed.

## Full Asset Reference

### Agents

| Agent              | Category      | Invoke                | Description                                  |
|--------------------|---------------|-----------------------|----------------------------------------------|
| memory             | Memory        | `@memory`             | Session context and preference persistence   |
| doc-ops            | Documentation | `@doc-ops`            | Documentation operations and maintenance     |
| hve-core-installer | Installation  | `@hve-core-installer` | Collection installation and setup management |

### Prompts

| Prompt             | Category      | Invoke                | Description                                      |
|--------------------|---------------|-----------------------|--------------------------------------------------|
| git-commit         | Git           | `/git-commit`         | Conventional commit message generation           |
| git-commit-message | Git           | `/git-commit-message` | Commit message from staged changes               |
| git-merge          | Git           | `/git-merge`          | Merge, rebase, and conflict resolution workflows |
| pull-request       | Git           | `/pull-request`       | Pull request creation with template support      |
| git-setup          | Git           | `/git-setup`          | Git configuration and environment setup          |
| checkpoint         | Documentation | `/checkpoint`         | Session progress summary and state capture       |
| doc-ops-update     | Documentation | `/doc-ops-update`     | Documentation sync and update operations         |
| ado-get-build-info | Diagnostics   | `/ado-get-build-info` | Azure DevOps build status and log retrieval      |

### Skills

| Skill        | Category | Description                             |
|--------------|----------|-----------------------------------------|
| video-to-gif | Media    | FFmpeg two-pass video-to-GIF conversion |

## Tips

| Do                                                        | Don't                                                      |
|-----------------------------------------------------------|------------------------------------------------------------|
| Use `@memory` to save preferences early in a session      | Repeat the same context setup in every conversation        |
| Use `/checkpoint` during long, multi-step workflows       | Lose progress context in extended sessions                 |
| Use `/git-commit` for all commits to maintain conventions | Write ad-hoc commit messages that skip conventional format |
| Install only the collections your role needs              | Install `hve-core-all` when you only need one collection   |
| Refer to the skill docs for media processing parameters   | Guess at FFmpeg options without consulting the skill file  |

## Next Steps

> [!TIP]
> Find your role-specific guide: [Role Guides Overview](README.md)
> Explore collection options: [Collection Quick Reference](README.md#collection-quick-reference)
> Get started with installation: [Install Guide](../getting-started/install.md)

---

> [!NOTE]
> Automated documentation freshness validation (GAP-09) and collection dependency resolution (GAP-07) are planned improvements. Current workflows rely on manual verification of asset availability and documentation accuracy.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
