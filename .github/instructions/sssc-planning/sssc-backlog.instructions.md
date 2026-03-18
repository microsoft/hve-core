---
description: "Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 5 — Backlog Generation

Generate actionable work items from the gap analysis in dual format (ADO + GitHub). Each work item maps a supply chain security gap to concrete adoption steps.

## Work Item Template

Each generated work item follows this structure:

```markdown
## [{Priority}] {Title}

**Scorecard Check:** {check_name} | **Risk:** {Critical|High|Medium|Low}
**Effort:** {S|M|L|XL} | **Adoption Type:** {category}
**Prerequisite:** {work_item_id or "None"}

### Description
{What needs to be done and why — include the security benefit}

### Adoption Steps
1. {Concrete step with file path or workflow reference}
2. {Next step}

### Source References
- Workflow: {repo}/path/to/workflow.yml
- Script: {repo}/path/to/script.ps1
- Documentation: {URL or path}

### Acceptance Criteria
- [ ] {Verifiable criterion}
- [ ] {Verifiable criterion}

### ADO Mapping
- Type: {Epic|Feature|User Story|Task}
- Tags: supply-chain, ossf, {scorecard-check}, {adoption-type}

### GitHub Mapping
- Labels: supply-chain, ossf, {scorecard-check}, {adoption-type}
- Milestone: {milestone}
```

## Priority Derivation

Derive work item priority from the Scorecard risk level:

| Risk Level | Priority | Execution Order |
|------------|----------|-----------------|
| Critical   | P1       | First           |
| High       | P2       | Second          |
| Medium     | P3       | Third           |
| Low        | P4       | Fourth          |

Within the same priority level, order items by adoption type (reusable workflow first, new capability last).

## ADO Work Item Format

Assign sequential IDs using the format `WI[NNN]` (for example, WI[001], WI[002]). Order work items by type hierarchy: Epic, Feature, User Story, Task.

Work item hierarchy for supply chain security:

* **Epic**: Supply chain security improvement program (one per assessment)
* **Feature**: Per adoption category (reusable workflow adoption, platform configuration, etc.)
* **User Story**: Per Scorecard check or SLSA improvement step
* **Task**: Individual implementation steps for a user story

HTML template for ADO description fields:

```html
<div>
  <h3>Supply Chain Control: {title}</h3>
  <p><strong>Scorecard Check:</strong> {check_name}</p>
  <p><strong>Risk Level:</strong> {risk_level}</p>
  <p><strong>Adoption Type:</strong> {adoption_type}</p>
  <h4>Adoption Steps</h4>
  <ol>
    <li>{step_1}</li>
    <li>{step_2}</li>
  </ol>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
</div>
```

## GitHub Issue Format

Assign temporary IDs using the format `{{TEMP-N}}`, replaced with real issue numbers on creation.

Include a YAML metadata block at the top of the issue body:

```yaml
---
scorecard_check: {check_name}
risk_level: {Critical|High|Medium|Low}
adoption_type: {category}
effort: {S|M|L|XL}
standards: [{scorecard_check}, {slsa_level}, {badge_criteria}]
---
```

Markdown template for GitHub issue body:

```markdown
## Supply Chain Control: {title}

**Scorecard Check:** {check_name}
**Risk Level:** {risk_level}
**Adoption Type:** {adoption_type}

### Adoption Steps

1. {step_1}
2. {step_2}

### Source References

- Workflow: `{repo}/path/to/workflow.yml`
- Script: `{repo}/path/to/script.ps1`

### Acceptance Criteria

- [ ] {criterion_1}
- [ ] {criterion_2}
```

## Content Sanitization

Strip internal tracking paths from work item output before handoff:

1. Replace `.copilot-tracking/` paths with descriptive text (e.g., "SSSC plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Preserve standards references (Scorecard check names, SLSA levels, Badge criteria) in all cases.

## Three-Tier Autonomy Model

Three tiers control how work items reach the target backlog system:

* **Full autonomy**: Create work items directly via backlog manager. User pre-approves batch creation.
* **Partial autonomy** (default): Present each batch of 5-10 items for user review before creation. User can modify, skip, or approve individual items.
* **Manual**: Produce output file without invoking backlog tools. User imports items independently.

Ask the user which tier they prefer. Default to partial autonomy on first use.

## Output

Write the neutral intermediate backlog to `.copilot-tracking/sssc-plans/{project-slug}/sssc-backlog.md`.

Update `state.json`:
* Set `phases.5-backlog.status` to `✅`
* Add `sssc-backlog.md` to `phases.5-backlog.artifacts`
* Advance `currentPhase` to `6`
