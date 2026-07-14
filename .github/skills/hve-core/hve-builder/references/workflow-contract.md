---
description: 'Mode routing, stage gates, profile selection, iteration rules, and outcome resolution for the hve-builder workflow.'
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

The behavior gate is satisfied-and-skipped for every minor or medium change. This includes all frontmatter-only changes and reference-only changes that update an agent, subagent, or skill name. Major changes alone dispatch `hve-builder-tester`. Record the required skip fields and reason. Validation is required for every mutating mode and for `validate`; it is optional in `review` unless the caller asks for mechanical conformance evidence.

## Stage order and gates

1. Scope and route. Resolve targets, mode, requirements, write boundary, evidence root, artifact architecture, applicable repository conventions, and directly required support artifacts. Intake may classify caller-provided facts, known targets, and already-supplied extension metadata without research. Do not run an open-ended codebase scan at intake; route a need for one through step 3.
2. Establish the baseline. For `improve`, `refactor`, and `replace`, capture the current contract and static findings before edits. Read only already-known target files, supplied criteria, and required canonical references. These bounded lifecycle-stage reads are not codebase exploration. Skip the baseline for a target that does not yet exist; `review` performs its single static assessment in step 5.
3. Research and explore only when needed. When non-obvious reuse discovery, an extension survey that requires a codebase scan, another open-ended workspace exploration, or an unresolved decision-critical internal, external, or hybrid question could change architecture or acceptance criteria, route it through the sole `rpi-research` bridge in `stage-dispatch.md`. Apply that bridge's return and unavailable-entrypoint rules. On `Needs clarification`, use approved evidence or ask the caller; when the missing answer is decision-critical and cannot be inferred, stop Blocked rather than guessing. Do not substitute a direct worker route or local research contract.
4. Author. For mutating modes, dispatch a generic Medium-profile authoring subagent using `stage-dispatch.md` inside the approved write boundary. It performs bounded reads of approved target files and supplied canonical references. A proposed type change, artifact split, new support artifact outside that boundary, or newly required exploration returns to scope and route before edits continue.
5. Review. For mutating modes and `review`, dispatch a generic Medium-profile static-review subagent in fresh context. Do not provide author reasoning or the author log; provide known target files, purpose, requirements, and canonical criteria. Its bounded reads are lifecycle-stage work, not exploration. Skip this stage for `validate`.
6. Test behavior. Classify every changed target before testing. For minor and medium changes, record a satisfied-and-skipped behavior gate. For major changes only, dispatch the `hve-builder-tester` skill with the intended reasoning profile, fidelity, isolation set, together set, and requirements. Skip this stage for `validate`.
7. Validate. For mutating modes and `validate`, dispatch a generic Low-profile validation subagent using `stage-dispatch.md` after source artifacts are at their real paths. Use caller-named or already-known applicable non-mutating checks and bounded target-file reads. In `review`, run validation only when requested.
8. Resolve and iterate. Apply the outcome resolver below. Re-enter authoring only for actionable findings inside scope; return to routing for architecture changes; stop on Pass, Revise, Deferred, or Blocked.

Stages may run in parallel only when neither consumes the other's output. An independent `rpi-research` handoff can run beside baseline review only when it cannot change the baseline target set. Authoring, post-edit review, behavior testing, and validation remain ordered because each consumes the preceding source state.

## Stage model selection

The lifecycle uses generic subagent dispatches with a model selected at invocation time rather than named worker frontmatter. `stage-dispatch.md` defines the prompt and evidence contract. This keeps the stage isolated while allowing the parent to select a responsibility-appropriate profile.

| Stage                   | Profile | Why                                                                             |
|-------------------------|---------|---------------------------------------------------------------------------------|
| Authoring, review       | Medium  | Architecture, authoring, and calibrated review require judgment                 |
| Validation              | Low     | Known-check execution follows a bounded mechanical protocol                     |
| Test design and grading | Medium  | Coverage and evidence grading require semantic judgment                         |
| `HVE Artifact Tester`   | Low     | Literal conformance simulation is bounded and intentionally non-interpretive    |

