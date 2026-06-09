---
description: "Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows."
applyTo: '**/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md'
---

## Mural Seeding Patterns

These conventions apply when an agent seeds a Mural board from a source artifact (DT method outputs, RAI Phase 2 packs, UX research notes). Workflow-specific contracts (cardinality assertions, A1/A2/A3 wedge bindings, journey-stage decompositions) live in the consuming agent. This file holds only the patterns that recur across every seeding workflow.

The skill is content-agnostic transport. An under-populated board surfaces as a missing agent-side decomposition rule, not a missing skill guard rail. See [mural-writeback-hygiene.instructions.md](mural-writeback-hygiene.instructions.md) for stable channel rules and [mural-human-record.instructions.md](mural-human-record.instructions.md) for the durable-record stance.

## Agent-Owned Element and Parent Intent

Before generating payloads, the consuming agent chooses the Mural element type, source-artifact decomposition, expected cardinality, placement intent, and parent-area intent. Apply this widget-type decision rule before writing any payload:

* Use a textbox for verbatim user content.
* Use a textbox for content over 15 words or over 120 characters.
* Use a textbox for lists, paragraphs, code, tables, or other structured layouts.
* Use a textbox for labels, headers, rationales, summaries, or explanatory annotations.
* Use a sticky note only for a short atomic card.
* Use an area for a container, phase, swimlane, group, or navigation zone.
* Use a shape, connector, or other supported widget only when the source artifact needs that visual semantics.

Textbox `text` is a plain string. Use embedded newlines as the list and soft-break primitive, for example `"* item one\n* item two"`; do not expect Markdown rendering inside the Mural widget.

Generated dictionary payloads must declare an explicit `type`. An untyped dictionary is a consuming-agent authoring error. String-only payloads are allowed only when the agent intentionally wants a small sticky note and the target parent area is already known.

Parent-area intent is declared before creation by resolving the target area id, target anchor, relative location, or area-relative layout primitive. Raw unparented coordinates are invalid outside documented discovery and probe operations. When discovery or probe operations produce coordinates, use them only as evidence for resolving a parent, anchor, or layout primitive before bulk creation.

## Duplicate-then-Populate

When the user supplies a source board id, prefer `mural mural duplicate` or `mural template instantiate` over `mural mural create`. The user calling a board "the template" almost always means duplicate it literally so its anchors, frames, and area definitions carry forward. Coordinate fabrication is the failure mode this pattern exists to prevent.

```text
seed_request.has(source_mural)  -> mural mural duplicate
seed_request.has(template_id)   -> mural template instantiate
neither                         -> mural mural create  (last resort)
```

## Source-Artifact-to-Area Binding

Each seed run binds one named source artifact to one named area, and one source row produces one widget. The agent owns the binding map (which document, which section, which target area). The skill never invents bindings.

Workflow-specific binding tables (RAI A1 / A2 / A3 wedges, UX JTBD / Journey Stages / Pain Points / Opportunities / Accessibility, DT Method N output blocks) live in the consuming agent file, not here.

## Anchor Inheritance

When the source board ships per-area placeholder widgets, do not invent `(x, y)`, `(width, height)`, or `style.backgroundColor` for seeded widgets. Pair seeded widgets to placeholder anchors by reading order `(y, x)`, copy geometry and fill, PATCH via `mural widget update-bulk`, then `mural widget delete` only the anchors that were consumed.

```text
anchors = sort(placeholders, by=(y, x))
seeds   = sort(new_widgets, by=author_order)
for a, s in zip(anchors, seeds): patch(s, geometry=a, fill=a.style.backgroundColor)
delete(consumed_anchor_ids)
```

## Probe-before-Bulk

Use `mural area probe` before bulk-populating any area. The verb creates a 1×1 probe sticky bound to the target `parentId`, retrieves it with full context (`area_chain` plus siblings), runs binding and occlusion checks, and deletes the probe, returning one verdict per area:

* `ok` — area is safe for bulk seeding.
* `unbound` — empty `area_chain`. Hard stop: surface the area id and observed parent ids, do not bulk-populate into an unbound area.
* `parent_mismatch` — nearest area in the chain is not the expected `parentId`. Hard stop: a similarly named sibling frame is being targeted instead of the intended area.
* `occluded` — probe bounding box is fully contained within one or more siblings (returned in `siblings_above`). Hard stop: a sticky that renders behind an area background panel is invisible to the human user and violates the durable-record stance in [mural-human-record.instructions.md](mural-human-record.instructions.md).

A clean (`ok`) probe is also positive evidence that the chosen `parentId` resolves to the intended area title, not a sibling frame with a similar name.

`widget create-bulk` enforces its own probe gate: it issues the first parented entry as a probe and inspects the returned `containment_verification.verdict`. If the verdict is not in the success set (`parent_match`, `area_chain_match`, `geometry_match`), every remaining entry that targets a parent is short-circuited with `reason: "probe_failed"` so the operator can re-anchor without burning the rest of the batch. Per-create containment verification reports the full verdict vocabulary — `parent_match`, `area_chain_match`, `geometry_match`, `parent_mismatch`, `geometry_mismatch`, `readback_failed`, `inconclusive` — and both `parent_mismatch` and `geometry_mismatch` exit non-zero. Empty or whitespace-only `--parent-id` values are rejected at argument parse time and as bulk-payload validation, before any API call.

