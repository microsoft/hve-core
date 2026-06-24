# Captured Output Fixture

Scenario: codebase-lane
Variant: with-subagents

## Summary

Task Researcher should use focused research for small local gaps and fan out to named lanes for medium-hard codebase work.

## Evidence

* .github/agents/hve-core/task-researcher.agent.md:61-74 - Lane Trigger Matrix defines mode selection.
* .github/agents/hve-core/subagents/researcher-subagent.agent.md:10-30 - Researcher subagent response contract includes lane status.
* .github/prompts/hve-core/task-research.prompt.md:11-14 - Command exposes mode and subagents inputs.

## Lane Evidence

* Codebase Locator found the agent, subagent, command, and eval files.
* Codebase Analyzer explained mode selection and synthesis rules.
* Codebase Pattern Finder found existing Vally and uv eval conventions.
* Web Search Researcher is only needed when external facts or current API behavior enter the task.

## Recommendation

Use the no-subagent variant as the latency baseline and compare it against named-lane output for evidence coverage and actionability.
