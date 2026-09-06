# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Entry-point tests for gitlab.py."""

from __future__ import annotations

import json
import pathlib
import traceback
from collections.abc import Callable

import gitlab
import pytest
from pytest_mock import MockerFixture
from test_constants import FIELDS_MR, TEST_GITLAB_TOKEN, TEST_GITLAB_URL, USAGE_MAIN

ARGV_MAIN_LIST = ["gitlab", "mr-list", "opened", "5"]
ARGV_MAIN_FIELDS = ["gitlab", "mr-get", "42", "--fields", "iid,title,author.name"]
ARGV_FIELDS_ONLY = ["gitlab", "--fields", "iid,title"]
EXPECTED_FIELD_SELECTION = [*FIELDS_MR, "author.name"]


def _oauth_profile(
    access_token: str = "access-secret",
) -> gitlab.credentials.Profile:
    return {
        "issuer": TEST_GITLAB_URL,
        "client_id": "client",
        "access_token": access_token,
        "refresh_token": "refresh-secret",
        "token_type": "Bearer",
        "obtained_at": 1,
        "expires_at": 4_102_444_800,
        "scopes": ["api"],
        "usable": True,
    }


def _configure_oauth(
    monkeypatch: pytest.MonkeyPatch,
    store_path: pathlib.Path,
) -> None:
    monkeypatch.setenv("GITLAB_AUTH_MODE", "oauth")
    monkeypatch.delenv("GITLAB_TOKEN")
    monkeypatch.setenv("GITLAB_OAUTH_CLIENT_ID", "client")
    monkeypatch.setenv("GITLAB_TOKEN_STORE", str(store_path))


