---
description: "Reference protocol for splitting an RPI plan critique into parallel lens assessments, selecting each lens's reasoning effort, and merging the returns into one finding set."
---

# Lens Assessment Reference

## Lenses

| Lens           | Question                                                                                                                                                                                            | Reads                                                      | Default effort |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------|----------------|
| Coverage       | Do the tasks cover every requirement, goal, and acceptance condition, with task `Requirements:` a reader can check?                                                                                 | Plan requirement lists and every task; requirement sources | `low`          |
| Evidence       | Are the plan's claims, decisions, `Details:`, and `References:` supported by the supplied research and evidence?                                                                                    | Plan; research and evidence                                | `medium`       |
| Executability  | Can each phase run as written, including dependencies and order, tools and environments, checks that can fail, and budgets?                                                                         | Plan; evidence about tools and environments                | `medium`       |
| Risk           | Are material risks, side effects, and irreversible, shared-system, or externally visible actions handled, are user decisions identified, and what material concern does the plan leave unaddressed? | Plan; risk-relevant evidence                               | `medium`       |
| Reconciliation | Is each earlier finding resolved, still open, or superseded, and did the corrections introduce regressions?                                                                                         | Plan; earlier critique                                     | `low`          |

Run Coverage, Evidence, Executability, and Risk for an initial critique. For a follow-up critique, run Reconciliation and only the lenses whose subject the corrections changed, scoped to the changed text. When Evidence, Executability, or Risk would cover a long plan, split it by phase range rather than raising its effort, so each assignment finishes quickly. Keep Coverage whole, because it must see every task.

## Reasoning effort

Select each lens's reasoning effort when you dispatch it. Agent frontmatter does not set it: `RPI Plan Critic` declares a model and no effort so that the effort follows the lens's work.

* When the user or caller sets an effort, use it, either one level for every lens or the named level for each named lens.
* Otherwise use each lens's default effort in `standard` depth, and lower a lens to `low` when its scope is small. For `deep` depth, raise each lens one level, up to `high`. Use `xhigh` or `max` only when the user or caller asks for them.
* Pass the level through the dispatch tool's reasoning-effort parameter, such as `reasoning_effort`. When the tool has no such parameter, dispatch without one and record the effort as host default.
* If a dispatch fails because its model does not support the selected effort, retry it once with `reasoning_effort` set to `medium`.
* Record each lens's effort and its source (selected, caller-set, or host default) in Lens Assessments.

## Dispatch

Fill in this assignment for each lens, then send every dispatch to `RPI Plan Critic` in one parallel batch before reading any return:

```text
Lens: <name>. <question from the Lenses table>
Plan: <plan path>; scope: <phases, tasks, or sections>
Evidence: <paths the lens reads; for Reconciliation, the earlier critique path>
Confirmed direction: the plan's User Decisions and Requirements section, plus <caller-supplied decisions, or none>
Depth: <standard or deep>
Severity scale: <the four definitions from Severity scale>
```

`RPI Plan Critic` defines its own reading limits and return format, so the assignment does not restate them. Leave out any list of suspected weaknesses and your own observations. The lens question and the severity scale are the whole brief, so each critic assesses the plan instead of confirming the parent's view.

`RPI Plan Critic` runs on the model its frontmatter declares; pass a different model only when the user names one. When `RPI Plan Critic` is unavailable, give a general-purpose subagent the same assignment at the same effort. Tell it to read only the plan and evidence the assignment supplies, change no files, run no validation, and dispatch no other agents. Ask it to return `Complete`, `Partial`, `Blocked`, or `Needs clarification` and, for each candidate, the location, a short quote, what it was checked against, the concern, a suggested severity, the smallest useful change, and its confidence.

## Severity scale

Rate each finding by its consequence for how this plan will actually run, such as a supervised test or a production change.

* Critical: the plan cannot be implemented as written, or implementing it would cause harm or irreversible damage.
* High: implementation would likely fail, miss an acceptance criterion, or cause an unintended side effect.
* Medium: likely rework, or an unsupported claim or gap that would change a decision.
* Low: a demonstrated minor error, such as a wrong count or citation. In `standard` depth, record a Low finding only for a demonstrated error, not for a possible improvement.

## Merge the returns

1. Read every return, and treat each concern under Outside the lens as a candidate too. Verify each candidate by finding its quote at the cited location, and check the named evidence there when the concern depends on it. Do not reassess the plan beyond the candidates.
2. Merge duplicates across lenses into one finding keyed to the earliest affected ID.
3. Record a `PC-xxx` finding only for a verified candidate, with its final severity from the scale. Reject a candidate that the cited evidence contradicts or that confirmed user direction resolves, and note the reason in Lens Assessments.
4. When a lens returns `Partial`, `Blocked`, `Needs clarification`, or nothing, cover the gap yourself when it is small; otherwise record the unassessed boundary and set critique execution to Partial.
5. Do not dispatch a second round of lenses for the same critique.
