#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Module-level constants for the Mural CLI package.

Frozen literals, env-var name registry, redaction patterns, and other
stateless module-level definitions live here so submodules can import
without taking a dependency on the legacy monolith.
"""

from __future__ import annotations

import os
import re
import threading

# Globals defined here are consumed by sibling modules via explicit
# ``from ._constants import ...`` rather than within this module. CodeQL's
# ``py/unused-global-variable`` query analyzes each module in isolation and
# would otherwise flag them as unused. Listing them in ``__all__`` marks them
# as this module's intended export surface. The package never uses
# ``from ._constants import *``, so this has no runtime effect on import
# behavior.
__all__ = [
    # OAuth endpoints and redirect.
    "MURAL_BASE_URL_DEFAULT",
    "MURAL_AUTHORIZE_URL",
    "MURAL_TOKEN_URL",
    "DEFAULT_REDIRECT_URI",
    # Environment variable name registry.
    "ENV_BASE_URL",
    "ENV_CLIENT_ID",
    "ENV_CLIENT_SECRET",
    "ENV_PROFILE",
    "ENV_SCOPES",
    "ENV_REDIRECT_URI",
    "ENV_TOKEN_STORE",
    "ENV_DEFAULT_WORKSPACE",
    "ENV_XDG_DATA_HOME",
    "ENV_NONINTERACTIVE",
    "ENV_ENV_FILE",
    "ENV_ENV_FILE_RELAXED",
    "ENV_XDG_CONFIG_HOME",
    # Bulk and polling limits.
    "MAX_BULK_WIDGETS",
    "POLL_DEFAULT_INTERVAL_S",
    "POLL_MAX_INTERVAL_S",
    "POLL_DEFAULT_TIMEOUT_S",
    "POLL_MAX_TIMEOUT_S",
    # Scopes and user agent.
    "DEFAULT_LOGIN_SCOPES",
    "DEFAULT_SCOPES",
    "READ_SCOPES",
    "WRITE_SCOPES",
    "USER_AGENT",
    # Rate limiting and retry policy.
    "RATE_LIMIT_TOKENS_PER_SEC",
    "RATE_LIMIT_BUCKET_CAPACITY",
    "MAX_RETRIES",
    "MAX_BACKOFF_SECONDS",
    "REFRESH_LEEWAY_SECONDS",
    # Process exit codes.
    "EXIT_SUCCESS",
    "EXIT_FAILURE",
    "EXIT_USAGE",
    "EXIT_TEMPFAIL",
    "EXIT_NOPERM",
    "EXIT_AREA_CAPACITY",
    # Transport hardening limits.
    "MURAL_MAX_FRAME_BYTES",
    "MURAL_MAX_BODY_BYTES",
    "MURAL_TOOL_TIMEOUT_SECS",
    # Token-store schema.
    "TOKEN_STORE_SCHEMA_VERSION",
    "DEFAULT_PROFILE_NAME",
    # Private (underscore-prefixed) cross-module globals.
    "_KNOWN_CREDENTIAL_KEYS",
    "_REDACT_KEYS",
    "_REDACT_PATTERNS",
    "_REFRESH_LOCK",
    "_RESERVED_TAGS",
    "_AUTHORED_BY_AI_TAG_TEXT",
    "_RESERVED_TAG_PREFIXES",
    "_TAG_MERGE_MAX_RETRIES",
    "_TAG_MERGE_BACKOFF_MIN_MS",
    "_TAG_MERGE_BACKOFF_MAX_MS",
    "_LINE_RE",
    "_PROFILE_NAME_RE",
    "_PROFILE_REQUIRED_KEYS",
]

MURAL_BASE_URL_DEFAULT = "https://app.mural.co/api/public/v1"
MURAL_AUTHORIZE_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/"
MURAL_TOKEN_URL = "https://app.mural.co/api/public/v1/authorization/oauth2/token"
# Loopback redirect URI: register ``http://localhost:8765/callback`` in the
# Mural OAuth app. The local HTTP server still binds to ``127.0.0.1`` (RFC
# 8252 §7.3) but the URI advertised to Mural uses ``localhost`` so the
# Mural portal accepts it (the portal rejects raw IPv4 literals as of 2024).
# Override with MURAL_REDIRECT_URI (validated by ``_validate_redirect_uri``).
DEFAULT_REDIRECT_URI = "http://localhost:8765/callback"

ENV_BASE_URL = "MURAL_BASE_URL"
ENV_CLIENT_ID = "MURAL_CLIENT_ID"
ENV_CLIENT_SECRET = "MURAL_CLIENT_SECRET"
ENV_PROFILE = "MURAL_PROFILE"
ENV_SCOPES = "MURAL_SCOPES"
ENV_REDIRECT_URI = "MURAL_REDIRECT_URI"
ENV_TOKEN_STORE = "MURAL_TOKEN_STORE"
ENV_DEFAULT_WORKSPACE = "MURAL_DEFAULT_WORKSPACE"
ENV_XDG_DATA_HOME = "XDG_DATA_HOME"
ENV_NONINTERACTIVE = "MURAL_NONINTERACTIVE"
ENV_ENV_FILE = "MURAL_ENV_FILE"
ENV_ENV_FILE_RELAXED = "MURAL_ENV_FILE_RELAXED"
ENV_XDG_CONFIG_HOME = "XDG_CONFIG_HOME"

# Credential keys recognized by the credential backend abstraction. The
# refresh token is stored persistently per-profile alongside client_id and
# client_secret so keyring-backed deployments can retain authentication
# state across processes without an env file.
_KNOWN_CREDENTIAL_KEYS: tuple[str, ...] = (
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    "MURAL_REFRESH_TOKEN",
)

READ_SCOPES: tuple[str, ...] = (
    "identity:read",
    "workspaces:read",
    "rooms:read",
    "murals:read",
    "templates:read",
)
WRITE_SCOPES: tuple[str, ...] = ("murals:write", "templates:write", "rooms:write")
# Maximum widgets accepted by ``mural_widget_create_bulk`` in a single call.
MAX_BULK_WIDGETS = 1000
# Polling defaults for ``mural_mural_poll``.
POLL_DEFAULT_INTERVAL_S = 5.0
POLL_MAX_INTERVAL_S = 60.0
POLL_DEFAULT_TIMEOUT_S = 300.0
POLL_MAX_TIMEOUT_S = 3600.0
# Default scope string used by interactive bootstrap (``auth bootstrap``) and
# the credential probe: the union of read and write scopes a typical first-time
# user needs to exercise read-and-write workflows immediately after setup.
DEFAULT_LOGIN_SCOPES = " ".join(READ_SCOPES + WRITE_SCOPES)
# Back-compat alias: ``DEFAULT_SCOPES`` is the read-only space-separated string
# applied when ``auth login`` runs without ``--write`` and without ``--scopes``.
DEFAULT_SCOPES = " ".join(READ_SCOPES)

USER_AGENT = "hve-core-mural/1.0"

# Proactive client-side rate limit (Mural enforces ~60 req/min globally; we
# cap at 20 req/sec per process and back off on 429 regardless).
RATE_LIMIT_TOKENS_PER_SEC = 20.0
RATE_LIMIT_BUCKET_CAPACITY = 20.0

# 429 / transient retry policy.
MAX_RETRIES = 3
MAX_BACKOFF_SECONDS = 30.0

# Access tokens are refreshed if they expire within this many seconds.
REFRESH_LEEWAY_SECONDS = 60

# Serializes 401-driven refreshes so concurrent callers coalesce on a single
# token rotation instead of racing on the token store.
_REFRESH_LOCK = threading.Lock()


EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
EXIT_TEMPFAIL = 75
EXIT_NOPERM = 77
EXIT_AREA_CAPACITY = 65

# Tag texts that are managed by the CLI and may not be removed without an
# explicit override. The ``authored-by-ai`` tag is auto-attached to every
# widget created by AI-driven flows so downstream consumers can distinguish
# AI-authored objects from human-authored ones.
_RESERVED_TAGS: frozenset[str] = frozenset({"authored-by-ai"})
_AUTHORED_BY_AI_TAG_TEXT = "authored-by-ai"

# Reserved tag text *prefixes* applied by composite/layout flows. Mutating
# these via tag tools requires `force_reserved=True` just like literal
# reserved tags. Kept as a separate registry so prefix membership is cheap.
_RESERVED_TAG_PREFIXES: tuple[str, ...] = (
    "auto-layout-hash:",
    "dt-method:",
    "dt-section:",
    "cluster-label:",
    "ai-author:",
)

_TAG_MERGE_MAX_RETRIES = 3
_TAG_MERGE_BACKOFF_MIN_MS = 50
_TAG_MERGE_BACKOFF_MAX_MS = 200

# Transport hardening limits. All overridable via env for diagnostic flexibility.
MURAL_MAX_FRAME_BYTES = int(os.environ.get("MURAL_MAX_FRAME_BYTES", 4 * 1024 * 1024))
MURAL_MAX_BODY_BYTES = int(os.environ.get("MURAL_MAX_BODY_BYTES", 16 * 1024 * 1024))
MURAL_TOOL_TIMEOUT_SECS = float(os.environ.get("MURAL_TOOL_TIMEOUT_SECS", "60"))

# Patterns used by ``_redact``. Matches both JSON shapes and form/header
# shapes so log-line scrubbing works regardless of payload encoding.
# Mural uses Authorization Code + PKCE only, so the OIDC and alternate-grant
# keys below are defense-in-depth: they protect against third-party libraries
# (urllib3, requests) and future code paths that log standard OAuth/OIDC
# payloads using these field names.
_REDACT_KEYS = (
    "access_token",
    "refresh_token",
    "code_verifier",
    "client_secret",
    "id_token",  # OIDC ID Token (JWT)
    "assertion",  # RFC 7521 §4.2 — JWT/SAML bearer grant assertion
    "client_assertion",  # RFC 7521 §4.2 — JWT/SAML client authentication
    "device_code",  # RFC 8628 device-authorization grant pre-auth secret
    "password",  # RFC 6749 §4.3 ROPC credential
)
_REDACT_PATTERNS = [
    # JSON-style: "key": "value"
    (re.compile(rf'("{re.escape(k)}"\s*:\s*")([^"]*)(")'), r"\1***\3")
    for k in _REDACT_KEYS
]
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


_LINE_RE = re.compile(
    r"^\s*(?:export\s+)?(?P<k>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<v>.*?)\s*$"
)


# ---------------------------------------------------------------------------
# Token-store schema v2
# ---------------------------------------------------------------------------

TOKEN_STORE_SCHEMA_VERSION = 2
DEFAULT_PROFILE_NAME = "default"

# Profile names: 1-32 chars, leading alphanumeric or underscore, then
# alphanumeric / underscore / dot / hyphen. Rejects "..", path separators,
# whitespace, and empty strings.
_PROFILE_NAME_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,31}$")

# Required keys on every persisted profile after migration.
_PROFILE_REQUIRED_KEYS: tuple[str, ...] = (
    "client_id",
    "access_token",
    "token_type",
    "obtained_at",
    "expires_at",
)
