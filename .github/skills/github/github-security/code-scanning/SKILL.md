---
name: github-security-code-scanning
description: 'Read GitHub code scanning alerts from the Security tab via Get-CodeScanningAlerts.ps1 - Brought to you by microsoft/hve-core'
license: MIT
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-20"
---

# GitHub Security — Code Scanning Skill

## Overview

Code scanning alerts are produced by static analysis tools such as CodeQL and Scorecard and surfaced in the GitHub Security tab. The GitHub Security tab is not accessible through the default MCP toolset, so this skill provides `Get-CodeScanningAlerts.ps1` for all read operations.

## Prerequisites

| Requirement | Details                                                                 |
|-------------|-------------------------------------------------------------------------|
| `pwsh`      | PowerShell 7+; install from https://learn.microsoft.com/powershell      |
| `gh` CLI    | Installed and on `PATH`; install from https://cli.github.com            |
| Auth        | Run `gh auth login` or set `GH_TOKEN`; requires `security_events` scope |
| Scope       | `security_events` for private repos; `public_repo` for public-only      |

The `repo` scope also satisfies `security_events`. The `gh` CLI handles authentication automatically; no explicit token passing is needed in commands.

`Get-CodeScanningAlerts.ps1` validates both prerequisites at startup and aborts with a targeted error message if either check fails.

## When to Use This Skill

Use this skill when the task involves reading code scanning alerts only. `Get-CodeScanningAlerts.ps1` is the only supported method for listing and grouping code scanning alerts. `gh api` must not be used as a fallback for listing or grouping.

When GitHub MCP server is configured with the `code_security` toolset, read-only access is available without `gh api`.

## Quick Start

Run this command to get a grouped summary of open code scanning alerts, sorted by frequency. This is the recommended first command when triaging a repository's code scanning posture.

```bash
pwsh scripts/security/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json
```

> [!NOTE]
> If using oh-my-zsh and the terminal shows `INT ✘` after this command, see [Reading Command Output](#reading-command-output) for how to interpret results.

This returns a JSON array of alert groups sorted by occurrence count, descending. Always use `-OutputFormat Json` when consuming results programmatically.

> [!NOTE]
> In a repository checkout (local dev or CI), the script resolves to `scripts/security/Get-CodeScanningAlerts.ps1` relative to the workspace root. When using the installed hve-core VS Code extension without a repo checkout, the same file ships inside the extension directory alongside other hve-core scripts.

## Parameters Reference

| Parameter       | Type   | Required | Default | Description                                                                       |
|-----------------|--------|----------|---------|-----------------------------------------------------------------------------------|
| `-Owner`        | String | Yes      |         | GitHub organization or user that owns the repository                              |
| `-Repo`         | String | Yes      |         | Repository name                                                                   |
| `-OutputFormat` | String | No       | Table   | Output format: always use `Json` for programmatic consumption                     |
| `-Branch`       | String | No       | `main`  | Branch to scope alert results                                                     |

## Script Reference

### Get-CodeScanningAlerts.ps1

Groups and sorts open code scanning alerts by occurrence count, descending.

```bash
# JSON output for programmatic consumption
pwsh scripts/security/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json

# Scope to a specific branch
pwsh scripts/security/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -Branch "{branch}" -OutputFormat Json
```

## Reading Command Output

> [!IMPORTANT]
> Read stdout. Ignore exit codes and shell prompt decorations entirely.

The only signal that determines whether `Get-CodeScanningAlerts.ps1` succeeded or failed is the content written to stdout:

* JSON output: stdout starts with `[` and is a valid JSON array. The command succeeded.
* Error output: stdout contains a line starting with `Error:` or `gh CLI not found`. The command failed.

Do not use the shell exit code or prompt decoration to determine success. oh-my-zsh displays an `INT` marker and a non-zero exit code in the prompt when a previous command in the session was interrupted by the user. This marker persists across subsequent commands and does not reflect the exit status of the most recently run script. A prompt showing `INT ✘` after the script run does not mean the script failed.

When stdout starts with `[`: the command succeeded. Present the output to the user. This is the only next action required.

When stdout contains `Error:` or `gh CLI not found`: report the error to the user.

When `run_in_terminal` returns no output: use `get_terminal_output` to read the terminal buffer. The script writes valid output even when the sync capture mode does not return it.

## Code Scanning Alerts

### List and group open alerts

Always run with `-OutputFormat Json`. Parse the JSON output and present it to the user.

```bash
pwsh scripts/security/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}" -OutputFormat Json
```

> [!NOTE]
> See [Reading Command Output](#reading-command-output) for how to interpret results.

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
    "SamplePaths": [
      "scripts/collections/Get-CollectionItems.py",
      "scripts/linting/Validate-MarkdownFrontmatter.py"
    ]
  },
  {
    "RuleDescription": "Code injection",
    "RuleId": "actions/code-injection/medium",
    "Tool": "CodeQL",
    "SecuritySeverity": "medium",
    "Count": 2,
    "SamplePaths": [
      ".github/workflows/validate.yml"
    ]
  },
  {
    "RuleDescription": "Branch-Protection",
    "RuleId": "BranchProtectionID",
    "Tool": "Scorecard",
    "SecuritySeverity": "high",
    "Count": 1,
    "SamplePaths": [
      "no file associated with this alert"
    ]
  }
]
```

`SecuritySeverity` is `null` when the rule has no severity tier assigned. `SamplePaths` is always a JSON array. When an alert has no associated source file (for example, `BranchProtectionID`), the array contains the sentinel string `"no file associated with this alert"`.

### Get single alert detail

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts/{alert_number}
```

