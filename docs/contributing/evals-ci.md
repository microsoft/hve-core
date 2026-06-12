---
title: Evals in CI
description: Auth contract, fork-PR policy, and how to add a new eval spec for the hve-core vally pipeline
sidebar_position: 11
author: Microsoft
ms.date: 2026-05-23
ms.topic: how-to
keywords:
  - evals
  - vally
  - ci
  - copilot
  - github actions
estimated_reading_time: 5
---

This guide describes how the vally eval pipeline authenticates in CI, how forked pull requests are handled, and how to add a new eval spec for an AI artifact (agent, prompt, instructions file, or skill).

## Required Secret

The `eval-execute` job in `.github/workflows/pr-validation.yml` runs the `vally eval` command for each changed AI artifact. The `vally` CLI delegates to the `@github/copilot` CLI, which requires a GitHub credential exported as `COPILOT_GITHUB_TOKEN`.

Configure the secret at the repository (or organization) level:

* Settings -> Secrets and variables -> Actions -> New repository secret
* Name: `COPILOT_GITHUB_TOKEN`
* Value: a token from one of the accepted token types listed below.

## Token-Type Guidance

The `@github/copilot` CLI accepts the following token prefixes. Classic personal access tokens (`ghp_`) are rejected at runtime.

| Prefix         | Token Type                         | Use in CI                                      |
|----------------|------------------------------------|------------------------------------------------|
| `ghs_`         | GitHub App installation token      | Preferred. Short-lived, scoped, auditable      |
| `github_pat_`  | Fine-grained personal access token | Acceptable when a GitHub App is not feasible   |
| `gho_`, `ghu_` | OAuth / user-to-server token       | Avoid. Tied to a user identity                 |
| `ghp_`         | Classic personal access token      | Rejected at runtime. The probe fails fast      |
| `GITHUB_TOKEN` | Actions-issued token               | Scope-limited. Not sufficient for `vally eval` |

For hve-core, the recommended pattern is a GitHub App with Copilot SDK scopes that mints an installation token in CI and exports it as `COPILOT_GITHUB_TOKEN`.

### Probe Behavior

`scripts/evals/Test-CopilotToken.ps1` runs before any `vally eval` invocation and exits non-zero with a `::error::` annotation when:

* `COPILOT_GITHUB_TOKEN` is missing or empty **and** `gh auth token` cannot supply a token (fallback for local runs with the GitHub CLI logged in)
* the token begins with `ghp_` (classic PAT)
* the optional `-SmokeTest` switch invokes `vally --version` and the CLI exits non-zero

The pass-path `Reason` includes `(source: COPILOT_GITHUB_TOKEN)` or `(source: gh auth token)` so contributors can confirm which credential path was used. The smoke test reports a clean skip when `vally` is not installed locally, so contributors can run the probe outside CI without installing the CLI.

## Per-Job COPILOT_HOME Isolation

The `@github/copilot` CLI persists state (logged-in users, caches) under the directory named by `COPILOT_HOME`, defaulting to `~/.copilot`. CI jobs share runner home directories across steps and can pollute each other when this state leaks.

Export `COPILOT_HOME` to a job-local path in every workflow job that invokes `vally`:

```yaml
env:
  COPILOT_GITHUB_TOKEN: ${{ secrets.COPILOT_GITHUB_TOKEN }}
  COPILOT_HOME: ${{ runner.temp }}/copilot-home
```

This pattern keeps each eval job hermetic, prevents credential bleed-through between matrix legs, and avoids the deprecated `--config-dir` CLI flag.

## Fork PR Policy

GitHub Actions does not expose repository secrets to workflows triggered by pull requests from forks. Without `COPILOT_GITHUB_TOKEN`, the `eval-execute` job cannot succeed.

The pipeline clean-skips eval execution for fork PRs rather than failing the check:

```yaml
jobs:
  eval-execute:
    if: github.event.pull_request.head.repo.fork == false
```

The `eval-presence` and `eval-lint` jobs do run on fork PRs because they require no secrets. Structural problems with eval specs (missing coverage, schema violations, profanity in stimulus text) surface immediately. Eval execution itself runs only after a maintainer merges the fork branch into a trusted topic branch on the upstream repository.

## Adding a New Eval Spec

