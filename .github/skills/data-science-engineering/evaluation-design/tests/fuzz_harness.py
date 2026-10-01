# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for evaluation JSON and CSV parsing."""

from __future__ import annotations

import json
import sys
from contextlib import suppress

from validate_evaluation_dataset import EvaluationValidationError, parse_csv_pairs

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_parse_evaluation(data: bytes) -> None:
    """Exercise JSON and CSV parsers with arbitrary UTF-8 input."""
    text = data.decode("utf-8", errors="replace")
    # RecursionError is documented CPython behavior for deeply nested JSON input.
    with suppress(json.JSONDecodeError, RecursionError):
        json.loads(text)
    with suppress(EvaluationValidationError):
        parse_csv_pairs(text)


class TestEvaluationFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_parsers_reject_or_return_bounded_types(self) -> None:
        for text in ("", "{}", "id,query\n001,test", '"unterminated'):
            with suppress(json.JSONDecodeError):
                assert isinstance(
                    json.loads(text), (dict, list, str, int, float, bool, type(None))
                )
            with suppress(EvaluationValidationError):
                rows, errors = parse_csv_pairs(text)
                assert isinstance(rows, list)
                assert isinstance(errors, list)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_parse_evaluation)
    atheris.Fuzz()
