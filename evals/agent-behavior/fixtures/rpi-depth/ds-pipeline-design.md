---
description: 'Synthetic accepted pipeline design for RPI execution production evaluation'
---
<!-- markdownlint-disable-file -->
# Synthetic Pipeline Domain Design

## Accepted DataOps Design

Create a customer-facing pipeline summary at `docs/data/synthetic-pipeline-output.md`.

The summary must state these accepted invariants:

* Validate the synthetic event identifier before transformation.
* Quarantine invalid records without changing accepted records.
* Emit a bounded rejected-record count after each run.
* Preserve the active `pipeline` job and `episodic` lifecycle class.

## Delivery Boundary

The user accepted this domain design and separately confirmed RPI Plan, Implement, and Review for substantial delivery. RPI may sequence, deliver, validate, and review the summary, but it may not redefine DataOps invariants, change the job, adopt planner state, or bypass the durable-write scan.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.