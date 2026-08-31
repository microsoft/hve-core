---
description: 'Mode routes, candidate convergence, one final behavior gate, and outcome resolution for hve-builder.'
---
<!-- markdownlint-disable-file -->
# HVE Builder Workflow Contract

Use this reference as the control-flow authority for an `hve-builder` run. The requirements catalog defines artifact quality; this contract determines when the candidate is final and which evidence permits completion.

## Mode Routes

| Mode       | Source write authority                                                 | Required work                                                              | Completion intent                                 |
|------------|------------------------------------------------------------------------|----------------------------------------------------------------------------|---------------------------------------------------|
| `create`   | Create approved targets and directly required support artifacts        | route, author, static review, validate, behavior decision                  | Deliver a new artifact set                        |
| `improve`  | Edit approved targets and directly required support artifacts          | baseline, author, static review, validate, behavior decision               | Improve behavior within the approved architecture |
| `refactor` | Edit approved targets while preserving the stated contract             | baseline, author, static review, validate, behavior decision               | Simplify without unintended behavior change       |
| `replace`  | Replace approved targets after capturing intent and migration boundary | baseline intent, route, author, static review, validate, behavior decision | Deliver an approved replacement architecture      |
| `review`   | Read source; write review and test evidence only                       | static review, optional requested validation, behavior decision            | Return an independent verdict                     |
| `validate` | Read source; write validation evidence only                            | validate                                                                   | Return mechanical conformance evidence            |

Validation is required for mutating modes and `validate`. It is optional in `review` unless requested. Behavior testing never runs in `validate`.

## Final-Candidate Invariant

Resolve the behavior gate once per HVE Builder run.

For a mutating route, the final candidate exists only after all known source changes are applied, static findings are closed, required validation passes, and the assessed source boundary is recorded. For a review route, complete the static assessment and any requested validation against the unchanged source boundary first.

After that boundary is frozen:

* Minor and Medium mutations record `Satisfied-and-skipped`.
* Major mutations and behavior-bearing review targets invoke `hve-builder-tester` at most once.
* No source edit, static review, validation pass, or behavior-test invocation follows the tester dispatch in the same run.
* A non-Pass behavior result ends the run. Its report may seed a later HVE Builder invocation, but never a same-run correction or retest.

## Existing Capability Surface

Treat existing `agents`, `hooks`, `handoffs`, `model`, and other non-tool capability-bearing frontmatter as baseline behavior. Preserve it in improve and refactor modes unless the caller requests a change or verified evidence establishes a host incompatibility, native failure, security defect, or required capability gap. Route an approved change through scope before editing and classify it as Major.

Agent and subagent `tools` configuration remains outside HVE Builder assessment. Apply the Tool-configuration boundary in [requirements-catalog.md](requirements-catalog.md).

## Lifecycle

1. Scope and route. Resolve targets, mode, requirements, write boundary, evidence root, architecture, applicable conventions, and directly required distribution support. Intake may classify supplied facts and known paths without exploration.
2. Establish the baseline. For improve, refactor, and replace, capture the current contract and non-tool capability surface from known targets and supplied references. Skip a missing create target. Review performs its assessment later.
3. Research only when needed. Use the `rpi-research` bridge in [stage-dispatch.md](stage-dispatch.md) for open-ended exploration, non-obvious reuse or extension discovery, and decision-critical evidence gaps. Do not substitute local discovery.
4. Author the candidate. The lifecycle lead edits approved targets directly. Gather current requirements and findings before each coherent batch. Return to scope before a type change, artifact split, capability-surface change, or new support artifact outside the boundary.
5. Validate the candidate. Run known non-mutating local checks, gather their complete in-scope finding set, and close those findings as a coherent batch before independent review. Do not invoke the behavior tester while validation remains open.
6. Review and close static findings. Dispatch one fresh-context Medium-profile static review against the mechanically valid candidate. Apply its complete in-scope finding set in one correction batch, then run targeted static closure and every validation check affected by the corrections. If either remains open, stop Revise. If the assessed boundary changes, return to scope rather than claiming closure.
7. Freeze and resolve behavior. Record the final target set, requirements, source revision, static verdict, validation result, classification, profile, fidelity, and grouping. Apply the Final-Candidate Invariant. In review mode, the unchanged source is already frozen; complete static review and any requested validation before the behavior decision, even when static findings make the eventual overall outcome Revise.
8. Resolve the run. Apply the outcome table. Do not re-enter an earlier stage after tester dispatch.

