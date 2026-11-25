---
title: ACT Rules Format alignment for generated test cases
description: The W3C ACT Rules Format shape (applicability, expectation, passed/failed/inapplicable) and EARL reporting that the accessibility skill's generated test cases and probe results follow for interoperability
---

## ACT Rules Format Alignment

The skill's accessibility test cases and probe results follow the W3C ACT Rules Format so results interoperate with the ACT Rules ecosystem and downstream conformance reporting, rather than using a bespoke shape. This alignment lets a generated test case, a runtime probe, and a manual assistive-technology pass all report against the same criterion in a comparable way.

### Atomic Rule Shape

An ACT atomic rule has frontmatter and a body:

* Frontmatter: `id`, `name`, `rule_type: atomic`, `description`, `accessibility_requirements` (mapping to WCAG success criteria with `forConformance` / `passed` / `failed` / `inapplicable` semantics), and `input_aspects` (for example DOM Tree, CSS Styling, Accessibility Tree).
* Body: **Applicability** (which elements and states the rule applies to), one or more **Expectation** clauses (what must hold for those targets), Assumptions, Accessibility Support, and **Test Cases** enumerated as Passed / Failed / Inapplicable examples.

Composite rules combine the outcomes of atomic rules through a stated logic (all-of / any-of), which is how a single success criterion satisfied by any of several techniques is expressed.

The runtime probes map onto this shape directly: a probe's scoped surfaces and interaction states are the Applicability, the probe's verdict logic (for example `liveRegionStatus`, `virtualSrNameRoleStatus` in [../../scripts/runtime_a11y/runner/_core.mjs](../../scripts/runtime_a11y/runner/_core.mjs)) is the Expectation, and the smoke-test fixtures under [../../tests/runtime_a11y/runner/probe-smoke](../../tests/runtime_a11y/runner/probe-smoke) are the Passed / Failed / Inapplicable Test Cases.

### Generated evidence and review semantics

The skill's generated manual cases, synthetic execution evidence, real-driver evidence, and later qualified-human review are separate layers rather than one merged pass/fail stream. A generated manual case can remain unresolved while a synthetic or real execution result is recorded separately; the execution result never writes back to the matrix, coverage artifact, or human-review checkbox. ACT-style reasoning is therefore applied to the evidence record itself, while the matrix and EARL export remain the canonical downstream summary.

This distinction matters for the ARIA-AT catalog. The current catalog defaults are citation-bearing manual-only mappings because the richer AT-mode and quick-navigation semantics are not faithfully modeled by the current structured command boundary. Runtime overrides may create explicit synthetic contract tests, but those are non-pass candidate evidence and never a conformance claim. The resulting evidence can support a later qualified-human review, but it does not substitute for it.

### EARL Reporting

Results are reported in EARL (Evaluation and Report Language), the ACT ecosystem's interchange format, rendered by [../../scripts/runtime_a11y/matrix/_render_earl.py](../../scripts/runtime_a11y/matrix/_render_earl.py). The status-to-outcome mapping:

| Skill status               | ACT / EARL outcome                 |
|----------------------------|------------------------------------|
| pass (adequate method)     | passed / `earl:passed`             |
| pass (informs-only method) | cannot tell / `earl:cantTell`      |
| partial                    | cannot tell / `earl:cantTell`      |
| fail                       | failed / `earl:failed`             |
| not-applicable             | inapplicable / `earl:inapplicable` |
| unknown                    | untested / `earl:untested`         |

The `informs -> cantTell` mapping is the ACT/EARL expression of the consolidated skill's method-adequacy rule: a check that cannot decide a criterion reports `cantTell`, never a false `passed`.

Each emitted assertion has a stable identifier and records the test subject, criterion, interaction state, evidence method, method adequacy, result date, and evidence source. Run `runtime_a11y render-artifacts` to produce the EARL report together with its source matrix, human-readable summary, manual test plans, and bundle manifest. The generated files are:

* `coverage-matrix-{repo-slug}.json`
* `coverage-matrix-{repo-slug}.md`
* `accessibility-results-{repo-slug}.earl.jsonld`
* `manual-at-testplan-{repo-slug}.md`
* `manual-at-testplan-{repo-slug}.yaml`
* `accessibility-artifacts-{repo-slug}.json`

The manual plans contain applicable matrix cells that have at least one human-deciding adequate method and do not yet have an adequate passing result. Completed manual results are evidence inputs; they do not change the matrix until ingested through the normal merge path.

### Licensing

The ACT Rules Format and its rule and example content are published by the W3C under the W3C Software and Document Notice and License (permissive: copy, modify, and distribute with the notice and a statement of changes). Reuse the schema and adapt examples under that attribution. This alignment prose and the status-to-outcome mapping are repository-original content licensed under CC BY 4.0.

Source: W3C ACT Rules Format, <https://www.w3.org/TR/act-rules-format/>; ACT Rules Community, <https://act-rules.github.io/>.
