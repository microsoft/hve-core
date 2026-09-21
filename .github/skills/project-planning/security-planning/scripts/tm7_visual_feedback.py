# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Pure feedback-domain contracts, metrics, and scoring logic for TM7 overlays."""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from tm7_threat_contract import MAX_SPEC_BYTES, read_bounded_bytes

LAYOUT_OVERLAY_SCHEMA_VERSION = 2
FEEDBACK_MANIFEST_SCHEMA_VERSION = 2

# Composition gate thresholds. Blocking thresholds describe objective native
# defects; advisory thresholds stay warn-only until calibrated against a
# human-approved corpus.
HANDLE_CLUSTER_STEP = 8.0
MIN_VISIBLE_COVERAGE_RATIO = 0.999
# TMT draws each connector label at that connector's handle point, so any two
# connectors sharing a handle render their labels on top of each other. A
# cluster of two is therefore already a defect.
MAX_HANDLE_CLUSTER_SIZE = 1
MAX_LABEL_OWNERSHIP_DISTANCE = 120.0
# The widest a connector label is allowed to render. TMT draws each label
# centred on its handle point, so layout must reserve half this width beyond the
# content it annotates or an edge label is truncated by the canvas.
MAX_CONNECTOR_LABEL_WIDTH = 260.0
MIN_LABEL_ARROWHEAD_CLEARANCE = 24.0
MAX_BRANCH_ALIGNMENT_VARIANCE = 4096.0
MIN_RANK_MONOTONICITY_RATIO = 0.85
MAX_ZONE_WHITESPACE_IMBALANCE = 0.6
# Advisory canvas-utilization band. A layout that uses far less than the
# calibrated pane crowds its own content; one that fills it completely leaves
# no breathing room. Both bounds stay advisory until calibrated against a
# human-approved corpus.
MIN_VIEWPORT_FILL_WIDTH_RATIO = 0.70
MAX_VIEWPORT_FILL_WIDTH_RATIO = 0.92
# A connector endpoint further than this from its own node is detached: the
# line points at the shape instead of being joined to it. The budget is per
# axis, so an endpoint on a corner is held to the same tolerance as one on an
# edge. Measuring the diagonal instead would penalise a corner by a factor of
# sqrt(2) for the identical overshoot on each axis.
MAX_ENDPOINT_ATTACHMENT_GAP = 1.0

# Whole-surface refinement search bounds. Each refinement evaluates complete
# alternatives rather than single-rule symptom corrections. Only an orientation
# and a zone order can reach layout, so the space is the distinct pairs of
# those two: two orientations times a zone-order set capped at eight rotations
# and their reversals, giving a structural ceiling of 32. Earlier revisions also
# varied a rank spacing and a branch offset, inflating the ceiling to 192; those
# two had no overlay channel, so their variants produced byte-identical layouts
# and, once candidates were scored on measured geometry, exact ties. Ties are
# not free: dominated-candidate pruning discards equal scores and selection
# demands a strict improvement, so the duplicates made the gate harder to open.
SURFACE_REFINEMENT_ZONE_ROTATION_CAP = 8
MAX_SURFACE_REFINEMENT_CANDIDATES = 32
# A surface carrying at least the rotation cap of zones enumerates the whole
# space, so a smaller count means the enumeration collapsed rather than that the
# surface was small.
MIN_SURFACE_REFINEMENT_CANDIDATES = 32
ALLOWED_TOP_LEVEL_OVERLAY_KEYS = {
    "schema_version",
    "overlay_type",
    "model_id",
    "overlay_id",
    "applies_to",
    "zone_rules",
    "node_rules",
    "connector_rules",
    "surface_rules",
    "provenance",
    "invalidation",
}
ALLOWED_APPLY_RULE_KEYS = {"surface_id", "generator_profile"}
ALLOWED_ZONE_RULE_KEYS = {
    "surface_id",
    "zone_id",
    "region",
    "label_band_height",
    "lane_order",
}
ALLOWED_NODE_RULE_KEYS = {
    "surface_id",
    "node_id",
    "layout_role",
    "absolute_position",
    "relative_placement",
}
ALLOWED_CONNECTOR_RULE_KEYS = {
    "surface_id",
    "flow_id",
    "source_port",
    "target_port",
    "handle_point",
    "label_offset",
}
ALLOWED_SURFACE_RULE_KEYS = {
    "surface_id",
    "zone_order",
    "orientation",
    "viewport_target",
    "outer_margin",
}
ALLOWED_LAYOUT_ROLES = {"main", "contextual", "suppressed", "connected"}
ALLOWED_ORIENTATIONS = {"horizontal", "vertical"}
ALLOWED_PROVENANCE_KEYS = {"evidence_ref", "generated_at", "approval_state"}
ALLOWED_INVALIDATION_KEYS = {
    "spec_fingerprint",
    "generator_profile_fingerprint",
    "surface_identity_fingerprint",
    "surface_zone_identity_fingerprint",
    "surface_flow_identity_fingerprint",
}
# Mirrors the `properties` set of tm7-visual-feedback-manifest.schema.json,
# which declares additionalProperties false. The two must stay in step: this
# constant is the runtime guard and the schema is the published contract.
ALLOWED_MANIFEST_TOP_LEVEL_KEYS = {
    "schema_version",
    "manifest_type",
    "model_id",
    "spec_path",
    "spec_sha256",
    "generator_profile",
    "generator_profile_sha256",
    "candidate_sha256",
    "iteration_id",
    "pinned_tmt_version",
    "created_at",
    "surfaces",
    "convergence",
    # Emitted only when a layout calibration contract is supplied, which is why
    # it was missed when this list was first written.
    "layout_calibration_v1",
}


@dataclass(slots=True)
class OverlayContext:
    """Context to validate a layout overlay against the current model state."""

    model_id: str
    spec_path: Path
    spec_sha256: str
    generator_profile: str
    generator_profile_sha256: str
    surface_ids: set[str]
    surface_node_ids: dict[str, set[str]] = field(default_factory=dict)
    surface_zone_ids: dict[str, set[str]] = field(default_factory=dict)
    surface_flow_ids: dict[str, set[str]] = field(default_factory=dict)


@dataclass(slots=True)
class SurfaceGeometry:
    """Geometry snapshot for a single TM7 drawing surface."""

    surface_id: str
    nominal_node_size: float
    node_rects: dict[str, tuple[float, float, float, float]]
    connector_segments: list[tuple[str, str, tuple[float, float], tuple[float, float]]]
    boundary_rects: dict[str, tuple[float, float, float, float]] = field(
        default_factory=dict
    )
    boundary_label_rects: dict[str, tuple[float, float, float, float]] = field(
        default_factory=dict
    )
    connector_label_rects: dict[str, tuple[float, float, float, float]] = field(
        default_factory=dict
    )
    layout_roles: dict[str, str] = field(default_factory=dict)
    zone_membership: dict[str, str] = field(default_factory=dict)
    zone_content_rects: dict[str, tuple[float, float, float, float]] = field(
        default_factory=dict
    )
    zone_parent_map: dict[str, str | None] = field(default_factory=dict)
    viewport_target: tuple[float, float, float, float] | None = None
    diagram_bounds: tuple[float, float, float, float] | None = None
    outer_margin: float = 0.0
    selected_flow_ids: set[str] = field(default_factory=set)
    expected_semantic_node_ids: set[str] = field(default_factory=set)
    expected_semantic_flow_ids: set[str] = field(default_factory=set)
    connector_routes: dict[str, dict[str, Any]] = field(default_factory=dict)
    node_ranks: dict[str, int] = field(default_factory=dict)
    branch_groups: dict[str, int] = field(default_factory=dict)
    orientation: str = "horizontal"


@dataclass(slots=True)
class ViewportBounds:
    """Viewport metadata captured from the rendered surface."""

    left: int
    top: int
    width: int
    height: int


@dataclass(slots=True)
class IterationResult:
    """Single iteration record used for convergence decisions."""

    iteration_id: int
    defect_signature: str
    gate_failure_count: int
    review_count: int = 0
    warn_count: int = 0
    evidence_complete: bool = True
    max_severity_score: float = 0.0


@dataclass(slots=True)
class ConvergenceResult:
    """Outcome of the convergence evaluation."""

    should_stop: bool
    stop_reason: str
    reason_detail: str | None = None


