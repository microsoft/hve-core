---
title: TM7 Generation Format Contract
description: OTM-aligned input schema, mapping reference, template profile contract, and current native feedback workflow for TM7 generation.
ms.date: 2026-08-11
ms.topic: reference
---


## TM7 generation reference

This document records the verified wire facts and the current input-contract decisions for the TM7 generation extension. The content is intentionally independent of the upstream OTM schema wording and is aligned to OTM concepts for interoperability rather than copied from the upstream document.

## Native TM7 visual feedback workflow

The skill also supports an opt-in, Windows-local feedback loop that replays a validated layout overlay through the generator and validates the result in the native Microsoft Threat Modeling Tool UI. The workflow is disabled unless `validate_tm7_with_tmt.py` is invoked with `--feedback-loop`, `--spec`, and `--overlay-output`. When those flags are absent, the default generation and validation behavior remains unchanged.

### Current CLI contract

`generate_tm7.py` takes the spec as its positional argument and accepts:

* `-o` / `--output` for the generated `.tm7` path, defaulting to `out.tm7`
* `--template` to select a template profile, defaulting to the spec value or `sdl_core_generic`
* `--mode` with `pre-populated-comprehensive` or `diagram-only-defer-to-tmt`
* `--update` to merge the generated output onto an existing TM7 model
* `--overlay-input` to replay a validated layout overlay onto the generated model
* `--threat-generation-enabled` to synthesize STRIDE-per-element threats and emit `ThreatGenerationEnabled=true`

`validate_tm7_with_tmt.py` takes the input model as its positional argument, always requires `--evidence-dir`, and selects behavior through `--mode`:

| Harness mode               | Purpose                                                                       |
|----------------------------|-------------------------------------------------------------------------------|
| `probe`                    | Confirm TMT is present, trusted, and at the pinned version without validating |
| `calibration-smoke`        | Short bounded run used to calibrate capture and layout metrics                |
| `validate`                 | Default mode; open the model in TMT and validate load fidelity                |
| `compare-generation-state` | Compare the model against `--comparison-model` for generation drift           |
| `upgrade-template`         | Exercise the TMT template-upgrade prompt and write `--upgraded-model-output`  |

The remaining flags group as follows:

* Feedback loop: `--feedback-loop`, `--spec`, `--overlay-input`, `--overlay-output`, `--max-iterations` (`1` through `3`, default `1`), and `--require-feedback-evidence` to require per-surface screenshot, UIA, metrics, and findings evidence before the run is accepted
* Template upgrade: `--template-upgrade-policy` with `fail` (default), `decline`, or `apply`, plus `--delete-stale-threats` to drop stale threats while applying a newer template
* Environment: `--require-tmt` to fail rather than skip when TMT is absent, `--pinned-version` (default `7.3.51110.1`), `--workspace-root` to relocate the runtime workspace, `--timeout-seconds` (default `60`), and `--diagnostic-override`
* Expectations: `--expected-threat-count` and `--expected-custom-type-count`, both optional assertions that are unset by default so a model of any size is accepted
* `-v` / `--verbose` for debug logging

The native harness requires the pinned Microsoft Threat Modeling Tool version and treats the workflow as a local UI Automation workflow that must run on Windows with an interactive desktop session. On a non-Windows host, or when TMT cannot be discovered, the run stops as `tmt-unavailable` under `--require-tmt` and as `skipped` without it, and it reports `version-mismatch`, `automation-timeout`, or `unexpected-modal` when the runtime environment diverges from the expected harness contract.

The feedback loop requires operator-safety confirmation from the agent before launch; `tm7-generation-workflow.instructions.md` owns that contract. The harness itself does not block on the operator: it announces the start of automation, surfaces baseline/refinement candidate progress, and emits a release notice once the loop completes or aborts so the operator knows the computer can be used again. The workflow may open, close, and reopen TMT more than once to complete save/reopen validation.

The default is a baseline plus one refinement. A single run holds the mouse and keyboard continuously from the start notice through the baseline and every refinement iteration, and returns control only at the release notice; the operator does not regain control between iterations. Replaying a corrected overlay with `--overlay-input` is a new run and a new takeover, so a review cycle that produces corrections costs more than one takeover. The agent asks the operator how many rounds to run before launching.

### Evidence layout

Each run writes a redacted evidence bundle rooted at the requested evidence directory. The root contains `manifest.json`, `status.json`, `action.log`, and the `screenshots/`, `uia/`, `exports/`, `summaries/`, and `logs/` folders. A run that captured at least one surface and either passed the automated gates or stopped for layout exhaustion also writes `agent-review-request.json` at the root; see Agent-assisted visual review. The run also writes `iterations/00-baseline` plus `iterations/01` through `iterations/03` as needed. Each iteration bundle contains per-surface screenshots, UIA snapshots, summaries, and the generated candidate model, and the loop writes an iteration-scoped `overlay.yaml` into the iteration bundle plus a final pending overlay to the explicit `--overlay-output` path; the payload carries `approval_state: pending` and the runtime never auto-promotes it to `approved`.

### Deterministic metrics, thresholds, and stop reasons

The deterministic geometry gates are separate from the advisory screenshot heuristics. The current implementation treats the following geometry findings as review or warning gates:

* `overlap_ratio > 0.03` becomes a review finding, while `overlap_ratio >= 0.01` becomes a warning
* `edge_node_intersections > 2` becomes a review finding, while `edge_node_intersections > 0` becomes a warning
* `edge_crossing_count > 2` becomes a review finding in non-dense layouts, while dense layouts warn at `>= 1`
* `min_spacing_ratio < 0.24` becomes a review finding, while `min_spacing_ratio < 0.6` becomes a warning
* a missing or incomplete surface capture is a review finding

Screenshot heuristics are advisory. They can raise a review finding when the image analysis indicates a likely defect, but they do not override deterministic geometry gates or the human semantic review step.

