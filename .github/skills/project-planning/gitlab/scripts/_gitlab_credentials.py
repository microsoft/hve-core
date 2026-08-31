#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Credential profile persistence for the GitLab skill CLI."""

from __future__ import annotations

import errno
import json
import os
import pathlib
import re
import stat
import tempfile
import threading
import time
import urllib.parse
from contextlib import contextmanager
from typing import Any, Iterator, TypedDict, cast

SCHEMA_VERSION = 1
DEFAULT_PROFILE = "default"
LOCK_ACQUISITION_TIMEOUT_SECONDS = 60.0
LOCK_RETRY_INTERVAL_SECONDS = 0.1
_PROFILE_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,31}$")
_REQUIRED_PROFILE_KEYS = {
    "issuer",
    "client_id",
    "access_token",
    "refresh_token",
    "token_type",
    "obtained_at",
    "expires_at",
    "scopes",
    "usable",
}
_PROCESS_LOCK = threading.RLock()
_LOCK_CONTENTION_ERRNOS = frozenset(
    value
    for value in (
        getattr(errno, "EACCES", None),
        getattr(errno, "EAGAIN", None),
        getattr(errno, "EWOULDBLOCK", None),
    )
    if value is not None
)


class CredentialError(ValueError):
    """Base error for GitLab OAuth credential-store failures."""


class CredentialSecurityError(CredentialError):
    """Raised when credential storage fails an ownership or permission check."""


class CredentialValidationError(CredentialError):
    """Raised when a credential profile or store payload is malformed."""


class Profile(TypedDict):
    """Persisted GitLab OAuth profile."""

    issuer: str
    client_id: str
    access_token: str
    refresh_token: str
    token_type: str
    obtained_at: int
    expires_at: int
    scopes: list[str]
    usable: bool


try:  # pragma: no cover - platform specific
    import fcntl as _fcntl
except ImportError:  # pragma: no cover - Windows
    _fcntl = None  # type: ignore[assignment]
try:  # pragma: no cover - platform specific
    import msvcrt as _msvcrt
except ImportError:  # pragma: no cover - POSIX
    _msvcrt = None  # type: ignore[assignment]


def validate_profile_name(name: str) -> str:
    """Return a safe profile name or raise a validation error."""
    if not isinstance(name, str) or not _PROFILE_RE.fullmatch(name):
        raise CredentialValidationError("GitLab profile name is invalid")
    return name


def resolve_profile_name(explicit: str | None, env: dict[str, str]) -> str:
    """Resolve the active profile from CLI input, environment, or default."""
    selected = explicit or env.get("GITLAB_PROFILE") or DEFAULT_PROFILE
    return validate_profile_name(selected)


def resolve_store_path(env: dict[str, str]) -> pathlib.Path:
    """Resolve the GitLab OAuth profile-store path."""
    explicit = env.get("GITLAB_TOKEN_STORE", "").strip()
    if explicit:
        return pathlib.Path(explicit).expanduser()
    if os.name == "nt":  # pragma: no cover - Windows
        local_app_data = env.get("LOCALAPPDATA", "").strip()
        root = (
            pathlib.Path(local_app_data).expanduser()
            if local_app_data
            else pathlib.Path.home() / "AppData/Local"
        )
        return root / "hve-core" / "gitlab" / "gitlab-token.json"
    xdg = env.get("XDG_DATA_HOME", "").strip()
    root = (
        pathlib.Path(xdg).expanduser() if xdg else pathlib.Path.home() / ".local/share"
    )
    return root / "hve-core" / "gitlab" / "gitlab-token.json"


def _validate_issuer(value: str) -> None:
    """Require a canonical origin-only GitLab issuer."""
    try:
        parsed = urllib.parse.urlsplit(value)
    except ValueError as exc:
        raise CredentialValidationError(
            "GitLab OAuth profile issuer is invalid"
        ) from exc
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise CredentialValidationError("GitLab OAuth profile issuer is invalid")
    if parsed.username is not None or parsed.password is not None:
        raise CredentialValidationError("GitLab OAuth profile issuer contains userinfo")
    if parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        raise CredentialValidationError(
            "GitLab OAuth profile issuer must be origin-only"
        )
    hostname = parsed.hostname.lower()
    if parsed.scheme == "http" and not (
        hostname in {"localhost", "::1"} or hostname.startswith("127.")
    ):
        raise CredentialValidationError("GitLab OAuth profile issuer must use HTTPS")


