---
name: prompt-analyze
description: Evaluate prompt engineering artifacts against quality criteria without modification.
maturity: stable
context: fork
agent: prompt-builder
argument-hint: "file=..."
---

# Prompt Analyze

Analyze the following prompt engineering artifact against quality criteria:

$ARGUMENTS

## Mode Directives

Operate in analyze mode. Execute Phase 1 (Baseline) only.

Analyze mode behavior:

* Dispatch the tester subagent to execute and evaluate the target file.
* Report findings without modifying the target file.
* Deliver a structured analysis report with severity-categorized issues after baseline evaluation.
* Skip all phases after Phase 1. Do not proceed to Research, Build, Validate, or Iterate.
