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
import contextlib
import getpass  # noqa: F401 - re-exposed as patchable facade attribute
import hashlib
import json
import logging
import os
import pathlib
import re
import secrets
import signal
import sys
import time
import traceback
import uuid
import webbrowser  # noqa: F401 - re-exposed as patchable facade attribute
from collections.abc import Mapping, MutableMapping
from typing import Any, Callable, Sequence

from . import _state  # noqa: E402,F401

# Re-export carved-out symbols so residual code and tests keep working.
from ._constants import (  # noqa: E402,F401
    _AUTHORED_BY_AI_TAG_TEXT,
    _KNOWN_CREDENTIAL_KEYS,
    _LINE_RE,
    _PROFILE_NAME_RE,
    _PROFILE_REQUIRED_KEYS,
    _REDACT_KEYS,
    _REDACT_PATTERNS,
    _REFRESH_LOCK,
    _RESERVED_TAG_PREFIXES,
    _RESERVED_TAGS,
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
_ROTATION_ENABLED = os.environ.get("MURAL_SPATIAL_ROTATION_ENABLED", "0") == "1"
_PARENTID_FILTER_ENABLED = os.environ.get("MURAL_SPATIAL_PARENTID_FILTER", "0") == "1"

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
        if key not in _state._seen_relaxed_warn:
            _state._seen_relaxed_warn.add(key)
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
        backend = KeyringBackend()
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
    if dedup_key in _state._seen_concurrent_warn:
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
        _state._seen_concurrent_warn.add(dedup_key)
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


def _emit(message: str, *, level: int = logging.INFO) -> None:
    """Write a redacted message to stderr and the module logger."""
    redacted = _redact(message)
    LOGGER.log(level, redacted)
    if level >= logging.ERROR or not _state._CLI_QUIET:
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


# ---------------------------------------------------------------------------
# Step 2.1 — Credential storage backends
# ---------------------------------------------------------------------------
# Carved into ``_backends`` for module size and testability.  Re-imported here
# so the package surface (and ``mural.<symbol>`` test access) is unchanged.
# Deferred to this point so ``_backends`` can bind the package siblings it
# depends on (``_emit``, ``_maybe_warn_concurrent_state``, etc.) which are
# defined above this line.

from ._backends import (  # noqa: E402,F401
    CredentialBackend,
    FileBackend,
    KeyringBackend,
    resolve_backend,
)

# The transport and OAuth re-export blocks below MUST stay in dependency order:
# ``_oauth`` reaches back into the package for ``_TOKEN_OPENER`` and
# ``_parse_token_response`` at module-load time, so ``_transport`` must be
# re-exported first.  ``# isort: off``/``# isort: on`` pins this order against
# the isort (``I``) rule, which would otherwise sort ``_oauth`` before
# ``_transport`` alphabetically and reintroduce a circular-import failure.
# isort: off
# ---------------------------------------------------------------------------
# Step 2.2 — Transport tier (redact, rate limiting, refresh, HTTP, asset upload)
# ---------------------------------------------------------------------------
# Carved into ``_transport`` for module size and testability.  Re-imported here
# so the package surface (and ``mural.<symbol>`` test access) is unchanged.
# Deferred to this point so ``_transport`` can bind the package siblings it
# depends on (``_emit``, ``_coalesced_refresh``, ``_load_token_store``, etc.)
# defined above, and so ``_oauth`` (imported below) sees ``_TOKEN_OPENER`` and
# ``_parse_token_response`` already bound on the package.
from ._transport import (  # noqa: E402,F401
    _RATE_BUCKET,
    _TOKEN_OPENER,
    _authenticated_request,
    _backoff_seconds,
    _build_api_error,
    _create_asset_url,
    _decode_body,
    _extract_error_payload,
    _join_url,
    _NoRedirect,
    _parse_rate_limit_headers,
    _parse_token_response,
    _read_capped,
    _read_response_body,
    _redact,
    _refresh_access_token,
    _token_bucket_acquire,
    _TokenBucket,
    _upload_to_sas,
)

# ---------------------------------------------------------------------------
# Step 2.3 — Loopback OAuth login flow
# ---------------------------------------------------------------------------
# Carved into ``_oauth`` for testability and module size.  Re-imported here
# so the package surface (and ``mural.<symbol>`` test access) is unchanged.
# PKCE primitives (``_generate_pkce_pair``/``_verify_pkce``) remain above so
# that ``_oauth`` can import them at module-load time without a cycle on the
# transport helpers it also depends on (``_TOKEN_OPENER`` etc.).  ``_transport``
# is re-exported above so ``_oauth``'s load-time reach-back resolves them.
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
# isort: on

# ---------------------------------------------------------------------------
# Step 4 — Output, emit, and widget-text helpers
# ---------------------------------------------------------------------------
# Carved into ``_output`` for testability and module size.  Re-imported here
# so the package surface (and ``mural.<symbol>`` test access) is unchanged.
# ``_output._emit_record`` reaches back through the package facade for
# ``_unwrap_value_envelope`` so monkeypatch interception still works.
# ``_output`` imports ``_validation`` at module load, so Python loads the
# validation tier transitively regardless of the order of these re-exports.
from ._output import (  # noqa: E402,F401
    _apply_widget_text_coalesce,
    _coalesce_widget_text,
    _emit_record,
    _emit_records,
    _read_fields,
    _strip_html,
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

# Explicit re-export surface so static analysis recognizes these names as part
# of the package API (consumed by sibling modules and ``mural.<symbol>`` tests).
__all__ = [
    # re-exported from ._constants
    "_AUTHORED_BY_AI_TAG_TEXT",
    "_KNOWN_CREDENTIAL_KEYS",
    "_LINE_RE",
    "_PROFILE_NAME_RE",
    "_PROFILE_REQUIRED_KEYS",
    "_REDACT_KEYS",
    "_REDACT_PATTERNS",
    "_REFRESH_LOCK",
    "_RESERVED_TAG_PREFIXES",
    "_RESERVED_TAGS",
    "_TAG_MERGE_BACKOFF_MAX_MS",
    "_TAG_MERGE_BACKOFF_MIN_MS",
    "_TAG_MERGE_MAX_RETRIES",
    "DEFAULT_LOGIN_SCOPES",
    "DEFAULT_PROFILE_NAME",
    "DEFAULT_REDIRECT_URI",
    "DEFAULT_SCOPES",
    "ENV_BASE_URL",
    "ENV_CLIENT_ID",
    "ENV_CLIENT_SECRET",
    "ENV_DEFAULT_WORKSPACE",
    "ENV_ENV_FILE",
    "ENV_ENV_FILE_RELAXED",
    "ENV_NONINTERACTIVE",
    "ENV_PROFILE",
    "ENV_REDIRECT_URI",
    "ENV_SCOPES",
    "ENV_TOKEN_STORE",
    "ENV_XDG_CONFIG_HOME",
    "ENV_XDG_DATA_HOME",
    "EXIT_AREA_CAPACITY",
    "EXIT_FAILURE",
    "EXIT_NOPERM",
    "EXIT_SUCCESS",
    "EXIT_TEMPFAIL",
    "EXIT_USAGE",
    "MAX_BACKOFF_SECONDS",
    "MAX_BULK_WIDGETS",
    "MAX_RETRIES",
    "MURAL_AUTHORIZE_URL",
    "MURAL_BASE_URL_DEFAULT",
    "MURAL_MAX_BODY_BYTES",
    "MURAL_TOKEN_URL",
    "POLL_DEFAULT_INTERVAL_S",
    "POLL_DEFAULT_TIMEOUT_S",
    "POLL_MAX_INTERVAL_S",
    "POLL_MAX_TIMEOUT_S",
    "RATE_LIMIT_BUCKET_CAPACITY",
    "RATE_LIMIT_TOKENS_PER_SEC",
    "READ_SCOPES",
    "REFRESH_LEEWAY_SECONDS",
    "TOKEN_STORE_SCHEMA_VERSION",
    "USER_AGENT",
    "WRITE_SCOPES",
    # env-driven flags defined locally for the importlib.reload contract
    "_ROTATION_ENABLED",
    "_PARENTID_FILTER_ENABLED",
    # process-local mutable state defined locally
    "_GEOS_PROBE_DONE",
    # re-exported from ._validation
    "_ALLOWED_HYPERLINK_SCHEMES",
    "_AZURE_BLOB_HOST_SUFFIX",
    "_DEFAULT_PAGE_SIZE",
    "_IMAGE_CONTENT_TYPES",
    "_MAX_CURSOR_BYTES",
    "_MAX_HYPERLINK_LEN",
    "_MAX_PAGE_SIZE",
    "_MAX_TAG_TEXT_LEN",
    "_MURAL_ID_RE",
    "_VALID_AREA_LAYOUTS",
    "_area_cache",
    "_build_area_body",
    "_build_arrow_body",
    "_build_image_body",
    "_build_shape_body",
    "_build_sticky_note_body",
    "_build_textbox_body",
    "_coerce_xy",
    "_extract_field",
    "_format_output",
    "_paginate",
    "_parse_json_arg",
    "_parse_pagination_cursor",
    "_project_record",
    "_resolve_workspace_id",
    "_unwrap_value_envelope",
    "_validate_area_layout",
    "_validate_asset_url",
    "_validate_hyperlink",
    "_validate_mural_id",
    "_validate_tag_text",
    # re-exported from ._output
    "_apply_widget_text_coalesce",
    "_coalesce_widget_text",
    "_emit_record",
    "_emit_records",
    "_read_fields",
    "_strip_html",
]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


# Mural exposes no RFC 7009 /revoke endpoint, so logout is local-only.


def _bootstrap_is_interactive() -> bool:
    """Return True when `mural auth bootstrap` may prompt the operator."""
    return (
        sys.stdin.isatty()
        and sys.stdout.isatty()
        and os.environ.get(ENV_NONINTERACTIVE) != "1"
        and os.environ.get("CI", "").lower() != "true"
    )


from ._cli_auth import (  # noqa: E402,F401 - re-export carved auth CLI surface
    _LOGOUT_TRANSPARENCY_LINES,
    _OAUTH_SETUP_WALKTHROUGH,
    _cmd_auth_bootstrap,
    _cmd_auth_list,
    _cmd_auth_login,
    _cmd_auth_logout,
    _cmd_auth_migrate,
    _cmd_auth_setup,
    _cmd_auth_status,
    _cmd_auth_use,
    _emit_logout_credential_summary,
    _emit_logout_transparency,
    _load_token_store_locked,
    _logout_remove_credentials,
    _migrate_source_is_keyring,
    _save_token_store_locked,
)


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


def _confirmation_register(
    *, tool: str, arguments: dict[str, Any], candidates: list[dict[str, Any]]
) -> str:
    """Register a preview and return its ``preview_id``."""
    preview_id = uuid.uuid4().hex
    _state._PENDING_CONFIRMATIONS[preview_id] = {
        "tool": tool,
        "arguments": dict(arguments),
        "candidates": list(candidates),
        "expires_at": time.time() + _state._CONFIRMATION_TTL_S,
    }
    # Light cleanup of expired entries to bound the dict.
    now = time.time()
    expired = [
        k for k, v in _state._PENDING_CONFIRMATIONS.items() if v["expires_at"] < now
    ]
    for k in expired:
        _state._PENDING_CONFIRMATIONS.pop(k, None)
    return preview_id


def _confirmation_consume(*, tool: str, confirmed_id: str) -> dict[str, Any]:
    """Return the registered preview for ``confirmed_id`` or raise."""
    entry = _state._PENDING_CONFIRMATIONS.pop(confirmed_id, None)
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
    except MuralError as exc:
        LOGGER.debug("failed to list existing areas for %s: %s", mural_id, exc)
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


from ._commands import (  # noqa: E402,F401 - re-export carved resource/bulk command surface
    _BULK_UPDATE_MAX_WORKERS,
    _CONTAINMENT_SUCCESS_VERDICTS,
    _DIFF_ANCHOR_KEYS,
    _DIFF_CONTENT_KEYS,
    _DIFF_GEOM_KEYS,
    _DIFF_IGNORED_KEYS,
    _DIFF_STYLE_KEYS,
    _POLL_OPS,
    _WIDGET_TYPE_API_TO_PATH_KEY,
    _WIDGET_TYPE_TO_PATH,
    CONTAINMENT_VERDICT_AREA_CHAIN_MATCH,
    CONTAINMENT_VERDICT_GEOMETRY_MATCH,
    CONTAINMENT_VERDICT_GEOMETRY_MISMATCH,
    CONTAINMENT_VERDICT_PARENT_MATCH,
    CONTAINMENT_VERDICT_PARENT_MISMATCH,
    CONTAINMENT_VERDICT_READBACK_FAILED,
    _apply_widget_diff,
    _attach_containment_to_record,
    _build_bulk_widget_updates_payload,
    _build_bulk_widgets_payload,
    _bulk_apply_author_tag,
    _bulk_create_widgets,
    _bulk_delete_widgets,
    _bulk_update_widgets,
    _cmd_area_create,
    _cmd_area_get,
    _cmd_area_list,
    _cmd_area_probe,
    _cmd_clone_with_tags,
    _cmd_layout_cluster,
    _cmd_layout_column,
    _cmd_layout_grid,
    _cmd_layout_row,
    _cmd_mural_archive,
    _cmd_mural_create,
    _cmd_mural_duplicate,
    _cmd_mural_get,
    _cmd_mural_list,
    _cmd_mural_poll,
    _cmd_mural_unarchive,
    _cmd_room_create,
    _cmd_room_get,
    _cmd_room_list,
    _cmd_spatial_arrow_graph,
    _cmd_spatial_cluster,
    _cmd_spatial_not_implemented,
    _cmd_spatial_pairwise_overlaps,
    _cmd_spatial_sort_along_axis,
    _cmd_spatial_widgets_in_region,
    _cmd_spatial_widgets_in_shape,
    _cmd_tag_apply,
    _cmd_tag_create,
    _cmd_tag_list,
    _cmd_tag_remove,
    _cmd_template_create,
    _cmd_template_instantiate,
    _cmd_template_list,
    _cmd_widget_create_arrow,
    _cmd_widget_create_bulk,
    _cmd_widget_create_image,
    _cmd_widget_create_shape,
    _cmd_widget_create_sticky_note,
    _cmd_widget_create_textbox,
    _cmd_widget_delete,
    _cmd_widget_diff,
    _cmd_widget_get,
    _cmd_widget_list,
    _cmd_widget_update,
    _cmd_widget_update_bulk,
    _cmd_workspace_get,
    _cmd_workspace_list,
    _coerce_finite_number,
    _create_widget,
    _diff_widget_fields,
    _diff_widget_lists,
    _duplicate_mural,
    _evaluate_containment_geometry,
    _evaluate_poll,
    _extract_bulk_create_succeeded,
    _is_containment_success,
    _layout_cli_arguments,
    _parse_origin_arg,
    _parse_parent_id,
    _parse_poll_condition,
    _patch_widget_or_disambiguate_404,
    _poll_mural,
    _read_tag_manifest,
    _resolve_dotted,
    _resolve_widget_update_body,
    _set_mural_status,
    _template_target_body,
    _typed_widget_path,
    _verify_parent_containment,
)


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
    _voting_session_set_status(mural_id, session_id, "active")
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


def _tool_template_list(arguments: dict[str, Any]) -> Any:
    workspace = arguments.get("workspace")
    if workspace is not None and (
        not isinstance(workspace, str) or not workspace.strip()
    ):
        raise MCPInvalidParamsError("workspace must be a non-empty string when set")
    return {"templates": [dict(entry) for entry in _state._TEMPLATE_REGISTRY]}


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


def _idempotency_get(name: str, key: str) -> dict[str, Any] | None:
    payload = _state._IDEMPOTENCY_CACHE.get((name, key))
    if payload is None:
        return None
    _state._IDEMPOTENCY_CACHE.move_to_end((name, key))
    return payload


def _idempotency_put(name: str, key: str, payload: dict[str, Any]) -> None:
    _state._IDEMPOTENCY_CACHE[(name, key)] = payload
    _state._IDEMPOTENCY_CACHE.move_to_end((name, key))
    while len(_state._IDEMPOTENCY_CACHE) > _state._IDEMPOTENCY_MAX:
        _state._IDEMPOTENCY_CACHE.popitem(last=False)


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
    _state._CLI_QUIET = bool(getattr(args, "quiet", False))
    _state._CLI_FORCE_JSON = bool(getattr(args, "json_output", False))
    _state._CLI_COLOR = _color_mode(getattr(args, "color", "auto"))
    _state._CLI_PROFILE = getattr(args, "profile", None) or None
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
