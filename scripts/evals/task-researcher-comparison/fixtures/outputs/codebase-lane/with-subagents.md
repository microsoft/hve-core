# Captured Output Fixture

Scenario: codebase-lane
Variant: with-subagents

## Summary

Task Researcher should use focused research for small local gaps and lane-enabled research for medium-hard codebase work.

## Evidence

- .github/agents/hve-core/task-researcher.agent.md:61-74 - Lane Trigger Matrix defines mode selection.
- .github/prompts/hve-core/task-research.prompt.md:11-14 - Command exposes mode and subagents inputs.

## Lane Evidence

- Codebase locator lane found the agent, subagent, command, and eval files.
- Codebase analyzer lane explained mode selection and synthesis rules.
- Codebase pattern finder lane found existing Vally and uv eval conventions.

## Recommendation

Use the no-subagent variant as the latency baseline and compare it against lane-enabled output for evidence coverage and actionability.
