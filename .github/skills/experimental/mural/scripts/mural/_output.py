#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Output, emit, and widget-text helpers for the Mural CLI.

Carved from ``mural.__init__`` per the modularization plan. ``_emit_record``
reaches back into the package for the current ``_unwrap_value_envelope``
attribute via a deferred ``from . import`` so
``monkeypatch.setattr(mural, "_unwrap_value_envelope", ...)`` propagates to the
emit path. ``_format_output`` is imported directly because it is not part of
the facade-dispatch surface.
"""

from __future__ import annotations

import argparse
import re
import sys
from typing import Any

from . import _state
from ._constants import EXIT_SUCCESS
from ._validation import _format_output

# Private (underscore-prefixed) globals defined here are consumed by sibling
# modules via explicit ``from ._output import ...`` rather than within this
# module. CodeQL's ``py/unused-global-variable`` query analyzes each module in
# isolation and would otherwise flag them as unused. Listing them in
# ``__all__`` marks them as this module's intended export surface. The package
# never uses ``from ._output import *``, so this has no runtime effect on
# import behavior.
__all__ = [
    "_read_fields",
    "_strip_html",
    "_coalesce_widget_text",
    "_apply_widget_text_coalesce",
    "_emit_records",
    "_emit_record",
]

_HTML_TAG_RE = re.compile(r"<[^>]+>")


def _pkg() -> Any:
    """Return the live ``mural`` package module for monkeypatch-aware routing."""
    return sys.modules[__package__]


def _read_fields(args: argparse.Namespace) -> list[str] | None:
    raw = getattr(args, "fields", None)
    if not raw:
        return None
    return [f.strip() for f in raw.split(",") if f.strip()]


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
    fmt = (
        "json"
        if _state._CLI_FORCE_JSON
        else (getattr(args, "format", None) or "json")
    )
    print(_format_output(records, fields, fmt))
    return EXIT_SUCCESS


def _emit_record(record: Any, args: argparse.Namespace) -> int:
    record = _pkg()._unwrap_value_envelope(record)
    _apply_widget_text_coalesce(record)
    fields = _read_fields(args)
    fmt = (
        "json"
        if _state._CLI_FORCE_JSON
        else (getattr(args, "format", None) or "json")
    )
    print(_format_output(record, fields, fmt))
    return EXIT_SUCCESS
