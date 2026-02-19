---
name: pr-reference
description: 'Generate PR reference XML with commit history and diffs; includes utilities to list changed files and read diff chunks - Brought to you by microsoft/hve-core'
user-invocable: true
---

# PR Reference Generation Skill

This skill generates XML reference files containing commit history and diffs between the current branch and a base branch. The output provides structured context for PR descriptions, code reviews, work item discovery, and security analysis.

## Overview

The PR reference generator queries git for commit metadata and diff output, then produces a structured XML document. Both bash and PowerShell implementations are provided for cross-platform support. The generated XML uses CDATA-wrapped commit messages and full unified diffs, enabling downstream consumers to extract change summaries, identify affected files, and analyze code modifications.

Use cases:

* PR description generation from commit history
* Code review preparation with structured diff context
* Work item discovery by analyzing branch changes
* Security analysis of modified files

## Response Format

After successful generation, include a file link to the XML output in the response:

```markdown
/absolute/path/to/pr-reference.xml
```

This allows the user to open the file and review the generated reference data.

## Prerequisites

Git is required and must be available in your system PATH. The repository must have at least one commit diverging from the base branch.

### Verify Git Installation

```bash
git --version
```

### Platform Requirements

| Platform      | Runtime                    |
| ------------- | -------------------------- |
| macOS / Linux | Bash (pre-installed)       |
| Windows       | PowerShell 7+ (pwsh)       |
| Cross-platform | PowerShell 7+ (pwsh)      |

## Quick Start

Generate a PR reference using default settings (compares against `origin/main`):

```bash
./.github/skills/pr-reference/scripts/generate.sh
```

```powershell
./.github/skills/pr-reference/scripts/generate.ps1
```

Output saves to `.copilot-tracking/pr/pr-reference.xml` by default.

## Parameters Reference

| Parameter          | Flag (bash)     | Flag (PowerShell)       | Default                                       | Description                                 |
| ------------------ | --------------- | ----------------------- | --------------------------------------------- | ------------------------------------------- |
| Base branch        | `--base-branch` | `-BaseBranch`           | `origin/main` (bash) / `main` (PowerShell)    | Target branch for comparison                |
| Exclude markdown   | `--no-md-diff`  | `-ExcludeMarkdownDiff`  | false                                         | Exclude markdown files (*.md) from the diff |
| Output path        | `--output`      | `-OutputPath`           | `.copilot-tracking/pr/pr-reference.xml`       | Custom output file path                     |

### Base Branch

The base branch determines the comparison point for commit history and diffs. The PowerShell script automatically resolves `origin/<branch>` when a bare branch name is provided.

### Exclude Markdown

Excluding markdown files is useful when generating PR descriptions where documentation changes would add noise to the diff context. The exclusion applies to both the diff output and the diff summary.

### Output Path

Custom output paths support branch-specific tracking directories and alternative filenames. Parent directories are created automatically when they do not exist.

## Script Reference

### generate.sh (Bash)

```bash
# Default usage
./generate.sh

# Custom base branch
./generate.sh --base-branch origin/develop

# Exclude markdown from diff
./generate.sh --no-md-diff

# Custom output path
./generate.sh --output .copilot-tracking/pr/review/feature-branch/pr-reference.xml

# Combined flags
./generate.sh --base-branch origin/release --no-md-diff --output /tmp/pr-ref.xml
```

### generate.ps1 (PowerShell)

```powershell
# Default usage
./generate.ps1

# Custom base branch
./generate.ps1 -BaseBranch develop

# Exclude markdown from diff
./generate.ps1 -ExcludeMarkdownDiff

# Custom output path
./generate.ps1 -OutputPath .copilot-tracking/pr/review/feature-branch/pr-reference.xml

# Combined flags
./generate.ps1 -BaseBranch release -ExcludeMarkdownDiff -OutputPath /tmp/pr-ref.xml
```

## Utility Scripts

After generating the PR reference, use these utility scripts to query the XML without manual terminal commands.

### List Changed Files

Extract file paths from the diff:

```bash
# List all changed files
./.github/skills/pr-reference/scripts/list-changed-files.sh

# Filter by change type
./.github/skills/pr-reference/scripts/list-changed-files.sh --type added

# Output as markdown table
./.github/skills/pr-reference/scripts/list-changed-files.sh --format markdown
```

```powershell
# List all changed files
./.github/skills/pr-reference/scripts/list-changed-files.ps1

# Filter by change type
./.github/skills/pr-reference/scripts/list-changed-files.ps1 -Type Added

# Output as JSON
./.github/skills/pr-reference/scripts/list-changed-files.ps1 -Format Json
```

### Read Diff Content

Read diff content with chunking support for large diffs:

```bash
# Show chunk info (how many chunks, line ranges)
./.github/skills/pr-reference/scripts/read-diff.sh --info

# Read a specific chunk (default 500 lines/chunk)
./.github/skills/pr-reference/scripts/read-diff.sh --chunk 1

# Read by line range
./.github/skills/pr-reference/scripts/read-diff.sh --lines 200,800

# Extract diff for a specific file
./.github/skills/pr-reference/scripts/read-diff.sh --file src/main.ts

# Show summary with file stats
./.github/skills/pr-reference/scripts/read-diff.sh --summary
```

```powershell
# Show chunk info
./.github/skills/pr-reference/scripts/read-diff.ps1 -Info

# Read a specific chunk
./.github/skills/pr-reference/scripts/read-diff.ps1 -Chunk 1

# Read by line range
./.github/skills/pr-reference/scripts/read-diff.ps1 -Lines "200,800"

# Extract diff for a specific file
./.github/skills/pr-reference/scripts/read-diff.ps1 -File "src/main.ts"
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

## Troubleshooting

### Git not found

Verify git is in your PATH:

```bash
which git        # macOS/Linux
where.exe git    # Windows
```

If git is installed but not found, add its directory to your PATH environment variable.

### No commits between branches

When the current branch has no commits diverging from the base branch, the XML will contain empty `<commits>` and `<full_diff>` elements. Verify you are on the correct branch and that commits exist:

```bash
git log origin/main..HEAD --oneline
```

### Branch does not exist

The script exits with an error when the specified base branch cannot be resolved. Verify the branch name and fetch remote refs:

```bash
git fetch origin
git branch -a | grep <branch-name>
```

### Large diffs

Diffs exceeding 1000 lines of impact trigger a warning in the PowerShell script. Consider rebasing onto the intended base branch or narrowing changes if the scope is unexpected. Use `--no-md-diff` to exclude documentation changes when they add noise.

### Output directory creation fails

Both scripts create parent directories automatically. If creation fails, verify write permissions to the target path. Use an absolute path to avoid ambiguity with the working directory.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
