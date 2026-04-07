---
name: pr-reference
description: 'Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core'
license: MIT
user-invocable: true
compatibility: 'Requires git available on PATH'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-03-16"
---

# PR Reference Generation Skill

## Overview

Queries git for commit metadata and diff output, then produces a structured XML document. Both bash and PowerShell implementations are provided.

Use cases:

* PR description generation from commit history
* Code review preparation with structured diff context
* Work item discovery by analyzing branch changes
* Security analysis of modified files

After successful generation, include a file link to the absolute path of the XML output in the response.

## Prerequisites

The repository must have at least one commit diverging from the base branch.

| Platform       | Runtime              |
|----------------|----------------------|
| macOS / Linux  | Bash (pre-installed) |
| Windows        | PowerShell 7+ (pwsh) |
| Cross-platform | PowerShell 7+ (pwsh) |

## Quick Start

Run the following command to generate a PR reference with default settings (compares against `origin/main`):

```bash
scripts/generate.sh
scripts/generate.sh --base-branch auto --merge-base --exclude-ext yml,json
```

```powershell
scripts/generate.ps1
scripts/generate.ps1 -BaseBranch auto -MergeBase -ExcludeExt yml,json
```

Output saves to `.copilot-tracking/pr/pr-reference.xml` by default.

## Parameters Reference

| Parameter          | Flag (bash)      | Flag (PowerShell)      | Default                                    | Description                                                        |
|--------------------|------------------|------------------------|--------------------------------------------|--------------------------------------------------------------------|
| Base branch        | `--base-branch`  | `-BaseBranch`          | `origin/main` (bash) / `main` (PowerShell) | Target branch for comparison. Use `auto` to detect remote default. |
| Merge base         | `--merge-base`   | `-MergeBase`           | false                                      | Use `git merge-base` for three-way comparison                      |
| Exclude markdown   | `--no-md-diff`   | `-ExcludeMarkdownDiff` | false                                      | Exclude markdown files (*.md) from the diff                        |
| Exclude extensions | `--exclude-ext`  | `-ExcludeExt`          | (none)                                     | Comma-separated extensions to exclude (e.g., `yml,yaml,json,png`)  |
| Exclude paths      | `--exclude-path` | `-ExcludePath`         | (none)                                     | Comma-separated path prefixes to exclude (e.g., `docs/,.github/`)  |
| Output path        | `--output`       | `-OutputPath`          | `.copilot-tracking/pr/pr-reference.xml`    | Custom output file path                                            |

Both defaults resolve to the same remote comparison. The PowerShell script automatically resolves `origin/<branch>` when a bare branch name is provided.

## Additional Scripts Reference

After generating the PR reference, use these utility scripts to query the XML.

### List Changed Files

Run the list script to extract file paths from the diff:

```bash
scripts/list-changed-files.sh                              # all changed files
scripts/list-changed-files.sh --type added                  # filter by single type
scripts/list-changed-files.sh --type added,modified,renamed  # filter by multiple types
scripts/list-changed-files.sh --exclude-type deleted         # exclude specific types
scripts/list-changed-files.sh --format markdown              # output as markdown table
```

```powershell
scripts/list-changed-files.ps1                             # all changed files
scripts/list-changed-files.ps1 -Type Added                  # filter by single type
scripts/list-changed-files.ps1 -Type Added,Modified,Renamed # filter by multiple types
scripts/list-changed-files.ps1 -ExcludeType Deleted          # exclude specific types
scripts/list-changed-files.ps1 -Format Json                  # output as JSON
```

| Parameter    | Flag (bash)      | Flag (PowerShell) | Default | Description                                                           |
|--------------|------------------|-------------------|---------|-----------------------------------------------------------------------|
| Input path   | `--input`, `-i`  | `-InputPath`      | (auto)  | Path to pr-reference.xml                                              |
| Type filter  | `--type`, `-t`   | `-Type`           | `all`   | Change types to include (comma-separated: added, modified, etc.)      |
| Exclude type | `--exclude-type` | `-ExcludeType`    | (none)  | Change types to exclude. Mutually exclusive with `--type` (non-`all`) |
| Format       | `--format`, `-f` | `-Format`         | `plain` | Output format: plain, json, or markdown                               |

### Read Diff Content

Run the read script to inspect diff content with chunking for large diffs:

```bash
scripts/read-diff.sh --info             # chunk info (count, line ranges)
scripts/read-diff.sh --chunk 1          # read a specific chunk
scripts/read-diff.sh --file src/main.ts  # extract diff for one file
scripts/read-diff.sh --summary          # file stats summary
```

```powershell
scripts/read-diff.ps1 -Info              # chunk info
scripts/read-diff.ps1 -Chunk 1           # read a specific chunk
scripts/read-diff.ps1 -File "src/main.ts" # extract diff for one file
```

## Output Format

The generated XML wraps commit metadata and unified diff output in a `<commit_history>` root element. See the [reference guide](references/REFERENCE.md) for the complete XML schema, element reference, output path variations, and workflow integration patterns.

## Troubleshooting

| Symptom                         | Cause                                 | Resolution                                                                |
|---------------------------------|---------------------------------------|---------------------------------------------------------------------------|
| "No commits found" or empty XML | No diverging commits from base branch | Verify the branch has commits ahead of the base with `git log base..HEAD` |
| "Branch not found" error        | Base branch ref missing locally       | Run `git fetch origin` to update remote tracking refs                     |
| "git: command not found"        | git is not on PATH                    | Install git or verify PATH includes the git binary directory              |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
