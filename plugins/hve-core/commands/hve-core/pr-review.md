---
description: "Review a pull request or local change set by routing to the consolidated Code Review agent"
agent: Code Review
argument-hint: "[pr=...] [base=...] [head=...] [scope=...]"
---

# PR Review

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for review scope discovery.
* ${input:pr}: (Optional) Pull request number or URL to review.
* ${input:base}: (Optional) Base branch or ref for the diff. Defaults to the repository default branch.
* ${input:head}: (Optional) Head branch or ref for the diff. Defaults to the current branch.
* ${input:scope}: (Optional) Additional scope hints such as paths, perspectives, or depth.

## Requirements

1. Resolve the review target using this priority: explicitly provided `${input:pr}`, the `${input:base}`/`${input:head}` diff, then the current branch against the default branch.
2. Hand off to the Code Review agent, which bootstraps change context with the shared PR-reference diff flow, confirms scope, selects perspectives and depth, and consolidates skill-backed findings into one report.
3. Keep emission human-gated: in interactive mode the agent writes a human-editable draft and pauses for explicit confirmation and a PR-state check before any native or external emission.
4. Summarize the verdict, severity counts, and the path to the persisted review report.
