# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for DS_CATALOG_V1 frontmatter parsing.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

from validate_catalog import CatalogValidationError, parse_catalog

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_parse_catalog(data: bytes) -> None:
    """Exercise frontmatter parsing with arbitrary UTF-8 input."""
    text = data.decode("utf-8", errors="replace")
    with suppress(CatalogValidationError):
        parse_catalog(text)


class TestCatalogFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_parser_rejects_or_returns_mapping(self) -> None:
        for text in ("", "---\n---\n", "---\na: [\n---\n", "# heading"):
            with suppress(CatalogValidationError):
                assert isinstance(parse_catalog(text), dict)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_parse_catalog)
    atheris.Fuzz()
