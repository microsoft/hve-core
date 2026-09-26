---
name: rpi-plan-critique
description: "Assess an RPI plan without editing it. Use for initial assessment, materially changed coverage, or planner-authorized recovery of missing assessment work."
argument-hint: "[plan=...] [evidence=...] [output=...] [depth={standard|deep}]"
license: MIT
user-invocable: true
---

# RPI Plan Critique

## Goal

Return one substantive, evidence-grounded credibility assessment of an RPI implementation plan. Assess the plan against the supplied evidence with fresh eyes rather than the drafting reasoning. Complete the material assessment as quickly as the supplied evidence permits by default; broaden depth only when the user explicitly requests `deep`. The critique is read-only with respect to the plan and writes only the caller-specified critique artifact.

## Flow

1. Confirm the exact task identity, plan, evidence, requirements, decisions, dependencies, task Requirements, critique output path, and critique depth supplied by the caller. Use `standard` when depth is omitted. Use `deep` only when the caller records explicit user direction; otherwise downgrade an unsupported deep request to standard and record the limitation.
2. Before assessment, inspect Critique Disposition, supplied parent state and recorded output paths for this task. Resolve the canonical hashing helper from the parent's supplied `rpi-plan` root or discover that skill by stable name, including standalone first use. Execute `scripts/Get-PlanAssessmentHash.ps1` on the saved plan using the deterministic assessed-content identity contract in `references/planning.md`. Verify the returned projection version, exact projection and SHA-256 against the reservation, or record them in a new standalone initial reservation. Missing helper/reference, failed invocation or unverifiable identity is a preflight limitation, never permission to recreate the projection.
   * Reuse prior substantive results and return completed coverage without replay. A changed hash alone does not authorize reassessment. For missing or materially changed coverage, verify the planning parent's scoped authorization, predecessor evidence and resolving action. Preserve prior findings even when output is missing; do not mistake a status label for actual coverage.
   * When run from `rpi-plan`, read Reservation and current-run ownership, Revision-bound closure and Evidence-based recovery from the parent's resolved canonical reference. When none is supplied, locate `rpi-plan` by stable name and read `references/planning.md` relative to its resolved root, not an assumed sibling directory.
      If the reference cannot be resolved or read, return a missing-dependency preflight limitation to the parent without assessment, reservation changes or standalone fallback. Reading the contract does not authorize the critique to run the recovery procedure.
   * Verify task, attempt ID/kind, canonical identity, depth, distinct output and immediate current-run provenance. A run may assess its own initial, recovery or revision-closure reservation once. Saved identifiers alone cannot authorize replay; earlier reservations return to the planner for reconciliation.
   * For `revision-closure`, verify predecessor and current hashes, delta, affected requirements, retained-coverage evidence and the parent's full-versus-scoped classification. Ordinary supported finding corrections belong to parent closure, not another critique. Assess the materially changed boundary and affected dependencies; use full scope when its impact cannot be bounded.
   * For `recovery`, verify existing scope authorization, saved candidate, originating-run inactivity, evidence reconciliation and concrete resolving action. No new consent, positive infrastructure diagnosis or historical retry count is required. Assess only the authorized missing work, retaining prior coverage and findings. An unresolved candidate conflict or potentially active competing run stops admission. The critic cannot authorize its own recovery.
   * For standalone first use with no prior run or assessment needing reconciliation, persist an initial `started` reservation in the specified output with task, unique attempt ID/kind, canonical identity, depth, output and uninterrupted reservation-to-assessment provenance. If it cannot be saved and read back, report the prerequisite without assessing.
      Existing standalone reservations route to the planning parent for reconciliation, not another standalone invocation. If `rpi-plan` is unavailable for that reconciliation, return the dependency limitation and preserve the existing evidence; do not reserve or reassess.
3. Read the plan and directly relevant supplied evidence. Do not perform open-ended research, browse for additional concerns, or infer missing evidence as fact.
4. Define the supplied inputs and criterion boundary, then assess requirements, research, phase and task Goals, task Requirements, Details, References, dependencies, decisions and material risks within that boundary. An initial assessment covers the full candidate; an admitted revision or recovery covers the named changed or missing scope. Verify retained coverage against predecessor evidence rather than inferring completeness from a prior status. Report unresolved gaps in combined coverage explicitly.
   * Assess coverage across the supplied plan and evidence as a whole. Do not require a task to repeat requirements already established elsewhere solely for restatement. A stated requirement alone does not prove implementation coverage; ground required changes in demonstrated omissions, contradictions, or material evidence gaps.
   * Treat missing detail in an abbreviated task or excerpt as a limitation of the supplied evidence, not proof that the full plan omits it. Identify the evidence needed to resolve a decision-critical uncertainty; do not turn the same uncertainty into a separate requirement-restatement finding.
   * In `standard`, assess the complete supplied boundary while prioritizing implementation blockers, contradictions, missing dependencies or acceptance coverage, unsupported scope or architecture, and material risks. Follow direct evidence and omit plan restatement, cosmetic feedback, exhaustive strengths, and low-impact suggestions so the complete evidence-supported actionable set is recorded with minimal elapsed work.
   * In `deep`, trace supplied evidence more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns. Deep remains one assessment and does not widen research authority.
   * In either depth, return one complete finding set rather than serializing findings across critique passes.
