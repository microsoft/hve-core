---
title: Threat Dragon Generation Contract
description: CLI contract, spec-to-native mapping, placement, rendering, and validation rules for exporting a threat-model spec to OWASP Threat Dragon v2.6.2.
ms.date: 2026-10-06
ms.topic: reference
---

## Threat Dragon generation reference

The `security-planning` skill exports the same YAML or JSON threat-model spec
that drives TM7 generation to an
[OWASP Threat Dragon](https://github.com/OWASP/threat-dragon) v2.6.2 JSON model.
The export is one-way: Threat Dragon edits are not read back into the spec. Only
Threat Dragon v2.6.2 is targeted, and TM-BOM output is out of scope.

The generator reuses `load_spec`, `resolve_profile`, and `build_tm7_payload` from
`generate_tm7.py`. Spec validation, zone hierarchy checks, element and threat
target resolution, and diagram geometry therefore come from TM7, and a Threat
Dragon diagram uses the same deterministic layout as its TM7 drawing surface.

## Entry points

| Script                              | Purpose                                               | Exit codes                                      |
|-------------------------------------|-------------------------------------------------------|-------------------------------------------------|
| `scripts/generate_threat_dragon.py` | Generate a validated model from a spec                | 0 success, 2 generation or validation error     |
| `scripts/validate_threat_dragon.py` | Validate any Threat Dragon model without modifying it | 0 valid, 1 invalid model, 2 usage or read error |

```bash
uv run --project "<security-planning-skill-root>" \
  python "<security-planning-skill-root>/scripts/generate_threat_dragon.py" \
  ./specs/model.yaml -o ./artifacts/model.threat-dragon.json

uv run --project "<security-planning-skill-root>" \
  python "<security-planning-skill-root>/scripts/validate_threat_dragon.py" \
  ./artifacts/model.threat-dragon.json
```

Resolve `<security-planning-skill-root>` from the loaded skill location before
running either command.

`-o` defaults to `out.threat-dragon.json` in the working directory. The caller
chooses the path. Generated models are build output, regenerated on demand and
not committed, the same as `.tm7` files.

The generator serializes to a sibling temporary file, validates that file, and
only then replaces the destination with `os.replace`. A model that fails
validation never reaches the destination, so an existing output stays intact.
Output is deterministic: the same spec and generator version produce identical
bytes, with UTF-8, two-space indentation, and LF line endings.

## Validation

`validate_threat_dragon.py` checks a model against the vendored
[v2.6.2 schema](../assets/threat-dragon/threat-dragon-v2.6.2.schema.json) and its
[provenance record](../assets/threat-dragon/threat-dragon-v2.6.2.provenance.json).
The schema check runs in-module, so the skill needs no extra runtime dependency.
It implements every keyword the vendored schema uses, including Threat Dragon's
non-standard `nullable`, and fails closed on any keyword it does not implement.

Semantic rules:

* Root and diagram `version` are `2.6.2`, `diagramType` is `STRIDE`, and the
  thumbnail is `./public/content/images/thumbnail.stride.jpg`.
* Diagram `id` values are their zero-based positions and `diagramTop` equals the
  diagram count.
* Model, cell, and threat identifiers are UUID version 5 values, unique across
  the model.
* Flow endpoints resolve to node cells in the same diagram, and
  `trustBoundaryIds` resolve to boundary cells.
* Trust boundaries carry no threats, and `hasOpenThreats` matches the attached
  threats.
* Status, severity, STRIDE type, shape, and `data.type` use the native
  vocabulary.
* Threat numbers are contiguous from 0 and `threatTop` is the highest number.

The validator reports every schema error found, capped at 50, followed by the
first semantic error, with JSON paths and element names.

## Spec mapping

### Model and diagrams

| Native path           | Source                                                               |
|-----------------------|----------------------------------------------------------------------|
| `summary.title`       | `project_metadata.name`                                              |
| `summary.owner`       | `project_metadata.owner`, or an empty string                         |
| `summary.description` | `project_metadata.summary` followed by the shared disclaimer         |
| `summary.id`          | UUID v5 of the project name                                          |
| `detail.diagrams`     | One diagram per laid-out representation, in TM7 surface order        |
| `diagram.title`       | Representation `name`                                                |
| `diagram.description` | Representation `description` plus an `HVE-Core representation` block |

Representations are ordered as TM7 orders them: context diagrams, then
functional scenarios, then operational views.

### Elements and zones

| Spec kind             | Native `shape`       | Native `data.type` |
|-----------------------|----------------------|--------------------|
| `external_interactor` | `actor`              | `tm.Actor`         |
| `process`             | `process`            | `tm.Process`       |
| `data_store`          | `store`              | `tm.Store`         |
| Trust zone            | `trust-boundary-box` | `tm.BoundaryBox`   |

Position and size come from TM7's laid-out rectangles, rounded to two decimal
places. TM7 model units are used directly as Threat Dragon canvas pixels.

Each trust zone drawn on a surface becomes one boundary box. Nested zones keep
their TM7 rectangles, and parent boxes take a lower `zIndex` than their children
so a child box draws on top. A box's `containedElements` lists every node in
the zone or a descendant zone, and `crossingFlows` lists the flows with exactly
one endpoint inside it.

Any other element kind, such as `trust_boundary_line`, fails generation with exit
code 2 and a message naming the element and its kind. TM7 emits box-only
boundaries and produces no line endpoint geometry.

Node `description` comes from the component or inline element `description`.
`out_of_scope` and `out_of_scope_reason` map to `outOfScope` and
`reasonOutOfScope`. A node without `out_of_scope` is in scope, which is Threat
Dragon's own default.

### Data flows

| Native path             | Source                                       |
|-------------------------|----------------------------------------------|
| `data.name`             | `label`, or the flow ID                      |
| `data.description`      | `notes`                                      |
| `data.protocol`         | `transport`, omitted when empty              |
| `data.isBidirectional`  | `bidirectional`, omitted when absent         |
| `data.isEncrypted`      | `encrypted`, omitted when absent             |
| `data.isPublicNetwork`  | `public_network`, omitted when absent        |
| `data.trustBoundaryIds` | Sorted IDs of boxes the flow crosses         |
| `source`, `target`      | Node cells for `source_ref` and `target_ref` |

Flows use the `smooth` connector with no vertices, so Threat Dragon routes them
between the laid-out nodes.

### Optional fields and Threat Dragon options

The optional spec fields are defined in
[tm7-generation.md](tm7-generation.md#optional-security-facts-for-other-exporters).
An absent field is unknown. The generator omits the native property or uses
`TBD`, and never writes `false` for a missing fact. A present field with the
wrong type, or a level outside its vocabulary, fails generation.

`export_options.threat_dragon.elements` maps an element ID to native properties
that apply only to its kind:

| Spec option                 | Element kind          | Native property          |
|-----------------------------|-----------------------|--------------------------|
| `provides_authentication`   | `external_interactor` | `providesAuthentication` |
| `is_web_application`        | `process`             | `isWebApplication`       |
| `handles_card_payment`      | `process`             | `handlesCardPayment`     |
| `handles_goods_or_services` | `process`             | `handlesGoodsOrServices` |
| `privilege_level`           | `process`             | `privilegeLevel`         |
| `is_a_log`                  | `data_store`          | `isALog`                 |
| `is_encrypted`              | `data_store`          | `isEncrypted`            |
| `is_signed`                 | `data_store`          | `isSigned`               |
| `stores_credentials`        | `data_store`          | `storesCredentials`      |
| `stores_inventory`          | `data_store`          | `storesInventory`        |

`privilege_level` is a string; every other option is a boolean. An unknown
option, an element ID that is not drawn, or an option for the wrong kind fails
generation.

## Threats

### Placement

Each threat in the TM7 payload is attached exactly once, to the cell for its
`target_ref`, which may be a node or a flow. When the target appears on more
than one representation, the threat goes on the first representation that also
contains its `interaction_ref` flow. Otherwise it goes on the first
representation that contains the target. A target drawn on no representation
fails generation.

Threats are numbered from 0 in diagram, cell, then payload order, and
`threatTop` is the highest number.

When `threat_generation_enabled` is `true`, the STRIDE threats TM7 generates for
elements and flows are exported like declared threats. TM7 generates them once
for each representation that draws the target, so Threat Dragon keeps the first
copy of each threat ID. Abuse-case threats that
TM7 derives from `abuse_cases` are left out, because every Threat Dragon threat
needs one of the six STRIDE types and an abuse case has none. Abuse cases stay
in the spec and in the TM7 and Markdown outputs.

### Field mapping

| Native path   | Source                                                                           |
|---------------|----------------------------------------------------------------------------------|
| `id`          | UUID v5 of the threat ID                                                         |
| `threatId`    | Threat `id`                                                                      |
| `title`       | `title`                                                                          |
| `description` | `description` plus the hve-core context block                                    |
| `type`        | STRIDE type from `category`                                                      |
| `modelType`   | `STRIDE`                                                                         |
| `status`      | Native status from `state`                                                       |
| `severity`    | Native severity from `severity` or `risk`                                        |
| `mitigation`  | `mitigation_ids` resolved through the spec `mitigations`, joined with semicolons |

| Spec `category`          | Native `type`            |
|--------------------------|--------------------------|
| `spoofing`               | `Spoofing`               |
| `tampering`              | `Tampering`              |
| `repudiation`            | `Repudiation`            |
| `information-disclosure` | `Information disclosure` |
| `denial-of-service`      | `Denial of service`      |
| `elevation-of-privilege` | `Elevation of privilege` |

Status first canonicalizes `state` through the TM7 threat contract's state
aliases, so an unsupported state fails generation exactly as it does for TM7.
Canonical `Mitigated` maps to `Mitigated` and `NotApplicable` to
`NotApplicable`. Every other canonical state, including `NeedsInvestigation`,
`NeedsMitigation`, and `AutoGenerated`, maps to `Open`.

Severity uses `severity` when present. Otherwise it uses `risk`, with
`informational` mapping to `Low`. When both are absent, severity is `TBD`.

The context block preserves facts Threat Dragon has no field for:

```text
HVE-Core context
Threat ID: T-100
State: Partially Mitigated
Likelihood: Medium
Impact: High
Risk: High
STRIDE: T
NIST: SI-10
MITRE: None
Placement flow: flow-browse
```

Unknown likelihood, impact, and risk show `TBD`, and empty citation lists show
`None`. The `Placement flow` line appears only when `interaction_ref` differs
from `target_ref`.

## Canvas attributes

Threat Dragon v2.6.2 draws labels and strokes from each cell's `attrs` and
`labels`, and copies `data.name` and threat styling into them only when a cell is
edited. The generator therefore writes them directly:

| Shape                | Label path                   | Stroke paths                        |
|----------------------|------------------------------|-------------------------------------|
| `actor`, `process`   | `attrs.text.text`            | `attrs.body`                        |
| `store`              | `attrs.text.text`            | `attrs.topLine`, `attrs.bottomLine` |
| `trust-boundary-box` | `attrs.label.text`           | None                                |
| `flow`               | `labels[0].attrs.label.text` | `attrs.line`                        |

| Condition                | `stroke`  | `strokeWidth` | `strokeDasharray` |
|--------------------------|-----------|---------------|-------------------|
| No open threats          | `#333333` | `1.5`         | `null`            |
| At least one open threat | `red`     | `2.5`         | `null`            |
| Node out of scope        | Unchanged | Unchanged     | `4 3`             |

Flows always use a `block` target marker. The source marker is `block` only when
`bidirectional` is `true`, so a one-way flow draws a single arrowhead.

## Native loader check

`tests/test_threat_dragon_loader.py` proves the golden models load and render in
real Threat Dragon v2.6.2 code. It needs Git, Node.js, npm, and network access,
so it runs only when `THREAT_DRAGON_LOADER=1`. It checks out OWASP Threat Dragon
at commit `8c0edb2295a1587684324646c8507fd56ba9a197`, runs `npm ci` in `td.vue`,
and runs `tests/harness/threat-dragon-v2.6.2-loader.spec.js` with that
checkout's Jest. Set `THREAT_DRAGON_CHECKOUT` to reuse an installed checkout of
the same commit.

The spec asserts native v2 detection with no migration path, no upstream schema
errors, acceptance by the `THREATMODEL_SELECTED` store mutation, and labels,
strokes, and source markers read back through Threat Dragon's registered X6
shapes.

Golden models under `tests/fixtures/threat-dragon/expected/` are regenerated with the
generator whenever TM7 layout or the mapping changes.

## Attribution

The vendored schema is an unmodified copy of
`td.vue/src/assets/schema/threat-dragon-v2.schema.json` from OWASP Threat Dragon
v2.6.2, licensed under the Apache License, Version 2.0. The licence text and a
third-party notice ship beside it in `assets/threat-dragon/`. The mapping in this
document is original hve-core content describing the export contract.
