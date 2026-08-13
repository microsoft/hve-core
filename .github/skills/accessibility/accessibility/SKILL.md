---
name: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, design intent verification, and the Accessibility Planner workflow."
license: MIT
compatibility: "Requires Python 3.11+ and uv; the scanner additionally needs Node.js and network access to run 'npx --yes @axe-core/cli@4.12.1'."
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-11"
---

# Accessibility — Skill Entry

This skill is the canonical accessibility reference contract for HVE Core. Agents and instructions invoke this skill by name and rely on it to own framework reference resolution, phase guidance resolution, and the scanner CLI entrypoint.

## Framework references

* [WCAG 2.2](references/frameworks/wcag-22.md)
* [ARIA Authoring Practices Guide](references/frameworks/aria-apg.md)
* [Cognitive Accessibility Guidance](references/frameworks/coga.md)
* [Section 508](references/frameworks/section-508.md)
* [EN 301 549](references/frameworks/en-301-549.md)
* [Graphics ARIA and SVG-AAM](references/frameworks/graphics-aria-svg-aam.md)

Assessment reference (cross-cutting, not a conformance framework):

* [Assistive-technology announcement model](references/frameworks/at-announcement-model.md) — read this when deciding the announcement-class criteria (WCAG 1.3.1, 4.1.2, 4.1.3): what a screen-reader user should hear, and how to decide it with an accessibility-tree assertion or a manual AT pass.

## Accessibility Planner workflow

The Accessibility Planner runs six phases, each keyed to a state id:

1. Phase 1 — Discovery (`discovery`)
2. Phase 2 — Framework Selection (`framework-selection`)
3. Phase 3 — Standards Mapping (`standards-mapping`)
4. Phase 4 — Plan Risk Assessment (`plan-risk-assessment`)
5. Phase 5 — Impact and Evidence (`impact-evidence`)
6. Phase 6 — Backlog Handoff (`backlog-handoff`)

## Phase reference index

