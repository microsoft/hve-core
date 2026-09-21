---
title: Experiment readiness
description: Turning a risk landscape into experiment candidates, prioritizing among competing unknowns, comparing options with evidence, and re-prioritizing mid-flight as findings arrive
---

## Sources

* Microsoft CSE Code-with-Engineering-Playbook, [Engineering Feasibility Spikes](https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/recipes/engineering-feasibility-spikes/), documentation licensed CC BY 4.0.
* Microsoft CSE Code-with-Engineering-Playbook, [Trade Studies](https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/trade-studies/), documentation licensed CC BY 4.0.

Content below is HVE Core guidance informed by those two pages and has been changed: the upstream practices are generalized beyond engagement-shaped engineering work, restructured around this pack's coaching flow, and stated in this repository's vocabulary. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires. Upstream terminology is named where it helps a reader find the source discussion.

## Read this when

The rest of this pack assumes an experiment has already been proposed. Read this file for the two steps on either side of that assumption: deciding which experiment to run at all, and deciding what to run next once results start arriving.

## Generating candidates from risk

Teams often arrive with one experiment already in mind, which is usually the idea someone found most interesting rather than the unknown that carries the most risk. Surfacing the risk landscape first produces a candidate list the team can choose from.

Run a structured failure exercise before selecting anything. Upstream calls this a pre-mortem: gather the people who will do the work, and ask them to imagine the effort has already failed and to name what caused it. The framing matters. Asking "what could go wrong" invites polite hedging; asking people to explain a failure that has already happened surfaces the concerns they were reluctant to raise.

Convert the output into candidates:

1. Collect the named causes without debating them. Both technical and business causes count.
2. Discard causes that are already decided, already measured, or outside the team's control.
3. For each remaining cause, ask what could be learned that would make the failure less likely. That learning is the candidate experiment.
4. Keep the cause attached to the candidate. An experiment that has lost its originating risk cannot be prioritized against anything.

Include the customer or partner team when the engagement allows it. Concerns that only they hold are exactly the ones the delivery team cannot generate alone.

## Prioritizing among candidates

A candidate list is longer than the available time, so selection is the real decision. Rank by how much a result would change what the team does next:

| Signal                     | Favors running it sooner                                             |
|----------------------------|----------------------------------------------------------------------|
| Consequence of being wrong | A wrong assumption here invalidates work already underway or planned |
| Decision blocked           | A concrete downstream decision cannot be made until this resolves    |
| Cost of late discovery     | Finding out later means rework rather than a change of plan          |
| Cheapness of learning      | A usable answer is reachable within the experiment's time box        |

Prefer the unknown whose resolution changes the most downstream work. An experiment that confirms something the team would have done anyway is a demo, which the vetting criteria in [mve-coaching.md](mve-coaching.md) already treat as a red flag.

## Comparing competing options with evidence

Some unknowns are not "does this work" but "which of these should we use". That is a comparison, and it warrants its own structure. Upstream calls this a trade study, adapted from systems engineering.

Run one only when the choice is genuinely open. When a clear answer already exists, record the decision and move on; a comparison that exists to justify a decision already made consumes time and produces no learning.

When a comparison is warranted:

1. Agree the requirements with whoever owns the decision, before looking at options.
2. Turn those requirements into evaluation criteria that can actually be measured or observed. Abstract requirements become undecidable comparisons.
3. Gather possible options, then narrow to a small number worth real investigation. Investigating everything shallowly produces a table nobody trusts.
4. Time box the research per option. Depth on a favored option and a glance at the others is the most common way a comparison becomes a rationalization.
5. Compare against the criteria and decide with the team. If the team cannot decide, name what additional evidence would settle it and who will get it, rather than deferring indefinitely.

Record the criteria alongside the result. When requirements change later, the recorded criteria show whether the decision still holds without repeating the work.

## Re-prioritizing while experiments are in flight

A sequence of experiments is not a plan to be executed in order. Each result changes what is worth learning next, and the value of a finding decays if it sits with one person until the work is done.

Share findings on a short recurring cadence rather than at completion. Upstream runs a brief session on a weekly or tighter rhythm, with everyone attending whether or not their own work is finished, precisely because a partial finding often changes someone else's next step.

Re-select after each share rather than continuing down the original list:

* Promote a candidate whose risk a finding just made more likely.
* Drop a candidate whose risk a finding just eliminated.
* Stop an in-flight experiment whose original success criteria a finding has invalidated, and say so explicitly rather than finishing it out of momentum.

Record what changed and why. Without that, a re-prioritized sequence is indistinguishable from an unplanned one.

## Related guidance

Vetting criteria, red flags, hypothesis format, design practices, and results evaluation are in [mve-coaching.md](mve-coaching.md). This file feeds that flow and does not repeat it.
