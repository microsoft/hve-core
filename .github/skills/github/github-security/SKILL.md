---
name: github-security
description: 'Read and act on GitHub Security tab alerts via gh api CLI - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires gh CLI authenticated on PATH with security_events scope'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-10"
---

# GitHub Security Skill

## Overview

The GitHub Security tab is not accessible through the default MCP toolset, so this skill provides `gh api` CLI commands for all read and write operations against GitHub Security alerts. The three alert types covered are code scanning (static analysis), secret scanning (credential detection), and Dependabot (dependency vulnerability). Advanced `jq` filter patterns for extended use cases are collected in `references/alert-filters.md`.

## Prerequisites

| Requirement | Details                                                                        |
|-------------|--------------------------------------------------------------------------------|
| `gh` CLI    | Installed and on `PATH`; install from https://cli.github.com                   |
| Auth        | Run `gh auth login` or set `GH_TOKEN`; requires `security_events` scope        |
| Scope       | `security_events` for private repos; `public_repo` for public-only             |
| `jq`        | Pre-installed on most systems; required for `--jq` filters                     |

The `repo` scope also satisfies `security_events`. The `gh` CLI handles authentication automatically — no explicit token passing is needed in commands.

`Get-CodeScanningAlerts.ps1` validates both prerequisites at startup and aborts with a targeted error message if either check fails.

## Quick Start

Run this command to get a grouped summary of open code scanning alerts, sorted by frequency. This is the recommended first command when triaging a repository's security posture.

```bash
pwsh scripts/security/Get-CodeScanningAlerts.ps1 -Owner "{owner}" -Repo "{repo}"
```

This groups open alerts by rule title and sorts results by occurrence count, descending.

> [!NOTE]
> In a repository checkout (local dev or CI), the script resolves to `scripts/security/Get-CodeScanningAlerts.ps1` relative to the workspace root. When using the installed hve-core VS Code extension without a repo checkout, the same file ships inside the extension directory alongside other hve-core scripts.

## When to Use This Skill

The GitHub Security tab is not accessible in the default MCP toolset. This skill provides `gh api` commands for all read and write operations across the three alert types. Write operations — dismissing, reopening, or resolving alerts — always require `gh api` regardless of MCP configuration.

