---
name: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, and the Accessibility Planner workflow."
license: MIT
compatibility: "Requires Python 3.11+ and uv; the scanner additionally needs Node.js and network access to run 'npx --yes @axe-core/cli@4.12.1'."
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-19"
---

# Accessibility — Skill Entry

This skill is the canonical accessibility reference contract for HVE Core. Agents and instructions invoke this skill by name and rely on it to own framework reference resolution, phase guidance resolution, and the scanner CLI entrypoint.

## Framework references

* [WCAG 2.2](references/frameworks/wcag-22.md)
* [ARIA Authoring Practices Guide](references/frameworks/aria-apg.md)
* [Cognitive Accessibility Guidance](references/frameworks/coga.md)
* [Section 508](references/frameworks/section-508.md)
* [EN 301 549](references/frameworks/en-301-549.md)

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

The runtime probe harness ([scripts/runtime_a11y](scripts/runtime_a11y)) runs Playwright-based accessibility probes against a project-specific surface inventory and aggregates the results into a coverage matrix. Use the [accessibility-coverage-matrix prompt](../../../prompts/accessibility/accessibility-coverage-matrix.prompt.md) for workflow orchestration and the [accessibility-surface-inventory subagent](../../../agents/accessibility/subagents/accessibility-surface-inventory.agent.md) as the canonical producer of the runtime config.

#### Invocation

```bash
uv run python -m runtime_a11y run-all --config a11y-runtime.config.json --out results.json
uv run python -m runtime_a11y probe <probeId> --config a11y-runtime.config.json
```

* `--out` writes the aggregated JSON document to disk.
* `--base-url` overrides the configured base URL.
* `--trace` captures Playwright traces and screenshots.
* `--allow-external` confirms intentional probing of a non-loopback host.

#### Config summary

The harness loads [scripts/runtime_a11y/config-schema.json](scripts/runtime_a11y/config-schema.json) and expects a runtime config with fields such as `baseUrl`, `serveMode`, `allowlist`, `routes`, `surfaces`, and `probeScoping`. The config defines the surfaces and interaction states the probes execute. A runtime guard blocks non-loopback targets unless the host is allowlisted or the caller supplies `--allow-external`.

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

Non-WCAG defect-scan probes (framework `defect-scan`):

* `probe-console-errors` (console/page errors)
* `probe-broken-links` (same-origin 404s)
* `probe-dom-hygiene` (duplicate ids, positive tabindex, missing/duplicate landmarks)
* `probe-title-lang` (empty title, invalid `lang`)

Method adequacy is encoded in [scripts/runtime_a11y/probe-criteria-map.json](scripts/runtime_a11y/probe-criteria-map.json). Each entry records which criteria a probe can decide and which criteria it can only inform. A result only counts as adequate when the winning method is allowed by that mapping.

#### Coverage engine outputs

The matrix engine in [scripts/runtime_a11y/matrix](scripts/runtime_a11y/matrix) expands the criterion x surface x state grid, merges updates deterministically, and preserves human-confirmed findings over lower-priority automation. It computes adequate-coverage percentages by framework and overall, then renders coverage-matrix JSON and markdown outputs named `coverage-matrix-{repo-slug}.json` and `coverage-matrix-{repo-slug}.md`.

#### Exit codes

* `0` indicates the harness completed successfully, even when probes reported findings.
* Non-zero exit codes indicate a harness error such as invalid config, a failed probe, missing Node.js, missing browser support, or a blocked target.

#### Runtime dependencies

The harness uses `npx` at run time to install pinned dependencies `playwright@1.61.1` and `@axe-core/playwright@4.12.1`. It targets the system Google Chrome browser through `channel: 'chrome'`, so no skill-local `package.json` or `node_modules` directory is required.

### CI regression gate

Use the ready-to-copy workflow template at [references/ci/accessibility-coverage.workflow-template.yml](references/ci/accessibility-coverage.workflow-template.yml) as the documentation-first integration point for a target project. Copy it into a real workflow under `.github/workflows/` only after the target project commits an `a11y-runtime.config.json` and has a build/serve path that the template can invoke.

The template mirrors the Docusaurus workflow recipe by provisioning system Chrome, setting up Node 24 plus Python and `uv`, building the target, serving it under a configurable base URL, and running `uv run python -m runtime_a11y run-all --config a11y-runtime.config.json --out results.json`. It treats the high-confidence probes as blocking failures: `probe-axe`, `probe-dom-hygiene`, `probe-broken-links`, `probe-console-errors`, `probe-target-size`, `probe-contrast`, and `probe-reflow-resize`. The heuristic probes such as `use-of-color`, `hover-focus`, `link-purpose`, `name-in-label`, `keyboard-traversal`, `widget-keyboard`, `aria-tree`, and `focus-*` are surfaced as informational results so they can guide follow-up work without blocking initial adoption.

The parity reference at [references/ci/probe-spec-parity.md](references/ci/probe-spec-parity.md) maps each runtime probe to the closest existing Docusaurus e2e spec and highlights gaps where no equivalent spec currently exists.

## Usage notes

* Treat this skill as the default accessibility entrypoint for planning and review workflows.
* Resolve framework and phase guidance through this skill instead of duplicating its internal reference paths in agents or instructions.
* Use the scanner CLI when you need normalized findings from an accessibility scan.


