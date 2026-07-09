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
  - gitlab
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the GitLab Atheris fuzz harness. Each file is raw bytes consumed by
`fuzz_dispatch` which routes `data[0] % len(FUZZ_TARGETS)` to one of the targets.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the `FUZZ_TARGETS`
array position:

| Index | Target                       |
|-------|------------------------------|
| 0     | `fuzz_strip_git_suffix`      |
| 1     | `fuzz_validate_numeric_id`   |
| 2     | `fuzz_extract_field`         |
| 3     | `fuzz_load_json_payload`     |
| 4     | `fuzz_validate_positive_int` |
| 5     | `fuzz_validate_state`        |
| 6     | `fuzz_validate_ref`          |
| 7     | `fuzz_parse_fields`          |

## Usage

```bash
cd .github/skills/gitlab/gitlab
uv sync --group fuzz --group dev
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