When GitHub MCP server is configured with non-default toolsets, read-only access is available without `gh api`. See the [MCP Availability Note](#mcp-availability-note) section for details on optional read-only MCP access.

## Code Scanning Alerts

### List open alerts

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&ref=refs/heads/main&per_page=100" \
  --paginate
```

Use `ref=refs/heads/main` to scope to a specific branch. Omit `ref` to return alerts from all branches.

### Group by rule title

Use `Get-CodeScanningAlerts.ps1` for automated or one-shot grouping. The `gh api` form below is retained as an advanced reference and for environments without PowerShell.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&ref=refs/heads/main&per_page=100" \
  --paginate \
  --jq '[.[] | {number, rule_description: .rule.description, rule_id: .rule.id, tool: .tool.name, security_severity: .rule.security_severity_level, path: .most_recent_instance.location.path}] | group_by(.rule_description) | map({rule_description: .[0].rule_description, rule_id: .[0].rule_id, tool: .[0].tool, security_severity: .[0].security_severity, count: length, sample_paths: [.[].path] | unique}) | sort_by(-.count)'
```

### Get single alert detail

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts/{alert_number}
```

### List affected file paths

Returns a unique, sorted list of file paths touched by open alerts.

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts --paginate \
  --jq '[.[].most_recent_instance.location.path] | unique | sort[]'
```

### Key fields

- `rule.security_severity_level` — severity tier: `critical`, `high`, `medium`, or `low`
- `rule.id` — rule identifier used for deduplication and cross-referencing
- `tool.name` — analysis tool that produced the alert (for example, `CodeQL`)
- `most_recent_instance.location.path` — source file path of the most recent alert occurrence

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

- `created_at` — timestamp of the analysis run
- `results_count` — number of alerts produced
- `rules_count` — number of rules evaluated
- `tool.version` — version of the analysis tool
- `warning` / `error` — any issues reported during analysis

## Secret Scanning

### List open alerts

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts \
  --paginate \
  -f state=open \
  -f per_page=100
```

### Filter active open secrets

Active secrets represent the highest-risk alerts because the credential is still valid.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.state == "open" and .validity == "active")]'
```

### Group by secret type with active counts

See `references/alert-filters.md` for the full group-by pattern that includes active counts per secret type.

### Key fields

- `secret_type` — machine-readable type identifier (for example, `github_personal_access_token`)
- `secret_type_display_name` — human-readable label for the secret type
- `validity` — `active`, `inactive`, or `unknown`
- `publicly_leaked` — `true` when the secret was exposed in a public location
- `push_protection_bypassed` — `true` when a developer bypassed push protection to commit the secret

## Dependabot Alerts

### List open alerts by severity

Returns critical and high severity open alerts with CVE, affected package, and available patch version.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts \
  --paginate \
  -f severity=critical,high \
  -f state=open \
  --jq '.[] | {number, package: .dependency.package.name, ecosystem: .dependency.package.ecosystem, severity: .security_advisory.severity, cve: .security_advisory.cve_id, patched: .security_vulnerability.first_patched_version.identifier}'
```

### Filter by ecosystem

Use `-f ecosystem=npm,pip` (comma-separated) to restrict results to specific package ecosystems.

### Filter for alerts with an available patch

Use `-f has=patch` to return only alerts where an upgraded version resolves the vulnerability.

### Key fields

- `dependency.package.ecosystem` — package manager (for example, `npm`, `pip`, `nuget`)
- `dependency.scope` — `runtime` or `development`
- `security_advisory.severity` — `critical`, `high`, `medium`, or `low`
- `security_vulnerability.first_patched_version.identifier` — lowest version that resolves the vulnerability
- `security_advisory.epss.percentage` — EPSS exploit probability score (0–1)

## Write Operations

### Dismiss code scanning alert

```bash
gh api --method PATCH repos/{owner}/{repo}/code-scanning/alerts/{alert_number} \
  -f state=dismissed \
  -f dismissed_reason="false positive" \
  -f dismissed_comment="Not applicable due to sanitizer"
```

Valid `dismissed_reason` values: `false positive`, `won't fix`, `used in tests`

### Reopen code scanning alert

Use the same PATCH endpoint with `state=open` to reopen a dismissed alert.

### Resolve secret scanning alert

```bash
gh api --method PATCH repos/{owner}/{repo}/secret-scanning/alerts/{alert_number} \
  -f state=resolved \
  -f resolution="false_positive" \
  -f resolution_comment="Not a real credential"
```

Valid `resolution` values: `false_positive`, `wont_fix`, `revoked`, `used_in_tests`

### Dismiss Dependabot alert

```bash
gh api --method PATCH repos/{owner}/{repo}/dependabot/alerts/{alert_number} \
  -f state=dismissed \
  -f dismissed_reason=tolerable_risk \
  -f dismissed_comment="Mitigated by WAF rule"
```

Valid `dismissed_reason` values: `fix_started`, `inaccurate`, `no_bandwidth`, `not_used`, `tolerable_risk`

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

The automation marker `<!-- automation:security-scan:{rule_id} -->` is embedded in the issue body and serves as the deduplication anchor. The dedup search uses `gh issue list --search` to find existing issues before creating duplicates. Replace all `{placeholders}` with actual values from the alert-grouping `jq` output.

## MCP Availability Note

When the GitHub MCP server is configured with non-default toolsets, read-only access to security alerts is available without `gh api`. The relevant toolsets are:

- `code_security` — code scanning alerts
- `dependabot` — Dependabot alerts
- `secret_protection` — secret scanning alerts
- `security_advisories` — security advisory data

Enable these toolsets via `toolsets: all` or explicit toolset configuration (for example, `https://api.githubcopilot.com/mcp/x/all` for the hosted remote server). Write operations — dismissing, reopening, and resolving alerts — are NOT available via MCP regardless of toolset and always require `gh api`.

## Troubleshooting

| Symptom                                                                | Likely cause                                   | Fix                                                                                            |
|------------------------------------------------------------------------|------------------------------------------------|------------------------------------------------------------------------------------------------|
| `gh CLI not found. Install it from https://cli.github.com`             | `gh` CLI not on `PATH`                         | Install from https://cli.github.com, then re-open your terminal                                |
| `gh CLI is not authenticated. Run 'gh auth login'`                     | `gh` auth not completed                        | Run `gh auth login`; ensure `security_events` scope is granted                                 |
| `gh: command not found` (raw shell, not via script)                    | `gh` CLI not installed                         | Install from https://cli.github.com                                                            |
| `HTTP 403 Resource not accessible by integration`                      | Missing `security_events` scope on token       | Re-authenticate: `gh auth refresh -s security_events` or set `GH_TOKEN` with appropriate scope |
| Empty results `[]`                                                      | Wrong `ref` format or no alerts on that branch | Omit `-f ref=` to search all branches, or use `refs/heads/main` format (not just `main`)       |

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
