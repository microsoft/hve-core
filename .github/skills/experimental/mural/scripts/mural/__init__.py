#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# dependencies = ["shapely>=2.0", "networkx>=3.0", "keyring>=24.0"]
# ///
"""Mural REST API client and CLI.

The auth surface covers env-var resolution, token-store I/O, PKCE, the
``_authenticated_request`` transport with auto-refresh and 429 backoff, and the
loopback OAuth ``auth login`` / ``logout`` / ``status`` subcommands. Mural REST
resource subcommands (workspace, room, mural, widget) live in this same module.

Runtime third-party dependencies are ``shapely`` and ``networkx``;
``shapely`` requires GEOS >= 3.11 to be present on the host. Test seams are
exposed via private parameters (``_http``, ``_now``, ``_open_browser``,
``_server_factory``) so unit tests can substitute fakes without
monkey-patching.
"""

from __future__ import annotations

import argparse
import getpass  # noqa: F401 - re-exposed as patchable facade attribute
import json
import logging
import os
import pathlib  # noqa: F401 - re-exposed as patchable facade attribute
import re
import secrets
import sys
import time  # noqa: F401 - re-exposed as patchable facade attribute
import webbrowser  # noqa: F401 - re-exposed as patchable facade attribute
from typing import Any, Callable

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
    _acquire_cache_lock,
    _autoload_credentials,
    _check_credential_file_perms,
    _compute_expires_at,
    _KeyringUnavailable,
    _load_token_store,
    _maybe_warn_concurrent_state,
    _migrate_v1_to_v2,
    _NullBackend,
    _probe_keyring_availability,
    _profile_from_credential_path,
    _resolve_active_profile,
    _resolve_credential_file,
    _resolve_token_store_path,
    _save_token_store,
    _select_profile,
    _service_name_for,
    _token_store_session,
    _validate_client_secret,
    _validate_profile,
    _validate_profile_name,
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


# Tag texts that are managed by the CLI and may not be removed without an
# explicit override. The ``authored-by-ai`` tag is auto-attached to every
# widget created by AI-driven flows so downstream consumers can distinguish
# AI-authored objects from human-authored ones.

# Reserved tag text *prefixes* applied by composite/layout flows. Mutating
# these via tag tools requires `force_reserved=True` just like literal
# reserved tags. Kept as a separate registry so prefix membership is cheap.


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
# Step 5.4 — Output emit tier (early re-export)
# ---------------------------------------------------------------------------
# ``_emit``, ``_emit_debug_traceback``, and ``_color_mode`` are carved into
# ``_output``. They are bound on the package surface here, BEFORE the
# ``_backends``/``_transport`` re-exports below, because both submodules bind
# ``_emit`` from the package at module-load time. The moved ``_emit`` and
# ``_emit_debug_traceback`` reach back through ``_pkg()._redact`` at call time,
# so importing ``_output`` at this point is import-safe (it pulls in only
# ``_state``, ``_constants``, and ``_validation``).
from ._output import (  # noqa: E402,F401
    _color_mode,
    _emit,
    _emit_debug_traceback,
)

