#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Geometry and spatial-query helpers for the Mural package.

Carved from ``mural.__init__`` per the modularization plan. Helpers that
default to package-owned state (for example ``_ROTATION_ENABLED`` and
``_ensure_geos_ready``) resolve those dependencies via deferred
``from . import`` lookups so ``monkeypatch.setattr(mural, ...)`` continues
to affect callers through the re-exported package surface.
"""

from __future__ import annotations

import logging
import math
import os
from typing import Any, TypedDict

from ._exceptions import MuralError

LOGGER = logging.getLogger("mural")

# Third-party dependency probe. ``shapely`` is a required runtime dependency
# (declared in ``pyproject.toml`` and the PEP 723 header above). The guarded
# import lets ``_probe_geos_version`` raise a structured ``MuralError`` for an
# older shapely or absent GEOS instead of surfacing an opaque ImportError at
# module load.
try:  # pragma: no cover - older shapely
    from shapely import geos_version as _SHAPELY_GEOS_VERSION
except ImportError:  # pragma: no cover - older shapely or shapely absent
    _SHAPELY_GEOS_VERSION = None  # type: ignore[assignment]


_GEOS_PROBE_DONE = False


class Rect(TypedDict):
    """Axis-aligned bounding rectangle in Mural canvas coordinates.

    ``x``/``y`` is the top-left corner in canvas units; ``w``/``h`` are
    non-negative dimensions. Use ``safe_rect`` to construct a ``Rect`` from
    arbitrary signed inputs.
    """

    x: float
    y: float
    w: float
    h: float


def safe_rect(x: float, y: float, w: float, h: float) -> Rect:
    """Return a ``Rect`` with non-negative ``w``/``h``.

    Negative dimensions are sign-corrected by translating the origin and
    absoluting the dimension, which preserves the geometric footprint while
    yielding a canonical AABB shape that downstream helpers can rely on.
    """
    nx = x if w >= 0 else x + w
    ny = y if h >= 0 else y + h
    return {"x": nx, "y": ny, "w": abs(w), "h": abs(h)}


def point_in_rect(px: float, py: float, rect: Rect, eps: float = 1e-6) -> bool:
    """Return ``True`` when ``(px, py)`` lies inside ``rect``.

    Inclusion is tested against an eps-expanded boundary so floating-point
    edge points still test true. ``eps`` defaults to ``1e-6``, matching the
    Mural canvas's effective sub-pixel precision.
    """
    return (
        rect["x"] - eps <= px <= rect["x"] + rect["w"] + eps
        and rect["y"] - eps <= py <= rect["y"] + rect["h"] + eps
    )


def rects_overlap(a: Rect, b: Rect, eps: float = 1e-6) -> bool:
    """Return ``True`` when ``a`` and ``b`` share any area or touch on an edge.

    Touching edges count as overlap (configurable via ``eps``); strict
    separation requires a gap larger than ``eps`` on at least one axis.
    """
    return not (
        a["x"] + a["w"] < b["x"] - eps
        or b["x"] + b["w"] < a["x"] - eps
        or a["y"] + a["h"] < b["y"] - eps
        or b["y"] + b["h"] < a["y"] - eps
    )


def rect_intersection(a: Rect, b: Rect) -> Rect | None:
    """Return the intersection ``Rect`` of ``a`` and ``b``, or ``None``.

    A zero-area intersection (touching edge or corner) is returned as a
    ``Rect`` with ``w`` and/or ``h`` equal to zero so callers can distinguish
    "touching" from "fully disjoint".
    """
    ix = max(a["x"], b["x"])
    iy = max(a["y"], b["y"])
    ix2 = min(a["x"] + a["w"], b["x"] + b["w"])
    iy2 = min(a["y"] + a["h"], b["y"] + b["h"])
    if ix2 < ix or iy2 < iy:
        return None
    return {"x": ix, "y": iy, "w": ix2 - ix, "h": iy2 - iy}


def rect_contains_rect(outer: Rect, inner: Rect, eps: float = 1e-6) -> bool:
    """Return ``True`` when ``inner`` is fully contained within ``outer``.

    Containment is tested with an eps tolerance on every edge so floating
    point boundary cases (e.g. coordinates produced by rotation math) still
    classify correctly.
    """
    return (
        inner["x"] >= outer["x"] - eps
        and inner["y"] >= outer["y"] - eps
        and inner["x"] + inner["w"] <= outer["x"] + outer["w"] + eps
        and inner["y"] + inner["h"] <= outer["y"] + outer["h"] + eps
    )


def _shape_to_rect(
    widget: dict[str, Any], *, rotation_aware: bool | None = None
) -> Rect:
    """Project a Mural ``widget`` geometry into an axis-aligned bounding rect.

    When ``rotation_aware`` is ``False`` the widget's ``rotation`` field is
    ignored and the unrotated rect is returned. When ``True`` the four
    corners are rotated about the rect center and the AABB of those rotated
    corners is returned, matching how rotated widgets actually occupy canvas
    space. Passing ``None`` (the default) defers to the module-level
    ``_ROTATION_ENABLED`` constant, which is set at import time from the
    ``MURAL_SPATIAL_ROTATION_ENABLED`` env flag (``"1"`` enables rotation
    awareness); explicit ``True``/``False`` always overrides the constant.
    """
    if rotation_aware is None:
        from . import _ROTATION_ENABLED as _rotation_default

        rotation_aware = _rotation_default
    x = float(widget.get("x", 0.0) or 0.0)
    y = float(widget.get("y", 0.0) or 0.0)
    w = float(widget.get("width", 0.0) or 0.0)
    h = float(widget.get("height", 0.0) or 0.0)
    base = safe_rect(x, y, w, h)
    if not rotation_aware:
        return base
    rotation = float(widget.get("rotation", 0.0) or 0.0)
    if rotation % 360.0 == 0.0:
        return base
    rad = math.radians(rotation)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    cx = base["x"] + base["w"] / 2.0
    cy = base["y"] + base["h"] / 2.0
    half_w = base["w"] / 2.0
    half_h = base["h"] / 2.0
    xs: list[float] = []
    ys: list[float] = []
    for dx, dy in (
        (-half_w, -half_h),
        (half_w, -half_h),
        (half_w, half_h),
        (-half_w, half_h),
    ):
        rx = dx * cos_a - dy * sin_a
        ry = dx * sin_a + dy * cos_a
        xs.append(cx + rx)
        ys.append(cy + ry)
    min_x = min(xs)
    min_y = min(ys)
    max_x = max(xs)
    max_y = max(ys)
    return {"x": min_x, "y": min_y, "w": max_x - min_x, "h": max_y - min_y}


def widget_center(
    widget: dict[str, Any], *, rotation_aware: bool | None = None
) -> tuple[float, float]:
    """Return the ``(cx, cy)`` AABB center of ``widget``.

    Always classify a widget by its center, never by its left/top edge:
    column-membership, lane assignment, and any "which region owns this
    sticky" decision must use this helper so a wide widget straddling a
    boundary is attributed to the column its mass actually sits in. Defers
    to ``_shape_to_rect`` so rotation handling matches ``widgets_in_region``.
    """
    rect = _shape_to_rect(widget, rotation_aware=rotation_aware)
    return (rect["x"] + rect["w"] / 2.0, rect["y"] + rect["h"] / 2.0)


def _area_probe_verdict(
    probe: dict[str, Any],
    siblings: list[dict[str, Any]],
    area_chain: list[dict[str, Any]],
    expected_area_id: str,
) -> dict[str, Any]:
    """Compute a z-order visibility verdict for a probe widget.

    Pure function — no I/O, no state mutation.  Returns a dict with:

    * ``verdict`` — ``ok``, ``unbound``, ``parent_mismatch``, or ``occluded``.
    * ``siblings_above`` — list of sibling ids whose bounding rect fully
      contains the probe's bounding rect (potential z-order occluders).
    * ``area_chain`` — the area chain as passed in (echoed for caller use).
    * ``recommendation`` — human-readable action string.
    """
    if not area_chain:
        return {
            "verdict": "unbound",
            "siblings_above": [],
            "area_chain": area_chain,
            "recommendation": (
                "Probe widget is not bound to any area. "
                "Verify the parentId resolves to a valid area."
            ),
        }

    nearest_area_id = area_chain[0].get("id") if area_chain else None
    if nearest_area_id != expected_area_id:
        return {
            "verdict": "parent_mismatch",
            "siblings_above": [],
            "area_chain": area_chain,
            "recommendation": (
                f"Nearest area in chain is {nearest_area_id!r}, "
                f"expected {expected_area_id!r}. "
                "Verify the parentId targets the correct area."
            ),
        }

    probe_rect = _shape_to_rect(probe)
    occluders: list[str] = []
    for sib in siblings:
        if not isinstance(sib, dict):
            continue
        sib_rect = _shape_to_rect(sib)
        if rect_contains_rect(sib_rect, probe_rect):
            sib_id = sib.get("id", "<unknown>")
            occluders.append(str(sib_id))

    if occluders:
        return {
            "verdict": "occluded",
            "siblings_above": occluders,
            "area_chain": area_chain,
            "recommendation": (
                f"Probe bounding box is fully contained within "
                f"{len(occluders)} sibling(s): {', '.join(occluders)}. "
                "Mural's REST API exposes no canvas z-order operation, "
                "so this must be resolved manually by an operator in the "
                "Mural UI ('Send to Back' / 'Bring to Front', or anchor "
                "restructure). Pause the workflow and surface this verdict "
                "to the operator. Do not re-run the probe, destroy and "
                "recreate the widget, or hand-tune (x, y) offsets — see "
                "the Z-Order Visibility section of "
                "mural-seeding-patterns.instructions.md."
            ),
        }

    return {
        "verdict": "ok",
        "siblings_above": [],
        "area_chain": area_chain,
        "recommendation": "Area is safe for bulk seeding.",
    }


def widgets_in_region(
    widgets: list[dict[str, Any]],
    region: Rect,
    *,
    mode: str = "center",
) -> list[dict[str, Any]]:
    """Return widgets whose geometry intersects ``region`` per ``mode``.

    ``mode='center'`` includes a widget when its bounding-box center lies
    inside ``region`` (using ``point_in_rect`` semantics). ``mode='bbox'``
    includes a widget when its AABB overlaps ``region`` (using
    ``rects_overlap`` semantics, which counts touching edges as overlap).
    Empty input returns an empty list. Output is stably sorted by widget
    ``id`` so callers see deterministic ordering across runs. Unknown
    ``mode`` values raise ``ValueError``.
    """
    if not widgets:
        return []
    if mode not in ("center", "bbox"):
        raise ValueError(f"unknown mode: {mode!r}")
    matched: list[dict[str, Any]] = []
    for widget in widgets:
        if mode == "center":
            cx, cy = widget_center(widget)
            if point_in_rect(cx, cy, region):
                matched.append(widget)
        else:
            rect = _shape_to_rect(widget)
            if rects_overlap(rect, region):
                matched.append(widget)
    return sorted(matched, key=lambda w: str(w.get("id", "")))


def widgets_in_shape(
    widgets: list[dict[str, Any]],
    shape_widget: dict[str, Any],
    *,
    mode: str = "center",
    rotation_aware: bool = False,
) -> list[dict[str, Any]]:
    """Return widgets contained by ``shape_widget``'s AABB.

    Composes ``_shape_to_rect(shape_widget, rotation_aware=rotation_aware)``
    with ``widgets_in_region`` so a frame, area, or rotated container can
    act as the query region. ``rotation_aware=True`` expands the container's
    AABB to enclose its rotated corners; the default leaves rotation
    handling to the env flag policy of ``_shape_to_rect``. Output ordering
    is the deterministic widget-id sort produced by ``widgets_in_region``.
    """
    region = _shape_to_rect(shape_widget, rotation_aware=rotation_aware)
    return widgets_in_region(widgets, region, mode=mode)


def pairwise_overlaps(
    widgets: list[dict[str, Any]],
    *,
    predicate: str = "intersects",
    rotation_aware: bool | None = None,
) -> list[tuple[str, str]]:
    """Return overlapping widget id pairs using a ``shapely.STRtree`` index.

    Builds an STR R-tree from each widget's AABB (computed via
    ``_shape_to_rect`` so the rotation-aware policy of the spatial module
    is respected) and queries every geometry against the tree. Results are
    deduped to a single ordered pair ``(a, b)`` with ``a < b`` per widget
    id and sorted lexicographically so callers see deterministic output.
    Empty input returns ``[]``. Unknown ``predicate`` values raise
    ``ValueError``. ``rotation_aware`` left as ``None`` (the sentinel)
    defers to ``_ROTATION_ENABLED`` mirroring the env flag policy of
    ``_shape_to_rect``.
    """
    from . import _ensure_geos_ready as _ensure

    _ensure()
    if not widgets:
        return []
    if predicate not in ("intersects", "contains"):
        raise ValueError(f"unknown predicate: {predicate!r}")
    if rotation_aware is None:
        from . import _ROTATION_ENABLED as _rotation_default

        rotation_aware = _rotation_default
    from shapely.geometry import box
    from shapely.strtree import STRtree

    geoms = []
    ids = []
    for widget in widgets:
        rect = _shape_to_rect(widget, rotation_aware=rotation_aware)
        geoms.append(
            box(
                rect["x"],
                rect["y"],
                rect["x"] + rect["w"],
                rect["y"] + rect["h"],
            )
        )
        ids.append(str(widget.get("id", "")))
    tree = STRtree(geoms)
    pairs: set[tuple[str, str]] = set()
    for i, geom in enumerate(geoms):
        candidates = tree.query(geom)
        for j in candidates:
            j_int = int(j)
            if j_int == i:
                continue
            if predicate == "intersects":
                if not geom.intersects(geoms[j_int]):
                    continue
                a, b = ids[i], ids[j_int]
                if a == b:
                    continue
                if a > b:
                    a, b = b, a
                pairs.add((a, b))
            else:
                if not geom.contains(geoms[j_int]):
                    continue
                a, b = ids[i], ids[j_int]
                if a == b:
                    continue
                if a > b:
                    a, b = b, a
                pairs.add((a, b))
    return sorted(pairs)


def cluster_widgets(
    widgets: list[dict[str, Any]],
    *,
    eps_px: float = 120.0,
    min_samples: int = 2,
) -> list[list[str]]:
    """Group widgets by spatial proximity of their AABB centers via DBSCAN.

    Projects each widget's bounding-box center (computed via
    ``_shape_to_rect`` so the rotation-aware policy of the spatial module
    is respected) into a 2D point, then runs a density-based clustering
    pass using a ``shapely.strtree.STRtree`` box query refined by
    Euclidean distance for ``eps_px``-radius neighborhood queries. Empty
    input returns ``[]``. Noise points (those
    with fewer than ``min_samples`` neighbors within ``eps_px``) are
    omitted; setting ``min_samples=1`` keeps isolated widgets as
    singletons. Each returned cluster is a sorted list of widget ids; the
    outer list is sorted by descending cluster size with a stable
    lexicographic tiebreak on the smallest member id so callers see
    deterministic output across runs. ``eps_px`` must be ``> 0`` and
    ``min_samples`` must be ``>= 1``; other values raise ``ValueError``.
    """
    if not widgets:
        return []
    if eps_px <= 0:
        raise ValueError(f"eps_px must be > 0; got {eps_px!r}")
    if min_samples < 1:
        raise ValueError(f"min_samples must be >= 1; got {min_samples!r}")
    from shapely.geometry import Point, box
    from shapely.strtree import STRtree

    ids: list[str] = []
    points: list[tuple[float, float]] = []
    for widget in widgets:
        rect = _shape_to_rect(widget)
        ids.append(str(widget.get("id", "")))
        points.append(
            (
                rect["x"] + rect["w"] / 2.0,
                rect["y"] + rect["h"] / 2.0,
            )
        )
    tree = STRtree([Point(px, py) for px, py in points])
    eps_sq = eps_px * eps_px
    neighbors: list[list[int]] = []
    for cx, cy in points:
        candidates = tree.query(box(cx - eps_px, cy - eps_px, cx + eps_px, cy + eps_px))
        nbrs: list[int] = []
        for j in candidates:
            j_int = int(j)
            jx, jy = points[j_int]
            dx = jx - cx
            dy = jy - cy
            if dx * dx + dy * dy <= eps_sq:
                nbrs.append(j_int)
        neighbors.append(nbrs)

    unclassified = -2
    noise = -1
    labels = [unclassified] * len(points)
    next_cluster = 0
    for i in range(len(points)):
        if labels[i] != unclassified:
            continue
        seeds = list(neighbors[i])
        if len(seeds) < min_samples:
            labels[i] = noise
            continue
        labels[i] = next_cluster
        queue = list(seeds)
        seen = set(seeds)
        k = 0
        while k < len(queue):
            j = queue[k]
            k += 1
            if labels[j] == noise:
                labels[j] = next_cluster
                continue
            if labels[j] != unclassified:
                continue
            labels[j] = next_cluster
            j_neighbors = neighbors[j]
            if len(j_neighbors) >= min_samples:
                for m in j_neighbors:
                    if m not in seen:
                        seen.add(m)
                        queue.append(m)
        next_cluster += 1

    grouped: dict[int, list[str]] = {}
    for idx, lbl in enumerate(labels):
        if lbl == noise:
            continue
        grouped.setdefault(lbl, []).append(ids[idx])
    clusters = [sorted(members) for members in grouped.values()]
    clusters.sort(key=lambda c: (-len(c), c[0] if c else ""))
    return clusters


def sort_along_axis(
    widgets: list[dict[str, Any]],
    *,
    axis: str = "x",
    origin: tuple[float, float] | None = None,
) -> list[dict[str, Any]]:
    """Return widgets ordered by their AABB-center projection along ``axis``.

    Computes each widget's bounding-box center via ``_shape_to_rect`` so
    the rotation-aware policy of the spatial module is respected, then
    projects centers onto the axis vector. ``axis="x"`` and ``axis="y"``
    project onto the canonical unit basis vectors; ``axis="diagonal"``
    projects onto ``(1, 1) / sqrt(2)``. When ``origin`` is provided the
    sort key is the absolute distance ``|(center - origin) · axis|`` so
    callers can order widgets by proximity to an anchor along a
    direction; widgets equidistant on opposite sides of the anchor tie
    on projection and fall back to id ordering. When ``origin`` is
    omitted the raw signed projection of the center is used so widgets
    sort by their position along the axis. Empty input returns ``[]``.
    Ties are broken by widget id so the output is deterministic across
    runs.
    """
    if not widgets:
        return []
    if axis == "x":
        ax, ay = 1.0, 0.0
    elif axis == "y":
        ax, ay = 0.0, 1.0
    elif axis == "diagonal":
        inv_sqrt2 = 1.0 / math.sqrt(2.0)
        ax, ay = inv_sqrt2, inv_sqrt2
    else:
        raise ValueError(f"axis must be one of 'x', 'y', 'diagonal'; got {axis!r}")
    ox, oy = (0.0, 0.0) if origin is None else (float(origin[0]), float(origin[1]))
    use_abs = origin is not None

    def _key(widget: dict[str, Any]) -> tuple[float, str]:
        rect = _shape_to_rect(widget)
        cx = rect["x"] + rect["w"] / 2.0
        cy = rect["y"] + rect["h"] / 2.0
        proj = (cx - ox) * ax + (cy - oy) * ay
        if use_abs:
            proj = abs(proj)
        return (proj, str(widget.get("id", "")))

    return sorted(widgets, key=_key)


def shoelace_area(polygon: list[tuple[float, float]]) -> float:
    """Return the absolute area of ``polygon`` via the shoelace formula.

    ``polygon`` is a list of ``(x, y)`` vertices in either winding order;
    the absolute value of the signed shoelace sum is returned so callers
    do not need to know the orientation. Polygons with fewer than three
    vertices have no area and return ``0.0``.
    """
    n = len(polygon)
    if n < 3:
        return 0.0
    total = 0.0
    for i in range(n):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % n]
        total += (x1 * y2) - (x2 * y1)
    return abs(total) / 2.0


def ray_cast_pip(
    point: tuple[float, float], polygon: list[tuple[float, float]]
) -> bool:
    """Return ``True`` when ``point`` lies inside ``polygon``.

    Uses the even-odd ray-casting algorithm: a horizontal ray from
    ``point`` to ``+inf`` is intersected against each polygon edge and the
    point is inside when the crossing count is odd. Edge-coincident points
    are not specially handled and may classify either way; callers needing
    boundary semantics should test against a small interior offset. Returns
    ``False`` for degenerate polygons (fewer than three vertices).
    """
    n = len(polygon)
    if n < 3:
        return False
    x, y = point
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside


def build_arrow_graph(
    widgets: list[dict[str, Any]],
    arrows: list[dict[str, Any]],
    *,
    snap_radius: float = 24.0,
) -> Any:
    """Build a directed multigraph from ``arrows`` anchored to ``widgets``.

    Non-arrow ``widgets`` become graph nodes keyed by widget id. Each arrow
    has its ``(x1, y1)`` and ``(x2, y2)`` endpoints snapped to the nearest
    widget AABB center within ``snap_radius`` (Euclidean pixels). Arrows
    with both endpoints anchored produce an edge keyed by the arrow id
    with the original arrow widget attached as the ``arrow_widget`` edge
    attribute. Arrows missing either anchor (no widget center within the
    radius, or malformed coordinates) are skipped and a warning is logged
    via the module logger. Widgets and arrows are processed in
    lexicographic id order so the resulting graph is deterministic across
    runs. Returns a ``networkx.MultiDiGraph``.
    """
    import networkx as nx

    graph = nx.MultiDiGraph()
    sorted_widgets = sorted(widgets, key=lambda w: str(w.get("id", "")))
    centers: list[tuple[str, float, float]] = []
    for widget in sorted_widgets:
        wid = str(widget.get("id", ""))
        graph.add_node(wid)
        rect = _shape_to_rect(widget)
        cx = rect["x"] + rect["w"] / 2.0
        cy = rect["y"] + rect["h"] / 2.0
        centers.append((wid, cx, cy))

    radius_sq = float(snap_radius) * float(snap_radius)

    def _nearest(px: float, py: float) -> str | None:
        best_id: str | None = None
        best_d2 = radius_sq
        for wid, cx, cy in centers:
            dx = cx - px
            dy = cy - py
            d2 = dx * dx + dy * dy
            if d2 <= best_d2:
                if best_id is None or d2 < best_d2 or wid < best_id:
                    best_id = wid
                    best_d2 = d2
        return best_id

    for arrow in sorted(arrows, key=lambda a: str(a.get("id", ""))):
        arrow_id = str(arrow.get("id", ""))
        try:
            sx = float(arrow["x1"])
            sy = float(arrow["y1"])
            ex = float(arrow["x2"])
            ey = float(arrow["y2"])
        except (KeyError, TypeError, ValueError):
            LOGGER.warning("arrow %s has no anchor within snap_radius", arrow_id)
            continue
        src = _nearest(sx, sy)
        dst = _nearest(ex, ey)
        if src is None or dst is None:
            LOGGER.warning("arrow %s has no anchor within snap_radius", arrow_id)
            continue
        graph.add_edge(src, dst, key=arrow_id, arrow_widget=arrow)
    return graph


def arrow_graph_summary(graph: Any) -> dict[str, Any]:
    """Return a JSON-serializable summary of an arrow ``graph``.

    Produces ``{"nodes": [...], "edges": [...], "stats": {...}}`` where
    ``nodes`` is the lexicographically sorted list of node ids, ``edges``
    is a list of ``{"id": arrow_id, "source": u, "target": v}`` records
    sorted by ``id``, and ``stats`` reports ``node_count``, ``edge_count``,
    and ``is_dag`` (``networkx.is_directed_acyclic_graph``). The result
    contains only primitive types so ``json.dumps`` round-trips without
    custom encoders.
    """
    import networkx as nx

    nodes = sorted(str(n) for n in graph.nodes())
    edges = sorted(
        (
            {"id": str(key), "source": str(u), "target": str(v)}
            for u, v, key in graph.edges(keys=True)
        ),
        key=lambda record: record["id"],
    )
    return {
        "nodes": nodes,
        "edges": edges,
        "stats": {
            "node_count": graph.number_of_nodes(),
            "edge_count": graph.number_of_edges(),
            "is_dag": bool(nx.is_directed_acyclic_graph(graph)),
        },
    }


def _probe_geos_version() -> tuple[int, int, int]:
    """Probe the bundled GEOS version exposed by ``shapely``.

    Returns the ``(major, minor, patch)`` tuple from ``shapely.geos_version``,
    or raises ``MuralError`` when the import or attribute lookup fails or when
    the detected major/minor is below ``(3, 11)``.
    """
    version = _SHAPELY_GEOS_VERSION
    if version is None:
        raise MuralError(
            "Unable to probe shapely.geos_version; mural spatial features "
            "require GEOS >= 3.11."
        )
    try:
        major, minor, patch = int(version[0]), int(version[1]), int(version[2])
    except (TypeError, ValueError, IndexError) as exc:
        raise MuralError(
            f"Detected GEOS version {version!r} in unexpected shape; mural "
            "spatial features require GEOS >= 3.11."
        ) from exc
    if (major, minor) < (3, 11):
        raise MuralError(
            f"Detected GEOS {major}.{minor}.{patch}; mural spatial features "
            "require GEOS >= 3.11."
        )
    return (major, minor, patch)


def _ensure_geos_ready() -> None:
    """Run the GEOS version probe at most once per process."""
    global _GEOS_PROBE_DONE
    if _GEOS_PROBE_DONE:
        return
    _GEOS_PROBE_DONE = True
    if os.environ.get("MURAL_SUPPRESS_GEOS_PROBE"):
        return
    _probe_geos_version()
