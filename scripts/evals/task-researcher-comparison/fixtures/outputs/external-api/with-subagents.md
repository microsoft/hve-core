# Captured Output Fixture

Scenario: external-api
Variant: with-subagents

## Summary

Validating a Task Researcher change that depends on an external LLM evaluation framework requires understanding both local eval conventions and the external framework's integration approach.

## Evidence

* .github/agents/hve-core/task-researcher.agent.md:15-30 - Local eval validation strategy and integration points.
* evals/README.md:20-45 - Conventions for local-first evaluation and external framework opt-in.

## External Evidence

* <https://deepeval.com/docs/introduction> - DeepEval supports local-first LLM application and agent evaluation.
* <https://deepeval.com/docs/metrics-llm-evals> - GEval supports custom LLM-as-judge criteria.

FAR quality note: Sources are factual, actionable, and relevant for selecting an automated grader.

## Lane Evidence

* Codebase locator lane identified eval integration points and credential patterns.
* Codebase analyzer lane connected local deterministic checks with opt-in LLM-judge tests.
* Codebase pattern finder lane found DeepEval documentation and GEval metric capabilities.
* Web Search Researcher provides current external API and documentation checks when local references are insufficient.

## Recommendation

Establish an automated-plus-manual grading plan that runs deterministic checks locally and opt-in DeepEval checks when provider credentials are available. This validates the change in both environments without breaking CI for users without external credentials. Subagent-enabled variant provides stronger evidence for external framework selection and integration trade-offs.
