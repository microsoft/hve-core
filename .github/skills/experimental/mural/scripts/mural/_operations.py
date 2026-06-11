#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""CLI operations tier for the Mural CLI.

Carved from ``mural/__init__`` (Step 3.3 of the __init__ modularization plan).
Holds the ``_op_*`` operation functions, the Design-Thinking and UX board compose
tools with their ``_cmd_compose_*`` wrappers, lineage tagging helpers, the
voting-session store and its ``_cmd_voting_*``/``_op_voting_*`` surface,
workspace search, widget context wrappers, and the idempotency cache accessors.

Helpers that remain in the package ``__init__`` (profile resolution, tag and
area helpers, ``_list_kwargs``, and friends) are imported from the package and
bind when ``__init__`` first imports this submodule, after those helpers are
defined.

Intra-package calls to facade-patched symbols (``_authenticated_request``,
``_paginate``, ``_emit_record``, ``_merge_tags``, ``_ensure_tag_manifest``,
``_bulk_create_widgets``, ``_bulk_update_widgets``, ``_create_asset_url``,
``_upload_to_sas``, ``_load_token_store``, ``_duplicate_mural``,
``_ROTATION_ENABLED``, and the spatial geometry entrypoints) route through
:func:`_pkg` so ``monkeypatch.setattr(mural, <symbol>, ...)`` keeps intercepting
without test edits.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import secrets
import sys
import time
import uuid
from typing import Any, Callable

from . import (  # noqa: E402 - package siblings defined before this import runs
    LOGGER,
    _area_probe,
    _assert_widget_has_author_tag,
    _create_tag,
    _ensure_geos_ready,
    _get_area_with_widget_fallback,
    _get_widget_with_context,
    _is_reserved_tag_id,
    _list_areas_with_widget_fallback,
    _list_kwargs,
    _list_widgets_with_context,
    _maybe_apply_author_tag,
    _resolve_active_profile,
    _select_profile,
    _state,
    _token_granted_scopes,
    _widget_tag_ids,
)
from ._commands import (
    _build_bulk_widget_updates_payload,
    _build_bulk_widgets_payload,
    _bulk_apply_author_tag,
    _evaluate_poll,
    _parse_poll_condition,
    _patch_widget_or_disambiguate_404,
    _poll_mural,
    _read_tag_manifest,
    _set_mural_status,
    _template_target_body,
)
from ._constants import (
    DEFAULT_PROFILE_NAME,
    ENV_PROFILE,
    MAX_BULK_WIDGETS,
    POLL_DEFAULT_INTERVAL_S,
    POLL_DEFAULT_TIMEOUT_S,
    POLL_MAX_INTERVAL_S,
    POLL_MAX_TIMEOUT_S,
)
from ._credentials import (
    _resolve_credential_file,
    _resolve_token_store_path,
)
from ._exceptions import (
    MCPInvalidParamsError,
    MuralAPIError,
    MuralAreaCapacityExceeded,
    MuralError,
    MuralValidationError,
)
from ._geometry import (
    arrow_graph_summary,
    build_arrow_graph,
    safe_rect,
)
from ._layout import (
    _execute_layout,
    _repair_tag_drift,
)
from ._output import (
    _emit_records,
)
from ._validation import (
    _IMAGE_CONTENT_TYPES,
    _area_cache,
    _build_area_body,
    _build_arrow_body,
    _build_image_body,
    _build_shape_body,
    _build_sticky_note_body,
    _build_textbox_body,
    _parse_json_arg,
    _resolve_workspace_id,
    _validate_mural_id,
    _validate_tag_text,
)


def _pkg() -> Any:
    """Return the live ``mural`` package module for facade-routed patching."""
    return sys.modules[__package__]


