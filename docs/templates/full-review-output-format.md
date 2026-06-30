---
title: Code Review Output Format
description: Shared data contracts, report structure, and persistence rules for the Code Review orchestrator and its perspective subagents
sidebar_position: 10
author: microsoft/hve-core
ms.date: 2026-06-19
ms.topic: reference
---

## Perspective Findings JSON Schema

Each perspective subagent writes findings in this format. The structured format enables deterministic merging without LLM re-parsing.

```json
{
  "summary": "<executive summary text>",
  "verdict": "approve | approve_with_comments | request_changes",
  "severity_counts": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
  "changed_files": [
    { "file": "<path>", "lines_changed": "<description>", "risk": "High|Medium|Low", "issue_count": 0 }
  ],
  "findings": [
    {
      "number": 1,
      "title": "<brief title>",
      "severity": "Critical|High|Medium|Low",
      "category": "<category name>",
      "skill": "<skill name or null>",
      "file": "<path>",
      "lines": "<line range, e.g. 45-52>",
      "problem": "<description>",
      "current_code": "<code snippet or null>",
      "suggested_fix": "<code snippet or null>"
    }
  ],
  "positive_changes": ["<observation>"],
  "testing_recommendations": ["<recommendation>"],
  "recommended_actions": ["<action>"],
  "out_of_scope_observations": [
    { "file": "<path>", "observation": "<text>" }
  ],
  "risk_assessment": "<risk level and explanation>",
  "acceptance_criteria_coverage": [
    { "ac": "<AC text>", "status": "Implemented|Partial|Not found", "notes": "<explanation>" }
  ]
}
```

Fields that do not apply may be omitted or set to `null` / empty array. The `acceptance_criteria_coverage` field is present only when the standards perspective received a story definition.

## Report Skeleton

Structure the merged report in this section order:

1. Metadata header: reviewer name, branch, date, aggregate severity counts, and the standards perspective's Code/PR Summary as the report description. If the standards perspective did not run, use another perspective's executive summary as the description.
2. Changed Files Overview: unified table of all reviewed files with risk levels and issue counts.
3. Merged Findings: all issues renumbered and tagged by source perspective, grouped by severity.
4. Acceptance Criteria Coverage: the standards perspective's coverage table, included only when a story input was provided.
5. Positive Changes: combined positive observations from every perspective that ran.
6. Testing Recommendations: combined testing guidance from every perspective that ran.
7. Recommended Actions: actions aggregated across the perspectives that ran; omit the section if none are present.
8. Out-of-scope Observations: combined observations from every perspective that ran.
9. Risk Assessment: the standards perspective's risk assessment for the overall change. If the standards perspective did not run, derive risk level from the highest-severity finding across the perspectives that ran.
10. Verdict: the strictest verdict across the perspectives that ran, with brief justification.

Omit sections sourced exclusively from a perspective that did not run.

## Persist and Present

**Do not present the report until both `review.md` and `metadata.json` have been successfully written to disk.**

1. Write the merged report and metadata to disk using the review-artifacts protocol with `reviewer` set to `code-review`.
2. Confirm both files exist before proceeding.
3. Present a **compact summary** in the conversation, not the full report. The summary contains:
   * Metadata table (reviewer, branch, date, severity counts)
   * Changed Files Overview table
   * One-line-per-finding table: `| # | Title [Source] | Severity | File:Lines |` where File:Lines is a single markdown link with a line range anchor (for example, `[review-test-sample.py](review-test-sample.py#L134-L136)`). For single-line findings use `#L<N>`; for ranges use `#L<start>-L<end>`.
   * Verdict with brief justification
   * Link to the full `review.md` on disk

   Do not reproduce problem descriptions, code snippets, or suggested fixes in the conversation response; those exist in `review.md`.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
