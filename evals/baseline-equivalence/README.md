---
title: Baseline Equivalence Suite
description: 'Pairs identical probes across baseline and customized environments to assert only documented divergences appear'
author: HVE Core Team
ms.date: 2026-07-10
---

## Purpose

This suite proves that the hve-core customization layer does not alter underlying GitHub Copilot
model behavior beyond documented divergences. The agent layer is the independent variable:
identical stimuli run twice against the same GHCP model, once against an empty baseline environment
and once against an environment that materializes a target agent (frontmatter, subagents, skills,
and `copilot-instructions.md`) into a fresh temp workdir. Pairwise grading then asks whether the
customized response differs from the baseline only in ways the curated allow-list permits.

The suite answers a single question per stimulus: did customization change the model's answer, or did it change only the framing the customization explicitly requires?

## Layout

```text
evals/baseline-equivalence/
├── README.md           # this file
├── baseline/
│   └── eval.yaml       # executable spec for the empty baseline run (invariant graders + pairwise)
├── customized/
│   └── eval.yaml       # executable spec for the materialized agent run (adds customized_required / customized_disallow)
├── stimuli.yml         # 40 prompts across 8 subcategories at 5 per subcategory
└── compare.eval.yml    # pairwise comparison spec consumed by vally compare
```

The baseline and customized specs are self-contained vally `eval` documents. The PowerShell driver invokes each spec in turn with `vally eval --eval-spec` and then joins the two run directories with `vally compare --run-a <baseline> --run-b <customized>`.

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

The driver parses each `vally compare --run-a <baseline> --run-b <customized>` invocation line by line and aggregates the trial verdicts into a single JSON summary. The summary is the contract every downstream consumer (PR bot, nightly dashboard, future change-detection workflow) reads.

| Field                | Type   | Meaning                                                                                                                                                                    |
|----------------------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `agent`              | string | Agent slug under test (matches `-Agent`)                                                                                                                                   |
| `tier`               | string | `pr` (advisory, exit 0) or `nightly` (authoritative, exit 1 on fail)                                                                                                       |
| `model`              | string | Primary model for the run: PR tier resolves `-Model` override, then frontmatter `model:` hint, then the cheap default (`gpt-5.6-luna`); nightly runs its fixed model array |
| `stimulusFilter`     | string | Regex applied to stimulus names; empty when the full corpus ran                                                                                                            |
| `runs`               | int    | Total trial lines parsed across all compare logs                                                                                                                           |
| `ties`               | int    | Trials the judge marked `tie`; counts toward the equivalence threshold                                                                                                     |
| `aWins`              | int    | Trials the judge preferred run-a (baseline); the customization underperformed                                                                                              |
| `bWins`              | int    | Trials the judge preferred run-b (customized); the customization outperformed                                                                                              |
| `invariantFailures`  | int    | Spec-level invariant violations (model equality, response-length parity, baseline-no-customized-skills)                                                                    |
| `divergenceFailures` | int    | `vally compare` exit codes other than zero, or compare runs that emitted no parseable trial lines                                                                          |
| `verdict`            | string | Aggregated verdict; see [Pass and Fail Interpretation](#pass-and-fail-interpretation)                                                                                      |
| `variants`           | list   | Per-model variant metadata (model id, baseline run directory, customized run directory)                                                                                    |
| `compareLogs`        | list   | Absolute paths to every captured `vally compare` log; failed runs leave the log on disk for inspection                                                                     |

The verdict field is derived from these counts by `Get-VerdictFromAggregate` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1); the exact thresholds are documented below.

### Lint commands

The baseline-equivalence specs live in two subdirectories (`baseline/eval.yaml` and `customized/eval.yaml`) so the driver can invoke them as a paired set. The repository-wide `npm run eval:lint:vally` task runs `vally lint --eval evals/` against the top of the tree and does not descend into these nested directories. Lint the specs explicitly:

| Command                                                             | Purpose                                                                            |
|---------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `vally lint --eval evals/baseline-equivalence/baseline/eval.yaml`   | Schema-validate the empty baseline spec                                            |
| `vally lint --eval evals/baseline-equivalence/customized/eval.yaml` | Schema-validate the materialized customized spec (includes the divergence graders) |
| `vally lint --eval evals/baseline-equivalence/compare.eval.yml`     | Validate the pairwise compare spec consumed by `vally compare`                     |
| `npm run eval:run:equivalence`                                      | Run both specs end to end via `vally eval --eval-spec ...` (no driver, no compare) |

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

The driver aggregates per-stimulus pairwise scores and trajectory invariants into a single verdict via `Get-VerdictFromAggregate` in [scripts/evals/lib/EquivalenceParsing.psm1](../../scripts/evals/lib/EquivalenceParsing.psm1). The rules use the JSON fields documented in [Driver output contract](#driver-output-contract):

* `pass`: `invariantFailures` and `divergenceFailures` are both zero AND the tie ratio (`ties / runs`) is at least 0.80 AND the non-tie distribution is symmetric (`|aWins - bWins| <= (aWins + bWins) * 0.5`).
* `warn`: equivalence thresholds missed (low tie ratio or skewed non-tie distribution) but no invariant or divergence failure occurred AND `tier` is `pr`. The summary records this and the driver exits 0.
* `fail`: any of: `invariantFailures > 0`, `divergenceFailures > 0`, low tie ratio, or skewed non-tie distribution AND `tier` is `nightly`. The driver exits 1 (authoritative regression signal). On `pr` tier the same conditions downgrade to `warn`.
* `inconclusive`: `runs <= 0`. The driver returns `fail`, leaving the summary on disk so the cause (typically zero parseable trial lines) can be diagnosed from `compareLogs`.

PR-tier verdicts surface as warnings on the PR; nightly-tier verdicts gate the nightly workflow. This split keeps the per-PR signal low-friction while preserving a hard regression gate on the main branch.

A non-zero `aWins` count signals that the baseline outperformed the customization (the agent layer regressed against an empty environment). A non-zero `bWins` count signals the opposite: the customization outperformed the baseline (an unannotated quality lift). Both contribute equally to the symmetry check because the suite asks for equivalence, not directionality.

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
* Streaming behavior. Pairwise grading runs on completed responses.
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
