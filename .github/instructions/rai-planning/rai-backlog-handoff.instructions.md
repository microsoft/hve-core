---
description: 'RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Review and Backlog Handoff

Instructions for generating the review rubric, RAI review summary, and formatted backlog items from RAI assessment findings. Phase 6 produces dual-format work items (ADO and GitHub) compatible with the Security Planner backlog handoff for cross-referencing.

## Review Rubric

A review checkpoint and six quality dimensions evaluate the completeness and quality of the RAI assessment before backlog generation proceeds.

### Review Checkpoints

| Checkpoint      | Criteria                                                             | Status            |
|-----------------|----------------------------------------------------------------------|-------------------|
| Threat Coverage | Every RAI threat has at least one control surface and evidence entry | ☐ Met / ☐ Not Met |

Review checkpoints are binary verification steps. A checkpoint marked "Not Met" indicates the relevant phase should be revisited before proceeding with handoff.

### Review Quality Checklist

| Dimension             | Description                                                                     | Status      |
|-----------------------|---------------------------------------------------------------------------------|-------------|
| Standards Alignment   | Coverage of responsible AI principles and NIST AI RMF subcategories             | ☐ Addressed |
| Threat Completeness   | AI STRIDE coverage, dual threat ID consistency, ML STRIDE matrix completion     | ☐ Addressed |
| Control Effectiveness | Control surface coverage across Prevent/Detect/Respond for each principle       | ☐ Addressed |
| Evidence Quality      | Evidence register completeness, confidence levels, gap identification           | ☐ Addressed |
| Tradeoff Resolution   | Tradeoff documentation quality, stakeholder impact, decision authority          | ☐ Addressed |
| Sensitive Uses        | Sensitive uses trigger coverage, depth tier justification, downstream alignment | ☐ Addressed |

Review status derivation:

* **Ready for stakeholder review** — All dimensions addressed with supporting evidence; no critical gaps identified.
* **Additional attention suggested** — Most dimensions addressed; one or more areas flagged for further consideration.
* **Significant areas need further consideration** — Multiple dimensions have limited coverage or missing evidence.

Before presenting review quality results, explain the checklist dimensions and what each status means in plain language. Frame all assessments as suggested observations based on session findings.

When presenting review quality results, explain each dimension's status by citing specific session observations. For example: "Standards Alignment is addressed — the assessment mapped all six responsible AI principles to system components with NIST AI RMF cross-references."

## RAI Review Summary

Template for the review summary produced at the end of Phase 6.

```markdown
# RAI Review Summary

## System: {system-name}
## Assessment Date: {YYYY-MM-DD}
## Depth Tier: {Basic/Standard/Comprehensive}

### Review Checkpoint Results

| Checkpoint      | Status        | Notes   |
|-----------------|---------------|---------|
| Threat Coverage | {Met/Not Met} | {notes} |

### Per-Principle Summary

| Principle            | Maturity Level                                 | Key Observations | Open Items |
|----------------------|------------------------------------------------|------------------|------------|
| Fairness             | {Foundational/Developing/Established/Advanced} | {summary}        | {count}    |
| Reliability & Safety | {level}                                        | {summary}        | {count}    |
| Privacy & Security   | {level}                                        | {summary}        | {count}    |
| Inclusiveness        | {level}                                        | {summary}        | {count}    |
| Transparency         | {level}                                        | {summary}        | {count}    |
| Accountability       | {level}                                        | {summary}        | {count}    |

### Key Findings

{Bulleted list of most significant findings from the assessment}

### Review Quality Summary

| Dimension             | Status                      | Notes   |
|-----------------------|-----------------------------|---------|
| Standards Alignment   | {Addressed/Needs Attention} | {notes} |
| Threat Completeness   | {Addressed/Needs Attention} | {notes} |
| Control Effectiveness | {Addressed/Needs Attention} | {notes} |
| Evidence Quality      | {Addressed/Needs Attention} | {notes} |
| Tradeoff Resolution   | {Addressed/Needs Attention} | {notes} |
| Sensitive Uses        | {Addressed/Needs Attention} | {notes} |

### Suggested Remediation Horizon Summary

| Horizon            | Work Item Count | Key Items   |
|--------------------|-----------------|-------------|
| Pre-Production     | {count}         | {top items} |
| Early Operations   | {count}         | {top items} |
| Ongoing Governance | {count}         | {top items} |

### Suggested Review Status: {Ready for stakeholder review / Additional attention suggested / Significant areas need further consideration}
### Remediation Suggested: {Yes/No}
### Work Items Generated: {count}

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
```

