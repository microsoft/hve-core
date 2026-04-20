---
description: "Living canonical deck lifecycle rules — when to trigger generation, coaching voice by method, schema additions to coaching state, and artifact completeness expectations"
applyTo: "**/.copilot-tracking/dt/**"
---

# DT Canonical Deck Instructions

The canonical deck is a living artifact that evolves alongside the Design Thinking process. It is not a final-stage output. It is a structured, internally-tagged representation of every HVE artifact produced so far — used to track alignment, surface gaps, and eventually derive customer-facing cards.

## What the Canonical Deck Is

Each deck entry is a structured markdown file containing:

1. A customer-friendly summary of the artifact — written as if explaining to a non-technical stakeholder.
2. An internal metadata table — 7 fields that capture source traceability, team state, freshness, and customer readiness.

The deck lives in `canonical/` inside the project slug directory (`.copilot-tracking/dt/{project-slug}/canonical/`). It is a single, evolving directory updated in place as the team progresses through the 9 methods. It is the single source of truth from which clean customer-facing cards are derived by filtering out internal metadata.

## Artifact Completeness Model

All artifact types (Vision Statement, Problem Statement, Scenarios, Use Cases, Personas) may exist at any method. Artifacts created early in the process are incomplete and need refinement, but they should still be captured in the deck.

### By Method

| Method              | Expected Artifact State                                                                                 | Candidate for Delivery           |
|---------------------|---------------------------------------------------------------------------------------------------------|----------------------------------|
| 1 (Scope)           | Vision and Problem: rough drafts. Scenarios/Use Cases/Personas: may exist as early ideas                | No — all too early               |
| 2 (Design Research) | Vision and Problem: refining. Scenarios: emerging from research. Personas: drafts based on stakeholders | No — still being validated       |
| 3 (Input Synthesis) | Vision and Problem: stable. Scenarios: validated. Use Cases: synthesized from HMWs. Personas: confirmed | No — awaiting concept work       |
| 4 (Brainstorming)   | All artifacts from 1-3 stable. Some new use cases may emerge from ideation                              | No — still solutioning           |
| 5 (User Concepts)   | Full set expected: all artifact types should exist. Concepts are validated.                             | Maybe — assess per entry         |
| 6+ (Solutioning)    | Artifacts stable from Method 5. Focus is on implementation, not artifact production.                    | Yes — for artifacts marked ready |

**Key rules**:
- Set `Internal state: HVE Core: needs work` for artifacts created before Method 5.
- Set `Internal state: HVE Core: think done` for artifacts that survived synthesis and concept validation.
- Set `Candidate for immediate delivery: yes` only when the artifact is at Method 5+ AND the team believes it is ready for customer review without rework.
- Artifacts created at Methods 1-4 should always have `Candidate for immediate delivery: no`.

### Scenario Card Completeness Contract

Every scenario card MUST include these sub-sections:

1. `### Description`
2. `### Scenario Narrative`
3. `### How Might We`

The `### Description` section is the short customer-facing overview for the scenario. Do not leave summary prose directly under the main scenario heading. Put that prose in `### Description` so canonical files and PowerPoint renders stay aligned.

The `How Might We` section must think through:

* The business value the team is trying to achieve
* The opportunities that could be unlocked if the scenario succeeds
* Who benefits from the scenario
* What those benefits are

The `Scenario Narrative` section must be people-centered and grounded in actual DT context. It should:

* Clearly articulate the business value the team is trying to unlock or unblock
* Identify the personas or users interacting with the system
* Explain what those users care about
* Describe the challenges they face
* Clarify what they are trying to accomplish
* Show what success looks like for the scenario
* Tell the story in human terms rather than as a technical system description

### Vision Statement Render Contract

Vision statement cards must preserve both of these sections through customer-card rendering:

1. `## Vision Statement`
2. `### Why This Matters`

The render output must not drop `Why This Matters`. It is a required customer-facing explanation block, not metadata.

### Use Case Card Completeness Contract

Every use case card MUST include these sub-sections:

1. Use Case Description
2. Business Value
3. Use Case Overview
4. Primary User
5. Secondary User
6. Preconditions
7. Steps
8. Data Requirements
9. Equipment Requirements
10. Operating Environment
11. Success Criteria
12. Pain Points
13. Evidence
14. Extensions

