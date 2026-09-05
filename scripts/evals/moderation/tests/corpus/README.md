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
  - moderation
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the moderation Atheris fuzz harness. Each file is raw bytes
consumed by `fuzz_moderate_input`, which decodes the payload as UTF-8 text and
exercises the moderate.py input validation path.

## Usage

```bash
cd scripts/evals/moderation
uv sync --group fuzz --group dev
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation. The
directory must exist for libFuzzer to start, so at least one seed is retained
here.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
