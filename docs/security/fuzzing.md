---
title: Fuzzing
description: OSSF Scorecard fuzz harness convention and compliance for HVE Core Python skills
sidebar_position: 5
author: Microsoft
ms.date: 2026-03-16
ms.topic: conceptual
keywords:
  - fuzzing
  - atheris
  - scorecard
  - security
estimated_reading_time: 3
---

## Overview

HVE Core uses [Atheris](https://github.com/google/atheris) fuzz harnesses to satisfy [OSSF Scorecard](https://securityscorecards.dev/) Fuzzing compliance. Each Python skill with a `tests/` directory includes a polyglot `fuzz_harness.py` that runs as both a pytest test and an Atheris coverage-guided fuzz target.

## Scorecard Fuzzing Detection

OSSF Scorecard evaluates fuzzing through a three-phase detection pipeline:

| Phase | Detection Method | HVE Core Strategy |
|-------|-----------------|-------------------|
| 1 | OSSFuzz integration | Not applicable (HVE Core is not a library) |
| 2 | ClusterFuzzLite YAML | Not applicable (no `.clusterfuzzlite/` config) |
| 3 | Source file regex: `import atheris` | Active: `fuzz_harness.py` in each Python skill |

Phase 3 scans all `.py` files in the repository for `import atheris`. A single match satisfies the OSSF Scorecard Fuzzing check, which contributes as one weighted sub-check to the aggregate Scorecard score.

## Convention

Every Python skill with a `tests/` directory **MUST** include:

1. `tests/fuzz_harness.py`: polyglot harness with `try: import atheris` guard
2. `fuzz` dependency group in `pyproject.toml` with `atheris>=3.0`
3. `python_files` config in `[tool.pytest.ini_options]` including `fuzz_harness.py`

The `validate:skills` npm script enforces this convention. Builds fail when a Python skill has `tests/` but no `fuzz_harness.py`.

## Running Fuzz Tests

### pytest Mode (CI Default)

```bash
cd .github/skills/experimental/powerpoint
uv run pytest tests/fuzz_harness.py -v
```

Runs property-based tests without requiring Atheris. This is the default CI path.

### Atheris Mode (Local Fuzzing)

```bash
cd .github/skills/experimental/powerpoint
uv sync --group fuzz
uv run python tests/fuzz_harness.py
```

Runs coverage-guided fuzzing with Atheris. Requires Linux x86_64 (no macOS wheels). Press Ctrl+C to stop.

## Adding a Fuzz Harness to a New Skill

1. Create `tests/fuzz_harness.py` following the polyglot pattern from an existing skill
2. Add `fuzz = ["atheris>=3.0"]` to `[dependency-groups]` in `pyproject.toml`
3. Add `python_files = ["test_*.py", "fuzz_harness.py"]` to `[tool.pytest.ini_options]`
4. Run `npm run validate:skills` to verify compliance
5. Run `uv run pytest tests/fuzz_harness.py -v` to verify pytest mode passes

## Platform Compatibility

Atheris provides pre-built wheels for Linux x86_64 only. The `fuzz` dependency group is separate from `dev` so that `uv sync` (without `--group fuzz`) works on all platforms. The harness degrades gracefully: when Atheris is not installed, `FUZZING = False` and only pytest tests execute.

## Related Documentation

* [Skills Contributing Guide](../contributing/skills.md): fuzz harness requirements
* [OSSF Scorecard](https://securityscorecards.dev/): security scoring methodology
* [Atheris](https://github.com/google/atheris): Python coverage-guided fuzzer

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
