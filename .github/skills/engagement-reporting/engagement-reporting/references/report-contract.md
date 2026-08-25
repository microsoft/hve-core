---
title: Engagement Reporting Contract
description: Synthesis, traceability, review, output, talk-track, and retention requirements for engagement reports.
ms.date: 2026-08-13
ms.topic: reference
---

## Working structure

```text
.working/
└── {date}-{report-type}/
    ├── research/
    │   ├── workiq-findings.md
    │   ├── board-findings.md
    │   ├── transcript-findings.md
    │   ├── manual-input.md
    │   └── coverage.md
    ├── synthesis/
    │   ├── draft.md
    │   ├── council-prompt.md
    │   ├── critique-*.md
    │   └── council-minutes.md
    └── review/
        ├── accuracy-check.md
        ├── style-check.md
        └── continuity-check.md
```

## Traceability

Maintain this chain in working artifacts:

```text
Final claim -> Draft claim -> Research finding -> Primary source
```

Previous reports can establish continuity but cannot support factual claims.
When directionality, ownership, completion state, or attribution is unclear,
flag the claim for verification.

## Synthesis

* Use the configured report template and audience
* Treat template layout, section names, order, table columns, and footer as a
  hard output contract
* Do not invent a consolidated, executive, or narrative layout when the
  configured template is `weekly-standard`
* State supported outcomes directly without naming the source channel
* Convert uncertainty into a concise blocker, ask, or next step; do not explain
  retrieval limitations in the report
* Show progression from the prior period
* Distinguish completed, in-progress, blocked, and upcoming work
* Include dates for scheduled events and identify accountable ownership
* Frame future events through completed preparation work
* Quantify outcomes when the source supports the number
* Include mitigation or a specific ask for material blockers
* Exclude unsupported strategy, sentiment, confidence, and causal claims

## Council validation

Use independent critiques for high-stakes reports, low-confidence findings,
cross-report discrepancies, or unclear directionality.

1. Build a critique input containing the draft, normalized findings, coverage,
   audience, and accuracy rules
2. Dispatch `Engagement Report Council Critic` at least twice with distinct run
   identifiers
   and isolated inputs
3. Use distinct model selections when supported and record model provenance;
   otherwise label the runs as same-model independent critiques
4. If independent agent runs are unavailable, use
   `engagement-report-council-critique` manually in separate model sessions and save each result as `critique-*.md`
5. Treat one critique as ordinary review rather than Council validation
6. Dispatch `Engagement Report Council Arbiter` to reconcile findings against
   research, not model agreement
7. Present material edits and disagreements to the user
8. Record critic runs, model provenance, evidence, decisions, rejected
   findings, and applied edits in `council-minutes.md`

## Review gate

Review the final draft for:

* Primary-source grounding
* Data minimization and audience-appropriate disclosure
* Correct directionality and partnership attribution
* Completion versus work-in-progress precision
* Continuity with prior next steps
* Style and configured `engagement.yaml` terminology compliance
* Template sections, dates, links, and formatting
* No source-channel narration, evidence commentary, confidence labels,
  coverage notes, or retrieval diagnostics

Block finalization when a material unsupported claim remains.
Also block finalization when the draft does not match a strict template. Repair
format drift before presenting the report to the user.

For standard weekly reports, perform this checklist once in the current
context. Do not invoke repository linters, shell searches, or repeated
diagnostic passes. Keep the review silent unless a material user decision is
required.

## Output

Save approved reports under `reports/`. Do not include working-file paths or the
traceability appendix in an external-facing report unless the user requests an
approved evidence appendix.

Audience-facing weekly reports must not include YAML frontmatter, source
coverage notes, confidence assessments, research counts, or verification
warnings. Return those separately in the agent response.

Offer talk tracks derived only from the approved report:

* One-sentence engagement theme
* Key points for two to three minutes of spoken delivery
* Anticipated questions and evidence-backed responses
* Transitions between sections

Talk tracks cannot introduce new claims.

## Retention

After approval and distribution, remind the user that the session directory
contains unencrypted source summaries and drafts. Offer to delete only the
specific `.working/{date}-{report-type}/` directory and require explicit
confirmation before deletion.
