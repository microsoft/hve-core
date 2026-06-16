#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Credential resolution helpers (leaves only at this stage).

Backend classes (``KeyringBackend``, ``FileBackend``, ``_NullBackend``,
``resolve_backend``) move here in Step 4.1.
"""

from __future__ import annotations

import contextlib
import logging
import os
import pathlib
import sys
from typing import Any, Mapping, MutableMapping

from ._constants import (
    _KNOWN_CREDENTIAL_KEYS,
    _PROFILE_NAME_RE,
    _PROFILE_REQUIRED_KEYS,
    DEFAULT_PROFILE_NAME,
    ENV_CLIENT_ID,
    ENV_ENV_FILE,
    ENV_ENV_FILE_RELAXED,
    ENV_PROFILE,
    ENV_TOKEN_STORE,
    ENV_XDG_CONFIG_HOME,
    ENV_XDG_DATA_HOME,
    TOKEN_STORE_SCHEMA_VERSION,
)
from ._exceptions import MuralError, MuralValidationError
from ._protocols import CredentialBackend


def _pkg() -> Any:
    """Return the live ``mural`` package module for monkeypatch-aware routing."""
    return sys.modules[__package__]


def _resolve_credential_file(
    profile_name: str,
    environ: Mapping[str, str] | None = None,
) -> pathlib.Path:
    src = environ if environ is not None else os.environ
    explicit = src.get(ENV_ENV_FILE)
    if explicit:
        return pathlib.Path(explicit).expanduser()
    filename = f"mural.{profile_name}.env"
    xdg = src.get(ENV_XDG_CONFIG_HOME)
    if xdg:
        return pathlib.Path(xdg) / "hve-core" / filename
    if os.name == "nt":
        appdata = src.get("APPDATA")
        if appdata:
            return pathlib.Path(appdata) / "hve-core" / filename
    return pathlib.Path.home() / ".config" / "hve-core" / filename


def _service_name_for(profile: str) -> str:
    """Return the keyring service name for ``profile`` honoring overrides."""
    override = os.environ.get("MURAL_KEYRING_SERVICE")
    if override:
        return override
    return f"hve-core/mural/{profile}"


def _profile_from_credential_path(path: pathlib.Path) -> str:
    """Derive the profile name from a credential file path's filename.

    Mirrors the ``mural.{profile}.env`` convention written by
    :func:`_resolve_credential_file`. Falls back to
    :data:`DEFAULT_PROFILE_NAME` for arbitrary paths (e.g. when
    ``MURAL_ENV_FILE`` overrides to a custom file).
    """
    name = path.name
    if name.startswith("mural.") and name.endswith(".env"):
        candidate = name[len("mural.") : -len(".env")]
        if candidate and _PROFILE_NAME_RE.match(candidate):
            return candidate
    return DEFAULT_PROFILE_NAME


def _resolve_token_store_path(env: dict[str, str] | None = None) -> pathlib.Path:
    """Return the on-disk token store path.

    Precedence: ``MURAL_TOKEN_STORE`` env var overrides everything. Otherwise:

    * Windows (``os.name == "nt"``): ``%LOCALAPPDATA%/hve-core/mural-token.json``,
      falling back to ``~/AppData/Local/hve-core/mural-token.json``.
    * POSIX: ``$XDG_DATA_HOME/hve-core/mural-token.json``, falling back to
      ``~/.local/share/hve-core/mural-token.json``.
    """
    src = env if env is not None else os.environ
    explicit = src.get(ENV_TOKEN_STORE)
    if explicit:
        return pathlib.Path(explicit).expanduser()
    if os.name == "nt":
        local_app_data = src.get("LOCALAPPDATA")
        if local_app_data:
            base = pathlib.Path(local_app_data).expanduser()
        else:
            base = pathlib.Path.home() / "AppData" / "Local"
    else:
        xdg = src.get(ENV_XDG_DATA_HOME)
        if xdg:
            base = pathlib.Path(xdg).expanduser()
        else:
            base = pathlib.Path.home() / ".local" / "share"
    return base / "hve-core" / "mural-token.json"


def _validate_client_secret(secret: str) -> str:
    """Reject empty/whitespace/short Mural client secrets before persistence.

    Catches the common bootstrap mistakes (paste fragment, trailing newline,
    accidentally pasting the client_id) before they get written to keyring or
    .env and silently fail later with an opaque ``invalid_client`` from Mural.
    """
    if not isinstance(secret, str):
        raise ValueError("client secret must be a string")
    trimmed = secret.strip()
    if not trimmed:
        raise ValueError("client secret is empty or whitespace only")
    if any(ch.isspace() for ch in trimmed):
        raise ValueError("client secret must not contain whitespace")
    # Mural client secrets are 64-char hex tokens; 16 is a safe lower bound
    # that catches truncated pastes without rejecting future shorter formats.
    if len(trimmed) < 16:
        raise ValueError(
            f"client secret is too short ({len(trimmed)} chars); expected at least 16"
        )
    return trimmed


def _compute_expires_at(now: float, expires_in: int | None) -> int:
    """Return an absolute expiry timestamp, fail-closed when ``expires_in`` is unknown.

    A missing, zero, or negative ``expires_in`` produces ``int(now)`` so the
    persisted value is immediately stale; the proactive-refresh predicate then
    forces a refresh on the next authenticated request rather than leaving the
    profile in an eternal-token state.
    """
    seconds = int(expires_in or 0)
    if seconds <= 0:
        return int(now)
    return int(now) + seconds


def _check_credential_file_perms(
    path: pathlib.Path, environ: Mapping[str, str]
) -> None:
    # Windows ACL semantics are out of scope; permission gating is POSIX-only.
    if os.name == "nt":
        return
    st = path.stat()
    expected_uid = os.geteuid()
    if st.st_uid != expected_uid:
        raise MuralError(
            f"Refusing to load {path}: file is owned by uid {st.st_uid} "
            f"(expected {expected_uid}). Re-create the file with "
            f"`chown {expected_uid} {path}` or remove it and re-run "
            "`mural auth bootstrap`."
        )
    mode = st.st_mode & 0o777
    if (mode & 0o077) == 0:
        return
    if environ.get(ENV_ENV_FILE_RELAXED) == "1":
        key = str(path)
        if key not in _pkg()._state.seen_relaxed_warn():
            _pkg()._state.seen_relaxed_warn().add(key)
            _pkg()._emit(
                f"{ENV_ENV_FILE_RELAXED}=1 honored for {path}; this disables "
                "mode-0600 enforcement (CI use only)",
                level=logging.WARNING,
            )
        return
    raise MuralError(
        f"Refusing to load {path}: mode {oct(mode)} is too permissive "
        f"(must be 0600). Run `chmod 0600 {path}` or set "
        f"{ENV_ENV_FILE_RELAXED}=1 to override."
    )


class _KeyringUnavailable(RuntimeError):
    """Sentinel raised when the keyring backend cannot be reached.

    Wraps ``ImportError``, ``keyring.errors.KeyringError``, and any
    platform-specific failure (headless Linux without D-Bus, locked vault,
    misconfigured ``MURAL_KEYRING_BACKEND`` override). Callers in
    :func:`resolve_backend` catch this sentinel to drive auto-fallback.
    """


class _NullBackend:
    """Backend used when ``MURAL_CREDENTIAL_BACKEND=env-only``.

    Reads return ``None`` so callers fall through to whatever is already
    populated in ``os.environ``. Writes raise to surface the fact that
    env-only mode has no persistence layer.
    """

    name = "env-only"

    def get(self, service: str, key: str) -> str | None:
        return None

    def set(self, service: str, key: str, value: str) -> None:
        raise RuntimeError("env-only backend cannot persist credentials")

    def delete(self, service: str, key: str) -> None:
        raise RuntimeError("env-only backend cannot persist credentials")


# Cached one-shot probe of keyring availability so ``mural auth status`` and
# downstream callers do not pay the import + backend resolution cost twice.
# Populated lazily by :func:`_probe_keyring_availability`.
_keyring_probe_cache: tuple[bool, str | None, str | None] | None = None


def _probe_keyring_availability() -> tuple[bool, str | None, str | None]:
    """Return ``(available, backend_name, error)`` for the keyring backend.

    Caches the result in :data:`_keyring_probe_cache` so repeated calls
    within the same process incur a single import + backend lookup. The
    probe never raises: ``_KeyringUnavailable`` is converted to
    ``(False, None, str(exc))``.
    """
    global _keyring_probe_cache
    if _keyring_probe_cache is not None:
        return _keyring_probe_cache
    try:
        backend = _pkg().KeyringBackend()
    except _KeyringUnavailable as exc:
        _keyring_probe_cache = (False, None, str(exc))
        return _keyring_probe_cache
    _keyring_probe_cache = (True, getattr(backend, "backend_name", None), None)
    return _keyring_probe_cache


def _maybe_warn_concurrent_state(
    profile: str,
    selected: CredentialBackend,
    file_path: pathlib.Path,
) -> None:
    """Emit a one-shot WARN when both persistent backends hold values.

    Probe failures (keyring unavailable, file unreadable, parse error) are
    swallowed so credential resolution proceeds with the already-selected
    backend.
    """
    dedup_key = (profile, selected.name)
    if dedup_key in _pkg()._state.seen_concurrent_warn():
        return
    keyring_populated = False
    file_populated = False
    service = _service_name_for(profile)
    try:
        probe_keyring = _pkg().KeyringBackend()
        for key in _KNOWN_CREDENTIAL_KEYS:
            value = probe_keyring.get(service, key)
            if value:
                keyring_populated = True
                break
    except _KeyringUnavailable:
        keyring_populated = False
    except Exception:  # noqa: BLE001 - probe must never raise
        keyring_populated = False
    try:
        if file_path.exists():
            entries = _pkg().FileBackend(file_path)._read_all()
            file_populated = any(entries.get(k) for k in _KNOWN_CREDENTIAL_KEYS)
    except Exception:  # noqa: BLE001 - probe must never raise
        file_populated = False
    if keyring_populated and file_populated:
        _pkg()._state.seen_concurrent_warn().add(dedup_key)
        _pkg()._emit(
            f"both keyring and file backends populated for profile "
            f"{profile!r}; {selected.name} backend takes precedence "
            "(run 'mural auth migrate --cleanup' to remove the stale copy)",
            level=logging.WARNING,
        )


def _autoload_credentials(
    profile_name: str,
    environ: MutableMapping[str, str] | None = None,
) -> pathlib.Path | None:
    """Hydrate ``environ`` from the credential backend selected for ``profile_name``.

    Routes every read through :func:`resolve_backend` so keyring-backed
    deployments hydrate without ever touching the on-disk credential file.
    Existing entries in ``environ`` always take precedence (env-var
    overrides are honoured). Returns the credential file path when the
    file backend supplied at least one value (preserves the legacy return
    contract used by diagnostics); returns ``None`` for keyring-only,
    env-only, or unpopulated cases.
    """
    env = environ if environ is not None else os.environ
    try:
        backend = _pkg().resolve_backend(profile_name)
    except MuralError:
        return None
    if isinstance(backend, _NullBackend):
        return None
    service = _service_name_for(profile_name)
    if isinstance(backend, _pkg().FileBackend) and backend._path.exists():
        # Preserve the historic mode-0600 enforcement that the legacy
        # autoload performed before reading.
        _pkg()._check_credential_file_perms(backend._path, env)
    loaded_any = False
    for key in _KNOWN_CREDENTIAL_KEYS:
        if env.get(key):
            continue
        try:
            value = backend.get(service, key)
        except _KeyringUnavailable:
            continue
        if value:
            env.setdefault(key, value)
            loaded_any = True
    if isinstance(backend, _pkg().FileBackend) and loaded_any:
        return backend._path
    return None


def _validate_profile_name(name: Any) -> str:
    """Return ``name`` after asserting it matches :data:`_PROFILE_NAME_RE`.

    Raises :class:`MuralValidationError` on any non-conforming input.
    """
    if not isinstance(name, str) or not _PROFILE_NAME_RE.match(name):
        raise MuralValidationError(f"invalid profile name: {name!r}")
    return name


def _validate_profile(profile: Any) -> None:
    """Assert ``profile`` is a dict carrying the required token fields.

    Optional fields (``refresh_token``, ``scope``, ``granted_scopes``) are
    not enforced. ``expires_at`` is required and must be an integer; a value
    of ``0`` is permitted and signals "refresh on next use". Unknown keys are
    preserved by callers on round-trip.
    """
    if not isinstance(profile, dict):
        raise MuralError("token store profile is malformed: not a JSON object")
    missing = [k for k in _PROFILE_REQUIRED_KEYS if k not in profile]
    if missing:
        raise MuralError(
            "token store profile is malformed: missing keys "
            + ", ".join(sorted(missing))
        )
    expires_at = profile.get("expires_at")
    if not isinstance(expires_at, int) or isinstance(expires_at, bool):
        raise MuralError(
            "token store profile is malformed: 'expires_at' must be an integer"
        )


def _select_profile(
    store: dict[str, Any], name: str = DEFAULT_PROFILE_NAME
) -> dict[str, Any]:
    """Return the named profile dict from a v2 envelope.

    Raises :class:`MuralError` when the profile is absent.
    """
    _pkg()._validate_profile_name(name)
    profiles = store.get("profiles") if isinstance(store, dict) else None
    if not isinstance(profiles, dict) or name not in profiles:
        raise MuralError(f"profile {name!r} not found in token store")
    profile = profiles[name]
    _pkg()._validate_profile(profile)
    return profile


def _resolve_active_profile(
    store: dict[str, Any] | None,
    env: dict[str, str] | os._Environ[str] | None,
    cli_value: str | None,
) -> str:
    """Resolve which profile is currently active.

    Precedence (first non-empty wins):

    1. ``cli_value`` from ``--profile`` flag.
    2. ``MURAL_PROFILE`` environment variable.
    3. ``active_profile`` field on the v2 envelope.
    4. :data:`DEFAULT_PROFILE_NAME`.

    The selected name is validated; the profile is not required to exist
    in ``store`` (callers handle absence as appropriate).
    """
    src = env if env is not None else os.environ
    candidate: str | None = None
    if cli_value:
        candidate = cli_value
    elif src.get(ENV_PROFILE):
        candidate = src.get(ENV_PROFILE)
    elif isinstance(store, dict):
        active = store.get("active_profile")
        if isinstance(active, str) and active:
            candidate = active
    if not candidate:
        candidate = DEFAULT_PROFILE_NAME
    return _pkg()._validate_profile_name(candidate)


def _migrate_v1_to_v2(
    legacy: dict[str, Any],
    env: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Wrap a legacy single-record token cache in a v2 envelope.

    Binds ``client_id`` from :data:`ENV_CLIENT_ID` when the legacy record
    lacks one, emitting a WARNING so operators can audit the binding.
    """
    src = env if env is not None else os.environ
    profile = dict(legacy)
    if "client_id" not in profile:
        client_id = src.get(ENV_CLIENT_ID)
        if client_id:
            profile["client_id"] = client_id
            _pkg()._emit(
                "legacy token cache had no client_id; bound to MURAL_CLIENT_ID "
                "for profile 'default'",
                level=logging.WARNING,
            )
    if "token_type" not in profile:
        profile["token_type"] = "Bearer"
    if "obtained_at" not in profile:
        profile["obtained_at"] = 0
    if not isinstance(profile.get("expires_at"), int) or isinstance(
        profile.get("expires_at"), bool
    ):
        profile["expires_at"] = 0
    return {
        "schema_version": TOKEN_STORE_SCHEMA_VERSION,
        "profiles": {DEFAULT_PROFILE_NAME: profile},
    }