## Z-Order Visibility

The Mural REST API exposes no canvas z-order operation as of May 2026 (see `https://developers.mural.co/public/reference/`). This is an upstream constraint, not a deferred skill feature: the widget endpoint surface is limited to typed `/widgets/{type}` POST/PATCH/DELETE, and the only widget field that resembles ordering, `presentationIndex`, is documented as outline-panel order, not canvas stacking. A correctly bound widget (`area_chain` non-empty, geometry inside the area) can therefore still render behind a sibling background panel, title bar, or frame.

`mural area probe` detects this case and returns `verdict: "occluded"` with the offending sibling ids in `siblings_above`. Treat `occluded` as a hard stop that escalates to the human operator: surface the affected area id and the `siblings_above` ids, pause the seeding workflow, and ask the operator to fix stacking in the Mural UI (right-click "Send to Back" / "Bring to Front", or restructure the area's anchor widgets). Use this escalation template:

```text
Mural seeding paused because the probe widget for area <area_id> is hidden behind sibling widget(s): <siblings_above>. Please open the board in Mural, send the occluding background/frame widget(s) to the back or bring the intended anchor layer to the front, then rerun the seeding step.
```

Do not re-run `mural area probe`, do not destroy and recreate the widget hoping it lands on top, and do not hand-tune `(x, y)` offsets to dodge the occluding sibling. None of these patterns can defeat the API ceiling, and destroy-and-recreate also costs widget id, comments, and edit history with no determinism guarantee.

Anchor Inheritance sidesteps this failure entirely when the source board ships per-area placeholders, because consumed anchors inherit both geometry and z-order slot. Use Anchor Inheritance whenever the source board has any per-area widgets, even ones that look purely decorative.

## Layout-Primitive Enforcement

Sibling placement uses `mural layout grid`, `mural layout row`, `mural layout cluster`, or `mural layout column`. Raw `(x, y)` integer literals on widget payloads are forbidden under any condition outside the Anchor Inheritance pattern above (where coordinates are copied, never authored).

Discovery and probe operations may observe raw coordinates, but their output is evidence only. Convert that evidence into a resolved `parentId`, anchor inheritance patch, or layout primitive before writing user-visible payloads.

If a layout primitive cannot express the intended arrangement, escalate to a new layout verb in the skill, not to inline coordinates.

## 404 Recovery

Treat HTTP 404 from any `mural` CLI verb as a re-read-SKILL.md trigger, not a drop-down-a-layer trigger. The verb name, argument shape, or required scope is wrong, and the fix lives in [SKILL.md](../../skills/experimental/mural/SKILL.md).

Do not import private skill helpers (`_authenticated_request`, `_merge_tags`, `_resolve_area_id`, etc.) into operator code. Private helpers are not a stable surface and any reach-around is treated as a regression in the consuming agent.

## Reserved Tag Manifest

Every seeded widget carries `authored-by-ai` (the Pattern C reserved author tag from [mural-writeback-hygiene.instructions.md](mural-writeback-hygiene.instructions.md)) plus exactly one workflow lineage tag from the manifest below. Tags are re-applied defensively on every seed run via `mural tag create` and `mural widget update-bulk` because workspace state may have drifted since the last invocation.

| Workflow                  | Lineage tag     | Set by                    |
|---------------------------|-----------------|---------------------------|
| RAI Phase 2 board seeding | `rai-phase2`    | `rai-planner.agent.md`    |
| DT Method N export        | `dt-method-{N}` | `dt-coach.agent.md`       |
| UX research bootstrap     | `ux-research`   | `ux-ui-designer.agent.md` |

Workflow tags must respect the 25-character cap from [mural-writing-style.instructions.md](mural-writing-style.instructions.md). Substitute the concrete value for `{N}` at seed time.

## Participating Workflows

Three agents pull these conventions via the `applyTo` glob in this file's frontmatter. Each agent owns its own decomposition rules and cardinality contracts, then references this file with `#file:` for the cross-cutting patterns above.

| Customization file                                                                  | Workflow            | Inline contract owned by the customization                                           |
|-------------------------------------------------------------------------------------|---------------------|--------------------------------------------------------------------------------------|
| [dt-coach.agent.md](../../../agents/design-thinking/dt-coach.agent.md)              | DT board export     | Per-method binding map; trigger milestones for Methods 1/3/4/5/6                     |
| [rai-planner.agent.md](../../../agents/rai-planning/rai-planner.agent.md)           | RAI Phase 2 seeding | A1 / A2 / A3 wedge bindings; per-area cardinality assertion; `state.json` write-back |
| [ux-ui-designer.agent.md](../../../agents/project-planning/ux-ui-designer.agent.md) | UX research seeding | JTBD / Journey / Pain / Opportunity / Accessibility decomposition                    |
