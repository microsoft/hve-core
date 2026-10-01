#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate a deterministic TM7 model from a vendor-neutral threat-model spec."""

from __future__ import annotations

import argparse
import json
import logging
import math
import os
import re
import sys
import tempfile
import textwrap
from collections import deque
from datetime import date, datetime
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

import tm7_visual_feedback
import yaml
from tm7_threat_contract import (
    MAX_SPEC_BYTES,
    THREAT_PROPERTY_KEYS,
    InputTooLargeError,
    ThreatContractError,
    UnsafeXmlError,
    _coerce_list,
    _local_name,
    _make_guid,
    build_custom_threat_type_id,
    build_entry_key,
    build_interaction_key,
    build_mitigation_text,
    collect_mapping_failures,
    parse_hardened_xml_bytes,
    read_bounded_bytes,
    serialize_threat_instances,
)

logger = logging.getLogger(__name__)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
# SIGINT convention: 128 + signal number.
EXIT_INTERRUPTED = 130

# The KnowledgeBase is pre-rendered XML, so it is substituted into the
# serialized model as literal text. The tag and its self-closing serialization
# must stay in step with the placeholder element added during rendering.
KNOWLEDGE_BASE_PLACEHOLDER = "<KnowledgeBasePlaceholder />"

MIN_NODE_SIZE = 100.0
MAX_NODE_WIDTH = 260.0
MAX_NODE_HEIGHT = 200.0
MIN_LAYOUT_GUTTER = 24.0
# Containment is judged against the emitted boundary rectangle, so the slack
# only absorbs float accumulation from packing, not a real placement escape.
ZONE_CONTAINMENT_TOLERANCE = 0.5
# Two connectors must never share a handle point: TMT renders each connector
# label at its handle, so a shared handle superimposes both labels.
MIN_HANDLE_SEPARATION = 24.0
# Node separation is judged relative to node size, so a fixed gutter shrinks
# proportionally as text-aware sizing grows nodes. The ratio keeps measured
# spacing above the readability floor for any node size.
MIN_LAYOUT_GUTTER_RATIO = 0.28
# Layouts expand toward the calibrated canvas rather than settling at their
# minimum demand, but only up to this multiple of measured content demand so a
# sparse surface is not stretched into widely separated nodes. The value is
# measurement-selected: it sets how much of the viewport width a sparse surface
# spans, so lowering it shrinks surface extent and flattens aspect less, while
# raising it does the reverse. Gains saturate above 3.5.
LAYOUT_EXPANSION_LIMIT = 2.5
# Padding between a trust zone's own rectangle and the content placed inside it.
# Zone sizing and the post-placement extent reclaim both measure against it, so
# they cannot drift apart and leave a zone drawn tighter than its own nodes.
ZONE_INNER_PADDING = 16.0
MIN_LABEL_ARROWHEAD_CLEARANCE = 24.0
# How many extra edge crossings one connector may introduce to buy a readable
# label when no placement is both readable and cleanly routed. An overprinted
# label carries no information at all, while a crossing still leaves both flows
# traceable, so a small exchange is worth making; an unbounded one is not,
# because crossings accumulate across every connector on the surface.
LABEL_READABILITY_CROSSING_BUDGET = 1
MAX_LABEL_OWNERSHIP_DISTANCE = 120.0
# Whole-surface layout candidates are the cross product of two fixed dimensions:
# orientation and zone-order variant. Three zone orders are produced for orders
# longer than two, so the enumeration cannot exceed 2 x 3. The cap is asserted
# after enumeration rather than used to truncate, so adding a third dimension
# must raise it deliberately.
SURFACE_LAYOUT_ORIENTATIONS = ("horizontal", "vertical")
MAX_SURFACE_LAYOUT_CANDIDATES = 6
# TMT draws the model at a fixed zoom rather than 1:1. A native run measured
# every node rendering at exactly 1.500x its model size, so a pane of N screen
# pixels only shows N / 1.5 model units. Laying out against raw pixel
# dimensions therefore overruns the visible canvas by half again.
TMT_RENDER_ZOOM = 1.5
# The visible model area on a 1920x1080 Diagram pane at the zoom above. Layout
# targets what the reviewer can actually see, so content is not placed past the
# right edge where it is silently clipped.
DEFAULT_VIEWPORT_WIDTH = 1920.0 / TMT_RENDER_ZOOM
DEFAULT_VIEWPORT_HEIGHT = 1080.0 / TMT_RENDER_ZOOM

MODEL_NS = "http://schemas.datacontract.org/2004/07/ThreatModeling.Model"
ABSTRACT_NS = "http://schemas.datacontract.org/2004/07/ThreatModeling.Model.Abstracts"
KNOWLEDGE_NS = "http://schemas.datacontract.org/2004/07/ThreatModeling.KnowledgeBase"
ARRAYS_NS = "http://schemas.microsoft.com/2003/10/Serialization/Arrays"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
SER_NS = "http://schemas.microsoft.com/2003/10/Serialization/"

DISCLAIMER_TEXT = (
    "This agent is an assistive tool only. It does not provide legal, "
    "regulatory, or compliance advice and does not replace professional "
    "security review boards, penetration testing teams, compliance "
    "auditors, legal counsel, or other qualified human reviewers. The "
    "output consists of suggested actions and considerations to support a "
    "user's own internal security review and decision-making. All security "
    "plans, threat models, security models, and mitigation recommendations "
    "generated by this tool must be independently reviewed and validated by "
    "appropriate security and compliance reviewers before use. Outputs from "
    "this tool do not constitute security approval, compliance "
    "certification, or regulatory sign-off."
)


class GenerationError(Exception):
    """Raised when input validation or generation fails."""

    def __init__(self, message: str, exit_code: int = EXIT_ERROR) -> None:
        super().__init__(message)
        self.exit_code = exit_code


class _ZIdAllocator:
    """Allocate deterministic sequential z:Id values for the diagram model."""

    def __init__(self, *, start: int = 1, limit: int | None = None) -> None:
        self._counter = start
        # Diagram objects share one global z:Id sequence with the bundled
        # KnowledgeBase, which is renumbered to follow the diagram (see
        # render_tm7_xml). The limit is a runaway guard, not a model-size cap.
        self._limit = limit if limit is not None else 1_000_000

    @property
    def current(self) -> int:
        """Return the next z:Id ordinal that would be allocated."""
        return self._counter

    def next_id(self) -> str:
        if self._counter >= self._limit:
            raise GenerationError(
                "Diagram z:Id allocation exceeded the safety limit",
                exit_code=EXIT_ERROR,
            )
        value = self._counter
        self._counter += 1
        return f"i{value}"


def create_parser() -> argparse.ArgumentParser:
    """Create the CLI parser for TM7 generation."""
    parser = argparse.ArgumentParser(description="Generate a deterministic TM7 file")
    parser.add_argument("spec", type=Path, help="Path to the input threat-model spec")
    parser.add_argument("-o", "--output", type=Path, default=Path("out.tm7"))
    parser.add_argument(
        "--template",
        default=None,
        help="Template profile name (defaults to the spec or sdl_core_generic)",
    )
    parser.add_argument(
        "--mode",
        choices=["pre-populated-comprehensive", "diagram-only-defer-to-tmt"],
        default=None,
        help="Generation mode",
    )
    parser.add_argument(
        "--update",
        type=Path,
        default=None,
        help="Merge the generated output onto an existing TM7 model",
    )
    parser.add_argument(
        "--overlay-input",
        type=Path,
        default=None,
        help="Replay a validated layout overlay onto the generated model",
    )
    parser.add_argument(
        "--threat-generation-enabled",
        action="store_true",
        help="Emit ThreatGenerationEnabled=true in the output model",
    )
    return parser


def load_layout_overlay(path: Path) -> dict[str, Any]:
    """Load a layout overlay from YAML or JSON for deterministic replay."""
    return tm7_visual_feedback.load_layout_overlay(path)


def _normalize_for_fingerprint(value: Any) -> Any:
    """Recursively normalize values so overlay fingerprints stay deterministic.

    Handles both filesystem paths and temporal values because the overlay
    invalidation contract is shared with the feedback loop, and a value
    normalized by only one side would produce two fingerprints for one logical
    input.
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


def _build_overlay_context(
    *,
    spec: dict[str, Any],
    profile: dict[str, Any],
    spec_path: Path,
    model: dict[str, Any],
) -> tm7_visual_feedback.OverlayContext:
    """Create the normalized context used to validate a replay overlay."""
    surface_nodes: dict[str, set[str]] = {}
    surface_zones: dict[str, set[str]] = {}
    surface_flows: dict[str, set[str]] = {}
    for surface in model.get("surfaces", []):
        surface_id = str(surface.get("id", ""))
        surface_nodes[surface_id] = {
            str(element.get("id", ""))
            for element in surface.get("elements", [])
            if isinstance(element, dict) and str(element.get("id", ""))
        }
        surface_zones[surface_id] = {
            str(zone.get("id", ""))
            for zone in surface.get("trust_zones", [])
            if isinstance(zone, dict) and str(zone.get("id", ""))
        }
        surface_flows[surface_id] = {
            str(flow.get("id", ""))
            for flow in surface.get("flows", [])
            if isinstance(flow, dict) and str(flow.get("id", ""))
        }
    model_id = str(
        spec.get("project_metadata", {}).get("name") or spec_path.stem or "tm7-model"
    )
    generator_profile_name = str(profile.get("name") or "sdl_core_generic")
    normalized_profile = dict(profile)
    normalized_profile["name"] = generator_profile_name
    return tm7_visual_feedback.OverlayContext(
        model_id=model_id,
        spec_path=spec_path,
        spec_sha256=tm7_visual_feedback._fingerprint(_normalize_for_fingerprint(spec)),
        generator_profile=generator_profile_name,
        generator_profile_sha256=tm7_visual_feedback._fingerprint(
            _normalize_for_fingerprint(normalized_profile)
        ),
        surface_ids={
            str(surface.get("id", "")) for surface in model.get("surfaces", [])
        },
        surface_node_ids={
            key: set(value) for key, value in sorted(surface_nodes.items())
        },
        surface_zone_ids={
            key: set(value) for key, value in sorted(surface_zones.items())
        },
        surface_flow_ids={
            key: set(value) for key, value in sorted(surface_flows.items())
        },
    )


def _resolve_layout_overlay(
    *,
    spec: dict[str, Any],
    profile: dict[str, Any],
    spec_path: Path,
    model: dict[str, Any],
    overlay_path: Path | None,
) -> dict[str, Any] | None:
    """Load and validate an overlay only when explicitly supplied."""
    if overlay_path is None:
        return None
    try:
        overlay = tm7_visual_feedback.load_layout_overlay(overlay_path)
    except (FileNotFoundError, ValueError, TypeError, yaml.YAMLError) as exc:
        raise GenerationError(
            f"Overlay input is invalid: {exc}",
            exit_code=EXIT_ERROR,
        ) from exc

    if not isinstance(overlay, dict):
        raise GenerationError("Overlay input is invalid: overlay must be a mapping")

    if overlay.get("schema_version", 2) == 1:
        raise GenerationError(
            "Overlay input is invalid: schema version 1 is not supported",
            exit_code=EXIT_ERROR,
        )

    context = _build_overlay_context(
        spec=spec,
        profile=profile,
        spec_path=spec_path,
        model=model,
    )
    # The overlay must carry its own invalidation fingerprints. Completeness is
    # required before any comparison, because synthesizing a missing block from
    # the same context it is validated against would let an overlay pass by
    # omitting the block entirely.
    required_invalidation_keys = (
        "spec_fingerprint",
        "generator_profile_fingerprint",
        "surface_identity_fingerprint",
        "surface_zone_identity_fingerprint",
        "surface_flow_identity_fingerprint",
    )
    invalidation = overlay.get("invalidation")
    if not isinstance(invalidation, dict):
        raise GenerationError(
            "Overlay input is invalid: invalidation block is required and must "
            "be a mapping",
            exit_code=EXIT_ERROR,
        )
    missing = [
        key
        for key in required_invalidation_keys
        if not str(invalidation.get(key, "")).strip()
    ]
    if missing:
        raise GenerationError(
            "Overlay input is invalid: invalidation is missing "
            f"{', '.join(sorted(missing))}",
            exit_code=EXIT_ERROR,
        )

    try:
        tm7_visual_feedback.validate_layout_overlay(overlay, context)
    except (ValueError, TypeError, KeyError) as exc:
        raise GenerationError(
            f"Overlay input is invalid: {exc}",
            exit_code=EXIT_ERROR,
        ) from exc
    return overlay


def load_template_profiles(base_dir: Path) -> dict[str, dict[str, Any]]:
    """Load template profile mappings from the bundled YAML assets."""
    profiles: dict[str, dict[str, Any]] = {}
    profile_dir = base_dir / "assets" / "template-profiles"
    if not profile_dir.exists():
        return profiles
    for path in sorted(profile_dir.glob("*.yaml")):
        with path.open("r", encoding="utf-8") as handle:
            profile = yaml.safe_load(handle) or {}
        if isinstance(profile, dict):
            name = path.stem
            profiles[name] = profile
    return profiles


def load_spec(path: Path) -> dict[str, Any]:
    """Load a threat-model spec from YAML or JSON.

    The file size is checked before any content is parsed so an oversized
    document cannot be expanded in memory ahead of schema validation.

    Args:
        path: Spec file to load.

    Returns:
        Parsed spec mapping.

    Raises:
        GenerationError: If the spec is missing, oversized, unparsable, or not
            a mapping.
    """
    if not path.exists():
        raise GenerationError(f"Spec file not found: {path}", exit_code=EXIT_ERROR)
    try:
        data = read_bounded_bytes(path, MAX_SPEC_BYTES)
    except InputTooLargeError as exc:
        raise GenerationError(
            f"Spec is too large: {exc}", exit_code=EXIT_ERROR
        ) from exc
    except OSError as exc:
        raise GenerationError(
            f"Unable to read spec: {exc}", exit_code=EXIT_ERROR
        ) from exc
    try:
        text = data.decode("utf-8")
        if path.suffix.lower() == ".json":
            loaded = json.loads(text)
        else:
            loaded = yaml.safe_load(text) or {}
    except (json.JSONDecodeError, yaml.YAMLError, UnicodeDecodeError) as exc:
        raise GenerationError(
            f"Unable to parse spec: {exc}", exit_code=EXIT_ERROR
        ) from exc

    if not isinstance(loaded, dict):
        raise GenerationError(
            "Spec root must be a mapping/object", exit_code=EXIT_ERROR
        )
    return loaded


def _parse_hardened_xml_bytes(data: bytes) -> ET.Element:
    """Parse XML bytes with entity and DTD protections enabled."""

    try:
        return parse_hardened_xml_bytes(data)
    except UnsafeXmlError as exc:
        raise GenerationError(str(exc), exit_code=EXIT_ERROR) from exc


def parse_template_xml(path: Path) -> ET.Element:
    """Parse bundled template XML with entity and DTD protections."""
    if not path.exists():
        raise GenerationError(f"Template file not found: {path}", exit_code=EXIT_ERROR)
    return _parse_hardened_xml_bytes(path.read_bytes())


def emit_warnings(spec: dict[str, Any]) -> None:
    """Emit non-fatal warnings for missing completeness dimensions.

    Warnings go through the module logger rather than ``print`` so an importing
    caller can capture, route, or silence them. ``configure_logging`` at the CLI
    boundary keeps the operator-visible stderr output unchanged.
    """
    representations = spec.get("representations") or {}
    context_diagrams = representations.get("context_diagrams") or []
    functional_scenarios = representations.get("functional_scenarios") or []
    operational_views = representations.get("operational_views") or []
    data_flows = spec.get("data_flows") or []
    threats = spec.get("threats") or []
    mitigations = spec.get("mitigations") or []
    abuse_cases = spec.get("abuse_cases") or []
    security_test_cases = spec.get("security_test_cases") or []

    if not context_diagrams:
        logger.warning("incomplete threat model: CTM-1 missing context diagrams")
    if not functional_scenarios:
        logger.warning("incomplete threat model: CTM-2 missing functional scenarios")
    if not operational_views:
        logger.warning("incomplete threat model: CTM-3 missing operational views")
    if not threats or not mitigations:
        logger.warning("incomplete threat model: CTM-4 missing threats or mitigations")
    if not data_flows:
        logger.warning("incomplete threat model: CTM-5 missing numbered data flows")
    else:
        missing_annotations = [
            flow.get("id")
            for flow in data_flows
            if not all(
                flow.get(field)
                for field in (
                    "transport",
                    "encryption",
                    "authentication",
                    "authorization",
                    "data_sensitivity",
                )
            )
        ]
        if missing_annotations:
            logger.warning(
                "incomplete threat model: CTM-6 missing flow annotations for %s",
                ", ".join(str(item) for item in missing_annotations),
            )
    if not any(isinstance(threat, dict) and threat.get("state") for threat in threats):
        logger.warning("incomplete threat model: CTM-7 missing threat state")
    if not abuse_cases:
        logger.warning("incomplete threat model: CTM-8 missing abuse cases")
    if not security_test_cases:
        logger.warning("incomplete threat model: CTM-9 missing security test cases")
    if not all(
        [
            context_diagrams,
            functional_scenarios,
            operational_views,
            threats,
            mitigations,
        ]
    ):
        logger.warning(
            "incomplete threat model: CTM-10 model is not complete enough for review"
        )


def _coerce_bool(value: Any, *, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return bool(value)
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off", ""}:
            return False
    return default


def _build_element_from_component(
    component: dict[str, Any], surface_id: str, profile: dict[str, Any]
) -> dict[str, Any]:
    kind = str(component.get("kind", "process"))
    type_id = _resolve_type_id(kind, profile)
    role = str(component.get("layout_role") or "").strip()
    element = {
        "id": str(component.get("id", "component")),
        "kind": kind,
        "name": str(component.get("name", "Component")),
        "trust_zone_id": str(component.get("trust_zone_id", "")),
        "surface_id": surface_id,
        "guid": _make_guid(f"{surface_id}:{component.get('id', 'component')}"),
        "type_id": type_id,
    }
    if role:
        element["layout_role"] = role
    return element


def _resolve_type_id(kind: str, profile: dict[str, Any]) -> str:
    type_ids = profile.get("type_ids", {})
    kind_map = {
        "external_interactor": type_ids.get("external_interactor", "GE.EI"),
        "process": type_ids.get("process", "GE.P"),
        "data_store": type_ids.get("data_store", "GE.DS"),
        "trust_boundary_box": type_ids.get("trust_boundary_box", "GE.TB.B"),
        "trust_boundary_line": type_ids.get("trust_boundary_line", "GE.TB.L"),
    }
    return kind_map.get(kind, type_ids.get("process", "GE.P"))


def build_model_from_spec(
    spec: dict[str, Any], profile: dict[str, Any], mode: str
) -> dict[str, Any]:
    """Build the internal threat-model representation from the input spec."""
    representations = spec.get("representations") or {}
    surfaces: list[dict[str, Any]] = []
    components = {
        component.get("id"): component
        for component in spec.get("components") or []
        if isinstance(component, dict)
    }
    zone_order = [
        str(zone.get("id", ""))
        for zone in spec.get("trust_zones") or []
        if isinstance(zone, dict) and str(zone.get("id", ""))
    ]
    trust_zones = {
        zone.get("id"): zone
        for zone in spec.get("trust_zones") or []
        if isinstance(zone, dict)
    }

    # A flow whose endpoints are the same element has no supported rendering.
    # Anchors are derived from the two element rectangles, so a self-loop
    # collapses to a zero-length connector that TMT stores but cannot show and
    # that no reviewer can select. Fail here rather than publish an invisible
    # edge that silently drops a declared interaction from the diagram.
    self_loop_ids = sorted(
        {
            str(flow.get("id", "") or "~unidentified")
            for flow in spec.get("data_flows") or []
            if isinstance(flow, dict)
            and str(flow.get("source_ref", ""))
            and str(flow.get("source_ref", "")) == str(flow.get("target_ref", ""))
        }
    )
    if self_loop_ids:
        raise GenerationError(
            "data flow endpoints must differ; self-referencing flows have no "
            f"supported rendering: {', '.join(self_loop_ids)}",
            exit_code=EXIT_ERROR,
        )

    def _validate_zone_hierarchy(zone_id: str, *, seen: set[str] | None = None) -> None:
        if not zone_id:
            return
        zone = trust_zones.get(zone_id)
        if not isinstance(zone, dict):
            raise GenerationError(
                f"parent_trust_zone_id references unknown zone {zone_id}",
                exit_code=EXIT_ERROR,
            )
        parent_zone_id = str(zone.get("parent_trust_zone_id", "") or "")
        if not parent_zone_id:
            return
        if parent_zone_id == zone_id:
            raise GenerationError(
                "parent_trust_zone_id cannot reference itself",
                exit_code=EXIT_ERROR,
            )
        visited = seen or set()
        if parent_zone_id in visited:
            raise GenerationError(
                f"parent_trust_zone_id creates a cycle at {zone_id}",
                exit_code=EXIT_ERROR,
            )
        _validate_zone_hierarchy(parent_zone_id, seen=visited | {zone_id})

    for zone_id in zone_order:
        _validate_zone_hierarchy(zone_id)

    def _collect_zone_ancestors(zone_id: str) -> list[str]:
        zone = trust_zones.get(zone_id)
        if not isinstance(zone, dict):
            return []
        parent_zone_id = str(zone.get("parent_trust_zone_id", "") or "")
        if not parent_zone_id:
            return []
        return [parent_zone_id, *_collect_zone_ancestors(parent_zone_id)]

    def _normalize_layout_role(element: dict[str, Any], *, degree: int) -> str:
        raw_role = str(element.get("layout_role") or "")
        normalized_role = raw_role.strip().lower()
        if normalized_role in {"main", "connected"}:
            normalized_role = "connected"
        if normalized_role in {"contextual", "suppressed"}:
            return normalized_role
        if normalized_role == "connected":
            if degree == 0:
                raise GenerationError(
                    f"connected layout_role requires a selected flow for "
                    f"{element.get('id', 'unknown')}",
                    exit_code=EXIT_ERROR,
                )
            return "connected"
        if normalized_role:
            raise GenerationError(
                f"unsupported layout_role {raw_role!r} for "
                f"{element.get('id', 'unknown')}",
                exit_code=EXIT_ERROR,
            )
        if degree > 0:
            return "connected"
        raise GenerationError(
            f"isolated element {element.get('id', 'unknown')} requires an explicit "
            "contextual or suppressed layout_role",
            exit_code=EXIT_ERROR,
        )

    for representation in (
        _coerce_list(representations.get("context_diagrams"))
        + _coerce_list(representations.get("functional_scenarios"))
        + _coerce_list(representations.get("operational_views"))
    ):
        if not isinstance(representation, dict):
            continue
        surface_id = str(representation.get("id", "surface"))
        surface_name = str(representation.get("name", surface_id))
        elements: list[dict[str, Any]] = []
        if surface_name.startswith("Deployment") or representation in _coerce_list(
            representations.get("operational_views")
        ):
            raw_components = (
                representation.get("components") or representation.get("elements") or []
            )
            for component in raw_components:
                if isinstance(component, dict):
                    component_id = str(component.get("id", ""))
                    catalog_component = components.get(component_id, {})
                    resolved_component = {
                        **catalog_component,
                        **component,
                    }
                    element = _build_element_from_component(
                        resolved_component, surface_id, profile
                    )
                    elements.append(element)
        else:
            raw_elements = representation.get("elements") or []
            for element in raw_elements:
                if isinstance(element, dict):
                    element_id = str(element.get("id", ""))
                    component = components.get(element_id)
                    if component:
                        element_payload = _build_element_from_component(
                            component, surface_id, profile
                        )
                        element_payload["name"] = str(
                            element.get("name", element_payload["name"])
                        )
                        element_payload["kind"] = str(
                            element.get("kind", element_payload["kind"])
                        )
                        element_payload["trust_zone_id"] = str(
                            element.get(
                                "trust_zone_id",
                                element_payload.get("trust_zone_id", ""),
                            )
                        )
                        role = str(
                            element.get("layout_role")
                            or component.get("layout_role")
                            or ""
                        ).strip()
                        if role:
                            element_payload["layout_role"] = role
                    else:
                        element_payload = {
                            "id": element_id,
                            "kind": str(element.get("kind", "process")),
                            "name": str(element.get("name", element_id)),
                            "trust_zone_id": str(element.get("trust_zone_id", "")),
                            "surface_id": surface_id,
                            "guid": _make_guid(f"{surface_id}:{element_id}"),
                            "type_id": _resolve_type_id(
                                str(element.get("kind", "process")), profile
                            ),
                        }
                        layout_role = str(element.get("layout_role") or "").strip()
                        if layout_role:
                            element_payload["layout_role"] = layout_role
                    elements.append(element_payload)

        flow_refs = []
        declared_flow_ids = {
            str(flow_id.get("id", "")) if isinstance(flow_id, dict) else str(flow_id)
            for flow_id in _coerce_list(representation.get("flows"))
        }
        element_ids = {str(element.get("id", "")) for element in elements}
        for flow in spec.get("data_flows") or []:
            if not isinstance(flow, dict):
                continue
            if declared_flow_ids and str(flow.get("id", "")) not in declared_flow_ids:
                continue
            source_id = str(flow.get("source_ref", ""))
            target_id = str(flow.get("target_ref", ""))
            if source_id in element_ids and target_id in element_ids:
                flow_refs.append(flow)

        degree_map: dict[str, int] = {element_id: 0 for element_id in element_ids}
        for flow in flow_refs:
            source_id = str(flow.get("source_ref", ""))
            target_id = str(flow.get("target_ref", ""))
            if source_id in degree_map:
                degree_map[source_id] += 1
            if target_id in degree_map:
                degree_map[target_id] += 1

        for element in elements:
            element_id = str(element.get("id", ""))
            role = _normalize_layout_role(
                element,
                degree=degree_map.get(element_id, 0),
            )
            element["layout_role"] = role

        elements = [
            element
            for element in elements
            if str(element.get("layout_role") or "").lower() != "suppressed"
        ]
        element_ids = {str(element.get("id", "")) for element in elements}

        # Membership in the post-suppression id set is the test, because the
        # role lookup this replaces read from `elements` after suppressed
        # entries had already been removed from it. That lookup returned an
        # empty role rather than "suppressed", so its guard never fired and
        # every flow survived. `flow_refs` already required both endpoints to
        # exist before suppression, so an id missing here was suppressed.
        filtered_flows = []
        for flow in flow_refs:
            source_id = str(flow.get("source_ref", ""))
            target_id = str(flow.get("target_ref", ""))
            if source_id not in element_ids or target_id not in element_ids:
                continue
            filtered_flows.append(flow)

        surface_zone_ids = set()
        for element in elements:
            zone_key = str(element.get("trust_zone_id", "") or "")
            if zone_key:
                surface_zone_ids.add(zone_key)
                surface_zone_ids.update(_collect_zone_ancestors(zone_key))

        child_zone_ids = {
            str(element.get("trust_zone_id", "") or "")
            for element in elements
            if str(element.get("trust_zone_id", "") or "")
        }
        for zone_id in sorted(child_zone_ids):
            if not zone_id:
                continue
            zone = trust_zones.get(zone_id)
            if not isinstance(zone, dict):
                continue
            parent_zone_id = str(zone.get("parent_trust_zone_id", "") or "")
            if parent_zone_id and parent_zone_id not in surface_zone_ids:
                raise GenerationError(
                    "trust_zone ancestry for "
                    f"{zone_id} is missing ancestor {parent_zone_id}",
                    exit_code=EXIT_ERROR,
                )

        surfaces.append(
            {
                "id": surface_id,
                "name": surface_name,
                "elements": elements,
                "flows": filtered_flows,
                "trust_zones": [
                    {
                        "id": zone_id,
                        "name": trust_zones.get(zone_id, {}).get("name", zone_id),
                        "description": trust_zones.get(zone_id, {}).get(
                            "description", ""
                        ),
                        **(
                            {
                                "parent_trust_zone_id": str(
                                    trust_zones.get(zone_id, {}).get(
                                        "parent_trust_zone_id", ""
                                    )
                                    or ""
                                )
                            }
                            if str(
                                trust_zones.get(zone_id, {}).get(
                                    "parent_trust_zone_id", ""
                                )
                                or ""
                            )
                            else {}
                        ),
                    }
                    for zone_id in zone_order
                    if zone_id in surface_zone_ids
                ],
            }
        )

    project_name = spec.get("project_metadata", {}).get("name", "threat model")
    model = {
        "profile": str(
            profile.get("name") or profile.get("description") or "sdl_core_generic"
        ),
        "mode": mode,
        "surfaces": surfaces,
        "notes": [f"Generated from {project_name}"],
        "threats": [],
        "elements": [],
        "flows": [],
        "knowledge_base": str(profile.get("knowledge_base") or "default"),
    }

    for surface in surfaces:
        for element in surface["elements"]:
            model["elements"].append({**element, "position": {}})
        for flow in surface["flows"]:
            model["flows"].append(
                {
                    "id": str(flow.get("id", "flow")),
                    "source_ref": str(flow.get("source_ref", "")),
                    "target_ref": str(flow.get("target_ref", "")),
                    "ordinal": flow.get("ordinal", 1),
                    "label": flow.get("label", ""),
                    "transport": flow.get("transport", ""),
                    "encryption": flow.get("encryption", ""),
                    "authentication": flow.get("authentication", ""),
                    "authorization": flow.get("authorization", ""),
                    "data_sensitivity": flow.get("data_sensitivity", ""),
                    "retention": flow.get("retention", ""),
                    "notes": flow.get("notes", ""),
                    "surface_id": surface["id"],
                }
            )

    return model


def _stable_custom_threat_type_id(threat_id: str, spec_threat: dict[str, Any]) -> str:
    """Create a deterministic ThreatType identifier for a custom spec threat."""
    source_id = str(spec_threat.get("id") or threat_id or "spec-threat").strip()
    return build_custom_threat_type_id(source_id)


def _resolve_mitigation_text(spec: dict[str, Any], threat: dict[str, Any]) -> str:
    """Resolve declared mitigation identifiers through the canonical contract."""
    return build_mitigation_text(spec, threat)


def _build_spec_threat_type_id(threat_id: str, spec_threat: dict[str, Any]) -> str:
    """Create a deterministic custom ThreatType identifier for a spec threat."""
    return _stable_custom_threat_type_id(threat_id, spec_threat)


def _map_phase2_threats(
    spec: dict[str, Any], model: dict[str, Any], profile: dict[str, Any]
) -> list[dict[str, Any]]:
    """Map declared spec threats into the internal threat payload."""
    threats: list[dict[str, Any]] = []
    assets = {
        asset.get("id"): asset
        for asset in spec.get("assets") or []
        if isinstance(asset, dict)
    }
    target_index = {}
    for element in model.get("elements", []):
        if isinstance(element, dict) and element.get("id"):
            target_index[str(element["id"])] = element
    for flow in model.get("flows", []):
        if isinstance(flow, dict) and flow.get("id"):
            target_index[str(flow["id"])] = flow

    seen_ids: set[str] = set()
    for spec_threat in spec.get("threats") or []:
        if not isinstance(spec_threat, dict):
            continue
        target_ref = str(spec_threat.get("target_ref", ""))
        target = target_index.get(target_ref)
        if not target:
            raise GenerationError(
                f"{spec_threat.get('id', 'spec-threat')}: target_ref "
                f"{target_ref or '(empty)'} resolves to no element or flow in "
                "the model",
                exit_code=EXIT_ERROR,
            )

        citations = spec_threat.get("citations") or {}
        stride_codes = _coerce_list(citations.get("stride"))
        nist_codes = _coerce_list(citations.get("nist"))
        mitre_codes = _coerce_list(citations.get("mitre"))
        stride_note = ",".join([str(entry) for entry in stride_codes]) or "N/A"
        nist_note = ",".join([str(entry) for entry in nist_codes]) or "N/A"
        mitre_note = ",".join([str(entry) for entry in mitre_codes]) or "N/A"
        notes_parts = [
            f"STRIDE={stride_note}",
            f"NIST={nist_note}",
            f"MITRE={mitre_note}",
        ]
        linked_assets = []
        properties: dict[str, Any] = {}
        for asset_id in _coerce_list(spec_threat.get("asset_ids", [])):
            asset = assets.get(str(asset_id))
            if asset:
                category = asset.get("category")
                sensitivity = asset.get("sensitivity")
                if category or sensitivity:
                    linked_assets.append(
                        f"asset:{asset.get('id', asset_id)}:"
                        f"category={category or 'n/a'}:"
                        f"sensitivity={sensitivity or 'n/a'}"
                    )
                    properties["asset_category"] = category
                    properties["asset_sensitivity"] = sensitivity
        if linked_assets:
            notes_parts.append("; ".join(linked_assets))

        target_type_id = target.get("type_id")
        if not target_type_id:
            if isinstance(target.get("source_ref"), str) and isinstance(
                target.get("target_ref"), str
            ):
                target_type_id = profile.get("type_ids", {}).get("data_flow", "GE.DF")
        if target_type_id:
            properties["target_type_id"] = str(target_type_id)

        # A spec threat may supply its own TMT display metadata. Only the keys the
        # threat contract recognizes are carried forward, so an unrecognized spec key
        # cannot reach the model. Authored values win over the derived defaults that
        # build_threat_instance_properties would otherwise substitute.
        supplied_properties = spec_threat.get("properties")
        if isinstance(supplied_properties, dict):
            for key in THREAT_PROPERTY_KEYS:
                value = supplied_properties.get(key)
                if value is not None and str(value).strip():
                    properties[key] = str(value)

        base_id = str(spec_threat.get("id", "spec-threat"))
        candidate_id = base_id
        suffix = 2
        while candidate_id in seen_ids:
            candidate_id = f"{base_id}-{suffix}"
            suffix += 1
        seen_ids.add(candidate_id)

        threat_type_id = _build_spec_threat_type_id(candidate_id, spec_threat)
        threats.append(
            {
                "id": candidate_id,
                "interaction_ref": str(spec_threat.get("interaction_ref", "")),
                "target_ref": target_ref,
                "title": str(spec_threat.get("title", "Threat")),
                "description": str(spec_threat.get("description", "Threat")),
                "category": str(spec_threat.get("category", "tampering")),
                "state": str(spec_threat.get("state", "Open")),
                "citations": {
                    "stride": [str(entry) for entry in stride_codes],
                    "nist": [str(entry) for entry in nist_codes],
                    "mitre": [str(entry) for entry in mitre_codes],
                },
                "notes": "; ".join(notes_parts),
                "properties": properties,
                "mitigations": _resolve_mitigation_text(spec, spec_threat),
                "source": "spec",
                "type_id": threat_type_id,
            }
        )

    return threats


def derive_threats(
    spec: dict[str, Any],
    model: dict[str, Any],
    mode: str,
    profile: dict[str, Any] | None = None,
    *,
    threat_generation_enabled: bool | None = None,
) -> list[dict[str, Any]]:
    """Derive a deterministic baseline threat list from the model and spec."""
    if mode == "diagram-only-defer-to-tmt":
        return []

    if not _coerce_bool(threat_generation_enabled, default=False):
        return _map_phase2_threats(spec, model, profile or {})

    threats: list[dict[str, Any]] = []
    element_kinds = {
        "external_interactor": ["Spoofing"],
        "process": [
            "Spoofing",
            "Tampering",
            "Repudiation",
            "Information Disclosure",
            "Denial of Service",
            "Elevation of Privilege",
        ],
        "data_store": ["Tampering", "Information Disclosure", "Denial of Service"],
        "data_flow": ["Tampering", "Information Disclosure", "Denial of Service"],
    }
    nist_family_map = {
        "Spoofing": ["IA"],
        "Tampering": ["SC"],
        "Repudiation": ["AU"],
        "Information Disclosure": ["SC"],
        "Denial of Service": ["SC"],
        "Elevation of Privilege": ["AC"],
    }

    for element in model.get("elements", []):
        kind = str(element.get("kind", "process"))
        if kind not in element_kinds:
            continue
        stride_categories = list(element_kinds[kind])
        if kind == "data_store" and "logging" in str(element.get("name", "")).lower():
            stride_categories.append("Repudiation")
        for stride_name in stride_categories:
            nist = nist_family_map.get(stride_name, ["SC"])
            threat_id = (
                f"generated-threat-{element['id']}-"
                f"{stride_name.lower().replace(' ', '-')}"
            )
            threats.append(
                {
                    "id": threat_id,
                    "target_ref": element["id"],
                    "title": f"{stride_name} against {element['name']}",
                    "description": (
                        f"The {kind.replace('_', ' ')} {element['name']} could be "
                        f"affected by {stride_name.lower()}."
                    ),
                    "category": stride_name.lower().replace(" ", "-"),
                    "state": "Open",
                    "citations": {
                        "stride": [stride_name[0]],
                        "nist": nist,
                        "mitre": [],
                    },
                    "notes": f"STRIDE={stride_name[0]}; NIST={','.join(nist)}",
                    "source": "generated",
                }
            )

    for flow in model.get("flows", []):
        for stride_name in ["Tampering", "Information Disclosure", "Denial of Service"]:
            threat_id = (
                f"generated-flow-threat-{flow['id']}-"
                f"{stride_name.lower().replace(' ', '-')}"
            )
            threats.append(
                {
                    "id": threat_id,
                    "target_ref": flow["id"],
                    "title": f"{stride_name} of flow {flow['id']}",
                    "description": (
                        f"The data flow {flow['id']} could be subject to "
                        f"{stride_name.lower()}."
                    ),
                    "category": stride_name.lower().replace(" ", "-"),
                    "state": "Open",
                    "citations": {
                        "stride": [stride_name[0]],
                        "nist": nist_family_map.get(stride_name, ["SC"]),
                        "mitre": [],
                    },
                    "notes": (
                        f"STRIDE={stride_name[0]}; "
                        f"NIST={','.join(nist_family_map.get(stride_name, ['SC']))}"
                    ),
                    "source": "generated",
                }
            )

    for abuse_case in spec.get("abuse_cases") or []:
        if not isinstance(abuse_case, dict):
            continue
        threat_id = f"abuse-{abuse_case.get('id', 'case')}"
        mitre_values = ",".join(_coerce_list(abuse_case.get("mitre_ids", [])))
        notes_parts = [
            "STRIDE=A",
            "NIST=SC",
            f"MITRE={mitre_values if abuse_case.get('mitre_ids') else 'None'}",
        ]
        evil_story = abuse_case.get("evil_user_story")
        properties: dict[str, Any] = {}
        if evil_story:
            notes_parts.append(f"EUS={evil_story}")
            properties["evil_user_story"] = evil_story
        threats.append(
            {
                "id": threat_id,
                "target_ref": abuse_case.get("flow_ids", [""])[0]
                if abuse_case.get("flow_ids")
                else "",
                "title": str(abuse_case.get("title", "Abuse case")),
                "description": str(abuse_case.get("description", "Abuse case")),
                "category": "abuse-case",
                "state": "Open",
                "citations": {
                    "stride": ["A"],
                    "nist": ["SC"],
                    "mitre": _coerce_list(abuse_case.get("mitre_ids"))
                    if isinstance(abuse_case, dict)
                    else [],
                },
                "notes": "; ".join(notes_parts),
                "properties": properties,
                "source": "abuse",
            }
        )

    threats.extend(_map_phase2_threats(spec, model, profile or {}))

    return threats


def resolve_profile(
    spec: dict[str, Any], cli_profile: str | None, template_dir: Path
) -> dict[str, Any]:
    """Resolve the template profile to use for the run."""
    profiles = load_template_profiles(template_dir)
    selected = cli_profile or spec.get("template_profile") or "sdl_core_generic"
    if selected in profiles:
        return profiles[selected]
    if selected == "sdl_core_generic":
        return {
            "description": "Generic SDL/Core profile",
            "knowledge_base": "default",
            "type_ids": {
                "external_interactor": "GE.EI",
                "process": "GE.P",
                "data_store": "GE.DS",
                "data_flow": "GE.DF",
                "trust_boundary_line": "GE.TB.L",
                "trust_boundary_box": "GE.TB.B",
                "annotation": "GE.A",
            },
        }
    raise GenerationError(f"Unknown template profile: {selected}", exit_code=EXIT_ERROR)


def _surface_zone_rank(surface: dict[str, Any], zone_key: str) -> int:
    """Return a stable trust-zone ordering for a given surface."""
    zone_order = {
        str(zone.get("id", "")): index
        for index, zone in enumerate(surface.get("trust_zones", []))
        if isinstance(zone, dict)
    }
    return zone_order.get(zone_key, 0)


def _surface_layout_gutter(elements: list[dict[str, Any]]) -> float:
    """Return the node separation required for a surface's measured node sizes.

    Readability is judged by separation relative to the surface's nominal node
    size, so the gutter scales with the nodes it separates.
    """
    extents = [
        max(_measure_node_dimensions(element))
        for element in elements
        if isinstance(element, dict)
        and str(element.get("kind", "")) != "trust_boundary_box"
        and str(element.get("layout_role") or "").lower() != "suppressed"
    ]
    if not extents:
        return MIN_LAYOUT_GUTTER
    nominal = max(MIN_NODE_SIZE, sum(extents) / len(extents))
    return max(MIN_LAYOUT_GUTTER, MIN_LAYOUT_GUTTER_RATIO * nominal)


def _measure_node_dimensions(
    element: dict[str, Any],
    *,
    min_width: float = MIN_NODE_SIZE,
    max_width: float = MAX_NODE_WIDTH,
    min_height: float = MIN_NODE_SIZE,
    max_height: float = MAX_NODE_HEIGHT,
) -> tuple[float, float]:
    """Estimate deterministic node dimensions from the text label."""
    name = str(element.get("name") or element.get("id") or "")
    text = " ".join(name.split())
    if not text:
        return (min_width, min_height)

    wrapped_lines = [
        line.strip()
        for line in textwrap.wrap(
            text,
            width=18,
            break_long_words=False,
            break_on_hyphens=False,
        )
        if line.strip()
    ]
    if not wrapped_lines:
        wrapped_lines = [text]
    line_count = max(1, len(wrapped_lines))
    max_line_length = max(len(line) for line in wrapped_lines)
    width = max(
        min_width,
        min(max_width, min_width + max(0, max_line_length - 8) * 6.0),
    )
    height = max(
        min_height,
        min(max_height, min_height + max(0, line_count - 1) * 20.0),
    )
    return (width, height)


def _flow_graph(
    surface: dict[str, Any],
) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Build deterministic adjacency lists for the flow graph on a surface."""
    elements = [
        element
        for element in surface.get("elements", [])
        if isinstance(element, dict)
        and str(element.get("kind", "")).lower() != "trust_boundary_box"
    ]
    element_ids = {str(element.get("id", "")) for element in elements}
    incoming: dict[str, list[str]] = {
        str(element.get("id", "")): [] for element in elements
    }
    outgoing: dict[str, list[str]] = {
        str(element.get("id", "")): [] for element in elements
    }
    for flow in surface.get("flows", []):
        if not isinstance(flow, dict):
            continue
        source_id = str(flow.get("source_ref", ""))
        target_id = str(flow.get("target_ref", ""))
        if source_id not in element_ids or target_id not in element_ids:
            continue
        outgoing.setdefault(source_id, []).append(target_id)
        incoming.setdefault(target_id, []).append(source_id)
    for node_id in list(outgoing):
        outgoing[node_id] = sorted(dict.fromkeys(outgoing[node_id]))
    for node_id in list(incoming):
        incoming[node_id] = sorted(dict.fromkeys(incoming[node_id]))
    return incoming, outgoing


