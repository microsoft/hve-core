---
description: "Native Vally execution, safe validation, spending boundaries, and evidence interpretation for skill-effectiveness"
---
<!-- cspell:ignore uninspected -->

# Native Execution And Evidence

The supported runtime is Vally 0.17.0, Copilot CLI 1.0.85 and SDK 1.0.14,
on Node.js 24+. Windows is the tested platform. Historical generated packages
retain their own code and pins; do not upgrade completed experiments in place.

## Copy And Test The Reusable Skill

Copy `SKILL.md`, `SECURITY.md`, `assets/`, `references/`, `package.json`,
`package-lock.json`, `.npmrc` and `.gitignore` as one folder.
No parent-repository helpers are needed.
Exclude node_modules, temporary test directories, logs, generated coverage
reports and previous outputs.

From the copied skill folder:

```powershell
npm ci
npm test
```

The four test files validate packaging, native lint/dry-run/mock results,
code-plus-prompt evidence wiring, inventory capture and SDK image attachments.
Ordinary tests use mocked SDK sessions and do not require the optional Copilot
binary. Native session-startup coverage is skipped unless explicitly selected.
These tests do not judge output quality or prove model vision.

The host's coverage-enabled Node runner writes `coverage-node.info` in the skill
folder. This generated report is ignored by Git and the package-content check;
other undeclared package files remain errors.

After separately authorizing local runtime startup and installing optional
dependencies, select the model-free native smoke test:

```powershell
$env:SKILL_EFFECTIVENESS_NATIVE_PREFLIGHT = '1'
node --test --test-name-pattern="actual native executor" assets/native-inventory.test.mjs
Remove-Item Env:\SKILL_EFFECTIVENESS_NATIVE_PREFLIGHT
```

This smoke test creates real local SDK sessions but stops before any model prompt.
It is not part of ordinary upstream validation.

The development package and generated package pin the same direct dependencies
and security overrides. MCP SDK 1.31.0 fixes GHSA-6qxp-vccf-f47h. Azure Monitor
exporter beta.46 replaces the old logging stack containing OpenTelemetry Core
2.0.0 (GHSA-8988-4f7v-96qf); its compatible Core versions include the 2.8.0 fix.
Keep these overrides when generating a package, since the exporter's `latest`
tag still selects the older release. No custom OAuth provider is supplied here;
applications adding HTTP OAuth must also follow the MCP advisory's credential
issuer-binding and migration requirements.
The CLI brings its server dependency transitively; no separate server pin is
needed here. YAML is used by template tests. The committed lockfile was
regenerated from public npm and uses canonical registry URLs and SHA-512
integrity hashes. Preserve direct pins and security overrides when regenerating.
Do not hand-repair hashes or resolve through a private mirror. Use a clean
resolution directory with copies of this package's manifest and registry
configuration, no existing lockfile, and no installed dependencies:

```powershell
npm install --package-lock-only --ignore-scripts --registry=https://registry.npmjs.org/
```

Inspect and replace only this package's lockfile. Then run `npm ci`, the package
tests, and the host's public dependency-feed check.

## Author A Native Package

