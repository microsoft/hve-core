---
id: "0002"
title: "Adopt Vally as the agent and skill behavior evaluation framework"
description: "Adopt Vally (@microsoft/vally-cli) with a Copilot-SDK executor and the evals/ tree as the standard way to evaluate the behavior of hve-core's authored AI customization artifacts, wired through repository validation scripts and supported by a vally-tests authoring skill."
author: "HVE Core Team"
ms.date: "2026-05-30"
ms.topic: "reference"
status: "accepted"
proposed_date: "2026-05-30"
accepted_date: "2026-05-30"
deciders:
  - "HVE Core Team"
consulted:
  - "HVE Core Maintainers"
  - "HVE Core Ambassadors"
  - "HVE Core Contributors"
informed:
  - "hve-core users"
  - "extension consumers"
effort: "L"
tags:
  - "evaluation"
  - "testing"
  - "ai-artifacts"
  - "ci"
  - "vally"
affected_components:
  - "evals/"
  - ".vally.yaml"
  - ".github/skills/hve-core/vally-tests/"
  - "package.json"
  - ".github/workflows/pr-validation.yml"
supersedes: null
superseded-by: null
related: []
asr_triggers:
  - kind: "maintainability"
    evidence: "evals/README.md describes the Vally evaluation architecture; the .github/skills/hve-core/vally-tests skill is the maintained authoring surface."
    note: "Establishes regression protection for non-code AI artifacts (agents, prompts, instructions, skills) that lack compile-time checks."
  - kind: "maintainability"
    evidence: ".vally.yaml maps checked-in Vally suites to categories for skill-quality, agent-behavior, and script-validation runs."
    note: "Evolvability surface: guards safe evolution of the customization layer. Captured under maintainability because the closed asr_triggers.kind enum does not admit a separate evolvability value."
  - kind: "compliance"
    evidence: "The .github/skills/hve-core/vally-tests refusal taxonomy enforces content-policy and Code of Conduct boundaries during test authoring."
    note: "Keeps test authoring out of adversarial territory with a closed refusal taxonomy."
success_criteria:
  - metric: "ai-artifact-regression-coverage"
    target: "checked-in evals/ suites lint successfully and can run through the repository Vally commands"
    measurement_window: "per-PR after adoption"
    source: "evals/README.md"
  - metric: "suite-routing-coverage"
    target: "the root Vally configuration routes each checked-in suite by category"
    measurement_window: "per validation run"
    source: ".vally.yaml"
  - metric: "validation-surface-integration"
    target: "repository validation keeps ADR, AI artifact, frontmatter, skill, and dependency checks in the PR gate"
    measurement_window: "every PR run"
    source: ".github/workflows/pr-validation.yml"
  - metric: "authoring-safety-enforcement"
    target: "the vally-tests skill refuses unsafe stimulus authoring before test cases are appended"
    measurement_window: "per authoring request"
    source: ".github/skills/hve-core/vally-tests/SKILL.md"
decisionMetadata:
  driverToTriggerMap:
    "Regression safety": "ASR-maintainability-eval-suite"
    "Baseline-equivalence guarantee": "ASR-maintainability-baseline-equivalence"
    "Authoring consistency": "ASR-maintainability-vally-tests-skill"
    "Tiered enforcement": "ASR-maintainability-tiered-gates"
    "Safety boundaries": "ASR-compliance-refusal-taxonomy"
---

## Context

The hve-core repository ships a large body of AI customization artifacts
(custom agents, prompts, instructions, and skills) that shape Copilot
behavior but carry no compile-time checks. These artifacts are markdown and
YAML, so the toolchain treats them as documents rather than programs: a typo,
a reordered instruction, or a reworded constraint changes runtime agent
behavior while every existing check stays green. Today the only safety net is
markdown and frontmatter linting plus human PR review, neither of which
exercises what an agent actually does when invoked. As the customization
surface grows, the blast radius of a silent behavioral regression grows with
it, and reviewer diligence does not scale to catch divergences across dozens
of interacting artifacts.

The project needed a repeatable way to evaluate the *behavior* of these
artifacts, surface customization drift as an explicit choice, and keep test
authoring inside safe content boundaries. This decision is retroactive: it
documents the Vally-based evaluation framework present in the repository. The
checked-in implementation includes the `evals/` tree with `skill-quality`,
`agent-behavior`, and `script-validation` suite specs, a root `.vally.yaml`
configuration, npm evaluation commands in `package.json`, a `vally-tests`
authoring skill at `.github/skills/hve-core/vally-tests/`, and PR validation
coverage through `.github/workflows/pr-validation.yml`. How should hve-core
standardize behavioral evaluation of its AI artifacts?

