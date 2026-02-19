---
name: pr-reference
description: 'Generates PR reference XML containing commit history and unified diffs between branches. Includes utilities to list changed files and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core'
user-invocable: true
compatibility: 'Requires git available on PATH'
---

# PR Reference Generation Skill

Queries git for commit metadata and diff output, then produces a structured XML document. Both bash and PowerShell implementations are provided.

Use cases:

* PR description generation from commit history
* Code review preparation with structured diff context
* Work item discovery by analyzing branch changes
* Security analysis of modified files

After successful generation, include a file link to the absolute path of the XML output in the response.

## Prerequisites

The repository must have at least one commit diverging from the base branch.

### Platform Requirements

| Platform      | Runtime                    |
| ------------- | -------------------------- |
| macOS / Linux | Bash (pre-installed)       |
| Windows       | PowerShell 7+ (pwsh)       |
| Cross-platform | PowerShell 7+ (pwsh)      |

## Quick Start

Generate a PR reference using default settings (compares against `origin/main`):

```bash
./scripts/generate.sh
```

```powershell
./scripts/generate.ps1
```

Output saves to `.copilot-tracking/pr/pr-reference.xml` by default.

## Parameters Reference

| Parameter          | Flag (bash)     | Flag (PowerShell)       | Default                                       | Description                                 |
| ------------------ | --------------- | ----------------------- | --------------------------------------------- | ------------------------------------------- |
| Base branch        | `--base-branch` | `-BaseBranch`           | `origin/main` (bash) / `main` (PowerShell)    | Target branch for comparison                |
| Exclude markdown   | `--no-md-diff`  | `-ExcludeMarkdownDiff`  | false                                         | Exclude markdown files (*.md) from the diff |
| Output path        | `--output`      | `-OutputPath`           | `.copilot-tracking/pr/pr-reference.xml`       | Custom output file path                     |

The PowerShell script automatically resolves `origin/<branch>` when a bare branch name is provided for `-BaseBranch`.

## Utility Scripts

After generating the PR reference, use these utility scripts to query the XML without manual terminal commands.

### List Changed Files

Extract file paths from the diff:

```bash
# List all changed files
./scripts/list-changed-files.sh

# Filter by change type
./scripts/list-changed-files.sh --type added

# Output as markdown table
./scripts/list-changed-files.sh --format markdown
```

```powershell
# List all changed files
./scripts/list-changed-files.ps1

# Filter by change type
./scripts/list-changed-files.ps1 -Type Added

# Output as JSON
./scripts/list-changed-files.ps1 -Format Json
```

### Read Diff Content

Read diff content with chunking support for large diffs:

```bash
# Show chunk info (how many chunks, line ranges)
./scripts/read-diff.sh --info

# Read a specific chunk (default 500 lines/chunk)
./scripts/read-diff.sh --chunk 1

# Read by line range
./scripts/read-diff.sh --lines 200,800

# Extract diff for a specific file
./scripts/read-diff.sh --file src/main.ts

# Show summary with file stats
./scripts/read-diff.sh --summary
```

```powershell
# Show chunk info
./scripts/read-diff.ps1 -Info

# Read a specific chunk
./scripts/read-diff.ps1 -Chunk 1

# Read by line range
./scripts/read-diff.ps1 -Lines "200,800"

# Extract diff for a specific file
./scripts/read-diff.ps1 -File "src/main.ts"
```

## Output Format

The generated XML follows this structure:

```xml
<commit_history>
  <current_branch>feature/example</current_branch>
  <base_branch>origin/main</base_branch>
  <commits>
    <commit hash="abc1234" date="2026-01-15">
      <message>
        <subject><![CDATA[feat: add new feature]]></subject>
        <body><![CDATA[Detailed description]]></body>
      </message>
    </commit>
  </commits>
  <full_diff>
    <!-- unified diff output -->
  </full_diff>
</commit_history>
```

See the [reference guide](references/REFERENCE.md) for the complete XML schema, output path variations, and workflow integration patterns.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