Populate the Per-Principle Summary table from `principleTracker`: maturity level from the Phase 5 assessment, key observations from the most significant `openObservations` and `resolvedObservations`, open item count from `openObservations.length`.

When `principleTracker` data is incomplete for a principle, note the gap in the Key Observations column and suggest revisiting the relevant phase.

## Work Item Categories

Five categories classify RAI work items by purpose and urgency.

| Category               | Description                                                | Suggested Horizon  | Priority Range      | Source                                                   |
|------------------------|------------------------------------------------------------|--------------------|---------------------|----------------------------------------------------------|
| Remediation            | Address identified RAI gaps or areas of concern            | Pre-Production     | Immediate–Near-term | Evidence gaps, principles with limited coverage          |
| Control Implementation | Implement new Prevent/Detect/Respond controls              | Pre-Production     | Near-term–Planned   | Control surface gaps                                     |
| Monitoring Setup       | Deploy detection and monitoring capabilities               | Early Operations   | Planned             | Detect controls without implementation                   |
| Documentation          | Create or update transparency and accountability artifacts | Ongoing Governance | Planned–Backlog     | Documentation gaps, tradeoff records                     |
| Enhancement            | Improve existing controls toward higher maturity           | Ongoing Governance | Backlog             | Principles at Developing or Established seeking Advanced |

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
| `rai:tradeoff`           | Tradeoff resolution item               | Originates from tradeoff documentation                 |
| `rai:cross-ref-security` | Cross-references Security Planner item | Overlaps with or extends a Security Planner work item  |

## Target System Selection

When generating work items, select the template based on `userPreferences.targetSystem`:

* **ado** — Use the ADO Work Item Template with HTML description format.
* **github** — Use the GitHub Issue Template with YAML metadata and markdown body.
* **both** — Generate both ADO and GitHub templates for dual-system environments.

Default to the format specified in user preferences. If no preference was set, ask the user which system(s) to target.

## Dual-Format Backlog Templates

Both ADO and GitHub formats can be generated simultaneously based on `userPreferences.targetSystem`. Both formats are compatible with the Security Planner backlog handoff for cross-referencing.

### ADO Work Item Template

Assign sequential IDs within the RAI plan using the format `WI-RAI-{NNN}` (for example, WI-RAI-001, WI-RAI-002). This convention is distinct from the Security Planner `WI-SEC-{NNN}` format to prevent ID collisions.

Required fields per work item:

* ID: `WI-RAI-{NNN}`
* Type: User Story / Task / Bug
* Title: `[RAI] {concise description}`
* Description: HTML-formatted with sections for Context, RAI Principle, Related Threat, Control Surface, Acceptance Criteria.
* Priority: Immediate / Near-term / Planned / Backlog
* Suggested Remediation Horizon: Pre-Production / Early Operations / Ongoing Governance
* Tags: From the RAI Tags table.
* Parent: Reference to epic or feature when applicable.
* Security Cross-Reference: `T-{BUCKET}-{NNN}` when overlapping with Security Planner.
* RAI Owner: (Optional) Role accountable for this item (for example, "ML Engineering Lead"). Default: "TBD — assign during backlog refinement." Supports traceability required by ISO 42001 and NIST AI RMF Govern 1.1.

HTML template for description fields:

