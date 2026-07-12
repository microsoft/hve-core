# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Polyglot fuzz harness for cost-estimator text normalization.

Runs as pytest property tests without Atheris and as a coverage-guided target
when executed directly with the fuzz dependency installed.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.cost.estimate_agent_cost import Tokenizer, normalize_text  # noqa: E402

try:
    import atheris
except ImportError:
    atheris = None


def fuzz_one_input(data: bytes) -> None:
    """Exercise normalization and heuristic token estimation on arbitrary bytes."""
    text = data.decode("utf-8", errors="ignore")
    normalized = normalize_text(text)
    tokenizer = Tokenizer(encoding=None)
    token_count, estimator, approximate, fallback_reason = tokenizer.estimate(normalized)
    assert token_count >= 0
    assert estimator == "heuristic"
    assert approximate is True
    assert fallback_reason is None


class TestCostEstimatorFuzzHarness:
    """Property tests that mirror the coverage-guided fuzz target."""

    def test_given_arbitrary_bytes_when_fuzzed_then_estimate_is_non_negative(self) -> None:
        # Arrange
        data = bytes(range(256))

        # Act / Assert
        fuzz_one_input(data)

    def test_given_mixed_line_endings_when_normalized_then_no_carriage_returns_remain(
        self,
    ) -> None:
        # Arrange
        text = "alpha\r\nbeta\rgamma\n"

        # Act
        normalized = normalize_text(text)

        # Assert
        assert "\r" not in normalized


if __name__ == "__main__" and atheris is not None:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_one_input)
    atheris.Fuzz()
