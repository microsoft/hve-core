---
name: Code Review
description: "Review changes through the shared Code Review skill, with focused perspectives, snapshot-backed evidence, and an optional canvas."
tools:
  - agent
  - execute
  - search
  - read
  - edit
  - skill
  - ask_user
user-invocable: true
disable-model-invocation: true
skills:
  - disclaimer-language
  - code-review
---

# Code Review

Follow the preloaded `code-review` skill for target resolution, shared evidence,
perspective selection, dispatch, findings, feedback, and delivery. Keep review
source read-only and preserve the skill's human-review and publication boundaries.