def _analyze_surface_layout_graph(surface: dict[str, Any]) -> dict[str, Any]:
    """Derive deterministic graph ranks, branches, and lane metadata."""
    elements = [
        element
        for element in surface.get("elements", [])
        if isinstance(element, dict)
        and str(element.get("kind", "")).lower() != "trust_boundary_box"
    ]
    node_ids = sorted(
        {
            str(element.get("id", ""))
            for element in elements
            if str(element.get("id", ""))
        }
    )
    incoming, outgoing = _flow_graph(surface)
    incoming = {node_id: list(values) for node_id, values in incoming.items()}
    outgoing = {node_id: list(values) for node_id, values in outgoing.items()}

    index = 0
    stack: list[str] = []
    index_map: dict[str, int] = {}
    lowlink_map: dict[str, int] = {}
    stack_members: set[str] = set()
    sccs: list[list[str]] = []

    def _strong_connect(root_id: str) -> None:
        """Assign strongly connected components without recursing per node.

        Tarjan's algorithm is naturally recursive, but the recursion depth
        equals the longest simple path in the flow graph. A deep enough chain of
        elements would raise RecursionError while generating an otherwise valid
        model, so the depth-first walk is carried on an explicit stack instead.
        """
        nonlocal index
        # Each frame holds a node and how many of its neighbours it has consumed,
        # which is the state the recursive form kept in the loop variable.
        work: list[tuple[str, int]] = [(root_id, 0)]
        index_map[root_id] = index
        lowlink_map[root_id] = index
        index += 1
        stack.append(root_id)
        stack_members.add(root_id)

        while work:
            node_id, neighbor_position = work[-1]
            neighbors = outgoing.get(node_id, [])
            if neighbor_position < len(neighbors):
                work[-1] = (node_id, neighbor_position + 1)
                neighbor_id = neighbors[neighbor_position]
                if neighbor_id not in index_map:
                    index_map[neighbor_id] = index
                    lowlink_map[neighbor_id] = index
                    index += 1
                    stack.append(neighbor_id)
                    stack_members.add(neighbor_id)
                    work.append((neighbor_id, 0))
                elif neighbor_id in stack_members:
                    lowlink_map[node_id] = min(
                        lowlink_map[node_id], index_map[neighbor_id]
                    )
                continue

            work.pop()
            if work:
                parent_id = work[-1][0]
                lowlink_map[parent_id] = min(
                    lowlink_map[parent_id],
                    lowlink_map[node_id],
                )
            if lowlink_map[node_id] == index_map[node_id]:
                component: list[str] = []
                while True:
                    popped = stack.pop()
                    stack_members.remove(popped)
                    component.append(popped)
                    if popped == node_id:
                        break
                sccs.append(sorted(component))

    for node_id in node_ids:
        if node_id not in index_map:
            _strong_connect(node_id)

    component_ids: dict[str, int] = {}
    for component_index, component in enumerate(sorted(sccs)):
        for node_id in component:
            component_ids[node_id] = component_index

    component_outgoing: dict[int, set[int]] = {
        component_index: set() for component_index in range(len(sccs))
    }
    component_incoming: dict[int, set[int]] = {
        component_index: set() for component_index in range(len(sccs))
    }
    for node_id in node_ids:
        source_component = component_ids[node_id]
        for neighbor_id in outgoing.get(node_id, []):
            target_component = component_ids[neighbor_id]
            if source_component == target_component:
                continue
            component_outgoing[source_component].add(target_component)
            component_incoming[target_component].add(source_component)

    component_rank_map: dict[int, int] = {}
    indegree_map = {
        component_index: len(component_incoming[component_index])
        for component_index in range(len(sccs))
    }
    queue = deque(
        sorted(
            [
                component_index
                for component_index, degree in indegree_map.items()
                if degree == 0
            ]
        )
    )
    while queue:
        component_index = queue.popleft()
        for child_component in sorted(component_outgoing[component_index]):
            component_rank_map[child_component] = max(
                component_rank_map.get(child_component, 0),
                component_rank_map.get(component_index, 0) + 1,
            )
            indegree_map[child_component] -= 1
            if indegree_map[child_component] == 0:
                queue.append(child_component)

    node_ranks: dict[str, int] = {}
    branch_groups: dict[str, int] = {}
    branch_index = 0
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in node_ids}
    for source_id in node_ids:
        for target_id in outgoing.get(source_id, []):
            adjacency[source_id].add(target_id)
        for parent_id in incoming.get(source_id, []):
            adjacency[source_id].add(parent_id)

    visited_nodes: set[str] = set()
    for node_id in sorted(node_ids):
        if node_id in visited_nodes:
            continue
        if not adjacency.get(node_id):
            # Unconnected nodes are not independent branches; grouping them
            # together keeps lane ordering driven by node content instead of
            # by an arbitrary per-node branch index.
            visited_nodes.add(node_id)
            branch_groups[node_id] = -1
            continue
        branch_nodes: list[str] = []
        branch_queue = deque([node_id])
        while branch_queue:
            current_id = branch_queue.popleft()
            if current_id in visited_nodes:
                continue
            visited_nodes.add(current_id)
            branch_nodes.append(current_id)
            for neighbor_id in sorted(adjacency.get(current_id, set())):
                if neighbor_id not in visited_nodes:
                    branch_queue.append(neighbor_id)
        for branch_node_id in sorted(branch_nodes):
            branch_groups[branch_node_id] = branch_index
        branch_index += 1

    for component_index, component in enumerate(sorted(sccs)):
        component_nodes = sorted(component)
        component_rank = component_rank_map.get(component_index, 0)
        if len(component_nodes) > 1:
            anchor_node = component_nodes[-1]
            local_order: list[str] = []
            local_seen: set[str] = set()
            local_stack = [anchor_node]
            while local_stack:
                current_node = local_stack.pop()
                if current_node in local_seen:
                    continue
                local_seen.add(current_node)
                local_order.append(current_node)
                for neighbor_id in sorted(outgoing.get(current_node, []), reverse=True):
                    if component_ids[neighbor_id] != component_index:
                        continue
                    if neighbor_id not in local_seen:
                        local_stack.append(neighbor_id)
            for offset, node_id in enumerate(
                local_order
                + [item for item in component_nodes if item not in local_seen]
            ):
                node_ranks[node_id] = component_rank * 1000 + offset
        else:
            node_ranks[component_nodes[0]] = component_rank * 1000

    for node_id in node_ids:
        if node_id not in node_ranks:
            node_ranks[node_id] = 0

    reverse_edge_pairs: list[tuple[str, str]] = []
    reverse_edge_members: set[str] = set()
    for component_index, component in enumerate(sorted(sccs)):
        component_nodes = sorted(component)
        if len(component_nodes) <= 1:
            continue
        pair = tuple(sorted((component_nodes[0], component_nodes[-1])))
        if pair not in reverse_edge_pairs:
            reverse_edge_pairs.append(pair)
            reverse_edge_members.update(pair)

    return_lane_nodes: set[str] = set()
    for component_index, component in enumerate(sorted(sccs)):
        component_nodes = sorted(component)
        if len(component_nodes) > 1:
            return_lane_nodes.update(component_nodes)
    return_lane_nodes.update(reverse_edge_members)

    cross_zone_flow_counts: dict[tuple[str, str], int] = {}
    for flow in surface.get("flows", []):
        if not isinstance(flow, dict):
            continue
        source_id = str(flow.get("source_ref", ""))
        target_id = str(flow.get("target_ref", ""))
        if (
            not source_id
            or not target_id
            or source_id not in node_ids
            or target_id not in node_ids
        ):
            continue
        source_zone = str(
            next(
                (
                    element.get("trust_zone_id", "")
                    for element in elements
                    if str(element.get("id", "")) == source_id
                ),
                "",
            )
        )
        target_zone = str(
            next(
                (
                    element.get("trust_zone_id", "")
                    for element in elements
                    if str(element.get("id", "")) == target_id
                ),
                "",
            )
        )
        if not source_zone or not target_zone or source_zone == target_zone:
            continue
        key = (source_zone, target_zone)
        cross_zone_flow_counts[key] = cross_zone_flow_counts.get(key, 0) + 1

    return {
        "incoming": incoming,
        "outgoing": outgoing,
        "scc_component_ids": component_ids,
        "node_ranks": node_ranks,
        "branch_groups": branch_groups,
        "fan_in": {node_id: len(incoming.get(node_id, [])) for node_id in node_ids},
        "fan_out": {node_id: len(outgoing.get(node_id, [])) for node_id in node_ids},
        "reverse_edge_pairs": reverse_edge_pairs,
        "return_lane_nodes": return_lane_nodes,
        "cross_zone_flow_counts": cross_zone_flow_counts,
    }


