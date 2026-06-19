---
title: Code Review Output Formats
description: Report structure, findings schema, and persistence rules for review orchestrators and skill-backed subagents.
ms.date: 2026-06-18
---

## Output contract

Review findings should be expressed as structured data first, then rendered into a merged markdown report. The structured data format enables deterministic merging without re-parsing the narrative report.

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

Fields that do not apply may be omitted or set to `null` or an empty array. The `acceptance_criteria_coverage` field is present only when the review had story or acceptance-criteria context.

## Report skeleton

Structure the merged report in this order:

1. Metadata header with reviewer name, branch, date, aggregate severity counts, and a concise description.
2. Changed Files Overview with a unified table of reviewed files, risk levels, and issue counts.
3. Merged Findings with all issues renumbered and tagged by source perspective.
4. Acceptance Criteria Coverage when story context was provided.
5. Positive Changes and Testing Recommendations.
6. Recommended Actions and Out-of-scope Observations.
7. Risk Assessment and the final verdict.

Omit sections that only apply to perspectives that were skipped.

## Persist and present

Do not present the full report until both `review.md` and `metadata.json` have been successfully written to disk.

1. Write the merged report and metadata to disk using the review-artifacts protocol.
2. Confirm both files exist before proceeding.
3. Present a compact summary in the conversation, not the full report.

The summary should include a metadata table, a changed-files table, a compact finding table, the verdict, and a link to the full report on disk. Problem descriptions, code snippets, and suggested fixes stay in `review.md` rather than the conversational response.
