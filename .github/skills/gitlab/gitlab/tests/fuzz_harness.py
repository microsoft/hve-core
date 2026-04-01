# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for GitLab skill helper logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import io
import sys
from contextlib import redirect_stderr, suppress

import gitlab
import pytest

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_strip_git_suffix(data: bytes) -> None:
    """Fuzz trimming of trailing .git suffixes."""
    provider = atheris.FuzzedDataProvider(data)
    value = provider.ConsumeUnicodeNoSurrogates(80)
    gitlab.strip_git_suffix(value)


def fuzz_validate_numeric_id(data: bytes) -> None:
    """Fuzz numeric identifier validation."""
    provider = atheris.FuzzedDataProvider(data)
    value = provider.ConsumeUnicodeNoSurrogates(40)
    with redirect_stderr(io.StringIO()), suppress(SystemExit):
        gitlab.validate_numeric_id(value)


def fuzz_extract_field(data: bytes) -> None:
    """Fuzz nested field extraction on representative GitLab payloads."""
    provider = atheris.FuzzedDataProvider(data)
    payload = {
        "iid": provider.ConsumeIntInRange(0, 500),
        "author": {"name": provider.ConsumeUnicodeNoSurrogates(20)},
        "labels": [provider.ConsumeUnicodeNoSurrogates(10) for _ in range(3)],
        "nested": {"deep": {"value": provider.ConsumeIntInRange(0, 99)}},
    }
    path_options = [
        "iid",
        "author.name",
        "labels",
        "nested.deep.value",
        provider.ConsumeUnicodeNoSurrogates(20),
    ]
    gitlab.extract_field(
        payload,
        path_options[provider.ConsumeIntInRange(0, len(path_options) - 1)],
    )


def fuzz_load_json_payload(data: bytes) -> None:
    """Fuzz JSON payload parsing."""
    provider = atheris.FuzzedDataProvider(data)
    raw_payload = provider.ConsumeUnicodeNoSurrogates(100)
    with redirect_stderr(io.StringIO()), suppress(SystemExit):
        gitlab.load_json_payload(raw_payload, "usage: gitlab")


def fuzz_validate_positive_int(data: bytes) -> None:
    """Fuzz validate_positive_int with arbitrary byte strings."""
    fdp = atheris.FuzzedDataProvider(data)
    text = fdp.ConsumeUnicodeNoSurrogates(fdp.remaining_bytes())
    with redirect_stderr(io.StringIO()), suppress(SystemExit):
        gitlab.validate_positive_int(text, "test-field")


def fuzz_parse_fields(data: bytes) -> None:
    """Fuzz parse_fields with arbitrary byte strings."""
    fdp = atheris.FuzzedDataProvider(data)
    count = fdp.ConsumeIntInRange(1, 6)
    args = [
        fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(0, 64))
        for _ in range(count)
    ]
    with redirect_stderr(io.StringIO()), suppress(SystemExit):
        gitlab.parse_fields(args)


FUZZ_TARGETS = [
    fuzz_strip_git_suffix,
    fuzz_validate_numeric_id,
    fuzz_extract_field,
    fuzz_load_json_payload,
    fuzz_validate_positive_int,
    fuzz_parse_fields,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestGitLabFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            ("group/project.git", "group/project"),
            ("group/project", "group/project"),
            (".git", ""),
        ],
    )
    def test_strip_git_suffix(self, value: str, expected: str) -> None:
        assert gitlab.strip_git_suffix(value) == expected

    @pytest.mark.parametrize("value", ["7", "123456"])
    def test_validate_numeric_id_accepts_digits(self, value: str) -> None:
        gitlab.validate_numeric_id(value)

    @pytest.mark.parametrize("value", ["", "abc", "12a", "-1"])
    def test_validate_numeric_id_rejects_invalid_values(self, value: str) -> None:
        with pytest.raises(SystemExit):
            gitlab.validate_numeric_id(value)

    def test_extract_field_handles_nested_values(self) -> None:
        payload = {
            "iid": 9,
            "author": {"name": "Ada"},
            "labels": ["bug", "urgent"],
        }

        assert gitlab.extract_field(payload, "iid") == "9"
        assert gitlab.extract_field(payload, "author.name") == "Ada"
        assert gitlab.extract_field(payload, "labels") == "bug, urgent"

    @pytest.mark.parametrize(
        ("raw_payload", "expected"),
        [
            ('{"title": "MR"}', {"title": "MR"}),
            ("[1, 2, 3]", [1, 2, 3]),
        ],
    )
    def test_load_json_payload(self, raw_payload: str, expected: object) -> None:
        assert gitlab.load_json_payload(raw_payload, "usage: gitlab") == expected


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
