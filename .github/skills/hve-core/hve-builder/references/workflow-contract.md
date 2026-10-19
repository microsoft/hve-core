---
description: 'Composable modes, parent-owned correction cycles, candidate evidence, and outcome resolution for hve-builder.'
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

Assess instruction quality against the requirements catalog and review rubric. Alone, review reads source and writes review evidence only. Combined with authorized mutation, it assesses the candidate within the shared lifecycle and supports bounded correction when required findings remain.

### Validate

Check mechanical conformance and record validation evidence. Alone, validate does not edit source or run the review pass. Combined with other activities, it does not suppress their required gates.

### Compose the Lifecycle Once

* When source mutation is authorized, run one shared lifecycle: scope, baseline existing targets, author, validate, review and close findings, and resolve the outcome. Review and validation are required stages even when absent from the mode names. Combining modes does not multiply stages; further correction cycles depend on material findings and progress, not mode count.
* For read-only `review`, run the review pass; mechanical validation is optional unless requested. For `review,validate`, also run mechanical validation, without granting write authority.
* For `validate` alone, run mechanical checks only. For explanation or discussion without requested changes or assessment, answer within that scope without starting an authoring lifecycle.

Use the requirements catalog's Authoring and maintenance decisions to choose what to keep, improve, refactor, replace, or delete. Deletion is an operation within an approved mutating boundary. Read-only review only recommends it. A cleanup request permits removing obsolete or redundant guidance inside that boundary, not silently retiring required behavior.

## Candidate Revision

Resolve the review pass and validation against an identified candidate revision, not a lifetime invocation count.

For a mutating route, the candidate exists only after all known source changes are applied and required validation passes. For a review route, the unchanged source boundary is the candidate. Review evidence names the revision it assessed:

* An authorized mutating route may correct required in-scope findings and review the revised candidate through Parent-Owned Convergence.
* Read-only review returns findings without source correction. Neither a finding set nor a mode combination widens write authority.
* Review evidence remains immutable for the revision it assessed. A later edit invalidates affected evidence for completion until the necessary checks and review cover the delivered candidate.

## Existing Capability Surface

Treat existing `agents`, `hooks`, `handoffs`, `model`, and other non-tool capability-bearing frontmatter as baseline behavior. Preserve it in improve and refactor modes unless the caller requests a change or verified evidence establishes a host incompatibility, native failure, security defect, or required capability gap. Route an approved change through scope before editing.

Agent and subagent `tools` configuration remains outside HVE Builder assessment. Apply the Tool-configuration boundary in [requirements-catalog.md](requirements-catalog.md).

## Lifecycle

1. Scope and route. Resolve targets, active mode set, requirements, per-target write boundary, evidence root, architecture, applicable conventions, and directly required distribution support. Intake may classify supplied facts and known paths without exploration.
2. Establish the baseline. For improve, refactor, and replace, capture the current contract and non-tool capability surface from known targets and supplied references. Skip a missing create target. Review performs its assessment later.
3. Research only when needed. Use the `rpi-research` bridge in [stage-dispatch.md](stage-dispatch.md) for open-ended exploration, non-obvious reuse or extension discovery, and decision-critical evidence gaps. Do not substitute local discovery.
4. Author the candidate. The lifecycle lead edits approved targets directly. Gather current requirements and findings before each coherent batch. Return to scope before a type change, artifact split, capability-surface change, or new support artifact outside the boundary.
5. Validate the candidate. Run known non-mutating local checks, gather their complete in-scope finding set, and close those findings as a coherent batch before the review pass.
6. Review and close findings. Run the review pass against the mechanically valid candidate. Apply its complete in-scope required finding set in one correction batch, then run targeted closure and every validation check affected by the corrections. Use Parent-Owned Convergence for remaining required findings. If the assessed boundary changes, return to scope and refresh the affected review rather than claiming closure.
7. Resolve or correct. Record the target set, requirements, source revision, review verdict, and validation result for the delivered candidate. Re-enter only the stages affected by a justified correction or resolved evidence prerequisite. When no further cycle is needed or supported, apply the Overall Outcome precedence. In read-only review, complete the review pass and any requested validation before resolving, even when findings make the outcome Revise.

Independent work may overlap only when neither task consumes the other's output. Authoring, validation, the review pass, and correction closure remain ordered because each establishes the next candidate boundary.

## Review Pass

The review pass applies [review-rubric.md](review-rubric.md) to the complete, mechanically valid candidate and returns one bounded, severity-graded finding set with a `Pass`, `Revise`, or `Blocked` verdict. The parent decides what passes and what needs further correction; it owns the recorded verdict and every disposition.

Review the candidate yourself by default. Dispatch `HVE Builder Reviewer` through [stage-dispatch.md](stage-dispatch.md) when fresh context would help: the authoring context is long or invested in its own reasoning, the change alters a decision rule, stage gate, write authority, or safety behavior, or the caller asks for an isolated review. A subagent is never required, and no gate depends on one. Treat its return as suggestions: read each cited location, then accept or reject each finding on your own reasoning. A reviewer's suggested verdict and severities do not bind the parent. When the reviewer reports an instruction as confusing or unclear and your reading of the artifact against its purpose, requirements, and conventions shows it is suitable, reject the finding and record the reason; when the reviewer is right, correct it. Record only what you verified, with each rejection and its reason in the review evidence.

