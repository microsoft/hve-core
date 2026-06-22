# Captured Output Fixture

Scenario: codebase-lane
Variant: no-subagents

## Summary

Task Researcher should use focused research for small local gaps and lane-enabled research for medium-hard codebase work.

## Evidence

- .github/agents/hve-core/task-researcher.agent.md:61-74 - Lane Trigger Matrix defines mode selection.
- .github/prompts/hve-core/task-research.prompt.md:11-14 - Command exposes mode and subagents inputs.

## Recommendation

Use the no-subagent variant as the latency baseline and compare it against lane-enabled output for evidence coverage and actionability.
