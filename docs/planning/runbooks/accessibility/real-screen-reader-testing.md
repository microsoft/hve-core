---
title: Real screen reader testing
description: Shared guidance for human-led real assistive technology testing, evidence capture, and release gating.
author: Microsoft
ms.date: 2026-09-18
ms.topic: how-to
keywords:
  - accessibility
  - screen reader
  - assistive technology
  - runbook
---

## Purpose

Use this runbook when generated accessibility plans or runtime artifacts need human-led evidence from a real screen reader such as NVDA or JAWS. The goal is to document the test setup, the expected interaction path, and the evidence a reviewer should record before any claim is made about a surface or control.

For the case-specific, public-safe manual validation checklist for the HVE Core docs accessibility remediation work, see [HVE Core docs accessibility manual validation](../../../contributing/accessibility-manual-validation).

## Deterministic synthetic gate versus optional real assistive-technology integration

Treat the synthetic runtime probe as the deterministic gate for catalog and driver validation. Synthetic evidence is useful for checking catalog provenance, keyboard allowlist enforcement, and the local resolver contract, but it does not prove real assistive-technology behavior. A real assistive-technology pass remains optional evidence for human-led validation when the environment is available and the plan requires AT-confirmed behavior.

Use real AT integration only when:

* the generated plan or matrix entry explicitly calls for AT evidence;
* the target interaction depends on screen-reader-specific output that synthetic playback cannot decide; or
* a reviewer needs confirmation of keyboard focus, announcement sequencing, or control-state output in an actual AT runtime.

Do not treat a real-screen-reader pass as a substitute for synthetic validation. Do not claim that a control is automation-eligible merely because a human run was observed in a local environment.

## Shared prerequisites

Before starting, confirm the following:

* The target surface, interaction state, and expected user task are known from the generated plan or matrix entry.
* The tester has access to a supported operating system and assistive technology stack.
* The browser, browser version, and AT version are recorded in the evidence notes.
* The target can be reproduced without assistance from the implementation team.
* The test environment is isolated from unrelated work and does not expose private or PII-bearing content.

Keep the case-specific commands and expected outcomes in the generated plan rather than in this shared runbook. The runbook only describes the shared procedure and evidence format.

## Target isolation, privacy, and evidence hygiene

* Use a disposable or test-only surface when possible.
* Avoid exposing PII, secrets, credentials, or internal-only content in the test environment.
* Record only the minimum necessary evidence: target identifier, AT stack, browser, steps, observed output, and result classification.
* Tear down the test surface, close the browser, and reset any temporary state before leaving the environment.
* If the required AT stack is unavailable, record the result as not yet verified rather than claiming a pass or a failure.

## Windows + NVDA setup and execution

### Automated harness setup

Prepare the machine separately from installing repository dependencies. Every command below establishes its own working directory, so none of them depend on where the previous one left you.

Set the two roots once per shell session:

```powershell
$RepoRoot = (git rev-parse --show-toplevel)
$SkillRoot = Join-Path $RepoRoot '.github/skills/accessibility/accessibility'
```

Record the prior state before changing anything, so a later comparison can tell what this setup altered:

```powershell
npx --yes @guidepup/setup@0.25.3 --version
Get-ChildItem "$env:USERPROFILE/.guidepup" -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
Get-Process nvda -ErrorAction SilentlyContinue | Select-Object Id, StartTime
```

Run the machine preparation once per Windows machine:

```powershell
Set-Location $RepoRoot
npx --yes @guidepup/setup@0.25.3 setup
```

Install the NVDA asset from the version-matched project after each Guidepup version update, so the installed asset matches the manifest the harness resolves:

```powershell
Set-Location $SkillRoot/scripts/runtime_a11y
npx --yes @guidepup/setup@0.25.3 install nvda
```

The setup and install commands modify machine configuration and the Guidepup user cache. Do not infer or run them as part of ordinary validation.

Before automated calibration, run the prerequisite-only probe. It starts no screen reader and takes no desktop control:

```powershell
Set-Location $SkillRoot
uv run scripts/runtime_a11y/__main__.py run-calibration --config <path-to>/a11y-runtime.config.json --prerequisite-only
```

Paths passed to `--out` and `--run-root` are containment-checked against the repository root, not against your current directory. Pass them relative to `$RepoRoot`, or run the command from `$RepoRoot` with an explicit `--project`:

