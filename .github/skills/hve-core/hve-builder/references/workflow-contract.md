---
description: 'Composable modes, candidate convergence, one final behavior gate, and outcome resolution for hve-builder.'
---
<!-- markdownlint-disable-file -->
# HVE Builder Workflow Contract

Use this reference as the control-flow authority for an `hve-builder` run. The requirements catalog defines artifact quality; this contract determines when the candidate is final and which evidence permits completion.

## Mode Composition

Modes name activities that may coexist in one run. Resolve the active set from explicit caller direction and clear intent. When neither specifies a different scope, default to `create`, `improve`, and `refactor` together. Record the set and its inferred or explicit basis without requiring the caller to choose a mode.

Apply activities where needed, not mechanically to every target. The default permits creating a missing artifact, improving an existing rule, and refactoring related duplication within the requested outcome and approved boundary. It does not require all three activities to produce changes, widen the product surface, or authorize replacement of the architecture.

Honor narrower intent: `refactor only` preserves behavior; `review only`, `validate only`, and a request for explanation do not authorize source changes. For different permissions across targets, record each target's write boundary. An explicit no-edit restriction wins over inferred mutation modes. Ask only when explicit directions conflict and the intended authority cannot be resolved.

### Create

Create approved targets and directly required support artifacts when a required behavior has no suitable owner. Reuse a suitable existing artifact instead of creating another to satisfy the mode label.

### Improve

Correct or extend behavior within the approved architecture and requirements. Capture the baseline of existing targets and distinguish intended behavior changes from accidental loss.

### Refactor

Simplify organization, duplication, or placement while preserving the affected contract. When combined with improve or create, preserve behavior outside their intended changes; the refactor activity does not forbid an explicitly intended improvement elsewhere in the same candidate.

### Replace

Replace approved targets after capturing their intent, retained capabilities, and migration boundary. This activity may join other modes when the request calls for replacement, but is not part of the inferred default. A cleanup request alone does not authorize a replacement architecture or retirement of required behavior.

### Review

Assess instruction quality independently. Alone, review reads source and writes review or test evidence only. Combined with authorized mutation, it assesses the final candidate within the same lifecycle rather than starting another review-and-edit loop.

### Validate

Check mechanical conformance and record validation evidence. Alone, validate does not edit source, invoke static review, or run behavior tests. Combined with other activities, it does not suppress their required gates.

### Compose the Lifecycle Once

* When source mutation is authorized, run one shared lifecycle: scope, baseline existing targets, author, validate, independently review and close findings, freeze, classify the complete delta, and resolve behavior. Review and validation are required stages even when absent from the mode names; combining modes does not multiply stages or tester invocations.
* For read-only `review`, run independent static review and the behavior decision; mechanical validation is optional unless requested. For `review,validate`, also run mechanical validation, without granting write authority.
* For `validate` alone, run mechanical checks only. For explanation or discussion without requested changes or assessment, answer within that scope without starting an authoring lifecycle.

Use the requirements catalog's Authoring and maintenance decisions to choose what to keep, improve, refactor, replace, or delete. Deletion is an operation within an approved mutating boundary. Read-only review only recommends it. A cleanup request permits removing obsolete or redundant guidance inside that boundary, not silently retiring required behavior.

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

1. Scope and route. Resolve targets, active mode set, requirements, per-target write boundary, evidence root, architecture, applicable conventions, and directly required distribution support. Intake may classify supplied facts and known paths without exploration.
2. Establish the baseline. For improve, refactor, and replace, capture the current contract and non-tool capability surface from known targets and supplied references. Skip a missing create target. Review performs its assessment later.
3. Research only when needed. Use the `rpi-research` bridge in [stage-dispatch.md](stage-dispatch.md) for open-ended exploration, non-obvious reuse or extension discovery, and decision-critical evidence gaps. Do not substitute local discovery.
4. Author the candidate. The lifecycle lead edits approved targets directly. Gather current requirements and findings before each coherent batch. Return to scope before a type change, artifact split, capability-surface change, or new support artifact outside the boundary.
5. Validate the candidate. Run known non-mutating local checks, gather their complete in-scope finding set, and close those findings as a coherent batch before independent review. Do not invoke the behavior tester while validation remains open.
6. Review and close static findings. Dispatch one fresh-context Medium-profile static review against the mechanically valid candidate. Apply its complete in-scope finding set in one correction batch, then run targeted static closure and every validation check affected by the corrections. If either remains open, stop Revise. If the assessed boundary changes, return to scope rather than claiming closure.
7. Freeze and resolve behavior. Record the final target set, requirements, source revision, static verdict, validation result, classification, profile, fidelity, and grouping. Apply the Final-Candidate Invariant. In read-only review, the unchanged source is already frozen; complete static review and any requested validation before the behavior decision, even when static findings make the eventual overall outcome Revise.
8. Resolve the run. Apply the Overall Outcome precedence. Do not re-enter an earlier stage after tester dispatch.

