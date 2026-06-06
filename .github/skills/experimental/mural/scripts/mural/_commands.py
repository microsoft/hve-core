#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Resource and bulk command tier for the Mural CLI.

Carved from ``mural/__init__`` (Step 3.2 of the __init__ modularization plan).
Holds the resource ``_cmd_*`` handlers (workspace, room, mural, widget, tag,
area, spatial, layout), the bulk create/update/diff/delete operations, mural
duplication and tag-clone, template instantiation, and the poll/archive command
surface.

Helpers that remain in the package ``__init__`` (area-chain and tag helpers,
``_resolve_widget_id``, ``_list_kwargs``, and friends) are imported from the
package and bind when ``__init__`` first imports this submodule, after those
helpers are defined.

Intra-package calls to facade-patched symbols (``_authenticated_request``,
``_paginate``, ``_emit_record``, ``_merge_tags``, ``_ensure_tag_manifest``,
``_bulk_create_widgets``, ``_bulk_update_widgets``, ``_apply_widget_diff``,
``_duplicate_mural``, the spatial geometry entrypoints, and friends) route
through :func:`_pkg` so ``monkeypatch.setattr(mural, <symbol>, ...)`` keeps
intercepting without test edits.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import pathlib
import sys
import time
from typing import Any, Callable

from . import (  # noqa: E402 - package siblings defined before this import runs
    _area_probe,
    _assert_widget_has_author_tag,
    _create_tag,
    _ensure_geos_ready,
    _ensure_reserved_author_tag,
    _get_area_with_widget_fallback,
    _is_reserved_tag_id,
    _list_areas_with_widget_fallback,
    _list_kwargs,
    _maybe_apply_author_tag,
    _resolve_widget_id,
    _walk_area_chain,
)
from ._constants import (
    EXIT_FAILURE,
    EXIT_SUCCESS,
    EXIT_USAGE,
    MAX_BULK_WIDGETS,
    POLL_MAX_INTERVAL_S,
    POLL_MAX_TIMEOUT_S,
)
from ._exceptions import (
    MuralAPIError,
    MuralBulkAtomicAbort,
    MuralError,
    MuralValidationError,
)
from ._geometry import (
    arrow_graph_summary,
    build_arrow_graph,
    safe_rect,
)
from ._layout import (
    _LAYOUT_HASH_PREFIX,
)
from ._output import (
    _coalesce_widget_text,
    _emit_records,
)
from ._validation import (
    _IMAGE_CONTENT_TYPES,
    _build_area_body,
    _build_arrow_body,
    _build_image_body,
    _build_shape_body,
    _build_sticky_note_body,
    _build_textbox_body,
    _parse_json_arg,
    _resolve_workspace_id,
    _validate_hyperlink,
    _validate_mural_id,
    _validate_tag_text,
)


def _pkg() -> Any:
    """Return the live ``mural`` package module for facade-routed patching."""
    return sys.modules[__package__]


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
        "widgets": _parse_json_arg(
            _pkg()._load_payload_file(args.widgets), "--widgets"
        ),
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
    return _pkg()._emit_record(
        _pkg()._op_layout("grid", _layout_cli_arguments(args)), args
    )


