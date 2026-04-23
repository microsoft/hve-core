---
description: "MVE domain knowledge and coaching conventions for the Experiment Designer agent - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/mve/**'
---

# Experiment Designer: MVE Knowledge Base

Domain knowledge and coaching conventions for Minimum Viable Experimentation (MVE) workflows. These instructions apply automatically when working with MVE session artifacts and guide the Experiment Designer agent through structured experiment design.

## What is an MVE

An MVE unblocks production engineering by validating key hypotheses with fast, focused experimentation. Customers often arrive with ideas that carry unknowns across data, technology, use cases, or design. Jumping into production engineering without first validating those unknowns introduces avoidable risk. An MVE identifies assumptions, defines testable hypotheses, and runs experiments to resolve uncertainty before committing to full-scale development.

### MVE vs MVP

MVEs differ from MVPs in several important ways:

* Focus on finding answers rather than building production code.
* Reduce MVP planning risk by validating or invalidating assumptions early.
* Follow lighter-weight processes and ceremonies than a full MVP.
* Deliver objective, reproducible results using the scientific method.
* Do not produce production-quality code artifacts.
* Emphasize quick results: start soon, keep scope small (a few weeks is typical).
* Succeed whether hypotheses are validated or invalidated; both outcomes are valuable.
* Can be run by a full or partial crew with help from subject matter experts.

### MVE as Enablement (Collaborative Engagements)

In collaborative engineering engagements, MVEs serve a dual purpose:

1. **Validate**: prove that a proposed approach, architecture, or technology works.
2. **Enable**: ensure the partner team gains hands-on experience and can own the outcome independently after the engagement.

The enablement dimension means:

* All work is done jointly with the partner team from scratch. Prior research by the advisory team is preparation so they can guide confidently, not scope reduction.
* The partner team must leave the MVE understanding the full technology stack, not just seeing a working demo.
* Ownership progresses during the engagement: the advisory team leads early, joint ownership mid-engagement, partner team leads in the final phase.
* Enablement is a measurable outcome: "the partner team can replicate the setup independently" is a success criterion alongside hypothesis verdicts.
* Knowledge transfer is embedded in the experiment design through pairing structure, workshops, and progressive handoff.

When designing a collaborative MVE, ask: if all hypotheses are validated but the partner team cannot replicate the outcome, has the MVE succeeded? The answer is no.

| Dimension      | MVE                                         | MVP                                |
|----------------|---------------------------------------------|------------------------------------|
| Goal           | Answer a question or validate an assumption | Deliver a minimum usable product   |
| Scope          | Narrowly focused on one unknown             | Broad enough to provide user value |
| Duration       | Days to weeks                               | Weeks to months                    |
| Team & Process | Partial crew, lightweight ceremonies        | Full crew, standard ceremonies     |
| Deliverables   | Data, findings, recommendation              | Working product increment          |
| Follow-up      | Go/no-go decision informed by evidence      | Iteration toward production        |

## MVE Types

Experiments fall into several categories depending on the unknowns being tested:

* Data feasibility: validate whether available data supports ML or other analytical aims.
* Architectural feasibility: test whether a proposed architecture can meet requirements.
* LLM feasibility: assess whether large language models can solve the target problem effectively.
* Performance, accuracy, or scalability tests: measure whether a solution meets quantitative thresholds.
* Use case validation: confirm that the proposed use case addresses a real need.
* User testing of UX: evaluate whether users can accomplish tasks with the proposed experience.
* End-to-end prototyping: verify that components integrate and function together.
* Hardware integration: test compatibility and performance with physical devices or infrastructure.

## When to Pursue an MVE

MVE-ready questions surface from five primary sources. Cultivate the MVE mindset by asking hard questions wherever unknowns appear.

1. Exploration conversations: gaps, hidden assumptions, and unknowns discovered during MVP discovery signal opportunities for targeted experimentation.
2. Customer requests: specific questions blocking business, engineering, or design decisions indicate hypothesis-ready problems.
3. Product groups: teams exploring new products, patterns, or architectures generate questions that benefit from structured experimentation.
4. Internal projects: gap-filler or speculative work provides space to test ideas without external commitments.
5. Everywhere: any conversation where assumptions go untested is an opportunity to propose an MVE.

## Vetting Criteria

Apply these four questions to determine whether a proposed MVE is worth pursuing.

### Does the MVE make business sense?

Confirm that the experiment involves a priority customer, aligns to high-impact scenarios, has a believable plan if unknowns are unblocked, and has an executive sponsor. Without business alignment, experiment results may not lead to action.

### Can you agree on a crisp, clear problem statement?

