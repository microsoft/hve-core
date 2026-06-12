#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Auth CLI tier for the Mural CLI.

Carved from ``mural/__init__`` (Step 3.1 of the __init__ modularization plan).
Holds the ``mural auth`` subcommand handlers, the logout transparency and
credential-removal helpers, and the lock-held token-store primitives
``_load_token_store_locked`` and ``_save_token_store_locked``.

Helpers that remain in the package ``__init__`` (``_emit``,
``_load_token_store``, ``_token_store_session``, ``_migrate_v1_to_v2``,
the profile validators, ...) are imported from the package and bind when
``__init__`` first imports this submodule, after those helpers are defined.

Intra-package calls to facade-patched symbols (``resolve_backend``,
``_run_login``, ``_save_token_store_locked``, ``_bootstrap_is_interactive``)
route through :func:`_pkg` so ``monkeypatch.setattr(mural, <symbol>, ...)``
keeps intercepting without test edits.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime
import getpass
import json
import logging
import os
import pathlib
import re
import sys
import threading
import time
import webbrowser
from typing import Any

from . import (  # noqa: E402 - package siblings defined before this import runs
    _acquire_cache_lock,
    _emit,
    _KeyringUnavailable,
    _migrate_v1_to_v2,
    _NullBackend,
    _resolve_active_profile,
    _select_profile,
    _state,
    _token_granted_scopes,
    _token_store_session,
    _validate_profile,
    _validate_profile_name,
)
from ._backends import (
    FileBackend,
    KeyringBackend,
)
from ._constants import (
    _KNOWN_CREDENTIAL_KEYS,
    DEFAULT_PROFILE_NAME,
    DEFAULT_REDIRECT_URI,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    ENV_PROFILE,
    ENV_SCOPES,
    EXIT_FAILURE,
    EXIT_SUCCESS,
    EXIT_USAGE,
    READ_SCOPES,
    TOKEN_STORE_SCHEMA_VERSION,
    WRITE_SCOPES,
)
from ._credentials import (
    _resolve_credential_file,
    _resolve_token_store_path,
    _service_name_for,
    _validate_client_secret,
)
from ._exceptions import (
    MuralError,
    MuralValidationError,
)


def _pkg() -> Any:
    """Return the live ``mural`` package module for facade-routed patching."""
    return sys.modules[__package__]


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
        _pkg()._save_token_store_locked(path, migrated)
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
                    (
                        "  2. Active credential backend "
                        + "(MURAL_CREDENTIAL_BACKEND={auto|keyring|file|env-only})"
                    ),
                    f"  3. Credential file: {cred_path}  (exists: {cred_exists})",
                    "",
                    (
                        "Run `mural auth bootstrap` to store Mural app"
                        + " credentials interactively,"
                    ),
                    (
                        f"or set {ENV_CLIENT_ID} and {ENV_CLIENT_SECRET} in your"
                        + " environment."
                    ),
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
        backend = _pkg().resolve_backend(profile_name)
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
        store = _pkg()._load_token_store(_resolve_token_store_path())
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
        record = _pkg()._run_login(scopes=scopes, timeout_seconds=args.timeout)
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
            _pkg()._save_token_store_locked(path, envelope)
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


_LOGOUT_TRANSPARENCY_LINES: tuple[str, ...] = (
    "Credentials have been cleared from this machine.",
    (
        "Your Mural OAuth tokens may remain active server-side until they "
        + "expire (access tokens have a documented 15-minute TTL; "
        + "refresh tokens persist longer and are not rotated on use)."
    ),
    (
        "To fully revoke access, visit https://app.mural.co/me/apps and "
        + "remove this integration."
    ),
)