Independent work may overlap only when neither task consumes the other's output. Authoring, validation, independent static review, correction closure, source freeze, and behavior testing remain ordered because each establishes the next candidate boundary.

## Static Review

Use [stage-dispatch.md](stage-dispatch.md) for one generic fresh-context reviewer. Give it targets, purpose, requirements, canonical criteria, overlays, and an evidence path, but not author reasoning. It returns one complete severity-graded finding set. Use targeted closure for those finding IDs instead of another broad review.

## Validation

The lifecycle lead runs caller-named or already-known applicable non-mutating checks. Classify each as `local` or `CI`. Generic validation runs local checks only; a named CI lane runs only when the caller specifically requests its reproduction. Dependency bootstrap, browsers, services, credentials, and external environments remain separate actions.

Record per-check owner and status. Local status is `Passed`, `Failed`, `Skipped`, `Deferred`, or `Unavailable`; CI status may also be `Pending CI`. Required unavailable evidence resolves to Deferred rather than Pass. Unexpected source mutation invalidates the candidate until reconciled before freeze.

When distribution scope applies, complete required plugin, extension, and generated-document synchronization before validation passes. Record a non-applicable distribution check with its reason.

## Change Classification

Use the highest class present in the complete source delta.

| Class  | Decision rule                                                                                                                                   | Behavior gate                                 |
|--------|-------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| Minor  | Editorial, formatting, comments, links, non-capability frontmatter, or name-reference updates with no rule or behavior change                   | Satisfied-and-skipped                         |
| Medium | Clarifies or reorganizes existing text without materially changing a model action or output                                                     | Satisfied-and-skipped                         |
| Major  | Adds, removes, or materially changes a model action, output, capability surface, write authority, decision rule, stage gate, or safety behavior | Invoke `hve-builder-tester` once after freeze |

For a supported skip, record classification, reason, execution `Not run`, verdict `Not applicable`, and fidelity `Not applicable`.

## Result Vocabulary

* Static review verdict: `Pass`, `Revise`, or `Blocked`
* Mechanical validation result: `Pass`, `Fail`, or `Deferred`
* Review-mode validation display: `Not requested` when the caller omitted optional mechanical validation
* Behavior execution: `Complete`, `Partial`, `Deferred`, `Blocked`, or `Not run`
* Behavior verdict: `Pass`, `Revise`, `Blocked`, `Not available`, or `Not applicable`
* Behavior disposition: `Executed` or `Satisfied-and-skipped`

Use `Not available` only when required behavior execution is Deferred before independent grading. `Partial`, `Deferred`, and `Blocked` are not passes.

## Overall Outcome

Use the first matching condition.

| Outcome    | Condition                                                                                                                         |
|------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `Blocked`  | Scope, safety, identity, decision-critical evidence, static assessment, or behavior grading is blocked                            |
| `Deferred` | A required stage or CI result is unavailable, behavior execution is Partial or Deferred, or the behavior verdict is Not available |
| `Revise`   | Static findings remain, validation fails, behavior verdict is Revise, or an acceptance criterion is unmet                         |
| `Pass`     | Every required stage passes or has a supported skip, and every acceptance criterion is met                                        |

## Batching and Stop Rules

* Gather the complete known finding set before editing. Prefer one coherent correction batch to serial micro-edits.
* Use targeted closure and affected checks after correction. A changed architecture, capability, safety, acceptance, or evidence boundary requires fresh assessment before freeze.
* Never use behavior testing to discover whether known static or mechanical work is complete.
* Preserve human-review checkboxes and leave them unchecked.

## Evidence

Default HVE Builder evidence to `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/`. Allocate unique stage paths without overwriting earlier evidence. Research artifacts remain owned by `rpi-research`. Use plain-text workspace-relative paths inside tracking files and Markdown links in user-facing responses.