> Source: `evals/README.md`, Vally evaluation architecture.
> Source: `.vally.yaml`, suite routing configuration.

## Decision Drivers

* Regression safety
* Baseline-equivalence guarantee
* Authoring consistency
* Tiered enforcement
* Safety boundaries

Each driver maps to a concrete pressure the changeset has to relieve.
Regression safety is the primary one: authored artifacts need a behavioral net
that fails a PR when an edit changes how an agent or skill actually responds,
not merely when the markdown stops linting. Baseline-equivalence guarantee
demands proof that the customization layer still tracks the underlying Copilot
model, surfacing any divergence as an explicit, documented choice rather than
an accident. Authoring consistency requires that writing a new conformance
test follow one repeatable, grader-routed path instead of bespoke per-author
scaffolding. Tiered enforcement separates authoritative gates that must block
merge from advisory, non-deterministic checks that inform but do not fail the
build, so flaky LLM scoring never holds a PR hostage. Safety boundaries keep
generated test corpora inside content-policy and Code of Conduct limits, which
matters because the framework synthesizes adversarial-adjacent stimuli to probe
refusals. The matrix in the next section scores each option against these five
drivers.

## Considered Options

Three options were weighed against the five drivers. They are not equivalent
in kind: Option A is a purpose-built harness for evaluating authored
artifacts, Option B is a runtime behavioral framework aimed at a different
layer of the stack, and Option C is the pre-changeset baseline. The framing
below keeps that distinction explicit so the matrix that follows is read as a
fit-for-purpose comparison rather than a feature bake-off.

* Option A: Adopt Vally (`@microsoft/vally-cli`) with a Copilot-SDK executor and a multi-suite `evals/` tree.
* Option B: Adopt `vyta/beval` for runtime/agentic behavioral evaluation (complementary; integration in progress, not a replacement).
* Option C: No automated behavior evaluation (status quo): markdown/frontmatter linting plus human PR review only.

## Decision Outcome

The matrix scores each option against the five drivers. "Yes" means the option
satisfies the driver directly and as a first-class capability; "Partial" means
it addresses the driver only for a subset of cases or at a different layer; and
"No" means the driver is unmet. Only Option A scores "Yes" across the board for
the authored-artifact problem, which is the result the prose after the matrix
explains.

| Decision driver                | Option A (Vally) | Option B (beval)        | Option C (status quo) |
|--------------------------------|------------------|-------------------------|-----------------------|
| Regression safety              | Yes              | Partial (runtime layer) | No                    |
| Baseline-equivalence guarantee | Yes              | No                      | No                    |
| Authoring consistency          | Yes              | Partial                 | No                    |
| Tiered enforcement             | Yes              | Partial                 | No                    |
| Safety boundaries              | Yes              | Partial                 | No                    |

Chosen option: **"Option A: Adopt Vally (`@microsoft/vally-cli`) with a Copilot-SDK executor and a multi-suite `evals/` tree"**,
because it is the only option that satisfies all five decision drivers for the
authored-artifact evaluation problem. Its Copilot-SDK-native executor evaluates
hve-core agents, prompts, instructions, and skills as actually invoked, its
pairwise `vally compare` provides a first-class baseline-equivalence guarantee,
its tag-routed grader catalog matches the multi-suite design, and it is npm-
and GitHub-Actions-native so it fits existing PR CI and local `npm run`
workflows.

`vyta/beval` (Option B) is treated as complementary rather than rejected. It
targets a different layer (runtime, multi-turn agentic behavior with scored
multi-dimensional metrics and persona-driven conversation simulation over
ACP/A2A) and is being integrated through open pull requests. It does not
provide a pairwise baseline-equivalence comparison and therefore cannot replace
Vally for the customization-artifact regression and baseline-equivalence role.
The two frameworks are intended to coexist at different layers.

The status quo (Option C) was rejected because it leaves AI artifacts without
any regression safety net or baseline protection and makes authoring
consistency depend entirely on reviewer diligence.

### Consequences