def _confirmation_register(
    *, tool: str, arguments: dict[str, Any], candidates: list[dict[str, Any]]
) -> str:
    """Register a preview and return its ``preview_id``."""
    preview_id = uuid.uuid4().hex
    _state.pending_confirmations()[preview_id] = {
        "tool": tool,
        "arguments": dict(arguments),
        "candidates": list(candidates),
        "expires_at": time.time() + _state.confirmation_ttl_seconds(),
    }
    # Light cleanup of expired entries to bound the dict.
    now = time.time()
    expired = [
        k for k, v in _state.pending_confirmations().items() if v["expires_at"] < now
    ]
    for k in expired:
        _state.pending_confirmations().pop(k, None)
    return preview_id


def _confirmation_consume(*, tool: str, confirmed_id: str) -> dict[str, Any]:
    """Return the registered preview for ``confirmed_id`` or raise."""
    entry = _state.pending_confirmations().pop(confirmed_id, None)
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

    Cheap stdlib-only fuzzy match used by :func:`_op_mural_find` to rank
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


def _op_mural_find(arguments: dict[str, Any]) -> Any:
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
    records = list(_pkg()._paginate("GET", f"/workspaces/{workspace_id}/murals"))
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


def _op_workspace_summary(arguments: dict[str, Any]) -> Any:
    """Aggregate workspace-wide counts for read-only oversight."""
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    rooms = list(_pkg()._paginate("GET", f"/workspaces/{workspace_id}/rooms"))
    murals = list(_pkg()._paginate("GET", f"/workspaces/{workspace_id}/murals"))
    archived = sum(1 for m in murals if (m.get("status") or "").lower() == "archived")
    return {
        "workspace_id": workspace_id,
        "rooms": len(rooms),
        "murals": len(murals),
        "murals_archived": archived,
        "murals_active": len(murals) - archived,
    }


def _op_parking_lot_sweep(arguments: dict[str, Any]) -> Any:
    """Discover parked widgets via tag/area lookup. Read-only."""
    mural_id = _validate_mural_id(arguments.get("mural"))
    area_id = arguments.get("area")
    tag_text = arguments.get("tag", "parking-lot")
    widgets = list(_pkg()._paginate("GET", f"/murals/{mural_id}/widgets"))
    # Resolve tag id once; if absent on the mural, treat as empty manifest.
    try:
        manifest = _pkg()._ensure_tag_manifest(mural_id, [{"text": tag_text}])
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


