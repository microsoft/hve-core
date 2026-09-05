---
title: Baseline Equivalence Suite
description: 'Pairs identical probes across baseline and customized environments to measure nominal behavior preservation'
author: HVE Core Team
ms.date: 2026-08-21
---

## Purpose

This suite measures whether invoking an hve-core agent changes nominal GitHub Copilot model
behavior. The agent layer is the independent variable: identical
questions run against the same model, once as a plain baseline prompt and once after a turn-0
`Launch .github/agents/hve-core/rpi-agent.agent.md` directive. This is the established invocation
pattern used by the repository's agent-conformance suites. The agent file remains staged in the
trial workspace so the launch turn can read it.

The suite answers a single question per stimulus: did customization change the model's answer under an ordinary prompt?

## Layout

```text
evals/baseline-equivalence/
├── README.md           # this file
├── baseline/
│   ├── eval.yaml       # executable spec for the empty baseline run (invariant graders + response-quality)
│   └── variant.yaml    # baseline variant metadata
├── customized/
│   ├── eval.yaml       # executable spec for the materialized agent run (adds customized_disallow guards)
│   └── variant.yaml    # RPI Agent variant metadata
├── compare.eval.yml    # comparison-judging contract: one rubric per canonical stimulus
├── stimuli.yml         # 35 equivalent-policy prompts across 7 subcategories
```

The baseline and customized specs are self-contained vally `eval` documents. The PowerShell driver invokes each spec in turn with `vally eval --eval-spec` and then joins the two run directories with `vally compare --eval-spec evals/baseline-equivalence/compare.eval.yml --judge-model <model> --baseline <baseline-run-dir> --treatment <customized-run-dir> --output <path>.jsonl`.

Comparison judging reads `compare.eval.yml`, supplied explicitly through `--eval-spec`. Without it, `vally compare` falls back to the rubric
embedded in the baseline trajectory and then to a general-purpose preference rubric that asks which response is better. Preference judging cannot
measure equivalence: two runs of one configuration still differ in wording, so the judge keeps picking winners and the tie ratio reports judge
tie-breaking rather than behavioral sameness. Each entry in the contract states the behavioral contract and instructs a tie
when both variants satisfy it. The judge model is
pinned separately through the driver's `-ComparisonJudgeModel` parameter, so both the rubric and the judge are visible in the command.

The contract is validated deterministically before any model-backed run. A missing, duplicated, unknown, or policy-mismatched entry fails `npm run ci:eval:lint:schema` and the Pester sync suite rather than silently changing what the tie ratio measures.

## How to Run

The PowerShell driver at [scripts/evals/Invoke-BaselineEquivalence.ps1](../../scripts/evals/Invoke-BaselineEquivalence.ps1) is the single entry point. Invoke it through the npm wrapper:

```bash
# devloop (default): single primary model, advisory verdict, always exits 0
npm run ci:eval:equivalence -- -Agent rpi-agent -Tier devloop

# calibration: two-model sweep, report-only comparison, authoritative deterministic and structural evidence
npm run ci:eval:equivalence -- -Agent rpi-agent -Tier calibration

# ci: two-model sweep with the same current evidence posture; reserved for a later calibrated policy
npm run ci:eval:equivalence -- -Agent rpi-agent -Tier ci

# Dry run: print planned vally commands and emit a placeholder summary without SDK calls
npm run ci:eval:equivalence -- -Agent rpi-agent -WhatIf
```

The former `pr` and `nightly` tier names are rejected with a migration message rather than aliased, because they carried different exit policies and a silent alias would let a stale caller select the wrong one.

`rpi-agent` is the only equivalence subject currently selected, because the customized launch target is fixed to that agent and the corpus guards encode that agent's contract. Other agents can be materialized by the driver, but they are not selected and are not meaningfully evaluated: scoring one against this corpus would fail for reasons unrelated to equivalence. Treat the shared-stimulus and scope-guard claims in this document as applying to `rpi-agent` only.

