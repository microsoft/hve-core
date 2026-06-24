---
description: "Initiate research for implementation planning from user requirements"
agent: Task Researcher
argument-hint: "topic=... [chat={true|false}] [subagents={auto|true|false}]"
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis.
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation.
* ${input:subagents:auto}: (Optional, defaults to auto) Subagent fan-out preference. Use `true` to request all applicable research lanes, `false` to avoid lane fan-out unless required, and `auto` to let Task Researcher apply its trigger matrix.

## Named Subagent Fan-Out

* When `subagents=true` is explicit, run the named lane subagents in parallel.
* Use `Codebase Locator` to map the relevant files, tests, configuration, documentation, schemas, and generated artifacts.
* Use `Codebase Analyzer` to trace implementation behavior, data flow, state changes, error handling, and side effects.
* Use `Codebase Pattern Finder` to collect analogous implementations, reusable helpers, conventions, and anti-patterns.
* Add `Web Search Researcher` only when external documentation, SDK, API, standards, or recent behavior facts are needed.
* Keep `Researcher Subagent` out of lane fan-out unless a focused follow-up is needed after lane synthesis.
* Synthesize named subagent findings into the main research document; do not require separate named-lane artifacts.

## Requirements

1. When chat is enabled, incorporate conversation context to refine research scope and identify implicit constraints.
2. Scope research to the provided topic, including related files, patterns, and external references.
3. Select direct, focused, or lane-enabled research using Task Researcher's trigger matrix and any explicit `subagents` input.
4. Evaluate implementation alternatives and select a recommended approach with evidence-based rationale.
5. Produce a consolidated research document at the standard tracking location for handoff to implementation planning.
