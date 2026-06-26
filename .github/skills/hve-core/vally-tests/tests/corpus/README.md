---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-06-12
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - vally
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the Vally corpus-importer Atheris fuzz harness. Each file is raw
bytes consumed by `fuzz_dispatch`, which routes `data[0] % 5` to one of five
targets and passes the remaining bytes as the payload.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the `FUZZ_TARGETS`
array position:

| Index | Target                      |
|-------|-----------------------------|
| 0     | `fuzz_normalize_prompt`     |
| 1     | `fuzz_hash_prompt`          |
| 2     | `fuzz_validate_row`         |
| 3     | `fuzz_build_patch_entry`    |
| 4     | `fuzz_load_existing_hashes` |

## Usage

```bash
cd .github/skills/hve-core/vally-tests
uv sync --group fuzz --group dev
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