The loop uses the stable stop reasons `automated-ready-pending-human`, `repeated-defect-no-improvement`, `max-iterations`, `evidence-incomplete`, `semantic-regression`, `candidate-generation-failed`, `overlay-validation-failed`, `tmt-unavailable`, `skipped`, `version-mismatch`, `automation-timeout`, `unexpected-modal`, and `harness-error`. Every outcome the loop assigns is one of these reasons, and an outcome that is not is reported as `harness-error` rather than collapsed into `unexpected-modal`; a generator, overlay, or harness failure is never described as a blocking dialog. `automated-ready-pending-human` is the success reason and states exactly what it means: the automated gates are satisfied and the result is waiting for human review. It is not an approval. A baseline run plus three refinement iterations is the maximum bounded execution. Semantic regression is evaluated against the baseline model identity and blocks promotion even when the geometry score improves.

When TMT is not discovered, `--require-tmt` decides the outcome: with the flag the run stops as `tmt-unavailable` with exit `3`, and without it the run stops as `skipped` with exit `0`. A run that publishes no overlay removes any file already at `--overlay-output`, so an earlier run's overlay is never mistaken for the current result. The only exception is a caller that points `--overlay-input` and `--overlay-output` at the same file.

### Whole-surface refinement

Before spending a native launch on another iteration, the loop asks whether any whole-surface alternative is measurably better than what was drawn. An alternative is a pairing of an orientation with a zone order, because those are the only two whole-surface choices an overlay can carry into layout. The search enumerates the distinct pairs, at most 32 per failing surface per iteration.

Each alternative is laid out in process, on a copy of the model, and scored on geometry measured from the result: canvas clipping, nodes outside their zone, boundary overlap, edges crossing nodes, label collisions, edge crossings, node overlap, and scroll extent, in that order of severity. That is information generation could not have had, because it comes from the shape the layout actually takes. Scoring an alternative on graph topology alone cannot work here: generation already minimized that same score when it chose the shipped layout, so the incumbent wins by construction and no alternative is ever selected.

An alternative the generator refuses to lay out, such as one that overruns the bounded canvas, is rejected as a candidate and the remaining alternatives still run. Rejection is ordinary and can account for a large share of the space on a surface with several zones. A rejected alternative never ends the run.

An alternative is selected only when it strictly improves on the incumbent and preserves every element, flow, and zone identity. A selected alternative becomes a `surface_rules` entry on the overlay replayed into the next iteration, so the iteration regenerates against the chosen layout rather than the unchanged model. When nothing improves, the loop stops as `repeated-defect-no-improvement` without launching.

`action.log` records one line per iteration reporting the surface, how many alternatives were evaluated, how many were pruned as dominated, how many were rejected for identity or for being unrealizable, and whether a launch was earned. Read that line before trusting a `repeated-defect-no-improvement` stop: it distinguishes a genuine "nothing was better" from a search that evaluated nothing.

### Overlay schema and invalidation

The feedback overlay is a versioned payload with `schema_version`, `overlay_type`, `model_id`, `overlay_id`, `applies_to`, `provenance`, `approval_state`, and `invalidation` fields. Layout intent is carried in four named rule collections rather than one generic `rules` list:

| Collection        | Governs                                                            |
|-------------------|--------------------------------------------------------------------|
| `zone_rules`      | Trust-boundary zone placement, sizing, and containment             |
| `node_rules`      | Element placement within its owning zone                           |
| `connector_rules` | Data-flow routing and handle positioning                           |
| `surface_rules`   | Surface-wide layout settings that apply to a whole drawing surface |

Overlays emitted by automation must carry `approval_state: pending`. Invalidation requires a complete fingerprint block; a partial block is rejected rather than backfilled. All five fingerprints must be present and must match:

* `spec_fingerprint`
* `generator_profile_fingerprint`
* `surface_identity_fingerprint`
* `surface_zone_identity_fingerprint`
* `surface_flow_identity_fingerprint`

These checks reject stale or tampered overlays before a candidate model is generated.

A stopped run can also publish an overlay seed. When the loop stops for layout exhaustion, meaning `repeated-defect-no-improvement` or `max-iterations`, it writes a valid overlay to `--overlay-output` carrying correct fingerprints, `approval_state: pending`, and all four rule collections empty. The empty collections are the signal that automation found no correction to publish. A correctness stop such as `semantic-regression`, an incomplete capture, or an environment failure publishes no seed at all.

Because the five fingerprints are hashes over spec bytes and sorted model identity sets, they are derived rather than authored. The seed is therefore the only practical starting point for a hand-authored or agent-authored overlay.

### Windows-local example

```bash
uv run --project .github/skills/project-planning/security-planning --group windows \
  python scripts/validate_tm7_with_tmt.py model.tm7 \
  --evidence-dir ./artifacts/feedback \
  --feedback-loop \
  --spec ./specs/model.yaml \
  --overlay-output ./artifacts/feedback/overlay.json \
  --max-iterations 3 \
  --require-feedback-evidence
```

The automation writes pending overlays only and keeps the canonical baseline unchanged. Promotion is an external action; the agent-facing rule is owned by `tm7-generation-workflow.instructions.md`.

### Agent-assisted visual review

Deterministic metrics cannot see every layout defect. TM7 persists no connector label geometry, and UI Automation exposes no label element for a connector: the tree carries only a `FocusBorder` spanning the whole route. An agent that reads the rendered screenshots can see defects that no metric will ever score, and this section defines how that observation becomes a layout correction.

The review is a default step, not an opt-in one. Every run that captured at least one surface and either passed the automated gates or stopped for layout exhaustion emits `agent-review-request.json` at the evidence root, and the run is not finished until that review happens. `automated-ready-pending-human` means the automated gates passed and the result is waiting for review; it is not an approval.

Treat the protocol's remedy as documented rather than proven. Its end-to-end effectiveness has not yet been demonstrated on a real defect.

#### Protocol