class TestMain:
    """Tests for main."""

    def test_dispatches_to_selected_command(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        seen: list[object] = []

        def fake_require_environment() -> None:
            seen.append("env")

        def fake_handler(args: list[str]) -> None:
            seen.append(("handler", args))

        monkeypatch.setattr(gitlab, "require_environment", fake_require_environment)
        monkeypatch.setitem(gitlab.COMMANDS, "mr-list", fake_handler)
        monkeypatch.setattr("sys.argv", ARGV_MAIN_LIST)

        result = gitlab.main()

        assert result == gitlab.EXIT_SUCCESS
        assert seen == ["env", ("handler", ["opened", "5"])]

    def test_dispatches_auth_before_api_environment(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        seen: list[list[str]] = []
        monkeypatch.setitem(
            gitlab.AUTH_COMMANDS,
            "status",
            lambda args: seen.append(args),
        )
        monkeypatch.setattr(
            gitlab,
            "require_environment",
            lambda: (_ for _ in ()).throw(AssertionError("must not run")),
        )
        monkeypatch.setattr("sys.argv", ["gitlab", "auth", "status"])

        assert gitlab.main() == gitlab.EXIT_SUCCESS
        assert seen == [[]]

    def test_rejects_fields_for_auth_commands(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(
            "sys.argv", ["gitlab", "--fields", "profile", "auth", "status"]
        )

        assert gitlab.main() == gitlab.EXIT_USAGE

        # main is the sole emission boundary: it must produce exactly one
        # redacted "error: ..." line when GITLAB_DEBUG is unset.
        assert (
            capsys.readouterr().err
            == "error: --fields is not valid with auth commands\n"
        )

    @pytest.mark.parametrize(
        "argv",
        [["gitlab", "auth"], ["gitlab", "auth", "unknown"]],
    )
    def test_rejects_invalid_auth_command_before_api_environment(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
        argv: list[str],
    ) -> None:
        monkeypatch.setattr(
            gitlab,
            "require_environment",
            lambda: (_ for _ in ()).throw(AssertionError("must not run")),
        )
        monkeypatch.setattr("sys.argv", argv)

        assert gitlab.main() == gitlab.EXIT_USAGE
        assert "gitlab auth {login|device-login|status|logout}" in (
            capsys.readouterr().err
        )

    def test_main_applies_fields_before_dispatch(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        captured: list[object] = []

        monkeypatch.setattr(
            gitlab, "require_environment", lambda: captured.append("env")
        )

        def fake_handler(args: list[str]) -> None:
            captured.append((args, gitlab.selected_fields))

        monkeypatch.setitem(gitlab.COMMANDS, "mr-get", fake_handler)
        monkeypatch.setattr("sys.argv", ARGV_MAIN_FIELDS)

        result = gitlab.main()

        assert result == gitlab.EXIT_SUCCESS
        assert captured == ["env", (["42"], EXPECTED_FIELD_SELECTION)]

    @pytest.mark.parametrize("argv", [["gitlab"], ["gitlab", "unknown-command"]])
    def test_main_rejects_missing_or_unknown_command(
        self,
        monkeypatch: pytest.MonkeyPatch,
        argv: list[str],
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(gitlab, "require_environment", lambda: None)
        monkeypatch.setattr("sys.argv", argv)

        assert gitlab.main() == gitlab.EXIT_USAGE
        assert USAGE_MAIN in capsys.readouterr().err

    def test_main_passes_empty_arguments_when_only_fields_are_present(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(gitlab, "require_environment", lambda: None)
        monkeypatch.setattr("sys.argv", ARGV_FIELDS_ONLY)

        assert gitlab.main() == gitlab.EXIT_USAGE
        assert gitlab.selected_fields == FIELDS_MR
        assert USAGE_MAIN in capsys.readouterr().err

    def test_main_handles_keyboard_interrupt(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """main returns 130 when KeyboardInterrupt is raised."""
        monkeypatch.setattr(
            gitlab,
            "parse_fields",
            lambda _: (_ for _ in ()).throw(KeyboardInterrupt),
        )
        assert gitlab.main() == 130

    def test_main_handles_broken_pipe(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """main returns 141 and redirects stdout on BrokenPipeError."""
        monkeypatch.setattr(
            gitlab,
            "parse_fields",
            lambda _: (_ for _ in ()).throw(BrokenPipeError),
        )
        dup2_calls: list[tuple[int, int]] = []
        close_calls: list[int] = []
        monkeypatch.setattr("os.dup2", lambda fd, fd2: dup2_calls.append((fd, fd2)))
        monkeypatch.setattr("os.open", lambda *a, **kw: 99)
        monkeypatch.setattr("os.close", lambda fd: close_calls.append(fd))
        assert gitlab.main() == 141
        assert len(dup2_calls) == 1
        assert close_calls == [99]

    def test_main_redacts_unexpected_exception(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setattr(
            gitlab,
            "parse_fields",
            lambda _: (_ for _ in ()).throw(RuntimeError("access_token=hidden")),
        )

        assert gitlab.main() == gitlab.EXIT_FAILURE
        captured = capsys.readouterr()
        assert captured.err.strip() == "error: unexpected GitLab CLI failure"
        assert "hidden" not in captured.err

    def test_main_handles_typed_error_at_single_redacted_boundary(
        self,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        error = gitlab.GitLabError("private_token=hidden", gitlab.EXIT_USAGE)
        debug_traceback = mocker.patch.object(gitlab, "_emit_debug_traceback")
        monkeypatch.setattr(gitlab, "require_environment", lambda: None)
        monkeypatch.setitem(
            gitlab.COMMANDS,
            "mr-list",
            lambda _args: (_ for _ in ()).throw(error),
        )
        monkeypatch.setattr("sys.argv", ARGV_MAIN_LIST)

        result = gitlab.main()

        assert result == gitlab.EXIT_USAGE
        assert capsys.readouterr().err == "error: private_token=[REDACTED]\n"
        debug_traceback.assert_called_once_with(error)


class TestAuthCommands:
    """Tests for stateful OAuth command behavior."""

    @pytest.mark.parametrize(
        ("provider", "command"),
        [
            ("gitlab.oauth.authorization_code_login", gitlab.cmd_auth_login),
            ("gitlab.oauth.device_login", gitlab.cmd_auth_device_login),
        ],
    )
    def test_login_wrapper_traceback_excludes_provider_secret(
        self,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
        provider: str,
        command: Callable[[list[str]], None],
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        _configure_oauth(monkeypatch, store_path)
        mocker.patch(
            provider,
            side_effect=gitlab.oauth.OAuthError("access_token=provider-secret"),
        )

        with pytest.raises(gitlab.GitLabError) as exc_info:
            command([])

        formatted = "".join(traceback.format_exception(exc_info.value))
        assert "provider-secret" not in formatted
        assert "access_token=[REDACTED]" in formatted
        assert exc_info.value.exit_code == gitlab.EXIT_FAILURE

    def test_login_surfaces_url_and_persists_profile(
        self,
        monkeypatch: pytest.MonkeyPatch,
        mocker: MockerFixture,
        tmp_path: pathlib.Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        _configure_oauth(monkeypatch, store_path)

        def login(
            _issuer: str,
            _client_id: str,
            **kwargs: object,
        ) -> gitlab.credentials.Profile:
            emit = kwargs["emit_authorize_url"]
            assert callable(emit)
            emit("https://gitlab.example.com/oauth/authorize?state=public")
            return _oauth_profile()

        mocker.patch("gitlab.oauth.authorization_code_login", side_effect=login)

        gitlab.cmd_auth_login([])

        output = capsys.readouterr().out
        assert "oauth/authorize" in output
        assert "access-secret" not in output
        assert (
            gitlab.credentials.get_profile(
                gitlab.credentials.load_store(store_path),
                "default",
            )["usable"]
            is True
        )

    def test_status_is_secret_free(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        _configure_oauth(monkeypatch, store_path)
        gitlab.credentials.save_store(
            store_path,
            {"schema_version": 1, "profiles": {"default": _oauth_profile()}},
        )

        gitlab.cmd_auth_status([])

        payload = json.loads(capsys.readouterr().out)
        assert payload["profile"] == "default"
        assert "access_token" not in payload
        assert "refresh_token" not in payload

    def test_logout_preserves_unrelated_profiles(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        _configure_oauth(monkeypatch, store_path)
        monkeypatch.setenv("GITLAB_PROFILE", "selected")
        gitlab.credentials.save_store(
            store_path,
            {
                "schema_version": 1,
                "profiles": {
                    "selected": _oauth_profile("selected-secret"),
                    "other": _oauth_profile("other-secret"),
                },
            },
        )

        gitlab.cmd_auth_logout([])

        store = gitlab.credentials.load_store(store_path)
        assert "selected" not in store["profiles"]
        assert "other" in store["profiles"]

    def test_rejects_mixed_legacy_credentials(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        store_path = tmp_path / "gitlab" / "gitlab-token.json"
        monkeypatch.setenv("GITLAB_AUTH_MODE", "oauth")
        monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
        monkeypatch.setenv("GITLAB_OAUTH_CLIENT_ID", "client")
        monkeypatch.setenv("GITLAB_TOKEN_STORE", str(store_path))

        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.cmd_auth_status([])

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "must not be set" in str(exc_info.value)
