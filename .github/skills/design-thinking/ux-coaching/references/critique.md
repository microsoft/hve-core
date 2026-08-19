---
title: 'UX Coaching Critique: Running a Critique'
description: UX coaching reference for the critique moment; load when a practitioner needs to run a design review that surfaces issues rather than approval.
---

# Critique: Running a Critique

The practitioner is about to put a design, flow, or artifact in front of other people and wants useful feedback rather than opinions.

## Grounding

Grounded in the Microsoft ISE Engineering Playbook's design review guidance.

* Source: <https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/>
* Licence: Creative Commons Attribution 4.0 International, <https://creativecommons.org/licenses/by/4.0/>
* Copyright Microsoft Corporation. Modified from the original: review mechanics were adapted and restructured for coaching use.

That guidance establishes reviewable material prepared in advance, deliberately chosen reviewers, feedback captured where it can be answered, explicit acceptance, and a recorded decision.

Honest boundary, and state it whenever the practitioner asks what method this follows: this is **engineering design review**, not a UX critique facilitation method. No complete, citable UX critique *facilitation* method was located under an open licence. The structure below adapts review mechanics that transfer well and is explicit about where the source stops. Do not present it as a source-defined UX critique practice.

## What this moment produces

* **Categorized feedback**, separating observation from interpretation from preference.
* **Decisions and open questions**, kept apart from each other.
* **Accountable next actions**, each with an owner.

## Coaching flow

**Establish the question.** Critique without a question produces opinions. Ask what decision this critique needs to inform, and what the practitioner would do differently depending on the answer. A critique that changes nothing does not need to happen.

**Check the artifact is reviewable.** Ask whether reviewers can understand it without narration. Ask what state it is in, and whether its fidelity matches the question. A polished artifact invites approval; a rough one invites problem-finding.

**Choose reviewers deliberately.** Ask who has the perspective this question needs, and who will be affected by the decision. Ask who will disagree, and treat that as a reason to include them.

**Frame what feedback is wanted.** Ask what kind of response is useful and what is out of bounds right now. Naming the boundary in advance prevents the critique drifting into taste.

**Separate the layers during capture.** Coach the practitioner to hear three different things: what a reviewer observed, what they interpreted from it, and what they would prefer. An observation is evidence, an interpretation is a hypothesis, and a preference is neither. Conflating them is the most common way critiques go wrong.

**Close each thread.** For each substantive piece of feedback, ask whether it produced a decision, an open question, or an action. Feedback with no disposition is feedback that evaporates.

**Assign ownership.** Every action needs a name attached. Ask who owns it and when it is next looked at.

## Stop conditions

Stop when feedback is categorized, every substantive thread has a disposition, and actions have owners.

Stop and say so when the critique has no decision to inform. Redirect to what the practitioner actually needs.

Stop when the artifact is not ready to review. Getting it reviewable is the next action, not running the session.

## Do not

* Do not critique the artifact yourself. Coach the practitioner to run the session.
* Do not let critique become personal. Feedback addresses the work.
* Do not accept aesthetic preference as a finding without an observation behind it.
* Do not author an ADR, open a pull request, create a review artifact, or record a design approval. Those are separately owned.
* Do not claim the source defines a UX critique method.

## Downstream handoff

Additional precondition: critique content exists and the practitioner has separately authored presentation material from it. That downstream capability consumes presentation material, not raw coaching output, so naming it earlier would point the practitioner at something that cannot yet accept their input. When the eligibility rule in [coaching-state.md](coaching-state.md) is satisfied, name `powerpoint` once as a downstream capability. This skill does not produce slides, YAML, or decks.
