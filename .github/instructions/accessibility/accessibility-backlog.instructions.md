---
description: 'Phase 5 dual-format work item generation with templates, priority derivation, and VPAT skeleton emission for Accessibility Planner.'
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Phase 5 — Backlog Generation

Generate actionable work items from the gap analysis in dual format (ADO + GitHub). Each work item maps an accessibility gap to concrete remediation steps. When in-scope regulatory jurisdictions are active, also emit a populated VPAT skeleton alongside the backlog.

Attach the Accessibility Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every backlog artifact and VPAT skeleton written by this phase.

Framework references in work items (criterion IDs, success-criterion text, conformance level, evidence hints) must be sourced from the per-criterion YAML under `state.frameworks[i].skillPath`. Do not inline framework-specific success-criterion tables in this instruction file. Gap inputs and priority values are produced by [`#file:./accessibility-gap-analysis.instructions.md`](./accessibility-gap-analysis.instructions.md).

## Exclusion Filter

Before generating any work items, filter the gap-analysis input against `state.frameworks[]`:

1. Skip every gap whose source framework has `disabled === true`. These frameworks were never loaded in Phase 3 and produce no gaps in a well-formed pipeline; the filter is a defense-in-depth check.
2. Skip every gap whose `criterionId` appears in the parent framework's `suppressedCriteria[].id`.

Excluded gaps must not produce work items, must not appear in priority counts, and must not be referenced from any other work item's `Source References`. The Phase 6 handoff renders the audit trail of what was excluded; this phase is silent about exclusions in the backlog itself.

## Work Item Template

Each generated work item follows this structure:

```markdown
## [{Priority}] {Title}

**Success Criterion:** {criterion_id} {criterion_name} ({level}) | **Priority:** {P1|P2|P3|P4}
**Effort:** {S|M|L|XL} | **Remediation Type:** {category}
**Surface Scope:** {component or route or template ids}
**Prerequisite:** {work_item_id or "None"}

### Description
{What needs to change and why — include the user-impact benefit and the disability populations affected}

### Acceptance Criteria
- [ ] {Verifiable criterion derived from the failing success-criterion text}
- [ ] {Verifiable criterion}

### Remediation Steps
1. {Concrete step with file path or component reference}
2. {Next step}

### Source References
- Framework: {framework-id} / Criterion: {criterion-id}
- Surface: {component, route, or template}
<!-- Each evidence entry is the canonical Evidence row defined in #file:../shared/evidence-citation.instructions.md -->
- Evidence: `<path>` (Lines <start>-<end>) — <rationale>

### ADO Mapping
- Type: {Epic|Feature|User Story|Task}
- Tags: accessibility, {framework-id}, {criterion-id}, {remediation-type}

### GitHub Mapping
- Labels: accessibility, {framework-id}, {criterion-id}, {remediation-type}
- Milestone: {milestone}
```

## Priority Derivation

Priority derivation across all planners follows the shared rules in [`#file:../shared/planner-priority-rules.instructions.md`](../shared/planner-priority-rules.instructions.md). Never derive priority from numerical scores.

Read the priority for each work item from `state.gapAnalysis[].priority`, set during Phase 4 gap analysis. Do not recompute priority in this phase; surface the derivation here for reviewer transparency only.

Phase 4 derives `priority` using the following formula, in evaluation order (first match wins):

| Condition (evaluated in order)                                                 | Priority | Execution Order |
|--------------------------------------------------------------------------------|----------|-----------------|
| Conformance level A and gap state `absent`                                     | P1       | First           |
| Level A and gap state `partial`, OR level AA and gap state `absent`            | P2       | Second          |
| Level AA and gap state `partial`, OR level AAA and gap state `absent`          | P3       | Third           |
| Level AAA and gap state `partial`, OR cognitive-overlay or AAA enhancement gap | P4       | Fourth          |

Within the same priority level, order items first by surface scope severity (public > regulated > internal > kiosk), then by remediation type (content fix first, design change next, platform capability last).

## ADO Work Item Format

Assign sequential IDs using the format `WI-A11Y-{NNN}` (for example, WI-A11Y-001, WI-A11Y-002). This convention distinguishes Accessibility Planner work items from Security Planner items (`WI-SEC-{NNN}`) and SSSC items (`WI-SSSC-{NNN}`). Order work items by type hierarchy: Epic, Feature, User Story, Task.

Work item hierarchy for accessibility remediation:

* **Epic**: Accessibility conformance program (one per assessment).
* **Feature**: Per remediation category (semantic markup, focus management, color and contrast, alternative text, captioning, cognitive accommodations).
* **User Story**: Per success criterion or capability-inventory entry.
* **Task**: Individual implementation steps for a user story.

HTML template for ADO description fields:

```html
<div>
  <h3>Accessibility Criterion: {title}</h3>
  <p><strong>Success Criterion:</strong> {criterion_id} {criterion_name}</p>
  <p><strong>Conformance Level:</strong> {A|AA|AAA}</p>
  <p><strong>Priority:</strong> {priority}</p>
  <p><strong>Remediation Type:</strong> {remediation_type}</p>
  <p><strong>Surface Scope:</strong> {scope}</p>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
  <h4>Remediation Steps</h4>
  <ol>
    <li>{step_1}</li>
    <li>{step_2}</li>
  </ol>
</div>
```

## GitHub Issue Format

Assign temporary IDs using the format `{{A11Y-TEMP-N}}`, replaced with real issue numbers on creation.

Include a YAML metadata block at the top of the issue body:

