---
description: "Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Backlog Handoff

Instructions for generating formatted work items from security planning security models. Applies to both Azure DevOps (ADO) and GitHub issue trackers.

## Handoff Overview

Generate formatted work items from security model mitigations and standards gaps identified during security planning.

* Context: Phase 5 of the security planning workflow.
* Input: Completed threat tables from Phase 4, including mitigations and standards references.
* Output: Formatted work items targeting ADO, GitHub, or both, based on user preference.
* Ask which backlog system(s) to target before generating. Both formats can be generated simultaneously.

## ADO Work Item Template

Assign sequential IDs within the security plan using the format `WI[NNN]` (for example, WI[001], WI[002]). Order work items by type hierarchy: Epic, Feature, User Story, Task, Bug.

Required fields per work item:

* Title: `[Security] {bucket}: {mitigation_summary}`
* Description: HTML-formatted with threat reference, mitigation details, and standards references.
* Acceptance criteria: Verifiable security control implementation steps.
* Tags: `Security`, `{bucket_name}`, `{STRIDE_category}`, plus applicable CIA triad and privacy tags (`cia:confidentiality`, `cia:integrity`, `cia:availability`, `cia:privacy`). Assign tags based on which information security properties the threat affects.
* Priority: Derived from risk level (see Work Item Prioritization).

Use the `format` parameter to control output: HTML for ADO API operations, markdown for display.

HTML template for description fields:

```html
<div>
  <h3>Security Control: {mitigation_name}</h3>
  <p><strong>Threat:</strong> {threat_id} - {threat_description}</p>
  <p><strong>Bucket:</strong> {bucket_name}</p>
  <p><strong>Standards:</strong> {owasp_ref}, {nist_ref}</p>
  <h4>Implementation</h4>
  <p>{implementation_details}</p>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
</div>
```

Work item hierarchy maps from the security plan structure:

* Epic: Security plan implementation (one per plan).
* Feature: Per operational bucket (one per bucket with findings).
* User Story: Per security concern or control.
* Task: Implementation steps for a user story.
* Bug: Existing vulnerabilities requiring remediation.

Five MCP tool categories support ADO operations: work item creation, work item update, work item query, attachment upload, and link management. Execution follows `ado-update-wit-items.instructions.md`.

## GitHub Issue Template

Assign temporary IDs using the format `{{TEMP-N}}`, replaced with real issue numbers on creation. Order operations by type: create, update, comment, label, close.

Required fields per issue:

* Title: `[Security] {bucket}: {mitigation_summary}`
* Body: Markdown-formatted with threat reference, mitigation details, and standards references.
* Labels: `security`, `{bucket_name}`, `{priority_level}`, plus applicable CIA triad and privacy labels (`cia:confidentiality`, `cia:integrity`, `cia:availability`, `cia:privacy`). Assign labels based on which information security properties the threat affects.
* Milestone: Security planning milestone, if one exists in the repository.

Include a YAML metadata block at the top of the issue body:

```yaml
---
threat_id: T-{bucket}-{NNN}
stride_category: {category}
risk_level: {Critical|High|Medium|Low}
bucket: {bucket_name}
standards: [OWASP A{NN}, NIST {XX}]
---
```

Markdown template for issue body:

```markdown
## Security Control: {mitigation_name}

**Threat:** {threat_id} - {threat_description}
**Bucket:** {bucket_name}
**Standards:** {owasp_ref}, {nist_ref}
**Risk Level:** {risk_level}

### Implementation

{implementation_details}

### Acceptance Criteria

* [ ] {criterion_1}
* [ ] {criterion_2}
```

Execution follows `github-backlog-update.instructions.md`.

## Content Sanitization Protocol

Strip all internal tracking paths from work item output before handoff to external systems.

Sanitization rules:

1. Replace `.copilot-tracking/` paths with descriptive text (for example, "security plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Remove internal tracking IDs that are not work item IDs.
5. Preserve standards references (OWASP, NIST, CIS IDs) in all cases.

After generating each work item, scan the output for `.copilot-tracking/`. If found, strip the path and log the sanitization action.

Debug mode: Retain full paths in `.copilot-tracking/security-plans/{slug}/debug/` output only. Paths never appear in external-facing work items.

## Three-Tier Autonomy Model

Three tiers control how work items reach the target backlog system.

* Full autonomy: Create work items directly via MCP tools. The user pre-approves batch creation, and all items are created in a single operation.
* Partial autonomy (default): Present each batch of 5 to 10 items for user review before creation. The user can modify, skip, or approve individual items.
* Manual: Produce an output file at `.copilot-tracking/security-plans/{slug}/backlog-handoff.md` without invoking MCP tools. The user imports items into the backlog system independently.

Ask the user in Phase 5 which tier they prefer. Default to partial autonomy on first use. Store the selected preference in the session state JSON under `userPreferences.autonomyTier`.

## Work Item Prioritization

Derive priority from the threat risk level assigned during Phase 4.

| Risk Level | Priority | Execution Order |
|------------|----------|-----------------|
| Critical   | P1       | First           |
| High       | P2       | Second          |
| Medium     | P3       | Third           |
| Low        | P4       | Fourth          |

Within the same priority level, order standards-mapped items before unmapped items. Favor identity/auth and data buckets over other buckets at equal priority.

When mitigation A depends on mitigation B, note the dependency in both work item bodies and place B earlier in the handoff sequence.

## RAI Work Item Categories

> [!NOTE]
> The following categories apply only when `raiEnabled` is true. They extend the standard work item hierarchy with RAI-specific concerns.

Five additional work item categories apply when the security plan includes AI/ML components:

1. RAI Assessment — items related to RAI evaluation and scoring
2. RAI Control Implementation — control surface implementations (Prevent, Detect, Respond)
3. RAI Monitoring — ongoing monitoring and measurement items
4. RAI Documentation — transparency artifacts, model cards, impact assessments
5. RAI Training — team training and awareness items

Each RAI work item includes three additional fields beyond the standard template:

* `rai-principle`: Which of the six Microsoft RAI principles the item addresses (fairness, reliability and safety, privacy and security, inclusiveness, transparency, accountability).
* `rai-phase`: Which RAI Planner phase generated the item.
* `rai-priority`: RAI-specific priority based on sensitive uses screening.

These fields appear in the YAML metadata block for GitHub issues and as custom fields in ADO work items. They supplement (not replace) the standard priority, tags, and CIA fields.

## Work Item Reference Detection

Before creating new work items during backlog generation, check for existing items to avoid duplication.

Detection steps:

1. Search for existing work items with matching threat IDs (`T-{BUCKET}-{NNN}`, `T-{BUCKET}-AI-{NNN}`).
2. Search for existing work items with matching OWASP or NIST references.
3. When matches are found, update existing items rather than creating duplicates. Add new mitigation details, standards references, or acceptance criteria to the existing item.
4. Link related items across security and RAI plans when both address the same component or threat.

Log all match decisions (create, update, skip, link) in the handoff summary.

## Handoff Summary Format

After generating all work items, produce a summary covering:

* Total items by type (Epic, Feature, Story, Task, Bug for ADO; Issue for GitHub).
* Items by operational bucket.
* Items by risk level.
* Items by STRIDE category.
* Items that could not be generated, with the reason for each failure.
