---
title: Validation Commands and CI-Owned Lanes
description: Choose local-safe validation defaults and reproduce CI-owned documentation and evaluation lanes when their prerequisites are available
sidebar_position: 12
author: Microsoft
ms.date: 2026-07-17
ms.topic: how-to
keywords:
  - validation
  - ci
  - npm
  - docusaurus
  - playwright
  - vally
  - evaluations
estimated_reading_time: 9
---

Validation command names distinguish the checks that are safe defaults for a
local development loop from lanes owned by CI. The distinction helps people and
automation choose an appropriate default without implying that a CI-owned
command cannot run on a workstation.

`ci:*` is a naming and default-agent-routing convention. It does not prevent
local execution, add a runtime guard, or require a special npm flag. Run a
named lane directly with its ordinary npm command when its prerequisites are
available.

## Start with local-safe validation

Use the smallest local-safe command that covers the change. Generic validation
does not select a `ci:*` lane, and a command mentioned in documentation, a
plan, a log, or an error message is not an agent execution request.

| Need                                      | Command                  | Notes                                       |
|-------------------------------------------|--------------------------|---------------------------------------------|
| Repository-wide local-safe validation     | `npm run validate:local` | Non-mutating default validation aggregate   |
| Documentation static and component checks | `npm run validate:docs`  | Does not run the browser E2E lane           |
| Markdown tables check                     | `npm run lint:tables`    | Non-mutating table alignment check          |
| Markdown tables fix                       | `npm run format:tables`  | Explicitly mutates table formatting         |
| Markdown lint fix                         | `npm run lint:md:fix`    | Explicitly mutates Markdown where possible  |
| Targeted check                            | `npm run <local-check>`  | Choose the check that owns the changed file |

For example, use `npm run lint:md -- docs/contributing/validation.md` for a
targeted Markdown check, or invoke `npm run lint:frontmatter` after changing
frontmatter. Use explicit fixers only when you intend to modify files, then
review the resulting diff.

## Install dependencies at the package root

This repository has independent lockfiles and package roots. Run `npm ci` in
the root whose command you intend to use. Do not substitute `npm install` for
the reproducible bootstrap path.

| Package root      | Use it for                                                      |
|-------------------|-----------------------------------------------------------------|
| Repository root   | Root validation, scripts, and `ci:eval:*` commands              |
| `docs/docusaurus` | Docusaurus lint, component test, build, and Playwright commands |
| `evals/beval`     | The Beval workflow and its package-specific dependencies        |

Installing dependencies for one root does not provision the other roots. The
root commands that delegate to Docusaurus still need the Docusaurus package
dependencies available.

## Documentation checks and browser lane

The documentation commands separate static and component validation from the
browser-backed lane.

| Lane                            | Command                                                | Prerequisites and cost                                                        | Output and interpretation                                                   |
|---------------------------------|--------------------------------------------------------|-------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Local docs validation           | `npm run validate:docs`                                | Docusaurus package dependencies. Fast local static and component work.        | Console output; use as the normal docs default                              |
| Docs browser setup              | `npm run ci:docs:setup:e2e`                            | Docusaurus dependencies, browser installation, and supported host privileges. | Provisions Chrome for the E2E lane                                          |
| Docs browser E2E                | `npm run ci:docs:test:e2e`                             | Docusaurus dependencies and Chrome. Browser-backed and potentially slower.    | `docs/docusaurus/test-results/` and Playwright output show browser failures |
| Nested browser E2E              | `npm run ci:test:e2e`                                  | Run from `docs/docusaurus`; same browser prerequisites.                       | Standard browser-suite output                                               |
| Nested fast or interactive mode | `npm run ci:test:e2e:fast` or `npm run ci:test:e2e:ui` | Run from `docs/docusaurus`; `:ui` is interactive.                             | Use only when the relevant browser workflow is intended                     |

The setup command and the E2E command remain separate. A generic validation
request does not install a browser, start a service, or run Playwright. In
hosted CI, a failed browser lane means the configured browser environment did
not complete the suite. Locally, first determine whether the browser and its
dependencies were provisioned before treating a launch failure as a product
failure.