def _cmd_auth_setup(args: argparse.Namespace) -> int:
    """Provision a new profile non-interactively from env or CLI args."""
    json_mode = bool(getattr(args, "json", False)) or _state._CLI_FORCE_JSON
    if not json_mode:
        redacted = _pkg()._redact(_OAUTH_SETUP_WALKTHROUGH)
        print(redacted)
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
            _pkg()._save_token_store_locked(path, envelope)
    # Mirror the client_id into the active credential backend so
    # subsequent `mural auth login` invocations can resolve it without
    # the operator re-exporting MURAL_CLIENT_ID. Failure to write is
    # surfaced as a single deduped WARN; the token-store record above
    # is already committed so setup remains useful in env-only mode.
    try:
        backend = _pkg().resolve_backend(profile_name)
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
            if warn_key not in _state.seen_fallback_warn():
                _state.seen_fallback_warn().add(warn_key)
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
                if warn_key not in _state.seen_fallback_warn():
                    _state.seen_fallback_warn().add(warn_key)
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
    if not _pkg()._bootstrap_is_interactive():
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
        backend = _pkg().resolve_backend(profile_name)
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
        ok, message = _pkg()._probe_client_credentials(client_id, client_secret)
        redacted = _pkg()._redact(message)
        if ok:
            _emit(
                f"credential probe succeeded: {redacted}",
                level=logging.INFO,
            )
        else:
            _emit(
                f"{redacted}; your credentials were saved but Mural "
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
    store = _pkg()._load_token_store(path)
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
    if _state._CLI_FORCE_JSON or getattr(_args, "format", "json") != "table":
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
    json_mode = bool(getattr(args, "json", False)) or _state._CLI_FORCE_JSON
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
        backend = _pkg().resolve_backend(profile)
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
    json_mode = bool(getattr(args, "json", False)) or _state._CLI_FORCE_JSON
    keep_credentials = bool(getattr(args, "keep_credentials", False))
    force = bool(getattr(args, "force", False))
    path = _resolve_token_store_path()
    if getattr(args, "all", False):
        # Snapshot profile names BEFORE clearing the token store so we
        # can iterate them for backend deletion.
        store_snapshot = _pkg()._load_token_store(path) or {}
        profile_names = sorted((store_snapshot.get("profiles") or {}).keys())
        empty = {"schema_version": TOKEN_STORE_SCHEMA_VERSION, "profiles": {}}
        try:
            with _acquire_cache_lock(path):
                _pkg()._save_token_store_locked(path, empty)
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
        backend = _pkg().resolve_backend(cred_profile)
        backend_name: str = backend.name
        backend_error: str | None = None
    except MuralError as exc:
        backend_name = "unavailable"
        backend_error = str(exc)
    keyring_available, keyring_backend_name, keyring_error = (
        _pkg()._probe_keyring_availability()
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
    store = _pkg()._load_token_store(path)
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
    json_mode = bool(getattr(args, "json", False)) or _state._CLI_FORCE_JSON
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
    if dedup_key not in _state.seen_concurrent_warn():
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
            _state.seen_concurrent_warn().add(dedup_key)
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

    migrated_slots: list[str] = []
    skipped_empty_slots: list[str] = []
    failures: dict[str, str] = {}
    for slot in _KNOWN_CREDENTIAL_KEYS:
        try:
            value = source.get(service, slot)
        except _KeyringUnavailable as exc:
            failures[slot] = f"source read failed: {exc}"
            continue
        if not value:
            skipped_empty_slots.append(slot)
            continue
        try:
            target.set(service, slot, value)
        except (_KeyringUnavailable, OSError, RuntimeError) as exc:
            failures[slot] = f"target write failed: {exc}"
            continue
        try:
            roundtrip = target.get(service, slot)
        except _KeyringUnavailable as exc:
            failures[slot] = f"round-trip read failed: {exc}"
            continue
        if roundtrip != value:
            failures[slot] = "round-trip mismatch (target value differs from source)"
            continue
        migrated_slots.append(slot)

    summary: dict[str, Any] = {
        "profile": profile,
        "direction": f"{source_name}->{target_name}",
        "source": source_name,
        "target": target_name,
        "migrated": migrated_slots,
        "skipped_empty": skipped_empty_slots,
        "failures": failures,
        "cleanup": False,
    }

    if failures:
        summary["status"] = "partial" if migrated_slots else "failed"
        if json_mode:
            redacted = _pkg()._redact(json.dumps(summary, indent=2))
            print(redacted)
        else:
            _emit(
                f"migration {source_name}->{target_name} for profile "
                f"{profile!r} encountered failures: {failures}",
                level=logging.ERROR,
            )
            if migrated_slots:
                _emit(
                    f"successfully migrated slots: {', '.join(migrated_slots)}",
                    level=logging.INFO,
                )
        return EXIT_FAILURE if not migrated_slots else EXIT_SUCCESS

    if not migrated_slots:
        summary["status"] = "no-op"
        if json_mode:
            redacted = _pkg()._redact(json.dumps(summary, indent=2))
            print(redacted)
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
                redacted = _pkg()._redact(json.dumps(summary, indent=2))
                print(redacted)
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
                    redacted = _pkg()._redact(json.dumps(summary, indent=2))
                    print(redacted)
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
                    redacted = _pkg()._redact(json.dumps(summary, indent=2))
                    print(redacted)
                else:
                    _emit(
                        "cleanup declined; source backend left intact",
                        level=logging.INFO,
                    )
                return EXIT_SUCCESS
        cleanup_removed_slots: list[str] = []
        cleanup_errors: dict[str, str] = {}
        for slot in migrated_slots:
            try:
                source.delete(service, slot)
            except (_KeyringUnavailable, OSError, RuntimeError) as exc:
                cleanup_errors[slot] = str(exc)
                continue
            cleanup_removed_slots.append(slot)
        summary["cleanup"] = True
        summary["cleanup_removed"] = cleanup_removed_slots
        if cleanup_errors:
            summary["cleanup_errors"] = cleanup_errors
            summary["status"] = "migrated_cleanup_partial"

    if json_mode:
        redacted = _pkg()._redact(json.dumps(summary, indent=2))
        print(redacted)
    else:
        _emit(
            f"migrated {len(migrated_slots)} slot(s) "
            f"({', '.join(migrated_slots)}) from {source_name} to {target_name} "
            f"for profile {profile!r}",
            level=logging.INFO,
        )
        if summary.get("cleanup"):
            _emit(
                f"cleanup removed {len(summary.get('cleanup_removed') or [])} "
                f"slot(s) from {source_name} backend",
                level=logging.INFO,
            )
    return EXIT_SUCCESS


def _migrate_source_is_keyring(direction: str) -> bool:
    """Return True when migration ``direction`` reads from keyring."""
    return direction == "file"
