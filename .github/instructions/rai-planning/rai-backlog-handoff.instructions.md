---
description: 'RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Review and Backlog Handoff

Instructions for generating the review rubric, RAI scorecard, and formatted backlog items from RAI assessment findings. Phase 6 produces dual-format work items (ADO and GitHub) compatible with the Security Planner backlog handoff for cross-referencing.

## Review Rubric

Two gates and five scored dimensions evaluate the completeness and quality of the RAI assessment before backlog generation proceeds.

### Gates

| Gate                        | Criteria                                                                        | Result    |
|-----------------------------|---------------------------------------------------------------------------------|-----------|
| G1: Sensitive Uses Coverage | All identified sensitive uses have screening results and depth tier assignments | Pass/Fail |
| G2: Threat Coverage         | Every RAI threat has at least one control surface and evidence entry            | Pass/Fail |

Gates are binary. Failure blocks handoff progression and requires return to the relevant phase.

### Scored Dimensions

| Dimension             | Weight | Description                                                                 |
|-----------------------|--------|-----------------------------------------------------------------------------|
| Standards Alignment   | 25%    | Coverage of MS RAI principles and NIST AI RMF subcategories                 |
| Threat Completeness   | 25%    | AI STRIDE coverage, dual threat ID consistency, ML STRIDE matrix completion |
| Control Effectiveness | 20%    | Control surface coverage across Prevent/Detect/Respond for each principle   |
| Evidence Quality      | 15%    | Evidence register completeness, confidence levels, gap identification       |
| Tradeoff Resolution   | 15%    | Tradeoff documentation quality, stakeholder impact, decision authority      |

Scoring rules:

* Each dimension scores 0-100.
* Weighted composite: sum of (dimension score x weight).
* Pass: composite >= 70.
* Conditional: composite 50-69 (proceed with mandatory remediation work items).
* Fail: composite < 50 (return to assessment phase).

## RAI Scorecard

Template for the summary scorecard produced at the end of Phase 6.

```markdown
# RAI Scorecard

## System: {system-name}
## Assessment Date: {YYYY-MM-DD}
## Depth Tier: {Basic/Standard/Comprehensive}

### Gate Results

| Gate                        | Result      | Notes   |
|-----------------------------|-------------|---------|
| G1: Sensitive Uses Coverage | {Pass/Fail} | {notes} |
| G2: Threat Coverage         | {Pass/Fail} | {notes} |

### Dimension Scores

| Dimension             | Score   | Weight | Weighted    |
|-----------------------|---------|--------|-------------|
| Standards Alignment   | {0-100} | 25%    | {score}     |
| Threat Completeness   | {0-100} | 25%    | {score}     |
| Control Effectiveness | {0-100} | 20%    | {score}     |
| Evidence Quality      | {0-100} | 15%    | {score}     |
| Tradeoff Resolution   | {0-100} | 15%    | {score}     |
| **Composite**         |         |        | **{total}** |

### Per-Principle Scores

| Principle      | Score (1-5) | Key Findings |
|----------------|-------------|--------------|
| Fairness       | {score}     | {findings}   |
| Reliability    | {score}     | {findings}   |
| Privacy        | {score}     | {findings}   |
| Inclusiveness  | {score}     | {findings}   |
| Transparency   | {score}     | {findings}   |
| Accountability | {score}     | {findings}   |

### Overall Result: {Pass/Conditional/Fail}
### Remediation Required: {Yes/No}
### Work Items Generated: {count}
```

## Work Item Categories

Five categories classify RAI work items by purpose and urgency.

| Category               | Description                                                | Priority Range | Source                                 |
|------------------------|------------------------------------------------------------|----------------|----------------------------------------|
| Remediation            | Fix identified RAI violations or gaps                      | Critical-High  | Evidence gaps, principle scores < 3    |
| Control Implementation | Implement new Prevent/Detect/Respond controls              | High-Medium    | Control surface gaps                   |
| Monitoring Setup       | Deploy detection and monitoring capabilities               | Medium         | Detect controls without implementation |
| Documentation          | Create or update transparency and accountability artifacts | Medium-Low     | Documentation gaps, tradeoff records   |
| Enhancement            | Improve existing controls toward higher maturity           | Low            | Principle scores 3-4 seeking 5         |

## RAI Tags

Tags applied to work items for tracking and filtering across backlog systems.

