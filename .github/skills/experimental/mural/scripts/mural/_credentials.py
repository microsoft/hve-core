#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Credential resolution helpers (leaves only at this stage).

Backend classes (``KeyringBackend``, ``FileBackend``, ``_NullBackend``,
``resolve_backend``) move here in Step 4.1.
"""

from __future__ import annotations

import os
import pathlib
from typing import Mapping

from ._constants import (
    _PROFILE_NAME_RE,
    DEFAULT_PROFILE_NAME,
    ENV_ENV_FILE,
    ENV_TOKEN_STORE,
    ENV_XDG_CONFIG_HOME,
    ENV_XDG_DATA_HOME,
)


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
