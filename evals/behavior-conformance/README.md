---
title: Behavior Conformance Suite
description: 'Tier 3 conformance evaluations for prompts, instructions, and skill behavior'
author: HVE Core Team
ms.date: 2026-07-16
---

This directory hosts the behavior conformance suite. It is the only suite under `evals/` that ships in advisory mode by default: failures are reported in the pull request summary but do not block the build until each spec graduates per the graduation policy below.

## Purpose

Behavior conformance answers a focused question per stimulus: *does the asset under test produce output that conforms to its documented contract?* It exercises three asset families:

* Prompt conformance: verifies prompts in `.github/prompts/**/*.prompt.md` invoke the correct subagent identity, scope language, and structural sections.
* Instruction conformance: verifies that instructions in `.github/instructions/**/*.instructions.md` are interpreted by the model in line with their `applyTo` and content rules.
* Skill behavior: verifies that skill invocation produces the canonical artifacts and section headers each `SKILL.md` advertises across three stimulus shapes (knowledge, tool-trigger, bleed-detection).

Each tier shares the same advisory contract, the same `output-matches` grader family, and the same manifest-driven gating model as the other Tier 1/2 suites. None of them introduce a model-judge grader.

## Spec inventory

| Spec                       | Tier | Mode     | Stimuli | Category               | Status            |
|----------------------------|------|----------|---------|------------------------|-------------------|
| `prompts.eval.yaml`        | 3p   | Advisory | 69      | `behavior-conformance` | Active (Phase 9)  |
| `instructions.eval.yaml`   | 3i   | Advisory | 71      | `behavior-conformance` | Active (Phase 11) |
| `skill-behavior.eval.yaml` | 3s   | Advisory | 124     | `behavior-conformance` | Active (Phase 13) |

The maintained `prompts.eval.yaml` inventory contains 69 stimuli across 66 prompt subjects. Coverage includes RPI orchestration, security review and planning, ADO, GitHub and Jira backlog workflows, Design Thinking, Git operations, evaluation authoring, and VEX workflows.

The maintained `instructions.eval.yaml` inventory contains 71 stimuli across 56 instruction subjects. Coverage spans:

* ADO backlog and PR families: `ado-backlog-sprint`, `ado-backlog-triage`, `ado-create-pull-request`, `ado-get-build-info`, `ado-update-wit-items`, `ado-wit-discovery`, `ado-wit-planning`.
* GitHub and Jira backlog flows: `github-backlog-discovery`, `github-backlog-planning`, `github-backlog-triage`, `github-backlog-update`, `jira-backlog-planning`, `jira-wit-planning`.
* HVE-Core authoring: `copilot-tracking`, `hve-builder`, `markdown`, `pull-request`, and `writing-style`.
* RAI and Security planning: `rai-identity`, `rai-risk-classification`, `backlog-handoff`, `sssc-assessment`.
* Additional: `docusaurus-edits`, `experiment-designer`, `story-quality`, `disclaimer-language`.

The maintained `skill-behavior.eval.yaml` inventory contains 124 stimuli across 50 skill subjects. It covers RPI and HVE Builder workflows, including the HVE Builder bounded-read, research-bridge, unavailable-bridge, and read-only-review decisions plus direct `rpi-challenger` and `rpi-plan-critique` contracts. The retained `prompt-analyze`, `prompt-builder`, and `prompt-refactor` compatibility routes and other installed skill domains remain in advisory mode.

The current branch-specific calibration status is not yet established for gating. Pass-rate and false-positive measurements are collected from advisory CI runs before graduation, and regex-only `output-matches` graders check contract vocabulary and routing signals rather than full semantic correctness.

## Pipeline integration

This suite follows the manifest-driven gating model established by DD-01:

* Stimulus resolution is performed by `scripts/evals/Modules/StimulusIndex.psm1`, which already recognizes `kind: prompt` backlinks (added in Phase 9) alongside the existing `skill`, `agent`, and `instruction` kinds.
* When the PR validation workflow's changed-artifact manifest contains at least one prompt, instruction, or skill, the existing `eval-execute` job in [`.github/workflows/pr-validation.yml`](../../.github/workflows/pr-validation.yml) dispatches the matching spec. No new workflow or per-suite job is introduced.
* Local invocation: `npm run eval:behavior-prompts` for the prompt suite, `npm run eval:behavior-instructions` for the instruction suite, and `npm run eval:behavior-skills` for the skill behavior suite.

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

Per **DD-23** and **DD-24**, each stimulus declares one or more `output-matches` graders. Simple routing cases commonly use two graders, while richer contract cases use additional graders when distinct requirements need independent signals:

| Grader role                  | Pattern source     | Intent                                                                    |
|------------------------------|--------------------|---------------------------------------------------------------------------|
| Routing or attribution       | Per-stimulus regex | Asserts the response selects or identifies the documented capability.     |
| Scope or contract vocabulary | Per-stimulus regex | Asserts the response stays in scope and carries required contract terms.  |
| Additional contract signal   | Per-stimulus regex | Separately checks a material boundary, status, artifact, or handoff rule. |

The repository's grader registry exposes `output-matches` (regex), `exact-match`, `contains`, and the hygiene-only `orphan-files`/`valid-refs` graders. No `type: prompt` (model judge) grader is registered, so this suite does not add LLM-judge grading; deeper semantic coverage is intentionally deferred to Phase 15 custom-grader work tracked under WI-16.

## Anti-patterns

* Do not flip `tags.advisory: false` on a stimulus before its prompt has been promoted in Phase 14.
* Do not introduce a `type: prompt` grader. The registry does not support it and the lint will fail.
* Do not introduce per-suite workflow files; gating must remain inside the existing `eval-execute` job.
* Do not bypass `StimulusIndex.psm1` to hand-roll a manifest mapping; backlink resolution must remain centralized.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
