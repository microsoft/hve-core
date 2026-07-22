---
title: Baseline Equivalence Suite
description: 'Pairs identical probes across baseline and customized environments to assert only documented divergences appear'
author: HVE Core Team
ms.date: 2026-07-22
---

## Purpose

This suite proves that the hve-core customization layer does not alter underlying GitHub Copilot
model behavior beyond documented divergences. The agent layer is the independent variable:
identical stimuli run twice against the same GHCP model, once against an empty baseline environment
and once against an environment that materializes a target agent (frontmatter, subagents, skills,
and `copilot-instructions.md`) into a fresh temp workdir. The `vally compare` comparison-mode
judge then asks whether the customized response differs from the baseline only in ways the
curated allow-list permits.

The suite answers a single question per stimulus: did customization change the model's answer, or did it change only the framing the customization explicitly requires?

## Layout

```text
evals/baseline-equivalence/
├── README.md           # this file
├── baseline/
│   └── eval.yaml       # executable spec for the empty baseline run (invariant graders + response-quality)
├── customized/
│   └── eval.yaml       # executable spec for the materialized agent run (adds customized_required / customized_disallow)
├── stimuli.yml         # 40 prompts across 8 subcategories at 5 per subcategory
└── compare.eval.yml    # A/B comparison spec judged by `vally compare`
```

The baseline and customized specs are self-contained vally `eval` documents. The PowerShell driver invokes each spec in turn with `vally eval --eval-spec` and then joins the two run directories with `vally compare --eval-spec compare.eval.yml --baseline <baseline-run-dir> --treatment <customized-run-dir> --output <path>.jsonl`.

Comparison stimuli with no explicit rubric override use Vally's embedded default comparison rubric. Add an override in [compare.eval.yml](compare.eval.yml) only when the stimulus needs narrower evaluation criteria.

## How to Run

The PowerShell driver at [scripts/evals/Invoke-BaselineEquivalence.ps1](../../scripts/evals/Invoke-BaselineEquivalence.ps1) is the single entry point. Invoke it through the npm wrapper:

```bash
# PR tier (default): single primary model, advisory verdict, always exits 0
npm run eval:equivalence -- -Agent task-researcher -Tier pr

# Nightly tier: three-model sweep, authoritative verdict, exits non-zero on fail
npm run eval:equivalence -- -Agent task-researcher -Tier nightly

# Narrow the stimulus set during smoke testing
npm run eval:equivalence -- -Agent task-researcher -Tier pr -StimulusFilter '^factual-'

# Dry run: print planned vally commands and emit a placeholder summary without SDK calls
npm run eval:equivalence -- -Agent task-researcher -WhatIf
```

The driver writes a machine-readable summary to `logs/baseline-equivalence-summary.json` and per-environment trajectories under `evals/results/`. The trajectory directories are gitignored.

### Driver output contract

Each `vally compare --eval-spec compare.eval.yml --baseline <baseline-run-dir> --treatment <customized-run-dir> --output <path>.jsonl` invocation writes one or more typed `type: "comparison"` records to `logs/vally-compare-<model>-<runId>.jsonl` (a console `.log` capture of the same invocation is kept alongside for troubleshooting, at the paths listed in `compareLogs`).
`Measure-CompareTrials` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1) reads that JSONL, tallies each non-errored trial's `winner` (`baseline` / `treatment` / `tie`), and carries forward the record's `summary` statistics (signed mean score, 95% confidence interval, win rate).
The driver aggregates one JSONL per model into a single JSON summary; the summary is the contract every downstream consumer (PR bot, nightly dashboard, future change-detection workflow) reads.
The compare invocation deliberately omits `--fail-on-regression` so `Get-VerdictFromAggregate` remains the single equivalence authority instead of double-counting the same regression signal.

