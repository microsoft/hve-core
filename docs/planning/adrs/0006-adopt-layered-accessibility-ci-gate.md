---
id: "0006"
title: "Adopt a layered accessibility CI gate as a blocking merge guardrail"
description: "Adopt a layered accessibility CI architecture for the Docusaurus site that runs static linting, component-level axe assertions, behavioral end-to-end checks, and a full-site crawl as a single blocking job, gating merges at a zero-violation full-site threshold against WCAG 2.2 AA."
author: "HVE Core Maintainers"
ms.date: "2026-07-16"
ms.topic: "reference"
status: "accepted"
proposed_date: "2026-06-14"
accepted_date: "2026-06-14"
deciders:
  - "HVE Core Maintainers"
consulted:
  - "Accessibility reviewer / a11y SME role"
  - "Documentation contributors"
informed:
  - "Broader contributor community"
effort: "M"
tags:
  - "accessibility"
  - "a11y"
  - "wcag"
  - "ci"
  - "docusaurus"
  - "testing"
affected_components:
  - ".github/workflows/docusaurus-tests.yml"
  - "docs/docusaurus/eslint.config.mjs"
  - "docs/docusaurus/e2e/site-crawl.spec.ts"
  - "docs/docusaurus/playwright.config.ts"
  - "docs/docusaurus/jest.config.js"
  - "docs/docusaurus/package.json"
  - "docs/docusaurus/e2e/"
supersedes: null
superseded-by: null
related: []
asr_triggers:
  - kind: "compliance"
    evidence: "docs/docusaurus/e2e/site-crawl.spec.ts now runs the current axe-based site-crawl gate with WCAG 2.x A/AA plus `wcag22aa` and `best-practice` tags at threshold 0, and .github/workflows/docusaurus-tests.yml runs that scan as a blocking step with no soft-fail."
    note: "The conformance target is WCAG 2.2 AA and the full-site scan must report zero violations to pass; there is no soft-fail escape hatch."
  - kind: "maintainability"
    evidence: "The SearchBar swizzle couples the site to @easyops-cn/docusaurus-search-local, so the behavioral and full-site layers must keep passing across upstream plugin churn (NFR-001)."
    note: "Layered coverage absorbs upstream DOM/ARIA drift without a bespoke pipeline; the gate lives inside docs/docusaurus and the shared workflow."
  - kind: "maintainability"
    evidence: "The canonical scan set in docs/docusaurus/e2e/_helpers/pages.ts and the e2e specs under docs/docusaurus/e2e/ are extended as new page types ship (RSK-2, G-004)."
    note: "New page types are onboarded by extending the canonical URL list and adding targeted specs rather than re-architecting the gate."
success_criteria:
  - metric: "full-site-axe-violations"
    target: "the Playwright site-crawl spec reports zero WCAG 2.2 AA violations across the canonical URL set"
    measurement_window: "per-PR"
    source: "docs/docusaurus/e2e/site-crawl.spec.ts"
  - metric: "a11y-gate-blocking"
    target: "the accessibility job blocks merge on any layer failure with no soft-fail default"
    measurement_window: "every PR run"
    source: ".github/workflows/docusaurus-tests.yml"
  - metric: "static-lint-clean"
    target: "eslint-plugin-jsx-a11y reports zero accessibility errors on the Docusaurus source tree"
    measurement_window: "per-PR"
    source: "docs/docusaurus/eslint.config.mjs"
decisionMetadata:
  driverToTriggerMap:
    "Regression prevention before merge": "ASR-compliance-conformance-gate"
    "Contributor trust through low flakiness": "ASR-maintainability-upstream-churn"
    "Layered coverage of defect classes": "ASR-compliance-conformance-gate"
    "Reusability as a lighthouse pattern": "ASR-evolvability-scan-set"
    "Maintainability under upstream churn": "ASR-maintainability-upstream-churn"
    "Fast CI feedback": "ASR-maintainability-upstream-churn"
    "Evolvability for new page types": "ASR-evolvability-scan-set"
---