Adopting Vally trades a heavier CI footprint and the inherent noise of
non-deterministic evaluation for a regression and baseline-equivalence net the
repository did not previously have. The good outcomes accrue to artifact
authors and reviewers; the bad outcomes land on CI maintenance and runtime
cost; the neutral items reflect deliberate scoping decisions (the beval
coexistence boundary and the data-driven `.vally.yaml` configuration) that are
neither wins nor regressions on their own.

* Good, because it gives non-code AI artifacts a behavioral regression net and a baseline-equivalence proof they previously lacked.
* Good, because the `vally-tests` skill makes conformance authoring repeatable and grader-routed instead of ad hoc.
* Good, because tiered enforcement separates authoritative blocking gates from advisory non-deterministic conformance checks.
* Good, because the framework reuses existing skill-validation and fuzz-harness conventions rather than inventing parallel ones.
* Bad, because it adds a new external dependency (`@microsoft/vally-cli`) plus a Copilot-SDK runtime to CI.
* Bad, because non-deterministic LLM evaluation introduces cost, latency, and flakiness that require multiple runs, tolerant graders, and generous timeouts.
* Bad, because it lands a large, multi-suite eval-infrastructure footprint that becomes ongoing maintenance surface.
* Neutral, because `vyta/beval` remains a complementary runtime/agentic evaluation layer under active integration; the two frameworks coexist at different layers.
* Neutral, because the executor and grader catalog are configured centrally in `.vally.yaml`, so suite behavior is data-driven rather than encoded per test.

### Confirmation

Compliance with this decision is confirmed by the evaluation framework itself
running under `autonomyTier: partial` Govern controls:

1. The checked-in `evals/` suites are documented in `evals/README.md` and routed through `.vally.yaml`.
2. The `package.json` evaluation commands provide local entry points for Vally linting and suite execution.
3. The `vally-tests` skill provides the repeatable authoring path whose outputs feed the suites above.
4. The PR validation workflow continues to gate the repository with ADR, AI artifact, frontmatter, skill, and dependency checks.

These checks map to the recorded success criteria: suite documentation and
configuration demonstrate regression coverage, the npm commands demonstrate a
repeatable execution surface, adoption of the skill path demonstrates authoring
consistency, and PR validation demonstrates that the evaluation framework stays
inside the repository's normal quality gate.

## Pros and Cons of the Options

### Option A: Adopt Vally with a Copilot-SDK executor

Vally is the only candidate built specifically to evaluate authored
customization artifacts as Copilot invokes them, and its pairwise comparison
mode is what makes baseline equivalence a measurable property rather than an
aspiration. Its costs are real but bounded, and they fall on CI rather than on
authors.

* Good, because the Copilot-SDK-native executor evaluates hve-core agents/prompts/instructions/skills as actually invoked.
* Good, because pairwise `vally compare` gives a first-class baseline-equivalence guarantee against the underlying model.
* Good, because tag-based suite routing and a grader catalog match the multi-suite `evals/` design.
* Good, because it is npm- and GitHub-Actions-native, fitting existing PR CI and local `npm run` workflows.
* Neutral, because the grader catalog and executor are configured in `.vally.yaml`, adding one central config surface to learn.
* Bad, because it introduces a new external dependency and a Copilot-SDK runtime in CI.
* Bad, because non-deterministic evals require multiple runs, tolerant graders, and generous timeouts.

### Option B: Adopt vyta/beval for runtime/agentic evaluation

beval is the stronger tool for the problem it targets, namely scoring how a
running agent behaves across a multi-turn conversation, but that is a different
problem from proving an edited instruction file still matches the baseline.
Its current alpha maturity and the absence of a pairwise comparison are why it
supplements rather than replaces Vally here.