| Field                | Type   | Meaning                                                                                                                                                                      |
|----------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `agent`              | string | Agent slug under test (matches `-Agent`)                                                                                                                                     |
| `tier`               | string | `pr` (advisory, exit 0) or `nightly` (authoritative, exit 1 on fail)                                                                                                         |
| `model`              | string | Primary model for the run: PR tier resolves `-Model` override, then frontmatter `model:` hint, then the cheap default (`gpt-5.6-luna`); nightly runs its fixed model array   |
| `stimulusFilter`     | string | Regex applied to stimulus names; empty when the full corpus ran                                                                                                              |
| `runs`               | int    | Total non-errored comparison trials parsed across all `--output` JSONL files                                                                                                 |
| `ties`               | int    | Trials with `winner: "tie"`; neither environment showed a clear preference                                                                                                   |
| `aWins`              | int    | Trials with `winner: "baseline"`; the customization underperformed                                                                                                           |
| `bWins`              | int    | Trials with `winner: "treatment"`; the customization outperformed                                                                                                            |
| `meanScore`          | number | Unweighted average, across records and models, of signed treatment-relative `summary.meanScore` values (positive favors the customization); reporting only                   |
| `ciLow`              | number | Conservative maximum lower bound of `summary.ciLow` across records and models                                                                                                |
| `ciHigh`             | number | Conservative minimum upper bound of `summary.ciHigh` across records and models                                                                                               |
| `winRate`            | number | Unweighted average, across records and models, of `summary.winRate` values; reporting only                                                                                   |
| `invariantFailures`  | int    | Spec-level invariant violations plus a baseline `vally eval` nonzero-exit fallback when no invariant count can be read                                                       |
| `divergenceFailures` | int    | Customized `vally eval` nonzero exits and one signal per compare run that exits nonzero, emits no parseable comparison records, or carries trials without summary statistics |
| `verdict`            | string | Aggregated verdict; see [Pass and Fail Interpretation](#pass-and-fail-interpretation)                                                                                        |
| `variants`           | list   | Per-model variant metadata (model id, baseline run directory, customized run directory)                                                                                      |
| `compareLogs`        | list   | Absolute paths to every captured `vally compare` console log; the sibling `--output` JSONL lives at `logs/vally-compare-<model>-<runId>.jsonl`                               |

The verdict field is derived from `ciLow`/`ciHigh` and the failure counts by `Get-VerdictFromAggregate` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1); the exact rule is documented below.

`meanScore` and `winRate` are unweighted diagnostics, not pooled estimates.

### Lint commands

The baseline-equivalence specs live in two subdirectories (`baseline/eval.yaml` and `customized/eval.yaml`) so the driver can invoke them as a paired set. The repository-wide `npm run eval:lint:vally` task runs `vally lint --eval-spec evals/` and discovers both nested specs. Use the explicit commands below for targeted validation:

| Command                                                                  | Purpose                                                                            |
|--------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `vally lint --eval-spec evals/baseline-equivalence/baseline/eval.yaml`   | Schema-validate the empty baseline spec                                            |
| `vally lint --eval-spec evals/baseline-equivalence/customized/eval.yaml` | Schema-validate the materialized customized spec (includes the divergence graders) |
| `vally lint --eval-spec evals/baseline-equivalence/compare.eval.yml`     | Validate the A/B compare spec consumed by `vally compare`                          |
| `npm run eval:run:equivalence`                                           | Run both specs end to end via `vally eval --eval-spec ...` (no driver, no compare) |

Run the three `vally lint` commands before pushing a change to this suite. The presence linter ([scripts/evals/Test-StimulusPresence.ps1](../../scripts/evals/Test-StimulusPresence.ps1)) is wired into the changed-artifact lane and is documented in [docs/contributing/evals-ci.md](../../docs/contributing/evals-ci.md).

## How to Extend Per-Agent

Onboarding a new agent (for example `task-planner`) does not require harness code changes. Drop a sibling configuration block in three places:

1. Teach the driver how to materialize the target agent's surface (frontmatter, subagents, skills, `copilot-instructions.md`) into the customized workspace. The current driver runs both specs against the repo cwd; materialization is the open follow-up to make the baseline run truly empty.
2. Add the agent's curated surface signatures to `surface_signatures.<agent>` in [compare.eval.yml](compare.eval.yml). Required signatures express divergences the customization mandates; disallowed signatures express patterns the customization must not produce.
3. Add per-agent divergence graders inline in [customized/eval.yaml](customized/eval.yaml) (`customized_required` / `customized_disallow` graders attached to the relevant stimuli) for any behaviors the surface-signature regex alone cannot capture.

