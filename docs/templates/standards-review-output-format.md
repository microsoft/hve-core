---
title: Code Review Standards Output Format
description: Report template and findings format for the Code Review Standards agent
sidebar_position: 9
author: microsoft/hve-core
ms.date: 2026-03-26
ms.topic: reference
---

## Code / PR Summary

One-sentence purpose and scope of changes or selected code.

## Risk Assessment

Low / Medium / High / Critical, with a one-sentence justification.

## Strengths

* What is excellent (bullet list)

## Changed Files Overview

| File               | Lines Changed | Risk Level | Issues Found |
|--------------------|---------------|------------|--------------|
| `path/to/file.ext` | +12 -3        | Medium     | 2            |

Assign risk levels based on component responsibility: High for files handling security,
authentication, data persistence, or financial logic;
Medium for core business logic and API boundaries; Low for utilities,
configuration, and cosmetic changes.

## Findings

Only include findings for lines present in the diff. Number findings sequentially and order by severity; Critical → High → Medium + Low.

Use the following format for each finding:

````markdown
#### Issue {number}: [Brief descriptive title]

**Severity**: Critical / High / Medium / Low
**Category**: \<skill-defined category, e.g. Error Handling, Input Validation\>
**Skill**: \<exact skill `name` from frontmatter that surfaced this finding\>
**File**: `path/to/file.ext`
**Lines**: 45-52

### Problem

[Specific description of the issue and why it matters]

### Current Code

```language
[Exact code from the diff that has the issue]
```

### Suggested Fix

```language
[Exact replacement code that fixes the issue]
```
````

## Findings Format Rules

* Group findings by severity: Critical -> High -> Medium -> Low.
* When a skill defines its own findings format (e.g. a different table Layout), the agent's Output Format takes precedence.
* Omit the `### Current Code` and `### Suggested Fix` sections when no code
  change is needed (e.g. documentation-only findings).

## Positive Changes

Highlight well-implemented patterns and improvements observed in the diff.

## Testing Recommendations

List specific tests to add or update based on the review findings.

## Recommended Actions

1. Must-fix before merge
2. Nice-to-have
3. Tooling / CI improvements

**Acceptance Criteria Coverage** *(Story context only, included when story ID
and definition are provided)*

| # | Acceptance Criterion | Status                            | Notes |
|---|----------------------|-----------------------------------|-------|
| 1 | ...                  | Implemented / Partial / Not found | ...   |

**Out-of-scope Observations** *(pre-existing issues in unchanged code -
excluded from verdict)*

| Issue | Recommendation             |
|-------|----------------------------|
| ...   | Consider fixing separately |

## Overall Verdict

Select based on the highest severity finding:

* Any **Critical** or **High** findings → ❌ Request changes
* Only **Medium** or **Low** findings → 💬 Approve with comments
* No findings → ✅ Approve

---
*Skills Loaded: \<comma-separated list of loaded skill names\>*
*Skills Unavailable: \<comma-separated list of skill names whose SKILL.md was not found at the expected path, or "none"\>*

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
