---
title: "Docusaurus Accessibility Conformance - Product Requirements Document"
description: "Product requirements for achieving and continuously verifying WCAG 2.2 AA accessibility conformance on the HVE-Core documentation site"
sidebar_position: 3
author: "HVE-Core Maintainers"
ms.date: 2026-06-14
ms.topic: reference
---

<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Docusaurus Accessibility Conformance - Product Requirements Document (PRD)
Version 1.0 | Status Approved | Owner Core Maintainers | Team HVE-Core (Open Source) | Target End of June 2026 | Lifecycle In Progress

## Progress Tracker
| Phase | Done | Gaps | Updated |
|-------|------|------|---------|
| Context | Yes | — | 2026-06-13 |
| Problem & Users | Yes | — | 2026-06-13 |
| Scope | Yes | — | 2026-06-13 |
| Requirements | Yes | — | 2026-06-13 |
| Metrics & Risks | Yes | — | 2026-06-13 |
| Operationalization | Yes | — | 2026-06-14 |
| Finalization | Yes | — | 2026-06-14 |
Unresolved Critical Questions: 0 | TBDs: 0

## 1. Executive Summary
### Context
HVE-Core is a public, open-source project whose Docusaurus documentation site (served under `/hve-core/`) is the primary public-facing surface for contributors and users. As a public OSS project, the site is expected to meet baseline accessibility standards (target WCAG 2.2 AA) so that people who rely on assistive technology, keyboard navigation, or low-vision settings can use the documentation without barriers. This initiative closes identified WCAG 2.2 AA conformance gaps and establishes automated CI guardrails that continuously verify accessibility so regressions are caught before they reach the public site.
### Core Opportunity
Beyond meeting the compliance floor, the deeper intent is for HVE-Core to act as a **lighthouse project** — a credible, reusable reference for building and continuously verifying accessible documentation. The documentation site is the **pilot implementation** of a repeatable accessibility pattern intended for adoption by other HVE-Core surfaces and downstream projects.
### Goals
| Goal ID | Statement | Type | Baseline | Target | Timeframe | Priority |
|---------|-----------|------|----------|--------|-----------|----------|
| G-001 | Bring all rendered page types across the documentation site into general WCAG 2.2 AA conformance, starting with identified gaps | Compliance | 12 automated issues (contrast-dominant) across the site | 0 automated issues; all rendered page types conformant | End of June 2026 | Critical |
| G-002 | Establish automated, continuous accessibility verification in CI to prevent regressions | Quality / Ops | No a11y gate in CI | Accessibility gate active at threshold 0 | At merge | Critical |
| G-003 | Produce a repeatable, documented accessibility pattern other surfaces/projects can adopt | Reputation | No documented pattern | Pattern documented for independent replication | Post-merge | High |
| G-004 | Define a path to expand from general conformance toward full conformance across all impacted area paths (COGA, time-based media, remaining WCAG categories) | Reputation / Compliance | General only | All impacted area paths committed | Roadmap scoped by end of July 2026; execution targeted end of 2026 | Medium |

### Objectives (Optional)
| Objective | Key Result | Priority | Owner |
|-----------|------------|----------|-------|
| Close identified WCAG 2.2 AA gaps | pa11y-ci, axe, and e2e checks pass at threshold 0 | Critical | Core Maintainers |
| Continuous accessibility verification | CI blocks merge on any accessibility violation | Critical | Core Maintainers |
| Reusable accessibility pattern | Guardrail recipe documented and replicable | High | Core Maintainers |

