#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Validation, projection, pagination, and body-builder helpers.

Carved from ``mural.__init__`` per the modularization plan. ``_paginate``
and ``_resolve_workspace_id`` reach back into the package for the current
``_authenticated_request`` attribute via a deferred ``from . import`` so
``monkeypatch.setattr(mural, "_authenticated_request", ...)`` propagates to
every caller.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import re
import urllib.parse
from typing import Any

from ._constants import ENV_DEFAULT_WORKSPACE
from ._exceptions import (
    MuralAmbiguousWorkspaceError,
    MuralSecurityError,
    MuralValidationError,
)

# Private (underscore-prefixed) globals defined here are consumed only by
# sibling modules via explicit ``from ._validation import ...`` rather than
# within this module. CodeQL's ``py/unused-global-variable`` query analyzes
# each module in isolation and would otherwise flag them as unused. Listing
# them in ``__all__`` marks them as this module's intended export surface.
# The package never uses ``from ._validation import *``, so this has no runtime
# effect on import behavior.
__all__ = [
    "_DEFAULT_PAGE_SIZE",
    "_MAX_PAGE_SIZE",
    "_IMAGE_CONTENT_TYPES",
    "_area_cache",
]

_MURAL_ID_RE = re.compile(r"^[A-Za-z0-9]+\.[A-Za-z0-9-]+$")
_AZURE_BLOB_HOST_SUFFIX = ".blob.core.windows.net"
_DEFAULT_PAGE_SIZE = 100
_MAX_PAGE_SIZE = 200
_MAX_CURSOR_BYTES = 4096
_IMAGE_CONTENT_TYPES: dict[str, str] = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
}

# Mural enforces a 25-character maximum on tag text.
_MAX_TAG_TEXT_LEN = 25
# Hyperlink href cap (defensive; Mural rejects very long URLs).
_MAX_HYPERLINK_LEN = 1024
# Hyperlink schemes Mural is allowed to render. Mural displays hyperlinks as
# clickable affordances on shapes/sticky-notes, so dangerous schemes
# (javascript:, data:, vbscript:, file:) are rejected at validation time.
_ALLOWED_HYPERLINK_SCHEMES: frozenset[str] = frozenset({"http", "https", "mailto"})
# Area layout values accepted by Mural's Areas API.
_VALID_AREA_LAYOUTS: frozenset[str] = frozenset({"free", "column", "row"})

# Module-level cache of area metadata keyed by area id. Populated by
# ``_get_area`` and the CLI ``area get`` handler. Process-local; not persisted.
_area_cache: dict[str, dict[str, Any]] = {}


def _validate_mural_id(value: str) -> str:
    """Return ``value`` after asserting it is a well-formed Mural id.

    Mural ids look like ``workspace.muralslug``.  Any input containing path
    separators, parent traversal sequences, or null bytes is rejected with
    ``MuralValidationError`` to prevent path injection in URL construction.
    """
    if not isinstance(value, str) or not value:
        raise MuralValidationError("mural id must be a non-empty string")
    if "\x00" in value or "/" in value or "\\" in value or ".." in value:
        raise MuralValidationError(f"mural id contains forbidden characters: {value!r}")
    if not _MURAL_ID_RE.match(value):
        raise MuralValidationError(
            f"mural id must match {_MURAL_ID_RE.pattern}, got {value!r}"
        )
    return value


def _extract_field(obj: Any, path: str) -> Any:
    """Return the value at ``path`` (dotted notation) within ``obj`` or ``None``.

    Accepts ``a.b.c`` and indexes both dict keys and integer list indices.
    Never raises; missing or type-mismatched segments yield ``None``.
    """
    if not path:
        return obj
    current: Any = obj
    for segment in path.split("."):
        if current is None:
            return None
        if isinstance(current, dict):
            current = current.get(segment)
        elif isinstance(current, list):
            try:
                idx = int(segment)
            except ValueError:
                return None
            if 0 <= idx < len(current):
                current = current[idx]
            else:
                return None
        else:
            return None
    return current


