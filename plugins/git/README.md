<!-- markdownlint-disable-file -->
# Git Workflow

Git commit messages, merges, setup, and pull request prompts

## Install

```bash
copilot plugin install git@hve-core
```

## Agents

| Agent | Description |
| ----- | ----------- |
| pr-review | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core |

## Commands

| Command | Description |
| ------- | ----------- |
| git-commit-message | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch |
| git-commit | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit |
| git-merge | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling. |
| git-setup | Interactive, verification-first Git configuration assistant (non-destructive) |
| pull-request | Provides prompt instructions for pull request (PR) generation - Brought to you by microsoft/edge-ai |

## Instructions

| Instruction | Description |
| ----------- | ----------- |
| writing-style | Required writing style conventions for voice, tone, and language in all markdown content |
| markdown | Required instructions for creating or editing any Markdown (.md) files |
| commit-message | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core |
| git-merge | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

