---
description: 'Power/Interest grid for stakeholder engagement, originally proposed by Aubrey L. Mendelow (1991) - presented as a 2x2 quadrant table with original HVE-Core engagement captions used by the BRD Builder'
---

# Mendelow Power/Interest Grid

The Power/Interest grid is a two-axis matrix that classifies each stakeholder by their `power` to affect a business initiative and their `interest` in its outcome, producing four engagement quadrants.
The grid is originally attributed to Aubrey L. Mendelow's 1991 conference paper (see [Origin and Citation](#origin-and-citation)).
The grid concept itself is a generic stakeholder-analysis construct; the per-quadrant captions and action guidance below are original Microsoft content and are the strings the BRD Builder emits.

## Axes

The BRD Builder evaluates each stakeholder on two ordinal axes:

* **Power** - the stakeholder's capacity to grant or withhold resources, approvals, or authority that the initiative depends on. Recorded as `low` or `high` for grid placement; finer gradations are captured in interview notes.
* **Interest** - the stakeholder's stake in or attention to the initiative's outcome, independent of their power. Recorded as `low` or `high` for grid placement.

The two axes are evaluated for the current state. Both can change across the BRD cycle (for example, a `Hidden` cohort can move to `Manage Closely` once the initiative becomes visible), so the grid is revisited at each Define-phase milestone.

## Quadrant Table

The quadrants are labeled by the joint axis state. Each row carries an original HVE-Core caption (one-line action guidance) and the BRD Builder's default engagement cadence.

| Quadrant       | Power | Interest | HVE-Core caption                                                                    | Default engagement cadence                                                  |
|----------------|-------|----------|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Manage Closely | High  | High     | Bring them into the room - their authority and attention shape every decision.      | Direct interview in Discover; named reviewer in Define; sign-off in Govern. |
| Keep Satisfied | High  | Low      | Brief them on outcomes - their authority can block or unblock when they engage.     | Summary brief in Define; surfaced for sign-off only on items they control.  |
| Keep Informed  | Low   | High     | Loop them in - their interest is real evidence and their voice strengthens the BRD. | Group interview or async input in Discover; review window in Define.        |
| Monitor        | Low   | Low      | Watch for shifts - low priority today, but movement either way changes the plan.    | No active engagement; revisit placement at each Define-phase milestone.     |

The four captions in the table above are original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## How the BRD Builder Uses the Grid

* During Discover, every identified stakeholder (Primary / Secondary / Hidden tier) is placed in exactly one quadrant. Placement is recorded with a one-line rationale citing the evidence for the power and interest ratings.
* `Manage Closely` and `Keep Informed` quadrants drive interview scheduling and review-list composition.
* `Keep Satisfied` quadrant drives sign-off authority lists for the Govern phase.
* `Monitor` quadrant entries are kept on the roster but excluded from active engagement until a milestone revisit moves them.
* The grid is re-evaluated at the Define-phase exit gate; any stakeholder whose quadrant has changed since Discover is flagged for re-engagement before Govern begins.

## Pitfalls

* Conflating role seniority with power. Power is initiative-specific; a senior executive in an unrelated org has low power over this BRD.
* Treating interest as fixed. Interest changes as the initiative becomes visible; the grid is revisited each milestone.
* Leaving a high-power stakeholder in `Monitor` because they are quiet. The `Hidden` tier (high power, currently low visible interest) belongs in `Keep Satisfied` until evidence justifies a move.
* Using the grid as a substitute for accountability assignment. The grid sets engagement cadence; accountability is owned by the [RACI patterns reference](raci-patterns.md).

## Origin and Citation

The Power/Interest grid is attributed to:

* Mendelow, A. L. (1991). *Environmental Scanning - The Impact of the Stakeholder Concept*. Proceedings of the Second International Conference on Information Systems (ICIS 1991), Cambridge, Massachusetts. [https://aisel.aisnet.org/icis1981/20/](https://aisel.aisnet.org/icis1981/20/) (accessed 2026-05-25)

The 2x2 grid construct has since been widely reproduced across the business-analysis, project-management, and corporate-strategy literatures as a generic stakeholder-analysis tool. The BRD Builder uses the grid concept on those generic grounds and adds original HVE-Core captions on top.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The 2x2 Power/Interest construct is treated as a generic stakeholder-analysis pattern; the cited conference paper is the property of its author and the publisher of the proceedings.


