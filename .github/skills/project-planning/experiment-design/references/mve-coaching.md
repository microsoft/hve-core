---
title: MVE coaching
description: Minimum Viable Experiment domain knowledge covering definition, types, vetting criteria, red flags, hypothesis construction, experiment design, evaluation, and the backlog bridge
---

## Source

This is HVE Core original coaching material. It is not derived from the Microsoft CSE engineering playbook. For ML environments, reproducibility, experiment tracking, model evaluation, abstractions, and production-readiness conventions, use `ml-experimentation`.

## What is an MVE

An MVE unblocks production engineering by validating key hypotheses with fast, focused experimentation. Customers often arrive with ideas that carry unknowns across data, technology, use cases, or design. Jumping into production engineering without first validating those unknowns introduces avoidable risk. An MVE identifies assumptions, defines testable hypotheses, and runs experiments to resolve uncertainty before committing to full-scale development.

### MVE versus MVP

MVEs differ from MVPs in several important ways:

* Focus on finding answers rather than building production code.
* Reduce MVP planning risk by validating or invalidating assumptions early.
* Follow lighter-weight processes and ceremonies than a full MVP.
* Deliver objective, reproducible results using the scientific method.
* Do not produce production-quality code artifacts.
* Emphasize quick results: start soon, keep scope small, with a few weeks being typical.
* Succeed whether hypotheses are validated or invalidated; both outcomes are valuable.
* Can be run by a full or partial crew with help from subject matter experts.

| Dimension        | MVE                                         | MVP                                |
|------------------|---------------------------------------------|------------------------------------|
| Goal             | Answer a question or validate an assumption | Deliver a minimum usable product   |
| Scope            | Narrowly focused on one unknown             | Broad enough to provide user value |
| Duration         | Days to weeks                               | Weeks to months                    |
| Team and process | Partial crew, lightweight ceremonies        | Full crew, standard ceremonies     |
| Deliverables     | Data, findings, recommendation              | Working product increment          |
| Follow-up        | Go/no-go decision informed by evidence      | Iteration toward production        |

### MVE as enablement in collaborative engagements

In collaborative engineering engagements, MVEs serve a dual purpose:

1. **Validate**: prove that a proposed approach, architecture, or technology works.
2. **Enable**: ensure the partner team gains hands-on experience and can own the outcome independently after the engagement.

The enablement dimension means:

* All work is done jointly with the partner team from scratch. Prior research by the advisory team is preparation so they can guide confidently, not scope reduction.
* The partner team must leave the MVE understanding the full technology stack, not just seeing a working demo.
* Ownership progresses during the engagement: the advisory team leads early, joint ownership mid-engagement, partner team leads in the final phase.
* Enablement is a measurable outcome. "The partner team can replicate the setup independently" is a success criterion alongside hypothesis verdicts.
* Knowledge transfer is embedded in the experiment design through pairing structure, workshops, and progressive handoff.

When designing a collaborative MVE, ask: if all hypotheses are validated but the outcome cannot be replicated independently, has the MVE succeeded? The answer is no.

## MVE types

Experiments fall into several categories depending on the unknowns being tested:

* Data feasibility: validate whether available data supports ML or other analytical aims.
* Architectural feasibility: test whether a proposed architecture can meet requirements.
* LLM feasibility: assess whether large language models can solve the target problem effectively.
* Performance, accuracy, or scalability tests: measure whether a solution meets quantitative thresholds.
* Use case validation: confirm that the proposed use case addresses a real need.
* User testing of UX: evaluate whether users can accomplish tasks with the proposed experience.
* End-to-end prototyping: verify that components integrate and function together.
* Hardware integration: test compatibility and performance with physical devices or infrastructure.

## When to pursue an MVE

MVE-ready questions surface from five primary sources:

1. Exploration conversations: gaps, hidden assumptions, and unknowns discovered during MVP discovery.
2. Customer requests: specific questions blocking business, engineering, or design decisions.
3. Product groups: teams exploring new products, patterns, or architectures.
4. Internal projects: gap-filler or speculative work that provides space to test ideas without external commitments.
5. Everywhere: any conversation where assumptions go untested is an opportunity to propose an MVE.

## Vetting criteria

Apply these four questions to determine whether a proposed MVE is worth pursuing.

### Does the MVE make business sense

Confirm that the experiment involves a priority customer, aligns to high-impact scenarios, has a believable plan if unknowns are unblocked, and has an executive sponsor. Without business alignment, experiment results may not lead to action.

