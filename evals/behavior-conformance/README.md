---
title: Behavior Conformance Suite
description: 'Tier 3 conformance evaluations for prompts, instructions, and skill behavior'
author: HVE Core Team
ms.date: 2026-09-04
---

This directory hosts the behavior conformance suite. It is the only suite under `evals/` that ships in advisory mode by default: failures are reported in the pull request summary but do not block the build until each spec graduates per the graduation policy below.

## Purpose

Behavior conformance answers a focused question per stimulus: *does the asset under test produce output that conforms to its documented contract?* It exercises three asset families:

* Prompt conformance: verifies prompts in `.github/prompts/**/*.prompt.md` invoke the correct subagent identity, scope language, and structural sections.
* Instruction conformance: verifies that instructions in `.github/instructions/**/*.instructions.md` are interpreted by the model in line with their `applyTo` and content rules.
* Skill behavior: verifies that skill invocation produces the canonical artifacts and section headers each `SKILL.md` advertises across three stimulus shapes (knowledge, tool-trigger, bleed-detection).

Each tier shares the same advisory contract and manifest-driven gating model as the other Tier 1/2 suites. Most stimuli use deterministic `output-matches` graders. `skill-behavior.eval.yaml` also uses one `prompt` model-judge grader for a semantic contract that regex cannot credibly assess.

## Spec inventory

| Spec                       | Tier | Mode     | Stimuli | Category               | Status            |
|----------------------------|------|----------|---------|------------------------|-------------------|
| `prompts.eval.yaml`        | 3p   | Advisory | 53      | `behavior-conformance` | Active (Phase 9)  |
| `instructions.eval.yaml`   | 3i   | Advisory | 64      | `behavior-conformance` | Active (Phase 11) |
| `skill-behavior.eval.yaml` | 3s   | Advisory | 228     | `behavior-conformance` | Active (Phase 13) |

The maintained `prompts.eval.yaml` inventory contains 53 stimuli across 48 prompt subjects. Coverage includes RPI orchestration, security review and planning, Design Thinking, Git operations, evaluation authoring, and VEX workflows. Backlog, work-item, and HVE Core pull request coverage moved to `skill-behavior.eval.yaml` when those workflows became skills.

The maintained `instructions.eval.yaml` inventory contains 64 stimuli: 62 instruction-tagged stimuli across 46 instruction subjects, plus two `backlog-management` skill stimuli. Coverage spans:

* Delivery workflows: `ado-create-pull-request`, `ado-get-build-info`, `pull-request`.
* HVE-Core authoring: `commit-message`, `copilot-tracking`, `hve-builder`, `markdown`, `pull-request`, and `writing-style`.
* RAI, Accessibility, and Security planning: `accessibility-identity`, `rai-identity`, `rai-risk-classification`, `backlog-handoff`, `sssc-assessment`, and `standards-mapping`.
* Additional: `docusaurus-edits`, `dt-coach-telemetry`, `experiment-designer`, `disclaimer-language`.

The maintained `skill-behavior.eval.yaml` inventory contains 228 stimuli across 73 skill subjects. It covers RPI and HVE Builder workflows, including HVE Builder bounded-read, research-bridge, unavailable-bridge, read-only-review, and final-candidate behavior-gate decisions plus direct `rpi-challenger`, `rpi-plan-critique`, and pull-request preflight contracts.

The `backlog-plan` and `backlog-execute` workflow commands carry knowledge coverage plus a read-only boundary assertion and a mutation-safety assertion respectively. The retained `prompt-analyze`, `prompt-builder`, and `prompt-refactor` compatibility routes and other installed skill domains remain in advisory mode.

The current branch-specific calibration status is not yet established for gating. Pass-rate and false-positive measurements are collected from advisory CI runs before graduation. Most stimuli use `output-matches` to check contract vocabulary and routing signals, while one skill stimulus uses `prompt` to assess a semantic changes-record contract.

## Pipeline integration

This suite follows the manifest-driven gating model established by DD-01:

