---
description: Synthetic no-subagent fixture for Task Researcher external API comparison
ms.date: 2026-06-24
---

# Captured Output Fixture

Scenario: external-api
Variant: no-subagents

## Summary

Validating a Task Researcher change that depends on an external LLM evaluation framework requires understanding both local eval conventions and the external framework's integration approach.

## Evidence

* .github/agents/hve-core/task-researcher.agent.md:15-30 - Local eval validation strategy and integration points.
* evals/README.md:20-45 - Conventions for local-first evaluation and external framework opt-in.

## External References

* <https://deepeval.com/docs/introduction> - DeepEval supports local-first LLM application and agent evaluation.

## Recommendation

Establish an automated-plus-manual grading plan that runs deterministic checks locally and opt-in DeepEval checks when provider credentials are available. This validates the change in both environments without breaking CI for users without external credentials.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
