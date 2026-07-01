---
description: "Research template and protocol for the task-researcher RPI skill"
---

# Task Researcher Reference

Use this reference for the research phase when the skill needs a planning-ready document.

## Template

Use [../templates/research.md](../templates/research.md) for `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`.

* Derive `{{task_slug}}` from the primary research target with lower-kebab-case.
* Replace `YYYY-MM-DD` with the current date at execution time.

The template includes these planning-ready sections.

### Scope and Success Criteria

* Scope: capture the task boundary, relevant files, constraints, and any exclusions.
* Assumptions: list what is assumed to be true until verified.
* Success Criteria:
  * Evidence is grounded in actual code, docs, or tooling results.
  * Alternatives are compared with trade-offs and one selected approach is justified with rationale.
  * Open gaps are explicit and actionable.

### Task Research Requests

* Capture the user's explicit requests and any inferred research questions.
* Record caller constraints, including research-only, no handoff, analysis, audit, or comparison boundaries.
* Note expected outcomes and non-goals before expanding the research scope.

### Research Executed

* Summarize the questions investigated, the sources checked, and the tools or subagents used.
* Record file paths, search terms, and external references with enough detail for downstream planning.
* Note when deeper research was delegated to the Researcher Subagent and where its output lives.
* If research was performed inline because `runSubagent` and `task` were unavailable, record the fallback reason.

### Evidence Log

* Record workspace-relative file paths and line ranges for the most important evidence.
* Group code search results by search term when search results materially informed the recommendation.
* Keep evidence concise enough for planning while preserving enough context to audit the recommendation.

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

### Potential Next Research

* List optional follow-up research that would improve confidence but is not required for the current handoff.
* Include the reason each item matters and the evidence or source that triggered it.

### Planning Handoff

* Name the selected approach, the primary evidence file, and the next step for `/rpi-plan` when normal RPI progression is requested.
* If the caller requested research-only, no handoff, analysis, audit, or comparison output, state that `/rpi-plan` was intentionally skipped and why.
* If material gaps remain, repeat the research cycle and update the dated artifact before planning.

### Artifact Self-Check

* When no executable validation is run, call the final check an artifact self-check.
* List the checked sections rather than saying validation confirmed the artifact.
* Record any missing sections or known limitations before responding.

### Subagent Return Contract

* Return the subagent research artifact path at `.copilot-tracking/research/subagents/YYYY-MM-DD/<topic>-research.md`.
* Report the current status and the most important findings.
* Record recommended next research items and clarifying questions.
* Keep the output evidence-linked and use it to update the primary research artifact rather than to replace it.

### Operational Contract

1. Research and analysis are the two linked phases; move from evidence gathering to synthesis, then re-enter research while material gaps remain.
2. When chat is enabled, incorporate conversation context to refine scope and surface implicit constraints before drafting the research artifact.
3. Write the primary research artifact under `.copilot-tracking/research/YYYY-MM-DD/` and keep it current as new evidence arrives.
4. Use `Researcher Subagent` via `runSubagent` or `task` when either dispatch tool is available; if dispatch tooling is unavailable, perform the equivalent research inline and record the fallback reason in the same primary artifact.
5. After subagent work, summarize the artifact path, status, key findings, recommended next research, and any clarifying questions in the primary research document.
6. Hard stop only on missing required input, an unresolvable task, or an unwritable research path.

### Document Management

* Keep the primary evidence document in `.copilot-tracking/research/YYYY-MM-DD/`.
* Keep delegated evidence in `.copilot-tracking/research/subagents/YYYY-MM-DD/` when subagent dispatch is used.
* Research references guide implementation logic during downstream RPI phases; do not direct that `.copilot-tracking/` paths or internal workflow artifact references be reproduced in production code, code comments, documentation strings, commit messages, or artifacts outside `.copilot-tracking/`.
* Use plain workspace-relative file paths in research artifacts, and do not invent parallel evidence stores.

## Protocol Detail

1. Create or update the primary dated research artifact first.
2. Dispatch the Researcher Subagent with `runSubagent` or `task` when available, providing the topic, questions, and a dated subagent artifact path.
3. If dispatch tooling is unavailable, perform the equivalent research inline and record the fallback reason in the same primary artifact.
4. Capture the subagent return contract in the primary document: artifact path, status, key findings, recommended next research, and clarifying questions.
5. Consolidate findings into the primary research document and keep the document current as new evidence arrives.
6. Run a gap check after each iteration: if the research still misses critical evidence, repeat research rather than guessing.
7. When alternatives are clear, capture them in the document, evaluate each option, and recommend one approach for planning.

## Final Response Contract

Return a concise, evidence-first response with:

* Research artifact path.
* Selected approach and rationale.
* Rejected alternatives or lower-ranked options.
* Key evidence with workspace-relative paths.
* Open questions and risks.
* Constraint status, including whether planning and implementation were avoided.
* Artifact self-check status, listing required sections checked when no executable validation ran.
* Handoff status, either `/rpi-plan` with the dated artifact path or an explicit no-handoff reason.

## Deeper Research Re-entry

Re-invoke the rpi-research skill when the current evidence is incomplete, when an alternative needs validation, or when the planning handoff would otherwise proceed on weak assumptions. Update the same dated primary research artifact rather than starting a parallel document.
