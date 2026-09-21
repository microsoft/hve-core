---
description: "Human-in-the-loop contract for TM7 threat-model generation and the native Windows TMT feedback loop"
applyTo: '.github/agents/security/security-planner.agent.md, .github/agents/security/security-reviewer.agent.md'
---

# TM7 Generation Workflow

This file owns the human-in-the-loop contract that every agent invoking TM7 generation or the native Threat Modeling Tool feedback loop must follow. It defines confirmation and operator-safety behavior only; entry points, flags, and output mechanics belong to the security-planning skill.

## Authorship confirmation

When the user requests a TM7 threat-model draft, refresh, or update, the agent may run the `generate_tm7.py` generator to produce the `.tm7` and markdown outputs. That permission covers generation only. It never extends to the `validate_tm7_with_tmt.py --feedback-loop` harness, which drives the native UI and requires the operator-safety confirmation below even though the loop replays through the same generator.

Before treating any generated output as authored or final, the agent must present the input spec and the generated result to the user, say: "I have prepared the proposed specification and generated output below for your review. Please confirm explicitly before I treat it as authored or final.", and then wait for that confirmation.

Until confirmation arrives, the generated model is unconfirmed. The agent does not record it as a phase artifact, does not advance a phase gate on it, and does not hand it off to backlog, review, or another agent. A missing, ambiguous, or declined response leaves it unconfirmed; the agent reports the model as awaiting confirmation rather than inferring approval from silence.

The agent keeps the human in the loop for the spec, the generated model, and any merge or update changes, and it does not author decisions on the user's behalf.

## Native feedback-loop operator safety

The native feedback loop drives real TMT UI controls and takes over the mouse and keyboard, so an operator who is unaware of it can corrupt the run or lose work in another window.

Before invoking the native Windows-local TMT feedback loop, the agent must ask the user how many refinement rounds to run. The agent must then tell the user that one run holds the mouse and keyboard continuously, from the start notice through the baseline and every refinement iteration until the release notice; control does not return between iterations. The agent must also tell the user that if the visual review produces corrections, replaying them is a new run and a new takeover that requires fresh confirmation, so more than one takeover is expected.

The agent must also tell the user that the harness will drive TMT UI controls and that the operator must not use the mouse, keyboard, switch windows, or interact with TMT until the completion notice appears.

The agent must then wait for the user to confirm that the desktop is clear and the takeover may begin. Notifying and launching in the same turn does not satisfy this rule, because it gives the operator no opportunity to save work or clear the screen. The harness emits a start notice but does not itself block on the operator, so this gate exists only in agent behavior. Without explicit confirmation the agent does not invoke the native loop, and it never launches native UI automation silently.

After the command returns or aborts, the agent must explicitly tell the user that automation has stopped and control of the computer is returned.

After each run completes, the agent must perform the agent-assisted visual review described in the security-planning skill. Performing that review is required, not advisory, and a passing automated gate does not substitute for it.

## Layout overlay promotion

Layout overlays produced by the feedback loop are emitted in `approval_state: pending`. A visual score is advisory evidence, not an approval. The agent does not promote a layout overlay, and does not describe a passing automated gate as a completed review; promotion is an explicit human action outside the loop.
