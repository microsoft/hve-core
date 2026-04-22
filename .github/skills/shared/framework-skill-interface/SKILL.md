---
name: framework-skill-interface
description: 'Authoring guide for Framework Skills — the host-agent-neutral packaging format for framework specifications (controls, criteria, principles, capabilities) consumed by HVE Core planners and reviewers. Use when importing a third-party framework (NIST, CIS, OWASP, internal org spec) into a domain skills directory, when extending an existing Framework Skill, or when validating a manifest. Pairs with the Prompt Builder agent and Researcher Subagent — this skill provides the contract; the agents drive the authoring workflow. - Brought to you by microsoft/hve-core'
license: MIT
user-invocable: true
compatibility: 'Requires PowerShell 7+ with the powershell-yaml module for manifest validation'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-20"
---

# Framework Skill Authoring Skill

## Overview

A Framework Skill packages a single framework specification — a set of controls, criteria, principles, capabilities, or document-section templates — as machine-readable YAML that any HVE Core host agent can enumerate and consume. The pattern is host-neutral: the same Framework Skill shape serves planners (SSSC, RAI), reviewers, importers, or any future agent that needs structured framework data.

Use this skill when you need to:

* Import a published framework (NIST SP 800-218, CIS Benchmarks, OWASP Top 10, an internal org standard) into a domain skills directory.
* Extend or revise an existing Framework Skill (new control, version bump, phase remap).
* Validate a manifest you received from an external author or AI-assisted import.

This skill does NOT execute the import — it documents the contract. Drive the authoring workflow through the [Prompt Builder](../../../agents/hve-core/prompt-builder.agent.md) agent (which orchestrates research, drafting, evaluation) using the [Researcher Subagent](../../../agents/hve-core/subagents/researcher-subagent.agent.md) for source retrieval.

## Framework Skill Layout

