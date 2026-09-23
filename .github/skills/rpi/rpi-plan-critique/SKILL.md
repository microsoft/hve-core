---
name: rpi-plan-critique
description: "Independently assess an RPI plan without editing it. Use for an initial critique, revision-bound closure, or planner-authorized recovery including infrastructure retry."
argument-hint: "[plan=...] [evidence=...] [output=...] [depth={standard|deep}]"
license: MIT
user-invocable: true
---

# RPI Plan Critique

## Goal

Return one substantive, evidence-grounded credibility assessment of an RPI implementation plan. Assess the plan against the supplied evidence with fresh eyes rather than the drafting reasoning. Complete the material assessment as quickly as the supplied evidence permits by default; broaden depth only when the user explicitly requests `deep`. The critique is read-only with respect to the plan and writes only the caller-specified critique artifact.

## Flow

1. Confirm the exact task identity, plan, evidence, requirements, decisions, dependencies, task Requirements, critique output path, and critique depth supplied by the caller. Use `standard` when depth is omitted. Use `deep` only when the caller records explicit user direction; otherwise downgrade an unsupported deep request to standard and record the limitation.
2. Before assessment, inspect Critique Disposition, supplied parent state and recorded output paths for this task. Standalone first use follows the local preflight below and does not require the `rpi-plan` skill or its files.
   * Return any prior substantive `Complete`, `Partial` or `Blocked` assessment and its verdict or limitation without reassessing the same candidate, even when its file is missing. Ambiguous identity or outcome blocks assessment. A changed hash alone does not authorize another attempt; only the planning parent's revision-bound closure contract can authorize assessment of a required correction. An evidence-qualified infrastructure failure is not a substantive assessment; only the planning parent's recovery contract can authorize a new attempt.
   * When run from `rpi-plan`, read Reservation and current-run ownership, Revision-bound closure, Interrupted critique recovery and Infrastructure failure recovery from the planning parent's resolved canonical reference pointer. When none is supplied, locate the available skill by stable name `rpi-plan` and read `references/planning.md` relative to its resolved root, not an assumed sibling directory.
      If the reference cannot be resolved or read, return a missing-dependency preflight limitation to the parent without assessment, reservation changes or standalone fallback. Reading the contract does not authorize the critique to run the recovery procedure.
   * Verify task, attempt ID/kind, candidate identity/hash boundary, depth, output and immediate current-run provenance against the saved reservation. A run may execute its own initial, approved recovery, infrastructure-retry or revision-closure reservation once. Saved identifiers alone cannot authorize replay; earlier `started` records route to the planning parent's reconciliation without assessment.
   * For `revision-closure`, verify the immediate predecessor, exact adjacent hashes and correction delta, affected requirements, disposition evidence, and parent's full-versus-targeted classification. Reject unchanged-candidate replay, unresolved prior evidence, a broken link or missing progress basis. For targeted closure, also require an uninterrupted Complete chain rooted in a full assessment and unchanged requirements, architecture, capability, safety and evidence boundaries; otherwise require a fresh full assessment of the revised candidate. A fresh full assessment may follow Partial or Blocked evidence without a prior Complete root. Never treat targeted closure of Partial or Blocked coverage as Complete.
   * Recovery and infrastructure retries verify specific consent, all prior provenance and distinct output; infrastructure retries also verify the parent's failure, ended-run, reconciliation and task-wide budget evidence. For an infrastructure retry of a failed closure, verify the predecessor, correction delta, affected IDs and full-versus-targeted scope for the current candidate; targeted scope also needs its Complete chain. A substantive assessment of a predecessor does not qualify as an assessment of the failed closure. New evidence or candidate changes stop admission. Return preflight limitations without claiming an assessment or overwriting results. The worker cannot grant retries, reset counts or fulfill a `human` attempt.
   * For standalone use with no consumed attempt, persist an initial `started` reservation in the specified output with task, unique attempt ID/kind, candidate identity and saved-content hash boundary, depth, output and uninterrupted reservation-to-assessment provenance before assessing. If it cannot be saved and read back, stop.
      Existing standalone reservations route to the planning parent for reconciliation, not another standalone invocation. If `rpi-plan` is unavailable for that reconciliation, return the dependency limitation and preserve the existing evidence; do not reserve or reassess.
3. Read the plan and directly relevant supplied evidence. Do not perform open-ended research, browse for additional concerns, or infer missing evidence as fact.
4. Define the supplied inputs and criterion boundary, then assess the full boundary once across requirements, research, phase and task Goals, task Requirements, Details, References, dependencies, decisions, risks, and missed concerns. For an admitted targeted revision closure or authorized retry of one, instead verify the latest correction delta and affected requirements against the immediate predecessor and complete chain back to the root full assessment, including whether the delta introduced a material gap; a material boundary change requires full reassessment, not targeted closure.
   * Assess coverage across the supplied plan and evidence as a whole. Do not require a task to repeat requirements already established elsewhere solely for restatement. A stated requirement alone does not prove implementation coverage; ground required changes in demonstrated omissions, contradictions, or material evidence gaps.
   * Treat missing detail in an abbreviated task or excerpt as a limitation of the supplied evidence, not proof that the full plan omits it. Identify the evidence needed to resolve a decision-critical uncertainty; do not turn the same uncertainty into a separate requirement-restatement finding.
   * In `standard`, assess the complete supplied boundary while prioritizing implementation blockers, contradictions, missing dependencies or acceptance coverage, unsupported scope or architecture, and material risks. Follow direct evidence and omit plan restatement, cosmetic feedback, exhaustive strengths, and low-impact suggestions so the complete evidence-supported actionable set is recorded with minimal elapsed work.
   * In `deep`, trace supplied evidence more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns. Deep remains one assessment and does not widen research authority.
   * In either depth, return one complete finding set rather than serializing findings across critique passes.
