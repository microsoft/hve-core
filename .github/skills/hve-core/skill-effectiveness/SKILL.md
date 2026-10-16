---
name: skill-effectiveness
description: "Use when creating, reviewing or improving a native Vally A/B evaluation of whether an Agent Skill helps on a realistic task, including deriving a candidate skill from repository knowledge."
license: MIT AND CC-BY-4.0
user-invocable: true
compatibility: "Node.js 24+, Vally 0.17.0, Copilot CLI 1.0.85 and SDK 1.0.14. Windows is the tested native platform."
---
# Evaluate Skill Effectiveness

## Goal

Help answer: **Does the same agent do the same task better with this skill?**
Build one runnable native Vally 0.17.0 package. Start with the useful task,
not a rubric or an evaluation framework.

This is a supervised experimental authoring aid. Local tests establish mechanics,
not judge accuracy, general skill value or reduced human effort.
Help the publisher build and iterate a credible demonstration of a claimed
benefit, not obtain a universal one-shot verdict.

## Success Criteria

* Produce a native evaluation package with both comparison arms, relevant public
  inputs, task-specific evidence, and evaluation notes.
* Keep conditions identical except for the complete focus skill, and disclose
  contamination, unavailable evidence, and development-example reuse.
* Distinguish measured outcomes, assessment judgments, and operational errors.
* Obtain explicit authorization and adequate spending controls before paid calls.

## Discuss The Task

Start from either an existing skill or a repository:

- For an existing skill, use it directly; no extraction or preliminary baseline run
  is required.
- For a repository, follow [repository intake](references/repository-intake.md) to
  identify useful knowledge, write a source-grounded candidate skill and check
  it. Keep the generated candidate outside this authoring skill's folder. If no
  candidate is defensible, explain why and stop. Otherwise continue below with
  that candidate; creation alone does not establish effectiveness.

Read the focus skill and identify connected capabilities that could help on a
realistic task. Explain what a capable baseline may already do and what observable
user benefit the skill might add. Do not require section coverage.

Discuss good and poor outcomes, valid alternatives, baseline headroom, fair
inputs/tools and unmeasured scope. Record this in
[EVALS.md](assets/EVALS.template.md), not a second measurement configuration.
For repository selection, use [repository intake](references/repository-intake.md).
State the publisher's claimed benefit and how to examine it: executable outcomes,
reasoned assessment of outputs, measured effort, or a combination.

## Keep The Comparison Fair

- Use the same task, original inputs, model, tools, limits and checks in both
  arms. Add only the complete focus skill to treatment; shared skills go to both.
- Disclose every required output and checker interface to both candidates.
  Do not encode a preferred implementation or private requirement in scoring.
- Pin sources and skill contents. Keep role mappings, author notes, prior
  outputs and judgments outside candidate and reviewer inputs.
- Fix the task and interpretation rules before seeing outputs. Changes informed
  by results require a new run. Reused examples are development, not held out.
- Use fresh candidate sessions and preserve failed/incomplete attempts.
- Inspect actual startup skill inventories and native access traces. Capture
  does not enforce isolation; missing evidence remains unverified. Preserve
  contaminated attempts and apply exclusions equally, without silent retries.

## Choose The Evidence

Choose evidence for the claimed benefit, not whichever grader is easiest to add:

| Claim                                                   | Evidence to generate                                                                    |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Behavior, calculations or contract fidelity             | Native `run-command` with relevant tests or validators                                  |
| Source-grounded interpretation, omissions or usefulness | Native `prompt` assessment of actual artifacts and sources, or an explicit human review |
| Legibility or visual communication                      | Rendered images inspected by a human or the supplied SDK image-review path              |

Combine executable and model assessment when they answer different parts of the
task. A precisely specified function may need tests alone; an analytical notebook
often needs execution, interpretation and image assessment. Do not require every
method for every task. Use native graders first; write a task-specific program
only for an observed gap. Completion and file existence are delivery prerequisites,
not the main evidence of quality.

Ask: **If both candidates deliver valid outputs, what evidence would let the
publisher decide whether the skill helped?** Consider a materially worse but
valid output. If it would pass every automated check, identify the concrete
review needed to examine the claimed benefit; do not present those checks as
the complete evaluation. A reasoned, opinionated assessment is valid: explain
why the difference matters to the user, accept alternatives and allow a tie.
If delivery itself is the claimed benefit, say so.

For open-ended tasks, implement the assessment using [holistic review](references/holistic-review.md).
The native template demonstrates executable checks plus a `prompt` grader; adapt
or remove methods that do not fit. Give each review the same task, relevant
original sources and criteria, but only its submission. Native `repo` evidence
supplies bounded text snapshots, not pixels or automatic anonymity. Inspect what
the judge actually receives; omitted sources and condition clues are limitations.
If choosing human review, identify the evidence and questions in the generated
notes rather than claiming the automatic checks measure the full benefit.

Select a short set of relevant, observable skill-derived guidelines before
inspecting outputs. Assess their adherence separately from task quality, accept
valid alternatives and mark unobservable practices unknown. Keep these evaluator
inputs out of the baseline candidate's context. Baseline adherence does not prove
that the skill is universally redundant.

