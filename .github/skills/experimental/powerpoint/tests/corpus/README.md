---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-03-19
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - powerpoint
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the Atheris fuzz harness. Each file is raw bytes consumed by
`fuzz_dispatch` which routes `data[0] % 4` to one of four targets.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the FUZZ_TARGETS
array position:

| Index | Target                        |
|-------|-------------------------------|
| 0     | `fuzz_resolve_color`          |
| 1     | `fuzz_hex_brightness`         |
| 2     | `fuzz_max_severity`           |
| 3     | `fuzz_has_formatting_variation`|

## Usage

```bash
cd .github/skills/experimental/powerpoint
uv sync --group fuzz
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
