---
description: Phase 5 accessibility impact assessment taxonomy, evidence register, tradeoff log, and seed work-item schemas
---

# Accessibility Impact Assessment

Phase 5 (`impact-evidence`) translates the framework selections, control mappings, and risk tier captured in Phases 1-4 into a structured evidence register, a tradeoff log, and a list of seed work-items ready for the Phase 6 backlog handoff. This file defines the taxonomy, schemas, and rules that govern those activities so downstream agents (Security Planner, SSSC Planner, and RAI Planner) can consume the outputs without reshaping them.

## Phase Purpose and Inputs

Phase 5 consumes:

* `project` block and `riskClassification.screeningSignals` from Phase 1 (Discovery)
* `frameworkSelections` from Phase 2 (Framework Selection), including the atomic disabled bundle for excluded frameworks
* `controlMappings` from Phase 3 (Standards Mapping), with every in-scope control carrying a `status` of `pending`, `covered`, `partial`, `gap`, or `not-applicable`
* `riskClassification.tier`, `planRiskAssessment.tradeoffs` seeds, and any `escalations` raised in Phase 4 (Plan Risk Assessment)

Phase 5 produces three artifacts written into `.copilot-tracking/accessibility/{project-slug}/`:

* `evidenceRegister` — the catalog of every artifact that demonstrates a control is met, partially met, or absent
* `tradeoffLog` — a record of accessibility decisions that traded against performance, cost, schedule, or other non-accessibility concerns
* `workItemSeeds` — pre-shaped seed records that the Phase 6 backlog handoff (`references/backlog-handoff.md`) renders into ADO or GitHub work items without further transformation

The planner does not perform criterion-level adjudication during Phase 5; framework SKILL packages and qualified human accessibility review own normative judgments. Phase 5 records what is present, what is missing, and what was traded away.

## Control Surface Taxonomy

Every evidence register entry, tradeoff record, and work-item seed is anchored to one of six control surfaces. The surface enumerates the delivery channel through which the user encounters the product; assistive technology coverage, conformance level applicability, and remediation strategy all vary by surface.

### `web`

Browser-rendered experiences delivered over HTTP, including single-page applications, server-rendered pages, and embedded web components. Component examples: HTML forms, ARIA widgets, SVG visualizations, in-browser PDF viewers, web-based authoring interfaces.

### `mobile`

Native or hybrid applications running on iOS, Android, or other mobile platforms. The user reaches the surface through a touch-first interaction model with platform-supplied assistive technology. Component examples: native screens, mobile WebViews, push-notification surfaces, in-app camera capture flows, deep-linked share sheets.

### `desktop`

Native applications running on Windows, macOS, Linux, or other desktop operating systems. The surface relies on platform accessibility APIs (UI Automation, AX, AT-SPI) rather than browser ARIA. Component examples: installer dialogs, ribbon and menu controls, tray applications, document editors, embedded chromium views inside a desktop shell.

### `documents`

User-facing documents produced or distributed by the product, evaluated against the structural and semantic accessibility requirements that apply to authored content rather than running software. Component examples: tagged PDFs, generated reports, exported spreadsheets, presentation decks, downloadable user manuals.

### `kiosk`

Self-service or fixed-purpose hardware surfaces where the user interacts with a constrained input modality and the product cannot assume personal assistive technology is present. Component examples: airport check-in terminals, in-store ordering screens, ATMs, ticket vending machines, wayfinding panels.

### `voice`

Voice-first surfaces and conversational interfaces where the user interacts primarily through speech and audio. Component examples: IVR phone flows, smart-speaker skills, in-car voice assistants, telephony bots, captioned voice-to-text intake forms.

A single component may span more than one surface (for example, a responsive web app rendered inside a kiosk shell). When this happens, the planner records one evidence entry per surface so remediation can be tracked per delivery channel.

## Evidence Register Schema

Every evidence entry catalogs a single artifact (a test result, an audit finding, an attestation, an implementation reference) that demonstrates or refutes coverage of a control on a single surface. Entries are reusable across planners by stable `evidenceId` and the cross-planner core fields are intentionally identical to the Security Planner evidence register so SSSC, RAI, and Security can cross-reference entries without translation.

Schema (YAML):

```yaml
evidenceId: EV-A11Y-001          # stable kebab-case id; never renumbered
surface: web                     # one of: web, mobile, desktop, documents, kiosk, voice
framework: wcag-22               # frameworkId from frameworkSelections
criterion: '1.4.3'               # framework-native criterion identifier
controlReference: 'WCAG 2.2 SC 1.4.3 (Contrast Minimum)'
status: covered                  # pending | covered | partial | gap | not-applicable
owner: accessibility-lead        # human-resolvable owner identifier
reviewedAt: 2026-05-20           # ISO 8601 date of last review
notes: |                         # free-text context
  Verified against design tokens v3.2; light theme only.
# Accessibility-specific extensions:
assistiveTechValidated:          # list of AT validated against the entry
  - 'NVDA 2024.4 + Firefox 128'
  - 'VoiceOver iOS 17.4 + Safari'
personaImpact:                   # list of impacted persona identifiers
  - 'low-vision'
  - 'color-blind-deuteranopia'
wcagLevel: AA                    # A | AA | AAA | N/A
```