def _build_surface_layout_candidates(
    surface: dict[str, Any],
    graph: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Generate deterministic whole-surface zone-order and placement candidates."""
    zone_ids = [
        str(zone.get("id", ""))
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict) and str(zone.get("id", ""))
    ]
    if not zone_ids:
        return []

    preferences = _resolve_surface_layout_preferences(
        surface,
        layout_overlay=layout_overlay,
    )
    base_zone_order = _sorted_zone_ids(
        surface,
        zone_order=preferences.get("zone_order"),
    )
    if preferences.get("zone_order"):
        base_zone_order = [
            zone_id for zone_id in preferences["zone_order"] if zone_id in zone_ids
        ]
    if not base_zone_order:
        base_zone_order = list(zone_ids)

    def _zone_order_variants(order: list[str]) -> list[list[str]]:
        variants = [list(order)]
        if len(order) > 1:
            variants.append(list(reversed(order)))
        if len(order) > 2:
            variants.append([order[0], order[-1], *order[1:-1]])
        return variants

    candidates: list[dict[str, Any]] = []
    seen_signatures: set[tuple[Any, ...]] = set()
    zone_flow_ranks = _zone_flow_ranks(surface)
    for orientation in SURFACE_LAYOUT_ORIENTATIONS:
        for zone_order in _zone_order_variants(base_zone_order):
            signature = (orientation, tuple(zone_order))
            if signature in seen_signatures:
                continue
            seen_signatures.add(signature)
            candidates.append(
                {
                    "surface_id": str(surface.get("id", "surface")),
                    "orientation": orientation,
                    "zone_order": zone_order,
                    "node_ranks": graph.get("node_ranks", {}),
                    "branch_groups": graph.get("branch_groups", {}),
                    "reverse_edge_members": {
                        node_id
                        for node_id in graph.get("node_ranks", {})
                        if node_id
                        in {item[1] for item in graph.get("reverse_edge_pairs", [])}
                    },
                    "return_lane_nodes": set(graph.get("return_lane_nodes", set())),
                    "fan_in": graph.get("fan_in", {}),
                    "fan_out": graph.get("fan_out", {}),
                    "zone_flow_ranks": zone_flow_ranks,
                }
            )

    # The enumeration is a full cross product of two fixed dimensions, so its
    # size is bounded by construction rather than by a running cap. Assert the
    # bound instead of silently truncating: a future dimension that makes the
    # product grow must be a deliberate change to this constant.
    if len(candidates) > MAX_SURFACE_LAYOUT_CANDIDATES:
        raise GenerationError(
            f"surface {surface.get('id', 'surface')} produced {len(candidates)} "
            f"layout candidates, above the structural bound of "
            f"{MAX_SURFACE_LAYOUT_CANDIDATES}",
            exit_code=EXIT_ERROR,
        )

    for candidate in candidates:
        candidate["score"] = tm7_visual_feedback.score_surface_layout_candidate(
            candidate,
            viewport_target=preferences.get(
                "viewport_target",
                (0.0, 0.0, DEFAULT_VIEWPORT_WIDTH, DEFAULT_VIEWPORT_HEIGHT),
            ),
        )
    return sorted(
        candidates,
        key=lambda candidate: (
            candidate["score"],
            candidate["orientation"],
            tuple(candidate["zone_order"]),
        ),
    )


SURFACE_LAYOUT_CANDIDATE_MEMBERS = (
    "surface_id",
    "orientation",
    "zone_order",
    "node_ranks",
    "branch_groups",
    "reverse_edge_members",
    "return_lane_nodes",
    "fan_in",
    "fan_out",
    "zone_flow_ranks",
)


def _validate_surface_layout_candidate(
    candidate: dict[str, Any], surface_id: str
) -> list[str]:
    """Return the invariant violations of one whole-surface layout candidate.

    Selection validates before it commits, so a candidate missing the members
    downstream placement reads is rejected at its origin rather than surfacing
    as a confusing failure elsewhere or as a silently degraded layout.
    """
    violations: list[str] = []
    missing = [
        member for member in SURFACE_LAYOUT_CANDIDATE_MEMBERS if member not in candidate
    ]
    if missing:
        violations.append(f"missing members {', '.join(missing)}")
    if candidate.get("orientation") not in SURFACE_LAYOUT_ORIENTATIONS:
        violations.append(f"unsupported orientation {candidate.get('orientation')!r}")
    zone_order = candidate.get("zone_order")
    if not isinstance(zone_order, list):
        violations.append("zone_order must be a list")
    else:
        if any(not str(zone_id) for zone_id in zone_order):
            violations.append("zone_order contains an unnamed zone")
        if len(set(zone_order)) != len(zone_order):
            violations.append("zone_order repeats a zone")
    return [f"{surface_id}: {violation}" for violation in violations]


def _select_surface_layout_candidate(
    surface: dict[str, Any],
    graph: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Select the best valid deterministic whole-surface orientation and order."""
    surface_id = str(surface.get("id", "surface"))
    candidates = _build_surface_layout_candidates(
        surface,
        graph,
        layout_overlay=layout_overlay,
    )
    if not candidates:
        # A surface with no trust zones produces no candidate. The fallback is a
        # real candidate and carries every member of the contract, so downstream
        # placement cannot tell it apart by shape.
        candidates = [
            {
                "surface_id": surface_id,
                "orientation": SURFACE_LAYOUT_ORIENTATIONS[0],
                "zone_order": [
                    str(zone.get("id", ""))
                    for zone in surface.get("trust_zones", [])
                    if isinstance(zone, dict) and str(zone.get("id", ""))
                ],
                "node_ranks": graph.get("node_ranks", {}),
                "branch_groups": graph.get("branch_groups", {}),
                "reverse_edge_members": set(),
                "return_lane_nodes": set(graph.get("return_lane_nodes", set())),
                "fan_in": graph.get("fan_in", {}),
                "fan_out": graph.get("fan_out", {}),
                "zone_flow_ranks": _zone_flow_ranks(surface),
            }
        ]

    rejected: list[str] = []
    for candidate in candidates:
        violations = _validate_surface_layout_candidate(candidate, surface_id)
        if not violations:
            return candidate
        rejected.extend(violations)
    raise GenerationError(
        f"no valid layout candidate for surface {surface_id}:\n"
        + "\n".join(sorted(rejected)),
        exit_code=EXIT_ERROR,
    )


def _rect_anchor(
    rect: dict[str, float], target: tuple[float, float]
) -> tuple[float, float]:
    """Return the edge point where a line from the rectangle center exits."""
    center_x = rect["left"] + (rect["width"] / 2)
    center_y = rect["top"] + (rect["height"] / 2)
    dx = target[0] - center_x
    dy = target[1] - center_y
    if dx == 0 and dy == 0:
        return (center_x, center_y)
    scale_x = (rect["width"] / 2) / abs(dx) if dx != 0 else float("inf")
    scale_y = (rect["height"] / 2) / abs(dy) if dy != 0 else float("inf")
    scale = min(scale_x, scale_y)
    if scale == float("inf"):
        scale = 1.0
    return (center_x + dx * scale, center_y + dy * scale)


def _segment_intersects_rect(
    start: tuple[float, float],
    end: tuple[float, float],
    rect: dict[str, float],
) -> bool:
    """Return True when a line segment intersects an axis-aligned rectangle.

    The generator holds rectangles as left/top/width/height mappings while the
    feedback loop holds them as left/top/right/bottom tuples. Both route through
    the one canonical algorithm so the geometry the generator publishes and the
    geometry the feedback loop scores cannot disagree.
    """
    return tm7_visual_feedback.segment_intersects_bounds(
        start,
        end,
        *tm7_visual_feedback.rect_bounds_from_ltwh(rect),
    )


def _segment_intersects_any_rect(
    start: tuple[float, float],
    end: tuple[float, float],
    rects: list[dict[str, float]],
) -> bool:
    """Return True when a segment intersects any of the supplied rectangles."""
    return any(_segment_intersects_rect(start, end, rect) for rect in rects)


def _segment_intersects_segment_strict(
    start_a: tuple[float, float],
    end_a: tuple[float, float],
    start_b: tuple[float, float],
    end_b: tuple[float, float],
) -> bool:
    """Return True when two segments cross at a genuine non-shared point."""
    if start_a == end_a or start_b == end_b:
        return False
    if start_a == start_b or start_a == end_b or end_a == start_b or end_a == end_b:
        return False
    orientation_a = tm7_visual_feedback._orientation(start_a, end_a, start_b)
    orientation_b = tm7_visual_feedback._orientation(start_a, end_a, end_b)
    orientation_c = tm7_visual_feedback._orientation(start_b, end_b, start_a)
    orientation_d = tm7_visual_feedback._orientation(start_b, end_b, end_a)
    if (
        orientation_a == 0
        or orientation_b == 0
        or orientation_c == 0
        or orientation_d == 0
    ):
        return False
    return orientation_a != orientation_b and orientation_c != orientation_d


def _build_connector_label_layout(
    label: str | None,
    transport: str | None,
    *,
    handle: tuple[float, float],
    label_offset: tuple[float, float] | None = None,
) -> dict[str, Any]:
    """Create deterministic connector label metadata for a flow."""
    return tm7_visual_feedback.build_connector_label_layout(
        label,
        transport,
        handle=handle,
        label_offset=label_offset,
    )


def _rects_intersect(
    left: dict[str, float],
    right: dict[str, float],
) -> bool:
    """Return whether two axis-aligned rectangles have positive intersection."""
    return not (
        left["left"] + left["width"] <= right["left"]
        or right["left"] + right["width"] <= left["left"]
        or left["top"] + left["height"] <= right["top"]
        or right["top"] + right["height"] <= left["top"]
    )


def _build_dense_candidate_handles(
    *,
    handle: tuple[float, float],
    source_point: tuple[float, float],
    target_point: tuple[float, float],
    routing_obstacles: list[dict[str, float]],
    envelope_min_x: float,
    envelope_max_x: float,
    envelope_min_y: float,
    envelope_max_y: float,
) -> list[tuple[float, float]]:
    """Build a bounded, deterministic set of candidate handles for label placement."""
    minimum_x = min(source_point[0], target_point[0])
    maximum_x = max(source_point[0], target_point[0])
    minimum_y = min(source_point[1], target_point[1])
    maximum_y = max(source_point[1], target_point[1])
    for rect in routing_obstacles:
        minimum_x = min(minimum_x, rect["left"])
        maximum_x = max(maximum_x, rect["left"] + rect["width"])
        minimum_y = min(minimum_y, rect["top"])
        maximum_y = max(maximum_y, rect["top"] + rect["height"])
    candidate_handles: list[tuple[float, float]] = [handle]
    axis_points_x = [
        envelope_min_x,
        (minimum_x + maximum_x) / 2.0,
        envelope_max_x,
    ]
    axis_points_y = [
        envelope_min_y,
        (minimum_y + maximum_y) / 2.0,
        envelope_max_y,
    ]
    for x_value in axis_points_x:
        for y_value in axis_points_y:
            candidate_handles.append(
                (
                    max(24.0, x_value),
                    max(24.0, y_value),
                )
            )

    step = 40.0
    for x_value in _iter_grid_values(
        envelope_min_x,
        envelope_max_x,
        step,
    ):
        for y_value in _iter_grid_values(
            envelope_min_y,
            envelope_max_y,
            step,
        ):
            candidate_handles.append(
                (
                    max(24.0, x_value),
                    max(24.0, y_value),
                )
            )

    for rect in routing_obstacles:
        clearance = 24.0
        offset_x = min(clearance, max(12.0, rect["width"] / 2.0))
        offset_y = min(clearance, max(12.0, rect["height"] / 2.0))
        candidate_handles.extend(
            [
                (max(24.0, rect["left"] + offset_x), max(24.0, rect["top"] + offset_y)),
                (
                    max(24.0, rect["left"] + rect["width"] - offset_x),
                    max(24.0, rect["top"] + offset_y),
                ),
                (
                    max(24.0, rect["left"] + offset_x),
                    max(24.0, rect["top"] + rect["height"] - offset_y),
                ),
                (
                    max(24.0, rect["left"] + rect["width"] - offset_x),
                    max(24.0, rect["top"] + rect["height"] - offset_y),
                ),
            ]
        )

    return list(dict.fromkeys(candidate_handles))


def _iter_grid_values(start: float, end: float, step: float) -> list[float]:
    """Return a deterministic list of grid values spanning the inclusive range."""
    if step <= 0.0:
        return [start]
    values: list[float] = []
    current = start
    while current <= end:
        values.append(current)
        current += step
    if values and values[-1] != end:
        values.append(end)
    return values


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
    if _segment_intersects_rect(
        start,
        end,
        {
            "left": left,
            "top": top,
            "width": right - left,
            "height": bottom - top,
        },
    ):
        return 0.0
    corners = [(left, top), (right, top), (right, bottom), (left, bottom)]
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


def _place_connector_label(
    label: str | None,
    transport: str | None,
    *,
    handle: tuple[float, float],
    obstacles: list[dict[str, float]],
    routing_obstacles: list[dict[str, float]],
    source_point: tuple[float, float],
    target_point: tuple[float, float],
    existing_segments: list[tuple[tuple[float, float], tuple[float, float]]]
    | None = None,
    preserve_handle: bool = False,
    explicit_handle: bool = False,
    reverse_lane_sign: float = 0.0,
    existing_handles: list[tuple[float, float]] | None = None,
    canvas_bounds: tuple[float, float] | None = None,
) -> dict[str, Any]:
    """Choose a deterministic connector label placement without failing the model."""
    fixed_handle = handle
    # TMT draws every connector label centred on the handle point, and the
    # handle is the only label geometry the model serializes. A non-zero offset
    # therefore moves the predicted rect without moving the drawn label, so a
    # search that ranks offsets scores placements the renderer never produces.
    # Searching handles alone keeps the prediction equal to the render.
    candidate_offsets: list[tuple[float, float]] = [(0.0, 0.0)]

    def evaluate_candidate(
        candidate_handle: tuple[float, float],
        candidate_offset: tuple[float, float],
    ) -> dict[str, Any]:
        layout = _build_connector_label_layout(
            label,
            transport,
            handle=candidate_handle,
            label_offset=candidate_offset,
        )
        left, top, width, height = layout["label_rect"]
        rect = {
            "left": float(left),
            "top": float(top),
            "width": float(width),
            "height": float(height),
        }
        label_clear = not any(
            _rects_intersect(rect, obstacle) for obstacle in obstacles
        )
        label_obstacle_hits = sum(
            1 for obstacle in obstacles if _rects_intersect(rect, obstacle)
        )
        route_obstacle_hits = 0
        route_obstacle_hits += int(
            _segment_intersects_any_rect(
                source_point, candidate_handle, routing_obstacles
            )
        )
        route_obstacle_hits += int(
            _segment_intersects_any_rect(
                candidate_handle, target_point, routing_obstacles
            )
        )
        prior_segments = existing_segments or []
        crossings = 0
        legs = [(source_point, candidate_handle), (candidate_handle, target_point)]
        for leg_start, leg_end in legs:
            for prior_start, prior_end in prior_segments:
                exact_duplicate = (
                    leg_start == prior_start and leg_end == prior_end
                ) or (leg_start == prior_end and leg_end == prior_start)
                if exact_duplicate or _segment_intersects_segment_strict(
                    leg_start,
                    leg_end,
                    prior_start,
                    prior_end,
                ):
                    crossings += 1
        path_length = sum(
            math.hypot(end[0] - start[0], end[1] - start[1]) for start, end in legs
        )
        rect_center = (
            rect["left"] + rect["width"] / 2.0,
            rect["top"] + rect["height"] / 2.0,
        )
        # The arrowhead renders at the target anchor, so a label that crowds
        # that point makes the flow direction ambiguous in native TMT.
        arrowhead_clearance = math.hypot(
            rect_center[0] - target_point[0],
            rect_center[1] - target_point[1],
        )
        arrowhead_penalty = max(
            0.0,
            MIN_LABEL_ARROWHEAD_CLEARANCE - arrowhead_clearance,
        )
        ownership_distance = min(
            _rect_to_segment_distance(
                (
                    rect["left"],
                    rect["top"],
                    rect["left"] + rect["width"],
                    rect["top"] + rect["height"],
                ),
                leg_start,
                leg_end,
            )
            for leg_start, leg_end in legs
        )
        ownership_penalty = max(
            0.0,
            ownership_distance - MAX_LABEL_OWNERSHIP_DISTANCE,
        )
        reverse_label_penalty = 0.0
        if reverse_lane_sign:
            # A bidirectional pair must bend to opposite sides so its two
            # labels do not stack. The lane is measured from the candidate
            # handle against the straight source-to-target line, because the
            # handle is what the model serializes and what TMT centres the
            # label on. Measuring the predicted rect against the handle would
            # compare a value to itself.
            flow_is_horizontal = abs(target_point[0] - source_point[0]) >= abs(
                target_point[1] - source_point[1]
            )
            if flow_is_horizontal:
                midpoint = (source_point[1] + target_point[1]) / 2.0
                lane_offset = candidate_handle[1] - midpoint
            else:
                midpoint = (source_point[0] + target_point[0]) / 2.0
                lane_offset = candidate_handle[0] - midpoint
            if lane_offset * reverse_lane_sign <= 0.0:
                reverse_label_penalty = MIN_LAYOUT_GUTTER + abs(lane_offset)
        displacement = abs(candidate_handle[0] - handle[0]) + abs(
            candidate_handle[1] - handle[1]
        )
        # A label driven past the visible canvas is truncated by the renderer,
        # which no obstacle or routing term measures: the label is clear of
        # every rectangle precisely because it sits where nothing else does.
        # The penalty is the distance the rect overruns the canvas, so it is
        # zero for every placement already inside it and a surface whose labels
        # all land on-canvas ranks exactly as it did before.
        canvas_penalty = 0.0
        if canvas_bounds is not None:
            canvas_penalty = max(
                0.0,
                (rect["left"] + rect["width"]) - canvas_bounds[0],
            ) + max(0.0, (rect["top"] + rect["height"]) - canvas_bounds[1])
        return {
            "layout": layout,
            "label_clear": label_clear,
            "label_obstacle_hits": label_obstacle_hits,
            "route_obstacle_hits": route_obstacle_hits,
            "crossings": crossings,
            "canvas_penalty": canvas_penalty,
            "arrowhead_penalty": arrowhead_penalty,
            "ownership_penalty": ownership_penalty,
            "reverse_label_penalty": reverse_label_penalty,
            "path_length": path_length,
            "displacement": displacement,
            "candidate_handle": candidate_handle,
            "candidate_offset": candidate_offset,
        }

    if preserve_handle and explicit_handle:
        evaluations = []
        for candidate_offset in candidate_offsets:
            evaluation = evaluate_candidate(handle, candidate_offset)
            evaluations.append(evaluation)
        if not evaluations:
            raise ValueError("connector label has no clear deterministic placement")
        label_clear_candidates = [
            evaluation for evaluation in evaluations if evaluation["label_clear"]
        ]
        route_clear_candidates = [
            evaluation
            for evaluation in label_clear_candidates
            if evaluation["route_obstacle_hits"] == 0 and evaluation["crossings"] == 0
        ]
        if not route_clear_candidates:
            route_clear_candidates = [
                evaluation
                for evaluation in evaluations
                if evaluation["route_obstacle_hits"] == 0
                and evaluation["crossings"] == 0
            ]
        ranked = route_clear_candidates or label_clear_candidates or evaluations
        if route_clear_candidates:
            best = min(
                ranked,
                key=lambda item: (
                    item["label_obstacle_hits"],
                    item["route_obstacle_hits"],
                    item["crossings"],
                    item["canvas_penalty"],
                    item["arrowhead_penalty"],
                    item["ownership_penalty"],
                    item["reverse_label_penalty"],
                    item["path_length"],
                    item["displacement"],
                    item["candidate_offset"][0],
                    item["candidate_offset"][1],
                ),
            )
        else:
            best = min(
                ranked,
                key=lambda item: (
                    item["label_obstacle_hits"],
                    item["route_obstacle_hits"],
                    item["crossings"],
                    item["canvas_penalty"],
                    item["arrowhead_penalty"],
                    item["ownership_penalty"],
                    item["reverse_label_penalty"],
                    item["path_length"],
                    item["displacement"],
                    item["candidate_offset"][0],
                    item["candidate_offset"][1],
                ),
            )
        layout = best["layout"]
        layout["handle_point"] = handle
        return layout

    if preserve_handle:
        minimum_x = min(source_point[0], target_point[0])
        maximum_x = max(source_point[0], target_point[0])
        minimum_y = min(source_point[1], target_point[1])
        maximum_y = max(source_point[1], target_point[1])
        for rect in routing_obstacles:
            minimum_x = min(minimum_x, rect["left"])
            maximum_x = max(maximum_x, rect["left"] + rect["width"])
            minimum_y = min(minimum_y, rect["top"])
            maximum_y = max(maximum_y, rect["top"] + rect["height"])
        envelope_min_x = minimum_x - 160.0
        envelope_max_x = maximum_x + 160.0
        envelope_min_y = minimum_y - 160.0
        envelope_max_y = maximum_y + 160.0
        # The envelope reaches past the content so a label can escape a crowded
        # neighbourhood, and past the canvas edge that reach is worthless: TMT
        # centres the label on the handle, so a handle within half a label of
        # the edge is drawn truncated. Clamping the envelope keeps the search
        # inside the region where a label can actually be read, using this
        # label's own measured extent rather than the widest possible one. The
        # clamp never crosses the nominal handle, so every connector keeps at
        # least its own starting placement and a surface whose labels already
        # sit on-canvas searches exactly the region it did before.
        if canvas_bounds is not None:
            nominal_rect = _build_connector_label_layout(
                label,
                transport,
                handle=handle,
                label_offset=(0.0, 0.0),
            )["label_rect"]
            envelope_max_x = min(
                envelope_max_x,
                max(handle[0], canvas_bounds[0] - float(nominal_rect[2]) / 2.0),
            )
            envelope_max_y = min(
                envelope_max_y,
                max(handle[1], canvas_bounds[1] - float(nominal_rect[3]) / 2.0),
            )
        candidate_handles = list(
            dict.fromkeys(
                _build_dense_candidate_handles(
                    handle=handle,
                    source_point=source_point,
                    target_point=target_point,
                    routing_obstacles=routing_obstacles,
                    envelope_min_x=envelope_min_x,
                    envelope_max_x=envelope_max_x,
                    envelope_min_y=envelope_min_y,
                    envelope_max_y=envelope_max_y,
                )
            )
        )
        occupied_handles = existing_handles or []

        def _build_evaluations(*, avoid_occupied: bool) -> list[dict[str, Any]]:
            results: list[dict[str, Any]] = []
            for candidate_handle in candidate_handles:
                if not (
                    envelope_min_x <= candidate_handle[0] <= envelope_max_x
                    and envelope_min_y <= candidate_handle[1] <= envelope_max_y
                ):
                    continue
                # This function chooses the handle that is finally serialized,
                # and TMT renders each connector label at its handle. A
                # candidate landing on an already-placed handle would
                # superimpose two labels.
                if avoid_occupied and any(
                    math.hypot(
                        candidate_handle[0] - occupied[0],
                        candidate_handle[1] - occupied[1],
                    )
                    < MIN_HANDLE_SEPARATION
                    for occupied in occupied_handles
                ):
                    continue
                for candidate_offset in candidate_offsets:
                    results.append(
                        evaluate_candidate(candidate_handle, candidate_offset)
                    )
            return results

        evaluations = _build_evaluations(avoid_occupied=True)
        if not evaluations:
            evaluations = _build_evaluations(avoid_occupied=False)
        if not evaluations:
            raise ValueError("connector label has no clear deterministic placement")
        label_clear_candidates = [
            evaluation for evaluation in evaluations if evaluation["label_clear"]
        ]
        route_clear_candidates = [
            evaluation
            for evaluation in label_clear_candidates
            if evaluation["route_obstacle_hits"] == 0 and evaluation["crossings"] == 0
        ]
        if not route_clear_candidates:
            # No placement is both label-clear and route-clear. Ranking only the
            # route-clear ones discards every readable placement, which is how
            # two labels end up overprinted into unreadable text while the
            # connectors beneath them route perfectly; ranking the union instead
            # lets a readable label pull the choice off a clean route and costs
            # more crossings than the diagram can afford. The tier is therefore
            # route-clear plus only those label-clear candidates that route no
            # worse than the best route-clear one, so readability is bought with
            # the routing budget that is already being spent.
            route_only = [
                evaluation
                for evaluation in evaluations
                if evaluation["route_obstacle_hits"] == 0
                and evaluation["crossings"] == 0
            ]
            best_route_cost = min(
                (
                    (evaluation["route_obstacle_hits"], evaluation["crossings"])
                    for evaluation in route_only
                ),
                default=(0, 0),
            )
            readable_at_cost = [
                evaluation
                for evaluation in evaluations
                if evaluation["label_clear"]
                and evaluation["route_obstacle_hits"] <= best_route_cost[0]
                and evaluation["crossings"]
                <= best_route_cost[1] + LABEL_READABILITY_CROSSING_BUDGET
            ]
            route_clear_candidates = route_only + readable_at_cost
        ranked = route_clear_candidates or label_clear_candidates or evaluations
        # A label that drifts away from its own connector is ambiguous about
        # which flow it describes, which is a correctness problem rather than an
        # aesthetic one. Prefer owned placements within the ranked tier before
        # falling back to the wider set.
        owned_candidates = [
            evaluation
            for evaluation in ranked
            if evaluation["ownership_penalty"] == 0.0
        ]
        if owned_candidates:
            ranked = owned_candidates
        if route_clear_candidates:
            best = min(
                ranked,
                key=lambda item: (
                    item["label_obstacle_hits"],
                    item["route_obstacle_hits"],
                    item["crossings"],
                    item["canvas_penalty"],
                    item["arrowhead_penalty"],
                    item["ownership_penalty"],
                    item["reverse_label_penalty"],
                    item["path_length"],
                    item["displacement"],
                    item["candidate_handle"][0],
                    item["candidate_handle"][1],
                    item["candidate_offset"][0],
                    item["candidate_offset"][1],
                ),
            )
        else:
            best = min(
                ranked,
                key=lambda item: (
                    item["label_obstacle_hits"],
                    item["route_obstacle_hits"],
                    item["crossings"],
                    item["canvas_penalty"],
                    item["arrowhead_penalty"],
                    item["ownership_penalty"],
                    item["reverse_label_penalty"],
                    item["path_length"],
                    item["displacement"],
                    item["candidate_handle"][0],
                    item["candidate_handle"][1],
                    item["candidate_offset"][0],
                    item["candidate_offset"][1],
                ),
            )
        layout = best["layout"]
        layout["handle_point"] = best["candidate_handle"]
        return layout

    evaluations = []
    for candidate_offset in candidate_offsets:
        evaluation = evaluate_candidate(fixed_handle, candidate_offset)
        evaluations.append(evaluation)
    if not evaluations:
        raise ValueError("connector label has no clear deterministic placement")
    label_clear_candidates = [
        evaluation for evaluation in evaluations if evaluation["label_clear"]
    ]
    route_clear_candidates = [
        evaluation
        for evaluation in label_clear_candidates
        if evaluation["route_obstacle_hits"] == 0 and evaluation["crossings"] == 0
    ]
    if not route_clear_candidates:
        route_clear_candidates = [
            evaluation
            for evaluation in evaluations
            if evaluation["route_obstacle_hits"] == 0 and evaluation["crossings"] == 0
        ]
    ranked = route_clear_candidates or label_clear_candidates or evaluations
    if route_clear_candidates:
        best = min(
            ranked,
            key=lambda item: (
                item["label_obstacle_hits"],
                item["route_obstacle_hits"],
                item["crossings"],
                item["canvas_penalty"],
                item["arrowhead_penalty"],
                item["ownership_penalty"],
                item["reverse_label_penalty"],
                item["path_length"],
                item["displacement"],
                item["candidate_offset"][0],
                item["candidate_offset"][1],
            ),
        )
    else:
        best = min(
            ranked,
            key=lambda item: (
                item["label_obstacle_hits"],
                item["route_obstacle_hits"],
                item["crossings"],
                item["canvas_penalty"],
                item["arrowhead_penalty"],
                item["ownership_penalty"],
                item["reverse_label_penalty"],
                item["path_length"],
                item["displacement"],
                item["candidate_offset"][0],
                item["candidate_offset"][1],
            ),
        )
    layout = best["layout"]
    layout["handle_point"] = fixed_handle
    return layout


def _resolve_connector_rule(
    surface: dict[str, Any],
    flow: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None,
) -> dict[str, Any] | None:
    """Resolve connector override rules for a flow when present."""
    if not isinstance(layout_overlay, dict):
        return None
    surface_id = str(surface.get("id", ""))
    flow_id = str(flow.get("id", ""))
    for rule in layout_overlay.get("connector_rules", []) or []:
        if not isinstance(rule, dict):
            continue
        if str(rule.get("surface_id", "")) != surface_id:
            continue
        if str(rule.get("flow_id", "")) != flow_id:
            continue
        return rule
    return None


def _allocate_edge_port_slots(
    surface: dict[str, Any],
    graph: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Assign deterministic node-side port slots for every edge group.

    Edges are grouped by the node side they leave or enter, so multiple edges
    sharing a node never collapse onto a single convergence point. Reverse
    pairs receive opposing slot order so each direction stays distinguishable.
    """
    elements = {
        str(element.get("id", "")): element
        for element in surface.get("elements", [])
        if isinstance(element, dict)
        and str(element.get("kind", "")).lower() != "trust_boundary_box"
    }
    reverse_pairs = {
        tuple(sorted(pair)) for pair in graph.get("reverse_edge_pairs", []) or []
    }

    ordered_flows = sorted(
        [
            flow
            for flow in surface.get("flows", [])
            if isinstance(flow, dict)
            and str(flow.get("source_ref", "")) in elements
            and str(flow.get("target_ref", "")) in elements
        ],
        key=lambda flow: (
            int(flow.get("ordinal", 0) or 0),
            str(flow.get("id", "")),
        ),
    )

    side_groups: dict[tuple[str, str, str], list[str]] = {}
    for flow in ordered_flows:
        flow_id = str(flow.get("id", ""))
        source_id = str(flow.get("source_ref", ""))
        target_id = str(flow.get("target_ref", ""))
        pair_key = tuple(sorted((source_id, target_id)))
        is_reverse = pair_key in reverse_pairs
        source_side = "outgoing-reverse" if is_reverse else "outgoing"
        target_side = "incoming-reverse" if is_reverse else "incoming"
        side_groups.setdefault((source_id, source_side, "source"), []).append(flow_id)
        side_groups.setdefault((target_id, target_side, "target"), []).append(flow_id)

    slots: dict[str, dict[str, Any]] = {}
    for (node_id, side, role), flow_ids in sorted(side_groups.items()):
        total = len(flow_ids)
        for index, flow_id in enumerate(sorted(flow_ids)):
            entry = slots.setdefault(flow_id, {})
            entry[role] = {
                "node_id": node_id,
                "side": side,
                "slot_index": index,
                "slot_count": total,
                "is_reverse": side.endswith("-reverse"),
            }
    return slots


def _apply_port_slot_offset(
    anchor: tuple[float, float],
    rect: dict[str, float],
    slot: dict[str, Any] | None,
) -> tuple[float, float]:
    """Spread a port anchor along the node edge using its allocated slot."""
    if not isinstance(slot, dict):
        return anchor

    slot_count = max(1, int(slot.get("slot_count", 1)))
    if slot_count <= 1 and not slot.get("is_reverse"):
        return anchor

    slot_index = int(slot.get("slot_index", 0))
    center_x = rect["left"] + rect["width"] / 2.0
    center_y = rect["top"] + rect["height"] / 2.0
    horizontal_span = max(0.0, rect["width"] / 2.0 - 8.0)
    vertical_span = max(0.0, rect["height"] / 2.0 - 8.0)

    fraction = 0.0
    if slot_count > 1:
        fraction = (slot_index + 1) / (slot_count + 1) - 0.5

    reverse_bias = 0.18 if slot.get("is_reverse") else 0.0
    # Slot spreading slides the anchor along the node edge, so the result must
    # stay on that edge. Without clamping, an anchor that already sits toward a
    # corner is pushed off the shape and the connector renders detached from
    # the node it belongs to.
    edge_inset = min(8.0, rect["width"] / 2.0, rect["height"] / 2.0)
    if abs(anchor[0] - center_x) >= abs(anchor[1] - center_y):
        offset = (fraction + reverse_bias) * vertical_span * 2.0
        lower = rect["top"] + edge_inset
        upper = rect["top"] + rect["height"] - edge_inset
        return (anchor[0], min(max(anchor[1] + offset, lower), upper))
    offset = (fraction + reverse_bias) * horizontal_span * 2.0
    lower = rect["left"] + edge_inset
    upper = rect["left"] + rect["width"] - edge_inset
    return (min(max(anchor[0] + offset, lower), upper), anchor[1])


def _resolve_port_point(
    rect: dict[str, float],
    toward_point: tuple[float, float],
    port: str | None,
) -> tuple[float, float]:
    """Resolve a port anchor for a node rectangle."""
    if not isinstance(port, str) or not port:
        return _rect_anchor(rect, toward_point)
    normalized_port = port.strip().lower()
    center_x = rect["left"] + rect["width"] / 2.0
    center_y = rect["top"] + rect["height"] / 2.0
    if normalized_port == "top":
        return (center_x, rect["top"])
    if normalized_port == "bottom":
        return (center_x, rect["top"] + rect["height"])
    if normalized_port == "left":
        return (rect["left"], center_y)
    if normalized_port == "right":
        return (rect["left"] + rect["width"], center_y)
    if normalized_port == "top-left":
        return (rect["left"], rect["top"])
    if normalized_port == "top-right":
        return (rect["left"] + rect["width"], rect["top"])
    if normalized_port == "bottom-left":
        return (rect["left"], rect["top"] + rect["height"])
    if normalized_port == "bottom-right":
        return (rect["left"] + rect["width"], rect["top"] + rect["height"])
    return _rect_anchor(rect, toward_point)


def _resolve_zone_port_point(
    zone_rect: dict[str, float] | None,
    toward_point: tuple[float, float],
    *,
    offset: float = 12.0,
) -> tuple[float, float] | None:
    """Choose a point just outside a zone boundary toward a target point."""
    if not zone_rect:
        return None
    center_x = zone_rect["left"] + zone_rect["width"] / 2.0
    center_y = zone_rect["top"] + zone_rect["height"] / 2.0
    candidates = [
        (zone_rect["left"] - offset, center_y),
        (zone_rect["left"] + zone_rect["width"] + offset, center_y),
        (center_x, zone_rect["top"] - offset),
        (center_x, zone_rect["top"] + zone_rect["height"] + offset),
    ]
    return min(
        candidates,
        key=lambda point: math.hypot(
            point[0] - toward_point[0],
            point[1] - toward_point[1],
        ),
    )


def _route_connector_handle(
    source_rect: dict[str, float],
    target_rect: dict[str, float],
    other_rects: list[dict[str, float]],
    source_anchor: tuple[float, float],
    target_anchor: tuple[float, float],
    ordinal: int,
    *,
    source_node_id: str | None = None,
    target_node_id: str | None = None,
    overlay_rule: dict[str, Any] | None = None,
    preferred_handle: tuple[float, float] | None = None,
    existing_segments: list[tuple[tuple[float, float], tuple[float, float]]]
    | None = None,
    existing_handles: list[tuple[float, float]] | None = None,
    reverse_lane_sign: float = 0.0,
) -> tuple[float, float]:
    """Return a handle point that bypasses nearby nodes and boundary bands."""
    if isinstance(overlay_rule, dict):
        raw_handle = overlay_rule.get("handle_point")
        if isinstance(raw_handle, dict):
            return (
                float(raw_handle.get("x", 0.0)),
                float(raw_handle.get("y", 0.0)),
            )

    mid_x = (source_anchor[0] + target_anchor[0]) / 2.0
    mid_y = (source_anchor[1] + target_anchor[1]) / 2.0
    if preferred_handle is not None:
        mid_x, mid_y = preferred_handle
    dx = target_anchor[0] - source_anchor[0]
    dy = target_anchor[1] - source_anchor[1]

    offsets: list[tuple[float, float]] = [
        (0.0, 0.0),
        (-80.0, 0.0),
        (80.0, 0.0),
        (0.0, -80.0),
        (0.0, 80.0),
        (-120.0, 0.0),
        (120.0, 0.0),
        (0.0, -120.0),
        (0.0, 120.0),
    ]
    if abs(dx) >= abs(dy):
        offsets = [(0.0, 0.0), (0.0, -80.0), (0.0, 80.0), (0.0, -120.0), (0.0, 120.0)]
    else:
        offsets = [(0.0, 0.0), (-80.0, 0.0), (80.0, 0.0), (-120.0, 0.0), (120.0, 0.0)]

    candidates = [
        (mid_x + offset_x, mid_y + offset_y) for offset_x, offset_y in offsets
    ]
    if dx != 0.0 or dy != 0.0:
        magnitude = math.hypot(dx, dy)
        perp_x = -dy / magnitude if magnitude > 0.0 else 0.0
        perp_y = dx / magnitude if magnitude > 0.0 else 0.0
        for distance in (64.0, 128.0):
            candidates.extend(
                [
                    (mid_x + perp_x * distance, mid_y + perp_y * distance),
                    (mid_x - perp_x * distance, mid_y - perp_y * distance),
                ]
            )
    candidates.extend(
        [
            (source_anchor[0] + dx * 0.25, source_anchor[1] + dy * 0.25),
            (target_anchor[0] - dx * 0.25, target_anchor[1] - dy * 0.25),
        ]
    )
    clearance = 24.0
    for rect in other_rects:
        left = rect["left"] - clearance
        right = rect["left"] + rect["width"] + clearance
        top = rect["top"] - clearance
        bottom = rect["top"] + rect["height"] + clearance
        candidates.extend(
            [
                (left, top),
                (right, top),
                (left, bottom),
                (right, bottom),
                (left, mid_y),
                (right, mid_y),
                (mid_x, top),
                (mid_x, bottom),
            ]
        )
    lane_offset = float((ordinal - 1) % 8) * 48.0
    candidates.extend(
        [
            (24.0 + lane_offset, mid_y),
            (1896.0 - lane_offset, mid_y),
            (mid_x, 24.0 + lane_offset),
            (mid_x, 1056.0 - lane_offset),
        ]
    )

    clear_candidates: list[tuple[float, float]] = []
    for candidate in dict.fromkeys(candidates):
        if not _segment_intersects_any_rect(source_anchor, candidate, other_rects):
            if not _segment_intersects_any_rect(candidate, target_anchor, other_rects):
                clear_candidates.append(candidate)

    if clear_candidates:
        prior_segments = existing_segments or []
        prior_handles = existing_handles or []

        def _collides_with_prior(candidate: tuple[float, float]) -> bool:
            """Report whether a candidate lands on an already-placed handle.

            TMT draws each connector label at that connector's handle, so two
            connectors sharing a handle render their labels on top of each
            other. An occupied handle is disqualifying, not merely penalized.
            """
            return any(
                math.hypot(
                    candidate[0] - prior_handle[0],
                    candidate[1] - prior_handle[1],
                )
                < MIN_HANDLE_SEPARATION
                for prior_handle in prior_handles
            )

        unoccupied_candidates = [
            candidate
            for candidate in clear_candidates
            if not _collides_with_prior(candidate)
        ]
        if unoccupied_candidates:
            clear_candidates = unoccupied_candidates

        def candidate_score(
            candidate: tuple[float, float],
        ) -> tuple[int, int, float, float, float, float]:
            legs = [
                (source_anchor, candidate),
                (candidate, target_anchor),
            ]
            crossings = 0
            duplicate_legs = 0
            for leg_start, leg_end in legs:
                for prior_start, prior_end in prior_segments:
                    exact_duplicate = (
                        leg_start == prior_start and leg_end == prior_end
                    ) or (leg_start == prior_end and leg_end == prior_start)
                    if exact_duplicate:
                        duplicate_legs += 1
                        crossings += 1
                        continue
                    if tm7_visual_feedback._segment_intersects_segment(
                        leg_start,
                        leg_end,
                        prior_start,
                        prior_end,
                    ):
                        crossings += 1
            path_length = sum(
                math.hypot(end[0] - start[0], end[1] - start[1]) for start, end in legs
            )
            cluster_penalty = 0.0
            for prior_handle in prior_handles:
                separation = math.hypot(
                    candidate[0] - prior_handle[0],
                    candidate[1] - prior_handle[1],
                )
                if separation < MIN_LAYOUT_GUTTER:
                    cluster_penalty += MIN_LAYOUT_GUTTER - separation
            reverse_penalty = 0.0
            if reverse_lane_sign:
                if abs(dx) >= abs(dy):
                    lane_offset = candidate[1] - mid_y
                else:
                    lane_offset = candidate[0] - mid_x
                if lane_offset * reverse_lane_sign <= 0.0:
                    reverse_penalty = MIN_LAYOUT_GUTTER + abs(lane_offset)
            preferred_bias = 0.0
            if preferred_handle is not None:
                preferred_bias = abs(candidate[0] - preferred_handle[0]) + abs(
                    candidate[1] - preferred_handle[1]
                )
            return (
                duplicate_legs,
                crossings,
                reverse_penalty,
                cluster_penalty,
                path_length,
                preferred_bias,
            )

        return min(clear_candidates, key=candidate_score)

    # No routed candidate is clear. Offset the midpoint fallback so it does not
    # land on an already-placed handle and duplicate that connector's label.
    fallback = (mid_x, mid_y)
    prior_handles = existing_handles or []
    attempt = 0
    while attempt < 8 and any(
        math.hypot(fallback[0] - prior[0], fallback[1] - prior[1])
        < MIN_HANDLE_SEPARATION
        for prior in prior_handles
    ):
        attempt += 1
        shift = MIN_HANDLE_SEPARATION * attempt
        if abs(dx) >= abs(dy):
            fallback = (mid_x, mid_y + (shift if attempt % 2 else -shift))
        else:
            fallback = (mid_x + (shift if attempt % 2 else -shift), mid_y)
    return fallback


def _find_clear_connector_points(
    source_rect: dict[str, float],
    target_rect: dict[str, float],
    other_rects: list[dict[str, float]],
    source_anchor: tuple[float, float],
    target_anchor: tuple[float, float],
    ordinal: int,
    *,
    routing_hints: dict[str, float] | None = None,
    source_node_id: str | None = None,
    target_node_id: str | None = None,
    overlay_rule: dict[str, Any] | None = None,
) -> tuple[tuple[float, float], tuple[float, float]]:
    """Choose source/target points on the node edges that avoid nearby nodes."""
    dx = target_anchor[0] - source_anchor[0]
    dy = target_anchor[1] - source_anchor[1]

    def _clamped(
        point: tuple[float, float],
        rect: dict[str, float],
    ) -> tuple[float, float]:
        """Keep an endpoint on its own node so the connector stays attached.

        Obstacle-avoidance slides endpoints along an axis. Without a bound the
        slide can carry an endpoint off the shape, which renders as a line that
        merely points at the node instead of being joined to it.
        """
        return (
            min(max(point[0], rect["left"]), rect["left"] + rect["width"]),
            min(max(point[1], rect["top"]), rect["top"] + rect["height"]),
        )

    base_offsets = [0, -40, 40, -80, 80, -120, 120]
    routing_hints = routing_hints or {}
    hint_offset = int(
        round(
            (
                routing_hints.get(source_node_id or "", 0.0)
                + routing_hints.get(target_node_id or "", 0.0)
            )
            * 24.0
        )
    )
    for offset in base_offsets:
        if abs(dx) >= abs(dy):
            candidate_source = (source_anchor[0], source_anchor[1] + offset)
            candidate_target = (target_anchor[0], target_anchor[1] + offset)
        else:
            candidate_source = (source_anchor[0] + offset, source_anchor[1])
            candidate_target = (target_anchor[0] + offset, target_anchor[1])
        candidate_source = _clamped(candidate_source, source_rect)
        candidate_target = _clamped(candidate_target, target_rect)
        if not _segment_intersects_any_rect(
            candidate_source, candidate_target, other_rects
        ):
            return candidate_source, candidate_target

    adjusted_offsets = [offset + hint_offset for offset in base_offsets]
    for offset in adjusted_offsets:
        if abs(dx) >= abs(dy):
            candidate_source = (source_anchor[0], source_anchor[1] + offset)
            candidate_target = (target_anchor[0], target_anchor[1] + offset)
        else:
            candidate_source = (source_anchor[0] + offset, source_anchor[1])
            candidate_target = (target_anchor[0] + offset, target_anchor[1])
        candidate_source = _clamped(candidate_source, source_rect)
        candidate_target = _clamped(candidate_target, target_rect)
        if not _segment_intersects_any_rect(
            candidate_source, candidate_target, other_rects
        ):
            return candidate_source, candidate_target

    offset = ((ordinal % 5) - 2) * 24
    if abs(dx) >= abs(dy):
        candidate_source = (source_anchor[0], source_anchor[1] + offset)
        candidate_target = (target_anchor[0], target_anchor[1] + offset)
    else:
        candidate_source = (source_anchor[0] + offset, source_anchor[1])
        candidate_target = (target_anchor[0] + offset, target_anchor[1])
    return _clamped(candidate_source, source_rect), _clamped(
        candidate_target,
        target_rect,
    )


def _resolve_surface_layout_preferences(
    surface: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None,
    measured_viewport: dict[str, float] | None = None,
) -> dict[str, Any]:
    """Resolve deterministic layout preferences for a surface."""
    surface_id = str(surface.get("id", ""))
    # A measured native Diagram pane takes precedence over the synthetic
    # default so generation targets the canvas the reviewer actually sees.
    # Overlay rules still win, because they are explicit reviewer intent.
    # Both are converted from screen pixels into model units, because TMT
    # draws at TMT_RENDER_ZOOM rather than 1:1.
    viewport_target = {
        "left": 0.0,
        "top": 0.0,
        "width": DEFAULT_VIEWPORT_WIDTH,
        "height": DEFAULT_VIEWPORT_HEIGHT,
    }
    if isinstance(measured_viewport, dict):
        measured_width = float(measured_viewport.get("width", 0.0) or 0.0)
        measured_height = float(measured_viewport.get("height", 0.0) or 0.0)
        if measured_width > 0.0 and measured_height > 0.0:
            viewport_target = {
                "left": float(measured_viewport.get("left", 0.0) or 0.0),
                "top": float(measured_viewport.get("top", 0.0) or 0.0),
                "width": measured_width / TMT_RENDER_ZOOM,
                "height": measured_height / TMT_RENDER_ZOOM,
            }
    outer_margin = 24.0
    orientation = "horizontal"
    zone_order: list[str] | None = None

    if isinstance(layout_overlay, dict):
        for rule in layout_overlay.get("surface_rules", []) or []:
            if not isinstance(rule, dict):
                continue
            if str(rule.get("surface_id", "")) != surface_id:
                continue
            raw_orientation = str(rule.get("orientation", "") or "").strip().lower()
            if raw_orientation in {"horizontal", "vertical"}:
                orientation = raw_orientation
            raw_zone_order = rule.get("zone_order")
            if isinstance(raw_zone_order, list):
                zone_order = [
                    str(zone_id) for zone_id in raw_zone_order if str(zone_id)
                ]
            target = rule.get("viewport_target")
            if isinstance(target, dict):
                viewport_target = {
                    "left": float(target.get("left", 0.0)),
                    "top": float(target.get("top", 0.0)),
                    "width": float(target.get("width", viewport_target["width"])),
                    "height": float(target.get("height", viewport_target["height"])),
                }
            outer_margin_value = rule.get("outer_margin")
            if isinstance(outer_margin_value, (int, float)):
                outer_margin = float(outer_margin_value)
            break

    return {
        "orientation": orientation,
        "zone_order": zone_order,
        "viewport_target": viewport_target,
        "outer_margin": outer_margin,
    }


def _zone_flow_ranks(surface: dict[str, Any]) -> dict[str, float]:
    """Rank zones by the mean graph rank of the nodes they contain.

    Zone order follows the direction of data flow so a reader scans zones in the
    same order the system processes work. Zones without ranked members fall back
    to the caller's tie-breaking.
    """
    graph = _analyze_surface_layout_graph(surface)
    node_ranks = graph.get("node_ranks", {}) or {}
    zone_totals: dict[str, list[float]] = {}
    for element in surface.get("elements", []):
        if not isinstance(element, dict):
            continue
        node_id = str(element.get("id", ""))
        zone_id = str(element.get("trust_zone_id", "") or "")
        if not zone_id or node_id not in node_ranks:
            continue
        zone_totals.setdefault(zone_id, []).append(float(node_ranks[node_id]))
    return {
        zone_id: sum(ranks) / len(ranks)
        for zone_id, ranks in zone_totals.items()
        if ranks
    }


def _sorted_zone_ids(
    surface: dict[str, Any],
    *,
    zone_order: list[str] | None = None,
) -> list[str]:
    """Return a deterministic zone ordering for the surface."""
    zones = [
        str(zone.get("id", ""))
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict) and str(zone.get("id", ""))
    ]
    explicit_order = {zone_id: index for index, zone_id in enumerate(zone_order or [])}
    zone_defs = {
        str(zone.get("id", "")): zone
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict)
    }
    flow_ranks = _zone_flow_ranks(surface)
    unranked_rank = max(flow_ranks.values(), default=0.0) + 1.0
    return sorted(
        zones,
        key=lambda zone_id: (
            explicit_order.get(zone_id, len(zones)),
            flow_ranks.get(zone_id, unranked_rank),
            str(zone_defs.get(zone_id, {}).get("name", zone_id)).lower(),
            zone_id,
        ),
    )


def _zone_children(surface: dict[str, Any], zone_id: str) -> list[str]:
    """Return declared children for a zone."""
    zone_defs = {
        str(zone.get("id", "")): zone
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict)
    }
    children = [
        str(zone.get("id", ""))
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict)
        and str(zone.get("id", ""))
        and str(zone.get("parent_trust_zone_id", "")) == zone_id
    ]
    zone_order = [
        str(zone.get("id", ""))
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict) and str(zone.get("id", ""))
    ]
    explicit_order = {zone_id: index for index, zone_id in enumerate(zone_order)}
    return sorted(
        children,
        key=lambda child_id: (
            explicit_order.get(child_id, len(zone_defs)),
            str(zone_defs.get(child_id, {}).get("name", child_id)).lower(),
            child_id,
        ),
    )


def _pack_zone_rects(
    parent_rect: dict[str, float],
    child_ids: list[str],
    *,
    orientation: str,
    inner_padding: float,
    gutter: float,
    child_requirements: list[tuple[float, float]] | None = None,
) -> list[dict[str, float]]:
    """Pack sibling zone rectangles inside a parent content rectangle.

    When per-child requirements are supplied each sibling first receives what
    it needs and any surplus is shared evenly. An even split alone starves a
    demanding sibling while over-serving a sparse one, which pushes nodes out
    of the starved zone. Requirements that cannot all be met fall back to an
    even split so the allocation and containment checks report the shortfall.
    """
    if not child_ids:
        return []
    parent_left = parent_rect["left"]
    parent_top = parent_rect["top"]
    parent_width = parent_rect["width"]
    parent_height = parent_rect["height"]

    def _distribute(total: float, index: int) -> list[float]:
        """Return per-child extents along the packing axis."""
        even = [total / len(child_ids)] * len(child_ids)
        if child_requirements is None or len(child_requirements) != len(child_ids):
            return even
        needed = [
            requirement[index] + inner_padding * 2 for requirement in child_requirements
        ]
        surplus = total - sum(needed)
        if surplus < 0:
            return even
        share = surplus / len(child_ids)
        return [value + share for value in needed]

    if orientation == "vertical":
        usable_height = max(
            60.0,
            parent_height - gutter * (len(child_ids) - 1),
        )
        child_heights = _distribute(usable_height, 1)
        child_width = max(80.0, parent_width)
        rects: list[dict[str, float]] = []
        top = parent_top
        for child_height in child_heights:
            rects.append(
                {
                    "left": parent_left,
                    "top": top,
                    "width": child_width,
                    "height": child_height,
                }
            )
            top += child_height + gutter
        return rects

    usable_width = max(
        60.0,
        parent_width - gutter * (len(child_ids) - 1),
    )
    child_widths = _distribute(usable_width, 0)
    child_height = max(60.0, parent_height)
    rects = []
    left = parent_left
    for child_width in child_widths:
        rects.append(
            {
                "left": left,
                "top": parent_top,
                "width": child_width,
                "height": child_height,
            }
        )
        left += child_width + gutter
    return rects


def _zone_node_lane_entries(
    zone_elements: list[dict[str, Any]],
    graph: dict[str, Any],
) -> dict[str, list[tuple[str, float, float, int]]]:
    """Return a zone's ordered main, return, and contextual node entries.

    Zone sizing and node placement both depend on how a zone's nodes are split
    into lanes and ordered within them, so both read that decision from here.
    Element selection stays with each caller: this partitions and orders only
    the list it is given.

    Each entry is ``(node_id, width, height, rank)`` with dimensions clamped
    the way node placement clamps them. The ordering key ends in the unique
    node id, so it is a total order and the sequence does not depend on whether
    a lane is filtered before or after sorting.
    """
    node_ranks = graph.get("node_ranks", {})
    fan_out = graph.get("fan_out", {})
    branch_groups = graph.get("branch_groups", {})
    member_ids = {str(element.get("id", "")) for element in zone_elements}
    same_zone_return_nodes = {
        node_id
        for node_id in graph.get("return_lane_nodes", set())
        if any(
            node_id in pair and partner in member_ids
            for pair in graph.get("reverse_edge_pairs", [])
            for partner in pair
            if partner != node_id
        )
    }

    def _order_key(element: dict[str, Any]) -> tuple[Any, ...]:
        node_id = str(element.get("id", ""))
        name = str(element.get("name", node_id))
        return (
            node_ranks.get(node_id, 0),
            -fan_out.get(node_id, 0),
            branch_groups.get(node_id, 0),
            len(name),
            name.lower(),
            node_id,
        )

    lanes: dict[str, list[tuple[str, float, float, int]]] = {
        "main": [],
        "return": [],
        "contextual": [],
    }
    for element in sorted(zone_elements, key=_order_key):
        node_id = str(element.get("id", ""))
        measured_width, measured_height = _measure_node_dimensions(element)
        entry = (
            node_id,
            min(MAX_NODE_WIDTH, max(MIN_NODE_SIZE, measured_width)),
            min(MAX_NODE_HEIGHT, max(MIN_NODE_SIZE, measured_height)),
            int(node_ranks.get(node_id, 0)),
        )
        layout_role = str(element.get("layout_role") or "").lower()
        if layout_role == "contextual":
            lanes["contextual"].append(entry)
        elif node_id in same_zone_return_nodes:
            lanes["return"].append(entry)
        else:
            lanes["main"].append(entry)
    return lanes


def _rank_band_indices(ranks: Any, band_size: int) -> dict[int, int]:
    """Map each distinct graph rank to the band that shares one row.

    Ranks are sparse and unevenly spaced, so banding is applied to their sorted
    positions rather than to their values. Band one preserves the default
    reading order of one rank per row.
    """
    distinct = sorted({int(rank) for rank in ranks})
    size = max(1, int(band_size))
    return {rank: index // size for index, rank in enumerate(distinct)}


def _simulate_packed_rows(
    entries: list[tuple[str, float, float, int]],
    available_width: float,
    gutter: float,
    *,
    band_size: int = 1,
) -> list[float]:
    """Return per-row heights for the packing node placement performs.

    Placement starts a new row when the next node leaves the current rank band
    or when it no longer fits the available width, so a column split alone
    cannot predict the row count. Rows have unequal heights once nodes grow
    with their label text, so heights are returned rather than a count.
    """
    bands = _rank_band_indices((entry[3] for entry in entries), band_size)
    rows: list[float] = []
    current_height = 0.0
    current_width = 0.0
    current_band: int | None = None
    started = False
    for _, width, height, rank in entries:
        band = bands.get(int(rank), 0)
        if not started:
            started = True
            current_height = height
            current_width = width
            current_band = band
            continue
        projected_width = current_width + gutter + width
        if band != current_band or projected_width > available_width:
            rows.append(current_height)
            current_height = height
            current_width = width
            current_band = band
            continue
        current_height = max(current_height, height)
        current_width = projected_width
        current_band = band
    if started:
        rows.append(current_height)
    return rows


def _fitting_rank_band_size(
    entries: list[tuple[str, float, float, int]],
    available_width: float,
    gutter: float,
    height_budget: float,
) -> int:
    """Return the smallest rank banding that keeps a lane inside its budget.

    One rank per row makes a long flow chain grow into a column taller than the
    canvas, and no column split can shorten it because the rank break fires
    before the width break. Merging the fewest adjacent ranks needed to fit
    keeps flow order readable while letting the lane use its full width.
    """
    distinct_ranks = len({int(entry[3]) for entry in entries})
    if distinct_ranks <= 1 or height_budget <= 0:
        return 1
    for band_size in range(1, distinct_ranks + 1):
        rows = _simulate_packed_rows(
            entries,
            available_width,
            gutter,
            band_size=band_size,
        )
        if not rows:
            return band_size
        height = sum(rows) + gutter * max(0, len(rows) - 1)
        if height <= height_budget:
            return band_size
    return distinct_ranks


def _preferred_zone_grid(
    node_count: int,
    node_width: float,
    node_height: float,
    gutter: float,
    inner_padding: float,
    target_aspect: float,
) -> tuple[int, int]:
    """Return the column and row split whose zone shape best fits the target.

    Node placement packs nodes into rows, so the column count determines the
    width a zone needs, and the row count gives a lower bound on its height.
    Choosing the split against a target aspect keeps a many-node zone from
    growing into either a narrow strip or a tall column.

    Distance is measured on the log of the aspect ratio so that a zone twice
    as wide as the target scores the same as one half as wide; a linear
    difference would bias every surface toward wide layouts.
    """
    if node_count <= 1:
        return (1, 1)
    safe_target = target_aspect if target_aspect > 0 else 1.0
    safe_height = node_height if node_height > 0 else 1.0
    best: tuple[tuple[float, int], int, int] | None = None
    for columns in range(1, node_count + 1):
        rows = math.ceil(node_count / columns)
        width = columns * node_width + (columns - 1) * gutter + inner_padding * 2
        height = rows * safe_height + (rows - 1) * gutter + inner_padding * 2
        aspect = width / height if height > 0 else safe_target
        score = (
            abs(math.log(aspect / safe_target)) if aspect > 0 else float("inf"),
            columns * rows - node_count,
        )
        if best is None or score < best[0]:
            best = (score, columns, rows)
    if best is None:
        return (1, node_count)
    return (best[1], best[2])


def _zone_target_aspect(
    viewport_rect: dict[str, float],
    orientation: str,
    zone_span: int,
) -> float:
    """Return the aspect an individual zone should target.

    Sibling zones are packed into a single strip, so each zone occupies a
    fraction of the surface along the packing axis. The zone target is the
    surface target divided across that strip, which keeps the assembled
    surface near the viewport shape instead of letting it stretch with the
    zone count.
    """
    height = viewport_rect.get("height", 0.0) or 1.0
    surface_aspect = float(viewport_rect.get("width", 0.0)) / float(height)
    if surface_aspect <= 0:
        surface_aspect = 1.0
    span = max(1, zone_span)
    if orientation == "vertical":
        return surface_aspect * span
    return surface_aspect / span


def _resolve_surface_orientation_and_zone_order(
    surface: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None,
) -> tuple[str, list[str]]:
    """Resolve the orientation and zone order that layout commits to.

    Zone placement and the layout metadata published for downstream refinement
    must agree on these two facts. Resolving them in one place keeps the
    published record a report of what layout actually did rather than a second,
    independently derived opinion that could drift from it.
    """
    preferences = _resolve_surface_layout_preferences(
        surface,
        layout_overlay=layout_overlay,
    )
    orientation = str(preferences.get("orientation", "horizontal") or "horizontal")
    zone_order = preferences.get("zone_order")
    if zone_order:
        return orientation, list(zone_order)
    graph = _analyze_surface_layout_graph(surface)
    candidate = _select_surface_layout_candidate(
        surface,
        graph,
        layout_overlay=layout_overlay,
    )
    orientation = str(candidate.get("orientation", orientation) or orientation)
    return orientation, list(candidate.get("zone_order", []) or [])


def _assign_zone_regions(
    surface: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None,
) -> tuple[dict[str, dict[str, float]], dict[str, dict[str, float]]]:
    """Allocate trust-zone rectangles before any nodes are placed."""
    preferences = _resolve_surface_layout_preferences(
        surface,
        layout_overlay=layout_overlay,
    )
    viewport_target = preferences["viewport_target"]
    outer_margin = float(preferences["outer_margin"])
    label_band = 24.0
    inner_padding = ZONE_INNER_PADDING
    gutter = 16.0
    orientation, zone_order = _resolve_surface_orientation_and_zone_order(
        surface,
        layout_overlay=layout_overlay,
    )

    surface_zones = [
        zone
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict) and str(zone.get("id", ""))
    ]
    zone_ids = [str(zone.get("id", "")) for zone in surface_zones]
    if not zone_ids:
        return {}, {}

    viewport_rect = {
        "left": float(viewport_target.get("left", 0.0)),
        "top": float(viewport_target.get("top", 0.0)),
        "width": float(viewport_target.get("width", DEFAULT_VIEWPORT_WIDTH)),
        "height": float(viewport_target.get("height", DEFAULT_VIEWPORT_HEIGHT)),
    }
    if viewport_rect["width"] < 240 or viewport_rect["height"] < 240:
        raise GenerationError(
            "layout could not allocate zone rectangles within the requested canvas",
            exit_code=EXIT_ERROR,
        )

    zone_rects: dict[str, dict[str, float]] = {}
    zone_content_rects: dict[str, dict[str, float]] = {}

    root_zone_ids = [
        zone_id
        for zone_id in _sorted_zone_ids(surface, zone_order=zone_order)
        if not str(
            next(
                (
                    zone.get("parent_trust_zone_id", "")
                    for zone in surface_zones
                    if str(zone.get("id", "")) == zone_id
                ),
                "",
            )
        )
    ]
    if not root_zone_ids:
        root_zone_ids = zone_ids

    visited_zone_ids: set[str] = set()
    zone_requirement_cache: dict[str, tuple[float, float]] = {}
    layout_graph = _analyze_surface_layout_graph(surface)
    layout_gutter = _surface_layout_gutter(surface.get("elements", []))
    zone_target_aspect = _zone_target_aspect(
        viewport_rect,
        orientation,
        len(root_zone_ids),
    )

    def _zone_has_return_lane(zone_id: str) -> bool:
        """Report whether a zone hosts a same-zone reverse pair."""
        member_ids = {
            str(element.get("id", ""))
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("trust_zone_id", "")) == zone_id
        }
        return any(
            node_id in member_ids and partner in member_ids
            for pair in layout_graph.get("reverse_edge_pairs", [])
            for node_id in pair
            for partner in pair
            if partner != node_id
        )

    def _measured_zone_node_extent(zone_id: str) -> tuple[float, float, float]:
        """Return the widest, tallest, and stacked node extents for a zone."""
        widths = [0.0]
        heights = [0.0]
        stacked = 0.0
        measured_count = 0
        for element in surface.get("elements", []):
            if not isinstance(element, dict):
                continue
            if str(element.get("trust_zone_id", "")) != zone_id:
                continue
            if str(element.get("layout_role") or "").lower() == "suppressed":
                continue
            measured_width, measured_height = _measure_node_dimensions(element)
            widths.append(measured_width)
            heights.append(measured_height)
            stacked += measured_height
            measured_count += 1
        stacked += layout_gutter * max(0, measured_count - 1)
        return (max(widths), max(heights), stacked)

    def _estimate_zone_content_requirements(zone_id: str) -> tuple[float, float]:
        if zone_id in zone_requirement_cache:
            return zone_requirement_cache[zone_id]
        child_ids = _zone_children(surface, zone_id)
        zone_elements = [
            element
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("trust_zone_id", "")) == zone_id
            and str(element.get("layout_role") or "").lower() != "suppressed"
        ]
        direct_node_count = len(
            [
                element
                for element in zone_elements
                if str(element.get("layout_role") or "").lower()
                not in {"contextual", "suppressed"}
            ]
        )
        measured_width, measured_height, _ = _measured_zone_node_extent(zone_id)
        cell_width = max(measured_width, MIN_NODE_SIZE)
        cell_height = max(measured_height, MIN_NODE_SIZE)
        # Width is derived from the grid's column split. Height is derived from
        # a simulation of the row packing node placement actually performs,
        # because placement breaks rows on graph rank as well as on width and
        # so can produce more rows than any column split predicts. The grid
        # height is kept as a lower bound.
        grid_columns, grid_rows = _preferred_zone_grid(
            direct_node_count,
            cell_width,
            cell_height,
            layout_gutter,
            inner_padding,
            zone_target_aspect,
        )
        grid_width = (
            grid_columns * cell_width
            + (grid_columns - 1) * layout_gutter
            + inner_padding * 2
        )
        # Sizing runs before final widths exist, so the grid's own content
        # width stands in. It is narrower than the width a zone finally
        # receives, which can only make the width-overflow break fire more
        # often, so the simulation never under-predicts rows.
        grid_content_width = max(cell_width, grid_width - inner_padding * 2)
        lane_entries = _zone_node_lane_entries(zone_elements, layout_graph)

        def _stack_height(rows: list[float]) -> float:
            if not rows:
                return 0.0
            return sum(rows) + layout_gutter * (len(rows) - 1)

        # The three lanes stack downward from the same top in their own
        # rectangles, so the zone must hold the tallest lane rather than their
        # sum. Lane widths mirror the ones node placement derives.
        # The contextual lane is offset from the main lane and is clamped to
        # keep room for one node, so its reserved width mirrors what placement
        # uses. `own_min_width` guarantees the zone can hold that offset.
        contextual_content_width = max(grid_content_width, 120.0 + MIN_NODE_SIZE)
        contextual_lane_width = contextual_content_width - min(
            max(120.0, contextual_content_width * 0.55) + layout_gutter,
            contextual_content_width - MIN_NODE_SIZE,
        )

        # A lane taller than the canvas is unreadable no matter how the zone is
        # otherwise shaped, so ranks are banded only as far as fitting requires.
        lane_height_budget = max(
            0.0,
            float(viewport_rect.get("height", 0.0))
            - outer_margin * 2
            - label_band
            - inner_padding * 2,
        )
        main_band = _fitting_rank_band_size(
            lane_entries["main"],
            grid_content_width,
            layout_gutter,
            lane_height_budget,
        )
        return_band = _fitting_rank_band_size(
            lane_entries["return"],
            max(140.0, grid_content_width * 0.4),
            layout_gutter,
            lane_height_budget,
        )
        contextual_band = _fitting_rank_band_size(
            lane_entries["contextual"],
            max(MIN_NODE_SIZE, contextual_lane_width),
            layout_gutter,
            lane_height_budget,
        )

        packed_height = max(
            _stack_height(
                _simulate_packed_rows(
                    lane_entries["main"],
                    grid_content_width,
                    layout_gutter,
                    band_size=main_band,
                )
            ),
            _stack_height(
                _simulate_packed_rows(
                    lane_entries["return"],
                    max(140.0, grid_content_width * 0.4),
                    layout_gutter,
                    band_size=return_band,
                )
            ),
            _stack_height(
                _simulate_packed_rows(
                    lane_entries["contextual"],
                    max(MIN_NODE_SIZE, contextual_lane_width),
                    layout_gutter,
                    band_size=contextual_band,
                )
            ),
        )
        # The grid row count is a shape heuristic that assumes one rank per
        # row, so it is only a safe height floor while that holds. Once ranks
        # are banded the simulation runs the same packing placement performs
        # and is authoritative; keeping the grid floor would reserve rows the
        # layout no longer creates and undo the banding.
        ranks_are_banded = max(main_band, return_band, contextual_band) > 1
        grid_row_floor = (
            0.0
            if ranks_are_banded
            else grid_rows * cell_height + (grid_rows - 1) * layout_gutter
        )
        grid_height = (
            max(packed_height, grid_row_floor) + label_band + inner_padding * 2
        )
        own_min_width = max(
            220.0 if child_ids else 180.0,
            # Count-based floor on zone width. It dominates `grid_width` for
            # most zones and controls how wide a zone spreads; containment is
            # held by the packed-row height reserved above.
            180.0 + max(0, direct_node_count - 1) * 36.0,
            200.0 + max(0, len(child_ids) - 1) * 16.0,
            measured_width + inner_padding * 2,
            grid_width,
        )
        if _zone_has_return_lane(zone_id):
            # A same-zone reverse pair renders as two side-by-side lanes, so the
            # zone must be wide enough to hold both plus the separating gutter.
            own_min_width = max(
                own_min_width,
                measured_width * 2.0 + layout_gutter + inner_padding * 2,
            )
        if lane_entries["contextual"]:
            # The contextual lane is offset from the main lane, so the zone
            # needs that offset plus room for one node. Reserving exactly this
            # keeps the lane separate without inflating the zone.
            own_min_width = max(
                own_min_width,
                120.0 + MIN_NODE_SIZE + inner_padding * 2,
            )
        own_min_height = max(
            220.0 if child_ids else 180.0,
            160.0 + max(0, len(child_ids) - 1) * 16.0,
            grid_height,
        )
        if child_ids:
            child_requirements = [
                _estimate_zone_content_requirements(child_id) for child_id in child_ids
            ]
            # `_allocate` reserves the label band and inner padding, and, when
            # the zone also holds direct nodes, a node band plus a separating
            # gutter, before any child rectangle starts. It then caps each
            # child at its received rectangle less another padding pair.
            # Reserving all of it here stops a parent from being sized smaller
            # than the children it must contain. The node band is taken
            # uncapped because `_allocate` only ever caps it downward.
            child_area_reservation = label_band + inner_padding * 4
            if direct_node_count > 0:
                child_area_reservation += (
                    min(
                        MAX_NODE_HEIGHT + inner_padding,
                        max(
                            140.0,
                            100.0 + 24.0 * max(1, math.ceil(direct_node_count / 2)),
                        ),
                    )
                    + inner_padding
                )
            if orientation == "vertical":
                required_width = max(
                    own_min_width,
                    max(width for width, _ in child_requirements) + inner_padding * 2,
                )
                required_height = max(
                    own_min_height,
                    sum(height for _, height in child_requirements)
                    + gutter * max(0, len(child_ids) - 1)
                    + child_area_reservation,
                )
            else:
                # `_pack_zone_rects` gives each sibling its own requirement and
                # shares any surplus, so the parent must hold the sum of the
                # sibling requirements plus the separating gutters. The result
                # is an outer width, so the parent's own padding is added on
                # top of the content width the siblings occupy.
                required_width = max(
                    own_min_width,
                    sum(width + inner_padding * 2 for width, _ in child_requirements)
                    + gutter * max(0, len(child_ids) - 1)
                    + inner_padding * 2,
                )
                required_height = max(
                    own_min_height,
                    max(height for _, height in child_requirements)
                    + child_area_reservation,
                )
        else:
            required_width = own_min_width
            required_height = own_min_height
        zone_requirement_cache[zone_id] = (required_width, required_height)
        return zone_requirement_cache[zone_id]

    def _subtree_zone_ids(zone_id: str) -> set[str]:
        descendants = {zone_id}
        pending = [zone_id]
        while pending:
            parent_id = pending.pop()
            for child_id in _zone_children(surface, parent_id):
                if child_id in descendants:
                    continue
                descendants.add(child_id)
                pending.append(child_id)
        return descendants

    def _allocate(zone_id: str, parent_rect: dict[str, float] | None = None) -> None:
        if zone_id in visited_zone_ids:
            return
        visited_zone_ids.add(zone_id)

        child_ids = _zone_children(surface, zone_id)
        subtree_nodes = sum(
            1
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("layout_role") or "").lower() != "suppressed"
            and str(element.get("trust_zone_id", "")) in _subtree_zone_ids(zone_id)
        )
        if parent_rect is None:
            outer_rect = {
                "left": viewport_rect["left"] + outer_margin,
                "top": viewport_rect["top"] + outer_margin,
                "width": max(240.0, viewport_rect["width"] - (outer_margin * 2)),
                "height": max(240.0, viewport_rect["height"] - (outer_margin * 2)),
            }
        else:
            available_width = max(120.0, parent_rect["width"] - (inner_padding * 2))
            available_height = max(120.0, parent_rect["height"] - (inner_padding * 2))
            required_width, required_height = _estimate_zone_content_requirements(
                zone_id
            )
            compact_width = min(
                available_width,
                max(required_width, 240.0 + max(0, subtree_nodes - 1) * 48.0),
            )
            compact_height = min(
                available_height,
                max(required_height, 220.0 + max(0, subtree_nodes - 1) * 36.0),
            )
            # This branch is already the "parent_rect is not None" case, so the
            # rectangle is derived from the parent directly. An earlier revision
            # nested a second parent_rect check here with a viewport-inset
            # fallback; that fallback could never run, and the inset bounds it
            # computed were dead with it.
            outer_rect = {
                "left": parent_rect["left"],
                "top": parent_rect["top"],
                "width": max(
                    120.0,
                    min(
                        parent_rect["width"],
                        compact_width,
                    ),
                ),
                "height": max(
                    120.0,
                    min(
                        parent_rect["height"],
                        compact_height,
                    ),
                ),
            }
            outer_rect["width"] = min(
                outer_rect["width"],
                max(120.0, parent_rect["width"]),
            )
            outer_rect["height"] = min(
                outer_rect["height"],
                max(120.0, parent_rect["height"]),
            )

        zone_rects[zone_id] = outer_rect
        # The content box is what the zone actually has left after its label
        # band and padding. Flooring it would let content extend past the zone
        # that owns it, which is the silent escape finding 25 describes. An
        # insufficient box is reported by the allocation check below instead.
        content_rect = {
            "left": outer_rect["left"] + inner_padding,
            "top": outer_rect["top"] + label_band + inner_padding,
            "width": outer_rect["width"] - (inner_padding * 2),
            "height": outer_rect["height"] - label_band - (inner_padding * 2),
        }
        zone_content_rects[zone_id] = content_rect

        if child_ids:
            zone_elements = [
                element
                for element in surface.get("elements", [])
                if isinstance(element, dict)
                and str(element.get("trust_zone_id", "")) == zone_id
                and str(element.get("layout_role") or "").lower() != "suppressed"
            ]
            direct_node_count = len(
                [
                    element
                    for element in zone_elements
                    if str(element.get("layout_role") or "").lower()
                    not in {"contextual", "suppressed"}
                ]
            )
            child_top = content_rect["top"]
            child_height = content_rect["height"]
            if direct_node_count > 0:
                node_band_height = min(
                    max(140.0, 100.0 + 24.0 * max(1, math.ceil(direct_node_count / 2))),
                    content_rect["height"] * 0.5,
                )
                child_top = content_rect["top"] + node_band_height + inner_padding
                child_height = content_rect["height"] - node_band_height - inner_padding
            child_available = {
                "left": content_rect["left"],
                "top": child_top,
                "width": content_rect["width"],
                "height": child_height,
            }
            if child_available["width"] < 120.0 or child_available["height"] < 120.0:
                raise GenerationError(
                    (
                        "layout could not allocate zone rectangles within the "
                        "requested canvas"
                    ),
                    exit_code=EXIT_ERROR,
                )
            packed_rects = _pack_zone_rects(
                child_available,
                child_ids,
                orientation=orientation,
                inner_padding=inner_padding,
                gutter=gutter,
                child_requirements=[
                    _estimate_zone_content_requirements(child_id)
                    for child_id in child_ids
                ],
            )
            for child_id, child_rect in zip(child_ids, packed_rects, strict=False):
                _allocate(child_id, child_rect)

    maximum_root_node_count = max(
        (
            sum(
                1
                for element in surface.get("elements", [])
                if isinstance(element, dict)
                and str(element.get("layout_role") or "").lower() != "suppressed"
                and str(element.get("trust_zone_id", ""))
                in _subtree_zone_ids(root_zone_id)
            )
            for root_zone_id in root_zone_ids
        ),
        default=1,
    )

    def _subtree_depth(zone_id: str) -> int:
        children = _zone_children(surface, zone_id)
        if not children:
            return 0
        return 1 + max(_subtree_depth(child_id) for child_id in children)

    maximum_root_depth = max(
        (_subtree_depth(root_zone_id) for root_zone_id in root_zone_ids),
        default=0,
    )
    measured_outer_height_demand = (
        max(
            (
                _estimate_zone_content_requirements(root_zone_id)[1]
                for root_zone_id in root_zone_ids
            ),
            default=0.0,
        )
        + outer_margin * 2
    )
    # The viewport bounds how far a sparse surface is allowed to spread, but it
    # must not compress content below what it measurably needs: doing so pushes
    # nodes outside the zone that owns them and fails generation. A surface
    # larger than the viewport stays readable because TMT scrolls, and the
    # overflow is reported by the fill and clipping metrics.
    maximum_outer_height = max(
        240.0,
        viewport_rect["height"] - (outer_margin * 2),
        measured_outer_height_demand,
    )
    compact_outer_height = min(
        maximum_outer_height,
        max(
            240.0,
            (180.0 + maximum_root_node_count * 100.0) * LAYOUT_EXPANSION_LIMIT,
            (220.0 + maximum_root_depth * 72.0) * LAYOUT_EXPANSION_LIMIT,
            # The count and depth heuristics above describe how far a surface
            # spreads, not how much room its content needs. Without the
            # measured requirement a root zone can be allocated less height
            # than its own subtree demands, which pushes nodes past the zone
            # that owns them.
            measured_outer_height_demand,
        ),
    )
    root_node_counts = {
        root_zone_id: sum(
            1
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("layout_role") or "").lower() != "suppressed"
            and str(element.get("trust_zone_id", "")) in _subtree_zone_ids(root_zone_id)
        )
        for root_zone_id in root_zone_ids
    }

    def _root_cell_size(root_zone_id: str) -> tuple[float, float]:
        """Return the widest and tallest node cell across a root zone subtree."""
        subtree = _subtree_zone_ids(root_zone_id)
        width = max(
            (_measured_zone_node_extent(zone_id)[0] for zone_id in subtree),
            default=MIN_NODE_SIZE,
        )
        height = max(
            (_measured_zone_node_extent(zone_id)[1] for zone_id in subtree),
            default=MIN_NODE_SIZE,
        )
        return (max(width, MIN_NODE_SIZE), max(height, MIN_NODE_SIZE))

    def _root_grid_width(root_zone_id: str) -> float:
        """Return the width a root zone needs for its aspect-targeted grid."""
        cell_width, cell_height = _root_cell_size(root_zone_id)
        columns, _ = _preferred_zone_grid(
            root_node_counts[root_zone_id],
            cell_width,
            cell_height,
            layout_gutter,
            inner_padding,
            zone_target_aspect,
        )
        return columns * cell_width + (columns - 1) * layout_gutter + inner_padding * 2

    def _root_containment_width(root_zone_id: str) -> float:
        """Return the width a root subtree needs to hold its own content.

        Every term is a containment floor: allocating less than this pushes
        nodes past the zone that owns them and fails generation.
        """
        return max(
            _root_cell_size(root_zone_id)[0] + inner_padding * 4,
            _root_grid_width(root_zone_id),
            # The floors above describe how far a subtree spreads, not how much
            # room its content needs. Without the measured requirement a root
            # zone can be allocated less width than its own subtree demands.
            _estimate_zone_content_requirements(root_zone_id)[0],
        )

    def _root_spread_width(root_zone_id: str) -> float:
        """Return the width a root subtree is allowed to fan out into."""
        return max(
            # Count-based floor on root width, mirroring the per-zone floor.
            # It controls how wide a root subtree spreads and is a composition
            # control rather than a containment control.
            220.0 + max(0, root_node_counts[root_zone_id] - 1) * 88.0,
            260.0 if _subtree_depth(root_zone_id) > 0 else 0.0,
            _root_containment_width(root_zone_id),
        )

    def _total_root_width(widths: dict[str, float]) -> float:
        return sum(widths.values()) + gutter * max(0, len(root_zone_ids) - 1)

    desired_root_widths = {
        root_zone_id: _root_spread_width(root_zone_id) for root_zone_id in root_zone_ids
    }
    desired_total_width = _total_root_width(desired_root_widths)
    # The spread floors decide how far a subtree fans out, not how much room its
    # nodes need, so they are the first thing to give up when a surface would
    # otherwise be laid out past the visible canvas and silently clipped.
    # Containment floors are kept either way. The exchange is only taken when it
    # actually buys a fitting surface, so a surface that overflows on content
    # alone keeps its spread and still reports the overflow through the fill and
    # clipping metrics, and a surface that already fits is laid out unchanged.
    width_budget = viewport_rect["width"] - (outer_margin * 2)
    if desired_total_width > width_budget:
        containment_root_widths = {
            root_zone_id: _root_containment_width(root_zone_id)
            for root_zone_id in root_zone_ids
        }
        if _total_root_width(containment_root_widths) <= width_budget:
            desired_root_widths = containment_root_widths
            desired_total_width = _total_root_width(containment_root_widths)
    # The viewport bounds how far a sparse surface is allowed to spread, but it
    # must not compress content below what it measurably needs: doing so pushes
    # nodes outside the zone that owns them and fails generation. A surface
    # wider than the viewport stays readable because TMT scrolls, and the
    # overflow is reported by the fill and clipping metrics.
    maximum_root_width = max(
        240.0,
        viewport_rect["width"] - (outer_margin * 2),
        desired_total_width,
    )
    # Expand toward the calibrated canvas so content is not compressed into a
    # narrow column, but bound the expansion by content demand so a sparse
    # surface is not stretched into a thin band of widely separated nodes.
    compact_outer_width = min(
        maximum_root_width,
        max(280.0, desired_total_width * LAYOUT_EXPANSION_LIMIT),
    )
    root_available = {
        "left": viewport_rect["left"] + outer_margin - inner_padding,
        "top": viewport_rect["top"] + outer_margin - inner_padding,
        "width": compact_outer_width + (inner_padding * 2),
        "height": compact_outer_height + (inner_padding * 2),
    }
    minimum_root_widths = {
        root_zone_id: max(
            (
                _measured_zone_node_extent(zone_id)[0]
                for zone_id in _subtree_zone_ids(root_zone_id)
            ),
            default=0.0,
        )
        + inner_padding * 4
        for root_zone_id in root_zone_ids
    }
    if orientation == "horizontal":
        available_content_width = root_available["width"] - gutter * max(
            0,
            len(root_zone_ids) - 1,
        )
        desired_content_width = sum(desired_root_widths.values())
        # Zones shrink to fit a narrow canvas and expand into a wide one, so a
        # sparse surface uses its share of the pane instead of clustering in a
        # column. Expansion is bounded so nodes are not scattered.
        # Expansion also stops at the visible canvas. Beyond that edge content
        # is clipped rather than merely scrolled, and expansion is discretionary
        # width by definition, so spending it on clipped space buys nothing. The
        # ratio floors at 1.0 so a surface whose content already exceeds the
        # canvas keeps its measured width instead of being compressed into its
        # own zones, which would push nodes out and fail generation.
        budget_content_width = width_budget - gutter * max(
            0,
            len(root_zone_ids) - 1,
        )
        budget_scale = (
            max(1.0, budget_content_width / desired_content_width)
            if desired_content_width > 0
            else LAYOUT_EXPANSION_LIMIT
        )
        scale = min(
            LAYOUT_EXPANSION_LIMIT,
            available_content_width / desired_content_width,
            budget_scale,
        )
        root_rects = []
        next_left = root_available["left"]
        for root_zone_id in root_zone_ids:
            root_width = max(
                minimum_root_widths.get(root_zone_id, 0.0),
                desired_root_widths[root_zone_id] * scale,
            )
            root_rects.append(
                {
                    "left": next_left,
                    "top": root_available["top"],
                    "width": root_width,
                    "height": root_available["height"],
                }
            )
            next_left += root_width + gutter
    else:
        root_rects = _pack_zone_rects(
            root_available,
            root_zone_ids,
            orientation=orientation,
            inner_padding=inner_padding,
            gutter=gutter,
        )
    for root_zone_id, root_rect in zip(root_zone_ids, root_rects, strict=False):
        _allocate(root_zone_id, root_rect)
    return zone_rects, zone_content_rects


def _place_zone_nodes(
    surface: dict[str, Any],
    *,
    zone_content_rects: dict[str, dict[str, float]],
) -> dict[str, dict[str, float]]:
    """Place nodes within zone content rectangles using deterministic ranks."""
    elements = [
        element
        for element in surface.get("elements", [])
        if isinstance(element, dict)
        and str(element.get("kind", "")).lower() != "trust_boundary_box"
        and str(element.get("layout_role") or "").lower() != "suppressed"
    ]
    if not elements:
        return {}

    graph = _analyze_surface_layout_graph(surface)
    element_map = {str(element.get("id", "")): element for element in elements}
    zone_ids = sorted(zone_content_rects)
    default_zone_id = zone_ids[0] if zone_ids else ""
    position_map: dict[str, dict[str, float]] = {}
    layout_gutter = _surface_layout_gutter(elements)

    def _layout_node_ids(
        node_ids: list[str],
        rect: dict[str, float],
    ) -> dict[str, dict[str, float]]:
        placements: dict[str, dict[str, float]] = {}
        count = len(node_ids)
        if count <= 0:
            return placements

        available_width = max(MIN_NODE_SIZE, rect["width"])
        measured_sizes: list[tuple[str, float, float]] = []
        for node_id in node_ids:
            element = element_map.get(node_id, {})
            estimated_width, estimated_height = _measure_node_dimensions(element)
            # A node must not be wider than the lane that holds it. Without
            # this clamp a node measured from long label text overflows a
            # narrow lane or child zone and renders outside its own trust
            # boundary while the surface as a whole still fits the canvas.
            measured_sizes.append(
                (
                    node_id,
                    min(
                        MAX_NODE_WIDTH,
                        available_width,
                        max(MIN_NODE_SIZE, estimated_width),
                    ),
                    min(MAX_NODE_HEIGHT, max(MIN_NODE_SIZE, estimated_height)),
                )
            )

        rows: list[list[tuple[str, float, float]]] = []
        current_row: list[tuple[str, float, float]] = []
        current_width = 0.0
        current_band: int | None = None
        node_ranks = graph.get("node_ranks", {})
        # The rect was sized against the same banding, so recomputing it here
        # from the rect keeps placement and estimation in agreement rather than
        # letting placement overflow a zone that was measured for fewer rows.
        band_entries = [
            (entry[0], entry[1], entry[2], int(node_ranks.get(entry[0], 0)))
            for entry in measured_sizes
        ]
        band_size = _fitting_rank_band_size(
            band_entries,
            available_width,
            layout_gutter,
            float(rect.get("height", 0.0)),
        )
        bands = _rank_band_indices(
            (entry[3] for entry in band_entries),
            band_size,
        )
        for entry in measured_sizes:
            node_width = entry[1]
            entry_band = bands.get(int(node_ranks.get(entry[0], 0)), 0)
            projected_width = (
                node_width
                if not current_row
                else current_width + layout_gutter + node_width
            )
            starts_new_row = bool(current_row) and (
                entry_band != current_band or projected_width > available_width
            )
            if starts_new_row:
                rows.append(current_row)
                current_row = [entry]
                current_width = node_width
                current_band = entry_band
                continue
            current_row.append(entry)
            current_width = projected_width
            current_band = entry_band
        if current_row:
            rows.append(current_row)

        row_top = rect["top"]
        for row in rows:
            row_left = rect["left"]
            row_height = max(entry[2] for entry in row)
            for node_id, width, height in row:
                placements[node_id] = {
                    "left": row_left,
                    "top": row_top,
                    "width": width,
                    "height": height,
                }
                row_left += width + layout_gutter
            row_top += row_height + layout_gutter
        return placements

    for zone_id in zone_ids:
        zone_elements = [
            element
            for element in elements
            if str(element.get("trust_zone_id", "")) == zone_id
        ]
        if not zone_elements:
            continue
        content_rect = zone_content_rects.get(zone_id, {})
        if not content_rect:
            continue

        lane_entries = _zone_node_lane_entries(zone_elements, graph)
        main_nodes = [entry[0] for entry in lane_entries["main"]]
        return_nodes = [entry[0] for entry in lane_entries["return"]]
        contextual_nodes = [entry[0] for entry in lane_entries["contextual"]]
        ordered_nodes = main_nodes + return_nodes

        node_area_rect = content_rect
        if _zone_children(surface, zone_id) and ordered_nodes:
            direct_node_count = len(ordered_nodes)
            if direct_node_count > 0:
                node_band_height = min(
                    max(140.0, 100.0 + 24.0 * max(1, math.ceil(direct_node_count / 2))),
                    content_rect["height"] * 0.5,
                )
                node_area_rect = {
                    "left": content_rect["left"],
                    "top": content_rect["top"],
                    "width": content_rect["width"],
                    "height": node_band_height,
                }

        main_placements = _layout_node_ids(main_nodes, node_area_rect)
        position_map.update(main_placements)

        if return_nodes:
            return_left = (
                node_area_rect["left"]
                + node_area_rect["width"] * 0.55
                + MIN_LAYOUT_GUTTER
            )
            content_right = content_rect["left"] + content_rect["width"]
            return_width = max(140.0, node_area_rect["width"] * 0.4)
            # The return lane must stay inside the owning zone; shift it left
            # before shrinking it so return nodes keep their measured width.
            if return_left + return_width > content_right:
                return_left = max(
                    content_rect["left"],
                    content_right - return_width,
                )
                return_width = min(return_width, content_right - return_left)
            return_rect = {
                "left": return_left,
                "top": node_area_rect["top"],
                "width": return_width,
                "height": node_area_rect["height"],
            }
            position_map.update(_layout_node_ids(return_nodes, return_rect))

        if contextual_nodes:
            content_right = content_rect["left"] + content_rect["width"]
            # The lane keeps its offset from the main lane but is pulled back
            # far enough to always retain room for one node, so it ends inside
            # the zone instead of running past it.
            contextual_left = min(
                node_area_rect["left"]
                + max(120.0, node_area_rect["width"] * 0.55)
                + MIN_LAYOUT_GUTTER,
                content_right - MIN_NODE_SIZE,
            )
            contextual_rect = {
                "left": contextual_left,
                "top": node_area_rect["top"],
                "width": min(
                    max(180.0, node_area_rect["width"] * 0.35),
                    content_right - contextual_left,
                ),
                "height": node_area_rect["height"],
            }
            position_map.update(_layout_node_ids(contextual_nodes, contextual_rect))

    for element in elements:
        element_id = str(element.get("id", ""))
        if element_id in position_map:
            continue
        zone_key = str(element.get("trust_zone_id", "") or default_zone_id)
        content_rect = zone_content_rects.get(zone_key)
        if not content_rect:
            continue
        position_map[element_id] = {
            "left": content_rect["left"] + MIN_LAYOUT_GUTTER,
            "top": content_rect["top"] + MIN_LAYOUT_GUTTER,
            "width": MIN_NODE_SIZE,
            "height": MIN_NODE_SIZE,
        }
    return position_map


def _assign_layered_positions(
    surface: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None = None,
) -> tuple[dict[str, dict[str, float]], dict[str, dict[str, float]]]:
    """Allocate zone rectangles and place nodes with a deterministic
    zone-first layout."""
    zone_rects, zone_content_rects = _assign_zone_regions(
        surface, layout_overlay=layout_overlay
    )
    position_map = _place_zone_nodes(surface, zone_content_rects=zone_content_rects)
    return position_map, zone_rects


def _apply_overlay_rules(
    surface: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None,
    zone_rects: dict[str, dict[str, float]] | None = None,
) -> dict[str, float]:
    """Apply supported overlay rules to layout positions before boundaries are built."""
    if not isinstance(layout_overlay, dict):
        return {}

    surface_id = str(surface.get("id", ""))
    applies_to_surface_ids = {
        str(entry.get("surface_id", ""))
        for entry in layout_overlay.get("applies_to", []) or []
        if isinstance(entry, dict) and str(entry.get("surface_id", ""))
    }
    if applies_to_surface_ids and surface_id not in applies_to_surface_ids:
        return {}

    surface_node_ids = {
        str(element.get("id", ""))
        for element in surface.get("elements", [])
        if isinstance(element, dict) and str(element.get("id", ""))
    }
    node_rules = [
        rule
        for rule in layout_overlay.get("node_rules", []) or []
        if isinstance(rule, dict)
        and str(rule.get("surface_id", "")) == surface_id
        and str(rule.get("node_id", "")) in surface_node_ids
    ]

    if not node_rules:
        return {}

    position_updates: dict[str, dict[str, float]] = {}
    for rule in node_rules:
        node_id = str(rule.get("node_id", ""))
        element = next(
            (
                element
                for element in surface.get("elements", [])
                if isinstance(element, dict) and str(element.get("id", "")) == node_id
            ),
            None,
        )
        if not isinstance(element, dict):
            continue
        current_position = element.get("position", {})
        if not isinstance(current_position, dict):
            current_position = {}
        left = float(current_position.get("left", 0.0))
        top = float(current_position.get("top", 0.0))
        width = float(current_position.get("width", 100.0))
        height = float(current_position.get("height", 100.0))

        absolute_position = rule.get("absolute_position")
        if isinstance(absolute_position, dict):
            left = float(absolute_position.get("left", left))
            top = float(absolute_position.get("top", top))
            width = float(absolute_position.get("width", width))
            height = float(absolute_position.get("height", height))
        else:
            relative_placement = rule.get("relative_placement")
            if isinstance(relative_placement, dict):
                reference = str(relative_placement.get("relative_to", ""))
                if reference in surface_node_ids and reference != node_id:
                    reference_element = next(
                        (
                            item
                            for item in surface.get("elements", [])
                            if isinstance(item, dict)
                            and str(item.get("id", "")) == reference
                        ),
                        None,
                    )
                    if isinstance(reference_element, dict):
                        reference_position = reference_element.get("position", {})
                        if not isinstance(reference_position, dict):
                            reference_position = {}
                        offset = relative_placement.get("offset") or {}
                        offset_x = float(offset.get("x", 0.0))
                        offset_y = float(offset.get("y", 0.0))
                        offset_x = max(-1000.0, min(1000.0, offset_x))
                        offset_y = max(-1000.0, min(1000.0, offset_y))
                        reference_left = float(reference_position.get("left", left))
                        reference_top = float(reference_position.get("top", top))
                        left = reference_left + offset_x
                        top = reference_top + offset_y

        zone_id = str(element.get("trust_zone_id", "") or "")
        zone_rect = (zone_rects or {}).get(zone_id)
        if zone_rect is not None:
            boundary_margin = 1.0
            minimum_left = float(zone_rect["left"]) + boundary_margin
            minimum_top = float(zone_rect["top"]) + boundary_margin
            maximum_left = (
                float(zone_rect["left"])
                + float(zone_rect["width"])
                - width
                - boundary_margin
            )
            maximum_top = (
                float(zone_rect["top"])
                + float(zone_rect["height"])
                - height
                - boundary_margin
            )
            if maximum_left < minimum_left or maximum_top < minimum_top:
                raise GenerationError(
                    f"Overlay node {node_id} cannot fit inside trust zone {zone_id}"
                )
            left = min(max(left, minimum_left), maximum_left)
            top = min(max(top, minimum_top), maximum_top)

        rule_layout_role = str(rule.get("layout_role") or "").strip().lower()
        if rule_layout_role in {"main", "connected"}:
            rule_layout_role = "connected"
        if rule_layout_role in {"contextual", "suppressed"}:
            element["layout_role"] = rule_layout_role
        elif rule_layout_role:
            element["layout_role"] = rule_layout_role

        if isinstance(absolute_position, dict):
            element["_overlay_absolute_position"] = True
        element["position"] = {
            "left": left,
            "top": top,
            "width": width,
            "height": height,
        }
        position_updates[node_id] = {"left": left, "top": top}

    return {key: value for key, value in position_updates.items()}


def _reclaim_unused_zone_extent(
    surface: dict[str, Any],
    zone_rects: dict[str, dict[str, float]],
    *,
    layout_overlay: dict[str, Any] | None = None,
) -> None:
    """Shrink zone rectangles onto their placed content when a surface overruns.

    Zone sizing runs before placement and deliberately never under-counts the
    rows a zone will need, so a zone is routinely allocated more room than its
    content finally uses. That surplus is invisible on a surface that fits, but
    on one that overruns the visible canvas it is the difference between a
    clipped diagram and a whole one.

    Only the zone rectangle changes and only ever by shrinking onto content that
    is already placed, so no node moves: zone containment and every routed
    connector are unaffected. A surface that already fits is left untouched, so
    the deliberate spread of a fitting layout is preserved.
    """
    if not zone_rects:
        return
    preferences = _resolve_surface_layout_preferences(
        surface,
        layout_overlay=layout_overlay,
    )
    viewport_target = preferences["viewport_target"]
    outer_margin = float(preferences["outer_margin"])
    width_limit = float(viewport_target.get("width", 0.0)) - outer_margin
    height_limit = float(viewport_target.get("height", 0.0)) - outer_margin

    node_rects: dict[str, list[tuple[float, float]]] = {}
    for element in surface.get("elements", []):
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")).lower() == "trust_boundary_box":
            continue
        position = element.get("position")
        if not isinstance(position, dict):
            continue
        zone_id = str(element.get("trust_zone_id", "") or "")
        if not zone_id:
            continue
        node_rects.setdefault(zone_id, []).append(
            (
                float(position.get("left", 0.0)) + float(position.get("width", 0.0)),
                float(position.get("top", 0.0)) + float(position.get("height", 0.0)),
            )
        )

    surface_right = max(
        (rect["left"] + rect["width"] for rect in zone_rects.values()),
        default=0.0,
    )
    surface_bottom = max(
        (rect["top"] + rect["height"] for rect in zone_rects.values()),
        default=0.0,
    )
    if surface_right <= width_limit and surface_bottom <= height_limit:
        return

    parents = {
        str(zone.get("id", "") or ""): str(zone.get("parent_trust_zone_id", "") or "")
        for zone in surface.get("trust_zones", [])
        if isinstance(zone, dict)
    }

    def _depth(zone_id: str) -> int:
        depth = 0
        seen = {zone_id}
        parent = parents.get(zone_id, "")
        while parent and parent not in seen:
            seen.add(parent)
            depth += 1
            parent = parents.get(parent, "")
        return depth

    # Children are reclaimed before their parents so a parent measures against
    # the child rectangle its own content already shrank to.
    for zone_id in sorted(zone_rects, key=_depth, reverse=True):
        rect = zone_rects[zone_id]
        corners = list(node_rects.get(zone_id, []))
        corners.extend(
            (child["left"] + child["width"], child["top"] + child["height"])
            for child_id, child in zone_rects.items()
            if parents.get(child_id, "") == zone_id
        )
        if not corners:
            continue
        content_right = max(corner[0] for corner in corners)
        content_bottom = max(corner[1] for corner in corners)
        rect["width"] = min(
            rect["width"],
            max(0.0, content_right + ZONE_INNER_PADDING - rect["left"]),
        )
        rect["height"] = min(
            rect["height"],
            max(0.0, content_bottom + ZONE_INNER_PADDING - rect["top"]),
        )


def apply_layout(
    model: dict[str, Any],
    profile: dict[str, Any],
    *,
    layout_overlay: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Assign deterministic positions to elements and connectors for each surface."""
    shape_width = 100
    shape_height = 100

    for surface in model.get("surfaces", []):
        elements = list(surface.get("elements", []))
        # Resolved before any mutation and reused at the layout_metadata write
        # below. Placement and the published record must describe one layout.
        # Resolving a second time after placement would read a mutated surface:
        # the flow list is rebuilt further down and silently drops any flow
        # whose endpoint is missing, which changes the graph the orientation
        # and zone order are derived from. The published record would then
        # describe a layout that was never placed, which is the same class of
        # defect this metadata exists to fix.
        surface_orientation, surface_zone_order = (
            _resolve_surface_orientation_and_zone_order(
                surface,
                layout_overlay=layout_overlay,
            )
        )
        layout_positions, zone_rects = _assign_layered_positions(
            surface, layout_overlay=layout_overlay
        )
        for element in elements:
            element_id = str(element.get("id", ""))
            if str(element.get("layout_role") or "").lower() == "suppressed":
                continue
            if element_id in layout_positions:
                position = dict(layout_positions[element_id])
                if "width" not in position:
                    position["width"] = shape_width
                if "height" not in position:
                    position["height"] = shape_height
                element["position"] = position

        unplaced = sorted(
            str(element.get("id", "") or "")
            for element in elements
            if str(element.get("layout_role") or "").lower() != "suppressed"
            and not isinstance(element.get("position"), dict)
        )
        if unplaced:
            raise GenerationError(
                f"Surface {surface.get('id', 'unknown')} produced no layout "
                f"position for {len(unplaced)} element(s): "
                f"{', '.join(unplaced)}; every element must declare a "
                "trust_zone_id that resolves to a placed trust zone",
                exit_code=EXIT_ERROR,
            )

        _apply_overlay_rules(
            surface,
            layout_overlay=layout_overlay,
            zone_rects=zone_rects,
        )

        _reclaim_unused_zone_extent(
            surface,
            zone_rects,
            layout_overlay=layout_overlay,
        )

        boundary_elements: list[dict[str, Any]] = []
        zone_defs = {
            str(zone.get("id", "")): zone
            for zone in surface.get("trust_zones", [])
            if isinstance(zone, dict)
        }
        unnamed_zones = sorted(
            zone_key
            for zone_key, zone_def in zone_defs.items()
            if zone_key
            and zone_rects.get(zone_key)
            and not str(zone_def.get("name", "") or "").strip()
        )
        if unnamed_zones:
            raise GenerationError(
                f"Surface {surface.get('id', 'unknown')} lays out "
                f"{len(unnamed_zones)} trust zone(s) without a name: "
                f"{', '.join(unnamed_zones)}; every laid-out trust zone must "
                "carry a name so its boundary box is emitted and enforced",
                exit_code=EXIT_ERROR,
            )
        for zone_key, zone_def in zone_defs.items():
            if not zone_key:
                continue
            zone_name = str(zone_def.get("name", "") or "").strip()
            bounds = zone_rects.get(zone_key)
            if not bounds:
                continue
            boundary_elements.append(
                {
                    "id": f"boundary-{zone_key}",
                    "kind": "trust_boundary_box",
                    "name": f"Boundary {zone_name}",
                    "trust_zone_id": zone_key,
                    "surface_id": surface["id"],
                    "guid": _make_guid(f"{surface['id']}:boundary:{zone_key}"),
                    "position": {
                        "left": bounds["left"],
                        "top": bounds["top"],
                        "width": bounds["width"],
                        "height": bounds["height"],
                    },
                    "type_id": profile.get("type_ids", {}).get(
                        "trust_boundary_box", "GE.TB.B"
                    ),
                }
            )
        surface["elements"].extend(boundary_elements)

        min_left = min(
            [
                float(element.get("position", {}).get("left", 0.0))
                for element in surface["elements"]
                if isinstance(element, dict)
                and isinstance(element.get("position"), dict)
            ]
            + [float(bounds.get("left", 0.0)) for bounds in zone_rects.values()],
            default=0.0,
        )
        min_top = min(
            [
                float(element.get("position", {}).get("top", 0.0))
                for element in surface["elements"]
                if isinstance(element, dict)
                and isinstance(element.get("position"), dict)
            ]
            + [float(bounds.get("top", 0.0)) for bounds in zone_rects.values()],
            default=0.0,
        )
        translate_left = max(24.0 - min_left, 0.0)
        translate_top = max(24.0 - min_top, 0.0)
        if translate_left != 0.0 or translate_top != 0.0:
            for element in surface["elements"]:
                if not isinstance(element, dict):
                    continue
                position = element.get("position", {})
                if not isinstance(position, dict):
                    continue
                element["position"] = {
                    **position,
                    "left": float(position.get("left", 0.0)) + translate_left,
                    "top": float(position.get("top", 0.0)) + translate_top,
                }
            for zone_key, bounds in list(zone_rects.items()):
                zone_rects[zone_key] = {
                    **bounds,
                    "left": float(bounds.get("left", 0.0)) + translate_left,
                    "top": float(bounds.get("top", 0.0)) + translate_top,
                }

        surface_flows: list[dict[str, Any]] = []
        placed_label_rects: list[dict[str, float]] = []
        # Connector labels are placed after the nodes they annotate and are the
        # one piece of surface geometry that can still leave the visible canvas
        # once every zone fits inside it, so label placement is given the same
        # canvas the layout targeted.
        connector_preferences = _resolve_surface_layout_preferences(
            surface,
            layout_overlay=layout_overlay,
        )
        connector_viewport = connector_preferences["viewport_target"]
        connector_outer_margin = float(connector_preferences["outer_margin"])
        connector_canvas_bounds = (
            float(connector_viewport.get("width", 0.0)) - connector_outer_margin,
            float(connector_viewport.get("height", 0.0)) - connector_outer_margin,
        )
        placed_connector_segments: list[
            tuple[tuple[float, float], tuple[float, float]]
        ] = []
        routing_graph = _analyze_surface_layout_graph(surface)
        edge_port_slots = _allocate_edge_port_slots(surface, routing_graph)
        reverse_pair_keys = {
            tuple(sorted(pair))
            for pair in routing_graph.get("reverse_edge_pairs", []) or []
        }
        placed_handles: list[tuple[float, float]] = []
        flow_lookup = {
            str(flow.get("id", "")): flow
            for flow in model.get("flows", [])
            if isinstance(flow, dict)
        }
        # Handles and labels are placed greedily: each placement avoids the
        # ones already made. Walking the flows in spec order would therefore
        # make the rendered geometry depend on the order flows happen to be
        # written in. Placement runs in a canonical order keyed by flow id and
        # the emitted list is restored to spec order once every flow is placed.
        ordered_surface_flows = sorted(
            enumerate(surface.get("flows", [])),
            key=lambda item: (str(item[1].get("id", "")), item[0]),
        )
        placed_flow_order: list[int] = []
        for spec_index, flow in ordered_surface_flows:
            source_element = next(
                (
                    element
                    for element in surface["elements"]
                    if element.get("id") == flow.get("source_ref")
                ),
                None,
            )
            target_element = next(
                (
                    element
                    for element in surface["elements"]
                    if element.get("id") == flow.get("target_ref")
                ),
                None,
            )
            if not source_element or not target_element:
                continue
            source_pos = source_element.get("position", {})
            target_pos = target_element.get("position", {})
            source_left = float(source_pos.get("left", 0))
            source_width = float(source_pos.get("width", shape_width))
            source_top = float(source_pos.get("top", 0))
            source_height = float(source_pos.get("height", shape_height))
            target_left = float(target_pos.get("left", 0))
            target_width = float(target_pos.get("width", shape_width))
            target_top = float(target_pos.get("top", 0))
            target_height = float(target_pos.get("height", shape_height))
            source_center_x = source_left + (source_width / 2.0)
            source_center_y = source_top + (source_height / 2.0)
            target_center_x = target_left + (target_width / 2.0)
            target_center_y = target_top + (target_height / 2.0)
            # The anchors are resolved further down through _resolve_port_point,
            # which honours an overlay port declaration and falls back to the
            # same rectangle anchoring. A pair of _rect_anchor assignments used
            # to sit here and was overwritten before either value was read.
            other_rects = []
            boundary_rects_by_zone: dict[str, dict[str, float]] = {}
            for other_element in surface["elements"]:
                if not isinstance(other_element, dict):
                    continue
                if str(other_element.get("id", "")) in {
                    flow.get("source_ref"),
                    flow.get("target_ref"),
                }:
                    continue
                position = other_element.get("position", {})
                if not isinstance(position, dict):
                    continue
                rect = {
                    "left": float(position.get("left", 0)),
                    "top": float(position.get("top", 0)),
                    "width": float(position.get("width", 0)),
                    "height": float(position.get("height", 0)),
                }
                if str(other_element.get("kind", "")).lower() == "trust_boundary_box":
                    boundary_rects_by_zone[
                        str(other_element.get("trust_zone_id", ""))
                    ] = rect
                    continue
                other_rects.append(rect)

            zone_defs_for_routing = {
                str(zone.get("id", "")): zone
                for zone in surface.get("trust_zones", [])
                if isinstance(zone, dict)
            }

            def related_zone_ids(zone_id: str) -> set[str]:
                related: set[str] = set()
                current = str(zone_id or "")
                while current:
                    if current in related:
                        break
                    related.add(current)
                    current = str(
                        zone_defs_for_routing.get(current, {}).get(
                            "parent_trust_zone_id", ""
                        )
                        or ""
                    )
                return related

            source_zone_id = str(source_element.get("trust_zone_id", "") or "")
            target_zone_id = str(target_element.get("trust_zone_id", "") or "")
            route_zone_ids = related_zone_ids(source_zone_id) | related_zone_ids(
                target_zone_id
            )
            unrelated_boundary_rects = [
                rect
                for zone_id, rect in boundary_rects_by_zone.items()
                if zone_id not in route_zone_ids
            ]
            unrelated_label_band_rects = [
                {
                    "left": rect["left"],
                    "top": rect["top"],
                    "width": rect["width"],
                    "height": 36.0,
                }
                for rect in unrelated_boundary_rects
            ]
            routing_obstacles = [
                *other_rects,
                *unrelated_boundary_rects,
                *unrelated_label_band_rects,
            ]
            routing_hints = {}
            if isinstance(layout_overlay, dict):
                for rule in layout_overlay.get("node_rules", []) or []:
                    if not isinstance(rule, dict):
                        continue
                    if str(rule.get("surface_id", "")) != surface["id"]:
                        continue
                    node_id = str(rule.get("node_id", ""))
                    if node_id in {
                        str(source_element.get("id", "")),
                        str(target_element.get("id", "")),
                    }:
                        routing_hints[node_id] = 0.0
            overlay_rule = _resolve_connector_rule(
                surface,
                flow,
                layout_overlay=layout_overlay,
            )
            source_port = None
            target_port = None
            if isinstance(overlay_rule, dict):
                source_port = overlay_rule.get("source_port")
                target_port = overlay_rule.get("target_port")
            source_rect_for_ports = {
                "left": float(source_left),
                "top": float(source_top),
                "width": float(source_width),
                "height": float(source_height),
            }
            target_rect_for_ports = {
                "left": float(target_left),
                "top": float(target_top),
                "width": float(target_width),
                "height": float(target_height),
            }
            source_anchor = _resolve_port_point(
                source_rect_for_ports,
                (target_center_x, target_center_y),
                source_port,
            )
            target_anchor = _resolve_port_point(
                target_rect_for_ports,
                (source_center_x, source_center_y),
                target_port,
            )
            if not isinstance(overlay_rule, dict) or not source_port:
                source_anchor = _apply_port_slot_offset(
                    source_anchor,
                    source_rect_for_ports,
                    edge_port_slots.get(str(flow.get("id", "")), {}).get("source"),
                )
            if not isinstance(overlay_rule, dict) or not target_port:
                target_anchor = _apply_port_slot_offset(
                    target_anchor,
                    target_rect_for_ports,
                    edge_port_slots.get(str(flow.get("id", "")), {}).get("target"),
                )
            same_zone = source_zone_id and source_zone_id == target_zone_id
            source_point, target_point = _find_clear_connector_points(
                {
                    "left": float(source_left),
                    "top": float(source_top),
                    "width": float(source_width),
                    "height": float(source_height),
                },
                {
                    "left": float(target_left),
                    "top": float(target_top),
                    "width": float(target_width),
                    "height": float(target_height),
                },
                routing_obstacles,
                source_anchor,
                target_anchor,
                int(flow.get("ordinal", len(surface_flows) + 1)),
                routing_hints=routing_hints,
                source_node_id=str(source_element.get("id", "")),
                target_node_id=str(target_element.get("id", "")),
                overlay_rule=overlay_rule,
            )
            preferred_handle = None
            if not same_zone:
                source_zone_port = _resolve_zone_port_point(
                    zone_rects.get(source_zone_id),
                    (target_center_x, target_center_y),
                    offset=12.0,
                )
                target_zone_port = _resolve_zone_port_point(
                    zone_rects.get(target_zone_id),
                    (source_center_x, source_center_y),
                    offset=12.0,
                )
                if source_zone_port is not None and target_zone_port is not None:
                    preferred_handle = (
                        (source_zone_port[0] + target_zone_port[0]) / 2.0,
                        (source_zone_port[1] + target_zone_port[1]) / 2.0,
                    )
            source_id_for_lane = str(source_element.get("id", ""))
            target_id_for_lane = str(target_element.get("id", ""))
            reverse_lane_sign = 0.0
            if (
                tuple(sorted((source_id_for_lane, target_id_for_lane)))
                in reverse_pair_keys
            ):
                reverse_lane_sign = (
                    1.0 if source_id_for_lane <= target_id_for_lane else -1.0
                )
            handle_point = _route_connector_handle(
                {
                    "left": float(source_left),
                    "top": float(source_top),
                    "width": float(source_width),
                    "height": float(source_height),
                },
                {
                    "left": float(target_left),
                    "top": float(target_top),
                    "width": float(target_width),
                    "height": float(target_height),
                },
                routing_obstacles,
                source_point,
                target_point,
                int(flow.get("ordinal", len(surface_flows) + 1)),
                source_node_id=str(source_element.get("id", "")),
                target_node_id=str(target_element.get("id", "")),
                overlay_rule=overlay_rule,
                preferred_handle=preferred_handle,
                existing_segments=placed_connector_segments,
                existing_handles=placed_handles,
                reverse_lane_sign=reverse_lane_sign,
            )
            flow_payload = flow_lookup.get(str(flow.get("id", "")), flow)
            all_boundary_label_bands = [
                {
                    "left": rect["left"],
                    "top": rect["top"],
                    "width": rect["width"],
                    "height": 36.0,
                }
                for rect in boundary_rects_by_zone.values()
            ]
            label_obstacles = [
                {
                    "left": source_left,
                    "top": source_top,
                    "width": source_width,
                    "height": source_height,
                },
                {
                    "left": target_left,
                    "top": target_top,
                    "width": target_width,
                    "height": target_height,
                },
                *other_rects,
                *all_boundary_label_bands,
                *placed_label_rects,
            ]
            try:
                label_layout = _place_connector_label(
                    flow_payload.get("label"),
                    flow_payload.get("transport"),
                    handle=handle_point,
                    obstacles=label_obstacles,
                    routing_obstacles=routing_obstacles,
                    source_point=source_point,
                    target_point=target_point,
                    existing_segments=placed_connector_segments,
                    preserve_handle=True,
                    explicit_handle=isinstance(overlay_rule, dict)
                    and isinstance(overlay_rule.get("handle_point"), dict),
                    reverse_lane_sign=reverse_lane_sign,
                    existing_handles=placed_handles,
                    canvas_bounds=connector_canvas_bounds,
                )
            except ValueError as exc:
                raise GenerationError(
                    f"Connector label for flow {flow.get('id', 'unknown')} "
                    f"cannot be rendered: {exc}"
                ) from exc
            handle_point = tuple(label_layout.pop("handle_point"))
            placed_handles.append(handle_point)
            placed_connector_segments.extend(
                [
                    (source_point, handle_point),
                    (handle_point, target_point),
                ]
            )
            label_left, label_top, label_width, label_height = label_layout[
                "label_rect"
            ]
            placed_label_rects.append(
                {
                    "left": float(label_left),
                    "top": float(label_top),
                    "width": float(label_width),
                    "height": float(label_height),
                }
            )
            placed_flow_order.append(spec_index)
            surface_flows.append(
                {
                    **flow,
                    "position": {
                        "source_x": int(round(source_point[0])),
                        "source_y": int(round(source_point[1])),
                        "target_x": int(round(target_point[0])),
                        "target_y": int(round(target_point[1])),
                        "handle_x": int(round(handle_point[0])),
                        "handle_y": int(round(handle_point[1])),
                    },
                    "ordinal": flow.get("ordinal", spec_index + 1),
                    "source_guid": source_element.get("guid"),
                    "target_guid": target_element.get("guid"),
                    "surface_id": surface["id"],
                    "display_label": label_layout["display_label"],
                    "label_lines": label_layout["label_lines"],
                    "label_rect": label_layout["label_rect"],
                }
            )
        surface_flows = [
            payload
            for _, payload in sorted(
                zip(placed_flow_order, surface_flows),
                key=lambda item: item[0],
            )
        ]
        surface["flows"] = surface_flows
        _assert_zone_containment(surface)

        geometry_points: list[tuple[float, float]] = []
        for element in surface["elements"]:
            if not isinstance(element, dict):
                continue
            position = element.get("position")
            if not isinstance(position, dict):
                continue
            left = float(position.get("left", 0.0))
            top = float(position.get("top", 0.0))
            geometry_points.extend(
                [
                    (left, top),
                    (
                        left + float(position.get("width", 0.0)),
                        top + float(position.get("height", 0.0)),
                    ),
                ]
            )
        for routed_flow in surface_flows:
            position = routed_flow.get("position", {})
            geometry_points.extend(
                [
                    (
                        float(position.get("source_x", 0.0)),
                        float(position.get("source_y", 0.0)),
                    ),
                    (
                        float(position.get("target_x", 0.0)),
                        float(position.get("target_y", 0.0)),
                    ),
                    (
                        float(position.get("handle_x", 0.0)),
                        float(position.get("handle_y", 0.0)),
                    ),
                ]
            )
            label_left, label_top, label_width, label_height = routed_flow.get(
                "label_rect", [0.0, 0.0, 0.0, 0.0]
            )
            geometry_points.extend(
                [
                    (float(label_left), float(label_top)),
                    (
                        float(label_left) + float(label_width),
                        float(label_top) + float(label_height),
                    ),
                ]
            )

        if geometry_points:
            minimum_x = min(point[0] for point in geometry_points)
            minimum_y = min(point[1] for point in geometry_points)
            shift_x = max(24.0 - minimum_x, 0.0)
            shift_y = max(24.0 - minimum_y, 0.0)
            if shift_x or shift_y:
                for element in surface["elements"]:
                    if not isinstance(element, dict):
                        continue
                    position = element.get("position", {})
                    if not isinstance(position, dict):
                        continue
                    position["left"] = float(position.get("left", 0.0)) + shift_x
                    position["top"] = float(position.get("top", 0.0)) + shift_y
                for routed_flow in surface_flows:
                    position = routed_flow.get("position", {})
                    for key in ("source_x", "target_x", "handle_x"):
                        position[key] = float(position.get(key, 0.0)) + shift_x
                    for key in ("source_y", "target_y", "handle_y"):
                        position[key] = float(position.get(key, 0.0)) + shift_y
                    label_rect = routed_flow.get("label_rect", [])
                    if isinstance(label_rect, list) and len(label_rect) == 4:
                        label_rect[0] = float(label_rect[0]) + shift_x
                        label_rect[1] = float(label_rect[1]) + shift_y

            geometry_points = [
                (point[0] + shift_x, point[1] + shift_y) for point in geometry_points
            ]
            maximum_x = max(point[0] for point in geometry_points) + 24.0
            maximum_y = max(point[1] for point in geometry_points) + 24.0
            preferences = _resolve_surface_layout_preferences(
                surface,
                layout_overlay=layout_overlay,
            )
            viewport = preferences["viewport_target"]
            viewport_width = float(viewport.get("width", 1920.0))
            viewport_height = float(viewport.get("height", 1080.0))
            if maximum_x > viewport_width * 2.0 or maximum_y > viewport_height * 2.0:
                raise GenerationError(
                    f"Surface {surface.get('id', 'unknown')} exceeds the bounded "
                    "two-by-two pane canvas"
                )
            # Layout derives the graph ranks, branch groups, orientation, and
            # zone order it places against and would otherwise discard them.
            # Validation-time refinement cannot recover them from a rendered
            # diagram, so it previously scored the shipped layout as though it
            # had no ranks and no branches at all. Publishing them here is
            # in-process surface state only; the serializer reads none of these
            # keys, so generated bytes are unchanged.
            surface["layout_metadata"] = {
                "diagram_bounds": [24.0, 24.0, maximum_x, maximum_y],
                "viewport": [
                    float(viewport.get("left", 0.0)),
                    float(viewport.get("top", 0.0)),
                    viewport_width,
                    viewport_height,
                ],
                "scroll_extent_ratio_x": maximum_x / viewport_width,
                "scroll_extent_ratio_y": maximum_y / viewport_height,
                "orientation": surface_orientation,
                "zone_order": surface_zone_order,
                "node_ranks": dict(routing_graph.get("node_ranks", {})),
                "branch_groups": dict(routing_graph.get("branch_groups", {})),
            }
    return model


def _rect_escapes(
    inner: tuple[float, float, float, float],
    outer: tuple[float, float, float, float],
) -> bool:
    """Report whether ``inner`` leaves ``outer`` beyond the containment tolerance."""
    left, top, right, bottom = inner
    outer_left, outer_top, outer_right, outer_bottom = outer
    return (
        left < outer_left - ZONE_CONTAINMENT_TOLERANCE
        or top < outer_top - ZONE_CONTAINMENT_TOLERANCE
        or right > outer_right + ZONE_CONTAINMENT_TOLERANCE
        or bottom > outer_bottom + ZONE_CONTAINMENT_TOLERANCE
    )


def _assert_zone_containment(surface: dict[str, Any]) -> None:
    """Fail closed when a laid-out node escapes its declared trust zone.

    The bounded-canvas guard only rejects gross overflow of the whole surface,
    so a moderately dense zone can pack nodes past its own boundary box while
    the surface still fits. That renders a diagram whose trust boundaries no
    longer describe the model, which is worse than no diagram at all. Nested
    zones are checked against their declared parent for the same reason.
    """
    zone_rects: dict[str, tuple[float, float, float, float]] = {}
    for element in surface.get("elements", []):
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) != "trust_boundary_box":
            continue
        position = element.get("position")
        if not isinstance(position, dict):
            continue
        left = float(position.get("left", 0.0))
        top = float(position.get("top", 0.0))
        zone_rects[str(element.get("trust_zone_id", ""))] = (
            left,
            top,
            left + float(position.get("width", 0.0)),
            top + float(position.get("height", 0.0)),
        )
    if not zone_rects:
        return

    zone_escapes: list[str] = []
    for zone in surface.get("trust_zones", []):
        if not isinstance(zone, dict):
            continue
        zone_id = str(zone.get("id", "") or "")
        parent_zone_id = str(zone.get("parent_trust_zone_id", "") or "")
        if not zone_id or not parent_zone_id:
            continue
        child_rect = zone_rects.get(zone_id)
        parent_rect = zone_rects.get(parent_zone_id)
        if child_rect is None or parent_rect is None:
            continue
        if _rect_escapes(child_rect, parent_rect):
            zone_escapes.append(f"{zone_id} outside parent {parent_zone_id}")
    if zone_escapes:
        raise GenerationError(
            f"Surface {surface.get('id', 'unknown')} places "
            f"{len(zone_escapes)} trust zone(s) outside their parent zone: "
            f"{', '.join(sorted(zone_escapes))}",
            exit_code=EXIT_ERROR,
        )

    escapes: list[str] = []
    for element in surface.get("elements", []):
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) == "trust_boundary_box":
            continue
        if str(element.get("layout_role") or "").lower() == "suppressed":
            continue
        zone_rect = zone_rects.get(str(element.get("trust_zone_id", "") or ""))
        if zone_rect is None:
            continue
        position = element.get("position")
        if not isinstance(position, dict):
            continue
        left = float(position.get("left", 0.0))
        top = float(position.get("top", 0.0))
        right = left + float(position.get("width", 0.0))
        bottom = top + float(position.get("height", 0.0))
        if _rect_escapes((left, top, right, bottom), zone_rect):
            escapes.append(
                f"{element.get('id', 'unknown')} in zone "
                f"{element.get('trust_zone_id', 'unknown')}"
            )
    if escapes:
        raise GenerationError(
            f"Surface {surface.get('id', 'unknown')} places "
            f"{len(escapes)} node(s) outside their trust zone: "
            f"{', '.join(sorted(escapes))}",
            exit_code=EXIT_ERROR,
        )


