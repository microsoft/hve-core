#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Area lookup, fallback, probe, and context helper implementations."""

from __future__ import annotations

import logging
from typing import Any, Callable


def _get_area_impl(
    mural_id: str,
    area_id: str,
    *,
    area_cache: dict[str, dict[str, Any]],
    authenticated_request: Callable[..., Any],
    MuralAPIError: type[Exception],
) -> dict[str, Any]:
    """Return area metadata for ``area_id``, fetching it on cache miss."""
    cached = area_cache.get(area_id)
    if cached is not None:
        return cached
    record = authenticated_request("GET", f"/murals/{mural_id}/areas/{area_id}")
    if not isinstance(record, dict):
        raise MuralAPIError(0, "AREA_INVALID", "area response is not an object")
    area_cache[area_id] = record
    return record


def _log_area_fallback_once_impl(
    mural_id: str,
    *,
    logged_mural_ids: set[str],
    logger: logging.Logger,
) -> None:
    if mural_id in logged_mural_ids:
        return
    logged_mural_ids.add(mural_id)
    logger.warning(
        "Mural %s returned 404 on /areas; falling back to /widgets?type=area.",
        mural_id,
    )


def _list_areas_with_widget_fallback_impl(
    mural_id: str,
    *,
    paginate: Callable[..., Any],
    area_cache: dict[str, dict[str, Any]],
    log_area_fallback_once: Callable[[str], None],
    MuralAPIError: type[Exception],
    **paginate_kwargs: Any,
) -> list[dict[str, Any]]:
    """List areas, falling back to ``/widgets?type=area`` on 404."""
    try:
        return list(paginate("GET", f"/murals/{mural_id}/areas", **paginate_kwargs))
    except MuralAPIError as exc:
        if exc.status != 404:
            raise
    log_area_fallback_once(mural_id)
    records = list(
        paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params={"type": "area"},
            **paginate_kwargs,
        )
    )
    for record in records:
        if isinstance(record, dict):
            area_id = record.get("id")
            if isinstance(area_id, str):
                area_cache[area_id] = record
    return records


def _get_area_with_widget_fallback_impl(
    mural_id: str,
    area_id: str,
    *,
    get_area: Callable[[str, str], dict[str, Any]],
    authenticated_request: Callable[..., Any],
    area_cache: dict[str, dict[str, Any]],
    log_area_fallback_once: Callable[[str], None],
    MuralAPIError: type[Exception],
) -> dict[str, Any]:
    """Get an area, transparently falling back to ``/widgets/{id}`` on 404."""
    try:
        return get_area(mural_id, area_id)
    except MuralAPIError as exc:
        if exc.status != 404:
            raise
    log_area_fallback_once(mural_id)
    record = authenticated_request("GET", f"/murals/{mural_id}/widgets/{area_id}")
    if not isinstance(record, dict):
        raise MuralAPIError(404, "AREA_INVALID", "widget response is not an object")
    if record.get("type") != "area":
        raise MuralAPIError(
            404,
            "AREA_INVALID",
            f"widget {area_id} is not an area (type={record.get('type')!r})",
        )
    area_cache[area_id] = record
    return record


def _area_probe_impl(
    mural_id: str,
    area_id: str,
    *,
    get_area_with_widget_fallback: Callable[[str, str], dict[str, Any]],
    authenticated_request: Callable[..., Any],
    resolve_widget_id: Callable[[Any], str | None],
    get_widget_with_context: Callable[[str, str], dict[str, Any]],
    area_probe_verdict: Callable[
        [dict[str, Any], list[Any], list[dict[str, Any]], str], dict[str, Any]
    ],
    logger: logging.Logger,
    redact: Callable[[str], str],
    MuralAPIError: type[Exception],
    MuralError: type[Exception],
    probe_text: str,
    probe_shape: str,
) -> dict[str, Any]:
    """Create a disposable sticky-note probe inside ``area_id`` and diagnose."""
    area = get_area_with_widget_fallback(mural_id, area_id)
    ax = float(area.get("x", 0.0) or 0.0)
    ay = float(area.get("y", 0.0) or 0.0)
    aw = float(area.get("width", 0.0) or 0.0)
    ah = float(area.get("height", 0.0) or 0.0)
    probe_x = ax + aw / 2.0
    probe_y = ay + ah / 2.0

    body: dict[str, Any] = {
        "text": probe_text,
        "x": probe_x,
        "y": probe_y,
        "shape": probe_shape,
        "width": 1,
        "height": 1,
        "parentId": area_id,
    }
    probe_record = authenticated_request(
        "POST", f"/murals/{mural_id}/widgets/sticky-note", json_body=body
    )
    probe_id = resolve_widget_id(probe_record)
    if not probe_id:
        raise MuralAPIError(
            0, "PROBE_FAILED", "Could not resolve widget id from probe response"
        )

    try:
        ctx = get_widget_with_context(mural_id, probe_id)
        verdict = area_probe_verdict(
            ctx["widget"],
            ctx["siblings"],
            ctx["area_chain"],
            area_id,
        )
    finally:
        try:
            authenticated_request("DELETE", f"/murals/{mural_id}/widgets/{probe_id}")
        except MuralError as cleanup_exc:
            logger.warning(
                "probe cleanup failed for %s: %s",
                probe_id,
                redact(str(cleanup_exc)),
            )

    verdict["probe_id"] = probe_id
    verdict["area_id"] = area_id
    verdict["area_title"] = area.get("title")
    return verdict


def _get_widget_with_context_impl(
    mural_id: str,
    widget_id: str,
    *,
    authenticated_request: Callable[..., Any],
    paginate: Callable[..., Any],
    walk_area_chain: Callable[[str, str | None], list[dict[str, Any]]],
) -> dict[str, Any]:
    """Return the widget plus its area_chain, siblings, and cluster envelope."""
    widget = authenticated_request("GET", f"/murals/{mural_id}/widgets/{widget_id}")
    parent_id = widget.get("parentId") if isinstance(widget, dict) else None
    area_chain = walk_area_chain(mural_id, parent_id) if parent_id else []
    siblings: list[Any] = []
    if parent_id:
        siblings = [
            w
            for w in paginate(
                "GET",
                f"/murals/{mural_id}/widgets",
                params={"parentId": parent_id},
            )
            if isinstance(w, dict) and w.get("id") != widget_id
        ]
    return {
        "widget": widget,
        "area_chain": area_chain,
        "siblings": siblings,
        "cluster": None,
    }


def _list_widgets_with_context_impl(
    mural_id: str,
    *,
    paginate: Callable[..., Any],
    walk_area_chain: Callable[[str, str | None], list[dict[str, Any]]],
    widget_type: str | None = None,
    parent_id: str | None = None,
    limit: int | None = None,
    page_size: int | None = None,
) -> list[dict[str, Any]]:
    """List widgets and attach an ``area_chain`` to each entry."""
    params: dict[str, Any] = {}
    if widget_type:
        params["type"] = widget_type
    if parent_id:
        params["parentId"] = parent_id
    widgets = list(
        paginate(
            "GET",
            f"/murals/{mural_id}/widgets",
            params=params or None,
            limit=limit,
            page_size=page_size,
        )
    )
    enriched: list[dict[str, Any]] = []
    for widget in widgets:
        if not isinstance(widget, dict):
            continue
        widget_parent = widget.get("parentId")
        chain = walk_area_chain(mural_id, widget_parent) if widget_parent else []
        enriched.append({"widget": widget, "area_chain": chain, "cluster": None})
    return enriched