Canonical profile lists:

* High: `GPT-5.6 Sol (copilot)`, `Claude Opus 4.8 (copilot)`, `GPT-5.5 (copilot)`
* Medium: `GPT-5.6 Terra (copilot)`, `Claude Sonnet 5 (copilot)`, `MAI-Code-1-Flash (copilot)`
* Low: `GPT-5.6 Luna (copilot)`, `MAI-Code-1-Flash (copilot)`, `Claude Haiku 4.5 (copilot)`

After selecting the responsibility-appropriate profile, choose the first model from its canonical ordered list that appears in the user's available model list. The `hve-builder-tester` lead may select the Medium profile for `HVE Artifact Tester` only when the target contract explicitly expects Medium. Record the profile override in run state and the report; do not raise or lower a profile merely for convenience.

## Stage result vocabulary

Workers report execution separately from judgment:

* Authoring status: `Complete`, `Partial`, or `Blocked`
* Research and exploration status: consume the execution status returned by `rpi-research`; when activation cannot run because it is unavailable, record `Deferred` with the run-specific rerun condition.
* Static review verdict: `Pass`, `Revise`, or `Blocked`
* Behavior review verdict: `Pass`, `Revise`, `Blocked`, or `Not available`; use `Not available` only when execution is Deferred before grading
* Behavior execution status: `Complete`, `Partial`, `Deferred`, or `Blocked`
* Mechanical validation result: `Pass`, `Fail`, or `Deferred`
* Validation display in `review` mode: `Not requested` when the caller did not request mechanical validation; this is not a validator result and does not affect the overall outcome
* Behavior gate disposition: `Executed` or `Satisfied-and-skipped`. For `Satisfied-and-skipped`, display execution status `Not run`, verdict `Not applicable`, fidelity `Not applicable`, and the no-behavior reason. These display values are not execution or review results.

`Partial` means a worker produced usable evidence but did not complete its contract. `Deferred` means a required action could not run in the current environment and names the exact rerun condition. Neither is a pass.

## Change classification

Classify the requested source delta before the behavior gate. When mixed changes exist, use the highest applicable class.

| Class  | Decision rule                                                                                                                           | Behavior gate                         |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| Minor  | Editorial, formatting, frontmatter-only, comments, link repairs, or an agent, subagent, or skill name-reference update with no rule change | Satisfied-and-skipped                 |
| Medium | Clarifies, reorganizes, or adjusts existing workflow text without adding, removing, or materially changing a model action or output    | Satisfied-and-skipped                 |
| Major  | Adds, removes, or materially changes a model action, output, tool use, write authority, decision rule, stage gate, or safety behavior | Dispatch `hve-builder-tester`         |

For a satisfied-and-skipped gate, record the classification, the specific non-behavior reason, execution `Not run`, verdict `Not applicable`, and fidelity `Not applicable`. Static review and validation remain required for their applicable routes.

## Overall outcome resolver

Resolve the run once, using the first matching row from top to bottom.

| Overall outcome | Condition                                                                                                                                                                              |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Blocked`       | Scope, safety, target identity, decision-critical clarification, or required evidence is too ambiguous to proceed responsibly                                                          |
| `Deferred`      | A required stage could not run, a required behavior verdict is Not available, or research, exploration, or behavior execution is Partial because an unavailable capability prevents completion |
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

Default durable HVE Builder stage evidence to `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/`. The parent allocates a unique `{{artifact_slug}}-{{stage}}-{{attempt}}.md` path before dispatch by scanning and incrementing the attempt suffix. Read-only workers gather evidence in memory and write their owned log once; workers that promise progressive logging must have edit capability for that log. Research and exploration artifacts belong to `rpi-research`; HVE Builder records only the bridge return needed for lifecycle routing. Use plain-text workspace-relative paths inside tracking files. The final response links durable user-facing evidence and preserves plain-text paths inside tracking artifacts.
