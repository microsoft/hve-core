---
title: Assessment Protocol
description: Step-by-step protocol for agents assessing a system against PbD 7 Foundation Principles
---

# Assessment Protocol

Consumers that explicitly load `privacy-by-design` use this protocol to assess a system, feature, or data flow against the 7 Foundation Principles. It defines intended assessment behavior, not an existing load step in the Privacy Reviewer or Privacy Planner.

## Assessment entry conditions

Begin a PbD assessment when any of these conditions hold:

- A new feature or system processes personal data and has not been assessed against PbD principles.
- A privacy review is requested during design, architecture, or pre-release review.
- A DPIA (from the `privacy-standards` skill) identifies high-risk processing that warrants principle-level analysis.
- A data retention audit is triggered by regulatory change or incident response.

## Assessment phases

### Phase 1: Scope and context

1. Identify the system, feature, or data flow under assessment.
2. Determine the personal data categories involved (using the data inventory from `privacy-standards`).
3. Identify applicable jurisdictions (use `cross-jurisdictional-mapping.md` triggers).
4. Establish the assessment boundary: which components, services, and data stores are in scope.
5. Document the processing purposes and lawful bases for each data category.
6. Load the applicable [industry profile](industry-privacy-profiles.md), including justified overrides, custom checks and suppressions from `.pbd-config.yml`. Record the effective checklist before scoring.

### Phase 2: Principle-by-principle assessment

For each principle (PbD-01 through PbD-07):

1. Read the principle reference file.
2. Evaluate each item in the principle checklist against the system evidence.
3. For each checklist item, record one of:
   - **MET** — evidence confirms the indicator is satisfied.
   - **NOT MET** — evidence confirms the indicator is violated or absent.
   - **INSUFFICIENT EVIDENCE** — cannot determine from available information.
4. Check for anti-patterns listed in the principle reference.
5. Assign PASS, PARTIAL, FAIL, or INSUFFICIENT_EVIDENCE using the ordered verdict rules below. Record evidence completeness independently.
6. Assign CRITICAL, HIGH, MEDIUM, or LOW only for an established deficiency; otherwise use N/A.
7. Record the finding with citation fields from the principle reference.

### Phase 3: Retention and disposal assessment

When the system stores personal data:

1. Verify retention schedules exist for each data category (use `data-retention-and-disposal.md`).
2. Check that retention periods are purpose-linked and justified.
3. Verify disposal methods are appropriate for the data sensitivity.
4. Check backup and replica inclusion in retention policies.
5. Verify legal hold procedures exist if the system could be subject to litigation holds.
6. Record retention-specific findings under PbD-05.

### Phase 4: Cross-jurisdictional check

When multiple jurisdictions apply:

1. Use the jurisdictional scope triggers in `cross-jurisdictional-mapping.md`.
2. Identify which regulations apply to each data flow.
3. Assess each applicable obligation against evidence; a shared baseline does not replace jurisdiction-specific requirements. Record the common baseline as MET, NOT_MET, INSUFFICIENT_EVIDENCE, or NOT_APPLICABLE rather than inferring a boolean from missing evidence.
4. Flag any jurisdiction-specific obligations not met by the common baseline.
5. Record cross-jurisdictional findings with the applicable regulation and article.

### Phase 5: Synthesis and handoff

