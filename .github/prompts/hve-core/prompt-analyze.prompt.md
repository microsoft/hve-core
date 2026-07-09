---
description: 'Review prompt-engineering artifacts without source edits through HVE Builder review mode'
agent: Prompt Builder
argument-hint: "[promptFiles=...] [requirements=...]"
---

# Prompt Analyze

## Inputs

* `${input:promptFiles}`: existing prompt-engineering artifacts to review; defaults to current open or attached files
* `${input:requirements}`: optional purpose, criteria, or behavior to emphasize

## Requirements

1. Route the targets to `hve-builder` review mode.
2. Keep source artifacts read-only; write only review, behavior-test, and requested validation evidence.
3. Report the behavior-test profile and fidelity, and do not describe simulation as native runtime evidence.
4. Return the static verdict, behavior verdict, validation as `Not requested` unless requested, overall outcome, top findings, and durable report links.
