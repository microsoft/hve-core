---
agent: 'agent'
description: 'Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.'
---

# Git Merge & Rebase Orchestrator

Follow all instructions from #file:../instructions/git-merge.instructions.md

## Overview

Manage Git merge, rebase, and rebase --onto sequences with standardized stop controls, conflict workflows, and completion summaries.

## Inputs

* ${input:operation:merge} – Selects the workflow (`merge`, `rebase`, or `rebase-onto`).
* ${input:branch:origin/dev} – Branch or ref that receives the merge or becomes the rebase target.
* ${input:onto:origin/dev} – Optional new base required when `${input:operation}` is `rebase-onto`.
* ${input:upstream} – Optional upstream branch or commit that bounds the commits to move during `rebase-onto`.
* ${input:conflictStop:false} – When `true`, pause after each conflict fix for user review before continuing.

No pushes occur automatically.

---

Proceed with git operation following the outlined steps above and the Required Protocol for Git Merge & Rebase.
