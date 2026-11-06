---
title: PR 3136 raw RCAEval three-round production evaluation (2026-11-06)
description: Public record of three paired raw-data production-model rounds with verified accounting, candidate-service scores, schema boundaries, and pending human causal review
author: HVE Core Team
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - root cause analysis
  - rcaeval
  - raw evidence
  - production evaluation
  - baseline
---

## Status and scope

> [!IMPORTANT]
> Production denotes the benchmark model profile, not production authority, readiness
> certification, general skill efficacy, or a verified causal finding. Human causal,
> mechanism-compatibility, privacy-impact, and completion review remains pending.

Run `pr-3136-raw-production-v12-wshzcfvbkbjc` completed three rounds over five raw
RCAEval cases in both skilled and skill-free conditions: 30 attempted sessions,
30 integrity-valid reports, and all applicable strict gates passed. The source
observations come from controlled microservice fault injections, not organic
production incidents or synthetic smoke fixtures.

The user first approved round one, then separately approved the remaining two rounds
under the original configuration and shared allowance. No session was retried,
no technical-stop override was used, and no extra round was executed.
Publication did not execute any additional model sessions.

This is test 4 in the [four-evaluation comparison](README.md#four-evaluation-comparison).
The [machine-readable snapshot](PR-3136-RAW-PRODUCTION-2026-11-06.json) preserves all
30 trial records, case and source-file identities, publishable extracted service labels,
native scores, strict gates, accounting, schema-boundary checks, redaction counts,
and provenance hashes. Three compound or non-service candidate labels are withheld;
their original scores are unchanged. Telemetry, prompts, model narratives and mechanism
excerpts, captures, approvals, session IDs, local paths, private originals, and reveal
links are excluded.

## Evaluation provenance

* Protocol and report output: `ad-hoc-v12`, `schema`
* Evidence track and format: `raw`, `jsonl-unmapped-v1`
* Model identifier and profile: `gpt-5.6-sol`, `production`
* Reasoning effort and context tier: `medium`, `default`
* Execution surface: installed Copilot headless runtime with host-mediated evidence
* CLI version exposed by the host: `GitHub Copilot CLI 1.0.101.`
* Node.js: `v26.13.0`
* Evaluated repository commit: `15901a4a4aeeee5e213d790e3dd66e5cddb052aa`
* Uncommitted harness changes at execution: none
* Input fingerprint: `8c656ca3fe69dbebc37d1f4294ad125fa630c998c2dc0217c6398502348fa252`
* Package-lock SHA-256: `41ff6a12141a89fa6eef57b985ef684108a586c322703015afe2c9a398885861`
* Verified at: `2026-11-06T23:34:33.698Z`
* Published JSON SHA-256: `1a21d014b6ebb6836524c9fb56f0e478991f21b32d53783048e74c052368f223`

All rounds used an isolated worktree of the evaluated commit. Publication occurs later
and does not change the frozen source/input fingerprint. The host exposes a model
identifier, not an immutable backend build. Hashes identify private supporting artifacts;
they are not retrieval links or a complete public replay archive.

### Execution and schema boundary

Both conditions used the same selected model, cases, evidence-tool contract, and limits:
eight model turns, 24 evidence calls, 240 seconds per turn, and 15 minutes of investigation
wall time per session. A single shared 6,000-AI-credit allowance covered all three rounds
and both conditions. It was a monitored cutoff, not a hard billing cap or a per-session
debug limit. The stop policy remained two consecutive technical failures.
Fixture approvals did not grant production authority.

Each trial used an independent runtime session and isolated temporary workspace.
Within each trial, investigation and schema-constrained finalization stayed in the
same session. The response schema was attached only to the final send; readiness and
finalization consumed the existing turn budget. Evidence collection was not
schema-constrained, and exact approvals and semantic report checks remained authoritative.

All 30 final-turn-only schema boundaries and all applicable strict gates passed.
Baseline gates marked `not-applicable` are not failures. Schema attachment, artifact
integrity, and logical report-contract conformance are separate checks; none proves
provider-side constrained decoding or causal correctness.
See the [finalization contract](SCHEMA-FINALIZATION.md).

## Raw cohort and input reuse

Source: [phamquiluan/RCAEval](https://huggingface.co/datasets/phamquiluan/RCAEval),
revision `afeacb11bcc94dadfd1c8f483ee4377b2b8b614e`, MIT license.
The [raw cohort provenance](raw-cases.json) records the source identities and selection.
Seed `rcaeval-raw-2026-11-05` selected five cases from 730 eligible cases after excluding
the prepared cohort. Selection did not depend on diagnostic success.

This run copied the verified inputs from the
[three-round raw debug evaluation](PR-3136-RAW-DEBUG-2026-11-06.md).
All 40 input files, totaling 386,114,573 bytes, matched exactly; no preparation-manifest
field was rewritten. No download or conversion was repeated, and no previous session,
result, approval, or model output was reused.

The eleven telemetry JSONL files contain 1,273,481 rows and 362,827,192 bytes.
Conversion preserves source fields and row order without metric mapping, renamed fields,
added telemetry fields, resampling, or preparation-time aggregates. Original Parquet
files and scoring truth remain scorer-only. "Raw" means conversion-only
`jsonl-unmapped-v1`, not access to unfamiliar original binary files.

| Case    | Source case                          | Held-out service      | Fault  |
|---------|--------------------------------------|-----------------------|--------|
| case-01 | `re2ob_currencyservice_loss_3`       | currencyservice       | loss   |
| case-02 | `re1ob_cartservice_cpu_4`            | cartservice           | cpu    |
| case-03 | `re2ss_carts_socket_3`               | carts                 | socket |
| case-04 | `re2ob_productcatalogservice_disk_2` | productcatalogservice | disk   |
| case-05 | `re2ss_catalogue_socket_1`           | catalogue             | socket |

## Results and consumption

| Round | Skilled service matches | Non-skilled service matches | Skilled valid reports | Non-skilled valid reports | Total AI credits |
|-------|------------------------:|----------------------------:|----------------------:|--------------------------:|-----------------:|
| 1     |                       5 |                           4 |                     5 |                         5 |       1082.94810 |
| 2     |                       5 |                           5 |                     5 |                         5 |       1091.04690 |
| 3     |                       4 |                           4 |                     5 |                         5 |       1027.73086 |
| All   |                      14 |                          13 |                    15 |                        15 |       3201.72586 |

Every round has five scheduled sessions per condition. Across 15 valid paired attempts,
both conditions matched the service in 13 pairs, only the skilled condition matched
in one pair, and neither matched in one pair. No pair favored only the non-skilled
condition. Candidate-mechanism matches were 10/15 skilled and 9/15 non-skilled;
mechanism-compatibility judgments remain pending human review.

Service matches above are leading-candidate service scores (Set B), not established
causal findings (Set A). All 15 skilled findings remain `not-established`; their
finding-service scores are unassessed, not diagnostic misses. Neither candidate
matches nor passed workflow gates establish causal correctness.

| Condition   | Sessions | AI credits | Premium requests |
|-------------|---------:|-----------:|-----------------:|
| Skilled     |       15 | 1838.74044 |               97 |
| Non-skilled |       15 | 1362.98542 |               84 |
| Total       |       30 | 3201.72586 |              181 |

Rounds two and three consumed an additional 2,118.77776 AI credits after round one's
1,082.94810. The full run left 2,798.27414 of the original shared allowance unused.
Accounting uses each session's final cumulative usage once and sums integer
`totalNanoAiu` before conversion, avoiding cumulative-snapshot double counting and
floating-point display artifacts.

## Execution audit and privacy limitations

The frozen audit verified 30 distinct runtime sessions, 181 accepted response identities
and canonical message hashes, and 536 successful evidence results with verified hashes.
The largest evidence result was 65,095 bytes, within the 65,536-byte limit.
There were two recoverable query rejections in round one, zero format rejections,
zero technical or integrity failures, zero partial host batches, zero technical pauses,
and zero cleanup errors.

All 40 inputs, 145 protected round-one files, 330 earlier debug files, and ten previously
published records were unchanged at verification. The source/input fingerprint and
user settings were preserved. The public export separately verifies native trial-file
hashes, scores, gates, final usage, cohort equality, and input identities.

Session artifacts recorded 2,172 redaction replacements. These counts describe the
redaction mechanism, not the number of unique sensitive values or proof that
investigation behavior was unaffected. Original-source retrieval, downstream causal
impact, and privacy impact remain unassessed. The publication uses a metadata-only
allowlist and passes a separate sensitivity scan with zero additional replacements.
Private captures, local report originals, pseudonym keys, and reveal links are excluded.

## Interpretation and human review

These are three repetitions over five selected fault-injection cases, not a representative
benchmark, 15 independent cases, or a controlled estimate of the skill's causal effect.
The exposed-feature and raw cohorts differ. Protocol, source state, and budget-policy
differences also prevent interpreting the four-category comparison as a controlled
model-only or feature-exposure experiment. Do not pool results across the categories.
Earlier snapshot files remain unchanged.

* [ ] Causal and mechanism judgments reviewed by a qualified human reviewer
* [ ] Extracted service labels and scoring ambiguities reviewed
* [ ] Privacy impact and original-source retrieval reviewed
* [ ] Evaluation completion and claims reviewed

Prepared with AI assistance; human evaluation review is pending.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
