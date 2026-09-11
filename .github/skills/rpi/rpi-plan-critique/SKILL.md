---
name: rpi-plan-critique
description: "Independently assess an RPI plan against supplied evidence without editing it. Use for a current initial or planner-authorized recovery critique dispatch."
argument-hint: "[plan=...] [evidence=...] [output=...] [depth={standard|deep}]"
license: MIT
user-invocable: true
---

# RPI Plan Critique

## Goal

Return one substantive, evidence-grounded credibility assessment of an RPI implementation plan. Complete the material assessment as quickly as the supplied evidence permits by default; broaden depth only when the user explicitly requests `deep`. The critique is read-only with respect to the plan and writes only the caller-specified critique artifact.

## Flow

1. Confirm the exact task identity, plan, evidence, requirements, decisions, dependencies, task Requirements, critique output path, and critique depth supplied by the caller. Use `standard` when depth is omitted. Use `deep` only when the caller records explicit user direction; otherwise downgrade an unsupported deep request to standard and record the limitation.
2. Before assessment, inspect Critique Disposition, supplied parent state and recorded output paths for this task. Standalone first use follows the local preflight below and does not require the `rpi-plan` skill or its files.
   * Return any prior terminal `Complete`, `Partial`, or `Blocked` execution and its verdict or limitation without reassessing, even when its file is missing. Ambiguous task identity blocks assessment.
    * For a parent dispatch, read the Reservation and current-dispatch ownership and Interrupted critique recovery contracts from the planning parent's resolved canonical reference pointer. When no pointer is supplied, locate the available skill by its stable name `rpi-plan` and read `references/planning.md` relative to that skill's resolved root, not an assumed sibling directory.
       If the reference cannot be resolved or read, return a missing-dependency preflight limitation to the parent without assessment, reservation changes or standalone fallback. Reading the contract does not authorize the worker to run its recovery procedure.
   * For a parent dispatch, verify task, attempt ID/kind, candidate identity/hash boundary, depth, output and immediate current-dispatch provenance against the saved reservation. That worker may execute its own initial or approved recovery reservation once. Saved matching identifiers alone cannot authorize a replay; earlier `started` records route to the planning parent's recovery protocol without a new assessment.
   * A recovery worker also verifies the saved task-specific approval, original-attempt provenance and distinct output. It cannot authorize recovery, reset its reservation or request another attempt. Any failure returns the preflight limitation; it does not claim a substantive assessment ran or overwrite an existing result.
    * For standalone use with no consumed attempt, persist an initial `started` reservation in the specified output with task, unique attempt ID/kind, candidate identity and saved-content hash boundary, depth, output and uninterrupted reservation-to-assessment provenance before assessing. If it cannot be saved and read back, stop.
       Existing standalone reservations route to the planning parent for reconciliation, not another standalone invocation. If `rpi-plan` is unavailable for that reconciliation, return the dependency limitation and preserve the existing evidence; do not reserve or reassess.
3. Read the plan and directly relevant supplied evidence. Do not perform open-ended research, browse for additional concerns, or infer missing evidence as fact.
4. Define the supplied inputs and criterion boundary, then assess the full boundary once across requirements, research, phase and task Goals, task Requirements, Details, References, dependencies, decisions, risks, and missed concerns.
   * In `standard`, assess the complete supplied boundary while prioritizing implementation blockers, contradictions, missing dependencies or acceptance coverage, unsupported scope or architecture, and material risks. Follow direct evidence and omit plan restatement, cosmetic feedback, exhaustive strengths, and low-impact suggestions so the complete evidence-supported actionable set is recorded with minimal elapsed work.
   * In `deep`, trace supplied evidence more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns. Deep remains one assessment and does not widen research authority.
   * In either depth, return one complete finding set rather than serializing findings across critique passes.
5. Write the critique using [templates/plan-critique.md](templates/plan-critique.md). Use severity-graded `PC-xxx` findings keyed to relevant requirement, research, phase, or task IDs. For each actionable finding, name the smallest useful change, action owner, exact resolving evidence, and whether it is a direct planner correction or needs a significant or divergent user decision.
6. Record critique execution as Complete, Partial, or Blocked, separately from the Pass, Revise, or Blocked verdict. A passing critique may identify residual risks that the planning parent has explicitly accepted.

## Inputs

* Plan path
* Caller requirements and task context
* Supplied research, evidence pointers, draft details, and decisions
* Dependencies and task Requirements
* One critique output path
* For parent dispatch: current attempt ID/kind, reservation and dispatch provenance, candidate hash boundary, parent state when present, the parent's resolved canonical planning reference pointer or discoverable `rpi-plan` skill, and task-specific recovery approval when applicable
* Critique depth and provenance: `standard` by default or `deep` from explicit user direction

