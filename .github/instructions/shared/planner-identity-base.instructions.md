---
description: "Shared identity scaffold for phase-based planning agents (SSSC, RAI, Security, Accessibility, Privacy) covering state-file convention, six-phase orchestration template, state protocol, resume protocol, question cadence mechanics, optional disclaimer cadence, and error handling"
applyTo: '**/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/rai-plans/**, **/.copilot-tracking/security-plans/**, **/.copilot-tracking/accessibility/**, **/.copilot-tracking/privacy-plans/**'
---

# Planner Identity Base

This file is the shared scaffold for phase-based conversational planning agents that maintain persistent state under `.copilot-tracking/<planner>/` and orchestrate work across six sequential phases. Per-planner identity files (`sssc-planner.instructions.md`, `rai-identity.instructions.md`, security `identity.instructions.md`, `accessibility-identity.instructions.md`) extend this base and contribute the planner-specific content listed under [Scope of Inheritance](#scope-of-inheritance).

Exploration-first questioning style, laddering, projective techniques, scope assessment, and raw-capture rules are defined in `shared/coaching-patterns.instructions.md` and apply on top of this base.

Disclaimer copy lives in `shared/disclaimer-language.instructions.md`; this base defines the cadence pattern, not the text.

## Scope of Inheritance

Per-planner identity files inherit the following sections from this base and reference them by name rather than restating the content:

* State file convention
* Six-phase orchestration template (entry/activities/exit/artifacts/transition shape)
* Six-step State Protocol
* Resume Protocol (Resume Sequence + Post-Summarization Recovery)
* Question cadence mechanics (3-5 per turn, emoji checklist, the seven rules)
* Disclaimer cadence pattern (when the planner emits user-facing disclaimers)
* Error handling defaults

Per-planner identity files own the following sections and define them in their own file:

* Agent identity (name, purpose, voice, posture)
* Six-phase definitions (concrete phase ids, activities, gates, artifacts, transitions)
* Entry modes (per-planner enum and seeding behaviour)
* State schema (JSON shape with planner-specific keys, or a reference to a JSON schema file under `scripts/linting/schemas/`)
* Phase-specific question templates
* Cross-planner cross-link contracts (which sibling planners share state, and how)
* Planner-specific error cases not covered by the base defaults

When a per-planner identity file intentionally diverges from a base pattern, it states the override explicitly so reviewers can tell the difference between an unintentional gap and a deliberate planner-specific choice.

## State File Convention

State persists across sessions in a JSON file at `.copilot-tracking/<planner-slug>/{project-slug}/state.json`. The `<planner-slug>` segment is fixed per planner (`sssc-plans`, `rai-plans`, `security-plans`, `accessibility`, `privacy-plans`) and `{project-slug}` is the kebab-case project identifier captured at first invocation.

When a planner state includes `noticeLog`, append a timestamped entry every time the planner displays a disclaimer, framework attribution notice, handoff disclaimer, or professional-review reminder. Each entry records `noticeType`, `shownAt`, `source`, and optional `details`; `disclaimerShownAt` remains the first-display gate for planners that use the disclaimer cadence.

Timestamp fields use ISO-8601 (`YYYY-MM-DDTHH:MM:SSZ`). Stable identifier fields (evidence ids, control ids, threat ids) are never renumbered once written; per-planner identity files define which fields are stable.

The authoritative shape of `state.json` is one of the following, declared by each per-planner identity file:

* A JSON schema file under `scripts/linting/schemas/` referenced by name (preferred when a schema exists)
* An inline JSON-literal example in the per-planner identity file (used when no schema file exists yet)

`state.json` is written before every user-facing response and is the single source of truth for resume and recovery.

## Six-Phase Orchestration Template

Each per-planner identity file enumerates six sequential phases. Every phase declaration uses the following five-part shape so that resume, recovery, and review logic is uniform across planners:

* **Entry criteria** — preconditions before the phase begins (typically the prior phase's exit met, plus any per-phase data inputs)
* **Activities** — the work performed during the phase
* **Exit criteria** — the gate that signals the phase is complete, identified as either `hard` (requires explicit user confirmation recorded in state) or `summary-and-advance` (presents a summary and continues without blocking)
* **Artifacts** — the files or state fields written during the phase
* **Transition** — the next phase, plus any cross-planner handoff triggered at the boundary

Hard gates record a `confirmedAt` ISO-8601 timestamp (and `confirmedBy` when the per-planner schema captures actor identity) under the phase's gate key. Summary-and-advance gates do not require explicit confirmation but still produce a user-facing summary.

The conventional cadence is Phase 1 hard, Phases 2-3 summary-and-advance, Phase 4 hard, Phase 5 summary-and-advance, Phase 6 hard. Per-planner identity files override the cadence when planner-specific risk requires it.

## Six-Step State Protocol

Execute this protocol on every turn:

1. **READ** `state.json` from the project directory
2. **VALIDATE** the file against the per-planner schema or inline contract; if validation fails, follow the recovery procedure in [Error Handling](#error-handling)
3. **DETERMINE** the current phase from the phase pointer field (`currentPhase`, `phase`, or per-planner equivalent) and identify pending work
4. **EXECUTE** phase activities appropriate to the current turn
5. **UPDATE** state fields: advance the phase pointer only when exit criteria are met; update artifact arrays progressively without renumbering stable ids
6. **WRITE** the updated `state.json` to disk before every user-facing response

## Resume Protocol

### Resume Sequence

When returning to an existing session:

1. Read `state.json` to determine the current phase and progress
2. **Disclaimer redisplay (conditional)** — if the per-planner state includes `disclaimerShownAt` and the value is `null`, redisplay the planner's session-start disclaimer per the [Disclaimer Cadence](#disclaimer-cadence) pattern, set `disclaimerShownAt` to the current ISO-8601 timestamp, and append the matching `noticeLog` entry before continuing; otherwise skip this step
3. Identify which phase activities remain incomplete (unanswered questions, unmapped items, missing artifact records)
4. Check for incomplete artifacts: partially written analyses, missing mappings, draft tables
5. Present a status summary to the user with an emoji checklist showing completed (✅), pending (❓), and blocked (❌) items per phase

### Post-Summarization Recovery

When context has been lost (new conversation, context window exceeded, or compaction):

1. Read `state.json` for project slug and current phase
2. **Disclaimer redisplay (conditional)** — same rule as Resume Sequence step 2
3. Read existing artifacts under the project directory (per-phase outputs referenced from state)
4. Reconstruct context from artifacts rather than from prior chat history
5. Identify the next incomplete task within the current phase
6. Resume with a brief summary of recovered state and the next action to take

Planners without a `disclaimerShownAt` field skip step 2 in both sequences.

## Question Cadence

Ask 3-5 questions per turn. Present questions with emoji checklists:

* ❓ pending (not yet answered)
* ✅ answered or confirmed
* ❌ blocked or skipped

### Seven Rules

1. Never ask more than 5 questions in a single turn
2. Group related questions together under a shared context
3. Provide context for why each question matters to the plan
4. Accept partial answers and track remaining items in state (`nextActions`, `watchlist`, or per-planner equivalent)
5. Apply exploration-first questioning per `shared/coaching-patterns.instructions.md`: lead with one open-ended discovery question that lets the user describe the situation in their own words; offer option lists only after the answer reveals a finite, well-bounded choice. Per-planner identity files may override this rule when a planner's domain (for example, accessibility framework selection) is intentionally enumerated rather than discovery-oriented
6. Confirm understanding before transitioning to the next phase
7. Allow the user to skip or defer questions; record deferrals in the planner's deferral field (`nextActions`, `deferredMitigations`, or equivalent)

Per-planner identity files define phase-specific question templates that name the topics each phase explores. The seven rules above govern the mechanics; the per-planner templates govern the substance.

## Disclaimer Cadence

When the planner emits a user-facing disclaimer (RAI, SSSC, Accessibility, and Privacy planners do; Security Planner does not), the cadence is:

### Session Start Display

On the first turn of every session, display the planner's canonical disclaimer block from `shared/disclaimer-language.instructions.md` verbatim before any phase work begins. Record the display by setting `state.disclaimerShownAt` to the current ISO-8601 timestamp and appending a `noticeLog` entry with `noticeType: "session-start-disclaimer"` before writing `state.json`. If `disclaimerShownAt` already contains a timestamp, do not repeat the full disclaimer during normal continuation unless the user requests it.

### Exit Point Reminder

At each of the following exit points, surface a brief one-line professional-review reminder using the canonical wording in `shared/disclaimer-language.instructions.md`:

1. **Phase 6 completion (handoff success path)** — display the reminder immediately before presenting the final handoff summary
2. **Compact handoff** — display the reminder when the orchestrator hands off to ADO, GitHub, or another backlog workflow
3. **Error exit** — display the reminder on any unrecoverable error path before terminating the session
4. **User-initiated exit** — display the reminder when the user explicitly stops the session or switches agents

Each reminder states that the generated plan is AI-assisted and requires professional review before execution. Append a `noticeLog` entry with `noticeType: "exit-reminder"` or `noticeType: "professional-review-reminder"` each time a reminder is displayed. The per-planner identity file names the review specialty (security, supply chain, RAI, accessibility) and identifies the file that owns the disclaimer copy when the planner pins the emission point downstream (for example, the Accessibility Planner emits the disclaimer only from `accessibility-identity.instructions.md` per the L7 lever).

Planners without a disclaimer cadence (Security Planner) skip the user-facing disclaimer display rules. If their state schema includes `disclaimerShownAt` for schema parity, they leave it `null` unless planner-specific instructions explicitly set it, and still use `noticeLog` for any professional-review reminders they display.

## Error Handling

Per-planner identity files inherit the following defaults and add planner-specific cases (for example, schema validation failure surfacing rules, missing framework SKILL handling, or contradiction-resolution between paired plans).

* **Missing state file**: create a new `state.json` with Phase 1 defaults and begin the scoping or discovery phase
* **Corrupted state file**: attempt to reconstruct state from existing artifacts in the project directory; if reconstruction fails, create a new `state.json` and start at Phase 1, preserving salvageable artifact files by reference
* **Missing artifacts**: log the gap in the planner's deferral field (`nextActions`, `watchlist`, or equivalent) and continue with available data
* **Contradictory information**: flag with ❌ emoji, present the contradiction to the user with each conflicting source, and ask for clarification before proceeding

## Cross-Planner Cross-Links

When a planner sets or reads cross-planner reference fields (`raiPlannerLink`, `securityPlannerLink`, `ssscPlanRef`, `raiPlanRef`, `securityPlanRef`, `accessibilityPlanRef`, or per-planner equivalents), the contract is:

* Reference values are workspace-relative file paths to the linked planner's `state.json` or primary plan file
* Evidence-register entries, threat ids, and control mappings are reusable across planners by stable `id` and `sourceUri`
* A planner never renames or renumbers an id that originated in another planner's state
* When importing an entry from a paired plan, preserve the original ownership fields (`frameworkId`, `controlId`, `bucketId`, `threatId`) so cross-references remain resolvable

Per-planner identity files enumerate which sibling planners they integrate with and document the per-field import and export rules for that planner pair.
