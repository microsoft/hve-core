# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Transport and environment tests for gitlab.py."""

from __future__ import annotations

import json
import urllib.request
from typing import cast

import gitlab
import pytest
from conftest import ConfiguredGitLab, HttpErrorFactory, ResponseFactory
from pytest_mock import MockerFixture
from test_constants import (
    TEST_API_URL,
    TEST_GITLAB_TOKEN,
    TEST_GITLAB_URL,
    USAGE_JOB_LOG,
)

REQUEST_ENDPOINT = f"{TEST_API_URL}/test"
REQUEST_JSON = {"iid": 7, "title": "MR"}
REQUEST_BODY = '{"iid": 7, "title": "MR"}'
NON_JSON_BODY = "plain text output"
PROJECT_NOT_FOUND = "GITLAB_PROJECT not set and no git remote found"
PARSE_REMOTE_ERROR = "cannot parse git remote URL"
EMPTY_REMOTE_PATH_ERROR = "cannot extract project path from remote"
TRACE_UNAVAILABLE = "trace unavailable"


def _request_headers(request: urllib.request.Request) -> dict[str, str]:
    return {key.lower(): value for key, value in request.header_items()}


class TestRequireEnvironment:
    """Tests for require_environment."""

    def test_loads_environment_and_sets_api_url(self) -> None:
        gitlab.require_environment()

        assert gitlab.gitlab_url == TEST_GITLAB_URL
        assert gitlab.gitlab_token == TEST_GITLAB_TOKEN
        assert gitlab.api_url == TEST_API_URL

    @pytest.mark.parametrize(
        ("env_name", "env_value", "expected_message"),
        [
            ("GITLAB_URL", "", "GITLAB_URL is not set"),
            ("GITLAB_URL", "gitlab.example.com", "GITLAB_URL must start with https://"),
            ("GITLAB_TOKEN", "", "GITLAB_TOKEN is not set"),
        ],
    )
    def test_rejects_invalid_environment(
        self,
        monkeypatch: pytest.MonkeyPatch,
        env_name: str,
        env_value: str,
        expected_message: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv(env_name, env_value)

        with pytest.raises(SystemExit) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert expected_message in capsys.readouterr().err


class TestProject:
    """Tests for project."""

    def test_prefers_explicit_project_environment(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_PROJECT", "group/project name")

        assert gitlab.project() == "group%2Fproject%20name"

    @pytest.mark.parametrize(
        ("remote_url", "expected"),
        [
            ("git@gitlab.com:group/project.git\n", "group%2Fproject"),
            ("https://gitlab.com/group/project.git\n", "group%2Fproject"),
            ("http://gitlab.local/group/sub/project\n", "group%2Fsub%2Fproject"),
        ],
    )
    def test_parses_supported_remote_urls(
        self,
        mocker: MockerFixture,
        remote_url: str,
        expected: str,
    ) -> None:
        mocker.patch("subprocess.check_output", return_value=remote_url)
        assert gitlab.project() == expected

    def test_requires_remote_when_project_not_configured(
        self, mocker: MockerFixture, capsys: pytest.CaptureFixture[str]
    ) -> None:
        mocker.patch("subprocess.check_output", side_effect=FileNotFoundError)
        with pytest.raises(SystemExit) as exc_info:
            gitlab.project()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert PROJECT_NOT_FOUND in capsys.readouterr().err

    def test_rejects_unparseable_remote(
        self, mocker: MockerFixture, capsys: pytest.CaptureFixture[str]
    ) -> None:
        mocker.patch(
            "subprocess.check_output",
            return_value="ssh://gitlab.example.com/group/project.git\n",
        )
        with pytest.raises(SystemExit) as exc_info:
            gitlab.project()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert PARSE_REMOTE_ERROR in capsys.readouterr().err

    def test_rejects_empty_path_after_host(
        self, mocker: MockerFixture, capsys: pytest.CaptureFixture[str]
    ) -> None:
        mocker.patch(
            "subprocess.check_output", return_value="https://gitlab.example.com/.git\n"
        )
        with pytest.raises(SystemExit) as exc_info:
            gitlab.project()

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert EMPTY_REMOTE_PATH_ERROR in capsys.readouterr().err


class TestRequest:
    """Tests for request."""

    def test_returns_parsed_json_and_prints_pretty_output(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        captured_request: dict[str, urllib.request.Request] = {}

        def fake_urlopen(request: urllib.request.Request) -> object:
            captured_request["request"] = request
            return response_factory(REQUEST_BODY)

        mocker.patch("urllib.request.urlopen", side_effect=fake_urlopen)
        parsed = gitlab.request("POST", REQUEST_ENDPOINT, {"title": "MR"})

        assert parsed == REQUEST_JSON
        request = cast(urllib.request.Request, captured_request["request"])
        request_data = cast(bytes, request.data)
        assert request.full_url == REQUEST_ENDPOINT
        assert request.get_method() == "POST"
        assert json.loads(request_data.decode()) == {"title": "MR"}
        assert _request_headers(request)["private-token"] == TEST_GITLAB_TOKEN
        assert '"iid": 7' in capsys.readouterr().out

    def test_suppresses_output_when_quiet(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        mocker.patch(
            "urllib.request.urlopen",
            return_value=response_factory('{"iid": 7}'),
        )
        parsed = gitlab.request("GET", REQUEST_ENDPOINT, quiet=True)

        assert parsed == {"iid": 7}
        assert capsys.readouterr().out == ""

    def test_returns_none_for_empty_body(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
    ) -> None:
        mocker.patch("urllib.request.urlopen", return_value=response_factory("   "))
        assert gitlab.request("GET", REQUEST_ENDPOINT) is None

    def test_prints_raw_text_for_non_json_response(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        mocker.patch(
            "urllib.request.urlopen",
            return_value=response_factory(NON_JSON_BODY),
        )
        parsed = gitlab.request("GET", REQUEST_ENDPOINT)

        assert parsed is None
        assert capsys.readouterr().out.strip() == NON_JSON_BODY

    def test_reports_structured_http_error(
        self,
        configured_gitlab: ConfiguredGitLab,
        http_error_factory: HttpErrorFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = http_error_factory('{"message": "forbidden"}', code=403)

        mocker.patch("urllib.request.urlopen", side_effect=error)
        with pytest.raises(SystemExit) as exc_info:
            gitlab.request("GET", REQUEST_ENDPOINT)

        assert exc_info.value.code == gitlab.EXIT_FAILURE
        error_lines = capsys.readouterr().err.splitlines()
        assert "forbidden" in error_lines[0]
        assert f"error: HTTP 403 from GET {REQUEST_ENDPOINT}" in error_lines[1]

    def test_reports_raw_http_error_body(
        self,
        configured_gitlab: ConfiguredGitLab,
        http_error_factory: HttpErrorFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = http_error_factory("Service unavailable", code=503)

        mocker.patch("urllib.request.urlopen", side_effect=error)
        with pytest.raises(SystemExit):
            gitlab.request("DELETE", REQUEST_ENDPOINT)

        error_lines = capsys.readouterr().err.splitlines()
        assert error_lines[0] == "Service unavailable"
        assert error_lines[1] == f"error: HTTP 503 from DELETE {REQUEST_ENDPOINT}"


class TestCmdJobLog:
    """Tests for cmd_job_log."""

    def test_prints_job_log(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        mocker.patch(
            "urllib.request.urlopen",
            return_value=response_factory("line one\nline two"),
        )
        gitlab.cmd_job_log(["99"])

        assert capsys.readouterr().out.strip().splitlines() == ["line one", "line two"]

    def test_requires_job_id(self, capsys: pytest.CaptureFixture[str]) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.cmd_job_log([])

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert USAGE_JOB_LOG in capsys.readouterr().err

    def test_rejects_non_numeric_job_id(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        with pytest.raises(SystemExit):
            gitlab.cmd_job_log(["abc"])

        assert "expected numeric ID, got: abc" in capsys.readouterr().err

    def test_reports_http_error_for_log_fetch(
        self,
        configured_gitlab: ConfiguredGitLab,
        http_error_factory: HttpErrorFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = http_error_factory(TRACE_UNAVAILABLE, code=404)

        mocker.patch("urllib.request.urlopen", side_effect=error)
        with pytest.raises(SystemExit) as exc_info:
            gitlab.cmd_job_log(["99"])

        assert exc_info.value.code == gitlab.EXIT_FAILURE
        error_lines = capsys.readouterr().err.splitlines()
        assert error_lines[0] == TRACE_UNAVAILABLE
        assert error_lines[1] == "error: HTTP 404 fetching job log"
