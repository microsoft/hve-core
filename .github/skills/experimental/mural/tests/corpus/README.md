---
title: Fuzz Corpus Seeds
description: Seed inputs for coverage-guided fuzzing with the Atheris fuzz harness
author: Microsoft
ms.date: 2026-04-24
ms.topic: reference
keywords:
  - fuzz
  - corpus
  - atheris
  - mural
estimated_reading_time: 2
---

<!-- markdownlint-disable-file -->
# Fuzz Corpus Seeds

Seed inputs for the Mural Atheris fuzz harness. Each file is raw bytes consumed by
`fuzz_dispatch` which routes `data[0] % len(FUZZ_TARGETS)` to one of the targets.

## Naming Convention

`{target_index}_{description}` where `target_index` matches the `FUZZ_TARGETS`
array position:

| Index | Target                         |
|-------|--------------------------------|
| 0     | `fuzz_redact`                  |
| 1     | `fuzz_validate_mural_id`       |
| 2     | `fuzz_extract_field`           |
| 3     | `fuzz_parse_pagination_cursor` |
| 4     | `fuzz_validate_asset_url`      |
| 5     | `fuzz_validate_redirect_uri`   |
| 6     | `fuzz_parse_json_arg`          |
| 7     | `fuzz_verify_pkce`             |
| 8     | `fuzz_extract_error_payload`   |
| 9     | `fuzz_build_authorize_url`     |
| 10    | `fuzz_loopback_callback_request` |
| 11    | `fuzz_parse_token_response`    |
| 12    | `fuzz_unwrap_value_envelope`   |
| 13    | `fuzz_validate_hyperlink`      |
| 14    | `fuzz_validate_tag_text`       |
| 15    | `fuzz_validate_area_layout`    |
| 16    | `fuzz_validate_profile_name`   |
| 17    | `fuzz_validate_profile`        |
| 18    | `fuzz_parse_rate_limit_headers` |
| 19    | `fuzz_profile_from_credential_path` |
| 20    | `fuzz_resolve_credential_file` |

## Usage

```bash
cd .github/skills/experimental/mural
uv sync --group fuzz --group dev
uv run python tests/fuzz_harness.py tests/corpus/
```

Atheris loads corpus files as starting inputs for coverage-guided mutation.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
