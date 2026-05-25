---
description: 'Workflow description in 1-200 characters'
agent: Target Agent Name
argument-hint: 'arg=... [option={a|b}]'
---

## Inputs

* ${input:task}: Task description (required)
* ${input:option}: Optional parameter

## Requirements

1. When ${input:task} provided, use as primary task
2. When ${input:option} provided, apply as constraint

## Steps

1. Execute the primary workflow
2. Validate results against requirements
3. Present findings to user

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
