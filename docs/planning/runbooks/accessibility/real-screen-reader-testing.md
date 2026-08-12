---
title: Real screen reader testing
description: Shared guidance for human-led real assistive technology testing, evidence capture, and release gating.
author: Microsoft
ms.date: 2026-07-16
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

### Setup

* Use a Windows host with a supported browser installed.
* Launch NVDA before opening the target surface.
* Confirm the browser is focused and that the tester understands whether the test should be executed in browse mode or focus mode.
* Record the NVDA version, browser, browser version, and the exact target URL or local test surface.

### Execution

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
