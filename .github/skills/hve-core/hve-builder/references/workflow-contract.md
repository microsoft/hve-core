---
description: 'Mode routing, stage gates, model assignments, iteration rules, and outcome resolution for the hve-builder workflow.'
---
<!-- markdownlint-disable-file -->
# HVE Builder Workflow Contract

Use this reference to route an `hve-builder` request, dispatch the right workers, and resolve one overall outcome. The requirements catalog defines artifact quality; this contract defines control flow.

## Mode routes

Infer the narrowest mode that satisfies the request. Ask only when two plausible modes would grant materially different write authority.

| Mode       | Source write authority                                                       | Required stages                                                                | Completion intent                                                                                |
|------------|------------------------------------------------------------------------------|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| `create`   | Create the approved targets and directly required support artifacts          | route, author, static review, behavior test, validate                          | Deliver a new, usable artifact set                                                               |
| `improve`  | Edit the approved targets and directly required support artifacts            | baseline review, author, static review, behavior test, validate                | Improve behavior without changing the approved architecture unless the caller accepts the change |
| `refactor` | Edit the approved targets; preserve documented behavior                      | baseline review, author, static review, behavior test, validate                | Simplify structure while preserving the stated contract                                          |
| `replace`  | Replace approved targets after recording their intent and migration boundary | baseline intent capture, route, author, static review, behavior test, validate | Deliver a new architecture that covers the approved old intent                                   |
| `review`   | Read source artifacts; write review and test evidence only                   | static review, behavior test when runtime behavior exists                      | Return an independent quality verdict without source edits                                       |
| `validate` | Read source artifacts; write validation evidence only                        | validate                                                                       | Run the host project's mechanical checks without source edits                                    |

A behavior test is satisfied-and-skipped only when the runtime-behavior rule in the `hve-builder-tester` skill says the target or change has no behavior to exercise. Record the reason. Validation is required for every mutating mode and for `validate`; it is optional in `review` unless the caller asks for mechanical conformance evidence.

## Stage order and gates

1. Scope and route. Resolve targets, mode, requirements, write boundary, evidence root, artifact architecture, applicable repository conventions, and directly required support artifacts.
2. Establish the baseline. For `improve`, `refactor`, and `replace`, capture the current contract and static findings before edits. Skip the baseline for a target that does not yet exist; `review` performs its single static assessment in step 5.
3. Research only decision-critical unknowns. Use repository evidence first. Dispatch `Researcher Subagent` when an unresolved external or behavioral fact could change the architecture or acceptance criteria. On `Needs Clarification`, answer from approved evidence and re-dispatch; when the missing answer is decision-critical and cannot be inferred, ask the caller. If it remains unavailable, stop Blocked rather than guessing.
4. Author. For mutating modes, dispatch `HVE Artifact Author` inside the approved write boundary. A proposed type change, artifact split, or new support artifact outside that boundary returns to scope and route before edits continue.
5. Review. For mutating modes and `review`, dispatch `HVE Artifact Reviewer` in fresh context. Do not provide author reasoning or the author log; provide targets, purpose, requirements, and canonical criteria. Skip this stage for `validate`.
6. Test behavior. For mutating modes and `review`, dispatch the `hve-builder-tester` skill for behavior-bearing targets. Pass the intended reasoning profile, fidelity, isolation set, together set, and requirements. Skip this stage for `validate`.
7. Validate. For mutating modes and `validate`, dispatch `HVE Artifact Validator` after source artifacts are at their real paths. Run non-mutating host checks that apply to the changed artifact types. In `review`, run validation only when requested.
8. Resolve and iterate. Apply the outcome resolver below. Re-enter authoring only for actionable findings inside scope; return to routing for architecture changes; stop on Pass, Revise, Deferred, or Blocked.

Stages may run in parallel only when neither consumes the other's output. Discovery of unrelated candidates can run beside baseline review. Authoring, post-edit review, behavior testing, and validation remain ordered because each consumes the preceding source state.

## Worker model assignments

The HVE Builder workers intentionally pin responsibility-based profiles, so their frontmatter carries each profile's full ordered availability-fallback list and prose names the first model as primary. This suite-specific pinning does not make `model:` mandatory elsewhere. An omitted subagent model inherits the invoking parent's model; an omitted directly invoked agent or prompt model uses the current session selection.

