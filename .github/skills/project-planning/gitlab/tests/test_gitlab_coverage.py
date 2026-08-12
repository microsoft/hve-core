# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Targeted tests for previously uncovered GitLab helper branches."""

from __future__ import annotations

import gitlab
import pytest
from pytest_mock import MockerFixture
from test_constants import TEST_API_URL


def test_redact_returns_empty_text_unchanged() -> None:
    assert gitlab._redact("") == ""


def test_normalize_base_url_rejects_empty() -> None:
    with pytest.raises(ValueError):
        gitlab._normalize_base_url("")


def test_normalize_base_url_requires_hostname() -> None:
    with pytest.raises(ValueError):
        gitlab._normalize_base_url("https://")


def test_is_loopback_rejects_empty_host() -> None:
    assert gitlab._is_loopback("") is False
    assert gitlab._is_loopback(None) is False


def test_validate_project_path_rejects_traversal() -> None:
    with pytest.raises(SystemExit):
        gitlab._validate_project_path("../escape")


def test_validate_project_path_rejects_empty() -> None:
    with pytest.raises(SystemExit):
        gitlab._validate_project_path("")


def test_validate_numeric_id_rejects_non_numeric() -> None:
    with pytest.raises(SystemExit):
        gitlab.validate_numeric_id("abc")


def test_validate_numeric_id_rejects_out_of_range() -> None:
    with pytest.raises(SystemExit):
        gitlab.validate_numeric_id("0")
    with pytest.raises(SystemExit):
        gitlab.validate_numeric_id(str(gitlab.MAX_NUMERIC_ID + 1))


def test_summarize_error_body_handles_non_dict_json() -> None:
    assert gitlab._summarize_error_body('"just a string"') == '"just a string"'


def test_read_capped_returns_empty_for_none_chunk() -> None:
    class _Response:
        def read(self, _amount: int) -> None:
            return None

    assert gitlab._read_capped(_Response(), 16) == b""


def test_read_capped_rejects_oversized_when_failing(
    configured_gitlab: object,
) -> None:
    class _Response:
        def read(self, _amount: int) -> bytes:
            return b"x" * 32

    with pytest.raises(SystemExit):
        gitlab._read_capped(_Response(), 16, fail_on_limit=True)


def test_request_bytes_rejects_missing_content_type(
    configured_gitlab: object,
    mocker: MockerFixture,
) -> None:
    class _Headers:
        def get(self, _key: str, _default: object = None) -> str:
            return ""

    class _Response:
        headers = _Headers()

        def __enter__(self) -> "_Response":
            return self

        def __exit__(self, *_args: object) -> bool:
            return False

        def read(self, _amount: int | None = None) -> bytes:
            return b"{}"

    mocker.patch("gitlab._OPENER.open", return_value=_Response())

    with pytest.raises(SystemExit):
        gitlab._request_bytes("GET", f"{TEST_API_URL}/projects/1", require_json=True)


def test_request_bytes_uses_error_context(
    configured_gitlab: object,
    http_error_factory: object,
    capsys: pytest.CaptureFixture[str],
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "gitlab._OPENER.open",
        side_effect=http_error_factory("boom", 500, TEST_API_URL),  # type: ignore[operator]
    )

    with pytest.raises(SystemExit):
        gitlab._request_bytes(
            "GET",
            f"{TEST_API_URL}/projects/1/jobs/2/trace",
            require_json=False,
            error_context="fetching job log",
        )

    assert "fetching job log" in capsys.readouterr().err


def test_mr_update_rejects_oversized_stdin(
    monkeypatch: pytest.MonkeyPatch,
    configured_gitlab: object,
    stdin_factory: object,
) -> None:
    monkeypatch.setenv("GITLAB_PROJECT", "group/project")
    stdin_factory("x" * (gitlab.MAX_BODY_BYTES + 1))  # type: ignore[operator]

    with pytest.raises(SystemExit):
        gitlab.cmd_mr_update(["9"])


def test_mr_comment_rejects_oversized_stdin(
    monkeypatch: pytest.MonkeyPatch,
    configured_gitlab: object,
    stdin_factory: object,
) -> None:
    monkeypatch.setenv("GITLAB_PROJECT", "group/project")
    stdin_factory("x" * (gitlab.MAX_BODY_BYTES + 1))  # type: ignore[operator]

    with pytest.raises(SystemExit):
        gitlab.cmd_mr_comment(["9"])
