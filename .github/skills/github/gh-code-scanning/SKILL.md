---
name: gh-code-scanning
description: 'Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires pwsh 7+ and gh CLI authenticated with the security_events scope. Bash script requires jq.'
ms.date: 2026-04-21
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-21"
---

# GitHub Code Scanning Skill

## Overview

GitHub code scanning alerts are produced by static analysis tools such as CodeQL and Scorecard and surfaced in the GitHub Security tab. The GitHub Security tab is not accessible through the default MCP toolset, so this skill provides scripts for all read operations.

## Prerequisites

| Requirement | Details                                                                 |
|-------------|-------------------------------------------------------------------------|
| `pwsh`      | PowerShell 7+; install from <https://learn.microsoft.com/powershell>    |
| `gh` CLI    | Installed and on `PATH`; install from <https://cli.github.com>          |
| Auth        | Run `gh auth login` or set `GH_TOKEN`; requires `security_events` scope |
| Scope       | `security_events` for private repos; `public_repo` for public-only      |

The `repo` scope also satisfies `security_events`. The `gh` CLI handles authentication automatically; no explicit token passing is needed in commands.

`Get-CodeScanningAlerts.ps1` validates both prerequisites at startup and aborts with a targeted error message if either check fails.

## Quick Start

Run this command to get a grouped summary of open code scanning alerts, sorted by frequency. This is the recommended first command when triaging a repository's code scanning posture.

```bash
pwsh scripts/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json
```

This returns a JSON array of alert groups sorted by occurrence count, descending. Always use `-OutputFormat Json` when consuming results programmatically.

## Parameters Reference

| Parameter       | Type   | Required | Default | Description                                                               |
|-----------------|--------|----------|---------|---------------------------------------------------------------------------|
| `-Owner`        | String | Yes      |         | GitHub organization or user that owns the repository                      |
| `-Repo`         | String | Yes      |         | Repository name                                                           |
| `-OutputFormat` | String | No       | Table   | Output format: agents must always use `Json` for programmatic consumption; `GroupedJson` is accepted as an alias for `Json` |
| `-Branch`       | String | No       | `main`  | Branch to scope alert results                                             |

> These parameters apply to `Get-CodeScanningAlerts.ps1`. For bash script flags including `-s {severity}`, see the Script Reference section below.

## Script Reference

### Get-CodeScanningAlerts.ps1

Groups and sorts open code scanning alerts by occurrence count, descending.

```bash
# JSON output for programmatic consumption
pwsh scripts/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json

# Scope to a specific branch
pwsh scripts/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -Branch "{branch}" -OutputFormat Json
```

### get-code-scanning-alerts.sh

Groups and sorts open code scanning alerts by occurrence count, descending. Requires `jq`.

```bash
# JSON output for programmatic consumption
bash scripts/get-code-scanning-alerts.sh -o "{owner}" -r "{repo}"

# Scope to a specific branch
bash scripts/get-code-scanning-alerts.sh -o "{owner}" -r "{repo}" -b "{branch}"

# Filter by severity
bash scripts/get-code-scanning-alerts.sh -o "{owner}" -r "{repo}" -s critical
```

## When to Use This Skill

Use this skill when the task involves reading code scanning alerts only. `Get-CodeScanningAlerts.ps1` is the only supported method for listing and grouping code scanning alerts. `gh api` must not be used as a fallback for listing or grouping.

When the GitHub MCP server is configured with the `code_security` toolset, read-only access to code scanning alerts is available without `gh api`. Enable via `toolsets: all` or explicit toolset configuration.

## Code Scanning Alerts

### List and group open alerts

Always run with `-OutputFormat Json`. Parse the JSON output and present it to the user.

```bash
pwsh scripts/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json
```

Use `-Branch {branch}` to scope to a branch other than `main`.

### JSON output shape

`-OutputFormat Json` returns an array of group objects:

```json
[
  {
    "RuleDescription": "Empty except",
    "RuleId": "py/empty-except",
    "Tool": "CodeQL",
    "SecuritySeverity": null,
    "Count": 23,
    "AffectedPaths": [
      "scripts/collections/Get-CollectionItems.py",
      "scripts/linting/Validate-MarkdownFrontmatter.py"
    ],
    "HasFilePaths": true,
    "AlertUrl": "https://github.com/microsoft/hve-core/security/code-scanning/42",
    "FindingDescription": "'except' clause does nothing but pass and there is no explanatory comment."
  },
  {
    "RuleDescription": "Code injection",
    "RuleId": "actions/code-injection/medium",
    "Tool": "CodeQL",
    "SecuritySeverity": "medium",
    "Count": 2,
    "AffectedPaths": [
      ".github/workflows/validate.yml"
    ],
    "HasFilePaths": true,
    "AlertUrl": "https://github.com/microsoft/hve-core/security/code-scanning/17",
    "FindingDescription": "Potential code injection in ${{ inputs.version }}, which may be controlled by an external user."
  },
  {
    "RuleDescription": "Branch-Protection",
    "RuleId": "BranchProtectionID",
    "Tool": "Scorecard",
    "SecuritySeverity": "high",
    "Count": 1,
    "AffectedPaths": [],
    "HasFilePaths": false,
    "AlertUrl": "https://github.com/microsoft/hve-core/security/code-scanning/1",
    "FindingDescription": "score is 9: branch protection is not maximal on development and all release branches"
  }
]
```

