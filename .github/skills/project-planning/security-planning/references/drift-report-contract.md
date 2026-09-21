---
title: Security Plan Drift Report Contract
description: Canonical full report, conversational adaptation, bounded Code Review output, and durable artifact sequencing.
ms.date: 2026-09-04
ms.topic: reference
---

# Security Plan Drift Report Contract

This contract defines the canonical body, caller adaptations, durable report sequencing, and completion statement.

## Canonical summary

Begin every full or conversational body with one summary line:

```text
Validated controls: <N> | Control drift: <N> | Residual risks: <N> | New threats: <N> | Obsolete items: <N> | Baseline: <complete|incomplete> | Filtered findings: <N>
```

Use `insufficient evidence` instead of a numeric count for a suppressed category.

## Full report sections

Render these sections in order:

1. Security plan source: resolved state and plan paths, project slug, current phase, and baseline completeness
2. Current repository evidence: producer, mode, scope, evidence pointer, selected skills, default exclusions, overrides, and drift notes
3. Validated controls: plan reference, control, finding identity, location, and notes
4. Control drift and regressions: plan reference, expected control, observed state, finding identity, location, and severity
5. Residual open risks: threat identity, description, finding identity, severity, and recommended action
6. Newly introduced threats: finding identity, skill, title, severity, affected bucket when mappable, and recommended action
7. Obsolete plan items: plan reference, evidence, reason, and recommended disposition
8. Recommended plan updates: proposed changes only; never modify the plan
9. Recommended backlog deltas: proposed additions, updates, or closures in the plan's existing identity scheme
10. Suggested next handoffs: recommendation and rationale only
11. Limitations and insufficient evidence: every suppressed category, unresolved fact class, unassessed record, and input or schema drift note

Use `None identified.` for a supported category with zero entries. Use `Insufficient evidence: <reason>.` when the category preconditions do not pass.

Include the Security Planning CAUTION block from the skill entry near the top of every durable report and before every full conversational drift body. Include the default-exclusions notice and any opted-in prefixes in section 2. Leave any human-review checkbox unchecked.

## Destination adaptations

### Direct artifact

A write-capable direct caller may write the full report under:

```text
.copilot-tracking/security-audits/<project-slug>/security-audit-<YYYY-MM-DD>-<NNN>.md
```

List only files whose names match `security-audit-<YYYY-MM-DD>-<NNN>.md` for the requested date, increment the highest three-digit sequence, and start at `001`. Ignore unrelated filenames in the same directory. If the selected path exists at creation time, increment and retry. Stop at `999` rather than overwrite. Write only this report.

### Security Reviewer

Render the full canonical body in conversation after the normal Scan Completion output and its disclaimers. The existing VULN report remains the reviewer's only durable artifact. When the user needs a durable drift report, state that direct drift invocation through `security-planning` from a write-capable context is required.

For conformant VULN_REPORT_V1 Form A evidence, populate control drift, residual planned risks, and newly introduced threats when their preconditions pass. Render validated controls and obsolete plan items as `Insufficient evidence: VULN_REPORT_V1 PASS rows do not include a covered location.` Do not infer a PASS location.

Reject a baseline reference in Security Reviewer `plan` mode because `PLAN_REPORT_V1` is plan-side evidence, not current-state evidence.

### Security Planner

Render the full canonical body as proposed plan updates inside the existing Phase 6 summary. Do not mutate plan markdown, `state.json`, phase gates, handoff flags, or human-review checkboxes.

When current-state evidence is a Security Reviewer VULN_REPORT_V1 Form A report, apply the same three eligible categories and two explicit insufficient-evidence results as the Security Reviewer destination. Direct Form B evidence with explicit covered locations remains eligible for all five categories.

When no current-state evidence resolves, state that drift was not assessed, name a user-run Security Reviewer audit or diff as the evidence-producing action, and continue the ordinary completeness review.

### Code Review

Render a bounded `Security Plan Drift` section after merged security findings and before the final report is persisted. Include:

* Summary counts
* Non-empty control drift, residual risk, and newly introduced threat entries
* `Insufficient evidence` lines for validated controls and obsolete plan items because Code Review evidence is diff-scoped
* One line pointing to the `security-planning` skill's Security Planning CAUTION disclaimer and default exclusions

Carry the same data in the optional structured field below. Omit the field when drift did not run.

```json
{
  "security_plan_drift": {
    "baseline": {
      "state_file": "<path>",
      "plan_file": "<path>",
      "status": "complete|incomplete"
    },
    "filtered_findings": 0,
    "control_drift": [],
    "residual_planned_risks": [],
    "newly_introduced_threats": [],
    "insufficient_evidence": {
      "validated_controls": "diff-scoped evidence",
      "obsolete_plan_items": "diff-scoped evidence"
    }
  }
}
```

Do not add an executed drift result to `recommended_specialist_reviews`.

## Completion statement

End every destination with the fields below. For Code Review, place this completion statement immediately before Code Review's mandatory final Disclaimer and Human Review section so that disclaimer and its unchecked checkbox remain the final section.

* Baseline path and status
* Current evidence pointer and scope
* Filtered finding count and overrides
* Output destination
* Recommended handoffs
* `Inputs and source artifacts were read-only; no plan, source, reviewer, backlog, or state artifact was modified.`
