---
description: 'Intake-phase question cadence, taxonomy, and persistence rules for the Requirements Builder agent.'
applyTo: '**/.copilot-tracking/requirements-sessions/**'
---

# Requirements Builder — Phase 2: Intake

Phase 2 elicits the structured evidence that powers downstream drafting. All captured answers are persisted under `.copilot-tracking/requirements-sessions/{slug}/intake/` and indexed in `state.intake.answeredQuestions[]`.

## Question Cadence

* **Maximum 5 questions per user-facing turn.** Fewer is fine; more is not.
* Use markers in every batch:
  * ❓ open question awaiting answer
  * ✅ answered (include the captured value as the rendered answer)
  * ❌ rejected by the user (record reason in `state.intake.rejectedQuestions[]`)
* Never re-ask a question that already appears with ✅ or ❌ in `state.intake`. Scan `state.intake.answeredQuestions[]` and `state.intake.rejectedQuestions[]` before drafting the next batch.
* When more than 5 open questions remain, prioritize universal taxonomy items (below) before per-framework follow-ups.

## Scan-Document-First Dedup

Before generating new questions, scan inputs already present in the session for answers:

1. `intake/from-meeting-analyst.yml` (when entry mode is `meeting-handoff`).
2. Any user-attached files referenced in the prior turn.
3. Existing `intake/stakeholders.yml` and `intake/evidence.yml` (resume scenarios).
4. Linked downstream artifacts (e.g. an existing `docs/prds/<slug>.md` when refining a draft).

Mark every question already answered by these inputs as ✅ with the captured value, and cite the source in `state.intake.answeredQuestions[].source`.

## Universal Question Taxonomy

The following themes are universal across requirements styles. Each active framework's items may declare per-framework supplemental questions via `followups[]` in `items/*.yml`; merge those into the cadence after the universal set is satisfied.

| # | Theme           | Example prompt                                                                      |
|---|-----------------|-------------------------------------------------------------------------------------|
| 1 | Vision          | What outcome does this initiative produce, and for whom?                            |
| 2 | Personas        | Which user/buyer/operator personas are in scope? Which are explicitly out of scope? |
| 3 | Problem         | What problem are we solving and how do we know it is real (evidence)?               |
| 4 | Success metrics | How will we know this is working in production? Leading and lagging indicators?     |
| 5 | Scope           | What is in v1 vs explicitly deferred? What edges are ambiguous?                     |
| 6 | Dependencies    | What systems, teams, contracts, or data sources must be in place?                   |
| 7 | Risks           | What could prevent the outcome? What is the mitigation or monitoring plan per risk? |

## Per-Framework Follow-ups

Each FSI item under an active framework may declare a `followups[]` list of additional questions scoped to that section. Schedule follow-ups only after the universal taxonomy is fully ✅ or ❌. Tag each follow-up in `state.intake.answeredQuestions[].frameworkId` so the review phase can audit per-framework completeness.

## Persistence

After each batch of answers:

* Persona/sponsor/role data → `intake/stakeholders.yml`.
* Claims, sources, metrics, evidence quotations → `intake/evidence.yml`.
* Meeting-handoff payload (entry mode `meeting-handoff` only) → `intake/from-meeting-analyst.yml`. Treat this file as read-only after intake completes.
* `state.intake.answeredQuestions[]` gains one entry per resolved question with `id`, `theme`, `value`, `source`, `frameworkId?`, `answeredAt`.
* `state.intake.openQuestions[]` is updated to remove resolved items.
* `state.intake.rejectedQuestions[]` gains one entry per ❌ with `id`, `reason`, `rejectedAt`.

## Exit Criteria

Phase 2 is complete when **either**:

* Every universal taxonomy theme has at least one ✅ or explicit ❌ entry, **and**
* Every active framework reports zero blocking `followups[]` (a follow-up flagged `required: true` blocks; `required: false` does not).

When complete, append a one-paragraph summary to `compaction-log.md` and advance to Phase 3.
