---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-07-08
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - adr-author
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the ADR Author Atheris fuzz harness. Each file is raw bytes consumed
by `_entry` which routes `data[0] % len(FUZZ_TARGETS)` to one of the targets.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the `FUZZ_TARGETS`
array position:

| Index | Target                       |
|-------|------------------------------|
| 0     | `_fuzz_validate_frontmatter` |
| 1     | `_fuzz_normalize_template`   |
| 2     | `_fuzz_update_lineage_slug`  |
| 3     | `_fuzz_utils`                |

The first byte selects the target; the remaining bytes are the input payload.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