Corpus backlinks identify related artifacts for indexing; they do not select subjects. The corpus is excluded from generic tag-filtered dispatch, which previously produced partial and zero-stimulus
runs that reported success without measuring anything. Extending coverage to the remaining agents requires per-subject conditional guards and is
deferred until one clean run under the restored comparison contract exists.

The driver writes a machine-readable summary to `logs/baseline-equivalence-summary.json` and per-environment trajectories under `evals/results/`. The trajectory directories are gitignored. Both executable specs run three trials per stimulus. Three is a provisional inner-loop budget, not a calibrated power claim; the first valid post-launch run records dispersion and interval width before any future authoritative comparative policy is considered.

Every stimulus also declares `constraints.max_agent_duration: 285s` beneath the 300-second hard timeout. Vally stops and aborts the active Copilot SDK request when that working-duration limit expires, while the outer CI shard stops after 240 minutes if process-level cleanup fails. A bounded trial may therefore report `agent_timeout`, but one unresolved request cannot hold the evaluation shard indefinitely.

### Driver output contract

Each `vally compare --eval-spec evals/baseline-equivalence/compare.eval.yml --judge-model <model> --baseline <baseline-run-dir> --treatment <customized-run-dir> --output <path>.jsonl` invocation writes one or more typed `type: "comparison"` records to `logs/vally-compare-<model>-<runId>.jsonl` (a console `.log` capture of the same invocation is kept alongside for troubleshooting, at the paths listed in `compareLogs`).
`Measure-CompareTrials` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1) reads that JSONL, tallies each non-errored trial's `winner` (`baseline` / `treatment` / `tie`), and carries forward the record's `summary` statistics (signed mean score, 95% confidence interval, win rate).
The driver aggregates one JSONL per model into a single JSON summary; the summary is the contract every downstream consumer reads. It carries `schemaVersion: "2.1.0"`, and consumers reject an unsupported major version rather than reading absent fields as zeros.
The compare invocation deliberately omits `--fail-on-regression`. Comparison is report-only calibration evidence until a later decision defines a degradation margin, confidence level, inequality, and missing-bound behavior from valid post-launch data.