When you add or modify an AI artifact under `.github/agents/`, `.github/prompts/`, `.github/instructions/`, or `.github/skills/`, the `eval-presence` job fails the PR until a matching eval spec exists.

Steps to add coverage:

1. Create an eval spec under `evals/` that follows the structure documented in `evals/README.md`.
2. Set the spec's `stimulus.backlink` field to the absolute repository path of the artifact under test (for example, `.github/agents/coding-standards/researcher-subagent.agent.md`).
3. Ensure the spec declares an executor compatible with the `vally` CLI (typically the `CopilotSdkExecutor` with a `model:` hint).
4. Run the presence check locally to confirm the artifact is covered:

   ```pwsh
   pwsh scripts/evals/Get-ChangedAIArtifact.ps1 -BaseRef origin/main -HeadRef HEAD -OutFile logs/changed-ai-artifacts.json
   pwsh scripts/evals/Test-StimulusPresence.ps1 -ManifestPath logs/changed-ai-artifacts.json
   ```

5. Run the eval locally (requires `COPILOT_GITHUB_TOKEN` in your shell environment):

   ```pwsh
   pwsh scripts/evals/Test-CopilotToken.ps1 -SmokeTest
   pwsh scripts/evals/Invoke-VallyEvals.ps1 -ManifestPath logs/changed-ai-artifacts.json
   ```

Commit the new spec alongside the artifact change. The PR comment summary in `eval-execute` reports per-artifact pass/fail with links to the captured `logs/eval-results-<artifact-id>.json` payloads.

## Stimulus presence linter

[scripts/evals/Test-StimulusPresence.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Test-StimulusPresence.ps1) is the gate that fails an `eval-presence` job when a changed AI artifact lacks an eval spec backlink. It reads the manifest produced by [scripts/evals/Get-ChangedAIArtifact.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Get-ChangedAIArtifact.ps1) and builds a coverage index from every `evals/**/*.yaml` spec.

Each changed artifact is matched against the `stimuli[].tags.<kind> = <slug>` backlinks in that index. Deleted artifacts (manifest status `D`) are skipped because coverage cannot be required for removed files.

The script writes a structured report to `logs/stimulus-presence.json` (covered, missing, errors, skipped) and emits a single `::error file=...::` annotation per missing artifact, so a PR comment names the file that needs coverage.

Exit codes:

| Exit | Meaning                                                                                   |
|------|-------------------------------------------------------------------------------------------|
| 0    | Every changed artifact is covered, or the manifest is empty or contains only deletions.   |
| 1    | At least one changed artifact is missing an eval-spec backlink.                           |
| 2    | Invalid input: missing manifest, missing `evals/` root, or unrecoverable YAML parse fail. |

The `-FailOnSpecError` switch promotes recoverable YAML parse failures to a hard exit 2 so a malformed spec cannot mask a missing-backlink failure during local hardening sweeps.

Run the linter locally before pushing artifact changes:

```pwsh
pwsh scripts/evals/Get-ChangedAIArtifact.ps1 -BaseRef origin/main -HeadRef HEAD -OutFile logs/changed-ai-artifacts.json
pwsh scripts/evals/Test-StimulusPresence.ps1 -ManifestPath logs/changed-ai-artifacts.json -FailOnSpecError
```

To add coverage for a missing artifact, create or extend an eval spec under `evals/` and set `stimuli[].tags.<kind>` to the artifact slug (the basename minus the `.agent.md`, `.prompt.md`, `.instructions.md`, or `SKILL.md` suffix); the next run reports it covered.

## Per-Spec Moderation Threshold

The `moderation.threshold` schema field on an eval spec sets the per-spec Detoxify cutoff (any label score exceeding the value hard-fails the spec):

```yaml
moderation:
  threshold: 0.7
```

The validator accepts numeric values in `[0.0, 1.0]`; out-of-range or non-numeric values emit `ModerationThresholdOutOfRange` / `ModerationThresholdType` diagnostics during `eval:lint:schema`. The default is `0.5` when the field is omitted.

`Invoke-VallyEvals.ps1 -ModerationThreshold <value>` overrides every spec's threshold for a run. CLI override wins over the per-spec value, which wins over the default.

## Content moderation coverage

Content moderation runs in two complementary CI lanes, each scoped to a different surface.

