---
title: Discovery Workflow
description: Discover and categorize GitHub issues through user-centric, artifact-driven, and search-based paths
author: Microsoft
ms.date: 2026-02-12
ms.topic: tutorial
keywords:
  - github backlog manager
  - issue discovery
  - github copilot
estimated_reading_time: 5
---

The Discovery workflow finds and categorizes GitHub issues from multiple sources, producing structured analysis files that feed into triage and planning.

## When to Use

* 🆕 Starting a new sprint and need to survey open issues across repositories
* 👤 Reviewing issues assigned to you or your team before a planning session
* 🔀 Code changes on a feature branch that may relate to existing backlog items
* 🔍 Searching for issues matching specific criteria across multiple repositories

## What It Does

1. Identifies issues through one of three discovery paths (user-centric, artifact-driven, or search-based)
2. Retrieves issue metadata including labels, assignees, milestones, and linked pull requests
3. Categorizes issues by type, area, and current state
4. Produces structured analysis files with issue summaries and recommendations
5. Flags issues that may need triage attention (unlabeled, stale, or assigned incorrectly)

> [!NOTE]
> Discovery is deliberately separated from triage. Finding issues and deciding what to do with them are different cognitive tasks. Running them in a single pass increases the chance of misclassification.

## The Three Discovery Paths

### User-Centric Discovery

Finds issues assigned to a specific user or team. This path is ideal for sprint preparation, where you need to see your current backlog before planning new work. The workflow queries GitHub for issues by assignee, filters by state, and organizes results by repository and milestone.

### Artifact-Driven Discovery

Analyzes local code changes (branches, commits, modified files) and maps them to existing backlog items. This path surfaces issues related to your current work, helping you avoid duplicate effort and identify issues your changes may resolve. The workflow reads git diff output and searches for matching issues by file path, keyword, and component area.

### Search-Based Discovery

Queries across repositories using criteria you define: labels, keywords, date ranges, milestone association, or any combination. This path handles broad inventory tasks, such as finding all unlabeled issues, all issues older than 90 days, or all issues in a specific area across multiple repositories.

## Output Artifacts

```text
.copilot-tracking/github-issues/discovery/<scope-name>/
├── issue-analysis.md    # Categorized issue inventory with metadata
├── issues-plan.md       # Recommended actions for discovered issues
└── planning-log.md      # Discovery session log with search queries used
```

Discovery writes its output to the `.copilot-tracking/github-issues/discovery/` directory. The scope name reflects the discovery target (a username, repository, or search description). These files serve as input for the triage workflow.

## How to Use

### Option 1: Prompt Shortcut

Use the backlog manager prompts to start a discovery session:

```text
Discover open issues assigned to me in microsoft/hve-core
```

```text
Find issues related to my current branch changes
```

```text
Search for unlabeled issues across all repositories in our organization
```

### Option 2: Direct Agent

Start a conversation with the GitHub Backlog Manager agent and describe your discovery goal. The agent classifies your intent and dispatches the appropriate discovery path automatically.

## Example Prompt

```text
Discover open issues assigned to me in microsoft/hve-core that don't have
a milestone. Include any issues labeled "needs-triage" regardless of assignee.
```

## Tips

✅ Do:

* Scope discovery to a specific repository or user to keep results manageable
* Run discovery before triage to ensure you have a complete picture
* Use artifact-driven discovery when working on a feature branch to find related issues
* Review the planning log to understand what queries produced the results

❌ Don't:

* Combine discovery with triage in a single session (clear context between workflows)
* Run discovery across an entire organization without filters (results become unwieldy)
* Skip reviewing the issue analysis before proceeding to triage
* Assume discovery catches everything on the first pass (iterate if needed)

## Common Pitfalls

| Pitfall                                  | Solution                                                              |
|------------------------------------------|-----------------------------------------------------------------------|
| Too many results to review               | Narrow the scope with repository, label, or date filters              |
| Missing issues from private repositories | Verify MCP token has access to the target repositories                |
| Stale results from cached queries        | Clear context and re-run discovery for fresh API results              |
| Artifact-driven path finds no matches    | Ensure your branch has committed changes (unstaged files are skipped) |

## Next Steps

1. Send your discovery output through the [Triage workflow](triage.md) to assign labels and priorities
2. See [Using Workflows Together](using-together.md) for the full pipeline walkthrough

> [!TIP]
> Run `/clear` between discovery and triage. Each workflow reads its own planning files and mixing session context produces unreliable label suggestions.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
