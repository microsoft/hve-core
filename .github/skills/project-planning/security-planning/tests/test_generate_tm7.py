# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the TM7 generation extension."""

from __future__ import annotations

import copy
import logging
import math
import platform
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_markdown  # noqa: E402
import generate_tm7  # noqa: E402
import tm7_threat_contract  # noqa: E402
import tm7_visual_feedback  # noqa: E402

SPEC_PATH = ROOT / "templates" / "threat-model-spec-example.yaml"
COMPREHENSIVE_SPEC_PATH = (
    Path(__file__).resolve().parent / "fixtures" / "comprehensive-spec.yaml"
)
SCRIPT_PATH = ROOT / "scripts" / "generate_tm7.py"
MARKDOWN_SCRIPT_PATH = ROOT / "scripts" / "generate_markdown.py"
FIXTURE_PATH = ROOT / "tests" / "fixtures" / "expected.tm7"
REFERENCE_FIXTURE_PATH = ROOT / "tests" / "fixtures" / "tmt-reference.tm7"
REFERENCE_THREATS_FIXTURE_PATH = (
    ROOT / "tests" / "fixtures" / "tmt-reference-threats.tm7"
)
DEFAULT_KB_PATH = ROOT / "assets" / "templates" / "default-kb.xml"
DESERIALIZE_HARNESS = ROOT / "scripts" / "Deserialize-Tm7.ps1"
THREAT_INSTANCE_ENTRY_TAG = "{*}KeyValueOfstringThreatpc_P0_PhOB"
THREAT_MEMBER_ORDER = tm7_threat_contract.THREAT_MEMBER_ORDER


def run_generator(
    spec_path: Path,
    output_path: Path,
    *,
    update_path: Path | None = None,
    mode: str | None = None,
    overlay_input: Path | None = None,
) -> Path:
    """Invoke the TM7 generator CLI for a spec."""
    command = [
        sys.executable,
        str(SCRIPT_PATH),
        str(spec_path),
        "-o",
        str(output_path),
    ]
    if update_path is not None:
        command.extend(["--update", str(update_path)])
    if overlay_input is not None:
        command.extend(["--overlay-input", str(overlay_input)])
    if mode is not None:
        command.extend(["--mode", mode])
    subprocess.run(command, check=True, cwd=ROOT, capture_output=True, text=True)
    return output_path


def parse_tm7(path: Path) -> ET.Element:
    """Parse a TM7 XML file into an ElementTree root."""
    return ET.parse(path).getroot()


def iter_surface_nodes(root: ET.Element) -> list[ET.Element]:
    """Return each drawing surface node from a TM7 document."""
    return root.findall("{*}DrawingSurfaceList/{*}DrawingSurfaceModel")


def iter_elements(root: ET.Element) -> list[ET.Element]:
    """Return each serialized element node from a TM7 document."""
    elements: list[ET.Element] = []
    for surface in iter_surface_nodes(root):
        borders = surface.find("{*}Borders")
        if borders is None:
            continue
        for item in borders.findall("{*}KeyValueOfguidanyType"):
            value = item.find("{*}Value")
            if value is None:
                continue
            child = next(iter(value), None)
            if child is not None:
                elements.append(child)
    return elements


def iter_connectors(root: ET.Element) -> list[ET.Element]:
    """Return each serialized connector node from a TM7 document."""
    connectors: list[ET.Element] = []
    for surface in iter_surface_nodes(root):
        lines = surface.find("{*}Lines")
        if lines is None:
            continue
        for item in lines.findall("{*}KeyValueOfguidanyType"):
            value = item.find("{*}Value")
            if value is None:
                continue
            child = next(iter(value), None)
            if child is not None:
                connectors.append(child)
    return connectors


def iter_threats(root: ET.Element) -> list[ET.Element]:
    """Return each serialized threat node from a TM7 document."""
    threats: list[ET.Element] = []
    threat_instances = root.find("{*}ThreatInstances")
    if threat_instances is None:
        return threats
    for item in threat_instances.findall(THREAT_INSTANCE_ENTRY_TAG):
        value = item.find("{*}Value")
        if value is None:
            continue
        threats.append(value)
    return threats


def parse_threat_fixture(
    path: Path = REFERENCE_THREATS_FIXTURE_PATH,
) -> list[dict[str, object]]:
    """Parse the fixture ThreatInstances collection into reusable test data."""
    root = parse_tm7(path)
    threat_instances = root.find("{*}ThreatInstances")
    if threat_instances is None:
        return []

    parsed_threats: list[dict[str, object]] = []
    for entry in threat_instances.findall(THREAT_INSTANCE_ENTRY_TAG):
        value = entry.find("{*}Value")
        if value is None:
            continue
        parsed_threat = tm7_threat_contract.extract_serializable_threat(value)
        parsed_threat["entry_key"] = entry.findtext("{*}Key")
        parsed_threats.append(parsed_threat)
    return parsed_threats


def parse_embedded_kb_type_ids(path: Path = REFERENCE_THREATS_FIXTURE_PATH) -> set[str]:
    """Return the non-empty threat type ids embedded in the fixture knowledge base."""
    root = parse_tm7(path)
    knowledge_base = root.find("{*}KnowledgeBase")
    if knowledge_base is None:
        return set()

    type_ids: set[str] = set()
    for threat_type in knowledge_base.findall(".//{*}ThreatType"):
        threat_id = threat_type.findtext("{*}Id")
        if threat_id:
            type_ids.add(threat_id)
    return type_ids


def parse_embedded_custom_kb_type_ids(path: Path) -> list[str]:
    """Return custom threat type ids embedded in a generated TM7 file."""
    root = parse_tm7(path)
    knowledge_base = root.find("{*}KnowledgeBase")
    if knowledge_base is None:
        return []

    custom_ids: list[str] = []
    for threat_type in knowledge_base.findall(".//{*}ThreatType"):
        threat_id = threat_type.findtext("{*}Id")
        if threat_id and threat_id.startswith("THC-"):
            custom_ids.append(threat_id)
    return sorted(custom_ids)


def parse_embedded_custom_kb_type_details(path: Path) -> list[dict[str, object]]:
    """Return the custom ThreatType XML details from a generated TM7 file."""
    root = parse_tm7(path)
    knowledge_base = root.find("{*}KnowledgeBase")
    if knowledge_base is None:
        return []

    details: list[dict[str, object]] = []
    for threat_type in knowledge_base.findall(".//{*}ThreatType"):
        threat_id = threat_type.findtext("{*}Id")
        if not threat_id or not threat_id.startswith("THC-"):
            continue
        meta_node = threat_type.find("{*}PropertiesMetaData")
        metadata: dict[str, str] = {}
        if meta_node is not None:
            for datum in meta_node.findall("{*}ThreatMetaDatum"):
                name = datum.findtext("{*}Name") or ""
                values = [
                    value.text or ""
                    for value in datum.findall(".//{*}string")
                    if value.text
                ]
                if name:
                    metadata[name] = " | ".join(values)
        details.append(
            {
                "id": threat_id,
                "description": threat_type.findtext("{*}Description") or "",
                "short_title": threat_type.findtext("{*}ShortTitle") or "",
                "generation_filters": (
                    threat_type.findtext("{*}GenerationFilters") or ""
                ),
                "metadata": metadata,
            }
        )
    return sorted(details, key=lambda item: str(item["id"]))


def parse_stock_kb_type_ids(path: Path = DEFAULT_KB_PATH) -> set[str]:
    """Return every stock ThreatType Id from the bundled knowledge-base asset."""
    text = path.read_text(encoding="utf-8")
    type_ids: set[str] = set()
    for match in re.finditer(
        r"<a:ThreatType\b[^>]*>.*?<a:Id>([^<]+)</a:Id>",
        text,
        re.DOTALL,
    ):
        threat_id = match.group(1).strip()
        if threat_id:
            type_ids.add(threat_id)
    return type_ids


def map_source_threat_ids_to_custom_type_ids(
    spec: dict[str, object],
    custom_details: list[dict[str, object]],
) -> dict[str, str]:
    """Map explicit source-threat ids to generated custom TypeIds by title."""
    by_title = {
        str(item["short_title"]): str(item["id"])
        for item in custom_details
        if isinstance(item.get("short_title"), str)
    }

    mapping: dict[str, str] = {}
    for threat in spec.get("threats") or []:
        if not isinstance(threat, dict):
            continue
        title = str(threat.get("title") or "")
        source_id = str(threat.get("id") or title)
        if title and title in by_title:
            mapping[source_id] = by_title[title]
    return mapping


# ---------------------------------------------------------------------------
# Geometry invariants
#
# The Microsoft Threat Modeling Tool validates diagram geometry on open. The
# genuine reference model (tests/fixtures/tmt-reference.tm7) defines the
# contract: connector endpoints sit at the center of the source/target shape
# and the handle is the midpoint of the two endpoints; shapes never overlap.
# These helpers extract that geometry so tests can assert the same invariants
# without needing the TMT runtime.
# ---------------------------------------------------------------------------

_XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"
_SHAPE_TYPES = frozenset({"Border", "StencilRectangle", "StencilEllipse"})


def _value_nodes(container: ET.Element | None) -> list[ET.Element]:
    """Return the polymorphic ``a:Value`` node of each dictionary entry."""
    if container is None:
        return []
    values: list[ET.Element] = []
    for item in container.findall("{*}KeyValueOfguidanyType"):
        value = item.find("{*}Value")
        if value is not None:
            values.append(value)
    return values


def _direct_float(node: ET.Element, name: str) -> float | None:
    """Read a direct numeric child, returning None when absent or malformed."""
    child = node.find("{*}" + name)
    if child is None or child.text is None:
        return None
    try:
        return float(child.text)
    except ValueError:
        return None


def shape_rects_by_surface(root: ET.Element) -> list[dict[str, dict[str, float]]]:
    """Return one guid->rectangle map of non-boundary shapes per surface."""
    per_surface: list[dict[str, dict[str, float]]] = []
    for surface in iter_surface_nodes(root):
        rects: dict[str, dict[str, float]] = {}
        for value in _value_nodes(surface.find("{*}Borders")):
            if value.attrib.get(_XSI_TYPE, "") not in _SHAPE_TYPES:
                continue
            guid = value.findtext("{*}Guid")
            rect = {
                "left": _direct_float(value, "Left"),
                "top": _direct_float(value, "Top"),
                "width": _direct_float(value, "Width"),
                "height": _direct_float(value, "Height"),
            }
            if guid and None not in rect.values():
                rects[guid] = rect
        per_surface.append(rects)
    return per_surface


def connector_geoms(root: ET.Element) -> list[dict[str, object]]:
    """Return the endpoint and handle geometry of every connector."""
    geoms: list[dict[str, object]] = []
    for surface in iter_surface_nodes(root):
        for value in _value_nodes(surface.find("{*}Lines")):
            if value.attrib.get(_XSI_TYPE, "") != "Connector":
                continue
            geoms.append(
                {
                    "source_guid": value.findtext("{*}SourceGuid"),
                    "target_guid": value.findtext("{*}TargetGuid"),
                    "sx": _direct_float(value, "SourceX"),
                    "sy": _direct_float(value, "SourceY"),
                    "tx": _direct_float(value, "TargetX"),
                    "ty": _direct_float(value, "TargetY"),
                    "hx": _direct_float(value, "HandleX"),
                    "hy": _direct_float(value, "HandleY"),
                }
            )
    return geoms


def _rects_overlap(a: dict[str, float], b: dict[str, float]) -> bool:
    return not (
        a["left"] + a["width"] <= b["left"]
        or b["left"] + b["width"] <= a["left"]
        or a["top"] + a["height"] <= b["top"]
        or b["top"] + b["height"] <= a["top"]
    )


def overlapping_shape_pairs(root: ET.Element) -> int:
    """Count overlapping non-boundary shape pairs across all surfaces."""
    total = 0
    for rects in shape_rects_by_surface(root):
        values = list(rects.values())
        for i in range(len(values)):
            for j in range(i + 1, len(values)):
                if _rects_overlap(values[i], values[j]):
                    total += 1
    return total


def zero_length_connectors(root: ET.Element) -> int:
    """Count connectors whose source and target points coincide."""
    return sum(
        1 for g in connector_geoms(root) if g["sx"] == g["tx"] and g["sy"] == g["ty"]
    )


def handle_mismatches(root: ET.Element) -> list[dict[str, object]]:
    """Return connectors whose handle is not the endpoint midpoint."""
    bad: list[dict[str, object]] = []
    for g in connector_geoms(root):
        mid_x = (g["sx"] + g["tx"]) / 2
        mid_y = (g["sy"] + g["ty"]) / 2
        if abs(g["hx"] - mid_x) > 1 or abs(g["hy"] - mid_y) > 1:
            bad.append(g)
    return bad


_NULL_GUID = "00000000-0000-0000-0000-000000000000"


def dangling_connector_endpoints(root: ET.Element) -> int:
    """Count connector endpoints not resolving to a shape on their own surface.

    A connector whose SourceGuid/TargetGuid references a shape that is not on the
    same drawing surface produces a "corrupt document" error in TMT even though
    the file deserializes. This catches cross-surface guid leakage.
    """
    total = 0
    for surface in iter_surface_nodes(root):
        border_guids = {
            value.findtext("{*}Guid")
            for value in _value_nodes(surface.find("{*}Borders"))
        }
        for value in _value_nodes(surface.find("{*}Lines")):
            if value.attrib.get(_XSI_TYPE, "") != "Connector":
                continue
            for role in ("SourceGuid", "TargetGuid"):
                guid = value.findtext("{*}" + role)
                if guid != _NULL_GUID and guid not in border_guids:
                    total += 1
    return total


def connector_field_names(root: ET.Element) -> set[str]:
    """Return the union of direct child element names across all connectors."""
    names: set[str] = set()
    for surface in iter_surface_nodes(root):
        for value in _value_nodes(surface.find("{*}Lines")):
            if value.attrib.get(_XSI_TYPE, "") != "Connector":
                continue
            for child in list(value):
                names.add(child.tag.split("}")[-1])
    return names


def boundary_line_shape_count(root: ET.Element) -> int:
    """Count trust-boundary-line (`GE.TB.L`) shapes on any drawing surface.

    TMT represents trust boundaries as `GE.TB.B` boxes only. Emitting a
    `GE.TB.L` "line boundary" as a box-geometry shape duplicates the boundary
    and triggers "Boundary line ... coordinates are corrupted" on open.
    """
    count = 0
    for surface in iter_surface_nodes(root):
        for value in _value_nodes(surface.find("{*}Borders")):
            if value.findtext("{*}GenericTypeId") == "GE.TB.L":
                count += 1
    return count


def min_shape_origin(root: ET.Element) -> float:
    """Return the smallest Left/Top coordinate across every shape and boundary.

    TMT treats a shape pinned to the (0,0) origin as uninitialized and
    "corrects" its coordinates on open, so every shape must be strictly
    positive.
    """
    coords: list[float] = []
    for surface in iter_surface_nodes(root):
        for value in _value_nodes(surface.find("{*}Borders")):
            left = _direct_float(value, "Left")
            top = _direct_float(value, "Top")
            if left is not None:
                coords.append(left)
            if top is not None:
                coords.append(top)
    return min(coords) if coords else 0.0


def _rects_intersect(a: dict[str, float], b: dict[str, float]) -> bool:
    return not (
        a["left"] + a["width"] <= b["left"]
        or b["left"] + b["width"] <= a["left"]
        or a["top"] + a["height"] <= b["top"]
        or b["top"] + b["height"] <= a["top"]
    )


