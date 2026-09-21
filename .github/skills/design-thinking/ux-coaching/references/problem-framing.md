---
title: 'UX Coaching Problem Framing: Deciding What the Problem Actually Is'
description: UX coaching reference for the problem-framing moment; load when a practitioner needs to establish what problem they are solving before design begins.
---

# Problem Framing: Deciding What the Problem Actually Is

The practitioner has a task, often already shaped as a solution, and needs to know what problem they are actually solving before anyone builds anything.

## Grounding

Grounded in GOV.UK Service Manual discovery guidance and the UK Government Digital, Data and Technology (DDaT) capability framework's evidence-based design expectations.

* Source: <https://www.gov.uk/service-manual/agile-delivery/how-the-discovery-phase-works>
* Source: <https://www.gov.uk/government/collections/digital-data-and-technology-profession-capability-framework>
* Licence: Open Government Licence v3.0, <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>
* Contains public sector information licensed under the OGL v3.0. Adapted for coaching use; wording and structure are not the originals.

That guidance directs teams to interrogate a proposed solution before accepting it, to understand how people currently get the job done, and to express what they need in their own terms. Its named outputs are a picture of the current experience and sets of user needs.

Honest boundary: the source names discovery activities and their outputs. It does not prescribe a single combined "problem statement" artifact. This moment therefore produces three connected components rather than one source-prescribed document, and says so when the practitioner asks what the method requires.

## What this moment produces

Three components that together constitute the framing. Each is separately observable, and the practitioner can stop with fewer than three as long as the gaps are named.

1. **Current experience.** How the job gets done today: who is involved, in what context, and where it breaks down. Describe it in prose or a simple sequence, or reference an existing map by location.
2. **User needs.** What people are trying to achieve, expressed as needs rather than features, each labelled with its evidence and source.
3. **Assumptions and boundaries.** What is being taken on faith, what is deliberately out of scope, and which questions remain open.

## Coaching flow

Adapt the order to the practitioner. This is what to explore, not a script.

**Start where they are.** When they arrive with a proposed solution, take it seriously before examining it. Ask what problem they expect it to solve and what made them reach for it. A solution someone already believes in is evidence about the problem, even when the solution is wrong.

**Get to the current experience.** Ask how the job is done today, without the proposed thing. Ask where it goes wrong, and what people do to work around it. Workarounds are the highest-signal thing here: people build them only around real friction.

**Separate needs from features.** When the practitioner says users need a dashboard, ask what the dashboard would let someone do, and what happens now when they cannot. Keep going until the need stands on its own without naming a solution.

**Label the evidence.** For each need, ask how they know. Direct observation, a support ticket, analytics, a stakeholder's belief, and an assumption are different things and belong in different places. Record them as what they are, and state each at its real strength rather than the strength the practitioner hopes for. Three complaints are three complaints, not a pattern.

**Find the boundary.** Ask what is deliberately not in scope, and what would have to be true for this framing to be wrong.

**Surface what is unresolved.** End by asking what they still do not know, and which unknown would most change the framing if answered.

## Stop conditions

Stop when the three components exist and the practitioner can state the problem in their own words without naming a solution.

Stop and say so when there is no evidence about the current experience. "We need research before we can frame this" is a real, useful outcome. Do not coach toward a confident framing built on assumptions.

Stop before ideation. When the practitioner starts generating solutions, note it and offer the choice: capture the idea and return to framing, or accept that framing is done.

## Do not

* Do not propose the solution, or evaluate a proposed one on its merits.
* Do not write requirements, user stories, or acceptance criteria.
* Do not author a journey map, persona, or research plan as a formatted deliverable.
* Do not let an assumption enter the needs set unlabelled.

## Downstream handoff

Additional precondition: an approved problem statement already exists for this project at a known location and was produced separately from this skill. The three components produced here do not satisfy the customer-card renderer's input schema on their own, because that renderer expects inputs this skill does not produce.

When the eligibility rule in [coaching-state.md](coaching-state.md) is satisfied, name `customer-card-render` once as a capability the practitioner could use next. Do not generate YAML, invoke a renderer, or select a deck format. When not eligible, say nothing about rendering.
