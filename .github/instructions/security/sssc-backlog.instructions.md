---
description: "Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 5 — Backlog Generation

Generate actionable work items from the gap analysis in dual format (ADO + GitHub). Each work item maps a supply chain security gap to concrete adoption steps.

## Dual-Format Backlog Templates

Both ADO and GitHub formats follow the canonical templates, field blocks, augmentation keys, and temporary-ID conventions defined in `.github/skills/shared/backlog-templates/SKILL.md`. Read the SSSC entries under "ADO Work Item Template", "GitHub Issue Template", and "Work Item ID Naming Convention" at emission time. The markdown body skeleton in the skill is reused verbatim; SSSC fills `{planner_specific_summary_lines}` with the Scorecard Check, Risk Level, and Adoption Type one-liners.

Work item hierarchy for supply chain security:

* **Epic**: Supply chain security improvement program (one per assessment)
* **Feature**: Per adoption category (reusable workflow adoption, platform configuration, etc.)
* **User Story**: Per Scorecard check or SLSA improvement step
* **Task**: Individual implementation steps for a user story

## Priority Derivation

Derive work item priority from the Scorecard risk level:

| Risk Level | Priority | Execution Order |
|------------|----------|-----------------|
| Critical   | P1       | First           |
| High       | P2       | Second          |
| Medium     | P3       | Third           |
| Low        | P4       | Fourth          |

Within the same priority level, order items by adoption type (reusable workflow first, new capability last).

## Content Sanitization

Content sanitization follows the five-rule protocol in `.github/skills/shared/backlog-templates/SKILL.md` under "Content Sanitization Protocol". SSSC-specific standards identifiers that must be preserved verbatim per rule 4: Scorecard check names (Branch-Protection, Code-Review, etc.), SLSA level strings (v1.0 L1-L4), and OpenSSF Best Practices Badge criteria IDs.

## Three-Tier Autonomy Model

The three-tier autonomy model is defined canonically in `.github/skills/shared/backlog-templates/SKILL.md` under "Autonomy-Tier Enumeration". SSSC uses the divergent vocabulary `Full` / `Partial` / `Guided` (the cross-reference table in the skill maps `Guided` to the canonical `manual` tier). Default tier on first use is `Partial`. Persist the selected tier in session state under `userPreferences.autonomyTier`.

## Output

Write the neutral intermediate backlog to `.copilot-tracking/sssc-plans/{project-slug}/sssc-backlog.md`.

Update `state.json`:
* Set `phases.5-backlog.status` to `✅`
* Add `sssc-backlog.md` to `phases.5-backlog.artifacts`
* Advance `currentPhase` to `6`

> **CAUTION:** AI-generated work items require professional review before execution. Treat the backlog as a starting draft, not a final plan.

> **Note** — The author created this content with assistance from AI. All outputs should be reviewed and validated by a qualified human reviewer before use.
> - [ ] Reviewed and validated by a qualified human reviewer
