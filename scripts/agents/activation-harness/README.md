---
title: Agent Activation Harness
description: PowerShell module and Pester harness that fingerprints VS Code Copilot agent cold-start payloads and enforces byte-budget contracts.
---

Computes deterministic activation fingerprints for VS Code Copilot custom agents and asserts cold-start byte budgets via Pester.

## Purpose

The harness models how VS Code Copilot loads a custom agent at activation time and measures the resulting context payload (agent file + every file pulled in via `#file:` directives or `applyTo` auto-attach). It produces a JSON-serializable fingerprint that can be diffed across refactors to prove that intended size reductions actually shipped and that no instruction file silently re-attached.

## Public Surface

`Get-AgentActivationFingerprint -AgentPath <string> -ScenarioName <string> [-RepoRoot <string>]`

Returns:

```text
@{
  ScenarioName   = '<scenario>'
  AgentBytes     = <int>
  ColdStartBytes = <int>           # total bytes loaded for this scenario
  LoadedFiles    = @(@{ Path = '<repo-relative>'; Bytes = <int> })
  Hash           = '<sha256 hex>'  # over deterministic Path:Bytes tuples
}
```

## Scenarios

| Scenario         | Models                                                      | Loads                                                                                                          |
|------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `CleanWorkspace` | Cold start with no editor file matching any `applyTo` glob. | Agent file + every `#file:` directive in the agent body.                                                       |
| `SteadyState`    | Editor working inside `.copilot-tracking/adr-plans/`.       | `CleanWorkspace` payload + every instruction whose `applyTo` covers ADR working directories.                   |
| `GovernEntry`    | Agent transitioning into the Govern lifecycle phase.        | `SteadyState` payload + `#file:` references in Lifecycle Dispatch Table rows tagged `Govern`.                  |
| `AdoptTemplate`  | Agent operating in adopt-template entry mode (Table B).     | `SteadyState` payload + `#file:` references in Table B rows tagged `Ingest`, `Normalize`, `Derive`, or `Fill`. |

## Byte-Budget Contract

The cold-start payload (`CleanWorkspace.ColdStartBytes`) is the gating budget for every agent governed by this harness:

* Pre-refactor baseline for `@adr-creation` is approximately 84 KB and recorded in `baseline.json`.
* Post-refactor target is **&lt; 44,000 bytes** (≈ 38–43 KB band).
* The Pester suite under `scripts/tests/agents/activation-harness/` fails fast when the cold-start payload exceeds 44,000 bytes or when an instruction file expected to remain off cold start (for example `adr-handoff.instructions.md`, `adr-byo-template.instructions.md`) appears in `LoadedFiles`.

## Usage

Run the full suite via the npm wrapper:

```powershell
npm run test:activation
```

This suite validates the activation contract, including cold-start byte budget, lifecycle load-set composition, scenario distinctness, and runner artifacts. It does not fail on exact `baseline.json` hash or byte-count drift.

Drive the module directly:

```powershell
Import-Module ./scripts/agents/activation-harness/Get-AgentActivationFingerprint.psm1 -Force
Get-AgentActivationFingerprint `
    -AgentPath '.github/agents/project-planning/adr-creation.agent.md' `
    -ScenarioName 'CleanWorkspace'
```

## Regenerating `baseline.json`

`baseline.json` is the exact snapshot reference for explicit drift audits. After an intentional change to the agent, to any instruction file it loads, or to any skill file pulled into its load-set (for example an `adr-author` skill script or asset reached via `#file:`), use the scripted checks rather than hand-editing the file:

```powershell
# Drift check with no writes. Exits 1 when the snapshot is out of date.
npm run test:activation:baseline:check

# Recapture the baseline with byte-identical formatting
npm run test:activation:baseline
```

> [!NOTE]
> Any change to ADR agent, instruction, or skill files that the harness loads can invalidate `baseline.json`. Run `npm run test:activation:baseline:check` when you need an exact no-write snapshot audit. Run `npm run test:activation:baseline` only when the drift is intentional and the committed reference should be refreshed.

Workflow:

1. Make the intentional change to the agent, instruction, or skill files.
2. Run `npm run test:activation` to confirm the behavior and invariant suite still passes.
3. Run `npm run test:activation:baseline:check` when the PR needs an exact snapshot drift audit.
4. Run `npm run test:activation:baseline` to rewrite `baseline.json` when the drift is intentional.
5. Commit the baseline update alongside the originating agent, instruction, or skill change.

## Files

* `Get-AgentActivationFingerprint.psm1`: public module exposing the single fingerprint function.
* `Update-AgentActivationBaseline.ps1`: regenerates `baseline.json` deterministically; supports `-DryRun` for CI drift gating.
* `baseline.json`: pre-refactor reference fingerprints across all four scenarios for `@adr-creation`.
* `README.md`: this document.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