Framework Skills live under a domain root. The conventional repo location is `.github/skills/<domain>/<framework-id>/`, but host agents that accept `-AdditionalRoots` (see [Discovery](#discovery)) can load Framework Skills from any directory the user controls — org-shared paths, `.copilot-tracking/framework-imports/`, a sibling repo, etc.

```text
<root>/<framework-id>/
├── SKILL.md            # Optional: human-facing skill page (recommended for built-ins)
├── index.yml           # REQUIRED: manifest validated against framework-skill-manifest.schema.json
└── items/              # Per-item YAML files; one file per id listed in phaseMap
    ├── <id>.yml
    └── ...
```

Notes:

* `<framework-id>` is lower-kebab and SHOULD match the `framework` value in `index.yml`.
* `<domain>` is lower-kebab and is inferred from the parent directory when `domain:` is omitted from the manifest.

## Manifest Contract (`index.yml`)

The manifest is validated by `scripts/linting/schemas/framework-skill-manifest.schema.json` (draft-2020-12, `additionalProperties: false`).

| Field       | Required | Notes                                                                                                                                                                                                           |
|-------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `framework` | yes      | Lower-kebab identifier matching the directory name.                                                                                                                                                             |
| `version`   | yes      | Free-form version string (semver, framework-native revision, date).                                                                                                                                             |
| `summary`   | yes      | Plain-English one-sentence description (≤120 chars) shown in user-facing enumeration prompts (for example, the SSSC Phase 1 Framework Applicability Gate). Avoid bare acronyms.                                 |
| `phaseMap`  | yes      | Map of host-defined phase labels → ordered list of item ids. Phase names are opaque strings owned by the consuming agent.                                                                                       |
| `domain`    | no       | Lower-kebab domain label. Inferred from parent directory when omitted.                                                                                                                                          |
| `itemKind`  | no       | Hint describing item file shape (`control`, `criterion`, `principle`, `capability`, `document-section`, etc.). Default of `control` is a host convention; the schema does not enforce it.                       |
| `status`    | no       | `draft` or `published` (schema default `published`). Hosts skip drafts unless explicitly opted in. New imports SHOULD start as `draft`.                                                                         |
| `metadata`  | yes      | Provenance and licensing block. The `authority`, `license`, `attributionRequired` keys are required; `licenseUrl` is required unless `license` is a public-domain sentinel; `attributionText` is required when `attributionRequired: true`. See [Licensing and Attribution](#licensing-and-attribution). |
| `globals`   | no       | Map of variable names to descriptor objects. Keys match `[A-Za-z_][A-Za-z0-9_]*`; values are objects with optional `description` (string) and `required` (boolean) fields. See [Globals Shape](#globals-shape). |
| `pipeline`  | no       | Optional ordered execution graph describing the stages a host runs end-to-end and the artifacts they exchange. See [Pipeline Shape](#pipeline-shape).                                                           |
| `governance` | yes     | Ownership, review cadence, and lifecycle status block. See [Governance](#governance).                                                                                                                          |
| `requiredSkills` | no  | Optional list of companion skills this Framework Skill calls (for example shared utilities used at a particular stage). See [Cross-Skill References](#cross-skill-references-requiredskills).                |

Example:

```yaml
framework: my-internal-spec
version: "2026.1"
summary: 'Internal organizational baseline for access control and audit logging on customer-facing services.'
domain: security
itemKind: control
status: draft
phaseMap:
  standards-mapping:
    - access-control
    - audit-logging
  gap-analysis:
    - access-control
    - audit-logging
metadata:
  source: https://example.com/spec.pdf
  imported_by: prompt-builder
  imported_at: "2026-03-16T12:00:00Z"
  review_required: true
```

### Licensing and Attribution

Every Framework Skill manifest MUST declare the licensing fields below under `metadata`. The validator (`scripts/linting/Validate-FsiContent.ps1`) enforces three rules: license presence, attribution coherence, and redistribution-vs-content coherence. Aggregated `attributionText` from every shipping bundle drives the repo-root `THIRD-PARTY-NOTICES` file via `npm run plugin:generate`.

| Field                         | Required | Notes                                                                                                                                                                                                                              |
|-------------------------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `authority`                   | yes      | Publishing authority that owns the upstream framework (for example `OpenSSF`, `NIST`, `CISA`, `W3C`, `microsoft/hve-core`). Used by `THIRD-PARTY-NOTICES` aggregation and audit reporting. Multi-author works MAY use a comma list. |
| `license`                     | yes      | Canonical SPDX identifier (`MIT`, `Apache-2.0`, `CC-BY-4.0`, `CC-BY-3.0`, `CC0-1.0`, etc.) or one of the case-sensitive sentinels `public-domain` and `US-Gov-Public-Domain`. Use the sentinel only when the work is not subject to copyright. |
| `licenseUrl`                  | conditional | Canonical URL to the license text. Required when `license` is not a public-domain sentinel; omit (or it is ignored) for the sentinels.                                                                                          |
| `attributionRequired`         | yes      | Boolean. `true` when redistribution requires an attribution notice (most permissive and Creative Commons licenses). Drives `THIRD-PARTY-NOTICES` inclusion.                                                                        |
| `attributionText`             | conditional | Verbatim attribution snippet aggregated into `THIRD-PARTY-NOTICES`. Required (non-empty) when `attributionRequired: true`.                                                                                                      |
| `redistribution`              | no       | Object with boolean keys `textVerbatim`, `idsAndUrlsOnly`, `derivedSummariesPermitted`. Per-item files MAY further constrain (for example mark a single item as ids-only) but MUST NOT relax these flags.                          |

The validator parameter `-MaxItemBodyChars` (default 200) governs the redistribution coherence rule: when `redistribution.textVerbatim` is `false` or `redistribution.idsAndUrlsOnly` is `true`, no per-item `body`, `text`, or `description` field may exceed the threshold.

Example `metadata` block:

```yaml
metadata:
  authority: OpenSSF
  license: Apache-2.0
  licenseUrl: https://www.apache.org/licenses/LICENSE-2.0
  attributionRequired: true
  attributionText: "OpenSSF Scorecard — Copyright OpenSSF, licensed under Apache-2.0."
  redistribution:
    textVerbatim: true
    idsAndUrlsOnly: false
    derivedSummariesPermitted: true
```

### Globals Shape

`globals` is a map where keys are variable names and values are descriptor objects. The schema uses `additionalProperties: true`, so custom descriptor fields are allowed. By convention, descriptors include:

* `description` — Human-readable explanation of the variable.
* `required` — Boolean indicating whether the host must collect a value before rendering (default `false`).

```yaml
globals:
  product_name:
    description: "Product or feature name used across all sections"
    required: true
  team_owner:
    description: "Team responsible for delivery"
```

Hosts resolve `{{var}}` tokens in `document-section` templates against this map after checking item-local `inputs`. See [Resolution Order](#resolution-order) for precedence rules.

### Governance

`governance` declares ownership, review cadence, and optional deprecation/style metadata for the bundle. The block is required on every FSI manifest (DN-03); hosts surface it in audit reports and the governance-review-currency lint reads it to flag stale bundles.

```yaml
governance:
  owners:
    - "@microsoft/hve-core"
  review_cadence: "P180D"
  last_reviewed: "2026-04-21"
```

Optional fields:

```yaml
governance:
  owners:
    - "@microsoft/hve-core"
  review_cadence: "P180D"
  last_reviewed: "2026-04-21"
  deprecation:
    status: active                          # active | deprecated | sunset
    replacement: "security/<other-skill>"  # optional pointer to the successor bundle
    sunset_date: "2027-01-01"              # optional ISO date
  style_guide: "https://example.com/style" # optional URI to authoring style guide
```

| Field            | Required | Type                            | Description                                                                                                                                                |
|------------------|----------|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `owners`         | yes      | array of strings (`minItems: 1`, unique) | CODEOWNERS-style handles, team names, or org identifiers responsible for keeping the bundle current.                                              |
| `review_cadence` | yes      | string (ISO 8601 duration)      | Maximum interval between reviews. Examples: `P90D`, `P6M`, `P1Y`. Must match `^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$`.                |
| `last_reviewed`  | yes      | string (`format: date`)         | ISO 8601 `YYYY-MM-DD` date the bundle was last reviewed.                                                                                                   |
| `deprecation`    | no       | object                          | Lifecycle marker. Required sub-field `status` is one of `active`, `deprecated`, `sunset`. Optional `replacement` (non-empty string) and `sunset_date` (ISO date). `additionalProperties: false`. |
| `style_guide`    | no       | string (`format: uri`)          | URI to the authoring style guide that governs this bundle.                                                                                                 |

#### Lint behavior

`Test-FsiGovernanceReviewCurrency` (in `scripts/linting/Validate-FsiContent.ps1`) emits warnings only — never errors — under these conditions:

* `"<framework> : governance.last_reviewed required when review_cadence is set"` — `review_cadence` populated but `last_reviewed` missing or empty.
* `"<framework> : governance.last_reviewed '<value>' is not a parseable date"` — `last_reviewed` cannot be parsed by `[DateTime]::TryParse`.
* `"<framework> : governance.review_cadence '<value>' is not a parseable ISO 8601 duration"` — `review_cadence` does not match the duration grammar.
* `"<framework> : governance review overdue (last_reviewed=<date> + cadence=<duration> due <due-date>, now=<today>)"` — the next review date computed from `last_reviewed + review_cadence` is earlier than today.

### Pipeline Shape

`pipeline` declares an ordered execution graph for Framework Skills whose host expects to run multiple stages — gather inputs, render content, export a binary deliverable — and pass artifacts between them. The field is optional; Framework Skills that map cleanly onto `phaseMap` alone do not need a pipeline.

Hosts iterate `pipeline.stages` in array order. Each stage is a small object:

| Field      | Required | Notes                                                                                                                                                                  |
|------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`       | yes      | Lower-kebab identifier matching `^[a-z][a-z0-9-]*$`. Unique within `pipeline.stages`. Referenced by `consumes[]` entries in later stages and by `usedByStages[]`.      |
| `kind`     | yes      | Open lower-kebab role label (for example `gather`, `render`, `export`). Hosts interpret semantics; the schema does not enumerate values.                              |
| `consumes` | no       | Ordered list of artifact ids produced by prior stages, or host-sourced inputs prefixed with `host:`. Duplicates are rejected by the schema.                            |
| `produces` | no       | Array of `{ id, kind, cleanup? }` artifact descriptors. Each `id` is lower-kebab and unique across the entire pipeline (not just within the stage).                    |

#### Artifact Kinds and the `binary/*` Convention

`produces[].kind` is open vocabulary, but two conventions are load-bearing:

* **Structured-content kinds** use `<format>/<role>` slashes (for example `yaml/manifest`, `markdown/section`, `json/state`). The kind-compatibility lint matches consumer/producer kinds verbatim.
* **Binary deliverables** use the reserved `binary/<format>` prefix (for example `binary/docx`, `binary/pdf`, `binary/png`, `binary/zip`). The `binary/` prefix signals that the artifact is a host-rendered file written to a working directory rather than an in-memory structured value.

For binary outputs, set `cleanup` to one of:

* `ephemeral` — the host SHOULD delete the artifact after the run completes. Use for intermediate render scratch (working PNGs consumed only by the next stage).
* `retained` — the host SHOULD preserve the artifact for user delivery, audit, or downstream stages.

The binary-artifact lint emits a **warning** when a `binary/*` output omits `cleanup`. Non-binary kinds may also set `cleanup`; the field is informational for those.

Hosts write `binary/*` artifacts to a per-run working directory, conventionally `.copilot-tracking/<host-domain>/<run-id>/` (for example `.copilot-tracking/pptx/2026-04-21-001/`). The Framework Skill names artifacts by `produces[].id`; the host owns the on-disk path.

#### `consumes[]` and the `host:` Prefix

Each `consumes` entry must either:

* match a `produces[].id` from an **earlier** stage (forward references and self-references are rejected by the lint), or
* begin with `host:` to mark a host-supplied input that has no producing stage (for example `host:user-prompt`, `host:repo-root`).

The kind-compatibility lint compares the `kind` of each consumed artifact against the producing stage's declared `kind` and warns on mismatch. `host:`-prefixed inputs are treated as warnings rather than errors so hosts can wire stable inputs without forcing every Framework Skill to declare them.

#### Pipeline Example

```yaml
pipeline:
  stages:
    - id: gather-inputs
      kind: gather
      consumes:
        - host:user-prompt
      produces:
        - id: collected-context
          kind: yaml/manifest
    - id: render-sections
      kind: render
      consumes:
        - collected-context
      produces:
        - id: section-markdown
          kind: markdown/section
        - id: chart-png
          kind: binary/png
          cleanup: ephemeral
    - id: export-deck
      kind: export
      consumes:
        - section-markdown
        - chart-png
      produces:
        - id: deliverable-deck
          kind: binary/pptx
          cleanup: retained
```

### Cross-Skill References (`requiredSkills`)

`requiredSkills` lets a Framework Skill declare other skills it calls. Hosts use the list to pre-load companion skills before stage execution and to surface dependencies during enumeration. The skill-reference lint resolves each `ref` against `.github/skills/<ref>/SKILL.md` and errors when the target is missing.

| Field          | Required | Notes                                                                                                                                                                |
|----------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ref`          | yes      | Skill slug in `<domain>/<name>` form. Both segments lower-kebab, matching `^[a-z][a-z0-9-]*/[a-z][a-z0-9-]*$`. Resolves to `.github/skills/<ref>/SKILL.md`.          |
| `scope`        | no       | `required` (default) or `optional`. `required` means the host MUST load the skill before executing stages that need it; `optional` permits on-demand loading.        |
| `reason`       | no       | Plain-English rationale (for example `redacts PII from gathered evidence before render`). Strongly recommended — the value surfaces in dependency listings.          |
| `usedByStages` | no       | Array of `pipeline.stages[].id` values that invoke the referenced skill. The lint errors when an entry does not match a known stage id.                              |

Duplicate `ref` values are rejected by the schema. Omit `requiredSkills` entirely when the Framework Skill has no external skill dependencies.

#### `requiredSkills` Example

```yaml
requiredSkills:
  - ref: shared/pii-redaction
    scope: required
    reason: "Redacts PII from gathered evidence before render writes any binary output."
    usedByStages:
      - render-sections
  - ref: experimental/powerpoint
    scope: required
    reason: "Builds the final .pptx deliverable from rendered markdown and chart PNGs."
    usedByStages:
      - export-deck
```

### Signing (`signing`)

`signing` is an optional manifest-level block that applies to the entire bundle's outputs (not per-item). It declares the signing method, signer identity, transparency-log endpoint, and an optional verification recipe. Hosts use it to enforce or skip artifact signing on outputs produced by the bundle — typically `pipeline.stages[].produces[]` artifacts and rendered `document-section` items. Bundles that omit the block produce unsigned outputs.

The `cosign` method aligns with the cosign + Fulcio + Rekor model documented in [`.github/skills/security/sigstore`](../../security/sigstore/SKILL.md); consult that skill for the canonical Sigstore reference.

```yaml
signing:
  required: true
  method: cosign
  identity: "https://github.com/microsoft/hve-core/.github/workflows/release.yml@refs/tags/v*"
  transparency_log: "https://rekor.sigstore.dev"
  verify:
    command: cosign
    args:
      - verify-blob
      - "--certificate-identity-regexp"
      - "https://github.com/microsoft/hve-core/.*"
      - "--certificate-oidc-issuer"
      - "https://token.actions.githubusercontent.com"
```

| Field              | Required | Type                         | Description                                                                                                                                                                                                                                                |
|--------------------|----------|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `required`         | no       | boolean (default `false`)    | When `true`, hosts MUST sign produced outputs unless the user passes `--insecure-skip-signing` (see Host Expectations below).                                                                                                                               |
| `method`           | yes      | enum (`cosign`/`gpg`/`none`) | Signing method. `cosign` integrates with Sigstore (Fulcio + Rekor) per `.github/skills/security/sigstore`; `gpg` uses a long-lived key; `none` declares the bundle deliberately produces unsigned outputs (useful for documentation-only Framework Skills). |
| `identity`         | no       | string (`minLength: 1`)      | Signer identity. For `cosign` keyless this is the certificate-identity regex or OIDC subject; for `gpg` this is the key id/fingerprint or signing email.                                                                                                   |
| `transparency_log` | no       | string OR object             | Transparency-log endpoint. Accepts a URI string (typical: `https://rekor.sigstore.dev`) or an object `{ url, public_key }` for non-public deployments where the host needs the log's verification key inline.                                              |
| `verify`           | no       | object                       | Optional verification recipe. Object with optional `command` (executable name) and `args` (array of strings), or `script` (path to a verification script). At least one of `command` OR `script` must be present when `verify` is supplied.                 |

`transparency_log` object form:

| Sub-field    | Required | Notes                                                            |
|--------------|----------|------------------------------------------------------------------|
| `url`        | yes      | Rekor-compatible log URL.                                        |
| `public_key` | yes      | PEM-encoded public key the host uses to verify inclusion proofs. |

`verify` object form:

| Sub-field | Required | Notes                                                                                                       |
|-----------|----------|-------------------------------------------------------------------------------------------------------------|
| `command` | one of   | Executable name (typically `cosign` or `gpg`). Pair with `args`.                                            |
| `args`    | no       | Array of CLI arguments passed to `command`.                                                                 |
| `script`  | one of   | Path to a verification script relative to the bundle root. Mutually exclusive in practice with `command`.   |

#### Host Expectations

* Hosts honor `--insecure-skip-signing` (and equivalent flags) to bypass signing in development workflows. The FSI does not enforce signing — it declares the contract.
* When `signing.required: true` is paired with `signing.method: 'none'`, the consistency lint emits a warning ("no signature will be produced unless host overrides") because the combination is contradictory.
* The lint does not validate that `verify.command` resolves on `$PATH` or that `transparency_log.url` is reachable; those are runtime concerns owned by hosts.

#### Lint Behavior

`Test-FsiSigningAttestationConsistency` (in `scripts/linting/Validate-FsiContent.ps1`) emits warnings (never errors) for the following conditions:

* `"<framework> : signing.required is true but signing.method is 'none' (no signature will be produced unless host overrides)"`.
* `"<relPath> : attestation.covers entry '<id>' does not resolve to any pipeline produces[].id or sibling item id in bundle '<framework>'"`. This warning is grouped with `signing` because the lint validates the manifest-level pairing of `signing` and per-item `attestation` together.

### `document-section` Manifest Example

Framework Skills that use `itemKind: document-section` pair `globals` with template-driven items. This example mirrors the `prd-template` prototype in `.github/skills/project-planning/`:

```yaml
framework: prd-template
version: "2026.1"
summary: 'Product Requirements Document sections with guided prompts and variable-driven inputs.'
domain: project-planning
itemKind: document-section
status: draft
globals:
  product_name:
    description: "Product or feature name used across all sections"
    required: true
  team_owner:
    description: "Team responsible for delivery"
  target_release:
    description: "Target release version or date"
phaseMap:
  outline:
    - background
    - problem-statement
    - non-goals
  draft:
    - goals-and-success-metrics
    - target-users
    - requirements
    - technical-approach
  finalize:
    - milestones
    - risks
    - open-questions
metadata:
  source: internal
  imported_by: prompt-builder
  imported_at: "2026-04-01T00:00:00Z"
```

Working prototype Framework Skills demonstrating `document-section` and `globals` usage live in `.github/skills/project-planning/`: `prd-template` and `adr-template`.

### Phase Labels Are Host-Owned

The schema does NOT enumerate phase names. Each consuming host agent defines its own phase vocabulary:

* **SSSC Planner** uses `standards-mapping`, `gap-analysis`, `backlog-generation`.
* A reviewer might use `intake`, `triage`, `report`.

Choose phase labels that match the host agent that will consume the Framework Skill. Document the mapping in the Framework Skill's `SKILL.md` if you ship one.

## `{{var}}` Substitution Semantics

`document-section` templates are the primary consumer of `{{var}}` tokens. Item templates contain `{{var}}` tokens that hosts substitute at render time using values from `globals` and per-item `inputs`. This section defines the normative contract for token grammar, resolution, and escaping.

### Token Grammar

A token is `{{` + identifier + `}}`. The identifier matches `[A-Za-z_][A-Za-z0-9_]*` (flat names only — dotted paths are reserved for a future version). Whitespace between the braces and the identifier is tolerated: `{{ name }}` is equivalent to `{{name}}`. By convention, use `snake_case` for variable names (e.g., `product_name`, `team_owner`). All prototype Framework Skills follow this convention.

### Resolution Order

Tokens resolve in two scopes, checked in order:

1. **Item-local `inputs`** — `inputs[].name` declared on the per-item YAML file.
2. **Manifest `globals`** — keys declared under `globals:` in `index.yml`.

Item-local wins on collision. When an `inputs[].name` matches a `globals` key, lint emits a **warning** (the shadow may be intentional) but does not block validation.

### Escape Convention

To emit a literal `{{…}}` in rendered output, prefix with a backslash: `\{{literal}}`. Lint skips escaped tokens during variable-resolution checks. Hosts render `\{{…}}` as the literal text `{{…}}`.

### Missing-Value Behavior

Lint emits an **ERROR** when a token resolves to nothing in either scope. This catches typos and undeclared variables at validation time. Render-time behavior (substitute blank, throw, prompt the user) is host-owned and out of scope for the FSI contract.

### Nested Rendering

Substitution is **single-pass**. A token whose resolved value contains another `{{…}}` token is not expanded again. Authors must not rely on recursive expansion.

### Host Responsibility

Hosts perform substitution at render time using `manifest.Raw.globals` merged with per-invocation `inputs` values. The FSI ships the contract and validates references at lint time; it does not execute rendering.

## Per-Item Files

Each id listed in `phaseMap` resolves to `items/<id>.yml`. The shape of these files is owned by the host-agent contract for the Framework Skill's `itemKind`, not by this skill. Look at an existing Framework Skill in the same domain for the expected fields.

If you are inventing a new `itemKind`, add a per-domain item schema under `scripts/linting/schemas/` and wire it into `npm run validate:skills` so per-item files get structural validation.

The `Resolve-FrameworkSkillPhaseItem` discovery helper returns `{ Id, Path, Exists }` per id; missing files surface `Exists = $false` so host agents can fail fast.

### Optional Per-Control Fields (security `itemKind: control`)

The security per-control schema (`planner-framework-control.schema.json`) accepts three optional fields that affect how host planners score evidence. Framework Skill authors use these fields to prevent reasonable equivalents from being mis-scored as gaps:

* **`equivalentImplementations`** — Array of `{ id, tool, rationale }` entries naming functional equivalents that share the control's underlying primitives. When present, host planners must score detection of any listed equivalent as full credit (`verified`) for this control rather than `partial`. Example: a `cosign-sign` control lists `actions/attest-build-provenance` because both produce Sigstore bundles signed by Fulcio with Rekor inclusion proofs.
* **`alternativeGroup`** — `{ id, rationale }` marking this control as one member of a mutually substitutable set. When any member of the group is verified in the inventory, host planners score the unused members `n/a` with reason `alternative format selected` (or equivalent). Example: `spdx-2.3` and `cyclonedx-1.5` share `alternativeGroup.id: sbom-format` because emitting either format satisfies the format-emission requirement.
* **`applicability`** — `{ discriminator, appliesWhen?, naWhen, naReason }` declaring an axis along which the control may be out of scope. `appliesWhen` lists discriminator values under which the control applies; `naWhen` lists values under which the control is not applicable. Host planners read `state.projectContext` to evaluate the discriminator and, when matched against `naWhen`, score the control `n/a` with `naReason`. Example: CISA `acquire-*` controls declare `discriminator: project-type, naWhen: [self-published-oss], naReason: 'self-published, no upstream supplier'`.

These fields are optional. Omit them when the control has no recognized equivalents, no substitutable alternative, or applies universally.

### Per-Item Fields (`document-section`)

The `document-section` per-item schema (`document-section.schema.json`) is strict (`additionalProperties: false`). Each file under `items/` for a `document-section` Framework Skill contains:

| Field           | Required | Notes                                                                                                                                                  |
|-----------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`            | yes      | Lower-kebab identifier matching the file name. Pattern: `^[a-z][a-z0-9-]*$`.                                                                           |
| `title`         | yes      | Human-readable section heading.                                                                                                                        |
| `template`      | yes      | Markdown body with `{{var}}` tokens resolved at render time.                                                                                           |
| `description`   | no       | Optional prose explaining the section's purpose.                                                                                                       |
| `inputs`        | no       | Array of per-section input descriptors. See [inputs sub-fields](#inputs-sub-fields) below.                                                             |
| `applicability` | no       | Same shape as the control-schema `applicability` object (`discriminator`, `appliesWhen`, `naWhen`, `naReason`).                                        |
| `evidenceHints` | no       | Array of glob-pattern strings identifying files that evidence completion. Unlike the control schema (single string), `document-section` uses an array. |
| `selectWhen`    | no       | Positive-inclusion predicate distinct from `applicability`. See [Conditional Selection (`selectWhen`)](#conditional-selection-selectwhen).            |
| `attestation`   | no       | Object declaring which produced artifacts a signature must cover. See [Per-Item Attestation (`attestation`)](#per-item-attestation-attestation).        |

#### `inputs[]` Sub-Fields

Each entry in the `inputs` array declares a variable the host collects before rendering the template. The sub-schema is defined in `$defs/input` of `document-section.schema.json`.

| Field         | Required | Notes                                                                                                                                                    |
|---------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `name`        | yes      | Identifier matching `[A-Za-z_][A-Za-z0-9_]*`. Referenced as `{{name}}` in the template.                                                                  |
| `description` | no       | Human-readable prompt text shown when collecting the value.                                                                                              |
| `required`    | no       | Boolean (default `false`). When `true`, the host must collect a value before rendering.                                                                  |
| `persistence` | no       | Enum: `none`, `session`, `project`, `user` (default `session`). `none` re-prompts every render; `session` caches for one host session; `project` persists to a project-scoped host store; `user` persists to a user-scoped store. |
| `sensitive`   | no       | Boolean (default `false`). Marks the input as containing sensitive material; combining `sensitive: true` with `persistence: user` emits a lint warning. |

Item-local `inputs[].name` values take precedence over manifest `globals` keys on collision. See [Resolution Order](#resolution-order).

### Conditional Selection (`selectWhen`)

The `selectWhen` field is a positive-inclusion predicate the host evaluates against `state.projectContext` (or its content-generation equivalent) to decide whether to include the item in a given run. It is distinct from `applicability`, which marks an item as structurally out of scope. At FSI v0 `selectWhen` is supported on `document-section` items only; it is not accepted on `control` or `rule` items.

| Field           | Required | Notes                                                                                                                          |
|-----------------|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `discriminator` | yes      | Name of the projectContext key whose value the host compares against `values` and `notValues`.                                 |
| `values`        | one of   | Array of strings. The item is included when the discriminator value matches any entry. At least one of `values` or `notValues` must be present. |
| `notValues`     | one of   | Array of strings. The item is excluded when the discriminator value matches any entry. May be combined with `values`.          |

Items without `selectWhen` are always included. An item MAY declare both `applicability` and `selectWhen`: `applicability` answers "is this in scope at all?" and `selectWhen` answers "given it is in scope, do we want it for this variant?"

#### Example

```yaml
id: regulated-disclosures
title: Regulated Disclosures
template: |-
  ## Regulated Disclosures
  {{regulatory_summary}}
selectWhen:
  discriminator: prd_template_variant
  values:
    - regulated
  notValues:
    - legacy
```

The host includes this section only when `state.projectContext.prd_template_variant` resolves to `regulated` and is not `legacy`. Both arrays enforce `minItems: 1` and `uniqueItems: true`; entries are non-empty strings.

### Per-Item Attestation (`attestation`)

`attestation` is the per-item counterpart to manifest [`signing`](#signing-signing). It tells the host *which* artifacts a signature must cover for this section's render output. Hosts pair the bundle's `signing` block with each item's `attestation.covers[]` to assemble the artifact set that gets signed (cosign blob signature, in-toto attestation, etc.). Items without `attestation` inherit the bundle's default behavior — unsigned, or a signature that covers the rendered item only.

| Field      | Required | Notes                                                                                                                                                                                                                                                                                          |
|------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `required` | no       | Boolean (default `false`). When `true`, hosts MUST produce a signature covering every id in `covers[]` before the item is considered complete. Pairs with manifest `signing.required`.                                                                                                         |
| `covers`   | yes      | Array (`minItems: 1`, `uniqueItems: true`) of slug-pattern strings (`^[a-z0-9][a-z0-9.-]*$`). Each entry resolves to either a `pipeline.stages[].produces[].id` or a sibling item id within the same bundle. Unresolved ids emit a lint warning (see Signing > Lint Behavior).                |

```yaml
id: regulated-disclosures
title: Regulated Disclosures
template: |-
  ## Regulated Disclosures
  {{regulatory_summary}}
attestation:
  required: true
  covers:
    - regulated-disclosures        # this item's rendered output
    - compliance-evidence-bundle   # a pipeline produces[].id from a downstream stage
```

The lint resolves each `covers[]` entry against the union of (a) all `pipeline.stages[].produces[].id` values declared in the manifest and (b) every item `id` in the bundle. Unresolved entries are warnings rather than errors, so authors can stage partial pipelines while iterating.

## Surface Tagging (sustainability extension)

FSI v1.0 ships an additive, non-breaking extension that lets sustainability bundles (and any other host whose items partition by workload surface) declare a closed set of surfaces and tag each item with the surfaces it applies to. All five fields are optional; bundles that do not opt in remain unchanged.

| Field                          | Where             | Type     | Semantics                                                                                                                                                              |
|--------------------------------|-------------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `surfaceFilter`                | Manifest top-level | string[] | Closed set drawn from `cloud`, `web`, `ml`, `fleet`. When present, every per-item file MUST declare `appliesTo` and every value MUST be a member of `surfaceFilter`. |
| `appliesTo`                    | Per-item control  | string[] | Subset of `surfaceFilter` declaring which surfaces this control applies to. Planners filter the bundle against the active workload mix at runtime.                   |
| `measurementClass`             | Per-item control  | string   | Epistemic class of any numeric output: `deterministic`, `estimated`, `heuristic`, or `user-declared`.                                                                |
| `sciVariable`                  | Per-item control  | string   | Maps the control to the SCI=(E*I+M)/R variable it informs: `E`, `I`, `M`, or `R`.                                                                                    |
| `appliesToPrinciples`          | Per-item control  | string[] | Cross-walk identifiers of the form `gsf-principles:<kebab-id>`. Validator emits a warning when the `gsf-principles` bundle is loaded but a referenced item is absent. |

Validator behavior (in `Test-FsiSurfaceTagging`):

* Manifest declares `surfaceFilter` AND any item omits `appliesTo` → ERROR.
* Item `appliesTo` value is not in `surfaceFilter` → ERROR.
* `sciVariable` value not in `{E, I, M, R}` → ERROR (also rejected by JSON schema).
* `measurementClass` value not in the enum → ERROR (also rejected by JSON schema).
* `appliesToPrinciples` entry that does not match `^gsf-principles:[a-z0-9-]+$` → ERROR.
* Cross-resolution against the `gsf-principles` bundle when present → WARNING per missing reference; skipped silently when the bundle is absent.

Example manifest fragment:

```yaml
framework: capability-inventory
version: '1.0'
summary: Sustainability capability inventory
itemKind: control
surfaceFilter: [cloud, web, ml, fleet]
```

Example per-item fragment:

```yaml
controls:
  - id: low-carbon-region-selection
    title: Low-carbon region selection
    appliesTo: [cloud]
    measurementClass: estimated
    sciVariable: I
    appliesToPrinciples:
      - gsf-principles:carbon-awareness
```

## Authoring Workflow

Use the Prompt Builder + Researcher Subagent pattern. There is no dedicated importer agent.

1. **Research the source spec.** Invoke Prompt Builder with a request to import `<framework>`. Prompt Builder dispatches Researcher Subagent to fetch the published spec and extract control/criterion identifiers.
2. **Draft the manifest and items.** Place files under your chosen root (built-in: `.github/skills/<domain>/<framework-id>/`; external: a path you control). Set `status: draft` and populate `metadata.source`, `metadata.imported_by`, `metadata.imported_at`, `metadata.review_required: true`.
3. **Validate.** Run `Test-FrameworkSkillInterface` (see [Validation](#validation)).
4. **Promote.** After human review, change `status` to `published`. Hosts will then surface the Framework Skill without `-IncludeDrafts`.

## Discovery

Host agents enumerate Framework Skills via `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`:

```powershell
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1

# Built-in Framework Skills only
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security'

# Built-ins + a user-controlled location
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security' `
    -AdditionalRoots './.copilot-tracking/framework-imports/security'

# Include drafts (typically gated by a host reference flag)
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security' -IncludeDrafts
```

`AdditionalRoots` accepts absolute paths or paths relative to `RepoRoot`. Built-in Framework Skills are searched first; duplicate `framework` ids from additional roots are skipped (no shadowing). The host agent decides which roots to register — this is where the user controls placement.

## Validation

Validate a single manifest against the schema:

```powershell
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1
Test-FrameworkSkillInterface -RepoRoot $PWD `
    -ManifestPath './.github/skills/security/my-internal-spec/index.yml'
```

Returns `[pscustomobject]@{ Valid = <bool>; Errors = <string[]> }`. `Errors` is an empty array (not `$null`) when `Valid = $true`, so `.Errors.Count` is always safe. Run this before promoting a draft Framework Skill and before opening a PR that adds or changes a Framework Skill.

For repo-wide validation, `npm run test:ps` runs the full Pester suite under `scripts/tests/`. For Framework Skill content validation, `npm run validate:fsi-content` executes `Validate-FsiContent.ps1`, which imports the discovery module and validates built-in Framework Skills as content checks are implemented. The validator currently runs four content lints:

* **Variable resolution** — Every `{{var}}` token in `document-section` templates must resolve to either an `inputs[].name` on the item or a `globals` key in the manifest. Unresolved tokens fail validation.
* **Pipeline kind compatibility** — Each `consumes[]` entry must match a `produces[].id` from an earlier stage (or carry the `host:` prefix). Producer/consumer `kind` values are compared and mismatches emit warnings.
* **Binary artifact cleanup** — Any `produces[]` entry whose `kind` starts with `binary/` should declare `cleanup: ephemeral` or `cleanup: retained`. Missing `cleanup` on a binary output emits a warning.
* **Skill reference resolution** — Every `requiredSkills[].ref` must resolve to an existing `.github/skills/<ref>/SKILL.md`, and every `usedByStages[]` entry must match a known `pipeline.stages[].id`.

## Quick Start

1. Create a directory under `.github/skills/<domain>/<framework-id>/` with an `index.yml` manifest and an `items/` subdirectory.
2. Populate `index.yml` following the [Manifest Contract](#manifest-contract-indexyml). Set `status: draft`.
3. Add one YAML file per item id listed in `phaseMap` under `items/`. Use the field tables for your `itemKind` ([control](#optional-per-control-fields-security-itemkind-control) or [document-section](#per-item-fields-document-section)).
4. Run `Test-FrameworkSkillInterface` (see [Validation](#validation)) and fix any errors.
5. After human review, change `status` to `published`.

## Troubleshooting

| Symptom                                         | Cause                                                          | Fix                                                                                     |
|-------------------------------------------------|----------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| `Valid = $false` with "missing item file"       | An id in `phaseMap` has no matching `items/<id>.yml`           | Create the missing file or remove the id from `phaseMap`.                               |
| `{{var}}` lint ERROR for unresolved token       | Token name does not match any `inputs[].name` or `globals` key | Add the variable to the item's `inputs` array or the manifest's `globals` map.          |
| Host agent does not surface the Framework Skill | `status: draft` and host is not using `-IncludeDrafts`         | Change `status` to `published` or pass `-IncludeDrafts`.                                |
| Duplicate `framework` id warning                | Same `framework` value in built-in and additional root         | Rename the external Framework Skill or remove the duplicate. Built-in takes precedence. |

## Draft Quarantine

`status: draft` is the safety boundary between authoring and consumption. AI-assisted imports MUST start as drafts. Hosts that surface drafts to end users SHOULD do so only when the user-supplied reference (for example `frameworkRef.includeDrafts: true` in a planner config) opts in explicitly.

> Brought to you by microsoft/hve-core
