# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `_unwrap_value_envelope` defensive unwrap helper (Phase A)."""

from __future__ import annotations

import argparse
from typing import Any

import pytest


def test_unwraps_sole_value_dict(mural_module: Any) -> None:
    record = {"value": {"id": "abc", "type": "shape"}}
    assert mural_module._unwrap_value_envelope(record) == {
        "id": "abc",
        "type": "shape",
    }


def test_passthrough_when_value_is_none(mural_module: Any) -> None:
    record = {"value": None}
    assert mural_module._unwrap_value_envelope(record) is record


def test_passthrough_when_value_is_list(mural_module: Any) -> None:
    record = {"value": [1, 2, 3]}
    assert mural_module._unwrap_value_envelope(record) is record


def test_passthrough_when_value_is_primitive(mural_module: Any) -> None:
    record = {"value": "scalar"}
    assert mural_module._unwrap_value_envelope(record) is record


def test_passthrough_when_extra_keys_present(mural_module: Any) -> None:
    record = {"value": {"id": "abc"}, "next": "cursor"}
    assert mural_module._unwrap_value_envelope(record) is record


def test_passthrough_when_no_value_key(mural_module: Any) -> None:
    record = {"id": "abc", "type": "shape"}
    assert mural_module._unwrap_value_envelope(record) is record


def test_passthrough_when_empty_dict(mural_module: Any) -> None:
    record: dict[str, Any] = {}
    assert mural_module._unwrap_value_envelope(record) is record


@pytest.mark.parametrize(
    "value",
    ["string", 42, 3.14, None, True, False, b"bytes"],
)
def test_passthrough_non_dict_input(mural_module: Any, value: Any) -> None:
    assert mural_module._unwrap_value_envelope(value) is value


def test_passthrough_for_list_input(mural_module: Any) -> None:
    record = [{"value": {"x": 1}}]
    assert mural_module._unwrap_value_envelope(record) is record


def test_does_not_recurse_on_nested_value_envelope(mural_module: Any) -> None:
    record = {"value": {"value": {"id": "abc"}}}
    unwrapped = mural_module._unwrap_value_envelope(record)
    assert unwrapped == {"value": {"id": "abc"}}


def test_emit_record_calls_unwrap_first(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """`_emit_record` defensively unwraps before formatting."""
    calls: list[Any] = []
    real_unwrap = mural_module._unwrap_value_envelope

    def _spy(record: Any) -> Any:
        calls.append(record)
        return real_unwrap(record)

    monkeypatch.setattr(mural_module, "_unwrap_value_envelope", _spy)
    args = argparse.Namespace(format="json", fields=None)
    rc = mural_module._emit_record({"value": {"id": "abc"}}, args)
    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"value": {"id": "abc"}}]
    captured = capsys.readouterr()
    assert '"id": "abc"' in captured.out
    assert '"value"' not in captured.out