1. Run the harness with `--feedback-loop` and let it write the evidence bundle.
2. Read `agent-review-request.json` at the evidence root. It carries, per surface, the screenshot and UIA paths, the node and zone rectangles, the connector handle points, and the predicted label rectangles, all in model coordinates, plus the coordinate-translation constants and the port convention. Fall back to the raw UIA tree at each surface's `uia_path` only when the request is absent or a value it does not carry is needed.
3. Read the screenshots the request points at. Judge the render against the defect classes no metric covers, which the request lists: label-on-node collision, label-on-label overlap, unreadable or truncated label text, connector routing through empty space, and visual crowding that leaves individually legible elements unreadable as a whole.
4. Translate the observation into model coordinates. The request supplies current values, so a displacement can usually be computed without the procedure below; use it when a value must be recovered from a screenshot.
5. Author rules into the published overlay at `--overlay-output`, using any of `zone_rules`, `node_rules`, `connector_rules`, and `surface_rules`. On the success path that overlay addresses every captured surface, so a rule can be authored for any of them; when the run found no automated correction it is the seed shape, carrying an `overlay-seed-` identifier and empty rule collections. Leave the `invalidation` block untouched; editing a fingerprint invalidates the overlay.
6. Replay the edited overlay with `--overlay-input` and compare the new screenshots against the previous iteration.
7. Stop after at most three attempts for a given surface, or earlier once the defect is resolved. This bound governs agent attempts and is counted separately from the harness's own iteration budget. Attempts accumulate per surface across the whole review cycle, including replays and separate agent sessions, and reset only when a spec or profile change produces a new baseline. A `surface_rules` canvas enlargement is an attempt like any other.

#### Request payload

`agent-review-request.json` is validated by [assets/schemas/tm7-agent-review-request.schema.json](../assets/schemas/tm7-agent-review-request.schema.json), which rejects unknown keys.

Per surface it carries `surface_id`, `surface_name`, `surface_guid`, `screenshot_path`, `uia_path`, `metrics_path`, `node_rects`, `predicted_connector_label_rects`, `connector_handles`, `zone_content_rects`, `boundary_rects`, `viewport_target`, `diagram_bounds`, `existing_findings`, and `review_status`.

At run level it carries `defect_classes`, `coordinate_translation`, `port_convention`, `overlay_seed_path`, `replay_command`, and `agent_round`. `overlay_seed_path` is `null` unless this run published an overlay. `replay_command` is reserved and is always `null` today, because the harness does not reconstruct its own invocation. `agent_round` is replay depth, `0` on an initial run and `1` when `--overlay-input` was supplied; it is not a claim about how many agent rounds have run, because the harness cannot see across invocations.

`predicted_connector_label_rects` are predictions from the generator's own placement search, not measurements of what the tool drew. Treat them as a hint about where a label will land, never as evidence of where it is.

#### Rule fields

Each collection accepts a fixed key set, and an unknown key is rejected rather than ignored. [assets/schemas/tm7-layout-overlay.schema.json](../assets/schemas/tm7-layout-overlay.schema.json) is the authoritative schema.

| Collection        | Accepted keys                                                                         |
|-------------------|---------------------------------------------------------------------------------------|
| `zone_rules`      | `surface_id`, `zone_id`, `region`, `label_band_height`, `lane_order`                  |
| `node_rules`      | `surface_id`, `node_id`, `layout_role`, `absolute_position`, `relative_placement`     |
| `connector_rules` | `surface_id`, `flow_id`, `source_port`, `target_port`, `handle_point`, `label_offset` |
| `surface_rules`   | `surface_id`, `zone_order`, `orientation`, `viewport_target`, `outer_margin`          |

Rule values are absolute model coordinates, not displacements. A translation step yields how far an element must move; the rule requires where it must end up. Read the current value from the candidate model in the iteration bundle, such as `iterations/00-baseline/candidate-00-baseline.tm7`, and add the displacement to it. For a connector, the current handle is the `HandleX` and `HandleY` pair on that flow, and `agent-review-request.json` reports it directly as `connector_handles`.

An authored `connector_rules` entry additionally requires non-empty `source_port` and `target_port`; validation rejects the rule before it looks at `handle_point`. Use `"auto"` for both. `handle_point` is an object with `x` and `y` keys, which is the same shape `connector_handles` emits, so a displaced handle can be authored without reshaping it.

#### Coordinate translation

The request payload supplies current node rectangles, zone rectangles, and connector handle points in model coordinates, so most corrections need no recovery step at all. Use this procedure when a value must be measured from a screenshot instead.

`feedback-manifest.json` carries no node rectangles. Its per-surface keys are `capture_path`, `findings`, `human_review_required`, `human_review_status`, `metrics`, `surface_guid`, `surface_id`, `surface_name`, and `uia_path`; there is no `surface_geometry` key at all.

Rendered rectangles come from the UI Automation tree at `uia_path`, one element per line in pipe-delimited form:

```text
8|Custom||VS Code Extension|654|242|885|392
```

The trailing four fields are left, top, right, and bottom in screen pixels, keyed by the element name that precedes them. A drawn node appears as a `Custom` row whose automation id is empty, which is the empty field between `Custom` and the name.

TMT renders the model faithfully at a uniform 1.5x zoom. A least-squares fit over eight nodes measured an x scale of 1.5001 and a y scale of 1.4926 with a maximum residual of 1.1 pixels. Model coordinates are therefore recoverable as `(screen - offset) / 1.5`, and the shared offset cancels whenever two rectangles on the same surface are compared, so a displacement can be computed without ever resolving the origin.

Worked example: a label whose right edge sits 60 screen pixels inside a node's left edge overlaps that node by `60 / 1.5`, which is 40 model units. Clearing it with a margin of 10 model units requires a displacement of 50 model units, not 50 pixels. State every displacement in model units, because rule values are model coordinates and a pixel figure pasted into a rule moves the element half again as far as intended.

#### Connector label placement

Three measured facts govern any rule that moves a connector label:

* `handle_point` is the only lever that reaches the renderer. It is serialized as `HandleX` and `HandleY` on the connector.
* `label_offset` has no effect and is ignored. It formerly displaced the predicted `label_rect` without moving the drawn label, so the placement search preferred offsets that appeared to clear obstacles while the render did not change. Measured over the comprehensive spec, 53 of 55 labels had a prediction that disagreed with the render, and the generator scored 2 collisions where TMT drew 46. The generator now searches handles alone, so the predicted rect always equals the rendered rect. The key is still accepted for schema compatibility.
* TMT draws each connector label centred on its handle point. It does not place the label's top-left corner there. Four labels on the `ctx-01` surface were extracted from a render screenshot and all four fit `label_centre_screen = 1.5 * handle_model + (-4.5, -3)` exactly on both axes. A competing hypothesis that labels anchor to the route midpoint was ruled out by the same measurement.

