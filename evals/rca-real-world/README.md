---
title: RCAEval real-world RCA evaluation
description: Run five blinded RCAEval cases through the root-cause-analysis skill with bounded evidence tools
author: HVE Core Team
ms.date: 2026-10-22
ms.topic: reference
keywords:
  - root cause analysis
  - rcaeval
  - evaluation
  - copilot sdk
  - blinded testing
---

This evaluation exercises the root-cause-analysis skill against five controlled RCAEval
fault-injection cases. It measures workflow conformance separately from held-out diagnostic
results. The selected cases do not represent organic production incidents or a statistically
representative benchmark.

## Source and license

The preparation command retrieves selected files from
[`phamquiluan/RCAEval`](https://huggingface.co/datasets/phamquiluan/RCAEval) at revision
`afeacb11bcc94dadfd1c8f483ee4377b2b8b614e`. That dataset revision is published under the MIT
license.

No RCAEval telemetry or transformed telemetry is committed to this repository. The committed
case contract records source paths only for preparation and provenance. Generated data remains
under the gitignored evaluation evidence root.

## Metric identities

Preparation preserves source column names and writes a per-case `metric-columns.json` mapping
each wide numeric column to its service and metric identities. The pinned RCAEval schema uses
terminal metric suffixes: `cpu`, `mem`, `latency`, `latency-50`, `latency-90`, `load`, `error`,
`diskio`, `socket`, and `workload`. Preparation extracts only these declared suffixes, preserving
underscores inside service names, and rejects unknown numeric columns instead of guessing a
boundary. The mapping uses telemetry schema only, never held-out root-cause labels.

`read_incident_scope` exposes the mapping. Both metric tools compare requested identities using
trimmed, case-insensitive equality, not substring matching. For example, `latency` does not match
`latency-90`, and `user` does not match `user-db`. Narrow rows use their explicit identity fields;
rows missing a requested identity are excluded. Mixed narrow and wide rows are handled per row.
Matched-row counts include only rows contributing selected finite numeric values.

The preparation manifest hashes each mapping, and continuation fingerprints include the mapping
files. Transformation version `2.0.0` requires freshly prepared inputs; old runs must not be resumed
with the new filtering semantics. Unknown, missing, or malformed mappings fail explicitly.

## Blindness boundary

The preparation command creates two separate roots:

* `model-visible/` contains neutrally named incident metadata and deterministic evidence stores.
* `scorer-only/` contains source provenance, hashes, and held-out service and fault labels.

Model sessions run from isolated temporary workspaces that receive the packaged RCA skills and
one neutral case context. They cannot access the repository, the case contract, source paths,
other cases, prior model output, or scorer-only files. Genuine service names remain in telemetry
because they are evidence; packaging metadata never identifies one as the expected answer.

## Prerequisites

* Node.js 24 and dependencies restored with `npm ci`
* Network access to the pinned Hugging Face revision for preparation
* GitHub Copilot authentication available to the Copilot SDK and CLI
* Exact `gpt-5.6-sol` model identity with `medium` reasoning effort and the `default` context tier
* A human reviewer for diagnostic compatibility and final CR-16 assessment

The harness fails closed before model execution if the exact model profile is unavailable,
source provenance changes, an input is malformed, or a blindness check fails.

## Commands

```powershell
npm run rca-eval:prepare -- --run-id <run-id>
npm run test:rca-eval
npm run ci:rca-eval -- --run-id <run-id> --round 1
```

The preparation and model-backed commands are added by the harness implementation. The
model-backed command is CI-owned because it uses external data, credentials, and model budget.

## Trial cadence and checkpoint

The current checkpoint schedule contains five isolated trial-1 sessions:

```text
round 1: case-01 trial 1, case-02 trial 1, case-03 trial 1, case-04 trial 1, case-05 trial 1
checkpoint
```

No trial-2 or trial-3 session can start before the user reviews this five-case checkpoint and
records a new decision. A failed session remains a result and is never retried automatically.

## Evidence

Raw inputs, transcripts, tool traces, approvals, scores, and manifests are written below:

```text
.copilot-tracking/evaluations/rcaeval-three-case/<run-id>/
```

The committed `PR-3136-EVIDENCE.md` report contains only sanitized outcomes, immutable input and
artifact hashes, commands, limitations, and human-review status. It excludes raw telemetry,
credentials, host paths, personal data, and unredacted tool payloads.

## Interpretation limits

* Five selected cases and their model sessions do not establish a general RCA accuracy rate.
* RCAEval uses controlled fault injection on microservice testbeds.
* Fixture approvals test generic-mode approval-protocol behavior. They do not establish live
  production authorization or authenticated human approval.
* Repeated time points from one injected incident are dependent observations. The statistical
  companion must report the independent-unit test as not applicable or blocked rather than
  inventing a p-value.
* Diagnostic compatibility, unsupported claims, CR-16 satisfaction, and issue closure remain
  human decisions.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