## 2. Problem Definition
### Current Situation
Accessibility relied on manual attention during code review, with no automated gate. A reviewer might or might not catch an accessibility regression, and nothing prevented a non-conformant change from reaching the published site. The site contained several WCAG 2.2 AA conformance gaps: decorative hub-card icons exposed to screen readers (SC 1.1.1), in-content links distinguished by color alone (SC 1.4.1), missing visible focus indicators (SC 2.4.7), and insufficient text contrast in dark mode and local search results (SC 1.4.3, SC 1.4.11).
### Problem Statement
As a public open-source project, the HVE-Core documentation site must meet baseline accessibility expectations (WCAG 2.2 AA) so that contributors and users who rely on assistive technology, keyboard navigation, or low-vision settings are not excluded. Today the site has conformance gaps and there is no automated guardrail to prevent regressions. Beyond being compliant, the deeper goal is for HVE-Core to serve as a lighthouse project: a credible, reusable reference for building and continuously verifying accessible documentation the right way.
### Root Causes
* No automated accessibility gate in CI; conformance depended on inconsistent manual review.
* Accessibility considerations (decorative imagery handling, non-color link cues, focus indicators, contrast) were not enforced at the component or site level.
### Impact of Inaction
Screen-reader, keyboard-only, and low-vision users face barriers using the docs; an inaccessible OSS docs site undermines HVE-Core's leadership positioning; without automated gates, fixes can silently regress; and the site falls short of WCAG 2.2 AA / Section 508 / EN 301 549 baseline expectations.

## 3. Users & Personas
| Persona | Goals | Pain Points | Impact |
|---------|-------|------------|--------|
| Screen-reader user | Understand content without noise | Decorative icons announced as content (SC 1.1.1) | Decorative imagery hidden from AT |
| Keyboard-only user | See where focus is, reach all controls | No visible focus indicator (SC 2.4.7) | Visible focus outlines added |
| Low-vision / color-vision user | Read text, distinguish links | Color-only links; low contrast in dark mode and search (SC 1.4.1, 1.4.3, 1.4.11) | Underlines + improved contrast |
| Contributor / Maintainer | Avoid shipping regressions | No automated a11y safety net | CI guardrails catch regressions early |
### Journeys (Optional)
A contributor opens a PR touching the docs site; CI runs static a11y lint, component axe tests, Playwright focus/keyboard e2e checks, and a pa11y-ci site scan; any violation fails the pipeline and blocks merge, demonstrating conformance continuously before changes reach the public site.

