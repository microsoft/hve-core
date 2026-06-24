# External Evaluation Framework Research

The selected mode is `subagents=true mode=lanes` with external research because the task depends on current DeepEval behavior.

## Named Lane Findings

* Codebase Locator maps evals/README.md:1-80, .github/agents/hve-core/task-researcher.agent.md, and scripts/evals/task-researcher-comparison/README.md:12-46.
* Codebase Analyzer traces local deterministic grading in scripts/evals/task-researcher-comparison/task_researcher_comparison/static_metrics.py:59-71.
* Codebase Pattern Finder compares this harness with existing eval conventions in evals/README.md:1-80.
* Web Search Researcher (.github/agents/hve-core/subagents/web-search-researcher.agent.md) checks the external source https://deepeval.com/docs/introduction for current DeepEval behavior.

## FAR Quality Note

The DeepEval source is factual because it is vendor documentation, actionable because it explains the current framework entry point, and relevant because this task depends on optional LLM-judge behavior.

## Recommendation

Combine local eval evidence with external framework evidence, then synthesize the selected validation approach into the main research document.