def _cmd_layout_cluster(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _pkg()._emit_record(
        _pkg()._op_layout("cluster", _layout_cli_arguments(args)), args
    )


def _cmd_layout_column(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _pkg()._emit_record(
        _pkg()._op_layout("column", _layout_cli_arguments(args)), args
    )


def _cmd_layout_row(args: argparse.Namespace) -> int:
    _ensure_geos_ready()
    return _pkg()._emit_record(
        _pkg()._op_layout("row", _layout_cli_arguments(args)), args
    )


def _cmd_spatial_widgets_in_shape(args: argparse.Namespace) -> int:
    """Return widgets contained by ``--shape-id`` per ``--mode`` semantics.

    Fetches the shape widget directly, then drains all mural widgets via
    pagination so spatial filtering is applied across the full canvas.
    ``--rotation-aware`` forces rotation-aware AABB expansion of the shape;
    when absent the env flag ``MURAL_SPATIAL_ROTATION_ENABLED`` (mirrored
    by ``_pkg()._ROTATION_ENABLED``) governs the default.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    shape = _pkg()._authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{args.shape_id}"
    )
    if not isinstance(shape, dict):
        raise MuralAPIError(
            0, "WIDGET_INVALID", "shape widget response is not an object"
        )
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    rotation_aware = bool(args.rotation_aware) or _pkg()._ROTATION_ENABLED
    matched = _pkg().widgets_in_shape(
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
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    matched = _pkg().widgets_in_region(widgets, region, mode=args.mode)
    return _emit_records(matched, args)


def _cmd_spatial_pairwise_overlaps(args: argparse.Namespace) -> int:
    """Return overlapping widget id pairs across the mural canvas.

    Drains every widget on the mural via pagination, builds the STR R-tree
    inside ``pairwise_overlaps``, and emits the deterministic pair list.
    ``--rotation-aware`` forces rotation-aware AABB expansion when set;
    otherwise the env flag ``MURAL_SPATIAL_ROTATION_ENABLED`` (mirrored by
    ``_pkg()._ROTATION_ENABLED``) governs the default.
    """
    _ensure_geos_ready()
    mural_id = _validate_mural_id(args.mural_id)
    widgets = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    rotation_aware = bool(args.rotation_aware) or _pkg()._ROTATION_ENABLED
    pairs = _pkg().pairwise_overlaps(
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
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            **_list_kwargs(args),
        )
    )
    clusters = _pkg().cluster_widgets(
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
        _pkg()._paginate(
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
    ordered = _pkg().sort_along_axis(widgets, axis=args.axis, origin=origin)
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
        _pkg()._paginate(
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
    records = list(_pkg()._paginate("GET", "/workspaces", **_list_kwargs(args)))
    return _emit_records(records, args)


# Single-resource GET handlers rely on _emit_record's defensive {"value"} unwrap.
def _cmd_workspace_get(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    record = _pkg()._authenticated_request("GET", f"/workspaces/{workspace_id}")
    return _pkg()._emit_record(record, args)


def _cmd_room_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _pkg()._paginate(
            "GET",
            f"/workspaces/{workspace_id}/rooms",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_room_get(args: argparse.Namespace) -> int:
    record = _pkg()._authenticated_request("GET", f"/rooms/{args.room}")
    return _pkg()._emit_record(record, args)


def _cmd_room_create(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    payload: dict[str, Any] = {
        "workspaceId": workspace_id,
        "name": args.name,
        "type": args.type,
    }
    if getattr(args, "description", None):
        payload["description"] = args.description
    record = _pkg()._authenticated_request("POST", "/rooms", json_body=payload)
    return _pkg()._emit_record(record, args)


def _cmd_mural_list(args: argparse.Namespace) -> int:
    workspace_id = _resolve_workspace_id(getattr(args, "workspace", None))
    records = list(
        _pkg()._paginate(
            "GET",
            f"/workspaces/{workspace_id}/murals",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_mural_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _pkg()._authenticated_request("GET", f"/murals/{mural_id}")
    return _pkg()._emit_record(record, args)


def _cmd_mural_create(args: argparse.Namespace) -> int:
    try:
        room_id = int(str(args.room).strip())
    except (TypeError, ValueError) as exc:
        raise SystemExit(f"error: --room must be an integer room id ({exc})")
    payload: dict[str, Any] = {"roomId": room_id, "title": args.title}
    record = _pkg()._authenticated_request("POST", "/murals", json_body=payload)
    return _pkg()._emit_record(record, args)


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
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_widget_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _pkg()._authenticated_request(
        "GET", f"/murals/{mural_id}/widgets/{args.widget}"
    )
    return _pkg()._emit_record(record, args)


def _cmd_widget_delete(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    if getattr(args, "require_author_tag", False) and not getattr(
        args, "force_human", False
    ):
        _assert_widget_has_author_tag(mural_id, args.widget)
    _pkg()._authenticated_request("DELETE", f"/murals/{mural_id}/widgets/{args.widget}")
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
            return _pkg()._authenticated_request("PATCH", typed_path, json_body=body)
        except MuralAPIError as exc:
            if exc.status != 404:
                raise
            # Widget may have a different type than the caller supplied; fall
            # through to GET-based discovery below.
    last_exc: MuralAPIError | None = None
    if typed_path is None:
        try:
            return _pkg()._authenticated_request(
                "PATCH",
                f"/murals/{mural_id}/widgets/{widget_id}",
                json_body=body,
            )
        except MuralAPIError as exc:
            if exc.status != 404:
                raise
            last_exc = exc
    try:
        record = _pkg()._authenticated_request(
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
    return _pkg()._authenticated_request("PATCH", discovered_path, json_body=body)


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
        body = _parse_json_arg(_pkg()._load_payload_file(file_arg), "--body-file")
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
        if not math.isfinite(f):
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
                + f"(width={width}, height={height})"
            ),
        )
    return (
        CONTAINMENT_VERDICT_GEOMETRY_MISMATCH,
        (
            f"widget (x={x}, y={y}) is outside parent area "
            + f"(width={width}, height={height}); parentId is correct but "
            + "the widget will render off-area — see geometry rules in "
            + "mural-seeding-patterns.instructions.md"
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
        record = _pkg()._authenticated_request(
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
            _pkg()._emit_record(record, args)
            return EXIT_FAILURE
    return _pkg()._emit_record(record, args)


def _create_widget(
    mural_id: str,
    widget_type: str,
    body: dict[str, Any],
    args: argparse.Namespace,
) -> int:
    record = _pkg()._authenticated_request(
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
                _pkg()._emit_record(record, args)
                return EXIT_FAILURE
    return _pkg()._emit_record(record, args)


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
        json_body=_build_image_body(asset_name=asset["name"], args=args),
    )
    _maybe_apply_author_tag(
        mural_id, record, skip=bool(getattr(args, "no_author_tag", False))
    )
    return _pkg()._emit_record(record, args)


# --- Tag, area, and widget-context CLI handlers ---------------------------


def _cmd_tag_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = list(
        _pkg()._paginate(
            "GET",
            f"/murals/{mural_id}/tags",
            **_list_kwargs(args),
        )
    )
    return _emit_records(records, args)


def _cmd_tag_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _create_tag(mural_id, args.text, getattr(args, "color", None))
    return _pkg()._emit_record(record, args)


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
        mapping = _pkg()._ensure_tag_manifest(mural_id, manifest)
        tag_id = mapping[text]
    record = _pkg()._merge_tags(mural_id, args.widget, additions=[tag_id])
    return _pkg()._emit_record(record, args)


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
    record = _pkg()._merge_tags(mural_id, args.widget, removals=[args.tag])
    return _pkg()._emit_record(record, args)


def _cmd_area_list(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    records = _list_areas_with_widget_fallback(mural_id, **_list_kwargs(args))
    return _emit_records(records, args)


def _cmd_area_get(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _get_area_with_widget_fallback(mural_id, args.area)
    return _pkg()._emit_record(record, args)


def _cmd_area_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _build_area_body(args)
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/areas", json_body=body
    )
    if isinstance(record, dict):
        area_id = record.get("id")
        if isinstance(area_id, str):
            _pkg()._area_cache[area_id] = record
    return _pkg()._emit_record(record, args)


def _cmd_area_probe(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    verdict = _area_probe(mural_id, args.area)
    return _pkg()._emit_record(verdict, args)


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
                seen_areas[area_id] = _pkg()._existing_layout_hashes(mural_id, area_id)
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
            response = _pkg()._authenticated_request(
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
    raw = _parse_json_arg(_pkg()._load_payload_file(args.file), "--file")
    widgets = _build_bulk_widgets_payload(raw)
    result = _pkg()._bulk_create_widgets(
        mural_id, widgets, atomic=bool(getattr(args, "atomic", False))
    )
    _bulk_apply_author_tag(
        mural_id, result, skip=bool(getattr(args, "no_author_tag", False))
    )
    return _pkg()._emit_record(result, args)


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
            _pkg()._merge_tags(mural_id, widget_id, additions=[tag_id])
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
    raw = _parse_json_arg(_pkg()._load_payload_file(args.file), "--file")
    updates = _build_bulk_widget_updates_payload(raw)
    result = _pkg()._bulk_update_widgets(
        mural_id,
        updates,
        atomic=bool(getattr(args, "atomic", False)),
        require_author_tag=bool(getattr(args, "require_author_tag", False)),
        force_human=bool(getattr(args, "force_human", False)),
    )
    return _pkg()._emit_record(result, args)


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
            _pkg()._authenticated_request("DELETE", f"/murals/{mural_id}/widgets/{wid}")
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
        _pkg()._bulk_create_widgets(mural_id, create_payload, atomic=atomic)
        if create_payload
        else dict(empty_create)
    )
    update_result = (
        _pkg()._bulk_update_widgets(mural_id, update_payload, atomic=atomic)
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
    raw = _parse_json_arg(_pkg()._load_payload_file(args.file), "--file")
    if isinstance(raw, dict) and "widgets" in raw:
        baseline = raw["widgets"]
    else:
        baseline = raw
    if not isinstance(baseline, list):
        raise MuralValidationError(
            "--file must contain a JSON array of widgets or "
            "an object with a 'widgets' array"
        )
    live = list(_pkg()._paginate("GET", f"/murals/{mural_id}/widgets"))
    result = _diff_widget_lists(baseline, live)
    if getattr(args, "apply", False):
        apply_result = _pkg()._apply_widget_diff(
            mural_id,
            baseline,
            result,
            atomic=bool(getattr(args, "atomic", False)),
        )
        result = {**result, "applied": True, **apply_result}
    return _pkg()._emit_record(result, args)


def _duplicate_mural(source_mural_id: str) -> str:
    """POST ``/murals/{id}/duplicate`` and return the new mural id.

    Raises :class:`MuralAPIError` when the response does not include an
    ``id`` field; the new mural identifier is required for downstream
    workflows such as :func:`_cmd_clone_with_tags`.
    """
    response = _pkg()._authenticated_request(
        "POST", f"/murals/{source_mural_id}/duplicate"
    )
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
    new_id = _pkg()._duplicate_mural(mural_id)
    return _pkg()._emit_record(
        {"new_mural_id": new_id, "source_mural_id": mural_id}, args
    )


def _read_tag_manifest(mural_id: str) -> list[dict[str, Any]]:
    """Return ``[{text, color?}]`` tag entries from an existing mural."""
    manifest: list[dict[str, Any]] = []
    for tag in _pkg()._paginate("GET", f"/murals/{mural_id}/tags"):
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
    new_id = _pkg()._duplicate_mural(source_id)
    tag_map = (
        _pkg()._ensure_tag_manifest(new_id, source_manifest) if source_manifest else {}
    )
    return _pkg()._emit_record(
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
    record = _pkg()._authenticated_request(
        "POST", f"/templates/{template_id}/instantiate", json_body=body
    )
    return _pkg()._emit_record(record, args)


def _cmd_template_create(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    body = _template_target_body(
        getattr(args, "workspace", None),
        getattr(args, "room", None),
        getattr(args, "name", None),
    )
    record = _pkg()._authenticated_request(
        "POST", f"/murals/{mural_id}/template", json_body=body
    )
    return _pkg()._emit_record(record, args)


def _cmd_template_list(args: argparse.Namespace) -> int:
    return _pkg()._emit_record(
        _pkg()._op_template_list({"workspace": getattr(args, "workspace", None)}),
        args,
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
        last_record = _pkg()._authenticated_request("GET", f"/murals/{mural_id}")
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
    return _pkg()._emit_record(result, args)


def _set_mural_status(mural_id: str, status: str) -> Any:
    return _pkg()._authenticated_request(
        "PATCH", f"/murals/{mural_id}", json_body={"status": status}
    )


def _cmd_mural_archive(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _set_mural_status(mural_id, "archived")
    return _pkg()._emit_record(record, args)


def _cmd_mural_unarchive(args: argparse.Namespace) -> int:
    mural_id = _validate_mural_id(args.mural)
    record = _set_mural_status(mural_id, "active")
    return _pkg()._emit_record(record, args)


# --- Voting sessions ---------------------------------------------------------