To move a label, move `handle_point` by the required model displacement and predict the resulting position by assuming centring.

#### Constraints

* `approval_state` stays `pending`; no runtime path promotes an overlay.
* Semantic identity is immutable. A layout correction may move things; it may never add, remove, or rename an element, flow, or zone. `validate_layout_overlay` enforces this.
* `surface_rules` may enlarge the canvas. Enlarging trades a clipped diagram for a scrolled one, and it is the only available remedy for genuine viewport overflow, so record why node and connector rules were insufficient. That rationale goes in the review record accompanying the overlay, not in the overlay itself: `provenance` accepts only `evidence_ref`, `generated_at`, and `approval_state`, and any other key is rejected.
* An agent-authored overlay is evidence, not truth. Record which iteration and which screenshot motivated each rule.

### Operator runbook

#### Prerequisites

Confirm all of the following before starting a feedback run. The harness stops rather than degrading when any of them is missing.

* Windows with an interactive, unlocked desktop session. A remote session that disconnects, a locked workstation, or a screensaver breaks UI Automation and screen capture.
* Microsoft Threat Modeling Tool at the pinned version, installed for the current user and launchable from the desktop.
* The `windows` dependency group installed, because the UI Automation and capture dependencies are not in the default group.
* The baseline model and the spec that produced it. The harness regenerates candidates from the spec, so a spec that no longer matches the model invalidates the overlay.
* A writable evidence directory on a local disk that either does not already exist or is owned by the harness. Avoid a synced or network folder; capture and manifest writes are frequent, and the harness refuses to remove directories it did not create.
* No already-open Threat Modeling Tool windows. The harness opens, closes, and reopens the tool, and a pre-existing window can capture the automation.
* No unsaved work in other applications, and no scheduled task, update, or notification popup expected during the run.
* An uninterrupted window of operator time, because the operator must not use the mouse, keyboard, or switch windows while the loop runs.

Run `--mode probe` first. It confirms the tool is present, trusted, and at the pinned version without performing a validation or feedback run, and it is the cheapest way to catch an environment problem.

#### While the run is active

The harness drives the real TMT window. Once it announces the start of automation, do not use the mouse or keyboard and do not switch windows. The harness reports baseline and refinement candidate progress as it goes, and the loop may open, close, and reopen TMT more than once to complete save and reopen validation. Treat the release notice, emitted when the loop completes or aborts, as the signal that the machine is usable again.

#### Aborting

Press `Ctrl+C` in the terminal running the harness. The harness records a stopped run and writes `status.json`. Closing the TMT window by hand instead is not an abort: the harness reports `unexpected-modal` or `automation-timeout`, and the evidence bundle records a failure that did not happen for the reason it names.

Because the tool may be mid-open, expect to close a stray Threat Modeling Tool window by hand after any abort and before starting another run. An aborted run leaves whatever evidence was already written in place; that partial bundle is diagnostic only and does not satisfy `--require-feedback-evidence`.

#### Reading the outcome

Read `status.json` at the evidence root first. It carries the stop reason and the exit code, and it is written even when the run fails, so a missing `status.json` means the process was killed before it could record an outcome.

| Stop reason                      | Exit | What it means                                                                  | Operator action                                                                                          |
|----------------------------------|------|--------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `automated-ready-pending-human`  | `0`  | Automated gates passed                                                         | Perform the human semantic review before any promotion; this is not an approval                          |
| `repeated-defect-no-improvement` | `8`  | The same defect persisted across iterations without improvement                | Inspect the findings and the published overlay seed; the defect needs a spec, profile, or layout change  |
| `max-iterations`                 | `8`  | The bounded iteration budget was exhausted before the gates cleared            | Review the best candidate manually; more iterations are not available by design                          |
| `evidence-incomplete`            | `7`  | Required per-surface evidence was missing under `--require-feedback-evidence`  | Check the iteration bundles for the missing capture, then rerun on a stable desktop session              |
| `semantic-regression`            | `1`  | A candidate diverged from the baseline model identity                          | Do not promote; treat the overlay as rejected, reconcile the spec, and review the layout intent          |
| `candidate-generation-failed`    | `2`  | Regenerating a candidate from the spec or overlay failed                       | Fix the generation error reported in `status.json`; the model and spec are untouched                     |
| `overlay-validation-failed`      | `2`  | A produced overlay failed its own schema or fingerprint validation             | Report the validation message in `status.json`; the model and spec are untouched                         |
| `harness-error`                  | `2`  | The harness itself failed outside the automation contract                      | Read `status.json` for the failure message; no overlay was published                                     |
| `skipped`                        | `0`  | TMT was absent and `--require-tmt` was not set                                 | None; run on a host with the pinned TMT, or pass `--require-tmt` to make absence a failure               |
| `tmt-unavailable`                | `3`  | TMT was absent or untrusted, or the host is not Windows, under `--require-tmt` | Verify the install and rerun `--mode probe`; the harness refuses untrusted executables                   |
| `version-mismatch`               | `4`  | The discovered TMT is not the pinned version                                   | Install the pinned version or set `--pinned-version` deliberately                                        |
| `automation-timeout`             | `5`  | A UI Automation step exceeded `--timeout-seconds`                              | Confirm the session is unlocked and interactive, then retry; raise `--timeout-seconds` on a slow machine |
| `unexpected-modal`               | `6`  | An unrecognized dialog blocked automation                                      | Inspect the final screenshot in the bundle, reproduce the dialog manually, dismiss its cause, then rerun |

#### Evidence

