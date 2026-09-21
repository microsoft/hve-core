# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for GitLab OAuth profile persistence."""

from __future__ import annotations

import errno
import inspect
import json
import os
import pathlib
import subprocess
import sys
import threading
import time

import _gitlab_credentials as credentials
import pytest


def _profile() -> credentials.Profile:
    return {
        "issuer": "https://gitlab.example.com",
        "client_id": "client",
        "access_token": "access",
        "refresh_token": "refresh",
        "token_type": "Bearer",
        "obtained_at": 1,
        "expires_at": 2,
        "scopes": ["api"],
        "usable": True,
    }


def test_store_round_trip_uses_private_directory_and_mode_0600(
    tmp_path: pathlib.Path,
) -> None:
    path = tmp_path / "gitlab" / "gitlab-token.json"
    store = {"schema_version": 1, "profiles": {"default": _profile()}}

    credentials.save_store(path, store)

    assert credentials.load_store(path) == store
    if os.name != "nt":
        assert path.stat().st_mode & 0o777 == 0o600
        assert path.parent.stat().st_mode & 0o777 == 0o700


def test_load_store_rejects_unsafe_permissions(tmp_path: pathlib.Path) -> None:
    if os.name == "nt":
        pytest.skip("POSIX permission semantics")
    path = tmp_path / "gitlab-token.json"
    path.write_text(json.dumps({"schema_version": 1, "profiles": {}}))
    path.chmod(0o644)

    with pytest.raises(credentials.CredentialSecurityError, match="owned by the user"):
        credentials.load_store(path)


def test_save_store_rejects_unsafe_existing_parent(tmp_path: pathlib.Path) -> None:
    if os.name == "nt":
        pytest.skip("POSIX permission semantics")
    parent = tmp_path / "shared"
    parent.mkdir(mode=0o755)
    parent.chmod(0o755)
    path = parent / "gitlab-token.json"

    with pytest.raises(
        credentials.CredentialSecurityError,
        match="directory must be owned",
    ):
        credentials.save_store(
            path,
            {"schema_version": 1, "profiles": {"default": _profile()}},
        )


def test_load_store_rejects_symlink(tmp_path: pathlib.Path) -> None:
    if os.name == "nt" or not hasattr(os, "O_NOFOLLOW"):
        pytest.skip("POSIX no-follow semantics")
    target = tmp_path / "target.json"
    target.write_text(json.dumps({"schema_version": 1, "profiles": {}}))
    target.chmod(0o600)
    link = tmp_path / "gitlab-token.json"
    link.symlink_to(target)

    with pytest.raises(credentials.CredentialSecurityError, match="opened safely"):
        credentials.load_store(link)


def test_load_store_normalizes_invalid_utf8(tmp_path: pathlib.Path) -> None:
    path = tmp_path / "gitlab-token.json"
    path.write_bytes(b"\xff")
    path.chmod(0o600)

    with pytest.raises(credentials.CredentialValidationError, match="valid JSON"):
        credentials.load_store(path)