| Field                                                                | Type         | Meaning                                                                                                                                                                                         |
|----------------------------------------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `schemaVersion`                                                      | string       | Reporting contract version. `2.1.0` is the current contract; consumers fail loudly on an unsupported major                                                                                      |
| `agent`                                                              | string       | Agent slug under test (matches `-Agent`)                                                                                                                                                        |
| `tier`                                                               | string       | `devloop` (one-model advisory), `calibration` (two-model report-only comparison), or `ci`; deterministic and structural evidence remains authoritative outside devloop                          |
| `model`                                                              | string       | Primary model for the run: `devloop` resolves one model; `calibration` and `ci` run the fixed `gpt-5.6-luna` and `claude-sonnet-4.6` pair                                                       |
| `runs`                                                               | int          | Total non-errored comparison trials parsed across all `--output` JSONL files                                                                                                                    |
| `ties`                                                               | int          | Trials with `winner: "tie"`; neither environment showed a clear preference                                                                                                                      |
| `baselineWins`                                                       | int          | Trials with `winner: "baseline"`; the customization underperformed                                                                                                                              |
| `treatmentWins`                                                      | int          | Trials with `winner: "treatment"`; the customization outperformed                                                                                                                               |
| `meanScore`                                                          | number       | Unweighted average, across records and models, of signed treatment-relative `summary.meanScore` values (positive favors the customization); reporting only                                      |
| `ciLow`                                                              | number       | Conservative maximum lower bound of `summary.ciLow` across records and models; reporting only, not a gate input                                                                                 |
| `ciHigh`                                                             | number       | Conservative minimum upper bound of `summary.ciHigh` across records and models; reporting only, not a gate input                                                                                |
| `winRate`                                                            | number       | Unweighted average, across records and models, of `summary.winRate` values; reporting only                                                                                                      |
| `invariantFailures`                                                  | int          | Declared-invariant violations read from the baseline run's structured results                                                                                                                   |
| `runHealthFailures`                                                  | int          | Run-integrity signals: missing run directories, unparseable compare output, a nonzero `vally compare` exit, and a nonzero `vally eval` exit only when that run produced no usable grader signal |
| `invocationEvidence`, `invocationFailures`                           | list, int    | Per-model expected and observed successful agent-file reads plus failed, missing, duplicate, wrong-path, and malformed evidence; any failure is structural                                      |
| `divergenceGuardFailures`                                            | int          | Declared `customized_disallow` guards that failed in the customized run                                                                                                                         |
| `divergenceGuardsEvaluated`                                          | int          | Declared guards actually evaluated; current guards detect persona bleed on equivalent-policy stimuli                                                                                            |
| `failedDivergenceGuards`                                             | list         | Up to 50 `stimulus/guard` identifiers for the failing guards                                                                                                                                    |
| `dataQualityViolations`                                              | int          | Malformed, unmatched, duplicate, missing, or unexpected records across comparison and declared-population reconciliation; any nonzero value fails closed at every tier                          |
| `dataQualityDiagnostics`                                             | list         | Up to 50 human-readable diagnostic strings explaining the counted data-quality violations; diagnostic aid, not a contractual enumeration                                                        |
| `judgeErrors`, `judgeErrorRate`                                      | int, number  | Errored comparison trials and their share of attempted trials; counted and reported, not yet enforced                                                                                           |
| `equivalentTrials`, `equivalentTies`, `divergenceTrials`, `tieRatio` | int, number  | Population split by comparison policy; tie ratio is retained only as a diagnostic                                                                                                               |
| `comparisonCalibration`, `comparisonStatus`                          | list, string | Equivalent-policy signed-score count, mean, standard deviation, 95% bounds, and per-stimulus dispersion for each model; status is `report-only`                                                 |
| `equivalenceGate`                                                    | string       | Authoritative deterministic and structural evidence status                                                                                                                                      |
| `documentedDivergenceGate`                                           | string       | `report-only`; retained in the 2.x summary contract after boundary-corpus removal                                                                                                               |
| `verdict`                                                            | string       | Authoritative deterministic and structural outcome; comparison cannot change it                                                                                                                 |
| `variants`                                                           | list         | Per-model variant metadata (model id, baseline run directory, customized run directory)                                                                                                         |
| `compareLogs`                                                        | list         | Absolute paths to every captured `vally compare` console log; the sibling `--output` JSONL lives at `logs/vally-compare-<model>-<runId>.jsonl`                                                  |

Authoritative evidence is derived by `Get-EquivalenceGateResults` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1); the exact rule is documented below.

`meanScore` and `winRate` are unweighted diagnostics, not pooled estimates.

### Lint commands

The baseline-equivalence specs live in two subdirectories (`baseline/eval.yaml` and `customized/eval.yaml`) so the driver can invoke them as a paired set. The repository-wide `npm run ci:eval:lint:vally` task runs `vally lint --eval-spec evals/` and discovers both nested specs. Use the explicit commands below for targeted validation:

| Command                                                                  | Purpose                                                                   |
|--------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `vally lint --eval-spec evals/baseline-equivalence/baseline/eval.yaml`   | Schema-validate the empty baseline spec                                   |
| `vally lint --eval-spec evals/baseline-equivalence/customized/eval.yaml` | Schema-validate the materialized customized spec and persona-bleed guards |

The customized spec cannot be run directly: only the driver materializes the customization surface, so a direct `vally eval` invocation would score an empty surface. Use `npm run ci:eval:equivalence -- -Agent <slug> -Tier devloop` to run the suite end to end.