def _project_record(record: Any, fields: list[str] | None) -> Any:
    """Return a shallow projection of ``record`` to ``fields`` (dotted paths)."""
    if not fields:
        return record
    if isinstance(record, list):
        return [_project_record(item, fields) for item in record]
    if not isinstance(record, dict):
        return record
    return {field: _extract_field(record, field) for field in fields}


def _format_output(data: Any, fields: list[str] | None, fmt: str) -> str:
    """Render ``data`` for stdout in ``json`` or ``table`` form."""
    projected = _project_record(data, fields)
    if fmt == "table":
        rows = projected if isinstance(projected, list) else [projected]
        if not rows:
            return ""
        keys = fields or sorted({k for r in rows if isinstance(r, dict) for k in r})
        if not keys:
            return ""
        widths = [
            max(
                len(k),
                *(len(str(_extract_field(r, k) or "")) for r in rows),
            )
            for k in keys
        ]
        header = "  ".join(k.ljust(w) for k, w in zip(keys, widths))
        sep = "  ".join("-" * w for w in widths)
        body_lines = [
            "  ".join(
                str(_extract_field(r, k) or "").ljust(w) for k, w in zip(keys, widths)
            )
            for r in rows
        ]
        return "\n".join([header, sep, *body_lines])
    return json.dumps(projected, indent=2)


def _parse_pagination_cursor(token: str) -> dict[str, Any]:
    """Decode and validate an opaque pagination cursor token.

    The cursor is treated as base64url-encoded JSON.  Tokens larger than
    ``_MAX_CURSOR_BYTES`` raw bytes or that fail to decode are rejected with
    ``MuralValidationError``; the helper exists primarily as a fuzzable seam.
    """
    if not isinstance(token, str) or not token:
        raise MuralValidationError("cursor token must be a non-empty string")
    if len(token.encode("utf-8")) > _MAX_CURSOR_BYTES:
        raise MuralValidationError("cursor token exceeds maximum size")
    padding = "=" * (-len(token) % 4)
    try:
        raw = base64.urlsafe_b64decode(token + padding)
    except (binascii.Error, ValueError) as exc:
        raise MuralValidationError("cursor token is not base64url") from exc
    try:
        decoded = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MuralValidationError("cursor token payload is not JSON") from exc
    if not isinstance(decoded, dict):
        raise MuralValidationError("cursor token payload must be a JSON object")
    return decoded


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


# Defensive unwrap of {"value": <dict>} single-GET envelope; passthrough otherwise.
def _unwrap_value_envelope(record: Any) -> Any:
    if (
        isinstance(record, dict)
        and list(record.keys()) == ["value"]
        and isinstance(record["value"], dict)
    ):
        return record["value"]
    return record


def _paginate(
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    limit: int | None = None,
    page_size: int | None = None,
    max_pages: int | None = None,
    **request_kwargs: Any,
) -> Any:
    """Yield records across Mural's ``next``-cursor pagination.

    ``params`` is applied to every page so that ``type``, ``parentId``, and
    other filters remain consistent per Mural's pagination contract.
    ``page_size`` maps to the ``limit`` query parameter.  ``limit`` (the
    function argument) caps the total number of records yielded.
    ``max_pages`` caps the number of API requests made (use ``1`` to disable
    cursor following for debugging).
    """
    # Late-bound import: ``_authenticated_request`` lives in ``mural.__init__``
    # for now. Resolving it via the package attribute at call time keeps
    # ``monkeypatch.setattr(mural, "_authenticated_request", ...)`` effective.
    from . import _authenticated_request as _pkg_auth  # noqa: F401  (anchor)

    base_params = dict(params or {})
    if page_size is not None:
        base_params["limit"] = int(page_size)
    yielded = 0
    pages = 0
    next_token: str | None = None
    while True:
        page_params = dict(base_params)
        if next_token is not None:
            page_params["next"] = next_token
        from . import _authenticated_request as _auth

        response = _auth(method, path, params=page_params, **request_kwargs)
        pages += 1
        if isinstance(response, dict) and "value" in response:
            records = response.get("value") or []
            next_token = response.get("next") or None
        elif isinstance(response, list):
            records = response
            next_token = None
        else:
            yield response
            return
        for record in records:
            yield record
            yielded += 1
            if limit is not None and yielded >= limit:
                return
        if not next_token:
            return
        if max_pages is not None and pages >= max_pages:
            return