Prefer targeted closure for corrected finding IDs over another broad review. Refresh the review for materially changed requirements, architecture, capability, safety, or evidence boundaries.

## Parent-Owned Convergence

The main agent using HVE Builder owns corrections to approved prompts, instructions, agents, subagents, skills, and directly required support files. A review subagent reports findings without editing targets or starting its own repair loop.

1. Gather the complete finding set before editing. Separate demonstrated defects and unmet requirements from advisory improvements and coverage gaps. Required corrections remain required regardless of severity; wording preferences and cosmetic polish alone do not justify another cycle.
2. Map each required finding to its requirement, root cause, smallest resolving change, and affected checks. Apply all compatible in-scope corrections as one coherent batch. Do not weaken requirements or review criteria to obtain Pass. An out-of-scope correction requires scope resolution, not assumed authority.
3. Before continuing, record what materially changes and why it should resolve the finding. Use targeted closure and affected validation; refresh the broader review only when the material boundary changed. Retain unaffected evidence with an explicit applicability rationale.
4. Review the complete task delta, not only the last repair, so a change to a decision rule cannot escape review because its final correction is small. Cover corrected behavior and related regressions while maintaining complete material requirement coverage for the current candidate.
5. Compare results with prior attempts by requirement and root cause. Continue while required work remains and evidence supports a concrete path to progress, such as closing a defect, reducing its impact, or resolving a material coverage gap. Prefer one successful attempt; do not impose an arbitrary iteration ceiling or repeat broad stages by habit.

Stop with the mapped outcome when all required gates pass, only advisory suggestions remain, the caller stops or an explicit budget is reached, or there is no supported resolving action. Repeated same-cause failures, oscillating edits, or unchanged evidence without a new evidence-backed approach are no-progress signals: stop with the unresolved findings and smallest next action rather than retrying blindly.

An unavailable check or reviewer is not proof of a source defect. Retry a Deferred or Blocked stage only after its specific prerequisite or evidence gap is demonstrably resolved within existing authority. Otherwise return the mapped non-Pass outcome. The same source revision may be reviewed again for such a resolved prerequisite, but not merely to seek a more favorable verdict. Read-only routes may recover evidence under this rule without gaining source-write authority.

## Validation

The lifecycle lead runs caller-named or already-known applicable non-mutating checks. Classify each as `local` or `CI`. Generic validation runs local checks only; a named CI lane runs only when the caller specifically requests its reproduction. Dependency bootstrap, browsers, services, credentials, and external environments remain separate actions.

Record per-check owner and status. Local status is `Passed`, `Failed`, `Skipped`, `Deferred`, or `Unavailable`; CI status may also be `Pending CI`. Required unavailable evidence resolves to Deferred rather than Pass. Unexpected source mutation invalidates the candidate until reconciled before freeze.

When distribution scope applies, complete required plugin, extension, and generated-document synchronization before validation passes. Record a non-applicable distribution check with its reason.

## Result Vocabulary

* Review verdict: `Pass`, `Revise`, or `Blocked`
* Mechanical validation result: `Pass`, `Fail`, or `Deferred`
* Read-only review validation display: `Not requested` when the caller omitted optional mechanical validation

Advisory suggestions are not unresolved required corrections. A Deferred check is not a pass.

## Overall Outcome

Use the first matching condition.

Apply this precedence to the current candidate and unresolved findings after convergence stops. An earlier Revise verdict remains historical evidence, not a permanent failure after its findings are closed; an earlier Pass cannot certify a later unreviewed change.

1. `Blocked`: scope, safety, identity, decision-critical evidence, or the review pass is blocked.
2. `Deferred`: a required stage or CI result is unavailable.
3. `Revise`: required review corrections remain, validation fails, or an acceptance criterion is unmet.
4. `Pass`: every required stage passes, and every acceptance criterion is met.

## Batching and Stop Rules

* Gather the complete known finding set before editing. Prefer one coherent correction batch to serial micro-edits.
* Use targeted closure and affected checks after correction. A changed architecture, capability, safety, acceptance, or evidence boundary requires a refreshed review before the outcome is resolved.
* Never use the review pass to discover whether known mechanical work is complete.
* Preserve human-review checkboxes and leave them unchecked.

## Evidence

Default HVE Builder evidence to `.copilot-tracking/hve-builder/{{YYYY-MM-DD}}/`. Allocate unique stage paths without overwriting earlier evidence. Record each attempt's revision, review verdict, required finding dispositions, correction batch, affected checks, retained-evidence rationale, progress, and continuation or stop reason in the parent evidence. Reuse existing matching evidence on resume rather than repeating an unchanged attempt. Research artifacts remain owned by `rpi-research`. Use plain-text workspace-relative paths inside tracking files and Markdown links in user-facing responses.