A well-defined problem statement is required before formulating hypotheses. If the problem statement itself is unclear, defining it can be the subject of the MVE. Avoid proceeding with vague or shifting problem definitions.

### Have you considered Responsible AI?

Apply RAI thinking even for attenuated experiments. MVEs may involve real user data, biased training sets, or sensitive use cases. Identify potential harms early, even when the experiment is far from production. Probe these dimensions:

* Fairness: could the experiment produce results that disadvantage particular user groups or demographics?
* Reliability and safety: could the experiment cause harm if results are misinterpreted or the prototype is used beyond its intended scope?
* Privacy: does the experiment involve personal data, and are appropriate safeguards in place?
* Transparency: will stakeholders understand what the experiment tests and how results were obtained?
* Accountability: is there a clear owner responsible for acting on results and addressing any harms discovered?

### Are the next steps clear?

Both parties need to know what happens based on outcomes. Define the path forward for validated hypotheses (proceed to MVP, scale the approach) and for invalidated hypotheses (pivot, abandon, redesign). Experiments without clear next steps waste effort.

## Red Flags

Watch for these warning patterns that indicate a proposed engagement is not a true MVE:

* Demos and prototypes: you are being asked to build something to generate interest or impress stakeholders, not to test a hypothesis. This is a demo, not an experiment.
* Skipping ahead: the customer demands a working prototype before validating the assumptions that prototype depends on. Insist on testing assumptions first.
* Solved problems: the question has already been answered elsewhere. If the outcome is already known, there is nothing to experiment on.
* Mini-MVP: the engagement is framed as a smaller version of an MVP rather than as hypothesis testing. An MVE is not a concession or a scaled-down product.
* Low commitment or impact: the team wants to explore for exploration's sake without a clear business driver or decision that depends on the results.
* Customer lacks follow-through capacity: the customer does not have the commitment, expertise, or resources to act on experiment results.
* No next steps: there is no clear path after answering the question. If nobody will act on the results, the experiment adds no value.
* No end users: user-facing projects require user involvement. Without access to real or representative users, user-experience experiments cannot produce valid results.
* Production code expectations: stakeholders expect the experiment code to be production-grade. MVE artifacts are disposable by design.
* Show without teach: the engagement is structured so the partner team watches a demonstration or receives a working artifact but does not participate in building it. In collaborative engagements, if the partner team cannot replicate the outcome independently after the MVE, the enablement purpose is not served. This is a demo disguised as an experiment.

## Hypothesis Format

Structure each hypothesis using this standard format:

```text
We believe [assumption].
We will test this by [method].
We will know we are right/wrong when [measurable outcome].
```

Each hypothesis has three components:

* Assumption: the specific belief or claim being tested. State it clearly enough that it can be confirmed or refuted.
* Method: the concrete approach for testing the assumption. Define what you will build, measure, or observe.
* Measurable outcome: the criteria that determine success or failure. Use quantitative thresholds, observable behaviors, or binary pass/fail conditions.

Rank hypotheses by priority. Address the highest-risk assumptions first, since invalidating a foundational assumption early prevents wasted effort on dependent experiments.

### Expanded Hypothesis Model

For richer hypothesis construction, consider all five components:

* What: the specific outcome or behavior expected.
* Who: the target user, segment, or system.
* Which: the specific feature, variable, or approach being tested.
* How Much: the quantitative threshold for success (percentage, lift, time, cost).
* Why: the rationale connecting the hypothesis to the broader goal.

### Qualities of Good Hypotheses

Effective hypotheses share four properties:

* Testable: the hypothesis can be confirmed or refuted through observation or measurement.
* Specific: the scope is narrow enough to produce a clear answer.
* Rationale-based: the hypothesis connects to a stated reason or business driver.
* Falsifiable: a defined outcome would prove the hypothesis wrong.

## Session Artifacts

All MVE session artifacts live under a structured tracking directory:

```text
.copilot-tracking/mve/{{YYYY-MM-DD}}/{{experiment-name}}/
├── context.md           # Problem statement, customer context, business case
├── hypotheses.md        # Testable hypotheses with priority ranking
├── vetting.md           # Vetting results and red flag assessment
├── experiment-design.md # Approach, scope, timeline, resources, success criteria
├── mve-plan.md          # Consolidated MVE plan document
└── backlog-brief.md     # Requirements bridge for backlog manager consumption (optional)
```