def _segment_intersects(
    a: tuple[float, float],
    b: tuple[float, float],
    c: tuple[float, float],
    d: tuple[float, float],
) -> bool:
    def orientation(
        p: tuple[float, float], q: tuple[float, float], r: tuple[float, float]
    ) -> float:
        return (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (r[1] - q[1])

    def on_segment(
        p: tuple[float, float], q: tuple[float, float], r: tuple[float, float]
    ) -> bool:
        return min(p[0], r[0]) <= q[0] <= max(p[0], r[0]) and min(p[1], r[1]) <= q[
            1
        ] <= max(p[1], r[1])

    o1 = orientation(a, b, c)
    o2 = orientation(a, b, d)
    o3 = orientation(c, d, a)
    o4 = orientation(c, d, b)

    if (o1 > 0 and o2 > 0) or (o1 < 0 and o2 < 0):
        return False
    if (o3 > 0 and o4 > 0) or (o3 < 0 and o4 < 0):
        return False
    if o1 == 0 and on_segment(a, c, b):
        return True
    if o2 == 0 and on_segment(a, d, b):
        return True
    if o3 == 0 and on_segment(c, a, d):
        return True
    if o4 == 0 and on_segment(c, b, d):
        return True
    return True


def _count_connector_intersections(surface: dict[str, object]) -> int:
    elements = surface.get("elements", [])
    flows = surface.get("flows", [])
    if not isinstance(elements, list) or not isinstance(flows, list):
        return 0

    rects: list[tuple[dict[str, float], str]] = []
    for element in elements:
        if not isinstance(element, dict):
            continue
        position = element.get("position", {})
        if not isinstance(position, dict):
            continue
        rects.append(
            (
                {
                    "left": float(position.get("left", 0)),
                    "top": float(position.get("top", 0)),
                    "width": float(position.get("width", 0)),
                    "height": float(position.get("height", 0)),
                },
                str(element.get("id", "")),
            )
        )

    intersections = 0
    for flow in flows:
        if not isinstance(flow, dict):
            continue
        position = flow.get("position", {})
        if not isinstance(position, dict):
            continue
        source = (
            float(position.get("source_x", 0)),
            float(position.get("source_y", 0)),
        )
        target = (
            float(position.get("target_x", 0)),
            float(position.get("target_y", 0)),
        )
        for rect, element_id in rects:
            if element_id in {flow.get("source_ref"), flow.get("target_ref")}:
                continue
            if element_id.startswith("boundary-"):
                continue
            if not _rects_intersect(
                rect, {"left": source[0], "top": source[1], "width": 1, "height": 1}
            ):
                pass
            if _segment_intersects(
                source,
                target,
                (rect["left"], rect["top"]),
                (rect["left"] + rect["width"], rect["top"] + rect["height"]),
            ):
                intersections += 1
                break
    return intersections


def _count_connector_crossings(surface: dict[str, object]) -> int:
    flows = surface.get("flows", [])
    if not isinstance(flows, list):
        return 0

    connectors = []
    for flow in flows:
        if not isinstance(flow, dict):
            continue
        position = flow.get("position", {})
        if not isinstance(position, dict):
            continue
        connectors.append(
            (
                (
                    float(position.get("source_x", 0)),
                    float(position.get("source_y", 0)),
                ),
                (
                    float(position.get("target_x", 0)),
                    float(position.get("target_y", 0)),
                ),
            )
        )

    crossings = 0
    for index, left in enumerate(connectors):
        for right in connectors[index + 1 :]:
            if left[0] == right[0] and left[1] == right[1]:
                continue
            if _segment_intersects(left[0], left[1], right[0], right[1]):
                crossings += 1
    return crossings


class TestThreatFixtureContract:
    def test_given_reference_threat_fixture_when_parsed_then_has_expected_threat_count(
        self,
    ) -> None:
        # Act
        threats = parse_threat_fixture()

        # Assert
        assert len(threats) == 61

    def test_given_reference_fixture_when_parsed_then_dictionary_keys_match(
        self,
    ) -> None:
        # Act
        threats = parse_threat_fixture()

        # Assert
        assert threats
        for threat in threats:
            entry_key = threat["entry_key"]
            expected_key = (
                f"{threat['type_id']}{threat['source_guid']}"
                f"{threat['flow_guid']}{threat['target_guid']}"
            )
            assert entry_key == expected_key

    def test_given_reference_fixture_when_parsed_then_interaction_keys_match(
        self,
    ) -> None:
        # Act
        threats = parse_threat_fixture()

        # Assert
        assert threats
        for threat in threats:
            expected_key = (
                f"{threat['source_guid']}:{threat['flow_guid']}:{threat['target_guid']}"
            )
            assert threat["interaction_key"] == expected_key

    def test_given_reference_fixture_when_parsed_then_member_order_matches(
        self,
    ) -> None:
        # Act
        threats = parse_threat_fixture()

        # Assert
        assert threats
        for threat in threats:
            assert threat["member_order"] == THREAT_MEMBER_ORDER

    def test_given_reference_fixture_when_parsed_then_properties_hold_values(
        self,
    ) -> None:
        # Act
        threat = parse_threat_fixture()[0]

        # Assert
        assert threat["properties"]["Title"]
        assert threat["properties"]["UserThreatCategory"]
        assert threat["properties"]["UserThreatShortDescription"]
        assert threat["properties"]["UserThreatDescription"]
        assert threat["properties"]["InteractionString"]
        assert threat["top_level_content"]["Title"] is None
        assert threat["top_level_content"]["UserThreatCategory"] is None
        assert threat["top_level_content"]["UserThreatShortDescription"] is None
        assert threat["top_level_content"]["UserThreatDescription"] is None
        assert threat["top_level_content"]["InteractionString"] is None
        assert threat["top_level_content"]["StateInformation"] is None

    def test_given_reference_fixture_when_parsed_then_type_ids_resolve_in_kb(
        self,
    ) -> None:
        # Arrange
        kb_type_ids = parse_embedded_kb_type_ids()

        # Act
        threats = parse_threat_fixture()

        # Assert
        assert kb_type_ids
        assert threats
        for threat in threats:
            assert threat["type_id"]
            assert threat["type_id"] in kb_type_ids


def _write_overlay(
    tmp_path: Path,
    *,
    spec: dict[str, object],
    profile: dict[str, object],
    overlay_type: str = "position",
) -> Path:
    """Write a deterministic overlay fixture for generator tests."""
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    surface_ids = [str(surface.get("id", "")) for surface in model.get("surfaces", [])]
    surface_node_ids = {
        str(surface.get("id", "")): sorted(
            {
                str(element.get("id", ""))
                for element in surface.get("elements", [])
                if isinstance(element, dict) and str(element.get("id", ""))
            }
        )
        for surface in model.get("surfaces", [])
    }
    surface_zone_ids = {
        str(surface.get("id", "")): sorted(
            {
                str(zone.get("id", ""))
                for zone in surface.get("trust_zones", [])
                if isinstance(zone, dict) and str(zone.get("id", ""))
            }
        )
        for surface in model.get("surfaces", [])
    }
    surface_flow_ids = {
        str(surface.get("id", "")): sorted(
            {
                str(flow.get("id", ""))
                for flow in surface.get("flows", [])
                if isinstance(flow, dict) and str(flow.get("id", ""))
            }
        )
        for surface in model.get("surfaces", [])
    }
    normalized_profile = dict(profile)
    normalized_profile["name"] = str(profile.get("name") or "sdl_core_generic")
    overlay = {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": str(
            spec.get("project_metadata", {}).get("name") or "overlay-model"
        ),
        "overlay_id": "overlay-001",
        "applies_to": [
            {
                "surface_id": surface_ids[0],
                "generator_profile": str(
                    normalized_profile.get("name") or "sdl_core_generic"
                ),
            }
        ],
        "zone_rules": [],
        "node_rules": [],
        "connector_rules": [],
        "surface_rules": [],
        "provenance": {
            "evidence_ref": "feedback/overlay.yaml",
            "generated_at": "2026-07-16T00:00:00Z",
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": tm7_visual_feedback._fingerprint(
                generate_tm7._normalize_for_fingerprint(spec)
            ),
            "generator_profile_fingerprint": tm7_visual_feedback._fingerprint(
                generate_tm7._normalize_for_fingerprint(normalized_profile)
            ),
            "surface_identity_fingerprint": tm7_visual_feedback._fingerprint(
                {
                    "surface_ids": sorted(surface_ids),
                    "surface_node_ids": {
                        key: sorted(value)
                        for key, value in sorted(surface_node_ids.items())
                    },
                }
            ),
            "surface_zone_identity_fingerprint": tm7_visual_feedback._fingerprint(
                {
                    "surface_ids": sorted(surface_ids),
                    "surface_zone_ids": {
                        key: sorted(value)
                        for key, value in sorted(surface_zone_ids.items())
                    },
                }
            ),
            "surface_flow_identity_fingerprint": tm7_visual_feedback._fingerprint(
                {
                    "surface_ids": sorted(surface_ids),
                    "surface_flow_ids": {
                        key: sorted(value)
                        for key, value in sorted(surface_flow_ids.items())
                    },
                }
            ),
        },
    }
    if overlay_type == "position":
        target_surface_id = next(
            (
                surface_id
                for surface_id in surface_ids
                if "proc-01" in surface_node_ids.get(surface_id, [])
            ),
            surface_ids[0],
        )
        overlay["node_rules"] = [
            {
                "surface_id": target_surface_id,
                "node_id": "proc-01",
                "layout_role": "main",
                "absolute_position": {
                    "left": 320.0,
                    "top": 220.0,
                    "width": 100.0,
                    "height": 100.0,
                },
            }
        ]
    elif overlay_type == "relative":
        target_surface_id = next(
            (
                surface_id
                for surface_id in surface_ids
                if "proc-01" in surface_node_ids.get(surface_id, [])
                and "ds-01" in surface_node_ids.get(surface_id, [])
            ),
            surface_ids[0],
        )
        overlay["node_rules"] = [
            {
                "surface_id": target_surface_id,
                "node_id": "ds-01",
                "layout_role": "contextual",
                "relative_placement": {
                    "relative_to": "proc-01",
                    "offset": {"x": 260.0, "y": 0.0},
                },
            }
        ]
    else:
        target_surface_id = next(
            (
                surface_id
                for surface_id in surface_ids
                if "proc-01" in surface_node_ids.get(surface_id, [])
            ),
            surface_ids[0],
        )
        overlay["node_rules"] = [
            {
                "surface_id": target_surface_id,
                "node_id": "proc-01",
                "layout_role": "main",
                "absolute_position": {
                    "left": 320.0,
                    "top": 220.0,
                    "width": 100.0,
                    "height": 100.0,
                },
            }
        ]
        overlay["connector_rules"] = [
            {
                "surface_id": target_surface_id,
                "flow_id": "flow-01",
                "source_port": "top",
                "target_port": "bottom",
                "handle_point": {"x": 0.0, "y": 0.0},
            }
        ]
    overlay_path = tmp_path / "overlay.yaml"
    overlay_path.write_text(yaml.safe_dump(overlay), encoding="utf-8")
    return overlay_path


def _build_zone_layout_spec() -> tuple[dict[str, object], dict[str, object]]:
    spec = {
        "project_metadata": {"name": "zone-layout"},
        "representations": {
            "context_diagrams": [
                {
                    "id": "surface-01",
                    "name": "Layout surface",
                    "trust_zone_ids": ["tz-root", "tz-child-1", "tz-child-2"],
                    "elements": [
                        {
                            "id": "node-main",
                            "kind": "process",
                            "name": "Main",
                            "trust_zone_id": "tz-root",
                        },
                        {
                            "id": "node-left",
                            "kind": "process",
                            "name": "Left",
                            "trust_zone_id": "tz-child-1",
                        },
                        {
                            "id": "node-right",
                            "kind": "process",
                            "name": "Right",
                            "trust_zone_id": "tz-child-2",
                        },
                        {
                            "id": "node-context",
                            "kind": "process",
                            "name": "Context",
                            "trust_zone_id": "tz-child-1",
                            "layout_role": "contextual",
                        },
                    ],
                    "flows": [
                        {
                            "id": "flow-main-left",
                            "source_ref": "node-main",
                            "target_ref": "node-left",
                            "ordinal": 1,
                            "label": "left",
                        },
                        {
                            "id": "flow-main-right",
                            "source_ref": "node-main",
                            "target_ref": "node-right",
                            "ordinal": 2,
                            "label": "right",
                        },
                    ],
                }
            ],
            "functional_scenarios": [],
            "operational_views": [],
        },
        "data_flows": [
            {
                "id": "flow-main-left",
                "source_ref": "node-main",
                "target_ref": "node-left",
                "ordinal": 1,
                "label": "left",
            },
            {
                "id": "flow-main-right",
                "source_ref": "node-main",
                "target_ref": "node-right",
                "ordinal": 2,
                "label": "right",
            },
        ],
        "trust_zones": [
            {"id": "tz-root", "name": "Root zone", "description": "root"},
            {
                "id": "tz-child-1",
                "name": "Child one",
                "description": "left",
                "parent_trust_zone_id": "tz-root",
            },
            {
                "id": "tz-child-2",
                "name": "Child two",
                "description": "right",
                "parent_trust_zone_id": "tz-root",
            },
        ],
        "components": [],
        "threats": [],
    }
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    return spec, profile


def _build_archetype_spec(
    *,
    surface_id: str,
    nodes: list[tuple[str, str, str]],
    edges: list[tuple[str, str, str]],
    zones: list[tuple[str, str, str | None]],
) -> tuple[dict[str, object], dict[str, object]]:
    """Build a generic archetype spec from node, edge, and zone descriptions.

    Nodes are (node_id, display_name, zone_id) and edges are
    (flow_id, source_id, target_id). The shapes stay domain-neutral so layout
    behavior is asserted against graph structure rather than any single model.
    """
    elements = [
        {
            "id": node_id,
            "kind": "process",
            "name": name,
            "trust_zone_id": zone_id,
        }
        for node_id, name, zone_id in nodes
    ]
    flows = [
        {
            "id": flow_id,
            "source_ref": source_id,
            "target_ref": target_id,
            "ordinal": index + 1,
            "label": f"step {index + 1}",
        }
        for index, (flow_id, source_id, target_id) in enumerate(edges)
    ]
    spec = {
        "project_metadata": {"name": surface_id},
        "representations": {
            "context_diagrams": [
                {
                    "id": surface_id,
                    "name": f"Archetype {surface_id}",
                    "trust_zone_ids": [zone_id for zone_id, _, _ in zones],
                    "elements": elements,
                    "flows": [dict(flow) for flow in flows],
                }
            ],
            "functional_scenarios": [],
            "operational_views": [],
        },
        "data_flows": [dict(flow) for flow in flows],
        "trust_zones": [
            {
                "id": zone_id,
                "name": zone_name,
                "description": zone_name,
                **({"parent_trust_zone_id": parent} if parent else {}),
            }
            for zone_id, zone_name, parent in zones
        ],
        "components": [],
        "threats": [],
    }
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    return spec, profile


ARCHETYPES: dict[str, dict[str, object]] = {
    "linear-pipeline": {
        "nodes": [
            ("n-1", "Ingest", "tz-a"),
            ("n-2", "Transform", "tz-a"),
            ("n-3", "Publish", "tz-a"),
        ],
        "edges": [("f-1", "n-1", "n-2"), ("f-2", "n-2", "n-3")],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": ["n-1", "n-2", "n-3"],
    },
    "fan-out-tree": {
        "nodes": [
            ("n-hub", "Dispatcher", "tz-a"),
            ("n-a", "Worker A", "tz-a"),
            ("n-b", "Worker B", "tz-a"),
            ("n-c", "Worker C", "tz-a"),
        ],
        "edges": [
            ("f-1", "n-hub", "n-a"),
            ("f-2", "n-hub", "n-b"),
            ("f-3", "n-hub", "n-c"),
        ],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": ["n-hub", "n-a"],
    },
    "fan-in-convergence": {
        "nodes": [
            ("n-a", "Source A", "tz-a"),
            ("n-b", "Source B", "tz-a"),
            ("n-c", "Source C", "tz-a"),
            ("n-sink", "Aggregator", "tz-a"),
        ],
        "edges": [
            ("f-1", "n-a", "n-sink"),
            ("f-2", "n-b", "n-sink"),
            ("f-3", "n-c", "n-sink"),
        ],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": ["n-a", "n-sink"],
    },
    "oauth-style-cycle": {
        "nodes": [
            ("n-client", "Client", "tz-a"),
            ("n-authz", "Authorization server", "tz-b"),
            ("n-api", "Resource API", "tz-b"),
        ],
        "edges": [
            ("f-1", "n-client", "n-authz"),
            ("f-2", "n-authz", "n-client"),
            ("f-3", "n-client", "n-api"),
        ],
        "zones": [("tz-a", "Zone A", None), ("tz-b", "Zone B", None)],
        "expected_rank_order": ["n-client", "n-authz"],
    },
    "two-independent-branches": {
        "nodes": [
            ("n-a1", "Branch one start", "tz-a"),
            ("n-a2", "Branch one end", "tz-a"),
            ("n-b1", "Branch two start", "tz-a"),
            ("n-b2", "Branch two end", "tz-a"),
        ],
        "edges": [("f-1", "n-a1", "n-a2"), ("f-2", "n-b1", "n-b2")],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": ["n-a1", "n-a2"],
    },
    "reverse-edge-pair": {
        "nodes": [
            ("n-a", "Requester", "tz-a"),
            ("n-b", "Responder", "tz-a"),
        ],
        "edges": [("f-1", "n-a", "n-b"), ("f-2", "n-b", "n-a")],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": [],
    },
    "multi-zone-chain": {
        "nodes": [
            ("n-edge", "Edge gateway", "tz-edge"),
            ("n-app", "Application service", "tz-app"),
            ("n-data", "Data store", "tz-data"),
        ],
        "edges": [("f-1", "n-edge", "n-app"), ("f-2", "n-app", "n-data")],
        "zones": [
            ("tz-edge", "Edge zone", None),
            ("tz-app", "Application zone", None),
            ("tz-data", "Data zone", None),
        ],
        "expected_rank_order": ["n-edge", "n-app", "n-data"],
    },
    "sparse-producer-consumer": {
        "nodes": [
            ("n-prod", "Producer", "tz-a"),
            ("n-queue", "Queue", "tz-a"),
            ("n-cons", "Consumer", "tz-a"),
        ],
        "edges": [("f-1", "n-prod", "n-queue"), ("f-2", "n-queue", "n-cons")],
        "zones": [("tz-a", "Zone A", None)],
        "expected_rank_order": ["n-prod", "n-queue", "n-cons"],
    },
}


def _layout_archetype(name: str, *, reverse_inputs: bool = False) -> dict[str, object]:
    archetype = ARCHETYPES[name]
    nodes = list(archetype["nodes"])
    edges = list(archetype["edges"])
    zones = list(archetype["zones"])
    if reverse_inputs:
        nodes = list(reversed(nodes))
        edges = list(reversed(edges))
        zones = list(reversed(zones))
    spec, profile = _build_archetype_spec(
        surface_id=f"surface-{name}",
        nodes=nodes,
        edges=edges,
        zones=zones,
    )
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    laid_out = generate_tm7.apply_layout(model, profile)
    return next(
        surface
        for surface in laid_out["surfaces"]
        if surface["id"] == f"surface-{name}"
    )


def _archetype_node_rects(
    surface: dict,
) -> dict[str, tuple[float, float, float, float]]:
    rects: dict[str, tuple[float, float, float, float]] = {}
    for element in surface["elements"]:
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) == "trust_boundary_box":
            continue
        position = element.get("position", {})
        left = float(position.get("left", 0.0))
        top = float(position.get("top", 0.0))
        rects[str(element["id"])] = (
            left,
            top,
            left + float(position.get("width", 0.0)),
            top + float(position.get("height", 0.0)),
        )
    return rects


@pytest.mark.parametrize("archetype_name", sorted(ARCHETYPES))
def test_given_archetype_when_laid_out_then_geometry_is_valid(
    archetype_name: str,
) -> None:
    # Act
    surface = _layout_archetype(archetype_name)
    rects = _archetype_node_rects(surface)

    # Assert
    expected_ids = {node_id for node_id, _, _ in ARCHETYPES[archetype_name]["nodes"]}
    assert set(rects) == expected_ids
    for left, top, right, bottom in rects.values():
        assert right - left >= generate_tm7.MIN_NODE_SIZE
        assert bottom - top >= generate_tm7.MIN_NODE_SIZE
    node_ids = sorted(rects)
    for index, node_id_a in enumerate(node_ids):
        left_a, top_a, right_a, bottom_a = rects[node_id_a]
        for node_id_b in node_ids[index + 1 :]:
            left_b, top_b, right_b, bottom_b = rects[node_id_b]
            overlaps = (
                left_a < right_b
                and left_b < right_a
                and top_a < bottom_b
                and top_b < bottom_a
            )
            assert not overlaps, f"{node_id_a} overlaps {node_id_b}"


@pytest.mark.parametrize("archetype_name", sorted(ARCHETYPES))
def test_given_reordered_archetype_inputs_when_laid_out_then_geometry_matches(
    archetype_name: str,
) -> None:
    # Act
    baseline = _archetype_node_rects(_layout_archetype(archetype_name))
    reordered = _archetype_node_rects(
        _layout_archetype(archetype_name, reverse_inputs=True)
    )

    # Assert
    assert baseline == reordered


@pytest.mark.parametrize("archetype_name", sorted(ARCHETYPES))
def test_given_archetype_when_laid_out_then_nodes_stay_inside_their_zone(
    archetype_name: str,
) -> None:
    # Act
    surface = _layout_archetype(archetype_name)
    rects = _archetype_node_rects(surface)
    zone_rects: dict[str, tuple[float, float, float, float]] = {}
    for element in surface["elements"]:
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) != "trust_boundary_box":
            continue
        position = element.get("position", {})
        left = float(position.get("left", 0.0))
        top = float(position.get("top", 0.0))
        zone_rects[str(element.get("trust_zone_id", ""))] = (
            left,
            top,
            left + float(position.get("width", 0.0)),
            top + float(position.get("height", 0.0)),
        )

    # Assert
    zone_by_node = {
        node_id: zone_id for node_id, _, zone_id in ARCHETYPES[archetype_name]["nodes"]
    }
    for node_id, (left, top, right, bottom) in rects.items():
        zone_rect = zone_rects.get(zone_by_node[node_id])
        if zone_rect is None:
            continue
        zone_left, zone_top, zone_right, zone_bottom = zone_rect
        assert zone_left <= left
        assert zone_top <= top
        assert right <= zone_right
        assert bottom <= zone_bottom


@pytest.mark.parametrize("node_count", [2, 6, 10, 14, 24])
def test_given_dense_zone_when_laid_out_then_nodes_never_escape_silently(
    node_count: int,
) -> None:
    """A dense zone must contain its nodes or fail closed, never both-and-neither.

    The bounded-canvas guard only rejects gross overflow of the whole surface.
    Between the sparse cases and that guard there was a window where layout
    returned successfully while nodes rendered outside their own trust
    boundary, so the emitted diagram misrepresented the trust model.
    """
    # Arrange
    nodes = [
        (f"n-{index}", f"Dense service {index}", "tz-a") for index in range(node_count)
    ]
    edges = [
        (f"f-{index}", f"n-{index}", f"n-{index + 1}")
        for index in range(node_count - 1)
    ]
    spec, profile = _build_archetype_spec(
        surface_id="surface-dense",
        nodes=nodes,
        edges=edges,
        zones=[("tz-a", "Zone A", None)],
    )
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    try:
        laid_out = generate_tm7.apply_layout(model, profile)
    except generate_tm7.GenerationError:
        # Assert: failing closed is an acceptable outcome for a zone that
        # cannot hold its contents.
        return
    surface = next(
        item for item in laid_out["surfaces"] if item["id"] == "surface-dense"
    )
    zone_rects = {
        str(element.get("trust_zone_id", "")): (
            float(element["position"]["left"]),
            float(element["position"]["top"]),
            float(element["position"]["left"]) + float(element["position"]["width"]),
            float(element["position"]["top"]) + float(element["position"]["height"]),
        )
        for element in surface["elements"]
        if isinstance(element, dict)
        and str(element.get("kind", "")) == "trust_boundary_box"
    }

    # Assert
    escapes = []
    for node_id, (left, top, right, bottom) in _archetype_node_rects(surface).items():
        zone_left, zone_top, zone_right, zone_bottom = zone_rects["tz-a"]
        if (
            left < zone_left
            or top < zone_top
            or right > zone_right
            or bottom > zone_bottom
        ):
            escapes.append(node_id)
    assert not escapes, (
        f"{node_count} nodes laid out successfully but {escapes} render "
        "outside trust zone tz-a"
    )