5. Write the critique using [templates/plan-critique.md](templates/plan-critique.md). Use severity-graded `PC-xxx` findings keyed to relevant requirement, research, phase, or task IDs. For each actionable finding, name the smallest useful change, action owner, exact resolving evidence, and whether it is a direct planner correction or needs a significant or divergent user decision. A closure result names its immediate predecessor, adjacent hashes, latest delta, affected IDs, verified dispositions, coverage type, and any new findings without erasing previous findings. Targeted closure also names its root full assessment and every intervening hash and result.
6. Record substantive critique execution as Complete, Partial or Blocked, separately from its Pass, Revise or Blocked verdict. A passing critique may identify residual risks the parent explicitly accepted. Do not manufacture a verdict for a host/transport failure or preflight limitation. If no assessment was produced, return that limitation with verdict unavailable and preserve any fragments; the planning parent owns failure classification and retry eligibility.

## Inputs

* Plan path
* Caller requirements and task context
* Supplied research, evidence pointers, draft details, and decisions
* Dependencies and task Requirements
* One critique output path
* When run from `rpi-plan`: current attempt ID/kind, reservation/run provenance, candidate hash boundary, parent state, canonical planning reference pointer or discoverable `rpi-plan` skill, and attempt-specific recovery consent and eligibility evidence when applicable
* Critique depth and provenance: `standard` by default or `deep` from explicit user direction

## Success criteria

* The critique distinguishes evidence-backed concerns from missing evidence.
* Critique depth and provenance are recorded. Standard completely assesses the material supplied boundary while minimizing low-value work; deep occurs only from explicit user direction.
* Preflight admits the verified current initial, approved recovery, infrastructure-retry or revision-closure run, but returns prior substantive evidence on unchanged-candidate replay and blocks ambiguous identity, outcome, broken closure lineage or provenance. Standalone first use reserves without requiring another skill; missing parent guidance never permits standalone fallback. A human assessment cannot be generated by this skill.
* Findings identify substantive gaps rather than structure, formatting, or cosmetic preferences.
* The critique records its inputs, criterion boundary, coverage assessment, and limitations.
* Each actionable finding has a severity, related IDs, evidence, impact, and smallest useful change.
* Each actionable finding identifies its action owner, exact resolving evidence, and whether it is a direct correction or requires a significant or divergent user decision.
* The critique returns one complete actionable finding set for the supplied boundary; cosmetic preferences and separately withheld late findings do not create serial passes.
* Substantive Complete, Partial or Blocked consumes the assessment for its candidate regardless of verdict; no unchanged-candidate replay is allowed. Only the planning parent may authorize revision-bound closure of required corrections or bounded recovery of a failed invocation. Infrastructure failure without assessment is not Pass and does not itself grant a retry.
* The closeout identifies the highest-impact finding, action owner, smallest next action, and whether a user response is required.
* The plan remains unchanged.

## Constraints

* Do not edit the plan, research, changes, or review records.
* Do not perform research beyond the supplied inputs. Route a material research gap to the planning parent as a Blocked or Revise finding.
* Do not grade formatting, document cosmetics, or template adherence unless the issue conceals a substantive planning risk.
* Confirmed user requests and answers outrank critique advice. A conflicting recommendation is rejected when current user direction already resolves it. Classify a significant or divergent issue as a user decision only when current user direction does not resolve it.
* Do not invoke this skill recursively or request an unchanged-candidate rerun. Only assess a changed candidate through a verified planner-owned revision-closure reservation. Missing evidence is a finding or Blocked result, not permission for another invocation.
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
* Return Revise when substantive findings require a plan change; the parent disposes findings and requests revision-bound closure only after an evidenced correction.
* Return Pass when the plan is credible for implementation and any residual risks are explicitly accepted.
* Stop after returning one substantive assessment or preflight/execution limitation. Every reservation consumes its attempt slot; only actual assessment evidence can satisfy the gate. Return infrastructure or unknown outcomes to the planning parent without retrying or inventing findings.

## Handoff

Return critique depth and provenance, execution status, verdict, output path, assessed hash and coverage type, severity summary, highest-impact finding, action owner, smallest next action, and user-response status to the planning parent. When `rpi-plan` ran the critique, the parent revises directly, obtains a significant or divergent user decision when required, and follows revision-bound closure before finalizing a changed candidate. A standalone critique may advise `/rpi-plan` for needed revision but does not invoke it.

## Final response contract

Return depth and provenance, invocation outcome, assessment execution/availability and verdict (unavailable when no assessment was produced), output path, severity counts and highest-impact finding when present, owner, next action and user-response need. Do not invent a finding or verdict for a preflight or transport failure. Keep the response compact and follow Conversation guidance for parent return, standalone advice, artifact links and next steps.