@contextlib.contextmanager
def _acquire_cache_lock(path: pathlib.Path):
    """Hold an exclusive cross-process lock on ``<path>.lock``.

    POSIX uses :func:`fcntl.flock`; Windows uses :func:`msvcrt.locking`.
    The lockfile is created mode 0600 and is never deleted to avoid races
    with concurrent acquirers; the file descriptor is always closed on exit.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = path.with_name(path.name + ".lock")
    fd = os.open(str(lock_path), os.O_RDWR | os.O_CREAT, 0o600)
    _fcntl = _pkg()._fcntl
    _msvcrt = _pkg()._msvcrt
    try:
        if _fcntl is not None:
            _fcntl.flock(fd, _fcntl.LOCK_EX)
            try:
                yield
            finally:
                with contextlib.suppress(OSError):
                    _fcntl.flock(fd, _fcntl.LOCK_UN)
        elif _msvcrt is not None:  # pragma: no cover - Windows
            _msvcrt.locking(fd, _msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                with contextlib.suppress(OSError):
                    os.lseek(fd, 0, os.SEEK_SET)
                    _msvcrt.locking(fd, _msvcrt.LK_UNLCK, 1)
        else:  # pragma: no cover - no lock primitive available
            yield
    finally:
        with contextlib.suppress(OSError):
            os.close(fd)


def _load_token_store(path: pathlib.Path) -> dict[str, Any] | None:
    """Load a token store from disk under a cross-process lock."""
    with _pkg()._acquire_cache_lock(path):
        return _pkg()._load_token_store_locked(path)


@contextlib.contextmanager
def _token_store_session(path: pathlib.Path):
    """Yield ``(envelope, commit)`` while holding the token store lock.

    Closes the IV-001 read/modify/write TOCTOU window: load and save share a
    single ``_acquire_cache_lock`` acquisition. ``envelope`` is the loaded
    store (or ``None`` when absent). ``commit(new_envelope)`` writes
    atomically via :func:`_save_token_store_locked` under the held lock.
    """
    with _pkg()._acquire_cache_lock(path):
        envelope = _pkg()._load_token_store_locked(path)

        def commit(new_envelope: dict[str, Any]) -> None:
            _pkg()._save_token_store_locked(path, new_envelope)

        yield envelope, commit


def _save_token_store(path: pathlib.Path, data: dict[str, Any]) -> None:
    """Persist a token store atomically with mode 0600 under a cross-process lock."""
    with _pkg()._acquire_cache_lock(path):
        _pkg()._save_token_store_locked(path, data)