`SecuritySeverity` is `null` when the rule has no severity tier assigned. `AffectedPaths` is always a JSON array of unique, sorted file paths with sentinel strings filtered out. `HasFilePaths` is `false` and `AffectedPaths` is `[]` when an alert has no associated source file (for example, `BranchProtectionID`). `AlertUrl` links directly to the alert in the GitHub Security tab. `FindingDescription` is the most recent alert message text.

### Get single alert detail

This call returns one record; it is not a listing or grouping operation and does not conflict with the `gh api` restriction above.

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts/{alert_number}
```

### List affected file paths

Use `-OutputFormat Json` and read the `AffectedPaths` field from each rule group. The JSON output includes `RuleDescription`, `RuleId`, `Tool`, `SecuritySeverity`, `Count`, `AffectedPaths` (unique, sorted file paths), `HasFilePaths` (boolean: `false` for repo-level rules that have no associated source file), `AlertUrl` (string: direct link to the alert in the GitHub Security tab), and `FindingDescription` (string: most recent alert message text from the analysis tool) per group.

### Key fields

These are GitHub API response field paths, not output object properties. The grouped output object field names are listed in the JSON output shape section above.

* `rule.security_severity_level`: severity tier: `critical`, `high`, `medium`, or `low`
* `rule.id`: rule identifier used for deduplication and cross-referencing
* `tool.name`: analysis tool that produced the alert (for example, `CodeQL`)
* `most_recent_instance.location.path`: source file path of the most recent alert occurrence

## Code Scanning Analyses

These calls retrieve analysis metadata, not alert listings, and do not conflict with the `gh api` restriction above.

### List recent analyses

Returns the last 10 CodeQL runs on the main branch.

```bash
gh api repos/{owner}/{repo}/code-scanning/analyses \
  -f tool_name=CodeQL \
  -f ref=refs/heads/main \
  -f per_page=10
```

### Key fields

* `created_at`: timestamp of the analysis run
* `results_count`: number of alerts produced
* `rules_count`: number of rules evaluated
* `tool.version`: version of the analysis tool
* `warning` / `error`: any issues reported during analysis

## Backlog Issue Creation

### Dedup check before creation

Search for an existing issue using the title and an embedded automation marker before creating a new one.

```bash
existing=$(gh issue list --repo "{owner}/{repo}" \
  --search "\"[Security] {rule_description}\" in:title" \
  --state open --json number --jq '.[0].number // empty')
if [[ -z "$existing" ]]; then
  gh issue create --repo "{owner}/{repo}" \
    --title "[Security] {rule_description}" \
    --label "security" \
    --body "<!-- automation:security-scan:{rule_id} -->
## Code Scanning Alert: {rule_description}

**Rule:** \`{rule_id}\`
**Severity:** {security_severity}
**Tool:** {tool}
**Affected files:** {count} occurrences

### Affected paths
{affected_paths}
"
fi
```

The automation marker `<!-- automation:security-scan:{rule_id} -->` is embedded in the issue body and serves as the deduplication anchor. Replace all `{placeholders}` with actual values from the alert-grouping JSON output.

## Troubleshooting

| Symptom                                                    | Likely cause                                   | Fix                                                                                                                 |
|------------------------------------------------------------|------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `gh CLI not found. Install it from https://cli.github.com` | `gh` CLI not on `PATH`                         | Install from <https://cli.github.com>, then re-open your terminal                                                   |
| `gh CLI is not authenticated. Run 'gh auth login'`         | `gh` auth not completed                        | Run `gh auth login`; ensure `security_events` scope is granted                                                      |
| `HTTP 403 Resource not accessible by integration`          | Missing `security_events` scope on token       | Re-authenticate: `gh auth refresh -s security_events` or set `GH_TOKEN` with appropriate scope                      |
| Empty results `[]`                                         | Wrong `ref` format or no alerts on that branch | Omit `-f ref=` to search all branches, or use `refs/heads/main` format (not just `main`)                            |
| `bash: jq: command not found`                              | `jq` not installed                             | Install via `brew install jq` (macOS), `apt-get install jq` (Debian/Ubuntu), or from <https://jqlang.github.io/jq/> |

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
