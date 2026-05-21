#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# dependencies = ["shapely>=2.0", "scipy>=1.11", "networkx>=3.0", "keyring>=24.0"]
# ///
"""Mural REST API client and CLI.

The auth surface covers env-var resolution, token-store I/O, PKCE, the
``_authenticated_request`` transport with auto-refresh and 429 backoff, and the
loopback OAuth ``auth login`` / ``logout`` / ``status`` subcommands. Mural REST
resource subcommands (workspace, room, mural, widget) live in this same module.

Runtime third-party dependencies are ``shapely``, ``scipy``, and ``networkx``;
``shapely`` requires GEOS >= 3.11 to be present on the host. Test seams are
exposed via private parameters (``_http``, ``_now``, ``_open_browser``,
``_server_factory``) so unit tests can substitute fakes without
monkey-patching.
"""

from __future__ import annotations

import argparse
import base64
import collections
import concurrent.futures
import contextlib
import datetime
import getpass
import hashlib
import json
import logging
import os
import pathlib
import re
import secrets
import signal
import sys
import threading
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
import uuid
import webbrowser
from collections.abc import Mapping, MutableMapping
from dataclasses import dataclass
from typing import Any, Callable, Protocol, Sequence

# Re-export carved-out symbols so residual code and tests keep working.
from ._constants import (  # noqa: E402,F401
    _AUTHORED_BY_AI_TAG_TEXT,
    _KNOWN_CREDENTIAL_KEYS,
    _LINE_RE,
    _PARENTID_FILTER_ENABLED,
    _PROFILE_NAME_RE,
    _PROFILE_REQUIRED_KEYS,
    _REDACT_KEYS,
    _REDACT_PATTERNS,
    _REFRESH_LOCK,
    _RESERVED_TAG_PREFIXES,
    _RESERVED_TAGS,
    _ROTATION_ENABLED,
    _TAG_MERGE_BACKOFF_MAX_MS,
    _TAG_MERGE_BACKOFF_MIN_MS,
    _TAG_MERGE_MAX_RETRIES,
    DEFAULT_LOGIN_SCOPES,
    DEFAULT_PROFILE_NAME,
    DEFAULT_REDIRECT_URI,
    DEFAULT_SCOPES,
    ENV_BASE_URL,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    ENV_DEFAULT_WORKSPACE,
    ENV_ENV_FILE,
    ENV_ENV_FILE_RELAXED,
    ENV_NONINTERACTIVE,
    ENV_PROFILE,
    ENV_REDIRECT_URI,
    ENV_SCOPES,
    ENV_TOKEN_STORE,
    ENV_XDG_CONFIG_HOME,
    ENV_XDG_DATA_HOME,
    EXIT_AREA_CAPACITY,
    EXIT_FAILURE,
    EXIT_NOPERM,
    EXIT_SUCCESS,
    EXIT_TEMPFAIL,
    EXIT_USAGE,
    MAX_BACKOFF_SECONDS,
    MAX_BULK_WIDGETS,
    MAX_RETRIES,
    MURAL_AUTHORIZE_URL,
    MURAL_BASE_URL_DEFAULT,
    MURAL_MAX_BODY_BYTES,
    MURAL_TOKEN_URL,
    POLL_DEFAULT_INTERVAL_S,
    POLL_DEFAULT_TIMEOUT_S,
    POLL_MAX_INTERVAL_S,
    POLL_MAX_TIMEOUT_S,
    RATE_LIMIT_BUCKET_CAPACITY,
    RATE_LIMIT_TOKENS_PER_SEC,
    READ_SCOPES,
    REFRESH_LEEWAY_SECONDS,
    TOKEN_STORE_SCHEMA_VERSION,
    USER_AGENT,
    WRITE_SCOPES,
)
from ._credentials import (  # noqa: E402,F401
    _profile_from_credential_path,
    _resolve_credential_file,
    _resolve_token_store_path,
    _service_name_for,
    _validate_client_secret,
)
from ._exceptions import (  # noqa: E402,F401
    MCPInvalidParamsError,
    MuralAmbiguousWorkspaceError,
    MuralAPIError,
    MuralAreaCapacityExceeded,
    MuralAuthScopeError,
    MuralBulkAtomicAbort,
    MuralError,
    MuralHumanAuthoredProtected,
    MuralSecurityError,
    MuralTagMergeConflict,
    MuralValidationError,
    ResponseTooLarge,
)

# Env-driven flags re-read on every package import/reload so importlib.reload(mural)
# picks up environment changes without also reloading mural._constants.
_ROTATION_ENABLED = os.environ.get("MURAL_SPATIAL_ROTATION_ENABLED", "0") == "1"  # noqa: F811
_PARENTID_FILTER_ENABLED = os.environ.get("MURAL_SPATIAL_PARENTID_FILTER", "0") == "1"  # noqa: F811

# Cross-platform file-lock primitives. Exactly one is non-None at runtime.
try:  # pragma: no cover - platform-specific
    import fcntl as _fcntl
except ImportError:  # pragma: no cover - Windows
    _fcntl = None  # type: ignore[assignment]
try:  # pragma: no cover - platform-specific
    import msvcrt as _msvcrt
except ImportError:  # pragma: no cover - POSIX
    _msvcrt = None  # type: ignore[assignment]

# Third-party dependency probe. ``shapely`` is a required runtime dependency
# (declared in ``pyproject.toml`` and the PEP 723 header above). The guarded
# import lets ``_probe_geos_version`` raise a structured ``MuralError`` for an
# older shapely or absent GEOS instead of surfacing an opaque ImportError at
# module load.
try:  # pragma: no cover - older shapely
    from shapely import geos_version as _SHAPELY_GEOS_VERSION
except ImportError:  # pragma: no cover - older shapely or shapely absent
    _SHAPELY_GEOS_VERSION = None  # type: ignore[assignment]


_GEOS_PROBE_DONE = False


def _probe_geos_version() -> tuple[int, int, int]:
    """Probe the bundled GEOS version exposed by ``shapely``.

    Returns the ``(major, minor, patch)`` tuple from ``shapely.geos_version``,
    or raises ``MuralError`` when the import or attribute lookup fails or when
    the detected major/minor is below ``(3, 11)``.
    """
    version = _SHAPELY_GEOS_VERSION
    if version is None:
        raise MuralError(
            "Unable to probe shapely.geos_version; mural spatial features "
            "require GEOS >= 3.11."
        )
    try:
        major, minor, patch = int(version[0]), int(version[1]), int(version[2])
    except (TypeError, ValueError, IndexError) as exc:
        raise MuralError(
            f"Detected GEOS version {version!r} in unexpected shape; mural "
            "spatial features require GEOS >= 3.11."
        ) from exc
    if (major, minor) < (3, 11):
        raise MuralError(
            f"Detected GEOS {major}.{minor}.{patch}; mural spatial features "
            "require GEOS >= 3.11."
        )
    return (major, minor, patch)


def _ensure_geos_ready() -> None:
    """Run the GEOS version probe at most once per process."""
    global _GEOS_PROBE_DONE
    if _GEOS_PROBE_DONE:
        return
    _GEOS_PROBE_DONE = True
    if os.environ.get("MURAL_SUPPRESS_GEOS_PROBE"):
        return
    _probe_geos_version()


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Loopback redirect URI: register ``http://localhost:8765/callback`` in the
# Mural OAuth app. The local HTTP server still binds to ``127.0.0.1`` (RFC
# 8252 §7.3) but the URI advertised to Mural uses ``localhost`` so the
# Mural portal accepts it (the portal rejects raw IPv4 literals as of 2024).
# Override with MURAL_REDIRECT_URI (validated by ``_validate_redirect_uri``).


# Credential keys recognized by the credential backend abstraction. The
# refresh token is stored persistently per-profile alongside client_id and
# client_secret so keyring-backed deployments can retain authentication
# state across processes without an env file.

# Maximum widgets accepted by ``mural_widget_create_bulk`` in a single call.
# Polling defaults for ``mural_mural_poll``.
# Default scope string used by interactive bootstrap (``auth bootstrap``) and
# the credential probe: the union of read and write scopes a typical first-time
# user needs to exercise read-and-write workflows immediately after setup.
# Back-compat alias: ``DEFAULT_SCOPES`` is the read-only space-separated string
# applied when ``auth login`` runs without ``--write`` and without ``--scopes``.


# Proactive client-side rate limit (Mural enforces ~60 req/min globally; we
# cap at 20 req/sec per process and back off on 429 regardless).

# 429 / transient retry policy.

# Access tokens are refreshed if they expire within this many seconds.

# Serializes 401-driven refreshes so concurrent callers coalesce on a single
# token rotation instead of racing on the token store.


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


# Tag texts that are managed by the CLI and may not be removed without an
# explicit override. The ``authored-by-ai`` tag is auto-attached to every
# widget created by AI-driven flows so downstream consumers can distinguish
# AI-authored objects from human-authored ones.

# Reserved tag text *prefixes* applied by composite/layout flows. Mutating
# these via tag tools requires `force_reserved=True` just like literal
# reserved tags. Kept as a separate registry so prefix membership is cheap.


def _is_reserved_tag_text(text: str) -> bool:
    """Return ``True`` for literal-reserved or reserved-prefix tag texts."""
    if not isinstance(text, str):
        return False
    if text in _RESERVED_TAGS:
        return True
    return any(text.startswith(prefix) for prefix in _RESERVED_TAG_PREFIXES)


# Transport hardening limits. All overridable via env for diagnostic flexibility.

# Spatial query feature flags. Both default off until widget rotation and
# parentId field semantics are verified against the live portal.

# Patterns used by ``_redact``. Matches both JSON shapes and form/header
# shapes so log-line scrubbing works regardless of payload encoding.
# Mural uses Authorization Code + PKCE only, so the OIDC and alternate-grant
# keys below are defense-in-depth: they protect against third-party libraries
# (urllib3, requests) and future code paths that log standard OAuth/OIDC
# payloads using these field names.
_REDACT_PATTERNS.extend(
    [
        # form-style: key=value (until & or whitespace)
        (re.compile(rf"(\b{re.escape(k)}=)([^&\s]+)"), r"\1***")
        for k in (*_REDACT_KEYS, "code")
    ]
)
_REDACT_PATTERNS.append(
    (
        re.compile(r"(?i)(authorization\s*[:=]\s*)(bearer\s+)?(\S+)", re.IGNORECASE),
        r"\1\2***",
    )
)
# Azure Blob SAS query strings (used for image uploads): scrub everything
# after the storage host's `?` so the `sig=` token is not logged.
_REDACT_PATTERNS.append(
    (re.compile(r"(\.blob\.core\.windows\.net/[^\s?]+\?)\S+"), r"\1***")
)

LOGGER = logging.getLogger("mural")