| Lane              | Job in [`pr-validation.yml`](https://github.com/microsoft/hve-core/blob/main/.github/workflows/pr-validation.yml) | Script                                                                                                                                 | Toolchain                                | Surface                                                                   |
|-------------------|-------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|---------------------------------------------------------------------------|
| Markdown corpus   | `eval-lint`                                                                                                       | [scripts/evals/Test-EvalSpecText.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Test-EvalSpecText.ps1)             | Node (alex.js, retext-profanities)       | `.github/{agents,prompts,instructions,skills}/**/*.md` and `docs/**/*.md` |
| Eval-spec stimuli | `content-moderation`                                                                                              | [scripts/evals/Invoke-CorpusModeration.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Invoke-CorpusModeration.ps1) | Python + Detoxify (`unitary/toxic-bert`) | Stimulus text and expected-output fixtures inside `evals/**/*.yaml`       |

The two lanes target different surfaces and do not overlap: the markdown-corpus lane keeps the AI artifacts that ship to contributors free of insensitive or foul language; the eval-spec stimuli lane scores adversarial test inputs against a Detoxify cutoff so a spec that probes a model with toxic content cannot itself ship unredacted.

The `content-moderation` job is the only path that exercises the real Detoxify model in CI. The job installs the Python dependencies (`scripts/evals/moderation/requirements.txt`) via `uv pip install`, caches the Detoxify weights between runs, then invokes `Invoke-CorpusModeration.ps1` per spec.

`Invoke-CorpusModeration.ps1` shells out to [scripts/evals/Invoke-ContentModeration.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Invoke-ContentModeration.ps1) for each stimulus. The default Detoxify threshold is `0.5`; per-spec overrides come from the `moderation.threshold` field documented above.

Local opt-in for the Detoxify lane:

```pwsh
uv pip install -r scripts/evals/moderation/requirements.txt
pwsh scripts/evals/Invoke-CorpusModeration.ps1 -SpecGlob 'evals/**/*.yaml'
```

Without the Python dependencies installed, `Invoke-ContentModeration.ps1` exits 2 with a setup error rather than silently passing. The markdown-corpus lane (`Test-EvalSpecText.ps1`) requires only Node and runs in `lint:all` without any opt-in.

## Eval Lint Scripts

Four eval-lint commands run in `lint:all`:

| Script             | Tool                            | Purpose                                                           |
|--------------------|---------------------------------|-------------------------------------------------------------------|
| `eval:lint:vally`  | `vally lint --eval-spec evals/` | Spec validation via the upstream CLI                              |
| `eval:lint:schema` | `Test-EvalSpec.ps1`             | hve-core schema lint (graders, executor, `moderation.threshold`)  |
| `eval:lint:text`   | `Test-EvalSpecText.ps1`         | retext-profanities + alex.js gate on the AI-artifact corpus       |
| `eval:lint:safety` | `Test-VallyTestSafety.ps1`      | Safety gate on vally test stimuli (`logs/vally-test-safety.json`) |

`eval:lint:text` scans `.github/{agents,prompts,instructions,skills}/**/*.md` and `docs/**/*.md`. By default `retext-profanities` findings flip the exit code (errors) and `alex` findings emit `::warning` annotations only. Pass `-FailOnAlex` to promote alex findings to errors for local hardening:

```pwsh
pwsh scripts/evals/Test-EvalSpecText.ps1 -FailOnAlex
```

False-positive lexical matches (e.g., `penetration test`, `attack surface`, `token abuse`) are filtered by the phrase-aware allowlist in `scripts/evals/Modules/retext-runner.mjs` (`PHRASE_ALLOWLIST` keyed by retext rule id; ±60-character context window).

`Test-EvalSpecText.ps1` exit codes:

| Exit | Meaning                                                                                      |
|------|----------------------------------------------------------------------------------------------|
| 0    | No error-level findings (alex.js findings may still be reported as warnings).                |
| 1    | At least one `retext-profanities` finding, or any alex.js finding when `-FailOnAlex` is set. |
| 2    | Setup failure (corpus expansion failed, Node shim missing, or `node` not on PATH).           |

### Baseline-equivalence specs

`eval:lint:vally` runs `vally lint --eval-spec evals/`, which validates the eval YAML files immediately under `evals/` but does not recurse into nested subdirectories. The baseline-equivalence suite under [evals/baseline-equivalence/](https://github.com/microsoft/hve-core/tree/main/evals/baseline-equivalence/) ships nested specs (`baseline/eval.yaml`, `customized/eval.yaml`, and `compare.eval.yml`) that need explicit per-file lint invocations:

```pwsh
vally lint --eval-spec evals/baseline-equivalence/baseline/eval.yaml
vally lint --eval-spec evals/baseline-equivalence/customized/eval.yaml
vally lint --eval-spec evals/baseline-equivalence/compare.eval.yml
```

[scripts/evals/Invoke-BaselineEquivalence.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Invoke-BaselineEquivalence.ps1) runs all three implicitly during `npm run eval:run:equivalence`. See [evals/baseline-equivalence/README.md](https://github.com/microsoft/hve-core/blob/main/evals/baseline-equivalence/README.md) for the suite operator guide and driver-output contract.

## Running Pester Tests Locally

`npm run test:ps` wraps `scripts/tests/Invoke-PesterTests.ps1`. The default invocation applies `ExcludeTag=@('Integration','Slow')`:

```pwsh
npm run test:ps                                              # default green-bar (excludes Integration + Slow)
npm run test:ps -- -ExcludeTag Slow                          # include Integration, exclude Slow
npm run test:ps -- -Tag Integration                          # run only Integration-tagged tests
npm run test:ps -- -TestPath scripts/tests/evals/            # scope to one directory
```

`-Tag` (with `-IncludeTag` as an alias) and `-ExcludeTag` flow through to the inner Pester configuration only when explicitly bound, so omitting them preserves the default exclusion. CI matches the default invocation; opt-in tag overrides are intended for targeted local runs.

Results land in `logs/pester-summary.json` (overall counts) and `logs/pester-failures.json` (per-failure detail).

## Testing PowerShell Wrappers Around Python Subprocesses

`Invoke-ContentModeration.ps1` invokes `python` through `Start-Process` in a child `pwsh -NoProfile -File` boundary. The parent test scope's `Mock` / `function:` injections do not cross that boundary, so the test suite at `scripts/tests/evals/Invoke-ContentModeration.Tests.ps1` uses a PATH-shimmed stub:

1. Create a temp directory and write `python.cmd` containing a CMD wrapper that re-launches `pwsh` against a canned `python.ps1`.
2. Prepend the temp directory to `$env:PATH` for the duration of the test.
3. The child process resolves `python` to the shim, executes `python.ps1`, and observes real argv (`--input`, `--output`, `--threshold`).

This is the only viable mock boundary for cross-process invocation. Apply the same pattern when adding tests for any PowerShell script that shells out to a Python subprocess.

### Test authoring patterns

When authoring new Pester suites for the evals scripts, three patterns recur often enough to call out:

* Define helper functions inside `BeforeAll { function ... }` so Pester promotes them to the containing `Describe` scope for all `It` blocks. Functions defined directly inside `Describe` (outside `BeforeAll`) do not survive the fresh runspaces Pester uses for each `It`.
* When the command under test is invoked through `pwsh -File` or `Start-Process` (so the parent runspace cannot install a `Mock`), declare a bare function at file scope in the test (or in a fixture script the child loads). The PATH-shim pattern above is one instance of this; the [scripts/tests/evals/fixtures/stub-vally.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/evals/fixtures/stub-vally.ps1) fixture is another.
* When a stub or script under test needs to signal a non-zero exit while `$ErrorActionPreference = 'Stop'` is in effect, write the diagnostic with `[Console]::Error.WriteLine(...)` and then call `exit <code>` explicitly. `throw` short-circuits the runspace before the intended exit code is set, which causes the parent process to observe exit 1 instead of the contract code.

The stub-vally fixture demonstrates the third pattern in practice. [scripts/tests/evals/Invoke-VallyEvals.Tests.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/evals/Invoke-VallyEvals.Tests.ps1)
drives [scripts/evals/Invoke-VallyEvals.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/evals/Invoke-VallyEvals.ps1) against the fixture by passing `-VallyCommand $script:StubPath` and setting `$env:STUB_VALLY_MODE` to `pass`, `fail`, or `crash` per scenario. Per-spec overrides flow through `$env:STUB_VALLY_MODES_JSON`.

This lets the stub-mode aggregation tests exercise the real driver code paths (the manifest loop, threshold override, and summary writer) without invoking the `vally` CLI or paying Copilot SDK costs.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