def _op_bootstrap_ux_board(arguments: dict[str, Any]) -> Any:
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
        for area in _pkg()._paginate("GET", f"/murals/{mural_id}/areas"):
            if isinstance(area, dict):
                title = area.get("title")
                if isinstance(title, str):
                    existing_titles.add(title)
    except MuralError as exc:
        LOGGER.debug("failed to list existing areas for %s: %s", mural_id, exc)
    _pkg()._ensure_tag_manifest(mural_id, [{"text": "ux-board"}])
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
            area = _pkg()._authenticated_request(
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


def _op_bootstrap_dt_board(arguments: dict[str, Any]) -> Any:
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
    for m in _pkg()._paginate("GET", f"/workspaces/{workspace_id}/murals"):
        mid = m.get("id")
        if not mid:
            continue
        try:
            tags = _pkg()._authenticated_request("GET", f"/murals/{mid}/tags") or []
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
    created = _pkg()._authenticated_request(
        "POST", f"/workspaces/{workspace_id}/murals", json_body=body
    )
    mural_id = created.get("id") if isinstance(created, dict) else None
    if not mural_id:
        raise MuralAPIError("mural creation returned no id")
    _pkg()._ensure_tag_manifest(mural_id, [{"text": method_tag}])
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
            area = _pkg()._authenticated_request(
                "POST", f"/murals/{mural_id}/areas", json_body=area_body
            )
        except MuralError as exc:
            created_areas.append({"section": section_name, "error": str(exc)})
            continue
        created_areas.append({"section": section_name, "area": area})
        _pkg()._ensure_tag_manifest(mural_id, [{"text": f"dt-section:{section_name}"}])
    return {
        "mural_id": mural_id,
        "method": method,
        "idempotent": False,
        "areas": created_areas,
        "run_id": run_id,
    }


def _op_populate_dt_section(arguments: dict[str, Any]) -> Any:
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
    _pkg()._ensure_tag_manifest(mural_id, [{"text": section_tag}, {"text": method_tag}])
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
    placement = _op_layout("cluster", layout_args)
    return {
        "mural_id": mural_id,
        "method": method,
        "section": section,
        "area_id": area_id,
        "placement": placement,
        "run_id": run_id,
    }


def _op_create_affinity_cluster(arguments: dict[str, Any]) -> Any:
    """Place ``clusters`` (pre-clustered items) into an affinity area.

    LLM-driven clustering is out of scope for this stdlib-only skill;
    callers must pass already-grouped ``clusters`` of the form
    ``[{label, items: [...]}]``. Each cluster is laid out via
    :func:`_op_layout` (``cluster``) within a sub-region and tagged
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
        _pkg()._ensure_tag_manifest(
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
            placement = _op_layout("cluster", layout_args)
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


def _op_repair_tag_drift(arguments: dict[str, Any]) -> Any:
    """Re-assert intended reserved tags on widgets tracked this session."""
    mural_id = _validate_mural_id(arguments.get("mural"))
    repaired = _repair_tag_drift(mural_id)
    return {"mural_id": mural_id, "repaired": repaired}


def _op_mural_lineage_lookup(arguments: dict[str, Any]) -> Any:
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
    for widget in _pkg()._paginate("GET", f"/murals/{mural_id}/widgets"):
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
    return _pkg()._emit_record(_op_bootstrap_dt_board(payload), args)


def _cmd_compose_bootstrap_ux_board(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {
        "workspace": args.workspace,
        "mural": args.mural,
    }
    return _pkg()._emit_record(_op_bootstrap_ux_board(payload), args)


def _cmd_compose_populate_dt_section(args: argparse.Namespace) -> int:
    items = _parse_json_arg(_load_payload_file(args.items), "--items")
    payload: dict[str, Any] = {
        "mural": args.mural,
        "area": args.area,
        "method": args.method,
        "section": args.section,
        "items": items,
    }
    return _pkg()._emit_record(_op_populate_dt_section(payload), args)


def _cmd_compose_affinity_cluster(args: argparse.Namespace) -> int:
    clusters = _parse_json_arg(_load_payload_file(args.clusters), "--clusters")
    payload: dict[str, Any] = {
        "mural": args.mural,
        "area": args.area,
        "clusters": clusters,
    }
    return _pkg()._emit_record(_op_create_affinity_cluster(payload), args)


def _cmd_compose_parking_lot_sweep(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"mural": args.mural}
    if getattr(args, "area", None):
        payload["area"] = args.area
    if getattr(args, "tag", None):
        payload["tag"] = args.tag
    return _pkg()._emit_record(_op_parking_lot_sweep(payload), args)


def _cmd_compose_workspace_summary(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {}
    if getattr(args, "workspace", None):
        payload["workspace"] = args.workspace
    return _pkg()._emit_record(_op_workspace_summary(payload), args)


def _cmd_mural_find(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"query": args.query}
    if getattr(args, "workspace", None):
        payload["workspace"] = args.workspace
    if getattr(args, "min_score", None) is not None:
        payload["min_score"] = args.min_score
    if getattr(args, "limit", None) is not None:
        payload["limit"] = args.limit
    return _pkg()._emit_record(_op_mural_find(payload), args)


def _cmd_mural_repair_tag_drift(args: argparse.Namespace) -> int:
    return _pkg()._emit_record(_op_repair_tag_drift({"mural": args.mural}), args)


def _cmd_mural_lineage_lookup(args: argparse.Namespace) -> int:
    payload: dict[str, Any] = {"mural_id": args.mural_id}
    if getattr(args, "run_id", None):
        payload["run_id"] = args.run_id
    if getattr(args, "method", None) is not None:
        payload["method"] = args.method
    if getattr(args, "section", None):
        payload["section"] = args.section
    return _pkg()._emit_record(_op_mural_lineage_lookup(payload), args)


def _validate_voting_session_id(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise MuralValidationError("voting session id must be a non-empty string")
    return value.strip()


def _voting_session_path(mural_id: str, session_id: str | None = None) -> str:
    if session_id is None:
        return f"/murals/{mural_id}/voting-sessions"
    return f"/murals/{mural_id}/voting-sessions/{session_id}"


def _voting_session_create(mural_id: str, body: dict[str, Any]) -> dict[str, Any]:
    return _pkg()._authenticated_request(
        "POST", _voting_session_path(mural_id), json_body=body
    )


def _voting_session_get(mural_id: str, session_id: str) -> dict[str, Any]:
    return _pkg()._authenticated_request(
        "GET", _voting_session_path(mural_id, session_id)
    )


def _voting_session_list(
    mural_id: str, *, limit: int | None = None, page_size: int | None = None
) -> Any:
    return _pkg()._paginate(
        "GET",
        _voting_session_path(mural_id),
        params=None,
        limit=limit,
        page_size=page_size,
    )


def _voting_session_set_status(
    mural_id: str, session_id: str, status: str
) -> dict[str, Any]:
    return _pkg()._authenticated_request(
        "PATCH",
        _voting_session_path(mural_id, session_id),
        json_body={"status": status},
    )


def _voting_session_delete(mural_id: str, session_id: str) -> dict[str, Any]:
    return _pkg()._authenticated_request(
        "DELETE", _voting_session_path(mural_id, session_id)
    )


def _voting_results(mural_id: str, session_id: str) -> dict[str, Any]:
    return _pkg()._authenticated_request(
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
    return _pkg()._emit_record(record, args)


def _cmd_voting_session_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_get(mural_id, session_id)
    return _pkg()._emit_record(record, args)


def _cmd_voting_session_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = list(_voting_session_list(mural_id, **_list_kwargs(args)))
    return _emit_records(records, args)


def _cmd_voting_session_open(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_set_status(mural_id, session_id, "active")
    return _pkg()._emit_record(record, args)


def _cmd_voting_session_close(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_set_status(mural_id, session_id, "closed")
    return _pkg()._emit_record(record, args)


def _cmd_voting_session_delete(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_session_delete(mural_id, session_id)
    return _pkg()._emit_record(record, args)


def _cmd_voting_results(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    session_id = _validate_voting_session_id(args.session)
    record = _voting_results(mural_id, session_id)
    return _pkg()._emit_record(record, args)


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
    return _pkg()._emit_record(result, args)


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


def _op_voting_session_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    body = arguments.get("body")
    if not isinstance(body, dict) or not body:
        raise MCPInvalidParamsError("body is required and must be a JSON object")
    return _voting_session_create(mural_id, body)


def _op_voting_session_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_get(mural_id, session_id)


def _op_voting_session_list(arguments: dict[str, Any]) -> Any:
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


def _op_voting_session_open(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_set_status(mural_id, session_id, "active")


def _op_voting_session_close(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_set_status(mural_id, session_id, "closed")


def _op_voting_session_delete(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_session_delete(mural_id, session_id)


def _op_voting_results(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    session_id = _validate_voting_session_id(arguments.get("session"))
    return _voting_results(mural_id, session_id)


def _op_voting_poll(arguments: dict[str, Any]) -> Any:
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


def _op_voting_run(arguments: dict[str, Any]) -> Any:
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


def _op_workspace_search(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    query = arguments.get("query")
    if not isinstance(query, str) or not query.strip():
        raise MCPInvalidParamsError("query is required and must be a non-empty string")
    limit = arguments.get("limit")
    page_size = arguments.get("page_size")
    return list(
        _pkg()._paginate(
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
    records = _pkg()._paginate(
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
    return _pkg()._emit_record(record, args)


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


def _op_workspace_list(arguments: dict[str, Any]) -> Any:
    kwargs = _list_kwargs(_ns_for_list(arguments))
    return list(_pkg()._paginate("GET", "/workspaces", **kwargs))


def _op_workspace_get(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return _pkg()._authenticated_request("GET", f"/workspaces/{workspace_id}")


def _op_room_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _pkg()._paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _op_room_get(arguments: dict[str, Any]) -> Any:
    return _pkg()._authenticated_request("GET", f"/rooms/{arguments['room']}")


def _op_room_create(arguments: dict[str, Any]) -> Any:
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
    return _pkg()._authenticated_request("POST", "/rooms", json_body=payload)


def _op_mural_list(arguments: dict[str, Any]) -> Any:
    workspace_id = _resolve_workspace_id(arguments.get("workspace"))
    return list(
        _pkg()._paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _op_mural_create(arguments: dict[str, Any]) -> Any:
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
    return _pkg()._authenticated_request("POST", "/murals", json_body=payload)


def _op_mural_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _pkg()._authenticated_request("GET", f"/murals/{mural_id}")


def _op_widget_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    params: dict[str, Any] = {}
    if arguments.get("type"):
        params["type"] = arguments["type"]
    if arguments.get("parent_id"):
        params["parentId"] = arguments["parent_id"]
    return list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _op_widget_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _pkg()._authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )


def _op_widget_update(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = arguments["body"]
    if not isinstance(body, dict):
        raise MuralValidationError("body must be a JSON object")
    if arguments.get("require_author_tag") and not arguments.get("force_human"):
        _assert_widget_has_author_tag(mural_id, arguments["widget"])
    return _patch_widget_or_disambiguate_404(mural_id, arguments["widget"], body)


def _op_widget_delete(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    if arguments.get("require_author_tag") and not arguments.get("force_human"):
        _assert_widget_has_author_tag(mural_id, arguments["widget"])
    _pkg()._authenticated_request(
        "DELETE", f"/murals/{mural_id}/widgets/{arguments['widget']}"
    )
    return {"ok": True, "deleted": arguments["widget"]}


def _op_widget_create_sticky_note(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_sticky_note_body(_ns_for_widget_body(arguments))
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/sticky-note", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _op_widget_create_textbox(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_textbox_body(_ns_for_widget_body(arguments))
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/textbox", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _op_widget_create_shape(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_shape_body(_ns_for_widget_body(arguments))
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/shape", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _op_widget_create_arrow(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_arrow_body(_ns_for_widget_body(arguments))
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/arrow", json_body=body
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _op_widget_create_image(arguments: dict[str, Any]) -> Any:
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
    asset = _pkg()._create_asset_url(mural_id, suffix)
    _pkg()._upload_to_sas(
        url=asset["url"],
        headers=asset.get("headers") or {},
        body=body_bytes,
        content_type=_IMAGE_CONTENT_TYPES[suffix],
    )
    record = _pkg()._authenticated_request(
        "POST",
        f"/murals/{mural_id}/widgets/image",
        json_body=_build_image_body(
            asset_name=asset["name"], args=_ns_for_widget_body(arguments)
        ),
    )
    _maybe_apply_author_tag(mural_id, record, skip=bool(arguments.get("no_author_tag")))
    return record


def _op_tag_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/tags",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )


def _op_tag_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _create_tag(mural_id, arguments["text"], arguments.get("color"))


def _op_tag_apply(arguments: dict[str, Any]) -> Any:
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
        mapping = _pkg()._ensure_tag_manifest(mural_id, [manifest_entry])
        tag_id = mapping[text]
    return _pkg()._merge_tags(mural_id, widget_id, additions=[tag_id])


def _op_tag_remove(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    widget_id = arguments["widget"]
    tag_id = arguments["tag"]
    if _is_reserved_tag_id(mural_id, tag_id) and not arguments.get("force_reserved"):
        raise MuralValidationError(
            f"refusing to remove reserved tag {tag_id!r}; "
            "pass 'force_reserved' to override"
        )
    return _pkg()._merge_tags(mural_id, widget_id, removals=[tag_id])


def _op_area_list(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _list_areas_with_widget_fallback(
        mural_id, **_list_kwargs(_ns_for_list(arguments))
    )


def _op_area_get(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _get_area_with_widget_fallback(mural_id, arguments["area"])


def _op_area_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    body = _build_area_body(_ns_for_widget_body(arguments))
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/areas", json_body=body
    )
    if isinstance(record, dict):
        area_id = record.get("id")
        if isinstance(area_id, str):
            _area_cache[area_id] = record
    return record


def _op_area_probe(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _area_probe(mural_id, arguments["area"])


def _op_widget_get_with_context(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    return _get_widget_with_context(mural_id, arguments["widget"])


def _op_widget_list_with_context(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural"])
    list_kwargs = _list_kwargs(_ns_for_list(arguments))
    return _list_widgets_with_context(
        mural_id,
        widget_type=arguments.get("type"),
        parent_id=arguments.get("parent_id"),
        limit=list_kwargs["limit"],
        page_size=list_kwargs["page_size"],
    )


def _op_auth_status(arguments: dict[str, Any]) -> Any:
    path = _resolve_token_store_path()
    profile_arg = arguments.get("profile") if isinstance(arguments, dict) else None
    cred_profile = profile_arg or os.environ.get(ENV_PROFILE) or DEFAULT_PROFILE_NAME
    cred_path = _resolve_credential_file(cred_profile, os.environ)
    cred_keys = {
        "credential_file": str(cred_path),
        "credential_file_exists": cred_path.exists(),
    }
    store = _pkg()._load_token_store(path)
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


def _op_spatial_widgets_in_shape(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    shape = _pkg()._authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{arguments['shape_id']}"
    )
    if not isinstance(shape, dict):
        raise MuralAPIError(
            0, "WIDGET_INVALID", "shape widget response is not an object"
        )
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    rotation_aware = bool(arguments.get("rotation_aware")) or _pkg()._ROTATION_ENABLED
    return _pkg().widgets_in_shape(
        widgets,
        shape,
        mode=arguments.get("mode", "center"),
        rotation_aware=rotation_aware,
    )


def _op_spatial_widgets_in_region(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    region = safe_rect(
        float(arguments["x"]),
        float(arguments["y"]),
        float(arguments["w"]),
        float(arguments["h"]),
    )
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    return _pkg().widgets_in_region(
        widgets, region, mode=arguments.get("mode", "center")
    )


def _op_spatial_pairwise_overlaps(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    rotation_aware = bool(arguments.get("rotation_aware")) or _pkg()._ROTATION_ENABLED
    pairs = _pkg().pairwise_overlaps(
        widgets,
        predicate=arguments.get("predicate", "intersects"),
        rotation_aware=rotation_aware,
    )
    return [{"a": a, "b": b} for a, b in pairs]


def _op_spatial_cluster(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(_ns_for_list(arguments)),
        )
    )
    clusters = _pkg().cluster_widgets(
        widgets,
        eps_px=float(arguments.get("eps_px", 120.0)),
        min_samples=int(arguments.get("min_samples", 2)),
    )
    return [{"members": members} for members in clusters]


def _op_spatial_sort_along_axis(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    widgets = list(
        _pkg()._paginate(
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
    return _pkg().sort_along_axis(
        widgets,
        axis=str(arguments.get("axis", "x")),
        origin=origin,
    )


def _op_spatial_arrow_graph(arguments: dict[str, Any]) -> Any:
    _ensure_geos_ready()
    mural_id = _validate_mural_id(arguments["mural_id"])
    all_widgets = list(
        _pkg()._paginate(
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


def _op_widget_create_bulk(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    widgets = _build_bulk_widgets_payload(arguments.get("widgets"))
    result = _pkg()._bulk_create_widgets(
        mural_id, widgets, atomic=bool(arguments.get("atomic"))
    )
    _bulk_apply_author_tag(mural_id, result, skip=bool(arguments.get("no_author_tag")))
    return result


def _op_widget_update_bulk(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    updates = _build_bulk_widget_updates_payload(arguments.get("updates"))
    return _pkg()._bulk_update_widgets(
        mural_id,
        updates,
        atomic=bool(arguments.get("atomic")),
        require_author_tag=bool(arguments.get("require_author_tag")),
        force_human=bool(arguments.get("force_human")),
    )


def _op_mural_duplicate(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    new_id = _pkg()._duplicate_mural(mural_id)
    return {"new_mural_id": new_id, "source_mural_id": mural_id}


def _op_clone_with_tags(arguments: dict[str, Any]) -> Any:
    source_id = _validate_mural_id(arguments.get("mural"))
    source_manifest = _read_tag_manifest(source_id)
    new_id = _pkg()._duplicate_mural(source_id)
    tag_map = (
        _pkg()._ensure_tag_manifest(new_id, source_manifest) if source_manifest else {}
    )
    return {
        "source_mural_id": source_id,
        "new_mural_id": new_id,
        "tag_count": len(tag_map),
        "tag_map": tag_map,
        "warnings": ["widget ids are not preserved across mural duplication"],
    }


def _op_template_instantiate(arguments: dict[str, Any]) -> Any:
    template_id = arguments.get("template")
    if not isinstance(template_id, str) or not template_id.strip():
        raise MCPInvalidParamsError("template is required")
    body = _template_target_body(
        arguments.get("workspace"),
        arguments.get("room"),
        arguments.get("name"),
    )
    return _pkg()._authenticated_request(
        "POST", f"/templates/{template_id.strip()}/instantiate", json_body=body
    )


def _op_template_create(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    body = _template_target_body(
        arguments.get("workspace"),
        arguments.get("room"),
        arguments.get("name"),
    )
    return _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/template", json_body=body
    )


def _op_template_list(arguments: dict[str, Any]) -> Any:
    workspace = arguments.get("workspace")
    if workspace is not None and (
        not isinstance(workspace, str) or not workspace.strip()
    ):
        raise MCPInvalidParamsError("workspace must be a non-empty string when set")
    return {"templates": [dict(entry) for entry in _state.template_registry()]}


def _op_mural_poll(arguments: dict[str, Any]) -> Any:
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


def _op_mural_archive(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    return _set_mural_status(mural_id, "archived")


def _op_mural_unarchive(arguments: dict[str, Any]) -> Any:
    mural_id = _validate_mural_id(arguments.get("mural"))
    return _set_mural_status(mural_id, "active")


def _op_layout(layout: str, arguments: dict[str, Any]) -> Any:
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
    bulk = _pkg()._bulk_create_widgets(mural_id, plan["widgets"])
    plan["widgets"] = bulk["succeeded"]
    plan["skipped"] = bulk["skipped"]
    plan.setdefault("warnings", []).extend(bulk["warnings"])
    return plan


def _op_layout_grid(arguments: dict[str, Any]) -> Any:
    return _op_layout("grid", arguments)


def _op_layout_cluster(arguments: dict[str, Any]) -> Any:
    return _op_layout("cluster", arguments)


def _op_layout_column(arguments: dict[str, Any]) -> Any:
    return _op_layout("column", arguments)


def _op_layout_row(arguments: dict[str, Any]) -> Any:
    return _op_layout("row", arguments)


# --- Tool schemas + registry ---------------------------------------------


def _idempotency_get(name: str, key: str) -> dict[str, Any] | None:
    cache = _state.idempotency_cache()
    payload = cache.get((name, key))
    if payload is None:
        return None
    cache.move_to_end((name, key))
    return payload


def _idempotency_put(name: str, key: str, payload: dict[str, Any]) -> None:
    cache = _state.idempotency_cache()
    cache[(name, key)] = payload
    cache.move_to_end((name, key))
    while len(cache) > _state.idempotency_max():
        cache.popitem(last=False)