# isort: split
# The ``_backends`` re-export below MUST execute after the ``_output`` block
# above so ``_emit`` is already bound on the package surface when ``_backends``
# imports it at module-load time. ``# isort: split`` keeps the two blocks in
# this deliberate dependency order.


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
    _bootstrap_is_interactive,
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
# depends on (``_emit``, ``_load_token_store``, etc.)
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
# ``_oauth`` owns the PKCE primitives and the scope/refresh helpers; it reaches
# back through the package facade for the transport and credential helpers it
# depends on (``_TOKEN_OPENER``, ``_select_profile`` etc.), which are
# re-exported above so ``_oauth``'s load-time binding resolves them.
from ._oauth import (  # noqa: E402,F401
    _apply_refresh,
    _b64url_nopad,
    _build_authorize_url,
    _CallbackResult,
    _coalesced_refresh,
    _exchange_authorization_code,
    _generate_pkce_pair,
    _LoopbackHandler,
    _LoopbackServer,
    _probe_client_credentials,
    _require_scope,
    _resolve_redirect_uri,
    _run_login,
    _start_loopback_server,
    _token_granted_scopes,
    _validate_redirect_uri,
    _verify_pkce,
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
    _list_kwargs,
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
    # process-local mutable state re-exported from ._geometry
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
    _is_reserved_tag_text,
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
    _GEOS_PROBE_DONE,
    Rect,
    _area_probe_verdict,
    _ensure_geos_ready,
    _probe_geos_version,
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
from ._signals import _install_signal_handlers  # noqa: E402,F401

# --- Phase 4 composites: confirmation gate, find, sweep, summary, DT ------


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

# --- Voting tool handlers ----------------------------------------------------
# --- Workspace search --------------------------------------------------------
# --- Tool handlers --------------------------------------------------------
#
# Each handler receives a validated ``arguments`` dict and returns a Python
# object that will be JSON-encoded by callers. Handlers reuse the same Mural
# API helpers (``_authenticated_request``, ``_paginate``, body builders) as
# the CLI ``_cmd_*`` functions but skip the argparse Namespace +
# stdout-printing layer.
from ._operations import (  # noqa: E402,F401 - re-export carved CLI operations surface
    _LINEAGE_PREFIX_PATTERN,
    _apply_lineage_prefix,
    _cmd_compose_affinity_cluster,
    _cmd_compose_bootstrap_dt_board,
    _cmd_compose_bootstrap_ux_board,
    _cmd_compose_parking_lot_sweep,
    _cmd_compose_populate_dt_section,
    _cmd_compose_workspace_summary,
    _cmd_mural_find,
    _cmd_mural_lineage_lookup,
    _cmd_mural_repair_tag_drift,
    _cmd_voting_poll,
    _cmd_voting_results,
    _cmd_voting_session_close,
    _cmd_voting_session_create,
    _cmd_voting_session_delete,
    _cmd_voting_session_get,
    _cmd_voting_session_list,
    _cmd_voting_session_open,
    _cmd_widget_get_with_context,
    _cmd_widget_list_with_context,
    _cmd_workspace_search,
    _confirmation_consume,
    _confirmation_register,
    _idempotency_get,
    _idempotency_put,
    _lineage_prefix,
    _load_dt_sections_map,
    _load_payload_file,
    _new_lineage_run_id,
    _ns_for_list,
    _ns_for_widget_body,
    _op_area_create,
    _op_area_get,
    _op_area_list,
    _op_area_probe,
    _op_auth_status,
    _op_bootstrap_dt_board,
    _op_bootstrap_ux_board,
    _op_clone_with_tags,
    _op_create_affinity_cluster,
    _op_layout,
    _op_layout_cluster,
    _op_layout_column,
    _op_layout_grid,
    _op_layout_row,
    _op_mural_archive,
    _op_mural_create,
    _op_mural_duplicate,
    _op_mural_find,
    _op_mural_get,
    _op_mural_lineage_lookup,
    _op_mural_list,
    _op_mural_poll,
    _op_mural_unarchive,
    _op_parking_lot_sweep,
    _op_populate_dt_section,
    _op_repair_tag_drift,
    _op_room_create,
    _op_room_get,
    _op_room_list,
    _op_spatial_arrow_graph,
    _op_spatial_cluster,
    _op_spatial_pairwise_overlaps,
    _op_spatial_sort_along_axis,
    _op_spatial_widgets_in_region,
    _op_spatial_widgets_in_shape,
    _op_tag_apply,
    _op_tag_create,
    _op_tag_list,
    _op_tag_remove,
    _op_template_create,
    _op_template_instantiate,
    _op_template_list,
    _op_voting_poll,
    _op_voting_results,
    _op_voting_run,
    _op_voting_session_close,
    _op_voting_session_create,
    _op_voting_session_delete,
    _op_voting_session_get,
    _op_voting_session_list,
    _op_voting_session_open,
    _op_widget_create_arrow,
    _op_widget_create_bulk,
    _op_widget_create_image,
    _op_widget_create_shape,
    _op_widget_create_sticky_note,
    _op_widget_create_textbox,
    _op_widget_delete,
    _op_widget_get,
    _op_widget_get_with_context,
    _op_widget_list,
    _op_widget_list_with_context,
    _op_widget_update,
    _op_widget_update_bulk,
    _op_workspace_get,
    _op_workspace_list,
    _op_workspace_search,
    _op_workspace_summary,
    _parse_lineage_prefix,
    _parse_simple_yaml,
    _parse_yaml_scalar,
    _poll_voting_session,
    _slugify_label,
    _trigram_score,
    _validate_voting_session_id,
    _voting_results,
    _voting_run_compose,
    _voting_session_create,
    _voting_session_delete,
    _voting_session_get,
    _voting_session_list,
    _voting_session_path,
    _voting_session_set_status,
)
from ._parser import (  # noqa: E402,F401 - re-export carved argparse parser surface
    _add_author_guard_flags,
    _add_no_author_tag_flag,
    _add_output_flags,
    _add_pagination_flags,
    _add_resource_subcommands,
    _add_xy,
    _build_parser,
)


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
