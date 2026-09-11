---
description: "Review a pull request or local change set by routing to the consolidated Code Review agent"
agent: Code Review
argument-hint: "[pr=...] [base=...] [head=...] [profile=...] [scope=...]"
---

# PR Review

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for review scope discovery.
* ${input:pr}: (Optional) Pull request number or URL to review.
* ${input:base}: (Optional) Base branch or ref for the diff. Defaults to the repository default branch.
* ${input:head}: (Optional) Head branch or ref for the diff. Defaults to the current branch.
* ${input:profile}: (Optional) Review profile: `standard`, `full`, or `custom`. Defaults to `standard` for every resolved target.
* ${input:scope}: (Optional) Additional scope hints such as paths, perspectives, or depth.

## Requirements

1. Resolve the review target using this priority: explicitly provided `${input:pr}`, an open PR or MR mapped from the current branch, the `${input:base}`/`${input:head}` diff, then local changes.
2. Hand off the resolved target and any explicit `${input:profile}` to the Code Review agent. When the profile is omitted, use `standard` independently of the target. The `standard` profile recommends Functional, Standards, and Readiness findings, adding Security and Accessibility when their signals fire. Orientation runs once as a workflow stage and is not a findings perspective.
3. Require the resolved PR or branch head SHA to match checked-out `HEAD` before diff generation. On mismatch, stop and ask the user to check out the target head instead of reviewing the current checkout under another target's metadata.
4. Bootstrap change context with the shared PR-reference diff flow using the exact target base, serialize the immutable reviewed head SHA and exact worker output paths, confirm scope, select perspectives and depth, and consolidate skill-backed findings into one report.
5. Keep emission human-gated: in interactive mode the agent writes a human-editable draft and pauses for explicit confirmation and a PR-state check against the reviewed head SHA before any native or external emission.
6. Summarize the verdict, severity counts, and the path to the persisted review report.
