---
description: "Research template and protocol for the RPI Researcher skill"
---

# RPI Researcher Reference

Use this reference when the research phase needs a planning-ready document.

## Template

Use [../templates/research.md](../templates/research.md) for .copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md.

* Derive `{{task_slug}}` from the primary research target with lower-kebab-case.
* Replace `YYYY-MM-DD` with the current date at execution time.
* When a trusted sandbox or caller-owned evidence root is provided, mirror the same research/YYYY-MM-DD/{{task_slug}}-research.md shape under that root and record the resolved root.

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

### Recommended Next Step

* Name the selected approach, the primary evidence file, and the advisory next-step recommendation for `/rpi-plan` when normal RPI progression is requested.
* State that the user or rpi-quick owns acting on the recommendation.
* If the caller requested research-only, no handoff, analysis, audit, or comparison output, state why no planning recommendation is made.
* If material gaps remain, repeat the research cycle and update the dated artifact before planning.

### Artifact Self-Check

* When no executable validation is run, call the final check an artifact self-check.
* List the checked sections rather than saying validation confirmed the artifact.
* Record any missing sections or known limitations before responding.

### Subagent Return Contract

* Return the subagent research artifact path at .copilot-tracking/research/subagents/YYYY-MM-DD/<topic>-research.md.
* Report the current status and the most important findings.
* Record recommended next research items and clarifying questions.
* Keep the output evidence-linked and use it to update the primary research artifact rather than to replace it.

## Protocol

1. Resolve the primary research artifact path before dispatching subagents.
2. Incorporate enabled chat context before drafting the artifact.
3. Use `Researcher Subagent` via `runSubagent` or `task` when available; otherwise perform equivalent inline research and record the fallback reason.
4. Consolidate delegated findings into the primary artifact and repeat while material gaps remain.
5. Keep delegated evidence under .copilot-tracking/research/subagents/YYYY-MM-DD/ or the mirrored subagent path under a trusted root.
6. Reject alternate roots with traversal, source artifact directories, or unrelated destinations.
7. Keep .copilot-tracking/ references out of production code, code comments, documentation strings, commit messages, and artifacts outside .copilot-tracking/.

## Final Response Contract

Return a concise, evidence-first response with:

* Research artifact path.
* Selected approach and rationale.
* Rejected alternatives or lower-ranked options.
* Key evidence with workspace-relative paths.
* Open questions and risks.
* Constraint status, including whether planning and implementation were avoided.
* Artifact self-check status, listing required sections checked when no executable validation ran.
* Advisory next-step recommendation, either `/rpi-plan` with the dated artifact path or an explicit no-planning reason.

## Deeper Research Re-entry

Re-invoke the rpi-research skill when the current evidence is incomplete, when an alternative needs validation, or when the planning recommendation would otherwise rely on weak assumptions. Update the same dated primary research artifact rather than starting a parallel document.