# GEOS probe is deferred to first spatial use via _ensure_geos_ready().


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Step 2.1 — Env-var resolution, token-store I/O, PKCE helpers
# ---------------------------------------------------------------------------


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
        if key not in _seen_relaxed_warn:
            _seen_relaxed_warn.add(key)
            _emit(
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


# ---------------------------------------------------------------------------
# Credential backend abstraction (keyring + file + env-only)
# ---------------------------------------------------------------------------


class _KeyringUnavailable(RuntimeError):
    """Sentinel raised when the keyring backend cannot be reached.

    Wraps ``ImportError``, ``keyring.errors.KeyringError``, and any
    platform-specific failure (headless Linux without D-Bus, locked vault,
    misconfigured ``MURAL_KEYRING_BACKEND`` override). Callers in
    :func:`resolve_backend` catch this sentinel to drive auto-fallback.
    """


class CredentialBackend(Protocol):
    """Protocol for Mural credential storage backends.

    Implementations route credential reads and writes through a uniform
    ``(service, key)`` namespace where ``service`` is the keyring service
    name (e.g. ``"hve-core/mural/{profile}"``) and ``key`` is one of the
    entries in :data:`_KNOWN_CREDENTIAL_KEYS`.
    """

    name: str

    def get(self, service: str, key: str) -> str | None: ...

    def set(self, service: str, key: str, value: str) -> None: ...

    def delete(self, service: str, key: str) -> None: ...


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


class KeyringBackend:
    """Backend that delegates to the OS keychain via the ``keyring`` package.

    Lazy-imports ``keyring`` in ``__init__`` so module load does not pay
    the cost of resolving a platform backend until a keyring lookup is
    requested. Honors ``MURAL_KEYRING_BACKEND`` to override the default
    backend selection (``module.path.ClassName`` form, applied via
    ``keyring.set_keyring``).
    """

    name = "keyring"

    def __init__(self) -> None:
        try:
            import keyring
            from keyring import errors as keyring_errors
        except ImportError as exc:
            raise _KeyringUnavailable(f"keyring package not importable: {exc}") from exc
        override = os.environ.get("MURAL_KEYRING_BACKEND")
        if override:
            try:
                import importlib

                module_path, _, class_name = override.rpartition(".")
                if not module_path or not class_name:
                    raise _KeyringUnavailable(
                        f"MURAL_KEYRING_BACKEND={override!r} must be "
                        "'module.path.ClassName'"
                    )
                module = importlib.import_module(module_path)
                backend_cls = getattr(module, class_name)
                keyring.set_keyring(backend_cls())
            except _KeyringUnavailable:
                raise
            except Exception as exc:
                raise _KeyringUnavailable(
                    f"failed to apply MURAL_KEYRING_BACKEND={override!r}: {exc}"
                ) from exc
        try:
            self.backend_name = keyring.get_keyring().name
        except Exception as exc:
            raise _KeyringUnavailable(
                f"failed to resolve keyring backend: {exc}"
            ) from exc
        self._keyring = keyring
        self._errors = keyring_errors

    def get(self, service: str, key: str) -> str | None:
        try:
            return self._keyring.get_password(service, key)
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc

    def set(self, service: str, key: str, value: str) -> None:
        try:
            self._keyring.set_password(service, key, value)
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc

    def delete(self, service: str, key: str) -> None:
        try:
            self._keyring.delete_password(service, key)
        except self._errors.PasswordDeleteError:
            return  # idempotent: missing entry is success
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc


class FileBackend:
    """Backend that reads and writes a per-profile mode-0600 env file.

    The ``service`` argument is accepted for protocol parity but unused;
    the backing path (resolved by :func:`_resolve_credential_file`) is
    bound at construction time.
    """

    name = "file"

    def __init__(self, path: pathlib.Path) -> None:
        self._path = path

    def _read_all(self) -> dict[str, str]:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        try:
            fd = os.open(str(self._path), flags)
        except FileNotFoundError:
            return {}
        with os.fdopen(fd, "r", encoding="utf-8", errors="strict") as fh:
            text = fh.read()
        result: dict[str, str] = {}
        for line in text.splitlines():
            stripped = line.lstrip()
            if not stripped or stripped.startswith("#"):
                continue
            match = _LINE_RE.match(line)
            if match is None:
                continue
            key = match.group("k")
            value = match.group("v")
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                value = value[1:-1]
            result[key] = value
        return result

    def get(self, service: str, key: str) -> str | None:
        return self._read_all().get(key)

    def set(self, service: str, key: str, value: str) -> None:
        existing = self._read_all()
        existing[key] = value
        self._write_all(existing)

    def delete(self, service: str, key: str) -> None:
        if not self._path.exists():
            return
        _check_credential_file_perms(self._path, os.environ)
        existing = self._read_all()
        if key not in existing:
            return
        existing.pop(key)
        if existing:
            self._write_all(existing)
        else:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(self._path)

    def _write_all(self, entries: dict[str, str]) -> None:
        # Mirrors _cmd_auth_bootstrap: 0o077 umask + O_EXCL temp + os.replace.
        body_lines = [
            "# Mural credentials (managed by FileBackend).",
            "# File mode MUST be 0600. Override only via MURAL_ENV_FILE_RELAXED=1.",
        ]
        for k in sorted(entries):
            body_lines.append(f"{k}={entries[k]}")
        body = ("\n".join(body_lines) + "\n").encode("utf-8")
        self._path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self._path.with_name(f"{self._path.name}.{os.getpid()}.tmp")
        prev_umask = os.umask(0o077)
        try:
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_TRUNC
            fd = os.open(str(tmp), flags, 0o600)
            try:
                with os.fdopen(fd, "wb") as fh:
                    fh.write(body)
            except BaseException:
                with contextlib.suppress(OSError):
                    os.close(fd)
                raise
            os.replace(tmp, self._path)
            with contextlib.suppress(OSError):
                os.chmod(self._path, 0o600)
        finally:
            os.umask(prev_umask)
            with contextlib.suppress(FileNotFoundError):
                tmp.unlink()


# Module-level dedup sets enforce one-WARN-per-process semantics across
# repeated resolve_backend calls within the same Python process.
_seen_fallback_warn: set[str] = set()
_seen_concurrent_warn: set[tuple[str, str]] = set()
# Tracks credential paths that already emitted the relaxed-mode WARN.
_seen_relaxed_warn: set[str] = set()
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
        backend = KeyringBackend()
    except _KeyringUnavailable as exc:
        _keyring_probe_cache = (False, None, str(exc))
        return _keyring_probe_cache
    _keyring_probe_cache = (True, getattr(backend, "backend_name", None), None)
    return _keyring_probe_cache


def resolve_backend(profile: str = "default") -> CredentialBackend:
    """Return the credential backend for ``profile`` honoring env overrides.

    ``MURAL_CREDENTIAL_BACKEND`` selects the backend (``auto`` default,
    ``keyring``, ``file``, ``env-only``). On ``auto``, KeyringBackend is
    tried first and falls back to FileBackend when ``_KeyringUnavailable``
    is raised; a one-shot WARN per profile records the fallback. After
    backend selection (skipped for env-only), a probe checks whether the
    other persistent backend also holds non-empty values and emits a
    second one-shot WARN per ``(profile, selected_backend)`` pair when so.
    The probe never raises and never affects the returned backend.
    """
    selector = os.environ.get("MURAL_CREDENTIAL_BACKEND", "auto").lower()
    file_path = _resolve_credential_file(profile, os.environ)
    selected: CredentialBackend
    if selector == "env-only":
        return _NullBackend()
    if selector == "file":
        selected = FileBackend(file_path)
    elif selector == "keyring":
        selected = KeyringBackend()  # let _KeyringUnavailable propagate
    elif selector == "auto":
        try:
            selected = KeyringBackend()
        except _KeyringUnavailable as exc:
            if profile not in _seen_fallback_warn:
                _seen_fallback_warn.add(profile)
                _emit(
                    f"keyring backend unavailable for profile {profile!r} "
                    f"({exc}); falling back to file backend at {file_path}",
                    level=logging.WARNING,
                )
            selected = FileBackend(file_path)
    else:
        raise MuralError(
            f"MURAL_CREDENTIAL_BACKEND={selector!r} is not one of "
            "'auto', 'keyring', 'file', 'env-only'"
        )
    _maybe_warn_concurrent_state(profile, selected, file_path)
    return selected


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
    if dedup_key in _seen_concurrent_warn:
        return
    keyring_populated = False
    file_populated = False
    service = _service_name_for(profile)
    try:
        probe_keyring = KeyringBackend()
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
            entries = FileBackend(file_path)._read_all()
            file_populated = any(entries.get(k) for k in _KNOWN_CREDENTIAL_KEYS)
    except Exception:  # noqa: BLE001 - probe must never raise
        file_populated = False
    if keyring_populated and file_populated:
        _seen_concurrent_warn.add(dedup_key)
        _emit(
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
        backend = resolve_backend(profile_name)
    except MuralError:
        return None
    if isinstance(backend, _NullBackend):
        return None
    service = _service_name_for(profile_name)
    if isinstance(backend, FileBackend) and backend._path.exists():
        # Preserve the historic mode-0600 enforcement that the legacy
        # autoload performed before reading.
        _check_credential_file_perms(backend._path, env)
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
    if isinstance(backend, FileBackend) and loaded_any:
        return backend._path
    return None


# ---------------------------------------------------------------------------
# Token-store schema v2: cross-process lock, profile envelope, migration
# ---------------------------------------------------------------------------


# Profile names: 1-32 chars, leading alphanumeric or underscore, then
# alphanumeric / underscore / dot / hyphen. Rejects "..", path separators,
# whitespace, and empty strings.

# Required keys on every persisted profile after migration.


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
    _validate_profile_name(name)
    profiles = store.get("profiles") if isinstance(store, dict) else None
    if not isinstance(profiles, dict) or name not in profiles:
        raise MuralError(f"profile {name!r} not found in token store")
    profile = profiles[name]
    _validate_profile(profile)
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
    return _validate_profile_name(candidate)


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
            _emit(
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


def _load_token_store_locked(path: pathlib.Path) -> dict[str, Any] | None:
    """Load and validate a token store while the caller holds the lock.

    On a v1 (pre-schema_version) record, transparently migrates to v2 and
    rewrites the file in place under the same lock. On a v2 envelope,
    validates ``schema_version == 2`` and every contained profile. Returns
    ``None`` when the store file is absent.
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise MuralError(f"cannot read token store at {path}: {exc}") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise MuralError(f"token store at {path} is not valid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise MuralError(f"token store at {path} is not a JSON object")
    if "schema_version" not in data:
        migrated = _migrate_v1_to_v2(data)
        _save_token_store_locked(path, migrated)
        data = migrated
    if data.get("schema_version") != TOKEN_STORE_SCHEMA_VERSION:
        raise MuralError(
            f"token store at {path} has unsupported schema_version "
            f"{data.get('schema_version')!r}"
        )
    profiles = data.get("profiles")
    if not isinstance(profiles, dict):
        raise MuralError(f"token store at {path} is missing a 'profiles' object")
    for name, profile in profiles.items():
        _validate_profile_name(name)
        _validate_profile(profile)
    return data


def _load_token_store(path: pathlib.Path) -> dict[str, Any] | None:
    """Load a token store from disk under a cross-process lock."""
    with _acquire_cache_lock(path):
        return _load_token_store_locked(path)


@contextlib.contextmanager
def _token_store_session(path: pathlib.Path):
    """Yield ``(envelope, commit)`` while holding the token store lock.

    Closes the IV-001 read/modify/write TOCTOU window: load and save share a
    single ``_acquire_cache_lock`` acquisition. ``envelope`` is the loaded
    store (or ``None`` when absent). ``commit(new_envelope)`` writes
    atomically via :func:`_save_token_store_locked` under the held lock.
    """
    with _acquire_cache_lock(path):
        envelope = _load_token_store_locked(path)

        def commit(new_envelope: dict[str, Any]) -> None:
            _save_token_store_locked(path, new_envelope)

        yield envelope, commit


def _save_token_store_locked(path: pathlib.Path, data: dict[str, Any]) -> None:
    """Write ``data`` atomically with mode 0600. Caller already holds the lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2, sort_keys=True).encode("utf-8")
    tmp = path.with_name(f"{path.name}.{os.getpid()}.{threading.get_ident()}.tmp")
    prev_umask = os.umask(0o077)
    try:
        # ``O_EXCL`` rejects a stale temp from a crashed peer rather than
        # silently overwriting it, defending the atomic-replace invariant.
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_TRUNC
        fd = os.open(str(tmp), flags, 0o600)
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(payload)
        except BaseException:
            with contextlib.suppress(OSError):
                os.close(fd)
            raise
        os.replace(tmp, path)
        with contextlib.suppress(OSError):
            os.chmod(path, 0o600)
    finally:
        os.umask(prev_umask)
        with contextlib.suppress(FileNotFoundError):
            tmp.unlink()


def _save_token_store(path: pathlib.Path, data: dict[str, Any]) -> None:
    """Persist a token store atomically with mode 0600 under a cross-process lock."""
    with _acquire_cache_lock(path):
        _save_token_store_locked(path, data)


def _b64url_nopad(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _token_granted_scopes(
    store: dict[str, Any] | None,
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> tuple[str, ...]:
    """Return the scopes granted to the named profile in a v2 envelope.

    Returns an empty tuple when ``store`` is empty, the profile is missing,
    or ``granted_scopes`` is absent or malformed. Mural's ``/token`` endpoint
    does not return ``scope`` (RFC 6749 §5.1 permits this; per §3.3 the
    granted scope equals the requested scope when omitted), so the canonical
    record is the ``granted_scopes`` list captured at authorization time.
    """
    if not store:
        return ()
    try:
        profile = _select_profile(store, profile_name)
    except MuralError:
        return ()
    granted = profile.get("granted_scopes")
    if isinstance(granted, list) and all(isinstance(s, str) for s in granted):
        return tuple(granted)
    return ()


def _require_scope(
    scope: "str | Sequence[str]",
    *,
    store: dict[str, Any] | None = None,
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> None:
    """Raise :class:`MuralAuthScopeError` when ``scope`` is not in the granted
    set of the named profile.

    ``scope`` may be a single string or a sequence of strings; in the
    sequence form every entry must be granted (logical AND). Templates and
    composite tools pass their required scopes directly.
    """
    if store is None:
        store = _load_token_store(_resolve_token_store_path())
    granted = _token_granted_scopes(store, profile_name)
    needed = (scope,) if isinstance(scope, str) else tuple(scope)
    for s in needed:
        if s not in granted:
            raise MuralAuthScopeError(s, granted)


def _generate_pkce_pair() -> tuple[str, str]:
    """Return ``(verifier, challenge)`` for the PKCE S256 method."""
    verifier = secrets.token_urlsafe(64)
    challenge = _b64url_nopad(hashlib.sha256(verifier.encode("ascii")).digest())
    return verifier, challenge


def _verify_pkce(verifier: str, challenge: str) -> bool:
    """Return ``True`` when ``challenge`` is the S256 digest of ``verifier``."""
    try:
        verifier_bytes = verifier.encode("ascii")
        challenge_bytes = challenge.encode("ascii")
    except UnicodeEncodeError:
        # PKCE values are ASCII per RFC 7636; non-ASCII input cannot match.
        return False
    expected = _b64url_nopad(hashlib.sha256(verifier_bytes).digest()).encode("ascii")
    # Constant-time comparison to mirror what the auth server does.
    return secrets.compare_digest(expected, challenge_bytes)


# ---------------------------------------------------------------------------
# Step 2.2 — Transport: redact, token bucket, refresh, _authenticated_request
# ---------------------------------------------------------------------------


def _redact(text: str) -> str:
    """Scrub token-shaped substrings from ``text`` before logging."""
    if not text:
        return text
    redacted = text
    for pattern, replacement in _REDACT_PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


@dataclass
class _TokenBucket:
    """Simple token-bucket throttle, instantiated per-process."""

    capacity: float = RATE_LIMIT_BUCKET_CAPACITY
    tokens_per_sec: float = RATE_LIMIT_TOKENS_PER_SEC
    tokens: float = RATE_LIMIT_BUCKET_CAPACITY
    last_refill: float = 0.0
    lock: threading.Lock = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        self.lock = threading.Lock()
        self.last_refill = time.monotonic()


_RATE_BUCKET = _TokenBucket()


def _token_bucket_acquire(
    *,
    bucket: _TokenBucket | None = None,
    now: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Block until one token is available in the bucket."""
    bucket = bucket or _RATE_BUCKET
    while True:
        with bucket.lock:
            current = now()
            elapsed = max(0.0, current - bucket.last_refill)
            bucket.tokens = min(
                bucket.capacity,
                bucket.tokens + elapsed * bucket.tokens_per_sec,
            )
            bucket.last_refill = current
            if bucket.tokens >= 1.0:
                bucket.tokens -= 1.0
                return
            deficit = 1.0 - bucket.tokens
            wait = deficit / bucket.tokens_per_sec if bucket.tokens_per_sec else 0.05
        sleep(max(wait, 0.001))


def _parse_rate_limit_headers(
    headers: Any,
    *,
    bucket: _TokenBucket | None = None,
    now: Callable[[], float] = time.monotonic,
) -> dict[str, int | None]:
    """Parse ``X-RateLimit-*`` headers and tighten the local bucket if needed."""
    bucket = bucket or _RATE_BUCKET

    def _header(name: str) -> str | None:
        # urllib's HTTPMessage and plain dicts both expose ``get``.
        getter = getattr(headers, "get", None)
        if getter is None:
            return None
        value = getter(name)
        if value is None:
            value = getter(name.lower())
        return value

    def _to_int(value: str | None) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    remaining = _to_int(_header("X-RateLimit-Remaining"))
    reset = _to_int(_header("X-RateLimit-Reset"))

    if remaining is not None and remaining <= 0 and reset is not None:
        # Drain the bucket; the next acquire will sleep until refill.
        with bucket.lock:
            bucket.tokens = 0.0
            bucket.last_refill = now()
    return {"remaining": remaining, "reset": reset}


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Redirect handler that refuses redirects on the OAuth token endpoint."""

    def _block(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
    ) -> Any:
        location = headers.get("Location", "<unknown>") if headers else "<unknown>"
        raise MuralAPIError(
            code,
            "TOKEN_REDIRECT",
            f"token endpoint attempted redirect to {location}",
        )

    http_error_301 = _block
    http_error_302 = _block
    http_error_303 = _block
    http_error_307 = _block
    http_error_308 = _block


_TOKEN_OPENER = urllib.request.build_opener(_NoRedirect())


def _parse_token_response(resp: Any) -> dict[str, Any]:
    """Validate token endpoint Content-Type, read capped body, return parsed dict."""
    status = getattr(resp, "status", 200)
    headers = getattr(resp, "headers", None)
    content_type = ""
    if headers is not None:
        try:
            content_type = headers.get("Content-Type", "") or ""
        except AttributeError:
            content_type = ""
    if not content_type.lower().startswith("application/json"):
        raise MuralAPIError(
            status,
            "TOKEN_BAD_CONTENT_TYPE",
            f"token endpoint returned non-JSON Content-Type: {content_type}",
        )
    body_bytes = _read_capped(resp, MURAL_MAX_BODY_BYTES)
    text = body_bytes.decode("utf-8", errors="replace")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise MuralAPIError(status, "TOKEN_INVALID_JSON", text) from exc
    if not isinstance(data, dict):
        raise MuralAPIError(
            status,
            "TOKEN_INVALID_PAYLOAD",
            "token endpoint returned non-object JSON body",
        )
    return data


def _refresh_access_token(
    refresh_token: str,
    *,
    client_id: str,
    client_secret: str | None = None,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = _TOKEN_OPENER.open,
) -> dict[str, Any]:
    """Exchange a refresh token for a new access token."""
    body: dict[str, str] = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": client_id,
    }
    if client_secret:
        body["client_secret"] = client_secret
    encoded = urllib.parse.urlencode(body).encode("ascii")
    request = urllib.request.Request(
        token_url,
        data=encoded,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    LOGGER.debug("POST %s", _redact(token_url))
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            data = _parse_token_response(resp)
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        text = _read_response_body(exc).decode("utf-8", errors="replace")
        _emit(f"refresh failed: HTTP {exc.code} {text}", level=logging.ERROR)
        raise MuralAPIError(
            exc.code, "REFRESH_FAILED", text or "refresh failed"
        ) from exc
    if status >= 400:
        raise MuralAPIError(status, "REFRESH_FAILED", json.dumps(data))
    if "access_token" not in data:
        raise MuralAPIError(status, "REFRESH_INVALID_PAYLOAD", "missing access_token")
    return data


def _emit(message: str, *, level: int = logging.INFO) -> None:
    """Write a redacted message to stderr and the module logger."""
    redacted = _redact(message)
    LOGGER.log(level, redacted)
    if level >= logging.ERROR or not _CLI_QUIET:
        print(redacted, file=sys.stderr)


def _emit_debug_traceback(exc: BaseException) -> None:
    """Write a redacted traceback to stderr when ``MURAL_DEBUG`` is set.

    Routes the formatted traceback through :func:`_redact` so OAuth state,
    tokens, and ``Authorization`` headers cannot leak via an unexpected
    exception bubbling out of :func:`main`.
    """
    if not os.environ.get("MURAL_DEBUG"):
        return
    formatted = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    print(_redact(formatted), file=sys.stderr)


def _color_mode(cli_choice: str | None) -> bool:
    """Resolve effective color output for CLI streams.

    Precedence: explicit ``--color always|never`` overrides; else honour
    ``NO_COLOR`` (any non-empty value disables); else honour ``FORCE_COLOR``
    (any non-empty value enables); else default to ``stderr.isatty()``.
    """
    if cli_choice == "always":
        return True
    if cli_choice == "never":
        return False
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    try:
        return bool(sys.stderr.isatty())
    except (AttributeError, ValueError):
        return False


_CLI_QUIET: bool = False
_CLI_FORCE_JSON: bool = False
_CLI_COLOR: bool = False
_CLI_PROFILE: str | None = None


def _install_signal_handlers() -> None:
    """Register POSIX signal handlers for SIGINT (130) and SIGPIPE (141).

    Idempotent: safe to call multiple times. SIGPIPE is a no-op on platforms
    that don't define it (e.g. Windows).
    """

    def _on_sigint(_signum: int, _frame: Any) -> None:  # pragma: no cover - thin
        sys.exit(130)

    def _on_sigpipe(_signum: int, _frame: Any) -> None:  # pragma: no cover - thin
        sys.exit(141)

    with contextlib.suppress(ValueError, OSError):
        signal.signal(signal.SIGINT, _on_sigint)
    if hasattr(signal, "SIGPIPE"):
        with contextlib.suppress(ValueError, OSError):
            signal.signal(signal.SIGPIPE, _on_sigpipe)


def _apply_refresh(
    store: dict[str, Any],
    *,
    client_id: str,
    client_secret: str | None,
    token_url: str,
    _http: Callable[..., Any],
    _now: Callable[[], float],
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> dict[str, Any]:
    """Refresh ``profile_name`` inside a v2 envelope and return a new envelope."""
    profile = _select_profile(store, profile_name)
    refresh_token = profile.get("refresh_token")
    if not refresh_token:
        raise MuralError(
            "token store has no refresh_token; run `python -m mural auth login`"
        )
    fresh = _refresh_access_token(
        refresh_token,
        client_id=client_id,
        client_secret=client_secret,
        token_url=token_url,
        _http=_http,
    )
    expires_in = int(fresh.get("expires_in", 0) or 0)
    new_profile = dict(profile)
    new_profile["access_token"] = fresh["access_token"]
    if "refresh_token" in fresh and fresh["refresh_token"]:
        new_profile["refresh_token"] = fresh["refresh_token"]
    new_profile["expires_at"] = _compute_expires_at(_now(), expires_in)
    new_store = dict(store)
    new_profiles = dict(store.get("profiles") or {})
    new_profiles[profile_name] = new_profile
    new_store["profiles"] = new_profiles
    return new_store


def _coalesced_refresh(
    store_path: pathlib.Path,
    observed_access_token: str,
    *,
    client_id: str,
    client_secret: str | None,
    token_url: str,
    _http: Callable[..., Any],
    _now: Callable[[], float],
    profile_name: str,
) -> dict[str, Any]:
    """Run a token refresh under both in-process and cross-process locks.

    Holds :data:`_REFRESH_LOCK` to coalesce threads, and ``_token_store_session``
    to coalesce peer processes. Re-reads the token store inside the locks; if a
    peer (thread or process) already rotated the access token, returns the
    peer's store without contacting the token endpoint. Otherwise calls
    :func:`_apply_refresh`, persists, and returns the new store.
    """
    with _REFRESH_LOCK:
        with _token_store_session(store_path) as (envelope, commit):
            store = envelope or {}
            profile = _select_profile(store, profile_name)
            if profile.get("access_token") != observed_access_token:
                return store
            store = _apply_refresh(
                store,
                client_id=client_id,
                client_secret=client_secret,
                token_url=token_url,
                _http=_http,
                _now=_now,
                profile_name=profile_name,
            )
            commit(store)
            return store


def _read_capped(stream: Any, limit: int) -> bytes:
    """Read bytes from ``stream`` up to ``limit`` and raise on overflow.

    Caps unbounded ``urllib`` response bodies so a hostile or misbehaving
    server cannot exhaust process memory. Reads ``limit + 1`` bytes; if the
    stream still has data, the response is rejected with ``ResponseTooLarge``.
    """
    chunk = stream.read(limit + 1)
    if chunk is None:
        return b""
    if len(chunk) > limit:
        raise ResponseTooLarge(f"response body exceeds {limit} bytes")
    return chunk


def _read_response_body(resp_or_err: Any) -> bytes:
    """Read a urllib response or :class:`HTTPError` body with the standard cap.

    Mirrors :func:`_read_capped` semantics but tolerates :class:`HTTPError`
    instances whose ``fp`` is ``None`` (returns ``b""``). Caps total bytes at
    :data:`MURAL_MAX_BODY_BYTES` so a hostile or misbehaving server cannot
    exhaust process memory via either a successful or error response body.
    """
    if getattr(resp_or_err, "fp", resp_or_err) is None:
        return b""
    try:
        return _read_capped(resp_or_err, MURAL_MAX_BODY_BYTES)
    except ResponseTooLarge:
        raise
    except Exception:  # pragma: no cover - defensive
        return b""


def _authenticated_request(
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    json_body: Any | None = None,
    token_store_path: pathlib.Path | None = None,
    base_url: str | None = None,
    env: dict[str, str] | None = None,
    profile: str | None = None,
    _now: Callable[[], float] = time.time,
    _http: Callable[..., Any] = urllib.request.urlopen,
    _sleep: Callable[[float], None] = time.sleep,
    _bucket: _TokenBucket | None = None,
) -> Any | None:
    """Perform an authenticated request with refresh, retry, and backoff."""
    src = env if env is not None else os.environ
    base = base_url or src.get(ENV_BASE_URL) or MURAL_BASE_URL_DEFAULT
    client_id = src.get(ENV_CLIENT_ID)
    if not client_id:
        raise MuralError(f"{ENV_CLIENT_ID} is not set")
    client_secret = src.get(ENV_CLIENT_SECRET) or None

    store_path = token_store_path or _resolve_token_store_path(env=src)
    store = _load_token_store(store_path)
    if not store:
        raise MuralError(
            f"no token store at {store_path}; run `python -m mural auth login` first"
        )
    profile_name = _resolve_active_profile(
        store, src, profile if profile is not None else _CLI_PROFILE
    )
    profile_data = _select_profile(store, profile_name)
    profile_client_id = profile_data.get("client_id")
    if profile_client_id and profile_client_id != client_id:
        raise MuralSecurityError(
            f"profile {profile_name!r} was issued for a different client_id; "
            f"run `python -m mural auth login` to refresh"
        )

    expires_at = int(profile_data.get("expires_at") or 0)
    if expires_at - REFRESH_LEEWAY_SECONDS <= _now() and profile_data.get(
        "refresh_token"
    ):
        store = _coalesced_refresh(
            store_path,
            profile_data.get("access_token", ""),
            client_id=client_id,
            client_secret=client_secret,
            token_url=src.get("MURAL_TOKEN_URL", MURAL_TOKEN_URL),
            _http=_http,
            _now=_now,
            profile_name=profile_name,
        )
        profile_data = _select_profile(store, profile_name)

    url = _join_url(base, path, params)
    encoded: bytes | None = None
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    if json_body is not None:
        encoded = json.dumps(json_body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    refreshed_due_to_401 = False
    attempt = 0
    while True:
        _token_bucket_acquire(bucket=_bucket, now=time.monotonic, sleep=_sleep)
        request_headers = dict(headers)
        request_headers["Authorization"] = f"Bearer {profile_data['access_token']}"
        request = urllib.request.Request(
            url,
            data=encoded,
            method=method.upper(),
            headers=request_headers,
        )
        LOGGER.debug("%s %s", method.upper(), _redact(url))
        try:
            with _http(request) as resp:  # type: ignore[arg-type]
                status = getattr(resp, "status", 200)
                body_bytes = _read_capped(resp, MURAL_MAX_BODY_BYTES)
                _parse_rate_limit_headers(resp.headers, bucket=_bucket)
                return _decode_body(status, body_bytes)
        except urllib.error.HTTPError as exc:
            status = exc.code
            body_bytes = _read_response_body(exc)
            headers_obj = getattr(exc, "headers", None)
            if headers_obj is not None:
                _parse_rate_limit_headers(headers_obj, bucket=_bucket)

            if status == 401 and not refreshed_due_to_401:
                refreshed_due_to_401 = True
                _emit("access token rejected; forcing refresh", level=logging.INFO)
                store = _coalesced_refresh(
                    store_path,
                    profile_data["access_token"],
                    client_id=client_id,
                    client_secret=client_secret,
                    token_url=src.get("MURAL_TOKEN_URL", MURAL_TOKEN_URL),
                    _http=_http,
                    _now=_now,
                    profile_name=profile_name,
                )
                profile_data = _select_profile(store, profile_name)
                continue

            if status == 429 or 500 <= status < 600:
                if attempt >= MAX_RETRIES:
                    raise _build_api_error(status, body_bytes, headers_obj) from exc
                wait = _backoff_seconds(headers_obj, attempt)
                _emit(
                    f"HTTP {status}; retrying in {wait:.2f}s "
                    f"(attempt {attempt + 1}/{MAX_RETRIES})",
                    level=logging.WARNING,
                )
                _sleep(wait)
                attempt += 1
                continue

            raise _build_api_error(status, body_bytes, headers_obj) from exc
        except urllib.error.URLError as exc:
            if attempt >= MAX_RETRIES:
                raise MuralError(f"network error contacting {url}: {exc}") from exc
            wait = min(MAX_BACKOFF_SECONDS, 2**attempt)
            _emit(
                f"network error: {exc}; retrying in {wait:.2f}s "
                f"(attempt {attempt + 1}/{MAX_RETRIES})",
                level=logging.WARNING,
            )
            _sleep(wait)
            attempt += 1
            continue


def _join_url(base: str, path: str, params: dict[str, Any] | None) -> str:
    if path.startswith(("http://", "https://")):
        url = path
    else:
        url = base.rstrip("/") + "/" + path.lstrip("/")
    if params:
        flat = {k: v for k, v in params.items() if v is not None}
        if flat:
            url = f"{url}?{urllib.parse.urlencode(flat, doseq=True)}"
    return url


def _decode_body(status: int, body_bytes: bytes) -> Any | None:
    if status == 204 or not body_bytes:
        return None
    try:
        return json.loads(body_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return body_bytes.decode("utf-8", errors="replace")


def _extract_error_payload(
    body_bytes: bytes,
    headers_obj: Any,
) -> tuple[str | None, str | None, str | None]:
    """Decode a Mural error response into ``(code, message, request_id)``.

    ``request_id`` falls back to the ``X-Request-Id`` header when the body
    omits it.  This helper exists as a discrete fuzzable seam so error
    extraction logic can be exercised without issuing real HTTP calls.
    """
    code: str | None = None
    message: str | None = None
    request_id: str | None = None
    if headers_obj is not None:
        getter = getattr(headers_obj, "get", None)
        if callable(getter):
            request_id = getter("X-Request-Id") or getter("x-request-id")
    if body_bytes:
        try:
            payload = json.loads(body_bytes.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            payload = None
        if isinstance(payload, dict):
            raw_code = payload.get("code")
            code = str(raw_code) if raw_code is not None else None
            raw_message = payload.get("message") or payload.get("error")
            message = str(raw_message) if raw_message else None
        if message is None:
            message = body_bytes.decode("utf-8", errors="replace")
    return code, message, request_id


def _build_api_error(status: int, body_bytes: bytes, headers_obj: Any) -> MuralAPIError:
    code, message, request_id = _extract_error_payload(body_bytes, headers_obj)
    if not message:
        message = f"HTTP {status}"
    return MuralAPIError(status, code, message, request_id)


def _backoff_seconds(headers_obj: Any, attempt: int) -> float:
    retry_after: float | None = None
    if headers_obj is not None:
        getter = getattr(headers_obj, "get", None)
        if callable(getter):
            raw = getter("Retry-After") or getter("retry-after")
            if raw is not None:
                try:
                    retry_after = float(raw)
                except (TypeError, ValueError):
                    retry_after = None
    if retry_after is None:
        retry_after = float(min(MAX_BACKOFF_SECONDS, 2**attempt))
    return min(MAX_BACKOFF_SECONDS, max(0.0, retry_after))


# ---------------------------------------------------------------------------
# Step 2.3 — Loopback OAuth login flow
# ---------------------------------------------------------------------------
# Carved into ``_oauth`` for testability and module size.  Re-imported here
# so the package surface (and ``mural.<symbol>`` test access) is unchanged.
# PKCE primitives (``_generate_pkce_pair``/``_verify_pkce``) remain above so
# that ``_oauth`` can import them at module-load time without a cycle on the
# transport helpers it also depends on (``_TOKEN_OPENER`` etc.).

from ._oauth import (  # noqa: E402,F401
    _build_authorize_url,
    _CallbackResult,
    _exchange_authorization_code,
    _LoopbackHandler,
    _LoopbackServer,
    _probe_client_credentials,
    _resolve_redirect_uri,
    _run_login,
    _start_loopback_server,
    _validate_redirect_uri,
)

# ---------------------------------------------------------------------------
# Step 3 — Validation, projection, pagination, asset upload helpers
# ---------------------------------------------------------------------------
# Carved into ``_validation`` for testability and module size.  Re-imported
# here so the package surface (and ``mural.<symbol>`` test access) is
# unchanged.
from ._validation import (  # noqa: E402,F401
    _ALLOWED_HYPERLINK_SCHEMES,
    _AZURE_BLOB_HOST_SUFFIX,
    _DEFAULT_PAGE_SIZE,
    _IMAGE_CONTENT_TYPES,
    _MAX_CURSOR_BYTES,
    _MAX_HYPERLINK_LEN,
    _MAX_PAGE_SIZE,
    _MAX_TAG_TEXT_LEN,
    _MURAL_ID_RE,
    _VALID_AREA_LAYOUTS,
    _area_cache,
    _build_area_body,
    _build_arrow_body,
    _build_image_body,
    _build_shape_body,
    _build_sticky_note_body,
    _build_textbox_body,
    _coerce_xy,
    _extract_field,
    _format_output,
    _paginate,
    _parse_json_arg,
    _parse_pagination_cursor,
    _project_record,
    _resolve_workspace_id,
    _unwrap_value_envelope,
    _validate_area_layout,
    _validate_asset_url,
    _validate_hyperlink,
    _validate_mural_id,
    _validate_tag_text,
)


def _create_asset_url(
    mural_id: str,
    file_extension: str,
    **request_kwargs: Any,
) -> dict[str, Any]:
    """Call ``POST /murals/{id}/assets`` and return the ``value`` payload."""
    if not file_extension:
        raise MuralValidationError("file_extension is required to create an asset url")
    ext = file_extension.lstrip(".").lower()
    response = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/assets",
        json_body={"fileExtension": ext},
        **request_kwargs,
    )
    if not isinstance(response, dict):
        raise MuralAPIError(0, "ASSET_URL_INVALID", "asset response is not an object")
    value = (
        response.get("value") if isinstance(response.get("value"), dict) else response
    )
    if not isinstance(value, dict) or "url" not in value or "name" not in value:
        raise MuralAPIError(0, "ASSET_URL_INVALID", "asset response missing url/name")
    return value


def _upload_to_sas(
    *,
    url: str,
    headers: dict[str, str],
    body: bytes,
    content_type: str,
    _http: Callable[..., Any] = urllib.request.urlopen,
) -> None:
    """PUT ``body`` to the Azure SAS ``url`` after validating it.

    ``headers`` is the dictionary returned by Mural's ``POST /assets`` call
    and must include ``x-ms-blob-type: BlockBlob``.  No Mural Bearer token is
    sent on this request.
    """
    _validate_asset_url(url)
    request_headers: dict[str, str] = {
        "Content-Type": content_type,
        "Content-Length": str(len(body)),
        "User-Agent": USER_AGENT,
    }
    for key, value in (headers or {}).items():
        if key.lower() == "authorization":
            continue
        request_headers[key] = value
    if request_headers.get("x-ms-blob-type", "").lower() != "blockblob":
        request_headers["x-ms-blob-type"] = "BlockBlob"
    request = urllib.request.Request(
        url,
        data=body,
        method="PUT",
        headers=request_headers,
    )
    LOGGER.debug("PUT %s", _redact(url))
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            status = getattr(resp, "status", 200)
            if status >= 400:
                payload = _read_response_body(resp).decode("utf-8", errors="replace")
                raise MuralAPIError(status, "ASSET_UPLOAD_FAILED", payload)
    except urllib.error.HTTPError as exc:
        text = _read_response_body(exc).decode("utf-8", errors="replace")
        raise MuralAPIError(
            exc.code, "ASSET_UPLOAD_FAILED", text or "upload failed"
        ) from exc
    except urllib.error.URLError as exc:
        raise MuralError(f"network error uploading to asset url: {exc}") from exc


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _cmd_auth_login(args: argparse.Namespace) -> int:
    _emit("mural auth login", level=logging.INFO)
    if not os.environ.get(ENV_CLIENT_ID):
        diag_profile = (
            getattr(args, "profile", None)
            or os.environ.get(ENV_PROFILE)
            or DEFAULT_PROFILE_NAME
        )
        cred_path = _resolve_credential_file(diag_profile, os.environ)
        cred_exists = "yes" if cred_path.exists() else "no"
        _emit(
            "\n".join(
                [
                    f"{ENV_CLIENT_ID} is not set.",
                    "",
                    "Looked for credentials in this order:",
                    f"  1. Process environment ({ENV_CLIENT_ID}, {ENV_CLIENT_SECRET})",
                    "  2. Active credential backend "
                    "(MURAL_CREDENTIAL_BACKEND={auto|keyring|file|env-only})",
                    f"  3. Credential file: {cred_path}  (exists: {cred_exists})",
                    "",
                    "Run `mural auth bootstrap` to store Mural app"
                    " credentials interactively,",
                    f"or set {ENV_CLIENT_ID} and {ENV_CLIENT_SECRET} in your"
                    " environment.",
                ]
            ),
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    try:
        profile_name = _validate_profile_name(
            getattr(args, "profile", None) or DEFAULT_PROFILE_NAME
        )
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    force = bool(getattr(args, "force", False))
    service = _service_name_for(profile_name)
    try:
        backend = resolve_backend(profile_name)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_FAILURE
    existing: dict[str, str] = {}
    try:
        for key in _KNOWN_CREDENTIAL_KEYS:
            value = backend.get(service, key)
            if value:
                existing[key] = value
    except _KeyringUnavailable:
        existing = {}
    refresh_present = False
    try:
        store = _load_token_store(_resolve_token_store_path())
        if isinstance(store, dict):
            profiles = store.get("profiles")
            if isinstance(profiles, dict):
                profile_record = profiles.get(profile_name)
                if isinstance(profile_record, dict):
                    refresh_present = bool(profile_record.get("refresh_token"))
    except Exception:  # noqa: BLE001 - probe must never raise
        refresh_present = False
    if (existing or refresh_present) and not force:
        _emit(
            f"profile {profile_name!r} already has stored credentials; "
            "rerun with --force to overwrite",
            level=logging.INFO,
        )
        return EXIT_SUCCESS
    # Scope resolution precedence:
    #   1. ``--scopes`` (explicit CLI flag).
    #   2. ``MURAL_SCOPES`` env var (split on whitespace or commas).
    #   3. ``READ_SCOPES + WRITE_SCOPES`` when ``--write`` is set.
    #   4. ``READ_SCOPES`` (fallback).
    # Step 2 wins over Step 3 so that operators can scope-down a write-capable
    # login via env without removing ``--write`` from automation. An empty or
    # whitespace-only ``MURAL_SCOPES`` value is rejected to prevent a silent
    # downgrade to the default scope set.
    env_scopes = os.environ.get(ENV_SCOPES)
    scope_source: str
    if args.scopes:
        granted = tuple(args.scopes.split())
        scopes = " ".join(granted)
        scope_source = "--scopes"
    elif env_scopes is not None:
        if not env_scopes.strip():
            try:
                raise MuralValidationError(
                    "INVALID_SCOPES: "
                    + ENV_SCOPES
                    + " is set but contains no scope tokens"
                )
            except MuralError as exc:
                _emit(str(exc), level=logging.ERROR)
                return EXIT_USAGE
        granted = tuple(
            token for token in re.split(r"[\s,]+", env_scopes.strip()) if token
        )
        scopes = " ".join(granted)
        scope_source = ENV_SCOPES
    elif args.write:
        granted = READ_SCOPES + WRITE_SCOPES
        scopes = " ".join(granted)
        scope_source = "--write"
    else:
        granted = READ_SCOPES
        scopes = None
        scope_source = "default"
    _emit(
        f"requesting OAuth scopes ({scope_source}): {' '.join(granted)}",
        level=logging.INFO,
    )
    try:
        record = _run_login(scopes=scopes, timeout_seconds=args.timeout)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_FAILURE
    record["granted_scopes"] = list(granted)
    # Bind the profile to the client_id used during the OAuth flow so
    # ``_authenticated_request`` can detect cross-client reuse on subsequent
    # invocations (Step 3.6 client_id mismatch check).
    client_id = os.environ.get(ENV_CLIENT_ID)
    record["client_id"] = client_id
    path = _resolve_token_store_path()
    # Login is the recovery path for a corrupt or incompatible store, so a
    # load failure here is downgraded to "start fresh" rather than blocking
    # the user from re-authenticating. The recovery write happens in its own
    # lock acquisition; the happy path uses ``_token_store_session`` to close
    # the read/modify/write TOCTOU window (IV-001).
    try:
        with _token_store_session(path) as (existing, commit):
            if not existing:
                existing = {
                    "schema_version": TOKEN_STORE_SCHEMA_VERSION,
                    "profiles": {},
                }
            profiles = dict(existing.get("profiles") or {})
            profiles[profile_name] = record
            envelope = dict(existing)
            envelope["schema_version"] = TOKEN_STORE_SCHEMA_VERSION
            envelope["profiles"] = profiles
            commit(envelope)
    except MuralError as exc:
        _emit(
            f"existing token store at {path} could not be read ({exc}); "
            "starting a new envelope",
            level=logging.WARNING,
        )
        envelope = {
            "schema_version": TOKEN_STORE_SCHEMA_VERSION,
            "profiles": {profile_name: record},
        }
        with _acquire_cache_lock(path):
            _save_token_store_locked(path, envelope)
    _emit(
        f"saved token store at {path} (profile {profile_name!r})",
        level=logging.INFO,
    )
    return EXIT_SUCCESS


_OAUTH_SETUP_WALKTHROUGH = """\
Mural OAuth app setup walkthrough
=================================

1. Sign in at https://app.mural.co and open Account Settings -> Developer
   Console -> Create new app.
2. Set the app's Redirect URL to the loopback address this CLI listens on:
     - Linux  : http://localhost:8765/callback
     - macOS  : http://localhost:8765/callback
     - Windows: http://localhost:8765/callback
   Override with the MURAL_REDIRECT_URI environment variable when port 8765
   is unavailable; the override must point at a loopback host
   (`localhost` or `127.0.0.1`) on a port in the range 1024-65535,
   with `/callback` as the exact path. IPv6 loopback (`[::1]`) is not
   accepted.
3. Copy the app credentials into your shell environment:
     - MURAL_CLIENT_ID      (required) the app's client identifier
     - MURAL_CLIENT_SECRET  (optional) only required for confidential clients
     - MURAL_REDIRECT_URI   (optional) overrides the default loopback URL
     - MURAL_SCOPES         (optional) overrides the default scope set
       (interactive bootstrap requests `DEFAULT_LOGIN_SCOPES`, the union
       of the read scopes and `murals:write` / `templates:write` /
       `rooms:write`, so first-time users can read and write immediately)
4. Run `mural auth bootstrap` for an interactive walkthrough that opens the
   developer portal and persists Client ID / Secret via the active
   credential backend (MURAL_CREDENTIAL_BACKEND={auto|keyring|file|
   env-only}; defaults to OS keyring with a 0600-mode file fallback),
   or `mural auth setup` for non-interactive provisioning, then
   `mural auth login --profile <name>` to mint tokens via the PKCE flow.

Redaction contract: this CLI redacts access tokens, refresh tokens, OAuth
`code` parameters, `state` parameters, and Authorization headers from every
stderr/log emission. Never paste raw tokens into shared transcripts.
"""


# Mural exposes no RFC 7009 /revoke endpoint, so logout is local-only.
_LOGOUT_TRANSPARENCY_LINES: tuple[str, ...] = (
    "Credentials have been cleared from this machine.",
    (
        "Your Mural OAuth tokens may remain active server-side until they "
        "expire (access tokens have a documented 15-minute TTL; "
        "refresh tokens persist longer and are not rotated on use)."
    ),
    (
        "To fully revoke access, visit https://app.mural.co/me/apps and "
        "remove this integration."
    ),
)


def _cmd_auth_setup(args: argparse.Namespace) -> int:
    """Provision a new profile non-interactively from env or CLI args."""
    json_mode = bool(getattr(args, "json", False)) or _CLI_FORCE_JSON
    if not json_mode:
        print(_OAUTH_SETUP_WALKTHROUGH)
    _emit("mural auth setup", level=logging.INFO)
    try:
        profile_name = _validate_profile_name(
            getattr(args, "profile", None) or DEFAULT_PROFILE_NAME
        )
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    client_id = getattr(args, "client_id", None) or os.environ.get(ENV_CLIENT_ID)
    if not client_id:
        _emit(
            f"{ENV_CLIENT_ID} is not set and --client-id was not provided",
            level=logging.ERROR,
        )
        return EXIT_USAGE
    scope = (
        getattr(args, "scope", None)
        or os.environ.get(ENV_SCOPES)
        or " ".join(READ_SCOPES)
    )
    granted = tuple(scope.split())
    record = {
        "client_id": client_id,
        "access_token": "",
        "token_type": "Bearer",
        "obtained_at": int(time.time()),
        "granted_scopes": list(granted),
    }
    path = _resolve_token_store_path()
    # ``setup`` is also a recovery entry point: a corrupt or incompatible
    # store should not block the user from preparing a new profile. Happy
    # path uses ``_token_store_session`` to close the IV-001 TOCTOU window.
    try:
        with _token_store_session(path) as (existing, commit):
            if not existing:
                existing = {
                    "schema_version": TOKEN_STORE_SCHEMA_VERSION,
                    "profiles": {},
                }
            profiles = dict(existing.get("profiles") or {})
            profiles[profile_name] = record
            envelope = dict(existing)
            envelope["schema_version"] = TOKEN_STORE_SCHEMA_VERSION
            envelope["profiles"] = profiles
            commit(envelope)
    except MuralError as exc:
        _emit(
            f"existing token store at {path} could not be read ({exc}); "
            "starting a new envelope",
            level=logging.WARNING,
        )
        envelope = {
            "schema_version": TOKEN_STORE_SCHEMA_VERSION,
            "profiles": {profile_name: record},
        }
        with _acquire_cache_lock(path):
            _save_token_store_locked(path, envelope)
    # Mirror the client_id into the active credential backend so
    # subsequent `mural auth login` invocations can resolve it without
    # the operator re-exporting MURAL_CLIENT_ID. Failure to write is
    # surfaced as a single deduped WARN; the token-store record above
    # is already committed so setup remains useful in env-only mode.
    try:
        backend = resolve_backend(profile_name)
    except MuralError as exc:
        backend = None
        _emit(
            f"could not resolve credential backend while mirroring "
            f"client_id for profile {profile_name!r}: {exc}",
            level=logging.WARNING,
        )
    if backend is not None:
        if isinstance(backend, _NullBackend):
            warn_key = f"setup-null:{profile_name}"
            if warn_key not in _seen_fallback_warn:
                _seen_fallback_warn.add(warn_key)
                _emit(
                    "credential backend is 'env-only'; client_id was "
                    f"recorded in the token store at {path} only. Set "
                    "MURAL_CREDENTIAL_BACKEND=keyring or =file before "
                    "`mural auth login` to persist the client_id outside "
                    "the environment.",
                    level=logging.WARNING,
                )
        else:
            try:
                backend.set(
                    _service_name_for(profile_name),
                    "MURAL_CLIENT_ID",
                    client_id,
                )
            except (_KeyringUnavailable, OSError, RuntimeError) as exc:
                warn_key = f"setup-write:{profile_name}:{backend.name}"
                if warn_key not in _seen_fallback_warn:
                    _seen_fallback_warn.add(warn_key)
                    _emit(
                        f"failed to mirror client_id into backend "
                        f"{backend.name!r} for profile {profile_name!r}: "
                        f"{exc}",
                        level=logging.WARNING,
                    )
    next_step = f"python -m mural auth login --profile {profile_name}"
    if json_mode:
        print(
            json.dumps(
                {
                    "profile": profile_name,
                    "token_store": str(path),
                    "status": "prepared",
                    "next_steps": [next_step],
                },
                indent=2,
            )
        )
    else:
        _emit(
            f"profile {profile_name!r} prepared at {path}; "
            f"run `{next_step}` to obtain tokens",
            level=logging.INFO,
        )
    return EXIT_SUCCESS


def _bootstrap_is_interactive() -> bool:
    """Return True when `mural auth bootstrap` may prompt the operator."""
    return (
        sys.stdin.isatty()
        and sys.stdout.isatty()
        and os.environ.get(ENV_NONINTERACTIVE) != "1"
        and os.environ.get("CI", "").lower() != "true"
    )


def _cmd_auth_bootstrap(args: argparse.Namespace) -> int:
    """Interactive one-time setup that writes app credentials to the active backend.

    Replaces the legacy file-only writer: credentials are persisted via
    :func:`resolve_backend` so the operator's
    ``MURAL_CREDENTIAL_BACKEND`` selector decides whether the secret
    lands in the OS keyring or the per-user credential file. The flow
    runs in eight stages so each side-effect is auditable in the log
    output.
    """
    try:
        profile_name = _validate_profile_name(
            getattr(args, "profile", None)
            or os.environ.get(ENV_PROFILE)
            or DEFAULT_PROFILE_NAME
        )
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    if not _bootstrap_is_interactive():
        _emit(
            "auth bootstrap requires an interactive TTY; non-interactive "
            "callers should run `mural auth setup` to provision a profile, "
            "or set MURAL_CLIENT_ID and MURAL_CLIENT_SECRET in the active "
            "credential backend directly.",
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    force = bool(getattr(args, "force", False))
    service = _service_name_for(profile_name)

    # Stage 1: detect existing credentials in the active backend.
    try:
        backend = resolve_backend(profile_name)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_FAILURE
    try:
        existing_id = backend.get(service, "MURAL_CLIENT_ID")
    except _KeyringUnavailable as exc:
        _emit(
            f"credential backend {backend.name!r} unavailable: {exc}",
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    if existing_id and not force:
        _emit(
            f"profile {profile_name!r} already has MURAL_CLIENT_ID stored in "
            f"backend {backend.name!r}; rerun with --force to overwrite, or "
            "use `mural auth status` to inspect.",
            level=logging.INFO,
        )
        return EXIT_SUCCESS

    # Stage 2: surface portal URL, scopes, and callback URL to the operator.
    portal_url = "https://app.mural.co/me/apps"
    callback_url = DEFAULT_REDIRECT_URI
    scopes = READ_SCOPES + WRITE_SCOPES
    _emit(
        f"opening {portal_url} for app credential creation; "
        "create a new app and copy its Client ID and Client Secret",
        level=logging.INFO,
    )
    _emit(
        f"required scopes: {', '.join(scopes)}",
        level=logging.INFO,
    )
    _emit(
        f"callback URL to register on the app: {callback_url}",
        level=logging.INFO,
    )

    # Stage 3: best-effort browser open (never raises).
    with contextlib.suppress(Exception):
        webbrowser.open(portal_url)

    # Stage 4: prompt for credentials with hidden secret entry.
    try:
        client_id = input("Mural Client ID: ").strip()
        client_secret = getpass.getpass("Mural Client Secret (input hidden): ").strip()
    except EOFError:
        _emit(
            "aborted at prompt; no credentials written",
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    try:
        if not client_id:
            raise MuralValidationError("Mural Client ID must not be empty")
        if not client_secret:
            raise MuralValidationError("Mural Client Secret must not be empty")
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    # Reject malformed secrets (whitespace, truncated pastes) before they
    # land in the credential backend and surface as opaque ``invalid_client``
    # errors during ``auth login``.
    try:
        client_secret = _validate_client_secret(client_secret)
    except ValueError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE

    # Stage 5: persist via the active backend. _NullBackend raises here so
    # the operator gets a clear actionable message instead of a silent no-op.
    if isinstance(backend, _NullBackend):
        _emit(
            "credential backend is 'env-only'; cannot persist credentials. "
            "Set MURAL_CREDENTIAL_BACKEND=keyring or =file before rerunning "
            "`mural auth bootstrap`.",
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    try:
        backend.set(service, "MURAL_CLIENT_ID", client_id)
        backend.set(service, "MURAL_CLIENT_SECRET", client_secret)
    except (_KeyringUnavailable, OSError, RuntimeError) as exc:
        _emit(
            f"failed to write credentials to backend {backend.name!r}: {exc}",
            level=logging.ERROR,
        )
        return EXIT_FAILURE

    # Stage 6: round-trip verification so silent backend faults surface now.
    try:
        roundtrip = backend.get(service, "MURAL_CLIENT_ID")
    except _KeyringUnavailable as exc:
        _emit(
            f"backend {backend.name!r} write succeeded but verification "
            f"read failed: {exc}",
            level=logging.ERROR,
        )
        return EXIT_FAILURE
    if roundtrip != client_id:
        _emit(
            f"backend {backend.name!r} verification mismatch: stored "
            "value differs from input",
            level=logging.ERROR,
        )
        return EXIT_FAILURE

    # Stage 7: probe credentials with /token client_credentials grant so
    # the operator learns immediately if the saved pair is rejected.
    if not getattr(args, "no_test", False):
        ok, message = _probe_client_credentials(client_id, client_secret)
        if ok:
            _emit(
                f"credential probe succeeded: {message}",
                level=logging.INFO,
            )
        else:
            _emit(
                f"{message}; your credentials were saved but Mural "
                "rejected them — try `mural auth bootstrap --no-test` "
                "if you want to debug separately",
                level=logging.ERROR,
            )
            return EXIT_FAILURE

    # Stage 8: actionable next steps.
    _emit(
        f"stored Mural app credentials for profile {profile_name!r} in "
        f"backend {backend.name!r}",
        level=logging.INFO,
    )
    _emit(
        "Run `mural auth status` to confirm credentials are resolvable, then "
        f"`mural auth login --profile {profile_name}` to obtain tokens.",
        level=logging.INFO,
    )
    return EXIT_SUCCESS


def _cmd_auth_list(_args: argparse.Namespace) -> int:
    """List configured profiles with active marker."""
    path = _resolve_token_store_path()
    store = _load_token_store(path)
    profiles_obj: dict[str, Any] = {}
    active: str | None = None
    if isinstance(store, dict):
        raw = store.get("profiles") or {}
        if isinstance(raw, dict):
            profiles_obj = raw
        active_raw = store.get("active_profile")
        if isinstance(active_raw, str) and active_raw:
            active = active_raw
    rows: list[dict[str, Any]] = []
    for name in sorted(profiles_obj):
        prof = profiles_obj.get(name) or {}
        cid = prof.get("client_id") or ""
        cid_short = cid[-4:] if isinstance(cid, str) and len(cid) > 4 else cid
        granted = prof.get("granted_scopes")
        if not (isinstance(granted, list) and all(isinstance(s, str) for s in granted)):
            granted = []
        rows.append(
            {
                "name": name,
                "client_id": cid_short,
                "granted_scopes": list(granted),
                "expires_at": prof.get("expires_at"),
                "has_refresh_token": bool(prof.get("refresh_token")),
                "active": name == active,
            }
        )
    if _CLI_FORCE_JSON or getattr(_args, "format", "json") != "table":
        print(
            json.dumps(
                {"token_store": str(path), "active_profile": active, "profiles": rows},
                indent=2,
            )
        )
        return EXIT_SUCCESS
    if not rows:
        print("(no profiles)")
        return EXIT_SUCCESS
    header = (
        f"  {'NAME':<20} {'CLIENT_ID':<6} {'REFRESH':<7} "
        f"{'GRANTED_SCOPES':<40} EXPIRES_AT"
    )
    print(header)
    for row in rows:
        marker = "*" if row["active"] else " "
        scope = " ".join(row["granted_scopes"])[:40]
        refresh = "yes" if row["has_refresh_token"] else "no"
        expires = row["expires_at"]
        if isinstance(expires, (int, float)):
            try:
                expires_str = datetime.datetime.fromtimestamp(
                    expires, tz=datetime.timezone.utc
                ).isoformat()
            except (OverflowError, OSError, ValueError):
                expires_str = str(expires)
        else:
            expires_str = "" if expires is None else str(expires)
        print(
            f"{marker} {row['name']:<20} {row['client_id']:<6} "
            f"{refresh:<7} {scope:<40} {expires_str}"
        )
    return EXIT_SUCCESS


def _cmd_auth_use(args: argparse.Namespace) -> int:
    """Set the active profile in the v2 envelope."""
    json_mode = bool(getattr(args, "json", False)) or _CLI_FORCE_JSON
    try:
        name = _validate_profile_name(args.name)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    path = _resolve_token_store_path()
    with _token_store_session(path) as (store, commit):
        if not store:
            _emit(
                f"no token store at {path}; run `python -m mural auth login` first",
                level=logging.ERROR,
            )
            return EXIT_FAILURE
        try:
            _select_profile(store, name)
        except MuralError as exc:
            _emit(str(exc), level=logging.ERROR)
            return EXIT_FAILURE
        envelope = dict(store)
        envelope["active_profile"] = name
        commit(envelope)
    if json_mode:
        print(
            json.dumps(
                {
                    "profile": name,
                    "token_store": str(path),
                    "status": "active",
                },
                indent=2,
            )
        )
    else:
        _emit(f"active profile set to {name!r}", level=logging.INFO)
    return EXIT_SUCCESS


def _logout_remove_credentials(
    profile: str,
    *,
    require_force_for_file: bool,
) -> dict[str, Any]:
    """Delete every known credential key for ``profile`` from its backend.

    Returns a per-profile result dict suitable for inclusion in the
    logout JSON envelope and (when ``--json`` is not set) for printing
    a friendly summary. Never raises: backend errors are captured in
    the returned ``error`` field so the caller can decide whether to
    surface them.

    When the resolved backend is :class:`FileBackend` and
    ``require_force_for_file`` is true, the file is left intact and the
    returned ``status`` is ``"requires_force"`` so the caller can
    instruct the operator to re-run with ``--force``.
    """
    result: dict[str, Any] = {"profile": profile}
    try:
        backend = resolve_backend(profile)
    except MuralError as exc:
        result["status"] = "error"
        result["error"] = str(exc)
        result["backend"] = "unavailable"
        return result
    result["backend"] = backend.name
    if isinstance(backend, _NullBackend):
        result["status"] = "skipped"
        result["reason"] = "MURAL_CREDENTIAL_BACKEND=env-only has no persistence layer"
        return result
    if isinstance(backend, FileBackend) and require_force_for_file:
        result["status"] = "requires_force"
        result["reason"] = (
            "FileBackend deletion requires --force "
            "(removes credential file at "
            f"{backend._path})"
        )
        return result
    service = _service_name_for(profile)
    removed: list[str] = []
    errors: dict[str, str] = {}
    for key in _KNOWN_CREDENTIAL_KEYS:
        try:
            existing = backend.get(service, key)
        except _KeyringUnavailable as exc:
            errors[key] = f"read failed: {exc}"
            continue
        if not existing:
            continue
        try:
            backend.delete(service, key)
        except _KeyringUnavailable as exc:
            errors[key] = f"delete failed: {exc}"
            continue
        except OSError as exc:
            errors[key] = f"delete failed: {exc}"
            continue
        removed.append(key)
    result["removed_keys"] = removed
    if errors:
        result["status"] = "partial" if removed else "error"
        result["errors"] = errors
    elif removed:
        result["status"] = "removed"
    else:
        result["status"] = "absent"
    return result


def _cmd_auth_logout(args: argparse.Namespace) -> int:
    """Remove credentials.

    Modes:
      * no flags: clear the currently-active profile only.
      * ``--profile NAME``: remove the named profile (and clear
        ``active_profile`` if it pointed there).
      * ``--all``: atomically replace the envelope with an empty v2 envelope.

    ``--all`` and ``--profile`` are mutually exclusive (enforced by argparse).

    By default credentials are also removed from the resolved backend
    (keyring or file). Pass ``--keep-credentials`` to leave backend
    state untouched. ``--force`` is required to delete from the
    :class:`FileBackend` (since it removes the on-disk credential file).
    """
    json_mode = bool(getattr(args, "json", False)) or _CLI_FORCE_JSON
    keep_credentials = bool(getattr(args, "keep_credentials", False))
    force = bool(getattr(args, "force", False))
    path = _resolve_token_store_path()
    if getattr(args, "all", False):
        # Snapshot profile names BEFORE clearing the token store so we
        # can iterate them for backend deletion.
        store_snapshot = _load_token_store(path) or {}
        profile_names = sorted((store_snapshot.get("profiles") or {}).keys())
        empty = {"schema_version": TOKEN_STORE_SCHEMA_VERSION, "profiles": {}}
        try:
            with _acquire_cache_lock(path):
                _save_token_store_locked(path, empty)
        except OSError as exc:
            _emit(f"cannot rewrite {path}: {exc}", level=logging.ERROR)
            return EXIT_FAILURE
        credentials_results: list[dict[str, Any]] = []
        if not keep_credentials:
            # When --all and no profiles in store, fall back to default
            # profile so we still try to clean its backend entries.
            for name in profile_names or [DEFAULT_PROFILE_NAME]:
                credentials_results.append(
                    _logout_remove_credentials(name, require_force_for_file=not force)
                )
        if json_mode:
            print(
                json.dumps(
                    {
                        "token_store": str(path),
                        "status": "cleared",
                        "scope": "all",
                        "credentials_removed": credentials_results,
                        "keep_credentials": keep_credentials,
                    },
                    indent=2,
                )
            )
        else:
            _emit(f"cleared all profiles in {path}", level=logging.INFO)
            for entry in credentials_results:
                _emit_logout_credential_summary(entry)
            _emit_logout_transparency()
        return EXIT_SUCCESS

    target = getattr(args, "profile", None)
    with _token_store_session(path) as (store, commit):
        if not store:
            credentials_results = []
            if not keep_credentials:
                fallback = target or os.environ.get(ENV_PROFILE) or DEFAULT_PROFILE_NAME
                try:
                    fallback = _validate_profile_name(fallback)
                except MuralError as exc:
                    _emit(str(exc), level=logging.ERROR)
                    return EXIT_USAGE
                credentials_results.append(
                    _logout_remove_credentials(
                        fallback, require_force_for_file=not force
                    )
                )
            if json_mode:
                print(
                    json.dumps(
                        {
                            "token_store": str(path),
                            "status": "absent",
                            "credentials_removed": credentials_results,
                            "keep_credentials": keep_credentials,
                        },
                        indent=2,
                    )
                )
            else:
                _emit(f"no token store at {path}", level=logging.INFO)
                for entry in credentials_results:
                    _emit_logout_credential_summary(entry)
            return EXIT_SUCCESS
        if target is None:
            target = _resolve_active_profile(store, os.environ, None)
        else:
            try:
                target = _validate_profile_name(target)
            except MuralError as exc:
                _emit(str(exc), level=logging.ERROR)
                return EXIT_USAGE
        profiles = dict(store.get("profiles") or {})
        token_status: str
        if target not in profiles:
            token_status = "absent"
        else:
            profiles.pop(target, None)
            envelope = dict(store)
            envelope["schema_version"] = TOKEN_STORE_SCHEMA_VERSION
            envelope["profiles"] = profiles
            if envelope.get("active_profile") == target:
                envelope.pop("active_profile", None)
            try:
                commit(envelope)
            except OSError as exc:
                _emit(f"cannot rewrite {path}: {exc}", level=logging.ERROR)
                return EXIT_FAILURE
            token_status = "removed"
    credentials_results = []
    if not keep_credentials:
        credentials_results.append(
            _logout_remove_credentials(target, require_force_for_file=not force)
        )
    if json_mode:
        print(
            json.dumps(
                {
                    "profile": target,
                    "token_store": str(path),
                    "status": token_status,
                    "credentials_removed": credentials_results,
                    "keep_credentials": keep_credentials,
                },
                indent=2,
            )
        )
    else:
        if token_status == "removed":
            _emit(
                f"removed profile {target!r} from {path}",
                level=logging.INFO,
            )
        else:
            _emit(
                f"profile {target!r} not present in {path}",
                level=logging.INFO,
            )
        for entry in credentials_results:
            _emit_logout_credential_summary(entry)
        if token_status == "removed":
            _emit_logout_transparency()
    return EXIT_SUCCESS


def _emit_logout_credential_summary(entry: dict[str, Any]) -> None:
    """Print a one-line operator-friendly summary of a credential cleanup."""
    profile = entry.get("profile", "?")
    backend = entry.get("backend", "?")
    status = entry.get("status", "?")
    if status == "removed":
        keys = ", ".join(entry.get("removed_keys") or []) or "(none)"
        _emit(
            f"removed credentials for profile {profile!r} "
            f"from {backend} backend (keys: {keys})",
            level=logging.INFO,
        )
    elif status == "absent":
        _emit(
            f"no credentials present for profile {profile!r} in {backend} backend",
            level=logging.INFO,
        )
    elif status == "skipped":
        _emit(
            f"skipped credential removal for profile {profile!r}: "
            f"{entry.get('reason')}",
            level=logging.INFO,
        )
    elif status == "requires_force":
        _emit(
            f"credential removal for profile {profile!r} requires --force: "
            f"{entry.get('reason')}",
            level=logging.WARNING,
        )
    elif status == "partial":
        keys = ", ".join(entry.get("removed_keys") or []) or "(none)"
        _emit(
            f"partial credential removal for profile {profile!r} "
            f"({backend}; removed: {keys}; errors: "
            f"{entry.get('errors')})",
            level=logging.WARNING,
        )
    else:  # error or unknown
        _emit(
            f"credential removal failed for profile {profile!r}: "
            f"{entry.get('error') or entry.get('errors')}",
            level=logging.ERROR,
        )


def _emit_logout_transparency() -> None:
    """Emit the local-only logout transparency message lines."""
    for line in _LOGOUT_TRANSPARENCY_LINES:
        _emit(line, level=logging.INFO)


def _cmd_auth_status(args: argparse.Namespace) -> int:
    path = _resolve_token_store_path()
    cred_profile = (
        getattr(args, "profile", None)
        or os.environ.get(ENV_PROFILE)
        or DEFAULT_PROFILE_NAME
    )
    cred_path = _resolve_credential_file(cred_profile, os.environ)
    selector = os.environ.get("MURAL_CREDENTIAL_BACKEND", "auto").lower()
    try:
        backend = resolve_backend(cred_profile)
        backend_name: str = backend.name
        backend_error: str | None = None
    except MuralError as exc:
        backend = None  # type: ignore[assignment]
        backend_name = "unavailable"
        backend_error = str(exc)
    keyring_available, keyring_backend_name, keyring_error = (
        _probe_keyring_availability()
    )
    # Probe both persistent backends so operators can see when concurrent
    # state exists even if it has not yet triggered a WARN this process.
    service = _service_name_for(cred_profile)
    keyring_populated = False
    if keyring_available:
        try:
            probe = KeyringBackend()
            for key in _KNOWN_CREDENTIAL_KEYS:
                if probe.get(service, key):
                    keyring_populated = True
                    break
        except _KeyringUnavailable:
            keyring_populated = False
    file_populated = False
    if cred_path.exists():
        try:
            file_entries = FileBackend(cred_path)._read_all()
            file_populated = any(file_entries.get(k) for k in _KNOWN_CREDENTIAL_KEYS)
        except Exception:  # noqa: BLE001 - probe must never raise
            file_populated = False
    concurrent_state = {
        "keyring_populated": keyring_populated,
        "file_populated": file_populated,
        "both_populated": keyring_populated and file_populated,
    }
    backends_have_creds = keyring_populated or file_populated
    cred_keys = {
        "credential_file": str(cred_path),
        "credential_file_exists": cred_path.exists(),
        "backend": backend_name,
        "backend_selector": selector,
        "keyring_available": keyring_available,
        "keyring_backend": keyring_backend_name,
        "concurrent_state": concurrent_state,
    }
    if backend_error is not None:
        cred_keys["backend_error"] = backend_error
    if keyring_error is not None and not keyring_available:
        cred_keys["keyring_error"] = keyring_error
    store = _load_token_store(path)
    if not store:
        print(
            json.dumps(
                {"authenticated": False, "token_store": str(path), **cred_keys},
                indent=2,
            )
        )
        return EXIT_SUCCESS if backends_have_creds else EXIT_FAILURE
    profile_name = _resolve_active_profile(
        store, os.environ, getattr(args, "profile", None)
    )
    try:
        profile = _select_profile(store, profile_name)
    except MuralError:
        print(
            json.dumps(
                {"authenticated": False, "token_store": str(path), **cred_keys},
                indent=2,
            )
        )
        return EXIT_SUCCESS if backends_have_creds else EXIT_FAILURE
    info = {
        "authenticated": True,
        "token_store": str(path),
        "profile": profile_name,
        "granted_scopes": list(_token_granted_scopes(store, profile_name)),
        "expires_at": profile.get("expires_at"),
        "has_refresh_token": bool(profile.get("refresh_token")),
        **cred_keys,
    }
    print(json.dumps(info, indent=2))
    if backends_have_creds or info["has_refresh_token"]:
        return EXIT_SUCCESS
    return EXIT_FAILURE


def _cmd_auth_migrate(args: argparse.Namespace) -> int:
    """Migrate stored credentials between the keyring and file backends.

    Bypasses :func:`resolve_backend` so the operator can move
    credentials regardless of the active ``MURAL_CREDENTIAL_BACKEND``
    selector. Performs a round-trip read after every key write so a
    silent corruption in either backend surfaces as a non-zero exit.

    With ``--cleanup`` the source backend's keys are removed after a
    successful round-trip; ``--yes`` skips the confirmation prompt
    (required when ``MURAL_NONINTERACTIVE=1``).
    """
    json_mode = bool(getattr(args, "json", False)) or _CLI_FORCE_JSON
    direction = getattr(args, "to", None)
    if direction not in {"keyring", "file"}:
        _emit("--to must be one of 'keyring' or 'file'", level=logging.ERROR)
        return EXIT_USAGE
    profile = (
        getattr(args, "profile", None)
        or os.environ.get(ENV_PROFILE)
        or DEFAULT_PROFILE_NAME
    )
    try:
        profile = _validate_profile_name(profile)
    except MuralError as exc:
        _emit(str(exc), level=logging.ERROR)
        return EXIT_USAGE
    cleanup = bool(getattr(args, "cleanup", False))
    force = bool(getattr(args, "force", False))
    yes = bool(getattr(args, "yes", False))
    noninteractive = os.environ.get("MURAL_NONINTERACTIVE", "").lower() in {
        "1",
        "true",
        "yes",
    }

    cred_path = _resolve_credential_file(profile, os.environ)
    service = _service_name_for(profile)

    # Probe both backends up-front. KeyringBackend instantiation may
    # raise _KeyringUnavailable; treat that as a usage error when the
    # operator asked to read or write keyring state.
    try:
        keyring_backend = KeyringBackend()
    except _KeyringUnavailable as exc:
        if direction == "keyring" or _migrate_source_is_keyring(direction):
            _emit(
                f"keyring backend unavailable: {exc}",
                level=logging.ERROR,
            )
            return EXIT_FAILURE
        keyring_backend = None  # type: ignore[assignment]
    file_backend = FileBackend(cred_path)

    if direction == "keyring":
        source = file_backend
        target = keyring_backend
        source_name = "file"
        target_name = "keyring"
    else:
        if keyring_backend is None:
            _emit(
                "keyring backend unavailable; cannot migrate from it",
                level=logging.ERROR,
            )
            return EXIT_FAILURE
        source = keyring_backend
        target = file_backend
        source_name = "keyring"
        target_name = "file"

    # Concurrent-state guard: surface a one-shot WARN per profile when
    # both backends already hold values so the operator understands the
    # migration may overwrite distinct copies.
    dedup_key = (profile, "migrate")
    if dedup_key not in _seen_concurrent_warn:
        try:
            keyring_has = keyring_backend is not None and any(
                keyring_backend.get(service, k) for k in _KNOWN_CREDENTIAL_KEYS
            )
        except _KeyringUnavailable:
            keyring_has = False
        try:
            file_has = cred_path.exists() and any(
                file_backend._read_all().get(k) for k in _KNOWN_CREDENTIAL_KEYS
            )
        except Exception:  # noqa: BLE001 - probe must never raise
            file_has = False
        if keyring_has and file_has:
            _seen_concurrent_warn.add(dedup_key)
            if not force:
                _emit(
                    f"both keyring and file backends already populated for "
                    f"profile {profile!r}; rerun with --force to overwrite",
                    level=logging.ERROR,
                )
                return EXIT_FAILURE
            _emit(
                f"both keyring and file backends already populated for "
                f"profile {profile!r}; --force set, overwriting destination",
                level=logging.WARNING,
            )

    migrated: list[str] = []
    skipped_empty: list[str] = []
    failures: dict[str, str] = {}
    for key in _KNOWN_CREDENTIAL_KEYS:
        try:
            value = source.get(service, key)
        except _KeyringUnavailable as exc:
            failures[key] = f"source read failed: {exc}"
            continue
        if not value:
            skipped_empty.append(key)
            continue
        try:
            target.set(service, key, value)
        except (_KeyringUnavailable, OSError, RuntimeError) as exc:
            failures[key] = f"target write failed: {exc}"
            continue
        try:
            roundtrip = target.get(service, key)
        except _KeyringUnavailable as exc:
            failures[key] = f"round-trip read failed: {exc}"
            continue
        if roundtrip != value:
            failures[key] = "round-trip mismatch (target value differs from source)"
            continue
        migrated.append(key)

    summary: dict[str, Any] = {
        "profile": profile,
        "direction": f"{source_name}->{target_name}",
        "source": source_name,
        "target": target_name,
        "migrated_keys": migrated,
        "skipped_empty_keys": skipped_empty,
        "failures": failures,
        "cleanup": False,
    }

    if failures:
        summary["status"] = "partial" if migrated else "failed"
        if json_mode:
            print(json.dumps(summary, indent=2))
        else:
            _emit(
                f"migration {source_name}->{target_name} for profile "
                f"{profile!r} encountered failures: {failures}",
                level=logging.ERROR,
            )
            if migrated:
                _emit(
                    f"successfully migrated keys: {', '.join(migrated)}",
                    level=logging.INFO,
                )
        return EXIT_FAILURE if not migrated else EXIT_SUCCESS

    if not migrated:
        summary["status"] = "no-op"
        if json_mode:
            print(json.dumps(summary, indent=2))
        else:
            _emit(
                f"no credentials to migrate for profile {profile!r} "
                f"(source {source_name} is empty)",
                level=logging.INFO,
            )
        return EXIT_SUCCESS

    summary["status"] = "migrated"

    if cleanup:
        if isinstance(source, FileBackend) and not force:
            summary["status"] = "migrated_cleanup_requires_force"
            summary["cleanup_blocked_reason"] = (
                "FileBackend cleanup requires --force (removes credential file)"
            )
            if json_mode:
                print(json.dumps(summary, indent=2))
            else:
                _emit(
                    f"migration succeeded but --cleanup of file backend "
                    f"requires --force (file at {cred_path})",
                    level=logging.WARNING,
                )
            return EXIT_SUCCESS
        if not yes:
            if noninteractive:
                summary["status"] = "migrated_cleanup_requires_yes"
                summary["cleanup_blocked_reason"] = (
                    "MURAL_NONINTERACTIVE=1 requires --yes for --cleanup"
                )
                if json_mode:
                    print(json.dumps(summary, indent=2))
                else:
                    _emit(
                        "MURAL_NONINTERACTIVE=1 requires --yes to proceed "
                        "with --cleanup",
                        level=logging.WARNING,
                    )
                return EXIT_USAGE
            try:
                response = (
                    input(
                        f"Remove migrated credentials from {source_name} backend "
                        f"for profile {profile!r}? [y/N] "
                    )
                    .strip()
                    .lower()
                )
            except (EOFError, KeyboardInterrupt):
                response = ""
            if response not in {"y", "yes"}:
                summary["status"] = "migrated_cleanup_declined"
                if json_mode:
                    print(json.dumps(summary, indent=2))
                else:
                    _emit(
                        "cleanup declined; source backend left intact",
                        level=logging.INFO,
                    )
                return EXIT_SUCCESS
        cleanup_removed: list[str] = []
        cleanup_errors: dict[str, str] = {}
        for key in migrated:
            try:
                source.delete(service, key)
            except (_KeyringUnavailable, OSError, RuntimeError) as exc:
                cleanup_errors[key] = str(exc)
                continue
            cleanup_removed.append(key)
        summary["cleanup"] = True
        summary["cleanup_removed_keys"] = cleanup_removed
        if cleanup_errors:
            summary["cleanup_errors"] = cleanup_errors
            summary["status"] = "migrated_cleanup_partial"

    if json_mode:
        print(json.dumps(summary, indent=2))
    else:
        _emit(
            f"migrated {len(migrated)} key(s) "
            f"({', '.join(migrated)}) from {source_name} to {target_name} "
            f"for profile {profile!r}",
            level=logging.INFO,
        )
        if summary.get("cleanup"):
            _emit(
                f"cleanup removed {len(summary.get('cleanup_removed_keys') or [])} "
                f"key(s) from {source_name} backend",
                level=logging.INFO,
            )
    return EXIT_SUCCESS


def _migrate_source_is_keyring(direction: str) -> bool:
    """Return True when migration ``direction`` reads from keyring."""
    return direction == "file"


def _read_fields(args: argparse.Namespace) -> list[str] | None:
    raw = getattr(args, "fields", None)
    if not raw:
        return None
    return [f.strip() for f in raw.split(",") if f.strip()]


def _list_kwargs(args: argparse.Namespace) -> dict[str, int | None]:
    limit = getattr(args, "limit", None)
    page_size = getattr(args, "page_size", None)
    max_pages = getattr(args, "max_pages", None)
    for name, value in (
        ("--limit", limit),
        ("--page-size", page_size),
        ("--max-pages", max_pages),
    ):
        if value is not None and value <= 0:
            raise MuralValidationError(f"{name} must be positive")
        if value is not None and value > _MAX_PAGE_SIZE * 100:
            raise MuralValidationError(f"{name} exceeds safe maximum")
    if page_size is not None and page_size > _MAX_PAGE_SIZE:
        raise MuralValidationError(f"--page-size cannot exceed {_MAX_PAGE_SIZE}")
    return {"limit": limit, "page_size": page_size, "max_pages": max_pages}


_HTML_TAG_RE = re.compile(r"<[^>]+>")


def _strip_html(value: Any) -> str:
    """Strip HTML tags and collapse whitespace from ``value``.

    Mirrors the canonical normaliser used by the diff_board fixture so
    portal-edited stickies (which migrate plain-text into ``htmlText``)
    render with a stable, tag-free ``text`` field downstream.
    """
    if not isinstance(value, str) or not value:
        return ""
    return _HTML_TAG_RE.sub("", value).strip()


def _coalesce_widget_text(widget: dict[str, Any]) -> str:
    """Return the best-available plain-text body for ``widget``.

    Prefers stripped ``htmlText`` (portal edits land there with
    ``text`` cleared), falling back to ``text``.  Returns ``""`` when
    neither field carries content.
    """
    html_text = _strip_html(widget.get("htmlText"))
    if html_text:
        return html_text
    raw = widget.get("text")
    return raw.strip() if isinstance(raw, str) else ""


def _apply_widget_text_coalesce(payload: Any) -> Any:
    """Surface ``htmlText`` content as ``text`` on widget-shaped dicts.

    Walks lists and dicts in place. A dict is treated as widget-shaped
    when it carries an ``htmlText`` key; in that case ``text`` is set
    to :func:`_coalesce_widget_text` so JSON consumers see the visible
    body even after portal edits. ``htmlText`` is preserved for
    round-trip callers. Non-widget records (tags, areas, workspaces)
    are untouched.
    """
    if isinstance(payload, list):
        for item in payload:
            _apply_widget_text_coalesce(item)
    elif isinstance(payload, dict):
        if "htmlText" in payload:
            payload["text"] = _coalesce_widget_text(payload)
        for value in payload.values():
            if isinstance(value, (dict, list)):
                _apply_widget_text_coalesce(value)
    return payload


def _emit_records(records: list[Any], args: argparse.Namespace) -> int:
    _apply_widget_text_coalesce(records)
    fields = _read_fields(args)
    fmt = "json" if _CLI_FORCE_JSON else (getattr(args, "format", None) or "json")
    print(_format_output(records, fields, fmt))
    return EXIT_SUCCESS


def _emit_record(record: Any, args: argparse.Namespace) -> int:
    record = _unwrap_value_envelope(record)
    _apply_widget_text_coalesce(record)
    fields = _read_fields(args)
    fmt = "json" if _CLI_FORCE_JSON else (getattr(args, "format", None) or "json")
    print(_format_output(record, fields, fmt))
    return EXIT_SUCCESS


# --- Area cache + traversal helpers ---------------------------------------


def _get_area(mural_id: str, area_id: str) -> dict[str, Any]:
    """Return area metadata for ``area_id``, fetching it on cache miss."""
    return _get_area_impl(
        mural_id,
        area_id,
        area_cache=_area_cache,
        authenticated_request=_authenticated_request,
        MuralAPIError=MuralAPIError,
    )


def _walk_area_chain(mural_id: str, parent_id: str | None) -> list[dict[str, Any]]:
    """Return the chain of ancestor areas starting at ``parent_id``.

    The chain is ordered nearest-ancestor first.  Stops at the first node
    without a ``parentId``.  A defensive depth cap of 32 prevents infinite
    loops in pathological responses.
    """
    chain: list[dict[str, Any]] = []
    seen: set[str] = set()
    current = parent_id
    depth = 0
    while current and depth < 32:
        if current in seen:
            break
        seen.add(current)
        try:
            area = _get_area(mural_id, current)
        except MuralAPIError as exc:
            LOGGER.warning("area chain walk stopped: %s", _redact(str(exc)))
            break
        chain.append(area)
        current = area.get("parentId") if isinstance(area, dict) else None
        depth += 1
    return chain


_AREA_FALLBACK_LOGGED: set[str] = set()


def _log_area_fallback_once(mural_id: str) -> None:
    _log_area_fallback_once_impl(
        mural_id,
        logged_mural_ids=_AREA_FALLBACK_LOGGED,
        logger=LOGGER,
    )


def _list_areas_with_widget_fallback(
    mural_id: str, **paginate_kwargs: Any
) -> list[dict[str, Any]]:
    """List areas, transparently falling back to ``/widgets?type=area`` on 404."""
    return _list_areas_with_widget_fallback_impl(
        mural_id,
        paginate=_paginate,
        area_cache=_area_cache,
        log_area_fallback_once=_log_area_fallback_once,
        MuralAPIError=MuralAPIError,
        **paginate_kwargs,
    )


def _get_area_with_widget_fallback(mural_id: str, area_id: str) -> dict[str, Any]:
    """Get an area, transparently falling back to ``/widgets/{id}`` on 404."""
    return _get_area_with_widget_fallback_impl(
        mural_id,
        area_id,
        get_area=_get_area,
        authenticated_request=_authenticated_request,
        area_cache=_area_cache,
        log_area_fallback_once=_log_area_fallback_once,
        MuralAPIError=MuralAPIError,
    )


_PROBE_TEXT = "[probe-before-bulk]"
_PROBE_SHAPE = "rectangle"


def _area_probe(mural_id: str, area_id: str) -> dict[str, Any]:
    """Create a disposable sticky-note probe inside ``area_id`` and diagnose."""
    return _area_probe_impl(
        mural_id,
        area_id,
        get_area_with_widget_fallback=_get_area_with_widget_fallback,
        authenticated_request=_authenticated_request,
        resolve_widget_id=_resolve_widget_id,
        get_widget_with_context=_get_widget_with_context,
        area_probe_verdict=_area_probe_verdict,
        logger=LOGGER,
        redact=_redact,
        MuralAPIError=MuralAPIError,
        MuralError=MuralError,
        probe_text=_PROBE_TEXT,
        probe_shape=_PROBE_SHAPE,
    )


def _get_widget_with_context(mural_id: str, widget_id: str) -> dict[str, Any]:
    """Return the widget plus its area_chain, siblings, and cluster envelope."""
    return _get_widget_with_context_impl(
        mural_id,
        widget_id,
        authenticated_request=_authenticated_request,
        paginate=_paginate,
        walk_area_chain=_walk_area_chain,
    )


def _list_widgets_with_context(
    mural_id: str,
    *,
    widget_type: str | None = None,
    parent_id: str | None = None,
    limit: int | None = None,
    page_size: int | None = None,
) -> list[dict[str, Any]]:
    """List widgets and attach an ``area_chain`` to each entry."""
    return _list_widgets_with_context_impl(
        mural_id,
        paginate=_paginate,
        walk_area_chain=_walk_area_chain,
        widget_type=widget_type,
        parent_id=parent_id,
        limit=limit,
        page_size=page_size,
    )


# --- Tag manifest helper --------------------------------------------------

from ._tag_helpers import (  # noqa: E402
    _assert_widget_has_author_tag_impl,
    _create_tag_impl,
    _ensure_reserved_author_tag_impl,
    _ensure_tag_manifest_impl,
    _is_reserved_tag_id_impl,
    _is_tag_cap_error_impl,
    _maybe_apply_author_tag_impl,
    _merge_tags_impl,
    _resolve_widget_id_impl,
    _tag_merge_backoff_seconds_impl,
    _widget_tag_ids_impl,
)

_TAG_CAP_HINTS: tuple[str, ...] = (
    "tag limit",
    "tag cap",
    "maximum number of tags",
    "too many tags",
)


def _is_tag_cap_error(exc: MuralAPIError) -> bool:
    return _is_tag_cap_error_impl(exc, tag_cap_hints=_TAG_CAP_HINTS)


def _create_tag(mural_id: str, text: str, color: str | None = None) -> dict[str, Any]:
    return _create_tag_impl(
        mural_id,
        text,
        color,
        validate_tag_text=_validate_tag_text,
        authenticated_request=_authenticated_request,
        is_tag_cap_error=_is_tag_cap_error,
        MuralAPIError=MuralAPIError,
        MuralValidationError=MuralValidationError,
    )


def _ensure_tag_manifest(
    mural_id: str, manifest: list[dict[str, Any]]
) -> dict[str, str]:
    """Idempotently materialise ``manifest`` and return ``{text -> tag_id}``.

    ``manifest`` is a list of ``{"text": str, "color": str?}`` records.  The
    helper fetches existing tags once, creates only the missing entries, and
    returns the combined mapping.  Subsequent calls with the same manifest
    issue zero POSTs.
    """
    return _ensure_tag_manifest_impl(
        mural_id,
        manifest,
        paginate=_paginate,
        create_tag=_create_tag,
        MuralAPIError=MuralAPIError,
        MuralValidationError=MuralValidationError,
    )


def _widget_tag_ids(widget: Any) -> list[str]:
    """Normalize a widget's ``tags`` field to a list of tag-id strings.

    Mural may return tag ids as bare strings or as dict records. This helper
    collapses both shapes so callers can compare against expected ids.
    Single-resource Mural GETs wrap the widget in ``{"value": {...}}``; this
    helper unwraps that envelope before reading ``tags`` so guard checks fed
    raw ``_authenticated_request`` responses do not produce false negatives.
    """
    return _widget_tag_ids_impl(widget)


def _tag_merge_backoff_seconds() -> float:
    """Return a jittered backoff delay for ``_merge_tags`` retries.

    Uses :mod:`secrets` (already imported for OAuth) to avoid pulling in
    :mod:`random` solely for jitter. Range is 50-200ms inclusive.
    """
    return _tag_merge_backoff_seconds_impl(
        randbelow=secrets.randbelow,
        backoff_min_ms=_TAG_MERGE_BACKOFF_MIN_MS,
        backoff_max_ms=_TAG_MERGE_BACKOFF_MAX_MS,
    )


def _merge_tags(
    mural_id: str,
    widget_id: str,
    *,
    additions: list[str] | tuple[str, ...] = (),
    removals: list[str] | tuple[str, ...] = (),
    max_retries: int = _TAG_MERGE_MAX_RETRIES,
) -> dict[str, Any]:
    """Read-modify-write the ``tags`` array on a widget with bounded retries.

    The Mural widget PATCH endpoint replaces the ``tags`` array wholesale and
    exposes no ETag/If-Match header, so concurrent writers can clobber each
    other. This helper fetches the current tag set, applies ``additions`` and
    ``removals`` as set operations, PATCHes the new array, and re-reads to
    confirm convergence. Up to ``max_retries`` attempts are made with a
    50-200ms jittered delay between them. On exhaustion :class:`MuralTagMergeConflict`
    is raised so callers can surface a structured envelope.
    """
    return _merge_tags_impl(
        mural_id,
        widget_id,
        additions=additions,
        removals=removals,
        max_retries=max_retries,
        authenticated_request=_authenticated_request,
        widget_tag_ids=_widget_tag_ids,
        patch_widget_or_disambiguate_404=_patch_widget_or_disambiguate_404,
        session_manifest_record=_session_manifest_record,
        tag_merge_backoff_seconds=_tag_merge_backoff_seconds,
        MuralTagMergeConflict=MuralTagMergeConflict,
    )


def _ensure_reserved_author_tag(mural_id: str) -> str:
    """Return the tag id for ``authored-by-ai`` on ``mural_id`` (creating it)."""
    return _ensure_reserved_author_tag_impl(
        mural_id,
        ensure_tag_manifest=_ensure_tag_manifest,
        authored_by_ai_tag_text=_AUTHORED_BY_AI_TAG_TEXT,
    )


def _resolve_widget_id(record: Any) -> str | None:
    """Best-effort extraction of a widget id from a create response payload."""
    return _resolve_widget_id_impl(record)


def _maybe_apply_author_tag(
    mural_id: str, record: Any, *, skip: bool
) -> dict[str, Any] | None:
    """Attach the reserved ``authored-by-ai`` tag to a freshly-created widget.

    Best-effort: returns the merge result on success, ``None`` when skipped
    or when the widget id cannot be resolved, and emits a stderr warning on
    soft failure so the surrounding create operation is not rolled back.
    """
    return _maybe_apply_author_tag_impl(
        mural_id,
        record,
        skip=skip,
        resolve_widget_id=_resolve_widget_id,
        ensure_reserved_author_tag=_ensure_reserved_author_tag,
        merge_tags=_merge_tags,
        MuralError=MuralError,
    )


def _assert_widget_has_author_tag(mural_id: str, widget_id: str) -> None:
    """Raise :class:`MuralHumanAuthoredProtected` if the AI tag is absent."""
    _assert_widget_has_author_tag_impl(
        mural_id,
        widget_id,
        ensure_reserved_author_tag=_ensure_reserved_author_tag,
        authenticated_request=_authenticated_request,
        widget_tag_ids=_widget_tag_ids,
        MuralHumanAuthoredProtected=MuralHumanAuthoredProtected,
    )


def _is_reserved_tag_id(mural_id: str, tag_id: str) -> bool:
    """Return ``True`` when ``tag_id`` matches a reserved tag (literal or prefix)."""
    return _is_reserved_tag_id_impl(
        mural_id,
        tag_id,
        paginate=_paginate,
        is_reserved_tag_text=_is_reserved_tag_text,
    )


# --- AABB rect helpers and spatial queries -------------------------------

# Carved into ``_geometry`` for testability and module size. Re-imported
# here so the package surface (and ``mural.<symbol>`` test access) is
# unchanged.

from ._area_helpers import (  # noqa: E402,F401
    _area_probe_impl,
    _get_area_impl,
    _get_area_with_widget_fallback_impl,
    _get_widget_with_context_impl,
    _list_areas_with_widget_fallback_impl,
    _list_widgets_with_context_impl,
    _log_area_fallback_once_impl,
)
from ._geometry import (  # noqa: E402,F401
    Rect,
    _area_probe_verdict,
    _shape_to_rect,
    arrow_graph_summary,
    build_arrow_graph,
    cluster_widgets,
    pairwise_overlaps,
    point_in_rect,
    ray_cast_pip,
    rect_contains_rect,
    rect_intersection,
    rects_overlap,
    safe_rect,
    shoelace_area,
    sort_along_axis,
    widget_center,
    widgets_in_region,
    widgets_in_shape,
)
from ._layout import (  # noqa: E402,F401
    _LAYOUT_DEFAULT_CELL_HEIGHT,
    _LAYOUT_DEFAULT_CELL_WIDTH,
    _LAYOUT_DEFAULT_GUTTER,
    _LAYOUT_DEFAULT_ORIGIN,
    _LAYOUT_FUNCS,
    _LAYOUT_HASH_PREFIX,
    _area_capacity,
    _area_overflow,
    _execute_layout,
    _existing_layout_hashes,
    _layout_canonical_widget,
    _layout_cluster,
    _layout_column,
    _layout_envelope,
    _layout_grid,
    _layout_hash,
    _layout_row,
    _repair_tag_drift,
    _session_manifest_record,
    _SessionManifest,
)

# --- Phase 4 composites: confirmation gate, find, sweep, summary, DT ------

# In-process registry of pending confirmation previews. Keyed by an opaque
# UUID returned in a ``confirmation_required`` envelope; consumed when the
# caller re-invokes with ``confirmed_id`` matching the preview.
_PENDING_CONFIRMATIONS: dict[str, dict[str, Any]] = {}
_CONFIRMATION_TTL_S = 600.0


def _confirmation_register(
    *, tool: str, arguments: dict[str, Any], candidates: list[dict[str, Any]]
) -> str:
    """Register a preview and return its ``preview_id``."""
    preview_id = uuid.uuid4().hex
    _PENDING_CONFIRMATIONS[preview_id] = {
        "tool": tool,
        "arguments": dict(arguments),
        "candidates": list(candidates),
        "expires_at": time.time() + _CONFIRMATION_TTL_S,
    }
    # Light cleanup of expired entries to bound the dict.
    now = time.time()
    expired = [k for k, v in _PENDING_CONFIRMATIONS.items() if v["expires_at"] < now]
    for k in expired:
        _PENDING_CONFIRMATIONS.pop(k, None)
    return preview_id


def _confirmation_consume(*, tool: str, confirmed_id: str) -> dict[str, Any]:
    """Return the registered preview for ``confirmed_id`` or raise."""
    entry = _PENDING_CONFIRMATIONS.pop(confirmed_id, None)
    if entry is None:
        raise MuralValidationError(
            "confirmation_id_mismatch: no pending preview for this id"
        )
    if entry["expires_at"] < time.time():
        raise MuralValidationError("confirmation_id_mismatch: preview expired")
    if entry["tool"] != tool:
        raise MuralValidationError(
            "confirmation_id_mismatch: tool name does not match preview"
        )
    return entry


def _trigram_score(a: str, b: str) -> float:
    """Return a 0..1 trigram-overlap similarity for ``a`` vs ``b``.

    Cheap stdlib-only fuzzy match used by :func:`_tool_mural_find` to rank
    candidates without taking a SequenceMatcher dependency.
    """
    if not a or not b:
        return 0.0
    a_l = a.lower().strip()
    b_l = b.lower().strip()
    if a_l == b_l:
        return 1.0

    def _tri(s: str) -> set[str]:
        padded = f"  {s}  "
        return {padded[i : i + 3] for i in range(len(padded) - 2)}

    sa = _tri(a_l)
    sb = _tri(b_l)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / float(len(sa | sb))


def _tool_mural_find(arguments: dict[str, Any]) -> Any:
    """Search murals by name with client-side fuzzy ranking.

    Falls back to listing the workspace and scoring titles locally; the
    server-side ``searchmurals`` endpoint is not yet wrapped (Phase 5
    Step 5.3). Returns ``{candidates, confirmation_required: true}``.
    """
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    query = arguments.get("query")
    if not isinstance(query, str) or not query.strip():
        raise MCPInvalidParamsError("query is required")
    threshold = float(arguments.get("min_score", 0.4))
    limit = int(arguments.get("limit", 10))
    records = list(_paginate("GET", f"/workspaces/{workspace_id}/murals"))
    scored: list[dict[str, Any]] = []
    for r in records:
        title = r.get("title") or r.get("name") or ""
        score = _trigram_score(query, title)
        if score >= threshold:
            scored.append(
                {
                    "id": r.get("id"),
                    "title": title,
                    "score": round(score, 4),
                    "last_modified": r.get("updatedOn") or r.get("lastModified"),
                    "owner": r.get("createdBy") or r.get("owner"),
                }
            )
    scored.sort(key=lambda x: x["score"], reverse=True)
    return {
        "candidates": scored[:limit],
        "confirmation_required": True,
        "search_endpoint_pending": True,
    }


def _tool_workspace_summary(arguments: dict[str, Any]) -> Any:
    """Aggregate workspace-wide counts for read-only oversight."""
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    rooms = list(_paginate("GET", f"/workspaces/{workspace_id}/rooms"))
    murals = list(_paginate("GET", f"/workspaces/{workspace_id}/murals"))
    archived = sum(1 for m in murals if (m.get("status") or "").lower() == "archived")
    return {
        "workspace_id": workspace_id,
        "rooms": len(rooms),
        "murals": len(murals),
        "murals_archived": archived,
        "murals_active": len(murals) - archived,
    }


def _tool_parking_lot_sweep(arguments: dict[str, Any]) -> Any:
    """Discover parked widgets via tag/area lookup. Read-only."""
    mural_id = _validate_mural_id(arguments.get("mural"))
    area_id = arguments.get("area")
    tag_text = arguments.get("tag", "parking-lot")
    widgets = list(_paginate("GET", f"/murals/{mural_id}/widgets"))
    # Resolve tag id once; if absent on the mural, treat as empty manifest.
    try:
        manifest = _ensure_tag_manifest(mural_id, [{"text": tag_text}])
        tag_id = manifest.get(tag_text)
    except MuralError:
        tag_id = None
    parked: list[dict[str, Any]] = []
    for w in widgets:
        wid_area = w.get("areaId")
        wid_tags = _widget_tag_ids(w)
        match_area = bool(area_id) and wid_area == area_id
        match_tag = bool(tag_id) and tag_id in wid_tags
        if match_area or match_tag:
            parked.append(
                {
                    "id": w.get("id"),
                    "type": w.get("type"),
                    "area_id": wid_area,
                    "tags": list(wid_tags),
                }
            )
    return {
        "mural_id": mural_id,
        "tag": tag_text,
        "area_id": area_id,
        "count": len(parked),
        "items": parked,
    }


def _load_dt_sections_map(
    override_path: str | None = None,
) -> dict[str, dict[str, Any]]:
    """Load the bundled DT section map and shallow-merge an optional override.

    Reads ``assets/dt-sections.default.yml`` adjacent to this script and, when
    ``override_path`` is provided and exists, deep-merges entries from that
    YAML file. Override merge is by exact ``(method, section)`` key. Raises
    :class:`MuralValidationError` on schema violations (fail-closed).
    """
    here = pathlib.Path(__file__).resolve().parent
    default_path = here.parent / "assets" / "dt-sections.default.yml"
    if not default_path.exists():
        raise MuralValidationError(f"dt-sections default missing at {default_path}")
    try:
        defaults = _parse_simple_yaml(default_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise MuralValidationError(
            f"dt_section_mapping_invalid: failed to parse defaults: {exc}"
        ) from exc
    if not isinstance(defaults, dict) or "methods" not in defaults:
        raise MuralValidationError(
            "dt_section_mapping_invalid: defaults missing 'methods'"
        )
    merged: dict[str, dict[str, Any]] = {}
    for method_key, method_val in (defaults.get("methods") or {}).items():
        if not isinstance(method_val, dict):
            continue
        merged[str(method_key)] = dict(method_val)
    if override_path and pathlib.Path(override_path).exists():
        try:
            override = _parse_simple_yaml(
                pathlib.Path(override_path).read_text(encoding="utf-8")
            )
        except Exception as exc:
            raise MuralValidationError(
                f"dt_section_mapping_invalid: override parse failed: {exc}"
            ) from exc
        if not isinstance(override, dict):
            raise MuralValidationError(
                "dt_section_mapping_invalid: override must be a mapping"
            )
        for method_key, method_val in (override.get("methods") or {}).items():
            if not isinstance(method_val, dict):
                continue
            merged.setdefault(str(method_key), {}).update(method_val)
    return merged


def _parse_simple_yaml(text: str) -> Any:
    """Minimal YAML parser for the DT section map (mappings + scalars).

    Supports nested key: value blocks, comments, integer/float scalars, and
    inline ``{x: 0, y: 0}`` flow mappings. Sufficient for the Layer-B
    ``dt-sections.default.yml`` schema; not a general-purpose YAML parser.
    """
    lines = [ln.rstrip() for ln in text.splitlines()]
    # Strip comments and blank lines.
    cleaned: list[tuple[int, str]] = []
    for raw in lines:
        stripped = raw.split("#", 1)[0].rstrip()
        if not stripped.strip():
            continue
        indent = len(stripped) - len(stripped.lstrip(" "))
        cleaned.append((indent, stripped.lstrip(" ")))

    pos = 0

    def parse_block(min_indent: int) -> dict[str, Any]:
        nonlocal pos
        result: dict[str, Any] = {}
        while pos < len(cleaned):
            indent, content = cleaned[pos]
            if indent < min_indent:
                break
            if indent > min_indent:
                # Ignore stray over-indented lines defensively.
                pos += 1
                continue
            if ":" not in content:
                pos += 1
                continue
            key, _, value = content.partition(":")
            key = key.strip()
            value = value.strip()
            pos += 1
            if value:
                result[key] = _parse_yaml_scalar(value)
            else:
                # Block child.
                if pos < len(cleaned) and cleaned[pos][0] > min_indent:
                    result[key] = parse_block(cleaned[pos][0])
                else:
                    result[key] = {}
        return result

    if not cleaned:
        return {}
    return parse_block(cleaned[0][0])


def _parse_yaml_scalar(value: str) -> Any:
    """Parse a YAML scalar including small inline flow mappings."""
    if value.startswith("{") and value.endswith("}"):
        # Inline flow mapping like {x: 0, y: 1000, layout: free}
        inner = value[1:-1].strip()
        if not inner:
            return {}
        result: dict[str, Any] = {}
        for part in inner.split(","):
            if ":" not in part:
                continue
            k, _, v = part.partition(":")
            result[k.strip()] = _parse_yaml_scalar(v.strip())
        return result
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [_parse_yaml_scalar(p.strip()) for p in inner.split(",")]
    if (value.startswith("'") and value.endswith("'")) or (
        value.startswith('"') and value.endswith('"')
    ):
        return value[1:-1]
    if value in ("true", "True"):
        return True
    if value in ("false", "False"):
        return False
    if value in ("null", "~", ""):
        return None
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def _slugify_label(text: str) -> str:
    """Return a lowercase, dash-separated slug suitable for reserved tags."""
    cleaned = "".join(c.lower() if c.isalnum() else "-" for c in text)
    while "--" in cleaned:
        cleaned = cleaned.replace("--", "-")
    return cleaned.strip("-") or "cluster"


def _new_lineage_run_id() -> str:
    # 26-char uppercase hex acts as a stdlib-only ULID surrogate so this skill
    # avoids a third-party `ulid` dependency. Cryptographic randomness keeps
    # the run identifier collision-resistant across composite invocations.
    return secrets.token_hex(13).upper()


def _lineage_prefix(method: int, section: str, run_id: str) -> str:
    """Format a Design Thinking lineage marker for a widget title."""
    return f"[dt:method={method} section={section} run={run_id}]"


def _apply_lineage_prefix(
    widget_payload: dict[str, Any], prefix: str
) -> dict[str, Any]:
    """Prepend ``prefix`` to ``widget_payload['title']`` unless already marked.

    Mutates ``widget_payload`` in place and returns it. If the existing title
    already starts with ``[dt:`` the marker is left untouched so repeated
    invocations stay idempotent and never nest markers.
    """
    if not isinstance(widget_payload, dict):
        return widget_payload
    existing = widget_payload.get("title")
    if isinstance(existing, str) and existing.lstrip().startswith("[dt:"):
        return widget_payload
    if isinstance(existing, str) and existing:
        widget_payload["title"] = f"{prefix} {existing}"
    else:
        widget_payload["title"] = prefix
    return widget_payload


_LINEAGE_PREFIX_PATTERN = re.compile(
    r"^\s*\[\s*dt\s*:"
    r"(?:[^\]]*?\bmethod\s*=\s*(?P<method>\d+))?"
    r"(?:[^\]]*?\bsection\s*=\s*(?P<section>[^\s\]]+))?"
    r"(?:[^\]]*?\brun\s*=\s*(?P<run>[A-Za-z0-9]+))?"
    r"[^\]]*\]"
)


def _parse_lineage_prefix(title: str) -> dict[str, Any] | None:
    """Return ``{method, section, run_id}`` parsed from a lineage marker.

    Returns ``None`` when ``title`` is not a string or carries no ``[dt:...]``
    marker. The parser is tolerant of extra whitespace and missing keys; any
    absent field is reported as ``None``.
    """
    if not isinstance(title, str) or not title:
        return None
    match = _LINEAGE_PREFIX_PATTERN.match(title)
    if not match:
        return None
    method_raw = match.group("method")
    try:
        method_value: int | None = int(method_raw) if method_raw is not None else None
    except ValueError:
        method_value = None
    return {
        "method": method_value,
        "section": match.group("section"),
        "run_id": match.group("run"),
    }


_UX_BOARD_AREAS: list[dict[str, Any]] = [
    {"label": "JTBD", "x": 0, "y": 0, "width": 4000, "height": 3000},
    {"label": "Journey Stages", "x": 4500, "y": 0, "width": 4000, "height": 3000},
    {"label": "Pain Points", "x": 9000, "y": 0, "width": 4000, "height": 3000},
    {
        "label": "Opportunities",
        "x": 13500,
        "y": 0,
        "width": 4000,
        "height": 3000,
    },
    {
        "label": "Accessibility Requirements",
        "x": 18000,
        "y": 0,
        "width": 4000,
        "height": 3000,
    },
]


def _tool_bootstrap_ux_board(arguments: dict[str, Any]) -> Any:
    """Bootstrap a UX research board on an existing mural.

    Adds the five UX areas (JTBD, Journey Stages, Pain Points,
    Opportunities, Accessibility Requirements) when not already present.
    Idempotent by area title: existing areas with the same title are
    preserved and reported with ``idempotent: True``.
    """
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    mural_id = _validate_mural_id(arguments.get("mural"))
    existing_titles: set[str] = set()
    try:
        for area in _paginate("GET", f"/murals/{mural_id}/areas"):
            if isinstance(area, dict):
                title = area.get("title")
                if isinstance(title, str):
                    existing_titles.add(title)
    except MuralError:
        pass
    _ensure_tag_manifest(mural_id, [{"text": "ux-board"}])
    created_areas: list[dict[str, Any]] = []
    any_new = False
    for spec in _UX_BOARD_AREAS:
        label = str(spec["label"])
        if label in existing_titles:
            created_areas.append(
                {
                    "id": None,
                    "label": label,
                    "anchor_widget_id": None,
                    "idempotent": True,
                }
            )
            continue
        any_new = True
        body = {
            "title": label,
            "x": spec["x"],
            "y": spec["y"],
            "width": spec["width"],
            "height": spec["height"],
            "type": "free",
        }
        try:
            area = _authenticated_request(
                "POST", f"/murals/{mural_id}/areas", json_body=body
            )
        except MuralError as exc:
            created_areas.append({"label": label, "error": str(exc)})
            continue
        area_id = area.get("id") if isinstance(area, dict) else None
        created_areas.append({"id": area_id, "label": label, "anchor_widget_id": None})
    return {
        "mural_id": mural_id,
        "workspace_id": workspace_id,
        "idempotent": not any_new,
        "areas": created_areas,
    }


def _tool_bootstrap_dt_board(arguments: dict[str, Any]) -> Any:
    """Bootstrap a Design Thinking board for ``method`` (1..9).

    Idempotent by ``dt-method:<n>`` reserved tag: if a mural in
    ``workspace`` already carries that tag, the existing mural is returned.
    Otherwise a new mural is created and tagged with ``dt-method:<n>``;
    one area per section in the default DT map is created and seeded with
    ``dt-section:<name>`` reserved tags.
    """
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    room_id = arguments.get("room")
    if not isinstance(room_id, str) or not room_id.strip():
        raise MCPInvalidParamsError("room is required")
    method = arguments.get("method")
    if not isinstance(method, int) or method < 1 or method > 9:
        raise MCPInvalidParamsError("method must be an integer 1..9")
    sections_map = _load_dt_sections_map(arguments.get("override_path"))
    method_block = sections_map.get(str(method)) or {}
    sections = method_block.get("sections") or {}
    method_tag = f"dt-method:{method}"
    # Idempotency: scan murals in workspace for dt-method:<n> tag.
    existing_id: str | None = None
    for m in _paginate("GET", f"/workspaces/{workspace_id}/murals"):
        mid = m.get("id")
        if not mid:
            continue
        try:
            tags = _authenticated_request("GET", f"/murals/{mid}/tags") or []
        except MuralError:
            continue
        if isinstance(tags, dict):
            tags = tags.get("value") or tags.get("data") or []
        for t in tags or []:
            if isinstance(t, dict) and t.get("text") == method_tag:
                existing_id = mid
                break
        if existing_id:
            break
    if existing_id:
        return {
            "mural_id": existing_id,
            "method": method,
            "idempotent": True,
            "areas": [],
            "run_id": None,
        }
    run_id = _new_lineage_run_id()
    title = arguments.get("title") or f"DT Method {method}"
    board_body: dict[str, Any] = {"title": title}
    _apply_lineage_prefix(board_body, _lineage_prefix(method, "board", run_id))
    body = {
        "title": board_body["title"],
        "roomId": room_id,
        "workspaceId": workspace_id,
    }
    created = _authenticated_request(
        "POST", f"/workspaces/{workspace_id}/murals", json_body=body
    )
    mural_id = created.get("id") if isinstance(created, dict) else None
    if not mural_id:
        raise MuralAPIError("mural creation returned no id")
    _ensure_tag_manifest(mural_id, [{"text": method_tag}])
    created_areas: list[dict[str, Any]] = []
    for section_name, section_meta in sections.items():
        if not isinstance(section_meta, dict):
            continue
        area_body: dict[str, Any] = {
            "title": section_name,
            "x": section_meta.get("x", 0),
            "y": section_meta.get("y", 0),
            "width": section_meta.get("width", 4000),
            "height": section_meta.get("height", 3000),
            "type": section_meta.get("layout", "free"),
        }
        _apply_lineage_prefix(area_body, _lineage_prefix(method, section_name, run_id))
        try:
            area = _authenticated_request(
                "POST", f"/murals/{mural_id}/areas", json_body=area_body
            )
        except MuralError as exc:
            created_areas.append({"section": section_name, "error": str(exc)})
            continue
        created_areas.append({"section": section_name, "area": area})
        _ensure_tag_manifest(mural_id, [{"text": f"dt-section:{section_name}"}])
    return {
        "mural_id": mural_id,
        "method": method,
        "idempotent": False,
        "areas": created_areas,
        "run_id": run_id,
    }


def _tool_populate_dt_section(arguments: dict[str, Any]) -> Any:
    """Populate an area on a DT board with widgets and reserved tags."""
    mural_id = _validate_mural_id(arguments.get("mural"))
    method = arguments.get("method")
    if not isinstance(method, int) or method < 1 or method > 9:
        raise MCPInvalidParamsError("method must be an integer 1..9")
    section = arguments.get("section")
    if not isinstance(section, str) or not section.strip():
        raise MCPInvalidParamsError("section is required")
    items = arguments.get("items")
    if not isinstance(items, list) or not items:
        raise MCPInvalidParamsError("items must be a non-empty array")
    area_id = arguments.get("area")
    if not isinstance(area_id, str) or not area_id.strip():
        raise MCPInvalidParamsError(
            "area is required (resolve via mural_area_list + section tag)"
        )
    section_tag = f"dt-section:{section}"
    method_tag = f"dt-method:{method}"
    _ensure_tag_manifest(mural_id, [{"text": section_tag}, {"text": method_tag}])
    widgets: list[dict[str, Any]] = []
    for item in items:
        if isinstance(item, str):
            widgets.append({"type": "sticky-note", "text": item})
        elif isinstance(item, dict):
            widgets.append({"type": item.get("type", "sticky-note"), **item})
    run_id = _new_lineage_run_id()
    lineage = _lineage_prefix(method, section, run_id)
    for widget in widgets:
        _apply_lineage_prefix(widget, lineage)
    layout_args = {
        "mural": mural_id,
        "area": area_id,
        "widgets": widgets,
        "cell_width": arguments.get("cell_width"),
        "cell_height": arguments.get("cell_height"),
        "gutter": arguments.get("gutter"),
    }
    if arguments.get("origin"):
        layout_args["origin"] = arguments.get("origin")
    layout_args = {k: v for k, v in layout_args.items() if v is not None}
    placement = _tool_layout("cluster", layout_args)
    return {
        "mural_id": mural_id,
        "method": method,
        "section": section,
        "area_id": area_id,
        "placement": placement,
        "run_id": run_id,
    }


def _tool_create_affinity_cluster(arguments: dict[str, Any]) -> Any:
    """Place ``clusters`` (pre-clustered items) into an affinity area.

    LLM-driven clustering is out of scope for this stdlib-only skill;
    callers must pass already-grouped ``clusters`` of the form
    ``[{label, items: [...]}]``. Each cluster is laid out via
    :func:`_tool_layout` (``cluster``) within a sub-region and tagged
    ``dt-method:3``, ``dt-section:affinity``, ``cluster-label:<slug>``.
    """
    mural_id = _validate_mural_id(arguments.get("mural"))
    area_id = arguments.get("area")
    if not isinstance(area_id, str) or not area_id.strip():
        raise MCPInvalidParamsError("area is required")
    clusters = arguments.get("clusters")
    if not isinstance(clusters, list) or not clusters:
        raise MCPInvalidParamsError("clusters must be a non-empty array")
    placements: list[dict[str, Any]] = []
    next_origin_x = 0.0
    run_id = _new_lineage_run_id()
    lineage = _lineage_prefix(3, "affinity", run_id)
    for cluster in clusters:
        if not isinstance(cluster, dict):
            continue
        label = cluster.get("label")
        members = cluster.get("items") or []
        if not isinstance(label, str) or not isinstance(members, list) or not members:
            continue
        slug = _slugify_label(label)
        widget_records: list[dict[str, Any]] = []
        cluster_tag = f"cluster-label:{slug}"
        for m in members:
            if isinstance(m, str):
                widget_records.append(
                    {
                        "type": "sticky-note",
                        "text": m,
                        "tags": ["dt-method:3", "dt-section:affinity", cluster_tag],
                    }
                )
            elif isinstance(m, dict):
                tags = list(m.get("tags") or [])
                for t in ("dt-method:3", "dt-section:affinity", cluster_tag):
                    if t not in tags:
                        tags.append(t)
                widget_records.append({**m, "tags": tags})
        for record in widget_records:
            _apply_lineage_prefix(record, lineage)
        # Ensure reserved tags exist on the mural before placement.
        _ensure_tag_manifest(
            mural_id,
            [
                {"text": "dt-method:3"},
                {"text": "dt-section:affinity"},
                {"text": cluster_tag},
            ],
        )
        layout_args = {
            "mural": mural_id,
            "area": area_id,
            "widgets": widget_records,
            "origin": [next_origin_x, 0.0],
        }
        try:
            placement = _tool_layout("cluster", layout_args)
        except MuralAreaCapacityExceeded:
            raise
        except MuralError as exc:
            placements.append({"label": label, "error": str(exc)})
            continue
        placements.append({"label": label, "slug": slug, "placement": placement})
        # Advance origin to the right of the previous cluster envelope.
        env = placement.get("computed_metadata", {}).get("envelope", {})
        next_origin_x += float(env.get("width", 0.0)) + 200.0
    return {
        "mural_id": mural_id,
        "area_id": area_id,
        "clusters": placements,
        "run_id": run_id,
    }


def _tool_repair_tag_drift(arguments: dict[str, Any]) -> Any:
    """Re-assert intended reserved tags on widgets tracked this session."""
    mural_id = _validate_mural_id(arguments.get("mural"))
    repaired = _repair_tag_drift(mural_id)
    return {"mural_id": mural_id, "repaired": repaired}


def _tool_mural_lineage_lookup(arguments: dict[str, Any]) -> Any:
    """Return widgets whose title carries a Design Thinking lineage marker.

    Filters are optional and combine with AND semantics: a widget is returned
    only when every supplied filter (``run_id``, ``method``, ``section``)
    matches its parsed marker.
    """
    mural_id = _validate_mural_id(arguments.get("mural_id"))
    run_filter = arguments.get("run_id")
    if run_filter is not None and not isinstance(run_filter, str):
        raise MCPInvalidParamsError("run_id must be a string when provided")
    method_filter = arguments.get("method")
    if method_filter is not None and not isinstance(method_filter, int):
        raise MCPInvalidParamsError("method must be an integer when provided")
    section_filter = arguments.get("section")
    if section_filter is not None and not isinstance(section_filter, str):
        raise MCPInvalidParamsError("section must be a string when provided")
    matches: list[dict[str, Any]] = []
    for widget in _paginate("GET", f"/murals/{mural_id}/widgets"):
        if not isinstance(widget, dict):
            continue
        title = widget.get("title")
        lineage = _parse_lineage_prefix(title) if isinstance(title, str) else None
        if lineage is None:
            continue
        if run_filter is not None and lineage.get("run_id") != run_filter:
            continue
        if method_filter is not None and lineage.get("method") != method_filter:
            continue
        if section_filter is not None and lineage.get("section") != section_filter:
            continue
        matches.append(
            {
                "widget_id": widget.get("id"),
                "title": title,
                "lineage": lineage,
            }
        )
    return {"mural_id": mural_id, "matches": matches}


# --- Phase 4 CLI handlers -------------------------------------------------


def _parse_origin_arg(value: str | None) -> list[float] | None:
    """Parse ``--origin "x,y"`` into ``[x, y]``; ``None`` when unset."""
    if value is None:
        return None
    parts = [p.strip() for p in value.split(",")]
    if len(parts) != 2:
        raise MuralValidationError("--origin must be 'x,y'")
    try:
        return [float(parts[0]), float(parts[1])]
    except ValueError as exc:
        raise MuralValidationError("--origin values must be numeric") from exc


def _layout_cli_arguments(args: argparse.Namespace) -> dict[str, Any]:
    """Build the ``arguments`` dict from a layout CLI namespace."""
    payload: dict[str, Any] = {
        "mural": args.mural,
        "area": args.area,
        "widgets": _parse_json_arg(_load_payload_file(args.widgets), "--widgets"),
    }
    for src, dst in (
        ("cell_width", "cell_width"),
        ("cell_height", "cell_height"),
        ("gutter", "gutter"),
    ):
        v = getattr(args, src, None)
        if v is not None:
            payload[dst] = v
    origin = _parse_origin_arg(getattr(args, "origin", None))
    if origin is not None:
        payload["origin"] = origin
    if hasattr(args, "columns") and args.columns is not None:
        payload["columns"] = args.columns
    return payload


def _cmd_layout_grid(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _emit_record(_tool_layout("grid", _layout_cli_arguments(args)), args)


def _cmd_layout_cluster(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _emit_record(_tool_layout("cluster", _layout_cli_arguments(args)), args)


def _cmd_layout_column(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _emit_record(_tool_layout("column", _layout_cli_arguments(args)), args)


def _cmd_layout_row(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _emit_record(_tool_layout("row", _layout_cli_arguments(args)), args)


def _cmd_compose_bootstrap_dt_board(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {
        "workspace": args.workspace,
        "room": args.room,
        "method": args.method,
    }
    if getattr(args, "title", None):
        payload["title"] = args.title
    if getattr(args, "override_path", None):
        payload["override_path"] = args.override_path
    return _emit_record(_tool_bootstrap_dt_board(payload), args)


def _cmd_compose_bootstrap_ux_board(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {
        "workspace": args.workspace,
        "mural": args.mural,
    }
    return _emit_record(_tool_bootstrap_ux_board(payload), args)


def _cmd_compose_populate_dt_section(args: argparse.Namespace) -> int:
    items = _parse_json_arg(_load_payload_file(args.items), "--items")
    payload: dict[str, Any] = {
        "mural": args.mural,
        "area": args.area,
        "method": args.method,
        "section": args.section,
        "items": items,
    }
    return _emit_record(_tool_populate_dt_section(payload), args)


def _cmd_compose_affinity_cluster(args: argparse.Namespace) -> int:
    clusters = _parse_json_arg(_load_payload_file(args.clusters), "--clusters")
    payload: dict[str, Any] = {
        "mural": args.mural,
        "area": args.area,
        "clusters": clusters,
    }
    return _emit_record(_tool_create_affinity_cluster(payload), args)


def _cmd_compose_parking_lot_sweep(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"mural": args.mural}
    if getattr(args, "area", None):
        payload["area"] = args.area
    if getattr(args, "tag", None):
        payload["tag"] = args.tag
    return _emit_record(_tool_parking_lot_sweep(payload), args)


def _cmd_compose_workspace_summary(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {}
    if getattr(args, "workspace", None):
        payload["workspace"] = args.workspace
    return _emit_record(_tool_workspace_summary(payload), args)


def _cmd_mural_find(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"query": args.query}
    if getattr(args, "workspace", None):
        payload["workspace"] = args.workspace
    if getattr(args, "min_score", None) is not None:
        payload["min_score"] = args.min_score
    if getattr(args, "limit", None) is not None:
        payload["limit"] = args.limit
    return _emit_record(_tool_mural_find(payload), args)


def _cmd_mural_repair_tag_drift(args: argparse.Namespace) -> int:
    return _emit_record(_tool_repair_tag_drift({"mural": args.mural}), args)


def _cmd_mural_lineage_lookup(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"mural_id": args.mural_id}
    if getattr(args, "run_id", None):
        payload["run_id"] = args.run_id
    if getattr(args, "method", None) is not None:
        payload["method"] = args.method
    if getattr(args, "section", None):
        payload["section"] = args.section
    return _emit_record(_tool_mural_lineage_lookup(payload), args)


def _cmd_spatial_widgets_in_shape(args: argparse.Namespace) -> int:
    """Return widgets contained by ``--shape-id`` per ``--mode`` semantics.

    Fetches the shape widget directly, then drains all mural widgets via
    pagination so spatial filtering is applied across the full canvas.
    ``--rotation-aware`` forces rotation-aware AABB expansion of the shape;
    when absent the env flag ``MURAL_SPATIAL_ROTATION_ENABLED`` (mirrored
    by ``_ROTATION_ENABLED``) governs the default.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    shape = _authenticated_request("GET", f"/murals/{mural_id}/widgets/{args.shape_id}")
    if not isinstance(shape, dict):
        raise MuralAPIError(
            0, "WIDGET_INVALID", "shape widget response is not an object"
        )
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    rotation_aware = bool(args.rotation_aware) or _ROTATION_ENABLED
    matched = widgets_in_shape(
        widgets, shape, mode=args.mode, rotation_aware=rotation_aware
    )
    return _emit_records(matched, args)


def _cmd_spatial_widgets_in_region(args: argparse.Namespace) -> int:
    """Return widgets inside an axis-aligned region per ``--mode`` semantics.

    Negative ``--w`` / ``--h`` values are sign-corrected by ``safe_rect``
    so the caller can pass either corner of the region in any order.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    region = safe_rect(args.x, args.y, args.w, args.h)
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    matched = widgets_in_region(widgets, region, mode=args.mode)
    return _emit_records(matched, args)


def _cmd_spatial_pairwise_overlaps(args: argparse.Namespace) -> int:
    """Return overlapping widget id pairs across the mural canvas.

    Drains every widget on the mural via pagination, builds the STR R-tree
    inside ``pairwise_overlaps``, and emits the deterministic pair list.
    ``--rotation-aware`` forces rotation-aware AABB expansion when set;
    otherwise the env flag ``MURAL_SPATIAL_ROTATION_ENABLED`` (mirrored by
    ``_ROTATION_ENABLED``) governs the default.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    rotation_aware = bool(args.rotation_aware) or _ROTATION_ENABLED
    pairs = pairwise_overlaps(
        widgets,
        predicate=args.predicate,
        rotation_aware=rotation_aware,
    )
    records = [{"a": a, "b": b} for a, b in pairs]
    return _emit_records(records, args)


def _cmd_spatial_cluster(args: argparse.Namespace) -> int:
    """Group widgets into spatial-proximity clusters via DBSCAN.

    Drains every widget on the mural via pagination, projects centers to
    2D points, and emits the deterministic cluster list from
    ``cluster_widgets``. ``--eps-px`` (default 120.0) sets the
    neighborhood radius and ``--min-samples`` (default 2) sets the
    density threshold; ``min_samples=1`` keeps isolated widgets as
    singleton clusters.
    """
    mural_id = _validate_mural_id(args.mural_id)
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    clusters = cluster_widgets(
        widgets,
        eps_px=args.eps_px,
        min_samples=args.min_samples,
    )
    records = [{"members": members} for members in clusters]
    return _emit_records(records, args)


def _cmd_spatial_sort_along_axis(args: argparse.Namespace) -> int:
    """Sort widgets along an axis projection and emit the ordered list.

    Drains every widget on the mural via pagination, projects each AABB
    center onto the axis vector selected by ``--axis``, and emits the
    deterministic ordering from ``sort_along_axis``. ``--origin-x`` and
    ``--origin-y`` are jointly optional; when both are provided the sort
    key becomes the signed projection of ``(center - origin)`` along the
    axis so callers can order widgets by distance from an anchor along a
    direction.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    origin: tuple[float, float] | None
    if args.origin_x is None and args.origin_y is None:
        origin = None
    elif args.origin_x is not None and args.origin_y is not None:
        origin = (float(args.origin_x), float(args.origin_y))
    else:
        print(
            "error: --origin-x and --origin-y must be provided together",
            file=sys.stderr,
        )
        return EXIT_USAGE
    ordered = sort_along_axis(widgets, axis=args.axis, origin=origin)
    return _emit_records(ordered, args)


def _cmd_spatial_arrow_graph(args: argparse.Namespace) -> int:
    """Build a directed multigraph from arrow widgets and emit it.

    Drains every widget on the mural, partitions arrow widgets from the
    rest, snaps each arrow endpoint to the nearest non-arrow widget AABB
    center within ``--snap-radius`` (Euclidean pixels), and emits the
    resulting graph in the requested format. ``summary`` (the default)
    prints a JSON summary; ``full`` augments each edge with the
    originating arrow widget; ``dot`` writes a Graphviz ``digraph`` text
    document. When ``--output`` is supplied the rendered text is written
    to that path instead of stdout.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    all_widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    arrows = [w for w in all_widgets if str(w.get("type", "")).lower() == "arrow"]
    targets = [w for w in all_widgets if str(w.get("type", "")).lower() != "arrow"]
    snap_radius = float(args.snap_radius)
    if snap_radius <= 0.0:
        print(
            "error: --snap-radius must be greater than 0",
            file=sys.stderr,
        )
        return EXIT_USAGE
    graph = build_arrow_graph(targets, arrows, snap_radius=snap_radius)
    summary = arrow_graph_summary(graph)
    fmt = args.format
    if fmt == "summary":
        text = json.dumps(summary, indent=2)
    elif fmt == "full":
        index = {str(w.get("id", "")): w for w in arrows}
        edges_full: list[dict[str, Any]] = []
        for edge in summary["edges"]:
            entry = dict(edge)
            entry["arrow_widget"] = index.get(edge["id"])
            edges_full.append(entry)
        payload = dict(summary)
        payload["edges"] = edges_full
        text = json.dumps(payload, indent=2)
    elif fmt == "dot":
        lines = ["digraph G {"]
        for node in summary["nodes"]:
            lines.append(f'  "{node}";')
        for edge in summary["edges"]:
            lines.append(
                f'  "{edge["source"]}" -> "{edge["target"]}" [label="{edge["id"]}"];'
            )
        lines.append("}")
        text = "\n".join(lines)
    else:
        print(
            f"error: invalid --format value {fmt!r}",
            file=sys.stderr,
        )
        return EXIT_USAGE
    output_path = getattr(args, "output", None)
    if output_path:
        pathlib.Path(output_path).write_text(text, encoding="utf-8")
    else:
        print(text)
    return EXIT_SUCCESS


def _cmd_spatial_not_implemented(args: argparse.Namespace) -> int:
    """Stub for spatial verbs whose implementation lands in a later PR.

    Reserved verb slots are registered so ``mural spatial --help`` lists
    the full surface and forward-compatible scripts can probe for
    availability without crashing on a Python traceback.
    """
    verb = getattr(args, "spatial_command", None) or "<unknown>"
    print(
        f"error: `mural spatial {verb}` is not yet implemented",
        file=sys.stderr,
    )
    return EXIT_USAGE


def _cmd_workspace_list(args: argparse.Namespace) -> int:
    records = list(_paginate("GET", "/workspaces", **_list_kwargs(args)))
    return _emit_records(records, args)


# Single-resource GET handlers rely on _emit_record's defensive {"value"} unwrap.
def _cmd_workspace_get(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    record = _authenticated_request("GET", f"/workspaces/{workspace_id}")
    return _emit_record(record, args)


def _cmd_room_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_room_get(args: argparse.Namespace) -> int:
    record = _authenticated_request("GET", f"/rooms/{args.room}")
    return _emit_record(record, args)


def _cmd_room_create(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    payload: dict[str, Any] = {
        "workspaceId": workspace_id,
        "name": args.name,
        "type": args.type,
    }
    if getattr(args, "description", None):
        payload["description"] = args.description
    record = _authenticated_request("POST", "/rooms", json_body=payload)
    return _emit_record(record, args)


def _cmd_mural_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_mural_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _authenticated_request("GET", f"/murals/{mural_id}")
    return _emit_record(record, args)


def _cmd_mural_create(args: argparse.Namespace) -> int:
    try:
        room_id = int(str(args.room).strip())
    except (TypeError, ValueError) as exc:
        raise SystemExit(f"error: --room must be an integer room id ({exc})")
    payload: dict[str, Any] = {"roomId": room_id, "title": args.title}
    record = _authenticated_request("POST", "/murals", json_body=payload)
    return _emit_record(record, args)


def _cmd_widget_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    params: dict[str, Any] = {}
    widget_type = getattr(args, "type", None)
    parent_id = getattr(args, "parent_id", None)
    if widget_type:
        params["type"] = widget_type
    if parent_id:
        params["parentId"] = parent_id
    records = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_widget_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _authenticated_request("GET", f"/murals/{mural_id}/widgets/{args.widget}")
    return _emit_record(record, args)


def _cmd_widget_delete(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    if getattr(args, "require_author_tag", False) and not getattr(
        args, "force_human", False
    ):
        _assert_widget_has_author_tag(mural_id, args.widget)
    _authenticated_request("DELETE", f"/murals/{mural_id}/widgets/{args.widget}")
    print(json.dumps({"ok": True, "deleted": args.widget}))
    return EXIT_SUCCESS


def _patch_widget_or_disambiguate_404(
    mural_id: str,
    widget_id: str,
    body: dict[str, Any],
    widget_type: str | None = None,
) -> Any:
    """PATCH a widget, routing to the correct type-specific endpoint.

    The Mural API requires PATCH against ``/widgets/{type}/{id}``; the
    generic ``/widgets/{id}`` route returns 404 PATH_NOT_FOUND. When
    ``widget_type`` is supplied the typed path is used directly. Otherwise the
    helper attempts the generic path first (preserving prior behavior so
    mocked tests keep passing) and, on 404, performs a single GET to learn
    the widget type from the live record before retrying against the typed
    path.
    """
    typed_path = _typed_widget_path(mural_id, widget_id, widget_type)
    if typed_path is not None:
        try:
            return _authenticated_request("PATCH", typed_path, json_body=body)
        except MuralAPIError as exc:
            if exc.status != 404:
                raise
            # Widget may have a different type than the caller supplied; fall
            # through to GET-based discovery below.
    last_exc: MuralAPIError | None = None
    if typed_path is None:
        try:
            return _authenticated_request(
                "PATCH",
                f"/murals/{mural_id}/widgets/{widget_id}",
                json_body=body,
            )
        except MuralAPIError as exc:
            if exc.status != 404:
                raise
            last_exc = exc
    try:
        record = _authenticated_request(
            "GET", f"/murals/{mural_id}/widgets/{widget_id}"
        )
    except MuralAPIError as probe_exc:
        if probe_exc.status == 404:
            raise MuralAPIError(
                404,
                "WIDGET_NOT_FOUND",
                (
                    f"widget {widget_id} not found on mural {mural_id}; "
                    "verify the widget id (it may have been deleted). "
                    "For tag mutations on an existing widget, use "
                    "`mural tag apply` / `mural tag remove` instead of "
                    "`widget update --body '{\"tags\":[...]}'`."
                ),
            ) from (last_exc or probe_exc)
        raise
    inner = record.get("value") if isinstance(record, dict) else None
    discovered_type = None
    if isinstance(inner, dict):
        discovered_type = inner.get("type")
    if discovered_type is None and isinstance(record, dict):
        discovered_type = record.get("type")
    discovered_path = _typed_widget_path(
        mural_id,
        widget_id,
        discovered_type if isinstance(discovered_type, str) else None,
    )
    if discovered_path is None:
        if last_exc is not None:
            raise last_exc
        raise MuralAPIError(
            404,
            "WIDGET_TYPE_UNKNOWN",
            (
                f"widget {widget_id} returned no recognized type from GET; "
                "cannot route PATCH to the type-specific endpoint."
            ),
        )
    return _authenticated_request("PATCH", discovered_path, json_body=body)


def _resolve_widget_update_body(args: argparse.Namespace) -> dict[str, Any]:
    """Load the patch body from inline ``--body`` or ``--body-file``.

    Mutually exclusive: providing both is an operator error. Either flag may
    be omitted entirely; the caller is responsible for ensuring the result
    plus any other inputs (e.g. ``--hyperlink``) is non-empty.
    """
    inline = getattr(args, "body", None)
    file_arg = getattr(args, "body_file", None)
    if inline and file_arg:
        raise MuralValidationError("provide either --body or --body-file, not both")
    if file_arg:
        body = _parse_json_arg(_load_payload_file(file_arg), "--body-file")
    elif inline:
        body = _parse_json_arg(inline, "--body")
    else:
        return {}
    if not isinstance(body, dict):
        raise MuralValidationError("widget update body must decode to a JSON object")
    return body


# Containment verdict vocabulary. ``parent_match``/``area_chain_match`` mean
# the readback confirmed the expected parent but area geometry was not
# available to evaluate; ``geometry_match`` is the strongest success and
# means the widget's (x, y) is inside the parent area's (width, height).
# ``geometry_mismatch`` is a hard failure: parent is correct but the widget
# will render outside the parent's frame. Callers should treat any of the
# three ``*_match`` values as containment success via
# :func:`_is_containment_success`.
CONTAINMENT_VERDICT_PARENT_MATCH = "parent_match"
CONTAINMENT_VERDICT_AREA_CHAIN_MATCH = "area_chain_match"
CONTAINMENT_VERDICT_GEOMETRY_MATCH = "geometry_match"
CONTAINMENT_VERDICT_PARENT_MISMATCH = "parent_mismatch"
CONTAINMENT_VERDICT_GEOMETRY_MISMATCH = "geometry_mismatch"
CONTAINMENT_VERDICT_READBACK_FAILED = "readback_failed"
CONTAINMENT_VERDICT_INCONCLUSIVE = "inconclusive"

_CONTAINMENT_SUCCESS_VERDICTS = frozenset(
    {
        CONTAINMENT_VERDICT_PARENT_MATCH,
        CONTAINMENT_VERDICT_AREA_CHAIN_MATCH,
        CONTAINMENT_VERDICT_GEOMETRY_MATCH,
    }
)


def _is_containment_success(verdict: str | None) -> bool:
    """Return True when ``verdict`` represents a containment success."""
    return verdict in _CONTAINMENT_SUCCESS_VERDICTS


def _coerce_finite_number(value: Any) -> float | None:
    """Return ``value`` as ``float`` when it is a finite real number."""
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        f = float(value)
        if f != f or f in (float("inf"), float("-inf")):
            return None
        return f
    return None


def _parse_parent_id(value: str) -> str:
    """argparse ``type=`` validator for ``--parent-id``.

    Rejects empty or whitespace-only values so the Mural API never receives
    a parentId of "" (which is silently ignored and produces an off-area
    widget).
    """
    if not isinstance(value, str) or not value.strip():
        raise argparse.ArgumentTypeError("--parent-id must be a non-empty string")
    return value.strip()


def _evaluate_containment_geometry(
    widget: dict[str, Any],
    area_chain: list[dict[str, Any]],
    expected_parent_id: str,
) -> tuple[str | None, str | None]:
    """Compare widget (x, y) to the expected parent area's (width, height).

    Returns ``(geometry_verdict, detail)`` where ``geometry_verdict`` is one
    of ``geometry_match``, ``geometry_mismatch``, or ``None`` when geometry
    could not be evaluated (missing or non-numeric coordinates/dimensions).
    ``detail`` is a short human-readable string suitable for ``recommendation``
    or ``None``.
    """
    expected_area: dict[str, Any] | None = None
    for entry in area_chain:
        if isinstance(entry, dict) and entry.get("id") == expected_parent_id:
            expected_area = entry
            break
    if expected_area is None:
        return None, None
    width = _coerce_finite_number(expected_area.get("width"))
    height = _coerce_finite_number(expected_area.get("height"))
    if width is None or height is None:
        return None, None
    x = _coerce_finite_number(widget.get("x"))
    y = _coerce_finite_number(widget.get("y"))
    if x is None or y is None:
        return None, None
    if 0.0 <= x <= width and 0.0 <= y <= height:
        return (
            CONTAINMENT_VERDICT_GEOMETRY_MATCH,
            (
                f"widget (x={x}, y={y}) is inside parent area "
                f"(width={width}, height={height})"
            ),
        )
    return (
        CONTAINMENT_VERDICT_GEOMETRY_MISMATCH,
        (
            f"widget (x={x}, y={y}) is outside parent area "
            f"(width={width}, height={height}); parentId is correct but "
            "the widget will render off-area — see geometry rules in "
            "mural-seeding-patterns.instructions.md"
        ),
    )


def _verify_parent_containment(
    mural_id: str,
    widget_id: str,
    expected_parent_id: str,
) -> dict[str, Any]:
    """Read a widget back and verify it persists the expected parent area.

    Returns a verdict dict with keys ``verdict`` (see
    ``CONTAINMENT_VERDICT_*`` constants), ``expected_parent_id``,
    ``persisted_parent_id``, ``area_chain_ids``, ``via`` (``parentId``,
    ``areaChain``, or ``None``), and ``recommendation``. Pure of side
    effects beyond a single widget GET plus area-chain walk.
    """
    try:
        record = _authenticated_request(
            "GET", f"/murals/{mural_id}/widgets/{widget_id}"
        )
    except MuralAPIError as exc:
        return {
            "verdict": CONTAINMENT_VERDICT_READBACK_FAILED,
            "expected_parent_id": expected_parent_id,
            "persisted_parent_id": None,
            "area_chain_ids": [],
            "via": None,
            "recommendation": (
                f"could not read widget {widget_id} back to verify containment: {exc}"
            ),
        }
    inner = record.get("value") if isinstance(record, dict) else None
    widget = (
        inner
        if isinstance(inner, dict)
        else (record if isinstance(record, dict) else {})
    )
    persisted_parent = widget.get("parentId")
    area_chain = (
        _walk_area_chain(mural_id, persisted_parent) if persisted_parent else []
    )
    chain_ids = [a.get("id") for a in area_chain if isinstance(a, dict)]
    parent_match_via: str | None = None
    if persisted_parent == expected_parent_id:
        parent_match_via = "parentId"
    elif expected_parent_id in chain_ids:
        parent_match_via = "areaChain"
    if parent_match_via is None:
        return {
            "verdict": CONTAINMENT_VERDICT_PARENT_MISMATCH,
            "expected_parent_id": expected_parent_id,
            "persisted_parent_id": persisted_parent,
            "area_chain_ids": chain_ids,
            "via": None,
            "recommendation": (
                f"persisted parentId {persisted_parent!r} and area chain "
                f"{chain_ids} do not contain expected area "
                f"{expected_parent_id!r}; the Mural API may have ignored "
                "parentId for this widget type — see probe-before-bulk in "
                "mural-seeding-patterns.instructions.md"
            ),
        }
    geometry_verdict, geometry_detail = _evaluate_containment_geometry(
        widget, area_chain, expected_parent_id
    )
    if geometry_verdict == CONTAINMENT_VERDICT_GEOMETRY_MATCH:
        return {
            "verdict": CONTAINMENT_VERDICT_GEOMETRY_MATCH,
            "expected_parent_id": expected_parent_id,
            "persisted_parent_id": persisted_parent,
            "area_chain_ids": chain_ids,
            "via": parent_match_via,
            "recommendation": geometry_detail,
        }
    if geometry_verdict == CONTAINMENT_VERDICT_GEOMETRY_MISMATCH:
        return {
            "verdict": CONTAINMENT_VERDICT_GEOMETRY_MISMATCH,
            "expected_parent_id": expected_parent_id,
            "persisted_parent_id": persisted_parent,
            "area_chain_ids": chain_ids,
            "via": parent_match_via,
            "recommendation": geometry_detail,
        }
    if parent_match_via == "parentId":
        return {
            "verdict": CONTAINMENT_VERDICT_PARENT_MATCH,
            "expected_parent_id": expected_parent_id,
            "persisted_parent_id": persisted_parent,
            "area_chain_ids": chain_ids,
            "via": "parentId",
            "recommendation": (
                "persisted parentId matches expected area; geometry not "
                "evaluated (area width/height or widget x/y unavailable)"
            ),
        }
    return {
        "verdict": CONTAINMENT_VERDICT_AREA_CHAIN_MATCH,
        "expected_parent_id": expected_parent_id,
        "persisted_parent_id": persisted_parent,
        "area_chain_ids": chain_ids,
        "via": "areaChain",
        "recommendation": (
            "persisted parentId differs but expected area is in the area "
            "chain; containment satisfied transitively (geometry not "
            "evaluated)"
        ),
    }


def _attach_containment_to_record(record: Any, verdict: dict[str, Any]) -> None:
    """Attach a containment verdict to a create/update response in place."""
    if not isinstance(record, dict):
        return
    inner = record.get("value")
    target = inner if isinstance(inner, dict) else record
    target["containment_verification"] = verdict


def _cmd_widget_update(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _resolve_widget_update_body(args)
    hyperlink = getattr(args, "hyperlink", None)
    if hyperlink is not None:
        body["hyperlink"] = _validate_hyperlink(hyperlink)
    if not body:
        raise MuralValidationError(
            "widget update requires --body, --body-file, or --hyperlink"
        )
    if getattr(args, "require_author_tag", False) and not getattr(
        args, "force_human", False
    ):
        _assert_widget_has_author_tag(mural_id, args.widget)
    record = _patch_widget_or_disambiguate_404(mural_id, args.widget, body)
    expected_parent = body.get("parentId") if isinstance(body, dict) else None
    if isinstance(expected_parent, str) and expected_parent:
        verdict = _verify_parent_containment(mural_id, args.widget, expected_parent)
        _attach_containment_to_record(record, verdict)
        if not _is_containment_success(verdict["verdict"]):
            _emit_record(record, args)
            return EXIT_FAILURE
    return _emit_record(record, args)


def _create_widget(
    mural_id: str,
    widget_type: str,
    body: dict[str, Any],
    args: argparse.Namespace,
) -> int:
    record = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/{widget_type}",
        json_body=body,
    )
    _maybe_apply_author_tag(
        mural_id, record, skip=bool(getattr(args, "no_author_tag", False))
    )
    expected_parent = getattr(args, "parent_id", None)
    if expected_parent:
        widget_id = _resolve_widget_id(record)
        if widget_id:
            verdict = _verify_parent_containment(mural_id, widget_id, expected_parent)
            _attach_containment_to_record(record, verdict)
            if not _is_containment_success(verdict["verdict"]):
                _emit_record(record, args)
                return EXIT_FAILURE
    return _emit_record(record, args)


def _cmd_widget_create_sticky_note(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(mural_id, "sticky-note", _build_sticky_note_body(args), args)


def _cmd_widget_create_textbox(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(mural_id, "textbox", _build_textbox_body(args), args)


def _cmd_widget_create_shape(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(mural_id, "shape", _build_shape_body(args), args)


def _cmd_widget_create_arrow(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    return _create_widget(mural_id, "arrow", _build_arrow_body(args), args)


def _cmd_widget_create_image(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    if not (getattr(args, "alt_text", None) or "").strip():
        raise MuralValidationError(
            "alt_text is required for image widgets (WCAG 2.2 SC 1.1.1)"
        )
    file_path = pathlib.Path(args.file).expanduser()
    if not file_path.is_file():
        raise MuralValidationError(f"image file not found: {file_path}")
    suffix = file_path.suffix.lower()
    if suffix not in _IMAGE_CONTENT_TYPES:
        raise MuralValidationError(
            f"unsupported image extension {suffix!r}; allowed: "
            + ", ".join(sorted(_IMAGE_CONTENT_TYPES))
        )
    body_bytes = file_path.read_bytes()
    asset = _create_asset_url(mural_id, suffix)
    _upload_to_sas(
        url=asset["url"],
        headers=asset.get("headers") or {},
        body=body_bytes,
        content_type=_IMAGE_CONTENT_TYPES[suffix],
    )
    record = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/image",
        json_body=_build_image_body(asset_name=asset["name"], args=args),
    )
    _maybe_apply_author_tag(
        mural_id, record, skip=bool(getattr(args, "no_author_tag", False))
    )
    return _emit_record(record, args)


# --- Tag, area, and widget-context CLI handlers ---------------------------


def _cmd_tag_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/tags",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_tag_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _create_tag(mural_id, args.text, getattr(args, "color", None))
    return _emit_record(record, args)


def _cmd_tag_apply(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    tag_id = getattr(args, "tag", None)
    text = getattr(args, "text", None)
    if not tag_id and not text:
        raise MuralValidationError("tag apply requires --tag or --text")
    if not tag_id:
        manifest = [{"text": _validate_tag_text(text)}]
        if getattr(args, "color", None):
            manifest[0]["color"] = args.color
        mapping = _ensure_tag_manifest(mural_id, manifest)
        tag_id = mapping[text]
    record = _merge_tags(mural_id, args.widget, additions=[tag_id])
    return _emit_record(record, args)


def _cmd_tag_remove(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    if _is_reserved_tag_id(mural_id, args.tag):
        if not getattr(args, "force_reserved", False):
            raise MuralValidationError(
                f"refusing to remove reserved tag {args.tag!r}; "
                "pass --force-reserved to override"
            )
        print(
            f"warning: removing reserved tag {args.tag!r} (forced)",
            file=sys.stderr,
        )
    record = _merge_tags(mural_id, args.widget, removals=[args.tag])
    return _emit_record(record, args)


def _cmd_area_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = _list_areas_with_widget_fallback(mural_id, **_list_kwargs(args))
    return _emit_records(records, args)


def _cmd_area_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _get_area_with_widget_fallback(mural_id, args.area)
    return _emit_record(record, args)


def _cmd_area_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _build_area_body(args)
    record = _authenticated_request("POST", f"/murals/{mural_id}/areas", json_body=body)
    if isinstance(record, dict):
        area_id = record.get("id")
        if isinstance(area_id, str):
            _area_cache[area_id] = record
    return _emit_record(record, args)


def _cmd_area_probe(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    verdict = _area_probe(mural_id, args.area)
    return _emit_record(verdict, args)


_WIDGET_TYPE_TO_PATH: dict[str, str] = {
    "stickynote": "widgets/sticky-note",
    "textbox": "widgets/textbox",
    "shape": "widgets/shape",
    "arrow": "widgets/arrow",
    "image": "widgets/image",
}

_WIDGET_TYPE_API_TO_PATH_KEY: dict[str, str] = {
    "sticky note": "stickynote",
    "sticky-note": "stickynote",
    "sticky_note": "stickynote",
    "stickynote": "stickynote",
    "text box": "textbox",
    "text-box": "textbox",
    "text_box": "textbox",
    "textbox": "textbox",
    "shape": "shape",
    "arrow": "arrow",
    "image": "image",
}


def _typed_widget_path(
    mural_id: str, widget_id: str, widget_type: str | None
) -> str | None:
    """Build the type-specific PATCH/DELETE path for ``widget_type``.

    Returns ``None`` when ``widget_type`` is missing or not in
    :data:`_WIDGET_TYPE_API_TO_PATH_KEY`. The Mural API rejects PATCH against
    the generic ``/widgets/{id}`` route with 404 PATH_NOT_FOUND, so callers
    that know the widget type should target the typed route directly.
    Accepts the GET-response variant ``"sticky note"`` (space) alongside
    the canonical hyphen/underscore forms because Mural normalizes types
    differently on the read and write sides.
    """
    if not isinstance(widget_type, str) or not widget_type:
        return None
    key = _WIDGET_TYPE_API_TO_PATH_KEY.get(widget_type.strip().lower())
    if not key:
        return None
    suffix = _WIDGET_TYPE_TO_PATH.get(key)
    if not suffix:
        return None
    return f"/murals/{mural_id}/{suffix}/{widget_id}"


def _build_bulk_widgets_payload(raw: Any) -> list[dict[str, Any]]:
    """Validate a bulk-create payload and return the list of widget bodies.

    Accepts either a top-level JSON array or ``{"widgets": [...]}``. Each
    entry must be a JSON object containing a ``type`` field plus any
    type-specific fields the Mural API expects. Raises
    :class:`MuralValidationError` when the payload is malformed or exceeds
    :data:`MAX_BULK_WIDGETS`.
    """
    if isinstance(raw, dict) and "widgets" in raw:
        widgets = raw["widgets"]
    else:
        widgets = raw
    if not isinstance(widgets, list):
        raise MuralValidationError(
            "bulk widgets payload must be a JSON array or {widgets: [...]}"
        )
    if not widgets:
        raise MuralValidationError("bulk widgets payload is empty")
    if len(widgets) > MAX_BULK_WIDGETS:
        raise MuralValidationError(
            f"bulk create exceeds {MAX_BULK_WIDGETS} widgets (received {len(widgets)})"
        )
    cleaned: list[dict[str, Any]] = []
    for index, entry in enumerate(widgets):
        if not isinstance(entry, dict):
            raise MuralValidationError(f"bulk widgets[{index}] must be a JSON object")
        if not isinstance(entry.get("type"), str) or not entry["type"]:
            raise MuralValidationError(
                f"bulk widgets[{index}].type must be a non-empty string"
            )
        for key in ("parent_id", "parentId"):
            if key in entry and entry[key] is not None:
                pid = entry[key]
                if not isinstance(pid, str) or not pid.strip():
                    raise MuralValidationError(
                        f"bulk widgets[{index}].{key} must be a non-empty string"
                    )
        cleaned.append(entry)
    return cleaned


def _extract_bulk_create_succeeded(response: Any) -> list[Any]:
    """Normalize a bulk-create response into a list of created widgets."""
    if isinstance(response, list):
        return list(response)
    if isinstance(response, dict):
        for key in ("value", "data", "widgets"):
            value = response.get(key)
            if isinstance(value, list):
                return list(value)
        return [response]
    return []


# Bare `POST /murals/{id}/widgets` returns 404 PATH_NOT_FOUND on Public API v1;
# each widget is dispatched to its per-type endpoint.
def _bulk_create_widgets(
    mural_id: str, widgets: list[dict[str, Any]], *, atomic: bool = False
) -> dict[str, Any]:
    skipped: list[dict[str, Any]] = []
    to_send: list[dict[str, Any]] = []
    seen_areas: dict[str, set[str]] = {}
    for entry in widgets:
        area_id = entry.get("areaId")
        entry_hash: str | None = None
        tags = entry.get("tags")
        if isinstance(tags, list):
            for t in tags:
                if isinstance(t, str) and t.startswith(_LAYOUT_HASH_PREFIX):
                    entry_hash = t[len(_LAYOUT_HASH_PREFIX) :]
                    break
        if area_id and entry_hash:
            if area_id not in seen_areas:
                seen_areas[area_id] = _existing_layout_hashes(mural_id, area_id)
            if entry_hash in seen_areas[area_id]:
                skipped.append(
                    {
                        "reason": "layout_hash_match",
                        "hash": entry_hash,
                        "area_id": area_id,
                        "item": entry,
                    }
                )
                continue
        to_send.append(entry)
    summary: dict[str, Any] = {
        "succeeded": [],
        "skipped": skipped,
        "failed": [],
        "warnings": [],
    }
    probe_index = next(
        (
            i
            for i, entry in enumerate(to_send)
            if isinstance(entry.get("parentId"), str) and entry["parentId"]
        ),
        None,
    )
    probe_outcome: dict[str, Any] | None = None
    halt_parented = False
    for index, entry in enumerate(to_send):
        expected_parent_raw = entry.get("parentId") if isinstance(entry, dict) else None
        has_parent = isinstance(expected_parent_raw, str) and bool(expected_parent_raw)
        if halt_parented and has_parent:
            skip_record: dict[str, Any] = {
                "reason": "probe_failed",
                "item": entry,
            }
            if probe_outcome is not None:
                skip_record["probe"] = probe_outcome
            summary["skipped"].append(skip_record)
            continue
        widget_type = entry.get("type")
        normalized = (
            widget_type.strip()
            .lower()
            .replace("-", "")
            .replace("_", "")
            .replace(" ", "")
        )
        subpath = _WIDGET_TYPE_TO_PATH.get(normalized)
        if subpath is None:
            summary["failed"].append(
                {
                    "item": entry,
                    "error": (
                        f"unsupported widget type {widget_type!r}; expected one of: "
                        "sticky-note, textbox, shape, arrow, image"
                    ),
                }
            )
            if atomic:
                raise MuralBulkAtomicAbort(summary)
            if index == probe_index:
                probe_outcome = {
                    "index": index,
                    "reason": "unsupported_widget_type",
                }
                summary["probe"] = probe_outcome
                halt_parented = True
            continue
        body = {k: v for k, v in entry.items() if k != "type"}
        try:
            response = _authenticated_request(
                "POST",
                f"/murals/{mural_id}/{subpath}",
                json_body=body,
            )
        except MuralError as exc:
            summary["failed"].append({"item": entry, "error": str(exc)})
            if index == probe_index:
                probe_outcome = {
                    "index": index,
                    "reason": "post_failed",
                    "error": str(exc),
                }
                summary["probe"] = probe_outcome
                halt_parented = True
            if atomic:
                raise MuralBulkAtomicAbort(summary) from exc
            continue
        created = _extract_bulk_create_succeeded(response)
        if created:
            probe_verdict_value: str | None = None
            probe_widget_id: str | None = None
            if has_parent:
                expected_parent = expected_parent_raw
                for created_widget in created:
                    widget_id = _resolve_widget_id(created_widget)
                    if not widget_id:
                        continue
                    verdict = _verify_parent_containment(
                        mural_id, widget_id, expected_parent
                    )
                    _attach_containment_to_record(created_widget, verdict)
                    success = _is_containment_success(verdict["verdict"])
                    if not success:
                        summary["warnings"].append(
                            f"containment verification failed for widget "
                            f"{widget_id}: {verdict['recommendation']}"
                        )
                    if probe_verdict_value is None:
                        probe_verdict_value = verdict["verdict"]
                        probe_widget_id = widget_id
            summary["succeeded"].extend(created)
            if index == probe_index and probe_verdict_value is not None:
                probe_outcome = {
                    "index": index,
                    "widget_id": probe_widget_id,
                    "verdict": probe_verdict_value,
                }
                summary["probe"] = probe_outcome
                if not _is_containment_success(probe_verdict_value):
                    halt_parented = True
                    if atomic:
                        raise MuralBulkAtomicAbort(summary)
        else:
            summary["failed"].append(
                {"item": entry, "error": "empty response from create"}
            )
            if index == probe_index:
                probe_outcome = {
                    "index": index,
                    "reason": "empty_response",
                }
                summary["probe"] = probe_outcome
                halt_parented = True
            if atomic:
                raise MuralBulkAtomicAbort(summary)
    return summary


def _cmd_widget_create_bulk(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    raw = _parse_json_arg(_load_payload_file(args.file), "--file")
    widgets = _build_bulk_widgets_payload(raw)
    result = _bulk_create_widgets(
        mural_id, widgets, atomic=bool(getattr(args, "atomic", False))
    )
    _bulk_apply_author_tag(
        mural_id, result, skip=bool(getattr(args, "no_author_tag", False))
    )
    return _emit_record(result, args)


def _bulk_apply_author_tag(
    mural_id: str, result: dict[str, Any], *, skip: bool
) -> None:
    """Best-effort attach the reserved author tag to every succeeded widget.

    Failures are appended to ``result['warnings']`` rather than aborting the
    whole batch so the caller still receives the create-side outcome.
    """
    if skip:
        return
    succeeded = result.get("succeeded") or []
    if not succeeded:
        return
    try:
        tag_id = _ensure_reserved_author_tag(mural_id)
    except MuralError as exc:
        result.setdefault("warnings", []).append(f"author-tag setup failed: {exc}")
        return
    warnings = result.setdefault("warnings", [])
    for entry in succeeded:
        widget_id = _resolve_widget_id(entry)
        if not widget_id:
            continue
        try:
            _merge_tags(mural_id, widget_id, additions=[tag_id])
        except MuralError as exc:
            warnings.append(f"author-tag attach failed for widget {widget_id}: {exc}")


_BULK_UPDATE_MAX_WORKERS = 8


def _build_bulk_widget_updates_payload(raw: Any) -> list[dict[str, Any]]:
    """Validate a bulk-update payload and return a normalized list.

    Accepts either a top-level JSON array or ``{"updates": [...]}``. Each
    entry must be ``{"widget_id": str, "body": dict}`` (camelCase ``widgetId``
    is also accepted). Raises :class:`MuralValidationError` when the payload
    is malformed or exceeds :data:`MAX_BULK_WIDGETS`.
    """
    if isinstance(raw, dict) and "updates" in raw:
        updates = raw["updates"]
    else:
        updates = raw
    if not isinstance(updates, list):
        raise MuralValidationError(
            "bulk updates payload must be a JSON array or {updates: [...]}"
        )
    if not updates:
        raise MuralValidationError("bulk updates payload is empty")
    if len(updates) > MAX_BULK_WIDGETS:
        raise MuralValidationError(
            f"bulk update exceeds {MAX_BULK_WIDGETS} widgets (received {len(updates)})"
        )
    cleaned: list[dict[str, Any]] = []
    for index, entry in enumerate(updates):
        if not isinstance(entry, dict):
            raise MuralValidationError(f"bulk updates[{index}] must be a JSON object")
        widget_id = entry.get("widget_id") or entry.get("widgetId")
        if not isinstance(widget_id, str) or not widget_id:
            raise MuralValidationError(
                f"bulk updates[{index}].widget_id must be a non-empty string"
            )
        body = entry.get("body")
        if not isinstance(body, dict) or not body:
            raise MuralValidationError(
                f"bulk updates[{index}].body must be a non-empty JSON object"
            )
        normalized: dict[str, Any] = {"widget_id": widget_id, "body": body}
        widget_type = entry.get("type") or entry.get("widgetType")
        if isinstance(widget_type, str) and widget_type:
            normalized["type"] = widget_type
        cleaned.append(normalized)
    return cleaned


def _bulk_update_widgets(
    mural_id: str,
    updates: list[dict[str, Any]],
    *,
    atomic: bool = False,
    require_author_tag: bool = False,
    force_human: bool = False,
) -> dict[str, Any]:
    """PATCH a batch of widgets concurrently and return a result envelope.

    Returns ``{"succeeded": [...], "failed": [...], "warnings": [...]}``.
    Each ``succeeded`` entry is ``{"widget_id": str, "widget": <response>}``
    and each ``failed`` entry is ``{"widget_id": str, "error": str}``.

    When ``atomic`` is true, raises :class:`MuralBulkAtomicAbort` carrying the
    partial summary as soon as the first failure is observed; remaining
    in-flight tasks are cancelled where possible.
    """
    succeeded: list[dict[str, Any]] = []
    failed: list[dict[str, Any]] = []
    warnings: list[str] = []
    guard_active = require_author_tag and not force_human

    def _patch_one(item: dict[str, Any]) -> dict[str, Any]:
        widget_id = item["widget_id"]
        if guard_active:
            _assert_widget_has_author_tag(mural_id, widget_id)
        record = _patch_widget_or_disambiguate_404(
            mural_id, widget_id, item["body"], item.get("type")
        )
        return {"widget_id": widget_id, "widget": record}

    workers = min(_BULK_UPDATE_MAX_WORKERS, max(1, len(updates)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_to_item = {pool.submit(_patch_one, item): item for item in updates}
        try:
            for future in concurrent.futures.as_completed(future_to_item):
                item = future_to_item[future]
                try:
                    succeeded.append(future.result())
                except Exception as exc:  # noqa: BLE001
                    failed.append({"widget_id": item["widget_id"], "error": str(exc)})
                    if atomic:
                        for pending in future_to_item:
                            if not pending.done():
                                pending.cancel()
                        raise MuralBulkAtomicAbort(
                            {
                                "succeeded": succeeded,
                                "failed": failed,
                                "warnings": warnings,
                            }
                        )
        finally:
            pass
    return {"succeeded": succeeded, "failed": failed, "warnings": warnings}


def _cmd_widget_update_bulk(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    raw = _parse_json_arg(_load_payload_file(args.file), "--file")
    updates = _build_bulk_widget_updates_payload(raw)
    result = _bulk_update_widgets(
        mural_id,
        updates,
        atomic=bool(getattr(args, "atomic", False)),
        require_author_tag=bool(getattr(args, "require_author_tag", False)),
        force_human=bool(getattr(args, "force_human", False)),
    )
    return _emit_record(result, args)


_DIFF_GEOM_KEYS = ("x", "y", "width", "height", "rotation")
_DIFF_STYLE_KEYS = ("style", "shape")
_DIFF_CONTENT_KEYS = ("text", "htmlText", "title", "hyperlink")
_DIFF_ANCHOR_KEYS = (
    "parentId",
    "startWidget",
    "endWidget",
    "startRefId",
    "endRefId",
    "points",
)
_DIFF_IGNORED_KEYS = frozenset(
    {"id", "createdOn", "updatedOn", "createdBy", "updatedBy"}
)


def _diff_widget_lists(
    baseline: list[dict[str, Any]], current: list[dict[str, Any]]
) -> dict[str, Any]:
    """Diff two widget lists by id and group field changes by category.

    ``baseline`` is the prior snapshot (typically the local file); ``current``
    is the live state (typically fetched from the mural). Widgets are matched
    by ``id``. ``htmlText``/``text`` are compared via :func:`_coalesce_widget_text`
    so portal-migrated content is not flagged as a spurious change.

    Returns a dict shaped::

        {
          "summary": {"added": N, "removed": N, "changed": N},
          "added": [widget, ...],
          "removed": [widget, ...],
          "changed": [{"id": ..., "type": ..., "delta": {category: {field: [a,b]}}}],
        }
    """
    base_by_id = {w["id"]: w for w in baseline if isinstance(w, dict) and w.get("id")}
    cur_by_id = {w["id"]: w for w in current if isinstance(w, dict) and w.get("id")}
    added = [cur_by_id[i] for i in cur_by_id if i not in base_by_id]
    removed = [base_by_id[i] for i in base_by_id if i not in cur_by_id]
    changed: list[dict[str, Any]] = []
    for wid, before in base_by_id.items():
        after = cur_by_id.get(wid)
        if after is None:
            continue
        delta = _diff_widget_fields(before, after)
        if delta:
            changed.append(
                {
                    "id": wid,
                    "type": after.get("type") or before.get("type"),
                    "delta": delta,
                }
            )
    return {
        "summary": {
            "added": len(added),
            "removed": len(removed),
            "changed": len(changed),
        },
        "added": added,
        "removed": removed,
        "changed": changed,
    }


def _diff_widget_fields(
    before: dict[str, Any], after: dict[str, Any]
) -> dict[str, dict[str, list[Any]]]:
    """Compute per-category field deltas between two widget dicts.

    Suppresses spurious ``text``/``htmlText`` differences when both sides
    coalesce to the same plain-text body (WI-16 portal migration).
    """
    delta: dict[str, dict[str, list[Any]]] = {}
    for key in _DIFF_GEOM_KEYS:
        if before.get(key) != after.get(key) and (
            before.get(key) is not None or after.get(key) is not None
        ):
            delta.setdefault("geometry", {})[key] = [before.get(key), after.get(key)]
    text_equivalent = _coalesce_widget_text(before) == _coalesce_widget_text(after)
    for key in _DIFF_CONTENT_KEYS:
        if before.get(key) == after.get(key):
            continue
        if key in {"text", "htmlText"} and text_equivalent:
            continue
        delta.setdefault("content", {})[key] = [before.get(key), after.get(key)]
    for key in _DIFF_STYLE_KEYS:
        if before.get(key) != after.get(key):
            delta.setdefault("style", {})[key] = [before.get(key), after.get(key)]
    for key in _DIFF_ANCHOR_KEYS:
        if before.get(key) != after.get(key):
            delta.setdefault("anchor", {})[key] = [before.get(key), after.get(key)]
    known = (
        set(_DIFF_GEOM_KEYS)
        | set(_DIFF_STYLE_KEYS)
        | set(_DIFF_CONTENT_KEYS)
        | set(_DIFF_ANCHOR_KEYS)
        | _DIFF_IGNORED_KEYS
    )
    other: dict[str, list[Any]] = {}
    for key in set(before) | set(after):
        if key in known:
            continue
        if before.get(key) != after.get(key):
            other[key] = [before.get(key), after.get(key)]
    if other:
        delta["other"] = other
    return delta


def _bulk_delete_widgets(
    mural_id: str, widget_ids: list[str], *, atomic: bool = False
) -> dict[str, Any]:
    """Sequentially DELETE widgets and return ``{succeeded, failed, warnings}``.

    The Mural API does not expose a bulk delete endpoint, so this helper
    walks ``widget_ids`` in order. Under ``atomic``, the first failure
    raises :class:`MuralBulkAtomicAbort` carrying the partial summary.
    """
    succeeded: list[str] = []
    failed: list[dict[str, Any]] = []
    for wid in widget_ids:
        try:
            _authenticated_request("DELETE", f"/murals/{mural_id}/widgets/{wid}")
            succeeded.append(wid)
        except MuralError as exc:
            failed.append({"widget_id": wid, "error": str(exc)})
            if atomic:
                raise MuralBulkAtomicAbort(
                    {
                        "succeeded": succeeded,
                        "failed": failed,
                        "warnings": [
                            f"delete failed for {wid} ({exc}); aborting under --atomic"
                        ],
                    }
                ) from exc
    return {"succeeded": succeeded, "failed": failed, "warnings": []}


def _apply_widget_diff(
    mural_id: str,
    baseline: list[dict[str, Any]],
    diff: dict[str, Any],
    *,
    atomic: bool = False,
) -> dict[str, Any]:
    """Push ``baseline`` to ``mural_id`` using the precomputed ``diff``.

    Routes diff entries to bulk operations so live state matches the
    snapshot:

    * ``diff['removed']`` (in snapshot, missing live) -> bulk create.
    * ``diff['changed']`` -> bulk update with baseline field values.
    * ``diff['added']``   (extra in live, not in snapshot) -> sequential delete.

    Returns ``{create, update, delete}`` envelopes from the underlying
    helpers. Under ``atomic``, the first failure in any phase raises
    :class:`MuralBulkAtomicAbort`; later phases are not attempted.

    PATCH bodies cannot unset fields, so when a changed field is absent
    or null in the baseline a warning is recorded in
    ``update['warnings']`` and the field is left untouched on live.
    """
    base_by_id = {
        w["id"]: w
        for w in baseline
        if isinstance(w, dict) and isinstance(w.get("id"), str)
    }
    create_payload: list[dict[str, Any]] = []
    for entry in diff.get("removed", []):
        if not isinstance(entry, dict):
            continue
        body = {k: v for k, v in entry.items() if k not in _DIFF_IGNORED_KEYS}
        if isinstance(body.get("type"), str) and body["type"]:
            create_payload.append(body)
    delete_ids: list[str] = [
        entry["id"]
        for entry in diff.get("added", [])
        if isinstance(entry, dict) and isinstance(entry.get("id"), str)
    ]
    update_payload: list[dict[str, Any]] = []
    unset_warnings: list[str] = []
    for change in diff.get("changed", []):
        if not isinstance(change, dict):
            continue
        wid = change.get("id")
        delta = change.get("delta") or {}
        base_w = base_by_id.get(wid) if isinstance(wid, str) else None
        if not isinstance(base_w, dict) or not isinstance(delta, dict):
            continue
        body: dict[str, Any] = {}
        unset_fields: list[str] = []
        for fields in delta.values():
            if not isinstance(fields, dict):
                continue
            for field in fields:
                if field in base_w and base_w[field] is not None:
                    body[field] = base_w[field]
                else:
                    unset_fields.append(field)
        if unset_fields:
            unset_warnings.append(
                f"widget {wid}: cannot unset fields via PATCH: "
                f"{sorted(set(unset_fields))}"
            )
        if body:
            entry: dict[str, Any] = {"widget_id": wid, "body": body}
            base_type = base_w.get("type")
            if isinstance(base_type, str) and base_type:
                entry["type"] = base_type
            update_payload.append(entry)

    empty_create = {
        "succeeded": [],
        "skipped": [],
        "failed": [],
        "warnings": [],
    }
    empty_update_or_delete = {
        "succeeded": [],
        "failed": [],
        "warnings": [],
    }
    create_result = (
        _bulk_create_widgets(mural_id, create_payload, atomic=atomic)
        if create_payload
        else dict(empty_create)
    )
    update_result = (
        _bulk_update_widgets(mural_id, update_payload, atomic=atomic)
        if update_payload
        else dict(empty_update_or_delete)
    )
    if unset_warnings:
        update_result.setdefault("warnings", []).extend(unset_warnings)
    delete_result = (
        _bulk_delete_widgets(mural_id, delete_ids, atomic=atomic)
        if delete_ids
        else dict(empty_update_or_delete)
    )
    return {
        "create": create_result,
        "update": update_result,
        "delete": delete_result,
    }


def _cmd_widget_diff(args: argparse.Namespace) -> int:
    """Diff a local widget snapshot against the live mural state."""
    mural_id = _validate_mural_id(args.mural)
    raw = _parse_json_arg(_load_payload_file(args.file), "--file")
    if isinstance(raw, dict) and "widgets" in raw:
        baseline = raw["widgets"]
    else:
        baseline = raw
    if not isinstance(baseline, list):
        raise MuralValidationError(
            "--file must contain a JSON array of widgets or "
            "an object with a 'widgets' array"
        )
    live = list(_paginate("GET", f"/murals/{mural_id}/widgets"))
    result = _diff_widget_lists(baseline, live)
    if getattr(args, "apply", False):
        apply_result = _apply_widget_diff(
            mural_id,
            baseline,
            result,
            atomic=bool(getattr(args, "atomic", False)),
        )
        result = {**result, "applied": True, **apply_result}
    return _emit_record(result, args)


def _duplicate_mural(source_mural_id: str) -> str:
    """POST ``/murals/{id}/duplicate`` and return the new mural id.

    Raises :class:`MuralAPIError` when the response does not include an
    ``id`` field; the new mural identifier is required for downstream
    workflows such as :func:`_cmd_clone_with_tags`.
    """
    response = _authenticated_request("POST", f"/murals/{source_mural_id}/duplicate")
    new_id: Any = None
    if isinstance(response, dict):
        new_id = response.get("id") or (
            response.get("value") if isinstance(response.get("value"), str) else None
        )
        if not isinstance(new_id, str):
            inner = response.get("value")
            if isinstance(inner, dict):
                new_id = inner.get("id")
    if not isinstance(new_id, str) or not new_id:
        raise MuralAPIError(
            0, "DUPLICATE_INVALID", "duplicate response missing mural id"
        )
    return new_id


def _cmd_mural_duplicate(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    new_id = _duplicate_mural(mural_id)
    return _emit_record({"new_mural_id": new_id, "source_mural_id": mural_id}, args)


def _read_tag_manifest(mural_id: str) -> list[dict[str, Any]]:
    """Return ``[{text, color?}]`` tag entries from an existing mural."""
    manifest: list[dict[str, Any]] = []
    for tag in _paginate("GET", f"/murals/{mural_id}/tags"):
        if not isinstance(tag, dict):
            continue
        text = tag.get("text")
        if not isinstance(text, str):
            continue
        entry: dict[str, Any] = {"text": text}
        color = tag.get("color")
        if isinstance(color, str) and color:
            entry["color"] = color
        manifest.append(entry)
    return manifest


def _cmd_clone_with_tags(args: argparse.Namespace) -> int:
    source_id = _validate_mural_id(args.mural)
    source_manifest = _read_tag_manifest(source_id)
    new_id = _duplicate_mural(source_id)
    tag_map = _ensure_tag_manifest(new_id, source_manifest) if source_manifest else {}
    return _emit_record(
        {
            "source_mural_id": source_id,
            "new_mural_id": new_id,
            "tag_count": len(tag_map),
            "tag_map": tag_map,
            "warnings": ["widget ids are not preserved across mural duplication"],
        },
        args,
    )


def _template_target_body(
    workspace: str | None, room: str | None, name: str | None = None
) -> dict[str, Any]:
    body: dict[str, Any] = {"workspaceId": _resolve_workspace_id(workspace)}
    if room:
        body["roomId"] = room
    if name:
        body["name"] = name
    return body


def _cmd_template_instantiate(args: argparse.Namespace) -> int:
    template_id = (args.template or "").strip()
    if not template_id:
        raise MuralValidationError("--template is required")
    body = _template_target_body(
        getattr(args, "workspace", None),
        getattr(args, "room", None),
        getattr(args, "name", None),
    )
    record = _authenticated_request(
        "POST", f"/templates/{template_id}/instantiate", json_body=body
    )
    return _emit_record(record, args)


def _cmd_template_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _template_target_body(
        getattr(args, "workspace", None),
        getattr(args, "room", None),
        getattr(args, "name", None),
    )
    record = _authenticated_request(
        "POST", f"/murals/{mural_id}/template", json_body=body
    )
    return _emit_record(record, args)


def _cmd_template_list(args: argparse.Namespace) -> int:
    return _emit_record(
        _tool_template_list({"workspace": getattr(args, "workspace", None)}), args
    )


_POLL_OPS: dict[str, Callable[[Any, Any], bool]] = {
    "==": lambda a, b: a == b,
    "!=": lambda a, b: a != b,
}


def _parse_poll_condition(condition: str) -> tuple[list[str], str, str]:
    """Parse ``"path op value"`` into ``(path_segments, op, expected)``.

    Supported operators are ``==`` and ``!=``. The path is dotted (e.g.
    ``status`` or ``meta.status``). The value is taken verbatim and matched
    against the string form of the resolved field.
    """
    if not isinstance(condition, str) or not condition.strip():
        raise MuralValidationError("poll condition must be a non-empty string")
    text = condition.strip()
    op_used: str | None = None
    op_index = -1
    for op in ("==", "!="):
        idx = text.find(op)
        if idx > 0:
            op_used = op
            op_index = idx
            break
    if op_used is None or op_index <= 0:
        raise MuralValidationError(
            "poll condition must be 'path op value' with op == or !="
        )
    path = text[:op_index].strip()
    expected = text[op_index + len(op_used) :].strip()
    if not path or not expected:
        raise MuralValidationError(
            "poll condition path and expected value must be non-empty"
        )
    segments = [seg for seg in path.split(".") if seg]
    if not segments:
        raise MuralValidationError("poll condition path is invalid")
    return segments, op_used, expected


def _resolve_dotted(record: Any, segments: list[str]) -> Any:
    cursor: Any = record
    for seg in segments:
        if isinstance(cursor, dict):
            cursor = cursor.get(seg)
        else:
            return None
    return cursor


def _evaluate_poll(record: Any, segments: list[str], op: str, expected: str) -> bool:
    actual = _resolve_dotted(record, segments)
    actual_str = "" if actual is None else str(actual)
    return _POLL_OPS[op](actual_str, expected)


def _poll_mural(
    mural_id: str,
    *,
    interval_s: float,
    timeout_s: float,
    condition: str,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
    if interval_s <= 0:
        raise MuralValidationError("--interval must be positive")
    if timeout_s <= 0:
        raise MuralValidationError("--timeout must be positive")
    if interval_s > POLL_MAX_INTERVAL_S:
        raise MuralValidationError(
            f"--interval must be ≤ {POLL_MAX_INTERVAL_S} seconds"
        )
    if timeout_s > POLL_MAX_TIMEOUT_S:
        raise MuralValidationError(f"--timeout must be ≤ {POLL_MAX_TIMEOUT_S} seconds")
    segments, op, expected = _parse_poll_condition(condition)
    deadline = monotonic() + timeout_s
    attempt = 0
    last_record: Any = None
    while True:
        last_record = _authenticated_request("GET", f"/murals/{mural_id}")
        if _evaluate_poll(last_record, segments, op, expected):
            return {
                "matched": True,
                "attempts": attempt + 1,
                "condition": condition,
                "mural": last_record,
            }
        attempt += 1
        if monotonic() >= deadline:
            raise MuralValidationError(
                f"poll timeout after {timeout_s}s waiting for {condition!r}"
            )
        delay = min(interval_s * (2 ** min(attempt - 1, 2)), POLL_MAX_INTERVAL_S)
        remaining = deadline - monotonic()
        if remaining <= 0:
            raise MuralValidationError(
                f"poll timeout after {timeout_s}s waiting for {condition!r}"
            )
        sleep(min(delay, remaining))


def _cmd_mural_poll(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    result = _poll_mural(
        mural_id,
        interval_s=float(args.interval),
        timeout_s=float(args.timeout),
        condition=args.condition,
    )
    return _emit_record(result, args)


def _set_mural_status(mural_id: str, status: str) -> Any:
    return _authenticated_request(
        "PATCH", f"/murals/{mural_id}", json_body={"status": status}
    )


def _cmd_mural_archive(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _set_mural_status(mural_id, "archived")
    return _emit_record(record, args)


def _cmd_mural_unarchive(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _set_mural_status(mural_id, "active")
    return _emit_record(record, args)


# --- Voting sessions ---------------------------------------------------------


def _validate_voting_session_id(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise MuralValidationError("voting session id must be a non-empty string")
    return value.strip()


def _voting_session_path(mural_id: str, session_id: str | None = None) -> str:
    if session_id is None:
        return f"/murals/{mural_id}/voting-sessions"
    return f"/murals/{mural_id}/voting-sessions/{session_id}"


def _voting_session_create(mural_id: str, body: dict[str, Any]) -> dict[str, Any]:
    return _authenticated_request(
        "POST", _voting_session_path(mural_id), json_body=body
    )


def _voting_session_get(mural_id: str, session_id: str) -> dict[str, Any]:
    return _authenticated_request("GET", _voting_session_path(mural_id, session_id))


def _voting_session_list(
    mural_id: str, *, limit: int | None = None, page_size: int | None = None
) -> Any:
    return _paginate(
        "GET",
        _voting_session_path(mural_id),
        params=None,
        limit=limit,
        page_size=page_size,
    )


def _voting_session_set_status(
    mural_id: str, session_id: str, status: str
) -> dict[str, Any]:
    return _authenticated_request(
        "PATCH",
        _voting_session_path(mural_id, session_id),
        json_body={"status": status},
    )


def _voting_session_delete(mural_id: str, session_id: str) -> dict[str, Any]:
    return _authenticated_request("DELETE", _voting_session_path(mural_id, session_id))


def _voting_results(mural_id: str, session_id: str) -> dict[str, Any]:
    return _authenticated_request(
        "GET", f"{_voting_session_path(mural_id, session_id)}/results"
    )


def _poll_voting_session(
    mural_id: str,
    session_id: str,
    *,
    interval_s: float,
    timeout_s: float,
    condition: str,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
    """Poll a voting session record until ``condition`` matches or timeout."""
    if interval_s <= 0:
        raise MuralValidationError("--interval must be positive")
    if timeout_s <= 0:
        raise MuralValidationError("--timeout must be positive")
    if interval_s > POLL_MAX_INTERVAL_S:
        raise MuralValidationError(
            f"--interval must be ≤ {POLL_MAX_INTERVAL_S} seconds"
        )
    if timeout_s > POLL_MAX_TIMEOUT_S:
        raise MuralValidationError(f"--timeout must be ≤ {POLL_MAX_TIMEOUT_S} seconds")
    segments, op, expected = _parse_poll_condition(condition)
    deadline = monotonic() + timeout_s
    attempt = 0
    last_record: Any = None
    while True:
        last_record = _voting_session_get(mural_id, session_id)
        if _evaluate_poll(last_record, segments, op, expected):
            return {
                "matched": True,
                "attempts": attempt + 1,
                "condition": condition,
                "session": last_record,
            }
        attempt += 1
        if monotonic() >= deadline:
            raise MuralValidationError(
                f"poll timeout after {timeout_s}s waiting for {condition!r}"
            )
        delay = min(interval_s * (2 ** min(attempt - 1, 2)), POLL_MAX_INTERVAL_S)
        remaining = deadline - monotonic()
        if remaining <= 0:
            raise MuralValidationError(
                f"poll timeout after {timeout_s}s waiting for {condition!r}"
            )
        sleep(min(delay, remaining))


def _cmd_voting_session_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body_raw = _parse_json_arg(_load_payload_file(args.file), "--file")
    if not isinstance(body_raw, dict):
        raise MuralValidationError("voting session payload must be a JSON object")
    record = _voting_session_create(mural_id, body_raw)
    return _emit_record(record, args)


def _cmd_voting_session_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_get(mural_id, session_id)
    return _emit_record(record, args)


def _cmd_voting_session_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = list(_voting_session_list(mural_id, **_list_kwargs(args)))
    return _emit_records(records, args)


def _cmd_voting_session_open(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_set_status(mural_id, session_id, "active")
    return _emit_record(record, args)


def _cmd_voting_session_close(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_set_status(mural_id, session_id, "closed")
    return _emit_record(record, args)


def _cmd_voting_session_delete(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_delete(mural_id, session_id)
    return _emit_record(record, args)


def _cmd_voting_results(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_results(mural_id, session_id)
    return _emit_record(record, args)


def _cmd_voting_poll(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    result = _poll_voting_session(
        mural_id,
        session_id,
        interval_s=float(args.interval),
        timeout_s=float(args.timeout),
        condition=args.condition,
    )
    return _emit_record(result, args)


def _voting_run_compose(
    mural_id: str,
    create_body: dict[str, Any],
    *,
    poll_condition: str = "status==closed",
    poll_interval_s: float = POLL_DEFAULT_INTERVAL_S,
    poll_timeout_s: float = POLL_DEFAULT_TIMEOUT_S,
    close_on_timeout: bool = True,
) -> dict[str, Any]:
    """Composite: create→open→poll→close→results.

    Returns ``{session, results, poll, closed_on_timeout, warnings}``.
    """
    warnings: list[str] = []
    closed_on_timeout = False
    session = _voting_session_create(mural_id, create_body)
    session_id_raw = session.get("id") if isinstance(session, dict) else None
    if not isinstance(session_id_raw, str) or not session_id_raw:
        raise MuralAPIError(
            0, "VOTING_NO_ID", "voting session create response missing id"
        )
    session_id = session_id_raw
    session = _voting_session_set_status(mural_id, session_id, "active")
    poll_result: dict[str, Any] | None = None
    try:
        poll_result = _poll_voting_session(
            mural_id,
            session_id,
            interval_s=poll_interval_s,
            timeout_s=poll_timeout_s,
            condition=poll_condition,
        )
    except MuralValidationError as exc:
        if not close_on_timeout:
            raise
        warnings.append(f"poll timed out: {exc}")
        closed_on_timeout = True
    closed = _voting_session_set_status(mural_id, session_id, "closed")
    results = _voting_results(mural_id, session_id)
    return {
        "session": closed,
        "results": results,
        "poll": poll_result,
        "closed_on_timeout": closed_on_timeout,
        "warnings": warnings,
    }


# --- Voting tool handlers ----------------------------------------------------


def _tool_voting_session_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    body = arguments.get("body")
    if not isinstance(body, dict) or not body:
        raise MCPInvalidParamsError("body is required and must be a JSON object")
    return _voting_session_create(mural_id, body)


def _tool_voting_session_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_get(mural_id, session_id)


def _tool_voting_session_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    limit = arguments.get("limit")
    page_size = arguments.get("page_size")
    return list(
        _voting_session_list(
            mural_id,
            limit=int(limit) if isinstance(limit, int) else None,
            page_size=int(page_size) if isinstance(page_size, int) else None,
        )
    )


def _tool_voting_session_open(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_set_status(mural_id, session_id, "active")


def _tool_voting_session_close(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_set_status(mural_id, session_id, "closed")


def _tool_voting_session_delete(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_delete(mural_id, session_id)


def _tool_voting_results(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_results(mural_id, session_id)


def _tool_voting_poll(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    interval = arguments.get("interval", POLL_DEFAULT_INTERVAL_S)
    timeout = arguments.get("timeout", POLL_DEFAULT_TIMEOUT_S)
    condition = arguments.get("condition") or "status==closed"
    if not isinstance(condition, str) or not condition.strip():
        raise MCPInvalidParamsError("condition must be a non-empty string")
    return _poll_voting_session(
        mural_id,
        session_id,
        interval_s=float(interval),
        timeout_s=float(timeout),
        condition=condition,
    )


def _tool_voting_run(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    body = arguments.get("body")
    if not isinstance(body, dict) or not body:
        raise MCPInvalidParamsError("body is required and must be a JSON object")
    confirmed = arguments.get("confirmation_id")
    if confirmed is None:
        preview = {
            "mural_id": mural_id,
            "create_body": body,
            "steps": ["create", "open", "poll", "close", "results"],
        }
        preview_id = _confirmation_register(
            tool="mural_voting_run",
            arguments=arguments,
            candidates=[preview],
        )
        return {
            "confirmation_required": True,
            "confirmation_id": preview_id,
            "preview": preview,
        }
    _confirmation_consume(tool="mural_voting_run", confirmed_id=str(confirmed))
    poll_condition = arguments.get("poll_condition") or "status==closed"
    interval = float(arguments.get("poll_interval", POLL_DEFAULT_INTERVAL_S))
    timeout = float(arguments.get("poll_timeout", POLL_DEFAULT_TIMEOUT_S))
    close_on_timeout = bool(arguments.get("close_on_timeout", True))
    return _voting_run_compose(
        mural_id,
        body,
        poll_condition=poll_condition,
        poll_interval_s=interval,
        poll_timeout_s=timeout,
        close_on_timeout=close_on_timeout,
    )


# --- Workspace search --------------------------------------------------------


def _tool_workspace_search(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    query = arguments.get("query")
    if not isinstance(query, str) or not query.strip():
        raise MCPInvalidParamsError("query is required and must be a non-empty string")
    limit = arguments.get("limit")
    page_size = arguments.get("page_size")
    return list(
        _paginate(
            "GET",
            f"/search/{workspace_id}/murals",
            params={"q": query.strip()},
            limit=int(limit) if isinstance(limit, int) else None,
            page_size=int(page_size) if isinstance(page_size, int) else None,
        )
    )


def _cmd_workspace_search(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(args.workspace)
    query = args.query
    if not isinstance(query, str) or not query.strip():
        raise MuralValidationError("--query is required and must be non-empty")
    records = _paginate(
        "GET",
        f"/search/{workspace_id}/murals",
        params={"q": query.strip()},
        **_list_kwargs(args),
    )
    return _emit_records(list(records), args)


def _load_payload_file(path: str) -> str:
    """Read a UTF-8 JSON payload file and return the raw string."""
    if not isinstance(path, str) or not path:
        raise MuralValidationError("--file is required")
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        raise MuralValidationError(f"could not read {path}: {exc}") from exc


def _cmd_widget_get_with_context(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _get_widget_with_context(mural_id, args.widget)
    return _emit_record(record, args)


def _cmd_widget_list_with_context(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    list_kwargs = _list_kwargs(args)
    records = _list_widgets_with_context(
        mural_id,
        widget_type=getattr(args, "type", None),
        parent_id=getattr(args, "parent_id", None),
        limit=list_kwargs["limit"],
        page_size=list_kwargs["page_size"],
    )
    return _emit_records(records, args)


# --- Tool handlers --------------------------------------------------------
#
# Each handler receives a validated ``arguments`` dict and returns a Python
# object that will be JSON-encoded by callers. Handlers reuse the same Mural
# API helpers (``_authenticated_request``, ``_paginate``, body builders) as
# the CLI ``_cmd_*`` functions but skip the argparse Namespace +
# stdout-printing layer.


def _ns_for_list(arguments: dict[str, Any]) -> argparse.Namespace:
    return argparse.Namespace(
        limit=arguments.get("limit"),
        page_size=arguments.get("page_size"),
    )


def _ns_for_widget_body(arguments: dict[str, Any]) -> argparse.Namespace:
    """Build a Namespace compatible with the ``_build_*_body`` helpers.

    ``style`` accepts a JSON object via MCP; we re-encode it so the existing
    builder (which calls ``_parse_json_arg``/``json.loads``) decodes it back.
    """
    ns = argparse.Namespace(**arguments)
    style = arguments.get("style")
    if isinstance(style, (dict, list)):
        ns.style = json.dumps(style)
    return ns


def _tool_workspace_list(arguments: dict[str, Any]) -> Any:
    kwargs = _list_kwargs(_ns_for_list(arguments))
    return list(_paginate("GET", "/workspaces", **kwargs))


def _tool_workspace_get(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return _authenticated_request("GET", f"/workspaces/{workspace_id}")


def _tool_room_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_room_get(arguments: dict[str, Any]) -> Any:
    return _authenticated_request("GET", f"/rooms/{arguments['room']}")


def _tool_room_create(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    name = arguments.get("name")
    if not isinstance(name, str) or not name.strip():
        raise MCPInvalidParamsError("name is required")
    payload: dict[str, Any] = {
        "workspaceId": workspace_id,
        "name": name,
        "type": arguments.get("type", "private"),
    }
    description = arguments.get("description")
    if isinstance(description, str) and description:
        payload["description"] = description
    return _authenticated_request("POST", "/rooms", json_body=payload)


def _tool_mural_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_mural_create(arguments: dict[str, Any]) -> Any:
    room = arguments.get("room")
    if room is None or not str(room).strip():
        raise MCPInvalidParamsError("room is required")
    try:
        room_id = int(str(room).strip())
    except (TypeError, ValueError) as exc:
        raise MCPInvalidParamsError(f"room must be an integer room id ({exc})")
    title = arguments.get("title")
    if not isinstance(title, str) or not title.strip():
        raise MCPInvalidParamsError("title is required")
    payload: dict[str, Any] = {"roomId": room_id, "title": title}
    return _authenticated_request("POST", "/murals", json_body=payload)


def _tool_mural_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _authenticated_request("GET", f"/murals/{mural_id}")


def _tool_widget_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    params: dict[str, Any] = {}
    if arguments.get("type"):
        params["type"] = arguments["type"]
    if arguments.get("parent_id"):
        params["parentId"] = arguments["parent_id"]
    return list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_widget_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )


def _tool_widget_update(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = arguments["body"]
    if not isinstance(body, dict):
        raise MuralValidationError("body must be a JSON object")
    if arguments.get("require_author_tag") and not arguments.get("force_human"):
        _assert_widget_has_author_tag(mural_id, arguments["widget"])
    return _patch_widget_or_disambiguate_404(mural_id, arguments["widget"], body)


def _tool_widget_delete(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    if arguments.get("require_author_tag") and not arguments.get("force_human"):
        _assert_widget_has_author_tag(mural_id, arguments["widget"])
    _authenticated_request(
        "DELETE", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )
    return {"ok": True, "deleted": arguments["widget"]}


def _tool_widget_create_sticky_note(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_sticky_note_body(_ns_for_widget_body(arguments))
    record = _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/sticky-note", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _tool_widget_create_textbox(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_textbox_body(_ns_for_widget_body(arguments))
    record = _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/textbox", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _tool_widget_create_shape(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_shape_body(_ns_for_widget_body(arguments))
    record = _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/shape", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _tool_widget_create_arrow(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_arrow_body(_ns_for_widget_body(arguments))
    record = _authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/arrow", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _tool_widget_create_image(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    if not (arguments.get("alt_text") or "").strip():
        raise MuralValidationError(
            "alt_text is required for image widgets (WCAG 2.2 SC 1.1.1)"
        )
    file_path = pathlib.Path(arguments["file"]).expanduser()
    if not file_path.is_file():
        raise MuralValidationError(f"image file not found: {file_path}")
    suffix = file_path.suffix.lower()
    if suffix not in _IMAGE_CONTENT_TYPES:
        raise MuralValidationError(
            f"unsupported image extension {suffix!r}; allowed: "
            + ", ".join(sorted(_IMAGE_CONTENT_TYPES))
        )
    body_bytes = file_path.read_bytes()
    asset = _create_asset_url(mural_id, suffix)
    _upload_to_sas(
        url=asset["url"],
        headers=asset.get("headers") or {},
        body=body_bytes,
        content_type=_IMAGE_CONTENT_TYPES[suffix],
    )
    record = _authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/image",
        json_body=_build_image_body(
            asset_name=asset["name"], args=_ns_for_widget_body(arguments)
        ),
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _tool_tag_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/tags",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _tool_tag_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _create_tag(mural_id, arguments["text"], arguments.get("color"))


def _tool_tag_apply(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    widget_id = arguments["widget"]
    tag_id = arguments.get("tag")
    text = arguments.get("text")
    if not tag_id and not text:
        raise MuralValidationError("tag apply requires 'tag' or 'text'")
    if not tag_id:
        manifest_entry: dict[str, Any] = {"text": _validate_tag_text(text)}
        if arguments.get("color"):
            manifest_entry["color"] = arguments["color"]
        mapping = _ensure_tag_manifest(mural_id, [manifest_entry])
        tag_id = mapping[text]
    return _merge_tags(mural_id, widget_id, additions=[tag_id])


def _tool_tag_remove(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    widget_id = arguments["widget"]
    tag_id = arguments["tag"]
    if _is_reserved_tag_id(mural_id, tag_id) and not arguments.get("force_reserved"):
        raise MuralValidationError(
            f"refusing to remove reserved tag {tag_id!r}; "
            "pass 'force_reserved' to override"
        )
    return _merge_tags(mural_id, widget_id, removals=[tag_id])


def _tool_area_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _list_areas_with_widget_fallback(
        mural_id, **_list_kwargs(_ns_for_list(arguments))
    )


def _tool_area_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _get_area_with_widget_fallback(mural_id, arguments["area"])


def _tool_area_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_area_body(_ns_for_widget_body(arguments))
    record = _authenticated_request("POST", f"/murals/{mural_id}/areas", json_body=body)
    if isinstance(record, dict):
        area_id = record.get("id")
        if isinstance(area_id, str):
            _area_cache[area_id] = record
    return record


def _tool_area_probe(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _area_probe(mural_id, arguments["area"])


def _tool_widget_get_with_context(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _get_widget_with_context(mural_id, arguments["widget"])


def _tool_widget_list_with_context(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    list_kwargs = _list_kwargs(_ns_for_list(arguments))
    return _list_widgets_with_context(
        mural_id,
        widget_type=arguments.get("type"),
        parent_id=arguments.get("parent_id"),
        limit=list_kwargs["limit"],
        page_size=list_kwargs["page_size"],
    )


def _tool_auth_status(arguments: dict[str, Any]) -> Any:
    path = _resolve_token_store_path()
    profile_arg = arguments.get("profile") if isinstance(arguments, dict) else None
    cred_profile = profile_arg or os.environ.get(ENV_PROFILE) or DEFAULT_PROFILE_NAME
    cred_path = _resolve_credential_file(cred_profile, os.environ)
    cred_keys = {
        "credential_file": str(cred_path),
        "credential_file_exists": cred_path.exists(),
    }
    store = _load_token_store(path)
    if not store:
        return {"authenticated": False, "token_store": str(path), **cred_keys}
    profile_name = _resolve_active_profile(store, os.environ, profile_arg)
    try:
        profile = _select_profile(store, profile_name)
    except MuralError:
        return {"authenticated": False, "token_store": str(path), **cred_keys}
    return {
        "authenticated": True,
        "token_store": str(path),
        "profile": profile_name,
        "granted_scopes": list(_token_granted_scopes(store, profile_name)),
        "expires_at": profile.get("expires_at"),
        "has_refresh_token": bool(profile.get("refresh_token")),
        **cred_keys,
    }


def _tool_spatial_widgets_in_shape(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    shape = _authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{arguments['shape_id']}"
    )
    if not isinstance(shape, dict):
        raise MuralAPIError(
            0, "WIDGET_INVALID", "shape widget response is not an object"
        )
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    rotation_aware = bool(arguments.get("rotation_aware")) or _ROTATION_ENABLED
    return widgets_in_shape(
        widgets,
        shape,
        mode=arguments.get("mode", "center"),
        rotation_aware=rotation_aware,
    )


def _tool_spatial_widgets_in_region(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    region = safe_rect(
        float(arguments["x"]),
        float(arguments["y"]),
        float(arguments["w"]),
        float(arguments["h"]),
    )
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    return widgets_in_region(widgets, region, mode=arguments.get("mode", "center"))


def _tool_spatial_pairwise_overlaps(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    rotation_aware = bool(arguments.get("rotation_aware")) or _ROTATION_ENABLED
    pairs = pairwise_overlaps(
        widgets,
        predicate=arguments.get("predicate", "intersects"),
        rotation_aware=rotation_aware,
    )
    return [{"a": a, "b": b} for a, b in pairs]


def _tool_spatial_cluster(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    clusters = cluster_widgets(
        widgets,
        eps_px=float(arguments.get("eps_px", 120.0)),
        min_samples=int(arguments.get("min_samples", 2)),
    )
    return [{"members": members} for members in clusters]


def _tool_spatial_sort_along_axis(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    ox = arguments.get("origin_x")
    oy = arguments.get("origin_y")
    if ox is None and oy is None:
        origin = None
    elif ox is not None and oy is not None:
        origin = (float(ox), float(oy))
    else:
        raise ValueError("origin_x and origin_y must be provided together")
    return sort_along_axis(
        widgets,
        axis=str(arguments.get("axis", "x")),
        origin=origin,
    )


def _tool_spatial_arrow_graph(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    all_widgets = list(
        _paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    arrows = [w for w in all_widgets if str(w.get("type", "")).lower() == "arrow"]
    targets = [w for w in all_widgets if str(w.get("type", "")).lower() != "arrow"]
    snap_radius = float(arguments.get("snap_radius", 24.0))
    if snap_radius <= 0.0:
        raise ValueError("snap_radius must be greater than 0")
    graph = build_arrow_graph(targets, arrows, snap_radius=snap_radius)
    summary = arrow_graph_summary(graph)
    fmt = str(arguments.get("format", "summary"))
    if fmt == "summary":
        return summary
    if fmt == "full":
        index = {str(w.get("id", "")): w for w in arrows}
        edges_full: list[dict[str, Any]] = []
        for edge in summary["edges"]:
            entry = dict(edge)
            entry["arrow_widget"] = index.get(edge["id"])
            edges_full.append(entry)
        payload = dict(summary)
        payload["edges"] = edges_full
        return payload
    if fmt == "dot":
        lines = ["digraph G {"]
        for node in summary["nodes"]:
            lines.append(f'  "{node}";')
        for edge in summary["edges"]:
            lines.append(
                f'  "{edge["source"]}" -> "{edge["target"]}" [label="{edge["id"]}"];'
            )
        lines.append("}")
        return {"format": "dot", "text": "\n".join(lines)}
    raise ValueError(f"invalid format value: {fmt!r}")


def _tool_widget_create_bulk(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    widgets = _build_bulk_widgets_payload(arguments.get("widgets"))
    result = _bulk_create_widgets(
        mural_id, widgets, atomic=bool(arguments.get("atomic"))
    )
    _bulk_apply_author_tag(mural_id, result, skip=bool(arguments.get("no_author_tag")))
    return result


def _tool_widget_update_bulk(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    updates = _build_bulk_widget_updates_payload(arguments.get("updates"))
    return _bulk_update_widgets(
        mural_id,
        updates,
        atomic=bool(arguments.get("atomic")),
        require_author_tag=bool(arguments.get("require_author_tag")),
        force_human=bool(arguments.get("force_human")),
    )


def _tool_mural_duplicate(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    new_id = _duplicate_mural(mural_id)
    return {"new_mural_id": new_id, "source_mural_id": mural_id}


def _tool_clone_with_tags(arguments: dict[str, Any]) -> Any:
    source_id = _validate_mural_id(arguments.get("mural"))
    source_manifest = _read_tag_manifest(source_id)
    new_id = _duplicate_mural(source_id)
    tag_map = _ensure_tag_manifest(new_id, source_manifest) if source_manifest else {}
    return {
        "source_mural_id": source_id,
        "new_mural_id": new_id,
        "tag_count": len(tag_map),
        "tag_map": tag_map,
        "warnings": ["widget ids are not preserved across mural duplication"],
    }


def _tool_template_instantiate(arguments: dict[str, Any]) -> Any:
    template_id = arguments.get("template")
    if not isinstance(template_id, str) or not template_id.strip():
        raise MCPInvalidParamsError("template is required")
    body = _template_target_body(
        arguments.get("workspace"),
        arguments.get("room"),
        arguments.get("name"),
    )
    return _authenticated_request(
        "POST", f"/templates/{template_id.strip()}/instantiate", json_body=body
    )


def _tool_template_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    body = _template_target_body(
        arguments.get("workspace"),
        arguments.get("room"),
        arguments.get("name"),
    )
    return _authenticated_request(
        "POST", f"/murals/{mural_id}/template", json_body=body
    )


_TEMPLATE_REGISTRY: list[dict[str, str]] = []


def _tool_template_list(arguments: dict[str, Any]) -> Any:
    workspace = arguments.get("workspace")
    if workspace is not None and (
        not isinstance(workspace, str) or not workspace.strip()
    ):
        raise MCPInvalidParamsError("workspace must be a non-empty string when set")
    return {"templates": [dict(entry) for entry in _TEMPLATE_REGISTRY]}


def _tool_mural_poll(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    interval = arguments.get("interval_s", POLL_DEFAULT_INTERVAL_S)
    timeout = arguments.get("timeout_s", POLL_DEFAULT_TIMEOUT_S)
    condition = arguments.get("condition")
    if not isinstance(condition, str):
        raise MCPInvalidParamsError("condition is required")
    return _poll_mural(
        mural_id,
        interval_s=float(interval),
        timeout_s=float(timeout),
        condition=condition,
    )


def _tool_mural_archive(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    return _set_mural_status(mural_id, "archived")


def _tool_mural_unarchive(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    return _set_mural_status(mural_id, "active")


def _tool_layout(layout: str, arguments: dict[str, Any]) -> Any:
    """Shared handler body for the four ``mural_layout_*`` tools.

    Validates inputs, runs the named layout, and returns the structured
    ``{computed_metadata, widgets, skipped, warnings}`` payload. The
    underlying executor raises :class:`MuralAreaCapacityExceeded` when the
    placed widgets would overflow the area; that exception is mapped to
    the ``AREA_CAPACITY_EXCEEDED`` envelope by the top-level CLI handler.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments.get("mural"))
    area_id = arguments.get("area")
    if not isinstance(area_id, str) or not area_id.strip():
        raise MCPInvalidParamsError("area is required")
    widgets = arguments.get("widgets")
    if not isinstance(widgets, list) or not widgets:
        raise MCPInvalidParamsError("widgets must be a non-empty array")
    if len(widgets) > MAX_BULK_WIDGETS:
        raise MCPInvalidParamsError(
            f"widgets exceeds MAX_BULK_WIDGETS ({MAX_BULK_WIDGETS})"
        )
    params: dict[str, Any] = {}
    for key in ("cell_width", "cell_height", "gutter"):
        value = arguments.get(key)
        if value is not None:
            params[key] = float(value)
    if layout == "grid":
        columns = arguments.get("columns")
        if not isinstance(columns, int) or columns < 1:
            raise MCPInvalidParamsError("columns must be a positive integer")
        params["columns"] = columns
    origin = arguments.get("origin")
    if isinstance(origin, list) and len(origin) == 2:
        params["origin"] = (float(origin[0]), float(origin[1]))
    plan = _execute_layout(
        layout=layout,
        mural_id=mural_id,
        area_id=area_id.strip(),
        widgets=widgets,
        params=params,
    )
    bulk = _bulk_create_widgets(mural_id, plan["widgets"])
    plan["widgets"] = bulk["succeeded"]
    plan["skipped"] = bulk["skipped"]
    plan.setdefault("warnings", []).extend(bulk["warnings"])
    return plan


def _tool_layout_grid(arguments: dict[str, Any]) -> Any:
    return _tool_layout("grid", arguments)


def _tool_layout_cluster(arguments: dict[str, Any]) -> Any:
    return _tool_layout("cluster", arguments)


def _tool_layout_column(arguments: dict[str, Any]) -> Any:
    return _tool_layout("column", arguments)


def _tool_layout_row(arguments: dict[str, Any]) -> Any:
    return _tool_layout("row", arguments)


# --- Tool schemas + registry ---------------------------------------------


_LIMIT_PROPERTY: dict[str, Any] = {
    "type": "integer",
    "minimum": 1,
    "maximum": _MAX_PAGE_SIZE * 100,
    "description": "Maximum total records to return.",
}
_PAGE_SIZE_PROPERTY: dict[str, Any] = {
    "type": "integer",
    "minimum": 1,
    "maximum": _MAX_PAGE_SIZE,
    "description": f"Page size (max {_MAX_PAGE_SIZE}).",
}
_WIDGET_XY_PROPERTY: dict[str, Any] = {"type": "number"}
_HYPERLINK_PROPERTY: dict[str, Any] = {
    "type": "string",
    "minLength": 1,
    "maxLength": _MAX_HYPERLINK_LEN,
    "description": (
        f"Optional URL to attach to the widget (max {_MAX_HYPERLINK_LEN} chars)."
    ),
}
_TAG_TEXT_PROPERTY: dict[str, Any] = {
    "type": "string",
    "minLength": 1,
    "maxLength": _MAX_TAG_TEXT_LEN,
    "description": (f"Tag label (max {_MAX_TAG_TEXT_LEN} chars per Mural API)."),
}

_DRY_RUN_PROPERTY: dict[str, Any] = {
    "type": "boolean",
    "default": False,
    "description": (
        "When true, validate inputs and return a preview of the API call "
        "without writing to Mural. Skips the OAuth scope check."
    ),
}
_IDEMPOTENCY_KEY_PROPERTY: dict[str, Any] = {
    "type": "string",
    "minLength": 1,
    "maxLength": 256,
    "description": (
        "Caller-supplied key. When the same (tool, key) pair is replayed "
        "within the in-process cache the previous result is returned and the "
        "API is not re-invoked."
    ),
}
_NO_AUTHOR_TAG_PROPERTY: dict[str, Any] = {
    "type": "boolean",
    "default": False,
    "description": (
        "When true, skip attaching the reserved 'authored-by-ai' tag to "
        "newly created widgets."
    ),
}
_REQUIRE_AUTHOR_TAG_PROPERTY: dict[str, Any] = {
    "type": "boolean",
    "default": False,
    "description": (
        "When true, refuse to mutate the widget unless it carries the "
        "reserved 'authored-by-ai' tag. Use `force_human` to override."
    ),
}
_FORCE_HUMAN_PROPERTY: dict[str, Any] = {
    "type": "boolean",
    "default": False,
    "description": ("Override `require_author_tag` and act on human-authored widgets."),
}
_FORCE_RESERVED_PROPERTY: dict[str, Any] = {
    "type": "boolean",
    "default": False,
    "description": ("Allow removal of reserved tags such as 'authored-by-ai'."),
}

# In-process idempotency cache for create-style tools. Bounded LRU using
# ``OrderedDict``; holds previously formatted tool results keyed by
# ``(tool_name, idempotency_key)``. Process-local only — not persisted.
_IDEMPOTENCY_MAX = 128
_IDEMPOTENCY_CACHE: "collections.OrderedDict[tuple[str, str], dict[str, Any]]" = (
    collections.OrderedDict()
)


def _idempotency_get(name: str, key: str) -> dict[str, Any] | None:
    payload = _IDEMPOTENCY_CACHE.get((name, key))
    if payload is None:
        return None
    _IDEMPOTENCY_CACHE.move_to_end((name, key))
    return payload


def _idempotency_put(name: str, key: str, payload: dict[str, Any]) -> None:
    _IDEMPOTENCY_CACHE[(name, key)] = payload
    _IDEMPOTENCY_CACHE.move_to_end((name, key))
    while len(_IDEMPOTENCY_CACHE) > _IDEMPOTENCY_MAX:
        _IDEMPOTENCY_CACHE.popitem(last=False)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mural",
        description="Mural REST API CLI.",
    )
    parser.add_argument(
        "--log-level",
        default="WARNING",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity (default: WARNING).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational stderr output (errors still print).",
    )
    parser.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        help="Force JSON output, overriding any --format value.",
    )
    parser.add_argument(
        "--color",
        choices=["auto", "always", "never"],
        default="auto",
        help=(
            "Colorize stderr output. Default 'auto' honours NO_COLOR / "
            "FORCE_COLOR and falls back to TTY detection."
        ),
    )
    parser.add_argument(
        "--profile",
        default=None,
        help=(
            "Profile name override. Precedence: --profile > MURAL_PROFILE "
            "env var > active_profile in the token store > 'default'."
        ),
    )
    sub = parser.add_subparsers(dest="command", required=True)

    auth = sub.add_parser("auth", help="OAuth 2.0 + PKCE authentication helpers")
    auth_sub = auth.add_subparsers(dest="auth_command", required=True)

    login = auth_sub.add_parser("login", help="Interactive loopback OAuth login")
    login.add_argument(
        "--scopes",
        default=None,
        help="Override the default scope string.",
    )
    login.add_argument(
        "--write",
        action="store_true",
        help=(
            "Request write scopes (murals:write) in addition to the default "
            "read-only set. Ignored when --scopes is supplied."
        ),
    )
    login.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Seconds to wait for the OAuth callback (default: 300).",
    )
    login.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Profile name to write the resulting tokens under.",
    )
    login.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Continue even when the active credential backend already "
            "holds tokens for this profile."
        ),
    )
    login.set_defaults(func=_cmd_auth_login)

    setup = auth_sub.add_parser(
        "setup",
        help="Provision a profile non-interactively (env- or flag-driven).",
    )
    setup.add_argument("--profile", dest="profile", default=argparse.SUPPRESS)
    setup.add_argument("--client-id", dest="client_id", default=None)
    setup.add_argument("--scope", dest="scope", default=None)
    setup.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help=(
            "Emit a JSON status envelope instead of the human-readable "
            "OAuth setup walkthrough."
        ),
    )
    setup.set_defaults(func=_cmd_auth_setup)

    bootstrap = auth_sub.add_parser(
        "bootstrap",
        help="Interactively store Mural app credentials (one-time setup)",
        description=(
            "Open the Mural developer portal in a browser and prompt for "
            "Client ID / Client Secret, then persist them via the active "
            "credential backend (MURAL_CREDENTIAL_BACKEND={auto|keyring|"
            "file|env-only}). Subsequent CLI runs resolve credentials "
            "through the same backend."
        ),
    )
    bootstrap.add_argument("--profile", dest="profile", default=argparse.SUPPRESS)
    bootstrap.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Overwrite credentials already stored in the active backend "
            "for this profile."
        ),
    )
    bootstrap.add_argument(
        "--no-test",
        dest="no_test",
        action="store_true",
        default=False,
        help=(
            "Skip the post-bootstrap credential probe against Mural's "
            "/token endpoint (use for offline runs or to debug a "
            "rejected credential separately)."
        ),
    )
    bootstrap.set_defaults(func=_cmd_auth_bootstrap)

    list_p = auth_sub.add_parser("list", help="List configured profiles")
    list_p.add_argument(
        "--format",
        dest="format",
        choices=("json", "table"),
        default="json",
        help="Output format (default: json).",
    )
    list_p.set_defaults(func=_cmd_auth_list)

    use = auth_sub.add_parser("use", help="Set the active profile")
    use.add_argument("name", help="Profile name to mark active")
    use.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of a human log line.",
    )
    use.set_defaults(func=_cmd_auth_use)

    logout = auth_sub.add_parser(
        "logout",
        help="Remove credentials (current profile, named profile, or all)",
    )
    logout_target = logout.add_mutually_exclusive_group()
    logout_target.add_argument(
        "--all",
        dest="all",
        action="store_true",
        help="Remove every profile (atomically replaces the envelope).",
    )
    logout_target.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Remove only the named profile.",
    )
    logout.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of a human log line.",
    )
    logout.add_argument(
        "--keep-credentials",
        dest="keep_credentials",
        action="store_true",
        help=(
            "Remove tokens from the token store but leave Mural app "
            "credentials (client_id / client_secret) untouched in the "
            "active credential backend."
        ),
    )
    logout.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Required to remove credentials from the file backend (deletes "
            "the credential file). Has no effect on keyring removals."
        ),
    )
    logout.set_defaults(func=_cmd_auth_logout)

    status = auth_sub.add_parser("status", help="Show current auth status")
    status.set_defaults(func=_cmd_auth_status)

    migrate = auth_sub.add_parser(
        "migrate",
        help="Move Mural app credentials between keyring and file backends",
        description=(
            "Round-trip MURAL_CLIENT_ID and MURAL_CLIENT_SECRET between the "
            "OS keyring and the per-user credential file. Bypasses "
            "MURAL_CREDENTIAL_BACKEND so the operator can move secrets "
            "regardless of the active selector."
        ),
    )
    migrate.add_argument(
        "--to",
        dest="to",
        choices=("keyring", "file"),
        required=True,
        help="Destination backend.",
    )
    migrate.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Profile name (default: $MURAL_PROFILE or 'default').",
    )
    migrate.add_argument(
        "--cleanup",
        dest="cleanup",
        action="store_true",
        help="Remove credentials from the source backend after a successful migration.",
    )
    migrate.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Required with --cleanup when the source backend is the file "
            "backend (deletes the credential file)."
        ),
    )
    migrate.add_argument(
        "--yes",
        dest="yes",
        action="store_true",
        help=(
            "Skip the interactive confirmation prompt for --cleanup. "
            "Required when MURAL_NONINTERACTIVE=1."
        ),
    )
    migrate.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of human log lines.",
    )
    migrate.set_defaults(func=_cmd_auth_migrate)

    _add_resource_subcommands(sub)

    return parser


def _add_output_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--fields",
        default=None,
        help="Comma-separated dotted field paths to project from each record.",
    )
    parser.add_argument(
        "--format",
        default="json",
        choices=["json", "table"],
        help="Output format (default: json).",
    )


def _add_pagination_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help=(
            "Maximum total records to return (default: unbounded; paginate to "
            "exhaustion)."
        ),
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=_DEFAULT_PAGE_SIZE,
        help=(
            f"Per-page limit forwarded to Mural "
            f"(default: {_DEFAULT_PAGE_SIZE}, max {_MAX_PAGE_SIZE})."
        ),
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=None,
        help=(
            "Maximum number of API pages to fetch (default: unbounded). "
            "Use --max-pages 1 to disable pagination for debugging."
        ),
    )


def _add_xy(parser: argparse.ArgumentParser, *, required: bool = True) -> None:
    parser.add_argument("--x", type=float, required=required, help="X coordinate")
    parser.add_argument("--y", type=float, required=required, help="Y coordinate")
    parser.add_argument("--width", type=float, default=None, help="Width")
    parser.add_argument("--height", type=float, default=None, help="Height")


def _add_no_author_tag_flag(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--no-author-tag",
        dest="no_author_tag",
        action="store_true",
        help="Skip attaching the reserved 'authored-by-ai' tag to created widgets",
    )


def _add_author_guard_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--require-author-tag",
        dest="require_author_tag",
        action="store_true",
        help=(
            "Refuse to mutate widgets unless they carry the reserved "
            "'authored-by-ai' tag (use --force-human to override)"
        ),
    )
    parser.add_argument(
        "--force-human",
        dest="force_human",
        action="store_true",
        help="Override --require-author-tag and act on human-authored widgets",
    )


def _add_resource_subcommands(sub: argparse._SubParsersAction) -> None:
    workspace = sub.add_parser("workspace", help="Workspace operations")
    ws_sub = workspace.add_subparsers(dest="workspace_command", required=True)
    ws_list = ws_sub.add_parser("list", help="List workspaces")
    _add_output_flags(ws_list)
    _add_pagination_flags(ws_list)
    ws_list.set_defaults(func=_cmd_workspace_list)
    ws_get = ws_sub.add_parser("get", help="Get a workspace")
    ws_get.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(ws_get)
    ws_get.set_defaults(func=_cmd_workspace_get)

    ws_search = ws_sub.add_parser(
        "search", help="Full-text search murals in a workspace"
    )
    ws_search.add_argument("--workspace", default=None, help="Workspace id")
    ws_search.add_argument(
        "--query", required=True, help="Search query (`q` parameter)"
    )
    _add_output_flags(ws_search)
    _add_pagination_flags(ws_search)
    ws_search.set_defaults(func=_cmd_workspace_search)

    room = sub.add_parser("room", help="Room operations")
    room_sub = room.add_subparsers(dest="room_command", required=True)
    room_list = room_sub.add_parser("list", help="List rooms in a workspace")
    room_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(room_list)
    _add_pagination_flags(room_list)
    room_list.set_defaults(func=_cmd_room_list)
    room_get = room_sub.add_parser("get", help="Get a room")
    room_get.add_argument("--room", required=True, help="Room id")
    _add_output_flags(room_get)
    room_get.set_defaults(func=_cmd_room_get)
    room_create = room_sub.add_parser("create", help="Create a room in a workspace")
    room_create.add_argument("--workspace", default=None, help="Workspace id")
    room_create.add_argument("--name", required=True, help="Room name")
    room_create.add_argument(
        "--type",
        choices=["private", "open"],
        default="private",
        help="Room type (default: private)",
    )
    room_create.add_argument(
        "--description", default=None, help="Optional room description"
    )
    _add_output_flags(room_create)
    room_create.set_defaults(func=_cmd_room_create)

    mural_p = sub.add_parser("mural", help="Mural operations")
    mural_sub = mural_p.add_subparsers(dest="mural_command", required=True)
    mural_list = mural_sub.add_parser("list", help="List murals in a workspace")
    mural_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(mural_list)
    _add_pagination_flags(mural_list)
    mural_list.set_defaults(func=_cmd_mural_list)
    mural_get = mural_sub.add_parser("get", help="Get a mural")
    mural_get.add_argument("--mural", required=True, help="Mural id (workspace.slug)")
    _add_output_flags(mural_get)
    mural_get.set_defaults(func=_cmd_mural_get)

    mural_create = mural_sub.add_parser("create", help="Create a mural in a room")
    mural_create.add_argument("--room", required=True, help="Room id (integer)")
    mural_create.add_argument("--title", required=True, help="Mural title")
    _add_output_flags(mural_create)
    mural_create.set_defaults(func=_cmd_mural_create)

    mural_dup = mural_sub.add_parser(
        "duplicate", help="Duplicate a mural and return the new mural id"
    )
    mural_dup.add_argument("--mural", required=True, help="Source mural id")
    _add_output_flags(mural_dup)
    mural_dup.set_defaults(func=_cmd_mural_duplicate)

    mural_clone = mural_sub.add_parser(
        "clone-with-tags",
        help="Duplicate a mural and replay its tag manifest on the new mural",
    )
    mural_clone.add_argument("--mural", required=True, help="Source mural id")
    _add_output_flags(mural_clone)
    mural_clone.set_defaults(func=_cmd_clone_with_tags)

    mural_poll = mural_sub.add_parser(
        "poll", help="Poll a mural until a dotted-path condition matches"
    )
    mural_poll.add_argument("--mural", required=True, help="Mural id")
    mural_poll.add_argument(
        "--condition",
        required=True,
        help="Condition 'path op value' where op is == or !=",
    )
    mural_poll.add_argument(
        "--interval",
        type=float,
        default=POLL_DEFAULT_INTERVAL_S,
        help=f"Initial poll interval in seconds (default {POLL_DEFAULT_INTERVAL_S})",
    )
    mural_poll.add_argument(
        "--timeout",
        type=float,
        default=POLL_DEFAULT_TIMEOUT_S,
        help=f"Timeout in seconds (default {POLL_DEFAULT_TIMEOUT_S})",
    )
    _add_output_flags(mural_poll)
    mural_poll.set_defaults(func=_cmd_mural_poll)

    mural_archive = mural_sub.add_parser(
        "archive", help="Archive a mural (status=archived)"
    )
    mural_archive.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_archive)
    mural_archive.set_defaults(func=_cmd_mural_archive)

    mural_unarchive = mural_sub.add_parser(
        "unarchive", help="Unarchive a mural (status=active)"
    )
    mural_unarchive.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_unarchive)
    mural_unarchive.set_defaults(func=_cmd_mural_unarchive)

    mural_find = mural_sub.add_parser(
        "find", help="Search murals by title (trigram similarity)"
    )
    mural_find.add_argument("--workspace", default=None, help="Workspace id")
    mural_find.add_argument("--query", required=True, help="Search text")
    mural_find.add_argument(
        "--min-score", type=float, default=None, help="Minimum trigram score (0..1)"
    )
    mural_find.add_argument(
        "--limit", type=int, default=None, help="Maximum candidates to return"
    )
    _add_output_flags(mural_find)
    mural_find.set_defaults(func=_cmd_mural_find)

    mural_repair = mural_sub.add_parser(
        "repair-tag-drift", help="Re-assert reserved tags on widgets in a mural"
    )
    mural_repair.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_repair)
    mural_repair.set_defaults(func=_cmd_mural_repair_tag_drift)

    template = sub.add_parser("template", help="Template operations")
    template_sub = template.add_subparsers(dest="template_command", required=True)

    tpl_inst = template_sub.add_parser(
        "instantiate", help="Create a new mural from a template"
    )
    tpl_inst.add_argument("--template", required=True, help="Template id")
    tpl_inst.add_argument("--workspace", default=None, help="Target workspace id")
    tpl_inst.add_argument("--room", default=None, help="Target room id")
    tpl_inst.add_argument("--name", default=None, help="Optional mural name")
    _add_output_flags(tpl_inst)
    tpl_inst.set_defaults(func=_cmd_template_instantiate)

    tpl_create = template_sub.add_parser(
        "create", help="Create a template from an existing mural"
    )
    tpl_create.add_argument("--mural", required=True, help="Source mural id")
    tpl_create.add_argument("--workspace", default=None, help="Target workspace id")
    tpl_create.add_argument("--room", default=None, help="Target room id")
    tpl_create.add_argument("--name", default=None, help="Optional template name")
    _add_output_flags(tpl_create)
    tpl_create.set_defaults(func=_cmd_template_create)

    tpl_list = template_sub.add_parser(
        "list", help="List known templates from the local registry"
    )
    tpl_list.add_argument("--workspace", default=None, help="Optional workspace filter")
    _add_output_flags(tpl_list)
    tpl_list.set_defaults(func=_cmd_template_list)

    widget = sub.add_parser("widget", help="Widget operations")
    widget_sub = widget.add_subparsers(dest="widget_command", required=True)

    w_list = widget_sub.add_parser("list", help="List widgets on a mural")
    w_list.add_argument("--mural", required=True, help="Mural id")
    w_list.add_argument("--type", default=None, help="Filter by widget type")
    w_list.add_argument("--parent-id", default=None, help="Filter by parent widget id")
    _add_output_flags(w_list)
    _add_pagination_flags(w_list)
    w_list.set_defaults(func=_cmd_widget_list)

    w_get = widget_sub.add_parser("get", help="Get a single widget")
    w_get.add_argument("--mural", required=True, help="Mural id")
    w_get.add_argument("--widget", required=True, help="Widget id")
    _add_output_flags(w_get)
    w_get.set_defaults(func=_cmd_widget_get)

    w_update = widget_sub.add_parser("update", help="Patch a widget with a JSON body")
    w_update.add_argument("--mural", required=True, help="Mural id")
    w_update.add_argument("--widget", required=True, help="Widget id")
    w_update.add_argument("--body", default=None, help="JSON patch body")
    w_update.add_argument(
        "--body-file",
        default=None,
        help=(
            "Path to a UTF-8 JSON file containing the patch body; "
            "mutually exclusive with --body"
        ),
    )
    w_update.add_argument(
        "--hyperlink", default=None, help="Optional URL to attach to the widget"
    )
    _add_author_guard_flags(w_update)
    _add_output_flags(w_update)
    w_update.set_defaults(func=_cmd_widget_update)

    w_delete = widget_sub.add_parser("delete", help="Delete a widget")
    w_delete.add_argument("--mural", required=True, help="Mural id")
    w_delete.add_argument("--widget", required=True, help="Widget id")
    _add_author_guard_flags(w_delete)
    w_delete.set_defaults(func=_cmd_widget_delete)

    w_create_bulk = widget_sub.add_parser(
        "create-bulk",
        help=(
            f"Create up to {MAX_BULK_WIDGETS} widgets from a JSON file via "
            "one POST per widget to the matching per-type endpoint"
        ),
    )
    w_create_bulk.add_argument("--mural", required=True, help="Mural id")
    w_create_bulk.add_argument(
        "--file",
        required=True,
        help="Path to a JSON file containing the widgets array",
    )
    w_create_bulk.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "Abort the run on the first per-widget failure "
            f"and exit {EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_no_author_tag_flag(w_create_bulk)
    _add_output_flags(w_create_bulk)
    w_create_bulk.set_defaults(func=_cmd_widget_create_bulk)

    w_update_bulk = widget_sub.add_parser(
        "update-bulk",
        help=(
            f"Update up to {MAX_BULK_WIDGETS} widgets from a JSON file with "
            "concurrent PATCH and per-widget retry"
        ),
    )
    w_update_bulk.add_argument("--mural", required=True, help="Mural id")
    w_update_bulk.add_argument(
        "--file",
        required=True,
        help=("Path to a JSON file containing an array of `{widget_id, body}` entries"),
    )
    w_update_bulk.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "Abort the run on the first per-widget failure and exit "
            f"{EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_author_guard_flags(w_update_bulk)
    _add_output_flags(w_update_bulk)
    w_update_bulk.set_defaults(func=_cmd_widget_update_bulk)

    w_diff = widget_sub.add_parser(
        "diff",
        help="Diff a local widget snapshot against the live mural state",
    )
    w_diff.add_argument("--mural", required=True, help="Mural id")
    w_diff.add_argument(
        "--file",
        required=True,
        help=(
            "Path to a JSON file containing a widgets array or an object "
            "with a 'widgets' array (the snapshot baseline)"
        ),
    )
    w_diff.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Push the snapshot to the live mural: create missing widgets, "
            "patch changed widgets to match the snapshot, and delete extras"
        ),
    )
    w_diff.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "With --apply, abort on the first failure in any phase and exit "
            f"{EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_output_flags(w_diff)
    w_diff.set_defaults(func=_cmd_widget_diff)

    w_create = widget_sub.add_parser("create", help="Create a widget by type")
    create_sub = w_create.add_subparsers(dest="widget_create_kind", required=True)

    sticky = create_sub.add_parser("sticky-note", help="Create a sticky-note widget")
    sticky.add_argument("--mural", required=True, help="Mural id")
    sticky.add_argument("--text", required=True, help="Sticky note text")
    sticky.add_argument(
        "--shape", default=None, help="Sticky shape (default: rectangle)"
    )
    sticky.add_argument("--style", default=None, help="JSON style overrides")
    sticky.add_argument("--hyperlink", default=None, help="Optional URL")
    sticky.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(sticky)
    _add_no_author_tag_flag(sticky)
    _add_output_flags(sticky)
    sticky.set_defaults(func=_cmd_widget_create_sticky_note)

    textbox = create_sub.add_parser("textbox", help="Create a textbox widget")
    textbox.add_argument("--mural", required=True, help="Mural id")
    textbox.add_argument("--text", required=True, help="Textbox text")
    textbox.add_argument("--style", default=None, help="JSON style overrides")
    textbox.add_argument("--hyperlink", default=None, help="Optional URL")
    textbox.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(textbox)
    _add_no_author_tag_flag(textbox)
    _add_output_flags(textbox)
    textbox.set_defaults(func=_cmd_widget_create_textbox)

    shape = create_sub.add_parser("shape", help="Create a shape widget")
    shape.add_argument("--mural", required=True, help="Mural id")
    shape.add_argument("--shape", required=True, help="Shape kind")
    shape.add_argument("--text", default=None, help="Optional shape text")
    shape.add_argument("--style", default=None, help="JSON style overrides")
    shape.add_argument("--hyperlink", default=None, help="Optional URL")
    shape.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(shape)
    _add_no_author_tag_flag(shape)
    _add_output_flags(shape)
    shape.set_defaults(func=_cmd_widget_create_shape)

    arrow = create_sub.add_parser("arrow", help="Create an arrow widget")
    arrow.add_argument("--mural", required=True, help="Mural id")
    arrow.add_argument("--x1", type=float, required=True, help="Start x")
    arrow.add_argument("--y1", type=float, required=True, help="Start y")
    arrow.add_argument("--x2", type=float, required=True, help="End x")
    arrow.add_argument("--y2", type=float, required=True, help="End y")
    arrow.add_argument("--style", default=None, help="JSON style overrides")
    arrow.add_argument("--hyperlink", default=None, help="Optional URL")
    arrow.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_no_author_tag_flag(arrow)
    _add_output_flags(arrow)
    arrow.set_defaults(func=_cmd_widget_create_arrow)

    image = create_sub.add_parser("image", help="Upload an image and create a widget")
    image.add_argument("--mural", required=True, help="Mural id")
    image.add_argument("--file", required=True, help="Local image file path")
    image.add_argument(
        "--alt-text",
        dest="alt_text",
        required=True,
        help=(
            "Alternative text describing the image (WCAG 2.2 SC 1.1.1). "
            "Required; must be a non-empty string."
        ),
    )
    image.add_argument("--title", default=None, help="Optional image title")
    image.add_argument("--hyperlink", default=None, help="Optional URL")
    image.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(image)
    _add_no_author_tag_flag(image)
    _add_output_flags(image)
    image.set_defaults(func=_cmd_widget_create_image)

    w_get_ctx = widget_sub.add_parser(
        "get-with-context", help="Get a widget plus area-chain and siblings"
    )
    w_get_ctx.add_argument("--mural", required=True, help="Mural id")
    w_get_ctx.add_argument("--widget", required=True, help="Widget id")
    _add_output_flags(w_get_ctx)
    w_get_ctx.set_defaults(func=_cmd_widget_get_with_context)

    w_list_ctx = widget_sub.add_parser(
        "list-with-context", help="List widgets including area-chain ancestry"
    )
    w_list_ctx.add_argument("--mural", required=True, help="Mural id")
    w_list_ctx.add_argument("--type", default=None, help="Filter by widget type")
    w_list_ctx.add_argument(
        "--parent-id", default=None, help="Filter by parent widget id"
    )
    _add_output_flags(w_list_ctx)
    _add_pagination_flags(w_list_ctx)
    w_list_ctx.set_defaults(func=_cmd_widget_list_with_context)

    tag = sub.add_parser("tag", help="Tag operations")
    tag_sub = tag.add_subparsers(dest="tag_command", required=True)

    t_list = tag_sub.add_parser("list", help="List tags on a mural")
    t_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(t_list)
    _add_pagination_flags(t_list)
    t_list.set_defaults(func=_cmd_tag_list)

    t_create = tag_sub.add_parser("create", help="Create a tag on a mural")
    t_create.add_argument("--mural", required=True, help="Mural id")
    t_create.add_argument("--text", required=True, help="Tag text (max 25 chars)")
    t_create.add_argument("--color", default=None, help="Optional color token")
    _add_output_flags(t_create)
    t_create.set_defaults(func=_cmd_tag_create)

    t_apply = tag_sub.add_parser("apply", help="Apply a tag to a widget")
    t_apply.add_argument("--mural", required=True, help="Mural id")
    t_apply.add_argument("--widget", required=True, help="Widget id")
    t_apply.add_argument("--tag", default=None, help="Existing tag id")
    t_apply.add_argument("--text", default=None, help="Tag text (creates if missing)")
    t_apply.add_argument("--color", default=None, help="Optional color token")
    _add_output_flags(t_apply)
    t_apply.set_defaults(func=_cmd_tag_apply)

    t_remove = tag_sub.add_parser("remove", help="Remove a tag from a widget")
    t_remove.add_argument("--mural", required=True, help="Mural id")
    t_remove.add_argument("--widget", required=True, help="Widget id")
    t_remove.add_argument("--tag", required=True, help="Tag id to remove")
    t_remove.add_argument(
        "--force-reserved",
        dest="force_reserved",
        action="store_true",
        help="Allow removal of reserved tags such as 'authored-by-ai'",
    )
    _add_output_flags(t_remove)
    t_remove.set_defaults(func=_cmd_tag_remove)

    area = sub.add_parser("area", help="Area operations")
    area_sub = area.add_subparsers(dest="area_command", required=True)

    a_list = area_sub.add_parser("list", help="List areas on a mural")
    a_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(a_list)
    _add_pagination_flags(a_list)
    a_list.set_defaults(func=_cmd_area_list)

    a_get = area_sub.add_parser("get", help="Get a single area (caches result)")
    a_get.add_argument("--mural", required=True, help="Mural id")
    a_get.add_argument("--area", required=True, help="Area id")
    _add_output_flags(a_get)
    a_get.set_defaults(func=_cmd_area_get)

    a_create = area_sub.add_parser("create", help="Create an area on a mural")
    a_create.add_argument("--mural", required=True, help="Mural id")
    a_create.add_argument("--title", required=True, help="Area title")
    a_create.add_argument("--x", type=float, default=None, help="Optional x")
    a_create.add_argument("--y", type=float, default=None, help="Optional y")
    a_create.add_argument("--width", type=float, default=None, help="Optional width")
    a_create.add_argument("--height", type=float, default=None, help="Optional height")
    a_create.add_argument(
        "--layout",
        default=None,
        choices=sorted(_VALID_AREA_LAYOUTS),
        help="Layout: free | column | row",
    )
    a_create.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_output_flags(a_create)
    a_create.set_defaults(func=_cmd_area_create)

    a_probe = area_sub.add_parser(
        "probe",
        help="Probe area z-order visibility",
    )
    a_probe.add_argument("--mural", required=True, help="Mural id")
    a_probe.add_argument("--area", required=True, help="Area id")
    _add_output_flags(a_probe)
    a_probe.set_defaults(func=_cmd_area_probe)

    layout = sub.add_parser("layout", help="Layout placement operations")
    layout_sub = layout.add_subparsers(dest="layout_command", required=True)
    for _name, _func, _needs_columns in (
        ("grid", _cmd_layout_grid, True),
        ("cluster", _cmd_layout_cluster, False),
        ("column", _cmd_layout_column, False),
        ("row", _cmd_layout_row, False),
    ):
        _p = layout_sub.add_parser(_name, help=f"Place widgets in a {_name} layout")
        _p.add_argument("--mural", required=True, help="Mural id")
        _p.add_argument("--area", required=True, help="Area id")
        _p.add_argument(
            "--widgets",
            required=True,
            help="Widgets payload (JSON array string, @path, or - for stdin)",
        )
        _p.add_argument(
            "--cell-width", type=float, default=None, help="Optional cell width"
        )
        _p.add_argument(
            "--cell-height", type=float, default=None, help="Optional cell height"
        )
        _p.add_argument("--gutter", type=float, default=None, help="Optional gutter")
        _p.add_argument("--origin", default=None, help='Optional origin "x,y"')
        if _needs_columns:
            _p.add_argument("--columns", type=int, required=True, help="Column count")
        _add_output_flags(_p)
        _p.set_defaults(func=_func)

    compose = sub.add_parser("compose", help="Composite Design Thinking operations")
    compose_sub = compose.add_subparsers(dest="compose_command", required=True)

    c_boot = compose_sub.add_parser(
        "bootstrap-dt-board", help="Create or reuse a Design Thinking mural"
    )
    c_boot.add_argument("--workspace", required=True, help="Workspace id")
    c_boot.add_argument("--room", required=True, help="Room id")
    c_boot.add_argument("--method", type=int, required=True, help="Method number 1..9")
    c_boot.add_argument("--title", default=None, help="Optional mural title")
    c_boot.add_argument(
        "--override-path",
        dest="override_path",
        default=None,
        help="Optional path to dt-sections override YAML",
    )
    _add_output_flags(c_boot)
    c_boot.set_defaults(func=_cmd_compose_bootstrap_dt_board)

    c_uxb = compose_sub.add_parser(
        "bootstrap-ux-board",
        help="Add the five UX research areas to an existing mural",
    )
    c_uxb.add_argument("--workspace", required=True, help="Workspace id")
    c_uxb.add_argument("--mural", required=True, help="Target mural id")
    _add_output_flags(c_uxb)
    c_uxb.set_defaults(func=_cmd_compose_bootstrap_ux_board)

    c_pop = compose_sub.add_parser(
        "populate-dt-section", help="Populate a Design Thinking section area"
    )
    c_pop.add_argument("--mural", required=True, help="Mural id")
    c_pop.add_argument("--area", required=True, help="Area id")
    c_pop.add_argument("--method", type=int, required=True, help="Method number 1..9")
    c_pop.add_argument("--section", required=True, help="Section name")
    c_pop.add_argument(
        "--items",
        required=True,
        help="Items payload (JSON array string, @path, or - for stdin)",
    )
    _add_output_flags(c_pop)
    c_pop.set_defaults(func=_cmd_compose_populate_dt_section)

    c_aff = compose_sub.add_parser(
        "affinity-cluster", help="Place pre-clustered items as affinity clusters"
    )
    c_aff.add_argument("--mural", required=True, help="Mural id")
    c_aff.add_argument("--area", required=True, help="Area id")
    c_aff.add_argument(
        "--clusters",
        required=True,
        help="Clusters payload (JSON array string, @path, or - for stdin)",
    )
    _add_output_flags(c_aff)
    c_aff.set_defaults(func=_cmd_compose_affinity_cluster)

    c_park = compose_sub.add_parser(
        "parking-lot-sweep", help="List parked widgets in a mural"
    )
    c_park.add_argument("--mural", required=True, help="Mural id")
    c_park.add_argument("--area", default=None, help="Optional area id")
    c_park.add_argument("--tag", default=None, help="Optional tag id override")
    _add_output_flags(c_park)
    c_park.set_defaults(func=_cmd_compose_parking_lot_sweep)

    c_sum = compose_sub.add_parser("workspace-summary", help="Summarize a workspace")
    c_sum.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(c_sum)
    c_sum.set_defaults(func=_cmd_compose_workspace_summary)

    lineage = sub.add_parser("lineage", help="Lineage operations")
    lineage_sub = lineage.add_subparsers(dest="lineage_command", required=True)

    l_lookup = lineage_sub.add_parser(
        "lookup", help="Look up widgets by Design Thinking lineage marker"
    )
    l_lookup.add_argument("--mural-id", required=True, help="Mural id")
    l_lookup.add_argument("--run-id", default=None, help="Filter by run id")
    l_lookup.add_argument(
        "--method", type=int, default=None, help="Filter by DT method (1..9)"
    )
    l_lookup.add_argument("--section", default=None, help="Filter by section name")
    _add_output_flags(l_lookup)
    l_lookup.set_defaults(func=_cmd_mural_lineage_lookup)

    spatial = sub.add_parser("spatial", help="Spatial query operations")
    spatial_sub = spatial.add_subparsers(dest="spatial_command", required=True)

    s_in_shape = spatial_sub.add_parser(
        "widgets-in-shape",
        help="Filter widgets contained by a shape (frame, area, or widget)",
    )
    s_in_shape.add_argument("--mural-id", required=True, help="Mural id")
    s_in_shape.add_argument(
        "--shape-id", required=True, help="Container shape widget id"
    )
    s_in_shape.add_argument(
        "--mode",
        default="center",
        choices=["center", "bbox"],
        help="Inclusion test (default: center).",
    )
    s_in_shape.add_argument(
        "--rotation-aware",
        dest="rotation_aware",
        action="store_true",
        help=(
            "Force rotation-aware AABB expansion of the shape; overrides "
            "MURAL_SPATIAL_ROTATION_ENABLED when set."
        ),
    )
    _add_output_flags(s_in_shape)
    _add_pagination_flags(s_in_shape)
    s_in_shape.set_defaults(func=_cmd_spatial_widgets_in_shape)

    s_in_region = spatial_sub.add_parser(
        "widgets-in-region",
        help="Filter widgets inside an axis-aligned rectangle",
    )
    s_in_region.add_argument("--mural-id", required=True, help="Mural id")
    s_in_region.add_argument("--x", type=float, required=True, help="Region origin X")
    s_in_region.add_argument("--y", type=float, required=True, help="Region origin Y")
    s_in_region.add_argument(
        "--w",
        type=float,
        required=True,
        help="Region width (sign-corrected via safe_rect).",
    )
    s_in_region.add_argument(
        "--h",
        type=float,
        required=True,
        help="Region height (sign-corrected via safe_rect).",
    )
    s_in_region.add_argument(
        "--mode",
        default="center",
        choices=["center", "bbox"],
        help="Inclusion test (default: center).",
    )
    _add_output_flags(s_in_region)
    _add_pagination_flags(s_in_region)
    s_in_region.set_defaults(func=_cmd_spatial_widgets_in_region)

    s_pairwise = spatial_sub.add_parser(
        "pairwise-overlaps",
        help="Find overlapping widget pairs across the mural",
    )
    s_pairwise.add_argument("--mural-id", required=True, help="Mural id")
    s_pairwise.add_argument(
        "--predicate",
        default="intersects",
        choices=["intersects", "contains"],
        help="AABB relationship test (default: intersects).",
    )
    s_pairwise.add_argument(
        "--rotation-aware",
        dest="rotation_aware",
        action="store_true",
        help=(
            "Force rotation-aware AABB expansion of widgets; overrides "
            "MURAL_SPATIAL_ROTATION_ENABLED when set."
        ),
    )
    _add_output_flags(s_pairwise)
    _add_pagination_flags(s_pairwise)
    s_pairwise.set_defaults(func=_cmd_spatial_pairwise_overlaps)

    s_cluster = spatial_sub.add_parser(
        "cluster",
        help="Cluster widgets by spatial proximity using DBSCAN",
    )
    s_cluster.add_argument("--mural-id", required=True, help="Mural id")
    s_cluster.add_argument(
        "--eps-px",
        dest="eps_px",
        type=float,
        default=120.0,
        help="DBSCAN neighborhood radius in pixels (default: 120.0).",
    )
    s_cluster.add_argument(
        "--min-samples",
        dest="min_samples",
        type=int,
        default=2,
        help=(
            "DBSCAN density threshold; min_samples=1 keeps isolated "
            "widgets as singleton clusters (default: 2)."
        ),
    )
    _add_output_flags(s_cluster)
    _add_pagination_flags(s_cluster)
    s_cluster.set_defaults(func=_cmd_spatial_cluster)

    s_sort_axis = spatial_sub.add_parser(
        "sort-along-axis",
        help="Sort widgets by AABB-center projection along an axis",
    )
    s_sort_axis.add_argument("--mural-id", required=True, help="Mural id")
    s_sort_axis.add_argument(
        "--axis",
        default="x",
        choices=["x", "y", "diagonal"],
        help="Axis to project centers onto (default: x).",
    )
    s_sort_axis.add_argument(
        "--origin-x",
        dest="origin_x",
        type=float,
        default=None,
        help=(
            "Optional anchor X used with --origin-y to sort by signed "
            "projection from an origin along the axis."
        ),
    )
    s_sort_axis.add_argument(
        "--origin-y",
        dest="origin_y",
        type=float,
        default=None,
        help=(
            "Optional anchor Y used with --origin-x to sort by signed "
            "projection from an origin along the axis."
        ),
    )
    _add_output_flags(s_sort_axis)
    _add_pagination_flags(s_sort_axis)
    s_sort_axis.set_defaults(func=_cmd_spatial_sort_along_axis)

    s_arrow_graph = spatial_sub.add_parser(
        "arrow-graph",
        help="Build a directed multigraph from arrow widgets",
    )
    s_arrow_graph.add_argument("--mural-id", required=True, help="Mural id")
    s_arrow_graph.add_argument(
        "--snap-radius",
        type=float,
        default=24.0,
        help=(
            "Maximum Euclidean distance (pixels) from an arrow endpoint "
            "to a widget AABB center for snapping (default 24)"
        ),
    )
    s_arrow_graph.add_argument(
        "--format",
        choices=["summary", "full", "dot"],
        default="summary",
        help=(
            "Output format: summary JSON (default), full JSON with the "
            "arrow widget attached to each edge, or Graphviz dot text"
        ),
    )
    s_arrow_graph.add_argument(
        "--output",
        default=None,
        help="Optional path to write rendered output instead of stdout",
    )
    _add_pagination_flags(s_arrow_graph)
    s_arrow_graph.set_defaults(func=_cmd_spatial_arrow_graph)

    voting = sub.add_parser("voting", help="Voting session operations")
    voting_sub = voting.add_subparsers(dest="voting_command", required=True)

    v_create = voting_sub.add_parser(
        "session-create", help="Create a voting session from a JSON file"
    )
    v_create.add_argument("--mural", required=True, help="Mural id")
    v_create.add_argument(
        "--file", required=True, help="Path to JSON body for the session"
    )
    _add_output_flags(v_create)
    v_create.set_defaults(func=_cmd_voting_session_create)

    v_get = voting_sub.add_parser("session-get", help="Get a voting session")
    v_get.add_argument("--mural", required=True, help="Mural id")
    v_get.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_get)
    v_get.set_defaults(func=_cmd_voting_session_get)

    v_list = voting_sub.add_parser(
        "session-list", help="List voting sessions on a mural"
    )
    v_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(v_list)
    _add_pagination_flags(v_list)
    v_list.set_defaults(func=_cmd_voting_session_list)

    v_open = voting_sub.add_parser(
        "session-open", help="Open a voting session (status=active)"
    )
    v_open.add_argument("--mural", required=True, help="Mural id")
    v_open.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_open)
    v_open.set_defaults(func=_cmd_voting_session_open)

    v_close = voting_sub.add_parser(
        "session-close", help="Close a voting session (status=closed)"
    )
    v_close.add_argument("--mural", required=True, help="Mural id")
    v_close.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_close)
    v_close.set_defaults(func=_cmd_voting_session_close)

    v_delete = voting_sub.add_parser("session-delete", help="Delete a voting session")
    v_delete.add_argument("--mural", required=True, help="Mural id")
    v_delete.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_delete)
    v_delete.set_defaults(func=_cmd_voting_session_delete)

    v_results = voting_sub.add_parser("results", help="Fetch voting session results")
    v_results.add_argument("--mural", required=True, help="Mural id")
    v_results.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_results)
    v_results.set_defaults(func=_cmd_voting_results)

    v_poll = voting_sub.add_parser(
        "poll", help="Poll a voting session until a condition matches"
    )
    v_poll.add_argument("--mural", required=True, help="Mural id")
    v_poll.add_argument("--session", required=True, help="Voting session id")
    v_poll.add_argument(
        "--condition",
        required=True,
        help="Dotted-path condition (e.g. `status==closed`)",
    )
    v_poll.add_argument(
        "--interval",
        type=float,
        default=POLL_DEFAULT_INTERVAL_S,
        help=f"Poll interval seconds (default {POLL_DEFAULT_INTERVAL_S})",
    )
    v_poll.add_argument(
        "--timeout",
        type=float,
        default=POLL_DEFAULT_TIMEOUT_S,
        help=f"Poll timeout seconds (default {POLL_DEFAULT_TIMEOUT_S})",
    )
    _add_output_flags(v_poll)
    v_poll.set_defaults(func=_cmd_voting_poll)