```html
<div>
  <h3>RAI Control: {control_name}</h3>
  <p><strong>RAI Principle:</strong> {principle}</p>
  <p><strong>Threat:</strong> {threat_id} - {threat_description}</p>
  <p><strong>Control Surface:</strong> {prevent|detect|respond} - {control_details}</p>
  <p><strong>Evidence:</strong> {evidence_status}</p>
  <p><strong>Suggested Remediation Horizon:</strong> {horizon}</p>
  <h4>Implementation</h4>
  <p>{implementation_details}</p>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
  <blockquote>
  <p><strong>Note</strong> — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.</p>
  <ul><li><input type="checkbox" disabled /> Reviewed and validated by a human reviewer</li></ul>
  </blockquote>
</div>
```

Work item hierarchy maps from the RAI assessment structure:

* Epic: RAI Principle (one per principle with findings).
* Feature: Control Category (Prevent, Detect, Respond per principle).
* User Story: Specific control or mitigation.
* Task: Implementation steps for a user story.
* Bug: Existing RAI areas of concern requiring attention.

Execution follows `ado-update-wit-items.instructions.md`.

### GitHub Issue Template

Assign temporary IDs using the format `{{RAI-TEMP-N}}`, replaced with real issue numbers on creation. This convention is distinct from the Security Planner `{{SEC-TEMP-N}}` format.

Required fields per issue:

* Title: `[RAI-{Principle}] {concise description}`
* Labels: From the RAI Tags table (without `rai:` prefix for GitHub labels).
* Milestone: Linked to assessment phase.
* Body: Markdown-formatted with sections for Context, RAI Principle, Related Threat, Control Surface, Acceptance Criteria.
* Security Cross-Reference: Link to Security Planner issue when overlapping.
* RAI Owner: (Optional) Role accountable for this issue (for example, "ML Engineering Lead"). Default: "TBD — assign during backlog refinement."

Include a YAML metadata block at the top of the issue body:

```yaml
---
rai_principle: {principle}
threat_id: T-RAI-{NNN}
suggested_priority: {Immediate|Near-term|Planned|Backlog}
suggested_horizon: {Pre-Production|Early Operations|Ongoing Governance}
category: {Remediation|Control Implementation|Monitoring Setup|Documentation|Enhancement}
depth_tier: {Basic|Standard|Comprehensive}
security_cross_ref: {WI-SEC-{NNN} or empty}
---
```

Markdown template for issue body:

```markdown
## RAI Control: {control_name}

**RAI Principle:** {principle}
**Threat:** {threat_id} - {threat_description}
**Control Surface:** {prevent|detect|respond} - {control_details}
**Suggested Priority:** {priority_level}
**Suggested Remediation Horizon:** {horizon}

### Implementation

{implementation_details}

### Acceptance Criteria

* [ ] {criterion_1}
* [ ] {criterion_2}

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
```

Execution follows `github-backlog-update.instructions.md`.

## Content Sanitization Protocol

Strip internal tracking paths and sensitive assessment details from work item output before handoff to external systems.

Sanitization rules:

