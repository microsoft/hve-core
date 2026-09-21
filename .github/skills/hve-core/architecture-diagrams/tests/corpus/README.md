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
  - architecture-diagrams
estimated_reading_time: 1
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the Architecture Diagrams Atheris fuzz harness. Each file is raw bytes
decoded as UTF-8 and passed to `parse_catalog` through the single `fuzz_parse_catalog`
target.

## Naming Convention

`{index}_{description}`. The harness has one target, so the index orders the seeds and
does not select behavior. Each seed exercises a distinct parser path.

| Seed                  | Path exercised                     |
|-----------------------|------------------------------------|
| `0_valid_catalog`     | Entities and relationships present |
| `1_empty_frontmatter` | Present but empty frontmatter      |
| `2_unclosed_sequence` | Malformed YAML that fails to parse |
| `3_scalar_entities`   | Wrong type for the entities key    |
| `4_no_frontmatter`    | Missing frontmatter delimiter      |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