def main(argv: list[str] | None = None) -> int:
    _install_signal_handlers()
    parser = _build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, args.log_level, logging.WARNING),
        format="%(levelname)s %(name)s: %(message)s",
    )
    global _CLI_QUIET, _CLI_FORCE_JSON, _CLI_COLOR, _CLI_PROFILE
    _CLI_QUIET = bool(getattr(args, "quiet", False))
    _CLI_FORCE_JSON = bool(getattr(args, "json_output", False))
    _CLI_COLOR = _color_mode(getattr(args, "color", "auto"))
    _CLI_PROFILE = getattr(args, "profile", None) or None
    profile_name = (
        getattr(args, "profile", None)
        or os.environ.get(ENV_PROFILE)
        or DEFAULT_PROFILE_NAME
    )
    try:
        _autoload_credentials(profile_name)
    except MuralError as exc:
        print(str(exc), file=sys.stderr)
        return EXIT_FAILURE
    func: Callable[[argparse.Namespace], int] = getattr(args, "func", None)
    if func is None:
        parser.print_help(sys.stderr)
        return EXIT_USAGE
    try:
        return func(args)
    except SystemExit:
        raise
    except KeyboardInterrupt:
        return 130
    except BrokenPipeError:
        return 141
    except MuralAuthScopeError as exc:
        print(f"auth: {exc}", file=sys.stderr)
        return 77
    except MuralHumanAuthoredProtected as exc:
        envelope = {
            "error": "human_authored_widget_protected",
            "mural": exc.mural_id,
            "widget": exc.widget_id,
        }
        print(json.dumps(envelope), file=sys.stderr)
        return EXIT_NOPERM
    except MuralTagMergeConflict as exc:
        envelope = {
            "error": "tag_merge_conflict",
            "mural": exc.mural_id,
            "widget": exc.widget_id,
            "intended": exc.intended,
            "observed": exc.observed,
            "missing": exc.missing,
            "extra": exc.extra,
            "attempts": exc.attempts,
        }
        print(json.dumps(envelope), file=sys.stderr)
        return EXIT_TEMPFAIL
    except MuralAreaCapacityExceeded as exc:
        envelope = {
            "error": "AREA_CAPACITY_EXCEEDED",
            "exit_code": EXIT_AREA_CAPACITY,
            "area_id": exc.area_id,
            "area_capacity": exc.area_capacity,
            "computed_extent": exc.computed_extent,
            "suggestion": exc.suggestion,
        }
        print(json.dumps(envelope), file=sys.stderr)
        return EXIT_AREA_CAPACITY
    except MuralBulkAtomicAbort as exc:
        envelope = {"error": "bulk_atomic_abort", "aborted": True, **exc.summary}
        print(json.dumps(envelope), file=sys.stderr)
        return EXIT_TEMPFAIL
    except MuralError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"internal error: {_redact(repr(exc))}", file=sys.stderr)
        _emit_debug_traceback(exc)
        return 70


if __name__ == "__main__":
    sys.exit(main())
