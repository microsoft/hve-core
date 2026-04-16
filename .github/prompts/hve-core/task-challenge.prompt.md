---
description: "Adversarial What/Why/How interrogation of completed implementation artifacts - Brought to you by microsoft/hve-core"
agent: Task Challenger
argument-hint: "[plan=...] [changes=...] [research=...] [focus=...]"
---

# Task Challenge

## Inputs

* ${input:plan}: (Optional) Implementation plan file path.
* ${input:changes}: (Optional) Changes log file path.
* ${input:research}: (Optional) Research file path.
* ${input:focus}: (Optional) Specific aspect, decision, or component to focus the challenge on.

## Requirements

1. Resolve scope using this priority: use `${input:plan}`, `${input:changes}`, and `${input:research}` as the primary scope artifacts when provided, otherwise follow Phase 1 Step 1.1 discovery order.
2. Apply `${input:focus}` as a pre-applied scope filter: use it to narrow the confirmed scope and note it in the scope summary when provided.
