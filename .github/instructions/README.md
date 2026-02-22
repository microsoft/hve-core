---
title: GitHub Copilot Instructions
description: Repository-specific coding guidelines and conventions for GitHub Copilot
author: HVE Core Team
ms.date: 2026-01-17
ms.topic: reference
keywords:
  - copilot
  - instructions
  - coding standards
  - guidelines
estimated_reading_time: 5
---

## GitHub Copilot Instructions

Repository-specific guidelines that GitHub Copilot automatically applies when
editing files. Instructions ensure consistent code style and conventions across
the codebase.

## How Instructions Work

1. Instruction files declare which file patterns they apply to using `applyTo`
   in frontmatter
2. GitHub Copilot reads instructions when editing matching files
3. Suggestions follow the documented standards automatically

Custom agents and the `prompt-builder` agent respect these instructions and can create new ones.
See [Contributing Instructions](../../docs/contributing/instructions.md) for authoring guidance.

## Available Instructions

### Language and Technology

| File                                                                                       | Applies To                                   | Purpose                                  |
|--------------------------------------------------------------------------------------------|----------------------------------------------|------------------------------------------|
| [coding-standards/bash/bash.instructions.md](coding-standards/bash/bash.instructions.md)  | `**/*.sh`                                    | Bash script implementation standards     |
| [coding-standards/bicep/bicep.instructions.md](coding-standards/bicep/bicep.instructions.md) | `**/bicep/**`                             | Bicep infrastructure as code patterns    |
| [coding-standards/csharp/csharp.instructions.md](coding-standards/csharp/csharp.instructions.md) | `**/*.cs`                              | C# implementation and coding conventions |
| [coding-standards/csharp/csharp-tests.instructions.md](coding-standards/csharp/csharp-tests.instructions.md) | `**/*.cs`                      | C# test code standards                   |
| [coding-standards/python-script.instructions.md](coding-standards/python-script.instructions.md) | `**/*.py`                              | Python scripting implementation          |
| [coding-standards/terraform/terraform.instructions.md](coding-standards/terraform/terraform.instructions.md) | `**/*.tf, **/*.tfvars, **/terraform/**` | Terraform infrastructure as code     |
| [coding-standards/uv-projects.instructions.md](coding-standards/uv-projects.instructions.md) | `**/*.py, **/*.ipynb`                    | Python virtual environments using uv     |

### Documentation and Content

| File                                                                          | Applies To                                                    | Purpose                                |
|-------------------------------------------------------------------------------|---------------------------------------------------------------|----------------------------------------|
| [hve-core/markdown.instructions.md](hve-core/markdown.instructions.md)                 | `**/*.md`                                                     | Markdown formatting standards          |
| [hve-core/writing-style.instructions.md](hve-core/writing-style.instructions.md)       | `**/*.md`                                                     | Voice, tone, and language conventions  |
| [hve-core/prompt-builder.instructions.md](hve-core/prompt-builder.instructions.md)     | `**/*.prompt.md, **/*.agent.md, **/*.instructions.md`         | Prompt engineering artifact authoring  |

### Git and Workflow

| File                                                                      | Applies To                       | Purpose                               |
|---------------------------------------------------------------------------|----------------------------------|---------------------------------------|
| [hve-core/commit-message.instructions.md](hve-core/commit-message.instructions.md)       | Commit actions                   | Conventional commit message format    |
| [hve-core/git-merge.instructions.md](hve-core/git-merge.instructions.md)                 | Git operations                   | Merge, rebase, and conflict handling  |
| [hve-core/pull-request.instructions.md](hve-core/pull-request.instructions.md)           | `**/.copilot-tracking/pr/**`     | PR generation workflow with subagents |
| [pull-request.instructions.md](pull-request.instructions.md)                             | `**/.copilot-tracking/pr/**`     | Repo-specific PR conventions          |

### Azure DevOps Integration

| File                                                                                      | Applies To                                              | Purpose                            |
|-------------------------------------------------------------------------------------------|---------------------------------------------------------|------------------------------------|
| [ado/ado-create-pull-request.instructions.md](ado/ado-create-pull-request.instructions.md) | `**/.copilot-tracking/pr/new/**`                      | Pull request creation protocol     |
| [ado/ado-get-build-info.instructions.md](ado/ado-get-build-info.instructions.md)          | `**/.copilot-tracking/pr/*-build-*.md`                  | Build status and log retrieval     |
| [ado/ado-update-wit-items.instructions.md](ado/ado-update-wit-items.instructions.md)      | `**/.copilot-tracking/workitems/**/handoff-logs.md`     | Work item creation and updates     |
| [ado/ado-wit-discovery.instructions.md](ado/ado-wit-discovery.instructions.md)            | `**/.copilot-tracking/workitems/discovery/**`           | Work item discovery protocol       |
| [ado/ado-wit-planning.instructions.md](ado/ado-wit-planning.instructions.md)              | `**/.copilot-tracking/workitems/**`                     | Work item planning specifications  |

## XML-Style Blocks

Instructions use XML-style comment blocks for structured content:

* **Purpose**: Enables automated extraction, better navigation, and consistency
* **Format**: Kebab-case tags in HTML comments on their own lines
* **Examples**: `<!-- <example-bash> -->`, `<!-- <schema-config> -->`
* **Nesting**: Allowed with distinct tag names
* **Closing**: Always required with matching tag names

````markdown
<!-- <example-terraform> -->
```terraform
resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "eastus"
}
```
<!-- </example-terraform> -->
````

## Creating New Instructions

Use the **prompt-builder** agent to create new instruction files:

1. Open Copilot Chat and select **prompt-builder** from the agent picker
2. Provide context (files, folders, or requirements)
3. Prompt Builder researches and drafts instructions
4. Auto-validates with Prompt Tester (up to 3 iterations)
5. Delivered to `.github/instructions/`

For manual creation, see [Contributing Instructions](../../docs/contributing/instructions.md).

## Directory Structure

```text
.github/instructions/
├── ado/                              # Azure DevOps workflows
│   ├── ado-create-pull-request.instructions.md
│   ├── ado-get-build-info.instructions.md
│   ├── ado-update-wit-items.instructions.md
│   ├── ado-wit-discovery.instructions.md
│   └── ado-wit-planning.instructions.md
├── coding-standards/                 # Language and technology conventions
│   ├── bash/
│   │   └── bash.instructions.md
│   ├── bicep/
│   │   └── bicep.instructions.md
│   ├── csharp/
│   │   ├── csharp.instructions.md
│   │   └── csharp-tests.instructions.md
│   ├── terraform/
│   │   └── terraform.instructions.md
│   ├── python-script.instructions.md
│   └── uv-projects.instructions.md
├── github/                           # GitHub integration
│   ├── community-interaction.instructions.md
│   ├── github-backlog-discovery.instructions.md
│   ├── github-backlog-planning.instructions.md
│   ├── github-backlog-triage.instructions.md
│   └── github-backlog-update.instructions.md
├── hve-core/                              # HVE Core workflow
│   ├── commit-message.instructions.md
│   ├── git-merge.instructions.md
│   ├── markdown.instructions.md
│   ├── prompt-builder.instructions.md
│   └── writing-style.instructions.md
├── shared/                           # Cross-collection
│   └── hve-core-location.instructions.md
└── README.md
```

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
