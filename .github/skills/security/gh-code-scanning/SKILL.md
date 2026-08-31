---
name: gh-code-scanning
description: 'Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI'
license: MIT
compatibility: 'Requires pwsh 7+ and gh CLI authenticated with the security_events scope. Bash script requires jq.'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-30"
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

| Parameter       | Type   | Required | Default | Description                                                                                                                 |
|-----------------|--------|----------|---------|-----------------------------------------------------------------------------------------------------------------------------|
| `-Owner`        | String | Yes      |         | GitHub organization or user that owns the repository                                                                        |
| `-Repo`         | String | Yes      |         | Repository name                                                                                                             |
| `-OutputFormat` | String | No       | Table   | Output format: agents must always use `Json` for programmatic consumption; `GroupedJson` is accepted as an alias for `Json` |
| `-Branch`       | String | No       | `main`  | Branch to scope alert results                                                                                               |

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
    "Severity": "warning",
    "Count": 23,
    "AffectedPaths": [
      "scripts/plugins/Sync-PluginManifest.ps1",
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
    "Severity": "error",
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
    "Severity": "error",
    "Count": 1,
    "AffectedPaths": [],
    "HasFilePaths": false,
    "AlertUrl": "https://github.com/microsoft/hve-core/security/code-scanning/1",
    "FindingDescription": "score is 9: branch protection is not maximal on development and all release branches"
  }
]
```

`SecuritySeverity` is `null` for code quality rules that have no security classification; `Severity` (the non-security rule severity: `error`, `warning`, `note`, `none`) provides a fallback. `AffectedPaths` is always a JSON array of unique, sorted file paths with sentinel strings filtered out. `HasFilePaths` is `false` and `AffectedPaths` is `[]` when an alert has no associated source file (for example, `BranchProtectionID`). `AlertUrl` links directly to the alert in the GitHub Security tab. `FindingDescription` is the most recent alert message text.

### Get single alert detail

This call returns one record; it is not a listing or grouping operation and does not conflict with the `gh api` restriction above.

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts/{alert_number}
```

### List affected file paths

Use `-OutputFormat Json` and read the `AffectedPaths` field from each rule group. The JSON output includes `RuleDescription`, `RuleId`, `Tool`, `SecuritySeverity`, `Severity`, `Count`, `AffectedPaths` (unique, sorted file paths), `HasFilePaths` (boolean: `false` for repo-level rules that have no associated source file), `AlertUrl` (string: direct link to the alert in the GitHub Security tab), and `FindingDescription` (string: most recent alert message text from the analysis tool) per group.

### Key fields

These are GitHub API response field paths, not output object properties. The grouped output object field names are listed in the JSON output shape section above.

* `rule.security_severity_level`: security severity tier: `critical`, `high`, `medium`, or `low`; `null` for code quality rules
* `rule.severity`: non-security rule severity: `error`, `warning`, `note`, or `none`; always populated
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

Search all issue states for the embedded automation marker before creating a new issue. Treat the broad search as a candidate query, then verify the first-line marker, the immutable GitHub Actions app author, and the automation-owned labels.

```bash
set -euo pipefail
rule_id="{rule_id}"
candidate_limit=200

if ! jq -en --arg rule "${rule_id}" '$rule | test("^[A-Za-z0-9._:/-]{1,256}$")' > /dev/null; then
  echo "Rule ID does not match the automation marker grammar." >&2
  exit 1
fi
if ! issues=$(gh issue list --repo "{owner}/{repo}" \
  --search '"automation:security-scan:" in:body' \
  --state all --limit "${candidate_limit}" --json number,state,body,author,labels); then
  echo "Unable to list candidate tracking issues; aborting." >&2
  exit 1
fi
if ! jq -e 'type == "array"' <<< "${issues}" > /dev/null; then
  echo "Candidate tracking issue response is not a JSON array; aborting." >&2
  exit 1
fi
if [[ $(jq 'length' <<< "${issues}") -ge "${candidate_limit}" ]]; then
  echo "Candidate query reached its limit; aborting rather than using a partial result." >&2
  exit 1
fi
if ! existing=$(jq -c --arg rule "${rule_id}" '
  [.[]
    | select(.body | test("^<!--[ \\t]*automation:security-scan:[A-Za-z0-9._:/-]{1,256}[ \\t]*-->(?:\\r?\\n|$)"))
    | select(.author.login? == "app/github-actions")
    | select(([.labels[]?.name] | index("automated")) != null)
    | select(([.labels[]?.name] | index("security")) != null)
    | select(.body | capture("^<!--[ \\t]*automation:security-scan:(?<rule>[A-Za-z0-9._:/-]{1,256})[ \\t]*-->(?:\\r?\\n|$)").rule == $rule)]
' <<< "${issues}"); then
  echo "Unable to verify candidate tracking issues; aborting." >&2
  exit 1
fi
match_count=$(jq 'length' <<< "${existing}")
if [[ "${match_count}" -gt 1 ]]; then
  echo "Multiple verified tracking issues match rule ${rule_id}; aborting." >&2
  exit 1
fi
existing_number=$(jq -r '.[0].number // empty' <<< "${existing}")
if [[ -z "${existing_number}" ]]; then
  gh issue create --repo "{owner}/{repo}" \
    --title "[Security] {rule_description}" \
    --label "security,automated,needs-triage" \
    --body "<!-- automation:security-scan:${rule_id} -->
## Code Scanning Alert: {rule_description}

**Rule:** \`${rule_id}\`
$([ -n "{severity}" ] && echo "**Severity:** {severity}")
**Tool:** {tool}
**Affected files:** {count} occurrences

### Affected paths
{affected_paths}
"
fi
```

The automation marker `<!-- automation:security-scan:{rule_id} -->` occupies the first physical line of the issue body and serves as the rule anchor. Only horizontal whitespace may surround the marker content. Rule IDs use 1 through 256 ASCII letters, digits, dots, underscores, colons, slashes, or hyphens. Automated lookup and reconciliation also require the issue author to be `app/github-actions` and the labels to include both `automated` and `security`; this author is produced when the workflow creates the issue with `GITHUB_TOKEN`. Marker text alone is not ownership proof. Removing or moving the marker or removing either ownership label excludes the issue from automation. If candidate lookup, parsing, or completeness cannot be verified, abort before creation. If more than one verified issue matches a live rule, abort before mutation instead of selecting one silently. Replace all `{placeholders}` with actual values from the alert-grouping JSON output.

## Troubleshooting

| Symptom                                                    | Likely cause                                   | Fix                                                                                                                 |
|------------------------------------------------------------|------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `gh CLI not found. Install it from https://cli.github.com` | `gh` CLI not on `PATH`                         | Install from <https://cli.github.com>, then re-open your terminal                                                   |
| `gh CLI is not authenticated. Run 'gh auth login'`         | `gh` auth not completed                        | Run `gh auth login`; ensure `security_events` scope is granted                                                      |
| `HTTP 403 Resource not accessible by integration`          | Missing `security_events` scope on token       | Re-authenticate: `gh auth refresh -s security_events` or set `GH_TOKEN` with appropriate scope                      |
| Empty results `[]`                                         | Wrong `ref` format or no alerts on that branch | Omit `-f ref=` to search all branches, or use `refs/heads/main` format (not just `main`)                            |
| `bash: jq: command not found`                              | `jq` not installed                             | Install via `brew install jq` (macOS), `apt-get install jq` (Debian/Ubuntu), or from <https://jqlang.github.io/jq/> |

