# Captured Output Fixture

Scenario: focused-local
Variant: with-subagents

## Summary

For simple local-only research, Task Researcher should use direct or focused mode without fan-out.

## Evidence

* .github/agents/hve-core/task-researcher.agent.md:45-60 - Trigger Matrix row for simple/medium local work indicates direct or focused mode.
* .github/prompts/hve-core/task-research.prompt.md:5-8 - Command input schema shows mode override capability.

## Recommendation

Direct research without subagents is appropriate for simple local tasks. This approach minimizes latency and avoids unnecessary complexity. Subagent-enabled variant confirms that the system correctly avoids over-fan-out for simple cases.
