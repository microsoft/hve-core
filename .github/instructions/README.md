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

| File | Applies To | Purpose |
| ---- | ---------- | ------- |
| [bash/bash.instructions.md](bash/bash.instructions.md) | `**/*.sh` | Bash script implementation standards |
| [bicep/bicep.instructions.md](bicep/bicep.instructions.md) | `**/bicep/**` | Bicep infrastructure as code patterns |
| [csharp/csharp.instructions.md](csharp/csharp.instructions.md) | `**/*.cs` | C# implementation and coding conventions |
| [csharp/csharp-tests.instructions.md](csharp/csharp-tests.instructions.md) | `**/*.cs` | C# test code standards |
| [python-script.instructions.md](python-script.instructions.md) | `**/*.py` | Python scripting implementation |
| [terraform/terraform.instructions.md](terraform/terraform.instructions.md) | `**/*.tf, **/*.tfvars, **/terraform/**` | Terraform infrastructure as code |
| [uv-projects.instructions.md](uv-projects.instructions.md) | `**/*.py, **/*.ipynb` | Python virtual environments using uv |

### Documentation and Content

| File | Applies To | Purpose |
| ---- | ---------- | ------- |
| [markdown.instructions.md](markdown.instructions.md) | `**/*.md` | Markdown formatting standards |
| [writing-style.instructions.md](writing-style.instructions.md) | `**/*.md` | Voice, tone, and language conventions |
| [prompt-builder.instructions.md](prompt-builder.instructions.md) | `**/*.prompt.md, **/*.agent.md, **/*.instructions.md` | Prompt engineering artifact authoring |

### Git and Workflow

| File | Applies To | Purpose |
| ---- | ---------- | ------- |
| [commit-message.instructions.md](commit-message.instructions.md) | Commit actions | Conventional commit message format |
| [git-merge.instructions.md](git-merge.instructions.md) | Git operations | Merge, rebase, and conflict handling |

### Azure DevOps Integration

| File | Applies To | Purpose |
| ---- | ---------- | ------- |
| [ado-create-pull-request.instructions.md](ado-create-pull-request.instructions.md) | `**/.copilot-tracking/pr/new/**` | Pull request creation protocol |
| [ado-get-build-info.instructions.md](ado-get-build-info.instructions.md) | `**/.copilot-tracking/pr/*-build-*.md` | Build status and log retrieval |
| [ado-update-wit-items.instructions.md](ado-update-wit-items.instructions.md) | `**/.copilot-tracking/workitems/**/handoff-logs.md` | Work item creation and updates |
| [ado-wit-discovery.instructions.md](ado-wit-discovery.instructions.md) | `**/.copilot-tracking/workitems/discovery/**` | Work item discovery protocol |
| [ado-wit-planning.instructions.md](ado-wit-planning.instructions.md) | `**/.copilot-tracking/workitems/**` | Work item planning specifications |

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
├── bash/
│   └── bash.instructions.md
├── bicep/
│   └── bicep.instructions.md
├── csharp/
│   ├── csharp.instructions.md
│   └── csharp-tests.instructions.md
├── terraform/
│   └── terraform.instructions.md
├── ado-*.instructions.md          # Azure DevOps workflows
├── commit-message.instructions.md
├── git-merge.instructions.md
├── markdown.instructions.md
├── prompt-builder.instructions.md
├── python-script.instructions.md
├── uv-projects.instructions.md
├── writing-style.instructions.md
└── README.md
```

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