* Stimulus resolution is performed by `scripts/evals/Modules/StimulusIndex.psm1`, which already recognizes `kind: prompt` backlinks (added in Phase 9) alongside the existing `skill`, `agent`, and `instruction` kinds.
* When the PR validation workflow's changed-artifact manifest contains at least one prompt, instruction, or skill, the existing `eval-execute` job in [`.github/workflows/pr-validation.yml`](../../.github/workflows/pr-validation.yml) dispatches the matching spec. No new workflow or per-suite job is introduced.
* Named local reproduction: `npm run ci:eval:behavior-prompts` for the prompt suite, `npm run ci:eval:behavior-instructions` for the instruction suite, and `npm run ci:eval:behavior-skills` for the skill behavior suite.

## Advisory mode

Per **DD-05**, every stimulus in this suite carries `tags.advisory: true`. The `Invoke-VallyEvals.ps1` dispatcher reads this tag and suppresses the per-spec failure tally for advisory specs: failures are still surfaced in the per-trial JSONL output and in the PR summary, but the script's overall exit code is not promoted to non-zero.

This keeps the inner-loop signal visible without blocking ship velocity while the model contract stabilizes. Graduation from advisory to authoritative is governed by the policy below.

## Graduation policy

Each behavior-conformance stimulus graduates from advisory to authoritative independently. A graduation pull request flips `tags.advisory: false` (or removes the key) on a single stimulus or a small batch of stimuli (at most three) and must satisfy all of the following:

* **Sample size.** The stimulus has executed in at least 30 CI runs while in advisory mode. Sample counts are sourced from `logs/eval-summary.json` artifacts across recent main-branch runs.
* **False-positive rate.** The rolling 7-day false-positive rate is at most 5%. A false positive is an advisory failure that a human reviewer has determined was correct behavior (the model output met the contract but the grader flagged it).
* **Sign-off.** The graduation pull request carries CODEOWNERS approval and adds an entry to [CHANGELOG.md](./CHANGELOG.md) recording the stimulus id, the observed sample size, and the observed false-positive rate.
* **Rollback policy.** If a graduated stimulus produces a false-positive rate above 5% in the first 14 days after graduation, revert it via a follow-up pull request that restores `tags.advisory: true` and appends a `Reverted` entry to the CHANGELOG.

Driver and workflow changes are not required to graduate a stimulus: the per-stimulus advisory split in `scripts/evals/Invoke-VallyEvals.ps1` consumes the `tags.advisory` value directly. Graduation pull requests are therefore spec-only.

## Graders

Per **DD-23** and **DD-24**, most stimuli declare one or more `output-matches` graders. Simple routing cases commonly use two graders, while richer contract cases use additional graders when distinct requirements need independent signals. One skill stimulus uses `prompt` for semantic behavior that deterministic regex cannot credibly assess:

| Grader role                    | Configuration source      | Intent                                                                       |
|--------------------------------|---------------------------|------------------------------------------------------------------------------|
| Routing or attribution         | Per-stimulus regex        | Asserts the response selects or identifies the documented capability.        |
| Scope or contract vocabulary   | Per-stimulus regex        | Asserts the response stays in scope and carries required contract terms.     |
| Additional contract signal     | Per-stimulus regex        | Separately checks a material boundary, status, artifact, or handoff rule.    |
| Model-judged semantic contract | Per-stimulus judge prompt | Assesses behavior that cannot be reduced credibly to deterministic patterns. |

The behavior specs currently configure `output-matches` and one `prompt` grader. Vally's deterministic output family exposes `output-contains`, `output-not-contains`, `output-matches`, and `output-not-matches`. The CLI registers the LLM-backed `prompt` and `panel` graders on demand when a spec uses them. `orphan-files` and `valid-refs` are skill-hygiene checks run by `vally lint`; they are not eval grader types. This suite loads no custom grader plugin.

## Anti-patterns

* Do not flip `tags.advisory: false` on a stimulus before its prompt has been promoted in Phase 14.
* Prefer deterministic output graders when they can credibly assess the behavior. Reserve `prompt` for semantic contracts that cannot be reduced to stable deterministic signals.
* Do not introduce per-suite workflow files; gating must remain inside the existing `eval-execute` job.
* Do not bypass `StimulusIndex.psm1` to hand-roll a manifest mapping; backlink resolution must remain centralized.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
