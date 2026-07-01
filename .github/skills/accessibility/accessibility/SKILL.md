---
name: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, and the Accessibility Planner workflow."
license: MIT
compatibility: "Requires Python 3.11+ and uv; the scanner additionally needs Node.js and network access to run 'npx --yes @axe-core/cli'."
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

## Usage notes

* Treat this skill as the default accessibility entrypoint for planning and review workflows.
* Resolve framework and phase guidance through this skill instead of duplicating its internal reference paths in agents or instructions.
* Use the scanner CLI when you need normalized findings from an accessibility scan.