### List affected file paths

Use `-OutputFormat Json` and read the `SamplePaths` field from each rule group. The JSON output includes `RuleDescription`, `RuleId`, `Tool`, `SecuritySeverity`, `Count`, and `SamplePaths` (unique, sorted file paths) per group.

### Key fields

- `rule.security_severity_level`: severity tier: `critical`, `high`, `medium`, or `low`
- `rule.id`: rule identifier used for deduplication and cross-referencing
- `tool.name`: analysis tool that produced the alert (for example, `CodeQL`)
- `most_recent_instance.location.path`: source file path of the most recent alert occurrence

## Code Scanning Analyses

### List recent analyses

Returns the last 10 CodeQL runs on the main branch.

```bash
gh api repos/{owner}/{repo}/code-scanning/analyses \
  -f tool_name=CodeQL \
  -f ref=refs/heads/main \
  -f per_page=10
```

### Key fields

- `created_at`: timestamp of the analysis run
- `results_count`: number of alerts produced
- `rules_count`: number of rules evaluated
- `tool.version`: version of the analysis tool
- `warning` / `error`: any issues reported during analysis

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

### Sample affected paths
{sample_paths}
"
fi
```

The automation marker `<!-- automation:security-scan:{rule_id} -->` is embedded in the issue body and serves as the deduplication anchor. Replace all `{placeholders}` with actual values from the alert-grouping JSON output.

## MCP Availability Note

When the GitHub MCP server is configured with the `code_security` toolset, read-only access to code scanning alerts is available without `gh api`. Enable via `toolsets: all` or explicit toolset configuration.

## Troubleshooting

| Symptom                                                    | Likely cause                                   | Fix                                                                                            |
|------------------------------------------------------------|------------------------------------------------|------------------------------------------------------------------------------------------------|
| `gh CLI not found. Install it from https://cli.github.com` | `gh` CLI not on `PATH`                         | Install from https://cli.github.com, then re-open your terminal                                |
| `gh CLI is not authenticated. Run 'gh auth login'`         | `gh` auth not completed                        | Run `gh auth login`; ensure `security_events` scope is granted                                 |
| `HTTP 403 Resource not accessible by integration`          | Missing `security_events` scope on token       | Re-authenticate: `gh auth refresh -s security_events` or set `GH_TOKEN` with appropriate scope |
| Empty results `[]`                                         | Wrong `ref` format or no alerts on that branch | Omit `-f ref=` to search all branches, or use `refs/heads/main` format (not just `main`)       |

> Brought to you by microsoft/hve-core