> See [github.com/vyta/beval](https://github.com/vyta/beval): a language-agnostic framework for behavioral evaluation of AI agents and LLM systems with a Given/When/Then DSL, scored multi-dimensional metrics, layered graders, and conversation simulation over ACP/A2A.

* Good, because scored multi-dimensional metrics and conversation simulation capture multi-turn/agentic behavior that pass/fail conformance does not.
* Good, because ACP-stdio/A2A adapters evaluate running agents, including a `dt-coach` sample directly relevant to hve-core.
* Good, because it is a language-agnostic spec with cross-language conformance, MIT-licensed, and under active Microsoft development.
* Neutral, because it operates at a different layer than Vally and is intended to coexist with it.
* Bad, because it is experimental/alpha (git-subdirectory install only; APIs and schemas may change).
* Bad, because it has no pairwise baseline-equivalence equivalent to `vally compare`, so it cannot fill the customization-artifact regression role.
* Bad, because its integration is still in progress through open PRs and is not yet a standard PR CI gate.

### Option C: No automated behavior evaluation (status quo)

Keeping the status quo is the cheapest option on day one and the most
expensive over time. It carries no infrastructure cost and no flakiness, but it
leaves every behavioral regression to chance and to reviewer attention, which
is exactly the exposure this changeset exists to close.

* Good, because it adds zero new dependencies, infrastructure, or CI cost.
* Good, because there is no non-determinism or eval flakiness to manage.
* Bad, because AI artifacts can silently drift on edits with no regression safety net.
* Bad, because there is no evidence the customization layer preserves baseline model behavior.
* Bad, because authoring consistency depends entirely on reviewer diligence.

## Architecture

The framework is organized as four cooperating stages. Authoring artifacts (the
`vally-tests` skill and artifact-specific reference files) produce stimulus and
expectation files. Those files are gathered into the suite tree under `evals/`.
The root `.vally.yaml` configuration routes the checked-in suites by category,
while `package.json` exposes local evaluation commands. PR validation provides
the surrounding quality gate for ADR, AI artifact, frontmatter, skill, and
dependency checks. The diagram below traces that flow from authoring on the
left to validation on the right.

```mermaid
flowchart LR
    subgraph Authoring["Authoring"]
        skill[".github/skills/hve-core/vally-tests"]
        refs["skill references and assets"]
    end

    subgraph Config["Configuration"]
        vally[".vally.yaml"]
        package["package.json eval commands"]
    end

    subgraph Suites["evals/ suites"]
        skillQuality["skill-quality"]
        agentBehavior["agent-behavior"]
        scriptValidation["script-validation"]
    end

    subgraph Validation["Repository validation"]
        prval["pr-validation.yml"]
    end

    skill --> skillQuality
    refs --> agentBehavior
    refs --> scriptValidation
    vally --> skillQuality
    vally --> agentBehavior
    vally --> scriptValidation
    package --> skillQuality
    package --> agentBehavior
    package --> scriptValidation
    prval --> skill
```

## Risks and Mitigations

* Risk: a new external dependency (`@microsoft/vally-cli`) plus a Copilot-SDK runtime increases build complexity and supply-chain surface. Mitigation: pin the dependency and run it through the existing dependency-pinning checks.
* Risk: non-deterministic LLM evaluation produces cost, latency, and flaky results. Mitigation: configure multiple runs (`runs: 3+`), tolerant graders, and generous timeouts; avoid pinned models; route non-deterministic checks to the advisory tier.
* Risk: the eval-infrastructure footprint becomes ongoing maintenance surface. Mitigation: keep suite behavior data-driven through `.vally.yaml` and the grader catalog, and reuse existing skill-validation and fuzz-harness conventions instead of bespoke tooling.

## Rollback / Exit Strategy

If this decision is reversed, the rollback path is:

1. Remove the `evals/` suite tree and `.vally.yaml`.
2. Remove the `.github/skills/hve-core/vally-tests/` skill.
3. Remove the `eval:*` npm scripts and the Vally dependency from `package.json` and `package-lock.json`.
4. Revert any `evals/`-related changes in `.github/workflows/pr-validation.yml`.
5. Update any collection manifests that reference the removed skill and re-run `npm run plugin:generate`.
6. Document the reversal in a superseding ADR that links back to this one and sets `superseded-by` here.

No data migration is required: removing the framework leaves the underlying AI customization artifacts untouched.

## Affected Components

* evals/
* .vally.yaml
* .github/skills/hve-core/vally-tests/
* package.json
* .github/workflows/pr-validation.yml

## More Information

* Suite architecture: `evals/README.md` and the `evals/` suite tree
* Central config: `./.vally.yaml`
* Authoring skill: `.github/skills/hve-core/vally-tests/`
* Evaluation commands: `package.json`
* PR validation workflow: `.github/workflows/pr-validation.yml`
* Complementary runtime framework: [vyta/beval](https://github.com/vyta/beval) (language-agnostic agentic behavioral evaluation; integration in progress via open PRs)

This decision should be re-visited if `vyta/beval` integration matures enough to subsume the customization-artifact regression role, if Vally's Copilot-SDK executor or `vally compare` contract changes materially, or if the cost and flakiness of non-deterministic evaluation outweigh the regression-safety benefit.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