def _flatten_laid_out_model(model: dict[str, Any]) -> None:
    """Rebuild the flat element/flow lists from the laid-out surfaces.

    ``build_model_from_spec`` seeds ``model["elements"]``/``["flows"]`` with
    empty-position copies before ``apply_layout`` runs. ``apply_layout`` assigns
    geometry (and trust-boundary shapes and connector guids) onto the surface
    lists instead, so the serialized geometry must be re-derived from those
    laid-out surfaces or every shape emits at the origin.
    """
    elements: list[dict[str, Any]] = []
    flows: list[dict[str, Any]] = []
    for surface in model.get("surfaces", []):
        surface_id = surface.get("id")
        suppressed_ids = {
            str(element.get("id", ""))
            for element in surface.get("elements", [])
            if str(element.get("layout_role") or "").lower() == "suppressed"
        }
        for flow in surface.get("flows", []):
            attached = suppressed_ids.intersection(
                {str(flow.get("source_ref", "")), str(flow.get("target_ref", ""))}
            )
            if attached:
                raise GenerationError(
                    f"suppressed element {sorted(attached)[0]} still carries "
                    f"connector {flow.get('id', 'unknown')} on surface "
                    f"{surface_id}; suppress the connector explicitly or leave "
                    "the element visible",
                    exit_code=EXIT_ERROR,
                )
        for element in surface.get("elements", []):
            if str(element.get("layout_role") or "").lower() == "suppressed":
                continue
            merged = {**element}
            merged.setdefault("surface_id", surface_id)
            elements.append(merged)
        for flow in surface.get("flows", []):
            merged = {**flow}
            merged["surface_id"] = surface_id
            flows.append(merged)
    model["elements"] = elements
    model["flows"] = flows


