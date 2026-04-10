---
title: GitHub Security Alert Filters Reference
description: Advanced jq filter patterns for code scanning, secret scanning, and Dependabot alert queries via gh api CLI
author: Microsoft
ms.date: 2026-04-10
ms.topic: reference
keywords:
  - github
  - security
  - code scanning
  - secret scanning
  - dependabot
  - jq
estimated_reading_time: 3
---

Advanced `jq` filter patterns for GitHub Security alert queries. All commands use `{owner}/{repo}` placeholders. Combine filters with `--paginate` for complete result sets.

## Code Scanning Filters

### Filter by security severity level

Use `select` on `rule.security_severity_level` to isolate alerts at a specific severity tier. This example returns only critical alerts.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" \
  --paginate \
  --jq '[.[] | select(.rule.security_severity_level == "critical")]'
```

Replace `"critical"` with `"high"`, `"medium"`, or `"low"` as needed.

### Filter by tool name

Pass `tool_name` as a query parameter to restrict results to a single analysis tool.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&tool_name=CodeQL&per_page=100" \
  --paginate
```

### List alerts with CWE tags

Selects alerts whose rule tags include a CWE reference and extracts the CWE identifier.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" \
  --paginate \
  --jq '[.[] | select(.rule.tags | any(. | startswith("external/cwe"))) | {number, rule: .rule.id, cwe: (.rule.tags[] | select(startswith("external/cwe"))), path: .most_recent_instance.location.path}]'
```

### Compact triage view

Returns a minimal set of fields useful for rapid triage across many alerts.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" \
  --paginate \
  --jq '.[] | {number, rule: .rule.name, severity: .rule.security_severity_level, state, path: .most_recent_instance.location.path, line: .most_recent_instance.location.start_line}'
```

### Dismissed alerts with reasons

Retrieves dismissed alerts and surfaces the dismissal reason, comment, and the user who dismissed them.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=dismissed&per_page=100" \
  --paginate \
  --jq '.[] | {number, rule: .rule.name, dismissed_reason, dismissed_comment, dismissed_by: .dismissed_by.login}'
```

### Alerts in test classifications only

Returns alerts where the most recent instance is classified as test code. Useful for deprioritizing test-only findings.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" \
  --paginate \
  --jq '[.[] | select(.most_recent_instance.classifications | contains(["test"]))]'
```

### Group by tool with counts

Summarizes open alert volume per analysis tool. Useful when multiple tools (CodeQL, ESLint, Semgrep) contribute results.

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" \
  --paginate \
  --jq 'group_by(.tool.name) | map({tool: .[0].tool.name, count: length})'
```

## Secret Scanning Filters

### Filter by secret_type

Returns alerts matching a specific secret type. Accepts any `secret_type` value from the API response.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.secret_type == "github_personal_access_token")]'
```

### Active open secrets

Filters to secrets that are both open and confirmed active. These represent the highest-priority remediation targets.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.state == "open" and .validity == "active")]'
```

### Group by secret_type with active counts

Summarizes exposure by secret type and breaks down how many of each type are currently active.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq 'group_by(.secret_type) | map({secret_type: .[0].secret_type, display_name: .[0].secret_type_display_name, count: length, active: [.[] | select(.validity == "active")] | length})'
```

### Publicly leaked secrets

Returns alerts where the secret was detected in a public location, indicating broader exposure risk.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.publicly_leaked == true)]'
```

### Push-protection bypasses

Lists alerts where a developer explicitly bypassed push protection to commit the secret. Useful for auditing policy adherence.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.push_protection_bypassed == true) | {number, secret_type, bypassed_by: .push_protection_bypassed_by.login, bypassed_at: .push_protection_bypassed_at}]'
```

### Filter for multi-repo secrets

Returns alerts flagged as present in multiple repositories. These indicate broader exposure across the organization.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --paginate \
  --jq '[.[] | select(.multi_repo == true)]'
```

## Dependabot Filters

### Group by ecosystem with severity breakdown

Summarizes open alerts per package ecosystem, with critical and high counts broken out for prioritization.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq 'group_by(.dependency.package.ecosystem) | map({ecosystem: .[0].dependency.package.ecosystem, count: length, critical: [.[] | select(.security_advisory.severity == "critical")] | length, high: [.[] | select(.security_advisory.severity == "high")] | length})'
```

### Runtime-scope critical alerts only

Returns only critical alerts where the affected dependency is used at runtime, excluding development-only packages.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq '[.[] | select(.dependency.scope == "runtime" and .security_advisory.severity == "critical")]'
```

### Alerts where a patch is available

Filters to alerts where an upgraded package version resolves the vulnerability and surfaces the fix version.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq '[.[] | select(.security_vulnerability.first_patched_version != null) | {number, package: .dependency.package.name, current: .security_vulnerability.vulnerable_version_range, fix_version: .security_vulnerability.first_patched_version.identifier}]'
```

### Show CVSS scores

Returns CVSS v3 and v4 scores alongside severity for a fuller risk picture than severity label alone.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq '.[] | {number, package: .dependency.package.name, cvss_v3: .security_advisory.cvss_severities.cvss_v3.score, cvss_v4: .security_advisory.cvss_severities.cvss_v4.score, severity: .security_advisory.severity}'
```

### Show EPSS exploit probability

Returns the EPSS score for each alert. EPSS ranges from 0 to 1 and indicates the likelihood of exploitation in the wild within the next 30 days.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq '.[] | {number, package: .dependency.package.name, epss: .security_advisory.epss.percentage, severity: .security_advisory.severity}'
```

### Development-scope only

Returns alerts affecting development-only dependencies. Useful for deprioritizing or separately tracking dev toolchain vulnerabilities.

```bash
gh api repos/{owner}/{repo}/dependabot/alerts --paginate \
  -f state=open \
  --jq '[.[] | select(.dependency.scope == "development")]'
```

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