The driver resolves the agent's frontmatter `model:` hint automatically. No new PowerShell, no new stimulus library, and no new judge prompt are required unless the agent's domain materially differs from the existing corpus.

## Onboarded Agents

The baseline-equivalence harness currently ships surface signatures (authoritative by default; experimental-collection rows are advisory and non-blocking until graduated)
for the agents listed below. Stimulus coverage counts the entries in [stimuli.yml](stimuli.yml) whose `tags.agent` includes the agent slug; an empty count means the agent
relies on shared corpus coverage rather than per-agent backlinks. New agents land here after their signature file is reviewed and at least three natural-fit stimulus backlinks are added (when applicable).

| Agent                        | Collection       | Signature File                                                                                             | Stimulus Coverage | Status        |
|------------------------------|------------------|------------------------------------------------------------------------------------------------------------|-------------------|---------------|
| ado-backlog-manager          | ado              | [surface-signatures/ado-backlog-manager.yml](surface-signatures/ado-backlog-manager.yml)                   | 0                 | authoritative |
| ado-prd-to-wit               | ado              | [surface-signatures/ado-prd-to-wit.yml](surface-signatures/ado-prd-to-wit.yml)                             | 0                 | authoritative |
| adr-creation                 | project-planning | [surface-signatures/adr-creation.yml](surface-signatures/adr-creation.yml)                                 | 0                 | authoritative |
| agentic-workflows            | root             | [surface-signatures/agentic-workflows.yml](surface-signatures/agentic-workflows.yml)                       | 0                 | authoritative |
| agile-coach                  | project-planning | [surface-signatures/agile-coach.yml](surface-signatures/agile-coach.yml)                                   | 0                 | authoritative |
| arch-diagram-builder         | project-planning | [surface-signatures/arch-diagram-builder.yml](surface-signatures/arch-diagram-builder.yml)                 | 0                 | authoritative |
| brd-builder                  | project-planning | [surface-signatures/brd-builder.yml](surface-signatures/brd-builder.yml)                                   | 2                 | authoritative |
| code-review                  | coding-standards | [surface-signatures/code-review.yml](surface-signatures/code-review.yml)                                   | 3                 | authoritative |
| dependency-reviewer          | root             | [surface-signatures/dependency-reviewer.yml](surface-signatures/dependency-reviewer.yml)                   | 1                 | authoritative |
| documentation                | hve-core         | [surface-signatures/documentation.yml](surface-signatures/documentation.yml)                               | 4                 | authoritative |
| dt-coach                     | design-thinking  | [surface-signatures/dt-coach.yml](surface-signatures/dt-coach.yml)                                         | 0                 | authoritative |
| dt-learning-tutor            | design-thinking  | [surface-signatures/dt-learning-tutor.yml](surface-signatures/dt-learning-tutor.yml)                       | 0                 | authoritative |
| eval-dataset-creator         | data-science     | [surface-signatures/eval-dataset-creator.yml](surface-signatures/eval-dataset-creator.yml)                 | 0                 | authoritative |
| experiment-designer          | experimental     | [surface-signatures/experiment-designer.yml](surface-signatures/experiment-designer.yml)                   | 0                 | advisory      |
| gen-data-spec                | data-science     | [surface-signatures/gen-data-spec.yml](surface-signatures/gen-data-spec.yml)                               | 0                 | authoritative |
| gen-jupyter-notebook         | data-science     | [surface-signatures/gen-jupyter-notebook.yml](surface-signatures/gen-jupyter-notebook.yml)                 | 0                 | authoritative |
| gen-streamlit-dashboard      | data-science     | [surface-signatures/gen-streamlit-dashboard.yml](surface-signatures/gen-streamlit-dashboard.yml)           | 0                 | authoritative |
| github-backlog-manager       | github           | [surface-signatures/github-backlog-manager.yml](surface-signatures/github-backlog-manager.yml)             | 2                 | authoritative |
| issue-triage                 | root             | [surface-signatures/issue-triage.yml](surface-signatures/issue-triage.yml)                                 | 3                 | authoritative |
| jira-backlog-manager         | jira             | [surface-signatures/jira-backlog-manager.yml](surface-signatures/jira-backlog-manager.yml)                 | 0                 | authoritative |
| jira-prd-to-wit              | jira             | [surface-signatures/jira-prd-to-wit.yml](surface-signatures/jira-prd-to-wit.yml)                           | 0                 | authoritative |
| meeting-analyst              | project-planning | [surface-signatures/meeting-analyst.yml](surface-signatures/meeting-analyst.yml)                           | 0                 | authoritative |
| memory                       | hve-core         | [surface-signatures/memory.yml](surface-signatures/memory.yml)                                             | 6                 | authoritative |
| network-isa95-planner        | project-planning | [surface-signatures/network-isa95-planner.yml](surface-signatures/network-isa95-planner.yml)               | 0                 | authoritative |
| pptx                         | experimental     | [surface-signatures/pptx.yml](surface-signatures/pptx.yml)                                                 | 0                 | advisory      |
| prd-builder                  | project-planning | [surface-signatures/prd-builder.yml](surface-signatures/prd-builder.yml)                                   | 2                 | authoritative |
| product-manager-advisor      | project-planning | [surface-signatures/product-manager-advisor.yml](surface-signatures/product-manager-advisor.yml)           | 2                 | authoritative |
| prompt-builder               | hve-core         | [surface-signatures/prompt-builder.yml](surface-signatures/prompt-builder.yml)                             | 0                 | authoritative |
| rai-planner                  | rai-planning     | [surface-signatures/rai-planner.yml](surface-signatures/rai-planner.yml)                                   | 0                 | authoritative |
| rpi-agent                    | hve-core         | [surface-signatures/rpi-agent.yml](surface-signatures/rpi-agent.yml)                                       | 6                 | authoritative |
| security-planner             | security         | [surface-signatures/security-planner.yml](surface-signatures/security-planner.yml)                         | 0                 | authoritative |
| security-reviewer            | security         | [surface-signatures/security-reviewer.yml](surface-signatures/security-reviewer.yml)                       | 0                 | authoritative |
| sssc-planner                 | security         | [surface-signatures/sssc-planner.yml](surface-signatures/sssc-planner.yml)                                 | 0                 | authoritative |
| system-architecture-reviewer | project-planning | [surface-signatures/system-architecture-reviewer.yml](surface-signatures/system-architecture-reviewer.yml) | 0                 | authoritative |
| task-challenger              | hve-core         | [surface-signatures/task-challenger.yml](surface-signatures/task-challenger.yml)                           | 7                 | authoritative |
| task-implementor             | hve-core         | [surface-signatures/task-implementor.yml](surface-signatures/task-implementor.yml)                         | 9                 | authoritative |
| task-planner                 | hve-core         | [surface-signatures/task-planner.yml](surface-signatures/task-planner.yml)                                 | 6                 | authoritative |
| task-researcher              | hve-core         | [surface-signatures/task-researcher.yml](surface-signatures/task-researcher.yml)                           | 0                 | authoritative |
| task-reviewer                | hve-core         | [surface-signatures/task-reviewer.yml](surface-signatures/task-reviewer.yml)                               | 4                 | authoritative |
| test-streamlit-dashboard     | data-science     | [surface-signatures/test-streamlit-dashboard.yml](surface-signatures/test-streamlit-dashboard.yml)         | 0                 | authoritative |
| ux-ui-designer               | project-planning | [surface-signatures/ux-ui-designer.yml](surface-signatures/ux-ui-designer.yml)                             | 0                 | authoritative |