### Can you agree on a crisp, clear problem statement

A well-defined problem statement is required before formulating hypotheses. If the problem statement itself is unclear, defining it can be the subject of the MVE. Avoid proceeding with vague or shifting problem definitions.

### Have you considered Responsible AI

Apply RAI thinking even for attenuated experiments. MVEs may involve real user data, biased training sets, or high-risk scenarios. Identify potential harms early, even when the experiment is far from production. Probe these dimensions:

* Fairness: could the experiment produce results that disadvantage particular user groups or demographics?
* Reliability and safety: could the experiment cause harm if results are misinterpreted or the prototype is used beyond its intended scope?
* Privacy: does the experiment involve personal data, and are appropriate safeguards in place?
* Transparency: will stakeholders understand what the experiment tests and how results were obtained?
* Accountability: is there a clear owner responsible for acting on results and addressing any harms discovered?

### Are the next steps clear

Both parties need to know what happens based on outcomes. Define the path forward for validated hypotheses, such as proceeding to MVP or scaling the approach, and for invalidated hypotheses, such as pivoting, abandoning, or redesigning. Experiments without clear next steps waste effort.

## Red flags

Watch for these warning patterns that indicate a proposed engagement is not a true MVE:

* Demos and prototypes: you are being asked to build something to generate interest or impress stakeholders, not to test a hypothesis.
* Skipping ahead: the customer demands a working prototype before validating the assumptions that prototype depends on.
* Solved problems: the question has already been answered elsewhere, so there is nothing to experiment on.
* Mini-MVP: the engagement is framed as a smaller version of an MVP rather than as hypothesis testing.
* Low commitment or impact: the team wants to explore without a clear business driver or dependent decision.
* Customer lacks follow-through capacity: the customer does not have the commitment, expertise, or resources to act on results.
* No next steps: nobody will act on the results, so the experiment adds no value.
* No end users: user-facing projects require user involvement; without real or representative users, UX experiments cannot produce valid results.
* Production code expectations: stakeholders expect experiment code to be production-grade. MVE artifacts are disposable by design.
* Show without teach: the partner team watches a demonstration or receives a working artifact but does not participate in building it. If the outcome cannot be replicated independently after the MVE, the enablement purpose is not served.

## Hypothesis format

Structure each hypothesis using this standard format:

```text
We believe [assumption].
We will test this by [method].
We will know we are right/wrong when [measurable outcome].
```

Each hypothesis has three components:

* Assumption: the specific belief or claim being tested, stated clearly enough to be confirmed or refuted.
* Method: the concrete approach for testing the assumption, defining what you will build, measure, or observe.
* Measurable outcome: the criteria that determine success or failure, using quantitative thresholds, observable behaviors, or binary pass/fail conditions.

Rank hypotheses by priority. Address the highest-risk assumptions first, since invalidating a foundational assumption early prevents wasted effort on dependent experiments.

### Expanded hypothesis model

For richer hypothesis construction, consider all five components:

* What: the specific outcome or behavior expected.
* Who: the target user, segment, or system.
* Which: the specific feature, variable, or approach being tested.
* How Much: the quantitative threshold for success, such as percentage, lift, time, or cost.
* Why: the rationale connecting the hypothesis to the broader goal.

### Qualities of good hypotheses

Effective hypotheses share four properties:

* Testable: the hypothesis can be confirmed or refuted through observation or measurement.
* Specific: the scope is narrow enough to produce a clear answer.
* Rationale-based: the hypothesis connects to a stated reason or business driver.
* Falsifiable: a defined outcome would prove the hypothesis wrong.

## Session artifacts

MVE sessions produce a small set of artifacts. Directory placement, filenames, and tracking-file hygiene are conventions applied automatically by `experiment-designer.instructions.md`; the purpose of each artifact is described here.

* Context: the problem statement, customer background, and business justification. Establishes why the experiment matters and what decision it informs.
* Hypotheses: testable hypotheses in priority order using the standard format, each with assumption, test method, and measurable outcome.
* Vetting: results of applying the vetting criteria and red flag checklist, documenting which criteria pass, which raise concerns, and any mitigations.
* Experiment design: the technical approach, scope boundaries, timeline estimate, required resources, and success criteria.
* MVE plan: findings from all other artifacts consolidated into a single plan document suitable for stakeholder review and approval.
* Backlog brief: experiment hypotheses and success criteria reformatted into requirements language for backlog managers. Optional, produced only when the user wants to transition the experiment into backlog work items.