## 4. Scope
### In Scope
* WCAG 2.2 AA conformance fixes for identified gaps on the HVE-Core Docusaurus site (`docs/docusaurus/`): hide decorative hub-card icons from AT; distinguish in-content links by more than color (underlines) and add visible `focus-visible` outlines; improve text contrast in dark mode and local search results.
* Conformance claim covers all rendered page types site-wide — docs articles, hub/landing pages, the homepage, navbar and sidebar chrome, blog/announcements, and the search bar / search results.
* Automated accessibility and quality guardrails in CI: component-level axe tests (Jest + axe-core), end-to-end focus/keyboard checks (Playwright), site-level scanning (pa11y-ci, WCAG2AA, threshold 0), static a11y linting (eslint-plugin-jsx-a11y), and test coverage reporting (Jest coverage to Codecov via OIDC).
* Treating the documentation site as the pilot implementation of a repeatable accessibility pattern.
* Producing the documented, reusable accessibility pattern (the guardrail recipe and its CI wiring) as a deliverable.
### Out of Scope (justify if empty)
* Organization-wide accessibility programs beyond the HVE-Core documentation site.
* Rolling the pattern out to other specific surfaces/projects (future work; this PRD establishes the reusable pattern, not its downstream adoption).
* Conformance levels beyond WCAG 2.2 AA (e.g., AAA) unless explicitly added later.
* Manual assistive-technology / screen-reader validation (e.g., NVDA, JAWS, VoiceOver) — this phase relies on automated checks only.
### Assumptions
* CI runners can build the site and run headless browsers (Playwright, pa11y-ci).
* Codecov (OIDC) remains available for coverage upload.
* The four enumerated page types (hub/landing, doc article, search results, homepage) represent the site's templates.
### Constraints
* Conformance target is WCAG 2.2 AA, not AAA — defines the "done" bar. WCAG 2.2 AA supersedes 2.1 AA; the identified gap criteria (SC 1.1.1, 1.4.1, 2.4.7, 1.4.3, 1.4.11) are shared across both versions. (Supersedes the BRD's 2.1 AA target per product decision.)
* pa11y-ci threshold is 0 — any new violation on scanned pages blocks merge.
* Conformance is validated by automated tooling only; manual assistive-technology / screen-reader validation is out of scope for this phase.

## 5. Product Overview
### Value Proposition
A documentation site that is accessible by default and stays accessible automatically: identified WCAG 2.2 AA gaps are closed and a CI guardrail prevents regressions, while the approach is documented as a reusable pattern others can adopt.
### Differentiators (Optional)
* Continuous, automated accessibility verification rather than one-time remediation.
* Lighthouse exemplar: a reproducible guardrail recipe other surfaces can copy without specialist support.
### UX / UI (Conditional)
Visual changes: decorative icons hidden from AT; in-content links carry a non-color cue (underline); visible `focus-visible` outlines on interactive controls; improved text/UI contrast in light mode, dark mode, and search results. UX Status: Implemented in changeset (REF-1 through REF-3).

## 6. Functional Requirements
| FR ID | Title | Description | Goals | Personas | Priority | Acceptance | Notes |
|-------|-------|------------|-------|----------|----------|-----------|-------|
| FR-001 | Decorative imagery not exposed to AT | Decorative imagery on the docs site must not be announced as meaningful content by assistive technology | G-001 | Screen-reader user | Critical | Decorative hub-card icons are not announced by screen readers; verified via axe component test (SC 1.1.1) | `BoxCard.tsx` `aria-hidden` / empty `alt` |
| FR-002 | Links distinguishable beyond color | In-content links must be distinguishable without relying on color alone | G-001 | Low-vision / color-vision user | Critical | Body links present a non-color visual cue (underline); verified via site scan / e2e (SC 1.4.1) | `custom.css` (WI-06) |
| FR-003 | Visible keyboard focus indicators | Interactive elements must show a visible focus indicator when navigated by keyboard | G-001 | Keyboard-only user | Critical | A visible focus indicator appears on keyboard focus across interactive controls; verified via Playwright e2e (SC 2.4.7) | `focus-visible` outlines |
| FR-004 | Sufficient text contrast | Text, including dark mode and search results, must meet WCAG AA contrast minimums | G-001 | Low-vision user | Critical | Text and UI contrast meet SC 1.4.3 / 1.4.11 in light, dark, and search surfaces; verified via pa11y-ci | `custom.css`, `SearchBar/index.jsx` |
| FR-005 | Automated accessibility gate in CI | CI must automatically verify accessibility on the docs site and block regressions | G-002 | Contributor / Maintainer | Critical | CI runs component, e2e, and site-level accessibility checks and fails the pipeline on any violation | `docusaurus-tests.yml` |
| FR-006 | Continuous coverage reporting | CI must report documentation test coverage to Codecov with an 80% project gate | G-002 | Maintainer | High | Coverage is generated and uploaded to Codecov on docs changes (flag `docusaurus`); project gate set at 80% | OIDC upload |
| FR-007 | Reusable, documented accessibility pattern | The accessibility approach must be documented so other surfaces/projects can adopt it | G-003 | Maintainer, downstream adopter | High | Pattern (guardrail recipe + CI wiring) is documented sufficiently for independent replication | Deliverable |
### Feature Hierarchy (Optional)
```plain
Accessibility Conformance
├── Conformance fixes (FR-001..FR-004)
│   ├── Decorative imagery handling
│   ├── Non-color link cues + focus indicators
│   └── Contrast (light / dark / search)
└── CI guardrail (FR-005..FR-007)
    ├── Static lint (eslint-plugin-jsx-a11y)
    ├── Component axe tests (Jest + axe-core)
    ├── E2E focus/keyboard (Playwright)
    ├── Site scan (pa11y-ci, WCAG2AA, threshold 0)
    ├── Coverage upload (Codecov)
    └── Documented reusable pattern
```

## 7. Non-Functional Requirements
| NFR ID | Category | Requirement | Metric/Target | Priority | Validation | Notes |
|--------|----------|------------|--------------|----------|-----------|-------|
| NFR-001 | Accessibility | Scanned pages conform to WCAG 2.2 AA | pa11y-ci violations = 0 | Critical | pa11y-ci CI run (blocks merge) | `.pa11yci` threshold 0 |
| NFR-002 | Accessibility | Components pass automated a11y checks | axe-core violations = 0 | Critical | Jest + @axe-core | BoxCard axe test |
| NFR-003 | Reliability | Accessibility CI checks are deterministic and non-flaky | e2e/site scans pass consistently (no false blocks) | High | Playwright e2e + pa11y-ci | Stabilize selectors, add retries (RSK-1) |
| NFR-004 | Maintainability | New/changed page templates are added to the canonical scan set | Scan set reviewed when a template changes | High | PR review checklist | Canonical scan set = one representative URL per rendered page template (homepage, hub/landing, doc article, blog/announcement, search results); prevents silent conformance gaps (RSK-2) |
| NFR-005 | Observability | CI reports per-check accessibility pass/fail and coverage | CI summary + Codecov report on every docs change | High | CI run + Codecov | Flag `docusaurus` |
| NFR-006 | Performance | Added accessibility/coverage checks keep CI runtime acceptable | Incremental a11y + coverage steps ≤ 5 min; total `docusaurus-tests` job ≤ 10 min wall-clock | Medium | CI run timing | Incremental cost only |
| NFR-007 | Quality | Docs component test coverage meets the project gate | Codecov project coverage ≥ 80% (flag `docusaurus`) | High | Codecov gate | Coverage gate; reported, with 80% threshold |
| NFR-008 | Maintainability | Static accessibility lint enforced on docs components | eslint-plugin-jsx-a11y passes with 0 errors | High | CI lint step (blocks merge) | Regression prevention alongside the CI gate |

## 8. Data & Analytics (Conditional)
### Inputs
Component source and rendered docs pages produced by the Docusaurus build, evaluated by static lint, axe-core, Playwright, and pa11y-ci.
### Outputs / Events
Per-page accessibility violation counts (pa11y-ci), component axe results, e2e pass/fail, and coverage metrics.
### Instrumentation Plan
| Event | Trigger | Payload | Purpose | Owner |
|-------|---------|--------|---------|-------|
| a11y site scan | PR / docs change | violations per scanned page | Block regressions | Core Maintainers |
| component axe test | PR / docs change | axe violations per component | Block regressions | Core Maintainers |
| e2e focus/keyboard | PR / docs change | pass/fail per spec | Validate interaction | Core Maintainers |
| coverage upload | PR / docs change | coverage metrics (flag `docusaurus`) | Quality trend | Core Maintainers |
### Metrics & Success Criteria
| Metric | Type | Baseline | Target | Window | Source |
|--------|------|----------|--------|--------|--------|
| Rendered page types in general WCAG 2.2 AA conformance | North-star | 0 conformant (12 automated issues, contrast-dominant) | All rendered page types (100%) | End of June 2026 | pa11y-ci |
| Canonical scan set page templates covered | Coverage | Ad hoc | One representative URL per rendered page template | At merge | pa11y-ci (`.pa11yci`) |
| Automated a11y violations (pa11y-ci + axe) | Quality | 12 (aggregate pre-fix; contrast main category) | 0 | At merge | pa11y-ci, Jest + @axe-core |
| Keyboard/focus e2e checks passing | Quality | Failing (pre-fix) | 100% pass (8 specs) | At merge | Playwright |
| Docs component test coverage | Quality | TBD (pre-fix) | ≥ 80% (Codecov gate) | At merge | Jest / Codecov |
| Impacted area paths under full conformance | Roadmap | 0 (general only) | All (committed) | Scoped by end of July 2026; execution by end of 2026 | Conformance roadmap |

## 9. Dependencies
| Dependency | Type | Criticality | Owner | Risk | Mitigation |
|-----------|------|------------|-------|------|-----------|
| Codecov (OIDC) | External | Medium | Core Maintainers | Coverage signal lost if unavailable | Treat coverage as non-blocking signal |
| CI runner / Node | Tooling | High | Core Maintainers | Gate cannot run without headless browser support | Ensure runners support Playwright/pa11y-ci |

## 10. Risks & Mitigations
| Risk ID | Description | Severity | Likelihood | Mitigation | Owner | Status |
|---------|-------------|---------|-----------|-----------|-------|--------|
| RSK-1 | Automated checks flake and falsely block merges | Medium | Medium | Stabilize selectors, add retries, keep scans deterministic | Core Maintainers | Open |
| RSK-2 | New page types added without scan coverage | High | Medium | Review pa11y-ci scan set whenever a page template is added | Core Maintainers | Open |
| RSK-3 | "General conformance" mistaken for full per-page-type audit | Medium | Medium | Distinguish identified-gap closure from full audit; track via G-004 | Core Maintainers | Open |

## 11. Privacy, Security & Compliance
### Data Classification
No personal or sensitive data is processed; inputs are public documentation source and rendered pages.
### PII Handling
Not applicable — accessibility scans and coverage metrics contain no PII.
### Threat Considerations
Codecov upload uses OIDC (no long-lived token). CI executes only project-owned test tooling against the project's own build.
### Regulatory / Compliance (Conditional)
| Regulation | Applicability | Action | Owner | Status |
|-----------|--------------|--------|-------|--------|
| WCAG 2.2 AA | Primary conformance target | Close identified gaps; gate in CI | Core Maintainers | In progress |
| Section 508 | Referenced baseline | Aligns with WCAG 2.2 AA | Core Maintainers | Referenced |
| EN 301 549 | Referenced baseline | Aligns with WCAG 2.2 AA | Core Maintainers | Referenced |

## 12. Operational Considerations
| Aspect | Requirement | Notes |
|--------|------------|-------|
| Deployment | Fixes and CI guardrail ship together in this changeset | Single coherent effort |
| Rollback | Revert changeset; CI gate is additive and isolated to docs workflow | Low blast radius |
| Monitoring | CI run summary surfaces per-check accessibility pass/fail; Codecov reports coverage against the 80% gate | Core Maintainers own failure triage |
| Alerting | Accessibility checks (pa11y-ci, axe, e2e) block merge; coverage is reported to Codecov (80% gate) | Failed PR checks notify the PR author and assigned reviewer via GitHub; persistent `main`-branch failures escalate to Core Maintainers via CODEOWNERS / Actions failure notifications |
| Support | Maintainers own scan set and triage accessibility failures | Ongoing |
| Capacity Planning | Incremental CI execution time only; no external spend | Budget: incremental steps ≤ 5 min; total docs job ≤ 10 min (NFR-006) |

## 13. Rollout & Launch Plan
### Phases / Milestones
| Phase | Date | Gate Criteria | Owner |
|-------|------|--------------|-------|
| Phase 1 — Conformance fixes + CI guardrail | This changeset | Identified WCAG gaps closed; CI accessibility gate active at threshold 0 | Core Maintainers |
| Phase 2 — Expand toward broader conformance | Future (G-004) | Defined per-page-type conformance scope met | Core Maintainers |
### Feature Flags (Conditional)
| Flag | Purpose | Default | Sunset Criteria |
|------|---------|--------|----------------|
| N/A | No runtime feature flags; changes are static/CI-level | — | — |
### Communication Plan (Optional)
Contributors are informed via the contributing guide and PR feedback that the accessibility CI gate must stay green to merge; maintainers gain familiarity with pa11y-ci, axe, and Playwright outputs through repo docs.

## 14. Open Questions
| Q ID | Question | Owner | Deadline | Status |
|------|----------|-------|---------|--------|
| OQ-1 | Full-conformance timeframe (G-004) set: roadmap scope defined by end of July 2026, execution targeted end of 2026 | Core Maintainers | 2026-06-14 | Resolved |
| OQ-2 | Canonical pa11y-ci scan set = one representative URL per rendered page template (homepage, hub/landing, doc article, blog/announcement, search results), reviewed when a template changes (NFR-004) | Core Maintainers | 2026-06-14 | Resolved |
| OQ-3 | North-star reflects closure of identified gaps across all rendered page types (automated), not a full manual per-page audit | Core Maintainers | 2026-06-13 | Resolved |
| OQ-4 | CI runtime budget set: incremental a11y + coverage steps ≤ 5 min; total `docusaurus-tests` job ≤ 10 min wall-clock (NFR-006) | Core Maintainers | 2026-06-14 | Resolved |

## 15. Changelog
| Version | Date | Author | Summary | Type |
|---------|------|-------|---------|------|
| 0.1 | 2026-06-13 | HVE-Core Maintainers | Initial PRD draft derived from the Docusaurus Accessibility Conformance BRD | Draft |
| 0.2 | 2026-06-13 | HVE-Core Maintainers | Set target WCAG 2.2 AA, owner Core Maintainers, target end of June 2026; confirmed 12-issue baseline, 80% coverage gate, site-wide surfaces, automated-only scope | Draft |
| 0.3 | 2026-06-14 | HVE-Core Maintainers | Resolved remaining open items: G-004 full-conformance timeframe, canonical pa11y-ci scan set (OQ-2), CI runtime budget (NFR-006), and failure-triage / alert routing (Section 12) | Draft |
| 1.0 | 2026-06-14 | HVE-Core Maintainers | Maintainer review complete; status set to Approved, Finalization phase closed | Approved |

## 16. References & Provenance
| Ref ID | Type | Source | Summary | Conflict Resolution |
|--------|------|--------|---------|--------------------|
| REF-0 | BRD | `docs/planning/brds/docusaurus-accessibility-conformance-brd.md` | Source business requirements document | Authoritative source |
| REF-1 | Code | `docs/docusaurus/src/components/Cards/BoxCard.tsx` | Hub card decorative icon fix (SC 1.1.1) | — |
| REF-2 | Code | `docs/docusaurus/src/css/custom.css` | Link/focus/contrast styles (WI-06, WI-07) | — |
| REF-3 | Code | `docs/docusaurus/src/theme/SearchBar/index.jsx` | Search contrast theme override | — |
| REF-4 | Config | `docs/docusaurus/.pa11yci` | Site accessibility scan config (WCAG2AA, threshold 0) | — |
| REF-5 | Config | `docs/docusaurus/playwright.config.ts` | End-to-end test config (8 e2e specs) | — |
| REF-6 | Workflow | `.github/workflows/docusaurus-tests.yml` | CI accessibility + coverage pipeline | — |
### Citation Usage
Sections 1–13 are derived from the BRD (REF-0); technical references (REF-1 through REF-6) cite the changeset artifacts that implement each requirement.

## 17. Appendices (Optional)
### Glossary
| Term | Definition |
|------|-----------|
| WCAG 2.2 AA | Web Content Accessibility Guidelines 2.2, conformance level AA (supersedes 2.1 AA) |
| axe-core | Automated accessibility testing engine used in component tests |
| pa11y-ci | Command-line accessibility scanner run in CI against rendered pages |
| Playwright | Browser automation framework used for end-to-end accessibility checks |
### Additional Notes
The changeset references work item markers WI-06 (link/focus styling) and WI-07 (search/contrast styling), which may correspond to pre-existing tracked work items.

Generated 2026-06-13 by PRD Builder (mode: interactive)
<!-- markdown-table-prettify-ignore-end -->

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