The `prompt-builder` and `task-researcher` rows show stimulus coverage `0` because their domains (prompt authoring and ad-hoc research) do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke them as subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `security-planner`, `security-reviewer`, and `sssc-planner` rows show stimulus coverage `0` for the same reason: their domains (threat modeling and RAI impact, security review and vulnerability assessment, and supply-chain hardening) do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke their subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `adr-creation`, `agile-coach`, `arch-diagram-builder`, `meeting-analyst`, `network-isa95-planner`, `system-architecture-reviewer`, and `ux-ui-designer` rows show stimulus coverage `0`
because their project-planning domains do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke them as subagents
or via their declared instruction and skill chains, and through their own surface-signature regex on every baseline-equivalence run.

The `ado-backlog-manager`, `ado-prd-to-wit`, `jira-backlog-manager`, and `jira-prd-to-wit` rows show stimulus coverage `0` because their domains (Azure DevOps and Jira work-item lifecycle, PRD-to-work-item planning) do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke them as subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `dt-coach` and `dt-learning-tutor` rows show stimulus coverage `0` because their Design Thinking coaching and curriculum domains do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke them as subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `eval-dataset-creator`, `gen-data-spec`, `gen-jupyter-notebook`, `gen-streamlit-dashboard`, and `test-streamlit-dashboard` rows show stimulus coverage `0` because their data-science and dashboard-generation domains do not map to any of the v1 stimulus categories. They are covered indirectly through dependency-map dispatch when other agents invoke them as subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `code-review` agent is backlinked onto the two existing `code-qa` walkthrough prompts (`code-walkthrough-fizzbuzz` and `code-error-explain-indexerror`) because step-by-step code explanation is a natural fit for a review-focused agent, and onto `multi-turn-correct-misunderstanding` because standards-driven correction of a prior mistake is a natural fit for that agent's domain.

