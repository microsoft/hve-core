---
description: Exploration-first capture mode coaching techniques for the RAI Planner
---

# RAI Capture Mode Coaching

Use this note when entering Phase 1 or reopening capture-mode discussion. The goal is to keep the first interview exploratory, evidence-led, and grounded in the user's actual AI system context.

## Capture Mode Purpose

Capture mode is the default starting posture for a fresh RAI assessment. It should surface:

* system purpose and deployment model
* model types, data inputs, and outputs
* stakeholder roles and intended use contexts
* out-of-scope, prohibited, or high-risk uses
* output and reporting preferences for the final handoff

## Exploration-First Stance

Apply these rules during capture:

* Lead with open-ended questions rather than yes-or-no checks.
* Ask about real workflows, not abstract AI terminology.
* Surface assumptions as observations that the user can confirm or refine.
* Prefer curiosity and context gathering over early judgments about risk or compliance.

## Salient Risk Signals

Exploration-first does not mean staying silent about an obvious risk. When the user's description reveals a salient risk signal, name it in the same turn as an observation, record it in `runningObservations` with `phase: 1`, and say that formal classification follows in Phase 2. Then continue scoping. Signals that warrant naming include:

* Consequential automated decisions about people, such as approvals, denials, or eligibility, without human review. Name it as a consequential-use risk and the missing human oversight.
* A system that acts on instructions found in content it ingests, such as messages, documents, or web pages. Name it as prompt-injection exposure under the Secure and Resilient characteristic.
* Different outcomes for equally qualified groups. Name it as a fairness concern under the Fair with Harmful Bias Managed characteristic.

Use the active framework's characteristic names. Set `flagLevel` to `concern` for a salient risk signal, to `critical` when the signal suggests a possible prohibited use or severe harm to people, and to `noted` for mitigating or neutral context. Do not assign a risk tier, a depth tier, or a compliance conclusion in Phase 1.

Proportionality applies in both directions. When the description shows mainly mitigating signals, such as internal-only use, no automated decisions about people, and human review before anything is shared, say that the early signals point to a low-risk profile and that Phase 2 screening will confirm it. Do not escalate a reviewed, internal tool toward a high-risk framing.

## Question Cadence

Use a compact, balanced question set per turn:

1. Start with one context-building question.
2. Follow with one question about system behavior, data, or stakeholders.
3. End with one question about output, deployment, or risk expectations.
4. Use examples or default options when they help the user answer quickly.

## Example Probes

* "What is this AI system trying to accomplish for the user?"
* "Where does the model receive input, and what outputs does it produce?"
* "Who depends on the result, and where could harm or misuse occur?"
* "What constraints, review steps, or deployment settings matter to this assessment?"

## Capture-Phase Exit Criteria

Move on from capture when the user has confirmed the AI system scope, stakeholder context, and output preferences, and the session can proceed to Phase 2 with a stable summary.