## Evaluation lanes

Evaluation lanes are CI-owned because their prerequisites and costs vary. They
remain directly runnable on a prepared local environment.

### Static checks

These lanes do not invoke a model. They are suitable for deliberate local
reproduction after installing root dependencies, but they are not included in
`validate:local`.

| Lane                          | Command                       | Typical prerequisites and output                                              |
|-------------------------------|-------------------------------|-------------------------------------------------------------------------------|
| Eval spec and generator drift | `npm run ci:eval:lint:vally`  | Root dependencies and Vally; may write a drift diff under `logs/`             |
| Eval schema                   | `npm run ci:eval:lint:schema` | Root dependencies and PowerShell modules; writes schema results under `logs/` |
| Eval text                     | `npm run ci:eval:lint:text`   | Root dependencies and Node; writes text-lint results under `logs/`            |
| Eval safety                   | `npm run ci:eval:lint:safety` | Root dependencies; writes `logs/vally-test-safety.json`                       |
| Skill hygiene                 | `npm run ci:eval:lint:skills` | Root dependencies and Vally; validates `.github/skills/`                      |

### Manifest, presence, and runtime sequence

Presence and execution lanes consume changed-artifact manifests. Generate the
manifest with the existing script before invoking them locally, then retain the
output in `logs/` while diagnosing a failure.

| Lane                 | Command                                                                                      | Prerequisites, cost, and output                                                                                                                                                  |
|----------------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Stimulus presence    | `npm run ci:eval:presence`                                                                   | Changed-artifact manifest at `logs/changed-ai-artifacts.json`; fast structural check writing `logs/stimulus-presence.json`                                                       |
| Eval execution       | `npm run ci:eval:execute`                                                                    | Manifest, Vally, Copilot credential, and a noninteractive service-capable environment; model-backed and potentially costly; writes `logs/eval-summary.json` and per-spec results |
| General eval suites  | `npm run ci:eval:run`                                                                        | Vally and model access; model-backed and potentially costly                                                                                                                      |
| One suite            | `npm run ci:eval:run:skills`, `npm run ci:eval:run:agents`, or `npm run ci:eval:run:scripts` | Same model and service prerequisites as the selected suite                                                                                                                       |
| Result comparison    | `npm run ci:eval:compare`                                                                    | Existing Vally result sets; compares prior outputs without selecting another suite                                                                                               |
| Prompt behavior      | `npm run ci:eval:behavior-prompts`                                                           | Vally and model access; runs the prompt conformance spec                                                                                                                         |
| Instruction behavior | `npm run ci:eval:behavior-instructions`                                                      | Vally and model access; runs the instruction conformance spec                                                                                                                    |
| Skill behavior       | `npm run ci:eval:behavior-skills`                                                            | Vally and model access; runs the skill behavior conformance spec                                                                                                                 |
| Agent matrix entry   | `npm run ci:eval:agent`                                                                      | Agent-matrix arguments supplied after `--`; model-backed when execution is selected                                                                                              |

Set `COPILOT_GITHUB_TOKEN` only in the environment that needs model-backed
execution. Never commit credentials, paste them into documentation, or assume
they are available to fork pull requests. Hosted CI clean-skips model execution
when secrets are unavailable to an untrusted fork. A local credential or
service failure is an environment result, not evidence that an eval contract
failed.

### Moderation

| Lane                     | Command                              | Prerequisites and output                                                                             |
|--------------------------|--------------------------------------|------------------------------------------------------------------------------------------------------|
| Input moderation         | `npm run ci:eval:moderate`           | Root dependencies plus the moderation Python environment                                             |
| Corpus moderation        | `npm run ci:eval:moderate:corpus`    | Changed-artifact manifest and moderation Python environment                                          |
| Artifact moderation      | `npm run ci:eval:moderate:artifacts` | Changed-artifact manifest and moderation Python environment; writes `logs/moderation-artifacts.json` |
| Moderation wrapper tests | `npm run ci:eval:moderate:test`      | Root test dependencies; no model invocation                                                          |

