---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-05-04
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - graphify
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the Atheris fuzz harness in `tests/fuzz_harness.py`. Each file
is raw bytes consumed by `fuzz_build_graph_mode`, which interprets the input
as a candidate `mode` argument to `graphify_wrapper.build_graph` (truncated to
16 chars).

## Seeds

| File             | Purpose                                                                |
|------------------|------------------------------------------------------------------------|
| `0_empty`        | Empty input - exercises the empty-string branch                        |
| `0_fast`         | Valid `fast` mode                                                      |
| `0_standard`     | Valid `standard` mode                                                  |
| `0_deep`         | Valid `deep` mode                                                      |
| `0_unknown`      | Unknown mode - must raise `ValueError`                                 |
| `0_null_bytes`   | Non-UTF-8 / control bytes - exercises decode-error path                |
| `0_unicode`      | Multi-byte UTF-8 - exercises the unicode-truncation path               |
| `0_long_garbage` | Input longer than the 16-char truncation window                        |

## Usage

```bash
cd .github/skills/experimental/graphify
uv sync --group fuzz
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