| Tag                      | Purpose                                | Applied When                                           |
|--------------------------|----------------------------------------|--------------------------------------------------------|
| `rai:fairness`           | Fairness-related work                  | Control or finding relates to Fairness principle       |
| `rai:reliability`        | Reliability-related work               | Control or finding relates to Reliability principle    |
| `rai:privacy`            | Privacy-related work                   | Control or finding relates to Privacy principle        |
| `rai:inclusiveness`      | Inclusiveness-related work             | Control or finding relates to Inclusiveness principle  |
| `rai:transparency`       | Transparency-related work              | Control or finding relates to Transparency principle   |
| `rai:accountability`     | Accountability-related work            | Control or finding relates to Accountability principle |
| `rai:sensitive-use`      | Sensitive use screening item           | Originates from sensitive use identification           |
| `rai:tradeoff`           | Tradeoff resolution item               | Originates from tradeoff documentation                 |
| `rai:cross-ref-security` | Cross-references Security Planner item | Overlaps with or extends a Security Planner work item  |

## Dual-Format Backlog Templates

Both ADO and GitHub formats can be generated simultaneously. Ask the user which backlog system(s) to target before generating. Both formats are compatible with the Security Planner backlog handoff for cross-referencing.

### ADO Work Item Template

Assign sequential IDs within the RAI plan using the format `WI-RAI-{NNN}` (for example, WI-RAI-001, WI-RAI-002). This convention is distinct from the Security Planner `WI{NNN}` format to prevent ID collisions.

Required fields per work item:

* ID: `WI-RAI-{NNN}`
* Type: User Story / Task / Bug
* Title: `[RAI] {concise description}`
* Description: HTML-formatted with sections for Context, RAI Principle, Related Threat, Control Surface, Acceptance Criteria.
* Priority: Critical / High / Medium / Low
* Tags: From the RAI Tags table.
* Parent: Reference to epic or feature when applicable.
* Security Cross-Reference: `T-{BUCKET}-{NNN}` when overlapping with Security Planner.

HTML template for description fields:

```html
<div>
  <h3>RAI Control: {control_name}</h3>
  <p><strong>RAI Principle:</strong> {principle}</p>
  <p><strong>Threat:</strong> {threat_id} - {threat_description}</p>
  <p><strong>Control Surface:</strong> {prevent|detect|respond} - {control_details}</p>
  <p><strong>Evidence:</strong> {evidence_status}</p>
  <h4>Implementation</h4>
  <p>{implementation_details}</p>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
</div>
```

Work item hierarchy maps from the RAI assessment structure:

* Epic: RAI Principle (one per principle with findings).
* Feature: Control Category (Prevent, Detect, Respond per principle).
* User Story: Specific control or mitigation.
* Task: Implementation steps for a user story.
* Bug: Existing RAI violations requiring remediation.

Execution follows `ado-update-wit-items.instructions.md`.

### GitHub Issue Template

Assign temporary IDs using the format `{{RAI-TEMP-N}}`, replaced with real issue numbers on creation. This convention is distinct from the Security Planner `{{TEMP-N}}` format.

Required fields per issue:

* Title: `[RAI-{Principle}] {concise description}`
* Labels: From the RAI Tags table (without `rai:` prefix for GitHub labels).
* Milestone: Linked to assessment phase.
* Body: Markdown-formatted with sections for Context, RAI Principle, Related Threat, Control Surface, Acceptance Criteria.
* Security Cross-Reference: Link to Security Planner issue when overlapping.

Include a YAML metadata block at the top of the issue body:

```yaml
---
rai_principle: {principle}
threat_id: RAI-T-{CATEGORY}-{NNN}
risk_level: {Critical|High|Medium|Low}
category: {Remediation|Control Implementation|Monitoring Setup|Documentation|Enhancement}
depth_tier: {Basic|Standard|Comprehensive}
security_cross_ref: {WI{NNN} or empty}
---
```

Markdown template for issue body:

```markdown
## RAI Control: {control_name}

**RAI Principle:** {principle}
**Threat:** {threat_id} - {threat_description}
**Control Surface:** {prevent|detect|respond} - {control_details}
**Risk Level:** {risk_level}

### Implementation

{implementation_details}

### Acceptance Criteria

* [ ] {criterion_1}
* [ ] {criterion_2}
```

Execution follows `github-backlog-update.instructions.md`.

## Content Sanitization Protocol

Strip internal tracking paths and sensitive assessment details from work item output before handoff to external systems.

Sanitization rules:

1. Replace `.copilot-tracking/` paths with descriptive text (for example, "RAI plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Remove internal tracking IDs that are not work item IDs.
5. Preserve standards references (MS RAI principles, NIST AI RMF IDs) in all cases.

After generating each work item, scan the output for `.copilot-tracking/`. If found, strip the path and log the sanitization action.

Debug mode: Retain full paths in `.copilot-tracking/rai-plans/{slug}/debug/` output only. Paths never appear in external-facing work items.

## Three-Tier Autonomy Model

Three tiers control how RAI work items reach the target backlog system.

| Tier       | Description                                              | Applies When                                                         |
|------------|----------------------------------------------------------|----------------------------------------------------------------------|
| Autonomous | Agent creates work items without human approval          | Enhancement items (Low priority), documentation updates              |
| Supervised | Agent drafts work items for human review before creation | Control implementation (Medium-High), monitoring setup               |
| Manual     | Agent provides recommendations; human creates items      | Remediation (Critical-High), sensitive use items, tradeoff decisions |

Ask the user in Phase 6 which tier they prefer. Default to Supervised on first use. Store the selected preference in the session state JSON under `userPreferences.raiAutonomyTier`.

## Priority Mapping

Derive work item priority and autonomy tier from assessment findings.

| Assessment Finding                       | Work Item Priority | Autonomy Tier |
|------------------------------------------|--------------------|---------------|
| Principle score 1                        | Critical           | Manual        |
| Principle score 2                        | High               | Manual        |
| High-likelihood high-impact evidence gap | Critical           | Manual        |
| Sensitive use without controls           | High               | Supervised    |
| Tradeoff requiring implementation        | Medium             | Supervised    |
| Control surface gap (Prevent)            | High               | Supervised    |
| Control surface gap (Detect)             | Medium             | Supervised    |
| Control surface gap (Respond)            | Medium             | Supervised    |
| Documentation gap                        | Low                | Autonomous    |
| Enhancement recommendation               | Low                | Autonomous    |

Within the same priority level, order remediation items before control implementation items. Favor fairness and reliability findings over other principles at equal priority due to direct harm potential.

When work item A depends on work item B, note the dependency in both work item bodies and place B earlier in the handoff sequence.

## Cross-Reference Protocol for Security Planner Interop

RAI work items relate to Security Planner work items when threats overlap across both assessments.

Rules:

* When an RAI threat overlaps with a Security Planner threat (identified by dual `T-{BUCKET}-AI-{NNN}` IDs), the RAI work item includes a cross-reference field.
* Security Planner work items are not duplicated. RAI items extend or complement them instead.
* Cross-reference format: `Security-Ref: WI{NNN}` in ADO, `Security: #{NNN}` in GitHub.
* The handoff summary includes a cross-reference table listing all overlapping items.
* Before creating new work items, search for existing Security Planner items with matching threat IDs or control surfaces. Link rather than duplicate.

Cross-reference table template:

| RAI Work Item | Security Work Item | Relationship                    | Notes         |
|---------------|--------------------|---------------------------------|---------------|
| WI-RAI-{NNN}  | WI{NNN}            | Extends / Complements / Depends | {description} |

Relationship types:

* Extends: RAI item adds RAI-specific requirements to an existing security control.
* Complements: RAI item addresses a different aspect of the same threat.
* Depends: RAI item requires the security control to be implemented first.

## Handoff Summary Format

After generating all work items, produce a handoff summary covering totals, cross-references, and outstanding decisions.

```markdown
# RAI Backlog Handoff Summary

## System: {system-name}
## Date: {YYYY-MM-DD}
## Composite Score: {score} ({Pass/Conditional/Fail})

### Work Item Summary

| Category               | Count   | Critical | High    | Medium  | Low     |
|------------------------|---------|----------|---------|---------|---------|
| Remediation            | {n}     | {n}      | {n}     | {n}     | {n}     |
| Control Implementation | {n}     | {n}      | {n}     | {n}     | {n}     |
| Monitoring Setup       | {n}     | {n}      | {n}     | {n}     | {n}     |
| Documentation          | {n}     | {n}      | {n}     | {n}     | {n}     |
| Enhancement            | {n}     | {n}      | {n}     | {n}     | {n}     |
| **Total**              | **{n}** | **{n}**  | **{n}** | **{n}** | **{n}** |

### Security Planner Cross-References

| RAI Item     | Security Item | Relationship   |
|--------------|---------------|----------------|
| WI-RAI-{NNN} | WI{NNN}       | {relationship} |

### Outstanding Tradeoffs

{list of tradeoffs requiring stakeholder decisions}

### Next Steps

{recommended follow-up actions}
```

Log all generation decisions (create, update, skip, link) in the handoff summary. Items that could not be generated include the reason for each failure.