The `brd-builder`, `prd-builder`, and `product-manager-advisor` agents are backlinked onto the two most generic `ambiguous-spec` prompts (`vague-feature` and `update-thing`) because requirements elicitation is a natural response to under-specified asks.

The `experiment-designer` and `pptx` rows show stimulus coverage `0` because their experimental domains (MVE / hypothesis design and slide-deck generation) do not map to any of the v1 stimulus categories. They land with `advisory` status per collection tier convention and are covered indirectly through dependency-map dispatch when other agents invoke them as subagents, and through their own surface-signature regex on every baseline-equivalence run.

The `rai-planner` row shows stimulus coverage `0` because its responsible-AI risk-assessment domain (NIST AI RMF, AI STRIDE, impact assessment) does not map to any of the v1 stimulus categories. It is covered indirectly through dependency-map dispatch and through its own surface-signature regex on every baseline-equivalence run.

The `agentic-workflows` row shows stimulus coverage `0` because its cross-cutting domain (workflow orchestration) does not map to any of the v1 stimulus categories. It is covered indirectly through dependency-map dispatch and through its own surface-signature regex on every baseline-equivalence run.

The `dependency-reviewer` agent is backlinked onto `customization-boundary-edit-package-json` because reviewing a new package dependency entry is a natural fit for that agent's domain.
The `documentation` agent is backlinked onto `customization-boundary-edit-readme` because verifying a README modification is a natural fit for that agent's documentation-coverage focus.
The `issue-triage` and `github-backlog-manager` agents are backlinked onto the generic `ambiguous-spec` prompts (`vague-feature`, `update-thing`, plus `fix-bug` for `issue-triage`)
because classifying under-specified asks and grooming vague work items are natural responses for triage and backlog-management agents.

## Pass and Fail Interpretation

The driver aggregates the `vally compare` comparison-record statistics and trajectory invariants into a single verdict via `Get-VerdictFromAggregate` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1).
Equivalence holds when the conservative cross-model bounds (`ciLow`/`ciHigh`) straddle zero, meaning every contributing model's 95% confidence interval includes zero. These bounds are not a pooled confidence interval. Opposing significant model results can produce `ciLow > ciHigh`; that intentionally fails the straddle test and triggers review. The rules use the JSON fields documented in [Driver output contract](#driver-output-contract):

* `runs <= 0`: the driver returns `fail` unconditionally, leaving the summary on disk so the cause (typically zero parseable `type: "comparison"` records) can be diagnosed from `compareLogs` and the sibling `--output` JSONL.
* `invariantFailures > 0` or `divergenceFailures > 0`: `warn` on `pr` tier, `fail` on `nightly` tier.
* Otherwise, `pass` when the confidence interval straddles zero (`ciLow <= 0 <= ciHigh`); `warn` on `pr` tier or `fail` on `nightly` tier when the interval excludes zero on either side.

