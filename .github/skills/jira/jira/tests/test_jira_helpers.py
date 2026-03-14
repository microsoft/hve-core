"""Helper-oriented unit tests for jira.py."""

from __future__ import annotations

import json

import jira
import pytest
from conftest import StdinFactory
from test_constants import (
    ERROR_FIELDS_EMPTY,
    FIELDS_COMMENT,
    FIELDS_ISSUE,
    TEST_ISSUE_KEY,
    USAGE_CREATE,
)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ('{"errorMessages": ["bad input", "try again"]}', "bad input; try again"),
        ('{"errors": {"summary": "required"}}', "summary: required"),
        ('{"status": "bad"}', '{"status": "bad"}'),
        ("plain text error", "plain text error"),
        ("   ", "No error details returned"),
    ],
)
def test_extract_error_message(raw: str, expected: str) -> None:
    assert jira._extract_error_message(raw) == expected


@pytest.mark.parametrize("issue_key", [TEST_ISSUE_KEY, "ABC1-9", "Proj9-123"])
def test_validate_issue_key_accepts_valid_values(issue_key: str) -> None:
    jira._validate_issue_key(issue_key)


@pytest.mark.parametrize("issue_key", ["", "PROJ", "123-1", "PROJ_1", "PROJ-"])
def test_validate_issue_key_rejects_invalid_values(issue_key: str) -> None:
    with pytest.raises(jira.ScriptError) as exc_info:
        jira._validate_issue_key(issue_key)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == f"Invalid issue key: {issue_key}"


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ('{"fields": {"summary": "x"}}', {"fields": {"summary": "x"}}),
        ("[1, 2]", [1, 2]),
    ],
)
def test_read_json_argument_parses_argument_payload(
    payload: str,
    expected: object,
) -> None:
    assert jira._read_json_argument(payload, USAGE_CREATE) == expected


def test_read_json_argument_reads_stdin(stdin_factory: StdinFactory) -> None:
    stdin_factory('{"fields": {"summary": "stdin"}}')

    assert jira._read_json_argument(None, USAGE_CREATE) == {
        "fields": {"summary": "stdin"}
    }


def test_read_json_argument_requires_content(stdin_factory: StdinFactory) -> None:
    stdin_factory("")

    with pytest.raises(jira.ScriptError) as exc_info:
        jira._read_json_argument(None, USAGE_CREATE)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == USAGE_CREATE


def test_read_json_argument_rejects_invalid_json() -> None:
    with pytest.raises(jira.ScriptError) as exc_info:
        jira._read_json_argument("{bad json}", USAGE_CREATE)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert "Invalid JSON payload" in str(exc_info.value)


@pytest.mark.parametrize(
    ("payload", "path", "expected"),
    [
        ({"key": TEST_ISSUE_KEY}, "key", TEST_ISSUE_KEY),
        ({"fields": {"summary": "Issue title"}}, "fields.summary", "Issue title"),
        ({"fields": {"labels": ["bug", "urgent"]}}, "fields.labels", "bug, urgent"),
        ({"fields": {"metadata": {"count": 3}}}, "fields.metadata", '{"count": 3}'),
        ({"fields": {"summary": None}}, "fields.summary", ""),
        ({"fields": "wrong"}, "fields.summary", ""),
    ],
)
def test_extract_field_returns_expected_values(
    payload: object,
    path: str,
    expected: str,
) -> None:
    assert jira._extract_field(payload, path) == expected


@pytest.mark.parametrize(
    ("value", "expected"),
    [(7, "7"), ("text", "text"), ({"x": 1}, '{"x": 1}'), ([1, 2], "[1, 2]")],
)
def test_stringify_value_renders_supported_types(value: object, expected: str) -> None:
    assert jira._stringify_value(value) == expected


def test_split_fields_returns_expected_list() -> None:
    assert jira._split_fields(" key, fields.summary , fields.status.name ") == [
        "key",
        "fields.summary",
        "fields.status.name",
    ]


@pytest.mark.parametrize("raw_fields", [None, ""])
def test_split_fields_returns_none_for_missing_value(raw_fields: str | None) -> None:
    assert jira._split_fields(raw_fields) is None


def test_split_fields_rejects_blank_field_list() -> None:
    with pytest.raises(jira.ScriptError) as exc_info:
        jira._split_fields(" , ")

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == ERROR_FIELDS_EMPTY


def test_print_selected_fields_formats_lists(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_selected_fields(
        [
            {"key": TEST_ISSUE_KEY, "fields": {"summary": "One"}},
            {"key": "PROJ-2", "fields": {"summary": "Two"}},
        ],
        FIELDS_ISSUE,
    )

    assert capsys.readouterr().out.splitlines() == [
        "key\tfields.summary",
        f"{TEST_ISSUE_KEY}\tOne",
        "PROJ-2\tTwo",
    ]


def test_print_selected_fields_formats_single_object(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_selected_fields(
        {
            "_issue": TEST_ISSUE_KEY,
            "author": {"displayName": "Ada"},
            "body": "done",
        },
        FIELDS_COMMENT,
    )

    assert capsys.readouterr().out.splitlines() == [
        f"_issue: {TEST_ISSUE_KEY}",
        "author.displayName: Ada",
        "body: done",
    ]


def test_print_result_with_none_produces_no_output(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_result(None, None)

    assert capsys.readouterr().out == ""


def test_print_result_with_fields_delegates_to_selected_fields(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_result(
        {"key": TEST_ISSUE_KEY, "fields": {"summary": "One"}},
        FIELDS_ISSUE,
    )

    assert capsys.readouterr().out.splitlines() == [
        f"key: {TEST_ISSUE_KEY}",
        "fields.summary: One",
    ]


def test_print_result_prints_string_and_json(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_result("plain text", None)
    jira._print_result({"key": TEST_ISSUE_KEY}, None)

    lines = capsys.readouterr().out.splitlines()
    assert lines[0] == "plain text"
    assert json.loads("\n".join(lines[1:])) == {"key": TEST_ISSUE_KEY}
