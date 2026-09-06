# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Transport and environment tests for gitlab.py."""

from __future__ import annotations

import io
import json
import pathlib
import subprocess
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
)

REQUEST_ENDPOINT = f"{TEST_API_URL}/test"
REQUEST_ENDPOINT_WITH_CONTEXT = f"{REQUEST_ENDPOINT}?private_token=hidden#fragment"
REQUEST_JSON = {"iid": 7, "title": "MR"}
REQUEST_BODY = '{"iid": 7, "title": "MR"}'
NON_JSON_BODY = "plain text output"
PROJECT_NOT_FOUND = "GITLAB_PROJECT not set and no git remote found"
PARSE_REMOTE_ERROR = "cannot parse git remote URL"
EMPTY_REMOTE_PATH_ERROR = "cannot extract project path from remote"
TRACE_UNAVAILABLE = "trace unavailable"


def _request_headers(request: urllib.request.Request) -> dict[str, str]:
    return {key.lower(): value for key, value in request.header_items()}


def _json_response(response_factory: ResponseFactory, body: str) -> object:
    response = response_factory(body)
    response.headers = {"Content-Type": "application/json"}
    return response


def _text_response(response_factory: ResponseFactory, body: str) -> object:
    response = response_factory(body)
    response.headers = {"Content-Type": "text/plain"}
    return response


def _oauth_profile(
    *,
    issuer: str = TEST_GITLAB_URL,
    client_id: str = "client",
    expires_at: int = 4_102_444_800,
) -> gitlab.credentials.Profile:
    return {
        "issuer": issuer,
        "client_id": client_id,
        "access_token": "oauth-access",
        "refresh_token": "oauth-refresh",
        "token_type": "Bearer",
        "obtained_at": 1,
        "expires_at": expires_at,
        "scopes": ["api"],
        "usable": True,
    }