* `context.md` captures the problem statement, customer background, and business justification. This file establishes why the experiment matters and what decision it informs.
* `hypotheses.md` lists testable hypotheses in priority order using the standard hypothesis format. Each hypothesis includes the assumption, test method, and measurable outcome.
* `vetting.md` records the results of applying vetting criteria and the red flag checklist. Document which criteria pass, which raise concerns, and any mitigations.
* `experiment-design.md` defines the technical approach, scope boundaries, timeline estimate, required resources, and success criteria. This file translates hypotheses into an actionable experiment plan.
* `mve-plan.md` consolidates findings from all other artifacts into a single plan document suitable for stakeholder review and approval.
* `backlog-brief.md` reformats experiment hypotheses and success criteria into requirements language for consumption by ADO or GitHub backlog manager agents. This artifact is optional and produced only during Phase 6 when the user wants to transition the experiment into backlog work items.

Include `<!-- markdownlint-disable-file -->` at the top of all markdown files created under `.copilot-tracking/`.

## Backlog Brief Template

Use this template when generating `backlog-brief.md` during Phase 6. Each requirement maps one hypothesis from the MVE plan into acceptance-criteria format suitable for backlog manager consumption.

```text
<!-- markdownlint-disable-file -->

# Backlog Brief: {experiment-name}

## Summary

{2-3 sentence overview derived from problem statement and primary hypothesis}

## Source Experiment

* **MVE Plan**: .copilot-tracking/mve/{date}/{name}/mve-plan.md
* **Experiment Type**: {type from Phase 4}
* **Timeline**: {scope from Phase 4}

## Requirements

### REQ-001: {requirement title derived from hypothesis H1}

{Success criteria for H1 reframed as acceptance criteria}

* Priority: {from hypothesis priority ranking}
* Acceptance Criteria:
  * {criterion 1}
  * {criterion 2}

### REQ-002: {requirement title derived from hypothesis H2}

{Success criteria for H2 reframed as acceptance criteria}

* Priority: {from hypothesis priority ranking}
* Acceptance Criteria:
  * {criterion 1}
  * {criterion 2}

## Dependencies and Resources

{Mapped from experiment design resource requirements}

## Out of Scope

{Items explicitly excluded from the experiment to prevent scope expansion during backlog planning}

## Suggested Labels

experiment, mve, {experiment-type-1}, {experiment-type-2}
```

### Template Field Guidance

* **Summary**: Synthesize from Phase 1 problem statement and Phase 2 primary hypothesis. Write as a requirements overview, not an experiment description.
* **Source Experiment**: Link back to the `mve-plan.md` so backlog managers can trace requirements to their origin.
* **Requirements**: One `REQ-NNN` section per hypothesis. The hypothesis assumption becomes the requirement description. Success criteria from Phase 4 become acceptance criteria. Priority carries from Phase 2 ranking.
* **Dependencies and Resources**: Map directly from Phase 4 experiment design resource requirements.
* **Out of Scope**: Preserve experiment scope boundaries to prevent backlog planning from exceeding the experiment's validated scope.
* **Suggested Labels**: Include `experiment` and `mve` as baseline labels. Add each experiment type from Phase 4 as a separate label (e.g., `data-feasibility`, `llm-feasibility`). Omit unused type placeholders.

## Backlog Bridge Usage Guide

Phase 6 (Backlog Bridge) converts completed experiment outputs into requirements language for backlog managers. Use this phase when a validated experiment should transition into planned work items.

### When to Use

Invoke Phase 6 after completing Phase 5 (MVE Plan) when:

* The experiment produced validated hypotheses ready for development planning.
* Work items need to be created in ADO or GitHub from the experiment findings.

Do not invoke Phase 6 for experiments that are still in progress or produced inconclusive results.

### Inputs and Outputs

* **Input**: Completed `mve-plan.md` from the session tracking directory.
* **Output**: `backlog-brief.md` written to the same session tracking directory.

### Handoff to Backlog Managers

After generating `backlog-brief.md`, provide it to the appropriate backlog manager agent:

* **ADO work items**: Invoke the ADO Backlog Manager agent and pass `backlog-brief.md` as the input document. The agent consumes it via Discovery Path B.
* **GitHub issues**: Invoke the GitHub Backlog Manager agent and pass `backlog-brief.md` as the input document. The agent consumes it via Discovery Path B.

The backlog brief is a bridge document: the backlog manager applies its own platform-specific conventions for titles, labels, sizing, and hierarchy.

## Backlog Bridge Example

End-to-end walkthrough from experiment completion to backlog item creation:

1. Complete Phases 1–5 of the Experiment Designer, producing `mve-plan.md`.
2. Tell the agent you want to create backlog items from the experiment (Phase 6 triggers).
3. The agent reviews `mve-plan.md` and generates `backlog-brief.md` with:
   * Each hypothesis mapped to a REQ-NNN requirement.
   * Success criteria converted to acceptance criteria.
   * Dependencies and out-of-scope items preserved.
