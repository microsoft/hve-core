---
name: skill-effectiveness
description: "Use when authoring or reviewing a native Vally baseline-versus-with-skill evaluation, with separate protected offline grading and existing-skill or repository-derived candidate entry routes."
license: MIT AND CC-BY-4.0
user-invocable: true
compatibility: "Node.js 24+, Vally 0.19.0, Copilot CLI 1.0.89 and SDK 1.0.15. Qualify the selected task/runtime policy separately; model-free checks do not establish containment."
---
# Evaluate Skill Effectiveness

## Goal

Help answer: **Does the same agent do the same task better with this skill?**
Author one native Vally A/B package. Start with the useful task,
not a rubric or an evaluation framework.

This is a supervised experimental authoring aid. Local tests establish mechanics,
not judge accuracy, general skill value or reduced human effort.
Help the publisher build and iterate a credible demonstration of a claimed
benefit, not obtain a universal one-shot verdict.

For a first use, read the
[authoring-only walkthrough](references/first-evaluation.md): minimum inputs,
a complete native pair, expected files and model-free plan inspection.

**Execution status:** the default templates do not enforce candidate or grader
containment. An optional Windows-native candidate profile applies the supported
command sandbox without inherited Copilot authentication variables. Read the
[restricted execution profile](references/experiment-method.md#restricted-execution-profile)
before selecting a runtime. Its adapter supports fresh environment-scoped
sessions only and rejects default/resume requests. Model-free checks cover tested
Linux boundaries and the opt-in Windows command policy, not arbitrary tasks,
grader containment or successful model-driven execution. Do not start untrusted
execution until the selected task and grading route are qualified; see
[evidence and limits](references/experiment-method.md#completed-model-free-evidence-and-limits).
The reusable authoring package and generic adapter are cross-platform; the
optional `windows-native` profile is Windows-only, not a portable sandbox.
For separate Linux image rendering, use the
[browser namespace profile](references/experiment-method.md#linux-browser-namespace-sandbox)
and opt-in real rendering regression; it does not restrict candidate sessions.
For full repository checkouts, qualify
[explicit empty client mode](references/experiment-method.md#explicit-empty-client-mode-for-repository-workspaces)
and inspect the actual instruction inventory before collecting outputs.

## Success Criteria

* Produce a native evaluation package with both comparison arms, relevant public
  inputs, task-specific evidence, and evaluation notes.
* Keep conditions identical except for the complete focus skill, and disclose
  contamination, unavailable evidence, and development-example reuse.
* Distinguish measured outcomes, assessment judgments, and operational errors.
* Obtain explicit approval for the paid scope and budget, and disclose which
  spending limits the execution path can and cannot enforce.

## Discuss The Task

Start from either an existing skill or a repository:

* For an existing skill, use it directly; no extraction or preliminary baseline run
  is required.
* For a repository, first complete the required canonical policy activation in
  [repository intake](references/repository-intake.md) before reading target
  sources. If activation is unavailable, stop that route. Then
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

Ground runtime capability claims in the pinned public Vally and SDK
distributions and their supported interfaces.
Public API declarations and package inspection do not prove runtime enforcement.

* Use the same task, original inputs, model, tools, limits and checks in both
  arms. Add only the complete focus skill to treatment; shared skills go to both.
* Disclose every required output and checker interface to both candidates.
  Do not encode a preferred implementation or private requirement in scoring.
* Pin sources and skill contents. Keep role mappings, author notes, prior
  outputs and judgments outside candidate and reviewer inputs.
* Fix the task and interpretation rules before seeing outputs. Changes informed
  by results require a new run. Reused examples are development, not held out.
* Use fresh candidate sessions and preserve failed/incomplete attempts.
* Inspect actual startup skill inventories and native access traces. Capture
  does not enforce isolation; missing evidence remains unverified. Preserve
  contaminated attempts and apply exclusions equally, without silent retries.
  Verify model-facing skill availability and activation as well as registration.
  Include the native `skill` tool when skills are supplied; a runtime may omit
  that tool when baseline has no skills. Disclose that native conditional
  exposure and keep both requested tool lists identical.

## Choose The Evidence

Choose evidence for the claimed benefit, not whichever grader is easiest to add:

| Claim                                                   | Evidence to generate                                                                    |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Behavior, calculations or contract fidelity             | Protected native `program` grading of relevant tests or validators                      |
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
The candidate template collects public task/delivery evidence only. A separate
grade-only template authenticates a private checker against an operator-pinned
digest and grades one bound submission through native protected-input paths.
The optional saved-review template contains only a `prompt` grader;
adapt or remove methods that do not fit. Give each review the same task, relevant
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

| Asset                                                             | Generated-package destination                  |
|-------------------------------------------------------------------|------------------------------------------------|
| [Package](assets/package.template.json)                           | `package.json`; generate an exact lockfile     |
| [Registry configuration](.npmrc)                                  | `.npmrc`; retain the canonical public registry |
| [MIT notice](LICENSE)                                             | `LICENSE`; retain with redistributed helpers   |
| [License allocation and attribution](NOTICE)                      | `NOTICE`; retain with copied materials         |
| [Native eval](assets/native-eval.template.yaml)                   | `evals/<task>.eval.yaml`                       |
| [Protected offline grade](assets/native-grade-eval.template.yaml) | `evals/<task>.grade.eval.yaml`                 |
| [Saved-evidence review](assets/native-review-eval.template.yaml)  | `evals/<task>.review.eval.yaml`; optional      |
| [Native experiment](assets/native-experiment.template.yaml)       | `experiments/<task>.experiment.yaml`           |
| [Inventory recorder](scripts/native-inventory.mjs)                | `scripts/native-inventory.mjs`                 |
| [SDK image review](scripts/review-images.mjs)                     | `scripts/review-images.mjs`                    |
| [Session-policy plugin](scripts/restricted-copilot-executor.mjs)  | `scripts/restricted-copilot-executor.mjs`      |
| [Optional Windows profile](scripts/native-windows-sandbox.mjs)    | `scripts/native-windows-sandbox.mjs`           |
| [Evaluation notes](assets/EVALS.template.md)                      | `EVALS.md`                                     |

Place public fixtures in `fixtures/<task>/public` and reviewed evaluator originals
in `grading/<task>`. Only the former enters candidate staging. Keep the full
focus skill intact, including legitimate public validation tools.
Candidate and grader toolchains may differ: for example, candidates can use
Node/Python while offline graders execute Jupyter notebooks and render Mermaid.
Disclose that split to both arms, preserve identical candidate capabilities and
retain full executable and visual evidence. A split is not permission to replace
required grading with file-only checks.
Use one original native trial record and one completed arm-bound snapshot per
offline grade invocation. Keep trusted checker/dependency originals outside
candidate mounts, bind their reviewed digest before execution and use fresh
scratch/output locations. Preserve original native reports byte-for-byte;
link every new grade explicitly in EVALS.md. A grade pass alone cannot prove
correct arm binding, immutable inputs or credential/egress isolation.
Keep review evidence and EVALS.md outside both candidate inputs and broad source
copies. See the [staging contract](references/experiment-method.md#separate-public-grading-and-review-inputs)
for grader-only dependencies, saved-result review and the remaining runtime gates.
Do not add a launcher, second schedule/plan format, custom result converter,
review framework or report generator.

Vally orders variants lexically. For repeated pairs, author native experiment
files with alternating role order and the correct baseline field. Record commands,
pair mappings and any justified imbalance in the notes. Choose counts within the
authorized budget, not a universal quota. Use native `overrides.runs` for
repetitions; increasing it alone does not alternate order. Record total candidate
sessions before spending. No custom repetition engine is needed.

Before spending, run install, strict native lint, dry-run and focused tests.
Exercise the actual native read/write/completion lifecycle with synthetic
responses and task-specific positive/negative permission checks. Include
ordinary directory listing; a denied legitimate operation can invalidate a pair.
Keep native workspace paths short and verify that audit patches are retained.
Retain startup audit records in an explicit durable operator audit directory, not inside
candidate workspaces or their directory listings. Keep operator policy receipts
there too; provide explicit, disjoint audit and workspace roots alongside native
outputs. Native temporary log roots do not preserve extra audit files on export.
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

**Paid trials and model reviews require explicit approval of the run plan and
budget.** Before any paid invocation, read and apply
[the supervised run policy](references/experiment-method.md#execute-an-approved-run-plan),
including retry/rerun scope, unknown usage and security prerequisites.
Authoring and model-free validation do not authorize calls. The retained CLI and
image helper still permit manual execution. The package omits paid aliases;
this does not enforce a spending ceiling.
Timeouts are not financial enforcement either. When an enforced
maximum is required but unavailable, stop. Keep spending enforcement with the
provider or native runtime, not a custom controller.

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
* Stop execution when required candidate/grader containment is unavailable or
  unverified; never fall back silently to unrestricted local execution.
* Do not start the next paid invocation when approval or required comparison
  evidence is missing, approved scope is complete, or reported usage reaches the
  agreed target. Missing or incomparable usage needs explicit bounded
  continuation approval. If a required enforced ceiling is unavailable, do not
  start paid calls.
* Report dependency, checker, runtime, and evidence failures explicitly; do not
  convert them into effectiveness scores or silently retry.

## Licensing

The package contains reusable authoring materials, not evaluation results.

| Material                                                                     | License   |
|------------------------------------------------------------------------------|-----------|
| Skill and reference prose, evaluation-notes template, and security model     | CC-BY-4.0 |
| JavaScript helpers and tests, YAML/JSON templates, and package configuration | MIT       |

License terms: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) and
[MIT](https://github.com/microsoft/hve-core/blob/main/LICENSE).

Dependencies retain their own licenses; no dependency source is vendored.
Retain [NOTICE](NOTICE) and `LICENSE` in generated packages, including attribution
and change notices for adapted evaluation notes. These terms cover copied HVE
materials, not automatically user-authored content or the complete generated
work. The generated manifest leaves that work's license to its author.
Read [the security model](SECURITY.md) before changing executable helpers or
authorizing their use with external content.