Every run writes a redacted bundle under `--evidence-dir`. Read `status.json` for the outcome and stop reason, `manifest.json` for the per-surface validation record, `feedback-manifest.json` for the per-surface feedback record, and `action.log` for the automation sequence. Per-iteration screenshots, UIA snapshots, summaries, and the generated candidate model live under `iterations/`. Every evidence path is confined to the evidence directory, and an identifier taken from the spec is reduced to a single safe path segment before it names a file.

Redaction covers text evidence only. Screenshots are pixels and are never redacted, so treat them as the most sensitive artifact in the bundle. Capture is refused unless the host can address a single native window handle; where that is unavailable no screenshot is written, and a run under `--require-feedback-evidence` fails closed rather than continuing without one. Review a bundle before sharing it outside the machine that produced it.

#### Recovery and rollback

The loop never mutates the canonical baseline model or spec and never promotes an overlay, so recovery is bounded:

* To discard a run entirely, delete its evidence directory and the file written to `--overlay-output`. Nothing outside those paths changed, and because generation is deterministic for a given spec and generator version, the baseline can always be regenerated from the spec rather than restored from a copy.
* To retry a failed run, re-run the same command. Evidence directories are per-run; do not reuse one across runs you intend to compare.
* To reuse a good layout, pass the pending overlay from `--overlay-output` back in through `--overlay-input`. If the spec or profile changed since the overlay was written, the fingerprint check rejects it and you regenerate from the baseline instead.
* If a stray Threat Modeling Tool window or a temporary workspace survives an abort, close the window and delete the workspace directory manually. The harness only auto-removes workspaces it marked as its own.

An overlay is only ever promoted by an explicit human action outside this loop. If a pending overlay was promoted and later found wrong, revert the promotion in version control; no harness flag reverses it.

