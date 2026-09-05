#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
import json
import logging
import os
import re
import sys
import traceback
import urllib.parse
from typing import Any

from . import _state
from ._constants import _REDACT_KEYS, EXIT_SUCCESS
from ._exceptions import MuralSecurityError
from ._validation import _format_output, _validate_asset_url

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
    "_emit",
    "_emit_json",
    "_emit_json_error",
    "_redact_payload",
    "_emit_debug_traceback",
    "_color_mode",
]

LOGGER = logging.getLogger("mural")
# _emit prints to stderr itself. Without a handler, logging's lastResort
# fallback would also write every WARNING-or-above record to stderr, printing
# those messages twice. The NullHandler suppresses that while leaving the
# logger available to an embedder that configures its own handlers.
LOGGER.addHandler(logging.NullHandler())

_HTML_TAG_RE = re.compile(r"<[^>]+>")

# Replacement text used when a mapping key is itself sensitive. Matches the
# substitution the ``_REDACT_PATTERNS`` regexes emit, so masked output looks
# the same regardless of which mechanism produced it.
_MASK = "***"


def _emit(message: str, *, level: int = logging.INFO) -> None:
    """Write a redacted message to stderr and the module logger."""
    redacted = _pkg()._redact(message)
    LOGGER.log(level, redacted)
    if level >= logging.ERROR or not _state._CLI_QUIET:
        print(redacted, file=sys.stderr)


def _emit_json(payload: Any) -> None:
    """Redact ``payload``, serialize it, then write it to stdout.

    Machine-readable ``--json`` envelopes are written to stdout rather than
    through :func:`_emit`, so without this helper they would bypass the
    redaction barrier that every stderr message passes through. Envelopes can
    embed backend error text and credential key names, so routing them here
    keeps the redaction guarantee uniform across both output channels.

    Redaction runs over the payload before serialization rather than over the
    serialized text, for the same reasons documented on
    :func:`_emit_json_error`: scrubbing the serialized form can consume the
    closing quote and brace of a JSON string and emit output that no longer
    parses. ``indent=2`` is preserved because pretty-printed ``--json`` output
    is part of the operator-facing CLI contract.
    """
    print(json.dumps(_redact_payload(payload), indent=2))


def _emit_json_error(payload: Any) -> None:
    """Redact ``payload`` in place-safe fashion, serialize it, write it to stderr.

    Terminal error envelopes are machine-readable and belong on stderr, so they
    can use neither :func:`_emit` (which also writes a duplicate logger record
    and reformats through the logging layer) nor :func:`_emit_json` (which
    targets stdout). Without this helper each envelope would reach stderr via a
    bare ``print(json.dumps(...))`` and bypass the redaction barrier that every
    other output channel passes through.

    Redaction runs over the payload's string *values* before serialization
    rather than over the serialized text. Scrubbing the serialized form would
    corrupt the envelope: the form-style pattern consumes every non-whitespace
    character after ``key=``, which swallows the closing quote and brace when a
    secret sits at the tail of a JSON string, and the JSON-style pattern fails
    to match once ``json.dumps`` has escaped the inner quotes. Redacting values
    first keeps the output parseable and the key set intact.
    """
    print(json.dumps(_redact_payload(payload)), file=sys.stderr)