### Cross-Planner Shared Fields

The following fields share names, semantics, and value spaces with the Security Planner evidence register (see `.github/instructions/security/security-model.instructions.md`):

| Field              | Purpose                                                               |
|--------------------|-----------------------------------------------------------------------|
| `evidenceId`       | Stable identifier; preserved when imported by another planner         |
| `surface`          | Delivery channel; aligns with the Security Planner bucket terminology |
| `framework`        | Source framework identifier (`wcag-22`, `section-508`, etc.)          |
| `criterion`        | Framework-native criterion or control identifier                      |
| `controlReference` | Human-readable citation including standard, section, and title        |
| `status`           | Lifecycle state shared across planners                                |
| `owner`            | Accountable individual or role                                        |
| `reviewedAt`       | ISO 8601 date of the most recent review                               |
| `notes`            | Free-text context, dependencies, and known limitations                |

### Accessibility-Specific Extensions

| Field                    | Purpose                                                                     |
|--------------------------|-----------------------------------------------------------------------------|
| `assistiveTechValidated` | List of assistive technology stacks the evidence was tested against         |
| `personaImpact`          | List of impacted persona identifiers from Phase 1 discovery                 |
| `wcagLevel`              | `A`, `AA`, or `AAA` for WCAG-anchored controls; `N/A` for non-WCAG criteria |

### Register Rules

* `evidenceId` is allocated once and never renumbered when entries are added or removed
* An entry with `status: gap` requires at least one `personaImpact` value; collapsing all impacted personas into a generic label is forbidden
* `wcagLevel` is required whenever `framework` is a WCAG-anchored framework (`wcag-22` and conformance-leveled imports); use `N/A` for other frameworks
* When the planner is unsure whether a control is covered, it writes `status: pending` rather than guessing; pending entries roll into the watchlist for follow-up

## Tradeoff Documentation Pattern

Tradeoffs are recorded whenever an accessibility decision is constrained by a non-accessibility concern. Common triggers include performance budgets (skipping a heavier ARIA pattern), cost (deferring a multilingual captioning pass), schedule (shipping a kiosk surface without voice fallback), and platform constraints (a vendor SDK that blocks programmatic focus management).

Schema (YAML):

```yaml
tradeoffId: TO-A11Y-001          # stable kebab-case id
surface: kiosk
decision: |
  Ship v1 kiosk without voice fallback; revisit after pilot retrospective.
accessibilityImpact: |
  Users who cannot read the screen lose a primary intake path; equivalent
  staff-assisted path is documented in operator runbook.
mitigations:
  - 'Operator-assisted fallback documented in runbook v2.1'
  - 'Voice fallback added to Q3 roadmap with owner'
acceptedBy: 'product-owner: jane.doe@example.com'
```

### Required Fields

* `tradeoffId` — stable identifier, never renumbered
* `surface` — the affected control surface from the six-surface taxonomy
* `decision` — the chosen course of action in plain prose
* `accessibilityImpact` — the harm or reduced experience that results, expressed in user-impact terms
* `mitigations` — list of compensating actions, runbook references, or roadmap commitments that reduce residual impact
* `acceptedBy` — the human accountable for the decision; an organizational role or named individual

### Arbitration Rule

The planner does not arbitrate tradeoffs. It surfaces the tension, drafts the candidate fields, and asks the user to populate `acceptedBy`. A tradeoff entry without an `acceptedBy` value is treated as a pending negotiation and rolls into `planRiskAssessment.watchlist` rather than the tradeoff log. The planner never auto-fills `acceptedBy` with itself, the model name, or a placeholder.

### Linking to Evidence

When a tradeoff causes an evidence entry to land at `status: partial` or `status: gap`, the affected `evidenceId` is added to the `mitigations` list as a reference (for example, `'See EV-A11Y-014 for residual gap detail'`). This keeps the tradeoff log and the evidence register navigable in both directions without duplicating content.

## Seed Work-Item Generation Rules

Work-item seeds are pre-shaped records the Phase 6 handoff renders directly. The seed shape is deliberately wide enough that both the ADO and GitHub renderers in `references/backlog-handoff.md` can consume it without further transformation.

Schema (YAML):

```yaml
seedId: SEED-A11Y-001            # stable kebab-case id
surface: mobile
framework: wcag-22
criterion: '2.4.7'
severity: major                  # critical | major | minor | enhancement
recommendedAction: |
  Restore visible focus indicator on the in-app camera capture
  view; ensure 3:1 contrast against all backgrounds.
evidenceRefs:                    # list of evidenceId values that justify this seed
  - EV-A11Y-007
  - EV-A11Y-009
autonomyTier: supervised         # manual | supervised | autonomous
```