Use the [copy map](../SKILL.md#assemble-and-validate). Generate its own lockfile.
Put the public task and required interfaces in the eval prompt and fixtures.
Keep role maps, private checks, reviews and previous outputs outside candidate
inputs. Stage only needed sources, not an entire authoring workspace.

Both variants explicitly list complete skill arrays, with shared skills in both
and the focus skill only in treatment. Keep every other condition identical.
The native template demonstrates completion, delivery, executable checking and a
native `prompt` grader. Replace its task/checker/rubric placeholders, remove
methods that do not fit and agree judge usage before execution. `capability`
and `regression` are Vally classifications, not choices of grading method.
Keep the existing-skill and repository-origin routes on this same execution path.

Prefer native file/content graders for simple checks and `run-command` for existing
tests. For example, when the public task includes the following test interface:

```yaml
- type: run-command
  name: behavior
  config:
    command: node
    args: ["--test", "task-fixture/behavior.test.mjs"]
    expected_exit_code: 0
    timeout: 3m
```

Test a passing result, a meaningful failing result and a broken checker setup.
A process exit alone cannot explain why a command failed; inspect the native
details and logs. Use a task-specific `program` grader only when necessary.
Do not return success plus a private "uninspected" flag: native reports do not
interpret that as unavailable.

## Validate Without Spending

Run from the generated package root, replacing task/model placeholders:

```powershell
npm ci
npm run vally -- lint --strict --eval-spec evals/<task>.eval.yaml
npm run study:dry-run -- experiments/<task>.experiment.yaml --param AGENT_MODEL=<id> --param JUDGE_MODEL=<judge-id>
```

The dry-run uses native Vally without loading the inventory recorder or starting
candidate sessions. It does not establish agent startup or budget enforcement.

Native `prompt` grading can coexist with executable checks. Put task-quality
criteria in the stimulus rubric and select evidence explicitly. For artifact
tasks, use `repo` rather than assuming the final response contains the files.
Follow [source-grounded review](holistic-review.md) to inspect snapshot coverage,
protect original sources and avoid condition leakage. Graders need not execute
sequentially; do not assume the judge receives another grader's output.

Count model judges as paid execution. The native prompt client can issue reminder
turns and retry failures; one configured grader is not a hard one-call cap.
Use [SDK image review](visual-review.md) for actual pixels after capture. Its
separate command has no scripted retries, but neither path enforces a credit cap.

## Execute Only After Authorization And Spending Controls

Native Vally 0.17.0 does not expose the required SDK session credit setting.
The recorder does not supply it. Do not start a paid run requiring that cap until
an adequate execution path exists. A timeout, manual monitoring or post-run
inspection is not a hard financial limit. Model reviews have the same requirement.

Once scope, budget and actual controls are adequate, use ordinary PowerShell
setup and native arguments; there is no custom launcher:

```powershell
$run = Join-Path $HOME ("skill-eval-runs\" + [guid]::NewGuid())
if (Test-Path -LiteralPath $run) { throw "Use a new evidence directory" }
$env:SKILL_EVAL_INVENTORY_DIR = Join-Path $run "inventories"
$env:COPILOT_CLI_PATH = node -p "require.resolve('@github/copilot-' + process.platform + '-' + process.arch)"
if ($LASTEXITCODE -ne 0) { throw "Pinned Copilot CLI could not be resolved" }
foreach ($name in @("EVALUATE_USE_HOST_COPILOT_HOME", "COPILOT_HOME_SETTINGS_JSON", "NODE_OPTIONS")) {
  [Environment]::SetEnvironmentVariable($name, $null, "Process")
}
npm run study:run -- experiments/<task>.experiment.yaml --param AGENT_MODEL=<id> --param JUDGE_MODEL=<judge-id> --output-dir "$run\runs" --workspace "$run\workspaces" --workers 1
if ($LASTEXITCODE -ne 0) { throw "Native run failed; preserve and inspect its evidence before proceeding" }
```

Each invocation needs a new external evidence directory. Record the exact command,
role mapping and output location in EVALS.md. Inspect one run before authorizing
the next; do not automate silent retries. `study:run` is just Node with `--import`
followed by the pinned Vally CLI. It forwards native arguments and exit status.
Direct CLI execution without the preload does not capture inventories.

## Publisher Iteration, Repetition And Pairing

Start with a useful comparison, not a required number of runs. An initial pair
can expose an unsuitable task or a measure that misses the claimed benefit.
The publisher may improve the skill or evaluation, record the changes in EVALS.md
and preserve earlier results. Examples tuned this way are development evidence.
Publisher inspection can guide iteration without pretending to be independent
review or an automatic quality verdict.

For a repeat batch, agree the count and spending scope, then keep the skill,
task, inputs and assessment fixed. Native `overrides.runs: N` repeats each
task/model/variant combination; one task and two variants means 2*N candidate
sessions. Count all experiment files and combinations before spending, and use
dry-run to confirm the plan. Report every trial. Rejudging saved outputs does
not create fresh candidate trials, and repetition does not improve a bad measure.

Vally orders variant IDs lexically. The template uses `a-baseline` and
`b-treatment`, with `baseline: a-baseline`. For a treatment-first pair, copy the
native experiment under a distinct name, use `a-treatment` and `b-baseline`,
set `baseline: b-baseline`, and retain each role's correct skill array.
Increasing `overrides.runs` does not alternate variant order. To alternate pairs,
keep `overrides.runs: 1` in separate native experiment files and reverse roles
between files within the agreed budget. A repeated fixed-order batch is also
possible; disclose its order imbalance rather than claiming counterbalancing.

Record which experiment files form the planned pairs. Use native task, variant,
trialIndex and session identities (including itemId/shardKey where present).
Native single-trial records can omit trialIndex; use their native task/variant
identity and unique itemId/shardKey rather than inventing a repetition number.
Never infer pairing from file order or replace missing attempts with another
repetition. No duplicate schedule format or cross-block analyzer is supplied.

## Inspect The Evidence

The [recorder](../assets/native-inventory.mjs) saves actual skill metadata after
SDK initialization and before returning a new session for its first prompt.
Its only setup variable is the absolute `SKILL_EVAL_INVENTORY_DIR`. Loaded as a
Node preload, it rejects missing configuration rather than silently doing nothing.
It resolves the pinned runtime from its package, not the host installation.

Snapshots retain enabled states, runtime source paths when available, requested
skill directories, timestamp and actual session ID. Match each filename/ID to
native trial session metadata. Native judge sessions created in the same CLI
process can also be captured; they are not candidate trials. Separate grader
processes do not inherit the preload.

The recorder changes no discovery, instructions, permissions, tools, memory,
resume behavior or credit settings. Unexpected skills are recorded, not rejected.
Capture/persistence errors stop that session before a prompt. Vally can omit the
transient inventory from persisted history; this is why the recorder remains.

Inspect baseline for focus-skill leakage, including copies at other paths/names;
check treatment availability and understand other context differences. Shared
unrelated skills do not automatically invalidate a comparison. Check native skill
activations and access traces for other outputs, private checks or external inputs.
No recorded invocation does not prove no availability or influence.

Missing snapshots, necessary source paths or logs remain unverified. A startup
snapshot does not cover later context changes, and native permissions can permit
access outside the workspace. This is supervised detection, not enforced isolation
or an OS sandbox. Preserve contaminated attempts, apply symmetric exclusions and
authorize replacements separately. A complete native report is not a clean bill
of integrity.

## Report Without A Second Reporting System

Link Vally's actual run directory, native report, raw trial records, workspaces
and inventories. Keep separate human/Copilot assessments beside that evidence,
with their inputs, limits and failures. Neither narrative findings nor later
visual reviews retroactively change native grades.

Distinguish a completed check scoring zero, missing candidate output, evaluator
unavailability and operational errors. Preserve native error status even when its
message is empty. Inspect individual grader results; do not interpret the aggregate
as task quality or a skill-effect verdict. Unknown usage stays unknown.

Write paired observations, variation, exclusions and limitations in EVALS.md.
Address the claimed benefit separately from delivery/check pass rates. For
example, successful C4 rendering establishes valid diagrams; examining abstraction
levels, relationship clarity and actual-image legibility addresses a communication
claim. Explain a preference with evidence, allow ties, and identify the reviewer.
There is no generated analysis.json, combined effect report or RESULTS.md updater.
Small pilots do not establish general effectiveness or equivalence.