## Experiment design best practices

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

## Common pitfalls

These mistakes occur during experiment design and execution. Unlike red flags, which screen whether work qualifies as an MVE, pitfalls happen after the experiment is already underway.

* Turning an MVE into a secret MVP. Scope creep transforms the experiment into a product build.
* Skipping problem definition. Jumping to solutions without understanding the problem leads to untestable hypotheses.
* No clear hypothesis. Exploring without a testable question is fishing, not experimentation.
* Ignoring null results. Treating invalidation as failure instead of valuable learning.
* Pivoting mid-experiment. Changing the hypothesis during the test invalidates results.
* Confirmation bias in analysis. Interpreting ambiguous data too optimistically to support a preferred outcome.
* Inadequate run time or sample size. Stopping too early leads to false conclusions.
* Overlooking external factors. Failing to check for anomalies or external events that skew results.
* Not involving the right people. Missing crucial perspectives from data science, UX, or domain experts.
* Lack of next-step plan. Finishing an MVE without acting on findings wastes the learning.
* Treating experiment code as production-ready. MVE code is disposable; reimplement for production.
* Partner team as passive observer. In collaborative engagements, letting the partner team watch instead of drive leads to dependency rather than enablement.

## Evaluating results

### Analyzing data

* Apply statistical analysis appropriate to the experiment type.
* Check primary and secondary metrics against the success criteria set in advance.
* Look for anomalies, outlier segments, and confounding factors.
* Distinguish signal from noise. Small sample sizes require extra caution; for survey or quantitative experiments, consult a domain expert or statistician to determine adequate sample sizes before drawing conclusions.

### Documenting learnings

* Restate the hypothesis and the test method.
* Report results with numbers: measured values, sample sizes, confidence levels.
* Interpret what the results mean in the context of the original problem.
* Capture qualitative observations alongside quantitative data.
* State next steps based on results.

### Decision framework

* Go: the hypothesis is validated. Proceed to MVP planning, scale the approach, or apply the finding.
* No-go: the hypothesis is invalidated. Pivot, abandon, or redesign based on what was learned.
* Adjust: results are mixed or inconclusive. Refine the hypothesis, increase sample size, or address confounding factors and re-run.

### When to iterate versus when to stop

* Iterate when results are close to thresholds but not conclusive, when new questions emerge from the data, or when the hypothesis needs refinement.
* Stop when the hypothesis is clearly validated or invalidated, when the learning objective has been achieved, or when further investment would not change the decision.
* Avoid analysis paralysis. Each MVE targets a specific learning objective; declare the result and move on.

## Project hypothesis template

Use this structure to organize hypotheses for complex experiments with multiple objectives.

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

## Backlog bridge

The backlog bridge converts completed experiment outputs into requirements language for backlog managers. Use it after the MVE plan is complete, when a validated experiment should transition into planned work items. Do not use it for experiments still in progress or those that produced inconclusive results.

### Backlog brief template

```text
<!-- markdownlint-disable-file -->

# Backlog Brief: {experiment-name}

## Summary

{2-3 sentence overview derived from problem statement and primary hypothesis}

## Source Experiment

* **MVE Plan**: {path to the session MVE plan}
* **Experiment Type**: {type from experiment design}
* **Timeline**: {scope from experiment design}

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

### Field guidance

* Summary: synthesize from the problem statement and primary hypothesis. Write as a requirements overview, not an experiment description.
* Source Experiment: link back to the MVE plan so backlog managers can trace requirements to their origin.
* Requirements: one `REQ-NNN` section per hypothesis. The hypothesis assumption becomes the requirement description, success criteria become acceptance criteria, and priority carries from the hypothesis ranking.
* Dependencies and Resources: map directly from experiment design resource requirements.
* Out of Scope: preserve experiment scope boundaries to prevent backlog planning from exceeding the experiment's validated scope.
* Suggested Labels: include `experiment` and `mve` as baseline labels, then add each experiment type as a separate label. Omit unused type placeholders.

### Handoff

After generating the backlog brief, provide it to the appropriate backlog manager agent as the input document. The brief is a bridge document: the backlog manager applies its own platform-specific conventions for titles, labels, sizing, and hierarchy, and the brief does not replace the MVE plan or any other session artifact.