def _resolve_workspace_id(
    explicit: str | None,
    *,
    env: dict[str, str] | None = None,
    **request_kwargs: Any,
) -> str:
    """Return the workspace id, falling back to env or list discovery."""
    src = env if env is not None else os.environ
    if explicit:
        return explicit
    fallback = src.get(ENV_DEFAULT_WORKSPACE)
    if fallback:
        return fallback
    workspaces = list(_paginate("GET", "/workspaces", env=src, **request_kwargs))
    ids = [w.get("id") for w in workspaces if isinstance(w, dict) and w.get("id")]
    if len(ids) == 1:
        return ids[0]
    raise MuralAmbiguousWorkspaceError(workspace_ids=ids)


def _validate_asset_url(url: str) -> None:
    """Raise ``MuralSecurityError`` when ``url`` is not a safe Azure SAS link.

    SSRF allowlist: requires https, no userinfo, no fragment, no IP-literal
    host, and a hostname ending in ``.blob.core.windows.net``.
    """
    if not isinstance(url, str) or not url:
        raise MuralSecurityError("asset upload url is empty")
    try:
        parsed = urllib.parse.urlsplit(url)
    except ValueError as exc:
        raise MuralSecurityError(f"asset upload url is malformed: {exc}") from exc
    if parsed.scheme != "https":
        raise MuralSecurityError(
            f"asset upload url must be https, got {parsed.scheme!r}"
        )
    if parsed.username or parsed.password:
        raise MuralSecurityError("asset upload url must not contain userinfo")
    if parsed.fragment:
        raise MuralSecurityError("asset upload url must not contain a fragment")
    host = (parsed.hostname or "").lower()
    if not host:
        raise MuralSecurityError("asset upload url has no host")
    # Reject bare IPv4 (all dots+digits) and bracketed IPv6 (':' present).
    if host.replace(".", "").isdigit() or ":" in host:
        raise MuralSecurityError(
            f"asset upload url host must be a name, not an address: {host!r}"
        )
    if not host.endswith(_AZURE_BLOB_HOST_SUFFIX):
        raise MuralSecurityError(
            f"asset upload url host {host!r} is not on the Azure Blob allowlist"
        )


def _parse_json_arg(value: str, flag: str) -> Any:
    """Parse a JSON CLI argument, raising ``MuralValidationError`` on failure."""
    try:
        return json.loads(value)
    except json.JSONDecodeError as exc:
        raise MuralValidationError(f"{flag} is not valid JSON: {exc}") from exc


