---
description: Synthetic lane-mode fixture for Task Researcher codebase-lane comparison
ms.date: 2026-06-24
---

# Task Researcher Mode Selection Research

The selected mode is `subagents=true mode=lanes` because the request asks for medium-hard codebase research across agent instructions, prompts, tests, and generated artifacts.

## Named Lane Findings

* Codebase Locator maps .github/agents/hve-core/task-researcher.agent.md:55-115, .github/agents/hve-core/subagents/codebase-locator.agent.md, .github/agents/hve-core/subagents/codebase-analyzer.agent.md, .github/agents/hve-core/subagents/codebase-pattern-finder.agent.md, .github/prompts/hve-core/task-research.prompt.md:9-31, and scripts/evals/task-researcher-comparison/fixtures/scenarios.yml:1-50.
* Codebase Analyzer traces how mode selection flows from the slash-command inputs into Task Researcher's trigger matrix at .github/agents/hve-core/task-researcher.agent.md:55-76.
* Codebase Pattern Finder compares the named subagent structure with existing hve-core subagents under .github/agents/hve-core/subagents/.

## Recommendation

Use the three local codebase lanes in parallel, then synthesize their findings into the primary `.copilot-tracking/research/{{YYYY-MM-DD}}/<topic>-research.md` document. Do not add external research lanes unless external framework or API facts are needed.

## Validation

Run `npm run eval:task-researcher:compare`, regenerate `evals/agent-behavior/eval.yaml`, and regenerate plugin outputs after source changes.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