def _redact_payload(payload: Any) -> Any:
    """Return a copy of ``payload`` with every string value redacted.

    Recurses through dicts, lists, tuples, sets, and frozensets. Mapping keys
    are left untouched so the envelope key set consumers parse cannot change;
    envelope keys are fixed literals in the raising code and never carry
    credential material.

    Two behaviours are deliberate and easy to "improve" incorrectly:

    * Sets are rebuilt as sets, never coerced to lists. ``json.dumps`` renders
      a tuple as an array but cannot serialize a set at all, so coercing here
      would change which payloads :func:`_emit_json_error` can serialize. That
      is a serialization decision, not a redaction one, and it belongs at the
      sink rather than inside this helper.
    * Redaction is not injective, so rebuilding a set can collapse its
      cardinality: ``{"code=A", "code=B"}`` reduces to a single member. That is
      acceptable for an error envelope, but member counts are not preserved.

    Tuples are rebuilt with ``tuple`` rather than ``type(payload)`` because a
    namedtuple is a tuple subclass whose constructor takes positional fields.
    Sets use the concrete ``set`` and ``frozenset`` constructors for the same
    reason.

    A mapping key whose lowercased form is an exact member of
    ``_REDACT_KEYS`` has its value replaced wholesale, whatever that value's
    type. This replaces what redacting the serialized text used to provide for
    top-level pairs, and is stronger: it does not depend on quoting, escaping,
    or serialization order, and it covers non-string values.

    Key matching is exact after lowercasing, never by suffix or substring.
    Env-style names such as ``MURAL_CLIENT_SECRET`` therefore do NOT match,
    which is deliberate: the values recorded under those names are backend
    error strings, and widening the match would change shipped
    ``auth logout --json`` output. A future path that needs to carry an actual
    credential value should not do so under an unmatched key name; add the key
    to ``_REDACT_KEYS`` instead of loosening the comparison here.
    """
    if isinstance(payload, str):
        return _pkg()._redact(payload)
    if isinstance(payload, dict):
        return {
            key: (
                _MASK
                if isinstance(key, str) and key.lower() in _REDACT_KEYS
                else _redact_payload(value)
            )
            for key, value in payload.items()
        }
    if isinstance(payload, list):
        return [_redact_payload(item) for item in payload]
    if isinstance(payload, tuple):
        return tuple(_redact_payload(item) for item in payload)
    if isinstance(payload, (set, frozenset)):
        items = (_redact_payload(item) for item in payload)
        return frozenset(items) if isinstance(payload, frozenset) else set(items)
    return payload


def _emit_debug_traceback(exc: BaseException) -> None:
    """Write a redacted traceback to stderr when ``MURAL_DEBUG`` is set.

    Routes the formatted traceback through :func:`_redact` so OAuth state,
    tokens, and ``Authorization`` headers cannot leak via an unexpected
    exception bubbling out of :func:`main`.
    """
    if not os.environ.get("MURAL_DEBUG"):
        return
    formatted = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    print(_pkg()._redact(formatted), file=sys.stderr)


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


def _mask_record_transport_credentials(payload: Any) -> Any:
    """Mask validated Azure Blob SAS URLs without changing record content."""
    if isinstance(payload, str):
        try:
            _validate_asset_url(payload)
        except MuralSecurityError:
            return payload
        query = urllib.parse.urlsplit(payload).query
        if any(
            key.lower() == "sig"
            for key, _value in urllib.parse.parse_qsl(query, keep_blank_values=True)
        ):
            return _pkg()._redact(payload)
        return payload
    if isinstance(payload, dict):
        return {
            key: _mask_record_transport_credentials(value)
            for key, value in payload.items()
        }
    if isinstance(payload, list):
        return [_mask_record_transport_credentials(item) for item in payload]
    if isinstance(payload, tuple):
        return tuple(_mask_record_transport_credentials(item) for item in payload)
    if isinstance(payload, (set, frozenset)):
        items = (_mask_record_transport_credentials(item) for item in payload)
        return frozenset(items) if isinstance(payload, frozenset) else set(items)
    return payload


def _emit_records(records: list[Any], args: argparse.Namespace) -> int:
    """Write a record list to stdout, masking validated SAS URL values.

    Successful records preserve Mural-authored content verbatim. Complete
    Azure Blob SAS URL values are the exception because their ``sig`` query
    parameter is a transport credential rather than authored record content.
    """
    _apply_widget_text_coalesce(records)
    fields = _read_fields(args)
    fmt = (
        "json" if _state._CLI_FORCE_JSON else (getattr(args, "format", None) or "json")
    )
    print(_format_output(_mask_record_transport_credentials(records), fields, fmt))
    return EXIT_SUCCESS


def _emit_record(record: Any, args: argparse.Namespace) -> int:
    """Write one record to stdout. See :func:`_emit_records`."""
    record = _pkg()._unwrap_value_envelope(record)
    _apply_widget_text_coalesce(record)
    fields = _read_fields(args)
    fmt = (
        "json" if _state._CLI_FORCE_JSON else (getattr(args, "format", None) or "json")
    )
    print(_format_output(_mask_record_transport_credentials(record), fields, fmt))
    return EXIT_SUCCESS
