# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `_validate_client_secret` (Phase C.2)."""

from __future__ import annotations

from typing import Any

import pytest

VALID_18_CHAR = "abcdef0123456789ab"  # 18 chars, no whitespace
VALID_16_CHAR = "abcdef0123456789"  # exact lower bound


def test_accepts_valid_secret(mural_module: Any) -> None:
    assert mural_module._validate_client_secret(VALID_18_CHAR) == VALID_18_CHAR


def test_accepts_minimum_length_secret(mural_module: Any) -> None:
    assert mural_module._validate_client_secret(VALID_16_CHAR) == VALID_16_CHAR


def test_strips_leading_and_trailing_whitespace(mural_module: Any) -> None:
    padded = f"  {VALID_18_CHAR}\n"
    assert mural_module._validate_client_secret(padded) == VALID_18_CHAR


@pytest.mark.parametrize("value", [None, 42, b"abcdef0123456789", ["x"], {"x": 1}])
def test_rejects_non_string(mural_module: Any, value: Any) -> None:
    with pytest.raises(ValueError, match="client secret must be a string"):
        mural_module._validate_client_secret(value)


@pytest.mark.parametrize("value", ["", "   ", "\t\n"])
def test_rejects_empty_or_whitespace_only(mural_module: Any, value: str) -> None:
    with pytest.raises(ValueError, match="client secret is empty or whitespace only"):
        mural_module._validate_client_secret(value)


@pytest.mark.parametrize(
    "value",
    [
        "abcdef0123 456789",
        "abcdef0123\t456789",
        "abc def0123 456789",
    ],
)
def test_rejects_internal_whitespace(mural_module: Any, value: str) -> None:
    with pytest.raises(ValueError) as excinfo:
        mural_module._validate_client_secret(value)
    msg = str(excinfo.value)
    assert "client secret must not contain whitespace" in msg
    assert value not in msg


def test_rejects_too_short_with_length_in_message(mural_module: Any) -> None:
    short = "abc12345"
    with pytest.raises(ValueError) as excinfo:
        mural_module._validate_client_secret(short)
    msg = str(excinfo.value)
    assert "too short" in msg
    assert "(8 chars)" in msg
    assert "expected at least 16" in msg
    assert short not in msg


def test_rejects_just_below_minimum(mural_module: Any) -> None:
    fifteen = "abcdef012345678"
    assert len(fifteen) == 15
    with pytest.raises(ValueError) as excinfo:
        mural_module._validate_client_secret(fifteen)
    msg = str(excinfo.value)
    assert "too short" in msg
    assert fifteen not in msg
