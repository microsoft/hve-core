---
title: Evaluation interview and sample review
description: Scoping interview areas, difficulty distribution defaults and adjustment rules, and the representative sample review protocol for AI evaluation datasets
---

## Interview posture

Ask one question at a time and wait for the answer. A batched interview produces shallow answers, and the later questions depend on the earlier ones. Record an explicit unknown rather than filling a gap with a plausible assumption; an assumed scope becomes a wrong expected answer in every pair that inherits it.

## Interview areas

### System context

* What is the system called? If it has no name, agree on one, because the artifacts are named from it.
* What business problem or scenario does it address?
* Which business outcomes is it meant to move?
* What tasks is it designed to perform, and what is explicitly out of scope?
* What risks does deploying it carry, including exposure of personal data and the consequences of a confidently wrong answer? Each named risk must later map to a detecting metric or remain explicitly unmeasured.
* Who are its primary users? Name each distinct user population, not only job titles, because population coverage is recorded independently from difficulty balance. Confirm the resulting list explicitly; it becomes `metadata.user_populations`, and every pair's populations are drawn from it.
* How readily will those users adopt it, and what stands in the way?

### Capabilities

* Does it draw on grounding sources such as documents, knowledge bases, or APIs? Which ones?
* How reliable, complete, and current are those sources? Is their quality sufficient for what users will expect?
* Does it call tools or external services to complete tasks? Which ones?
* What response shape is expected: a direct answer, step-by-step guidance, structured data, or something else?

### Scenarios

* Describe several representative situations where the system should succeed.
* Which situations are ambiguous, adversarial, or otherwise difficult?
* What should it refuse or redirect, and what specific action should it take instead: decline, hand off to a person, or point to another resource?
* What limitations should it state plainly rather than working around?
* Are there topics it must never produce content about, regardless of how a request is phrased?

### Approach and cadence

* Is the team building low-code or pro-code?
* Is evaluation manual, batch, or both, and how often does it run?

### Confirmation

Present a structured summary organized by the areas above, then ask whether it captures the system accurately and what should be corrected. Do not generate the dataset until this is confirmed.

## Size and distribution

A dataset below roughly thirty pairs cannot separate a real regression from noise once it is split across categories. Treat thirty as the floor, not the target.

Default balance:

| Category           | Default share | What it establishes                                                  |
|--------------------|---------------|----------------------------------------------------------------------|
| Easy               | 20%           | The system handles its core job                                      |
| Grounding checks   | 10%           | Answers trace to sources rather than to the model's memory           |
| Hard               | 40%           | Behavior under ambiguity, multi-step requests, and edge conditions   |
| Negative and error | 20%           | Correct behavior when it should decline, redirect, or report failure |
| Safety             | 10%           | Prohibited content stays refused under rephrasing                    |

Adjustment rules:

* Raise the safety share when the system touches personal, health, financial, or legal matters.
* Raise the grounding share when it draws on many sources or sources of uneven quality.
* Raise the negative share when refusal behavior is a primary requirement.
* Keep every category at or above five percent. A category at zero is an untested claim.
* When rounding fractional counts, preserve the declared total so the recorded distribution matches the actual rows.

Distribute pairs across every confirmed user population as well as categories. Record each pair's populations in its `populations` array and the per-population pair counts in `metadata.population_coverage`. Population is an independent coverage axis, never a sixth `difficulty` value or a `distribution` key.

A pair may serve several confirmed populations. List all of them rather than choosing one, because a request that two populations phrase identically is evidence about both. An empty list means the pair is not specific to any population. Because pairs overlap, the population counts do not sum to `total_pairs`, and every confirmed population gets a count even when that count is zero. A zero is the point: it shows that a population was confirmed and left untested, which a missing entry would hide. A dataset that only reflects the most fluent user overstates readiness.

## Writing pairs

* State the expected response as observable behavior, not as exact wording, unless the wording itself is the requirement.
* For refusal pairs, assert the specific action expected. "Declines" is weaker than "declines and directs the user to a human agent."
* For grounding pairs, name the source the answer should rest on so a reviewer can verify it.
* For tool-using systems, record which tools the request should invoke.
* Vary phrasing, verbosity, and formality within a category. Uniformly well-formed questions measure a narrower system than the one that ships.
* Note any pair whose expected answer needs subject-matter confirmation rather than asserting it.

## Sample review

Before finalizing, walk the user through five to eight pairs spanning the categories: one or two easy, one or two hard, one grounding check, one negative, and one safety. Present each pair's request, expected behavior, populations, and expected tools.

The populations belong in the sample because nobody else checks them. They are inferred during generation, and this review is the only point where a person who knows the users can say that a pair was attributed to the wrong population or is missing one. When the dataset contains them, include at least one pair serving several populations and one pair with no populations, so the reviewer sees both cases. Also show the per-population counts, including any zero, so an untested population surfaces while it can still be corrected.

Ask for consolidated feedback in one pass: which pairs need changing, what is missing across the set, and whether the detail level is right. Revise the identified pairs, apply the same correction to comparable pairs elsewhere in the set, and offer to regenerate a category when the feedback indicates a systematic problem rather than an isolated one. Recompute the population counts after any revision that changes a pair's populations.

Confirm satisfaction before finalizing the full dataset and the evaluation guide.
