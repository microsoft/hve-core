---
description: 'Template-selection rules for the Requirements Builder agent: framework-skill phaseMap reading, depth-tier gating, and audience filtering.'
applyTo: '**/.copilot-tracking/requirements-sessions/**'
---

# Requirements Builder — Phase 3: Template Selection

Phase 3 reads the active frameworks' manifests and projects the universe of available document sections down to the set that will actually be drafted in Phase 4.

## Inputs

* `state.frameworks[]` filtered to entries with `selected: true`.
* For each selected framework: `index.yml.phaseMap` plus the `items/*.yml` referenced by that map.
* `state.intake.answeredQuestions[]` to resolve audience and depth-tier inferences.

## Selection Algorithm

For each selected framework `F`:

1. Read `F.index.yml.phaseMap`. Treat the keyed phase ids (`drafting`, `review`, …) as the canonical schedule for `F`'s items.
2. Enumerate `F.items[*]`. For each item:
   * Skip when `selectWhen.depth_tier` is present and does not contain the active depth tier (`light` | `standard` | `deep`).
   * Skip when `applicability.audience` is present and intersects empty with the active audience set captured in `state.intake.answeredQuestions[]` (theme `Personas`).
   * Otherwise include the item in `F`'s draft plan.
3. Persist `F`'s included item ids into `state.drafts.outputs[where frameworkId == F.id].sectionsPending[]` in the order declared by `index.yml.phaseMap`.

## Multi-Framework Outputs

When more than one framework is selected, each framework drafts into its own per-framework output path declared in its `index.yml.outputPath` (resolved in Phase 4). Do not merge sections across frameworks; per-framework `state.drafts.outputs[]` entries remain independent.

## Persistence

* `state.drafts.outputs[]` gains one entry per selected framework: `{ frameworkId, slug, path, format, sectionsCompleted: [], sectionsPending: [<itemId>, …] }`.
* `state.skillsLoaded[]` gains an append-only entry for every `index.yml` and `items/*.yml` read during selection (per the rules in [`requirements-identity.instructions.md`](requirements-identity.instructions.md)).

## Exit Criteria

Phase 3 is complete when every selected framework has a non-empty `sectionsPending[]` (or a recorded reason in `compaction-log.md` when the framework matches no items after gating). Append a one-paragraph summary of the selection result to `compaction-log.md` and advance to Phase 4.