There is no `inconclusive` bucket and no fixed tie-ratio or symmetry threshold; the 0.80 tie-ratio and
`|aWins - bWins|` symmetry heuristic from the Vally 0.6-era driver no longer applies. PR-tier verdicts surface as warnings on the PR; nightly-tier verdicts gate the nightly workflow. This split keeps the per-PR signal low-friction while preserving a hard regression gate on the main branch.

A confidence interval excluding zero on the negative side (`ciHigh < 0`) signals a statistically significant regression: the baseline outperformed the customization.
This is the same condition `vally compare --fail-on-regression` would flag, which this driver deliberately does not pass on the compare invocation so `Get-VerdictFromAggregate` remains the single equivalence authority (see [Driver output contract](#driver-output-contract)).
A confidence interval excluding zero on the positive side (`ciLow > 0`) signals the opposite: an unexpected, statistically significant improvement. Both directions are documented-divergence review triggers for an equivalence suite, since its purpose is proving no undocumented behavior change occurred rather than proving the customization is better.

## Stimulus Shape

Each entry in [stimuli.yml](stimuli.yml) uses these keys:

| Key                   | Applies To      | Meaning                                                                                                                                           |
|-----------------------|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `name`                | both            | Stimulus identifier; mirrors the key used in [compare.eval.yml](compare.eval.yml) so `vally compare` pairs trajectories by name                   |
| `prompt`              | both            | The verbatim user-facing prompt sent to both environments                                                                                         |
| `invariants`          | both            | Named graders from `grader_registry.invariants` that must pass on both the baseline and customized trajectories                                   |
| `customized_required` | customized only | Named graders from `grader_registry.customized_required` that must match the customized trajectory; documents an expected divergence              |
| `customized_disallow` | customized only | Named graders from `grader_registry.customized_disallow` that must NOT match the customized trajectory; catches unintended persona or scope bleed |
| `tags`                | filter          | `category` and `subcategory` for stimulus selection and reporting                                                                                 |

Trajectory invariants live at the spec level (not per stimulus) and apply across the baseline-customized pair: model equality (`metadata.model` matches across A and B), baseline-no-customized-skills (the baseline trajectory invokes no skills the customization layer expects), and response length parity within plus or minus 25 percent.

## Surface-Signature Allow-List

The customization layer is allowed to differ from the baseline only in ways the curated `surface_signatures` block in [compare.eval.yml](compare.eval.yml) declares. For `task-researcher`, the allow-list permits a leading `## 🔬 Task Researcher:` header and language scoping file writes to `.copilot-tracking/research/`. Anything outside the allow-list that diverges from baseline is treated as a regression, not a feature.

This framing is intentional. The suite is not a free-form quality grader; it asks the narrow question "does customization change anything beyond what we said it would?" Curated allowances keep the question crisp.

## Non-Goals

The suite does NOT assert:

* Latency or wall-clock time. Both environments share the same model; throughput differences are not the customization layer's responsibility.
* Streaming behavior. `vally compare` grading runs on completed responses.
* Multi-turn conversation dynamics. v1 stimuli are single-turn.
* MCP server behavior. Both environments configure `mcpServers: {}` to isolate the agent layer from external tool variability.
* Absolute billing cost. Length parity within plus or minus 25 percent bounds the proxy for cost; dollar amounts are out of scope.
* Cross-model behavioral equivalence. Each run compares baseline to customized against the SAME model; differences between models (for example `claude-opus-4.7` vs `gpt-5.5`) are the model vendor's domain.

## References

* [evals/README.md](../README.md) for the suite catalog and shared anti-patterns.
* [baseline/eval.yaml](baseline/eval.yaml) and [customized/eval.yaml](customized/eval.yaml) for the executable specs invoked by the driver.
* [scripts/evals/Invoke-BaselineEquivalence.ps1](../../scripts/evals/Invoke-BaselineEquivalence.ps1) for driver parameters and exit codes.
* [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1) for the parser and verdict aggregator that produce `logs/baseline-equivalence-summary.json`.
* [docs/contributing/evals-ci.md](../../docs/contributing/evals-ci.md) for the stimulus presence linter, the spec-text linter, moderation lanes, and CI auth contract.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
