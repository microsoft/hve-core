---
title: Agentic Workflow Runtime Scripts
description: Trusted runtime support for compiled Agentic Workflows
author: HVE Core Team
ms.date: 2026-10-22
ms.topic: reference
keywords:
  - agentic workflows
  - powershell
  - runtime
estimated_reading_time: 2
---

Trusted scripts in this directory perform deterministic processing for
compiled Agentic Workflows. They do not make semantic decisions assigned to
the model.

## Backlog Grooming

The `backlog-grooming/` runtime owns candidate result collection and wave
validation.

| Script                                                    | Purpose                                                                                  |
|-----------------------------------------------------------|------------------------------------------------------------------------------------------|
| `backlog-grooming/Invoke-BacklogGroomResultCollector.ps1` | Convert normalized candidate calls and trusted shard context into an immutable v2 result |
| `backlog-grooming/Invoke-BacklogGroomWaveValidator.ps1`   | Validate a complete immutable wave and construct its aggregate                           |
| `backlog-grooming/Modules/BacklogGrooming.psm1`           | Validate candidate semantics and construct canonical shard rows, provenance, and digests |

### Sweep state discovery

The coordinator in
[backlog-groom-orchestrator.yml](../../.github/workflows/backlog-groom-orchestrator.yml)
discovers snapshots and checkpoints by listing all available runs of that
workflow, then listing each run's artifacts. Initial/resume discovery and
continuation duplicate-checkpoint detection share this route. Neither uses
the unfiltered repository-wide artifact list. Failed runs and execution-tag
runs remain eligible because they can contain accepted state.

Each collection requests 100 records per page. Its first validated
`total_count` establishes a bound of `max(1, ceil(total_count / 100))`
logical page requests. Discovery follows pagination links to exhaustion,
checking counts, page sizes, unique identities, and producing-run identity.
Detected truncation, inconsistent counts, missing or duplicate identities,
and links beyond the bound stop planning. GitHub listings are not
transactionally isolated, so concurrent inventory changes can also stop
planning. Total listing cost is the workflow-run page count plus the
artifact-page counts for every enumerated run; full-history discovery grows
with the available run inventory and has no fixed run-count or age cutoff.

The planning github-script step enables three request retries, allowing at
most four physical attempts per logical API request. The action's default
statuses excluded from retries (`400`, `401`, `403`, `404`, `422`) remain unchanged.
Retries do not enlarge the logical page bounds. Exhausted listing or
snapshot/checkpoint metadata API and network errors fail planning rather
than appearing as an empty inventory. Recognized missing, expired, or
untrusted candidate metadata can still be warned about and skipped during
ordinary discovery; execution-tag recovery fails closed.

The separate candidate budgets remain 500 metadata scans and 50 downloads,
inclusive. Discovery does not spend those budgets on listing pages.
Existing provenance, digest, predecessor-chain, ambiguity, and no-op checks
still determine which discovered state is accepted.

Scheduled runs after the seventh day of the month return `calendar-noop`
before discovery. A green calendar no-op does not demonstrate API recovery.
Local extracted-step fixtures verify deterministic behavior and retry
configuration, not hosted SDK backoff or production recovery. A real
non-no-op hosted sweep requires separate maintainer authorization.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