def validate_profile(profile: dict[str, Any]) -> None:
    """Validate a persisted OAuth profile."""
    if not isinstance(profile, dict):
        raise CredentialValidationError("GitLab OAuth profile must be an object")
    missing = sorted(_REQUIRED_PROFILE_KEYS - profile.keys())
    if missing:
        raise CredentialValidationError(
            f"GitLab OAuth profile missing keys: {', '.join(missing)}"
        )
    for key in ("issuer", "client_id", "access_token", "token_type"):
        if not isinstance(profile[key], str) or not profile[key]:
            raise CredentialValidationError(
                f"GitLab OAuth profile {key!r} must be non-empty text"
            )
    _validate_issuer(cast(str, profile["issuer"]))
    if not isinstance(profile["refresh_token"], str):
        raise CredentialValidationError(
            "GitLab OAuth profile 'refresh_token' must be text"
        )
    if not isinstance(profile["obtained_at"], int) or isinstance(
        profile["obtained_at"],
        bool,
    ):
        raise CredentialValidationError(
            "GitLab OAuth profile 'obtained_at' must be an integer"
        )
    if not isinstance(profile["expires_at"], int) or isinstance(
        profile["expires_at"],
        bool,
    ):
        raise CredentialValidationError(
            "GitLab OAuth profile 'expires_at' must be an integer"
        )
    if not isinstance(profile["scopes"], list) or not all(
        isinstance(scope, str) and scope for scope in profile["scopes"]
    ):
        raise CredentialValidationError(
            "GitLab OAuth profile 'scopes' must be a text array"
        )
    if not isinstance(profile["usable"], bool):
        raise CredentialValidationError("GitLab OAuth profile 'usable' must be boolean")


def _ensure_private_parent(path: pathlib.Path) -> None:
    """Create and verify the dedicated credential-store directory."""
    if os.name == "nt":
        raise CredentialSecurityError(
            "GitLab OAuth profile persistence is unavailable on Windows until "
            "a protected credential backend is configured"
        )
    previous_umask = os.umask(0o077)
    try:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    finally:
        os.umask(previous_umask)
    info = path.parent.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.geteuid()
        or info.st_mode & 0o077
    ):
        raise CredentialSecurityError(
            "GitLab OAuth token store directory must be owned by the user "
            "without group or world permissions"
        )


def _validate_descriptor(fd: int, *, label: str) -> None:
    """Validate ownership and permissions on an already-open descriptor."""
    if os.name == "nt":
        return
    info = os.fstat(fd)
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.geteuid()
        or info.st_mode & 0o077
    ):
        raise CredentialSecurityError(
            f"GitLab OAuth token store {label} must be owned by the user "
            "without group or world permissions"
        )


def load_store(path: pathlib.Path) -> dict[str, Any]:
    """Load and validate the OAuth profile store.

    Args:
        path: Profile-store path.

    Returns:
        Validated store envelope, or an empty envelope when the file is absent.

    Raises:
        CredentialSecurityError: The store cannot be opened safely or the
            platform cannot protect persisted OAuth credentials.
        CredentialValidationError: The store encoding, JSON, schema, or profile
            content is malformed.
    """
    if os.name == "nt":
        _ensure_private_parent(path)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except FileNotFoundError:
        return {"schema_version": SCHEMA_VERSION, "profiles": {}}
    except OSError as exc:
        raise CredentialSecurityError(
            "GitLab OAuth token store cannot be opened safely"
        ) from exc
    raw_fd = fd
    try:
        _validate_descriptor(fd, label="file")
        handle = os.fdopen(fd, "r", encoding="utf-8")
        raw_fd = -1
        with handle:
            payload = json.load(handle)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        raise CredentialValidationError(
            "GitLab OAuth token store is not valid JSON"
        ) from exc
    finally:
        if raw_fd >= 0:
            os.close(raw_fd)
    if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
        raise CredentialValidationError(
            "GitLab OAuth token store has an unsupported schema"
        )
    profiles = payload.get("profiles")
    if not isinstance(profiles, dict):
        raise CredentialValidationError(
            "GitLab OAuth token store profiles must be an object"
        )
    for name, profile in profiles.items():
        validate_profile_name(name)
        validate_profile(profile)
    return payload


