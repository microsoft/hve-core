---
name: backlog-templates
description: "Shared work-item templates and conventions for ADO and GitHub backlog handoff across the RAI, Security, SSSC, Accessibility, and Privacy planners"
license: MIT
user-invocable: true
compatibility: "Hosts: vscode, github-coding-agent. Reference-only templates; the consuming planner supplies tracker access."
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0.0"
  last_updated: "2026-08-09"
---

# Backlog Templates

Shared reference for ADO and GitHub work-item template generation, content sanitization, autonomy-tier vocabulary, disclaimer-block placement, and work-item ID conventions used by every planner that emits a backlog handoff.

## Overview

Planners that emit Phase-final backlog work items all need the same dual-format template skeletons, the same content sanitization rules, and the same convention for where to assign work-item IDs. This skill consolidates those shared pieces so each planner instruction file can reference one source instead of restating them.

Callers:

* RAI Planner (`rai-planner` skill `references/backlog-handoff.md`)
* Security Planner (`Security Planner` agent; security-specific handoff details in the `security-planning` skill's `references/backlog-formats.md`)
* SSSC Planner (`SSSC Planner` agent, governed by `sssc-planner.instructions.md`)
* Accessibility Planner (`accessibility/accessibility` skill `references/phases/backlog-handoff.md`)
* Privacy Planner (`Privacy Planner` agent, governed by the `privacy-standards` skill's `references/privacy-identity.md`)

What stays per-planner (NOT in this skill):

* Domain-specific HTML and markdown body content (NIST characteristic vs. STRIDE category vs. WCAG criterion vs. Scorecard check).
* Severity-to-priority and severity-to-tier mapping tables — different input vocabularies per planner.
* Work-item hierarchy mapping (Epic / Feature / Story / Task / Bug).
* The accessibility disclaimer text (pinned to `accessibility-identity.instructions.md` by the L7 disclaimer lever).

## ADO Work Item Template

ADO description fields use HTML and embed a planner-specific field block plus a verbatim disclaimer blockquote. Parameterize the skeleton with the planner ID prefix and per-planner field set.

Skeleton:

```html
<div>
  <h3>{Domain} Control: {control_name}</h3>
  <!-- planner-specific field block goes here -->
  <h4>Implementation</h4>
  <p>{implementation_details}</p>
  <h4>Acceptance Criteria</h4>
  <ul>
    <li>{criterion_1}</li>
    <li>{criterion_2}</li>
  </ul>
  <blockquote>
  <p><strong>Note</strong> — The author created this content with assistance from AI. All outputs should be reviewed and validated by a qualified {role} reviewer before use.</p>
  <ul><li><input type="checkbox" disabled /> Reviewed and validated by a qualified {role} reviewer</li></ul>
  </blockquote>
</div>
```

Fill the field block with the active planner's handoff fields. Keep the implementation, acceptance criteria, and human-review block in every rendered item.

## GitHub Issue Template

GitHub issues use a YAML metadata header followed by a markdown body. Temporary IDs of the form `{{<PREFIX>-TEMP-N}}` are replaced with real issue numbers on creation.

Canonical YAML metadata header:

```yaml
---
id: "{{<PREFIX>-TEMP-N}}"
planner: {rai|security|sssc|accessibility|privacy}
priority: {Critical|High|Medium|Low}
standards: ["{standard_id_1}", "{standard_id_2}"]
evidence_refs: ["{evidence_id_1}"]
cross_planner_refs: ["{wi_id_1}"]
---
```

Add the active planner's handoff fields to the same YAML header. Keep the shared keys, including `standards`, rather than replacing the header with a domain-specific one.

Markdown body skeleton:

```markdown
## {Domain} Control: {control_name}

{planner_specific_summary_lines}

### Implementation

{implementation_details}

### Acceptance Criteria

* [ ] {criterion_1}
* [ ] {criterion_2}
```

The disclaimer blockquote from the ADO template is reused verbatim at the end of the markdown body for parity across formats.

## Per-Platform Field Mappings

### ADO

| Field              | Purpose                                  | Required | Per-planner override                                                  |
|--------------------|------------------------------------------|----------|-----------------------------------------------------------------------|
| Title              | Bracket-tag prefix + concise description | Yes      | Title prefix differs (`[Security]`, `[RAI]`, `[A11Y][{framework}]`).  |
| Description        | HTML body per the ADO template skeleton  | Yes      | Field block contents differ.                                          |
| AcceptanceCriteria | Verifiable checks                        | Yes      | Accessibility adds assistive-technology validation when required.     |
| Tags               | Domain tags + applicable property tags   | Yes      | Tag vocabulary differs (CIA triad, RAI principles, WCAG level, etc.). |
| Priority           | Derived from risk or severity            | Yes      | Mapping table per planner.                                            |
| Iteration          | Iteration path supplied by user          | Optional | Empty defaults to backlog refinement.                                 |
| AreaPath           | Project area supplied by user            | Yes      | Required for ADO emission across all planners.                        |
| Parent             | Epic or Feature parent reference         | Optional | Set when seed maps into the planner-specific hierarchy.               |

### GitHub

| Field     | Purpose                                  | Required | Per-planner override                                                       |
|-----------|------------------------------------------|----------|----------------------------------------------------------------------------|
| title     | Bracket-tag prefix + concise description | Yes      | Title prefix differs (matches ADO Title convention).                       |
| body      | Markdown body per the GitHub template    | Yes      | YAML header augmentation and body summary lines differ.                    |
| labels    | Lowercased domain + property labels      | Yes      | Label vocabulary differs; strip `prefix:` form when colons are disallowed. |
| milestone | Planning milestone if one exists         | Optional | Each planner may target a domain milestone; otherwise leave unset.         |
| assignees | Owner role suggestion                    | Optional | Default to `TBD — assign during backlog refinement.`                       |

## Content Sanitization Protocol

Apply these five rules to every work item before emission to ADO or GitHub. Sanitization runs after rendering and before MCP-driven creation.

1. Replace any occurrence of `.copilot-tracking/` with a descriptive phrase such as `{domain} plan artifacts` (for example, `security plan artifacts`, `accessibility plan artifacts`).
2. Replace absolute file system paths with workspace-relative references.
3. Remove embedded state JSON or pointers to state JSON files; standards references inside state remain after extraction.
4. Preserve standards identifiers verbatim — OWASP A{NN}, NIST AI RMF subcategory IDs, CIS control numbers, WCAG criterion IDs (1.1.1, 1.3.5), Scorecard check names, SLSA level strings, Section 508 chapter IDs, EN 301 549 clause numbers.
5. Append a `state.noticeLog` entry per sanitized artifact with `noticeType: "sanitization"`, `source: "<planner-handoff-instruction-path>"`, the artifact path, and the sanitization rules that fired.

Debug-mode output retained under `.copilot-tracking/<planner-domain>/{slug}/debug/` keeps full paths and never reaches external-facing work items.

## Autonomy-Tier Enumeration

Three tiers control how rendered work items reach the target backlog system. The canonical vocabulary is `manual` / `supervised` / `autonomous`. A fourth value, `coached`, names a capability that emits no work items at all.

* `manual` — The planner emits a backlog handoff file under `.copilot-tracking/`. The user creates each work item in the target system independently. No MCP tool invocations.
* `supervised` — The planner drafts rendered work items in `.copilot-tracking/`, presents each batch of 5 to 10 items for user review, and only invokes MCP creation tools on user approval. This is the default tier.
* `autonomous` — The planner invokes MCP creation tools directly on the sanitized batch after the user pre-approves the run. All items are created in a single operation.
* `coached` — The capability produces a conversation and its own output rather than backlog work items. It renders nothing, invokes no creation tool, and reaches no backlog system, so no tier applies to it. No backlog planner selects this value and no planner state schema accepts it; it exists so a coaching-shaped capability has a name in this vocabulary instead of an undocumented absence. Coaching capabilities record no autonomy field in their own state.

Cross-reference mapping for planners that use divergent vocabularies. Each planner persists the selected value in its session state under `userPreferences.autonomyTier` using its own vocabulary; this table is the single source of truth for cross-planner equivalence.

| Canonical (this skill) | Accessibility (seed schema) | Security       | RAI            | SSSC              | Privacy           |
|------------------------|-----------------------------|----------------|----------------|-------------------|-------------------|
| autonomous             | autonomous                  | Full           | Full           | Full              | Full              |
| supervised (default)   | supervised                  | Partial        | Partial        | Partial (default) | Partial (default) |
| manual                 | manual                      | Manual         | Manual         | Guided            | Manual            |
| coached                | not applicable              | not applicable | not applicable | not applicable    | not applicable    |

Notes:

* Accessibility's vocabulary already matches the canonical names; the seed schema `autonomyTier` field is the persisted form.
* SSSC uses `Guided` as the lowest-autonomy tier label. Treat `Guided` and `Manual` as equivalent across planners for cross-reference and reporting.
* `coached` is not a tier and has no planner equivalent. It is not selectable, not persisted in any planner state schema, and carries no severity-to-tier routing. A planner that encounters it should treat it as out of range.
* Severity-to-tier mapping (which severity routes to which tier) stays in each planner's handoff instruction file.

## Disclaimer-Block Placement Convention

Every backlog handoff artifact (handoff summary, ADO output file, GitHub output file) emits a disclaimer block verbatim at the end of the file. The block is the source of authority that the planner emission was AI-assisted and requires qualified human review before execution.

Use only the emitting planner's notice:

* RAI: `RAI Planning` in `rai-disclaimers`.
* Security or SSSC: `Security Planning` or `SSSC Planning`, respectively, in `security-disclaimers`.
* Privacy: `Privacy Planning` in `privacy-disclaimers`.
* Accessibility: `Disclaimer Handling` in `accessibility-identity.instructions.md`. The L7 disclaimer lever pins the accessibility planning notice to that file.

Placement rules:

* Emit the block at the end of every emitted artifact, not at the start.
* Set `state.disclaimerShownAt` to the ISO 8601 timestamp at first emission within a session.
* Append a `state.noticeLog` entry per emission with `noticeType: "handoff-disclaimer"`, `source: "<authoritative-instruction-path>"`, and the artifact path.
* For ADO emission, the per-work-item HTML blockquote inside the description field is a separate review affordance and does not replace the file-level disclaimer block.

This skill intentionally does not reproduce the disclaimer text. Read it from the authoritative source above at emission time so updates to the canonical text propagate without skill edits.

## Work Item ID Naming Convention

Work items use the format `WI-{PREFIX}-{NNN}` where the prefix identifies the originating planner and `{NNN}` is a zero-padded monotonic sequence scoped to the plan slug.

| Planner       | ADO prefix | GitHub temp ID    |
|---------------|------------|-------------------|
| RAI           | `WI-RAI-`  | `{{RAI-TEMP-N}}`  |
| Security      | `WI-SEC-`  | `{{SEC-TEMP-N}}`  |
| SSSC          | `WI-SSSC-` | `{{SSSC-TEMP-N}}` |
| Accessibility | `WI-A11Y-` | `{{A11Y-TEMP-N}}` |
| Privacy       | `WI-PRIV-` | `{{PRIV-TEMP-N}}` |

Rules:

* Distinct prefixes prevent ID collision when multiple planners produce a backlog against the same project.
* Sequence is monotonic per plan slug. Do not reuse identifiers across plans or sessions.
* GitHub temporary IDs are replaced with real issue numbers at creation time; preserve the temporary ID in `state.noticeLog` for traceability.
* Cross-planner references use the target planner's full ID, prefixed with the relationship type: `Accessibility-Ref: WI-A11Y-{NNN}`, `Security-Ref: WI-SEC-{NNN}`, `RAI-Ref: WI-RAI-{NNN}`, `SSSC-Ref: WI-SSSC-{NNN}`, `Privacy-Ref: WI-PRIV-{NNN}`.

Internal reference IDs (`T-{BUCKET}-{NNN}` for threats, `EV-A11Y-{NNN}` for evidence, `SEED-A11Y-{NNN}` for seeds, `TO-A11Y-{NNN}` for tradeoffs) remain scoped to their owning planner and are out of scope for this skill.
