---
description: "Orchestration reference for the Research, Plan, Implement, Review, and Follow-up RPI lifecycle."
---

# RPI Orchestration Reference

## Lifecycle

1. Assess research readiness from caller-supplied research, task details, decisions, and plan inputs. Activate `rpi-research` only when evidence is missing, stale, contradictory, insufficient for planning, or when complexity, uncertainty, dependencies, risk, or a decision-critical question warrants investigation. When evidence is adequate, record why Research is reused or satisfied-and-skipped.
2. Run Plan to create or revise marker-addressed plan and phase-detail artifacts. Its independent critique is an internal planning gate and returns to the planning parent.
3. Run Implement to complete approved `Pxx` and `Pxx-Txx` tasks and record changes, validation, divergences, and amendments. For a significant or divergent amendment, pause affected work, obtain the user decision, and update the current plan without repeating critique.
4. Run Review once after Implement to compare all planning and execution evidence, then separate execution status from outcome.
5. Follow-up routes open work to research, planning, implementation, or a distinct future item.

`rpi-quick` is the explicit parent that continues to an eligible next stage without a new user command. It does not bypass a stage gate, blocker, risky-action confirmation, or user-owned decision. A standalone child stage returns its evidence and advice to this parent; it does not self-sequence peer lifecycle stages.

## Artifact path matrix

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

Reuse the dated task artifacts in place. Use plain-text workspace-relative paths and the stable task, phase, task, change, divergence, amendment, critique, and review IDs.

## Follow-up routing

* Defect: offer later `rpi-implement` work.
* Decision gap or unsupported plan assumption: offer later `rpi-plan` work.
* Evidence gap: offer later `rpi-research` work.
* Residual work outside accepted scope: create a distinct follow-up item.

## Lifecycle discipline

Do not create a phase for ceremonial completeness. Research may be reused or satisfied-and-skipped when the readiness assessment finds adequate evidence, and must not be reported as executed in that case. A significant or divergent implementation amendment pauses affected work until its user decision and current plan are reconciled. Preserve durable evidence and report validation truthfully as passed, failed, skipped, or unavailable.

## Conversation and closeout

Give concise updates at material stage boundaries. State the current stage and why it is eligible, changes or findings, decisions, blockers, results, relevant artifact links, and one important point the user might otherwise miss. Before a question or required confirmation, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

At closeout, report lifecycle execution or session status separately from outcome or decision state. Include the current results, important updates, decisions, and blockers or open items. Advise `/compact` only when stale output, superseded reasoning, or completed-stage detail outweighs current context and durable phase artifacts are current. When advising it, name the retained state and artifact pointers. Otherwise omit compaction guidance.

State that the parent continues automatically when another stage is eligible. State the exact confirmation or blocker when control returns to the user. End the user-facing closeout with a Markdown table linking every relevant existing artifact and a short description. Keep the table as the final response element.
