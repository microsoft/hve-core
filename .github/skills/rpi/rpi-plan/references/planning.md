---
description: "Reference protocol for evidence-based RPI planning, bounded phase authoring, and independent plan critique."
---

# RPI Plan Reference

## Artifact paths

Use one date and one lower-kebab-case task slug across the task's durable artifacts.

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

The research, changes, and review paths belong to their respective RPI stages. Planning creates or revises only the plan, phase details, and critique artifact unless a justified research activation is required.

## Identity and markers

Use one stable task ID throughout the artifact set. Use `Pxx` for phase IDs and `Pxx-Txx` for task IDs. Put each marker immediately before its matching heading:

```markdown
<!-- rpi:phase id=P01 -->
### [ ] P01: Establish the change

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Update the primary artifact
```

The plan owns amendment IDs in the form `AM-xxx`. Do not use line numbers, line ranges, detail-line verification, or separate legacy log artifacts. Navigate by task ID, marker, and heading.

## Executive summary

Every plan checklist includes a user-facing `## Executive Summary` immediately after `## Task Metadata` and before `## Sources`. It gives readers a useful overview before the detailed evidence, scope, and phases.

Include these elements when evidence supports them:

* Explain, in approachable language, what the plan will implement and why the outcome matters.
* Highlight material decisions and their practical consequences.
* Include a `### What You May Not Know` subsection for important context, dependencies, risks, or constraints that a user might otherwise miss.
* State unresolved decisions or blockers and the next action when they remain. Do not present an unsupported assumption as a settled decision.

Keep summary claims synchronized with the evidence and the detailed plan. Do not invent claims, decisions, resources, risks, or links. Link to same-plan sections when navigation helps, and add an authoritative external explanatory link only when supplied evidence supports it and it materially improves comprehension. Keep workspace-relative paths as plain text, not Markdown links.

Use readable Markdown selectively: concise paragraphs and lists for structure, bold for essential reader attention, and italics when introducing a term. Plain Markdown has no underline syntax. Use renderer-specific underline only when the generated tracking artifact's renderer is known to support it and the emphasis is essential; pair it with a plain-Markdown fallback, preferably bold. Do not use underline as decoration or repeat it for routine emphasis.

Update the executive summary after every material plan change, including critique-driven revisions, amendments, decisions or their consequences, scope, phases, dependencies, acceptance criteria, risks, and readiness. Before critique handoff and again before finalization, reconcile the summary with the current plan. Summary synchronization is a readiness condition.

## Research readiness

Read and understand the supplied research before deciding whether to activate `rpi-research`. Additional research is justified only when at least one condition holds:

* Evidence does not cover a requirement, acceptance criterion, dependency, or material risk needed for planning.
* The task's complexity or uncertainty makes a plan speculative.
* A decision-critical choice has multiple plausible outcomes without credible supporting evidence.

When none apply, plan from the supplied evidence. When one applies, ask `rpi-research` for the smallest evidence set that closes the gap, then resume planning.

## Overall planning and bounded phase authoring

The planning parent owns task scope, phase order, dependencies, decision register, amendment register, critique disposition, and finalization. It may delegate one bounded phase to `RPI Planner` when that phase needs isolated authoring effort.

A `RPI Planner` dispatch contains:

* The complete overall plan outline
* One exact `Pxx` phase assignment
* Caller requirements and evidence pointers
* Exact plan and phase-details paths
* An allowed write boundary limited to that phase in those two artifacts

The worker preserves other phases, resolves supported local choices, and records assumptions or questions when evidence is insufficient. It does not research, implement, review, or redesign the overall plan.

## Independent critique

After the plan and phase details exist, dispatch a fresh generic native critique worker through `runSubagent` that activates `rpi-plan-critique`. Give it exact paths and evidence, including the task context, requirements, research, draft content, decisions, dependencies, acceptance criteria, plan path, details path, and a single critique output path. The critique worker reads plan sources and writes only the critique artifact.

Use the critique verdict to select the smallest next action:

* Revise the plan directly for a localized evidence-backed correction.
* Dispatch `RPI Planner` for one `Pxx` phase when only that phase needs deeper authoring.
* Ask a small set of decision-critical questions when a missing choice cannot be inferred.
* Rerun critique after material changes.
* Finalize when the critique passes or recorded dispositions justify residual risk.

## Detail quality

Phase details describe context, intent, boundaries, likely targets, dependencies, validation expectations, completion evidence, and unresolved items. They ground execution in evidence without inventing a procedural choreography that the evidence does not support.

## Final planning handoff

The final plan identifies the implementation handoff with task IDs, markers, and artifact paths. The final user-facing planning response concisely restates the executive-summary outcome, important decisions and consequences, information the user may not immediately know, and unresolved decisions or blockers before naming artifact paths and the next RPI stage. It does not create a separate legacy log artifact or require a line-based verification pass.