> **Update (2026-06-30):** This ADR was revised in place to reflect the migration of the
> full-site crawl from pa11y-ci to the `@axe-core/playwright` site-crawl spec
> (`docs/docusaurus/e2e/site-crawl.spec.ts`). pa11y-ci, `.pa11yci`, and puppeteer were removed;
> the full-site and behavioral layers now both run on Playwright, so the gate spans three tools
> (`eslint-plugin-jsx-a11y`, `jest-axe`, Playwright with `@axe-core/playwright`) across four
> layers. The decision to run a layered, blocking accessibility gate at a zero-violation
> full-site threshold is unchanged.

## Context

The Docusaurus documentation site under `docs/docusaurus/` needs an
accessibility regression guardrail that runs before merge rather than as a
periodic audit. Different accessibility defect classes surface at different
layers: missing roles and labels are best caught statically, component-level
ARIA and contrast regressions surface when a component renders, keyboard and
focus behavior only appears when a browser drives the page, and whole-page
violations only emerge against the built, served site. A single tool covers one
of these layers well and the others poorly.

The decision is how to shape the accessibility CI for this site so it (a)
prevents accessibility regressions from merging, (b) stays trustworthy enough
that contributors do not learn to ignore it, (c) covers the distinct defect
classes above, and (d) can serve as a reusable lighthouse pattern for other
sites. The gate must run inside the existing
`.github/workflows/docusaurus-tests.yml` job rather than a bespoke pipeline,
must validate against WCAG 2.2 AA, and the full-site scan implemented by the
Playwright `@axe-core/playwright` site-crawl spec
(`docs/docusaurus/e2e/site-crawl.spec.ts`) must gate at a zero-violation
threshold with no soft-fail. The static layer is configured in `docs/docusaurus/eslint.config.mjs`,
the component layer in `docs/docusaurus/jest.config.js`, the behavioral layer in
`docs/docusaurus/playwright.config.ts` with specs under `docs/docusaurus/e2e/`,
and the npm scripts that wire these together live in
`docs/docusaurus/package.json`.

> Source: `docs/planning/prds/docusaurus-accessibility-conformance-prd.md`, conformance target and validation-scope requirements.
> Source: `docs/planning/brds/docusaurus-accessibility-conformance-brd.md`, originating business goals and accessibility conformance drivers.
> Source: `.copilot-tracking/research/2026-06-13/docusaurus-accessibility-gold-gaps-research.md`, four-layer toolchain gap analysis.

## Decision Drivers

* Regression prevention before merge
* Contributor trust through low flakiness
* Layered coverage of defect classes
* Reusability as a lighthouse pattern
* Maintainability under upstream churn
* Fast CI feedback
* Evolvability for new page types

## Considered Options

* Option A: Layered multi-tool gate. Run static linting (`eslint-plugin-jsx-a11y`), component-level axe assertions (`jest-axe`), behavioral end-to-end checks (Playwright with `@axe-core/playwright`), and a full-site axe crawl (Playwright `@axe-core/playwright` site-crawl spec) as one blocking CI job at a zero-violation full-site threshold.
* Option B: Single full-site scanner. Run only a Playwright axe crawl against the served site as the sole accessibility gate.
* Option C: Runtime-only. Run only Playwright with axe injection against a running browser, with no static linting and no full-site crawl.

## Decision Outcome

| Decision driver                         | Option A | Option B | Option C |
|-----------------------------------------|----------|----------|----------|
| Regression prevention before merge      | Yes      | Partial  | Partial  |
| Contributor trust through low flakiness | Yes      | Yes      | Partial  |
| Layered coverage of defect classes      | Yes      | No       | Partial  |
| Reusability as a lighthouse pattern     | Yes      | Partial  | No       |
| Maintainability under upstream churn    | Partial  | Yes      | Partial  |
| Fast CI feedback                        | Partial  | Yes      | Yes      |
| Evolvability for new page types         | Yes      | Partial  | Partial  |

Chosen option: **"Option A: Layered multi-tool gate"**, because it is the only
option that covers every distinct accessibility defect class while still gating
merges at a zero-violation full-site threshold. Option B catches whole-page
violations on the served site but misses component-level and keyboard/focus
regressions and gives authors no fast static signal, so it under-covers the
defect classes the driver names. Option C exercises real keyboard and focus
behavior but drops both the cheap static signal and the authoritative full-site
crawl, leaving whole-page and lint-detectable defects unguarded. Option A's
costs (more moving parts and a longer overall job) are accepted as the price of
defense in depth, and they fall on CI rather than on authors.

