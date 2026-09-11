# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for synthetic operation JSON parsing."""

from __future__ import annotations

import json
import sys
from contextlib import suppress

from synthetic_data_operation import OperationError, validate_operation

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_validate_record(data: bytes) -> None:
    """Exercise JSON decoding and validation with arbitrary UTF-8 input."""
    with suppress(json.JSONDecodeError, UnicodeError, OperationError, TypeError):
        value = json.loads(data.decode("utf-8", errors="strict"))
        if isinstance(value, dict):
            validate_operation(value)


class TestSyntheticOperationFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_validator_rejects_or_returns_categories(self) -> None:
        for value in (b"", b"{}", b"[]", b'{"record_type":"preflight"}'):
            fuzz_validate_record(value)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_validate_record)
    atheris.Fuzz()