5. Write the critique using [templates/plan-critique.md](templates/plan-critique.md). Use severity-graded `PC-xxx` findings keyed to relevant IDs. Name the smallest useful change, owner, resolving evidence and whether a direct planner correction or material user decision is needed. A scoped result identifies predecessor evidence, adjacent hashes, delta or missing scope, retained coverage and new findings without erasing earlier results. `Complete` describes completion of the declared scope, not unassessed portions of the plan.
6. Record substantive execution as Complete, Partial or Blocked, separately from its Pass, Revise or Blocked verdict. When no assessment was produced, record Deferred with verdict unavailable and the missing prerequisite; preserve uncertain outcomes as unknown and all surviving fragments. Return to the planner, which resumes revision and readiness authority. This skill's read-only constraint does not prevent subsequent parent edits.

## Inputs

* Plan path
* Caller requirements and task context
* Supplied research, evidence pointers, draft details, and decisions
* Dependencies and task Requirements
* One critique output path
* When run from `rpi-plan`: attempt ID/kind, reservation/run provenance, canonical candidate identity, parent state, planning reference pointer or discoverable `rpi-plan`, scope, predecessor coverage and recovery eligibility when applicable
* Critique depth and provenance: `standard` by default or `deep` from explicit user direction

## Success criteria

* The critique distinguishes evidence-backed concerns from missing evidence.
* Critique depth and provenance are recorded. Standard completely assesses the material supplied boundary while minimizing low-value work; deep occurs only from explicit user direction.
* Preflight admits the verified current initial, recovery or changed-boundary assessment; it reuses completed coverage and blocks unexplained identity, scope or run-provenance conflicts. Standalone first use requires the canonical hashing helper. Missing parent guidance returns Deferred, not permission for standalone fallback.
* Findings identify substantive gaps rather than structure, formatting, or cosmetic preferences.
* The critique records its inputs, criterion boundary, coverage assessment, and limitations.
* Each actionable finding has a severity, related IDs, evidence, impact, and smallest useful change.
* Each actionable finding identifies its action owner, exact resolving evidence, and whether it is a direct correction or requires a significant or divergent user decision.
* The critique returns one complete actionable finding set for the supplied boundary; cosmetic preferences and separately withheld late findings do not create serial passes.
* Actual findings remain binding until disposed; completed coverage is not replayed for a better verdict. The parent can authorize missing or materially changed assessment work without a lifetime attempt cap. A no-assessment failure is Deferred, not Pass or a substantive plan verdict.
* The closeout identifies the highest-impact finding, action owner, smallest next action, and whether a user response is required.
* The plan remains unchanged.

## Constraints

* Do not edit the plan, research, changes, or review records.
* Do not perform research beyond the supplied inputs. Route a material research gap to the planning parent as a Blocked or Revise finding.
* Do not grade formatting, document cosmetics, or template adherence unless the issue conceals a substantive planning risk.
* Confirmed user requests and answers outrank critique advice. A conflicting recommendation is rejected when current user direction already resolves it. Classify a significant or divergent issue as a user decision only when current user direction does not resolve it.
* Do not invoke this skill recursively or authorize another run. Return missing evidence to the parent with its scope and clearing action. Only the parent can commission evidence-based recovery or changed-boundary assessment.
* Do not author or attest a human assessment. Human review applies only when an actual source requires it; an interrupted critique does not introduce that requirement.
* Use plain-text workspace-relative paths in the output artifact.

## Conversation guidance

* In standard mode, suppress continual updates unless a blocker prevents completion. In deep mode, provide concise updates only at meaningful boundaries. Explain the assessment action and why it matters, material findings, blockers, and relevant artifact links without narrating low-level actions.
* Do not ask the user questions during critique. Record any significant or divergent decision need in its finding and return it to the planning parent or standalone caller for disposition.
* Use a small status marker such as ✅, ⚠️, or ⛔ only when it improves scanning, and pair it with text.
* At closeout, separate substantive execution (Complete, Partial or Blocked) from verdict (Pass, Revise or Blocked). When no assessment was produced, state the execution limitation and unavailable verdict instead. Identify the highest-impact finding when present, its owner, next action and user-response need. A planner-owned revision does not require user input.
* Advise `/compact` only when stale tool output or completed assessment detail outweighs useful current context and the plan and critique artifact are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* When run from `rpi-plan`, return the verdict to the planning parent and do not ask the user to invoke planning again. In a standalone invocation, do not invoke a peer stage. State `/rpi-plan` only when a revision needs the planning parent. Otherwise state the explicit stop or no-handoff reason. In an active confirmed automatic RPI Agent context, return the verdict to the parent so it can continue after gates and required confirmations pass.
* For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Stop rules

* Return Blocked when supplied evidence cannot support a decision-critical assessment; do not request another critique.
* Return Revise when substantive findings require a plan change; the parent closes ordinary corrections directly and requests assessment only for missing or materially changed coverage.
* Return Pass when the plan is credible for implementation and any residual risks are explicitly accepted.
* Stop after returning the declared assessment or execution limitation. A reservation is not completed work. Return control to the planning parent without self-retry, invented findings or an additional human-approval demand.

## Handoff

Return depth, invocation outcome, execution, verdict, output, identity, actual and retained coverage, findings, owner and next action to the planning parent. The parent revises, closes findings and finalizes under its reference; a routine correction does not require another critique or human sign-off. A standalone critique may advise `/rpi-plan` for disposition but does not invoke it.

## Final response contract

Return depth and provenance, invocation outcome, assessment execution/availability and verdict (unavailable when no assessment was produced), output path, severity counts and highest-impact finding when present, owner, next action and user-response need. Do not invent a finding or verdict for a preflight or transport failure. Keep the response compact and follow Conversation guidance for parent return, standalone advice, artifact links and next steps.
