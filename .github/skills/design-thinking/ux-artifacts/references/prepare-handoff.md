---
title: "UX artifact mode: Prepare handoff"
description: Produce an implementation-facing UX handoff covering flow, states, recovery, rationale, evidence, assumptions, and open decisions.
---

# Prepare handoff

Use this mode when UX decisions are ready to inform engineering. The asset describes what the experience must do and why. It does not prescribe implementation architecture or replace requirements ownership.

The output is a gitignored local file. When the team requires a permanent engineering record, copy or reference it from committed documentation.

## Inputs

* Supplied journey, needs, inclusion, or design evidence
* Entry and exit conditions
* Screens, states, or system responses already decided
* Recovery paths and known edge cases
* Rationale, assumptions, and unresolved decisions

When a completed `sketch-structure` asset exists, the caller may pass its pointer as `source`. Consume the surface composition and states it already records; do not restate its composition tables here. This mode adds system response, success and exit conditions, recovery, engineering questions, and acceptance inputs.

## Output body

After the common evidence sections, write:

```markdown
## Experience Flow

| Step or state | User intent and action | System response | Success or exit condition | Recovery path | Basis and source                             |
|---------------|------------------------|-----------------|---------------------------|---------------|----------------------------------------------|
| <step>        | <intent and action>    | <response>      | <condition>               | <recovery>    | <Observed, Reported, or Assumed plus source> |

## Design Rationale

* <decision and why it follows from supplied evidence>

## Inclusion and Accessibility Handoff

* Inclusion decisions: <source pointer or summary>
* Technical conformance questions for `accessibility`: <questions or None>
* Build-checkable surface meaning: <Design Intent Record candidate or None>

## Engineering Questions

* <unresolved implementation-facing question and owner>

## Acceptance Inputs

| User-visible outcome or state                                           | Basis and source                             |
|-------------------------------------------------------------------------|----------------------------------------------|
| <outcome requirements authors can turn into native acceptance criteria> | <Observed, Reported, or Assumed plus source> |
```

## Design Intent Record boundary

A Design Intent Record is human-authored committed source owned by `accessibility`. Point to one when a surface-specific decision must be checkable in a build. Do not copy its schema, generate a substitute record, or treat Figma as authoritative for the same decision.

The handoff may carry intent and expectation identifiers after a record exists. It does not create those identifiers speculatively.

## Completion conditions

* Flow, system response, success, and recovery are explicit where evidence supports them.
* Every design rationale identifies its evidence strength.
* Every acceptance input carries its evidence class and source.
* Assumptions and open engineering questions remain visible.
* Accessibility and Design Intent Record candidates route to their authoritative capability.

## Stop conditions

Stop when implementation architecture, requirements prioritization, or acceptance-criteria ownership is the unresolved task. Record the question and return the handoff instead of making that downstream decision. Stop and name `sketch-structure` when the real request is what a surface contains rather than how the experience behaves across states.