```yaml
---
framework_id: {framework_id}
criterion_id: {criterion_id}
conformance_level: {A|AA|AAA}
priority: {P1|P2|P3|P4}
remediation_type: {category}
effort: {S|M|L|XL}
surface_scope: [{component_or_route_ids}]
standards: [{framework_id}, {criterion_id}]
---
```

Markdown template for GitHub issue body:

```markdown
## Accessibility Criterion: {title}

**Success Criterion:** {criterion_id} {criterion_name} ({level})
**Priority:** {priority}
**Remediation Type:** {remediation_type}
**Surface Scope:** {scope}

### Acceptance Criteria

- [ ] {criterion_1}
- [ ] {criterion_2}

### Remediation Steps

1. {step_1}
2. {step_2}

### Source References

- Framework: `{framework_id}` / Criterion: `{criterion_id}`
- Surface: `{component_or_route}`
<!-- Each evidence entry is the canonical Evidence row defined in #file:../shared/evidence-citation.instructions.md -->
- Evidence: `<path>` (Lines <start>-<end>) — <rationale>
```

## VPAT Skeleton Extension

When any of `Section508`, `EN301549`, or `EAA` appears in `state.jurisdictions[]`, emit a `vpat-skeleton.md` artifact alongside the backlog. When none of these jurisdictions are active, skip this section entirely; do not create the file.

### Scoping

Determine the VPAT 2.5 edition from active jurisdictions:

| Active jurisdictions                                                              | VPAT 2.5 edition |
|-----------------------------------------------------------------------------------|------------------|
| Only `Section508`                                                                 | VPAT 2.5 508     |
| Only `EN301549` or only `EAA` (or both, without Section 508)                      | VPAT 2.5 EU      |
| Any combination that includes `Section508` plus one or more of `EN301549` / `EAA` | VPAT 2.5 INT     |

### Required sections

The skeleton renders the standard VPAT 2.5 table of contents matching the selected edition:

1. Product information and evaluation methods.
2. Applicable standards and guidelines (one row per active jurisdiction with its referenced standard version).
3. Terms (Supports, Partially Supports, Does Not Support, Not Applicable, Not Evaluated).
4. WCAG 2.x report tables (Level A, Level AA, and Level AAA when the assessment depth tier includes AAA).
5. Section 508 Revised 508 Standards report (Chapter 3 functional performance criteria, Chapters 4-7 technical requirements) when Section 508 is active.
6. EN 301 549 report (Chapters 4 functional performance, 5 generic, 9 web, 10 documents, 11 software, 12 documentation, 13 ICT with two-way voice) when EN 301 549 or EAA is active.

### Per-criterion row pre-fill

For each entry in `state.gapAnalysis[]`, pre-fill the corresponding VPAT report row from gap fields. Map gap state to the VPAT conformance verdict:

| `state.gapAnalysis[].state` | VPAT verdict       |
|-----------------------------|--------------------|
| `present`                   | Supports           |
| `partial`                   | Partially Supports |
| `absent`                    | Does Not Support   |
| `not-applicable`            | Not Applicable     |
| `not-evaluated` (or unset)  | Not Evaluated      |

The "Remarks and Explanations" cell is pre-filled with `gap.description` followed by `Effort: {S|M|L|XL}` on a new line. Leave criterion rows that have no matching gap entry blank with verdict `Not Evaluated`.

### Mandatory disclaimer

Every emitted `vpat-skeleton.md` opens with the following disclaimer beneath the shared Accessibility Planning disclaimer block:

> This VPAT skeleton is a planning artifact generated from automated gap analysis. It is not a certified Voluntary Product Accessibility Template. Before submitting to a procurement officer, customer, or regulator, the skeleton must be reviewed and certified by a qualified accessibility professional with verifiable VPAT authoring credentials. The verdicts pre-filled from gap analysis reflect modeled conformance only and require independent assistive-technology testing to confirm.

### State target

After emission, set `state.backlog.vpatSkeleton`:

```json
{
  "path": ".copilot-tracking/accessibility-plans/{project-slug}/vpat-skeleton.md",
  "edition": "INT|EU|508",
  "jurisdictionsCovered": ["Section508", "EN301549", "EAA"]
}
```

## Content Sanitization

Strip internal tracking paths from work item output before handoff:

1. Replace `.copilot-tracking/` paths with descriptive text (e.g., "Accessibility plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Preserve standards references (framework IDs, success criterion IDs and names, conformance levels) in all cases.

## Three-Tier Autonomy Model

Three tiers control how work items reach the target backlog system:

* **Full autonomy**: Create work items directly via backlog manager. User pre-approves batch creation.
* **Partial autonomy** (default): Present each batch of 5-10 items for user review before creation. User can modify, skip, or approve individual items.
* **Manual**: Produce output file without invoking backlog tools. User imports items independently.

Ask the user which tier they prefer. Default to partial autonomy on first use.

## Output

Write the neutral intermediate backlog to `.copilot-tracking/accessibility-plans/{project-slug}/accessibility-backlog.md`. When the VPAT skeleton extension fires, write `.copilot-tracking/accessibility-plans/{project-slug}/vpat-skeleton.md` in the same folder.

Update `state.json`:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Set `state.backlog.ado` to the ADO-flavored backlog path and `state.backlog.github` to the GitHub-flavored backlog path.
* Set `state.backlog.vpatSkeleton` only when a VPAT skeleton was emitted; omit the key otherwise.
* Set `phase` to `review-and-handoff` once the user confirms the backlog draft.