* Phase 1 — Discovery: [capture-coaching.md](references/phases/capture-coaching.md) — read this when running exploration-first capture questioning.
* Phase 2 — Framework Selection: [framework-selection.md](references/phases/framework-selection.md) — read this when choosing which frameworks and conformance level apply.
* Phase 3 — Standards Mapping: walk the [framework references](#framework-references) roll-up tables to emit `controlMappings`; consumed by Phase 5. No dedicated file — mapping is driven by the framework roll-ups.
* Phase 4 — Plan Risk Assessment: [capture-coaching.md](references/phases/capture-coaching.md) governs the questioning posture when escalation triggers reopen scoping; tier criteria are applied per the Accessibility Planner identity instructions and recorded as `riskClassification.tier`. No dedicated file — the accessibility risk surface is narrow enough to stay inline.
* Phase 5 — Impact and Evidence: [impact-assessment.md](references/phases/impact-assessment.md) — read this when building the evidence register, tradeoff log, and seed work-items.
* Phase 6 — Backlog Handoff: [backlog-handoff.md](references/phases/backlog-handoff.md) — read this when rendering work items and validating handoff gates.

## Method adequacy (decide vs inform)

Method adequacy is the doctrine that a verification method may only be recorded as satisfying a success criterion when that method can actually *decide* the criterion. A method that can observe a related signal but cannot confirm the user-facing outcome only *informs* the criterion; it raises or lowers suspicion but never closes it. This section is the canonical definition; the planner evidence register, the reviewer verdict logic, and the runtime probe harness all resolve adequacy through it.

The machine-readable adequacy source is [scripts/runtime_a11y/probe-criteria-map.json](scripts/runtime_a11y/probe-criteria-map.json). Each probe entry lists the criteria it `decides` and the criteria it only `informs`. A result counts as adequate only when the winning method appears in the `decides` list for that criterion and state.

### Failure classes and adequate methods

Accessibility defects generalize into five classes. Static analysis (axe, `eslint-plugin-jsx-a11y`, snapshot structure counts) can decide only the first class; the remaining four require an interaction-state probe or an assistive-technology (AT) pass to be decided rather than merely informed.

| Class                          | Representative WCAG SC                           | What static analysis can do | Adequate method to decide                                                                                   |
|--------------------------------|--------------------------------------------------|-----------------------------|-------------------------------------------------------------------------------------------------------------|
| **Static-decidable structure** | 1.1.1, 1.4.3, 4.1.2 (name present), 2.4.2, 3.1.1 | Decide                      | axe / static scan                                                                                           |
| **Interaction behavior**       | 2.1.1, 2.1.2, 2.4.3, 2.4.7, 2.4.11               | Inform only                 | Keyboard/interaction probe driving keys across `focus`/`open` states, or manual keyboard pass               |
| **Announcement correctness**   | 1.3.1, 4.1.2 (computed name/role), 4.1.3         | Inform only                 | Accessibility-tree assertion of computed name/role/live, or manual AT pass (Windows NVDA or human-led JAWS) |
| **Adaptive rendering**         | 1.4.4, 1.4.10, 1.4.12, 2.4.11                    | Inform only                 | Rendered probe at 200% zoom, 320px reflow, and text-spacing states                                          |
| **Faux semantics**             | 1.3.1 (faux headings), 2.4.3 (faux controls)     | Cannot see                  | Heuristic source pass plus accessibility-tree assertion; no element exists for a rule engine to flag        |

For the announcement class, the [assistive-technology announcement model](references/frameworks/at-announcement-model.md) specifies what the user should hear per criterion and how to decide it. For the interaction and faux-semantics classes, the [focus-management anti-pattern catalog](references/frameworks/aria-apg.md#focus-management-anti-patterns) enumerates the defects that pass a static scan yet break keyboard and screen-reader users.

### Adequacy rule

* A control in the interaction, announcement, adaptive-rendering, or faux-semantics classes cannot be recorded as fully satisfied on static evidence alone. Static evidence caps such a control at a partial state until an adequate method is attached.
* A criterion whose winning method only `informs` it is never a conformance verdict; it is a lead that routes to an adequate method or a manual pass.
* Preserve the adequacy determination alongside the status so downstream planners and reviewers do not re-promote an inadequately verified control.

This doctrine and its class taxonomy are repository-original content licensed under CC BY 4.0; the underlying success-criterion definitions remain with WCAG 2.2 as cited in [wcag-22.md](references/frameworks/wcag-22.md).

### Calibration is evidence quality, not a conformance verdict

Calibration establishes that the assistive-technology stack behaves as expected before its output is trusted. Its checkpoints record driver identity, profile fingerprint, and artifact hashes for a journey that passed.

A checkpoint is deliberately not a matrix input. Nothing in the coverage or outcome pipeline reads one, and that separation is intended rather than unfinished. A passing calibration says the harness was working; it does not say the surface satisfies a success criterion. Wiring checkpoints into coverage would turn a statement about the tool into a statement about the product.

If calibration evidence should ever influence coverage, that is new design work requiring its own review: it needs an explicit mapping from a journey to a criterion, surface, and state, and it must respect the same method-adequacy rules as any other evidence.

### Gate strictness by assessment tier

The enforcement posture for the interaction, announcement, adaptive-rendering, and faux-semantics classes graduates with the assessment depth tier recorded in `riskClassification.tier`, so the gate inherits the rigor a project opted into rather than applying one global switch:

* `basic` — the adequate-method probes (keyboard, widget-keyboard, live-region, aria-tree, virtual-sr) report **advisory** (warn-only); the always-decidable core probes still block.
* `standard` (default) — **ratchet**: the adequate-method probes block on new or changed surfaces and stay advisory over the existing backlog, so no new defect in these classes ships while legacy content is surfaced without freezing the project.
* `comprehensive` — the adequate-method probes **block** on every in-scope surface.

The always-decidable core probes (axe, DOM hygiene, broken links, console errors, target size, contrast, reflow/resize) block at every tier. The CI workflow template implements this dial through the `A11Y_TIER` and `A11Y_RATCHET_SURFACES` inputs; the Accessibility Reviewer applies the same graduation to its FAIL and PARTIAL verdicts.

## Tooling

The scanner CLI ([scripts/scan.py](scripts/scan.py)) wraps the Node-based axe-core scanner and normalizes its findings into a stable JSON shape.

### Prerequisites

* Python 3.11+ with [uv](https://docs.astral.sh/uv/) available on PATH.
* Node.js with `npx` available on PATH.
* Network access on first run so `npx` can fetch `@axe-core/cli`.

### Quick Start

```bash
uv run scripts/scan.py https://example.com
uv run scripts/scan.py ./page.html --output results.json
```

### Parameters Reference

| Parameter  | Required | Default | Description                                |
|------------|----------|---------|--------------------------------------------|
| `target`   | Yes      | —       | URL or local file to scan.                 |
| `--output` | No       | stdout  | Path to write the normalized JSON results. |

### Script Reference

* Entrypoint: [scripts/scan.py](scripts/scan.py)
* Output shape:

  ```json
  {
    "target": "<scanned target>",
    "summary": {
      "violations": 0,
      "passes": 0,
      "incomplete": 0,
      "inapplicable": 0
    },
    "violations": [
      { "id": "", "impact": "", "description": "", "nodes": 0 }
    ]
  }
  ```

* Exit codes:
  * `0` — scan completed successfully.
  * `1` — scan failed or returned invalid output.
  * `2` — scanner unavailable (Node.js or `@axe-core/cli` missing).

### Troubleshooting

| Symptom                                  | Likely cause                               | Action                                                           | Exit code |
|------------------------------------------|--------------------------------------------|------------------------------------------------------------------|-----------|
| `scanner unavailable` error              | Node.js or `npx` not on PATH               | Install Node.js so `npx` resolves, then re-run.                  | `2`       |
| Long pause or download on first run      | `npx` is fetching `@axe-core/cli`          | Allow network access on the first run; later runs use the cache. | —         |
| `scan failed or returned invalid output` | axe-core CLI errored or emitted non-JSON   | Confirm the target URL or file is reachable and well-formed.     | `1`       |
| Empty `violations` but issues expected   | Page rendered after the scan, or rules N/A | Confirm the target fully loads; check `summary.inapplicable`.    | `0`       |

### Mapping findings to frameworks

Each violation's `impact` is one of `minor`, `moderate`, `serious`, or `critical`. axe rule tags decode to WCAG success criteria by stripping the `wcag` prefix and inserting decimals:

| axe tag   | WCAG success criterion   |
|-----------|--------------------------|
| `wcag111` | 1.1.1 Non-text Content   |
| `wcag143` | 1.4.3 Contrast (Minimum) |

WCAG success criteria are normative; the axe techniques that surface them are informative. Treat scanner output as evidence pointing at a criterion, not a conformance verdict.

### Runtime probe harness

The runtime probe harness ([scripts/runtime_a11y](scripts/runtime_a11y)) runs Playwright-based accessibility probes against a project-specific surface inventory and aggregates the results into a coverage matrix. Use the `accessibility-coverage-matrix.prompt.md` prompt for workflow orchestration and the `Accessibility Surface Inventory` subagent as the canonical producer of the runtime config. Activate each by name; when one does not resolve, warn the user that the capability is unavailable and stop the dependent step.

#### Harness prerequisites

Complete these once before any runtime-harness command. They are separate from the `scan.py` prerequisites above.

* Python 3.11+ with [uv](https://docs.astral.sh/uv/) available on PATH.
* Node.js available on PATH, plus system Google Chrome, because the probes target `channel: 'chrome'`.
* Skill-local Node dependencies installed under [scripts/runtime_a11y](scripts/runtime_a11y). The CLI fails fast with an install hint when they are missing.

Install the harness dependencies from the `scripts/runtime_a11y` directory:

```bash
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci
```

```powershell
$env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = '1'; npm ci
```

`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` avoids downloading bundled browsers that the harness never uses.

#### Invocation

Run the harness through its script entrypoint. Invoke it from the skill root, which is the directory holding `pyproject.toml`, so uv resolves the skill's own environment. This matches the invocation convention used by `scan.py` and the other Python skills, and it needs no `PYTHONPATH`.

```bash
uv run scripts/runtime_a11y/__main__.py run-all --config a11y-runtime.config.json --out results.json
uv run scripts/runtime_a11y/__main__.py probe <probeId> --config a11y-runtime.config.json
uv run scripts/runtime_a11y/__main__.py render-artifacts --matrix coverage-matrix-repo.json --output-dir .copilot-tracking/accessibility/coverage --repo-slug repo
```

To run from any other working directory, pin the skill as the uv project and use the same script path:

```bash
uv run --project <skill-root> <skill-root>/scripts/runtime_a11y/__main__.py run-all --config a11y-runtime.config.json --out results.json
```

* `--config` resolves relative to the current working directory.
* `--out` writes the aggregated JSON document to disk.
* `--base-url` overrides the configured base URL. It must remain a loopback origin unless the host is allowlisted or `--allow-external` is supplied.
* `--trace` captures Playwright traces and screenshots.
* `--allow-external` confirms intentional probing of a non-loopback host.
* `render-artifacts` turns a rendered matrix JSON document into the complete coverage evidence bundle.

#### Visual review capture

`capture-visual-review` records deterministic screenshot evidence for the configured surfaces and states. It requires `visualReview.enabled` to be `true` in the runtime config.

```bash
uv run scripts/runtime_a11y/__main__.py capture-visual-review \
  --config <path-to>/a11y-runtime.config.json \
  --run-root .copilot-tracking/accessibility/local-runs/<run-name>
```

* `--run-root` selects the evidence directory. It resolves relative to the repository root and must land on a child path inside `.copilot-tracking/accessibility/local-runs`. Paths outside that root, and traversal segments, are rejected.
* Omitting `--run-root` allocates a timestamped run directory beneath that same root.
* `--visual-surface` and `--visual-state` narrow the capture to specific configured ids.
* The server the command targets follows `serveMode`. See [Server modes](#server-modes).

#### Server modes

`serveMode` in the runtime config decides whether the harness manages a server for `capture-visual-review`.

| `serveMode` | Behavior                                                                                                                                     |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `auto`      | Reuses a healthy server at the configured loopback origin, otherwise builds and starts one it owns and stops afterward.                      |
| `served`    | Requires a server already answering the configured loopback origin, and fails with the expected origin and start command when none responds. |
| `external`  | Never probes or starts a server. The configured target must already be reachable.                                                            |
| `off`       | Never probes or starts a server.                                                                                                             |

`auto` and `served` accept only loopback origins, because the harness will not manage or health-probe a remote server. A non-loopback target still requires the allowlist or `--allow-external`, and is only valid with `external` or `off`.

Under `auto`, starting an owned server builds the site first, so a capture that has to start its own server takes several minutes before the first screenshot. Leave a server running at the configured origin to skip that cost, which is the reuse path.

The Docusaurus site in this repository is configured for `auto` at `http://127.0.0.1:3001`, which is the same production-build origin the Playwright end-to-end suite uses. Capturing against the production build keeps visual evidence consistent with what continuous integration verifies.

#### Config summary

The harness loads [scripts/runtime_a11y/config-schema.json](scripts/runtime_a11y/config-schema.json) and expects a runtime config with fields such as `baseUrl`, `serveMode`, `allowlist`, `routes`, `surfaces`, and `probeScoping`. The config defines the surfaces and interaction states the probes execute. A runtime guard blocks non-loopback targets unless the host is allowlisted or the caller supplies `--allow-external`. `serveMode` controls server ownership for visual review capture, described under [Server modes](#server-modes).

#### Probe inventory and adequacy map

The harness currently includes these probes under [scripts/runtime_a11y/runner](scripts/runtime_a11y/runner):

WCAG and ARIA APG probes:

* `probe-axe`
* `probe-keyboard-traversal`
* `probe-focus-visible`
* `probe-focus-obscured`
* `probe-live-region`
* `probe-aria-tree`
* `probe-widget-keyboard`
* `probe-reflow-resize`
* `probe-target-size`
* `probe-contrast`
* `probe-forced-colors`
* `probe-reduced-motion`
* `probe-structure-crawl`
* `probe-name-in-label`
* `probe-use-of-color` (1.4.1)
* `probe-text-spacing` (1.4.12)
* `probe-hover-focus` (1.4.13)
* `probe-link-purpose` (2.4.4)
* `probe-input-purpose` (1.3.5)
* `probe-forms` (3.3.2, informs 3.3.1/3.3.3)
* `probe-context-change` (3.2.1, 3.2.2)
* `probe-orientation` (1.3.4)
* `probe-audio-control` (1.4.2)
* `probe-timing` (2.2.1)
* `probe-zoom-blocker` (1.4.4, informs 1.4.10)
* `probe-virtual-sr` (4.1.2 name/role announcement captured from a virtual screen reader's spoken-phrase log; informs 1.3.1)
* `probe-real-sr` (real Windows NVDA announcement assertions through a Guidepup adapter; only decides when configured expectations are present and the AT stack is available)

Non-WCAG defect-scan probes (framework `defect-scan`):

* `probe-console-errors` (console/page errors)
* `probe-broken-links` (same-origin 404s)
* `probe-dom-hygiene` (duplicate ids, positive tabindex, missing/duplicate landmarks)
* `probe-title-lang` (empty title, invalid `lang`)

Method adequacy is encoded in [scripts/runtime_a11y/probe-criteria-map.json](scripts/runtime_a11y/probe-criteria-map.json). Each entry records which criteria a probe can decide and which criteria it can only inform. A result only counts as adequate when the winning method is allowed by that mapping.

#### Coverage engine outputs

The matrix engine in [scripts/runtime_a11y/matrix](scripts/runtime_a11y/matrix) expands the criterion x surface x state grid, merges updates deterministically, and preserves human-confirmed findings over lower-priority automation. It computes adequate-coverage percentages by framework and overall. The `render-artifacts` command emits a deterministic bundle containing `coverage-matrix-{repo-slug}.json`, `coverage-matrix-{repo-slug}.md`, `accessibility-results-{repo-slug}.earl.jsonld`, `manual-at-testplan-{repo-slug}.md`, `manual-at-testplan-{repo-slug}.yaml`, and `accessibility-artifacts-{repo-slug}.json`.

The EARL (Evaluation and Report Language) JSON-LD export is the normalized results contract for interoperability with the ACT Rules ecosystem and downstream VPAT or EAA review. Each evaluated cell becomes one stable `earl:Assertion` that records subject, criterion, state, method, method adequacy, result date, and evidence. A result whose winning method only informs its criterion is `earl:cantTell`, never a false `earl:passed`. Inapplicable cells are `earl:inapplicable`; unevaluated cells are omitted. The paired manual plans contain cells that still require a human-deciding method and provide blank result fields for evidence writeback.

#### Public ARIA-AT and execution contract

The catalog in [scripts/runtime_a11y/aria-at-catalog.json](scripts/runtime_a11y/aria-at-catalog.json) is the repository's documented source of truth for generated AT-oriented cases. Its provenance fields are strict and immutable: each mapping records a local catalog version, a canonical upstream URL, a commit-pinned upstream URL, and the upstream commit SHA used for the reviewed refresh. The repository does not copy upstream assertion tables or prose; it paraphrases official W3C and ARIA-AT intent and cites the source in the generated artifacts.

The current public posture is intentionally conservative. The five starter defaults (modal dialog, checkbox, select-only combobox, menu button, and tabs) are citation-bearing manual-only mappings because the richer AT-mode and quick-navigation semantics that these patterns can require are not faithfully modeled by the current structured command boundary. Runtime overrides may create explicit synthetic contract tests, but those are always non-pass candidate evidence and never accessibility conformance evidence. The resolver uses the documented fallback order of state -> surface -> catalog; commands and assertions are stored as atomic arrays, and an explicit empty array intentionally disables execution for a given case.

Unknown patterns remain generic manual drafts or project-refinement markers rather than a fake automation pass. Equally specific ambiguity is treated as a configuration error before rendering or driver startup. The public CLI exposes `render-artifacts` as an optional mapping configuration step and `run-at-plan` as the supported path for listing, selecting, executing, and reporting generated AT cases. The real-driver boundary currently supports Guidepup-backed Windows NVDA automation plus manual-only JAWS and other operator-led flows; synthetic execution is a separate evidence channel and never claims a pass. The generated manual plans stay linked to the shared [real screen reader testing runbook](../../../../docs/planning/runbooks/accessibility/real-screen-reader-testing.md), while case-specific commands remain inside the generated plan output rather than being written back into the matrix or coverage artifacts.

The generated manual cases, synthetic or real execution evidence, ACT-style result reasoning, EARL outcomes, and later qualified-human review are distinct layers. The public workflow renders representative fixtures through the documented CLI and inspects the six generated artifacts, but it does not commit golden outputs for the inspection bundle.

#### Exit codes

* `0` indicates the harness completed successfully, even when probes reported findings.
* Non-zero exit codes indicate a harness error such as invalid config, a failed probe, missing Node.js, uninstalled harness dependencies, missing browser support, or a blocked target.

`verify-intent` adds two design-intent codes that a consuming project's CI can distinguish:

| Exit code | Meaning                                    | Typical response                               |
|-----------|--------------------------------------------|------------------------------------------------|
| `3`       | A blocking expectation resolved `failed`   | Treat as intent drift; the surface regressed   |
| `4`       | A blocking expectation was never evaluated | Treat as coverage drift; the check did not run |

The two are separate because a failed check and an unrun check call for different responses. Reusing one code would let missing coverage read as a regression, or pass silently.

#### Runtime dependencies

The harness resolves its Node dependencies from a skill-local package under [scripts/runtime_a11y](scripts/runtime_a11y) (`package.json` plus committed `package-lock.json`), pinning `playwright@1.61.1`, `@axe-core/playwright@4.12.1`, and `@guidepup/virtual-screen-reader@0.32.1`. Install them once as described under [Harness prerequisites](#harness-prerequisites). The probes then resolve their dependencies from the local `node_modules`; the CLI fails fast with an install hint when `node_modules` is absent, before it probes or starts any server.

#### Testing

The harness is tested in two tiers. Browserless verdict and pure-helper unit tests run under `node --test` (repo script `test:node`) and cover the decision logic in `runner/_core.mjs` (for example `virtualSrNameRoleStatus` and `liveRegionStatus`). Browser smoke tests under `tests/runtime_a11y/runner/probe-smoke/` launch system Chrome and drive the real capture path against inline fixtures to prove the DOM-to-verdict pipeline, including nameless controls, live-region firing, forced-color computed styles, and CDP accessibility-node structure. They are named `*.smoke.mjs` so the default browserless run skips them. PR Validation runs them through the CI-owned `npm run ci:test:a11y:smoke` entry point. Local reproduction requires system Chrome and the skill-local `node_modules`.

### CI regression gate

Use the ready-to-copy workflow template at [references/ci/accessibility-coverage.workflow-template.yml](references/ci/accessibility-coverage.workflow-template.yml) as the documentation-first integration point for a target project. Copy it into a real workflow under `.github/workflows/` only after the target project commits an `a11y-runtime.config.json` and has a build/serve path that the template can invoke. Once authored `*.intent.yaml` records exist, the template fails closed if the config or current-run results are missing.

The template mirrors the Docusaurus workflow recipe by provisioning system Chrome, setting up Node 24 plus Python and `uv`, building the target, serving it under a configurable base URL, and running the harness script entrypoint with `uv run --project` pinned at the vendored skill root. The core high-confidence probes always block: `probe-axe`, `probe-dom-hygiene`, `probe-broken-links`, `probe-console-errors`, `probe-target-size`, `probe-contrast`, and `probe-reflow-resize`. The interaction-state and announcement probes (`probe-keyboard-traversal`, `probe-widget-keyboard`, `probe-live-region`, `probe-aria-tree`, `probe-virtual-sr`, `probe-real-sr`) are the adequate method for the classes static analysis only informs, and their blocking posture follows the `A11Y_TIER` dial defined under [Gate strictness by assessment tier](#gate-strictness-by-assessment-tier): `basic` reports them advisory, `standard` ratchets (blocking on the surfaces listed in `A11Y_RATCHET_SURFACES`), and `comprehensive` blocks them everywhere. The remaining heuristic probes such as `use-of-color`, `hover-focus`, `link-purpose`, `name-in-label`, and `focus-*` are surfaced as informational results so they can guide follow-up work without blocking initial adoption. The real-screen-reader probe stays advisory by default unless a project opts into it through configured expected assertions and a supported OS/AT stack; it returns `candidate` when the platform or AT is unavailable rather than pretending a pass or failure. Decisive coverage of the adaptive-rendering class depends on the target committing the `zoom-200`, `reflow-320`, and text-spacing states in its `a11y-runtime.config.json`.

The parity reference at [references/ci/probe-spec-parity.md](references/ci/probe-spec-parity.md) maps each runtime probe to the closest existing Docusaurus e2e spec and highlights gaps where no equivalent spec currently exists.

The [references/ci/act-rule-format.md](references/ci/act-rule-format.md) reference documents how the harness's probes, generated test cases, and EARL results align to the W3C ACT Rules Format (applicability, expectation, passed/failed/inapplicable) so results interoperate with the ACT Rules ecosystem and conformance reporting.

### Design intent verification

A consuming project can declare what a surface must convey and have CI check that what shipped still matches. The declaration is a Design Intent Record, human-authored and committed at `design-intent/<surface-id>.intent.yaml` in that project. Each intent states what the surface must communicate, why, and for whom, and binds every claim to a named check.

The authored-record field contract is in [references/design-intent/record-contract.md](references/design-intent/record-contract.md). Read it when authoring or reviewing a record. This section covers verification.

This skill supplies the step that turns a probe run into a verdict against that declaration.

#### Invocation

```bash
uv run --project <skill-root> <skill-root>/scripts/runtime_a11y/__main__.py verify-intent \
  --record design-intent/<surface-id>.intent.yaml \
  --results results.json
```

* `--record` is the authored record. It is never read for anything but its declarations and never rewritten.
* `--results` is a results document from `run-all`.
* `--out` overrides the output path, which defaults to `design-intent/.verification/<surface-id>.earl.json` beside the record.

#### How results resolve to outcomes

A result row matches an expectation when its surface, state, emitting probe, and criterion all match what the record declares. Because criterion coverage overlaps across probes, the emitting probe is part of the join.

| Situation                             | Outcome    | Mode        |
|---------------------------------------|------------|-------------|
| Every matched criterion passed        | `passed`   | `automatic` |
| Any matched criterion failed          | `failed`   | `automatic` |
| Evidence gathered but not decisive    | `cantTell` | `automatic` |
| No result row matched the expectation | `untested` | `automatic` |
| The expectation uses `assert: custom` | `untested` | `manual`    |

An expectation is one claim over one or more criteria, so the worst criterion outcome governs. Expectations the run did not cover report `untested` rather than being omitted, which keeps a missing check visible instead of silently absent.

Expectations whose criteria a probe only informs resolve to `cantTell` in normal operation. That is expected: the probe gathered evidence without settling the claim.

A `custom` expectation reports `untested` whether or not the record carries a human `override`. The adapter records only observed runtime outcome in the artifact. Human override remains authoritative in the record itself and is not merged into the generated artifact outcome.

Interpretation is two-layered by contract, and the generated artifact now carries both layers on every assertion:

* `observedOutcome` is the generated artifact field `outcome`. An override never replaces it.
* `effectiveOutcome` applies fail-safe precedence. Either an observed or human `failed` outcome yields `failed`; human `passed` settles only `untested`, `cantTell`, or `inapplicable`; otherwise the observed outcome remains. This is the value the gate applies.
* `overrideConflict` is `true` only when the observed and authored override outcomes are each `passed` or `failed` and differ. An override that settles an `untested`, `cantTell`, or `inapplicable` expectation is the documented use, not a conflict.

A conclusive conflict fails closed. `verify-intent` writes one `Warning:` line to stderr for each conflicting assertion, names the intent, expectation, observed outcome, and override outcome, and returns design-intent drift when the conflicting expectation blocks.

The shipped Python verifier rejects duplicate YAML keys, validates the complete authored schema, and enforces semantic checks for dates, filename and runtime-config bindings, duplicate identifiers, method pairing, and probe adequacy before writing an artifact. This repository's PowerShell validator independently enforces the same contract for source and generated-artifact validation.

#### Exit codes

* `0` — the artifact was written and no blocking expectation failed.
* `1` — the record or results document was malformed. Nothing is written.
* `2` — the record or results document could not be read.
* `3` — the artifact was written and a blocking expectation failed.
* `4` — the artifact was written and a blocking expectation was never evaluated.

Exit codes `3` and `4` are enforcement signals. A consuming project's CI step fails its build on either non-zero exit, exactly as it would for any other command. The artifact is still written so the run can publish it. Which expectations block is the record's decision, through each expectation's `blocking` flag.

Graphics and diagram semantics have no runtime probe. Those expectations use `assert: custom` and resolve through human review; see the [Graphics ARIA and SVG-AAM reference](references/frameworks/graphics-aria-svg-aam.md) for the boundary between what automation can decide and what it cannot.

#### Rendering a record for review

A record states what must be true and how it is checked, but carries no implementation or delivery scope. Reviewers who want prose rather than YAML can render one:

```bash
uv run --project <skill-root> <skill-root>/scripts/runtime_a11y/__main__.py project-intent \
  --record design-intent/<surface-id>.intent.yaml \
  --out handoff.md
```

Output is deterministic and renders only what the record already says, adding no analysis and no verification results. Generate it on demand rather than committing it, so it cannot drift from the record it describes. Without `--out` the Markdown goes to stdout.

## Usage notes

* Treat this skill as the default accessibility entrypoint for planning and review workflows.
* Resolve framework and phase guidance through this skill instead of duplicating its internal reference paths in agents or instructions.
* Use the scanner CLI when you need normalized findings from an accessibility scan.