Run both `vally lint` commands before pushing a change to this suite. The presence linter ([scripts/evals/Test-StimulusPresence.ps1](../../scripts/evals/Test-StimulusPresence.ps1)) is wired into the changed-artifact lane and is documented in [docs/contributing/evals-ci.md](../../docs/contributing/evals-ci.md).

## How to Extend Per-Agent

Onboarding a new agent (for example `security-planner`) requires a subject-aware launch target and policy selection:

1. The driver materializes the target agent's surface into an isolated workspace automatically, and the customized spec launches the subject before sending the user question.
   [scripts/evals/lib/EquivalenceEnvironment.psm1](../../scripts/evals/lib/EquivalenceEnvironment.psm1) copies the agent file, its declared
   instructions, its subagents, `copilot-instructions.md`, and only the skills that agent actually references. Two different agents therefore
   produce different customized environments. Materialization alone is not invocation: the launch turn is the evidence-bearing treatment. The baseline runs against the same shared seed project but no agent and is cached and reused across agents, keyed on model, Vally version, and a content hash covering the baseline spec plus the seed.
2. Persona-bleed guards are declared inline on equivalent-policy stimuli. `Resolve-AgentScopePattern` remains available in [scripts/evals/lib/EquivalenceEnvironment.psm1](../../scripts/evals/lib/EquivalenceEnvironment.psm1) for deferred per-subject guard work.
3. Add subject-aware guards only when evidence shows they measure nominal non-degradation rather than lifecycle phase behavior.

The driver resolves the agent's frontmatter `model:` hint automatically. No new PowerShell, no new stimulus library, and no new judge prompt are required unless the agent's domain materially differs from the existing corpus.

Vally exposes no agent-selection flag. The repository-standard turn-0 `Launch` instruction causes the model to read the staged agent file before the user question. Invocation evidence is parsed from structured tool calls and results, never inferred from the response text.

## Agent Coverage

Any agent in `.github/agents/` can be materialized without being registered anywhere. The driver copies the target agent's surface into an isolated
workspace at run time, so there is no onboarding list to join and no per-agent harness code to add. Stage 1 evaluates `rpi-agent`
alone because the executable Launch turn targets that agent. Subject-aware launch routing is required before meaningful multi-agent coverage.

What does vary per agent is stimulus backlinking. Most stimuli are shared corpus prompts that any agent runs; a subset carries an explicit `tags.agent` backlink marking it as characteristic of that agent's domain. Those backlinks are the only per-agent data in this suite, and they are counted from [stimuli.yml](stimuli.yml):

| Agent           | Backlinked Stimuli | Why                                                                 |
|-----------------|--------------------|---------------------------------------------------------------------|
| rpi-agent       | 18                 | The suite's primary subject and fixed launch target                 |
| documentation   | 3                  | README and documentation-coverage prompts                           |
| code-review     | 3                  | Code walkthrough, error explanation, and correcting a prior mistake |
| issue-triage    | 3                  | Under-specified asks that need classification                       |
| backlog-manager | 2                  | Grooming vague work items                                           |
| brd-builder     | 2                  | Requirements elicitation on vague feature requests                  |
| prd-builder     | 2                  | Requirements elicitation on vague feature requests                  |

Counts sum to more than 35 because a stimulus may backlink several agents. An agent absent from this table has no domain-specific prompt in the v1 corpus.

## Authoritative and Report-Only Interpretation

The driver separates authoritative evidence from report-only comparison through `Get-EquivalenceGateResults` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1).

**Authoritative evidence.** Deterministic invariants, successful agent invocation, run health, and structural population quality determine `equivalenceGate` and `verdict`.

* `runs <= 0` or `dataQualityViolations > 0`: `fail` at **every** tier, including `devloop`. An incomplete comparison cannot evidence equivalence regardless of who runs it, and the summary is left on disk so the cause can be diagnosed from `compareLogs` and the sibling `--output` JSONL.
* `invocationFailures > 0` contributes to structural data-quality failure. Every expected customized `model|stimulus|trial` identity requires one successful exact-path agent-file read with non-empty RPI Agent content.
* `invariantFailures > 0` or `runHealthFailures > 0`: `warn` on `devloop`; `fail` on `calibration` and `ci`.
* An empty equivalent population fails closed at every tier.

