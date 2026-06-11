#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Layout engines and session-manifest helpers for the Mural package.

Carved from ``mural.__init__`` per the modularization plan. Helpers that
touch package-owned state or call package-owned functions resolve those
dependencies via deferred ``from . import`` lookups so
``monkeypatch.setattr(mural, ...)`` continues to affect callers through the
re-exported package surface.
"""

from __future__ import annotations

import hashlib
import json
import math
from typing import Any, Callable, Sequence

# Layout tuning constants. Defaults chosen to keep auto-laid stickies
# legible at standard zoom and to leave a small visual gutter.
_LAYOUT_DEFAULT_CELL_WIDTH = 168.0
_LAYOUT_DEFAULT_CELL_HEIGHT = 168.0
_LAYOUT_DEFAULT_GUTTER = 16.0
_LAYOUT_DEFAULT_ORIGIN = (0.0, 0.0)
_LAYOUT_HASH_PREFIX = "auto-layout-hash:"


def _layout_canonical_widget(widget: dict[str, Any]) -> dict[str, Any]:
    """Return the subset of ``widget`` that participates in layout-hash equality.

    Geometry-only fields (``x``, ``y``, ``width``, ``height``) are excluded so
    that re-running a layout on the same logical inputs produces a stable hash
    even when prior runs assigned different coordinates.
    """
    if not isinstance(widget, dict):
        return {}
    keep = {
        k: v for k, v in widget.items() if k not in {"x", "y", "width", "height", "id"}
    }
    return keep


def _layout_hash(
    *,
    area_id: str,
    layout: str,
    widgets: list[dict[str, Any]],
    params: dict[str, Any] | None = None,
) -> str:
    """Return a stable 12-char hex digest for a layout invocation.

    The hash is computed over canonical-JSON of the (ordered) logical
    widget contents plus ``area_id``, ``layout`` name, and ``params``. It
    powers ``auto-layout-hash:<digest>`` reserved tags so repeated layout
    runs are deduped client-side.
    """
    payload = {
        "area_id": area_id,
        "layout": layout,
        "params": params or {},
        "widgets": [_layout_canonical_widget(w) for w in widgets],
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:12]


def _layout_envelope(widgets: list[dict[str, Any]]) -> dict[str, float]:
    """Compute the bounding ``{x, y, width, height}`` for placed ``widgets``.

    Widgets without geometry contribute ``(0, 0, 0, 0)``. Returns zeros for
    an empty list. The envelope is exclusive of any area padding; callers
    overlay it against the area capacity to detect overflow.
    """
    if not widgets:
        return {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0}
    xs: list[float] = []
    ys: list[float] = []
    rights: list[float] = []
    bottoms: list[float] = []
    for widget in widgets:
        x = float(widget.get("x", 0.0) or 0.0)
        y = float(widget.get("y", 0.0) or 0.0)
        width = float(widget.get("width", 0.0) or 0.0)
        height = float(widget.get("height", 0.0) or 0.0)
        xs.append(x)
        ys.append(y)
        rights.append(x + width)
        bottoms.append(y + height)
    min_x = min(xs)
    min_y = min(ys)
    return {
        "x": min_x,
        "y": min_y,
        "width": max(rights) - min_x,
        "height": max(bottoms) - min_y,
    }


def _area_capacity(area: dict[str, Any]) -> dict[str, float]:
    """Return ``{width, height}`` capacity for an area record.

    Looks first at ``width``/``height`` and falls back to
    ``bounds.width``/``bounds.height``. Missing dimensions yield ``inf``
    so the overflow check degrades to a no-op rather than spuriously
    refusing layouts on partial area metadata.
    """
    bounds = area.get("bounds") if isinstance(area, dict) else None
    width = area.get("width") if isinstance(area, dict) else None
    height = area.get("height") if isinstance(area, dict) else None
    if width is None and isinstance(bounds, dict):
        width = bounds.get("width")
    if height is None and isinstance(bounds, dict):
        height = bounds.get("height")
    return {
        "width": float(width) if isinstance(width, (int, float)) else float("inf"),
        "height": float(height) if isinstance(height, (int, float)) else float("inf"),
    }


def _area_overflow(
    *,
    area: dict[str, Any],
    envelope: dict[str, float],
) -> tuple[bool, dict[str, Any]]:
    """Return ``(overflow, capacity)`` comparing the envelope to the area bounds."""
    capacity = _area_capacity(area)
    overflow = (
        envelope["width"] > capacity["width"] or envelope["height"] > capacity["height"]
    )
    return overflow, capacity


def _layout_grid(
    widgets: list[dict[str, Any]],
    *,
    columns: int,
    cell_width: float = _LAYOUT_DEFAULT_CELL_WIDTH,
    cell_height: float = _LAYOUT_DEFAULT_CELL_HEIGHT,
    gutter: float = _LAYOUT_DEFAULT_GUTTER,
    origin: tuple[float, float] = _LAYOUT_DEFAULT_ORIGIN,
) -> list[dict[str, Any]]:
    """Place ``widgets`` in a row-major ``columns``-wide grid."""
    if columns <= 0:
        from . import MuralValidationError

        raise MuralValidationError("columns must be >= 1")
    placed: list[dict[str, Any]] = []
    origin_x, origin_y = origin
    for idx, widget in enumerate(widgets):
        col = idx % columns
        row = idx // columns
        new = dict(widget)
        new["x"] = origin_x + col * (cell_width + gutter)
        new["y"] = origin_y + row * (cell_height + gutter)
        new.setdefault("width", cell_width)
        new.setdefault("height", cell_height)
        placed.append(new)
    return placed


def _layout_cluster(
    widgets: list[dict[str, Any]],
    *,
    cell_width: float = _LAYOUT_DEFAULT_CELL_WIDTH,
    cell_height: float = _LAYOUT_DEFAULT_CELL_HEIGHT,
    gutter: float = _LAYOUT_DEFAULT_GUTTER,
    origin: tuple[float, float] = _LAYOUT_DEFAULT_ORIGIN,
) -> list[dict[str, Any]]:
    """Place ``widgets`` in a near-square cluster (ceil(sqrt(N)) columns)."""
    count = len(widgets)
    if count == 0:
        return []
    columns = max(1, int(math.ceil(math.sqrt(count))))
    return _layout_grid(
        widgets,
        columns=columns,
        cell_width=cell_width,
        cell_height=cell_height,
        gutter=gutter,
        origin=origin,
    )


def _layout_column(
    widgets: list[dict[str, Any]],
    *,
    cell_width: float = _LAYOUT_DEFAULT_CELL_WIDTH,
    cell_height: float = _LAYOUT_DEFAULT_CELL_HEIGHT,
    gutter: float = _LAYOUT_DEFAULT_GUTTER,
    origin: tuple[float, float] = _LAYOUT_DEFAULT_ORIGIN,
) -> list[dict[str, Any]]:
    """Stack ``widgets`` vertically in a single column."""
    return _layout_grid(
        widgets,
        columns=1,
        cell_width=cell_width,
        cell_height=cell_height,
        gutter=gutter,
        origin=origin,
    )


def _layout_row(
    widgets: list[dict[str, Any]],
    *,
    cell_width: float = _LAYOUT_DEFAULT_CELL_WIDTH,
    cell_height: float = _LAYOUT_DEFAULT_CELL_HEIGHT,
    gutter: float = _LAYOUT_DEFAULT_GUTTER,
    origin: tuple[float, float] = _LAYOUT_DEFAULT_ORIGIN,
) -> list[dict[str, Any]]:
    """Lay ``widgets`` out horizontally in a single row."""
    count = len(widgets)
    return _layout_grid(
        widgets,
        columns=max(1, count),
        cell_width=cell_width,
        cell_height=cell_height,
        gutter=gutter,
        origin=origin,
    )


_LAYOUT_FUNCS: dict[str, Callable[..., list[dict[str, Any]]]] = {
    "grid": _layout_grid,
    "cluster": _layout_cluster,
    "column": _layout_column,
    "row": _layout_row,
}


def _existing_layout_hashes(mural_id: str, area_id: str | None) -> set[str]:
    """Return ``auto-layout-hash:<digest>`` values already on widgets in ``area_id``.

    Used by ``mural_widget_create_bulk`` to skip widgets whose layout hash
    matches a prior run, so repeated invocations are idempotent client-side.
    Returns an empty set when ``area_id`` is ``None``.
    """
    if not area_id:
        return set()
    from . import _paginate, _widget_tag_ids

    digests: set[str] = set()
    tag_lookup: dict[str, str] = {}
    for tag in _paginate("GET", f"/murals/{mural_id}/tags"):
        if not isinstance(tag, dict):
            continue
        text = tag.get("text") or ""
        if isinstance(text, str) and text.startswith(_LAYOUT_HASH_PREFIX):
            tag_id = tag.get("id")
            if isinstance(tag_id, str):
                tag_lookup[tag_id] = text[len(_LAYOUT_HASH_PREFIX) :]
    if not tag_lookup:
        return set()
    for widget in _paginate("GET", f"/murals/{mural_id}/widgets"):
        if not isinstance(widget, dict):
            continue
        if widget.get("areaId") != area_id and widget.get("area_id") != area_id:
            continue
        for tag_id in _widget_tag_ids(widget):
            digest = tag_lookup.get(tag_id)
            if digest is not None:
                digests.add(digest)
    return digests


def _execute_layout(
    *,
    layout: str,
    mural_id: str,
    area_id: str,
    widgets: list[dict[str, Any]],
    params: dict[str, Any],
) -> dict[str, Any]:
    """Run a layout function, validate against area capacity, and tag results.

    Returns ``{computed_metadata, widgets, skipped, warnings}``. Refuses to
    coerce when the computed envelope overflows the area bounds — raises
    :class:`MuralAreaCapacityExceeded` so the caller surfaces the
    structured ``AREA_CAPACITY_EXCEEDED`` envelope.
    """
    from . import MuralAreaCapacityExceeded, MuralValidationError, _get_area

    func = _LAYOUT_FUNCS.get(layout)
    if func is None:
        raise MuralValidationError(f"unknown layout {layout!r}")
    placed = func(widgets, **params)
    area = _get_area(mural_id, area_id)
    envelope = _layout_envelope(placed)
    overflow, capacity = _area_overflow(area=area, envelope=envelope)
    if overflow:
        raise MuralAreaCapacityExceeded(
            area_id=area_id,
            area_capacity=capacity,
            computed_extent=envelope,
            suggestion=(
                "Reduce widget count, shrink cell dimensions, or place into "
                "a larger area before re-running this layout."
            ),
        )
    digest = _layout_hash(area_id=area_id, layout=layout, widgets=placed, params=params)
    layout_tag_text = f"{_LAYOUT_HASH_PREFIX}{digest}"
    for widget in placed:
        existing = list(widget.get("tags") or [])
        if layout_tag_text not in existing:
            existing.append(layout_tag_text)
        widget["tags"] = existing
        widget["areaId"] = area_id
    metadata = {
        "layout": layout,
        "area_id": area_id,
        "envelope": envelope,
        "capacity": capacity,
        "hash": digest,
        "count": len(placed),
    }
    return {
        "computed_metadata": metadata,
        "widgets": placed,
        "skipped": [],
        "warnings": [],
    }


# Process-local intended-tag manifest. Keyed by ``(mural_id, widget_id)`` so
# composite flows can re-assert intent after concurrent mutations from
# other clients drift the server-side tag set. Strictly best-effort: never
# blocks a primary mutation, never persisted to disk.
_SessionManifest: dict[tuple[str, str], set[str]] = {}


def _session_manifest_record(
    mural_id: str, widget_id: str, intended: Sequence[str]
) -> None:
    """Record the intended tag set for ``(mural_id, widget_id)``."""
    if not mural_id or not widget_id:
        return
    _SessionManifest[(mural_id, widget_id)] = {
        tag for tag in intended if isinstance(tag, str)
    }


def _repair_tag_drift(mural_id: str) -> list[dict[str, Any]]:
    """Re-assert intended tags for every manifest entry in ``mural_id``.

    Returns one ``{widget_id, repaired, warning}`` record per inspected
    widget. Drift detected on a widget triggers a single ``_merge_tags``
    call to restore the intended set; failures are recorded but do not
    raise so the caller can keep sweeping.
    """
    from . import (
        _TAG_MERGE_MAX_RETRIES,
        MuralAPIError,
        MuralError,
        _authenticated_request,
        _ensure_tag_manifest,
        _merge_tags,
        _widget_tag_ids,
    )

    repaired: list[dict[str, Any]] = []
    keys = [key for key in _SessionManifest if key[0] == mural_id]
    if not keys:
        return repaired
    tag_text_to_id = _ensure_tag_manifest(
        mural_id,
        [
            {"text": text}
            for text in sorted(
                {text for key in keys for text in _SessionManifest.get(key, set())}
            )
        ],
    )
    for mid, widget_id in keys:
        intended_text = _SessionManifest.get((mid, widget_id), set())
        intended_ids = {
            tag_text_to_id[text] for text in intended_text if text in tag_text_to_id
        }
        try:
            widget = _authenticated_request("GET", f"/murals/{mid}/widgets/{widget_id}")
        except MuralAPIError as exc:
            repaired.append(
                {"widget_id": widget_id, "repaired": False, "warning": str(exc)}
            )
            continue
        observed_ids = set(_widget_tag_ids(widget))
        missing = intended_ids - observed_ids
        if not missing:
            continue
        try:
            _merge_tags(
                mid,
                widget_id,
                additions=sorted(missing),
                removals=[],
                max_retries=_TAG_MERGE_MAX_RETRIES,
            )
            repaired.append(
                {
                    "widget_id": widget_id,
                    "repaired": True,
                    "warning": "tag_drift_repaired",
                }
            )
        except MuralError as exc:
            repaired.append(
                {"widget_id": widget_id, "repaired": False, "warning": str(exc)}
            )
    return repaired