> This schema is an independently authored HVE-Core artifact and is not a verbatim copy of the Open Threat Model (OTM) specification. It is aligned to OTM concepts and terminology for interoperability and was informed by the OTM project maintained by IriusRisk: [OpenThreatModel](https://github.com/iriusrisk/OpenThreatModel). OTM is licensed under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Any adaptation or redistribution should preserve this attribution and apply the same CC BY-SA terms where applicable.

## Canonical input schema

The generator accepts a vendor-neutral YAML or JSON threat-model spec whose top-level structure is intentionally generic and data-driven.

```yaml
project_metadata:
  name: Example service
  version: 1.0
  summary: Generic example threat model
  scope: Service boundary
  assumptions:
    - Traffic flows over a public network
  policy_values:
    cryptography_suites:
      - TLS 1.3
    identity_providers:
      - OpenID Connect compatible identity provider
    data_classification_labels:
      - public
      - internal
      - restricted

representations:
  context_diagrams:
    - id: ctx-01
      name: Context diagram
      description: System boundary and external entities
      elements: []
      flows: []
      trust_zone_ids: []
  functional_scenarios:
    - id: func-01
      name: Primary interaction
      description: Primary use case
      elements: []
      flows: []
      trust_zone_ids: []
  operational_views:
    - id: op-01
      name: Deployment and operations
      description: Managed deployment and operating model
      components: []
      trust_zone_ids: []

assets:
  - id: asset-01
    name: User content
    kind: data
    description: User-supplied content
    sensitivity: internal
    category: Content

components:
  - id: comp-01
    name: Application process
    kind: process
    asset_ids:
      - asset-01
    trust_zone_id: tz-01

trust_zones:
  - id: tz-01
    name: Application boundary
    description: In-scope boundary

data_flows:
  - id: flow-01
    source_ref: ext-01
    target_ref: comp-01
    ordinal: 1
    transport: HTTPS
    encryption: TLS 1.3
    authentication: bearer token
    authorization: scoped access token
    data_sensitivity: internal
    retention: 90 days
    notes: Primary request path

threats:
  - id: threat-01
    target_ref: comp-01
    interaction_ref: flow-01
    category: tampering
    title: Tampering of request payload
    description: An attacker could alter the payload in transit
    state: Open
    citations:
      stride:
        - T
      nist:
        - SC-8
      mitre: []
    mitigation_ids:
      - mitigation-01

mitigations:
  - id: mitigation-01
    name: Payload signature verification
    description: Validate request content integrity
    target_refs:
      - comp-01
    citations:
      nist:
        - SC-8

abuse_cases:
  - id: abuse-01
    title: Replay of a signed request
    description: An attacker reuses a previously valid request
    actor: External adversary
    objective: Bypass intended controls
    evil_user_story: As an authenticated low-privilege user, I want to manipulate the checkout flow so that I can bypass authorization
    flow_ids:
      - flow-01
    mitigation_ids:
      - mitigation-01

security_test_cases:
  - id: test-01
    title: Negative boundary input
    description: Submit malformed input and verify rejection
    target_refs:
      - comp-01
    test_type: negative-input
    expected_result: Request is rejected and logged
```

`security_test_cases[].test_type` takes one of `negative-input`,
`malformed-message`, `multi-step-logic`, or `authorization`. The completeness
check RGAP-05 in the threat-model review reference is keyed to this vocabulary.

### Semantic target and placement interaction

`threats[].target_ref` identifies the component or element whose behavior is
threatened. `threats[].interaction_ref` identifies the concrete data flow used to
place the threat instance in TM7. The semantic target must be the source or target
endpoint of that interaction by default.

When TM7 cannot represent a reviewed component threat without using a nearby
carrier interaction, declare the exception rather than relying on same-surface
coexistence:

```yaml
placement_override:
  reviewed: true
  rationale: The selected interaction is the reviewed TM7 carrier for this component threat.
```

The portable validator rejects non-endpoint placement when the override is absent,
unreviewed, or lacks a rationale. Human review remains required; automated tooling
does not set `reviewed: true` on behalf of a reviewer.

### Data flow endpoints

A data flow must connect two different elements. `source_ref` and `target_ref`
that name the same element are rejected during model construction, and the
diagnostic names every offending flow id in sorted order.

Connector anchors are derived from the two endpoint rectangles, so a
self-referencing flow collapses to a zero-length connector. TMT stores that
connector but draws nothing a reviewer can see or select, which silently removes
a declared interaction from the diagram while the run still exits zero. Model a
loop back into the same component as an explicit intermediate element, or as a
component threat with a reviewed `placement_override`.

### Layout geometry

Segment-to-rectangle contact has one production algorithm. The generator holds
rectangles as `left`/`top`/`width`/`height` mappings and the feedback loop holds
them as `left`/`top`/`right`/`bottom` tuples; both adapt to the same bounds and
call the same test, so published geometry and scored geometry cannot disagree.

Contact is closed on both operands. A connector that runs exactly along a node
border, or that grazes a corner partway along its length, counts as
intersecting, because it overlaps that node visually.

Whole-surface layout candidates are the cross product of orientation and
zone-order variant. Selection returns the first candidate that satisfies the
candidate contract and fails when none does, rather than returning the
best-scored candidate unchecked. A surface with no trust zones yields a fallback
candidate carrying every member of that same contract.

### Authored-base reconciliation

Portable validation operates only on the threat-model specification. When an
existing TMT-authored base is supplied, run a separate reconciliation gate. That
gate verifies that each placement connector exists on its declared surface, all
surface and connector GUIDs are non-null, and connector endpoints match the
authored element identities corresponding to the declared source and target.

A portable pass does not imply that an authored base is complete. Missing elements,
missing connectors, wrong-surface connectors, and endpoint identity drift are
authored-base reconciliation failures.

#### Surface identity

Reconciliation binds an authored drawing surface to its declared surface through
the deterministic surface GUID, which is derived from the declared surface `id`.
Authored order never participates: reordering the drawing surfaces in a base
model cannot rebind a connector to a different diagram. A declared surface with
no matching authored surface, and an authored base that presents the same
declared surface twice, both fail the gate. Authored surfaces that match no
declared surface are ignored, so a base model may carry extra diagrams.

Element identity is resolved per surface. There is no cross-surface element
fallback, so an endpoint drawn on one diagram cannot satisfy a connector on
another.

### Native template upgrades

Treat TMT's `Threat Model Conversion Confirmation` prompt as a controlled
migration boundary. The native harness defaults to `fail` and requires one of
three explicit policies:

* `fail`: preserve the model and report that a newer template is available.
* `decline`: open against the embedded template without changing it.
* `apply`: apply the installed template to a harness-owned working copy.

Apply a newer template to a topology-complete model with zero threat instances,
then populate explicit threats only after the upgraded base passes save/reopen and
authored-base reconciliation. Applying a template after explicit population can
retain the threat rows as stale entries whose interaction is `Deleted`.

TMT's native conversion replaces the embedded KnowledgeBase. When the project
uses deterministic custom threat types, compose the upgraded stock template with
those custom types before population. The harness must verify the expected custom
type count and clean reopen before publishing the composed base.

Stale-threat deletion is independent from template application and remains off by
default. Enable it only through the explicit `--delete-stale-threats` option after
reviewing the impact on human-authored threat notes and state.

### CTM field inventory

| CTM    | Field path                                                                                                                                                                                       | Notes                                                              |
|--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| CTM-1  | `representations.context_diagrams`                                                                                                                                                               | Context/system view with external entities and boundaries          |
| CTM-2  | `representations.functional_scenarios`                                                                                                                                                           | Functional/scenario view with trust boundaries and data flows      |
| CTM-3  | `representations.operational_views`                                                                                                                                                              | Deployment and operating context                                   |
| CTM-4  | `threats` and `mitigations`                                                                                                                                                                      | Threat analysis with mitigations                                   |
| CTM-5  | `data_flows[].ordinal`                                                                                                                                                                           | Numbered flows                                                     |
| CTM-6  | `data_flows[].transport`, `data_flows[].encryption`, `data_flows[].authentication`, `data_flows[].authorization`, `data_flows[].data_sensitivity`, `data_flows[].retention`, `assets[].category` | Per-flow annotation fields and optional asset classification hints |
| CTM-7  | `threats[].state`, `threats[].citations`, `mitigations`                                                                                                                                          | Reviewable triage and status                                       |
| CTM-8  | `abuse_cases`, `abuse_cases[].evil_user_story`                                                                                                                                                   | Abuse-case and evil-user-story capture                             |
| CTM-9  | `security_test_cases`                                                                                                                                                                            | Negative and boundary-test artifacts                               |
| CTM-10 | `project_metadata`, `representations`, `threats`, `mitigations`, `abuse_cases`, `security_test_cases`                                                                                            | The complete spec must be rich enough to emit a reviewable model   |

## CTM-to-carrier mapping

| CTM    | Input field(s)                                                                                             | OTM-like carrier                          | TM7 carrier                                                              |
|--------|------------------------------------------------------------------------------------------------------------|-------------------------------------------|--------------------------------------------------------------------------|
| CTM-1  | `representations.context_diagrams`                                                                         | representation and trust-zone context     | drawing surface with external-interactor/process/store/boundary elements |
| CTM-2  | `representations.functional_scenarios`                                                                     | scenario-oriented representation          | drawing surface with flow and boundary geometry                          |
| CTM-3  | `representations.operational_views`                                                                        | operational representation                | drawing surface with deployment-oriented components                      |
| CTM-4  | `threats`, `mitigations`                                                                                   | threats and mitigations                   | threat instances plus notes/properties                                   |
| CTM-5  | `data_flows[].ordinal`                                                                                     | numbered dataflow ordering                | connector properties and labels                                          |
| CTM-6  | `data_flows[].transport`, `encryption`, `authentication`, `authorization`, `data_sensitivity`, `retention` | dataflow attributes                       | connector properties                                                     |
| CTM-7  | `threats[].state`, `threats[].citations`                                                                   | review state and evidence                 | threat state and citation-bearing notes/properties                       |
| CTM-8  | `abuse_cases`                                                                                              | adversary narrative                       | threat entries and notes                                                 |
| CTM-9  | `security_test_cases`                                                                                      | test-plan evidence                        | notes or cross-references in the generated markdown twin                 |
| CTM-10 | whole spec                                                                                                 | complete threat-model interchange payload | the generated `.tm7` file itself                                         |

## Verified TM7 wire facts

### Namespaces

The generator uses the namespaces verified against the Threat Modeling Tool's own `SerializableModelData` DataContract (`ThreatModeling.ExternalStorage.OM.SerializableModelData`, serialized as `<ThreatModel>` in the Model namespace):

* Model namespace: `http://schemas.datacontract.org/2004/07/ThreatModeling.Model`
* Abstracts namespace: `http://schemas.datacontract.org/2004/07/ThreatModeling.Model.Abstracts`
* KnowledgeBase namespace: `http://schemas.datacontract.org/2004/07/ThreatModeling.KnowledgeBase`
* Serialization arrays namespace: `http://schemas.microsoft.com/2003/10/Serialization/Arrays`
* XML schema-instance namespace: `http://www.w3.org/2001/XMLSchema-instance`

### Element and threat serialization rules

These rules reflect the DataContract graph verified against the Threat Modeling Tool's own serializer: `SerializableModelData.GetSerializer()` deserializes the generated file with no `SerializationException`. They were extracted from a genuine, TMT-loadable reference export (`tests/fixtures/tmt-reference.tm7`), not a reverse-engineered inference.

* Each `DrawingSurfaceModel` carries the base fields `GenericTypeId` (`DRAWINGSURFACE`), `Guid`, `Properties`, `TypeId`, then `Borders`, `Header`, `Lines`, and a trailing `Zoom` (default `1`).
* Every `Properties` display attribute is an `a:anyType` with a polymorphic `i:type` (`b:HeaderDisplayAttribute` or `b:StringDisplayAttribute`) in the KnowledgeBase namespace. Because `StringDisplayAttribute.Value` is typed as `object`, a present `<b:Value>` **must** carry `i:type="c:string"` (xsd:string); omitting the type hint makes the DataContract serializer reject the file with `Element Value ... cannot have child contents to be deserialized as an object`. `HeaderDisplayAttribute` uses an empty `<b:Name/>` and `<b:Value i:nil="true"/>`; `StringDisplayAttribute` sets `<b:Name>` to the property key.
* Shapes are stored in `Borders` as a GUID-keyed dictionary of `a:KeyValueOfguidanyType` entries (in the Serialization Arrays namespace). Each `a:Value` carries a polymorphic `i:type` of `StencilRectangle` (external interactor, `GE.EI`), `StencilEllipse` (process, `GE.P`), `StencilParallelLines` (data store, `GE.DS`), or `BorderBoundary` (trust boundary box, `GE.TB.B`), plus base fields `GenericTypeId`, `Guid`, `Properties`, `TypeId` and geometry `Height`, `Left`, `StrokeDashArray`, `StrokeThickness`, `Top`, `Width`.
* Data flows are stored in `Lines` as `a:KeyValueOfguidanyType` entries whose `a:Value` uses `i:type="Connector"` (`GE.DF`) with `SourceGuid`, `SourceX`, `SourceY`, `TargetGuid`, `TargetX`, `TargetY`, `HandleX`, `HandleY`, and `StrokeThickness`. An unconnected endpoint uses the all-zero GUID sentinel `00000000-0000-0000-0000-000000000000`.
* The root model carries, in order, `DrawingSurfaceList`, `MetaInformation`, `Notes`, `ThreatInstances`, `ThreatGenerationEnabled`, `Validations`, `Version`, `KnowledgeBase`, and `Profile` (`<Profile><PromptedKb xmlns=""/></Profile>`).
* The verified `Version` string is `4.3`. All `z:Id` values form a single contiguous sequence: diagram objects are numbered `i1..iN` in document order, and the embedded `KnowledgeBase` root `z:Id` is renumbered to `i(N+1)` at generation time. Because no `z:Ref` targets the KnowledgeBase root, this keeps every id unique with no model-size ceiling. A fixed start offset would instead cap a diagram at the object count below that offset.

### Threats, the embedded KnowledgeBase, and citations

A loadable `.tm7` derives its threats from an embedded DataContract KnowledgeBase, exactly as the reference file does. It does not hand-serialize threat instances.

* With the default flags, generated output emits an empty `<ThreatInstances/>` and `<ThreatGenerationEnabled>false</ThreatGenerationEnabled>`, matching the loadable reference, and TMT generates threats from the embedded KnowledgeBase when the model is opened. This is a consequence of the flag defaults rather than a fixed property of the format; see [Mode-flag behavior](#mode-flag-behavior) for the cases that populate the element.
* The generator embeds a verbatim DataContract `<KnowledgeBase>` from the bundled `assets/templates/default-kb.xml` asset. That asset was extracted from the genuine TMT reference export; it is Azure-flavored but includes the generic `GE.*` stencils this generator emits. Swapping in a smaller MIT SDL-core DataContract KnowledgeBase is tracked as follow-up work.
* Per-threat STRIDE + NIST SP 800-53 (+ optional MITRE ATT&CK/CAPEC) citations are surfaced in the synchronized markdown twin (`generate_markdown.py`), which reuses the generator's deterministic threat derivation. The `threats[].citations` field in the input spec remains the source-of-truth structure for those citations.
* The `bundled .tb7` under `assets/templates/` is a no-namespace XmlSerializer template and is NOT spliced into the `.tm7` directly; the DataContract `default-kb.xml` is the embeddable KnowledgeBase.

## STRIDE-per-element matrix

| Element kind        | Baseline STRIDE categories                                                                          |
|---------------------|-----------------------------------------------------------------------------------------------------|
| External interactor | Spoofing                                                                                            |
| Process             | Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege |
| Data store          | Tampering, Information Disclosure, Denial of Service, Repudiation for logging stores                |
| Data flow           | Tampering, Information Disclosure, Denial of Service                                                |
| Trust boundary      | No direct threat by itself; use it as a grouping and routing anchor                                 |

## Mode-flag behavior

Two independent controls decide what lands in `<ThreatInstances>`: the `--mode` flag and the `--threat-generation-enabled` flag. They are not aliases for each other and must not be treated as one control.

| `--mode`                      | `--threat-generation-enabled` | `<ThreatInstances>` content                                  |
|-------------------------------|-------------------------------|--------------------------------------------------------------|
| `pre-populated-comprehensive` | absent (default)              | The threats declared in the spec's own `threats:` list       |
| `pre-populated-comprehensive` | present                       | A synthesized STRIDE-per-element set derived from the model  |
| `diagram-only-defer-to-tmt`   | absent or present             | Always empty; TMT generates threats when the model is opened |

`pre-populated-comprehensive` is the default mode. In its default flag state it does not synthesize anything: it maps the spec's declared threats onto the resolved model elements and flows, and it fails closed when a declared `target_ref` resolves to no element or flow. A spec that declares no threats therefore produces an empty `<ThreatInstances/>` in either mode, which is why the bundled example template generates an empty element.

The serialized `<ThreatGenerationEnabled>` field is a separate value read from `--threat-generation-enabled` when supplied, otherwise from the spec's `threat_generation_enabled` key, and it defaults to `false`. Note that the same flag name drives two consumers: it switches the generator into STRIDE synthesis, and it sets the field TMT reads to decide whether to auto-generate its own threats. Leaving it at the default keeps the generator and TMT from populating the same threat set twice.

### Threat-instance identity

Every spec-sourced threat must reach `<ThreatInstances>`. A threat whose `interaction_ref` resolves to no model flow, or whose flow lacks a `SourceGuid`, `FlowGuid`, or `TargetGuid`, fails generation and names every affected threat in one sorted diagnostic. The generator also reconciles the emitted instance count against the spec-sourced threat count, so a partial array cannot ship.

The serialized `<Id>` member is the identifier reviewers and CSV exports cite, so it is derived rather than positional. The generator takes the SHA-256 digest of the UTF-8 bytes of the exact normalized source threat id and maps it into the closed interval `[1, 2147483647]`, which is the positive half of the signed 32-bit range TMT stores. Zero stays reserved as the unassigned sentinel. Because the identifier depends only on the source id, it survives insertion, reordering, and separate processes. Two source ids that derive the same numeric id fail generation deterministically, naming both.

## Template-profile abstraction

The generator should support a pluggable profile abstraction where each profile maps generic DFD semantics to a concrete template's stencil `TypeId` values and a knowledge-base reference.

```yaml
template_profiles:
  sdl_core_generic:
    description: Generic SDL/Core profile for broad threat modeling
    asset_source: microsoft/threat-modeling-templates/default.tb7
    knowledge_base: default
    type_ids:
      external_interactor: GE.EI
      process: GE.P
      data_store: GE.DS
      data_flow: GE.DF
      trust_boundary_line: GE.TB.L
      trust_boundary_box: GE.TB.B
      annotation: GE.A
```

### Default shipped profile

The default profile is the generic SDL/Core profile and uses the verified generic stencil TypeIds:

* External interactor: `GE.EI`
* Process: `GE.P`
* Data store: `GE.DS`
* Data flow: `GE.DF`
* Trust boundary line: `GE.TB.L`
* Trust boundary box: `GE.TB.B`
* Annotation: `GE.A`

### Reference-only profile tables

The following profiles are documented as mapping-table references and are not bundled as redistributed template files because they are either domain-specific or not confirmed as bundled MIT artifacts.

| Profile         | Status                       | Notes                                                                                                                                                                    |
|-----------------|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Azure           | Reference-only mapping table | Public Azure-oriented profile with examples such as `SE.P.TMCore.AzureAppServiceWebApp`, `SE.P.TMCore.AzureAD`, and `SE.P.TMCore.Host` from public tooling documentation |
| PatrickGallucci | Reference-only mapping table | Public profile catalog with a richer cloud-oriented threat vocabulary; keep as a mapping-table reference until a confirmed redistribution path is chosen                 |

## Standards rationale and public citations

The generated TM7 file and its markdown twin are justified by public, vendor-neutral standards and guidance:

* OWASP Threat Modeling Cheat Sheet: DFD completeness, trust boundaries, data flows, data stores, processes, and external entities. Source: <https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html>
* OWASP Abuse Case Cheat Sheet: abuse cases, adversary narratives, and security test cases. Source: <https://cheatsheetseries.owasp.org/cheatsheets/Abuse_Case_Cheat_Sheet.html>
* Threat Modeling Manifesto: methodology-neutral review questions and representation-driven analysis. Source: <https://www.threatmodelingmanifesto.org/>
* NIST Risk Management Framework: data-sensitivity and impact-based categorization. Source: <https://csrc.nist.gov/Projects/risk-management/about-rmf>
* MITRE ATT&CK and CAPEC: optional enrichment for abuse-case-driven threats. Source: <https://attack.mitre.org/> and <https://capec.mitre.org/>

The extension therefore uses a vendor-neutral, standards-aligned input contract and preserves traceability in the emitted TM7 model without copying the upstream OTM schema text.

## Verifying TMT deserialization

Generated files are validated against the Threat Modeling Tool's own assemblies rather than a hand-crafted schema. `scripts/Deserialize-Tm7.ps1` locates the installed `ThreatModeling.ExternalStorage.Local.dll`, verifies each candidate assembly carries a valid Microsoft Authenticode signature before loading it, obtains the exact `DataContractSerializer` from `SerializableModelData.GetSerializer()`, and calls `ReadObject` on a target `.tm7`. The TMT assemblies are 32-bit, so the harness re-launches itself under the 32-bit Windows PowerShell host when invoked from a 64-bit process. It prints `DESERIALIZE_OK` (exit 0) on success, `DESERIALIZE_FAIL: <message>` (exit 1) on a contract mismatch, and `TMT_ASSEMBLIES_NOT_FOUND` (exit 3) when the tool is not installed.

The pytest suite drives this harness in `test_given_generated_tm7_when_deserialized_by_tmt_then_round_trips` for both generation modes and against the reference fixture. The tests skip cleanly on non-Windows hosts or when the assemblies are absent (for example, in CI) and run automatically when the tool is installed locally. Structural-parity tests additionally assert that the generated root and `DrawingSurfaceModel` member order match `tests/fixtures/tmt-reference.tm7`.
