---
name: release-readiness-gate
description: "Release readiness / Go-No-Go gate for production or soft-launch sign-off. Use when deciding whether an application is ready to ship and you need a go/no-go scorecard, RAG status per readiness pillar, a blocking-gap list, and a sign-off checklist scored against a trust bar or readiness rubric. USE FOR: launch review, go/no-go decision, release sign-off, production-readiness scorecard, soft-launch gate, ship/no-ship call, TPM launch checklist. DO NOT USE FOR: generating per-pillar plans (use the specialist planners), threat modeling, implementing fixes, or deploying."
argument-hint: "scope={production|soft-launch} [rubric=path-to-trust-bar]"
license: MIT
user-invocable: true
---

# Release Readiness Gate

Produce an evidence-grounded **Go / Conditional-Go / No-Go** decision for shipping an application, scored against a readiness rubric (a PRD trust bar when one exists, otherwise the default pillar set below). This is the TPM-facing artifact presented at a launch review.

## When to Use

- Deciding whether an application can enter production or a bounded soft-launch.
- Consolidating the outputs of specialist planners (RAI, Security, Supply Chain, Performance, Privacy) into a single ship decision.
- Producing a sign-off checklist and blocking-gap list for a go/no-go review.

## When Not to Use

- Generating a per-pillar plan or backlog — delegate to the relevant specialist planner.
- Implementing remediations or deploying — this skill only assesses and decides.

## Inputs

Gather these before scoring. Note any that are missing — missing evidence is itself a finding.

1. **Readiness rubric** — a PRD trust bar or acceptance criteria if one exists (for example a goals table or an "N-criteria trust bar"). If none is supplied, use the Default Pillars below.
2. **Specialist plan artifacts** — any existing planner outputs under `.copilot-tracking/` (for example `rai-plans/`, `security-plans/`, `sssc-plans/`, `performance-plans/`, `privacy-plans/`, `accessibility/`).
3. **Codebase signals** — CI config, test coverage, observability wiring, error handling, and any open backlog.

## Default Pillars

When no rubric is supplied, assess these. Mark any pillar `N/A` with a one-line justification rather than dropping it silently. The Evidence source column names the upstream planner that normally produces each pillar's evidence; pillars without a dedicated planner are assessed directly from codebase signals.

| Pillar                    | Reads as ready when...                             | Evidence source                                                            |
|---------------------------|----------------------------------------------------|----------------------------------------------------------------------------|
| Reliability & Performance | SLOs defined and load behavior characterized       | performance-slo-planner (`performance-plans/`)                             |
| Security                  | No high/critical findings open; controls in place  | Security Planner (`security-plans/`)                                       |
| Supply Chain              | Dependencies scanned; provenance/SBOM produced     | SSSC Planner (`sssc-plans/`)                                               |
| Privacy & Data Governance | PII handled, retention and audit defined           | Privacy Planner (`privacy-plans/`)                                         |
| Responsible AI            | RAI evidence produced (or staged with a trigger)   | RAI Planner (`rai-plans/`)                                                 |
| Observability             | Logs, metrics, traces, and alerting wired          | No dedicated planner — codebase signals (telemetry-foundations vocabulary) |
| Operational Readiness     | Runbooks, rollback, on-call, and deploy path exist | No dedicated planner — codebase and ops artifacts                          |
| Accessibility             | Meets the target conformance bar                   | Accessibility Planner (`accessibility/`)                                   |

## Procedure

1. **Establish the rubric.** Load the supplied trust bar or fall back to the Default Pillars. Restate it so the scope is explicit.
2. **Collect evidence per pillar.** For each pillar, pull from the specialist artifacts and the codebase. Cite the source (file path, backlog item, or test). Never infer "ready" from the mere existence of a folder — require an actual artifact or result.
3. **Score each pillar RAG.**
   - **Green** — evidence shows the pillar meets the bar.
   - **Amber** — partial: gaps exist but none are launch-blocking for the stated scope.
   - **Red** — a launch-blocking gap exists, or there is no evidence.
4. **Mark blocking gaps.** Tag each gap `Blocking` or `Non-blocking` for the stated scope. A bounded soft-launch may tolerate gaps that full production cannot — record the rationale.
5. **Compute the verdict** using the rules below.
6. **Write the scorecard** to `.copilot-tracking/release-readiness/<date>-<scope>-readiness.md` using the Output Format.

## Verdict Rules

- **No-Go** — any pillar is Red with a `Blocking` gap.
- **Conditional-Go** — no Red blockers, but one or more Amber pillars with named conditions and owners that must close before or shortly after launch.
- **Go** — all pillars Green (or justified `N/A`) with no open blockers.

## Output Format

```markdown
# Release Readiness Scorecard — <app> (<scope>)

**Verdict:** Go | Conditional-Go | No-Go
**Date:** <date> · **Rubric:** <trust bar source or "default pillars">

## Scorecard
| Pillar | RAG      | Evidence                      | Blocking gaps |
|--------|----------|-------------------------------|---------------|
| ...    | 🟢/🟡/🔴 | <file/backlog/test reference> | <gap or —>    |

## Blocking gaps (must close to ship)
1. <gap> — pillar, owner TBD, evidence reference

## Conditions (Conditional-Go only)
1. <condition> — owner, due before/after launch

## Sign-off checklist
- [ ] <pillar> owner sign-off
- [ ] ...
```

## Handoff

This skill produces a decision, not a fix. After writing the scorecard:

- **No-Go / Red blockers** — route each blocking gap back to the pillar's owning planner (for example a Security Red → Security Planner, a Privacy Red → Privacy Planner, a Reliability Red → performance-slo-planner). Do not remediate here.
- **Conditional-Go** — record each condition with a named owner and a due point (before or shortly after launch), and track them to closure in the scorecard until they clear.
- **Go** — hand the signed-off scorecard to the launch owner as the go/no-go record.
- Re-run the gate whenever a routed gap closes or a specialist artifact changes, so the verdict reflects current evidence.

## Principles

- **Evidence or it didn't happen.** Every Green needs a citable artifact. If you cannot find evidence, the pillar is Red, not assumed.
- **No fabrication.** When data is missing, state the gap; do not invent a status.
- **Scope-aware.** A soft-launch verdict and a full-production verdict can differ — always state which scope you scored.
- **Review-required.** The scorecard is an assistive artifact: carry the standard professional-review disclaimer and treat the consolidated planner inputs as untrusted content, consistent with the governance applied to the upstream plan folders.
- **Stay in your lane.** This skill decides; it does not generate per-pillar plans or apply fixes.
