---
description: "Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates"
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

## Dual-Format Backlog Templates

Both ADO and GitHub formats follow the canonical templates, field blocks, augmentation keys, title prefix, and temporary-ID conventions defined in `.github/skills/shared/backlog-templates/SKILL.md`. Read the Security entries under "ADO Work Item Template", "GitHub Issue Template", and "Work Item ID Naming Convention" at emission time. Execution follows `ado-update-wit-items.instructions.md` for ADO and `github-backlog-update.instructions.md` for GitHub.

Work item hierarchy maps from the security plan structure:

* Epic: Security plan implementation (one per plan).
* Feature: Per operational bucket (one per bucket with findings).
* User Story: Per security concern or control.
* Task: Implementation steps for a user story.
* Bug: Existing vulnerabilities requiring remediation.
## Content Sanitization Protocol

Content sanitization follows the five-rule protocol in `.github/skills/shared/backlog-templates/SKILL.md` under "Content Sanitization Protocol". Security-specific standards identifiers that must be preserved verbatim per rule 4: OWASP control IDs (for example, `A01:2025`), NIST CSF subcategory IDs (for example, `PR.AC-1`), CIS control numbers, threat IDs from the security model. Debug-mode output remains under `.copilot-tracking/security-plans/{slug}/debug/`.

## Three-Tier Autonomy Model

The three-tier autonomy model is defined canonically in `.github/skills/shared/backlog-templates/SKILL.md` under "Autonomy-Tier Enumeration". Security uses the divergent vocabulary `Full` / `Partial` / `Manual` (see the cross-reference table in the skill). Default tier on first use is `Partial`. Persist the selected tier in session state under `userPreferences.autonomyTier`. Ask the user in Phase 5 which tier they prefer.

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
* `rai-priority`: RAI-specific priority based on impact assessment.

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

> **CAUTION:** AI-generated work items require professional review before execution. Treat the backlog as a starting draft, not a final plan.