def test_windows_store_fails_closed_before_filesystem_access(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    monkeypatch.setattr(credentials.os, "name", "nt")
    opened: list[object] = []
    monkeypatch.setattr(
        credentials.os,
        "open",
        lambda *_args, **_kwargs: opened.append(True),
    )

    with pytest.raises(credentials.CredentialSecurityError, match="unavailable"):
        credentials.load_store(tmp_path / "gitlab-token.json")

    assert opened == []


def _raise_inside_store_lock(path: pathlib.Path) -> None:
    """Raise from inside a held store lock so the caller can assert release."""
    with credentials.store_lock(path):
        raise RuntimeError("boom")


def test_store_lock_releases_after_body_error(tmp_path: pathlib.Path) -> None:
    path = tmp_path / "gitlab" / "gitlab-token.json"

    with pytest.raises(RuntimeError, match="boom"):
        _raise_inside_store_lock(path)

    reacquired = False
    with credentials.store_lock(path):
        reacquired = True

    assert reacquired, "store_lock must be re-acquirable after its body raised"


def test_store_lock_serializes_threads(tmp_path: pathlib.Path) -> None:
    path = tmp_path / "gitlab" / "gitlab-token.json"
    entered: list[int] = []
    first_entered = threading.Event()
    release_first = threading.Event()

    def worker(identifier: int) -> None:
        with credentials.store_lock(path):
            entered.append(identifier)
            if identifier == 1:
                first_entered.set()
                release_first.wait(timeout=2)

    first = threading.Thread(target=worker, args=(1,))
    second = threading.Thread(target=worker, args=(2,))
    first.start()
    first_entered.wait(timeout=1)
    second.start()
    time.sleep(0.05)
    assert entered == [1]
    release_first.set()
    first.join(timeout=1)
    second.join(timeout=1)

    assert entered == [1, 2]


@pytest.mark.parametrize("contention_errno", ["EACCES", "EAGAIN", "EWOULDBLOCK"])
def test_store_lock_retries_contention_then_acquires(
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    contention_errno: str,
) -> None:
    if credentials._fcntl is None:
        pytest.skip("POSIX advisory locking is unavailable")
    path = tmp_path / "gitlab" / "gitlab-token.json"
    operations: list[int] = []
    sleeps: list[float] = []
    clock = [0.0]

    def flock(_fd: int, operation: int) -> None:
        operations.append(operation)
        if len(operations) == 1:
            raise OSError(getattr(errno, contention_errno), "locked")

    monkeypatch.setattr(credentials._fcntl, "flock", flock)
    monkeypatch.setattr(credentials.time, "monotonic", lambda: clock[0])
    monkeypatch.setattr(
        credentials.time,
        "sleep",
        lambda seconds: sleeps.append(seconds),
    )

    with credentials.store_lock(path):
        pass

    assert sleeps == [credentials.LOCK_RETRY_INTERVAL_SECONDS]
    assert operations[-1] == credentials._fcntl.LOCK_UN


def test_store_lock_times_out_under_persistent_contention(
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    if credentials._fcntl is None:
        pytest.skip("POSIX advisory locking is unavailable")
    path = tmp_path / "gitlab" / "gitlab-token.json"
    operations: list[int] = []
    clock = [0.0]

    def flock(_fd: int, operation: int) -> None:
        operations.append(operation)
        raise OSError(errno.EWOULDBLOCK, "locked")

    def sleep(seconds: float) -> None:
        clock[0] += seconds

    monkeypatch.setattr(credentials._fcntl, "flock", flock)
    monkeypatch.setattr(credentials.time, "monotonic", lambda: clock[0])
    monkeypatch.setattr(credentials.time, "sleep", sleep)

    with pytest.raises(credentials.CredentialError, match="timed out waiting"):
        with credentials.store_lock(path):  # pragma: no cover - body must not run
            pass

    assert clock[0] == pytest.approx(credentials.LOCK_ACQUISITION_TIMEOUT_SECONDS)
    assert credentials._fcntl.LOCK_UN not in operations


def test_store_lock_propagates_non_contention_errors(
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    if credentials._fcntl is None:
        pytest.skip("POSIX advisory locking is unavailable")
    path = tmp_path / "gitlab" / "gitlab-token.json"
    sleeps: list[float] = []

    def flock(_fd: int, _operation: int) -> None:
        raise OSError(errno.ENOLCK, "no locks available")

    monkeypatch.setattr(credentials._fcntl, "flock", flock)
    monkeypatch.setattr(
        credentials.time,
        "sleep",
        lambda seconds: sleeps.append(seconds),
    )

    with pytest.raises(OSError) as exc_info:
        with credentials.store_lock(path):  # pragma: no cover - body must not run
            pass

    assert exc_info.value.errno == errno.ENOLCK
    assert sleeps == []


def _hold_store_lock_child(lock_path: str, ready_path: str) -> None:
    """Hold a real advisory lock in a separate process until stdin closes."""
    import fcntl
    import pathlib as child_pathlib
    import sys

    descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        child_pathlib.Path(ready_path).write_text("ready", encoding="utf-8")
        sys.stdin.read()
    finally:
        os.close(descriptor)


def test_store_lock_times_out_against_independent_process(
    tmp_path: pathlib.Path,
) -> None:
    if credentials._fcntl is None or os.name == "nt":
        pytest.skip("POSIX advisory locking is unavailable")
    path = tmp_path / "gitlab" / "gitlab-token.json"
    credentials._ensure_private_parent(path)
    lock_path = path.with_name(f"{path.name}.lock")
    ready_path = tmp_path / "child-ready"
    source = (
        f"{inspect.getsource(_hold_store_lock_child)}\n"
        "import os\n"
        f"_hold_store_lock_child({str(lock_path)!r}, {str(ready_path)!r})\n"
    )
    child = subprocess.Popen(
        [sys.executable, "-c", source],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.monotonic() + 10
        while not ready_path.exists():
            if time.monotonic() >= deadline:
                pytest.fail("lock-holding child process did not signal readiness")
            time.sleep(0.01)

        original_timeout = credentials.LOCK_ACQUISITION_TIMEOUT_SECONDS
        credentials.LOCK_ACQUISITION_TIMEOUT_SECONDS = 0.3
        try:
            with pytest.raises(credentials.CredentialError, match="timed out waiting"):
                with credentials.store_lock(path):  # pragma: no cover - must not run
                    pass
        finally:
            credentials.LOCK_ACQUISITION_TIMEOUT_SECONDS = original_timeout
    finally:
        if child.stdin is not None:
            child.stdin.close()
        child.wait(timeout=10)

    with credentials.store_lock(path):
        released = True

    assert released, "store_lock must acquire once the other process releases it"


def test_save_failure_preserves_existing_store(
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "gitlab" / "gitlab-token.json"
    original = {"schema_version": 1, "profiles": {"default": _profile()}}
    credentials.save_store(path, original)
    monkeypatch.setattr(
        credentials.os,
        "replace",
        lambda *_args: (_ for _ in ()).throw(OSError("disk failure")),
    )

    with pytest.raises(credentials.CredentialSecurityError, match="written safely"):
        credentials.save_store(
            path,
            {"schema_version": 1, "profiles": {}},
        )

    assert credentials.load_store(path) == original


def test_default_store_path_uses_dedicated_private_leaf(
    tmp_path: pathlib.Path,
) -> None:
    path = credentials.resolve_store_path({"XDG_DATA_HOME": str(tmp_path)})

    assert path == tmp_path / "hve-core" / "gitlab" / "gitlab-token.json"


@pytest.mark.parametrize("name", ["", ".bad", "bad/name", "bad name", "x" * 33])
def test_validate_profile_name_rejects_unsafe(name: str) -> None:
    with pytest.raises(ValueError):
        credentials.validate_profile_name(name)


def test_profile_binding_fields_are_required() -> None:
    profile: dict[str, object] = dict(_profile())
    profile.pop("issuer")

    with pytest.raises(ValueError, match="missing keys"):
        credentials.validate_profile(profile)


def test_profile_issuer_must_be_origin_only() -> None:
    profile = _profile()
    profile["issuer"] = "https://gitlab.example.com/attacker"

    with pytest.raises(
        credentials.CredentialValidationError,
        match="origin-only",
    ):
        credentials.validate_profile(profile)


def test_delete_profile_reports_presence() -> None:
    store = {"schema_version": 1, "profiles": {"default": _profile()}}

    assert credentials.delete_profile(store, "default") is True
    assert credentials.delete_profile(store, "default") is False