Provision the moderation environment with its locked `uv` environment in
`scripts/evals/moderation` before running a real Detoxify lane. The model-backed
moderation path can download or use model weights and is not a generic local
validation default. A setup exit indicates missing dependencies rather than a
clean moderation result.

### Baseline equivalence and agent matrix

| Lane                  | Command                                                    | Behavior and output                                                                                                     |
|-----------------------|------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Baseline equivalence  | `npm run ci:eval:equivalence -- -Agent rpi-agent -Tier pr` | Model-backed comparison; writes `logs/baseline-equivalence-summary.json` and result trajectories under `evals/results/` |
| Equivalence dry run   | `npm run ci:eval:equivalence -- -Agent rpi-agent -WhatIf`  | Prints planned work and writes a dry-run summary without SDK calls                                                      |
| Raw equivalence specs | `npm run ci:eval:run:equivalence`                          | Runs paired specs directly; requires the selected model environment                                                     |
| Agent matrix          | `npm run ci:eval:agent:matrix`                             | Model-backed nightly matrix; writes date-scoped output under `evals/results/agent-matrix/`                              |
| Agent matrix dry run  | `npm run ci:eval:agent:matrix:dryrun`                      | No model invocation; writes a dry-run matrix summary                                                                    |
| Changed-agent matrix  | `npm run ci:eval:agent:changed`                            | Requires a suitable git comparison base and model access                                                                |

PR-tier equivalence results can be advisory while nightly results can be
authoritative. Read the lane's generated JSON verdict and the hosted workflow
status together. Do not infer a hosted CI policy from a direct local invocation.

### Dashboards and reports

Dashboard generation is noninteractive. These commands generate artifacts but
do not open a browser:

```bash
npm run ci:eval:agent:dashboard
npm run ci:eval:agent:report
npm run ci:eval:agent:report:dryrun
npm run ci:eval:dashboard
```

Only `npm run ci:eval:agent:dashboard:open` is interactive and opens the
generated dashboard. Keep it separate from unattended validation or report
generation.

## Beval workflow

Beval is a CI-owned workflow with its own package root at `evals/beval`. The
workflow has a 30-minute timeout and requires `COPILOT_TOKEN`. It installs that
package root, starts Copilot ACP agent and judge services on TCP ports 3000 and
3001, verifies both ports, then runs this existing invocation:

```bash
beval -c evals/beval/dt-coach/eval.config.yaml run --cases evals/beval/dt-coach/cases/ --agent evals/beval/dt-coach/agent.yaml -m validation -o evals/beval/dt-coach/results/results.json
```

Results remain under `evals/beval/dt-coach/results/` and the workflow uploads
them as the `beval-results-${{ github.run_id }}` artifact. Run `npm ci` in
`evals/beval` before a deliberate local reproduction, and establish the two
services and credential through an operator-managed environment. Do not ask for
or transmit the credential through chat. Do not treat Beval as part of
`validate:local`, infer its prerequisites from generic validation, or add a root
package wrapper solely for naming consistency.

## Review and cleanup

Review generated results before removing them. Common local outputs include
`logs/`, `evals/results/`, `docs/docusaurus/build/`, and browser test-report
directories. These artifacts help distinguish a contract failure from missing
dependencies, unavailable credentials, or an unsupported local host.

Treat a passing local reproduction as useful evidence, not as a replacement
for the hosted CI status. Hosted CI controls its own operating system,
credentials, browser provisioning, and branch-protection policy.

## Related guidance

* [Evals in CI](evals-ci) covers the hosted workflow authentication, fork, and
  evaluation-spec contracts.
* [Build System and Validation](../customization/build-system) explains the
  local validation commands and customization points.
* [HVE Core Documentation Site](https://github.com/microsoft/hve-core/blob/main/docs/docusaurus/README.md)
  covers the Docusaurus project and accessibility layers.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