If sufficient context is not available for any sub-section:

- Set the sub-section body to exactly `<insufficient knowledge>`
- Add `#### Questions to Ask` under that sub-section
- Provide 2-5 targeted questions to ask customers, stakeholders, or end users so the team can gather missing information

Do not suppress or remove required sub-sections due to missing data. Missing knowledge must be explicit and actionable.
Do not invent content to make a section feel complete. Canonical generation must stay grounded in concrete evidence from prior Design Thinking methods.

## When to Trigger Canonical Deck Generation

The canonical deck offer fires on **artifact write events**, not method boundaries. A team can generate customer-friendly cards after completing any meaningful task within a method — no need to wait until an entire method is done.

### Primary Trigger: Artifact Write Event

After any new canonical artifact is registered in the coaching state, the DT Coach checks whether to offer deck generation.

The canonical artifact set is: Vision Statement, Problem Statement, Scenario, Use Case, Persona. Non-canonical artifacts (stakeholder maps, interview notes, HMW questions, observation logs) do NOT trigger the offer.

**Offer the deck when ALL of the following are true:**

1. The artifact just written is a canonical type (see above).
2. The artifact path differs from `canonical_deck.last_offered_artifact_path` — a different canonical artifact has been written since the last offer.
3. The team has not set `canonical_deck.session_declined: true`.
4. The active method is 1-5.

**Do NOT offer when:**

- Only non-canonical artifacts were produced.
- The artifact is an update to one already in the deck (offer a deck **refresh** instead — see Staleness Detection).
- The team is mid-sentence or in an active question flow. Wait for a natural pause.
- The active method is 6, 7, 8, or 9.

### Secondary Trigger: Session Start Staleness Check

At the start of every session (Methods 1-5), compare artifact fingerprints against the last snapshot. If any canonical artifact changed since the last snapshot, offer:

> Some of your artifacts have changed since the last deck snapshot. Want me to refresh the canonical deck before we continue?

### Tertiary Trigger: Explicit Team Request

Respond immediately when the team asks to see customer cards or asks to generate/update the deck. No cooldown applies. Invoke `generate-canonical-deck.prompt.md` immediately.

Examples: "Can you generate my customer cards?", "What would this look like for a customer?", "Update the deck."

### Auto-Generate Trigger: Method 7b Approach Selection

When the team selects a high-fidelity prototype approach (Method 7b, phase `approach-selected`), generate the final deck automatically without asking. Write result to `{project-slug}/canonical/`.

## Customer Card PowerPoint Offer Lifecycle

The customer-card PowerPoint is a render artifact derived from the canonical deck. It lives under the project slug and is re-built whenever the team wants a visual artifact for sharing or review.

### Render Output Location

All PowerPoint render artifacts live under `.copilot-tracking/dt/{project-slug}/render/`:

```text
.copilot-tracking/dt/{project-slug}/render/
├── content/
│   └── ... generated slide YAML and assets ...
└── output/
  └── customer-cards.pptx
```

Do not write render outputs outside the project slug. The project slug is always the base path for canonical deck inputs and PowerPoint outputs.

### Runtime Fallback Contract for Customer-Card Builds

When invoking `dt-build-customer-cards.prompt.md`, use the direct Python execution path as the primary strategy. Shell wrapper scripts (`build-cards.ps1`, `invoke-pptx-pipeline.sh`) are available as fallbacks but are not required.

**Primary path — direct Python invocation:**

1. Ensure `uv` is available. Locate it on PATH or at common install locations (`~/.local/bin/uv`, `~/.local/bin/uv.exe`, `~/.cargo/bin/uv`). If not found, install it silently first.
2. Run `uv sync --directory <skill-root>` once to create the virtual environment and install dependencies from the skill's `pyproject.toml`.
3. Run `generate_cards.py` with any available Python (it uses only stdlib modules).
4. Run `build_deck.py` using the skill's venv Python (`<skill-root>/.venv/Scripts/python.exe` on Windows, `<skill-root>/.venv/bin/python` on macOS/Linux).

**Fallback path — shell wrapper scripts:**

