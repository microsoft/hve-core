# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for Jira skill helper logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

import pytest

import jira

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_extract_error_message(data: bytes) -> None:
    """Fuzz extraction of error text from raw payloads."""
    provider = atheris.FuzzedDataProvider(data)
    raw_value = provider.ConsumeUnicodeNoSurrogates(120)
    jira._extract_error_message(raw_value)


def fuzz_validate_issue_key(data: bytes) -> None:
    """Fuzz issue-key validation with arbitrary text."""
    provider = atheris.FuzzedDataProvider(data)
    issue_key = provider.ConsumeUnicodeNoSurrogates(40)
    with suppress(jira.ScriptError):
        jira._validate_issue_key(issue_key)


def fuzz_extract_field(data: bytes) -> None:
    """Fuzz nested field extraction across representative payload shapes."""
    provider = atheris.FuzzedDataProvider(data)
    payload = {
        "key": provider.ConsumeUnicodeNoSurrogates(20),
        "fields": {
            "summary": provider.ConsumeUnicodeNoSurrogates(40),
            "labels": [provider.ConsumeUnicodeNoSurrogates(12) for _ in range(3)],
            "metadata": {"count": provider.ConsumeIntInRange(0, 50)},
        },
    }
    path_options = [
        "key",
        "fields.summary",
        "fields.labels",
        "fields.metadata.count",
        provider.ConsumeUnicodeNoSurrogates(30),
    ]
    jira._extract_field(
        payload,
        path_options[provider.ConsumeIntInRange(0, len(path_options) - 1)],
    )


def fuzz_split_fields(data: bytes) -> None:
    """Fuzz comma-delimited field parsing."""
    provider = atheris.FuzzedDataProvider(data)
    raw_fields = provider.ConsumeUnicodeNoSurrogates(80)
    with suppress(jira.ScriptError):
        jira._split_fields(raw_fields)


def fuzz_read_json_argument(data: bytes) -> None:
    """Fuzz the _read_json_argument helper with arbitrary byte strings."""
    fdp = atheris.FuzzedDataProvider(data)
    text = fdp.ConsumeUnicodeNoSurrogates(fdp.remaining_bytes())
    with suppress(jira.ScriptError):
        jira._read_json_argument(text, "usage: test")


FUZZ_TARGETS = [
    fuzz_extract_error_message,
    fuzz_validate_issue_key,
    fuzz_extract_field,
    fuzz_split_fields,
    fuzz_read_json_argument,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestJiraFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    @pytest.mark.parametrize(
        ("raw_value", "expected"),
        [
            ('{"errorMessages": ["bad input"]}', "bad input"),
            ('{"errors": {"summary": "required"}}', "summary: required"),
            ("plain text error", "plain text error"),
            ("", "No error details returned"),
        ],
    )
    def test_extract_error_message(self, raw_value: str, expected: str) -> None:
        assert jira._extract_error_message(raw_value) == expected

    @pytest.mark.parametrize("issue_key", ["PROJ-1", "Proj9-123"])
    def test_validate_issue_key_accepts_valid_values(self, issue_key: str) -> None:
        jira._validate_issue_key(issue_key)

    @pytest.mark.parametrize("issue_key", ["", "PROJ", "123-1", "PROJ_"])
    def test_validate_issue_key_rejects_invalid_values(self, issue_key: str) -> None:
        with pytest.raises(jira.ScriptError):
            jira._validate_issue_key(issue_key)

    def test_extract_field_handles_nested_values(self) -> None:
        payload = {
            "fields": {
                "summary": "Issue title",
                "labels": ["bug", "urgent"],
                "metadata": {"count": 3},
            }
        }

        assert jira._extract_field(payload, "fields.summary") == "Issue title"
        assert jira._extract_field(payload, "fields.labels") == "bug, urgent"
        assert jira._extract_field(payload, "fields.metadata") == '{"count": 3}'

    def test_split_fields_supports_csv_lists(self) -> None:
        assert jira._split_fields(" key, fields.summary ") == [
            "key",
            "fields.summary",
        ]


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