Independent work may overlap only when neither task consumes the other's output. Authoring, validation, independent static review, correction closure, source freeze, and behavior testing remain ordered because each establishes the next candidate boundary.

## Static Review

Use [stage-dispatch.md](stage-dispatch.md) for one generic fresh-context reviewer. Give it targets, purpose, requirements, canonical criteria, overlays, and an evidence path, but not author reasoning. It returns one complete severity-graded finding set. Use targeted closure for those finding IDs instead of another broad review.

## Validation

The lifecycle lead runs caller-named or already-known applicable non-mutating checks. Classify each as `local` or `CI`. Generic validation runs local checks only; a named CI lane runs only when the caller specifically requests its reproduction. Dependency bootstrap, browsers, services, credentials, and external environments remain separate actions.

Record per-check owner and status. Local status is `Passed`, `Failed`, `Skipped`, `Deferred`, or `Unavailable`; CI status may also be `Pending CI`. Required unavailable evidence resolves to Deferred rather than Pass. Unexpected source mutation invalidates the candidate until reconciled before freeze.

When distribution scope applies, complete required plugin, extension, and generated-document synchronization before validation passes. Record a non-applicable distribution check with its reason.

## Change Classification

Use the highest class present in the complete source delta.

* Minor: editorial, formatting, comments, links, non-capability frontmatter, or name-reference updates with no rule or behavior change. Record `Satisfied-and-skipped`.
* Medium: clarifies or reorganizes existing text without materially changing a model action or output. Record `Satisfied-and-skipped`.
* Major: adds, removes, or materially changes a model action, output, capability surface, write authority, decision rule, stage gate, or safety behavior. Invoke `hve-builder-tester` once after freeze.

For a supported skip, record classification, reason, execution `Not run`, verdict `Not applicable`, and fidelity `Not applicable`.

## Result Vocabulary

* Static review verdict: `Pass`, `Revise`, or `Blocked`
* Mechanical validation result: `Pass`, `Fail`, or `Deferred`
* Read-only review validation display: `Not requested` when the caller omitted optional mechanical validation
* Behavior execution: `Complete`, `Partial`, `Deferred`, `Blocked`, or `Not run`
* Behavior verdict: `Pass`, `Revise`, `Blocked`, `Not available`, or `Not applicable`
* Behavior disposition: `Executed` or `Satisfied-and-skipped`

Use `Not available` only when required behavior execution is Deferred or Blocked before independent grading. Resolve execution Blocked to overall Blocked before applying the Not available deferral rule. `Partial`, `Deferred`, and `Blocked` are not passes. Advisory suggestions are not unresolved required corrections.

## Overall Outcome

Use the first matching condition.

1. `Blocked`: scope, safety, identity, decision-critical evidence, static assessment, or behavior grading is blocked.
2. `Deferred`: a required stage or CI result is unavailable, behavior execution is Partial or Deferred, or the behavior verdict is Not available.
3. `Revise`: required static corrections remain, validation fails, behavior verdict is Revise, or an acceptance criterion is unmet.
4. `Pass`: every required stage passes or has a supported skip, and every acceptance criterion is met.

## Batching and Stop Rules

* Gather the complete known finding set before editing. Prefer one coherent correction batch to serial micro-edits.
* Use targeted closure and affected checks after correction. A changed architecture, capability, safety, acceptance, or evidence boundary requires fresh assessment before freeze.
* Never use behavior testing to discover whether known static or mechanical work is complete.
* Preserve human-review checkboxes and leave them unchecked.

## Evidence

Default HVE Builder evidence to `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/`. Allocate unique stage paths without overwriting earlier evidence. Research artifacts remain owned by `rpi-research`. Use plain-text workspace-relative paths inside tracking files and Markdown links in user-facing responses.
