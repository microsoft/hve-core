---
title: 'UX Coaching State'
description: UX coaching reference for session state structure; load when reading, writing, or resuming ux-coaching moment state.
---

# UX Coaching State

Coaching state lets a practitioner leave a moment and come back to it. It records enough to resume a conversation, and deliberately records nothing that implies sequence, completion, or progress through a curriculum.

## Location

Store state at `.copilot-tracking/ux-coaching/{project-slug}/state.yaml`.

`{project-slug}` is a lower-kebab-case project identifier, for example `checkout-redesign`. Never write state directly under `.copilot-tracking/ux-coaching/` without a project-slug directory. Ask for the slug when the practitioner has not supplied one, and offer any existing slugs in the directory as choices.

The slug names a project, not a person. Do not record practitioner names, email addresses, employer, team membership, or any other personal identifier.

## Two scopes

State separates what belongs to the practitioner from what belongs to a single piece of work.

* Practitioner scope carries notes that improve coaching across every moment in this project.
* Moment-instance scope carries one named piece of work: its subject, its status, what it produced, and enough summary to resume.

Instances are an unordered set. There is no current instance, no completed list, and no transition history.

## No autonomy mode

Coaching has no autonomy mode, and this state defines no autonomy field.

Autonomy tiers exist to control how generated work items reach a backlog system: whether the agent drafts, asks, or creates directly. Coaching emits no work items. It produces a conversation and one plain-text output the practitioner owns, and every turn already leaves the decision with them. A tier would describe a choice this skill never makes.

Do not add an autonomy field under any name. The canonical enumeration in the shared backlog-templates skill records the coaching posture for cross-capability reference; nothing needs to be persisted here.

## Schema

```yaml
practitioner:
  pattern_notes: ""          # free text: how this practitioner responds to hints

moments:
  - id: "checkout-flow-critique-2026-08-02"
    moment: "critique"        # problem-framing | critique | stakeholder-advocacy
    subject: "checkout flow v3"
    status: "open"           # open | parked | closed
    entered_at: "2026-08-02T00:00:00Z"
    last_touched_at: "2026-08-02T00:00:00Z"
    evidence: []             # what the practitioner supplied as evidence, with its source
    assumptions: []          # what remains unvalidated, stated as such
    unresolved: []           # open questions the practitioner named
    output_ref: null         # where the produced output lives, once it exists
    resume_summary: ""       # enough to re-enter the conversation without re-asking
```

## Field rules

`id` is stable once written. Derive it from the subject and the entry date, and never renumber it.

`status` means only what it says. `open` is in progress, `parked` is deliberately set aside, `closed` is finished. A closed instance is not a completed step toward anything.

`evidence`, `assumptions`, and `unresolved` stay distinct. Move an item from `assumptions` to `evidence` only when the practitioner supplies a source, and record that source with it.

`output_ref` stays `null` until the moment's output actually exists.

`pattern_notes` records how this practitioner responds to hints. It never presets a progressive-guidance level; escalation starts at level 1 each time a gap appears.

## Downstream eligibility

A moment is eligible for a downstream handoff when both hold:

1. `output_ref` is non-null and resolves.
2. The moment reference's own additional precondition is met.

Neither condition alone is sufficient, and no moment defines an independent gate.

`resume_summary` is written for a practitioner returning after a week. Favor what was decided and why over a transcript.

## Forbidden fields

These encode progress through a sequence and must not appear:

* A current or active moment pointer
* A completed-moment list
* A transition or history log of movement between moments
* A phase, step, or stage number
* Any Design Thinking method number or canonical deck state
* Any autonomy tier, autonomy mode, or equivalent preference

A practitioner who runs a critique on Tuesday and frames a problem on Friday has not moved backward. Nothing should record that they did.

## Resume

1. Read the state file for the resolved project slug. When it does not exist, this is a new project; create it before the first coaching turn.
2. Offer open and parked instances whose subject relates to what the practitioner is asking about. Let them choose to resume one or start a new one.
3. On resume, load `resume_summary`, `evidence`, `assumptions`, and `unresolved`, and confirm the standing picture in one turn before continuing to coach.
4. Update `last_touched_at` and the changed fields at each material point in the conversation.

## Recovery

When the state file is missing, unparseable, or internally inconsistent, say so plainly and offer the practitioner a choice: start a fresh instance, or rebuild the standing picture together from what they remember and from `output_ref` if it resolves.

Never invent evidence, assumptions, or history to fill a gap. An empty field is honest; a fabricated one is not.
