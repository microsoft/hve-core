# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Credential-file auto-load helpers (Phase 1-3)."""

from __future__ import annotations

import argparse
import logging
import os
import pathlib
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# FileBackend._read_all (env-file parser)
# ---------------------------------------------------------------------------


def test_file_backend_read_all_parses_basic_kv(
    mural_module: Any,
    tmp_path: pathlib.Path,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text(
        "MURAL_CLIENT_ID=plain-id\nMURAL_CLIENT_SECRET=plain-secret\n",
        encoding="utf-8",
    )
    backend = mural_module.FileBackend(path)
    assert backend._read_all() == {
        "MURAL_CLIENT_ID": "plain-id",
        "MURAL_CLIENT_SECRET": "plain-secret",
    }


def test_file_backend_read_all_handles_export_quotes_comments_blanks(
    mural_module: Any,
    tmp_path: pathlib.Path,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text(
        "# comment line\n"
        "\n"
        "   \n"
        "export MURAL_CLIENT_ID=exported-id\n"
        'MURAL_CLIENT_SECRET="quoted secret"\n'
        "MURAL_REFRESH_TOKEN='single-quoted'\n",
        encoding="utf-8",
    )
    backend = mural_module.FileBackend(path)
    assert backend._read_all() == {
        "MURAL_CLIENT_ID": "exported-id",
        "MURAL_CLIENT_SECRET": "quoted secret",
        "MURAL_REFRESH_TOKEN": "single-quoted",
    }


def test_file_backend_read_all_returns_empty_when_missing(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    missing = tmp_path / "does-not-exist.env"
    backend = mural_module.FileBackend(missing)
    assert backend._read_all() == {}


def test_file_backend_read_all_silently_skips_malformed_lines(
    mural_module: Any,
    tmp_path: pathlib.Path,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text(
        "MURAL_CLIENT_ID=good\n"
        "this is not a kv line\n"
        "=missing-key\n"
        "1BAD_KEY=starts-with-digit\n"
        "MURAL_CLIENT_SECRET=also-good\n",
        encoding="utf-8",
    )
    backend = mural_module.FileBackend(path)
    assert backend._read_all() == {
        "MURAL_CLIENT_ID": "good",
        "MURAL_CLIENT_SECRET": "also-good",
    }


# ---------------------------------------------------------------------------
# _resolve_credential_file
# ---------------------------------------------------------------------------


def test_resolve_credential_file_honours_env_file_override(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    explicit = tmp_path / "explicit.env"
    path = mural_module._resolve_credential_file(
        "default", {"MURAL_ENV_FILE": str(explicit)}
    )
    assert path == explicit


def test_resolve_credential_file_uses_xdg_config_home(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    xdg = tmp_path / "xdg-config"
    path = mural_module._resolve_credential_file("work", {"XDG_CONFIG_HOME": str(xdg)})
    assert path == xdg / "hve-core" / "mural.work.env"


def test_resolve_credential_file_falls_back_to_home_config(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("HOME", str(tmp_path))
    path = mural_module._resolve_credential_file("default", {})
    assert path == tmp_path / ".config" / "hve-core" / "mural.default.env"


# ---------------------------------------------------------------------------
# _check_credential_file_perms
# ---------------------------------------------------------------------------


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_check_credential_file_perms_accepts_0600(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "creds.env"
    path.write_bytes(b"MURAL_CLIENT_ID=x\n")
    os.chmod(path, 0o600)
    mural_module._check_credential_file_perms(path, {})


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_check_credential_file_perms_rejects_loose_mode(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "creds.env"
    path.write_bytes(b"MURAL_CLIENT_ID=x\n")
    os.chmod(path, 0o644)
    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._check_credential_file_perms(path, {})
    message = str(excinfo.value)
    assert "0o644" in message
    assert "MURAL_ENV_FILE_RELAXED" in message
    assert str(path) in message


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_check_credential_file_perms_relaxed_override(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "creds.env"
    path.write_bytes(b"MURAL_CLIENT_ID=x\n")
    os.chmod(path, 0o644)
    mural_module._check_credential_file_perms(path, {"MURAL_ENV_FILE_RELAXED": "1"})


# ---------------------------------------------------------------------------
# _autoload_credentials
# ---------------------------------------------------------------------------


def test_autoload_credentials_returns_none_when_file_absent(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    missing = tmp_path / "absent.env"
    env: dict[str, str] = {"MURAL_ENV_FILE": str(missing)}
    result = mural_module._autoload_credentials("default", env)
    assert result is None
    assert "MURAL_CLIENT_ID" not in env


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_autoload_credentials_loads_when_env_unset(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text(
        "MURAL_CLIENT_ID=from-file\nMURAL_CLIENT_SECRET=secret-from-file\n",
        encoding="utf-8",
    )
    os.chmod(path, 0o600)
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.setenv("MURAL_ENV_FILE", str(path))
    env: dict[str, str] = {"MURAL_ENV_FILE": str(path)}
    result = mural_module._autoload_credentials("default", env)
    assert result == path
    assert env["MURAL_CLIENT_ID"] == "from-file"
    assert env["MURAL_CLIENT_SECRET"] == "secret-from-file"


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_autoload_credentials_env_wins_over_file(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text(
        "MURAL_CLIENT_ID=from-file\nMURAL_CLIENT_SECRET=secret-from-file\n",
        encoding="utf-8",
    )
    os.chmod(path, 0o600)
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.setenv("MURAL_ENV_FILE", str(path))
    env: dict[str, str] = {
        "MURAL_ENV_FILE": str(path),
        "MURAL_CLIENT_ID": "from-env",
    }
    mural_module._autoload_credentials("default", env)
    assert env["MURAL_CLIENT_ID"] == "from-env"
    assert env["MURAL_CLIENT_SECRET"] == "secret-from-file"


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only permission semantics")
def test_autoload_credentials_propagates_perm_error(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "creds.env"
    path.write_text("MURAL_CLIENT_ID=loose\n", encoding="utf-8")
    os.chmod(path, 0o644)
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.setenv("MURAL_ENV_FILE", str(path))
    env: dict[str, str] = {"MURAL_ENV_FILE": str(path)}
    with pytest.raises(mural_module.MuralError):
        mural_module._autoload_credentials("default", env)


# ---------------------------------------------------------------------------
# _cmd_auth_bootstrap
# ---------------------------------------------------------------------------


def test_cmd_auth_bootstrap_non_tty_returns_failure(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    target = tmp_path / "mural.default.env"
    monkeypatch.setenv("MURAL_ENV_FILE", str(target))
    monkeypatch.setenv("MURAL_NONINTERACTIVE", "1")
    args = argparse.Namespace(profile=None)
    rc = mural_module._cmd_auth_bootstrap(args)
    assert rc == mural_module.EXIT_FAILURE
    assert not target.exists()
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert "interactive TTY" in combined
    assert "active credential backend" in combined


# ---------------------------------------------------------------------------
# Phase 6 helpers
# ---------------------------------------------------------------------------


_CRED_BACKEND_ENV_VARS = (
    "MURAL_CREDENTIAL_BACKEND",
    "MURAL_KEYRING_BACKEND",
    "MURAL_KEYRING_SERVICE",
    "MURAL_NONINTERACTIVE",
    "MURAL_ENV_FILE_RELAXED",
    "MURAL_ENV_FILE",
)


def _isolate_credential_env(
    monkeypatch: pytest.MonkeyPatch, tmp_path: pathlib.Path
) -> None:
    """Strip credential-backend env vars and seed XDG paths under ``tmp_path``."""
    for var in _CRED_BACKEND_ENV_VARS:
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "xdg-config"))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "xdg-data"))


@pytest.fixture
def keyring_alt_backend(monkeypatch: pytest.MonkeyPatch, tmp_path: pathlib.Path) -> str:
    """Wire ``KeyringBackend`` to ``keyrings.alt.file.PlaintextKeyring``.

    Returns the keyring service name used for round-trip operations.
    PlaintextKeyring stores its data under ``XDG_DATA_HOME/python_keyring/``,
    which is rerouted to ``tmp_path`` so each test gets isolated state.
    """
    _isolate_credential_env(monkeypatch, tmp_path)
    monkeypatch.setenv("MURAL_KEYRING_BACKEND", "keyrings.alt.file.PlaintextKeyring")
    service = "test-mural/default"
    monkeypatch.setenv("MURAL_KEYRING_SERVICE", service)
    return service


def _seed_both_backends(
    mural_module: Any, cred_path: pathlib.Path, service: str
) -> None:
    """Populate both keyring and file backends with overlapping credentials."""
    keyring_backend = mural_module.KeyringBackend()
    keyring_backend.set(service, "MURAL_CLIENT_ID", "from-keyring")
    keyring_backend.set(service, "MURAL_CLIENT_SECRET", "secret-keyring")
    file_backend = mural_module.FileBackend(cred_path)
    file_backend.set(service, "MURAL_CLIENT_ID", "from-file")
    file_backend.set(service, "MURAL_CLIENT_SECRET", "secret-file")


# ---------------------------------------------------------------------------
# resolve_backend selector precedence and auto-fallback (Step 6.1)
# ---------------------------------------------------------------------------


class TestResolveBackend:
    def test_file_selector_returns_file_backend(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)
        monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module.FileBackend)
        assert backend.name == "file"

    def test_env_only_selector_returns_null_backend(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)
        monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "env-only")
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module._NullBackend)
        assert backend.name == "env-only"
        with pytest.raises(RuntimeError):
            backend.set("svc", "k", "v")

    def test_keyring_selector_returns_keyring_backend(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)
        monkeypatch.setenv(
            "MURAL_KEYRING_BACKEND", "keyrings.alt.file.PlaintextKeyring"
        )
        monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "keyring")
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module.KeyringBackend)
        assert backend.name == "keyring"

    def test_unknown_selector_raises_mural_error(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)
        monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "garbage")
        with pytest.raises(mural_module.MuralError) as excinfo:
            mural_module.resolve_backend("default")
        assert "MURAL_CREDENTIAL_BACKEND" in str(excinfo.value)

    def test_auto_returns_keyring_when_available(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)
        monkeypatch.setenv(
            "MURAL_KEYRING_BACKEND", "keyrings.alt.file.PlaintextKeyring"
        )
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module.KeyringBackend)

    def test_auto_falls_back_to_file_on_keyring_unavailable(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)

        def _raise_unavailable(self: Any) -> None:
            raise mural_module._KeyringUnavailable("test-induced")

        monkeypatch.setattr(mural_module.KeyringBackend, "__init__", _raise_unavailable)
        caplog.set_level(logging.WARNING, logger="mural")
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module.FileBackend)
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "keyring backend unavailable for profile 'default'" in r.message
            and "falling back to file backend" in r.message
        ]
        assert len(warns) == 1

    def test_auto_fallback_warn_dedupes_per_profile_per_process(
        self,
        mural_module: Any,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: pathlib.Path,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        _isolate_credential_env(monkeypatch, tmp_path)

        def _raise_unavailable(self: Any) -> None:
            raise mural_module._KeyringUnavailable("test-induced")

        monkeypatch.setattr(mural_module.KeyringBackend, "__init__", _raise_unavailable)
        caplog.set_level(logging.WARNING, logger="mural")
        for _ in range(3):
            mural_module.resolve_backend("default")
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "keyring backend unavailable for profile 'default'" in r.message
        ]
        assert len(warns) == 1


# ---------------------------------------------------------------------------
# KeyringBackend round-trip via keyrings.alt PlaintextKeyring (Step 6.2)
# ---------------------------------------------------------------------------


class TestKeyringBackend:
    def test_set_get_round_trip(
        self, mural_module: Any, keyring_alt_backend: str
    ) -> None:
        backend = mural_module.KeyringBackend()
        backend.set(keyring_alt_backend, "MURAL_CLIENT_ID", "alpha-id")
        backend.set(keyring_alt_backend, "MURAL_CLIENT_SECRET", "alpha-secret")
        assert backend.get(keyring_alt_backend, "MURAL_CLIENT_ID") == "alpha-id"
        assert backend.get(keyring_alt_backend, "MURAL_CLIENT_SECRET") == "alpha-secret"

    def test_delete_removes_entry(
        self, mural_module: Any, keyring_alt_backend: str
    ) -> None:
        backend = mural_module.KeyringBackend()
        backend.set(keyring_alt_backend, "MURAL_CLIENT_ID", "to-be-deleted")
        backend.delete(keyring_alt_backend, "MURAL_CLIENT_ID")
        assert backend.get(keyring_alt_backend, "MURAL_CLIENT_ID") is None

    def test_delete_missing_is_idempotent(
        self, mural_module: Any, keyring_alt_backend: str
    ) -> None:
        backend = mural_module.KeyringBackend()
        backend.delete(keyring_alt_backend, "MURAL_CLIENT_ID")
        assert backend.get(keyring_alt_backend, "MURAL_CLIENT_ID") is None

    def test_get_returns_none_for_missing(
        self, mural_module: Any, keyring_alt_backend: str
    ) -> None:
        backend = mural_module.KeyringBackend()
        assert backend.get(keyring_alt_backend, "MURAL_REFRESH_TOKEN") is None


# ---------------------------------------------------------------------------
# Credential-file hygiene G3/G5/G6 (Step 6.3)
# ---------------------------------------------------------------------------


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only ownership/symlink semantics")
class TestCredentialFileHygiene:
    def test_st_uid_mismatch_refuses_load(
        self,
        mural_module: Any,
        tmp_path: pathlib.Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        path = tmp_path / "creds.env"
        path.write_bytes(b"MURAL_CLIENT_ID=x\n")
        os.chmod(path, 0o600)
        real_uid = os.geteuid()
        monkeypatch.setattr(os, "geteuid", lambda: real_uid + 12345)
        with pytest.raises(mural_module.MuralError) as excinfo:
            mural_module._check_credential_file_perms(path, {})
        message = str(excinfo.value)
        assert "owned by uid" in message
        assert str(path) in message

    def test_relaxed_emits_single_warn_per_process(
        self,
        mural_module: Any,
        tmp_path: pathlib.Path,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        path = tmp_path / "creds.env"
        path.write_bytes(b"MURAL_CLIENT_ID=x\n")
        os.chmod(path, 0o644)
        environ = {"MURAL_ENV_FILE_RELAXED": "1"}
        caplog.set_level(logging.WARNING, logger="mural")
        for _ in range(3):
            mural_module._check_credential_file_perms(path, environ)
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "MURAL_ENV_FILE_RELAXED=1 honored" in r.message
            and str(path) in r.message
        ]
        assert len(warns) == 1

    def test_symlink_refused_via_o_nofollow(
        self,
        mural_module: Any,
        tmp_path: pathlib.Path,
    ) -> None:
        import errno

        target = tmp_path / "real.env"
        target.write_bytes(b"MURAL_CLIENT_ID=x\n")
        os.chmod(target, 0o600)
        symlink = tmp_path / "link.env"
        os.symlink(str(target), str(symlink))
        backend = mural_module.FileBackend(symlink)
        with pytest.raises(OSError) as excinfo:
            backend._read_all()
        # ELOOP on Linux/macOS, EMLINK on some BSDs; either signals O_NOFOLLOW.
        assert excinfo.value.errno in (errno.ELOOP, errno.EMLINK)


# ---------------------------------------------------------------------------
# Migrate concurrent-state guard (Step 6.4 part A)
# ---------------------------------------------------------------------------


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only file backend semantics")
class TestMigrateConcurrentState:
    @staticmethod
    def _make_args(**overrides: Any) -> argparse.Namespace:
        defaults: dict[str, Any] = {
            "to": "keyring",
            "profile": None,
            "cleanup": False,
            "force": False,
            "yes": False,
            "json": False,
        }
        defaults.update(overrides)
        return argparse.Namespace(**defaults)

    def test_migrate_errors_when_both_backends_populated_without_force(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        _seed_both_backends(mural_module, cred_path, keyring_alt_backend)
        caplog.set_level(logging.ERROR, logger="mural")
        rc = mural_module._cmd_auth_migrate(self._make_args(to="keyring"))
        assert rc == mural_module.EXIT_FAILURE
        errors = [
            r
            for r in caplog.records
            if r.levelno == logging.ERROR
            and "both keyring and file backends already populated" in r.message
            and "profile 'default'" in r.message
            and "rerun with --force" in r.message
        ]
        assert len(errors) == 1

    def test_migrate_warns_with_force_when_both_backends_populated(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        _seed_both_backends(mural_module, cred_path, keyring_alt_backend)
        caplog.set_level(logging.WARNING, logger="mural")
        rc = mural_module._cmd_auth_migrate(self._make_args(to="keyring", force=True))
        assert rc == mural_module.EXIT_SUCCESS
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends already populated" in r.message
            and "profile 'default'" in r.message
            and "--force set, overwriting destination" in r.message
        ]
        assert len(warns) == 1

    def test_migrate_dedupes_warn_per_process(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        _seed_both_backends(mural_module, cred_path, keyring_alt_backend)
        caplog.set_level(logging.WARNING, logger="mural")
        for _ in range(3):
            rc = mural_module._cmd_auth_migrate(
                self._make_args(to="keyring", force=True)
            )
            assert rc == mural_module.EXIT_SUCCESS
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends already populated" in r.message
        ]
        assert len(warns) == 1


# ---------------------------------------------------------------------------
# Migrate partial-failure exit code
# ---------------------------------------------------------------------------


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only file backend semantics")
class TestMigratePartialFailureExitCode:
    @staticmethod
    def _make_args(**overrides: Any) -> argparse.Namespace:
        defaults: dict[str, Any] = {
            "to": "keyring",
            "profile": None,
            "cleanup": False,
            "force": False,
            "yes": False,
            "json": False,
        }
        defaults.update(overrides)
        return argparse.Namespace(**defaults)

    def test_partial_failure_returns_success_when_some_keys_migrated(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        service = keyring_alt_backend
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        file_backend = mural_module.FileBackend(cred_path)
        file_backend.set(service, "MURAL_CLIENT_ID", "src-id")
        file_backend.set(service, "MURAL_CLIENT_SECRET", "src-secret")

        original_set = mural_module.KeyringBackend.set

        def failing_set(self: Any, svc: str, key: str, value: str) -> None:
            if key == "MURAL_CLIENT_SECRET":
                raise mural_module._KeyringUnavailable("simulated write failure")
            original_set(self, svc, key, value)

        monkeypatch.setattr(mural_module.KeyringBackend, "set", failing_set)

        rc = mural_module._cmd_auth_migrate(self._make_args(to="keyring"))

        assert rc == mural_module.EXIT_SUCCESS
        keyring_backend = mural_module.KeyringBackend()
        assert keyring_backend.get(service, "MURAL_CLIENT_ID") == "src-id"
        assert keyring_backend.get(service, "MURAL_CLIENT_SECRET") is None

    def test_full_failure_still_returns_failure(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        service = keyring_alt_backend
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        file_backend = mural_module.FileBackend(cred_path)
        file_backend.set(service, "MURAL_CLIENT_ID", "src-id")
        file_backend.set(service, "MURAL_CLIENT_SECRET", "src-secret")

        def always_fail(self: Any, svc: str, key: str, value: str) -> None:
            raise mural_module._KeyringUnavailable("simulated write failure")

        monkeypatch.setattr(mural_module.KeyringBackend, "set", always_fail)

        rc = mural_module._cmd_auth_migrate(self._make_args(to="keyring"))

        assert rc == mural_module.EXIT_FAILURE


# ---------------------------------------------------------------------------
# resolve_backend concurrent-state guard (Step 6.4 part B)
# ---------------------------------------------------------------------------


@pytest.mark.skipif(os.name == "nt", reason="POSIX-only file backend semantics")
class TestResolveBackendConcurrentState:
    def test_warns_when_both_populated(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        _seed_both_backends(mural_module, cred_path, keyring_alt_backend)
        caplog.set_level(logging.WARNING, logger="mural")
        backend = mural_module.resolve_backend("default")
        assert isinstance(backend, mural_module.KeyringBackend)
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends populated for profile" in r.message
            and "'default'" in r.message
        ]
        assert len(warns) == 1

    def test_dedupes_per_profile_and_backend_per_process(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        _seed_both_backends(mural_module, cred_path, keyring_alt_backend)
        caplog.set_level(logging.WARNING, logger="mural")
        for _ in range(3):
            mural_module.resolve_backend("default")
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends populated for profile" in r.message
        ]
        assert len(warns) == 1

    def test_no_warn_when_only_keyring_populated(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        backend = mural_module.KeyringBackend()
        backend.set(keyring_alt_backend, "MURAL_CLIENT_ID", "only-keyring")
        caplog.set_level(logging.WARNING, logger="mural")
        mural_module.resolve_backend("default")
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends populated" in r.message
        ]
        assert warns == []

    def test_no_warn_when_only_file_populated(
        self,
        mural_module: Any,
        keyring_alt_backend: str,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        cred_path = mural_module._resolve_credential_file("default", os.environ)
        file_backend = mural_module.FileBackend(cred_path)
        file_backend.set(keyring_alt_backend, "MURAL_CLIENT_ID", "only-file")
        caplog.set_level(logging.WARNING, logger="mural")
        mural_module.resolve_backend("default")
        warns = [
            r
            for r in caplog.records
            if r.levelno == logging.WARNING
            and "both keyring and file backends populated" in r.message
        ]
        assert warns == []
