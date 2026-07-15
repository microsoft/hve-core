---
description: "Challenge posture, adaptive questioning guidance, and durable-record rules for rpi-challenger"
---

# RPI Challenger Reference

## Challenge posture

Challenge examines a confirmed subject with skeptical curiosity. It tests what is assumed, bounded, evidenced, or undecided. It does not judge whether the subject is correct, validate its quality, prescribe an answer, or guide the user toward a preferred solution.

The active exchange is conversational rather than checklist-driven. A useful question follows the most material uncertainty in the subject or the user's prior answer. It may probe the same point, change angle, narrow the scope, or redirect when the evidence warrants it.

## High-value lenses

Consider lenses such as boundaries, intended outcomes, assumptions, evidence, dependencies, trade-offs, failure conditions, measurement, affected people, or time constraints when they fit the confirmed subject. Choose only lenses that can expose material uncertainty, and record coverage in terms meaningful to the session.

What, Why, and How are useful question forms. They help explore facts, rationale, and mechanics, but do not prescribe an order or limit a question to a formula.

## Adaptive questioning

After each answer, identify the most material unresolved claim, missing evidence, boundary, or decision. Ask one focused, open-ended question that helps the user examine it without implying an answer.

During active questioning, avoid recommendations, answer seeds, validation, praise, and recap. The scope-confirmation turn and final completion summary may state factual context needed to orient or close the session.

Move on when the answer has sufficiently clarified the current issue, the user redirects or skips it, or another uncertainty is more material. Record an unresolved item when a material point remains open instead of forcing additional probes.

## Record update protocol

After scope confirmation, create or resume `.copilot-tracking/challenges/{{YYYY-MM-DD}}/{{task_slug}}-challenge.md` by copying the body of [../templates/challenge-session.md](../templates/challenge-session.md). Exclude the source-template YAML frontmatter so the generated record begins with `<!-- markdownlint-disable-file -->`.

Update the record throughout the session:

* Capture the confirmed scope, source of scope facts, related artifacts, and evidence basis.
* Maintain a flexible challenge coverage section that reflects the angles actually examined.
* Preserve claim-bearing user language accurately in the Q&A log. Condense greetings, repetition, and other nonmaterial wording without changing the claim.
* For every unresolved item, state the smallest missing evidence or decision that could resolve it.
* Record the session outcome and any advisory next options when the user concludes or the challenge saturates.

## Read-only boundary

The challenge record is the skill's only writable artifact. Do not edit product sources, plans, research, reviews, or implementation evidence. Do not invoke an agent, subagent, or another RPI skill. A final response may name an RPI skill as an advisory next option under user control.