1. Use `pwsh` with `build-cards.ps1` when available. It handles `uv sync` internally.
2. If `pwsh` is unavailable but native `bash` is available (not WSL bash on Windows), use `invoke-pptx-pipeline.sh`. It handles `uv sync` internally.

All Python scripts depend on packages declared in the skill's `pyproject.toml`. Never run `pip install` or any manual dependency installation.

**Environment setup is silent.** Do not ask users to confirm dependency installation, uv availability checks, or venv creation. Run these steps automatically and only surface errors if they fail.

### Primary Trigger: Canonical Deck Create or Refresh

After the canonical deck is created or refreshed, offer the PowerPoint render by invoking `dt-build-customer-cards.prompt.md`.

Offer when ALL of the following are true:

1. A generated canonical snapshot exists for the current method or final state.
2. `customer_card_render.last_generated_snapshot_key` does not match the latest generated snapshot key.
3. `customer_card_render.session_declined` is not `true`.
4. The active method is 1-5, or the team explicitly asked for the visual.

### Secondary Trigger: Session Start Check

At the start of a session, if the latest generated canonical snapshot is newer than the latest successful PowerPoint render, offer a refresh once for that snapshot:

> The canonical deck moved since the last PowerPoint build. Want me to generate a fresh visual from it?

This offer uses the same cooldown model as the canonical deck offer. Do not repeat it for the same snapshot after the team has already accepted or declined.

### Tertiary Trigger: Explicit Request

When the team explicitly asks for a PowerPoint, slide deck, PPT, or customer-card visual, invoke `dt-build-customer-cards.prompt.md` immediately. Explicit requests skip cooldown checks.

### PowerPoint Offer Cooldown Logic

Track PowerPoint offer state separately from canonical deck offer state.

* After making an offer, store the latest generated canonical snapshot key in `customer_card_render.last_offered_snapshot_key`.
* After a successful build, store the same snapshot key in `customer_card_render.last_generated_snapshot_key`.
* If the team says `stop asking` or similar, set `customer_card_render.session_declined: true`.
* Reset `customer_card_render.session_declined` to `false` when a newer canonical snapshot is generated than the one recorded in `last_offered_snapshot_key`.

### Cooldown Logic

After making an offer (accepted or declined), store the triggering artifact path in `canonical_deck.last_offered_artifact_path`. Only make a new offer when a **different** canonical artifact path is written. If the team declines twice in a row during one session, set `canonical_deck.session_declined: true`. Reset to `false` at the next session start.

## Coaching Voice by Trigger Context

The DT Coach uses an observational, option-framing voice — collaborative, not commanding. Match the voice to the artifact just written, not to a method boundary.

### After a Vision Statement or Problem Statement is written

> I can rough that into a scope card — a clean header, customer summary, and a few metadata tags. Makes it easy to compare your understanding now versus later. Want me to do that, or keep moving?

### After a Scenario is written

> That scenario is a good candidate for a customer card. I can add it to the deck now if you want to see what it looks like in customer-friendly format. Want that?

### After a Use Case is written

> I can add that use case to the canonical deck. It is a draft at this stage, but it helps make the inventory visible. Want me to include it?

### After a Persona is written or confirmed

> That persona could go straight into the deck. I can capture it now so we track it as the project evolves. Want me to add it?

### After multiple canonical artifacts are written in the same sub-method

> You have added {N} artifacts this session. I can generate a deck snapshot that covers all of them — shows what is captured so far, what is still rough, and what might be customer-ready. Want that before we move to the next step?

### Session-start staleness offer

> A few artifacts changed since the last deck snapshot. Want me to refresh the deck, or are you still mid-revision?

**Purpose for all offers**: Let teams see how their current work reads to customers — early and often, not just at method boundaries.

## Coaching State Schema Additions

Add the following block to `coaching-state.md` to track canonical deck lifecycle:

```yaml
canonical_deck:
  enabled: true
  auto_generate_at_method_7b: true
  session_declined: false              # Reset to false at each new session start
  last_offered_artifact_path: null    # Path of artifact that triggered the most recent offer

  snapshots:
    method_1:
      status: "skipped | generated | pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

    method_2:
      status: "pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

    method_3:
      status: "pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

    method_4:
      status: "pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

    method_5:
      status: "pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

    final:
      status: "pending"
      timestamp: null
      output_path: ".copilot-tracking/dt/{project-slug}/canonical"
      entry_count: 0
      candidate_count: 0
      fingerprints: {}

customer_card_render:
  enabled: true
  session_declined: false
  last_offered_snapshot_key: null
  last_generated_snapshot_key: null
  last_generated: null
  last_output_path: null
```