Use executed tests for behavioral claims and actual rendered images for
[visual review](references/visual-review.md). Keywords, schemas, rendering success
and citation resolution do not establish substantive quality.

Missing required candidate output is a delivery failure. Missing evaluator
evidence is unmeasured; checker/runtime errors stay errors, not measured zeroes.
Both outputs may be inadequate. Keep executed results and model reasoning
separately interpretable: a favorable review does not erase a failing test, and
a passing test does not prove a sound conclusion. Native aggregate scores are
not skill-effect verdicts. One appropriate judge is enough to start; do not add
a panel or another deciding model without a reason.

## Assemble And Validate

Follow [native execution](references/experiment-method.md). Vally owns candidate
execution, workspaces, graders, native records and reports.

| Asset                                                       | Generated-package destination                  |
|-------------------------------------------------------------|------------------------------------------------|
| [Package](assets/package.template.json)                     | `package.json`; generate an exact lockfile     |
| [Registry configuration](.npmrc)                            | `.npmrc`; retain the canonical public registry |
| [Native eval](assets/native-eval.template.yaml)             | `evals/<task>.eval.yaml`                       |
| [Native experiment](assets/native-experiment.template.yaml) | `experiments/<task>.experiment.yaml`           |
| [Inventory recorder](assets/native-inventory.mjs)           | `scripts/native-inventory.mjs`                 |
| [SDK image review](assets/review-images.mjs)                | `scripts/review-images.mjs`                    |
| [Evaluation notes](assets/EVALS.template.md)                | `EVALS.md`                                     |

Include public fixtures, the focus skill and directly relevant task tests.
Do not add a launcher, second schedule/plan format, custom result converter,
review framework or report generator.

Vally orders variants lexically. For repeated pairs, author native experiment
files with alternating role order and the correct baseline field. Record commands,
pair mappings and any justified imbalance in the notes. Choose counts within the
authorized budget, not a universal quota. Use native `overrides.runs` for
repetitions; increasing it alone does not alternate order. Record total candidate
sessions before spending. No custom repetition engine is needed.

Before spending, run install, strict native lint, dry-run and focused tests.
Test valid alternatives, meaningful wrong results, missing inputs and actual
checker startup errors. Validate a model judge on task-relevant good/weak examples
within an agreed review budget; local mocks establish wiring, not judgment quality.
Select criteria from the task before grading outputs; do not tune them until a
preferred candidate wins. On Windows invoke JavaScript CLIs through Node instead
of spawning npm.cmd. Model-free tests do not establish assessment quality.

## Run And Interpret

An initial pair can test whether the task and evidence are useful. The publisher
may then improve the skill, task or assessment, documenting what changed and
preserving earlier outcomes. Label examples tuned against observed outputs as
development demonstrations, not held-out validation. Publisher inspection during
iteration is useful but must not be called blinded or independent review.
Once satisfied, agree a repeat count and keep the skill, task and assessment fixed
for fresh candidate trials to examine whether the observed difference recurs.
Repetition does not repair an irrelevant measure or prove general effectiveness.

**Paid trials and model reviews require explicit scope, budget and adequate
spending controls.** Native Vally 0.17.0 does not expose the needed SDK credit
limit. Do not start a paid path requiring that cap until it is available;
timeouts and post-run audits are not substitutes. No new approval flags apply.
Include native prompt-grader calls and SDK image reviews in the agreed scope;
they are additional model usage, not free checks.

The generated `study:dry-run` and `study:run` scripts call native Vally directly.
They take an experiment path and native arguments, including `--param AGENT_MODEL=...`;
use the environment setup and full commands in the execution guide.

Inspect inventories, session identities and access traces before interpreting
results. Pair by native task/trial identity and declared experiment pairing,
never directory or record order. Keep native reports and raw evidence; write a
short assessment of paired observations, failures, variation, measured usage and
limits. There is no automatic cross-block analysis or adoption verdict.

Unavailable usage stays unknown. Repeated reviews of one output pair measure
judgment stability, not independent skill trials. Small pilots establish neither
equivalence nor statistical confidence. Negative and inconclusive outcomes are
useful feedback for publisher iteration. Report all agreed trials, not just
favorable examples, and distinguish a curated demonstration from broader evidence.

## Stop Rules

* Stop candidate creation when repository evidence does not justify a useful skill.
* Stop paid execution when authorization, required spending controls, or required
  comparison evidence is unavailable.
* Report dependency, checker, runtime, and evidence failures explicitly; do not
  convert them into effectiveness scores or silently retry.

## Licensing

Historical experiments and review attachments are not shipped in this package.

| Material                                                                     | License   |
|------------------------------------------------------------------------------|-----------|
| Skill and reference prose, evaluation-notes template, and security model     | CC-BY-4.0 |
| JavaScript helpers and tests, YAML/JSON templates, and package configuration | MIT       |

License terms: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) and
[MIT](https://github.com/microsoft/hve-core/blob/main/LICENSE).

Dependencies retain their own licenses; no dependency source is vendored.
Read [the security model](SECURITY.md) before changing executable helpers or
authorizing their use with external content.