### Severity Derivation

* `critical` — a `status: gap` on a Level A WCAG criterion, a `status: gap` on a Section 508 functional performance criterion, or a control whose failure blocks an essential user task on any surface
* `major` — a `status: gap` on a Level AA criterion, or a `status: partial` on a Level A criterion
* `minor` — a `status: partial` on a Level AA criterion, or a `status: gap` on a Level AAA criterion when AAA is in scope
* `enhancement` — a control marked `status: covered` where the user requested an opportunistic uplift (for example, raising AA to AAA)

### Autonomy Tier Semantics

The `autonomyTier` value controls how the Phase 6 handoff treats the seed. Semantics are inherited from `.github/instructions/security/backlog-handoff.instructions.md`:

* `manual` — write the seed to a handoff file only; do not create a work item via MCP tools
* `supervised` — present the seed to the user in a review batch before MCP creation; this is the default for new sessions
* `autonomous` — create the work item directly via MCP tools when the user has pre-approved batch creation

### Seed Rules

* Every `seedId` references at least one `evidenceId` in `evidenceRefs`; seeds without supporting evidence are forbidden and surface as a watchlist entry instead
* `severity` is derived mechanically from the rules above; the planner records the derivation in `notes` only when the user overrides the default
* `recommendedAction` is written in user-task language, not control-id language, so the work item is actionable by an implementer who does not have the framework spec open
* A seed inherits `surface` from the originating evidence entry; multi-surface remediation produces one seed per surface

## Cross-Planner Evidence Cross-Links

Evidence entries can be cross-referenced to entries owned by the Security Planner, the RAI Planner, or the SSSC Planner. Cross-links keep the four planners auditable as a single accessibility-and-trust posture without duplicating evidence content.

Schema fragment (YAML), appended to any evidence entry that is cross-linked:

```yaml
crossPlannerRefs:
  - planner: security-planner    # security-planner | rai-planner | sssc-planner
    evidenceId: EV-WEB-014
    relationship: 'shared-control'    # shared-control | informs | depends-on
  - planner: sssc-planner
    evidenceId: EV-SSSC-021
    relationship: 'informs'
```

### When to Cross-Link

* Security Planner — when an accessibility evidence entry also satisfies a Security Planner control (for example, focus-management evidence that satisfies both keyboard accessibility and a UI redress-attack mitigation)
* RAI Planner — when the underlying surface is AI-generated (alt text, captions, generative UI) and the evidence informs both the accessibility and RAI evidence registers
* SSSC Planner — when the evidence is part of a VPAT, ACR, or EAA attestation packet that the SSSC Planner will publish

### Cross-Link Rules

* The originating planner owns the `evidenceId`; the cross-linking planner references it without renaming
* `relationship: shared-control` means both planners count the entry against their own coverage
* `relationship: informs` means the entry provides context but is not counted against the cross-linking planner's coverage
* `relationship: depends-on` means the cross-linking planner's coverage is conditional on the referenced entry remaining valid
* Stale cross-links (the referenced `evidenceId` is missing or its `status` is `superseded`) flag a watchlist entry on the next Phase 5 re-entry

## Phase Exit Criteria

Phase 5 advances to Phase 6 only when all of the following are true:

* Every `controlMappings` entry with `status` of `gap` or `partial` has at least one matching `evidenceRegister` entry, or a `planRiskAssessment.deferredMitigations` record explaining the absence with a `deferredReason`
* Every `evidenceRegister` entry has the nine cross-planner shared fields populated; the accessibility extensions are populated when the framework requires them
* Every tradeoff in the tradeoff log carries an `acceptedBy` value
* Every `seedId` references at least one `evidenceId` in `evidenceRefs`
* The set of severities across all seeds is internally consistent with the underlying evidence statuses (for example, no `enhancement` seed references a `gap` evidence entry)
* `gates.impact-evidence.confirmed` is set to `true` with `confirmedAt` and `confirmedBy`

When any criterion fails, the planner reports the failing item, repairs the artifact in place, and re-runs the exit check; it does not advance the phase on a partial pass.

## Anti-patterns

The following behaviors are forbidden in Phase 5 and surface as planner self-corrections when observed during state reads:

* Fabricating a `severity` value without a backing evidence entry, including extrapolating severity from a framework citation without a concrete artifact reference
* Collapsing the `personaImpact` field into a single generic label such as "users with disabilities"; persona granularity from Phase 1 must be preserved on every gap or partial entry
* Treating `manual` autonomy as the implicit default for every seed; the autonomy tier is selected explicitly per session and recorded in `userPreferences.autonomyTier`
* Recording a tradeoff without an `acceptedBy` value; un-accepted tradeoffs are watchlist entries, not tradeoff-log entries
