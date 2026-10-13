---
name: rpi-plan-critique
description: "Independently assess an RPI plan without editing it. Use when an implementation-ready plan needs a credibility check or a revised plan needs its earlier findings reconciled."
argument-hint: "[plan=...] [evidence=...] [output=...] [depth={standard|deep}] [prior=...]"
license: MIT
user-invocable: true
---

# RPI Plan Critique

## Goal

Return one substantive, evidence-grounded credibility assessment of an RPI implementation plan. Assess the plan against the supplied evidence with fresh eyes rather than the drafting reasoning. Complete the material assessment as quickly as the supplied evidence permits by default; broaden depth only when the user explicitly requests `deep`. The critique is read-only with respect to the plan and writes only the caller-specified critique artifact.

## Flow

1. Confirm the task identity, plan, evidence, requirements, decisions, dependencies, task Requirements, critique output path, and critique depth supplied by the caller. Use `standard` when depth is omitted. Use `deep` only when the caller records explicit user direction; otherwise downgrade an unsupported deep request to standard and record the limitation. Standalone use needs only these inputs; no planning parent is required.
2. Read the plan, directly relevant supplied evidence, and the earlier critique when one is supplied. Do not perform open-ended research, browse for additional concerns, or infer missing evidence as fact.
3. Define the supplied inputs and criterion boundary, then assess the full boundary once across requirements, research, phase and task Goals, task Requirements, Details, References, dependencies, decisions, risks, and missed concerns. For a follow-up critique, mark each earlier finding resolved, still open, or superseded against the current plan, and add new findings for gaps the revision introduced.
   * Assess coverage across the supplied plan and evidence as a whole. Do not require a task to repeat requirements already established elsewhere solely for restatement. A stated requirement alone does not prove implementation coverage; ground required changes in demonstrated omissions, contradictions, or material evidence gaps.
   * Treat missing detail in an abbreviated task or excerpt as a limitation of the supplied evidence, not proof that the full plan omits it. Identify the evidence needed to resolve a decision-critical uncertainty; do not turn the same uncertainty into a separate requirement-restatement finding.
   * In `standard`, assess the complete supplied boundary while prioritizing implementation blockers, contradictions, missing dependencies or acceptance coverage, unsupported scope or architecture, and material risks. Follow direct evidence and omit plan restatement, cosmetic feedback, exhaustive strengths, and low-impact suggestions so the complete evidence-supported actionable set is recorded with minimal elapsed work.
   * In `deep`, trace supplied evidence more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns. Deep remains one assessment and does not widen research authority.
   * In either depth, return one complete finding set rather than serializing findings across critique passes.
4. Write the critique using [templates/plan-critique.md](templates/plan-critique.md). Use severity-graded `PC-xxx` findings keyed to relevant requirement, research, phase, or task IDs. For each actionable finding, name the smallest useful change, action owner, exact resolving evidence, and whether it is a direct planner correction or needs a significant or divergent user decision. A follow-up critique continues the earlier `PC-xxx` numbering and records each earlier finding's reconciled status.
5. Record critique execution as Complete, Partial, or Blocked, separately from its Pass, Revise, or Blocked verdict. A passing critique may identify residual risks the parent explicitly accepted. When no assessment was produced, return that limitation with verdict unavailable and preserve any fragments; do not manufacture a verdict.

## Inputs

* Plan path
* Caller requirements and task context
* Supplied research, evidence pointers, draft details, and decisions
* Dependencies and task Requirements
* One critique output path
* The earlier critique when this is a follow-up critique
* Critique depth and provenance: `standard` by default or `deep` from explicit user direction

## Success criteria

* The critique distinguishes evidence-backed concerns from missing evidence.
* Critique depth and provenance are recorded. Standard completely assesses the material supplied boundary while minimizing low-value work; deep occurs only from explicit user direction.
* Standalone use works without a planning parent. A follow-up critique reconciles every earlier finding as resolved, still open, or superseded rather than repeating it.
* Findings identify substantive gaps rather than structure, formatting, or cosmetic preferences.
* The critique records its inputs, criterion boundary, coverage assessment, and limitations.
* Each actionable finding has a severity, related IDs, evidence, impact, and smallest useful change.
* Each actionable finding identifies its action owner, exact resolving evidence, and whether it is a direct correction or requires a significant or divergent user decision.
* The critique returns one complete actionable finding set for the supplied boundary; cosmetic preferences and separately withheld late findings do not create serial passes.
* A run that produced no assessment reports its limitation with verdict unavailable, never Pass.
* The closeout identifies the highest-impact finding, action owner, smallest next action, and whether a user response is required.
* The plan remains unchanged.

## Constraints

* Do not edit the plan, research, changes, or review records.
* Do not perform research beyond the supplied inputs. Route a material research gap to the planning parent as a Blocked or Revise finding.
* Do not grade formatting, document cosmetics, or template adherence unless the issue conceals a substantive planning risk.
* Confirmed user requests and answers outrank critique advice. A conflicting recommendation is rejected when current user direction already resolves it. Classify a significant or divergent issue as a user decision only when current user direction does not resolve it.
* Do not invoke this skill recursively or request another critique; the planning parent or user decides whether a follow-up critique runs. Missing evidence is a finding or Blocked result.
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
* Return Revise when substantive findings require a plan change; the parent disposes findings and decides whether a follow-up critique runs.
* Return Pass when the plan is credible for implementation and any residual risks are explicitly accepted.
* Stop after returning one assessment or execution limitation. Return a failed or incomplete run to the caller without retrying or inventing findings.

## Handoff

Return critique depth and provenance, execution status, verdict, output path, critique type (initial or follow-up), severity summary, highest-impact finding, action owner, smallest next action, and user-response status to the planning parent. When `rpi-plan` ran the critique, the parent revises directly, obtains a significant or divergent user decision when required, and decides whether a follow-up critique is warranted. A standalone critique may advise `/rpi-plan` for needed revision but does not invoke it.

## Final response contract

Return depth and provenance, execution status and verdict (unavailable when no assessment was produced), output path, severity counts and highest-impact finding when present, owner, next action and user-response need. Do not invent a finding or verdict for a failed run. Keep the response compact and follow Conversation guidance for parent return, standalone advice, artifact links and next steps.