1. Aggregate findings into a summary with counts by verdict and severity.
2. Order actionable findings by severity: CRITICAL, HIGH, MEDIUM, LOW; within a tier, FAIL before PARTIAL. CRITICAL and HIGH both map to P1 without downgrading CRITICAL or inventing P0.
3. For each FAIL or PARTIAL finding, provide a specific, actionable remediation recommendation.
4. Apply the [finding schema's overall verdict rules](finding-schema.md#overall-verdict-rules), preserving unknowns and evidence requests separately from remediation. COMPLIANT describes this rubric only, not legal sign-off.
5. Hand off findings in the finding schema format (see `finding-schema.md`).

## Verdict rules

Evaluate these rules in order for the effective applicable checklist:

1. FAIL when more than half of applicable items are NOT MET, or a critical anti-pattern is established without effective compensating controls. Unknown items stay in the denominator, never in the NOT MET count.
2. PARTIAL when at least one deficiency or compensated anti-pattern is established and the FAIL rule does not apply. This includes ties and mixed known deficiencies with missing evidence.
3. INSUFFICIENT_EVIDENCE when no deficiency is established but any item is unknown, or no applicable items remain. Identify the evidence or scope needed; never emit a vacuous PASS.
4. PASS only when at least one applicable item remains, all are MET, and no unresolved anti-pattern or contradiction remains.

Use the same rules for a sub-check's scoped items. A confirmed anti-pattern is a deficiency even when checklist counts alone appear favorable. Record `evidence_status: INCOMPLETE` if any applicable item, anti-pattern investigation, retention obligation or jurisdictional check remains unknown; otherwise use COMPLETE. Missing artifacts are not proof that a control is absent.

Fold retention, industry/custom checks and jurisdiction-specific deficiencies into the affected principle's assessment. Do not let a sub-finding disappear behind a principle PASS. Cross-jurisdictional findings identify the affected principles; include the corresponding obligation in each applicable checklist once, not duplicate evidence counts within a principle.

## Severity rules

| Severity | Condition                                                                                                       |
|----------|-----------------------------------------------------------------------------------------------------------------|
| CRITICAL | Established deficiency with severe direct impact, or FAIL under an effective CRITICAL profile/override priority |
| HIGH     | Established deficiency with direct risk to data subjects or applicable obligations                              |
| MEDIUM   | Established control gap with limited or indirect impact                                                         |
| LOW      | Established documentation or process deficiency with no demonstrated direct impact                              |
| N/A      | No established deficiency, including PASS and unknown-only results                                              |

Determine the deficiency first, then its impact. Sensitive data alone cannot elevate PASS or unknown-only results. Apply a failed custom check's configured severity and the profile escalation rule without lowering an otherwise justified severity. A principle's severity is the highest severity of its established deficiencies; use N/A when none exist.

## Evidence expectations

Record evidence source, scope and observation date where available. Distinguish intended policy from deployed behavior. When sources conflict, compare their scope, version and timing; retain both and explain which conclusion they support. If the conflict cannot be reconciled, mark the affected check unknown rather than assuming PASS. A verified operational contradiction is NOT MET, not merely missing evidence.

For PbD-06, verify that notices accurately describe current practice. A promise to destroy eSIM profiles within 30 days contradicted by recoverability at day 120 establishes a transparency deficiency and a related PbD-05 retention issue unless an applicable, disclosed exception explains it. Preserve MET credit for independently verified notice accessibility, contact routes and other unaffected controls. Cross-reference the two issues rather than duplicating remediation for the same cause.

Acceptable evidence for MET determinations:

- Architecture documents or ADRs showing privacy-by-design decisions
- Code showing privacy controls (encryption, access control, data minimization, consent mechanisms)
- Configuration files showing privacy-protective defaults
- Data flow diagrams showing personal data boundaries
- Retention schedule documents
- Privacy impact assessments or DPIA records
- Test cases covering privacy behaviors
- Monitoring or alerting configurations for privacy-relevant events

## Interaction with other skills

| Skill               | Interaction                                                                                    |
|---------------------|------------------------------------------------------------------------------------------------|
| `privacy-standards` | Provides data inventory, DPIA thresholds, and standards backbone; PbD assessment builds on top |
| `security-planning` | Security controls overlap with PbD-05; reference security findings rather than duplicating     |
| `rai-planner`       | RAI assessment may identify data use concerns that feed into PbD-04 and PbD-07                 |

## Stop rules

- Stop the assessment if scope cannot be established (no identifiable system or data flow).
- Stop and escalate if the system processes data in a jurisdiction not covered by this skill's mappings.
- Do not fabricate evidence; record INSUFFICIENT EVIDENCE and note what is needed.
- Do not provide legal opinions; frame all findings as planning guidance requiring qualified review.

---

Protocol synthesized from the assessment patterns used by the Security Reviewer and RAI Planner within hve-core, adapted for privacy principle assessment.

Source principles: [IPC Ontario, Privacy by Design](https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf). Assessment rules and output conventions are repository-original planning guidance.
