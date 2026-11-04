---
title: Experimental schema-constrained report finalization
description: Opt-in same-session synthetic test of report-only response schemas
ms.date: 2026-11-04
---

## Scope

The [experimental finalization path](../../scripts/evals/rca-real-world/schema-finalization.mts)
uses the installed Copilot headless runtime. It sends an investigation prompt and host-supplied
evidence without response schemas, waits for an exact report-readiness signal, and sends a
schema-constrained finalization prompt in the same session. Only the final report is constrained.
No evidence is repeated in that final prompt.

The report keeps the existing [diagnostic contract](../../scripts/evals/rca-real-world/communication.mts).
The skilled condition requires a nested finding; the baseline does not receive that field.
Existing semantic validation still rejects contradictory findings and invalid authority claims.
An unsupported model, invalid readiness signal, runtime error, timeout, invalid report, or failed
session cleanup produces an explicit failure. There is no unconstrained fallback or host repair.

The paired evaluation runner offers this boundary with `--report-output schema` under
`ad-hoc-v9`; `--report-output prompt` remains the default and rollback mode for a fresh run.
Its schema mode uses host-mediated exact approvals, not native runtime tool execution.
Every readiness and finalization send consumes the existing turn budget. Output mode is immutable
in manifests, scores, and reports. The audit checks the outbound schema fingerprint and same-session
identity. Cumulative usage includes the final send and must be complete and within budget.

The standalone experiment below does not execute tools: successful results and a tool failure
are supplied as synthetic host evidence. The integrated runner has separate deterministic tests
for actual host execution, approvals, replay, final/blocked outcomes, budgets, and mode inheritance.
Neither establishes compatibility with native tool calling or production investigations.

## Run the checks

The existing Node test runner covers deterministic schema, stage, validation, and framing checks:

```powershell
node --test scripts\tests\evals\rca-real-world\schema-finalization.test.mts
```

The live test is skipped unless explicitly enabled. It makes three model sends to the debug model,
uses no actual incident data, disables tools, verifies private skill/plugin isolation, and writes
raw synthetic evidence and events to a fresh directory. Set an absolute output path that does not
already exist:

```powershell
$env:RCA_SCHEMA_SMOKE = '1'
$env:RCA_SCHEMA_SMOKE_OUTPUT = Join-Path $PWD '.copilot-tracking\evaluations\schema-finalization-smoke-unique'
node --test --test-name-pattern='live synthetic' scripts\tests\evals\rca-real-world\schema-finalization.test.mts
```

The integrated synthetic smoke test uses a small generated fixture and no RCA skill bundle:

```powershell
$env:RCA_SCHEMA_RUNNER_SMOKE = '1'
$env:RCA_SCHEMA_RUNNER_SMOKE_OUTPUT = Join-Path $PWD '.copilot-tracking\evaluations\schema-runner-smoke-unique'
node --test --test-name-pattern='live integrated schema runner' scripts\tests\evals\rca-real-world\runner.test.mts
```

Do not treat a passing synthetic test as evidence of improved RCA accuracy. Use a fresh run ID
for a model-backed evaluation and do not pool schema-mode results with prompt-only results.

## Disable or revert

Live smoke tests are opt-in. Leave both `RCA_SCHEMA_SMOKE` and `RCA_SCHEMA_RUNNER_SMOKE` unset
to skip them during ordinary tests. Use `--report-output prompt` for a fresh run to disable
runtime schema enforcement. Do not delete the runtime modules while the runner imports them.
No dependency manifest, skill, or historical evaluation file was changed by this integration.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