```powershell
Set-Location $RepoRoot
uv run --project .github/skills/accessibility/accessibility `
  .github/skills/accessibility/accessibility/scripts/runtime_a11y/__main__.py run-calibration `
  --config docs/docusaurus/a11y-runtime.config.json `
  --prerequisite-only `
  --out .copilot-tracking/accessibility/local-runs/<date>/prereq.json
```

The probe reports the skill-local Guidepup library, manifest-selected NVDA asset, and a conflicting NVDA process independently. Do not launch a personal NVDA instance before the automated run. The harness launches an isolated Guidepup session and fails closed when another NVDA process is active.

### Supported recovery

Guidepup documents asset and cache management, not machine rollback. Use only the supported steps below.

1. Confirm no NVDA process is active before changing assets. A running instance holds files the reinstall needs:

   ```powershell
   Get-Process nvda -ErrorAction SilentlyContinue | Select-Object Id, StartTime
   ```

   Stop an instance you started yourself through NVDA's own exit command. Do not force-terminate a screen reader a person is relying on.

2. Reinstall the version-matched asset from the same project that installed it:

   ```powershell
   Set-Location $SkillRoot/scripts/runtime_a11y
   npx --yes @guidepup/setup@0.25.3 install nvda
   ```

3. Remove unused cached assets only when a reinstall does not resolve the problem. Inspect first, then remove the specific unused entry rather than the whole cache:

   ```powershell
   Get-ChildItem "$env:USERPROFILE/.guidepup" | Select-Object Name, LastWriteTime
   ```

4. Verify recovery with the prerequisite-only probe before any run that takes desktop control. A clean probe is the recovery acceptance signal.

Removing the Guidepup cache does not reverse the machine-level changes `setup` made, and this project does not document a machine uninstall. Guidepup exposes no such contract, so do not invent one. Reversing Windows-level configuration, registry state, or an NVDA installation a person installed themselves belongs to your endpoint management or vendor support procedures, not to this runbook.

### Bounded case selection and integrity gate

Use repeatable `--journey` arguments to select the exact live cases authorized for one desktop-control window. Unknown or duplicate IDs fail before browser or NVDA startup.

Omitting `--journey` authorizes only the journeys authored under `calibration.journeys`. Case execution recipes bound through the screen-reader catalog take live desktop control, so they are opt-in and must be named explicitly. When a configuration authors no calibration journeys, an unfiltered command fails and lists the bound IDs available for explicit selection.

```powershell
Set-Location $SkillRoot
uv run scripts/runtime_a11y/__main__.py run-calibration `
  --config <path-to>/a11y-runtime.config.json `
  --journey screen-reader-integrity `
  --run-root <local-evidence-root>
```

Before desktop control begins the harness prints an explicit notice naming the run root, the journey count, and the exact journey IDs it is authorized to run. Read that list and confirm it matches what you intended before leaving the machine alone.

Run `screen-reader-integrity` before dependent product cases. Continue only when it produces an accepted checkpoint and browser/NVDA cleanup is certain. A checkpoint proves that the selected tool stack worked; it is not a conformance result and must not be promoted into a WCAG outcome by itself.

After the integrity gate passes, start a new bounded run for the selected product journeys. Keep raw speech under the restricted local evidence root. Ordinary evidence and composed bundles use classifications, counts, digests, and artifact hashes rather than transcript text.

### Bounded deterministic collection

`run-all` without `probeScoping` expands every known probe across every declared surface and state. Use `--probe`, `--surface`, and `--state` for local evidence collection unless the project config declares a reviewed probe scope. Real NVDA stays in explicit `run-calibration` sessions rather than ordinary deterministic CI.

```powershell
Set-Location $SkillRoot
uv run scripts/runtime_a11y/__main__.py run-all `
  --config <path-to>/a11y-runtime.config.json `
  --probe probe-axe `
  --surface homepage `
  --state desktop `
  --out <local-evidence-root>/axe-homepage-desktop.json
```

An explicit `--probe`, `--surface`, or `--state` that selects no run is a usage failure rather than a successful empty document, so a typo cannot be mistaken for a clean result.

Each Node probe child has a bounded runtime. Real NVDA startup, stop, command dispatch, action capture, log clearing, and speech-log capture are also bounded. Projects can lower the `realScreenReader.lifecycle` limits for `commandTimeoutMs`, `captureTimeoutMs`, and `logTimeoutMs` when their environment needs a tighter budget. A timeout is an operational failure, not evidence about the product, and the run still attempts owned NVDA cleanup.

### Automated action capture

