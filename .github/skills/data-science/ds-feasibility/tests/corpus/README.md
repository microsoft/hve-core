---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-08-06
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - ds-feasibility
estimated_reading_time: 1
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the DS Feasibility Atheris fuzz harness. Each file is raw bytes decoded
as UTF-8 and passed to `parse_profile` through the single `fuzz_parse_profile` target.

## Naming Convention

`{index}_{description}`. The harness has one target, so the index orders the seeds and
does not select behavior. Each seed exercises a distinct parser path.

| Seed                   | Path exercised                              |
|------------------------|---------------------------------------------|
| `0_valid_profile`      | Well-formed interchange block               |
| `1_anchor_alias`       | Prohibited anchors, aliases, and merge keys |
| `2_duplicate_key`      | Duplicate-key rejection                     |
| `3_unterminated_block` | Missing end marker and closing fence        |
| `4_no_block`           | Input without an interchange block          |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
