---
title: GitHub Copilot Instructions
description: Repository-specific coding guidelines and conventions for GitHub Copilot
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - copilot
  - instructions
  - coding standards
  - guidelines
estimated_reading_time: 3
---

## GitHub Copilot Instructions

Repository-specific guidelines that GitHub Copilot automatically applies when
editing files. Instructions ensure consistent code style and conventions across
the codebase.

## How It Works

1. Instruction files declare which file patterns they apply to using `applyTo`
   in frontmatter
2. GitHub Copilot reads instructions when editing matching files
3. Suggestions follow the documented standards automatically

## Chat Mode Integration

Chat modes reference and apply instructions automatically:

- **`@prompt-builder`** creates new instruction files in this directory
- **All chat modes** respect instructions matching file patterns via `applyTo`
  field
- **Copilot** loads instructions when editing files matching the patterns
- Instructions provide repository-specific guardrails and conventions

See [Chat Modes README](../chatmodes/README.md) for details on using `@prompt-builder`.

## XML-Style Blocks

Instructions use XML-style comment blocks for structured content:

- **Purpose:** Enable automated extraction, better navigation, consistency
- **Format:** Kebab-case tags in HTML comments on their own lines
- **Examples:** `<!-- <example-bash> -->`, `<!-- <schema-config> -->`,
  `<!-- <important-rules> -->`
- **Nesting:** Allowed with distinct tag names
- **Closing:** Always required with matching tag names

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

## Available Instructions

| File | Applies To | Purpose |
|------|------------|---------|
| [commit-message.instructions.md](commit-message.instructions.md) | `commit` | Conventional commit message format and standards |
| [markdown.instructions.md](markdown.instructions.md) | `**/*.md` | Markdown formatting standards and style guide |

## Creating New Instructions

### Recommended Approach

1. Use `@prompt-builder` chat mode for creation
2. Provide context (files, folders, or requirements)
3. Prompt Builder researches and drafts instructions
4. Auto-validates with Prompt Tester (up to 3 iterations)
5. Delivered to `.github/instructions/`

### Manual Creation

1. Create a `.md` file in this directory
2. Add frontmatter with `description` and `applyTo` fields:

   ```yaml
   ---
   description: "Brief purpose"
   applyTo: 'glob-pattern'
   ---
   ```

3. Document rules clearly with examples using XML-style blocks
4. Test instructions with Copilot before committing
5. Update this README's table

## Best Practices

- Use specific file patterns to avoid over-applying rules
- Include code examples for clarity
- Keep instructions focused and actionable
- Test instructions with Copilot before committing

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.