Use `captureMode: action` only with `triggerAfterDriverStart: true` and an existing declarative trigger. The harness wraps that trigger in Guidepup's `capture(action)` API and records `actionSpeech` and `actionNormalizedSpeech` separately from the cumulative transcript. Foreground browser-process binding is checked before and after the action.

Guidepup action capture closes after one second without additional speech. Use it for immediate interaction-driven output such as focus changes and status updates that occur with the action. Keep delayed announcements on the existing settle-based or manual path unless prepared-host calibration establishes repeatable behavior.

### Human-led setup

* Use a Windows host with a supported browser installed.
* Launch NVDA before opening the target surface.
* Confirm the browser is focused and that the tester understands whether the test should be executed in browse mode or focus mode.
* Record the NVDA version, browser, browser version, and the exact target URL or local test surface.

### Human-led execution

1. Review the generated plan entry and identify the surface, state, and expected user task.
2. Start from a known baseline state and perform the steps described by the plan.
3. Observe the announced role, name, state, and any focus movement or state changes.
4. Note the exact keyboard sequence used, including any AT-specific navigation or mode changes.

### Evidence and cleanup

* Capture the observed speech output, focus location, and any unexpected behavior.
* Record the result as verified pass, verified fail, or not verified.
* Close the browser and stop NVDA when the pass is complete.

### Troubleshooting and unsupported behavior

* If NVDA fails to announce the target, verify that the browser is focused and that the target is available in the current browsing context.
* If the interaction requires a mode change that the test environment cannot reproduce, record the result as not verified and note the limitation.
* If the target is not supported in the current browser or AT stack, record the limitation explicitly and avoid over-claiming.

### When the run reports that it could not stop the screen reader

The harness starts NVDA, drives it, and then confirms it has actually exited. When it cannot confirm that, it stops the whole run rather than continuing on a machine whose state it can no longer account for.

What happened:

* The harness force-terminates only a screen reader it started. A screen reader you were already running before the run began is left alone.
* Evidence collected before the failure is still written. It is marked quarantined, which means the findings are real but the run did not finish, so it is not a basis for a conformance claim.
* No further probes run.

What to do:

1. Check whether a screen reader is still running, and close it if you no longer need it.
2. If you rely on a screen reader for your own use, restart it. The harness does not restart one for you.
3. Record the affected result as not verified. An unconfirmed cleanup says nothing about the surface being tested.
4. Start a new run only after you have confirmed the state of the machine.

If Windows, Chrome, NVDA, Guidepup, or the selected NVDA asset was updated, rerun the prerequisite-only probe. Complete a recommended restart before retrying a portfolio that showed startup or multi-journey instability. Evidence from an interrupted pre-restart run remains quarantined even when an integrity-only retry passed.

## macOS + VoiceOver (out of current scope)

VoiceOver is not a current automated or manual target for this runbook. The supported real assistive-technology scope is Windows NVDA automation plus human-led Windows JAWS evidence. If VoiceOver is reintroduced as an in-scope target, restore a full macOS + VoiceOver setup and execution section and route it through the same evidence and calibration expectations described here.

## Windows + JAWS manual-only setup and execution

* JAWS remains a manual-only path for these starter mappings unless a separate automation path is explicitly approved.
* Use a Windows host with JAWS installed and launch it before interacting with the target surface.
* Record the JAWS version, browser, browser version, and the target URL or local test surface.
* Capture the exact steps performed and the output observed, because JAWS-specific sequences can differ materially from NVDA.
* Record the result as a human-led verification and do not treat it as an automated pass.

## Unsupported stacks

If the environment lacks a supported AT stack, the browser is incompatible, or the target surface cannot be reproduced reliably, record the result as not verified. Do not infer a pass or a failure from a partial or blocked environment.

## Braille, cognitive, and human-review boundaries

* Braille output and cognitive accessibility observations are out of scope for this runbook unless a qualified human reviewer explicitly requests them.
* This runbook supports evidence collection for assistive-technology interaction output, not conformance certification.
* Any conformance claim, accessibility sign-off, or public-facing attestation still requires a qualified human review and the relevant compliance workflow.

## Result vocabulary and evidence writeback

Use a separate result vocabulary for manual evidence:

* verified pass
* verified fail
* not verified
* unsupported

Do not write these results back to the automation matrix automatically. Keep them as evidence-only entries in the plan or evidence register, and let a downstream human review decide whether they should influence coverage or release gating.

## Case-specific commands remain in generated plans

The shared runbook should not embed case-specific commands, expected announcements, or per-pattern shortcuts. Keep those in the generated plan artifacts so the runbook stays stable and the plan remains the single source of truth for the specific test case.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
