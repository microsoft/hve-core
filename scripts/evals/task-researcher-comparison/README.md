# Task Researcher Subagent Comparison

This suite compares Task Researcher outputs with subagents disabled and enabled.

## Variants

| Variant | Command intent | Expected behavior |
|---------|----------------|-------------------|
| `no-subagents` | `/task-research topic="..." subagents=false` | Direct or focused research unless subagents are required to complete the request. |
| `with-subagents` | `/task-research topic="..." subagents=true mode=lanes` | Runs the named lanes in parallel, then synthesizes Codebase Locator, Codebase Analyzer, Codebase Pattern Finder, and Web Search Researcher evidence when external facts are needed. |

## Automated Grading

The deterministic checks run without model credentials. DeepEval `GEval` checks are opt-in and require an LLM provider key.

```bash
npm run eval:task-researcher:compare
DEEPEVAL_RUN_LLM=1 npm run eval:task-researcher:deepeval
```

## Manual Review Rubric

Score each dimension from 0 to 2.

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| Coverage | Misses key source surfaces. | Finds some relevant files or sources. | Covers required local and external surfaces for the scenario. |
| Citation precision | Claims lack citations. | Uses paths or URLs but lacks line/source specificity. | Uses workspace-relative paths with line ranges and clear external URLs. |
| Actionability | No implementation-ready recommendation. | Recommendation exists but lacks concrete next steps. | Gives a selected approach, rejected alternatives, risks, and validation steps. |
| Noise control | Includes broad unrelated research. | Some unnecessary detail. | Focused on the scenario and avoids tangents. |
| Mode compliance | Violates expected mode. | Partially follows mode but over- or under-fans-out. | Matches expected no-subagent behavior or names the lane subagents that should fan out. |

## Interpreting Delta

Prefer `with-subagents` when it improves coverage or actionability by at least 2 total points without losing more than 1 point in noise control. Prefer `no-subagents` when scores are tied and the request is simple or latency-sensitive.

## DeepEval LLM-Judge Mode

DeepEval metrics are optional because they require an LLM provider key. Run deterministic checks first, then opt into LLM judging:

```bash
uv run --project scripts/evals/task-researcher-comparison pytest
DEEPEVAL_RUN_LLM=1 uv run --project scripts/evals/task-researcher-comparison deepeval test run scripts/evals/task-researcher-comparison/tests/test_deepeval_metrics.py
```

The DeepEval score is not a replacement for the manual rubric. Use it to identify deltas that deserve human review.

## Capturing Live Outputs

The comparison tests can grade committed synthetic fixtures or live captured outputs.

Without a runner, the capture helper writes prompt files:

```bash
uv run --project scripts/evals/task-researcher-comparison python -m task_researcher_comparison.capture
```

With a runner, set `TASK_RESEARCHER_RUNNER` to a command template that accepts `{prompt}` and writes the assistant output to stdout:

```bash
TASK_RESEARCHER_RUNNER='your-agent-runner --prompt "{prompt}"' \
  uv run --project scripts/evals/task-researcher-comparison python -m task_researcher_comparison.capture
```
