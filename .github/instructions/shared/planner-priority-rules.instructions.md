---
description: "Shared priority derivation rules for HVE Core planner agents — categorical Concern Level model, four-tier priority ladder, tie-break rules, and forbidden numeric-priority constructs"
applyTo: '**/.copilot-tracking/rai-plans/**, **/.copilot-tracking/security-plans/**, **/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/accessibility-plans/**, **/.copilot-tracking/sustainability-plans/**'
---

# Planner Priority Rules

This file is the single source of truth for how HVE Core planner agents (RAI, Security, SSSC, Sustainability, Accessibility) derive work-item priority. Every planner identity, backlog, and handoff instruction file references this contract. Per-domain instructions may add domain-specific Concern Level criteria, but they may not redefine the priority ladder, the tie-break rules, or the forbidden constructs listed below.

## Hard Rule

**Never derive priority from numerical scores.** Priority is derived from the combination of Concern Level, trigger severity, and per-domain coverage tracker observations (`principleTracker`, `controlTracker`, `criterionTracker`). Numeric values that appear in indicator activation, rubrics, or evidence registers are observation aids only — they must not feed an arithmetic priority computation, weighted composite, or threshold-to-priority mapping.

## Concern Level Model

Each planner classifies findings into one of three categorical Concern Levels. Domain instructions define what evidence places a finding into each level; the labels and downstream derivation behavior below are fixed.

| Concern Level    | General Meaning                                                                                                              |
|------------------|------------------------------------------------------------------------------------------------------------------------------|
| Low Concern      | Finding has limited blast radius, mitigations exist, no regulatory or safety pressure, and no prohibited-use trigger.        |
| Moderate Concern | Finding has elevated exposure, partial mitigation, or pending regulatory scrutiny; warrants planned remediation.             |
| High Concern     | Finding has broad blast radius, missing or insufficient mitigation, prohibited-use proximity, or active regulatory exposure. |

Concern Level is a **summary label** the agent assigns from the activated-indicator and tracker pattern. It is never produced by averaging numeric scores or applying a `score ≥ N → label` threshold.

## Priority Ladder

| Priority  | Criteria                                                                                                        | Suggested Action                                                                              |
|-----------|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| Immediate | Prohibited-use gate trigger, or High Concern combined with active regulatory or safety exposure.                | Block phase advancement (where the gate model permits) and remediate before the next handoff. |
| Near-term | High Concern without active regulatory exposure, or Moderate Concern with prohibited-use proximity.             | Schedule into the next backlog increment.                                                     |
| Planned   | Moderate Concern with sufficient mitigation in place, or Low Concern combined with elevated downstream context. | Schedule into a future backlog increment with a documented owner.                             |
| Backlog   | Low Concern with no elevated context, or coverage-tracker observation with no active gap.                       | Track for opportunistic remediation; no committed delivery date required.                     |

### Tracker-Shorthand Mapping

Work-item bodies, ADO `Priority` fields (numeric `1`–`4`), and GitHub `priority/pN` labels may use the `P0`–`P4` shorthand below. The shorthand is an output-format convenience for issue trackers and does not introduce a numeric priority computation — assignment still derives from the categorical ladder above.

| Shorthand | Ladder Equivalent                           | ADO `Priority` | GitHub Label  |
|-----------|---------------------------------------------|----------------|---------------|
| P0        | Immediate                                   | `1`            | `priority/p0` |
| P1        | Near-term                                   | `2`            | `priority/p1` |
| P2        | Planned                                     | `3`            | `priority/p2` |
| P3        | Backlog                                     | `4`            | `priority/p3` |
| P4        | Backlog (deferred-coverage tracker entries) | `4`            | `priority/p4` |

Per-domain backlog instructions may use either the ladder labels or the shorthand, but must not introduce additional priority bands or numeric thresholds beyond this mapping.

## Derivation Rules

* Prohibited-use gate triggers always derive **Immediate** regardless of Concern Level.
* High Concern derives **Immediate** when paired with active regulatory or safety exposure; otherwise **Near-term**.
* Moderate Concern derives **Near-term** when paired with prohibited-use proximity; otherwise **Planned**.
* Low Concern derives **Planned** when elevated downstream context exists; otherwise **Backlog**.
* Coverage-tracker entries (`principleTracker`, `controlTracker`, `criterionTracker`) supply supporting evidence for the Concern Level assignment. They do not override the ladder.
* On conflict between two rules, the **higher priority wins**. Document the rule that selected the higher level in the work-item rationale.

## Tie-Break Rules

When two or more findings derive the same priority and a deterministic ordering is required (for example, when generating a sequenced backlog):

1. Prohibited-use gate triggers sort first.
2. Findings with active regulatory or safety exposure sort next.
3. Findings with broader blast radius (more affected components, larger user impact, or wider supply-chain reach) sort next.
4. Coverage-tracker entries marked `mappedInPhase3: false` sort last within their priority band — they are deferred-coverage rather than active gaps.
5. Within an otherwise-identical group, sort by domain finding ID ascending for stability.

## Forbidden Constructs

Planner instruction files, work-item bodies, state schemas, and handoff outputs must not contain the following:

* Field names: `priorityScore`, `weightedComposite`, `riskScore`, `compositeScore`, `severityScore`, `urgencyScore`.
* Mappings of the form `score < N → Critical`, `value ≥ N → High Priority`, or any other numeric-threshold-to-priority rule.
* `Likelihood × Impact = Risk` matrices used to assign work-item priority. Likelihood and Impact may be recorded as observation context but must not be multiplied or otherwise composed into a priority value.
* Weighted dimension averages used to assign Concern Level, depth tier, or work-item priority.
* "Top N by score" backlog ordering. Backlog ordering follows the priority ladder and tie-break rules above.

When an indicator activation rule itself uses a numeric threshold (for example, a score-bracket lookup that maps to a categorical activation), that threshold remains acceptable provided its output is the categorical activation flag and not a priority value.

## Cross-Reference

* Concern Level criteria specific to RAI security findings live in `.github/instructions/rai-planning/rai-security-model.instructions.md`.
* Concern Level criteria specific to base security findings live in `.github/instructions/security/security-model.instructions.md`.
* Coverage tracker schemas live in each planner's identity instructions (`*-identity.instructions.md`).
* Depth-tier naming (canonical `Tier 1` / `Tier 2` / `Tier 3`, with narrative aliases such as `Lightweight` / `Standard` / `In-Depth`) and per-domain indicator-result vocabularies (for example, SSSC's `None` / `Limited` / `Broad` / `Extensive`, accessibility's surface-kind and audience-composition enums) are domain-owned and may differ across planners provided they remain categorical and feed Concern Level rather than a numeric priority computation.
* The priority ladder and forbidden-constructs list in this file take precedence over any conflicting language elsewhere.
