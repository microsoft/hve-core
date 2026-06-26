---
title: Code Review Output Formats
description: Report structure, findings schema, and persistence rules for review orchestrators and skill-backed subagents.
ms.date: 2026-06-26
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
  "pr_comment_draft": {
    "applies": true,
    "event": "REQUEST_CHANGES | COMMENT | APPROVE",
    "body": "<pre-filled general PR or MR comment text>",
    "approved_for_posting": false
  },
  "out_of_scope_observations": [
    { "file": "<path>", "observation": "<text>" }
  ],
  "recommended_specialist_reviews": [
    {
      "concern": "<concern>",
      "signals_matched": ["<signal>"],
      "backing": "<agent/skill/doc>",
      "availability": "available|unavailable|manual",
      "action": "<handoff or guidance note>"
    }
  ],
  "risk_assessment": "<risk level and explanation>",
  "acceptance_criteria_coverage": [
    { "ac": "<AC text>", "status": "Implemented|Partial|Not found", "notes": "<explanation>" }
  ]
}
```

Fields that do not apply may be omitted or set to `null` or an empty array. The `recommended_specialist_reviews` field is present only when specialist signals fired. The `acceptance_criteria_coverage` field is present only when the review had story or acceptance-criteria context. The `pr_comment_draft` object is present only when the review scope targets a pull request or merge request; its `approved_for_posting` flag stays `false` until the human checks the posting box in `review.md`.

## Report skeleton

Structure the merged report in this order:

1. Metadata header with reviewer name, branch, date, aggregate severity counts, and a concise description.
2. Changed Files Overview with a unified table of reviewed files, risk levels, and issue counts.
3. Merged Findings with all issues renumbered and tagged by source perspective.
4. Acceptance Criteria Coverage when story context was provided.
5. Positive Changes and Testing Recommendations.
6. Recommended Actions and Out-of-scope Observations.
7. Recommended specialist follow-up reviews when specialist signals fired, with Sustainability pointing to <https://learn.microsoft.com/en-us/azure/well-architected/sustainability/sustainability-get-started> and the dated directional caveat from the [Cross-Skill Forks](cross-skill-forks.md) registry.
8. Risk Assessment and the final verdict.
9. PR Comment Draft, present only when the review scope targets a pull request or merge request (see the PR comment draft section below).
10. Disclaimer and human-review sign-off, always present as the final section (see the disclaimer and human-review sign-off section below).

Omit sections that only apply to perspectives that were skipped. The disclaimer and human-review sign-off section (item 10) is never omitted.

## PR comment draft

When the review scope targets a pull request or merge request, `review.md` includes a human-editable **PR Comment Draft** section so the human can review and edit the general PR-level comment before any posting. This is the general PR or MR comment (not the inline findings), and it is gated by an explicit posting checkbox.

Render the section in `review.md` with this shape:

```markdown
## PR Comment Draft (human review required)

<!-- PR or MR scope only. The agent pre-fills the body below from the verdict and top findings. Edit it freely. It is NOT posted until you check the box. -->

**Proposed event:** REQUEST_CHANGES <!-- one of REQUEST_CHANGES | COMMENT | APPROVE -->

**Comment body (edit before posting):**

> <pre-filled general PR or MR comment derived from the verdict and the highest-severity findings>

- [ ] Reviewed, edited, and approved this comment for posting to the PR
```

Authoring rules:

- Pre-fill the **Proposed event** from the normalized verdict: `request_changes` maps to `REQUEST_CHANGES`, `approve_with_comments` to `COMMENT`, and `approve` to `APPROVE`. The human may change it.
- Pre-fill the **Comment body** with a concise, courteous general comment that acknowledges the work, states whether changes are requested based on the verdict, and summarizes the top findings at a glance. Keep it self-contained so it reads well as a single PR comment.
- Leave the posting checkbox unchecked. The agent never checks it; only the human may convert `[ ]` to `[x]`.
- Treat this checkbox as the human gate for posting the general PR or MR comment, per the interactive emission guardrails in the [Emission Modes](emission-modes.md) reference. Do not post the comment while the box is unchecked.
- Author the draft only in `review.md`. Do not reproduce the full drafted comment body in the conversational summary; the chat closeout links to this section instead of pasting it inline.

## Disclaimer and human-review sign-off

Every `review.md` ends with a Disclaimer and Human Review section, always rendered last and never omitted. It contains the verbatim `## Code-Review` `> [!CAUTION]` block from [Disclaimer Language](../../../../instructions/shared/disclaimer-language.instructions.md), followed by an unchecked `- [ ] Reviewed and validated by a qualified human reviewer` checkbox. The agent never checks this box; only a human may convert `[ ]` to `[x]`. This section restores the human-review gate as a codified part of the output contract rather than an emergent behavior of path-attached instructions.

## Narrative and board shapes

For orientation-first reviews, emit a factual walkthrough narrative before the detailed findings register. The walkthrough should be stored in the review folder and should be followed by an enumerated dispatch board that lists review items, their status, and the next action.

Use the following lightweight shapes:

- Narrative walkthrough — factual Register 1 prose with a diff summary, runway summary, and appendices.
- Dispatch board — an enumerated list or markdown table of board items with id, area, status, register, summary, links, and selectable symbols.
- Emission record — the selected emission mode, target, status, and a short outcome summary.

## Persist and present

Do not present the full report until both `review.md` and `metadata.json` have been successfully written to disk.

1. Write the merged report and metadata to disk using the review-artifacts protocol.
2. Confirm both files exist before proceeding.
3. Present a compact summary in the conversation, not the full report.

The summary should include a metadata table, a changed-files table, a compact finding table, the verdict, and a link to the full report on disk. Problem descriptions, code snippets, and suggested fixes stay in `review.md` rather than the conversational response.

End the compact summary with an explicit Next actions hand-back per the closeout contract in the [Emission Modes](emission-modes.md) reference: link the report, instruct the human to open and edit it, and offer the human-gated emission action. When the scope targets a pull request or merge request, link the PR Comment Draft section rather than reproducing the drafted comment body inline. Do not end the run on the verdict and link alone.