**Report-only comparison.** Equivalent-policy signed scores are calculated independently per model. Each model reports score count, mean, standard deviation, 95% confidence bounds, and per-stimulus dispersion. Tie ratio, all-policy Vally summaries, and persona-bleed guards remain diagnostics.

* No comparative pass/fail state exists yet. A valid post-launch calibration must precede any decision about a degradation margin, confidence level, inequality, or authoritative comparative tier.
* Historical values from before launch-based invocation are not comparable to post-change results.
* Individual divergence-guard outcomes are report-only, but total guard collapse is not. When no declared guard produces a result, that is promoted to `runHealthFailures`, which fails `calibration` and `ci`. A guard suite that silently stopped running is a broken run, not a clean one.

The inherited `0.80` tie-ratio floor and the old all-policy `ciLow` and `ciHigh` fields are retained only for historical reporting. Neither participates in an authoritative decision.

## Stimulus Shape

Each entry in [stimuli.yml](stimuli.yml) uses these keys:

| Key                   | Applies To          | Meaning                                                                                                                                           |
|-----------------------|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `name`                | both                | Stimulus identifier; must match across both specs so `vally compare` pairs trajectories by name                                                   |
| `prompt`              | canonical, baseline | The verbatim user-facing question                                                                                                                 |
| `turns`               | customized only     | Exactly two turns: the RPI Agent launch directive followed by the canonical user question                                                         |
| `invariants`          | both                | Named graders that gate the verdict. Measured on the baseline run, so a gating invariant must be evidence a reasonable baseline always produces   |
| `customized_disallow` | customized only     | Named graders from `grader_registry.customized_disallow` that must NOT match the customized trajectory; catches unintended persona or scope bleed |
| `tags`                | filter              | `category` and `subcategory` for stimulus selection and reporting                                                                                 |

A grader may run without gating. Omitting it from `invariants` while leaving it in `graders` keeps it executing and keeps its per-trial result in the run output, but removes it from the verdict.

That split exists because invariants are read from the baseline run only: a grader that records how the *uncustomized* model chose to respond cannot distinguish "the customization layer changed behavior" from "the underlying model answered differently," which is the only question this suite asks.
`asks-clarifying-question` and `mentions-print-paren` report under that rule.
`mentions-scripts-or-deps` still gates, because its stimulus reads a file the seed workspace provides and intermittent failure means the read itself is unreliable.

Reporting-without-gating is not a way to quiet a failing check. It applies when the grader measures the baseline model's preference rather than the customization's effect, and the reasoning belongs in the stimulus entry alongside the change.

Trajectory invariants live at the spec level (not per stimulus) and apply across the baseline-customized pair: model equality (`metadata.model` matches across A and B), baseline-no-customized-skills (the baseline trajectory invokes no skills the customization layer expects), and response length parity within plus or minus 25 percent.

## Customized Disallow Guards

The 35-stimulus corpus is entirely equivalent-policy. `customized_disallow` guards on the instruction-bleed stimuli detect unsolicited RPI Agent self-reference while leaving comparison report-only. Complete delivery evidence showed that the removed customization-boundary guards measured lifecycle phase behavior rather than nominal model non-degradation. Agent behavior testing owns those implementation and scope contracts.

This framing is intentional. The suite is not a free-form quality grader; it asks the narrow question "does customization change anything beyond what we said it would?" Curated allowances keep the question crisp.

## Non-Goals

The suite does NOT assert:

* Latency or wall-clock time. Both environments share the same model; throughput differences are not the customization layer's responsibility.
* Streaming behavior. `vally compare` grading runs on completed responses.
* General multi-turn conversation dynamics beyond the one launch turn and user question.
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