def _coerce_xy(value: Any, name: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise MuralValidationError(f"{name} must be numeric, got {value!r}") from exc


def _validate_hyperlink(value: Any) -> str:
    """Return ``value`` after asserting it is a safe hyperlink string.

    Enforces a non-empty string, a ``_MAX_HYPERLINK_LEN`` cap, and an
    allowlist of URL schemes (``http``, ``https``, ``mailto``). Dangerous
    schemes such as ``javascript:``, ``data:``, ``vbscript:``, and
    ``file:`` are rejected because Mural surfaces hyperlinks as clickable
    affordances on widgets and would otherwise enable cross-tenant
    phishing or script execution against viewers.
    """
    if not isinstance(value, str) or not value:
        raise MuralValidationError("hyperlink must be a non-empty string")
    if len(value) > _MAX_HYPERLINK_LEN:
        raise MuralValidationError(
            f"hyperlink exceeds {_MAX_HYPERLINK_LEN}-character limit"
        )
    try:
        scheme = urllib.parse.urlsplit(value).scheme.lower()
    except ValueError as exc:
        raise MuralValidationError(f"hyperlink is not a parseable URL: {exc}") from exc
    if scheme not in _ALLOWED_HYPERLINK_SCHEMES:
        allowed = ", ".join(sorted(_ALLOWED_HYPERLINK_SCHEMES))
        raise MuralValidationError(
            f"hyperlink scheme {scheme!r} is not allowed (allowed: {allowed})"
        )
    return value


def _validate_tag_text(value: Any) -> str:
    """Return ``value`` after asserting it is non-empty and ≤25 characters."""
    if not isinstance(value, str) or not value:
        raise MuralValidationError("tag text must be a non-empty string")
    if len(value) > _MAX_TAG_TEXT_LEN:
        raise MuralValidationError(
            f"tag text exceeds {_MAX_TAG_TEXT_LEN}-character limit"
        )
    return value


def _validate_area_layout(value: Any) -> str:
    """Return ``value`` if it is one of ``free|column|row``."""
    if value not in _VALID_AREA_LAYOUTS:
        raise MuralValidationError(
            "area layout must be one of: " + ", ".join(sorted(_VALID_AREA_LAYOUTS))
        )
    return value


def _build_area_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "title", None):
        raise MuralValidationError("--title is required for area create")
    body: dict[str, Any] = {
        "title": args.title,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    layout = getattr(args, "layout", None)
    if layout:
        body["layout"] = _validate_area_layout(layout)
    parent_id = getattr(args, "parent_id", None)
    if parent_id:
        body["parentId"] = parent_id
    return body


def _build_sticky_note_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "text", None):
        raise MuralValidationError("--text is required for sticky-note widgets")
    body: dict[str, Any] = {
        "text": args.text,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
        "shape": getattr(args, "shape", None) or "rectangle",
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    if getattr(args, "hyperlink", None):
        body["hyperlink"] = _validate_hyperlink(args.hyperlink)
    if getattr(args, "parent_id", None):
        body["parentId"] = args.parent_id
    return body


def _build_textbox_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "text", None):
        raise MuralValidationError("--text is required for textbox widgets")
    body: dict[str, Any] = {
        "text": args.text,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    if getattr(args, "hyperlink", None):
        body["hyperlink"] = _validate_hyperlink(args.hyperlink)
    if getattr(args, "parent_id", None):
        body["parentId"] = args.parent_id
    return body


def _build_shape_body(args: argparse.Namespace) -> dict[str, Any]:
    if not getattr(args, "shape", None):
        raise MuralValidationError("--shape is required for shape widgets")
    body: dict[str, Any] = {
        "shape": args.shape,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "text", None):
        body["text"] = args.text
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    if getattr(args, "hyperlink", None):
        body["hyperlink"] = _validate_hyperlink(args.hyperlink)
    if getattr(args, "parent_id", None):
        body["parentId"] = args.parent_id
    return body


def _build_arrow_body(args: argparse.Namespace) -> dict[str, Any]:
    body: dict[str, Any] = {
        "x1": _coerce_xy(getattr(args, "x1", None), "--x1"),
        "y1": _coerce_xy(getattr(args, "y1", None), "--y1"),
        "x2": _coerce_xy(getattr(args, "x2", None), "--x2"),
        "y2": _coerce_xy(getattr(args, "y2", None), "--y2"),
    }
    if getattr(args, "style", None):
        body["style"] = _parse_json_arg(args.style, "--style")
    if getattr(args, "hyperlink", None):
        body["hyperlink"] = _validate_hyperlink(args.hyperlink)
    if getattr(args, "parent_id", None):
        body["parentId"] = args.parent_id
    return body


def _build_image_body(
    *,
    asset_name: str,
    args: argparse.Namespace,
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "name": asset_name,
        "x": _coerce_xy(args.x, "--x"),
        "y": _coerce_xy(args.y, "--y"),
    }
    if getattr(args, "width", None) is not None:
        body["width"] = _coerce_xy(args.width, "--width")
    if getattr(args, "height", None) is not None:
        body["height"] = _coerce_xy(args.height, "--height")
    if getattr(args, "title", None):
        body["title"] = args.title
    alt_text = getattr(args, "alt_text", None)
    if alt_text:
        body["altText"] = alt_text
    if getattr(args, "hyperlink", None):
        body["hyperlink"] = _validate_hyperlink(args.hyperlink)
    if getattr(args, "parent_id", None):
        body["parentId"] = args.parent_id
    return body
