---
title: Contributing Skills to HVE Core
description: Requirements and standards for contributing skill packages to hve-core
author: Microsoft
ms.date: 2026-02-16
ms.topic: how-to
keywords:
  - skills
  - contributing
  - ai artifacts
estimated_reading_time: 8
---

This guide defines the requirements, standards, and best practices for contributing skill packages to the hve-core library.

**⚙️ Common Standards**: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## What is a Skill?

A **skill** is a self-contained package that provides guidance and utilities for specific tasks. Unlike agents or prompts that guide conversation flows, skills bundle documentation, and optionally executable scripts, to perform concrete operations. A skill can be purely documentation-driven (providing structured knowledge and instructions) or can include cross-platform scripts for automated task execution.

## Skill vs Agent vs Prompt

| Artifact | Purpose                       | Includes Scripts | User Interaction         |
|----------|-------------------------------|------------------|--------------------------|
| Skill    | Task execution with utilities | Optional         | Minimal after invocation |
| Agent    | Conversational guidance       | No               | Multi-turn conversation  |
| Prompt   | Single-session workflow       | No               | One-shot execution       |

## Use Cases for Skills

Create a skill when you need to:

* Package structured knowledge and instructions for a specific task domain
* Bundle documentation with executable scripts for automated task execution
* Provide cross-platform utilities (bash and PowerShell)
* Standardize common development tasks
* Share reusable tooling across projects

## Skills Not Accepted

The following skill types will likely be **rejected**:

* **Duplicate Skills**: Skills that replicate functionality of existing tools or skills
* **Single-Platform Scripts**: Skills that include scripts for only one operating system (when scripts are present, both `.sh` and `.ps1` are required)
* **Undocumented Utilities**: Scripts without comprehensive SKILL.md documentation

## File Structure Requirements

### Location

All skill files **MUST** be placed in:

```text
.github/skills/<skill-name>/
├── SKILL.md                    # Main skill definition (required)
├── scripts/                    # Executable scripts (optional)
│   ├── <action>.sh             # Bash script for macOS/Linux
│   └── <action>.ps1            # PowerShell script for Windows
├── references/                 # Additional documentation (optional)
│   └── REFERENCE.md            # Detailed technical reference
├── assets/                     # Static resources (optional)
│   └── templates/              # Document or configuration templates
└── examples/
    └── README.md               # Usage examples (recommended)
```

The `scripts/` directory is **optional**. When present, it **MUST** contain at least one `.sh` file and at least one `.ps1` file for cross-platform support. Skills without scripts are valid and function as documentation-driven knowledge packages.

### Naming Convention

* Use lowercase kebab-case for directory names: `video-to-gif`
* Main definition file MUST be named `SKILL.md`
* Script names should describe their action: `convert.sh`, `validate.ps1`
* Only recognized subdirectories are allowed: `scripts`, `references`, `assets`, `examples`

## Frontmatter Requirements

### Required Fields

**`name`** (string, MANDATORY)

* **Purpose**: Unique identifier for the skill
* **Format**: Lowercase kebab-case matching the directory name
* **Example**: `video-to-gif`

**`description`** (string, MANDATORY)

* **Purpose**: Concise explanation of skill functionality
* **Format**: Single sentence ending with attribution
* **Example**: `'Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core'`

### Frontmatter Example

```yaml
---
name: video-to-gif
description: 'Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core'
---
```

### Optional Fields

**`user-invocable`** (boolean, optional)

* **Purpose**: Controls visibility in the VS Code slash command menu
* **Default**: `true`
* **When true**: Skill appears in the `/` menu for manual invocation via `/skill-name`
* **When false**: Skill does not appear in the `/` menu; loaded only by semantic matching or explicit `#file:` reference
* **Use case**: Set `false` for background skills that support other workflows without direct user invocation

**`disable-model-invocation`** (boolean, optional)

* **Purpose**: Controls whether Copilot automatically loads the skill via semantic matching
* **Default**: `false`
* **When false**: Copilot loads the skill automatically when the task description semantically matches the `description` field
* **When true**: Skill is only loaded via manual `/skill-name` slash command invocation
* **Use case**: Set `true` for skills with high token cost or niche applicability that should not load automatically

**`argument-hint`** (string, optional)