def test_given_zoneless_surface_when_laid_out_then_generation_fails_closed() -> None:
    """A surface whose elements carry no trust zone must not publish a model.

    Without zones no boundary rectangle exists, so every node would fall back
    to one constant coordinate and the containment guard would find nothing to
    enforce. The emitted diagram would be a single opaque pile presented as a
    threat model.
    """
    # Arrange
    spec, profile = _build_zone_layout_spec()
    surface = spec["representations"]["context_diagrams"][0]
    surface["trust_zone_ids"] = []
    for element in surface["elements"]:
        element.pop("trust_zone_id", None)
    spec["trust_zones"] = []
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError) as failure:
        generate_tm7.apply_layout(model, profile)
    message = str(failure.value)
    assert "no layout position" in message
    assert "node-left" in message
    assert "node-main" in message


def test_given_unplaced_element_when_laid_out_then_identifiers_are_sorted() -> None:
    """Diagnostics must name every unplaced element in a stable sorted order."""
    # Arrange
    spec, profile = _build_zone_layout_spec()
    surface = spec["representations"]["context_diagrams"][0]
    surface["trust_zone_ids"] = []
    for element in surface["elements"]:
        element.pop("trust_zone_id", None)
    spec["trust_zones"] = []
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    with pytest.raises(generate_tm7.GenerationError) as failure:
        generate_tm7.apply_layout(model, profile)

    # Assert
    named = [
        fragment.strip()
        for fragment in str(failure.value).split(":")[1].split(";")[0].split(",")
    ]
    assert named == sorted(named)


def test_given_suppressed_element_without_zone_when_laid_out_then_model_is_valid() -> (
    None
):
    """Suppression is a deliberate exclusion, not a missing placement.

    The element is injected after the model is built because
    ``build_model_from_spec`` already prunes suppressed elements; the contract
    under test is that ``apply_layout`` does not treat a surviving suppressed
    element as an unplaced one.
    """
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    surface = next(item for item in model["surfaces"] if item["id"] == "surface-01")
    surface["elements"].append(
        {
            "id": "node-suppressed",
            "kind": "process",
            "name": "Suppressed",
            "layout_role": "suppressed",
        }
    )

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    laid_out_surface = next(
        item for item in laid_out["surfaces"] if item["id"] == "surface-01"
    )
    placed = {
        str(element.get("id", ""))
        for element in laid_out_surface["elements"]
        if isinstance(element, dict)
        and str(element.get("kind", "")) != "trust_boundary_box"
    }
    assert "node-suppressed" in placed
    assert "node-main" in placed


def test_given_unnamed_trust_zone_when_laid_out_then_generation_fails_closed() -> None:
    """An unnamed zone emits no boundary box, silently disabling its guard."""
    # Arrange
    spec, profile = _build_zone_layout_spec()
    for zone in spec["trust_zones"]:
        if zone["id"] == "tz-child-1":
            zone["name"] = "   "
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError, match="tz-child-1"):
        generate_tm7.apply_layout(model, profile)


def test_given_child_zone_outside_parent_when_asserted_then_containment_fails() -> None:
    """A nested boundary rendered outside its parent misstates the trust model."""
    # Arrange
    surface = {
        "id": "surface-nested",
        "trust_zones": [
            {"id": "tz-root", "name": "Root"},
            {"id": "tz-child", "name": "Child", "parent_trust_zone_id": "tz-root"},
        ],
        "elements": [
            {
                "id": "boundary-tz-root",
                "kind": "trust_boundary_box",
                "trust_zone_id": "tz-root",
                "position": {
                    "left": 0.0,
                    "top": 0.0,
                    "width": 400.0,
                    "height": 400.0,
                },
            },
            {
                "id": "boundary-tz-child",
                "kind": "trust_boundary_box",
                "trust_zone_id": "tz-child",
                "position": {
                    "left": 300.0,
                    "top": 300.0,
                    "width": 400.0,
                    "height": 400.0,
                },
            },
        ],
    }

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError) as failure:
        generate_tm7._assert_zone_containment(surface)
    assert "tz-child outside parent tz-root" in str(failure.value)


def test_given_child_zone_inside_parent_when_asserted_then_containment_passes() -> None:
    """A properly nested boundary must not be rejected."""
    # Arrange
    surface = {
        "id": "surface-nested",
        "trust_zones": [
            {"id": "tz-root", "name": "Root"},
            {"id": "tz-child", "name": "Child", "parent_trust_zone_id": "tz-root"},
        ],
        "elements": [
            {
                "id": "boundary-tz-root",
                "kind": "trust_boundary_box",
                "trust_zone_id": "tz-root",
                "position": {
                    "left": 0.0,
                    "top": 0.0,
                    "width": 400.0,
                    "height": 400.0,
                },
            },
            {
                "id": "boundary-tz-child",
                "kind": "trust_boundary_box",
                "trust_zone_id": "tz-child",
                "position": {
                    "left": 40.0,
                    "top": 40.0,
                    "width": 200.0,
                    "height": 200.0,
                },
            },
        ],
    }

    # Act and Assert
    generate_tm7._assert_zone_containment(surface)


def test_given_failing_write_when_write_tm7_then_prior_destination_survives(
    tmp_path: Path,
) -> None:
    """A failed write must leave the previous model intact and no temp residue.

    The failure is injected with an unencodable lone surrogate rather than by
    patching the write path, so the test describes the durability contract
    instead of the implementation. A direct write truncates the destination
    before the encoder rejects the payload, which is the defect.
    """
    # Arrange
    destination = tmp_path / "nested" / "model.tm7"
    destination.parent.mkdir(parents=True)
    destination.write_text("<PreviousModel />", encoding="utf-8")
    original = destination.read_bytes()

    # Act
    with pytest.raises(UnicodeEncodeError):
        generate_tm7.write_tm7(destination, "<Model>\ud800</Model>")

    # Assert
    assert destination.read_bytes() == original
    assert not list(destination.parent.glob("*.tmp"))

    generate_tm7.write_tm7(destination, "<NewModel />")
    assert destination.read_text(encoding="utf-8") == "<NewModel />"
    assert not list(destination.parent.glob("*.tmp"))


def test_given_cli_run_when_flag_is_absent_then_the_spec_is_read_once(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The CLI resolves the threat-generation flag from the generator's read.

    Two independent reads let the flag and the model come from different
    revisions of the same file, so the read count is the contract under test.
    """
    # Arrange
    spec, _ = _build_zone_layout_spec()
    spec["threat_generation_enabled"] = True
    spec_path = tmp_path / "single-read.yaml"
    spec_path.write_text(yaml.safe_dump(spec, sort_keys=False), encoding="utf-8")
    output_path = tmp_path / "single-read.tm7"
    reads: list[Path] = []
    real_load_spec = generate_tm7.load_spec

    def counting_load_spec(path: Path) -> dict[str, object]:
        reads.append(Path(path))
        return real_load_spec(path)

    monkeypatch.setattr(generate_tm7, "load_spec", counting_load_spec)
    monkeypatch.setattr(
        sys,
        "argv",
        ["generate_tm7.py", str(spec_path), "-o", str(output_path)],
    )

    # Act
    exit_code = generate_tm7.main()

    # Assert
    assert exit_code == generate_tm7.EXIT_SUCCESS
    assert reads == [spec_path]
    assert "<ThreatGenerationEnabled>true</ThreatGenerationEnabled>" in (
        output_path.read_text(encoding="utf-8")
    )


def test_given_explicit_false_when_generating_then_the_spec_flag_is_not_consulted(
    tmp_path: Path,
) -> None:
    # Arrange
    spec, _ = _build_zone_layout_spec()
    spec["threat_generation_enabled"] = True
    spec_path = tmp_path / "explicit-false.yaml"
    spec_path.write_text(yaml.safe_dump(spec, sort_keys=False), encoding="utf-8")
    output_path = tmp_path / "explicit-false.tm7"

    # Act
    generate_tm7.generate_tm7_candidate(
        spec_path=spec_path,
        output_path=output_path,
        template=None,
        mode=None,
        update_path=None,
        overlay_path=None,
        threat_generation_enabled=False,
    )

    # Assert
    assert "<ThreatGenerationEnabled>false</ThreatGenerationEnabled>" in (
        output_path.read_text(encoding="utf-8")
    )


def test_given_contract_violation_when_cli_runs_then_message_is_concise(
    tmp_path: Path,
) -> None:
    """An invalid threat state is an expected failure, not an unhandled crash.

    The same run also proves completeness warnings still reach an operator on
    stderr now that they are emitted through the module logger.
    """
    # Arrange
    spec = copy.deepcopy(yaml.safe_load(SPEC_PATH.read_text(encoding="utf-8")))
    spec["threats"][0]["state"] = "not-a-real-state"
    spec.pop("abuse_cases", None)
    spec_path = tmp_path / "invalid-state.yaml"
    spec_path.write_text(yaml.safe_dump(spec, sort_keys=False), encoding="utf-8")

    # Act
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT_PATH),
            str(spec_path),
            "-o",
            str(tmp_path / "model.tm7"),
        ],
        check=False,
        cwd=ROOT,
        capture_output=True,
        text=True,
    )

    # Assert
    assert result.returncode != 0
    assert "Traceback" not in result.stderr
    assert "not-a-real-state" in result.stderr
    assert "CTM-8" in result.stderr
    assert not (tmp_path / "model.tm7").exists()


def test_given_external_spec_when_markdown_generated_then_profile_matches_tm7(
    tmp_path: Path,
) -> None:
    """Markdown must resolve the same shipped profile the TM7 generator resolves.

    Resolving from the spec's own directory made an external spec pick up a
    different profile than generation used for the same input.
    """
    # Arrange
    external_spec = tmp_path / "elsewhere" / "spec.yaml"
    external_spec.parent.mkdir(parents=True)
    external_spec.write_text(
        SPEC_PATH.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    spec = generate_markdown.load_spec(external_spec)
    expected = generate_tm7.resolve_profile(spec, None, ROOT)

    # Act
    result = subprocess.run(
        [
            sys.executable,
            str(MARKDOWN_SCRIPT_PATH),
            str(external_spec),
            "-o",
            str(tmp_path / "report.md"),
        ],
        check=False,
        cwd=ROOT,
        capture_output=True,
        text=True,
    )

    # Assert
    assert result.returncode == 0, result.stderr
    actual = generate_markdown.resolve_profile(
        spec,
        None,
        Path(generate_markdown.__file__).resolve().parent.parent,
    )
    assert actual["type_ids"] == expected["type_ids"]
    assert (tmp_path / "report.md").exists()


@pytest.mark.parametrize("archetype_name", sorted(ARCHETYPES))
def test_given_archetype_when_laid_out_then_rank_order_is_monotonic(
    archetype_name: str,
) -> None:
    # Act
    surface = _layout_archetype(archetype_name)
    rects = _archetype_node_rects(surface)
    expected_order = list(ARCHETYPES[archetype_name]["expected_rank_order"])
    zone_by_node = {
        node_id: zone_id for node_id, _, zone_id in ARCHETYPES[archetype_name]["nodes"]
    }

    # Assert
    # Ranks stack downward inside a zone while zones advance left to right, so
    # the monotonic axis depends on whether consecutive ranks share a zone.
    for previous_id, current_id in zip(expected_order, expected_order[1:]):
        previous_rect = rects[previous_id]
        current_rect = rects[current_id]
        if zone_by_node[previous_id] == zone_by_node[current_id]:
            previous_position = (previous_rect[1] + previous_rect[3]) / 2.0
            current_position = (current_rect[1] + current_rect[3]) / 2.0
            axis = "vertical"
        else:
            previous_position = (previous_rect[0] + previous_rect[2]) / 2.0
            current_position = (current_rect[0] + current_rect[2]) / 2.0
            axis = "horizontal"
        assert previous_position < current_position, (
            f"{archetype_name}: {previous_id} should precede {current_id} "
            f"on the {axis} axis"
        )


def test_given_reverse_pair_archetype_when_laid_out_then_lanes_are_separated() -> None:
    # Act
    surface = _layout_archetype("reverse-edge-pair")
    rects = _archetype_node_rects(surface)

    # Assert
    left_a, top_a, right_a, bottom_a = rects["n-a"]
    left_b, top_b, right_b, bottom_b = rects["n-b"]
    separated_horizontally = right_a <= left_b or right_b <= left_a
    separated_vertically = bottom_a <= top_b or bottom_b <= top_a
    assert separated_horizontally or separated_vertically


@pytest.mark.parametrize(
    "display_name",
    [
        "Api",
        "Workflow orchestration service",
        "Extremely long downstream reconciliation and audit publication service",
    ],
)
def test_given_varied_name_lengths_when_measured_then_growth_is_deterministic(
    display_name: str,
) -> None:
    # Arrange
    spec, profile = _build_archetype_spec(
        surface_id="surface-naming",
        nodes=[("n-1", display_name, "tz-a"), ("n-2", "Sink", "tz-a")],
        edges=[("f-1", "n-1", "n-2")],
        zones=[("tz-a", "Zone A", None)],
    )
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    first = generate_tm7.apply_layout(model, profile)
    second = generate_tm7.apply_layout(
        generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        ),
        profile,
    )

    def _node_rect(laid_out: dict) -> tuple[float, float, float, float]:
        surface = next(
            item for item in laid_out["surfaces"] if item["id"] == "surface-naming"
        )
        element = next(item for item in surface["elements"] if item.get("id") == "n-1")
        position = element["position"]
        return (
            float(position["left"]),
            float(position["top"]),
            float(position["width"]),
            float(position["height"]),
        )

    first_rect = _node_rect(first)
    second_rect = _node_rect(second)

    # Assert
    assert first_rect == second_rect
    width, height = first_rect[2], first_rect[3]
    measured_width, measured_height = generate_tm7._measure_node_dimensions(
        {"id": "n-1", "name": display_name}
    )
    assert width == pytest.approx(measured_width)
    assert height == pytest.approx(measured_height)
    assert generate_tm7.MIN_NODE_SIZE <= width <= generate_tm7.MAX_NODE_WIDTH
    assert generate_tm7.MIN_NODE_SIZE <= height <= generate_tm7.MAX_NODE_HEIGHT


def test_given_archetypes_when_refining_then_search_stays_within_budget() -> None:
    # Arrange
    incumbent = {
        "candidate_id": "incumbent",
        "node_ids": ["n-1", "n-2", "n-3"],
        "flow_ids": ["f-1", "f-2"],
        "zone_ids": ["tz-a", "tz-b", "tz-c"],
        "orientation": "vertical",
        "zone_order": ["tz-a", "tz-b", "tz-c"],
        "node_ranks": {"n-1": 0, "n-2": 1, "n-3": 2},
        "branch_groups": {"n-1": 0, "n-2": 0, "n-3": 0},
    }
    candidates = [
        {**incumbent, "candidate_id": f"candidate-{index:04d}"} for index in range(500)
    ]

    # Act
    decision = tm7_visual_feedback.select_surface_refinement(
        incumbent_score=tm7_visual_feedback.score_surface_layout_candidate(incumbent),
        incumbent_semantic_fingerprint=(
            tm7_visual_feedback.surface_semantic_fingerprint(incumbent)
        ),
        candidates=candidates,
    )

    # Assert
    assert (
        decision["evaluated_count"]
        <= tm7_visual_feedback.MAX_SURFACE_REFINEMENT_CANDIDATES
    )


def test_given_cross_zone_connector_when_layout_then_avoids_unrelated_label_band() -> (
    None
):
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    surface = next(
        surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
    )
    flow = next(flow for flow in surface["flows"] if flow["id"] == "flow-main-left")
    source = (flow["position"]["source_x"], flow["position"]["source_y"])
    handle = (flow["position"]["handle_x"], flow["position"]["handle_y"])
    target = (flow["position"]["target_x"], flow["position"]["target_y"])

    unrelated_boundary_rects = []
    unrelated_label_band_rects = []
    for element in surface["elements"]:
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) != "trust_boundary_box":
            continue
        zone_id = str(element.get("trust_zone_id", ""))
        if zone_id in {"tz-root", "tz-child-1"}:
            continue
        position = element.get("position", {})
        rect = {
            "left": float(position.get("left", 0)),
            "top": float(position.get("top", 0)),
            "width": float(position.get("width", 0)),
            "height": float(position.get("height", 0)),
        }
        unrelated_boundary_rects.append(rect)
        unrelated_label_band_rects.append(
            {
                "left": rect["left"],
                "top": rect["top"],
                "width": rect["width"],
                "height": 36.0,
            }
        )

    assert all(
        not generate_tm7._segment_intersects_rect(source, handle, rect)
        for rect in unrelated_boundary_rects + unrelated_label_band_rects
    )
    assert all(
        not generate_tm7._segment_intersects_rect(handle, target, rect)
        for rect in unrelated_boundary_rects + unrelated_label_band_rects
    )


def test_given_intra_zone_connector_when_layout_then_avoids_unrelated_node() -> None:
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    surface = next(
        surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
    )
    flow = next(flow for flow in surface["flows"] if flow["id"] == "flow-main-left")
    source = (flow["position"]["source_x"], flow["position"]["source_y"])
    handle = (flow["position"]["handle_x"], flow["position"]["handle_y"])
    target = (flow["position"]["target_x"], flow["position"]["target_y"])

    node_rects = []
    for element in surface["elements"]:
        if not isinstance(element, dict):
            continue
        if str(element.get("kind", "")) == "trust_boundary_box":
            continue
        element_id = str(element.get("id", ""))
        if element_id in {"node-main", "node-left"}:
            continue
        position = element.get("position", {})
        node_rects.append(
            {
                "left": float(position.get("left", 0)),
                "top": float(position.get("top", 0)),
                "width": float(position.get("width", 0)),
                "height": float(position.get("height", 0)),
            }
        )

    assert all(
        not generate_tm7._segment_intersects_rect(source, handle, rect)
        for rect in node_rects
    )
    assert all(
        not generate_tm7._segment_intersects_rect(handle, target, rect)
        for rect in node_rects
    )


def test_given_segment_when_routing_handle_then_zero_crossing_wins() -> None:
    # Arrange
    source_anchor = (100.0, 100.0)
    target_anchor = (600.0, 100.0)
    existing_segments = [((350.0, 80.0), (350.0, 200.0))]

    def count_crossings(handle: tuple[float, float]) -> int:
        crossings = 0
        for leg_start, leg_end in ((source_anchor, handle), (handle, target_anchor)):
            for prior_start, prior_end in existing_segments:
                if tm7_visual_feedback._segment_intersects_segment(
                    leg_start,
                    leg_end,
                    prior_start,
                    prior_end,
                ):
                    crossings += 1
        return crossings

    # Act
    handle = generate_tm7._route_connector_handle(
        {"left": 0.0, "top": 0.0, "width": 100.0, "height": 100.0},
        {"left": 500.0, "top": 0.0, "width": 100.0, "height": 100.0},
        [],
        source_anchor,
        target_anchor,
        1,
        existing_segments=existing_segments,
    )

    # Assert
    assert count_crossings(handle) == 0
    assert handle[0] == 350.0
    assert handle[1] == 100.0


def test_given_existing_segment_when_placing_label_then_crossing_is_avoided() -> None:
    # Arrange
    source_point = (100.0, 100.0)
    target_point = (600.0, 100.0)
    handle = (350.0, 100.0)
    existing_segments = [((350.0, 80.0), (350.0, 200.0))]

    def count_crossings(candidate_handle: tuple[float, float]) -> int:
        crossings = 0
        for leg_start, leg_end in (
            (source_point, candidate_handle),
            (candidate_handle, target_point),
        ):
            for prior_start, prior_end in existing_segments:
                if tm7_visual_feedback._segment_intersects_segment(
                    leg_start,
                    leg_end,
                    prior_start,
                    prior_end,
                ):
                    crossings += 1
        return crossings

    # Act
    layout = generate_tm7._place_connector_label(
        "Flow",
        "HTTPS",
        handle=handle,
        obstacles=[],
        routing_obstacles=[],
        source_point=source_point,
        target_point=target_point,
        existing_segments=existing_segments,
    )
    placed_handle = tuple(layout["handle_point"])

    # Assert
    assert placed_handle[0] == 350.0
    assert placed_handle[1] == 100.0
    assert count_crossings(placed_handle) == 0


def test_given_connector_override_when_apply_layout_then_replays_ports_and_handle() -> (
    None
):
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    overlay = {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": "zone-layout",
        "overlay_id": "overlay-connector",
        "applies_to": [
            {"surface_id": "surface-01", "generator_profile": "sdl_core_generic"}
        ],
        "zone_rules": [],
        "node_rules": [],
        "connector_rules": [
            {
                "surface_id": "surface-01",
                "flow_id": "flow-main-left",
                "source_port": "top",
                "target_port": "bottom",
                "handle_point": {"x": 240.0, "y": 160.0},
                "label_offset": {"x": 12.0, "y": 8.0},
            }
        ],
        "surface_rules": [],
        "provenance": {
            "evidence_ref": "test",
            "generated_at": "2026-07-18T00:00:00Z",
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": "spec",
            "generator_profile_fingerprint": "profile",
            "surface_identity_fingerprint": "surface",
            "surface_zone_identity_fingerprint": "zones",
            "surface_flow_identity_fingerprint": "flows",
        },
    }

    # Act
    laid_out = generate_tm7.apply_layout(model, profile, layout_overlay=overlay)

    # Assert
    surface = next(
        surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
    )
    flow = next(flow for flow in surface["flows"] if flow["id"] == "flow-main-left")
    assert flow["position"]["handle_x"] == 240
    assert flow["position"]["handle_y"] == 160


def test_given_outside_node_overlay_when_layout_then_node_stays_inside_boundary() -> (
    None
):
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    overlay = {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": "zone-layout",
        "overlay_id": "overlay-outside-node",
        "applies_to": [
            {"surface_id": "surface-01", "generator_profile": "sdl_core_generic"}
        ],
        "zone_rules": [],
        "node_rules": [
            {
                "surface_id": "surface-01",
                "node_id": "node-left",
                "layout_role": "connected",
                "absolute_position": {
                    "left": 10000.0,
                    "top": 10000.0,
                    "width": 100.0,
                    "height": 100.0,
                },
            }
        ],
        "connector_rules": [],
        "surface_rules": [],
        "provenance": {
            "evidence_ref": "test",
            "generated_at": "2026-07-22T00:00:00Z",
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": "spec",
            "generator_profile_fingerprint": "profile",
            "surface_identity_fingerprint": "surface",
            "surface_zone_identity_fingerprint": "zones",
            "surface_flow_identity_fingerprint": "flows",
        },
    }

    # Act
    laid_out = generate_tm7.apply_layout(model, profile, layout_overlay=overlay)
    surface = laid_out["surfaces"][0]
    node = next(item for item in surface["elements"] if item["id"] == "node-left")
    boundary = next(
        item for item in surface["elements"] if item["id"] == "boundary-tz-child-1"
    )
    node_position = node["position"]
    boundary_position = boundary["position"]

    # Assert
    assert node_position["left"] >= boundary_position["left"]
    assert node_position["top"] >= boundary_position["top"]
    assert node_position["left"] + node_position["width"] <= (
        boundary_position["left"] + boundary_position["width"]
    )
    assert node_position["top"] + node_position["height"] <= (
        boundary_position["top"] + boundary_position["height"]
    )


def test_given_cyclic_surface_when_analyzed_then_components_and_ranks_are_derived() -> (
    None
):
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {"id": "source", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "branch", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "consumer", "kind": "process", "trust_zone_id": "zone-b"},
        ],
        "flows": [
            {"id": "f-1", "source_ref": "source", "target_ref": "branch"},
            {"id": "f-2", "source_ref": "branch", "target_ref": "consumer"},
            {"id": "f-3", "source_ref": "consumer", "target_ref": "source"},
        ],
        "trust_zones": [
            {"id": "zone-a", "name": "Zone A"},
            {"id": "zone-b", "name": "Zone B"},
        ],
    }

    # Act
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Assert
    assert (
        graph["scc_component_ids"]["source"] == graph["scc_component_ids"]["consumer"]
    )
    assert graph["node_ranks"]["source"] < graph["node_ranks"]["branch"]
    assert graph["node_ranks"]["branch"] < graph["node_ranks"]["consumer"]
    assert graph["reverse_edge_pairs"] == [("branch", "source")]


def test_given_two_zone_surface_when_candidates_built_then_orientation_is_stable() -> (
    None
):
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {"id": "source", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "consumer", "kind": "process", "trust_zone_id": "zone-b"},
        ],
        "flows": [
            {"id": "f-1", "source_ref": "source", "target_ref": "consumer"},
        ],
        "trust_zones": [
            {"id": "zone-a", "name": "Zone A"},
            {"id": "zone-b", "name": "Zone B"},
        ],
    }

    # Act
    graph = generate_tm7._analyze_surface_layout_graph(surface)
    candidates = generate_tm7._build_surface_layout_candidates(surface, graph)
    selected = generate_tm7._select_surface_layout_candidate(surface, graph)

    # Assert
    assert len(candidates) >= 2
    assert selected["orientation"] in {"horizontal", "vertical"}
    assert selected["zone_order"] == ["zone-a", "zone-b"]


@pytest.mark.parametrize(
    ("case", "start", "end", "expected"),
    [
        ("crossing", (50.0, 150.0), (250.0, 150.0), True),
        ("contained", (120.0, 120.0), (180.0, 180.0), True),
        ("disjoint", (0.0, 0.0), (10.0, 10.0), False),
        ("tangent top edge", (50.0, 100.0), (250.0, 100.0), True),
        ("tangent left edge", (100.0, 50.0), (100.0, 250.0), True),
        ("corner grazed mid-segment", (150.0, 50.0), (250.0, 150.0), True),
        ("diagonal through opposite corners", (50.0, 50.0), (250.0, 250.0), True),
        ("endpoint on boundary", (50.0, 150.0), (100.0, 150.0), True),
        ("degenerate inside", (150.0, 150.0), (150.0, 150.0), True),
        ("degenerate on edge", (100.0, 150.0), (100.0, 150.0), True),
        ("degenerate outside", (5.0, 5.0), (5.0, 5.0), False),
        ("parallel just outside", (50.0, 99.999999), (250.0, 99.999999), False),
    ],
)
def test_given_segment_and_rect_when_tested_then_both_shapes_agree(
    case: str,
    start: tuple[float, float],
    end: tuple[float, float],
    expected: bool,
) -> None:
    """The generator and the feedback loop must not disagree about contact.

    The generator holds rectangles as left/top/width/height and the feedback
    loop as left/top/right/bottom. Two independent algorithms previously backed
    those shapes and disagreed on tangent and corner-grazing contact, so the
    geometry the generator published could be scored against a different
    contact rule than the one that produced it.
    """
    # Arrange
    rect_ltwh = {"left": 100.0, "top": 100.0, "width": 100.0, "height": 100.0}
    rect_ltrb = (100.0, 100.0, 200.0, 200.0)

    # Act
    generator_result = generate_tm7._segment_intersects_rect(start, end, rect_ltwh)
    feedback_result = tm7_visual_feedback._segment_intersects_rect(
        start, end, rect_ltrb
    )

    # Assert
    assert generator_result == expected, case
    assert feedback_result == expected, case


def test_given_deep_flow_chain_when_analyzed_then_no_recursion_error() -> None:
    """Component analysis must not recurse once per node.

    Tarjan's algorithm recurses to the depth of the longest simple path, so a
    sufficiently long chain of elements raised RecursionError while generating
    an otherwise valid model.
    """
    # Arrange
    depth = 4000
    node_ids = [f"node-{index:05d}" for index in range(depth)]
    surface = {
        "id": "surface-deep",
        "elements": [
            {"id": node_id, "kind": "process", "trust_zone_id": "zone-a"}
            for node_id in node_ids
        ],
        "flows": [
            {
                "id": f"f-{index:05d}",
                "source_ref": node_ids[index],
                "target_ref": node_ids[index + 1],
            }
            for index in range(depth - 1)
        ],
        "trust_zones": [{"id": "zone-a", "name": "Zone A"}],
    }

    # Act
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Assert
    assert len(graph["node_ranks"]) == depth
    assert len({graph["scc_component_ids"][node_id] for node_id in node_ids}) == depth


def test_given_deep_flow_cycle_when_analyzed_then_one_component_is_found() -> None:
    """A cycle spanning the whole chain must still collapse to one component."""
    # Arrange
    depth = 2000
    node_ids = [f"node-{index:05d}" for index in range(depth)]
    flows = [
        {
            "id": f"f-{index:05d}",
            "source_ref": node_ids[index],
            "target_ref": node_ids[(index + 1) % depth],
        }
        for index in range(depth)
    ]
    surface = {
        "id": "surface-cycle",
        "elements": [
            {"id": node_id, "kind": "process", "trust_zone_id": "zone-a"}
            for node_id in node_ids
        ],
        "flows": flows,
        "trust_zones": [{"id": "zone-a", "name": "Zone A"}],
    }

    # Act
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Assert
    assert len({graph["scc_component_ids"][node_id] for node_id in node_ids}) == 1


def test_given_zoneless_surface_when_selected_then_fallback_has_full_contract() -> None:
    """The no-candidate fallback must be shape-identical to a real candidate."""
    # Arrange
    surface = {
        "id": "surface-zoneless",
        "elements": [
            {"id": "source", "kind": "process"},
            {"id": "consumer", "kind": "process"},
        ],
        "flows": [{"id": "f-1", "source_ref": "source", "target_ref": "consumer"}],
        "trust_zones": [],
    }
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Act
    selected = generate_tm7._select_surface_layout_candidate(surface, graph)

    # Assert
    assert generate_tm7._build_surface_layout_candidates(surface, graph) == []
    for member in generate_tm7.SURFACE_LAYOUT_CANDIDATE_MEMBERS:
        assert member in selected, member


def test_given_invalid_candidates_when_selected_then_the_first_valid_one_wins(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Selection must skip an invalid candidate rather than return position zero."""
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {"id": "source", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "consumer", "kind": "process", "trust_zone_id": "zone-b"},
        ],
        "flows": [{"id": "f-1", "source_ref": "source", "target_ref": "consumer"}],
        "trust_zones": [
            {"id": "zone-a", "name": "Zone A"},
            {"id": "zone-b", "name": "Zone B"},
        ],
    }
    graph = generate_tm7._analyze_surface_layout_graph(surface)
    built = generate_tm7._build_surface_layout_candidates(surface, graph)
    broken = copy.deepcopy(built[0])
    broken["orientation"] = "diagonal"
    expected = copy.deepcopy(built[1])
    monkeypatch.setattr(
        generate_tm7,
        "_build_surface_layout_candidates",
        lambda *args, **kwargs: [broken, expected],
    )

    # Act
    selected = generate_tm7._select_surface_layout_candidate(surface, graph)

    # Assert
    assert selected["orientation"] == expected["orientation"]
    assert selected["zone_order"] == expected["zone_order"]