def build_tm7_payload(
    spec: dict[str, Any],
    profile: dict[str, Any],
    mode: str,
    existing_model: dict[str, Any] | None = None,
    *,
    threat_generation_enabled: bool | None = None,
    layout_overlay: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Build the internal TM7 payload structure for serialization."""
    model = build_model_from_spec(spec, profile, mode)
    model = apply_layout(model, profile, layout_overlay=layout_overlay)
    _flatten_laid_out_model(model)
    threats = derive_threats(
        spec,
        model,
        mode,
        profile,
        threat_generation_enabled=threat_generation_enabled,
    )
    model["threats"] = threats
    model["notes"].append(DISCLAIMER_TEXT)
    if existing_model:
        model = merge_model(model, existing_model)

    threat_generation_enabled_value = _coerce_bool(
        threat_generation_enabled
        if threat_generation_enabled is not None
        else spec.get("threat_generation_enabled"),
        default=False,
    )
    payload = {
        "Version": "4.3",
        "Profile": model.get("profile", "sdl_core_generic"),
        "ThreatGenerationEnabled": threat_generation_enabled_value,
        "ThreatInstances": [
            {
                **{
                    "id": threat["id"],
                    "interaction_ref": threat.get("interaction_ref", ""),
                    "target_ref": threat["target_ref"],
                    "title": threat["title"],
                    "description": threat["description"],
                    "state": threat.get("state", "Open"),
                    "notes": threat.get("notes", ""),
                    "citations": threat.get("citations", {}),
                    "properties": threat.get("properties", {}),
                    "category": threat.get("category", "tampering"),
                    "source": threat.get("source", "generated"),
                },
                "type_id": threat.get("type_id") or threat.get("category", "tampering"),
            }
            for threat in model["threats"]
        ],
        "Notes": [],
        "Surfaces": model["surfaces"],
        "Elements": model.get("elements", []),
        "Flows": model.get("flows", []),
        "KnowledgeBase": model.get("knowledge_base", "default"),
        "spec": spec,
        "Spec": spec,
    }
    return payload


def merge_model(
    spec_model: dict[str, Any], existing_model: dict[str, Any]
) -> dict[str, Any]:
    """Merge the generated model with an existing TM7 model, preserving human edits."""
    translated_existing = existing_model.get("parsed", existing_model)
    existing_elements = {
        element.get("id"): element
        for element in translated_existing.get("elements", [])
    }
    existing_flows = {
        flow.get("id"): flow for flow in translated_existing.get("flows", [])
    }
    existing_threats = {
        threat.get("id"): threat for threat in translated_existing.get("threats", [])
    }

    for element in spec_model.get("elements", []):
        existing = existing_elements.get(element.get("id"))
        if existing:
            element["position"] = existing.get("position", element.get("position", {}))
            element["notes"] = existing.get("notes", element.get("notes", ""))
            element["id"] = existing.get("id", element.get("id", ""))

    for flow in spec_model.get("flows", []):
        existing = existing_flows.get(flow.get("id"))
        if existing:
            flow["position"] = existing.get("position", flow.get("position", {}))
            flow["retention"] = existing.get("retention", flow.get("retention", ""))

    preserved_threats: list[dict[str, Any]] = []
    for threat in spec_model.get("threats", []):
        existing = existing_threats.get(threat.get("id"))
        if existing and existing.get("state") not in {
            None,
            "",
            "Open",
            "AutoGenerated",
        }:
            threat["state"] = existing.get("state", threat.get("state", "Open"))
            threat["notes"] = existing.get("notes", threat.get("notes", ""))
        preserved_threats.append(threat)
    spec_model["threats"] = preserved_threats
    return spec_model


def _escape_xml_text(value: str) -> str:
    """Escape XML text content for manual string insertion into the KB template."""
    return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _add_child(
    parent: ET.Element,
    tag: str,
    text: str | None = None,
    attrs: dict[str, str] | None = None,
) -> ET.Element:
    element = ET.SubElement(parent, tag, attrs or {})
    if text is not None:
        element.text = text
    return element


def _add_display_attribute(
    parent: ET.Element,
    display_name: str,
    value: str | None,
    *,
    attr_type: str,
    value_attr_type: str | None = None,
) -> None:
    value_attrs: dict[str, str] = {
        "xmlns:a": ARRAYS_NS,
        "xmlns:b": KNOWLEDGE_NS,
        "i:type": attr_type,
    }
    element = ET.SubElement(parent, "a:anyType", value_attrs)
    _add_child(element, "b:DisplayName", display_name, {"xmlns:b": KNOWLEDGE_NS})
    name_text = "" if attr_type.endswith("HeaderDisplayAttribute") else display_name
    _add_child(element, "b:Name", name_text, {"xmlns:b": KNOWLEDGE_NS})
    value_node = _add_child(element, "b:Value", None, {"xmlns:b": KNOWLEDGE_NS})
    if value is None:
        value_node.attrib["i:nil"] = "true"
    else:
        value_node.text = value
        # StringDisplayAttribute.Value is typed as object; the DataContract
        # serializer requires an explicit i:type hint to read the text as a
        # string. Default to xsd:string unless the caller overrides.
        value_node.attrib["i:type"] = value_attr_type or "c:string"
        value_node.attrib["xmlns:c"] = "http://www.w3.org/2001/XMLSchema"


def _serialize_integral_value(value: Any, *, default: int = 0) -> str:
    """Serialize geometry values as integer strings for TM7 compatibility."""
    if value is None:
        return str(default)
    try:
        return str(int(float(value)))
    except (TypeError, ValueError):
        return str(default)


def _parse_geometry_value(value: Any, *, default: int = 0) -> int:
    """Parse geometry values from TM7 XML, accepting decimal text."""
    if value is None:
        return default
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def _load_knowledge_base(
    template_dir: Path, profile_name: str
) -> tuple[str, dict[str, Any]]:
    kb_path = template_dir / "assets" / "templates" / "default-kb.xml"
    if not kb_path.exists():
        raise GenerationError(
            "Missing bundled default KnowledgeBase template", exit_code=EXIT_ERROR
        )

    kb_text = kb_path.read_text(encoding="utf-8").strip()
    if not kb_text.startswith("<KnowledgeBase") or "</KnowledgeBase>" not in kb_text:
        raise GenerationError(
            "Embedded KnowledgeBase asset is malformed", exit_code=EXIT_ERROR
        )

    return kb_text, {"profile": profile_name}


def _extend_knowledge_base_with_spec_threats(
    kb_text: str, payload: dict[str, Any]
) -> str:
    """Append custom ThreatType entries for explicit spec threats into the KB."""
    spec = payload.get("spec") or payload.get("Spec")
    if not isinstance(spec, dict):
        return kb_text

    spec_threats = [
        threat for threat in (spec.get("threats") or []) if isinstance(threat, dict)
    ]
    if not spec_threats:
        return kb_text

    existing_ids = set(re.findall(r"<a:Id>([^<]+)</a:Id>", kb_text))
    fragments: list[str] = []
    for spec_threat in spec_threats:
        type_id = str(
            _build_spec_threat_type_id(
                spec_threat.get("id", "spec-threat"), spec_threat
            )
        ).strip()
        if not type_id or type_id in existing_ids:
            continue

        description = str(
            spec_threat.get("description") or spec_threat.get("title") or ""
        )
        category = str(spec_threat.get("category") or "E")
        title = str(spec_threat.get("title") or "")

        def _collect_mitigation_texts(value: Any) -> list[str]:
            items: list[str] = []
            if isinstance(value, str):
                if value.strip():
                    items.append(value.strip())
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, str) and item.strip():
                        items.append(item.strip())
                    elif isinstance(item, dict):
                        for nested_key in (
                            "description",
                            "details",
                            "detail",
                            "text",
                            "name",
                            "title",
                        ):
                            nested_value = item.get(nested_key)
                            if isinstance(nested_value, str) and nested_value.strip():
                                items.append(nested_value.strip())
                                break
            elif isinstance(value, dict):
                for nested_key in (
                    "description",
                    "details",
                    "detail",
                    "text",
                    "name",
                    "title",
                ):
                    nested_value = value.get(nested_key)
                    if isinstance(nested_value, str) and nested_value.strip():
                        items.append(nested_value.strip())
                        break
            return items

        mitigation_candidates: list[str] = []
        for key in ("possible_mitigations", "mitigations", "mitigation"):
            mitigation_candidates.extend(
                _collect_mitigation_texts(spec_threat.get(key))
            )

        mitigation_ids = spec_threat.get("mitigation_ids")
        if isinstance(mitigation_ids, (list, tuple, set)):
            mitigation_id_values = [
                str(item) for item in mitigation_ids if str(item).strip()
            ]
        elif isinstance(mitigation_ids, str) and mitigation_ids.strip():
            mitigation_id_values = [mitigation_ids.strip()]
        else:
            mitigation_id_values = []

        if mitigation_id_values:
            mitigation_lookup = {
                str(item.get("id")): item
                for item in (spec.get("mitigations") or [])
                if isinstance(item, dict) and item.get("id") is not None
            }
            for mitigation_id in mitigation_id_values:
                mitigation_item = mitigation_lookup.get(mitigation_id)
                if isinstance(mitigation_item, dict):
                    mitigation_candidates.extend(
                        _collect_mitigation_texts(mitigation_item)
                    )

        if mitigation_candidates:
            mitigation_text = "; ".join(dict.fromkeys(mitigation_candidates))
        else:
            mitigation_text = "Review the implementation for a suitable mitigation."

        metadata_fragments = [
            "<a:PropertiesMetaData>"
            "<ThreatMetaDatum>"
            f"<Name>UserThreatDescription</Name>"
            "<Label>Description</Label>"
            "<HideFromUI>false</HideFromUI>"
            f'<Values xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"><b:string>{_escape_xml_text(description)}</b:string></Values>'
            "<Id>22222222-2222-2222-2222-222222222222</Id>"
            "<AttributeType>0</AttributeType>"
            "</ThreatMetaDatum>"
            "<ThreatMetaDatum>"
            f"<Name>PossibleMitigations</Name>"
            "<Label>Possible Mitigation(s)</Label>"
            "<HideFromUI>false</HideFromUI>"
            f'<Values xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"><b:string>{_escape_xml_text(mitigation_text)}</b:string></Values>'
            "<Id>22222222-2222-2222-2222-222222222222</Id>"
            "<AttributeType>2</AttributeType>"
            "</ThreatMetaDatum>"
            "<ThreatMetaDatum>"
            f"<Name>Priority</Name>"
            "<Label>Priority</Label>"
            "<HideFromUI>false</HideFromUI>"
            f'<Values xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"><b:string>High</b:string></Values>'
            "<Id>22222222-2222-2222-2222-222222222222</Id>"
            "<AttributeType>1</AttributeType>"
            "</ThreatMetaDatum>"
            "<ThreatMetaDatum>"
            f"<Name>SDLPhase</Name>"
            "<Label>SDL Phase</Label>"
            "<HideFromUI>false</HideFromUI>"
            f'<Values xmlns:b="http://schemas.microsoft.com/2003/10/Serialization/Arrays"><b:string>Implementation</b:string></Values>'
            "<Id>22222222-2222-2222-2222-222222222222</Id>"
            "<AttributeType>1</AttributeType>"
            "</ThreatMetaDatum>"
            "</a:PropertiesMetaData>"
        ]

        normalized_category = {
            "spoofing": "S",
            "tampering": "T",
            "repudiation": "R",
            "information-disclosure": "I",
            "information disclosure": "I",
            "denial-of-service": "D",
            "denial of service": "D",
            "elevation-of-privilege": "E",
            "elevation of privilege": "E",
        }.get(str(category or "").strip().lower(), str(category or "E"))
        if len(normalized_category) > 1:
            normalized_category = str(normalized_category[0]).upper()

        fragments.append(
            "<a:ThreatType>"
            "<a:IsExtension>false</a:IsExtension>"
            f"<a:Category>{_escape_xml_text(normalized_category)}</a:Category>"
            f"<a:Description>{_escape_xml_text(description)}</a:Description>"
            "<a:GenerationFilters>"
            "<a:Include>source is 'ROOT'</a:Include>"
            "<a:Exclude/>"
            "</a:GenerationFilters>"
            f"<a:Id>{_escape_xml_text(type_id)}</a:Id>"
            + "".join(metadata_fragments)
            + f'<a:RelatedCategory i:nil="true"/>'
            f"<a:ShortTitle>{_escape_xml_text(title)}</a:ShortTitle>"
            "</a:ThreatType>"
        )
        existing_ids.add(type_id)

    if not fragments:
        return kb_text

    closing_marker = "</a:ThreatTypes>"
    if closing_marker not in kb_text:
        closing_marker = "</ThreatTypes>"
    if closing_marker not in kb_text:
        return kb_text

    return kb_text.replace(closing_marker, "".join(fragments) + closing_marker, 1)


def _renumber_kb_root_zid(kb_text: str, zid: int) -> str:
    """Renumber the KnowledgeBase root z:Id so it follows the diagram sequence.

    The bundled KnowledgeBase carries a single z:Id on its root element and no
    z:Ref targets it, so it can be freely renumbered to sit immediately after
    the diagram's allocated ids. This keeps every z:Id in one contiguous,
    collision-free sequence regardless of how many diagram objects exist.
    """
    updated, count = re.subn(r'z:Id="i\d+"', f'z:Id="i{zid}"', kb_text, count=1)
    if count == 0:
        raise GenerationError(
            "Embedded KnowledgeBase asset is missing its root z:Id",
            exit_code=EXIT_ERROR,
        )
    return updated


def _serialize_threat_instances(root: ET.Element, payload: dict[str, Any]) -> None:
    """Serialize the threat payload into the ThreatInstances DataContract array."""
    flows_by_id = {
        str(flow.get("id", "")): flow
        for flow in payload.get("Flows", [])
        if isinstance(flow, dict) and flow.get("id") is not None
    }
    surfaces_by_id = {
        str(surface.get("id", "")): surface
        for surface in payload.get("Surfaces", [])
        if isinstance(surface, dict) and surface.get("id") is not None
    }

    threat_payloads: list[dict[str, Any]] = []
    dropped: list[str] = []
    spec_threat_count = 0
    for threat in payload.get("ThreatInstances", []):
        if not isinstance(threat, dict) or threat.get("source") != "spec":
            continue

        spec_threat_count += 1
        threat_id = str(threat.get("id", "") or "(unnamed)")
        interaction_ref = str(threat.get("interaction_ref", ""))
        interaction = flows_by_id.get(interaction_ref)
        if not isinstance(interaction, dict):
            dropped.append(
                f"{threat_id}: interaction_ref "
                f"{interaction_ref or '(missing)'} does not resolve to a model flow"
            )
            continue

        source_guid = str(interaction.get("source_guid") or "")
        flow_guid = str(
            interaction.get("guid")
            or _make_guid(
                f"{interaction.get('surface_id', '')}:{interaction.get('id', '')}"
            )
        )
        target_guid = str(interaction.get("target_guid") or "")
        missing_guids = sorted(
            name
            for name, value in (
                ("source_guid", source_guid),
                ("flow_guid", flow_guid),
                ("target_guid", target_guid),
            )
            if not value
        )
        if missing_guids:
            dropped.append(
                f"{threat_id}: flow {interaction_ref} is missing "
                f"{', '.join(missing_guids)}"
            )
            continue

        surface_id = str(interaction.get("surface_id", ""))
        surface = surfaces_by_id.get(surface_id) if surface_id else None
        drawing_surface_guid = ""
        if surface is not None:
            drawing_surface_guid = str(
                _make_guid(f"surface:{surface.get('id', surface_id)}")
            )

        type_id = str(threat.get("type_id") or threat.get("category") or "")
        threat_payloads.append(
            {
                **threat,
                "source_id": str(threat.get("id", "")),
                "interaction_string": str(
                    interaction.get("display_label") or interaction_ref
                ),
                "type_id": type_id,
                "source_guid": source_guid,
                "flow_guid": flow_guid,
                "target_guid": target_guid,
                "interaction_key": build_interaction_key(
                    source_guid,
                    flow_guid,
                    target_guid,
                ),
                "drawing_surface_guid": drawing_surface_guid,
                "dictionary_key": build_entry_key(
                    type_id,
                    source_guid,
                    flow_guid,
                    target_guid,
                ),
            }
        )

    if dropped:
        raise GenerationError(
            f"Threat serialization would drop {len(dropped)} spec threat(s):\n"
            + "\n".join(sorted(dropped)),
            exit_code=EXIT_ERROR,
        )

    if not payload.get("ThreatInstances"):
        ET.SubElement(root, "ThreatInstances")
        return

    mapping_failures = collect_mapping_failures(payload.get("spec") or {})
    if mapping_failures:
        raise GenerationError(
            "Threat mapping contract validation failed:\n"
            + "\n".join(mapping_failures),
            exit_code=EXIT_ERROR,
        )

    prepared = serialize_threat_instances(root, threat_payloads)
    if len(prepared) != spec_threat_count:
        raise GenerationError(
            f"Threat serialization emitted {len(prepared)} instances for "
            f"{spec_threat_count} spec threat(s)",
            exit_code=EXIT_ERROR,
        )


def render_tm7_xml(
    payload: dict[str, Any], template_dir: Path, profile_name: str
) -> str:
    """Serialize the internal payload into a deterministic XML string."""
    root = ET.Element("ThreatModel", {"xmlns": MODEL_NS, "xmlns:i": XSI_NS})

    drawing_surface_list = ET.SubElement(root, "DrawingSurfaceList")
    knowledge_base_text, _ = _load_knowledge_base(template_dir, str(profile_name))
    z_id_allocator = _ZIdAllocator()

    for surface in payload.get("Surfaces", []):
        surface_node = ET.SubElement(
            drawing_surface_list,
            "DrawingSurfaceModel",
            {"xmlns:z": SER_NS, "z:Id": z_id_allocator.next_id()},
        )
        _add_child(
            surface_node, "GenericTypeId", "DRAWINGSURFACE", {"xmlns": ABSTRACT_NS}
        )
        _add_child(
            surface_node,
            "Guid",
            _make_guid(f"surface:{surface['id']}"),
            {"xmlns": ABSTRACT_NS},
        )
        surface_properties = _add_child(
            surface_node,
            "Properties",
            None,
            {"xmlns": ABSTRACT_NS, "xmlns:a": ARRAYS_NS},
        )
        # TMT reads a drawing surface's tab caption from the StringDisplayAttribute
        # named "Name" in this collection, the same mechanism element names use.
        # The sibling Header element is kept in sync but does not drive the tab.
        surface_title = str(surface.get("name", surface.get("id", "surface")))
        _add_display_attribute(
            surface_properties, "Diagram", None, attr_type="b:HeaderDisplayAttribute"
        )
        _add_display_attribute(
            surface_properties,
            "Name",
            surface_title,
            attr_type="b:StringDisplayAttribute",
        )
        _add_child(surface_node, "TypeId", "DRAWINGSURFACE", {"xmlns": ABSTRACT_NS})

        borders = ET.SubElement(surface_node, "Borders", {"xmlns:a": ARRAYS_NS})
        for element in [
            item
            for item in payload.get("Elements", [])
            if item.get("surface_id") == surface.get("id")
        ]:
            kind = str(element.get("kind", "process"))
            if kind == "external_interactor":
                stencil_type = "StencilRectangle"
            elif kind == "process":
                stencil_type = "StencilEllipse"
            elif kind == "data_store":
                stencil_type = "StencilParallelLines"
            else:
                stencil_type = "BorderBoundary"
            container = ET.SubElement(
                borders, "a:KeyValueOfguidanyType", {"xmlns:a": ARRAYS_NS}
            )
            _add_child(
                container,
                "a:Key",
                str(
                    element.get(
                        "guid", _make_guid(f"{surface['id']}:{element.get('id', '')}")
                    )
                ),
                {"xmlns:a": ARRAYS_NS},
            )
            container_value = ET.SubElement(
                container,
                "a:Value",
                {
                    "xmlns:a": ARRAYS_NS,
                    "z:Id": z_id_allocator.next_id(),
                    "i:type": stencil_type,
                },
            )
            container_value.attrib["xmlns:z"] = SER_NS
            _add_child(
                container_value,
                "GenericTypeId",
                str(element.get("type_id", "GE.P")),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "Guid",
                str(
                    element.get(
                        "guid", _make_guid(f"{surface['id']}:{element.get('id', '')}")
                    )
                ),
                {"xmlns": ABSTRACT_NS},
            )
            properties = _add_child(
                container_value, "Properties", None, {"xmlns": ABSTRACT_NS}
            )
            _add_display_attribute(
                properties,
                "Name",
                str(element.get("name", "")),
                attr_type="b:StringDisplayAttribute",
            )
            _add_display_attribute(
                properties, "Diagram", None, attr_type="b:HeaderDisplayAttribute"
            )
            _add_child(
                container_value,
                "TypeId",
                str(element.get("type_id", "GE.P")),
                {"xmlns": ABSTRACT_NS},
            )
            position = element.get("position", {})
            _add_child(
                container_value,
                "Height",
                _serialize_integral_value(position.get("height", 100)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "Left",
                _serialize_integral_value(position.get("left", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "StrokeDashArray",
                None,
                {"xmlns": ABSTRACT_NS, "i:nil": "true"},
            )
            _add_child(
                container_value,
                "StrokeThickness",
                _serialize_integral_value(0),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "Top",
                _serialize_integral_value(position.get("top", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "Width",
                _serialize_integral_value(position.get("width", 100)),
                {"xmlns": ABSTRACT_NS},
            )

        _add_child(surface_node, "Header", surface_title)
        lines = ET.SubElement(surface_node, "Lines", {"xmlns:a": ARRAYS_NS})
        for flow in [
            item
            for item in payload.get("Flows", [])
            if item.get("surface_id") == surface.get("id")
        ]:
            container = ET.SubElement(
                lines, "a:KeyValueOfguidanyType", {"xmlns:a": ARRAYS_NS}
            )
            _add_child(
                container,
                "a:Key",
                str(
                    flow.get(
                        "guid", _make_guid(f"{surface['id']}:{flow.get('id', '')}")
                    )
                ),
                {"xmlns:a": ARRAYS_NS},
            )
            container_value = ET.SubElement(
                container,
                "a:Value",
                {
                    "xmlns:a": ARRAYS_NS,
                    "z:Id": z_id_allocator.next_id(),
                    "i:type": "Connector",
                },
            )
            container_value.attrib["xmlns:z"] = SER_NS
            _add_child(
                container_value, "GenericTypeId", "GE.DF", {"xmlns": ABSTRACT_NS}
            )
            _add_child(
                container_value,
                "Guid",
                str(
                    flow.get(
                        "guid", _make_guid(f"{surface['id']}:{flow.get('id', '')}")
                    )
                ),
                {"xmlns": ABSTRACT_NS},
            )
            properties = _add_child(
                container_value, "Properties", None, {"xmlns": ABSTRACT_NS}
            )
            _add_display_attribute(
                properties,
                "Name",
                str(flow.get("display_label") or flow.get("id", "")),
                attr_type="b:StringDisplayAttribute",
            )
            _add_display_attribute(
                properties,
                "SemanticId",
                str(flow.get("id", "")),
                attr_type="b:StringDisplayAttribute",
            )
            _add_display_attribute(
                properties, "Diagram", None, attr_type="b:HeaderDisplayAttribute"
            )
            _add_child(container_value, "TypeId", "GE.DF", {"xmlns": ABSTRACT_NS})
            position = flow.get("position", {})
            _add_child(
                container_value,
                "HandleX",
                _serialize_integral_value(position.get("handle_x", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "HandleY",
                _serialize_integral_value(position.get("handle_y", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(container_value, "PortSource", "None", {"xmlns": ABSTRACT_NS})
            _add_child(container_value, "PortTarget", "None", {"xmlns": ABSTRACT_NS})
            _add_child(
                container_value,
                "SourceGuid",
                str(flow.get("source_guid") or "00000000-0000-0000-0000-000000000000"),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "SourceX",
                _serialize_integral_value(position.get("source_x", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "SourceY",
                _serialize_integral_value(position.get("source_y", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "TargetGuid",
                str(flow.get("target_guid") or "00000000-0000-0000-0000-000000000000"),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "TargetX",
                _serialize_integral_value(position.get("target_x", 0)),
                {"xmlns": ABSTRACT_NS},
            )
            _add_child(
                container_value,
                "TargetY",
                _serialize_integral_value(position.get("target_y", 0)),
                {"xmlns": ABSTRACT_NS},
            )

        _add_child(surface_node, "Zoom", _serialize_integral_value(1))

    meta_information = ET.SubElement(root, "MetaInformation")
    _add_child(meta_information, "Assumptions")
    _add_child(meta_information, "Contributors")
    _add_child(meta_information, "ExternalDependencies")
    high_level_description = _add_child(meta_information, "HighLevelSystemDescription")
    high_level_description.text = DISCLAIMER_TEXT
    _add_child(meta_information, "Owner")
    _add_child(meta_information, "Reviewer")
    _add_child(meta_information, "ThreatModelName")

    ET.SubElement(root, "Notes")
    _serialize_threat_instances(root, payload)
    _add_child(
        root,
        "ThreatGenerationEnabled",
        "true" if payload.get("ThreatGenerationEnabled") else "false",
    )
    _add_child(root, "Validations", None, {"xmlns:a": KNOWLEDGE_NS})
    _add_child(root, "Version", "4.3")
    ET.SubElement(root, "KnowledgeBasePlaceholder")
    profile = ET.SubElement(root, "Profile")
    ET.SubElement(profile, "PromptedKb", {"xmlns": ""})

    xml_text = ET.tostring(root, encoding="unicode")
    knowledge_base_text = _extend_knowledge_base_with_spec_threats(
        knowledge_base_text, payload
    )
    knowledge_base_text = _renumber_kb_root_zid(
        knowledge_base_text, z_id_allocator.current
    )
    xml_text = _inject_knowledge_base(xml_text, knowledge_base_text, payload)
    if not xml_text.startswith("<?xml"):
        xml_text = '<?xml version="1.0" encoding="utf-8"?>\n' + xml_text
    return xml_text


def _inject_knowledge_base(
    xml_text: str,
    knowledge_base_text: str,
    payload: dict[str, Any],
) -> str:
    """Replace the KnowledgeBase placeholder, failing closed when it is absent.

    The placeholder is emitted as an empty element and substituted by literal
    text because the KnowledgeBase is pre-rendered XML. An unmatched replace
    would otherwise yield a model with no KnowledgeBase and a success exit code.
    """
    if KNOWLEDGE_BASE_PLACEHOLDER not in xml_text:
        raise GenerationError(
            f"KnowledgeBase placeholder {KNOWLEDGE_BASE_PLACEHOLDER} is absent "
            "from the serialized model; refusing to emit a model without a "
            "KnowledgeBase",
            exit_code=EXIT_ERROR,
        )
    if not knowledge_base_text.strip():
        raise GenerationError(
            "KnowledgeBase content is empty; refusing to emit a model without a "
            "KnowledgeBase",
            exit_code=EXIT_ERROR,
        )
    return xml_text.replace(KNOWLEDGE_BASE_PLACEHOLDER, knowledge_base_text, 1)


def parse_hardened_xml(path: Path) -> dict[str, Any]:
    """Parse a TM7 file using a safe XML parser."""
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise GenerationError(
            f"Unable to read TM7 input: {exc}", exit_code=EXIT_ERROR
        ) from exc

    try:
        root = parse_hardened_xml_bytes(data)
    except UnsafeXmlError as exc:
        raise GenerationError(
            f"Unable to parse TM7 input: {exc}", exit_code=EXIT_ERROR
        ) from exc

    parsed_model: dict[str, Any] = {
        "elements": [],
        "flows": [],
        "threats": [],
        "notes": [],
    }
    for surface_node in root.findall("{*}DrawingSurfaceList/{*}DrawingSurfaceModel"):
        surface_id = _find_child_text(surface_node, "Header") or _find_child_text(
            surface_node, "Guid"
        )
        borders = surface_node.find("{*}Borders")
        if borders is not None:
            for item in borders.findall("{*}KeyValueOfguidanyType"):
                value = item.find("{*}Value")
                if value is None:
                    continue
                element_node = value
                element_guid = _find_child_text(element_node, "Guid")
                parsed_model["elements"].append(
                    {
                        "id": _resolve_element_identity(element_node, element_guid),
                        "kind": _find_child_text(element_node, "Kind")
                        or _find_instance_type(element_node),
                        "name": _find_child_text(element_node, "Name")
                        or _find_display_attribute_value(element_node, "Name"),
                        "position": {
                            "left": _parse_geometry_value(
                                _find_child_text(element_node, "Left")
                            ),
                            "top": _parse_geometry_value(
                                _find_child_text(element_node, "Top")
                            ),
                            "width": _parse_geometry_value(
                                _find_child_text(element_node, "Width")
                            ),
                            "height": _parse_geometry_value(
                                _find_child_text(element_node, "Height")
                            ),
                        },
                        "notes": _find_child_text(element_node, "Notes"),
                        "surface_id": surface_id,
                        "guid": element_guid,
                        "type_id": _find_child_text(element_node, "TypeId"),
                    }
                )

        lines = surface_node.find("{*}Lines")
        if lines is not None:
            for item in lines.findall("{*}KeyValueOfguidanyType"):
                value = item.find("{*}Value")
                if value is None:
                    continue
                connector_node = value
                parsed_model["flows"].append(
                    {
                        "id": _find_display_attribute_value(
                            connector_node,
                            "SemanticId",
                        )
                        or _find_child_text(connector_node, "Id")
                        or _find_display_attribute_value(connector_node, "Name"),
                        "position": {
                            "source_x": _parse_geometry_value(
                                _find_child_text(connector_node, "SourceX")
                            ),
                            "source_y": _parse_geometry_value(
                                _find_child_text(connector_node, "SourceY")
                            ),
                            "target_x": _parse_geometry_value(
                                _find_child_text(connector_node, "TargetX")
                            ),
                            "target_y": _parse_geometry_value(
                                _find_child_text(connector_node, "TargetY")
                            ),
                            "handle_x": _parse_geometry_value(
                                _find_child_text(connector_node, "HandleX")
                            ),
                            "handle_y": _parse_geometry_value(
                                _find_child_text(connector_node, "HandleY")
                            ),
                        },
                        "surface_id": surface_id,
                        "retention": _find_child_text(connector_node, "Retention"),
                        "source_guid": _find_child_text(connector_node, "SourceGuid"),
                        "target_guid": _find_child_text(connector_node, "TargetGuid"),
                    }
                )

    threat_instances = root.find("{*}ThreatInstances")
    if threat_instances is not None:
        for item in threat_instances.findall("{*}KeyValueOfstringThreatpc_P0_PhOB"):
            value = item.find("{*}Value")
            if value is None:
                continue

            properties_node = value.find("{*}Properties")
            property_map: dict[str, str] = {}
            if properties_node is not None:
                for property_item in properties_node.findall(
                    "{*}KeyValueOfstringstring"
                ):
                    key = _find_child_text(property_item, "Key")
                    property_value = _find_child_text(property_item, "Value")
                    if key is not None:
                        property_map[key] = property_value or ""

            parsed_model["threats"].append(
                {
                    "id": _find_child_text(value, "Id"),
                    "target_ref": _find_child_text(value, "TargetGuid"),
                    "title": property_map.get("Title")
                    or _find_child_text(value, "Title")
                    or "",
                    "description": (
                        property_map.get("UserThreatDescription")
                        or property_map.get("UserThreatShortDescription")
                        or _find_child_text(value, "UserThreatDescription")
                        or _find_child_text(value, "UserThreatShortDescription")
                        or ""
                    ),
                    "category": property_map.get("UserThreatCategory")
                    or _find_child_text(value, "TypeId")
                    or "",
                    "state": _find_child_text(value, "State") or "Open",
                    "notes": property_map.get("PossibleMitigations", ""),
                    "citations": {},
                    "type_id": _find_child_text(value, "TypeId"),
                }
            )

    notes_node = root.find("{*}Notes")
    if notes_node is not None:
        parsed_model["notes"] = [
            child.text or "" for child in notes_node.findall("{*}Note") if child.text
        ]

    return parsed_model


def _find_child_text(parent: ET.Element, child_name: str) -> str | None:
    """Return the text of the first child whose local name matches exactly.

    Matching is exact rather than by suffix because TM7 element members include
    overlapping names such as ``Id``, ``TypeId``, and ``GenericTypeId``. Suffix
    matching resolves the earliest-serialized overlapping member instead of the
    requested one.
    """
    for child in parent:
        if _local_name(child.tag) == child_name:
            return child.text
    return None


def _find_instance_type(element: ET.Element) -> str | None:
    """Return the serializer instance type that carries an authored element kind."""
    for key, value in element.attrib.items():
        if _local_name(key) == "type":
            return value
    return None


def _resolve_element_identity(element: ET.Element, guid: str | None) -> str | None:
    """Return a stable merge identity for a parsed element.

    Generated models carry an explicit ``Id`` member. Authored models omit it, so
    the element GUID becomes the stable identity; without this fallback every
    authored element collapses onto a single merge key.
    """
    explicit_id = _find_child_text(element, "Id")
    if explicit_id and explicit_id.strip():
        return explicit_id
    semantic_id = _find_display_attribute_value(element, "SemanticId")
    if semantic_id and semantic_id.strip():
        return semantic_id
    return guid


def _find_display_attribute_value(
    element: ET.Element,
    display_name: str,
) -> str | None:
    """Return a named StringDisplayAttribute value from an element."""
    for attribute in element.findall("{*}Properties/{*}anyType"):
        name = attribute.findtext("{*}DisplayName")
        if name != display_name:
            continue
        return attribute.findtext("{*}Value")
    return None


def write_tm7(output_path: Path, xml_text: str) -> None:
    """Write the rendered XML through a sibling temporary file.

    A direct write truncates the destination before the new content lands, so an
    interrupted write would destroy the existing model and could leave a partial
    file that still parses as XML. Writing a sibling temporary file and replacing
    the destination keeps the prior artifact intact until the replacement is
    complete. The replacement also swaps a symlinked destination rather than
    writing through it to whatever the link targets.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(  # noqa: SIM115 - closed in the with below
        mode="w",
        encoding="utf-8",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
        delete=False,
    )
    temporary_path = Path(handle.name)
    try:
        with handle:
            handle.write(xml_text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, output_path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def generate_tm7_candidate(
    *,
    spec_path: Path,
    output_path: Path,
    template: str | None,
    mode: str | None,
    update_path: Path | None,
    overlay_path: Path | None,
    threat_generation_enabled: bool | None = None,
) -> Path:
    """Generate a TM7 candidate from the supplied spec and optional overlay.

    Args:
        spec_path: Threat model spec to read exactly once.
        output_path: Destination for the generated model.
        template: Template profile override, or None to use the spec value.
        mode: Generation mode override, or None to use the spec value.
        update_path: Existing model to merge into, when updating.
        overlay_path: Layout overlay to apply, when supplied.
        threat_generation_enabled: Explicit flag, or None to defer to the spec.

    Returns:
        The written model path.
    """
    if overlay_path is not None and update_path is not None:
        raise GenerationError(
            "overlay input cannot be combined with --update",
            exit_code=EXIT_ERROR,
        )

    spec = load_spec(spec_path)
    # The flag is resolved from this read alone. A second load_spec in the
    # caller allowed the flag and the model to come from different revisions of
    # the same file.
    resolved_threat_generation = (
        threat_generation_enabled
        if threat_generation_enabled is not None
        else _coerce_bool(spec.get("threat_generation_enabled"), default=False)
    )
    emit_warnings(spec)
    template_dir = Path(__file__).resolve().parent.parent
    profile = resolve_profile(spec, template, template_dir)
    profile["name"] = template or spec.get("template_profile") or "sdl_core_generic"
    default_mode = (
        "pre-populated-comprehensive"
        if spec.get("threats")
        else "diagram-only-defer-to-tmt"
    )
    resolved_mode = mode or str(spec.get("mode") or default_mode)

    existing_model = None
    if update_path is not None:
        existing_model = parse_hardened_xml(update_path)
        existing_model["parsed"] = existing_model

    baseline_model = build_model_from_spec(spec, profile, resolved_mode)
    layout_overlay = _resolve_layout_overlay(
        spec=spec,
        profile=profile,
        spec_path=spec_path,
        model=baseline_model,
        overlay_path=overlay_path,
    )
    payload = build_tm7_payload(
        spec,
        profile,
        resolved_mode,
        existing_model=existing_model,
        threat_generation_enabled=resolved_threat_generation,
        layout_overlay=layout_overlay,
    )
    xml_text = render_tm7_xml(
        payload, template_dir, str(profile.get("name") or "sdl_core_generic")
    )
    write_tm7(output_path, xml_text)
    return output_path


def configure_logging() -> None:
    """Route module diagnostics to stderr with a concise prefix.

    Warnings carry a ``Warning: `` prefix on stderr so operator-visible output
    stays distinct from generated content on stdout.
    """
    if logging.getLogger().handlers:
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
    logging.getLogger().addHandler(handler)
    logging.getLogger().setLevel(logging.INFO)


def main() -> int:
    """CLI entry point."""
    configure_logging()
    parser = create_parser()
    args = parser.parse_args()

    try:
        output_path = generate_tm7_candidate(
            spec_path=args.spec,
            output_path=args.output,
            template=args.template,
            mode=args.mode,
            update_path=args.update,
            overlay_path=args.overlay_input,
            threat_generation_enabled=True if args.threat_generation_enabled else None,
        )
        print(f"Generated {output_path}")
        return EXIT_SUCCESS
    except GenerationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.exit_code
    except ThreatContractError as exc:
        # A contract violation is an expected domain failure for invalid input,
        # so it reports the same concise message and exit code as any other
        # rejected spec instead of escaping as a traceback.
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return EXIT_INTERRUPTED
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