4. Review the generated `backlog-brief.md` and confirm it is accurate.
5. Open the ADO or GitHub Backlog Manager agent.
6. Provide `backlog-brief.md` as the input document.
7. The backlog manager's Discovery Path B consumes the brief and produces platform-specific work items. Refer to the backlog manager agent's documentation for output format details.

## Experiment Design Best Practices

Apply these nine practices when designing experiments:

* Test one thing at a time. Isolate a single variable per hypothesis so results are attributable.
* Start with the simplest viable approach. Reduce complexity to accelerate learning.
* Choose metrics before running. Define what you will measure before the experiment begins.
* Set success criteria in advance. Establish quantitative thresholds before seeing results to avoid post-hoc rationalization.
* Control for bias. Use baselines, control groups, or blind evaluation where possible.
* Document the plan before executing. Write down the approach, timeline, and criteria so the team shares a common understanding.
* Minimum but sufficient scope. Build only what is needed to test the hypothesis.
* Include qualitative checks. Supplement quantitative metrics with user feedback or expert observations.
* Plan for iteration. Define what happens if results are inconclusive or mixed.

## Common Pitfalls

These mistakes occur during experiment design and execution. Unlike Red Flags (which screen whether work qualifies as an MVE), pitfalls happen after the experiment is already underway.

* Turning an MVE into a secret MVP. Scope creep transforms the experiment into a product build.
* Skipping problem definition. Jumping to solutions without understanding the problem leads to untestable hypotheses.
* No clear hypothesis. Exploring without a testable question is fishing, not experimentation.
* Ignoring null results. Treating invalidation as failure instead of recognizing it as valuable learning.
* Pivoting mid-experiment. Changing the hypothesis during the test invalidates results.
* Confirmation bias in analysis. Interpreting ambiguous data too optimistically to support a preferred outcome.
* Inadequate run time or sample size. Stopping too early leads to false conclusions.
* Overlooking external factors. Failing to check for anomalies or external events that skew results.
* Not involving the right people. Missing crucial perspectives from data science, UX, or domain experts.
* Lack of next-step plan. Finishing an MVE without acting on findings wastes the learning.
* Treating experiment code as production-ready. MVE code is disposable; reimplement for production.
* Partner team as passive observer. In collaborative engagements, letting the partner team watch instead of drive leads to dependency rather than enablement. Design the experiment so the partner team does the work with guidance, not the other way around.

## Evaluating Results

After running the experiment, analyze outcomes systematically and decide on next steps.

### Analyzing Data

* Apply statistical analysis appropriate to the experiment type.
* Check primary and secondary metrics against the success criteria set in advance.
* Look for anomalies, outlier segments, and confounding factors.
* Distinguish signal from noise: small sample sizes require extra caution. For survey or quantitative experiments, consult a domain expert or statistician to determine adequate sample sizes before drawing conclusions.

### Documenting Learnings

* Restate the hypothesis and the test method.
* Report results with numbers: measured values, sample sizes, confidence levels.
* Interpret what the results mean in context of the original problem.
* Capture qualitative observations alongside quantitative data.
* State next steps based on results.

### Decision Framework

* Go: the hypothesis is validated. Proceed to MVP planning, scale the approach, or apply the finding.
* No-go: the hypothesis is invalidated. Pivot, abandon, or redesign based on what was learned.
* Adjust: results are mixed or inconclusive. Refine the hypothesis, increase sample size, or address confounding factors and re-run.

### When to Iterate vs. When to Stop

* Iterate when results are close to thresholds but not conclusive, when new questions emerge from the data, or when the hypothesis needs refinement.
* Stop when the hypothesis is clearly validated or invalidated, when the learning objective has been achieved, or when further investment would not change the decision.
* Avoid analysis paralysis. Each MVE targets a specific learning objective; declare the result and move on.

## Project Hypothesis Template

Use this structure to organize hypotheses for complex experiments with multiple objectives. This format informs the `hypotheses.md` tracking artifact.

```text
Project Goal
  Business problem, why it needs solving, how the solution would be used,
  value to customer and organization.

Assumptions
  Initiative-level assumptions that underpin the entire project.

Objective 1: [description]
  Relationship to overall goal.
  Assumptions specific to this objective.
  Constraints: non-functional requirements, technology restrictions.
  Evaluation Methodology: experiments, A/B tests, pilot programs.
  Hypotheses:
    H1: We believe [assumption]. We will test this by [method].
        We will know we are right/wrong when [measurable outcome].
    H2: ...

Objective 2: [description]
  (same structure)
```

Each objective groups related hypotheses under shared assumptions and constraints. This hierarchy helps teams trace individual experiments back to business goals and identify dependencies between hypotheses.