def _normalize_for_fingerprint(value: Any) -> Any:
    """Recursively normalize values so overlay fingerprints stay deterministic.

    Handles both filesystem paths and temporal values because the overlay
    invalidation contract is shared with the generator, and a value normalized
    by only one side would produce two fingerprints for one logical input.
    """
    if isinstance(value, dict):
        return {
            str(key): _normalize_for_fingerprint(item)
            for key, item in sorted(value.items(), key=lambda entry: str(entry[0]))
        }
    if isinstance(value, list):
        return [_normalize_for_fingerprint(item) for item in value]
    if isinstance(value, tuple):
        return [_normalize_for_fingerprint(item) for item in value]
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def _canonical_bytes(value: Any) -> bytes:
    """Encode a normalized value as canonical JSON bytes for hashing."""
    return json.dumps(
        _normalize_for_fingerprint(value),
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _fingerprint(value: Any) -> str:
    """Return the SHA-256 fingerprint of a value's canonical encoding."""
    return hashlib.sha256(_canonical_bytes(value)).hexdigest()


def _is_finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def _normalize_path_reference(value: str, *, field_name: str) -> str:
    candidate = Path(value)
    if candidate.is_absolute():
        try:
            return str(candidate.relative_to(Path.cwd()))
        except ValueError:
            return candidate.name
    return str(candidate)


def _validate_path_reference(value: str, *, field_name: str) -> None:
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ValueError(f"{field_name} must not contain absolute or traversal paths")


def _is_background_bytes(payload: bytes) -> bool:
    if not payload:
        return True
    if len(payload) == 1:
        return True
    return len(set(payload)) <= 1


def _wrap_label_lines(
    label_text: str,
    *,
    max_lines: int = 2,
    max_chars: int = 42,
) -> list[str]:
    """Wrap connector labels to a conservative maximum of two lines."""
    text = " ".join(label_text.split())
    if not text:
        return [""]
    words = text.split()
    if any(len(word) > max_chars for word in words):
        raise ValueError("connector label exceeds the conservative two-line limit")
    if len(text) <= max_chars:
        return [text]
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip() if current else word
        if len(candidate) <= max_chars:
            current = candidate
            continue
        if not current:
            raise ValueError("connector label exceeds the conservative two-line limit")
        if len(lines) >= max_lines:
            raise ValueError("connector label exceeds the conservative two-line limit")
        lines.append(current)
        current = word
    if current:
        if len(lines) >= max_lines:
            raise ValueError("connector label exceeds the conservative two-line limit")
        lines.append(current)
    if not lines:
        lines = [text]
    return lines[:max_lines]


def _normalize_transport_label(transport: str | None) -> str:
    """Normalize verbose transport metadata into concise diagram vocabulary."""
    value = " ".join(str(transport or "").split())
    lowered = value.lower()
    if not value:
        return ""
    if "https" in lowered and "ssh" in lowered:
        return "HTTPS/SSH"
    if "https" in lowered and "file" in lowered:
        return "HTTPS/file"
    if "https" in lowered:
        return "HTTPS"
    if "http" in lowered and "loopback" in lowered:
        return "HTTP loopback"
    if "local process" in lowered:
        return "local process"
    if "local file" in lowered:
        return "local file"
    if "local read" in lowered:
        return "local read"
    if "local workspace" in lowered:
        return "local workspace"
    if "workflow subprocess" in lowered:
        return "workflow subprocess"
    if "internal trigger" in lowered:
        return "internal trigger"
    if lowered.startswith("internal"):
        return "internal"
    if "vs code" in lowered or "extension host" in lowered:
        return "extension API"
    return value


def build_connector_label_layout(
    label: str | None,
    transport: str | None,
    *,
    handle: tuple[float, float],
    label_offset: tuple[float, float] | None = None,
) -> dict[str, Any]:
    """Create a deterministic connector label layout near a handle point."""
    label_text = " ".join(str(label or "").split()) if label else ""
    if not label_text:
        raise ValueError("connector label requires an explicit action")
    transport_text = _normalize_transport_label(transport)
    display_label = " over ".join(part for part in [label_text, transport_text] if part)
    label_lines = _wrap_label_lines(display_label)
    max_line_length = max(len(line) for line in label_lines)
    width = max(120.0, min(MAX_CONNECTOR_LABEL_WIDTH, float(max_line_length * 8 + 16)))
    height = max(28.0, float(len(label_lines) * 24 + 8))
    # TMT draws the label centred on the handle point, so the predicted rect
    # is derived from the centre outwards. Anchoring the rect's top-left at
    # the handle would displace every prediction by half the label extent and
    # make collision avoidance optimize against geometry that is not drawn.
    center_x = float(handle[0]) + float((label_offset or (0.0, 0.0))[0])
    center_y = float(handle[1]) + float((label_offset or (0.0, 0.0))[1])
    # Centre-derived rects can land left of or above the canvas origin. Clamping
    # keeps the predicted rect on-canvas. An unclamped negative rect reaches
    # surface extents and shifts the whole layout by an amount that depends on
    # which connector was measured first, so the same model laid out from
    # differently ordered inputs would not match.
    left = max(center_x - width / 2.0, 24.0)
    top = max(center_y - height / 2.0, 24.0)
    return {
        "display_label": display_label,
        "label_lines": label_lines,
        "label_rect": [left, top, width, height],
    }


def _rect_overlap(
    left_a: float,
    top_a: float,
    right_a: float,
    bottom_a: float,
    left_b: float,
    top_b: float,
    right_b: float,
    bottom_b: float,
) -> float:
    overlap_left = max(left_a, left_b)
    overlap_top = max(top_a, top_b)
    overlap_right = min(right_a, right_b)
    overlap_bottom = min(bottom_a, bottom_b)
    if overlap_right <= overlap_left or overlap_bottom <= overlap_top:
        return 0.0
    overlap_area = (overlap_right - overlap_left) * (overlap_bottom - overlap_top)
    area_a = max(0.0, right_a - left_a) * max(0.0, bottom_a - top_a)
    area_b = max(0.0, right_b - left_b) * max(0.0, bottom_b - top_b)
    smaller_area = min(area_a, area_b)
    if smaller_area <= 0.0:
        return 0.0
    return overlap_area / smaller_area


def _orientation(
    point_a: tuple[float, float],
    point_b: tuple[float, float],
    point_c: tuple[float, float],
) -> int:
    value = (point_b[1] - point_a[1]) * (point_c[0] - point_b[0]) - (
        point_b[0] - point_a[0]
    ) * (point_c[1] - point_b[1])
    if value == 0.0:
        return 0
    return 1 if value > 0.0 else -1


def _on_segment(
    point_a: tuple[float, float],
    point_b: tuple[float, float],
    point_c: tuple[float, float],
) -> bool:
    return min(point_a[0], point_b[0]) <= point_c[0] <= max(
        point_a[0], point_b[0]
    ) and min(point_a[1], point_b[1]) <= point_c[1] <= max(point_a[1], point_b[1])


def _segment_intersects_segment(
    start_a: tuple[float, float],
    end_a: tuple[float, float],
    start_b: tuple[float, float],
    end_b: tuple[float, float],
) -> bool:
    if start_a == end_a or start_b == end_b:
        return False
    orientation_a = _orientation(start_a, end_a, start_b)
    orientation_b = _orientation(start_a, end_a, end_b)
    orientation_c = _orientation(start_b, end_b, start_a)
    orientation_d = _orientation(start_b, end_b, end_a)
    if orientation_a == 0 and _on_segment(start_a, end_a, start_b):
        return False
    if orientation_b == 0 and _on_segment(start_a, end_a, end_b):
        return False
    if orientation_c == 0 and _on_segment(start_b, end_b, start_a):
        return False
    if orientation_d == 0 and _on_segment(start_b, end_b, end_a):
        return False
    return orientation_a != orientation_b and orientation_c != orientation_d


def segment_intersects_bounds(
    start: tuple[float, float],
    end: tuple[float, float],
    left: float,
    top: float,
    right: float,
    bottom: float,
) -> bool:
    """Return True when a closed segment meets a closed axis-aligned rectangle.

    This is the single production algorithm for segment-rectangle contact. It
    uses Liang-Barsky parametric clipping, which resolves tangent and
    corner-grazing contact that an edge-enumeration test misses whenever the
    contact happens away from a segment endpoint. Contact is closed on both
    operands: a connector that runs exactly along a node border does overlap it
    visually, so it must count as intersecting.

    Callers hold rectangles in two different shapes, so they route through
    ``rect_bounds_from_ltwh`` or ``rect_bounds_from_ltrb`` rather than
    reimplementing the test.
    """
    start_x, start_y = start
    end_x, end_y = end
    delta_x = end_x - start_x
    delta_y = end_y - start_y
    # Liang-Barsky: each boundary contributes an inequality p*t <= q. A zero
    # p means the segment is parallel to that boundary, so a negative q puts it
    # wholly outside and no value of t can recover it.
    directions = (-delta_x, delta_x, -delta_y, delta_y)
    distances = (start_x - left, right - start_x, start_y - top, bottom - start_y)
    enter = 0.0
    exit_ = 1.0
    for direction, distance in zip(directions, distances, strict=True):
        if direction == 0:
            if distance < 0:
                return False
            continue
        parameter = distance / direction
        if direction < 0:
            enter = max(enter, parameter)
        else:
            exit_ = min(exit_, parameter)
        if enter > exit_:
            return False
    return True


def rect_bounds_from_ltwh(rect: dict[str, float]) -> tuple[float, float, float, float]:
    """Adapt a left/top/width/height mapping to closed bounds."""
    left = float(rect["left"])
    top = float(rect["top"])
    return (left, top, left + float(rect["width"]), top + float(rect["height"]))


def rect_bounds_from_ltrb(
    rect: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    """Adapt a left/top/right/bottom tuple to closed bounds."""
    return (float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))


def _segment_intersects_rect(
    start: tuple[float, float],
    end: tuple[float, float],
    rect: tuple[float, float, float, float],
) -> bool:
    return segment_intersects_bounds(start, end, *rect_bounds_from_ltrb(rect))


def load_layout_overlay(path: Path) -> dict[str, Any]:
    """Load a YAML or JSON overlay from disk.

    The file size is checked before parsing so an oversized overlay cannot be
    expanded in memory ahead of schema validation.

    Args:
        path: Overlay file to load.

    Returns:
        Parsed overlay mapping.

    Raises:
        FileNotFoundError: If the overlay does not exist.
        InputTooLargeError: If the overlay exceeds its documented ceiling.
        ValueError: If the overlay is not a mapping.
    """

    resolved_path = Path(path)
    if not resolved_path.exists():
        raise FileNotFoundError(resolved_path)
    data = read_bounded_bytes(resolved_path, MAX_SPEC_BYTES)
    text = data.decode("utf-8")
    if resolved_path.suffix.lower() == ".json":
        payload = json.loads(text)
    else:
        payload = yaml.safe_load(text)
    if not isinstance(payload, dict):
        raise ValueError("overlay must be a mapping")
    return payload


def validate_layout_overlay(overlay: dict[str, Any], context: OverlayContext) -> None:
    """Validate version 2 overlay shape, identities, geometry, and fingerprints."""

    if not isinstance(overlay, dict):
        raise ValueError("overlay must be a mapping")
    unknown_keys = set(overlay) - ALLOWED_TOP_LEVEL_OVERLAY_KEYS
    if unknown_keys:
        raise ValueError(f"unknown overlay keys: {sorted(unknown_keys)}")

    schema_version = overlay.get("schema_version")
    if schema_version != LAYOUT_OVERLAY_SCHEMA_VERSION:
        raise ValueError(f"schema_version must be {LAYOUT_OVERLAY_SCHEMA_VERSION}")

    overlay_type = overlay.get("overlay_type")
    if overlay_type != "tm7_layout_overlay":
        raise ValueError("overlay_type must be tm7_layout_overlay")

    model_id = overlay.get("model_id")
    if not isinstance(model_id, str) or not model_id:
        raise ValueError("model_id must be a non-empty string")
    if model_id != context.model_id:
        raise ValueError("overlay model_id does not match context")

    overlay_id = overlay.get("overlay_id")
    if not isinstance(overlay_id, str) or not overlay_id:
        raise ValueError("overlay_id must be a non-empty string")

    applies_to = overlay.get("applies_to")
    if not isinstance(applies_to, list) or not applies_to:
        raise ValueError("applies_to must be a non-empty list")
    for entry in applies_to:
        if not isinstance(entry, dict):
            raise ValueError("applies_to entries must be mappings")
        unknown_entry_keys = set(entry) - ALLOWED_APPLY_RULE_KEYS
        if unknown_entry_keys:
            raise ValueError(f"unknown applies_to keys: {sorted(unknown_entry_keys)}")
        surface_id = entry.get("surface_id")
        generator_profile = entry.get("generator_profile")
        if not isinstance(surface_id, str) or not surface_id:
            raise ValueError("surface_id must be non-empty")
        if surface_id not in context.surface_ids:
            raise ValueError(f"unknown surface_id: {surface_id}")
        if not isinstance(generator_profile, str) or not generator_profile:
            raise ValueError("generator_profile must be non-empty")

    def _require_finite_number(value: Any, *, field_name: str) -> float:
        if not _is_finite_number(value):
            raise ValueError(f"{field_name} must be a finite number")
        return float(value)

    def _require_rectangle(
        value: Any,
        *,
        field_name: str,
    ) -> tuple[float, float, float, float]:
        if not isinstance(value, dict):
            raise ValueError(f"{field_name} must be an object")
        left = _require_finite_number(
            value.get("left"),
            field_name=f"{field_name}.left",
        )
        top = _require_finite_number(
            value.get("top"),
            field_name=f"{field_name}.top",
        )
        width = _require_finite_number(
            value.get("width"),
            field_name=f"{field_name}.width",
        )
        height = _require_finite_number(
            value.get("height"),
            field_name=f"{field_name}.height",
        )
        if width <= 0 or height <= 0:
            raise ValueError(f"{field_name} must define positive width and height")
        return (left, top, left + width, top + height)

    def _require_point(value: Any, *, field_name: str) -> tuple[float, float]:
        if not isinstance(value, dict):
            raise ValueError(f"{field_name} must be an object")
        x = _require_finite_number(value.get("x"), field_name=f"{field_name}.x")
        y = _require_finite_number(value.get("y"), field_name=f"{field_name}.y")
        return (x, y)

    def _validate_rule_collection(
        *,
        collection_name: str,
        rules: Any,
        allowed_keys: set[str],
        target_key_name: str,
        target_validator: Any,
    ) -> None:
        if not isinstance(rules, list):
            raise ValueError(f"{collection_name} must be a list")
        seen_rule_keys: set[tuple[str, ...]] = set()
        for rule in rules:
            if not isinstance(rule, dict):
                raise ValueError(f"{collection_name} entries must be mappings")
            unknown_rule_keys = set(rule) - allowed_keys
            if unknown_rule_keys:
                raise ValueError(
                    f"unknown {collection_name} keys: {sorted(unknown_rule_keys)}"
                )
            surface_id = rule.get("surface_id")
            if not isinstance(surface_id, str) or not surface_id:
                raise ValueError(f"{collection_name} surface_id must be non-empty")
            if surface_id not in context.surface_ids:
                raise ValueError(f"unknown surface_id: {surface_id}")
            target_value = target_validator(rule)
            rule_key = (surface_id, target_value)
            if rule_key in seen_rule_keys:
                raise ValueError(f"duplicate {collection_name} target key")
            seen_rule_keys.add(rule_key)

    def _validate_zone_rule(rule: dict[str, Any]) -> str:
        zone_id = rule.get("zone_id")
        if not isinstance(zone_id, str) or not zone_id:
            raise ValueError("zone_rules zone_id must be non-empty")
        if zone_id not in context.surface_zone_ids.get(
            rule.get("surface_id", ""),
            set(),
        ):
            raise ValueError(f"unknown zone_id: {zone_id}")
        _require_rectangle(rule.get("region"), field_name="zone_rules.region")
        label_band_height = rule.get("label_band_height")
        _require_finite_number(
            label_band_height,
            field_name="zone_rules.label_band_height",
        )
        if label_band_height <= 0:
            raise ValueError("zone_rules.label_band_height must be positive")
        lane_order = rule.get("lane_order")
        if not isinstance(lane_order, list) or not lane_order:
            raise ValueError("zone_rules.lane_order must be a non-empty list")
        if any(not isinstance(item, str) or not item for item in lane_order):
            raise ValueError("zone_rules.lane_order must contain non-empty strings")
        return zone_id

    def _validate_node_rule(rule: dict[str, Any]) -> str:
        node_id = rule.get("node_id")
        if not isinstance(node_id, str) or not node_id:
            raise ValueError("node_rules node_id must be non-empty")
        if node_id not in context.surface_node_ids.get(
            rule.get("surface_id", ""),
            set(),
        ):
            raise ValueError(f"unknown node_id: {node_id}")
        layout_role = rule.get("layout_role")
        if layout_role not in ALLOWED_LAYOUT_ROLES:
            raise ValueError(
                "node_rules.layout_role must be main, "
                "contextual, suppressed, or connected"
            )
        absolute_position = rule.get("absolute_position")
        relative_placement = rule.get("relative_placement")
        if absolute_position is None and relative_placement is None:
            raise ValueError(
                "node_rules require absolute_position or relative_placement"
            )
        if absolute_position is not None and relative_placement is not None:
            raise ValueError(
                "node_rules cannot define both absolute_position and relative_placement"
            )
        if absolute_position is not None:
            _require_rectangle(
                {
                    "left": absolute_position.get("left"),
                    "top": absolute_position.get("top"),
                    "width": absolute_position.get("width"),
                    "height": absolute_position.get("height"),
                },
                field_name="node_rules.absolute_position",
            )
        if relative_placement is not None:
            if not isinstance(relative_placement, dict):
                raise ValueError("node_rules.relative_placement must be an object")
            relative_to = relative_placement.get("relative_to")
            if not isinstance(relative_to, str) or not relative_to:
                raise ValueError(
                    "node_rules.relative_placement.relative_to must be non-empty"
                )
            offset = relative_placement.get("offset")
            if not isinstance(offset, dict):
                raise ValueError(
                    "node_rules.relative_placement.offset must be an object"
                )
            _require_finite_number(
                offset.get("x"),
                field_name="node_rules.relative_placement.offset.x",
            )
            _require_finite_number(
                offset.get("y"),
                field_name="node_rules.relative_placement.offset.y",
            )
        return node_id

    def _validate_connector_rule(rule: dict[str, Any]) -> str:
        flow_id = rule.get("flow_id")
        if not isinstance(flow_id, str) or not flow_id:
            raise ValueError("connector_rules flow_id must be non-empty")
        if flow_id not in context.surface_flow_ids.get(
            rule.get("surface_id", ""),
            set(),
        ):
            raise ValueError(f"unknown flow_id: {flow_id}")
        if not isinstance(rule.get("source_port"), str) or not rule.get("source_port"):
            raise ValueError("connector_rules.source_port must be non-empty")
        if not isinstance(rule.get("target_port"), str) or not rule.get("target_port"):
            raise ValueError("connector_rules.target_port must be non-empty")
        _require_point(
            rule.get("handle_point"),
            field_name="connector_rules.handle_point",
        )
        if "label_offset" in rule and rule.get("label_offset") is not None:
            _require_point(
                rule.get("label_offset"),
                field_name="connector_rules.label_offset",
            )
        return flow_id

    def _validate_surface_rule(rule: dict[str, Any]) -> str:
        surface_id = rule.get("surface_id")
        if not isinstance(surface_id, str) or not surface_id:
            raise ValueError("surface_rules surface_id must be non-empty")
        if surface_id not in context.surface_ids:
            raise ValueError(f"unknown surface_id: {surface_id}")
        zone_order = rule.get("zone_order")
        if not isinstance(zone_order, list) or not zone_order:
            raise ValueError("surface_rules.zone_order must be a non-empty list")
        for zone_id in zone_order:
            if not isinstance(zone_id, str) or not zone_id:
                raise ValueError(
                    "surface_rules.zone_order must contain non-empty strings"
                )
            if zone_id not in context.surface_zone_ids.get(surface_id, set()):
                raise ValueError(f"unknown zone_id: {zone_id}")
        orientation = rule.get("orientation")
        if orientation not in ALLOWED_ORIENTATIONS:
            raise ValueError("surface_rules.orientation must be horizontal or vertical")
        _require_rectangle(
            rule.get("viewport_target"),
            field_name="surface_rules.viewport_target",
        )
        outer_margin = _require_finite_number(
            rule.get("outer_margin"),
            field_name="surface_rules.outer_margin",
        )
        if outer_margin < 0:
            raise ValueError("surface_rules.outer_margin must be non-negative")
        return surface_id

    zone_rules = overlay.get("zone_rules")
    _validate_rule_collection(
        collection_name="zone_rules",
        rules=zone_rules,
        allowed_keys=ALLOWED_ZONE_RULE_KEYS,
        target_key_name="zone_id",
        target_validator=_validate_zone_rule,
    )
    node_rules = overlay.get("node_rules")
    _validate_rule_collection(
        collection_name="node_rules",
        rules=node_rules,
        allowed_keys=ALLOWED_NODE_RULE_KEYS,
        target_key_name="node_id",
        target_validator=_validate_node_rule,
    )
    connector_rules = overlay.get("connector_rules")
    _validate_rule_collection(
        collection_name="connector_rules",
        rules=connector_rules,
        allowed_keys=ALLOWED_CONNECTOR_RULE_KEYS,
        target_key_name="flow_id",
        target_validator=_validate_connector_rule,
    )
    surface_rules = overlay.get("surface_rules")
    _validate_rule_collection(
        collection_name="surface_rules",
        rules=surface_rules,
        allowed_keys=ALLOWED_SURFACE_RULE_KEYS,
        target_key_name="surface_id",
        target_validator=_validate_surface_rule,
    )

    provenance = overlay.get("provenance")
    if not isinstance(provenance, dict):
        raise ValueError("provenance must be a mapping")
    unknown_provenance_keys = set(provenance) - ALLOWED_PROVENANCE_KEYS
    if unknown_provenance_keys:
        raise ValueError(f"unknown provenance keys: {sorted(unknown_provenance_keys)}")
    evidence_ref = provenance.get("evidence_ref")
    if not isinstance(evidence_ref, str) or not evidence_ref:
        raise ValueError("provenance.evidence_ref must be non-empty")
    evidence_ref = _normalize_path_reference(
        evidence_ref, field_name="provenance.evidence_ref"
    )
    provenance["evidence_ref"] = evidence_ref
    _validate_path_reference(evidence_ref, field_name="provenance.evidence_ref")
    generated_at = provenance.get("generated_at")
    if generated_at is None:
        generated_at = datetime.now(timezone.utc).isoformat()
    if isinstance(generated_at, datetime):
        generated_at = generated_at.isoformat()
    elif isinstance(generated_at, date):
        generated_at = generated_at.isoformat()
    if not isinstance(generated_at, str) or not generated_at:
        raise ValueError("provenance.generated_at must be non-empty")
    provenance["generated_at"] = generated_at
    approval_state = provenance.get("approval_state", "pending")
    if approval_state not in {"pending", "approved", "rejected"}:
        raise ValueError("approval_state must be pending, approved, or rejected")
    if approval_state != "pending":
        raise ValueError("automatically generated overlays must remain pending")

    invalidation = overlay.get("invalidation")
    if not isinstance(invalidation, dict):
        raise ValueError("invalidation must be a mapping")
    unknown_invalidation_keys = set(invalidation) - ALLOWED_INVALIDATION_KEYS
    if unknown_invalidation_keys:
        raise ValueError(
            f"unknown invalidation keys: {sorted(unknown_invalidation_keys)}"
        )
    spec_fingerprint = invalidation.get("spec_fingerprint")
    generator_profile_fingerprint = invalidation.get("generator_profile_fingerprint")
    surface_identity_fingerprint = invalidation.get("surface_identity_fingerprint")
    surface_zone_identity_fingerprint = invalidation.get(
        "surface_zone_identity_fingerprint"
    )
    surface_flow_identity_fingerprint = invalidation.get(
        "surface_flow_identity_fingerprint"
    )
    if not isinstance(spec_fingerprint, str) or not spec_fingerprint:
        raise ValueError("spec_fingerprint must be non-empty")
    if (
        not isinstance(generator_profile_fingerprint, str)
        or not generator_profile_fingerprint
    ):
        raise ValueError("generator_profile_fingerprint must be non-empty")
    if (
        not isinstance(surface_identity_fingerprint, str)
        or not surface_identity_fingerprint
    ):
        raise ValueError("surface_identity_fingerprint must be non-empty")
    if (
        not isinstance(surface_zone_identity_fingerprint, str)
        or not surface_zone_identity_fingerprint
    ):
        raise ValueError("surface_zone_identity_fingerprint must be non-empty")
    if (
        not isinstance(surface_flow_identity_fingerprint, str)
        or not surface_flow_identity_fingerprint
    ):
        raise ValueError("surface_flow_identity_fingerprint must be non-empty")
    if spec_fingerprint != context.spec_sha256:
        raise ValueError("spec fingerprint mismatch")
    if generator_profile_fingerprint != context.generator_profile_sha256:
        raise ValueError("generator profile fingerprint mismatch")
    if surface_identity_fingerprint != _fingerprint(
        {
            "surface_ids": sorted(context.surface_ids),
            "surface_node_ids": {
                key: sorted(value)
                for key, value in sorted(context.surface_node_ids.items())
            },
        }
    ):
        raise ValueError("surface identity fingerprint mismatch")
    if surface_zone_identity_fingerprint != _fingerprint(
        {
            "surface_ids": sorted(context.surface_ids),
            "surface_zone_ids": {
                key: sorted(value)
                for key, value in sorted(context.surface_zone_ids.items())
            },
        }
    ):
        raise ValueError("surface zone identity fingerprint mismatch")
    if surface_flow_identity_fingerprint != _fingerprint(
        {
            "surface_ids": sorted(context.surface_ids),
            "surface_flow_ids": {
                key: sorted(value)
                for key, value in sorted(context.surface_flow_ids.items())
            },
        }
    ):
        raise ValueError("surface flow identity fingerprint mismatch")


def _validate_layout_calibration_v1(value: Any) -> None:
    """Validate the versioned same-run calibration contract."""
    if not isinstance(value, dict):
        raise ValueError("layout_calibration_v1 must be a mapping")
    if value.get("contract") != "layout_calibration_v1":
        raise ValueError("layout_calibration_v1 contract must be layout_calibration_v1")
    if value.get("scope") != "same-run":
        raise ValueError("layout_calibration_v1 scope must be same-run")
    for key in (
        "viewport_target",
        "pane_rect",
        "scroll_percentages",
        "effective_scale",
        "screenshot_dimensions",
        "crop_dimensions",
        "confidence",
    ):
        if key not in value:
            raise ValueError(f"layout_calibration_v1 is missing {key}")
    viewport_target = value.get("viewport_target")
    if not isinstance(viewport_target, list) or len(viewport_target) != 4:
        raise ValueError("layout_calibration_v1 viewport_target must have 4 values")
    pane_rect = value.get("pane_rect")
    if not isinstance(pane_rect, list) or len(pane_rect) != 4:
        raise ValueError("layout_calibration_v1 pane_rect must have 4 values")
    if pane_rect[2] <= 0 or pane_rect[3] <= 0:
        raise ValueError(
            "layout_calibration_v1 pane_rect must describe a positive-sized pane"
        )
    scroll_percentages = value.get("scroll_percentages")
    if not isinstance(scroll_percentages, dict):
        raise ValueError("layout_calibration_v1 scroll_percentages must be a mapping")
    for key in ("horizontal", "vertical"):
        if key not in scroll_percentages:
            raise ValueError(f"layout_calibration_v1 scroll_percentages missing {key}")
    effective_scale = value.get("effective_scale")
    if not isinstance(effective_scale, dict):
        raise ValueError("layout_calibration_v1 effective_scale must be a mapping")
    for key in ("x", "y"):
        if key not in effective_scale:
            raise ValueError(f"layout_calibration_v1 effective_scale missing {key}")
    for key in ("screenshot_dimensions", "crop_dimensions"):
        dimensions = value.get(key)
        if not isinstance(dimensions, dict):
            raise ValueError(f"layout_calibration_v1 {key} must be a mapping")
        for dimension_key in ("width", "height"):
            if dimension_key not in dimensions:
                raise ValueError(f"layout_calibration_v1 {key} missing {dimension_key}")
    confidence = value.get("confidence")
    if not isinstance(confidence, dict):
        raise ValueError("layout_calibration_v1 confidence must be a mapping")
    for key in ("pane_measured", "scroll_interface_found", "consistent"):
        if key not in confidence:
            raise ValueError(f"layout_calibration_v1 confidence missing {key}")
    if not isinstance(confidence.get("pane_measured"), bool):
        raise ValueError(
            "layout_calibration_v1 confidence.pane_measured must be boolean"
        )
    if not isinstance(confidence.get("scroll_interface_found"), bool):
        raise ValueError(
            "layout_calibration_v1 confidence.scroll_interface_found must be boolean"
        )
    if not isinstance(confidence.get("consistent"), bool):
        raise ValueError("layout_calibration_v1 confidence.consistent must be boolean")
    if confidence.get("consistent") is False and not confidence.get("failure_reason"):
        raise ValueError(
            "layout_calibration_v1 must report a failure reason when inconsistent"
        )


def build_feedback_manifest(
    *,
    model_id: str,
    spec_path: str | Path,
    spec_sha256: str,
    generator_profile: str,
    generator_profile_sha256: str,
    candidate_sha256: str,
    iteration_id: str,
    pinned_tmt_version: str,
    surfaces: list[dict[str, Any]] | None = None,
    convergence: dict[str, Any] | None = None,
    created_at: str | None = None,
    layout_calibration_v1: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a feedback evidence manifest with stable versioned fields."""

    normalized_surfaces: list[dict[str, Any]] = []
    for surface in surfaces or []:
        normalized_surface = dict(surface)
        normalized_surface.setdefault("human_review_status", "pending")
        normalized_surface.setdefault("human_review_required", True)
        normalized_surfaces.append(normalized_surface)

    manifest = {
        "schema_version": FEEDBACK_MANIFEST_SCHEMA_VERSION,
        "manifest_type": "tm7_visual_feedback",
        "model_id": model_id,
        "spec_path": str(spec_path),
        "spec_sha256": spec_sha256,
        "generator_profile": generator_profile,
        "generator_profile_sha256": generator_profile_sha256,
        "candidate_sha256": candidate_sha256,
        "iteration_id": iteration_id,
        "pinned_tmt_version": pinned_tmt_version,
        "created_at": created_at or "1970-01-01T00:00:00Z",
        "surfaces": normalized_surfaces,
        "convergence": convergence or {"status": "pending"},
    }
    if layout_calibration_v1 is not None:
        _validate_layout_calibration_v1(layout_calibration_v1)
        manifest["layout_calibration_v1"] = layout_calibration_v1
    return manifest


def validate_feedback_manifest(manifest: dict[str, Any]) -> None:
    """Validate manifest version, pending-human status, and convergence shape."""

    if not isinstance(manifest, dict):
        raise ValueError("manifest must be a mapping")
    # Mirrors the overlay path, which rejects unknown top-level keys against
    # its own allow-list. The manifest allow-list was declared alongside it but
    # never consulted, so a typo or a stale key reached evidence unchallenged.
    unknown_keys = set(manifest) - ALLOWED_MANIFEST_TOP_LEVEL_KEYS
    if unknown_keys:
        raise ValueError(f"unknown manifest keys: {', '.join(sorted(unknown_keys))}")
    if manifest.get("schema_version") != FEEDBACK_MANIFEST_SCHEMA_VERSION:
        raise ValueError(f"schema_version must be {FEEDBACK_MANIFEST_SCHEMA_VERSION}")
    candidate_sha256 = manifest.get("candidate_sha256")
    if not isinstance(candidate_sha256, str) or len(candidate_sha256) != 64:
        raise ValueError("candidate_sha256 must be an exact SHA-256 fingerprint")
    if any(character not in "0123456789abcdef" for character in candidate_sha256):
        raise ValueError("candidate_sha256 must be lowercase hexadecimal")
    surfaces = manifest.get("surfaces")
    if not isinstance(surfaces, list):
        raise ValueError("surfaces must be a list")
    for surface in surfaces:
        if not isinstance(surface, dict):
            raise ValueError("surface entries must be mappings")
        if surface.get("human_review_status") != "pending":
            raise ValueError("human_review_status must be pending")
        if surface.get("human_review_required") is not True:
            raise ValueError("human_review_required must be true")
    if "layout_calibration_v1" in manifest:
        _validate_layout_calibration_v1(manifest.get("layout_calibration_v1"))
    convergence = manifest.get("convergence")
    if not isinstance(convergence, dict):
        raise ValueError("convergence must be a mapping")
    if convergence.get("status") not in {
        "pending",
        "automated-ready-pending-human",
        "stopped",
    }:
        raise ValueError("convergence status must remain pending human review")
    if not isinstance(convergence.get("selected_candidate"), (str, type(None))):
        raise ValueError("selected_candidate must be a string or null")
    if not isinstance(convergence.get("stop_reason"), str) or not convergence.get(
        "stop_reason"
    ):
        raise ValueError("stop_reason must be a non-empty string")


def _rect_intersection_area(
    left_a: float,
    top_a: float,
    right_a: float,
    bottom_a: float,
    left_b: float,
    top_b: float,
    right_b: float,
    bottom_b: float,
) -> float:
    overlap_left = max(left_a, left_b)
    overlap_top = max(top_a, top_b)
    overlap_right = min(right_a, right_b)
    overlap_bottom = min(bottom_a, bottom_b)
    if overlap_right <= overlap_left or overlap_bottom <= overlap_top:
        return 0.0
    return (overlap_right - overlap_left) * (overlap_bottom - overlap_top)


def _union_area_of_rectangles(
    rectangles: list[tuple[float, float, float, float]],
) -> float:
    """Compute the union area of axis-aligned rectangles deterministically."""

    if not rectangles:
        return 0.0
    x_coords = sorted({x for rect in rectangles for x in (rect[0], rect[2])})
    if len(x_coords) < 2:
        return 0.0
    area = 0.0
    for index in range(len(x_coords) - 1):
        left = x_coords[index]
        right = x_coords[index + 1]
        if right <= left:
            continue
        vertical_segments = [
            (top, bottom)
            for rect_left, rect_top, rect_right, rect_bottom in rectangles
            if rect_left <= left and rect_right >= right
            for top, bottom in [(rect_top, rect_bottom)]
        ]
        if not vertical_segments:
            continue
        y_coords = sorted({y for segment in vertical_segments for y in segment})
        for y_index in range(len(y_coords) - 1):
            bottom = y_coords[y_index]
            top = y_coords[y_index + 1]
            if top <= bottom:
                continue
            if any(
                segment_top <= bottom and segment_bottom >= top
                for segment_top, segment_bottom in vertical_segments
            ):
                area += (right - left) * (top - bottom)
    return area


def _point_to_segment_distance(
    point: tuple[float, float],
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    """Return the shortest distance from a point to a line segment."""

    segment_x = end[0] - start[0]
    segment_y = end[1] - start[1]
    if segment_x == 0.0 and segment_y == 0.0:
        return math.hypot(point[0] - start[0], point[1] - start[1])
    projection = (
        (point[0] - start[0]) * segment_x + (point[1] - start[1]) * segment_y
    ) / (segment_x * segment_x + segment_y * segment_y)
    projection = max(0.0, min(1.0, projection))
    closest_x = start[0] + projection * segment_x
    closest_y = start[1] + projection * segment_y
    return math.hypot(point[0] - closest_x, point[1] - closest_y)


def _rect_to_segment_distance(
    rect: tuple[float, float, float, float],
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    """Return the shortest distance from a rectangle to a line segment.

    Ownership is judged from the label's nearest point so a wide label whose
    edge hugs its connector is not treated as orphaned for being wide.
    """
    left, top, right, bottom = rect
    if _segment_intersects_rect(start, end, rect):
        return 0.0
    corners = [
        (left, top),
        (right, top),
        (right, bottom),
        (left, bottom),
    ]
    edges = [
        ((left, top), (right, top)),
        ((right, top), (right, bottom)),
        ((right, bottom), (left, bottom)),
        ((left, bottom), (left, top)),
    ]
    distances = [_point_to_segment_distance(corner, start, end) for corner in corners]
    distances.extend(
        _point_to_segment_distance(point, edge_start, edge_end)
        for point in (start, end)
        for edge_start, edge_end in edges
    )
    return min(distances)


def _route_legs(
    route: dict[str, Any],
) -> list[tuple[tuple[float, float], tuple[float, float]]]:
    """Return the ordered source-handle-target legs for a connector route."""

    source_point = tuple(
        float(value) for value in route.get("source_point", (0.0, 0.0))
    )
    target_point = tuple(
        float(value) for value in route.get("target_point", (0.0, 0.0))
    )
    handle_point = route.get("handle_point")
    if handle_point is None:
        return [(source_point, target_point)]
    handle = tuple(float(value) for value in handle_point)
    return [(source_point, handle), (handle, target_point)]


def _quantize_point(point: tuple[float, float], *, step: float) -> tuple[int, int]:
    return (int(round(point[0] / step)), int(round(point[1] / step)))


def derive_composition_metrics(surface_geometry: SurfaceGeometry) -> dict[str, Any]:
    """Derive deterministic composition metrics for whole-surface readability."""

    routes = surface_geometry.connector_routes
    orientation = str(surface_geometry.orientation or "horizontal").lower()
    flow_axis_is_horizontal = orientation != "vertical"

    visible_clipping_count = 0
    visible_coverage_ratio = 1.0
    viewport_fill_ratio = 1.0
    viewport_fill_width_ratio = 1.0
    viewport_fill_height_ratio = 1.0
    viewport = surface_geometry.viewport_target
    if viewport is not None:
        view_left, view_top, view_width, view_height = (float(v) for v in viewport)
        view_right = view_left + view_width
        view_bottom = view_top + view_height
        # Content extent against the calibrated pane. A layout that occupies a
        # small fraction of the available canvas crowds nodes, labels, and
        # routes together while leaving the rest of the surface empty.
        extent_rects = list(surface_geometry.node_rects.values()) + list(
            surface_geometry.boundary_rects.values()
        )
        if extent_rects and view_width > 0.0 and view_height > 0.0:
            content_left = min(rect[0] for rect in extent_rects)
            content_top = min(rect[1] for rect in extent_rects)
            content_right = max(rect[2] for rect in extent_rects)
            content_bottom = max(rect[3] for rect in extent_rects)
            viewport_fill_width_ratio = min(
                1.0,
                max(0.0, content_right - content_left) / view_width,
            )
            viewport_fill_height_ratio = min(
                1.0,
                max(0.0, content_bottom - content_top) / view_height,
            )
            viewport_fill_ratio = viewport_fill_width_ratio * viewport_fill_height_ratio
        rendered_rects = list(surface_geometry.node_rects.values()) + list(
            surface_geometry.connector_label_rects.values()
        )
        visible_area = 0.0
        total_area = 0.0
        for left, top, right, bottom in rendered_rects:
            area = max(0.0, right - left) * max(0.0, bottom - top)
            if area <= 0.0:
                continue
            total_area += area
            visible_area += _rect_intersection_area(
                left,
                top,
                right,
                bottom,
                view_left,
                view_top,
                view_right,
                view_bottom,
            )
            if (
                left < view_left
                or top < view_top
                or right > view_right
                or bottom > view_bottom
            ):
                visible_clipping_count += 1
        if total_area > 0.0:
            visible_coverage_ratio = visible_area / total_area

    backward_edge_count = 0
    node_ranks = surface_geometry.node_ranks
    for flow_id in sorted(routes):
        route = routes[flow_id]
        source_id = str(route.get("source_id", ""))
        target_id = str(route.get("target_id", ""))
        if source_id in node_ranks and target_id in node_ranks:
            if node_ranks[target_id] < node_ranks[source_id]:
                backward_edge_count += 1
            continue
        legs = _route_legs(route)
        span = (
            legs[-1][1][0] - legs[0][0][0]
            if flow_axis_is_horizontal
            else legs[-1][1][1] - legs[0][0][1]
        )
        if span < 0.0:
            backward_edge_count += 1

    # Handles that land on the same quantized point are visually indistinguishable
    # in native TMT because the tool renders a single draggable midpoint marker.
    handle_clusters: dict[tuple[int, int], int] = {}
    for flow_id in sorted(routes):
        handle_point = routes[flow_id].get("handle_point")
        if handle_point is None:
            continue
        key = _quantize_point(
            (float(handle_point[0]), float(handle_point[1])),
            step=HANDLE_CLUSTER_STEP,
        )
        handle_clusters[key] = handle_clusters.get(key, 0) + 1
    max_handle_cluster_size = max(handle_clusters.values(), default=0)

    leg_keys: dict[tuple[int, int, int, int], int] = {}
    for flow_id in sorted(routes):
        for leg_start, leg_end in _route_legs(routes[flow_id]):
            start_key = _quantize_point(leg_start, step=HANDLE_CLUSTER_STEP)
            end_key = _quantize_point(leg_end, step=HANDLE_CLUSTER_STEP)
            ordered = (
                (start_key, end_key) if start_key <= end_key else (end_key, start_key)
            )
            key = (ordered[0][0], ordered[0][1], ordered[1][0], ordered[1][1])
            leg_keys[key] = leg_keys.get(key, 0) + 1
    duplicate_route_leg_count = sum(
        count - 1 for count in leg_keys.values() if count > 1
    )

    max_label_ownership_distance = 0.0
    min_label_arrowhead_clearance = math.inf
    ownership_offender_flow_id = ""
    arrowhead_offender_flow_id = ""
    scored_label_count = 0
    for flow_id in sorted(surface_geometry.connector_label_rects):
        route = routes.get(flow_id)
        if route is None:
            continue
        scored_label_count += 1
        left, top, right, bottom = surface_geometry.connector_label_rects[flow_id]
        center = ((left + right) / 2.0, (top + bottom) / 2.0)
        legs = _route_legs(route)
        ownership_distance = min(
            _rect_to_segment_distance((left, top, right, bottom), leg_start, leg_end)
            for leg_start, leg_end in legs
        )
        if ownership_distance > max_label_ownership_distance:
            max_label_ownership_distance = ownership_distance
            ownership_offender_flow_id = flow_id
        target_point = tuple(
            float(value) for value in route.get("target_point", (0.0, 0.0))
        )
        arrowhead_clearance = math.hypot(
            center[0] - target_point[0],
            center[1] - target_point[1],
        )
        if arrowhead_clearance < min_label_arrowhead_clearance:
            min_label_arrowhead_clearance = arrowhead_clearance
            arrowhead_offender_flow_id = flow_id
    if not math.isfinite(min_label_arrowhead_clearance):
        min_label_arrowhead_clearance = 0.0

    # Nodes in one branch group should share a cross-axis lane so the eye can
    # follow a branch without re-scanning the surface.
    branch_lane_positions: dict[int, list[float]] = {}
    for node_id, rect in sorted(surface_geometry.node_rects.items()):
        if node_id not in surface_geometry.branch_groups:
            continue
        group_id = int(surface_geometry.branch_groups[node_id])
        left, top, right, bottom = rect
        cross_axis_center = (
            (top + bottom) / 2.0 if flow_axis_is_horizontal else (left + right) / 2.0
        )
        branch_lane_positions.setdefault(group_id, []).append(cross_axis_center)
    branch_alignment_variance = 0.0
    for positions in branch_lane_positions.values():
        if len(positions) < 2:
            continue
        mean = sum(positions) / len(positions)
        variance = sum((value - mean) ** 2 for value in positions) / len(positions)
        branch_alignment_variance = max(branch_alignment_variance, variance)

    ordered_pairs = 0
    monotonic_pairs = 0
    ranked_nodes = [
        node_id
        for node_id in sorted(surface_geometry.node_rects)
        if node_id in node_ranks
    ]
    for index, node_id_a in enumerate(ranked_nodes):
        for node_id_b in ranked_nodes[index + 1 :]:
            rank_a = node_ranks[node_id_a]
            rank_b = node_ranks[node_id_b]
            if rank_a == rank_b:
                continue
            rect_a = surface_geometry.node_rects[node_id_a]
            rect_b = surface_geometry.node_rects[node_id_b]
            if flow_axis_is_horizontal:
                position_a = (rect_a[0] + rect_a[2]) / 2.0
                position_b = (rect_b[0] + rect_b[2]) / 2.0
            else:
                position_a = (rect_a[1] + rect_a[3]) / 2.0
                position_b = (rect_b[1] + rect_b[3]) / 2.0
            ordered_pairs += 1
            if (rank_b - rank_a) * (position_b - position_a) > 0.0:
                monotonic_pairs += 1
    rank_monotonicity_ratio = monotonic_pairs / ordered_pairs if ordered_pairs else 1.0

    zone_fill_ratios: list[float] = []
    for zone_id, zone_rect in sorted(surface_geometry.zone_content_rects.items()):
        zone_area = max(0.0, zone_rect[2] - zone_rect[0]) * max(
            0.0,
            zone_rect[3] - zone_rect[1],
        )
        if zone_area <= 0.0:
            continue
        member_rects = [
            rect
            for node_id, rect in surface_geometry.node_rects.items()
            if surface_geometry.zone_membership.get(node_id) == zone_id
        ]
        if not member_rects:
            continue
        occupied_area = _union_area_of_rectangles(member_rects)
        zone_fill_ratios.append(min(1.0, occupied_area / zone_area))
    zone_whitespace_imbalance = (
        max(zone_fill_ratios) - min(zone_fill_ratios) if zone_fill_ratios else 0.0
    )

    # A connector endpoint must sit on the node it belongs to. An endpoint that
    # floats away renders as a line pointing at a shape rather than joined to
    # it, which is a semantic defect rather than an aesthetic one.
    detached_endpoint_count = 0
    detached_endpoint_flow_id = ""
    detached_endpoint_node_id = ""
    max_endpoint_gap = 0.0
    for flow_id in sorted(routes):
        route = routes[flow_id]
        for role, point_key in (
            ("source_id", "source_point"),
            ("target_id", "target_point"),
        ):
            node_id = str(route.get(role, ""))
            rect = surface_geometry.node_rects.get(node_id)
            point = route.get(point_key)
            if rect is None or not isinstance(point, (list, tuple)):
                continue
            left, top, right, bottom = rect
            gap_x = max(left - float(point[0]), 0.0, float(point[0]) - right)
            gap_y = max(top - float(point[1]), 0.0, float(point[1]) - bottom)
            gap = max(gap_x, gap_y)
            if gap > MAX_ENDPOINT_ATTACHMENT_GAP:
                detached_endpoint_count += 1
                if gap > max_endpoint_gap:
                    max_endpoint_gap = gap
                    detached_endpoint_flow_id = flow_id
                    detached_endpoint_node_id = node_id

    return {
        "visible_clipping_count": visible_clipping_count,
        "visible_coverage_ratio": visible_coverage_ratio,
        "detached_endpoint_count": detached_endpoint_count,
        "detached_endpoint_flow_id": detached_endpoint_flow_id,
        "detached_endpoint_node_id": detached_endpoint_node_id,
        "max_endpoint_gap": max_endpoint_gap,
        "viewport_fill_ratio": viewport_fill_ratio,
        "viewport_fill_width_ratio": viewport_fill_width_ratio,
        "viewport_fill_height_ratio": viewport_fill_height_ratio,
        "backward_edge_count": backward_edge_count,
        "max_handle_cluster_size": max_handle_cluster_size,
        "duplicate_route_leg_count": duplicate_route_leg_count,
        "max_label_ownership_distance": max_label_ownership_distance,
        "min_label_arrowhead_clearance": min_label_arrowhead_clearance,
        "branch_alignment_variance": branch_alignment_variance,
        "rank_monotonicity_ratio": rank_monotonicity_ratio,
        "zone_whitespace_imbalance": zone_whitespace_imbalance,
        "connector_label_count": scored_label_count,
        "label_ownership_flow_id": ownership_offender_flow_id,
        "label_arrowhead_flow_id": arrowhead_offender_flow_id,
        "coordinate_space": "tm7-model",
    }


def derive_geometry_metrics(surface_geometry: SurfaceGeometry) -> dict[str, Any]:
    """Derive deterministic geometry metrics from a surface geometry snapshot."""

    node_rects = surface_geometry.node_rects
    affected_node_ids: set[str] = set()
    boundary_ids = sorted(surface_geometry.boundary_rects)
    boundary_overlap_count = 0
    boundary_gaps: list[float] = []

    def _is_zone_ancestor(ancestor_id: str, descendant_id: str) -> bool:
        parent_id = surface_geometry.zone_parent_map.get(descendant_id)
        visited: set[str] = set()
        while parent_id and parent_id not in visited:
            if parent_id == ancestor_id:
                return True
            visited.add(parent_id)
            parent_id = surface_geometry.zone_parent_map.get(parent_id)
        return False

    for index, boundary_id in enumerate(boundary_ids):
        left_a, top_a, right_a, bottom_a = surface_geometry.boundary_rects[boundary_id]
        for other_id in boundary_ids[index + 1 :]:
            left_b, top_b, right_b, bottom_b = surface_geometry.boundary_rects[other_id]
            if _is_zone_ancestor(boundary_id, other_id) or _is_zone_ancestor(
                other_id,
                boundary_id,
            ):
                continue
            if (
                _rect_intersection_area(
                    left_a,
                    top_a,
                    right_a,
                    bottom_a,
                    left_b,
                    top_b,
                    right_b,
                    bottom_b,
                )
                > 0.0
            ):
                boundary_overlap_count += 1
                continue
            horizontal_gap = max(0.0, left_b - right_a, left_a - right_b)
            vertical_gap = max(0.0, top_b - bottom_a, top_a - bottom_b)
            boundary_gaps.append(math.hypot(horizontal_gap, vertical_gap))

    node_outside_zone_count = 0
    for node_id, rect in node_rects.items():
        zone_id = surface_geometry.zone_membership.get(node_id)
        if not zone_id:
            continue
        zone_rect = surface_geometry.zone_content_rects.get(zone_id)
        if zone_rect is None:
            continue
        left, top, right, bottom = rect
        zone_left, zone_top, zone_right, zone_bottom = zone_rect
        if not (
            zone_left <= left
            and zone_top <= top
            and right <= zone_right
            and bottom <= zone_bottom
        ):
            node_outside_zone_count += 1
            affected_node_ids.add(node_id)

    boundary_label_intersections = 0
    for rect in node_rects.values():
        for label_rect in surface_geometry.boundary_label_rects.values():
            if _rect_intersection_area(*rect, *label_rect) > 0.0:
                boundary_label_intersections += 1
                break
    for label_rect in surface_geometry.connector_label_rects.values():
        for boundary_label_rect in surface_geometry.boundary_label_rects.values():
            if _rect_intersection_area(*label_rect, *boundary_label_rect) > 0.0:
                boundary_label_intersections += 1
                break

    connector_label_intersections = 0
    for label_id, label_rect in surface_geometry.connector_label_rects.items():
        label_hit = False
        for node_rect in node_rects.values():
            if _rect_intersection_area(*label_rect, *node_rect) > 0.0:
                label_hit = True
                break
        if not label_hit:
            for boundary_label_rect in surface_geometry.boundary_label_rects.values():
                if _rect_intersection_area(*label_rect, *boundary_label_rect) > 0.0:
                    label_hit = True
                    break
        if not label_hit:
            for (
                other_label_id,
                other_label_rect,
            ) in surface_geometry.connector_label_rects.items():
                if other_label_id == label_id:
                    continue
                if _rect_intersection_area(*label_rect, *other_label_rect) > 0.0:
                    label_hit = True
                    break
        if label_hit:
            connector_label_intersections += 1

    canvas_rect: tuple[float, float, float, float] | None = None
    if surface_geometry.diagram_bounds is not None:
        canvas_rect = surface_geometry.diagram_bounds
    else:
        points: list[tuple[float, float]] = []
        for left, top, right, bottom in node_rects.values():
            points.append((left, top))
            points.append((right, bottom))
        for _, _, start, end in surface_geometry.connector_segments:
            points.append(start)
            points.append(end)
        if points:
            min_x = min(point[0] for point in points)
            min_y = min(point[1] for point in points)
            max_x = max(point[0] for point in points)
            max_y = max(point[1] for point in points)
            margin = surface_geometry.outer_margin
            canvas_rect = (
                min_x - margin,
                min_y - margin,
                max_x + margin,
                max_y + margin,
            )
    clipping_count = 0
    if canvas_rect is not None:
        canvas_left, canvas_top, canvas_right, canvas_bottom = canvas_rect
        for rect in node_rects.values():
            left, top, right, bottom = rect
            if (
                left < canvas_left
                or top < canvas_top
                or right > canvas_right
                or bottom > canvas_bottom
            ):
                clipping_count += 1
        for _, _, start, end in surface_geometry.connector_segments:
            for point in (start, end):
                if (
                    point[0] < canvas_left
                    or point[1] < canvas_top
                    or point[0] > canvas_right
                    or point[1] > canvas_bottom
                ):
                    clipping_count += 1

    viewport_width = 0.0
    viewport_height = 0.0
    if surface_geometry.viewport_target is not None:
        _, _, viewport_width, viewport_height = surface_geometry.viewport_target
    scroll_extent_ratio_x = 0.0
    scroll_extent_ratio_y = 0.0
    if canvas_rect is not None:
        canvas_width = max(0.0, canvas_rect[2] - canvas_rect[0])
        canvas_height = max(0.0, canvas_rect[3] - canvas_rect[1])
        if viewport_width > 0.0:
            scroll_extent_ratio_x = canvas_width / viewport_width
        if viewport_height > 0.0:
            scroll_extent_ratio_y = canvas_height / viewport_height

    unclassified_isolated_node_count = 0
    contextual_island_count = 0
    for node_id, rect in node_rects.items():
        role = surface_geometry.layout_roles.get(node_id, "")
        degree = sum(
            1
            for source_id, target_id, _, _ in surface_geometry.connector_segments
            if node_id in {source_id, target_id}
        )
        if role in {"connected", "contextual", "suppressed"}:
            pass
        elif degree == 0:
            unclassified_isolated_node_count += 1
        if role == "contextual" and degree == 0:
            contextual_island_count += 1

    expected_nodes = surface_geometry.expected_semantic_node_ids
    expected_flows = surface_geometry.expected_semantic_flow_ids
    rendered_semantic_node_coverage = 1.0
    if expected_nodes:
        rendered_semantic_nodes = {
            node_id for node_id in node_rects if node_id in expected_nodes
        }
        rendered_semantic_node_coverage = len(rendered_semantic_nodes) / len(
            expected_nodes
        )
    emitted_selected_flow_coverage = 1.0
    if expected_flows:
        emitted_selected_flow_coverage = len(
            surface_geometry.selected_flow_ids & expected_flows
        ) / len(expected_flows)
    semantic_flow_coverage = min(
        rendered_semantic_node_coverage,
        emitted_selected_flow_coverage,
    )

    empty_zone_ratio = 0.0
    unoccupied_zone_count = 0
    for zone_id, zone_rect in surface_geometry.zone_content_rects.items():
        content_area = max(
            0.0,
            (zone_rect[2] - zone_rect[0]) * (zone_rect[3] - zone_rect[1]),
        )
        if content_area <= 0.0:
            continue
        zone_rectangles = [
            rect
            for node_id, rect in node_rects.items()
            if surface_geometry.zone_membership.get(node_id) == zone_id
            or _is_zone_ancestor(
                zone_id,
                surface_geometry.zone_membership.get(node_id, ""),
            )
        ]
        if not zone_rectangles:
            unoccupied_zone_count += 1
        union_area = _union_area_of_rectangles(zone_rectangles)
        empty_zone_ratio = max(
            empty_zone_ratio,
            max(0.0, (content_area - union_area) / content_area),
        )

    overlap_ratio = 0.0
    node_pairs = list(node_rects.items())
    for index, (node_id_a, rect_a) in enumerate(node_pairs):
        left_a, top_a, right_a, bottom_a = rect_a
        for node_id_b, rect_b in node_pairs[index + 1 :]:
            left_b, top_b, right_b, bottom_b = rect_b
            overlap_area = _rect_intersection_area(
                left_a,
                top_a,
                right_a,
                bottom_a,
                left_b,
                top_b,
                right_b,
                bottom_b,
            )
            if overlap_area <= 0.0:
                continue
            area_a = max(0.0, right_a - left_a) * max(0.0, bottom_a - top_a)
            area_b = max(0.0, right_b - left_b) * max(0.0, bottom_b - top_b)
            smaller_area = min(area_a, area_b)
            if smaller_area <= 0.0:
                continue
            overlap_ratio = max(overlap_ratio, overlap_area / smaller_area)

    edge_node_intersections = 0
    for source_id, target_id, start, end in surface_geometry.connector_segments:
        for node_id, rect in node_rects.items():
            if node_id in {source_id, target_id}:
                continue
            if _segment_intersects_rect(start, end, rect):
                edge_node_intersections += 1
                break

    edge_crossing_count = 0
    connector_segments = list(surface_geometry.connector_segments)
    for index, (source_id_a, target_id_a, start_a, end_a) in enumerate(
        connector_segments
    ):
        for source_id_b, target_id_b, start_b, end_b in connector_segments[index + 1 :]:
            if _segment_intersects_segment(start_a, end_a, start_b, end_b):
                edge_crossing_count += 1

    min_spacing_ratio = 1.0
    if surface_geometry.nominal_node_size > 0.0:
        node_pairs = list(node_rects.items())
        for index, (node_id_a, rect_a) in enumerate(node_pairs):
            left_a, top_a, right_a, bottom_a = rect_a
            for node_id_b, rect_b in node_pairs[index + 1 :]:
                left_b, top_b, right_b, bottom_b = rect_b
                overlap_area = _rect_intersection_area(
                    left_a,
                    top_a,
                    right_a,
                    bottom_a,
                    left_b,
                    top_b,
                    right_b,
                    bottom_b,
                )
                if overlap_area > 0.0:
                    continue
                distance_x = max(0.0, left_b - right_a, left_a - right_b)
                distance_y = max(0.0, top_b - bottom_a, top_a - bottom_b)
                distance = math.hypot(distance_x, distance_y)
                min_spacing_ratio = min(
                    min_spacing_ratio,
                    distance / surface_geometry.nominal_node_size,
                )

    return {
        "surface_id": surface_geometry.surface_id,
        "overlap_ratio": overlap_ratio,
        "edge_node_intersections": edge_node_intersections,
        "edge_crossing_count": edge_crossing_count,
        "min_spacing_ratio": min_spacing_ratio,
        "boundary_count": len(boundary_ids),
        "boundary_overlap_count": boundary_overlap_count,
        "boundary_min_gutter": min(boundary_gaps) if boundary_gaps else 0.0,
        "node_outside_zone_count": node_outside_zone_count,
        "boundary_label_intersections": boundary_label_intersections,
        "connector_label_intersections": connector_label_intersections,
        "canvas_clipping_count": clipping_count,
        "scroll_extent_ratio_x": scroll_extent_ratio_x,
        "scroll_extent_ratio_y": scroll_extent_ratio_y,
        "unclassified_isolated_node_count": unclassified_isolated_node_count,
        "contextual_island_count": contextual_island_count,
        "semantic_flow_coverage": semantic_flow_coverage,
        "empty_zone_ratio": empty_zone_ratio,
        "unoccupied_zone_count": unoccupied_zone_count,
        "affected_node_ids": sorted(affected_node_ids),
        **derive_composition_metrics(surface_geometry),
    }


def derive_image_metrics(image_path: Path, viewport: ViewportBounds) -> dict[str, Any]:
    """Derive advisory screenshot heuristics without requiring image libraries."""

    resolved_path = Path(image_path)
    if resolved_path.exists():
        payload = resolved_path.read_bytes()
        capture_status = "ok"
    else:
        payload = b""
        capture_status = "missing"
    is_all_background = _is_background_bytes(payload)
    severity = "review" if is_all_background else "pass"
    return {
        "capture_status": capture_status,
        "viewport": {
            "left": viewport.left,
            "top": viewport.top,
            "width": viewport.width,
            "height": viewport.height,
        },
        "is_all_background": is_all_background,
        "severity": severity,
        "evidence_path": str(resolved_path),
    }


def derive_findings(metrics: dict[str, Any], *, density: str) -> list[dict[str, Any]]:
    """Map geometry and image metrics to gate, warn, and review findings."""

    findings: list[dict[str, Any]] = []
    surface_id = str(metrics.get("surface_id", "unknown"))
    node_id = str(metrics.get("node_id", "unknown"))
    flow_id = str(metrics.get("flow_id", "unknown"))
    evidence_path = str(metrics.get("evidence_path", ""))
    coordinate_space = str(metrics.get("coordinate_space", "tm7-model"))

    def _append_metric(
        *,
        metric_name: str,
        metric_value: Any,
        threshold: float,
        severity: str,
        category: str,
        owning_flow_id: str | None = None,
        owning_node_id: str | None = None,
    ) -> None:
        # A metric that knows which node or flow it concerns says so. The
        # surface-level defaults are a fallback, and pairing them with an
        # unrelated metric asserts a relationship the measurement never
        # established.
        findings.append(
            {
                "surface_id": surface_id,
                "node_id": owning_node_id or node_id,
                "flow_id": owning_flow_id or flow_id,
                "node_id_attributed": owning_node_id is not None,
                "flow_id_attributed": owning_flow_id is not None,
                "metric_name": metric_name,
                "metric_value": metric_value,
                "threshold": threshold,
                "severity": severity,
                "evidence_path": evidence_path,
                "category": category,
                "coordinate_space": coordinate_space,
            }
        )

    if "overlap_ratio" in metrics:
        overlap_ratio = float(metrics.get("overlap_ratio", 0.0))
        if overlap_ratio > 0.03:
            severity = "review"
        elif overlap_ratio >= 0.01:
            severity = "warn"
        else:
            severity = "pass"
        _append_metric(
            metric_name="overlap_ratio",
            metric_value=overlap_ratio,
            threshold=0.03,
            severity=severity,
            category="node_overlap",
        )

    if "boundary_overlap_count" in metrics:
        boundary_overlap_count = int(metrics.get("boundary_overlap_count", 0))
        _append_metric(
            metric_name="boundary_overlap_count",
            metric_value=boundary_overlap_count,
            threshold=0,
            severity="review" if boundary_overlap_count > 0 else "pass",
            category="boundary_overlap",
        )

    if "boundary_min_gutter" in metrics:
        boundary_min_gutter = float(metrics.get("boundary_min_gutter", 0.0))
        boundary_count = int(metrics.get("boundary_count", 0))
        if boundary_count < 2 or not math.isfinite(boundary_min_gutter):
            severity = "pass"
        elif boundary_min_gutter < 24.0:
            severity = "review"
        else:
            severity = "pass"
        _append_metric(
            metric_name="boundary_min_gutter",
            metric_value=boundary_min_gutter,
            threshold=24.0,
            severity=severity,
            category="boundary_gutter",
        )

    if "node_outside_zone_count" in metrics:
        node_outside_zone_count = int(metrics.get("node_outside_zone_count", 0))
        _append_metric(
            metric_name="node_outside_zone_count",
            metric_value=node_outside_zone_count,
            threshold=0,
            severity="review" if node_outside_zone_count > 0 else "pass",
            category="zone_containment",
        )

    # Predicted-label gates are advisory. The TM7 format persists no connector
    # label geometry, so TMT derives label position from the connector handle
    # at render time and never reads these rectangles. Blocking on them
    # produced false confidence: they reported clean surfaces that contained
    # visible label collisions. Rendered-label measurement is tracked as
    # follow-on work; until then these values are reported, not enforced.
    if "boundary_label_intersections" in metrics:
        boundary_label_intersections = int(
            metrics.get("boundary_label_intersections", 0)
        )
        _append_metric(
            metric_name="boundary_label_intersections",
            metric_value=boundary_label_intersections,
            threshold=0,
            severity="warn" if boundary_label_intersections > 0 else "pass",
            category="predicted_label_advisory",
        )

    if "connector_label_intersections" in metrics:
        connector_label_intersections = int(
            metrics.get("connector_label_intersections", 0)
        )
        _append_metric(
            metric_name="connector_label_intersections",
            metric_value=connector_label_intersections,
            threshold=0,
            severity="warn" if connector_label_intersections > 0 else "pass",
            category="predicted_label_advisory",
        )

    if "canvas_clipping_count" in metrics:
        canvas_clipping_count = int(metrics.get("canvas_clipping_count", 0))
        _append_metric(
            metric_name="canvas_clipping_count",
            metric_value=canvas_clipping_count,
            threshold=0,
            severity="review" if canvas_clipping_count > 0 else "pass",
            category="canvas_clipping",
        )

    if "visible_clipping_count" in metrics:
        visible_clipping_count = int(metrics.get("visible_clipping_count", 0))
        _append_metric(
            metric_name="visible_clipping_count",
            metric_value=visible_clipping_count,
            threshold=0,
            severity="review" if visible_clipping_count > 0 else "pass",
            category="visible_clipping",
        )

    if "visible_coverage_ratio" in metrics:
        visible_coverage_ratio = float(metrics.get("visible_coverage_ratio", 1.0))
        _append_metric(
            metric_name="visible_coverage_ratio",
            metric_value=visible_coverage_ratio,
            threshold=MIN_VISIBLE_COVERAGE_RATIO,
            severity=(
                "review"
                if visible_coverage_ratio < MIN_VISIBLE_COVERAGE_RATIO
                else "pass"
            ),
            category="tile_coverage",
        )

    if "viewport_fill_width_ratio" in metrics:
        viewport_fill_width_ratio = float(metrics.get("viewport_fill_width_ratio", 1.0))
        _append_metric(
            metric_name="viewport_fill_width_ratio",
            metric_value=viewport_fill_width_ratio,
            threshold=MIN_VIEWPORT_FILL_WIDTH_RATIO,
            severity=(
                "warn"
                if viewport_fill_width_ratio < MIN_VIEWPORT_FILL_WIDTH_RATIO
                or viewport_fill_width_ratio > MAX_VIEWPORT_FILL_WIDTH_RATIO
                else "pass"
            ),
            category="canvas_utilization",
        )

    if "viewport_fill_ratio" in metrics:
        _append_metric(
            metric_name="viewport_fill_ratio",
            metric_value=float(metrics.get("viewport_fill_ratio", 1.0)),
            threshold=MIN_VIEWPORT_FILL_WIDTH_RATIO,
            severity="pass",
            category="canvas_utilization",
        )

    if "detached_endpoint_count" in metrics:
        detached_endpoint_count = int(metrics.get("detached_endpoint_count", 0))
        _append_metric(
            metric_name="detached_endpoint_count",
            metric_value=detached_endpoint_count,
            threshold=0,
            severity="review" if detached_endpoint_count > 0 else "pass",
            category="connector_attachment",
            owning_flow_id=str(metrics.get("detached_endpoint_flow_id") or "") or None,
            owning_node_id=str(metrics.get("detached_endpoint_node_id") or "") or None,
        )

    if "backward_edge_count" in metrics:
        backward_edge_count = int(metrics.get("backward_edge_count", 0))
        _append_metric(
            metric_name="backward_edge_count",
            metric_value=backward_edge_count,
            threshold=0,
            severity="warn" if backward_edge_count > 0 else "pass",
            category="reverse_edge_density",
        )

    if "max_handle_cluster_size" in metrics:
        max_handle_cluster_size = int(metrics.get("max_handle_cluster_size", 0))
        _append_metric(
            metric_name="max_handle_cluster_size",
            metric_value=max_handle_cluster_size,
            threshold=MAX_HANDLE_CLUSTER_SIZE,
            severity=(
                "review"
                if max_handle_cluster_size > MAX_HANDLE_CLUSTER_SIZE
                else "pass"
            ),
            category="handle_cluster_density",
        )

    if "duplicate_route_leg_count" in metrics:
        duplicate_route_leg_count = int(metrics.get("duplicate_route_leg_count", 0))
        _append_metric(
            metric_name="duplicate_route_leg_count",
            metric_value=duplicate_route_leg_count,
            threshold=0,
            severity="review" if duplicate_route_leg_count > 0 else "pass",
            category="duplicate_route_legs",
        )

    if "max_label_ownership_distance" in metrics:
        max_label_ownership_distance = float(
            metrics.get("max_label_ownership_distance", 0.0)
        )
        _append_metric(
            metric_name="max_label_ownership_distance",
            metric_value=max_label_ownership_distance,
            threshold=MAX_LABEL_OWNERSHIP_DISTANCE,
            severity=(
                "warn"
                if max_label_ownership_distance > MAX_LABEL_OWNERSHIP_DISTANCE
                else "pass"
            ),
            category="predicted_label_advisory",
            owning_flow_id=str(metrics.get("label_ownership_flow_id") or "") or None,
        )

    if "min_label_arrowhead_clearance" in metrics:
        min_label_arrowhead_clearance = float(
            metrics.get("min_label_arrowhead_clearance", 0.0)
        )
        has_labels = bool(metrics.get("connector_label_count", 1))
        _append_metric(
            metric_name="min_label_arrowhead_clearance",
            metric_value=min_label_arrowhead_clearance,
            threshold=MIN_LABEL_ARROWHEAD_CLEARANCE,
            severity=(
                "warn"
                if has_labels
                and min_label_arrowhead_clearance < MIN_LABEL_ARROWHEAD_CLEARANCE
                else "pass"
            ),
            category="predicted_label_advisory",
            owning_flow_id=str(metrics.get("label_arrowhead_flow_id") or "") or None,
        )

    if "branch_alignment_variance" in metrics:
        branch_alignment_variance = float(metrics.get("branch_alignment_variance", 0.0))
        _append_metric(
            metric_name="branch_alignment_variance",
            metric_value=branch_alignment_variance,
            threshold=MAX_BRANCH_ALIGNMENT_VARIANCE,
            severity=(
                "warn"
                if branch_alignment_variance > MAX_BRANCH_ALIGNMENT_VARIANCE
                else "pass"
            ),
            category="branch_alignment",
        )

    if "rank_monotonicity_ratio" in metrics:
        rank_monotonicity_ratio = float(metrics.get("rank_monotonicity_ratio", 1.0))
        _append_metric(
            metric_name="rank_monotonicity_ratio",
            metric_value=rank_monotonicity_ratio,
            threshold=MIN_RANK_MONOTONICITY_RATIO,
            severity=(
                "warn"
                if rank_monotonicity_ratio < MIN_RANK_MONOTONICITY_RATIO
                else "pass"
            ),
            category="rank_monotonicity",
        )

    if "zone_whitespace_imbalance" in metrics:
        zone_whitespace_imbalance = float(metrics.get("zone_whitespace_imbalance", 0.0))
        _append_metric(
            metric_name="zone_whitespace_imbalance",
            metric_value=zone_whitespace_imbalance,
            threshold=MAX_ZONE_WHITESPACE_IMBALANCE,
            severity=(
                "warn"
                if zone_whitespace_imbalance > MAX_ZONE_WHITESPACE_IMBALANCE
                else "pass"
            ),
            category="whitespace_balance",
        )

    if "scroll_extent_ratio_x" in metrics:
        scroll_extent_ratio_x = float(metrics.get("scroll_extent_ratio_x", 0.0))
        _append_metric(
            metric_name="scroll_extent_ratio_x",
            metric_value=scroll_extent_ratio_x,
            threshold=2.0,
            severity=(
                "review"
                if scroll_extent_ratio_x > 2.0
                else "warn"
                if scroll_extent_ratio_x > 1.0
                else "pass"
            ),
            category="scroll_extent",
        )

    if "scroll_extent_ratio_y" in metrics:
        scroll_extent_ratio_y = float(metrics.get("scroll_extent_ratio_y", 0.0))
        _append_metric(
            metric_name="scroll_extent_ratio_y",
            metric_value=scroll_extent_ratio_y,
            threshold=2.0,
            severity=(
                "review"
                if scroll_extent_ratio_y > 2.0
                else "warn"
                if scroll_extent_ratio_y > 1.0
                else "pass"
            ),
            category="scroll_extent",
        )

    if "unclassified_isolated_node_count" in metrics:
        unclassified_isolated_node_count = int(
            metrics.get("unclassified_isolated_node_count", 0)
        )
        _append_metric(
            metric_name="unclassified_isolated_node_count",
            metric_value=unclassified_isolated_node_count,
            threshold=0,
            severity="review" if unclassified_isolated_node_count > 0 else "pass",
            category="isolation",
        )

    if "contextual_island_count" in metrics:
        contextual_island_count = int(metrics.get("contextual_island_count", 0))
        _append_metric(
            metric_name="contextual_island_count",
            metric_value=contextual_island_count,
            threshold=0,
            severity="warn" if contextual_island_count > 0 else "pass",
            category="contextual_island",
        )

    if "semantic_flow_coverage" in metrics:
        semantic_flow_coverage = float(metrics.get("semantic_flow_coverage", 1.0))
        _append_metric(
            metric_name="semantic_flow_coverage",
            metric_value=semantic_flow_coverage,
            threshold=1.0,
            severity="review" if semantic_flow_coverage < 1.0 else "pass",
            category="semantic_flow_coverage",
        )

    if "empty_zone_ratio" in metrics:
        empty_zone_ratio = float(metrics.get("empty_zone_ratio", 0.0))
        _append_metric(
            metric_name="empty_zone_ratio",
            metric_value=empty_zone_ratio,
            threshold=0.65,
            severity="warn" if empty_zone_ratio > 0.65 else "pass",
            category="empty_zone_ratio",
        )

    if "unoccupied_zone_count" in metrics:
        unoccupied_zone_count = int(metrics.get("unoccupied_zone_count", 0))
        _append_metric(
            metric_name="unoccupied_zone_count",
            metric_value=unoccupied_zone_count,
            threshold=0,
            severity="review" if unoccupied_zone_count > 0 else "pass",
            category="unoccupied_zone",
        )

    if "edge_node_intersections" in metrics:
        edge_node_intersections = int(metrics.get("edge_node_intersections", 0))
        if edge_node_intersections > 2:
            severity = "review"
        elif edge_node_intersections > 0:
            severity = "warn"
        else:
            severity = "pass"
        _append_metric(
            metric_name="edge_node_intersections",
            metric_value=edge_node_intersections,
            threshold=2,
            severity=severity,
            category="edge_node_intersection",
        )

    if "edge_crossing_count" in metrics:
        edge_crossing_count = int(metrics.get("edge_crossing_count", 0))
        if density == "dense":
            severity = "warn" if edge_crossing_count >= 1 else "pass"
        else:
            if edge_crossing_count > 2:
                severity = "review"
            elif edge_crossing_count > 0:
                severity = "warn"
            else:
                severity = "pass"
        _append_metric(
            metric_name="edge_crossing_count",
            metric_value=edge_crossing_count,
            threshold=2,
            severity=severity,
            category="edge_crossing",
        )

    if "min_spacing_ratio" in metrics:
        min_spacing_ratio = float(metrics.get("min_spacing_ratio", 1.0))
        if min_spacing_ratio < 0.24:
            severity = "review"
        elif min_spacing_ratio < 0.6:
            severity = "warn"
        else:
            severity = "pass"
        _append_metric(
            metric_name="min_spacing_ratio",
            metric_value=min_spacing_ratio,
            threshold=0.24,
            severity=severity,
            category="spacing",
        )

    capture_scope = str(metrics.get("capture_scope", "")).strip()
    viewport = metrics.get("viewport") or {}
    viewport_width = int(viewport.get("width", 0) or 0)
    viewport_height = int(viewport.get("height", 0) or 0)
    annotation = str(metrics.get("annotation") or "").strip()
    expected_identity = str(
        metrics.get("expected_identity") or metrics.get("surface_name") or surface_id
    ).strip()
    completeness_ok = (
        capture_scope == "pane"
        and viewport_width > 0
        and viewport_height > 0
        and bool(annotation)
        and bool(expected_identity)
    )
    if not completeness_ok:
        _append_metric(
            metric_name="surface_completeness",
            metric_value=1.0 if completeness_ok else 0.0,
            threshold=1.0,
            severity="review",
            category="surface_completeness",
        )

    if metrics.get("capture_status") not in {None, "ok"}:
        _append_metric(
            metric_name="surface_capture_status",
            metric_value=0.0,
            threshold=1.0,
            severity="review",
            category="surface_completeness",
        )

    if metrics.get("severity") == "review":
        _append_metric(
            metric_name="image_heuristic",
            metric_value=1.0,
            threshold=0.0,
            severity="review",
            category="screenshot_heuristic",
        )

    return findings


def _normalize_vector(vector: tuple[float, float]) -> tuple[float, float]:
    """Normalize a vector to unit length when possible."""

    delta_x, delta_y = vector
    magnitude = math.hypot(delta_x, delta_y)
    if magnitude <= 1e-12:
        return (0.0, 0.0)
    return (delta_x / magnitude, delta_y / magnitude)


def _deterministic_fallback_vector(node_id: str) -> tuple[float, float]:
    """Provide a deterministic fallback movement axis for a node."""

    digest = hashlib.sha256(node_id.encode("utf-8")).hexdigest()
    if int(digest[-1], 16) % 2 == 0:
        return (-1.0, 0.0)
    return (0.0, -1.0)


def _movement_vector_from_segment(
    node_rect: tuple[float, float, float, float],
    segment: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[float, float]:
    """Compute an away-from-segment vector for a node rectangle."""

    left, top, right, bottom = node_rect
    center_x = (left + right) / 2.0
    center_y = (top + bottom) / 2.0
    start, end = segment
    start_x, start_y = start
    end_x, end_y = end
    delta_x = end_x - start_x
    delta_y = end_y - start_y
    if abs(delta_x) <= 1e-12 and abs(delta_y) <= 1e-12:
        return _normalize_vector((center_x - start_x, center_y - start_y))
    projection = ((center_x - start_x) * delta_x + (center_y - start_y) * delta_y) / (
        delta_x * delta_x + delta_y * delta_y
    )
    projection = max(0.0, min(1.0, projection))
    closest_x = start_x + projection * delta_x
    closest_y = start_y + projection * delta_y
    vector_x = center_x - closest_x
    vector_y = center_y - closest_y
    if abs(vector_x) <= 1e-12 and abs(vector_y) <= 1e-12:
        midpoint_x = (start_x + end_x) / 2.0
        if center_x >= midpoint_x:
            return _normalize_vector((-delta_y, delta_x))
        return _normalize_vector((delta_y, -delta_x))
    return _normalize_vector((vector_x, vector_y))


def derive_overlay_candidates(
    *,
    surface_geometry: SurfaceGeometry,
    overlay_context: OverlayContext,
    metrics: dict[str, Any],
    density: str = "simple",
) -> list[dict[str, Any]]:
    """Create deterministic overlay candidates from the scoring metrics."""

    findings = derive_findings(metrics, density=density)
    review_count = sum(
        1
        for finding in findings
        if finding["severity"] == "review"
        and finding.get("category") != "surface_completeness"
    )
    warn_count = sum(1 for finding in findings if finding["severity"] == "warn")
    gate_failure_count = sum(
        1
        for finding in findings
        if finding["severity"] == "review"
        and finding.get("category")
        not in {"screenshot_heuristic", "surface_completeness"}
    )
    max_severity_score = 3.0 if review_count else 2.0 if warn_count else 0.0
    movement_increment = max(surface_geometry.nominal_node_size * 0.25, 10.0)
    node_id = str(metrics.get("node_id", "unknown"))
    flow_id = str(metrics.get("flow_id", "") or "")
    candidate_targets: list[str] = []
    if node_id not in {"", "unknown"}:
        candidate_targets.append(node_id)
    for affected_node_id in metrics.get("affected_node_ids") or []:
        candidate_targets.append(str(affected_node_id))
    candidate_targets.extend(sorted(surface_geometry.node_rects))
    candidate_targets = [
        target_id for target_id in dict.fromkeys(candidate_targets) if target_id
    ]
    if not candidate_targets:
        candidate_targets = [node_id or "unknown"]

    candidates: list[dict[str, Any]] = []
    for target_node_id in candidate_targets:
        candidate_rule: dict[str, Any] = {}
        constraint_type = "none"
        target_type = "node"
        target_id = node_id
        rule_collection = "node_rules"
        overlay_rule: dict[str, Any] = {}
        if gate_failure_count > 0:
            node_rect = surface_geometry.node_rects.get(target_node_id)
            vectors: list[tuple[float, float]] = []
            if node_rect is not None:
                for (
                    source_id,
                    target_id,
                    start,
                    end,
                ) in surface_geometry.connector_segments:
                    if target_node_id in {source_id, target_id}:
                        continue
                    if _segment_intersects_rect(start, end, node_rect):
                        vectors.append(
                            _movement_vector_from_segment(
                                node_rect,
                                ((start[0], start[1]), (end[0], end[1])),
                            )
                        )
                for other_node_id, other_rect in surface_geometry.node_rects.items():
                    if other_node_id == target_node_id:
                        continue
                    left_a, top_a, right_a, bottom_a = node_rect
                    left_b, top_b, right_b, bottom_b = other_rect
                    overlap = _rect_overlap(
                        left_a,
                        top_a,
                        right_a,
                        bottom_a,
                        left_b,
                        top_b,
                        right_b,
                        bottom_b,
                    )
                    if overlap > 0.0:
                        center_a = ((left_a + right_a) / 2.0, (top_a + bottom_a) / 2.0)
                        center_b = ((left_b + right_b) / 2.0, (top_b + bottom_b) / 2.0)
                        vectors.append(
                            _normalize_vector(
                                (center_a[0] - center_b[0], center_a[1] - center_b[1])
                            )
                        )
                if surface_geometry.node_rects and len(surface_geometry.node_rects) > 1:
                    other_nodes = [
                        other_node_id
                        for other_node_id in surface_geometry.node_rects
                        if other_node_id != target_node_id
                    ]
                    if other_nodes:
                        center_a = ((left_a + right_a) / 2.0, (top_a + bottom_a) / 2.0)
                        nearest_node_id = min(
                            other_nodes,
                            key=lambda candidate_id: (
                                math.hypot(
                                    center_a[0]
                                    - (
                                        (
                                            surface_geometry.node_rects[candidate_id][0]
                                            + surface_geometry.node_rects[candidate_id][
                                                2
                                            ]
                                        )
                                        / 2.0
                                    ),
                                    center_a[1]
                                    - (
                                        (
                                            surface_geometry.node_rects[candidate_id][1]
                                            + surface_geometry.node_rects[candidate_id][
                                                3
                                            ]
                                        )
                                        / 2.0
                                    ),
                                ),
                                candidate_id,
                            ),
                        )
                        other_rect = surface_geometry.node_rects[nearest_node_id]
                        center_b = (
                            (other_rect[0] + other_rect[2]) / 2.0,
                            (other_rect[1] + other_rect[3]) / 2.0,
                        )
                        vectors.append(
                            _normalize_vector(
                                (center_a[0] - center_b[0], center_a[1] - center_b[1])
                            )
                        )
            if vectors:
                aggregate_vector = (0.0, 0.0)
                for vector in vectors:
                    aggregate_vector = (
                        aggregate_vector[0] + vector[0],
                        aggregate_vector[1] + vector[1],
                    )
                aggregate_vector = _normalize_vector(aggregate_vector)
                if aggregate_vector == (0.0, 0.0):
                    aggregate_vector = _deterministic_fallback_vector(target_node_id)
                left, top, _, _ = (
                    node_rect if node_rect is not None else (0.0, 0.0, 0.0, 0.0)
                )
                updated_left = max(1.0, left + aggregate_vector[0] * movement_increment)
                updated_top = max(1.0, top + aggregate_vector[1] * movement_increment)
                candidate_rule = {
                    "node_id": target_node_id,
                    "constraint": "position",
                    "left": float(updated_left),
                    "top": float(updated_top),
                }
                constraint_type = "position"
            else:
                left, top, _, _ = (
                    node_rect if node_rect is not None else (0.0, 0.0, 0.0, 0.0)
                )
                candidate_rule = {
                    "node_id": target_node_id,
                    "constraint": "position",
                    "left": float(max(1.0, left + movement_increment)),
                    "top": float(max(1.0, top)),
                }
                constraint_type = "position"
        review_categories = {
            str(finding.get("category", ""))
            for finding in findings
            if finding.get("severity") == "review"
        }
        if (
            gate_failure_count > 0
            and review_categories
            & {
                "boundary_overlap",
                "boundary_gutter",
                "zone_containment",
                "boundary_label_clearance",
            }
            and surface_geometry.boundary_rects
        ):
            target_type = "zone"
            target_id = sorted(surface_geometry.boundary_rects)[0]
            left, top, right, bottom = surface_geometry.boundary_rects[target_id]
            rule_collection = "zone_rules"
            constraint_type = "region"
            overlay_rule = {
                "surface_id": surface_geometry.surface_id,
                "zone_id": target_id,
                "region": {
                    "left": max(1.0, left + 24.0),
                    "top": max(1.0, top),
                    "width": max(120.0, right - left),
                    "height": max(120.0, bottom - top),
                },
                "label_band_height": 36.0,
                "lane_order": ["connected", "contextual"],
            }
        elif (
            gate_failure_count > 0 and "connector_label_clearance" in review_categories
        ):
            if surface_geometry.connector_label_rects:
                target_type = "connector"
                target_id = sorted(surface_geometry.connector_label_rects)[0]
                left, top, right, bottom = surface_geometry.connector_label_rects[
                    target_id
                ]
                rule_collection = "connector_rules"
                constraint_type = "label_offset"
                overlay_rule = {
                    "surface_id": surface_geometry.surface_id,
                    "flow_id": target_id,
                    "source_port": "auto",
                    "target_port": "auto",
                    "handle_point": {
                        "x": (left + right) / 2.0,
                        "y": (top + bottom) / 2.0,
                    },
                    "label_offset": {"x": 24.0, "y": -24.0},
                }
        elif gate_failure_count > 0 and review_categories & {
            "canvas_clipping",
            "scroll_extent",
        }:
            target_type = "surface"
            target_id = surface_geometry.surface_id
            rule_collection = "surface_rules"
            constraint_type = "viewport"
            viewport = surface_geometry.viewport_target or (0.0, 0.0, 1920.0, 1080.0)
            overlay_rule = {
                "surface_id": surface_geometry.surface_id,
                "zone_order": sorted(surface_geometry.boundary_rects),
                "orientation": "horizontal",
                "viewport_target": {
                    "left": viewport[0],
                    "top": viewport[1],
                    "width": viewport[2],
                    "height": viewport[3],
                },
                "outer_margin": max(24.0, surface_geometry.outer_margin),
            }
        elif candidate_rule:
            overlay_rule = {
                "surface_id": surface_geometry.surface_id,
                "node_id": node_id,
                "layout_role": "connected",
                "absolute_position": {
                    "left": float(candidate_rule.get("left", 1.0)),
                    "top": float(candidate_rule.get("top", 1.0)),
                    "width": max(
                        1.0,
                        (surface_geometry.node_rects.get(node_id) or (0, 0, 100, 100))[
                            2
                        ]
                        - (
                            surface_geometry.node_rects.get(node_id) or (0, 0, 100, 100)
                        )[0],
                    ),
                    "height": max(
                        1.0,
                        (surface_geometry.node_rects.get(node_id) or (0, 0, 100, 100))[
                            3
                        ]
                        - (
                            surface_geometry.node_rects.get(node_id) or (0, 0, 100, 100)
                        )[1],
                    ),
                },
            }
        candidate = {
            "surface_id": surface_geometry.surface_id,
            "node_id": target_node_id,
            "constraint_type": constraint_type,
            "target_type": target_type,
            "target_id": target_id,
            "rule_collection": rule_collection,
            "overlay_rule": overlay_rule,
            "movement_increment": movement_increment,
            "gate_failure_count": gate_failure_count,
            "review_count": review_count,
            "warn_count": warn_count,
            "max_severity_score": max_severity_score,
            "findings": findings,
            "rule": candidate_rule,
            "provenance": {
                "evidence_ref": "evidence/iteration-01",
                "approval_state": "pending",
            },
            "invalidation": {
                "spec_fingerprint": overlay_context.spec_sha256,
                "generator_profile_fingerprint": (
                    overlay_context.generator_profile_sha256
                ),
                "surface_identity_fingerprint": _fingerprint(
                    {
                        "surface_ids": sorted(overlay_context.surface_ids),
                        "surface_node_ids": {
                            key: sorted(value)
                            for key, value in sorted(
                                overlay_context.surface_node_ids.items()
                            )
                        },
                    }
                ),
                "surface_zone_identity_fingerprint": _fingerprint(
                    {
                        "surface_ids": sorted(overlay_context.surface_ids),
                        "surface_zone_ids": {
                            key: sorted(value)
                            for key, value in sorted(
                                overlay_context.surface_zone_ids.items()
                            )
                        },
                    }
                ),
                "surface_flow_identity_fingerprint": _fingerprint(
                    {
                        "surface_ids": sorted(overlay_context.surface_ids),
                        "surface_flow_ids": {
                            key: sorted(value)
                            for key, value in sorted(
                                overlay_context.surface_flow_ids.items()
                            )
                        },
                    }
                ),
            },
            "ranking_key": None,
        }
        if not overlay_context.surface_node_ids.get(surface_geometry.surface_id):
            raise ValueError("overlay_context references an unknown surface")
        if flow_id not in {"", "unknown"}:
            candidate["flow_id"] = flow_id
        if gate_failure_count == 0:
            candidate["rule"] = {}
            candidate["constraint_type"] = "none"
        candidates.append(candidate)
    return candidates


def score_surface_layout_candidate(
    candidate: dict[str, Any],
    *,
    viewport_target: tuple[float, float, float, float] | None = None,
) -> tuple[float, float, float, float, float]:
    """Score a whole-surface layout candidate using the deterministic tuple order.

    The tuple declares only dimensions this function can compute from a
    candidate: viewport fit, reverse-edge ambiguity, branch order, total edge
    length, and semantic stability. Geometry-dependent dimensions such as tile
    coverage, label collision, connector crossing, unrelated node hits, boundary
    crossing, and whitespace need a laid-out surface, which a candidate does not
    carry, so they are scored after layout rather than declared here as members
    that could only ever be constant.
    """
    if isinstance(viewport_target, dict):
        viewport = (
            float(viewport_target.get("left", 0.0)),
            float(viewport_target.get("top", 0.0)),
            float(viewport_target.get("width", 1920.0)),
            float(viewport_target.get("height", 1080.0)),
        )
    else:
        viewport = viewport_target or (0.0, 0.0, 1920.0, 1080.0)
    viewport_width = float(viewport[2])
    viewport_height = float(viewport[3])
    node_ranks = candidate.get("node_ranks", {}) or {}
    branch_groups = candidate.get("branch_groups", {}) or {}
    reverse_edge_members = candidate.get("reverse_edge_members", set()) or set()
    fan_in = candidate.get("fan_in", {}) or {}
    fan_out = candidate.get("fan_out", {}) or {}

    orientation = str(candidate.get("orientation") or "horizontal").lower()
    preferred_orientation = (
        "horizontal" if viewport_width >= viewport_height else "vertical"
    )
    orientation_penalty = 0.0 if orientation == preferred_orientation else 0.5

    zone_order = [str(zone_id) for zone_id in candidate.get("zone_order", []) or []]
    # Zones should read in flow order. When flow ranks are unavailable the
    # comparison falls back to identifier order so scoring stays deterministic.
    zone_flow_ranks = candidate.get("zone_flow_ranks") or {}

    def _zone_sort_value(zone_id: str) -> Any:
        if zone_id in zone_flow_ranks:
            return (0, float(zone_flow_ranks[zone_id]), zone_id)
        return (1, 0.0, zone_id)

    zone_order_inversions = sum(
        1
        for index, zone_id in enumerate(zone_order)
        for later_zone_id in zone_order[index + 1 :]
        if _zone_sort_value(later_zone_id) < _zone_sort_value(zone_id)
    )

    viewport_fit_penalty = (
        max(0.0, (viewport_width - 1200.0) / 100.0) + orientation_penalty
    )
    reverse_edge_ambiguity_penalty = 0.0 if not reverse_edge_members else 0.25
    branch_order_penalty = float(zone_order_inversions) * 0.25
    total_edge_length_penalty = 0.0
    semantic_stability_penalty = 0.0

    for node_id in sorted(node_ranks):
        branch_order_penalty += float(branch_groups.get(node_id, 0)) * 0.01
        viewport_fit_penalty += float(node_ranks.get(node_id, 0)) * 0.0001
        total_edge_length_penalty += (
            float(fan_in.get(node_id, 0) + fan_out.get(node_id, 0)) * 0.005
        )
        semantic_stability_penalty += float(len(str(node_id))) * 0.0001
    branch_order_penalty = min(branch_order_penalty, 8.0)
    viewport_fit_penalty = min(viewport_fit_penalty, 16.0)
    total_edge_length_penalty = min(total_edge_length_penalty, 8.0)
    semantic_stability_penalty = min(semantic_stability_penalty, 4.0)

    return (
        viewport_fit_penalty,
        reverse_edge_ambiguity_penalty,
        branch_order_penalty,
        total_edge_length_penalty,
        semantic_stability_penalty,
    )


def surface_semantic_fingerprint(candidate: dict[str, Any]) -> str:
    """Fingerprint the semantic identities a layout candidate must preserve."""

    return _fingerprint(
        {
            "node_ids": sorted(
                str(node_id) for node_id in candidate.get("node_ids", [])
            ),
            "flow_ids": sorted(
                str(flow_id) for flow_id in candidate.get("flow_ids", [])
            ),
            "zone_ids": sorted(
                str(zone_id) for zone_id in candidate.get("zone_ids", [])
            ),
        }
    )


def _dominates(
    score_a: tuple[float, ...],
    score_b: tuple[float, ...],
) -> bool:
    """Return True when score_a is at least as good everywhere and better somewhere."""

    return all(a <= b for a, b in zip(score_a, score_b)) and any(
        a < b for a, b in zip(score_a, score_b)
    )


def prune_dominated_surface_candidates(
    scored_candidates: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Discard candidates that are equal or worse in every score dimension."""

    ordered = sorted(
        scored_candidates,
        key=lambda entry: (tuple(entry["score"]), str(entry.get("candidate_id", ""))),
    )
    survivors: list[dict[str, Any]] = []
    for entry in ordered:
        score = tuple(entry["score"])
        if any(_dominates(tuple(kept["score"]), score) for kept in survivors):
            continue
        if any(tuple(kept["score"]) == score for kept in survivors):
            continue
        survivors.append(entry)
    return survivors


def select_surface_refinement(
    *,
    incumbent_score: tuple[float, ...],
    incumbent_semantic_fingerprint: str,
    candidates: list[dict[str, Any]],
    viewport_target: tuple[float, float, float, float] | None = None,
    score_candidate: Callable[[dict[str, Any]], tuple[float, ...] | None] | None = None,
) -> dict[str, Any]:
    """Select one whole-surface alternative that strictly improves portable gates.

    Candidates that change semantic identities are rejected before layout scoring so
    a readability refinement can never silently alter the modeled system. When no
    surviving candidate improves the incumbent score tuple the result reports
    ``repeated-defect-no-improvement`` so the caller skips the native launch.

    ``score_candidate`` lets a caller that can lay a candidate out score it on
    measured geometry instead. The default scorer sees graph topology only, and
    generation already minimized that same function when it chose the shipped
    layout, so the incumbent is its argmin by construction and no alternative
    can strictly improve on it. A caller supplying measured geometry is scoring
    something generation could not have known: what the tool actually drew.
    Returning ``None`` rejects a candidate, which is how a layout that cannot be
    realized is dropped without failing the run. The incumbent score must come
    from the same scorer, or the comparison is meaningless.
    """

    bounded_candidates = candidates[:MAX_SURFACE_REFINEMENT_CANDIDATES]
    scored: list[dict[str, Any]] = []
    semantic_rejected: list[str] = []
    unrealizable_rejected: list[str] = []
    for index, candidate in enumerate(bounded_candidates):
        candidate_id = str(candidate.get("candidate_id") or f"candidate-{index:04d}")
        if surface_semantic_fingerprint(candidate) != incumbent_semantic_fingerprint:
            semantic_rejected.append(candidate_id)
            continue
        if score_candidate is None:
            candidate_score: tuple[float, ...] | None = score_surface_layout_candidate(
                candidate,
                viewport_target=viewport_target,
            )
        else:
            candidate_score = score_candidate(candidate)
        if candidate_score is None:
            unrealizable_rejected.append(candidate_id)
            continue
        scored.append(
            {
                "candidate_id": candidate_id,
                "candidate": candidate,
                "score": candidate_score,
            }
        )

    pruned = prune_dominated_surface_candidates(scored)
    improving = [
        entry for entry in pruned if tuple(entry["score"]) < tuple(incumbent_score)
    ]
    if not improving:
        return {
            "selected": None,
            "selected_candidate_id": None,
            "stop_reason": "repeated-defect-no-improvement",
            "requires_native_launch": False,
            "evaluated_count": len(scored),
            "pruned_count": len(scored) - len(pruned),
            "semantic_rejected_ids": semantic_rejected,
            "unrealizable_rejected_ids": unrealizable_rejected,
        }

    best = min(
        improving,
        key=lambda entry: (tuple(entry["score"]), str(entry["candidate_id"])),
    )
    return {
        "selected": best["candidate"],
        "selected_candidate_id": best["candidate_id"],
        "selected_score": tuple(best["score"]),
        "stop_reason": "pending",
        "requires_native_launch": True,
        "evaluated_count": len(scored),
        "pruned_count": len(scored) - len(pruned),
        "semantic_rejected_ids": semantic_rejected,
        "unrealizable_rejected_ids": unrealizable_rejected,
    }


def rank_overlay_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Sort candidates using the deterministic ranking tuple."""

    sorted_candidates = sorted(
        candidates,
        key=lambda candidate: (
            candidate["gate_failure_count"],
            candidate["review_count"],
            candidate["warn_count"],
            candidate["max_severity_score"],
            candidate["surface_id"],
            candidate["node_id"],
            candidate["constraint_type"],
        ),
    )
    for candidate in sorted_candidates:
        candidate["ranking_key"] = (
            candidate["gate_failure_count"],
            candidate["review_count"],
            candidate["warn_count"],
            candidate["max_severity_score"],
            candidate["surface_id"],
            candidate["node_id"],
            candidate["constraint_type"],
        )
    return sorted_candidates


def evaluate_convergence(
    history: list[IterationResult],
    *,
    max_iterations: int,
) -> ConvergenceResult:
    """Evaluate whether the feedback loop should stop.

    Evidence completeness is checked before the zero-gate success path. A run
    with no failing gates but incomplete evidence has not demonstrated
    readiness; it has only failed to observe anything, which is the opposite
    conclusion.
    """

    if not history:
        return ConvergenceResult(should_stop=False, stop_reason="pending")
    if not history[-1].evidence_complete:
        return ConvergenceResult(should_stop=True, stop_reason="evidence-incomplete")
    if history[-1].gate_failure_count == 0:
        return ConvergenceResult(
            should_stop=True,
            stop_reason="automated-ready-pending-human",
            reason_detail="automated readiness pending human review",
        )
    if len(history) >= max_iterations + 1:
        return ConvergenceResult(should_stop=True, stop_reason="max-iterations")
    if (
        len(history) >= 2
        and len(history) < max_iterations
        and history[-1].defect_signature == history[-2].defect_signature
        and history[-1].gate_failure_count >= history[-2].gate_failure_count
    ):
        return ConvergenceResult(
            should_stop=True,
            stop_reason="repeated-defect-no-improvement",
        )
    return ConvergenceResult(should_stop=False, stop_reason="continue")


__all__ = [
    "ConvergenceResult",
    "IterationResult",
    "MAX_SURFACE_REFINEMENT_CANDIDATES",
    "MIN_SURFACE_REFINEMENT_CANDIDATES",
    "OverlayContext",
    "SURFACE_REFINEMENT_ZONE_ROTATION_CAP",
    "SurfaceGeometry",
    "ViewportBounds",
    "build_feedback_manifest",
    "derive_findings",
    "derive_geometry_metrics",
    "derive_image_metrics",
    "derive_overlay_candidates",
    "evaluate_convergence",
    "load_layout_overlay",
    "rank_overlay_candidates",
    "score_surface_layout_candidate",
    "select_surface_refinement",
    "surface_semantic_fingerprint",
    "validate_feedback_manifest",
    "validate_layout_overlay",
]