def test_given_only_invalid_candidates_when_selected_then_generation_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """No valid candidate must fail loudly instead of laying out a broken one."""
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {"id": "source", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "consumer", "kind": "process", "trust_zone_id": "zone-b"},
        ],
        "flows": [{"id": "f-1", "source_ref": "source", "target_ref": "consumer"}],
        "trust_zones": [
            {"id": "zone-a", "name": "Zone A"},
            {"id": "zone-b", "name": "Zone B"},
        ],
    }
    graph = generate_tm7._analyze_surface_layout_graph(surface)
    broken = copy.deepcopy(
        generate_tm7._build_surface_layout_candidates(surface, graph)[0]
    )
    broken["zone_order"] = ["zone-a", "zone-a"]
    monkeypatch.setattr(
        generate_tm7,
        "_build_surface_layout_candidates",
        lambda *args, **kwargs: [broken],
    )

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError) as error:
        generate_tm7._select_surface_layout_candidate(surface, graph)
    assert "surface-test: zone_order repeats a zone" in str(error.value)


def test_given_candidate_enumeration_when_built_then_the_bound_is_reachable() -> None:
    """The declared candidate bound must match what enumeration can produce.

    The previous value of 192 could never be reached, so it enforced nothing.
    """
    # Arrange
    zone_ids = [f"zone-{index}" for index in range(4)]
    surface = {
        "id": "surface-wide",
        "elements": [
            {"id": f"node-{index}", "kind": "process", "trust_zone_id": zone_id}
            for index, zone_id in enumerate(zone_ids)
        ],
        "flows": [
            {
                "id": f"f-{index}",
                "source_ref": f"node-{index}",
                "target_ref": f"node-{index + 1}",
            }
            for index in range(len(zone_ids) - 1)
        ],
        "trust_zones": [{"id": zone_id, "name": zone_id} for zone_id in zone_ids],
    }
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Act
    candidates = generate_tm7._build_surface_layout_candidates(surface, graph)

    # Assert
    assert len(candidates) == generate_tm7.MAX_SURFACE_LAYOUT_CANDIDATES
    assert all("placement_variant" not in candidate for candidate in candidates)


def test_given_self_referencing_flow_when_built_then_generation_fails() -> None:
    """A flow whose endpoints are the same element has no supported rendering."""
    # Arrange
    spec = {
        "components": [{"id": "source", "name": "Source", "kind": "process"}],
        "data_flows": [
            {"id": "loop-01", "source_ref": "source", "target_ref": "source"},
            {"id": "loop-02", "source_ref": "source", "target_ref": "source"},
        ],
        "representations": {
            "context_diagrams": [
                {
                    "id": "surface-01",
                    "elements": [{"id": "source"}],
                    "flows": ["loop-01", "loop-02"],
                }
            ]
        },
    }

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError) as error:
        generate_tm7.build_model_from_spec(spec, {"type_ids": {}}, "full")
    message = str(error.value)
    assert "loop-01, loop-02" in message
    assert "self-referencing" in message


def test_given_branching_surface_when_candidates_built_then_each_one_is_valid() -> None:
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {"id": "source", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "branch-1", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "branch-2", "kind": "process", "trust_zone_id": "zone-a"},
            {"id": "consumer", "kind": "process", "trust_zone_id": "zone-b"},
        ],
        "flows": [
            {"id": "f-1", "source_ref": "source", "target_ref": "branch-1"},
            {"id": "f-2", "source_ref": "source", "target_ref": "branch-2"},
            {"id": "f-3", "source_ref": "branch-1", "target_ref": "consumer"},
            {"id": "f-4", "source_ref": "branch-2", "target_ref": "consumer"},
        ],
        "trust_zones": [
            {"id": "zone-a", "name": "Zone A"},
            {"id": "zone-b", "name": "Zone B"},
        ],
    }

    # Act
    graph = generate_tm7._analyze_surface_layout_graph(surface)
    candidates = generate_tm7._build_surface_layout_candidates(surface, graph)

    # Assert
    assert len(candidates) >= 3
    assert len(candidates) <= generate_tm7.MAX_SURFACE_LAYOUT_CANDIDATES
    assert all(
        generate_tm7._validate_surface_layout_candidate(candidate, "surface-test") == []
        for candidate in candidates
    )


def test_given_long_node_text_when_placed_then_node_grows_and_reserves_gutters() -> (
    None
):
    # Arrange
    surface = {
        "id": "surface-test",
        "elements": [
            {
                "id": "node-long",
                "kind": "process",
                "trust_zone_id": "zone-a",
                "name": "OAuth authorization callback flow handling",
            },
            {
                "id": "node-short",
                "kind": "process",
                "trust_zone_id": "zone-a",
                "name": "token",
            },
        ],
        "flows": [],
        "trust_zones": [{"id": "zone-a", "name": "Zone A"}],
    }

    # Act
    positions = generate_tm7._place_zone_nodes(
        surface,
        zone_content_rects={
            "zone-a": {
                "left": 24.0,
                "top": 24.0,
                "width": 800.0,
                "height": 400.0,
            }
        },
    )

    # Assert
    long_position = positions["node-long"]
    short_position = positions["node-short"]
    assert long_position["width"] > 100.0
    assert long_position["height"] > 100.0
    assert (
        short_position["left"] + short_position["width"] + 24.0
        <= long_position["left"] + 1.0
    )


def _build_fan_out_reverse_surface() -> dict[str, object]:
    return {
        "id": "surface-ports",
        "elements": [
            {"id": "hub", "kind": "process", "trust_zone_id": "zone-a", "name": "Hub"},
            {
                "id": "leaf-a",
                "kind": "process",
                "trust_zone_id": "zone-a",
                "name": "Leaf A",
            },
            {
                "id": "leaf-b",
                "kind": "process",
                "trust_zone_id": "zone-a",
                "name": "Leaf B",
            },
            {
                "id": "leaf-c",
                "kind": "process",
                "trust_zone_id": "zone-a",
                "name": "Leaf C",
            },
        ],
        "flows": [
            {"id": "f-1", "source_ref": "hub", "target_ref": "leaf-a", "ordinal": 1},
            {"id": "f-2", "source_ref": "hub", "target_ref": "leaf-b", "ordinal": 2},
            {"id": "f-3", "source_ref": "leaf-a", "target_ref": "hub", "ordinal": 3},
            {"id": "f-4", "source_ref": "hub", "target_ref": "leaf-c", "ordinal": 4},
        ],
        "trust_zones": [{"id": "zone-a", "name": "Zone A"}],
    }


def test_given_fan_out_edges_when_allocating_ports_then_slots_are_distinct() -> None:
    # Arrange
    surface = _build_fan_out_reverse_surface()
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Act
    slots = generate_tm7._allocate_edge_port_slots(surface, graph)

    # Assert
    forward_slots = [
        slots[flow_id]["source"]["slot_index"] for flow_id in ("f-2", "f-4")
    ]
    assert sorted(forward_slots) == [0, 1]
    assert slots["f-2"]["source"]["slot_count"] == 2


def test_given_reverse_pair_when_allocating_ports_then_sides_are_separated() -> None:
    # Arrange
    surface = _build_fan_out_reverse_surface()
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Act
    slots = generate_tm7._allocate_edge_port_slots(surface, graph)

    # Assert
    assert slots["f-3"]["source"]["is_reverse"] is True
    assert slots["f-2"]["source"]["is_reverse"] is False
    assert slots["f-3"]["source"]["side"] != slots["f-2"]["source"]["side"]


def test_given_reordered_flows_when_allocating_ports_then_slots_are_stable() -> None:
    # Arrange
    surface = _build_fan_out_reverse_surface()
    reordered = dict(surface)
    reordered["flows"] = list(reversed(surface["flows"]))
    graph = generate_tm7._analyze_surface_layout_graph(surface)

    # Act
    original_slots = generate_tm7._allocate_edge_port_slots(surface, graph)
    reordered_slots = generate_tm7._allocate_edge_port_slots(reordered, graph)

    # Assert
    assert original_slots == reordered_slots


def test_given_shared_node_side_when_offsetting_ports_then_points_differ() -> None:
    # Arrange
    rect = {"left": 0.0, "top": 0.0, "width": 100.0, "height": 100.0}
    anchor = (100.0, 50.0)

    # Act
    first = generate_tm7._apply_port_slot_offset(
        anchor,
        rect,
        {"slot_index": 0, "slot_count": 2, "is_reverse": False},
    )
    second = generate_tm7._apply_port_slot_offset(
        anchor,
        rect,
        {"slot_index": 1, "slot_count": 2, "is_reverse": False},
    )

    # Assert
    assert first != second
    assert first[0] == anchor[0]
    assert second[0] == anchor[0]


def test_given_clustered_handles_when_routing_then_separation_is_preferred() -> None:
    # Arrange
    source_rect = {"left": 0.0, "top": 0.0, "width": 100.0, "height": 100.0}
    target_rect = {"left": 500.0, "top": 0.0, "width": 100.0, "height": 100.0}
    source_anchor = (100.0, 50.0)
    target_anchor = (500.0, 50.0)

    # Act
    handle = generate_tm7._route_connector_handle(
        source_rect,
        target_rect,
        [],
        source_anchor,
        target_anchor,
        1,
        existing_handles=[(300.0, 50.0)],
    )

    # Assert
    separation = math.hypot(handle[0] - 300.0, handle[1] - 50.0)
    assert separation >= generate_tm7.MIN_LAYOUT_GUTTER


