---
title: Contributing Skills to HVE Core
description: Requirements and standards for contributing skill packages to hve-core
author: Microsoft
ms.date: 2026-01-18
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

A **skill** is a self-contained package that provides guidance and utilities for specific tasks. Unlike agents or prompts that guide conversation flows, skills bundle documentation with executable scripts that perform concrete operations.

## Skill vs Agent vs Prompt

| Artifact | Purpose                       | Includes Scripts | User Interaction         |
|----------|-------------------------------|------------------|--------------------------|
| Skill    | Task execution with utilities | Yes              | Minimal after invocation |
| Agent    | Conversational guidance       | No               | Multi-turn conversation  |
| Prompt   | Single-session workflow       | No               | One-shot execution       |

## Use Cases for Skills

Create a skill when you need to:

* Bundle documentation with executable scripts
* Provide cross-platform utilities (bash and PowerShell)
* Standardize common development tasks
* Share reusable tooling across projects

## Skills Not Accepted

The following skill types will likely be **rejected**:

* **Duplicate Skills**: Skills that replicate functionality of existing tools or skills
* **Single-Platform Skills**: Skills that only work on one operating system
* **Undocumented Utilities**: Scripts without comprehensive SKILL.md documentation

## File Structure Requirements

### Location

All skill files **MUST** be placed in:

```text
.github/skills/<skill-name>/
├── SKILL.md                    # Main skill definition (required)
├── convert.sh                  # Bash script (required for cross-platform)
├── convert.ps1                 # PowerShell script (required for cross-platform)
└── examples/
    └── README.md               # Usage examples (recommended)
```

### Naming Convention

* Use lowercase kebab-case for directory names: `video-to-gif`
* Main definition file MUST be named `SKILL.md`
* Script names should describe their action: `convert.sh`, `validate.ps1`

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

**`maturity`** (string enum, MANDATORY)

* **Purpose**: Controls which extension channel includes this skill
* **Valid values**: `stable`, `preview`, `experimental`, `deprecated`

### Frontmatter Example

```yaml
---
name: video-to-gif
description: 'Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core'
maturity: stable
---
```

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

#### 5. Parameters Reference

Documents all configurable options with defaults:

```markdown
## Parameters

| Parameter | Default | Description  |
|-----------|---------|--------------|
| --fps     | 10      | Frame rate   |
| --width   | 480     | Output width |
```

#### 6. Script Reference

Documents both bash and PowerShell usage:

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

## Validation Checklist

Before submitting your skill, verify:

### Structure

* [ ] Directory at `.github/skills/<skill-name>/`
* [ ] SKILL.md present with valid frontmatter
* [ ] Bash script present for macOS/Linux
* [ ] PowerShell script present for Windows
* [ ] Examples README (recommended)

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `name` field present and matches directory name
* [ ] `description` field present and descriptive
* [ ] `maturity` field present with valid value

### Scripts

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
npm run psscriptanalyzer      # Validate PowerShell scripts
npm run lint                  # Validate markdown formatting
```

All checks **MUST** pass before merge.

## Related Documentation

* [AI Artifacts Common Standards](ai-artifacts-common.md) - Shared standards for all contributions
* [Contributing Agents](custom-agents.md) - Agent file guidelines
* [Contributing Prompts](prompts.md) - Prompt file guidelines
* [Contributing Instructions](instructions.md) - Instructions file guidelines

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
