---
title: "UX artifact mode: Frame needs"
description: Produce a source-labelled current-context and user-needs asset from supplied evidence without conducting coaching or user research.
---

# Frame needs

Use this mode when the practitioner already has context or evidence and needs a durable statement of user needs. Use the problem-framing moment in `ux-coaching` instead when they need help deciding what the problem actually is.

## Inputs

* Supplied evidence or an explicit `source`
* Users or roles represented by that evidence
* Current context and trigger, when known
* Desired outcome, when known
* Incumbent approach or workaround, when known

## Output body

After the common evidence sections from [evidence-model.md](evidence-model.md), write:

```markdown
## Current Context

<Who is in what situation, based only on supplied evidence.>

## User Needs

### Need 1

* Context: <trigger or circumstance>
* Need: <what the person needs to accomplish without naming a feature>
* Outcome: <why the result matters>
* Basis: Observed | Reported | Assumed
* Source: <source pointer or description>

## Current Approach and Workarounds

<What happens today and any workaround, or Unknown.>

## Boundaries

* In scope: <current boundary>
* Out of scope: <current boundary>
```

## User-need form and attribution

Use the GOV.UK Service Manual's situation, motivation, and outcome shape in adapted prose. This reference adapts public sector information licensed under the Open Government Licence v3.0:

* Source: <https://www.gov.uk/service-manual/user-research/start-by-learning-user-needs>
* Licence: <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>
* Adaptation: The labels and asset structure are rewritten for this repository's evidence contract.

Do not call the form JTBD, a job story, or an implementation of any JTBD school. Research found no verified reuse grant for the job-story template.

## Completion conditions

* Every need names context, need, outcome, basis, and source.
* Feature requests are translated only when supplied evidence supports the underlying need.
* Unsupported needs remain assumed or unresolved.
* The output does not claim that interviews, observation, or testing occurred.

## Stop conditions

Stop with a partial asset when no source supports a claimed need. Name the missing evidence rather than conducting a coaching sequence or inventing a user.
