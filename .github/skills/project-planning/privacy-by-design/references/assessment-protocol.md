---
title: Assessment Protocol
description: Step-by-step protocol for agents assessing a system against PbD 7 Foundation Principles
---

# Assessment Protocol

This document defines the step-by-step protocol that the Privacy Reviewer or Privacy Planner follows when assessing a system, feature, or data flow against the 7 Foundation Principles of Privacy by Design.

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

### Phase 2: Principle-by-principle assessment

For each principle (PbD-01 through PbD-07):

1. Read the principle reference file.
2. Evaluate each item in the principle checklist against the system evidence.
3. For each checklist item, record one of:
   - **MET** — evidence confirms the indicator is satisfied.
   - **NOT MET** — evidence confirms the indicator is violated or absent.
   - **INSUFFICIENT EVIDENCE** — cannot determine from available information.
4. Check for anti-patterns listed in the principle reference.
5. Assign a principle-level verdict: PASS, PARTIAL, or FAIL (see verdict rules below).
6. Assign a severity: HIGH, MEDIUM, or LOW (see severity rules below).
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
3. Verify that the implementation meets the highest applicable standard.
4. Flag any jurisdiction-specific obligations not met by the common baseline.
5. Record cross-jurisdictional findings with the applicable regulation and article.

### Phase 5: Synthesis and handoff

1. Aggregate findings into a summary with counts by verdict and severity.
2. Identify the top-priority findings (FAIL with HIGH severity first).
3. For each FAIL or PARTIAL finding, provide a specific, actionable remediation recommendation.
4. If all principles are PASS, confirm compliance and note any conditions.
5. Hand off findings in the finding schema format (see `finding-schema.md`).

## Verdict rules

| Verdict | Condition |
|---------|-----------|
| PASS | All checklist items are MET and no anti-patterns are detected |
| PARTIAL | Majority of checklist items are MET but gaps remain, OR anti-patterns are present with compensating controls |
| FAIL | Majority of checklist items are NOT MET, OR critical anti-patterns are present without compensating controls |

## Severity rules

| Severity | Condition |
|----------|-----------|
| HIGH | Finding involves sensitive data, affects many data subjects, or creates direct regulatory non-compliance risk |
| MEDIUM | Finding involves standard personal data, affects limited data subjects, or creates indirect compliance risk |
| LOW | Finding is a documentation or process gap with no direct impact on data subjects |

## Evidence expectations

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

| Skill | Interaction |
|-------|-------------|
| `privacy-standards` | Provides data inventory, DPIA thresholds, and standards backbone; PbD assessment builds on top |
| `security-planning` | Security controls overlap with PbD-05; reference security findings rather than duplicating |
| `rai-planner` | RAI assessment may identify data use concerns that feed into PbD-04 and PbD-07 |

## Stop rules

- Stop the assessment if scope cannot be established (no identifiable system or data flow).
- Stop and escalate if the system processes data in a jurisdiction not covered by this skill's mappings.
- Do not fabricate evidence; record INSUFFICIENT EVIDENCE and note what is needed.
- Do not provide legal opinions; frame all findings as planning guidance requiring qualified review.

---

Protocol synthesized from the assessment patterns used by the Security Reviewer and RAI Planner within hve-core, adapted for privacy principle assessment.
