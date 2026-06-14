---
description: "Research template and compact protocol for the task-researcher RPI skill"
---

# Task Researcher Reference

Use this reference for the research phase when the skill needs a planning-ready document rather than a long inline protocol.

## Template

Use [../templates/research.md](../templates/research.md) for `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`.

The template includes these planning-ready sections.

### Scope and Success Criteria

* Scope: capture the task boundary, relevant files, constraints, and any exclusions.
* Assumptions: list what is assumed to be true until verified.
* Success Criteria:
  * Evidence is grounded in actual code, docs, or tooling results.
  * Alternatives are compared with trade-offs.
  * Open gaps are explicit and actionable.

### Research Executed

* Summarize the questions investigated, the sources checked, and the tools or subagents used.
* Record file paths, search terms, and external references with enough detail for downstream planning.
* Note when deeper research was delegated to the Researcher Subagent and where its output lives.

### Key Discoveries

* Capture the most relevant findings, implementation constraints, and project conventions.
* Call out any discovered risks, assumptions, or dependencies that affect planning.

### Technical Scenarios and Alternatives

* Evaluate at least the main viable approaches.
* For each option, note the benefits, trade-offs, complexity, and likely implementation impact.
* Conclude with the recommended approach and rationale based on the evidence gathered.

### Open Questions and Risks

* List unresolved questions, verification gaps, and any decisions that still need confirmation.
* Mark items as blocking, important, or follow-up only.

### Planning Handoff

* Name the selected approach, the primary evidence file, and the next step for `/task-planner`.
* If material gaps remain, repeat the research cycle and update the dated artifact before planning.

## Compact Protocol Detail

1. Create or update the primary dated research artifact first.
2. Dispatch the Researcher Subagent with `runSubagent` or `task` when available, providing the topic, questions, and a dated subagent artifact path.
3. Consolidate findings into the primary research document and keep the document current as new evidence arrives.
4. Run a gap check after each iteration: if the research still misses critical evidence, repeat research rather than guessing.
5. When alternatives are clear, capture them in the document and recommend one approach for planning.

## Deeper Research Re-entry

Re-invoke the task-researcher skill when the current evidence is incomplete, when an alternative needs validation, or when the planning handoff would otherwise proceed on weak assumptions. Update the same dated primary research artifact rather than starting a parallel document.
