---
title: Generic Root Cause Analysis Skills
description: Configure the hybrid RCA skill package and its companion assessment skills
---

This package contains three portable skills:

* `root-cause-analysis/SKILL.md` owns the hybrid investigation and disposition workflow.
* `statistical-hypothesis-testing/SKILL.md` compares eligible binary rates or numeric averages.
* `causal-evidence-likelihood/SKILL.md` estimates how one evidence item changes hypothesis
  plausibility through a reasoned likelihood ratio.

The package does not define a custom agent. Install all three skills so the RCA workflow can invoke
its companion assessments. An investigation can begin with empty or populated sets of evidence,
hypotheses, and observations.

## Host behavior

The RCA skill selects one of two host modes:

* In Azure SRE mode, it loads `root-cause-analysis/references/azure-sre-tools.md` and automatically
  uses relevant, safe, read-only tools from that catalog. Azure terminology and source guidance
  become authoritative for the connected Azure evidence.
* In generic mode, it inventories other available tools, proposes a bounded evidence-expansion
  action, and obtains user approval before invoking those tools. It can still assess supplied
  evidence when no additional tools are approved or available.

Tool availability does not grant data access or permission to alter a system. Enforce read-only
access, approvals, and production boundaries through host controls.

## Statistical runtime prerequisite

The host must provide an approved code-execution or statistics tool with a pre-existing runtime
that supports Barnard's exact test and Welch's independent-samples t-test. The package does not
ship or install that runtime. Do not install or upgrade statistical packages during an
investigation.

When no approved runtime is available, `statistical-hypothesis-testing` records the test as
`Blocked` and returns no statistic, confidence interval, degrees of freedom, or p-value. A blocked
statistical result is excluded from pair selection and summaries. The investigation may continue
through other executed evidence and eligible causal assessments.

## Azure SRE installation

1. Open the Azure SRE agent and go to **Builder > Skills**.
2. Create skills named `root-cause-analysis`, `statistical-hypothesis-testing`, and
   `causal-evidence-likelihood`.
3. Add each corresponding `SKILL.md` as a skill procedure.
4. Include the `root-cause-analysis/references/azure-sre-tools.md` reference with the RCA skill.
5. Attach the Azure SRE tools available to the agent and verify its connector credentials.
6. Verify whether the host exposes an approved statistical runtime. The cataloged Azure SRE tools
   do not themselves provide one; without a separate runtime, statistical tests are `Blocked`.
7. Keep write tools disabled for a read-only investigation.
8. Start a new thread and verify that the host is detected as Azure SRE mode.

Local repository changes do not update a deployed Azure SRE agent. Upload each changed skill and
its references to refresh the deployment.

## Generic installation

Install the three skill directories in a host that supports on-demand skills. Expose only tools
appropriate for the investigation. The RCA skill will request approval before using non-Azure-SRE
tools to expand the evidence set.

Example invocation:

> Use the root-cause-analysis skill to investigate why the reported outcome occurred. Start with
> the hypotheses, evidence, and observations in this thread. Identify gaps, propose additional
> evidence collection when useful, and continue until the completion gate passes or a concrete
> evidence, access, approval, or tool blocker remains.

## Behavior and limits

The skill tests predictions before declaring a cause, actively seeks disconfirming evidence,
tracks source lineage, and preserves exact test parameters and observations. It invokes
statistical testing for eligible grouped observations and causal evidence likelihood assessment
for valid exploratory and confirmatory hypothesis-evidence pairs under their respective authority
boundaries. Statistical significance and elicited likelihood ratios inform evidence weighting but
cannot directly set a hypothesis disposition.

`Complete` means the causal completion gate passed. `Provisional`, `Inconclusive`, `Blocked`, and
`Paused` are not completed RCAs. The skill cannot guarantee that available evidence contains a
discoverable root cause, override host budgets, schedule itself, or continue after the host stops.

The procedure checkpoints after completed test cycles. Use approved durable storage when
available; a checkpoint emitted only in chat does not guarantee cross-thread recovery.

## Deferred work

The following approved backlog remains outside this change:

* Expand statistical methods beyond binary rates and independent-sample means.

Behavior conformance coverage now verifies companion-skill disposition authority, the `Complete`
gate, production-action approval, and resumable checkpoints for every non-complete stop state. A
synthetic regression corpus exercises incident, data, software, and process-failure cases.

## Microsoft documentation

* [Skills: creation, tool attachment, and lifecycle](https://learn.microsoft.com/azure/sre-agent/skills)
* [Connectors and data access](https://learn.microsoft.com/azure/sre-agent/connectors)

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
