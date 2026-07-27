---
title: Evaluations
description: 'Architecture overview and contributor guide for Vally evaluation specs'
author: HVE Core Team
ms.date: 2026-07-16
---

This directory contains [Vally](https://www.npmjs.com/package/@microsoft/vally-cli) evaluation specs for hve-core.

## Architecture

```text
evals/
├── skill-quality/        copilot-sdk evals testing skill behavior
├── agent-behavior/       copilot-sdk evals testing agent responses
├── script-validation/    copilot-sdk evals testing deterministic scripts
├── baseline-equivalence/ parameterized baseline-vs-customized equivalence suite
├── behavior-conformance/ Tier 3 advisory conformance for prompts, instructions, and skill behavior
└── skill-hygiene/        vally lint structural checks for .github/skills/
```

## Executors

| Suite                  | Executor      | Purpose                                                                                              |
|------------------------|---------------|------------------------------------------------------------------------------------------------------|
| `skill-quality`        | `copilot-sdk` | Tests that skills provide accurate guidance via real agent conversation                              |
| `agent-behavior`       | `copilot-sdk` | Tests that agents respond correctly to domain prompts                                                |
| `script-validation`    | `copilot-sdk` | Tests agent reasoning about validation rules (will migrate to mock when available)                   |
| `baseline-equivalence` | `copilot-sdk` | Asserts hve-core agent customization preserves baseline model behavior beyond documented divergences |
| `behavior-conformance` | `copilot-sdk` | Tier 3 advisory conformance for prompts, instructions, and skill behavior (does not fail PR builds)  |
| `skill-hygiene`        | `vally lint`  | Structural checks for every `SKILL.md` under `.github/skills/`; authoritative, no executor calls     |

The `skill-hygiene` suite is the only entry that uses `vally lint` instead of `vally eval`. It is a README-only suite (no `eval.yaml`) that reuses the lint pipeline's static grader registry to validate the skill catalog on every PR that touches `.github/skills/`. See [`skill-hygiene/README.md`](skill-hygiene/README.md) for coverage and grader detail.

## Running Evals

```bash
# Lint all eval specs (no execution, fast)
npm run ci:eval:lint:vally   # vally schema lint
npm run ci:eval:lint:schema  # PowerShell schema/shape lint
npm run ci:eval:lint:skills  # vally lint over .github/skills/ (skill-hygiene suite)
npm run ci:eval:lint:text    # alex.js + retext-profanities (corpus)

# Run all maintained eval suites
npm run ci:eval:run

# Run a specific suite
npm run ci:eval:run:skills
npm run ci:eval:run:scripts

# Compare results against baseline
npm run ci:eval:compare
```

## Adding New Evals

1. Create a directory under `evals/` with an `eval.yaml`.
2. Choose the executor:
   * `copilot-sdk` for testing skill/agent behavior (non-deterministic, use `runs: 3`+).
   * `mock` for testing scripts/validators with fixture files (deterministic, use `runs: 1`). Not yet available - use `copilot-sdk` until the mock executor plugin ships.
3. Write per-stimulus graders (one stimulus per test case).
4. Run `npm run ci:eval:lint:vally` (or `npm run ci:eval:lint:schema`) to validate the spec.
5. Tag stimuli with `category` matching a suite filter in `.vally.yaml`.

## Anti-Patterns

* Don't use `runs: 1` for copilot-sdk evals (non-deterministic output needs multiple runs).
* Don't set timeout below `120s` for copilot-sdk evals.
* Don't use `output-contains` as the sole grader for qualitative agent output.
* Don't bundle multiple test cases into one stimulus with an aggregate grader.
* Don't pin models in eval specs.

## Command guidance

The `ci:eval:*` prefix identifies CI-owned lanes; it does not prevent direct
local execution. These lanes are separate from `validate:local` because their
dependencies, service access, and model cost vary. See [Validation Commands
and CI-Owned Lanes](../docs/contributing/validation) before reproducing a lane.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
