---
title: Metric selection and tooling
description: How to derive an evaluation metric plan from a system's grounding, tool use, and risk profile, and how to match evaluation tooling to the team's development approach
---

## Selection principle

Select metrics from what the system actually does. A retrieval-grounded assistant and a tool-calling agent fail in different ways, and a uniform metric set measures neither well. Derive the plan from three properties established in the interview: whether the system draws on grounding sources, whether it calls tools, and what its risk profile is.

| System property                       | What it makes measurable                                                                                               |
|---------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| Draws on grounding sources            | Whether answers rest on those sources rather than on model memory, and whether retrieved context is actually used      |
| Calls tools or services               | Whether the right tools were chosen, invoked with correct inputs, and whether their results were used correctly        |
| Carries elevated risk                 | Whether refusal, abstention, fairness, and harmful-content behavior holds under representative and adversarial framing |
| Operates under cost or latency limits | Whether responses arrive within the operating envelope and at acceptable cost                                          |

Always measure whether the system understood what was asked and stayed within its instructions. Those two hold regardless of architecture.

## Evaluator vocabulary

Managed evaluation platforms publish named evaluators. Use those names when the team will run on that platform, so the plan maps directly onto what the tooling reports.

Current agent-oriented evaluator families, cited as factual identifiers, group roughly as follows:

* Outcome-oriented: whether the task was completed, whether the system adhered to its instructions, whether user intent was correctly identified, whether the user would be satisfied, and whether the path taken was efficient.
* Step-oriented: whether tool calls were accurate, whether the right tools were selected, whether tool inputs were correct, whether tool outputs were used, and whether calls succeeded technically.
* Response-quality-oriented: relevance, groundedness, answer completeness, appropriate abstention, and use of available context.
* Responsibility-and-safety-oriented: fairness across confirmed user populations, harmful-content behavior, and groundedness under adversarial framing.

Do not treat this grouping as a frozen catalog. Evaluator names, availability, and preview status change between platform releases, and some evaluators have constrained support depending on which tools an agent uses. Confirm the current set against the authoritative source recorded in [provenance.md](provenance.md) before committing a plan, and record the date you checked.

## Building the plan

For each selected metric, record three things: why this system needs it, what priority it carries relative to the others, and what threshold or qualitative bar counts as acceptable. A metric with no stated bar produces a number nobody can act on.

For every risk named in the confirmed interview summary, record the metric selected to detect it. Keep an unmeasured risk visible and state that no detecting metric is available rather than omitting the row. This is detection coverage, not risk assessment: do not assign severity, likelihood, tier, or approval. Route those decisions to `rai-planner`.

Use the following shape in the metric plan:

| Risk         | Source                      | Detecting metric         |
|--------------|-----------------------------|--------------------------|
| {named risk} | Confirmed interview summary | {metric or `unmeasured`} |

Prioritize from consequence. When a wrong answer is expensive or harmful, groundedness and refusal behavior outrank fluency. When throughput matters, latency and cost move up. State the tradeoff explicitly rather than marking everything high priority.

Note any metric the chosen tooling cannot produce, and say how that dimension will be checked instead, including by human review.

## Tooling

Match tooling to how the team builds and how often they evaluate.

| Team approach                                    | Typical fit                                                                                       |
|--------------------------------------------------|---------------------------------------------------------------------------------------------------|
| Low-code, built in a managed agent platform      | The platform's built-in evaluation surface, using its native evaluators and test sets             |
| Pro-code, integrated into a development pipeline | A programmatic evaluation SDK invoked from the repository, with results stored alongside builds   |
| Mixed                                            | Programmatic evaluation as the system of record, with the platform surface for exploratory review |

Cadence matters as much as capability. Manual review suits early iteration and ambiguous quality questions. Batch evaluation suits regression detection once expectations are stable. Teams that need both should decide which one gates a release.

Recommend one primary option and state why it fits, rather than listing alternatives without a recommendation. Name the prerequisites it carries, such as credentials, deployed judge models, or environment configuration, so the team learns about them before the first run rather than during it.