### Consequences

* Good, because each accessibility defect class is caught at the cheapest layer that can detect it, from static lint through full-site crawl.
* Good, because the full-site Playwright axe crawl gates at a zero-violation threshold with no soft-fail, so whole-page WCAG 2.2 AA regressions cannot merge.
* Good, because the four layers are wired through standard npm scripts and the shared workflow, making the gate a reusable lighthouse pattern other sites can adopt.
* Bad, because the layered gate spans several configuration surfaces to keep aligned, increasing the maintenance footprint under upstream churn.
* Bad, because the behavioral layer drives a real browser and is the most likely source of flakiness, which can erode contributor trust if not contained.
* Bad, because cross-browser behavioral coverage is deferred: the workflow installs Chromium only, so Firefox and WebKit keyboard/focus paths are not yet exercised in CI.
* Neutral, because the conformance target is fixed at WCAG 2.2 AA for all layers; tightening or relaxing it is a follow-up decision, not a per-run toggle.
* Neutral, because the canonical scan set is intentionally small at adoption and grows as new page types ship rather than enumerating every route up front.

### Confirmation

Compliance with this decision is confirmed by three mechanisms:

1. CI enforcement: `.github/workflows/docusaurus-tests.yml` runs the static, component, full-site, and behavioral layers in one job, and the full-site scan fails the job on any violation because `docs/docusaurus/e2e/site-crawl.spec.ts` gates with `violations: []` at threshold 0.
2. Local reproduction: the `lint:a11y`, `test:coverage`, and historical `test:e2e` scripts in `docs/docusaurus/package.json` reproduced each layer outside CI. The current replacement for the browser command is `ci:test:e2e`, which runs both the behavioral specs and the full-site axe crawl.
3. Configuration review: the conformance standard and URL set live in `docs/docusaurus/e2e/site-crawl.spec.ts` and `docs/docusaurus/e2e/_helpers/pages.ts`, and the static, component, and behavioral configs live in `docs/docusaurus/eslint.config.mjs`, `docs/docusaurus/jest.config.js`, and `docs/docusaurus/playwright.config.ts`, so the gate's contract is reviewable in version control.

## Pros and Cons of the Options

### Option A: Layered multi-tool gate

Layering is the only approach that matches tools to the defect classes they
detect best, and running them as one blocking job makes coverage a property of
the merge gate rather than of reviewer diligence.

* Good, because static lint gives authors the fastest possible signal on missing roles and labels before anything renders.
* Good, because `jest-axe` catches component-level ARIA and contrast regressions at render time, close to the code that caused them.
* Good, because Playwright with `@axe-core/playwright` exercises real keyboard and focus behavior that static and render-time checks cannot see.
* Good, because the Playwright axe crawl is the authoritative whole-page gate at a zero-violation threshold.
* Neutral, because the layers share one workflow and standard npm scripts, so the added structure is centralized rather than scattered.
* Bad, because the layered gate's configuration surfaces must stay aligned as the toolchain and upstream plugins evolve.
* Bad, because the behavioral browser layer is the most flakiness-prone and needs containment to preserve contributor trust.

### Option B: Single full-site scanner

A Playwright axe-only gate is the simplest to operate and the least flaky, but it
trades away coverage of exactly the defect classes that do not surface in a
whole-page crawl.

* Good, because a single tool and config is the cheapest to run and maintain.
* Good, because a full-site crawl on the served site has low non-determinism relative to a driven browser.
* Bad, because it gives authors no fast static signal and no component-level isolation of regressions.
* Bad, because it cannot assert keyboard and focus behavior, leaving a major WCAG defect class unguarded.

### Option C: Runtime-only

A Playwright-and-axe-only gate proves real interaction behavior but discards
both the cheap static signal and the authoritative full-site crawl, so its
coverage is uneven.