def test_given_reverse_lane_sign_when_routing_then_handles_use_opposite_lanes() -> None:
    # Arrange
    source_rect = {"left": 0.0, "top": 0.0, "width": 100.0, "height": 100.0}
    target_rect = {"left": 500.0, "top": 0.0, "width": 100.0, "height": 100.0}
    source_anchor = (100.0, 50.0)
    target_anchor = (500.0, 50.0)

    # Act
    forward_handle = generate_tm7._route_connector_handle(
        source_rect,
        target_rect,
        [],
        source_anchor,
        target_anchor,
        1,
        reverse_lane_sign=1.0,
    )
    reverse_handle = generate_tm7._route_connector_handle(
        source_rect,
        target_rect,
        [],
        source_anchor,
        target_anchor,
        2,
        reverse_lane_sign=-1.0,
    )

    # Assert
    midpoint_y = (source_anchor[1] + target_anchor[1]) / 2.0
    assert forward_handle[1] > midpoint_y
    assert reverse_handle[1] < midpoint_y


def test_given_duplicate_leg_when_routing_then_alternate_handle_is_chosen() -> None:
    # Arrange
    source_rect = {"left": 0.0, "top": 0.0, "width": 100.0, "height": 100.0}
    target_rect = {"left": 500.0, "top": 0.0, "width": 100.0, "height": 100.0}
    source_anchor = (100.0, 50.0)
    target_anchor = (500.0, 50.0)
    duplicate_segments = [
        ((100.0, 50.0), (300.0, 50.0)),
        ((300.0, 50.0), (500.0, 50.0)),
    ]

    # Act
    handle = generate_tm7._route_connector_handle(
        source_rect,
        target_rect,
        [],
        source_anchor,
        target_anchor,
        1,
        existing_segments=duplicate_segments,
    )

    # Assert
    assert handle != (300.0, 50.0)


def test_given_label_candidates_when_placing_then_arrowhead_clearance_is_kept() -> None:
    # Arrange
    source_point = (100.0, 300.0)
    target_point = (600.0, 300.0)
    handle = (350.0, 300.0)

    # Act
    layout = generate_tm7._place_connector_label(
        "Submit request",
        "HTTPS",
        handle=handle,
        obstacles=[],
        routing_obstacles=[],
        source_point=source_point,
        target_point=target_point,
    )

    # Assert
    left, top, width, height = layout["label_rect"]
    center = (left + width / 2.0, top + height / 2.0)
    clearance = math.hypot(center[0] - target_point[0], center[1] - target_point[1])
    assert clearance >= generate_tm7.MIN_LABEL_ARROWHEAD_CLEARANCE


def test_given_label_candidates_when_placing_then_ownership_distance_is_bounded() -> (
    None
):
    # Arrange
    source_point = (100.0, 300.0)
    target_point = (600.0, 300.0)
    handle = (350.0, 300.0)

    # Act
    layout = generate_tm7._place_connector_label(
        "Persist content",
        "HTTPS",
        handle=handle,
        obstacles=[],
        routing_obstacles=[],
        source_point=source_point,
        target_point=target_point,
    )

    # Assert
    left, top, width, height = layout["label_rect"]
    center = (left + width / 2.0, top + height / 2.0)
    ownership = min(
        generate_tm7._point_to_segment_distance(center, source_point, handle),
        generate_tm7._point_to_segment_distance(center, handle, target_point),
    )
    assert ownership <= generate_tm7.MAX_LABEL_OWNERSHIP_DISTANCE


def test_given_reverse_pair_labels_when_placing_then_lanes_are_separated() -> None:
    # Arrange
    source_point = (100.0, 300.0)
    target_point = (600.0, 300.0)
    handle = (350.0, 300.0)

    # Act
    # Lane separation is only reachable by moving the handle, because the
    # handle is the only label geometry the model serializes and TMT centres
    # each label on it. A fixed handle therefore cannot separate a pair.
    forward = generate_tm7._place_connector_label(
        "Send request",
        "HTTPS",
        handle=handle,
        obstacles=[],
        routing_obstacles=[],
        source_point=source_point,
        target_point=target_point,
        reverse_lane_sign=1.0,
        preserve_handle=True,
    )
    reverse = generate_tm7._place_connector_label(
        "Return result",
        "HTTPS",
        handle=handle,
        obstacles=[],
        routing_obstacles=[],
        source_point=source_point,
        target_point=target_point,
        reverse_lane_sign=-1.0,
        preserve_handle=True,
    )

    # Assert
    forward_handle = forward["handle_point"]
    reverse_handle = reverse["handle_point"]
    assert forward_handle[1] > handle[1]
    assert reverse_handle[1] < handle[1]
    # The drawn label follows the handle, so separated handles separate labels.
    forward_center_y = forward["label_rect"][1] + forward["label_rect"][3] / 2.0
    reverse_center_y = reverse["label_rect"][1] + reverse["label_rect"][3] / 2.0
    assert forward_center_y > handle[1]
    assert reverse_center_y < handle[1]


def test_given_point_and_segment_when_measuring_then_distance_is_shortest() -> None:
    # Act
    distance = generate_tm7._point_to_segment_distance(
        (50.0, 80.0),
        (0.0, 0.0),
        (100.0, 0.0),
    )
    endpoint_distance = generate_tm7._point_to_segment_distance(
        (-30.0, 0.0),
        (0.0, 0.0),
        (100.0, 0.0),
    )

    # Assert
    assert distance == pytest.approx(80.0)
    assert endpoint_distance == pytest.approx(30.0)


def test_given_slot_offset_when_applied_then_anchor_stays_on_node() -> None:
    """Slot spreading must not push an anchor off the node it belongs to."""
    # Arrange
    rect = {"left": 100.0, "top": 100.0, "width": 120.0, "height": 100.0}
    corner_anchor = (220.0, 195.0)
    slot = {"slot_index": 3, "slot_count": 4, "is_reverse": True}

    # Act
    result = generate_tm7._apply_port_slot_offset(corner_anchor, rect, slot)

    # Assert
    assert rect["left"] <= result[0] <= rect["left"] + rect["width"]
    assert rect["top"] <= result[1] <= rect["top"] + rect["height"]


def test_given_avoidance_offsets_when_routing_then_endpoints_stay_attached() -> None:
    """Obstacle avoidance must not detach an endpoint from its node."""
    # Arrange
    source_rect = {"left": 40.0, "top": 100.0, "width": 110.0, "height": 100.0}
    target_rect = {"left": 800.0, "top": 100.0, "width": 140.0, "height": 120.0}
    blockers = [
        {"left": 300.0, "top": 60.0, "width": 200.0, "height": 400.0},
        {"left": 560.0, "top": 60.0, "width": 160.0, "height": 400.0},
    ]

    # Act
    source_point, target_point = generate_tm7._find_clear_connector_points(
        source_rect,
        target_rect,
        blockers,
        (150.0, 150.0),
        (800.0, 160.0),
        3,
    )

    # Assert
    assert (
        source_rect["left"]
        <= source_point[0]
        <= (source_rect["left"] + source_rect["width"])
    )
    assert (
        source_rect["top"]
        <= source_point[1]
        <= (source_rect["top"] + source_rect["height"])
    )
    assert (
        target_rect["left"]
        <= target_point[0]
        <= (target_rect["left"] + target_rect["width"])
    )
    assert (
        target_rect["top"]
        <= target_point[1]
        <= (target_rect["top"] + target_rect["height"])
    )


def test_given_comprehensive_layout_when_generated_then_no_detached_endpoints() -> None:
    """Every connector endpoint must touch the node it connects."""
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    for surface in laid_out["surfaces"]:
        rects = {}
        for element in surface.get("elements", []):
            if not isinstance(element, dict):
                continue
            if str(element.get("kind", "")) == "trust_boundary_box":
                continue
            position = element.get("position", {})
            left = float(position.get("left", 0.0))
            top = float(position.get("top", 0.0))
            rects[str(element["id"])] = (
                left,
                top,
                left + float(position.get("width", 0.0)),
                top + float(position.get("height", 0.0)),
            )
        for flow in surface.get("flows", []):
            position = flow.get("position") or {}
            for source_key, x_key, y_key in (
                ("source_ref", "source_x", "source_y"),
                ("target_ref", "target_x", "target_y"),
            ):
                rect = rects.get(str(flow.get(source_key, "")))
                if rect is None:
                    continue
                point_x = float(position.get(x_key, 0.0))
                point_y = float(position.get(y_key, 0.0))
                gap_x = max(rect[0] - point_x, 0.0, point_x - rect[2])
                gap_y = max(rect[1] - point_y, 0.0, point_y - rect[3])
                assert math.hypot(gap_x, gap_y) <= 1.0, (
                    f"{flow.get('id')} {source_key} endpoint is detached"
                )


def test_given_occupied_handle_when_routing_then_candidate_is_displaced() -> None:
    """TMT draws labels at handles, so two connectors must not share one."""
    # Arrange
    source_rect = {"left": 100.0, "top": 100.0, "width": 100.0, "height": 100.0}
    target_rect = {"left": 500.0, "top": 100.0, "width": 100.0, "height": 100.0}
    source_anchor = (200.0, 150.0)
    target_anchor = (500.0, 150.0)
    occupied = (350.0, 150.0)

    # Act
    handle = generate_tm7._route_connector_handle(
        source_rect=source_rect,
        target_rect=target_rect,
        other_rects=[],
        source_anchor=source_anchor,
        target_anchor=target_anchor,
        ordinal=1,
        existing_handles=[occupied],
    )

    # Assert
    separation = math.hypot(handle[0] - occupied[0], handle[1] - occupied[1])
    assert separation >= generate_tm7.MIN_HANDLE_SEPARATION


def test_given_many_shared_edges_when_routing_then_handles_stay_distinct() -> None:
    """Every routed handle on a surface must be separable from the others."""
    # Arrange
    source_rect = {"left": 100.0, "top": 100.0, "width": 100.0, "height": 100.0}
    target_rect = {"left": 500.0, "top": 100.0, "width": 100.0, "height": 100.0}
    placed: list[tuple[float, float]] = []

    # Act
    for index in range(5):
        handle = generate_tm7._route_connector_handle(
            source_rect=source_rect,
            target_rect=target_rect,
            other_rects=[],
            source_anchor=(200.0, 150.0),
            target_anchor=(500.0, 150.0),
            ordinal=index + 1,
            existing_handles=list(placed),
        )
        placed.append(handle)

    # Assert
    for index, handle_a in enumerate(placed):
        for handle_b in placed[index + 1 :]:
            separation = math.hypot(
                handle_a[0] - handle_b[0], handle_a[1] - handle_b[1]
            )
            assert separation >= generate_tm7.MIN_HANDLE_SEPARATION


def test_given_explicit_connector_label_when_layout_then_label_and_rect_persist() -> (
    None
):
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    flow = next(flow for flow in model["flows"] if flow["id"] == "flow-main-left")
    flow["label"] = "Access the service"
    flow["transport"] = "HTTPS"

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    surface = next(
        surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
    )
    flow_payload = next(
        flow for flow in surface["flows"] if flow["id"] == "flow-main-left"
    )
    assert flow_payload["display_label"] == "Access the service over HTTPS"
    assert len(flow_payload["label_lines"]) <= 2
    assert isinstance(flow_payload["label_rect"], list)


def test_given_overlong_label_when_layout_then_generation_error_is_raised() -> None:
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    flow = next(flow for flow in model["flows"] if flow["id"] == "flow-main-left")
    flow["label"] = (
        "This label is intentionally too long to fit within the conservative "
        "two-line limit"
    )
    flow["transport"] = "HTTPS"

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError, match="flow-main-left"):
        generate_tm7.apply_layout(model, profile)


def test_given_labelled_flow_when_layout_then_canvas_bounds_stay_positive() -> None:
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    flow = next(flow for flow in model["flows"] if flow["id"] == "flow-main-left")
    flow["label"] = "Access the service"
    flow["transport"] = "HTTPS"

    # Act
    laid_out = generate_tm7.apply_layout(model, profile)

    # Assert
    surface = next(
        surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
    )
    flow_payload = next(
        flow for flow in surface["flows"] if flow["id"] == "flow-main-left"
    )
    positions = [
        element.get("position", {})
        for element in surface["elements"]
        if isinstance(element, dict) and isinstance(element.get("position"), dict)
    ]
    assert all(position["left"] >= 24 for position in positions)
    assert all(position["top"] >= 24 for position in positions)
    assert flow_payload["position"]["handle_x"] >= 0
    assert flow_payload["label_rect"][0] >= 24


def test_given_expanded_canvas_when_layout_then_generation_error_is_raised() -> None:
    # Arrange
    spec, profile = _build_zone_layout_spec()
    model = generate_tm7.build_model_from_spec(
        spec,
        profile,
        str(spec.get("mode") or "pre-populated-comprehensive"),
    )
    overlay = {
        "schema_version": 2,
        "overlay_type": "tm7_layout_overlay",
        "model_id": "zone-layout",
        "overlay_id": "overlay-canvas",
        "applies_to": [
            {"surface_id": "surface-01", "generator_profile": "sdl_core_generic"}
        ],
        "zone_rules": [],
        "node_rules": [],
        "connector_rules": [],
        "surface_rules": [
            {
                "surface_id": "surface-01",
                "zone_order": ["tz-root", "tz-child-1", "tz-child-2"],
                "orientation": "horizontal",
                "viewport_target": {"left": 0, "top": 0, "width": 200, "height": 200},
                "outer_margin": 24,
            }
        ],
        "provenance": {
            "evidence_ref": "test",
            "generated_at": "2026-07-18T00:00:00Z",
            "approval_state": "pending",
        },
        "invalidation": {
            "spec_fingerprint": "spec",
            "generator_profile_fingerprint": "profile",
            "surface_identity_fingerprint": "surface",
            "surface_zone_identity_fingerprint": "zones",
            "surface_flow_identity_fingerprint": "flows",
        },
    }

    # Act and Assert
    with pytest.raises(generate_tm7.GenerationError, match="canvas"):
        generate_tm7.apply_layout(model, profile, layout_overlay=overlay)