def save_store(path: pathlib.Path, payload: dict[str, Any]) -> None:
    """Atomically write the OAuth profile store with mode 0600.

    Args:
        path: Profile-store path.
        payload: Validated store envelope.

    Raises:
        CredentialSecurityError: The platform or filesystem cannot provide the
            required storage guarantees.
        CredentialValidationError: The store envelope is malformed.
    """
    if os.name == "nt":
        _ensure_private_parent(path)
    if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
        raise CredentialValidationError(
            "GitLab OAuth token store has an unsupported schema"
        )
    profiles = payload.get("profiles")
    if not isinstance(profiles, dict):
        raise CredentialValidationError(
            "GitLab OAuth token store profiles must be an object"
        )
    for name, profile in profiles.items():
        validate_profile_name(name)
        validate_profile(profile)
    _ensure_private_parent(path)
    previous_umask = os.umask(0o077)
    temp_path: pathlib.Path | None = None
    try:
        fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        temp_path = pathlib.Path(temp_name)
        try:
            if os.name != "nt":
                os.fchmod(fd, 0o600)
            handle = os.fdopen(fd, "w", encoding="utf-8")
        except BaseException:
            os.close(fd)
            raise
        with handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
        temp_path = None
        os.chmod(path, 0o600)
        if os.name != "nt":
            directory_fd = os.open(path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
    except OSError as exc:
        raise CredentialSecurityError(
            "GitLab OAuth token store cannot be written safely"
        ) from exc
    finally:
        os.umask(previous_umask)
        if temp_path is not None:
            try:
                temp_path.unlink(missing_ok=True)
            except OSError:
                pass


@contextmanager
def store_lock(path: pathlib.Path) -> Iterator[None]:
    """Serialize profile-store updates across processes.

    Args:
        path: Profile-store path whose sibling lock file is acquired.

    Yields:
        Control while the in-process and cross-process locks are held.

    Raises:
        CredentialSecurityError: Lock storage cannot be protected or no
            supported locking primitive exists.
        CredentialError: Cross-process lock acquisition exceeds its bounded
            wait. The bound covers acquisition only; it does not bound waiting
            for the in-process lock or work performed while the lock is held.
    """
    with _PROCESS_LOCK:
        _ensure_private_parent(path)
        if _fcntl is None and _msvcrt is None:
            raise CredentialSecurityError(
                "no file-locking primitive is available; refusing an unlocked update"
            )
        lock_path = path.with_name(f"{path.name}.lock")
        flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
        previous_umask = os.umask(0o077)
        try:
            fd = os.open(lock_path, flags, 0o600)
        except OSError as exc:
            raise CredentialSecurityError(
                "GitLab OAuth token store lock cannot be opened safely"
            ) from exc
        finally:
            os.umask(previous_umask)
        acquired = False
        try:
            _validate_descriptor(fd, label="lock")
            deadline = time.monotonic() + LOCK_ACQUISITION_TIMEOUT_SECONDS
            while True:
                try:
                    if _fcntl is not None:  # pragma: no branch - one platform path
                        _fcntl.flock(fd, _fcntl.LOCK_EX | _fcntl.LOCK_NB)
                    elif _msvcrt is not None:  # pragma: no cover - Windows
                        _msvcrt.locking(fd, _msvcrt.LK_NBLCK, 1)
                    acquired = True
                    break
                except OSError as exc:
                    if _fcntl is not None and exc.errno not in _LOCK_CONTENTION_ERRNOS:
                        raise
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise CredentialError(
                            "timed out waiting for the GitLab OAuth token store lock"
                        ) from None
                    time.sleep(min(LOCK_RETRY_INTERVAL_SECONDS, remaining))
            yield
        finally:
            try:
                if acquired and _fcntl is not None:  # pragma: no branch
                    _fcntl.flock(fd, _fcntl.LOCK_UN)
                elif acquired and _msvcrt is not None:  # pragma: no cover - Windows
                    _msvcrt.locking(fd, _msvcrt.LK_UNLCK, 1)
            finally:
                os.close(fd)


def get_profile(store: dict[str, Any], name: str) -> Profile:
    """Return one named profile or raise a credential error."""
    validate_profile_name(name)
    profile = store.get("profiles", {}).get(name)
    if not isinstance(profile, dict):
        raise CredentialValidationError(
            f"GitLab OAuth profile {name!r} does not exist; run auth login"
        )
    validate_profile(profile)
    return cast(Profile, profile)


def set_profile(store: dict[str, Any], name: str, profile: Profile) -> None:
    """Set one validated profile in a mutable store envelope."""
    validate_profile_name(name)
    validate_profile(profile)
    store.setdefault("profiles", {})[name] = profile


def delete_profile(store: dict[str, Any], name: str) -> bool:
    """Delete one profile and report whether it existed."""
    validate_profile_name(name)
    return store.setdefault("profiles", {}).pop(name, None) is not None