* Good, because it exercises real keyboard, focus, and interaction behavior end to end.
* Good, because behavioral specs double as regression tests for navigation and focus management.
* Bad, because it provides no fast static lint signal for authors.
* Bad, because it has no authoritative full-site crawl, so whole-page violations on un-scripted routes can merge.

## Architecture

The gate is one CI job composed of four cooperating layers. The static layer
runs first against the source tree, the component layer asserts axe rules at
render time, and once the site is built and served the full-site crawl and the
behavioral end-to-end checks run against it. Any layer failing fails the job,
and the full-site crawl enforces a zero-violation threshold with no soft-fail.
The diagram below traces a pull request through the layers to the merge gate.

```text
 Pull Request
      |
      v
+--------------------------------------------------------------+
|   docusaurus job (.github/workflows/docusaurus-tests.yml)    |
|                                                              |
|  Layer 1: eslint-plugin-jsx-a11y   (static / lint src)       |
|       |                                                      |
|       v                                                      |
|  Layer 2: jest-axe                 (component / render)      |
|       |                                                      |
|       v                                                      |
|  build + serve:ci                                            |
|       |                                                      |
|       +--> Layer 3: Playwright axe crawl (full-site, threshold 0) |
|       |                                                      |
|       +--> Layer 4: Playwright + @axe-core/playwright        |
|                                    (behavioral e2e)          |
+--------------------------------------------------------------+
      |
      v
  merge gate (blocking, no soft-fail)
```

## Risks and Mitigations

* Risk: the layered gate spans several configuration surfaces to keep aligned, increasing the maintenance footprint under upstream churn. Mitigation: centralize the layers in one workflow and the `docs/docusaurus/package.json` scripts, and pin tool versions through the existing dependency-pinning checks.
* Risk: the behavioral browser layer is the most likely source of flakiness, which can erode contributor trust if it produces false failures. Mitigation: scope the behavioral specs under `docs/docusaurus/e2e/` to deterministic flows, use explicit waits and focus helpers, and keep the highest-risk keyboard/focus paths narrow.
* Risk: cross-browser behavioral coverage is deferred because the workflow installs Chromium only, so Firefox and WebKit regressions can slip through. Mitigation: track cross-browser expansion as a follow-up that extends `playwright.config.ts` to the highest-risk keyboard/focus paths on Firefox and WebKit once the Chromium gate is stable.

## Rollback / Exit Strategy

If this decision is reversed, the rollback path is:

1. Remove the accessibility layers from `.github/workflows/docusaurus-tests.yml`, leaving the build and existing test steps intact.
2. Remove the `lint:a11y` and historical `test:e2e` wiring (currently named `ci:test:e2e`) from `docs/docusaurus/package.json` and the corresponding configs in `docs/docusaurus/eslint.config.mjs`, `docs/docusaurus/e2e/site-crawl.spec.ts`, and `docs/docusaurus/playwright.config.ts`.
3. Retain or remove the `docs/docusaurus/e2e/` specs depending on whether behavioral coverage is kept for non-accessibility reasons.
4. Document the reversal in a superseding ADR that links back to this one and sets `superseded-by` here.

No data migration is required; removing the gate leaves the site content untouched.

## Affected Components

* .github/workflows/docusaurus-tests.yml
* docs/docusaurus/eslint.config.mjs
* docs/docusaurus/e2e/site-crawl.spec.ts
* docs/docusaurus/playwright.config.ts
* docs/docusaurus/jest.config.js
* docs/docusaurus/package.json
* docs/docusaurus/e2e/

## More Information

* CI job and gate wiring: `.github/workflows/docusaurus-tests.yml`
* Static layer config: `docs/docusaurus/eslint.config.mjs`
* Full-site scan config (standard and threshold): `docs/docusaurus/e2e/site-crawl.spec.ts`
* Behavioral layer config: `docs/docusaurus/playwright.config.ts`
* Component layer config: `docs/docusaurus/jest.config.js`
* Layer npm scripts: `docs/docusaurus/package.json`
* Behavioral specs: `docs/docusaurus/e2e/`

This decision should be re-visited if the full-site scan threshold or
soft-fail posture changes, if cross-browser behavioral coverage is promoted
from a deferred follow-up to a required gate, or if the conformance target
moves off WCAG 2.2 AA.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
