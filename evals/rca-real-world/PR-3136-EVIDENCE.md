---
title: PR 3136 RCAEval two-level output evidence
description: Sanitized evidence from a five-case blinded evaluation of RCA Set A and Set B outputs
author: HVE Core Team
ms.date: 2026-10-20
---

## Scope

This run evaluated five selected RCAEval fault-injection cases with three trials per case. It used
GPT-5.6 Sol with medium reasoning effort and the default context tier. The evaluation scored the
strict evidence-supported Set A independently from the leading unverified Set B.

The cases are controlled faults on microservice testbeds, not organic production incidents.
Fifteen completed sessions do not establish a general RCA accuracy rate.

## Provenance

| Item                             | Value                                                                               |
|----------------------------------|-------------------------------------------------------------------------------------|
| Run ID                           | `pr-3136-rcaeval-current-20261020-01`                                               |
| Repository commit at run start   | `3c9c765b4cf8c5a8e32b372aedbb5f805538dc75`                                          |
| RCAEval revision                 | `afeacb11bcc94dadfd1c8f483ee4377b2b8b614e`                                          |
| Dataset source and license       | [phamquiluan/RCAEval](https://huggingface.co/datasets/phamquiluan/RCAEval), MIT     |
| Model                            | `gpt-5.6-sol`                                                                       |
| Reasoning effort                 | `medium`                                                                            |
| Context tier                     | `default`                                                                           |
| Node.js                          | `v24.14.0`                                                                          |
| Copilot CLI                      | `GitHub Copilot CLI 1.0.101`                                                        |
| Evaluated skill bundle SHA-256   | `e974e88b343ea20976cbc7c4de99f155ed46f270dc09cd28fa46a001e05cd2ee`                  |
| Tool contract SHA-256            | `b1856da23ac1223cfddbe3022d8556341be4b48953a7021131fb7fb6c785efa3`                  |
| Input fingerprint                | `64accee92c1bdd036f841baf3b2eb3897e83c900ae91d9d0b1199b3062bae9e2`                  |
| Parquet reader                   | `hyparquet@1.31.5:fdd28364b0dde800dea00979cbd3ddee26a053bb0d15b17820e0f865b9ab8178` |
| Package lock SHA-256             | `eaf8cac5de9c2ac68fbae49473e3c74c2e4a5c639e3168211834bbe118faacc6`                  |
| Premium requests                 | 60                                                                                  |
| Approved evidence calls executed | 92                                                                                  |

## Commands

| Command                                                                                                  | Result                                  | Purpose                                              |
|----------------------------------------------------------------------------------------------------------|-----------------------------------------|------------------------------------------------------|
| `node scripts/evals/rca-real-world/prepare-cli.mts --run-id pr-3136-rcaeval-current-20261020-01`         | Passed                                  | Prepare and validate blinded inputs                  |
| `node scripts/evals/rca-real-world/prepare-cli.mts --run-id pr-3136-rcaeval-current-20261020-01 --check` | Passed                                  | Verify prepared input provenance and modality counts |
| `node scripts/evals/rca-real-world/run-cli.mts --run-id pr-3136-rcaeval-current-20261020-01 --round 1`   | Passed; checkpoint paused               | Execute and score one trial per case                 |
| `node scripts/evals/rca-real-world/run-cli.mts --run-id pr-3136-rcaeval-current-20261020-01 --round 2`   | Passed after user continuation approval | Execute and score trial round 2                      |
| `node scripts/evals/rca-real-world/run-cli.mts --run-id pr-3136-rcaeval-current-20261020-01 --round 3`   | Passed                                  | Execute and score trial round 3                      |
| `node --test scripts/tests/evals/rca-real-world/*.test.mts`                                              | Passed, 48 tests                        | Run deterministic RCA evaluation regression tests    |
| `node --check` on every RCA evaluation `.mts` file                                                       | Passed                                  | Check TypeScript-strippable syntax                   |
| `pwsh -NoProfile -File scripts/linting/Validate-SkillStructure.ps1 -WarningsAsErrors`                    | Passed, 90 skills                       | Validate skill structure                             |
| Focused frontmatter validation                                                                           | Passed, 0 warnings                      | Validate changed RCA skill frontmatter               |
| `git diff --check`                                                                                       | Passed                                  | Check patch whitespace                               |

## Results

| Case    | Trial | Integrity | Set A service | Set B status | Set B service | Set B mechanism | Safety warning |
|---------|------:|-----------|---------------|--------------|---------------|-----------------|----------------|
| case-01 |     1 | Pass      | Unassessed    | Candidate    | Match         | Match           | Present        |
| case-01 |     2 | Pass      | Unassessed    | Candidate    | Match         | Match           | Present        |
| case-01 |     3 | Pass      | Unassessed    | Candidate    | Match         | Match           | Present        |
| case-02 |     1 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-02 |     2 | Pass      | Unassessed    | Candidate    | Match         | Match           | Present        |
| case-02 |     3 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-03 |     1 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-03 |     2 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-03 |     3 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-04 |     1 | Pass      | Unassessed    | Candidate    | Miss          | Unassessed      | Present        |
| case-04 |     2 | Pass      | Unassessed    | Candidate    | Miss          | Unassessed      | Present        |
| case-04 |     3 | Pass      | Unassessed    | Candidate    | Miss          | Unassessed      | Present        |
| case-05 |     1 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-05 |     2 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |
| case-05 |     3 | Pass      | Unassessed    | Candidate    | Match         | Unassessed      | Present        |

Aggregate results:

* Integrity passed in 15 of 15 sessions.
* Set A remained unassessed in all 15 sessions.
* Set B matched the held-out service in 12 sessions, missed in three, and never abstained.
* Set B matched the held-out mechanism in four sessions.
* The required Set B safety warning appeared in all 15 sessions.
* The correct held-out cause was represented in a tested hypothesis in six sessions.

These are exact run counts, not population accuracy estimates.

## Approval and strict-gate review

Every evidence approval was labelled as a simulated evaluation fixture and persisted separately
from the model transcript. The run tests approval-protocol conformance only. It does not establish
live production authorization or authenticated human approval.

The machine wording check rejected `approvalClearlySimulated` in all fifteen sessions. The
repository user reviewed and accepted the five trial-one statements for continuation. Ten
round-two and round-three semantic judgments remain pending.
Every other strict gate passed in all 15 sessions.

## Scorer corrections

The preserved outputs exposed one deterministic parser gap: a generic RCA target could contain a
canonical service plus an operation or implementation path, but the service-level scorer compared
the full compound value with the held-out service.

The scorer and regression tests were corrected, and all 15 preserved outputs were rescored. No
model session, evidence call, or raw output was rerun or replaced.

## Limitations and review status

* RCAEval uses controlled fault injection on microservice testbeds.
* Five selected cases and fifteen sessions do not establish a general RCA accuracy rate.
* Service-level matching does not establish mechanism-level causal correctness.
* Fixture approvals do not establish production authority.
* Ten authorization-wording judgments and all diagnostic compatibility decisions remain human
  review items.
* The evaluated skill bundle includes the completed hve-builder corrections for generic RCA
  targets, neutral and unassessed evidence directions, and causal-likelihood eligibility.
* Raw telemetry, prompts, transcripts, tool payloads, credentials, personal data, and host paths
  are excluded from this committed report.
* Satisfaction of CR-16 and closure of #3134 remain reviewer decisions.

* [ ] Reviewed and validated by a qualified human reviewer

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