## Success criteria

* The critique distinguishes evidence-backed concerns from missing evidence.
* Critique depth and provenance are recorded. Standard completely assesses the material supplied boundary while minimizing low-value work; deep occurs only from explicit user direction.
* Preflight admits the verified current initial or approved recovery worker, but returns prior same-task evidence without reassessment on replay and blocks ambiguous identity or dispatch provenance. Standalone first use reserves before assessment without requiring another skill; missing parent-dispatch guidance never permits standalone fallback.
* Findings identify substantive gaps rather than structure, formatting, or cosmetic preferences.
* The critique records its inputs, criterion boundary, coverage assessment, and limitations.
* Each actionable finding has a severity, related IDs, evidence, impact, and smallest useful change.
* Each actionable finding identifies its action owner, exact resolving evidence, and whether it is a direct correction or requires a significant or divergent user decision.
* The critique returns one complete actionable finding set for the supplied boundary; cosmetic preferences and separately withheld late findings do not create serial passes.
* Complete, Partial, or Blocked consumes the assessment regardless of verdict; no terminal result is retried and no closure critique is requested. Only the planning parent may authorize the single started-only interruption recovery defined in its reference.
* The closeout identifies the highest-impact finding, action owner, smallest next action, and whether a user response is required.
* The plan remains unchanged.

## Constraints

* Do not edit the plan, research, changes, or review records.
* Do not perform research beyond the supplied inputs. Route a material research gap to the planning parent as a Blocked or Revise finding.
* Do not grade formatting, document cosmetics, or template adherence unless the issue conceals a substantive planning risk.
* Confirmed user requests and answers outrank critique advice. A conflicting recommendation is rejected when current user direction already resolves it. Classify a significant or divergent issue as a user decision only when current user direction does not resolve it.
* Do not invoke this skill recursively, ask for a same-task rerun, or perform a closure assessment. Missing evidence is a finding or Blocked result, not permission for another invocation.
* Use plain-text workspace-relative paths in the output artifact.

## Conversation guidance

* In standard mode, suppress continual updates unless a blocker prevents completion. In deep mode, provide concise updates only at meaningful boundaries. Explain the assessment action and why it matters, material findings, blockers, and relevant artifact links without narrating low-level actions.
* Do not ask the user questions during critique. Record any significant or divergent decision need in its finding and return it to the planning parent or standalone caller for disposition.
* Use a small status marker such as ✅, ⚠️, or ⛔ only when it improves scanning, and pair it with text.
* At closeout, separate critique execution status, Complete, Partial, or Blocked, from its Pass, Revise, or Blocked verdict. Identify the highest-impact finding, its action owner, the smallest next action, and whether a user response is required. A planner-owned revision does not require user input.
* Advise `/compact` only when stale tool output or completed assessment detail outweighs useful current context and the plan and critique artifact are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* When dispatched by `rpi-plan`, return the verdict to the planning parent and do not ask the user to invoke planning again. In a standalone invocation, do not invoke a peer stage. State `/rpi-plan` only when a revision needs the planning parent. Otherwise state the explicit stop or no-handoff reason. In an active `rpi-quick` or confirmed automatic RPI Agent context, return the verdict to the parent so it can continue after gates and required confirmations pass.
* For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Stop rules

* Return Blocked when supplied evidence cannot support a decision-critical assessment; do not request another critique.
* Return Revise when substantive findings require a plan change; the parent disposes findings without a closure critique.
* Return Pass when the plan is credible for implementation and any residual risks are explicitly accepted.
* Stop after writing and returning one Complete, Partial, or Blocked assessment. Every status consumes the invocation.

## Handoff

Return critique depth and provenance, execution status, verdict, output path, severity summary, highest-impact finding, action owner, smallest next action, and user-response status to the planning parent. When `rpi-plan` dispatched the critique, the parent revises directly, obtains a significant or divergent user decision when required, and finalizes without another critique. A standalone critique may advise `/rpi-plan` for needed revision but does not invoke it.

## Final response contract

Return critique depth and provenance, execution status, Pass, Revise, or Blocked verdict, the critique output path, severity counts, one highest-impact `PC-xxx` finding, its action owner, the smallest recommended next action, and whether a user response is required. Do not reproduce the full critique in the response. Follow the Conversation guidance section for parent return, standalone advice, conditional compaction advice, the linked artifact table, and final next steps.