* **Purpose**: Displays expected inputs in the VS Code prompt picker
* **Format**: Brief text with required arguments first, then optional arguments
* **Conventions**: Use `[]` for positional arguments, `key=value` for named parameters, `{option1|option2}` for enumerations, `...` for free-form text
* **Example**: `"input=video.mp4 [--fps={5|10|15|24}] [--width=1280]"`

### Invocation Control Matrix

| `user-invocable` | `disable-model-invocation` | `/` Menu | Semantic Loading | Invocation Method           |
|------------------|----------------------------|----------|------------------|-----------------------------|
| `true` (default) | `false` (default)          | Yes      | Yes              | Automatic + manual          |
| `true`           | `true`                     | Yes      | No               | Manual `/skill-name` only   |
| `false`          | `false`                    | No       | Yes              | Automatic only              |
| `false`          | `true`                     | No       | No               | Only via `#file:` reference |

### Frontmatter Example with Optional Fields

```yaml
---
name: pr-reference
description: 'Generate PR reference XML files with commit history and diffs for pull request workflows - Brought to you by microsoft/hve-core'
user-invocable: true
disable-model-invocation: false
argument-hint: "[--base-branch=origin/main] [--exclude-markdown]"
---
```

This example demonstrates a skill configured for both automatic semantic loading and manual `/pr-reference` invocation, with argument hints displayed in the prompt picker.

## Collection Entry Requirements

All skills must have matching entries in one or more `collections/*.collection.yml` manifests. Collection entries control distribution and maturity.

### Adding Your Skill to a Collection

After creating your skill package, add an `items[]` entry in each target collection manifest:

```yaml
items:
  - path: .github/skills/my-skill
    kind: skill
    maturity: stable
```

### Selecting Collections for Skills

Choose collections based on who uses the skill's utilities:

| Skill Type           | Recommended Collections              |
|----------------------|--------------------------------------|
| Media processing     | `hve-core-all`                       |
| Documentation tools  | `hve-core-all`, `prompt-engineering` |
| Data processing      | `hve-core-all`, `data-science`       |
| Infrastructure tools | `hve-core-all`, `coding-standards`   |
| Code generation      | `hve-core-all`, `coding-standards`   |