| Worker                       | Primary model           | Profile | Why                                                                                |
|------------------------------|-------------------------|---------|------------------------------------------------------------------------------------|
| `HVE Artifact Explorer`      | GPT-5.6 Terra (copilot) | Medium  | Semantic relatedness and reuse decisions span heterogeneous artifacts              |
| `HVE Artifact Author`        | GPT-5.6 Terra (copilot) | Medium  | Architecture-aware multi-file authoring requires trade-off judgment                |
| `HVE Artifact Reviewer`      | GPT-5.6 Terra (copilot) | Medium  | Independent rubric application and severity calibration require judgment           |
| `HVE Artifact Validator`     | GPT-5.6 Luna (copilot)  | Low     | Check discovery and command execution follow a bounded mechanical protocol         |
| `HVE Artifact Test Designer` | GPT-5.6 Terra (copilot) | Medium  | Black-box scenario design requires semantic coverage analysis                      |
| `HVE Artifact Tester`        | GPT-5.6 Luna (copilot)  | Low     | Literal conformance simulation is bounded and intentionally non-interpretive       |
| `HVE Artifact Test Reviewer` | GPT-5.6 Terra (copilot) | Medium  | Behavior-evidence grading and coverage analysis require independent judgment       |
| `Researcher Subagent`        | GPT-5.6 Terra (copilot) | Medium  | Decision-critical research requires source comparison and contradiction resolution |

Canonical profile lists:

* High: `GPT-5.6 Sol (copilot)`, `Claude Opus 4.8 (copilot)`, `GPT-5.5 (copilot)`
* Medium: `GPT-5.6 Terra (copilot)`, `Claude Sonnet 5 (copilot)`, `MAI-Code-1-Flash (copilot)`
* Low: `GPT-5.6 Luna (copilot)`, `MAI-Code-1-Flash (copilot)`, `Claude Haiku 4.5 (copilot)`

The `hve-builder-tester` lead may override only `HVE Artifact Tester` from Luna to Terra when the target contract explicitly expects the Medium profile. Record the override in run state and the report. Do not override semantic workers to Luna or mechanical workers to Terra for convenience.

## Stage result vocabulary

Workers report execution separately from judgment:

* Discovery and authoring status: `Complete`, `Partial`, or `Blocked`
* Static review verdict: `Pass`, `Revise`, or `Blocked`
* Behavior review verdict: `Pass`, `Revise`, `Blocked`, or `Not available`; use `Not available` only when execution is Deferred before grading
* Behavior execution status: `Complete`, `Partial`, `Deferred`, or `Blocked`
* Mechanical validation result: `Pass`, `Fail`, or `Deferred`
* Validation display in `review` mode: `Not requested` when the caller did not request mechanical validation; this is not a validator result and does not affect the overall outcome
* Behavior gate disposition: `Executed` or `Satisfied-and-skipped`. For `Satisfied-and-skipped`, display execution status `Not run`, verdict `Not applicable`, fidelity `Not applicable`, and the no-behavior reason. These display values are not execution or review results.

`Partial` means a worker produced usable evidence but did not complete its contract. `Deferred` means a required action could not run in the current environment and names the exact rerun condition. Neither is a pass.

## Overall outcome resolver

Resolve the run once, using the first matching row from top to bottom.

| Overall outcome | Condition                                                                                                                                                                              |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Blocked`       | Scope, safety, target identity, decision-critical clarification, or required evidence is too ambiguous to proceed responsibly                                                          |
| `Deferred`      | A required stage could not run, a required behavior verdict is Not available, or discovery or behavior execution is Partial because an unavailable capability prevents completion      |
| `Revise`        | A review verdict is Revise, validation is Fail, authoring is Partial, or an actionable acceptance criterion remains unmet                                                              |
| `Pass`          | Every required stage completed or was legitimately satisfied-and-skipped, every required review verdict is Pass, validation is Pass when required, and all acceptance criteria are met |

Never convert validation failure into Pass because static prose looks correct. Never convert an unavailable stage into Pass because another stage succeeded.

## Iteration and stop rules

* Iterate only on evidence-backed findings that can change acceptance. Do not require a fixed number of ceremonial cycles.
* Re-run the affected downstream gates after each source edit. A wording-only fix still needs static review; a behavior-changing fix also needs behavior testing; every source edit needs validation.
* Stop and report Deferred when the same unresolved finding recurs without new evidence or when the caller's declared budget is exhausted. Name the finding, attempted resolution, and rerun condition.
* Stop and report Blocked before any destructive, externally visible, or out-of-scope action that lacks required approval.
* Preserve human review checkboxes. Agents leave them unchecked.

## Evidence boundary

Default durable evidence to `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/`. The parent allocates a unique `{{artifact_slug}}-{{stage}}-{{attempt}}.md` path before dispatch by scanning and incrementing the attempt suffix. Read-only workers gather evidence in memory and write their owned log once; workers that promise progressive logging must have edit capability for that log. Use plain-text workspace-relative paths inside tracking files.

> Brought to you by microsoft/hve-core
