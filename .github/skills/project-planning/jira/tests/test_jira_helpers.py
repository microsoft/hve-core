# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Helper-oriented unit tests for jira.py."""

from __future__ import annotations

import ast
import io
import json
import logging
import pathlib

import jira
import pytest
from conftest import StdinFactory
from test_constants import (
    ERROR_FIELDS_EMPTY,
    FIELDS_COMMENT,
    FIELDS_ISSUE,
    TEST_API_URL,
    TEST_ISSUE_KEY,
    USAGE_CREATE,
)

SOURCE = pathlib.Path(jira.__file__).read_text(encoding="utf-8")
SOURCE_TREE = ast.parse(SOURCE)
SECRET = "s3cr3t-Value_123"
EXPECTED_REDACT_KEYS = (
    "access_token",
    "refresh_token",
    "code_verifier",
    "client_secret",
    "id_token",
    "assertion",
    "client_assertion",
    "device_code",
    "password",
    "jira_pat",
    "api_token",
    "personal_access_token",
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


def test_redact_masks_header_and_query_secrets() -> None:
    payload = (
        "Authorization: Bearer abc123 "
        "PRIVATE-TOKEN: pvt123 "
        "X-API-Key: key123 "
        "Cookie: sessionid=abc "
        "Set-Cookie: sid=abc "
        "https://x/?private_token=abc&access_token=def&token=ghi"
    )

    result = jira._redact(payload)

    assert "abc123" not in result
    assert "pvt123" not in result
    assert "key123" not in result
    assert "sessionid=abc" not in result
    assert "sid=abc" not in result
    assert "[REDACTED]" in result


@pytest.mark.parametrize("key", EXPECTED_REDACT_KEYS)
def test_redact_masks_pinned_json_and_form_keys(key: str) -> None:
    payload = f'{{"{key}": "{SECRET}"}} {key}={SECRET}'

    redacted = jira._redact(payload)

    assert SECRET not in redacted
    assert "[REDACTED]" in redacted


def test_pinned_keyset_excludes_public_pkce_challenge() -> None:
    """``code_challenge`` is public by PKCE design; masking it corrupts the URL."""
    assert jira._REDACT_KEYS == EXPECTED_REDACT_KEYS
    assert "code_challenge" not in jira._REDACT_KEYS

    authorize_url = "https://example.atlassian.net/authorize?code_challenge=abcDEF1"

    assert "abcDEF1" in jira._redact(authorize_url)


def test_redact_masks_mixed_case_escaped_and_encoded_forms() -> None:
    """Upstream payloads vary in casing and encoding; all shapes must mask."""
    payload = (
        '{"Access_Token":"mixed-secret"} '
        r"{\"refresh_token\":\"escaped-secret\"} "
        "api_token%3Dencoded-secret"
    )

    redacted = jira._redact(payload)

    assert "mixed-secret" not in redacted
    assert "escaped-secret" not in redacted
    assert "encoded-secret" not in redacted


def test_redact_masks_azure_sas_query_string() -> None:
    """SAS tokens ride in the query string, so drop everything after the ?."""
    url = f"https://acct.blob.core.windows.net/c/b?sig={SECRET}&se=2026"

    redacted = jira._redact(url)

    assert redacted == "https://acct.blob.core.windows.net/c/b?[REDACTED]"


def test_redact_masks_every_secret_in_a_multi_secret_line() -> None:
    payload = f"a access_token={SECRET}1 b api_token={SECRET}2 c"

    redacted = jira._redact(payload)

    assert f"{SECRET}1" not in redacted
    assert f"{SECRET}2" not in redacted


def test_redact_is_idempotent() -> None:
    """Re-redacting already-redacted text must not corrupt the marker."""
    once = jira._redact(f"api_token={SECRET}")

    assert jira._redact(once) == once


@pytest.mark.parametrize("payload", ["", "   "])
def test_redact_handles_empty_payloads(payload: str) -> None:
    assert jira._redact(payload).strip() == ""


def test_redact_preserves_unicode_around_masked_secrets() -> None:
    redacted = jira._redact(f"\u65e5\u672c\u8a9e api_token={SECRET} \u2713")

    assert SECRET not in redacted
    assert "\u65e5\u672c\u8a9e" in redacted
    assert "\u2713" in redacted


def test_client_repr_omits_authorization_header() -> None:
    client = jira.JiraClient(
        api_url=TEST_API_URL,
        auth_header=f"Bearer {SECRET}",
        use_legacy_search=True,
        audit_actor="actor",
        audit_origin="https://jira.example.com",
        auth_mode="data-center-pat",
    )

    assert SECRET not in repr(client)
    assert "auth_header" not in repr(client)


def test_api_error_and_debug_traceback_are_secret_free(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    caplog: pytest.LogCaptureFixture,
) -> None:
    error = jira.JiraAPIError(message=f"api_token={SECRET}")
    monkeypatch.setenv("JIRA_DEBUG", "1")
    with caplog.at_level(logging.ERROR, logger="jira"):
        jira._emit(f"api_token={SECRET}")
    jira._emit_debug_traceback(error)

    captured = capsys.readouterr()
    assert SECRET not in str(error)
    assert SECRET not in repr(error)
    assert SECRET not in captured.err
    assert SECRET not in caplog.text


def test_source_print_calls_remain_in_emit_helpers() -> None:
    owners: list[str] = []
    for node in ast.walk(SOURCE_TREE):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if any(
            isinstance(child, ast.Call)
            and isinstance(child.func, ast.Name)
            and child.func.id == "print"
            for child in ast.walk(node)
        ):
            owners.append(node.name)

    assert set(owners) <= {
        "_emit",
        "_emit_stdout",
        "_emit_structured_stdout",
        "_emit_debug_traceback",
    }
    assert "LOGGER.exception(" not in SOURCE


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


def test_read_json_argument_reads_bounded_stdin(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class LimitedStream(io.StringIO):
        def read(self, size: int | None = -1) -> str:
            if size is None or size < 0:
                raise AssertionError("unbounded stdin read")
            return super().read(size)

    monkeypatch.setattr("sys.stdin", LimitedStream('{"fields": {"summary": "stdin"}}'))

    assert jira._read_json_argument(None, USAGE_CREATE) == {
        "fields": {"summary": "stdin"}
    }


def test_read_json_argument_rejects_oversized_stdin(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class LimitedStream(io.StringIO):
        def read(self, size: int | None = -1) -> str:
            if size is None or size < 0:
                raise AssertionError("unbounded stdin read")
            return super().read(size)

    monkeypatch.setattr("sys.stdin", LimitedStream("x" * (jira.MAX_BODY_BYTES + 1)))

    with pytest.raises(jira.ScriptError) as exc_info:
        jira._read_json_argument(None, USAGE_CREATE)

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert "size limit" in str(exc_info.value).lower()


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


def test_print_selected_fields_preserves_empty_edge_columns(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._print_selected_fields(
        [{"first": "", "title": "fix secret token password", "last": ""}],
        ["first", "title", "last"],
    )

    lines = capsys.readouterr().out.splitlines()
    assert lines[1].split("\t") == ["", "fix secret token password", ""]


def test_sanitize_structured_preserves_sensitive_container_shape() -> None:
    payload = {
        "summary": "Basic auth broken",
        "api_token": {"value": SECRET, "nested": [SECRET]},
    }

    sanitized = jira._sanitize_structured(payload)

    assert sanitized == {
        "summary": "Basic auth broken",
        "api_token": {"value": "[REDACTED]", "nested": ["[REDACTED]"]},
    }


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


def test_emit_writes_exactly_one_stderr_line() -> None:
    """_emit prints once; logging's lastResort must not echo the record.

    _emit both logs at ERROR and prints to stderr. A logger with no handler
    falls back to logging.lastResort, which writes WARNING-or-above records to
    stderr as well, so every CLI error would appear twice.
    """
    assert any(isinstance(h, logging.NullHandler) for h in jira.LOGGER.handlers)


def test_emit_is_not_duplicated_by_last_resort(
    capsys: pytest.CaptureFixture[str],
) -> None:
    jira._emit("single line")

    lines = [line for line in capsys.readouterr().err.splitlines() if line.strip()]

    assert lines == ["single line"]