class TestRequireEnvironment:
    """Tests for require_environment."""

    def test_loads_environment_and_sets_api_url(self) -> None:
        gitlab.require_environment()

        assert gitlab.gitlab_url == TEST_GITLAB_URL
        assert gitlab.auth_context is not None
        assert gitlab.auth_context.token == TEST_GITLAB_TOKEN
        assert gitlab.api_url == TEST_API_URL

    @pytest.mark.parametrize(
        "base_url",
        [
            "https://gitlab.example.com/evil",
            "https://user@example.com",
            "https://gitlab.example.com?query=1",
            "https://gitlab.example.com/path",
            "https://gitlab.example.com\n",
        ],
    )
    def test_rejects_non_origin_base_urls(
        self,
        monkeypatch: pytest.MonkeyPatch,
        base_url: str,
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", base_url)
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "origin-only" in str(exc_info.value)

    def test_accepts_clean_origin_base_url(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", "https://gitlab.example.com/")
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)

        gitlab.require_environment()

        assert gitlab.api_url == "https://gitlab.example.com/api/v4"

    def test_oauth_mode_rejects_legacy_token(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_AUTH_MODE", "oauth")
        monkeypatch.setenv("GITLAB_OAUTH_CLIENT_ID", "client")

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_legacy_mode_is_explicit(self) -> None:
        gitlab.require_environment()

        assert gitlab.auth_context is not None
        assert gitlab.auth_context.mode == "legacy-token"

    def test_unset_mode_does_not_infer_legacy_from_token(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.delenv("GITLAB_AUTH_MODE")

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "must not be set in oauth mode" in str(exc_info.value)

    def test_oauth_mode_loads_bound_profile(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        gitlab.credentials.save_store(
            store_path,
            {"schema_version": 1, "profiles": {"default": _oauth_profile()}},
        )
        monkeypatch.setenv("GITLAB_AUTH_MODE", "oauth")
        monkeypatch.delenv("GITLAB_TOKEN")
        monkeypatch.setenv("GITLAB_OAUTH_CLIENT_ID", "client")
        monkeypatch.setenv("GITLAB_TOKEN_STORE", str(store_path))

        gitlab.require_environment()

        assert gitlab.auth_context == gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=store_path,
            client_id="client",
        )

    def test_auth_context_repr_omits_legacy_token(self) -> None:
        context = gitlab.AuthContext(
            mode="legacy-token",
            issuer=TEST_GITLAB_URL,
            token=TEST_GITLAB_TOKEN,
        )

        assert TEST_GITLAB_TOKEN not in repr(context)

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
    ) -> None:
        monkeypatch.setenv(env_name, env_value)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert expected_message in str(exc_info.value)


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
        self, mocker: MockerFixture
    ) -> None:
        mocker.patch("subprocess.check_output", side_effect=FileNotFoundError)
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.project()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert PROJECT_NOT_FOUND in str(exc_info.value)

    def test_rejects_unparseable_remote(self, mocker: MockerFixture) -> None:
        mocker.patch(
            "subprocess.check_output",
            return_value="ssh://gitlab.example.com/group/project.git\n",
        )
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.project()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert PARSE_REMOTE_ERROR in str(exc_info.value)

    def test_rejects_empty_path_after_host(self, mocker: MockerFixture) -> None:
        mocker.patch(
            "subprocess.check_output", return_value="https://gitlab.example.com/.git\n"
        )
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.project()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert EMPTY_REMOTE_PATH_ERROR in str(exc_info.value)

    @pytest.mark.parametrize(
        "remote_url",
        [
            "https://gitlab.example.com/../group/project.git",
            "https://gitlab.example.com/group/%2Fproject.git",
            "https://gitlab.example.com/group\\project.git",
        ],
    )
    def test_rejects_invalid_project_paths(
        self,
        mocker: MockerFixture,
        remote_url: str,
    ) -> None:
        mocker.patch("subprocess.check_output", return_value=remote_url)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.project()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "invalid project path" in str(exc_info.value)

    def test_accepts_owner_project_path_from_remote(
        self, mocker: MockerFixture
    ) -> None:
        mocker.patch(
            "subprocess.check_output",
            return_value="https://gitlab.example.com/owner/project.git\n",
        )

        assert gitlab.project() == "owner%2Fproject"


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

        def fake_urlopen(
            request: urllib.request.Request, timeout: int | None = None
        ) -> object:
            captured_request["request"] = request
            return _json_response(response_factory, REQUEST_BODY)

        mocker.patch("gitlab._OPENER.open", side_effect=fake_urlopen)
        parsed = gitlab.request("POST", REQUEST_ENDPOINT, {"title": "MR"})

        assert parsed == REQUEST_JSON
        request = cast(urllib.request.Request, captured_request["request"])
        request_data = cast(bytes, request.data)
        assert request.full_url == REQUEST_ENDPOINT
        assert request.get_method() == "POST"
        assert json.loads(request_data.decode()) == {"title": "MR"}
        assert _request_headers(request)["private-token"] == TEST_GITLAB_TOKEN
        assert '"iid": 7' in capsys.readouterr().out

    def test_oauth_request_uses_bearer_header(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
    ) -> None:
        profile = {"access_token": "oauth-access"}
        gitlab.auth_context = gitlab.AuthContext(
            mode="oauth", issuer="https://gitlab.example.com"
        )
        mocker.patch("gitlab._oauth_profile", return_value=profile)
        opener = mocker.patch(
            "gitlab._OPENER.open",
            return_value=_json_response(response_factory, REQUEST_BODY),
        )

        gitlab.request("GET", REQUEST_ENDPOINT, quiet=True)

        headers = _request_headers(opener.call_args.args[0])
        assert headers["authorization"] == "Bearer oauth-access"
        assert "private-token" not in headers

    def test_oauth_get_refreshes_and_replays_once_after_401(
        self,
        response_factory: ResponseFactory,
        http_error_factory: HttpErrorFactory,
        mocker: MockerFixture,
    ) -> None:
        gitlab.auth_context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=pathlib.Path("/unused"),
            client_id="client",
        )
        opener = mocker.patch(
            "gitlab._OPENER.open",
            side_effect=[
                http_error_factory("unauthorized", 401, REQUEST_ENDPOINT),
                _json_response(response_factory, REQUEST_BODY),
            ],
        )
        mocker.patch(
            "gitlab._force_oauth_refresh",
            return_value=_oauth_profile(),
        )

        result = gitlab._request_bytes("GET", REQUEST_ENDPOINT)

        assert json.loads(result) == REQUEST_JSON
        assert opener.call_count == 2

    def test_oauth_post_does_not_replay_after_401(
        self,
        http_error_factory: HttpErrorFactory,
        mocker: MockerFixture,
    ) -> None:
        gitlab.auth_context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=pathlib.Path("/unused"),
            client_id="client",
        )
        opener = mocker.patch(
            "gitlab._OPENER.open",
            side_effect=http_error_factory("unauthorized", 401, REQUEST_ENDPOINT),
        )
        refresh = mocker.patch("gitlab._force_oauth_refresh")

        with pytest.raises(gitlab.GitLabAPIError):
            gitlab._request_bytes("POST", REQUEST_ENDPOINT, data={"title": "MR"})

        assert opener.call_count == 1
        refresh.assert_not_called()

    def test_retryable_refresh_failure_preserves_profile(
        self,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        profile = _oauth_profile(expires_at=1)
        gitlab.credentials.save_store(
            store_path,
            {"schema_version": 1, "profiles": {"default": profile}},
        )
        context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=store_path,
            client_id="client",
        )
        mocker.patch(
            "gitlab.oauth.refresh_profile",
            side_effect=gitlab.oauth.OAuthError(
                "connection refused",
                retryable=True,
            ),
        )

        with pytest.raises(gitlab.GitLabError):
            gitlab._oauth_profile(context)

        stored = gitlab.credentials.get_profile(
            gitlab.credentials.load_store(store_path),
            "default",
        )
        assert stored["usable"] is True

    def test_uncertain_refresh_failure_retains_unusable_tombstone(
        self,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        profile = _oauth_profile(expires_at=1)
        gitlab.credentials.save_store(
            store_path,
            {"schema_version": 1, "profiles": {"default": profile}},
        )
        context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=store_path,
            client_id="client",
        )
        mocker.patch(
            "gitlab.oauth.refresh_profile",
            side_effect=gitlab.oauth.OAuthError(
                "response lost",
                retryable=True,
                completion_uncertain=True,
            ),
        )

        with pytest.raises(gitlab.GitLabError):
            gitlab._oauth_profile(context)

        stored = gitlab.credentials.get_profile(
            gitlab.credentials.load_store(store_path),
            "default",
        )
        assert stored["usable"] is False

    def test_terminal_refresh_failure_marks_profile_unusable(
        self,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        profile = _oauth_profile(expires_at=1)
        gitlab.credentials.save_store(
            store_path,
            {"schema_version": 1, "profiles": {"default": profile}},
        )
        context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=store_path,
            client_id="client",
        )
        mocker.patch(
            "gitlab.oauth.refresh_profile",
            side_effect=gitlab.oauth.OAuthError(
                "invalid grant",
                code="invalid_grant",
            ),
        )

        with pytest.raises(gitlab.GitLabError):
            gitlab._oauth_profile(context)

        stored = gitlab.credentials.get_profile(
            gitlab.credentials.load_store(store_path),
            "default",
        )
        assert stored["usable"] is False

    def test_locked_profile_binding_mismatch_prevents_refresh(
        self,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        gitlab.credentials.save_store(
            store_path,
            {
                "schema_version": 1,
                "profiles": {
                    "default": _oauth_profile(
                        issuer="https://attacker.example.com",
                        expires_at=1,
                    )
                },
            },
        )
        context = gitlab.AuthContext(
            mode="oauth",
            issuer=TEST_GITLAB_URL,
            profile_name="default",
            store_path=store_path,
            client_id="client",
        )
        refresh = mocker.patch("gitlab.oauth.refresh_profile")

        with pytest.raises(gitlab.GitLabError):
            gitlab._oauth_profile(context)

        refresh.assert_not_called()

    def test_suppresses_output_when_quiet(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        mocker.patch(
            "gitlab._OPENER.open",
            return_value=_json_response(response_factory, '{"iid": 7}'),
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
        mocker.patch(
            "gitlab._OPENER.open",
            return_value=_json_response(response_factory, "   "),
        )
        assert gitlab.request("GET", REQUEST_ENDPOINT) is None

    def test_prints_raw_text_for_non_json_response(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        mocker.patch(
            "gitlab._OPENER.open",
            return_value=_text_response(response_factory, NON_JSON_BODY),
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

        mocker.patch("gitlab._OPENER.open", side_effect=error)
        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab.request("GET", REQUEST_ENDPOINT)

        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE
        assert exc_info.value.status == 403
        rendered = str(exc_info.value)
        assert rendered.startswith(f"HTTP 403 from GET {REQUEST_ENDPOINT}")
        assert "forbidden" in rendered
        assert capsys.readouterr().err == ""

    def test_reports_raw_http_error_body(
        self,
        configured_gitlab: ConfiguredGitLab,
        http_error_factory: HttpErrorFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = http_error_factory("Service unavailable", code=503)

        mocker.patch("gitlab._OPENER.open", side_effect=error)
        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab.request("DELETE", REQUEST_ENDPOINT)

        assert str(exc_info.value) == (
            f"HTTP 503 from DELETE {REQUEST_ENDPOINT}: Service unavailable"
        )
        assert capsys.readouterr().err == ""

    def test_prefers_parsed_http_error_message_and_redacts_it(
        self,
        configured_gitlab: ConfiguredGitLab,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = urllib.error.HTTPError(
            url=REQUEST_ENDPOINT,
            code=403,
            msg="forbidden",
            hdrs={},
            fp=io.BytesIO(b'{"message": "token abc123"}'),
        )
        mocker.patch("gitlab._OPENER.open", side_effect=error)

        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab.request("GET", REQUEST_ENDPOINT)

        rendered = str(exc_info.value)
        assert "token=[REDACTED]" in rendered
        assert "abc123" not in rendered
        assert capsys.readouterr().err == ""

    def test_falls_back_to_redacted_raw_error_body(
        self,
        configured_gitlab: ConfiguredGitLab,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = urllib.error.HTTPError(
            url=REQUEST_ENDPOINT,
            code=502,
            msg="bad gateway",
            hdrs={},
            fp=io.BytesIO(b"token abc123"),
        )
        mocker.patch("gitlab._OPENER.open", side_effect=error)

        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab.request("GET", REQUEST_ENDPOINT)

        rendered = str(exc_info.value)
        assert "token=[REDACTED]" in rendered
        assert "abc123" not in rendered
        assert capsys.readouterr().err == ""


class TestGitLabTransportHardening:
    """Regression tests for hardened transport behavior."""

    def test_uses_timeout_for_git_remote_lookup(self, mocker: MockerFixture) -> None:
        captured: dict[str, object] = {}

        def fake_check_output(*args: object, **kwargs: object) -> str:
            captured["kwargs"] = kwargs
            raise subprocess.TimeoutExpired(
                cmd=["git", "remote", "get-url", "origin"],
                timeout=kwargs["timeout"],
            )

        mocker.patch("subprocess.check_output", side_effect=fake_check_output)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.project()

        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE
        assert captured["kwargs"]["timeout"] == gitlab.REQUEST_TIMEOUT
        assert "timed out resolving git remote for project" in str(exc_info.value)

    def test_prints_redacted_and_capped_non_json_output(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        body = "token abc123\n" + ("x" * (gitlab.MAX_BODY_BYTES + 32))
        response = _text_response(response_factory, body)
        mocker.patch("gitlab._OPENER.open", return_value=response)
        monkeypatch.setattr(gitlab, "MAX_BODY_BYTES", 32)

        parsed = gitlab.request("GET", REQUEST_ENDPOINT)

        assert parsed is None
        output = capsys.readouterr().out
        assert "token=[REDACTED]" in output
        assert "abc123" not in output
        assert "... [truncated]" in output

    @pytest.mark.parametrize(
        ("content_type", "expected_fragment"),
        [("", "unexpected Content-Type"), ("text/plain", "unexpected Content-Type")],
    )
    def test_rejects_missing_or_non_json_content_types(
        self,
        content_type: str,
        expected_fragment: str,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
    ) -> None:
        response = response_factory(REQUEST_BODY)
        response.headers = {"Content-Type": content_type} if content_type else {}
        mocker.patch("gitlab._OPENER.open", return_value=response)

        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab._request_bytes(
                "GET",
                REQUEST_ENDPOINT_WITH_CONTEXT,
                headers={"PRIVATE-TOKEN": TEST_GITLAB_TOKEN},
                require_json=True,
            )

        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE
        assert exc_info.value.method == "GET"
        assert exc_info.value.resource == REQUEST_ENDPOINT
        rendered = str(exc_info.value)
        assert expected_fragment in rendered
        assert "hidden" not in rendered
        assert "fragment" not in rendered

    def test_rejects_oversized_json_response_as_api_error(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setattr(gitlab, "MAX_BODY_BYTES", 16)
        response = _json_response(response_factory, "x" * 17)
        mocker.patch("gitlab._OPENER.open", return_value=response)

        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab._request_bytes(
                "POST",
                REQUEST_ENDPOINT_WITH_CONTEXT,
                headers={"PRIVATE-TOKEN": TEST_GITLAB_TOKEN},
                require_json=True,
            )

        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE
        assert exc_info.value.method == "POST"
        assert exc_info.value.resource == REQUEST_ENDPOINT
        rendered = str(exc_info.value)
        assert "response body exceeds size limit" in rendered
        assert "hidden" not in rendered
        assert "fragment" not in rendered

    def test_allows_application_json_content_type(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
    ) -> None:
        response = _json_response(response_factory, REQUEST_BODY)
        mocker.patch("gitlab._OPENER.open", return_value=response)

        assert (
            gitlab._request_bytes(
                "GET",
                REQUEST_ENDPOINT,
                headers={"PRIVATE-TOKEN": TEST_GITLAB_TOKEN},
                require_json=True,
            )
            == REQUEST_BODY.encode()
        )

    def test_allows_empty_body_without_content_type(
        self,
        configured_gitlab: ConfiguredGitLab,
        response_factory: ResponseFactory,
        mocker: MockerFixture,
    ) -> None:
        response = response_factory("")
        response.headers = {}
        mocker.patch("gitlab._OPENER.open", return_value=response)

        assert (
            gitlab._request_bytes(
                "DELETE",
                REQUEST_ENDPOINT,
                headers={"PRIVATE-TOKEN": TEST_GITLAB_TOKEN},
                require_json=True,
            )
            == b""
        )

    def test_redirect_blocked(self) -> None:
        handler = gitlab._NoRedirect()
        request = urllib.request.Request("https://gitlab.example.com/redirect")

        with pytest.raises(urllib.error.HTTPError) as exc_info:
            handler.redirect_request(
                request,
                None,
                302,
                "Found",
                None,
                "https://evil.example.com/next",
            )

        assert exc_info.value.code == 302
        assert "refusing redirect" in str(exc_info.value)

    def test_requires_https_for_non_localhost(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", "http://example.com")

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_rejects_non_localhost_http_even_when_allow_env_set(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", "http://example.com")
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
        monkeypatch.setenv("GITLAB_ALLOW_INSECURE", "1")

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_rejects_loopback_http_without_allow_env(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", "http://127.0.0.1:8080")
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
        monkeypatch.delenv("GITLAB_ALLOW_INSECURE", raising=False)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.require_environment()

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_accepts_loopback_http_with_allow_env(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("GITLAB_URL", "http://127.0.0.1:8080")
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
        monkeypatch.setenv("GITLAB_ALLOW_INSECURE", "1")

        gitlab.require_environment()

        assert gitlab.gitlab_url == "http://127.0.0.1:8080"
        assert gitlab.api_url == "http://127.0.0.1:8080/api/v4"

    def test_rejects_invalid_mr_state(self) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.cmd_mr_list(["invalid-state"])

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_rejects_invalid_ref(self) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.cmd_pipeline_run(["invalid ref"])

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_rejects_zero_for_positive_integer(self) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.validate_positive_int("0", "max_results")

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE

    def test_rejects_oversized_stdin_payload_before_parsing(
        self,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
    ) -> None:
        monkeypatch.setattr(
            gitlab.sys,
            "stdin",
            io.StringIO("{" + ("x" * (gitlab.MAX_BODY_BYTES + 1)) + "}"),
        )
        mocker.patch("gitlab.load_json_payload", side_effect=AssertionError)

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.cmd_mr_create([])

        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE
        assert "request body exceeds size limit" in str(exc_info.value)

    def test_redacts_sensitive_error_bodies(
        self,
        configured_gitlab: ConfiguredGitLab,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        error = urllib.error.HTTPError(
            url=REQUEST_ENDPOINT,
            code=403,
            msg="forbidden",
            hdrs={},
            fp=io.BytesIO(b'{"message": "token abc123"}'),
        )
        mocker.patch("gitlab._OPENER.open", side_effect=error)

        with pytest.raises(gitlab.GitLabAPIError) as exc_info:
            gitlab.request("GET", REQUEST_ENDPOINT)

        assert "abc123" not in str(exc_info.value)
        assert "abc123" not in capsys.readouterr().err
