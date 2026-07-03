---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-06-18
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - telemetry
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the telemetry Atheris fuzz harness. Each file is raw bytes consumed
by `fuzz_dispatch`, which routes `data[0] % 3` to one of three targets.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the `FUZZ_TARGETS`
array position:

| Index | Target                 |
|-------|------------------------|
| 0     | `fuzz_iter_jsonl`      |
| 1     | `fuzz_normalize_event` |
| 2     | `fuzz_build_entry`     |

The first byte selects the target; the remaining bytes are the input payload.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