For complete collection documentation, see [AI Artifacts Common Standards - Collection Manifests](ai-artifacts-common.md#collection-manifests).

## SKILL.md Content Structure

### Required Sections

#### 1. Title (H1)

Clear, descriptive heading matching skill purpose:

```markdown
# Video-to-GIF Conversion Skill
```

#### 2. Overview

Explains what the skill does and its approach:

```markdown
This skill converts video files to optimized GIF animations using FFmpeg two-pass palette optimization.
```

#### 3. Prerequisites

Lists installation requirements for each platform:

```markdown
## Prerequisites

FFmpeg MUST be installed and available in your system PATH.

### macOS

\`\`\`bash
brew install ffmpeg
\`\`\`

### Linux

\`\`\`bash
sudo apt install ffmpeg
\`\`\`

### Windows

\`\`\`powershell
choco install ffmpeg
\`\`\`
```

#### 4. Quick Start

Shows basic usage with default settings:

```markdown
## Quick Start

\`\`\`bash
./.github/skills/video-to-gif/convert.sh input.mp4
\`\`\`
```

#### 5. Parameters Reference (when scripts are included)

Documents all configurable options with defaults. Include this section when the skill contains scripts with configurable parameters.

```markdown
## Parameters

| Parameter | Default | Description  |
|-----------|---------|--------------|
| --fps     | 10      | Frame rate   |
| --width   | 480     | Output width |
```

#### 6. Script Reference (when scripts are included)

Documents both bash and PowerShell usage. Include this section when the skill contains a `scripts/` directory.

```markdown
## Script Reference

### convert.sh (Bash)

\`\`\`bash
./convert.sh --input video.mp4 --fps 15
\`\`\`

### convert.ps1 (PowerShell)

\`\`\`powershell
./convert.ps1 -InputPath video.mp4 -Fps 15
\`\`\`
```

#### 7. Troubleshooting

Common issues and solutions:

```markdown
## Troubleshooting

### Tool not found

Verify the dependency is in your PATH...
```

#### 8. Attribution Footer

Include at end of file:

```markdown
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
```

## Script Requirements

Scripts are **optional** for skills. A skill can function purely as a documentation-driven knowledge package without any scripts. When a skill includes a `scripts/` directory, both bash and PowerShell implementations are **required** for cross-platform support.

### Bash Scripts

Bash scripts **MUST**:

* Use `#!/usr/bin/env bash` shebang
* Enable strict mode: `set -euo pipefail`
* Follow main function pattern
* Include usage function with `--help` support
* Check for required dependencies
* Handle platform differences (macOS vs Linux)

See [bash.instructions.md](../../.github/instructions/bash/bash.instructions.md) for complete standards.

### PowerShell Scripts

PowerShell scripts **MUST**:

* Use `[CmdletBinding()]` attribute
* Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
* Validate parameters with `[ValidateScript()]`, `[ValidateRange()]`, or `[ValidateSet()]`
* Check for required dependencies
* Use proper error handling

## Examples Directory

The `examples/` subdirectory **SHOULD** include:

* Quick usage examples for common scenarios
* Test data generation instructions
* Quality comparison guides
* Batch processing patterns

## Semantic Skill Loading

VS Code Copilot uses progressive disclosure to load skills efficiently. Understanding this model helps authors write effective `description` fields and helps callers invoke skills correctly.

### How Skills are Discovered

Copilot reads the `name` and `description` fields from all SKILL.md files at startup. This lightweight metadata (~100 tokens per skill) enables relevance matching without loading full skill content.

### How Skills are Loaded

When a user request or caller description semantically matches a skill's `description`:

1. **Level 1 (Discovery)**: Copilot matches the task against `name` and `description` frontmatter (always loaded, ~100 tokens per skill).
2. **Level 2 (Instructions)**: The full SKILL.md body loads into context with script usage, parameters, and troubleshooting (<5000 tokens recommended).
3. **Level 3 (Resources)**: Scripts, examples, and references in the skill directory load on-demand during execution.

### Writing Effective Descriptions

The `description` field is the semantic key for automatic loading. Craft descriptions that are:

* Specific enough for accurate matching (include the primary action verb and artifact type)
* Broad enough to cover all use cases (avoid narrowing to one scenario)
* Containing searchable terms that callers naturally use

### How Callers Invoke Skills

Prompts, agents, and instructions should describe the task intent rather than referencing script paths. Copilot matches task descriptions against skill `description` fields and loads the skill on-demand.

Avoid hardcoded script paths, platform detection logic, or extension fallback code in caller files.

For explicit invocation, use the `/skill-name` slash command in chat.

## Validation Checklist

Before submitting your skill, verify:

### Structure

* [ ] Directory at `.github/skills/<skill-name>/`
* [ ] SKILL.md present with valid frontmatter
* [ ] If `scripts/` directory exists: both `.sh` and `.ps1` files present
* [ ] Only recognized subdirectories used (`scripts`, `references`, `assets`, `examples`)
* [ ] Examples README (recommended)

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `name` field present and matches directory name
* [ ] `description` field present and descriptive
* [ ] Optional: `user-invocable` set appropriately (default `true` works for most skills)
* [ ] Optional: `disable-model-invocation` set appropriately (default `false` works for most skills)
* [ ] Optional: `argument-hint` provides useful input guidance if set

### Scripts (when included)

* [ ] `scripts/` directory contains at least one `.sh` and one `.ps1` file
* [ ] Bash script follows bash.instructions.md
* [ ] PowerShell script passes PSScriptAnalyzer
* [ ] Both scripts implement equivalent functionality
* [ ] Help and usage documentation included

### Documentation

* [ ] All required SKILL.md sections present
* [ ] Prerequisites documented per platform
* [ ] Parameters fully documented
* [ ] Troubleshooting section included
* [ ] Attribution footer present

## Automated Validation

Run these commands before submission:

```bash
npm run lint:frontmatter      # Validate SKILL.md frontmatter
npm run lint:ps               # Validate PowerShell scripts (when present)
npm run lint:md               # Validate markdown formatting
npm run validate:skills       # Validate skill directory structure
```

All checks **MUST** pass before merge.

## Related Documentation

* [AI Artifacts Common Standards](ai-artifacts-common.md) - Shared standards for all contributions
* [Contributing Agents](custom-agents.md) - Agent file guidelines
* [Contributing Prompts](prompts.md) - Prompt file guidelines
* [Contributing Instructions](instructions.md) - Instructions file guidelines
* [Agent Skills Specification](https://agentskills.io/specification) - Core specification for skill structure and metadata
* [VS Code Copilot Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) - VS Code integration, progressive disclosure, and frontmatter controls

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