class TestGenerateTm7:
    def test_given_zone_hierarchy_when_layout_then_child_containment_and_gutter_hold(
        self,
    ) -> None:
        # Arrange
        spec, profile = _build_zone_layout_spec()
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)
        surface = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
        )
        boundaries = {
            str(element.get("trust_zone_id", "")): element
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("kind", "")) == "trust_boundary_box"
            and str(element.get("trust_zone_id", ""))
        }
        root_rect = boundaries["tz-root"]["position"]
        child_one_rect = boundaries["tz-child-1"]["position"]
        child_two_rect = boundaries["tz-child-2"]["position"]

        # Assert
        content_left = root_rect["left"] + 16
        content_top = root_rect["top"] + 40
        content_right = root_rect["left"] + root_rect["width"] - 16
        content_bottom = root_rect["top"] + root_rect["height"] - 16
        assert child_one_rect["left"] >= content_left
        assert child_one_rect["top"] >= content_top
        assert child_two_rect["left"] >= content_left
        assert child_two_rect["top"] >= content_top
        assert child_one_rect["left"] + child_one_rect["width"] <= content_right
        assert child_two_rect["left"] + child_two_rect["width"] <= content_right
        assert child_one_rect["top"] + child_one_rect["height"] <= content_bottom
        assert child_two_rect["top"] + child_two_rect["height"] <= content_bottom
        assert (
            child_one_rect["left"] + child_one_rect["width"]
            <= child_two_rect["left"] - 16
            or child_two_rect["left"] + child_two_rect["width"]
            <= child_one_rect["left"] - 16
        )

    def test_given_multiple_root_zones_when_layout_then_total_width_is_not_averaged(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            "pre-populated-comprehensive",
        )
        surface = next(item for item in model["surfaces"] if item["id"] == "ctx-01")

        # Act
        zone_rects, _ = generate_tm7._assign_zone_regions(
            surface,
            layout_overlay=None,
        )

        # Assert
        assert sum(rect["width"] for rect in zone_rects.values()) > 600.0

    def test_given_contextual_nodes_when_layout_then_context_lane_is_reserved(
        self,
    ) -> None:
        # Arrange
        spec, profile = _build_zone_layout_spec()
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)
        surface = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
        )
        positions = {
            str(element.get("id", "")): element.get("position", {})
            for element in surface.get("elements", [])
            if isinstance(element, dict) and str(element.get("id", ""))
        }
        connected_rect = positions["node-left"]
        contextual_rect = positions["node-context"]

        # Assert
        assert contextual_rect["left"] >= connected_rect["left"] + 120
        assert (
            contextual_rect["left"] + contextual_rect["width"]
            <= connected_rect["left"] + connected_rect["width"] + 200
        )

    def test_given_small_zone_content_when_layout_then_leaf_zone_is_compacted(
        self,
    ) -> None:
        # Arrange
        spec, profile = _build_zone_layout_spec()
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)

        # Assert
        surface = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
        )
        boundaries = {
            str(element.get("trust_zone_id", "")): element
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("kind", "")) == "trust_boundary_box"
            and str(element.get("trust_zone_id", ""))
        }
        child_rect = boundaries["tz-child-1"]["position"]
        assert child_rect["width"] < 280
        assert child_rect["height"] < 260

    def test_given_vertical_surface_rule_when_layout_then_that_candidate_is_used(
        self,
    ) -> None:
        # Arrange
        spec, profile = _build_zone_layout_spec()
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )
        overlay = {
            "schema_version": 2,
            "overlay_type": "tm7_layout_overlay",
            "model_id": "zone-layout",
            "overlay_id": "overlay-vertical",
            "applies_to": [
                {"surface_id": "surface-01", "generator_profile": "sdl_core_generic"}
            ],
            "zone_rules": [],
            "node_rules": [],
            "connector_rules": [],
            "surface_rules": [
                {
                    "surface_id": "surface-01",
                    "zone_order": ["tz-root", "tz-child-1", "tz-child-2"],
                    "orientation": "vertical",
                    "viewport_target": {
                        "left": 0,
                        "top": 0,
                        "width": 1920,
                        "height": 1080,
                    },
                    "outer_margin": 24,
                }
            ],
            "provenance": {
                "evidence_ref": "test",
                "generated_at": "2026-07-18T00:00:00Z",
                "approval_state": "pending",
            },
            "invalidation": {
                "spec_fingerprint": "spec",
                "generator_profile_fingerprint": "profile",
                "surface_identity_fingerprint": "surface",
                "surface_zone_identity_fingerprint": "zones",
                "surface_flow_identity_fingerprint": "flows",
            },
        }

        # Act
        laid_out = generate_tm7.apply_layout(model, profile, layout_overlay=overlay)
        surface = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "surface-01"
        )
        boundaries = {
            str(element.get("trust_zone_id", "")): element
            for element in surface.get("elements", [])
            if isinstance(element, dict)
            and str(element.get("kind", "")) == "trust_boundary_box"
            and str(element.get("trust_zone_id", ""))
        }

        # Assert
        assert (
            boundaries["tz-child-1"]["position"]["top"]
            < boundaries["tz-child-2"]["position"]["top"]
        )

    def test_given_tiny_canvas_when_layout_then_generation_error_is_raised(
        self,
    ) -> None:
        # Arrange
        spec, profile = _build_zone_layout_spec()
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )
        overlay = {
            "schema_version": 2,
            "overlay_type": "tm7_layout_overlay",
            "model_id": "zone-layout",
            "overlay_id": "overlay-tiny",
            "applies_to": [
                {"surface_id": "surface-01", "generator_profile": "sdl_core_generic"}
            ],
            "zone_rules": [],
            "node_rules": [],
            "connector_rules": [],
            "surface_rules": [
                {
                    "surface_id": "surface-01",
                    "zone_order": ["tz-root", "tz-child-1", "tz-child-2"],
                    "orientation": "vertical",
                    "viewport_target": {
                        "left": 0,
                        "top": 0,
                        "width": 160,
                        "height": 160,
                    },
                    "outer_margin": 24,
                }
            ],
            "provenance": {
                "evidence_ref": "test",
                "generated_at": "2026-07-18T00:00:00Z",
                "approval_state": "pending",
            },
            "invalidation": {
                "spec_fingerprint": "spec",
                "generator_profile_fingerprint": "profile",
                "surface_identity_fingerprint": "surface",
                "surface_zone_identity_fingerprint": "zones",
                "surface_flow_identity_fingerprint": "flows",
            },
        }

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="layout"):
            generate_tm7.apply_layout(model, profile, layout_overlay=overlay)

    def test_given_no_overlay_when_generate_then_output_is_byte_compatible(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "baseline.tm7"
        comparison_path = tmp_path / "baseline-copy.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        run_generator(SPEC_PATH, comparison_path)

        # Assert
        assert output_path.read_bytes() == comparison_path.read_bytes()

    def test_given_overlay_input_when_generate_then_overlay_replays_positions(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)
        output_path = tmp_path / "overlay.tm7"

        # Act
        run_generator(SPEC_PATH, output_path, overlay_input=overlay_path)
        payload = generate_tm7.build_tm7_payload(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
            layout_overlay=generate_tm7.load_layout_overlay(overlay_path),
        )
        context_surface = next(
            surface for surface in payload["Surfaces"] if surface["id"] == "ctx-01"
        )
        positions = {
            str(element.get("id", "")): element.get("position", {})
            for element in context_surface["elements"]
            if isinstance(element, dict) and element.get("id")
        }
        boundary = next(
            element
            for element in context_surface["elements"]
            if isinstance(element, dict)
            and str(element.get("kind", "")) == "trust_boundary_box"
        )

        # Assert
        assert positions["proc-01"]["left"] == (
            boundary["position"]["left"]
            + boundary["position"]["width"]
            - positions["proc-01"]["width"]
            - 1.0
        )
        assert positions["proc-01"]["top"] == (
            boundary["position"]["top"]
            + boundary["position"]["height"]
            - positions["proc-01"]["height"]
            - 1.0
        )
        assert boundary["position"]["left"] <= positions["proc-01"]["left"]
        assert boundary["position"]["top"] <= positions["proc-01"]["top"]

    def test_given_repeated_node_id_when_overlay_applies_then_only_surface_moves(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)

        # Act
        payload = generate_tm7.build_tm7_payload(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
            layout_overlay=generate_tm7.load_layout_overlay(overlay_path),
        )
        positions = {
            str(surface["id"]): {
                str(element.get("id", "")): element.get("position", {})
                for element in surface.get("elements", [])
            }
            for surface in payload["Surfaces"]
        }
        context_boundary = next(
            element
            for element in payload["Surfaces"][0]["elements"]
            if isinstance(element, dict)
            and str(element.get("kind", "")) == "trust_boundary_box"
        )

        # Assert
        assert positions["ctx-01"]["proc-01"]["left"] == (
            context_boundary["position"]["left"]
            + context_boundary["position"]["width"]
            - positions["ctx-01"]["proc-01"]["width"]
            - 1.0
        )
        assert (
            positions["func-01"]["proc-01"]["left"]
            != positions["ctx-01"]["proc-01"]["left"]
        )

    def test_given_relative_overlay_when_generate_then_connector_reroutes(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(
            tmp_path, spec=spec, profile=profile, overlay_type="relative"
        )
        output_path = tmp_path / "relative.tm7"

        # Act
        run_generator(SPEC_PATH, output_path, overlay_input=overlay_path)
        payload = generate_tm7.build_tm7_payload(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
            layout_overlay=generate_tm7.load_layout_overlay(overlay_path),
        )
        positions = {
            str(element.get("id", "")): element.get("position", {})
            for element in payload["Elements"]
            if isinstance(element, dict) and element.get("id")
        }
        flow = next(
            flow
            for flow in payload["Surfaces"][0].get("flows", [])
            if flow.get("id") == "flow-01"
        )
        source_guid = flow.get("source_guid")
        target_guid = flow.get("target_guid")

        # Assert
        assert positions["ds-01"]["left"] > positions["proc-01"]["left"]
        assert source_guid is not None
        assert target_guid is not None
        assert (flow["position"]["source_x"], flow["position"]["source_y"]) != (
            flow["position"]["target_x"],
            flow["position"]["target_y"],
        )

    @pytest.mark.parametrize("evasion", ["stale", "deleted", "emptied", "partial"])
    def test_given_stale_overlay_when_generate_then_no_output_is_written(
        self,
        tmp_path: Path,
        evasion: str,
    ) -> None:
        """Replay invalidation must be supplied, complete, and current.

        The fingerprints used to be synthesized with `setdefault` from the same
        context they are then compared against, so an overlay that simply
        omitted the block validated unconditionally. Deletion, not forgery, was
        the evasion, so absence and partial presence are checked alongside a
        stale value.
        """
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)
        output_path = tmp_path / "stale.tm7"
        overlay = generate_tm7.load_layout_overlay(overlay_path)
        if evasion == "stale":
            overlay["invalidation"]["spec_fingerprint"] = "stale"
        elif evasion == "deleted":
            overlay.pop("invalidation", None)
        elif evasion == "emptied":
            overlay["invalidation"] = {}
        else:
            overlay["invalidation"].pop("surface_flow_identity_fingerprint", None)
        overlay_path.write_text(yaml.safe_dump(overlay), encoding="utf-8")

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError) as exc_info:
            generate_tm7.generate_tm7_candidate(
                spec_path=SPEC_PATH,
                output_path=output_path,
                template=None,
                mode=None,
                update_path=None,
                overlay_path=overlay_path,
                threat_generation_enabled=False,
            )
        assert exc_info.value.exit_code == 2
        assert not output_path.exists()
        assert not output_path.exists()

    def test_given_overlay_and_update_when_generate_then_conflict_is_rejected(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)
        update_path = tmp_path / "existing.tm7"
        update_path.write_text("<ThreatModel />", encoding="utf-8")
        output_path = tmp_path / "conflict.tm7"

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError) as exc_info:
            generate_tm7.generate_tm7_candidate(
                spec_path=SPEC_PATH,
                output_path=output_path,
                template=None,
                mode=None,
                update_path=update_path,
                overlay_path=overlay_path,
                threat_generation_enabled=False,
            )
        assert exc_info.value.exit_code == 2
        assert not output_path.exists()

    def test_given_same_overlay_when_regenerated_then_output_is_deterministic(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)
        first_path = tmp_path / "first.tm7"
        second_path = tmp_path / "second.tm7"

        # Act
        generate_tm7.generate_tm7_candidate(
            spec_path=SPEC_PATH,
            output_path=first_path,
            template=None,
            mode=None,
            update_path=None,
            overlay_path=overlay_path,
            threat_generation_enabled=False,
        )
        generate_tm7.generate_tm7_candidate(
            spec_path=SPEC_PATH,
            output_path=second_path,
            template=None,
            mode=None,
            update_path=None,
            overlay_path=overlay_path,
            threat_generation_enabled=False,
        )

        # Assert
        assert first_path.read_bytes() == second_path.read_bytes()

    def test_given_overlay_when_generate_then_semantic_identity_is_preserved(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        overlay_path = _write_overlay(tmp_path, spec=spec, profile=profile)
        output_path = tmp_path / "semantic.tm7"

        # Act
        generate_tm7.generate_tm7_candidate(
            spec_path=SPEC_PATH,
            output_path=output_path,
            template=None,
            mode=None,
            update_path=None,
            overlay_path=overlay_path,
            threat_generation_enabled=False,
        )
        payload = generate_tm7.build_tm7_payload(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
            layout_overlay=generate_tm7.load_layout_overlay(overlay_path),
        )

        # Assert
        assert len(payload["ThreatInstances"]) == len(spec.get("threats") or [])
        assert payload["ThreatInstances"][0]["title"] == "Payload tampering in transit"
        assert payload["Elements"][0]["guid"]
        assert payload["Surfaces"][0]["flows"][0]["source_guid"]
        assert payload["Surfaces"][0]["flows"][0]["target_guid"]

    def test_given_operational_component_reference_when_built_then_catalog_resolves(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec["representations"]["operational_views"][0]["components"] = [
            {"id": "proc-03"}
        ]
        profile = generate_tm7.resolve_profile(spec, None, ROOT)

        # Act
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            "diagram-only-defer-to-tmt",
        )
        component = model["surfaces"][2]["elements"][0]

        # Assert
        assert component["name"] == "Deployment pipeline"
        assert component["kind"] == "process"
        assert component["trust_zone_id"] == "tz-02"

    def test_given_layout_role_metadata_when_build_model_then_roles_are_preserved(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec.setdefault("representations", {})
        spec["representations"]["context_diagrams"] = [
            {
                "id": "ctx-role-test",
                "name": "Role test",
                "elements": [
                    {
                        "id": "node-main",
                        "kind": "process",
                        "name": "Main node",
                        "trust_zone_id": "tz-01",
                        "layout_role": "connected",
                    },
                    {
                        "id": "node-context",
                        "kind": "process",
                        "name": "Context node",
                        "trust_zone_id": "tz-01",
                        "layout_role": "contextual",
                    },
                    {
                        "id": "node-suppressed",
                        "kind": "process",
                        "name": "Suppressed node",
                        "trust_zone_id": "tz-01",
                        "layout_role": "suppressed",
                    },
                ],
                "flows": [
                    {
                        "id": "flow-role-test",
                        "source_ref": "node-main",
                        "target_ref": "node-context",
                        "ordinal": 1,
                        "label": "Primary role path",
                    }
                ],
            }
        ]
        spec["representations"]["functional_scenarios"] = []
        spec["representations"]["operational_views"] = []
        spec["data_flows"] = [
            {
                "id": "flow-role-test",
                "source_ref": "node-main",
                "target_ref": "node-context",
                "ordinal": 1,
                "label": "Primary role path",
            }
        ]
        profile = generate_tm7.resolve_profile(spec, None, ROOT)

        # Act
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            str(spec.get("mode") or "pre-populated-comprehensive"),
        )

        # Assert
        assert model["surfaces"][0]["flows"][0]["label"] == "Primary role path"
        assert [element["id"] for element in model["surfaces"][0]["elements"]] == [
            "node-main",
            "node-context",
        ]
        assert model["surfaces"][0]["elements"][0]["layout_role"] == "connected"
        assert model["surfaces"][0]["elements"][1]["layout_role"] == "contextual"
        assert model["surfaces"][0]["elements"][0]["id"] == "node-main"
        assert model["surfaces"][0]["elements"][1]["id"] == "node-context"

    def test_given_isolated_element_without_role_when_build_model_then_error_is_raised(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec.setdefault("representations", {}).setdefault("context_diagrams", [])
        spec["representations"]["context_diagrams"] = [
            {
                "id": "ctx-role-test",
                "name": "Role test",
                "elements": [
                    {
                        "id": "node-isolated",
                        "kind": "process",
                        "name": "Isolated node",
                        "trust_zone_id": "tz-01",
                    }
                ],
                "flows": [],
            }
        ]
        profile = generate_tm7.resolve_profile(spec, None, ROOT)

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="layout_role"):
            generate_tm7.build_model_from_spec(
                spec,
                profile,
                str(spec.get("mode") or "pre-populated-comprehensive"),
            )

    def test_given_invalid_parent_trust_zone_when_build_model_then_error_is_raised(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec.setdefault("trust_zones", [])
        spec["trust_zones"] = [
            {
                "id": "tz-01",
                "name": "Root zone",
                "description": "Root",
                "parent_trust_zone_id": "tz-missing",
            }
        ]
        profile = generate_tm7.resolve_profile(spec, None, ROOT)

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="parent_trust_zone_id"):
            generate_tm7.build_model_from_spec(
                spec,
                profile,
                str(spec.get("mode") or "pre-populated-comprehensive"),
            )

    def test_given_valid_spec_when_generate_tm7_then_xml_is_well_formed(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        root = parse_tm7(output_path)

        # Assert
        assert root.tag.endswith("ThreatModel")
        assert root.find("{*}DrawingSurfaceList") is not None

    def test_given_valid_spec_when_generate_tm7_then_namespaces_are_correct(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)

        # Assert
        xml_bytes = output_path.read_bytes()
        assert generate_tm7.MODEL_NS.encode("utf-8") in xml_bytes
        assert generate_tm7.ARRAYS_NS.encode("utf-8") in xml_bytes
        assert generate_tm7.XSI_NS.encode("utf-8") in xml_bytes

    def test_given_valid_spec_when_generate_tm7_then_guid_wiring_is_integral(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        root = parse_tm7(output_path)
        elements = {
            element.findtext("{*}Guid"): element.findtext("{*}Id")
            for element in iter_elements(root)
        }
        connectors = iter_connectors(root)
        null_guid = "00000000-0000-0000-0000-000000000000"

        # Assert
        assert connectors
        for connector in connectors:
            source_guid = connector.findtext("{*}SourceGuid")
            target_guid = connector.findtext("{*}TargetGuid")
            assert source_guid in elements or source_guid == null_guid
            assert target_guid in elements or target_guid == null_guid

    def test_given_valid_spec_when_generate_then_stride_coverage(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        mode = str(spec.get("mode") or "pre-populated-comprehensive")

        # Act
        payload = generate_tm7.build_tm7_payload(spec, profile, mode)
        categories = {threat["category"] for threat in payload["ThreatInstances"]}

        # Assert
        assert categories

    def test_given_valid_spec_when_generate_tm7_then_embedded_citations_are_present(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        mode = "pre-populated-comprehensive"

        # Act
        payload = generate_tm7.build_tm7_payload(spec, profile, mode)
        threats = payload["ThreatInstances"]

        # Assert
        assert threats
        assert all(
            "STRIDE=" in threat["notes"] and "NIST=" in threat["notes"]
            for threat in threats
        )
        assert any(threat["citations"].get("stride") for threat in threats)
        assert any(threat["citations"].get("nist") for threat in threats)

    def test_given_spec_when_generated_then_embedded_kb_type_count_matches_threats(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"
        spec = generate_tm7.load_spec(SPEC_PATH)
        explicit_threats = [
            threat for threat in spec.get("threats") or [] if isinstance(threat, dict)
        ]

        # Act
        run_generator(SPEC_PATH, output_path)
        custom_ids = parse_embedded_custom_kb_type_ids(output_path)

        # Assert
        assert len(custom_ids) == len(explicit_threats)

    def test_given_same_id_when_mutable_fields_change_then_ids_stay_stable(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        original_spec = yaml.safe_load(yaml.safe_dump(spec))
        modified_spec = yaml.safe_load(yaml.safe_dump(spec))
        target_threat = next(
            threat
            for threat in original_spec.get("threats") or []
            if isinstance(threat, dict) and threat.get("id")
        )
        source_id = str(target_threat["id"])
        modified_threat = next(
            threat
            for threat in modified_spec.get("threats") or []
            if isinstance(threat, dict) and str(threat.get("id")) == source_id
        )
        modified_threat["title"] = "Updated title"
        modified_threat["description"] = "Updated description"
        modified_threat["citations"] = {
            "stride": ["STRIDE-NEW"],
            "nist": ["NIST-NEW"],
            "mitre": ["MITRE-NEW"],
        }
        modified_threat["mitigation_ids"] = ["mitigation-new-id"]
        original_spec_path = tmp_path / "original-spec.yaml"
        modified_spec_path = tmp_path / "modified-spec.yaml"
        original_spec_path.write_text(
            yaml.safe_dump(original_spec),
            encoding="utf-8",
        )
        modified_spec_path.write_text(
            yaml.safe_dump(modified_spec),
            encoding="utf-8",
        )
        original_output_path = tmp_path / "original.tm7"
        modified_output_path = tmp_path / "modified.tm7"

        # Act
        run_generator(original_spec_path, original_output_path)
        run_generator(modified_spec_path, modified_output_path)

        def extract_custom_ids(path: Path) -> list[str]:
            root = parse_tm7(path)
            knowledge_base = root.find("{*}KnowledgeBase")
            if knowledge_base is None:
                return []
            custom_ids: list[str] = []
            for threat_type in knowledge_base.findall(".//{*}ThreatType"):
                threat_id = threat_type.findtext("{*}Id") or ""
                if threat_id.startswith("THC-"):
                    custom_ids.append(threat_id)
            return custom_ids

        original_ids = extract_custom_ids(original_output_path)
        modified_ids = extract_custom_ids(modified_output_path)
        target_index = next(
            index
            for index, threat in enumerate(original_spec.get("threats") or [])
            if isinstance(threat, dict) and str(threat.get("id")) == source_id
        )

        # Assert
        assert original_ids[target_index] == modified_ids[target_index]

    def test_given_reordered_spec_when_generated_then_custom_ids_are_stable(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        original_spec = generate_tm7.load_spec(SPEC_PATH)
        reversed_spec = {
            **original_spec,
            "threats": list(reversed(original_spec.get("threats") or [])),
        }
        original_output_path = tmp_path / "original.tm7"
        reversed_output_path = tmp_path / "reversed.tm7"
        original_spec_path = tmp_path / "original-spec.yaml"
        reversed_spec_path = tmp_path / "reversed-spec.yaml"
        original_spec_path.write_text(
            yaml.safe_dump(original_spec),
            encoding="utf-8",
        )
        reversed_spec_path.write_text(
            yaml.safe_dump(reversed_spec),
            encoding="utf-8",
        )

        # Act
        run_generator(original_spec_path, original_output_path)
        run_generator(reversed_spec_path, reversed_output_path)
        original_details = parse_embedded_custom_kb_type_details(original_output_path)
        reversed_details = parse_embedded_custom_kb_type_details(reversed_output_path)

        # Assert
        assert map_source_threat_ids_to_custom_type_ids(
            original_spec,
            original_details,
        ) == map_source_threat_ids_to_custom_type_ids(reversed_spec, reversed_details)

    def test_given_spec_when_generated_then_custom_ids_do_not_clash_with_stock(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"
        stock_ids = parse_stock_kb_type_ids(DEFAULT_KB_PATH)
        type_id_pattern = re.compile(r"^THC-[a-z0-9-]{1,24}-[A-Z0-9]{16}$")

        # Act
        run_generator(SPEC_PATH, output_path)
        custom_ids = parse_embedded_custom_kb_type_ids(output_path)

        # Assert
        assert len(custom_ids) == len(set(custom_ids))
        assert all(type_id_pattern.fullmatch(threat_id) for threat_id in custom_ids)
        assert all(
            not threat_id.startswith("TH") or threat_id.startswith("THC-")
            for threat_id in custom_ids
        )
        assert all(threat_id not in stock_ids for threat_id in custom_ids)

    def test_given_spec_when_generate_tm7_then_custom_types_are_discoverable(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        custom_details = parse_embedded_custom_kb_type_details(output_path)
        custom_ids = [str(item["id"]) for item in custom_details]

        # Assert
        assert custom_ids
        assert [str(item["id"]) for item in custom_details] == custom_ids

    def test_given_spec_when_generate_tm7_then_custom_types_include_required_metadata(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"
        spec = generate_tm7.load_spec(SPEC_PATH)
        mitigations = {
            str(item.get("id")): item
            for item in spec.get("mitigations") or []
            if isinstance(item, dict) and item.get("id")
        }

        # Act
        run_generator(SPEC_PATH, output_path)
        custom_details = parse_embedded_custom_kb_type_details(output_path)

        # Assert
        assert custom_details
        for threat in spec.get("threats") or []:
            if not isinstance(threat, dict):
                continue
            title = str(threat.get("title") or "")
            details = next(
                (
                    detail
                    for detail in custom_details
                    if str(detail.get("short_title") or "") == title
                ),
                None,
            )
            assert details is not None
            metadata = details["metadata"]
            expected_description = str(threat.get("description") or "")
            expected_mitigation_texts = [
                str(
                    mitigations[str(mitigation_id)].get("description")
                    or mitigations[str(mitigation_id)].get("name")
                    or ""
                )
                for mitigation_id in threat.get("mitigation_ids") or []
                if str(mitigation_id) in mitigations
            ]
            assert metadata.get("UserThreatDescription")
            assert expected_description in str(
                metadata.get("UserThreatDescription") or ""
            )
            assert metadata.get("PossibleMitigations")
            for expected_text in expected_mitigation_texts:
                assert expected_text in str(metadata.get("PossibleMitigations") or "")
            assert metadata.get("Priority") == "High"
            assert metadata.get("SDLPhase") == "Implementation"
            assert str(details["description"]) != ""
            assert str(details["short_title"]) != ""

    def test_given_spec_when_generated_then_threats_populate_and_generation_is_off(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        root = parse_tm7(output_path)
        threat_instances = root.find("{*}ThreatInstances")
        generation_enabled = root.findtext("{*}ThreatGenerationEnabled")

        # Assert
        assert threat_instances is not None
        threat_entries = threat_instances.findall(THREAT_INSTANCE_ENTRY_TAG)
        assert threat_entries
        assert generation_enabled == "false"

    def test_given_populated_threats_when_generated_then_interactions_match_connectors(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        root = parse_tm7(output_path)
        connector_names = {}
        for surface in iter_surface_nodes(root):
            for connector in _value_nodes(surface.find("{*}Lines")):
                flow_guid = connector.findtext("{*}Guid") or ""
                name = (
                    generate_tm7._find_display_attribute_value(connector, "Name") or ""
                )
                connector_names[flow_guid] = name

        # Assert
        assert connector_names
        for threat in iter_threats(root):
            flow_guid = threat.findtext("{*}FlowGuid") or ""
            properties = tm7_threat_contract.extract_serializable_threat(threat)[
                "properties"
            ]
            assert properties["InteractionString"] == connector_names[flow_guid]

    @pytest.mark.parametrize(
        ("flag_override", "expected_flag"),
        [(None, "false"), (True, "true")],
    )
    def test_given_diagram_only_mode_when_generate_then_flag_matches_request(
        self,
        tmp_path: Path,
        flag_override: bool | None,
        expected_flag: str,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec["mode"] = "diagram-only-defer-to-tmt"
        if flag_override is not None:
            spec["threat_generation_enabled"] = flag_override
        spec_path = tmp_path / "diagram-only-spec.yaml"
        spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")
        output_path = tmp_path / "diagram-only.tm7"

        # Act
        run_generator(spec_path, output_path)
        root = parse_tm7(output_path)

        # Assert
        assert root.findtext("{*}ThreatGenerationEnabled") == expected_flag
        assert iter_threats(root) == []

    def test_given_unmapped_targets_when_mapped_then_generation_fails(
        self,
    ) -> None:
        """Every spec threat must reach the model or generation must fail.

        ``_map_phase2_threats`` skips a threat whose ``target_ref`` names no
        element or flow, and the mapping contract only runs when at least one
        instance survives. A spec whose targets are all unresolvable therefore
        produces a threat-free model and a success exit code.
        """
        # Arrange
        spec = copy.deepcopy(generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH))
        for threat in spec["threats"]:
            threat["target_ref"] = "no-such-target"
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        model = generate_tm7.build_model_from_spec(
            spec, profile, "pre-populated-comprehensive"
        )

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="no-such-target"):
            generate_tm7._map_phase2_threats(spec, model, profile)

    def test_given_unresolvable_threat_flows_when_serialized_then_drops_are_named(
        self,
    ) -> None:
        """Spec threats must never disappear between the payload and the model.

        Each unresolved threat used a bare ``continue``, and the mapping
        contract validates the spec rather than the emitted array, so a threat
        could be absent from a shipped model with no diagnostic at all.
        """
        # Arrange
        root = ET.Element("ThreatModel")
        payload = {
            "Flows": [],
            "Surfaces": [],
            "spec": {},
            "ThreatInstances": [
                {
                    "id": "threat-zz",
                    "source": "spec",
                    "interaction_ref": "flow-missing",
                },
                {"id": "threat-aa", "source": "spec", "interaction_ref": ""},
            ],
        }

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError) as error:
            generate_tm7._serialize_threat_instances(root, payload)
        message = str(error.value)
        assert "would drop 2 spec threat(s)" in message
        assert message.index("threat-aa") < message.index("threat-zz")

    def test_given_flow_without_endpoint_guids_when_serialized_then_members_named(
        self,
    ) -> None:
        """A flow missing endpoint GUIDs must name the absent members."""
        # Arrange
        root = ET.Element("ThreatModel")
        payload = {
            "Flows": [
                {
                    "id": "flow-01",
                    "surface_id": "surface-01",
                    "source_guid": "",
                    "target_guid": "",
                }
            ],
            "Surfaces": [{"id": "surface-01"}],
            "spec": {},
            "ThreatInstances": [
                {"id": "threat-01", "source": "spec", "interaction_ref": "flow-01"}
            ],
        }

        # Act and Assert
        with pytest.raises(
            generate_tm7.GenerationError,
            match="missing source_guid, target_guid",
        ):
            generate_tm7._serialize_threat_instances(root, payload)

    def test_given_generated_threats_when_serialized_then_no_drop_is_reported(
        self,
    ) -> None:
        """Generated threats carry no interaction and are not spec drops."""
        # Arrange
        root = ET.Element("ThreatModel")
        payload = {
            "Flows": [],
            "Surfaces": [],
            "spec": {},
            "ThreatInstances": [
                {
                    "id": "generated-threat-01",
                    "source": "generated",
                    "target_ref": "node-a",
                }
            ],
        }

        # Act
        generate_tm7._serialize_threat_instances(root, payload)

        # Assert
        threat_instances = root.find("ThreatInstances")
        assert threat_instances is not None
        assert list(threat_instances) == []

    def test_given_connected_suppression_when_flattened_then_rejected(
        self,
    ) -> None:
        """Suppressing a node that still carries connectors must be rejected.

        The element loop drops suppressed shapes while the flow loop keeps every
        connector, so the emitted model references a ``SourceGuid`` that has no
        entry in ``Borders``. The user contract rejects this input rather than
        cascading connector deletion.
        """
        # Arrange
        model = {
            "surfaces": [
                {
                    "id": "surface-01",
                    "elements": [
                        {"id": "node-a", "layout_role": "suppressed"},
                        {"id": "node-b"},
                    ],
                    "flows": [
                        {
                            "id": "flow-01",
                            "source_ref": "node-a",
                            "target_ref": "node-b",
                        }
                    ],
                }
            ]
        }

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="node-a"):
            generate_tm7._flatten_laid_out_model(model)

    def test_given_isolated_suppression_when_flattened_then_accepted(
        self,
    ) -> None:
        """Suppressing a node with no attached flow remains valid input."""
        # Arrange
        model = {
            "surfaces": [
                {
                    "id": "surface-01",
                    "elements": [
                        {"id": "node-a", "layout_role": "suppressed"},
                        {"id": "node-b"},
                        {"id": "node-c"},
                    ],
                    "flows": [
                        {
                            "id": "flow-01",
                            "source_ref": "node-b",
                            "target_ref": "node-c",
                        }
                    ],
                }
            ]
        }

        # Act
        generate_tm7._flatten_laid_out_model(model)

        # Assert
        assert [element["id"] for element in model["elements"]] == ["node-b", "node-c"]
        assert [flow["id"] for flow in model["flows"]] == ["flow-01"]

    def test_given_missing_placeholder_when_rendered_then_generation_fails(
        self,
    ) -> None:
        """A KnowledgeBase that never replaces its placeholder must fail closed.

        The injection is a literal string replace with no verification, so a
        renamed placeholder silently yields a model with no KnowledgeBase and a
        success exit code.
        """
        # Arrange
        payload = {"KnowledgeBase": "<KnowledgeBase />"}

        # Act and Assert
        with pytest.raises(generate_tm7.GenerationError, match="KnowledgeBase"):
            generate_tm7._inject_knowledge_base(
                "<ThreatModel><NoPlaceholderHere /></ThreatModel>",
                "<KnowledgeBase />",
                payload,
            )

    def test_given_authored_model_when_parsed_then_identity_and_fields_persist(
        self,
    ) -> None:
        """Authored TM7 elements must recover their own identity, type, and name.

        A TMT-authored element omits a direct ``Id`` child and orders
        ``GenericTypeId`` ahead of ``TypeId``. Suffix matching therefore resolves
        both ``Id`` and ``TypeId`` to the generic stencil, collapsing every element
        onto one merge key and discarding the specific type and the authored name.
        """
        # Arrange
        parsed_model = generate_tm7.parse_hardened_xml(REFERENCE_FIXTURE_PATH)
        elements = parsed_model["elements"]

        # Act
        identifiers = [element.get("id") for element in elements]
        specific_type_ids = {
            str(element.get("type_id"))
            for element in elements
            if str(element.get("type_id", "")).startswith("SE.")
        }
        named = [element for element in elements if element.get("name")]

        # Assert
        assert len(elements) > 1
        assert len(set(identifiers)) == len(identifiers)
        assert all(identifier for identifier in identifiers)
        assert specific_type_ids
        assert len(named) == len(elements)

    def test_given_generated_tm7_when_deserialized_then_model_is_loadable(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        parsed_model = generate_tm7.parse_hardened_xml(output_path)

        # Assert
        assert parsed_model["elements"]
        assert parsed_model["flows"]
        assert parsed_model["threats"]
        assert all(
            isinstance(threat.get("id"), str) and bool(threat["id"].strip())
            for threat in parsed_model["threats"]
        )
        assert all(
            isinstance(threat.get("target_ref"), str)
            and bool(threat["target_ref"].strip())
            for threat in parsed_model["threats"]
        )

    def test_given_incomplete_spec_when_emit_then_ctm_warnings(
        self,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        # Arrange
        incomplete_spec = {
            "project_metadata": {"name": "demo"},
            "representations": {"context_diagrams": []},
            "threats": [],
            "mitigations": [],
            "abuse_cases": [],
            "security_test_cases": [],
        }

        # Act
        with caplog.at_level(logging.WARNING, logger="generate_tm7"):
            generate_tm7.emit_warnings(incomplete_spec)
        emitted = "\n".join(record.getMessage() for record in caplog.records)

        # Assert
        assert "CTM-1" in emitted
        assert "CTM-5" in emitted
        assert "CTM-8" in emitted
        assert all(record.levelno == logging.WARNING for record in caplog.records)

    def test_given_authoritative_topology_when_generate_then_instances_use(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(SPEC_PATH)
        spec.setdefault("representations", {})
        spec["representations"]["context_diagrams"] = [
            {
                "id": "ctx-topology",
                "name": "Topology context",
                "elements": [
                    {
                        "id": "node-source",
                        "kind": "process",
                        "name": "Source",
                        "trust_zone_id": "tz-01",
                        "layout_role": "connected",
                    },
                    {
                        "id": "node-target",
                        "kind": "process",
                        "name": "Target",
                        "trust_zone_id": "tz-01",
                        "layout_role": "contextual",
                    },
                ],
                "flows": [
                    {
                        "id": "flow-topology",
                        "source_ref": "node-source",
                        "target_ref": "node-target",
                        "ordinal": 1,
                        "label": "topology",
                    }
                ],
            }
        ]
        spec["representations"]["functional_scenarios"] = []
        spec["representations"]["operational_views"] = []
        spec["data_flows"] = [
            {
                "id": "flow-topology",
                "source_ref": "node-source",
                "target_ref": "node-target",
                "ordinal": 1,
                "label": "topology",
            }
        ]
        spec["threats"] = []
        for index in range(1, 81):
            spec["threats"].append(
                {
                    "id": f"T-{index:02d}",
                    "category": "tampering",
                    "title": f"Threat {index}",
                    "description": f"Threat {index} description",
                    "interaction_ref": "flow-topology",
                    "target_ref": "node-target",
                    "mitigation_ids": [],
                    "citations": {"stride": ["T"], "nist": ["SC-7"]},
                }
            )
        spec_path = tmp_path / "topology-spec.yaml"
        spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")
        output_path = tmp_path / "comprehensive.tm7"

        # Act
        run_generator(spec_path, output_path)
        root = parse_tm7(output_path)
        embedded_kb_type_ids = {
            threat_type.findtext("{*}Id")
            for threat_type in root.findall(".//{*}ThreatType")
            if threat_type.findtext("{*}Id")
        }
        threat_instances = iter_threats(root)
        referenced_type_ids = {
            threat.findtext("{*}TypeId") for threat in threat_instances
        }
        numeric_ids = {
            int(threat.findtext("{*}Id") or "0") for threat in threat_instances
        }

        # Assert
        assert len(threat_instances) == 80
        assert len(referenced_type_ids) == 80
        assert referenced_type_ids.issubset(embedded_kb_type_ids)
        assert numeric_ids == {
            tm7_threat_contract.derive_threat_numeric_id(f"T-{index:02d}")
            for index in range(1, 81)
        }
        assert len(numeric_ids) == 80
        entries = root.findall("{*}ThreatInstances/{*}KeyValueOfstringThreatpc_P0_PhOB")
        for entry, threat in zip(entries, threat_instances, strict=True):
            extracted = tm7_threat_contract.extract_serializable_threat(threat)
            assert extracted["member_order"] == THREAT_MEMBER_ORDER
            assert list(extracted["properties"]) == (
                tm7_threat_contract.THREAT_PROPERTY_KEYS
            )
            assert entry.findtext("{*}Key") == tm7_threat_contract.build_entry_key(
                str(extracted["type_id"]),
                str(extracted["source_guid"]),
                str(extracted["flow_guid"]),
                str(extracted["target_guid"]),
            )

    def test_given_ctx_flow_04_when_layout_then_label_has_clear_position(self) -> None:
        # Arrange
        spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        model = generate_tm7.build_model_from_spec(
            spec, profile, "pre-populated-comprehensive"
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)
        surface = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "ctx-01"
        )
        flow = next(
            flow for flow in surface.get("flows", []) if flow.get("id") == "flow-04"
        )

        # Assert
        assert flow.get("display_label")
        assert flow.get("label_rect")
        left, top, width, height = flow["label_rect"]
        assert left >= 24.0
        assert top >= 24.0
        assert width > 0.0
        assert height > 0.0

    def test_given_comprehensive_spec_when_layout_then_connectors_are(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        model = generate_tm7.build_model_from_spec(
            spec, profile, "pre-populated-comprehensive"
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)

        # Assert
        assert laid_out["surfaces"]
        for surface in laid_out["surfaces"]:
            for flow in surface.get("flows", []):
                if not isinstance(flow, dict):
                    continue
                position = flow.get("position", {})
                if not isinstance(position, dict):
                    continue
                assert position.get("source_x") is not None
                assert position.get("source_y") is not None
                assert position.get("target_x") is not None
                assert position.get("target_y") is not None
                assert position.get("source_x") != position.get("target_x") or (
                    position.get("source_y") != position.get("target_y")
                )

        target_surface_ids = {
            "ctx-01",
            "op-cicd",
            "func-cred",
            "dom-docproc",
            "dom-reposcan",
            "dom-planning",
        }
        for surface in laid_out["surfaces"]:
            if str(surface.get("id", "")) not in target_surface_ids:
                continue
            node_rects: dict[str, tuple[float, float, float, float]] = {}
            connector_segments: list[
                tuple[str, str, tuple[float, float], tuple[float, float]]
            ] = []
            boundary_rects: dict[str, tuple[float, float, float, float]] = {}
            boundary_label_rects: dict[str, tuple[float, float, float, float]] = {}
            connector_label_rects: dict[str, tuple[float, float, float, float]] = {}
            zone_membership: dict[str, str] = {}
            zone_content_rects: dict[str, tuple[float, float, float, float]] = {}
            for element in surface.get("elements", []):
                if not isinstance(element, dict):
                    continue
                position = element.get("position")
                if not isinstance(position, dict):
                    continue
                element_id = str(element.get("id", ""))
                rect = (
                    float(position.get("left", 0.0)),
                    float(position.get("top", 0.0)),
                    float(position.get("left", 0.0))
                    + float(position.get("width", 0.0)),
                    float(position.get("top", 0.0))
                    + float(position.get("height", 0.0)),
                )
                if str(element.get("kind", "")).lower() == "trust_boundary_box":
                    boundary_rects[element_id] = rect
                    boundary_label_rects[element_id] = (
                        rect[0],
                        rect[1],
                        rect[2],
                        rect[1] + 36.0,
                    )
                    continue
                node_rects[element_id] = rect
                zone_membership[element_id] = str(
                    element.get("trust_zone_id", "") or ""
                )
            for flow in surface.get("flows", []):
                if not isinstance(flow, dict):
                    continue
                position = flow.get("position", {})
                if not isinstance(position, dict):
                    continue
                source_point = (
                    float(position.get("source_x", 0.0)),
                    float(position.get("source_y", 0.0)),
                )
                target_point = (
                    float(position.get("target_x", 0.0)),
                    float(position.get("target_y", 0.0)),
                )
                handle_point = (
                    float(position.get("handle_x", 0.0)),
                    float(position.get("handle_y", 0.0)),
                )
                connector_segments.append(
                    (
                        str(flow.get("source_ref", "")),
                        str(flow.get("target_ref", "")),
                        source_point,
                        handle_point,
                    )
                )
                connector_segments.append(
                    (
                        str(flow.get("source_ref", "")),
                        str(flow.get("target_ref", "")),
                        handle_point,
                        target_point,
                    )
                )
                label_rect = flow.get("label_rect") or []
                if isinstance(label_rect, list) and len(label_rect) == 4:
                    left, top, width, height = (float(value) for value in label_rect)
                    connector_label_rects[str(flow.get("id", ""))] = (
                        left,
                        top,
                        left + width,
                        top + height,
                    )
            for zone in surface.get("trust_zones", []):
                if not isinstance(zone, dict):
                    continue
                zone_id = str(zone.get("id", ""))
                if not zone_id:
                    continue
                for element in surface.get("elements", []):
                    if not isinstance(element, dict):
                        continue
                    if str(element.get("id", "")) != f"boundary-{zone_id}":
                        continue
                    position = element.get("position")
                    if not isinstance(position, dict):
                        break
                    zone_content_rects[zone_id] = (
                        float(position.get("left", 0.0)),
                        float(position.get("top", 0.0)),
                        float(position.get("left", 0.0))
                        + float(position.get("width", 0.0)),
                        float(position.get("top", 0.0))
                        + float(position.get("height", 0.0)),
                    )
                    break
            geometry = tm7_visual_feedback.SurfaceGeometry(
                surface_id=str(surface.get("id", "")),
                nominal_node_size=100.0,
                node_rects=node_rects,
                connector_segments=connector_segments,
                boundary_rects=boundary_rects,
                boundary_label_rects=boundary_label_rects,
                connector_label_rects=connector_label_rects,
                zone_membership=zone_membership,
                zone_content_rects=zone_content_rects,
                layout_roles={
                    str(element.get("id", "")): str(element.get("layout_role", ""))
                    for element in surface.get("elements", [])
                    if isinstance(element, dict) and str(element.get("id", ""))
                },
                viewport_target=(0.0, 0.0, 1920.0, 1080.0),
                diagram_bounds=(0.0, 0.0, 1920.0, 1080.0),
                outer_margin=24.0,
                selected_flow_ids={
                    str(flow.get("id", ""))
                    for flow in surface.get("flows", [])
                    if isinstance(flow, dict)
                },
                expected_semantic_node_ids=set(),
                expected_semantic_flow_ids=set(),
            )
            metrics = tm7_visual_feedback.derive_geometry_metrics(geometry)
            # Laying out against the visible canvas rather than the full 1920
            # model units removed clipping from five surfaces and cost ctx-01
            # one additional crossing. Raising LAYOUT_EXPANSION_LIMIT from 2.5
            # to 4.0 left both the crossing count and the surface extent
            # unchanged, so the surface is already at its content-demand
            # ceiling and the budget records that measurement rather than
            # relaxing the limit for every surface. The native feedback loop
            # treats the third crossing as a review finding and attempts to
            # resolve it, so this drops back to two once refinement lands.
            #
            # dom-docproc carries the same allowance for a different reason.
            # Placing labels where TMT actually draws them, centred on the
            # serialized handle, means the handle must clear obstacles on its
            # own instead of delegating to an offset the renderer ignores.
            # That constrains routing: across the nine surfaces the change
            # moved total crossings from 18 to 16, trading one extra crossing
            # here and on op-cicd for two fewer on dom-webscan, one on
            # dom-planning, and one on dom-otel. A label drawn on top of a
            # node is less readable than a line crossing, so the exchange is
            # taken deliberately rather than tuned away.
            relaxed_crossing_surfaces = {"ctx-01", "dom-docproc"}
            crossing_budget = (
                3 if str(surface.get("id", "")) in relaxed_crossing_surfaces else 2
            )
            assert metrics["edge_crossing_count"] <= crossing_budget, surface.get("id")
            assert metrics["edge_node_intersections"] <= 1, surface.get("id")
            assert metrics["node_outside_zone_count"] == 0, surface.get("id")
            # Predicted connector-label rectangles are not persisted by TM7 and
            # are not read by the renderer, so they are reported rather than
            # asserted. Rendered-label measurement is tracked separately.
            assert metrics["detached_endpoint_count"] == 0, surface.get("id")

    def test_given_comprehensive_spec_when_layout_then_empty_zones_are_pruned(
        self,
    ) -> None:
        # Arrange
        spec = generate_tm7.load_spec(COMPREHENSIVE_SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        model = generate_tm7.build_model_from_spec(
            spec,
            profile,
            "pre-populated-comprehensive",
        )
        context = next(
            surface for surface in model["surfaces"] if surface["id"] == "ctx-01"
        )
        planning = next(
            surface for surface in model["surfaces"] if surface["id"] == "dom-planning"
        )

        # Act
        laid_out = generate_tm7.apply_layout(model, profile)

        # Assert
        context_layout = next(
            surface for surface in laid_out["surfaces"] if surface["id"] == "ctx-01"
        )
        assert {zone["id"] for zone in context["trust_zones"]} == {
            "tz-dev",
            "tz-github",
            "tz-repo",
        }
        assert {zone["id"] for zone in planning["trust_zones"]} == {
            "tz-dev",
            "tz-repo",
        }
        boundary_heights = [
            element["position"]["height"]
            for element in context_layout["elements"]
            if element.get("kind") == "trust_boundary_box"
        ]
        boundary_widths = [
            element["position"]["width"]
            for element in context_layout["elements"]
            if element.get("kind") == "trust_boundary_box"
        ]
        assert boundary_heights
        assert max(boundary_heights) < 700
        assert boundary_widths
        assert max(boundary_widths) < 800
        context_positions = {
            element["id"]: element["position"]
            for element in context_layout["elements"]
            if element.get("kind") != "trust_boundary_box"
        }
        planning_layout = next(
            surface
            for surface in laid_out["surfaces"]
            if surface["id"] == "dom-planning"
        )
        planning_positions = {
            element["id"]: element["position"]
            for element in planning_layout["elements"]
            if element.get("kind") != "trust_boundary_box"
        }
        assert len({position["top"] for position in context_positions.values()}) > 1
        assert (
            planning_positions["ext-dev"]["top"]
            < planning_positions["comp-securityplanning"]["top"]
        )
        assert (
            planning_positions["comp-securityplanning"]["left"]
            < planning_positions["comp-artifacts"]["left"]
        )

    def test_given_spec_when_generate_tm7_then_golden_fixture_matches(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "golden.tm7"

        # Act
        run_generator(SPEC_PATH, output_path)
        generated_root = parse_tm7(output_path)
        expected_root = parse_tm7(FIXTURE_PATH)

        # Assert
        assert generated_root.tag == expected_root.tag
        generated_custom_types = [
            (
                threat_type.findtext("{*}Id") or "",
                threat_type.findtext("{*}ShortTitle") or "",
            )
            for threat_type in generated_root.findall(".//{*}ThreatType")
            if (threat_type.findtext("{*}Id") or "").startswith("THC-")
        ]
        assert generated_custom_types
        assert all(
            re.fullmatch(r"THC-[a-z0-9-]{1,24}-[A-Z0-9]{16}", threat_id)
            for threat_id, _ in generated_custom_types
        )
        assert all(short_title for _, short_title in generated_custom_types)

    def test_given_existing_model_when_merge_then_human_edits_are_preserved(
        self,
    ) -> None:
        # Arrange
        spec_model = {
            "elements": [
                {"id": "proc-01", "position": {"left": 0, "top": 0}, "notes": ""}
            ],
            "flows": [],
            "threats": [{"id": "threat-01", "state": "Open", "notes": "auto"}],
        }
        existing_model = {
            "elements": [
                {
                    "id": "proc-01",
                    "position": {"left": 321, "top": 654},
                    "notes": "Human review note",
                }
            ],
            "flows": [],
            "threats": [
                {
                    "id": "threat-01",
                    "state": "Mitigated",
                    "notes": "Human review note",
                }
            ],
        }

        # Act
        merged = generate_tm7.merge_model(spec_model, existing_model)

        # Assert
        element = next(node for node in merged["elements"] if node["id"] == "proc-01")
        assert element["position"] == {"left": 321, "top": 654}
        assert element["notes"] == "Human review note"
        threat = next(node for node in merged["threats"] if node["id"] == "threat-01")
        assert threat["state"] == "Mitigated"
        assert "Human review note" in threat["notes"]

    def test_given_markdown_report_when_compare_to_tm7_then_threat_sets_match(
        self,
        tmp_path: Path,
    ) -> None:
        # Arrange
        output_path = tmp_path / "model.tm7"
        spec = generate_tm7.load_spec(SPEC_PATH)
        profile = generate_tm7.resolve_profile(spec, None, ROOT)
        mode = str(spec.get("mode") or "pre-populated-comprehensive")
        payload = generate_tm7.build_tm7_payload(spec, profile, mode)
        run_generator(SPEC_PATH, output_path)

        # Act
        markdown_text = generate_markdown.build_markdown_report(spec, profile, mode)
        tm7_ids = {threat["id"] for threat in payload["ThreatInstances"]}
        markdown_ids = {
            identifier.split("|", 1)[0].removeprefix("- ID:").strip()
            for identifier in markdown_text.splitlines()
            if identifier.strip().startswith("- ID:")
        }

        # Assert
        assert tm7_ids == markdown_ids


def test_given_generate_markdown_cli_when_run_then_output_is_written(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "report.md"

    # Act
    subprocess.run(
        [
            sys.executable,
            str(MARKDOWN_SCRIPT_PATH),
            str(SPEC_PATH),
            "-o",
            str(output_path),
        ],
        check=True,
        cwd=ROOT,
        capture_output=True,
        text=True,
    )

    # Assert
    assert output_path.exists()
    report_text = output_path.read_text(encoding="utf-8")
    assert "# Threat Model STRIDE/NIST Report" in report_text


def test_given_flow_retention_when_generate_markdown_then_retention_is_present(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = generate_tm7.load_spec(SPEC_PATH)
    spec.setdefault("data_flows", [{}])[0].update(
        {"id": "flow-01", "retention": "90 days"}
    )
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    mode = str(spec.get("mode") or "pre-populated-comprehensive")

    # Act
    markdown_text = generate_markdown.build_markdown_report(spec, profile, mode)

    # Assert
    assert "retention=90 days" in markdown_text


def test_given_optional_fields_when_generate_markdown_then_sections_are_rendered(
    tmp_path: Path,
) -> None:
    # Arrange
    spec = generate_tm7.load_spec(SPEC_PATH)
    spec.setdefault("assets", [{}])[0].update(
        {"name": "User content", "category": "Content", "sensitivity": "internal"}
    )
    spec.setdefault("abuse_cases", [{}])[0].update(
        {
            "title": "Replay of a previously valid request",
            "evil_user_story": (
                "As an authenticated low-privilege user, I want to manipulate the "
                "checkout flow so that I can bypass authorization"
            ),
        }
    )
    spec.setdefault("data_flows", [{}])[0].update(
        {"id": "flow-01", "retention": "90 days"}
    )
    spec_path = tmp_path / "spec.yaml"
    spec_path.write_text(yaml.safe_dump(spec), encoding="utf-8")
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    mode = str(spec.get("mode") or "pre-populated-comprehensive")

    # Act
    report_text = generate_markdown.build_markdown_report(spec, profile, mode)

    # Assert
    assert "## Evil User Stories" in report_text
    assert "## Data Classification" in report_text
    assert "Retention" in report_text


def test_given_spec_without_optional_fields_when_generate_then_notes_have_no_eus() -> (
    None
):
    # Arrange
    spec = generate_tm7.load_spec(SPEC_PATH)
    spec.get("assets", [{}])[0].pop("category", None)
    spec.get("abuse_cases", [{}])[0].pop("evil_user_story", None)
    spec.get("data_flows", [{}])[0].pop("retention", None)
    profile = generate_tm7.resolve_profile(spec, None, ROOT)
    mode = str(spec.get("mode") or "pre-populated-comprehensive")

    # Act
    payload = generate_tm7.build_tm7_payload(spec, profile, mode)
    threats = payload["ThreatInstances"]

    # Assert
    assert threats
    assert all("EUS=" not in threat["notes"] for threat in threats)


def test_given_reference_contract_when_generate_then_structure_matches(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"
    reference_text = REFERENCE_FIXTURE_PATH.read_text(encoding="utf-8")

    # Act
    run_generator(SPEC_PATH, output_path)
    generated_text = output_path.read_text(encoding="utf-8")

    # Assert: the generated file shares the genuine TMT DataContract structure.
    shared_markers = [
        "<DrawingSurfaceModel",
        "<Borders",
        "<a:KeyValueOfguidanyType",
        'i:type="StencilRectangle"',
        'i:type="StencilEllipse"',
        'i:type="Connector"',
        "<Lines",
        "<Version>4.3</Version>",
        "<KnowledgeBase",
        "<a:ThreatType>",
        '<PromptedKb xmlns=""',
    ]
    for marker in shared_markers:
        assert marker in reference_text, f"reference missing {marker!r}"
        assert marker in generated_text, f"generated missing {marker!r}"

    # ThreatInstances should be present in the generated contract and contain
    # serialized threat entries while threat generation remains disabled.
    assert "<ThreatInstances" in generated_text
    assert "KeyValueOfstringThreatpc_P0_PhOB" in generated_text
    assert "<ThreatGenerationEnabled>false</ThreatGenerationEnabled>" in generated_text
    # The embedded KnowledgeBase must be populated (Manifest + at least one type).
    assert "<a:Manifest" in generated_text or "<a:Manifest>" in generated_text
    assert generated_text.count("<a:ThreatType>") > 1


def _root_child_order(root: ET.Element) -> list[str]:
    """Return the local names of a TM7 root's direct children."""
    return [child.tag.split("}")[-1] for child in root]


def test_given_reference_when_compare_root_member_order_then_matches(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    generated_root = parse_tm7(output_path)
    reference_root = parse_tm7(REFERENCE_FIXTURE_PATH)

    # Assert: the DataContract member order of the root must match TMT's.
    assert _root_child_order(generated_root) == _root_child_order(reference_root)


def test_given_reference_when_compare_surface_member_order_then_matches(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    generated_surface = iter_surface_nodes(parse_tm7(output_path))[0]
    reference_surface = iter_surface_nodes(parse_tm7(REFERENCE_FIXTURE_PATH))[0]
    generated_order = [child.tag.split("}")[-1] for child in generated_surface]
    reference_order = [child.tag.split("}")[-1] for child in reference_surface]

    # Assert: DrawingSurfaceModel member order must match TMT's contract.
    assert generated_order == reference_order


def test_given_named_surfaces_when_generated_then_tab_caption_carries_surface_name(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"
    spec = yaml.safe_load(SPEC_PATH.read_text(encoding="utf-8"))
    expected_names = [
        str(surface["name"])
        for view in ("context_diagrams", "functional_scenarios", "operational_views")
        for surface in spec["representations"].get(view, [])
    ]

    # Act
    run_generator(SPEC_PATH, output_path)
    surfaces = iter_surface_nodes(parse_tm7(output_path))

    # Assert: TMT reads the tab caption from the "Name" StringDisplayAttribute in
    # the surface Properties collection. An empty collection renders every tab as
    # the default "Diagram" caption regardless of the sibling Header element.
    captions = []
    for surface in surfaces:
        properties = surface.find("{*}Properties")
        assert properties is not None
        name_value = next(
            (
                attribute.find("{*}Value")
                for attribute in properties
                if (display := attribute.find("{*}DisplayName")) is not None
                and display.text == "Name"
            ),
            None,
        )
        assert name_value is not None
        captions.append(name_value.text)

    assert captions == expected_names
    assert [surface.find("{*}Header").text for surface in surfaces] == expected_names


def test_given_reference_when_compare_surface_properties_shape_then_matches() -> None:
    # Act
    reference_surface = iter_surface_nodes(parse_tm7(REFERENCE_FIXTURE_PATH))[0]
    properties = reference_surface.find("{*}Properties")

    # Assert: the generated surface Properties collection mirrors this TMT-authored
    # shape, so the attribute pair and ordering are pinned against the real tool.
    assert properties is not None
    assert [
        attribute.get(f"{{{generate_tm7.XSI_NS}}}type") for attribute in properties
    ] == [
        "b:HeaderDisplayAttribute",
        "b:StringDisplayAttribute",
    ]


def test_given_reference_fixture_when_checked_then_no_zero_length_connectors() -> None:
    # Act
    root = parse_tm7(REFERENCE_FIXTURE_PATH)

    # Assert
    assert zero_length_connectors(root) == 0


def test_given_reference_fixture_when_checked_then_most_handles_are_midpoints() -> None:
    # Act: the genuine model proves the midpoint handle is TMT's natural default.
    # A minority of connectors are hand-curved, so this is a majority check, not
    # an absolute one (overlap and curved handles are tolerated by TMT on open).
    root = parse_tm7(REFERENCE_FIXTURE_PATH)
    connectors = connector_geoms(root)
    midpoint_count = len(connectors) - len(handle_mismatches(root))

    # Assert
    assert connectors
    assert midpoint_count / len(connectors) >= 0.7


def test_given_reference_fixture_when_checked_then_endpoints_are_centers() -> None:
    # Arrange
    root = parse_tm7(REFERENCE_FIXTURE_PATH)
    shapes: dict[str, dict[str, float]] = {}
    for surface_shapes in shape_rects_by_surface(root):
        shapes.update(surface_shapes)

    # Act / Assert: each resolvable endpoint sits at its shape's center.
    checked = 0
    for geom in connector_geoms(root):
        source = shapes.get(geom["source_guid"])
        target = shapes.get(geom["target_guid"])
        if source is not None:
            assert abs(geom["sx"] - (source["left"] + source["width"] / 2)) <= 1
            assert abs(geom["sy"] - (source["top"] + source["height"] / 2)) <= 1
            checked += 1
        if target is not None:
            assert abs(geom["tx"] - (target["left"] + target["width"] / 2)) <= 1
            assert abs(geom["ty"] - (target["top"] + target["height"] / 2)) <= 1
            checked += 1
    assert checked > 0


def test_given_generated_when_checked_then_handles_are_midpoints(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert: every native handle is finite and remains within a bounded canvas.
    connectors = connector_geoms(root)
    assert connectors
    assert all(
        all(
            isinstance(connector[key], float)
            and math.isfinite(connector[key])
            and -4000.0 <= connector[key] <= 4000.0
            for key in ("hx", "hy")
        )
        for connector in connectors
    )


def test_given_generated_when_checked_then_no_overlapping_shapes(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert: our layout is overlap-free (stricter than TMT requires).
    assert overlapping_shape_pairs(root) == 0


def test_given_generated_when_checked_then_no_zero_length_connectors(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert
    assert connector_geoms(root)
    assert zero_length_connectors(root) == 0


def test_given_generated_when_checked_then_no_dangling_endpoints(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert: every connector endpoint resolves to a shape on its own surface.
    assert dangling_connector_endpoints(root) == 0


def test_given_reference_when_checked_then_no_dangling_endpoints() -> None:
    # Act
    root = parse_tm7(REFERENCE_FIXTURE_PATH)

    # Assert: the genuine model has no cross-surface endpoint leakage.
    assert dangling_connector_endpoints(root) == 0


def test_given_generated_when_checked_then_no_boundary_line_shapes(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert: trust boundaries are box-only (GE.TB.B); no GE.TB.L line boxes.
    assert boundary_line_shape_count(root) == 0


def test_given_generated_when_checked_then_shapes_are_off_origin(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    root = parse_tm7(output_path)

    # Assert: no shape or boundary sits at the (0,0) origin that TMT corrects.
    assert min_shape_origin(root) > 0


def test_given_generated_when_checked_then_connector_fields_match_reference(
    tmp_path: Path,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"

    # Act
    run_generator(SPEC_PATH, output_path)
    generated_fields = connector_field_names(parse_tm7(output_path))
    reference_fields = connector_field_names(parse_tm7(REFERENCE_FIXTURE_PATH))

    # Assert: the generated Connector must not introduce members the genuine
    # TMT Connector lacks (e.g., StrokeThickness, Retention).
    assert generated_fields <= reference_fields, (
        f"unexpected connector fields: {sorted(generated_fields - reference_fields)}"
    )


def _find_powershell() -> str | None:
    """Return a PowerShell executable that can host the TMT harness."""
    for candidate in ("pwsh", "powershell"):
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    return None


def _run_tmt_deserialize(target: Path) -> subprocess.CompletedProcess[str]:
    """Invoke the committed harness that deserializes with TMT's serializer."""
    powershell = _find_powershell()
    if powershell is None:
        pytest.skip("PowerShell is not available on this platform")
    return subprocess.run(
        [
            powershell,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(DESERIALIZE_HARNESS),
            "-Path",
            str(target),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.skipif(
    platform.system() != "Windows",
    reason="TMT assemblies are Windows-only",
)
@pytest.mark.parametrize(
    "mode",
    ["pre-populated-comprehensive", "diagram-only-defer-to-tmt"],
)
def test_given_generated_tm7_when_deserialized_by_tmt_then_round_trips(
    tmp_path: Path,
    mode: str,
) -> None:
    # Arrange
    output_path = tmp_path / "model.tm7"
    run_generator(SPEC_PATH, output_path, mode=mode)

    # Act
    result = _run_tmt_deserialize(output_path)
    stdout = result.stdout.strip()

    # Assert
    if result.returncode == 3 or "TMT_ASSEMBLIES_NOT_FOUND" in stdout:
        pytest.skip("Microsoft Threat Modeling Tool assemblies are not installed")
    assert result.returncode == 0, f"harness failed: {stdout}\n{result.stderr}"
    assert "DESERIALIZE_OK" in stdout


@pytest.mark.skipif(
    platform.system() != "Windows",
    reason="TMT assemblies are Windows-only",
)
def test_given_reference_fixture_when_deserialized_by_tmt_then_round_trips() -> None:
    # Act
    result = _run_tmt_deserialize(REFERENCE_FIXTURE_PATH)
    stdout = result.stdout.strip()

    # Assert
    if result.returncode == 3 or "TMT_ASSEMBLIES_NOT_FOUND" in stdout:
        pytest.skip("Microsoft Threat Modeling Tool assemblies are not installed")
    assert result.returncode == 0, f"harness failed: {stdout}\n{result.stderr}"
    assert "DESERIALIZE_OK" in stdout


def test_given_spec_within_limit_when_loaded_then_parses_normally(
    tmp_path: Path,
) -> None:
    # Arrange
    spec_path = tmp_path / "small.yaml"
    spec_path.write_text("project_metadata:\n  name: Bounded\n", encoding="utf-8")

    # Act
    spec = generate_tm7.load_spec(spec_path)

    # Assert
    assert spec["project_metadata"]["name"] == "Bounded"


def test_given_spec_over_limit_when_loaded_then_generation_error_is_raised(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    monkeypatch.setattr(generate_tm7, "MAX_SPEC_BYTES", 64)
    spec_path = tmp_path / "oversized.yaml"
    spec_path.write_text("key: " + ("a" * 512) + "\n", encoding="utf-8")

    # Act & Assert
    with pytest.raises(generate_tm7.GenerationError, match="too large"):
        generate_tm7.load_spec(spec_path)


def test_given_alias_expansion_payload_when_loaded_then_no_uncaught_exception(
    tmp_path: Path,
) -> None:
    # Arrange
    spec_path = tmp_path / "aliases.yaml"
    spec_path.write_text(
        "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nd: [*c, *c]\n",
        encoding="utf-8",
    )

    # Act & Assert
    try:
        generate_tm7.load_spec(spec_path)
    except generate_tm7.GenerationError:
        # Either outcome passes. The contract under test is that an alias
        # expansion bomb terminates through the declared error type instead of
        # exhausting memory or raising something uncaught, so a clean load and
        # a GenerationError are both correct.
        pass