1. Replace `.copilot-tracking/` paths with descriptive text (for example, "RAI plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Remove internal tracking IDs that are not work item IDs.
5. Preserve standards references (responsible AI principles, NIST AI RMF IDs) in all cases.

After generating each work item, scan the output for `.copilot-tracking/`. If found, strip the path and log the sanitization action.

Debug mode: Retain full paths in `.copilot-tracking/rai-plans/{slug}/debug/` output only. Paths never appear in external-facing work items.

## Three-Tier Autonomy Model

Three tiers control how RAI work items reach the target backlog system.

| Tier    | Description                                              | Applies When                                                 |
|---------|----------------------------------------------------------|--------------------------------------------------------------|
| Full    | Agent creates work items without human approval          | Enhancement items (Backlog priority), documentation updates  |
| Partial | Agent drafts work items for human review before creation | Control implementation (Planned–Near-term), monitoring setup |
| Manual  | Agent provides recommendations; human creates items      | Remediation (Immediate–Near-term), tradeoff decisions        |

Ask the user in Phase 6 which tier they prefer. Default to Partial on first use. Store the selected preference in the session state JSON under `userPreferences.autonomyTier`.

## Suggested Priority Derivation

Derive suggested work item priority and autonomy tier from assessment observations and principleTracker data.

| Assessment Observation                                | Suggested Priority | Autonomy Tier | Suggested Horizon  |
|-------------------------------------------------------|--------------------|---------------|--------------------|
| Principle at Foundational maturity with critical gaps | Immediate          | Manual        | Pre-Production     |
| Principle at Foundational maturity                    | Near-term          | Manual        | Pre-Production     |
| Multiple open observations for a principle            | Near-term          | Partial       | Pre-Production     |
| Tradeoff requiring implementation                     | Planned            | Partial       | Early Operations   |
| Control surface gap (Prevent)                         | Near-term          | Partial       | Pre-Production     |
| Control surface gap (Detect)                          | Planned            | Partial       | Early Operations   |
| Control surface gap (Respond)                         | Planned            | Partial       | Early Operations   |
| Documentation gap                                     | Backlog            | Full          | Ongoing Governance |
| Enhancement recommendation                            | Backlog            | Full          | Ongoing Governance |

Within the same priority level, order remediation items before control implementation items. Consider fairness and reliability findings for earlier attention due to direct impact potential.

When multiple observations apply to a single work item, use the highest suggested priority among them.

When work item A depends on work item B, note the dependency in both work item bodies and place B earlier in the handoff sequence.

## Cross-Reference Protocol for Security Planner Interop

RAI work items relate to Security Planner work items when threats overlap across both assessments.

Rules:

* When an RAI threat overlaps with a Security Planner threat (identified by dual `T-{BUCKET}-AI-{NNN}` IDs), the RAI work item includes a cross-reference field.
* Security Planner work items are not duplicated. RAI items extend or complement them instead.
* Cross-reference format: `Security-Ref: WI-SEC-{NNN}` in ADO, `Security: #{NNN}` in GitHub.
* The handoff summary includes a cross-reference table listing all overlapping items.
* Before creating new work items, search for existing Security Planner items with matching threat IDs or control surfaces. Link rather than duplicate.

Cross-reference table template:

| RAI Work Item | Security Work Item | Relationship                    | Notes         |
|---------------|--------------------|---------------------------------|---------------|
| WI-RAI-{NNN}  | WI-SEC-{NNN}       | Extends / Complements / Depends | {description} |

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
## Suggested Review Status: {Ready for stakeholder review / Additional attention suggested / Significant areas need further consideration}

### Work Item Summary

| Category               | Count   | Immediate | Near-term | Planned | Backlog |
|------------------------|---------|-----------|-----------|---------|---------|
| Remediation            | {n}     | {n}       | {n}       | {n}     | {n}     |
| Control Implementation | {n}     | {n}       | {n}       | {n}     | {n}     |
| Monitoring Setup       | {n}     | {n}       | {n}       | {n}     | {n}     |
| Documentation          | {n}     | {n}       | {n}       | {n}     | {n}     |
| Enhancement            | {n}     | {n}       | {n}       | {n}     | {n}     |
| **Total**              | **{n}** | **{n}**   | **{n}**   | **{n}** | **{n}** |

### Suggested Remediation Horizon Breakdown

| Horizon            | Count | Key Items |
|--------------------|-------|-----------|
| Pre-Production     | {n}   | {items}   |
| Early Operations   | {n}   | {items}   |
| Ongoing Governance | {n}   | {items}   |

### Security Planner Cross-References

| RAI Item     | Security Item | Relationship   |
|--------------|---------------|----------------|
| WI-RAI-{NNN} | WI-SEC-{NNN}  | {relationship} |

### Outstanding Tradeoffs

{list of tradeoffs requiring stakeholder decisions}

### Next Steps

{recommended follow-up actions}

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
>
> **Disclaimer** — This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice and does not replace Responsible AI review boards, ethics committees, legal counsel, compliance teams, or other qualified human reviewers. The output consists of suggested actions and considerations to support a user's own internal review and decision‑making. All RAI assessments, sensitive use screenings, security models, and mitigation recommendations generated by this tool must be independently reviewed and validated by appropriate legal and compliance reviewers before use. Outputs from this tool do not constitute legal approval, compliance certification, or regulatory sign‑off.
```

Log all generation decisions (create, update, skip, link) in the handoff summary. Items that could not be generated include the reason for each failure.

## Optional Artifacts

During Phase 6, offer each optional artifact independently. Generate only those the user opts into. Each accepted artifact produces a corresponding "Documentation" category work item for completion.

### Transparency Note Outline

Ask: "Would you like a transparency note outline included in the handoff?"

When accepted, generate a skeleton transparency note appended to the handoff summary:

```markdown
## Transparency Note Outline (Draft)

### System Purpose

{What the system does, target users, and intended deployment context}

### Capabilities

{What the system can do within its designed scope}

### Limitations

{Known boundaries, failure modes, and conditions where accuracy degrades}

### Data Usage

{Training data sources, inference inputs, data retention, and privacy considerations}

### Decision Process

{How the system produces outputs, confidence indicators, and key algorithmic choices}

### Human Oversight

{Human-in-the-loop checkpoints, escalation paths, and override mechanisms}

### Contact and Feedback

{How users report issues, request explanations, or provide input on system behavior}

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
```

Generate a "Documentation" category work item: `[RAI] Complete transparency note from Phase 6 outline`. Assign priority Planned–Backlog and tag `rai:transparency`.

### Monitoring Summary

Ask: "Would you like a consolidated monitoring summary included in the handoff?"

When accepted, auto-populate from "Monitoring Setup" category work items generated during the assessment. This unified view prevents individual monitoring work items from becoming disconnected.

```markdown
## Monitoring Summary

| Work Item    | Metric        | Threshold/Criteria | Alert Mechanism   | Review Cadence |
|--------------|---------------|--------------------|-------------------|----------------|
| WI-RAI-{NNN} | {metric_name} | {threshold}        | {alert_mechanism} | {cadence}      |

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
```

Generate a "Documentation" category work item: `[RAI] Validate and operationalize monitoring summary`. Assign priority Planned and tag `rai:accountability`.

### Artifact Signing

Ask: "Would you like cryptographic signing of all session artifacts?"

When accepted, invoke `npm run rai:sign -- -ProjectSlug {project-slug}` via `execute/runInTerminal`. The script generates a SHA-256 manifest (`artifact-manifest.json`) covering all files in the project directory and optionally signs it with cosign when available. After execution completes, update `state.json` fields `signingRequested` to `true` and `signingManifestPath` to the manifest output path.

If the user also requests cosign signing, append `-IncludeCosign` to the command. Cosign uses keyless signing via Sigstore; it requires `cosign` in PATH and an OIDC identity provider.

Generate a "Documentation" category work item: `[RAI] Verify artifact manifest integrity and configure signing in CI pipeline`. Assign priority Planned-Backlog and tag `rai:accountability`.

## Audience Adaptation

Adjust handoff output formatting based on `userPreferences.audienceProfile`:

* **technical** — Full implementation detail with control specifications, threat IDs, and suggested monitoring thresholds.
* **executive** — High-level summary with business impact, principle maturity overview, and key action items.
* **compliance** — Full detail with regulatory mapping, standards traceability, and audit trail references.
* **mixed** — Balanced format with executive summary followed by technical detail sections.

Default to **technical** when no preference is set. The audience profile affects the RAI Review Summary, work item descriptions, and handoff summary formatting.