### Field Definitions

- `enabled`: Set to `true` when the team has opted in to canonical deck tracking.
- `auto_generate_at_method_7b`: When `true`, generate final deck automatically at Method 7b completion without asking.
- `session_declined`: Set to `true` when the team says "stop asking" or declines twice in a row during a session. Reset to `false` at each new session start.
- `last_offered_artifact_path`: Path of the canonical artifact that triggered the most recent offer. A new offer is only made when a **different** artifact path is written. Cleared after successful generation.
- `snapshots[method].status`: One of `pending` (not yet offered), `skipped` (offered and user declined), `generated` (offer accepted and deck created).
- `snapshots[method].output_path`: Always `.copilot-tracking/dt/{project-slug}/canonical/` — all snapshots point to the same evolving directory.
- `snapshots[method].entry_count`: Total number of deck entries generated.
- `snapshots[method].candidate_count`: Number of entries marked `Candidate for immediate delivery: yes`.
- `snapshots[method].fingerprints`: Map of `{artifact-filename}: {sha256}` for staleness detection.
- `customer_card_render.last_offered_snapshot_key`: Snapshot key of the latest generated canonical deck snapshot that triggered a PowerPoint offer (for example, `method_3:2026-04-09`).
- `customer_card_render.last_generated_snapshot_key`: Snapshot key used for the most recent successful PowerPoint build.
- `customer_card_render.last_generated`: ISO 8601 date of the most recent successful PowerPoint build.
- `customer_card_render.last_output_path`: Relative path to the generated PPTX under the project slug.

## Output Directory Convention

The canonical deck lives in a single directory inside the project slug and is updated in place throughout all 9 methods:

```
.copilot-tracking/dt/{project-slug}/
└── canonical/
    ├── vision-statement.md
    ├── problem-statement.md
    ├── scenarios/
    │   └── {scenario-name}.md
    ├── use-cases/
    │   └── {use-case-name}.md
    └── personas/
        └── {persona-name}.md
```

There are no per-method output copies. The `generate-canonical-deck` prompt always writes to `output-dir: canonical` scoped under the active project slug. Artifacts are created or overwritten as understanding improves across methods.

Method-boundary history is preserved through the coaching state snapshot fingerprints — not through separate output directories. The coach can surface comparisons across methods by comparing fingerprints: "Your problem statement changed since Method 1 — want to review what shifted?"

## Staleness Detection

After each snapshot, store SHA256 fingerprints of the source artifact files. On the next session start or before the next snapshot offer:

1. Recompute the fingerprint of each source file.
2. Compare against stored fingerprints.
3. If any source changed, mark the corresponding deck entry `Freshness status: Stale`.
4. Offer to regenerate stale entries before the next snapshot.

### User-Facing Command Explanation Requirement

When the coach needs to run or request approval for fingerprint/hash commands, explain what the command does in plain language before execution. Do not present raw command text without context.

Minimum explanation format:

1. Purpose: "I am checking whether canonical source files changed since the last snapshot."
2. Method: "I will compute SHA256 fingerprints and compare them to saved snapshot values."
3. Expected result: "If fingerprints differ, I will refresh only changed deck entries."

The same rule applies to PowerPoint build commands and any fallback command path.

## Method-Boundary PowerPoint Offer

At each transition away from Methods 1-5, after canonical snapshot generation completes, the coach offers customer-card PowerPoint generation before switching to the next method.

The offer occurs even when the team did not explicitly ask for PPTX output. The user can accept, decline, or defer, and the decision is recorded in `customer_card_render` state fields.

## Purpose Explanation for Teams

When a team asks what the canonical deck is for, the coach explains:

> It serves as a thinking tool first, and a customer delivery tool later. Now, it helps us see what we've committed to and where our understanding is still rough — which surfaces gaps early. Later, it becomes the source from which we derive clean customer-facing cards, so there's no manual translation between what the team knows and what customers see.
