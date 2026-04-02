---
description: "Pre-PR branch diff review for functional correctness, error handling, edge cases, and testing gaps - Brought to you by microsoft/hve-core"
agent: Code Review Functional
argument-hint: "[baseBranch=origin/main]"
---

# Code Review Functional

## Inputs

* ${input:baseBranch:origin/main}: (Optional) Comparison base branch. Defaults to `origin/main`.

## Requirements

Run the Code Review Functional agent to analyze the current branch diff against the base branch.

The agent reviews changed files through five focus areas: Logic, Edge Cases, Error Handling, Concurrency, and Contract. It produces a severity-ordered report with numbered findings, concrete code fixes, and testing recommendations.
