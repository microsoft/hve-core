---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-09-14
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - evaluation-design
estimated_reading_time: 1
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the evaluation dataset Atheris fuzz harness. Each file is raw bytes
decoded as UTF-8 and passed through the single `fuzz_parse_evaluation` target, which
exercises both `json.loads` and `parse_csv_pairs`.

## Naming Convention

`{index}_{description}`. The harness has one target, so the index orders the seeds and
does not select behavior. Each seed exercises a distinct parser path.

| Seed                | Path exercised                          |
|---------------------|-----------------------------------------|
| `0_valid_csv_row`   | Well-formed pair row across all columns |
| `1_header_only`     | Contract header with no data rows       |
| `2_short_row`       | Row with fewer values than columns      |
| `3_header_mismatch` | Header rejected against the contract    |
| `4_bad_quoting`     | Strict-mode quoting failure             |
| `5_valid_json`      | JSON decode path                        |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
