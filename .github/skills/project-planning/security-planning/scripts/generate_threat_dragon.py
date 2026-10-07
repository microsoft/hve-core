#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate an OWASP Threat Dragon v2.6.2 model from a threat-model spec.

The generator reads the same spec as ``generate_tm7.py`` and reuses its model
building, validation, layout, and threat mapping through ``build_tm7_payload``.
Each laid-out representation becomes one Threat Dragon diagram. The output is
validated against the vendored v2.6.2 schema and semantic rules before it
atomically replaces the destination.

Usage:
    python scripts/generate_threat_dragon.py spec.yaml -o model.threat-dragon.json

Exit codes: 0 success, 2 generation or validation error.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

from generate_tm7 import (
    DISCLAIMER_TEXT,
    GenerationError,
    _coerce_bool,
    build_tm7_payload,
    load_spec,
    resolve_profile,
)
from tm7_threat_contract import (
    ThreatContractError,
    build_mitigation_text,
    normalize_state,
)
from validate_threat_dragon import (
    EXPECTED_THUMBNAIL,
    THREAT_DRAGON_VERSION,
    SchemaError,
    validate_file,
)

EXIT_SUCCESS = 0
EXIT_ERROR = 2

DEFAULT_OUTPUT = Path("out.threat-dragon.json")
UUID_NAMESPACE = uuid.UUID("026a4b28-585c-51e0-bd7e-95349d93632f")

NODE_SHAPES = {
    "external_interactor": ("actor", "tm.Actor"),
    "process": ("process", "tm.Process"),
    "data_store": ("store", "tm.Store"),
}
BOUNDARY_KIND = "trust_boundary_box"
ABUSE_SOURCE = "abuse"
STRIDE_TYPES = {
    "spoofing": "Spoofing",
    "tampering": "Tampering",
    "repudiation": "Repudiation",
    "information-disclosure": "Information disclosure",
    "denial-of-service": "Denial of service",
    "elevation-of-privilege": "Elevation of privilege",
}
LEVELS = {"low": "Low", "medium": "Medium", "high": "High", "critical": "Critical"}
RISK_LEVELS = {**LEVELS, "informational": "Informational"}
STATUS_BY_CANONICAL_STATE = {"Mitigated": "Mitigated", "NotApplicable": "NotApplicable"}
ELEMENT_OPTIONS: dict[str, tuple[str, str, type]] = {
    "provides_authentication": ("external_interactor", "providesAuthentication", bool),
    "is_web_application": ("process", "isWebApplication", bool),
    "handles_card_payment": ("process", "handlesCardPayment", bool),
    "handles_goods_or_services": ("process", "handlesGoodsOrServices", bool),
    "privilege_level": ("process", "privilegeLevel", str),
    "is_a_log": ("data_store", "isALog", bool),
    "is_encrypted": ("data_store", "isEncrypted", bool),
    "is_signed": ("data_store", "isSigned", bool),
    "stores_credentials": ("data_store", "storesCredentials", bool),
    "stores_inventory": ("data_store", "storesInventory", bool),
}

DEFAULT_STROKE = "#333333"
DEFAULT_STROKE_WIDTH = 1.5
OPEN_THREAT_STROKE = "red"
OPEN_THREAT_STROKE_WIDTH = 2.5
OUT_OF_SCOPE_DASH = "4 3"


def _uid(name: str) -> str:
    return str(uuid.uuid5(UUID_NAMESPACE, name))


def _coord(value: Any) -> int | float:
    number = round(float(value or 0), 2)
    return int(number) if number.is_integer() else number


def _text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def _optional_bool(value: Any, where: str) -> bool | None:
    if value is None:
        return None
    if not isinstance(value, bool):
        raise GenerationError(f"{where} must be true or false, got {value!r}")
    return value


def _optional_level(value: Any, allowed: dict[str, str], where: str) -> str | None:
    if value is None:
        return None
    key = _text(value).lower()
    if key not in allowed:
        raise GenerationError(
            f"{where} must be one of {', '.join(allowed)}, got {value!r}"
        )
    return allowed[key]


def _representations(spec: dict[str, Any]) -> list[dict[str, Any]]:
    representations = spec.get("representations") or {}
    ordered: list[dict[str, Any]] = []
    for group in ("context_diagrams", "functional_scenarios", "operational_views"):
        items = representations.get(group) or []
        ordered.extend(item for item in items if isinstance(item, dict))
    return ordered


def _element_facts(spec: dict[str, Any]) -> dict[tuple[str, str], dict[str, Any]]:
    """Merge catalog component facts with inline representation overrides."""
    components = {
        _text(item.get("id")): item
        for item in spec.get("components") or []
        if isinstance(item, dict)
    }
    facts: dict[tuple[str, str], dict[str, Any]] = {}
    for representation in _representations(spec):
        surface_id = _text(representation.get("id")) or "surface"
        entries = (representation.get("elements") or []) + (
            representation.get("components") or []
        )
        for entry in entries:
            if isinstance(entry, dict):
                element_id = _text(entry.get("id"))
                facts[(surface_id, element_id)] = {
                    **components.get(element_id, {}),
                    **entry,
                }
    return facts


def _element_options(
    spec: dict[str, Any], kinds: dict[str, set[str]]
) -> dict[str, dict[str, Any]]:
    """Validate and translate ``export_options.threat_dragon`` element options."""
    export_options = spec.get("export_options")
    if export_options is None:
        return {}
    if not isinstance(export_options, dict):
        raise GenerationError("export_options must be a mapping")
    threat_dragon = export_options.get("threat_dragon")
    if threat_dragon is None:
        return {}
    if not isinstance(threat_dragon, dict):
        raise GenerationError("export_options.threat_dragon must be a mapping")
    unknown_sections = sorted(set(threat_dragon) - {"elements"})
    if unknown_sections:
        raise GenerationError(
            f"export_options.threat_dragon has unknown key(s) {unknown_sections}"
        )
    elements = threat_dragon.get("elements") or {}
    if not isinstance(elements, dict):
        raise GenerationError("export_options.threat_dragon.elements must be a mapping")

    translated: dict[str, dict[str, Any]] = {}
    for element_id, options in elements.items():
        where = f"export_options.threat_dragon.elements.{element_id}"
        element_kinds = kinds.get(str(element_id))
        if not element_kinds:
            raise GenerationError(f"{where} names no drawn element")
        if not isinstance(options, dict):
            raise GenerationError(f"{where} must be a mapping")
        native: dict[str, Any] = {}
        for option, value in options.items():
            if option not in ELEMENT_OPTIONS:
                raise GenerationError(f"{where}.{option} is not a supported option")
            kind, native_name, value_type = ELEMENT_OPTIONS[option]
            if element_kinds != {kind}:
                raise GenerationError(
                    f"{where}.{option} applies only to {kind} elements, not "
                    f"{', '.join(sorted(element_kinds))}"
                )
            if value is None:
                continue
            if not isinstance(value, value_type):
                raise GenerationError(
                    f"{where}.{option} must be a {value_type.__name__}, got {value!r}"
                )
            native[native_name] = value
        translated[str(element_id)] = native
    return translated


def _stroke(has_open_threats: bool, out_of_scope: bool) -> dict[str, Any]:
    return {
        "stroke": OPEN_THREAT_STROKE if has_open_threats else DEFAULT_STROKE,
        "strokeWidth": (
            OPEN_THREAT_STROKE_WIDTH if has_open_threats else DEFAULT_STROKE_WIDTH
        ),
        "strokeDasharray": OUT_OF_SCOPE_DASH if out_of_scope else None,
    }


def _append_block(text: str, block: str) -> str:
    return f"{text}\n\n{block}" if text else block


def _threat_context(threat: dict[str, Any], spec_threat: dict[str, Any]) -> str:
    citations = threat.get("citations") or {}

    def _joined(key: str) -> str:
        values = [str(item) for item in citations.get(key) or [] if str(item)]
        return ", ".join(values) if values else "None"

    lines = [
        "HVE-Core context",
        f"Threat ID: {threat.get('id', '')}",
        f"State: {_text(threat.get('state')) or 'Open'}",
        "Likelihood: "
        + (
            _optional_level(spec_threat.get("likelihood"), LEVELS, "likelihood")
            or "TBD"
        ),
        "Impact: "
        + (_optional_level(spec_threat.get("impact"), LEVELS, "impact") or "TBD"),
        "Risk: "
        + (_optional_level(spec_threat.get("risk"), RISK_LEVELS, "risk") or "TBD"),
        f"STRIDE: {_joined('stride')}",
        f"NIST: {_joined('nist')}",
        f"MITRE: {_joined('mitre')}",
    ]
    interaction_ref = _text(threat.get("interaction_ref"))
    if interaction_ref and interaction_ref != _text(threat.get("target_ref")):
        lines.append(f"Placement flow: {interaction_ref}")
    return "\n".join(lines)


def _native_threat(
    threat: dict[str, Any], spec_threat: dict[str, Any], spec: dict[str, Any]
) -> dict[str, Any]:
    threat_id = _text(threat.get("id"))
    where = f"threat {threat_id}"
    category = _text(threat.get("category")).lower().replace("_", "-").replace(" ", "-")
    if category not in STRIDE_TYPES:
        raise GenerationError(
            f"{where}: category {threat.get('category')!r} has no Threat Dragon "
            "STRIDE type"
        )
    try:
        canonical_state = normalize_state(threat.get("state"))
    except ThreatContractError as exc:
        raise GenerationError(f"{where}: {exc}") from exc
    severity = _optional_level(spec_threat.get("severity"), LEVELS, f"{where} severity")
    if severity is None:
        risk = _optional_level(spec_threat.get("risk"), RISK_LEVELS, f"{where} risk")
        severity = "Low" if risk == "Informational" else risk
    return {
        "id": _uid(f"threat:{threat_id}"),
        "threatId": threat_id,
        "number": 0,
        "title": _text(threat.get("title")) or threat_id,
        "description": _append_block(
            _text(threat.get("description")), _threat_context(threat, spec_threat)
        ),
        "type": STRIDE_TYPES[category],
        "modelType": "STRIDE",
        "status": STATUS_BY_CANONICAL_STATE.get(canonical_state, "Open"),
        "severity": severity or "TBD",
        "mitigation": build_mitigation_text(spec, spec_threat) if spec_threat else "",
    }


def _place_threats(
    payload: dict[str, Any],
) -> dict[tuple[int, str], list[dict[str, Any]]]:
    """Attach each threat once, following TM7 placement (D7 in the reference)."""
    surfaces = payload.get("Surfaces") or []
    flow_ids = [
        {_text(flow.get("id")) for flow in s.get("flows") or []} for s in surfaces
    ]
    node_ids = [
        {
            _text(element.get("id"))
            for element in s.get("elements") or []
            if element.get("kind") != BOUNDARY_KIND
        }
        for s in surfaces
    ]
    placed: dict[tuple[int, str], list[dict[str, Any]]] = {}
    seen_ids: set[str] = set()
    for threat in payload.get("ThreatInstances") or []:
        # Abuse cases carry no STRIDE type, which every Threat Dragon threat needs.
        if threat.get("source") == ABUSE_SOURCE:
            continue
        # Generated threats repeat once per surface that draws their target.
        threat_id = _text(threat.get("id"))
        if threat_id in seen_ids:
            continue
        seen_ids.add(threat_id)
        target = _text(threat.get("target_ref"))
        interaction = _text(threat.get("interaction_ref"))
        is_flow = any(target in ids for ids in flow_ids)
        members = flow_ids if is_flow else node_ids
        candidates = [index for index, ids in enumerate(members) if target in ids]
        if not candidates:
            raise GenerationError(
                f"threat {threat.get('id')}: target {target or '(empty)'} is not "
                "drawn on any representation"
            )
        preferred = [index for index in candidates if interaction in flow_ids[index]]
        surface_index = (preferred or candidates)[0]
        key = f"{'flow' if is_flow else 'node'}:{target}"
        placed.setdefault((surface_index, key), []).append(threat)
    return placed


def _zone_ancestry(surface: dict[str, Any]) -> dict[str, list[str]]:
    parents = {
        _text(zone.get("id")): _text(zone.get("parent_trust_zone_id"))
        for zone in surface.get("trust_zones") or []
    }
    ancestry: dict[str, list[str]] = {}
    for zone_id in parents:
        chain: list[str] = []
        current = parents.get(zone_id, "")
        while current and current not in chain:
            chain.append(current)
            current = parents.get(current, "")
        ancestry[zone_id] = chain
    return ancestry


def build_threat_dragon_model(
    spec: dict[str, Any], payload: dict[str, Any]
) -> dict[str, Any]:
    """Map a laid-out TM7 payload and its spec to a Threat Dragon v2.6.2 model.

    Args:
        spec: Parsed threat-model spec.
        payload: Result of ``build_tm7_payload`` for the same spec.

    Returns:
        Threat Dragon v2.6.2 model.

    Raises:
        GenerationError: If the spec holds content Threat Dragon cannot represent.
    """
    surfaces = payload.get("Surfaces") or []
    kinds: dict[str, set[str]] = {}
    for surface in surfaces:
        for element in surface.get("elements") or []:
            kind = _text(element.get("kind"))
            if kind not in NODE_SHAPES and kind != BOUNDARY_KIND:
                raise GenerationError(
                    f"element {element.get('id')} on representation "
                    f"{surface.get('id')} has kind {kind!r}, which Threat Dragon "
                    "export does not support"
                )
            if kind in NODE_SHAPES:
                kinds.setdefault(_text(element.get("id")), set()).add(kind)

    options = _element_options(spec, kinds)
    facts = _element_facts(spec)
    spec_flows = {
        _text(flow.get("id")): flow
        for flow in spec.get("data_flows") or []
        if isinstance(flow, dict)
    }
    spec_threats = [
        item for item in spec.get("threats") or [] if isinstance(item, dict)
    ]
    spec_threat_iter = iter(spec_threats)
    spec_threat_by_instance: dict[int, dict[str, Any]] = {}
    for threat in payload.get("ThreatInstances") or []:
        if threat.get("source") == "spec":
            spec_threat_by_instance[id(threat)] = next(spec_threat_iter, {})
    placed = _place_threats(payload)
    representations = {_text(r.get("id")): r for r in _representations(spec)}

    threat_counter = 0

    def _threats_for(surface_index: int, key: str) -> list[dict[str, Any]]:
        nonlocal threat_counter
        native = []
        for threat in placed.get((surface_index, key), []):
            entry = _native_threat(
                threat, spec_threat_by_instance.get(id(threat), {}), spec
            )
            entry["number"] = threat_counter
            threat_counter += 1
            native.append(entry)
        return native

    diagrams: list[dict[str, Any]] = []
    for surface_index, surface in enumerate(surfaces):
        surface_id = _text(surface.get("id"))
        elements = surface.get("elements") or []
        flows = surface.get("flows") or []
        zones = {
            _text(zone.get("id")): zone for zone in surface.get("trust_zones") or []
        }
        ancestry = _zone_ancestry(surface)
        node_elements = [e for e in elements if e.get("kind") in NODE_SHAPES]
        node_cell_ids = {
            _text(e.get("id")): _uid(f"node:{surface_id}:{e.get('id')}")
            for e in node_elements
        }
        flow_cell_ids = {
            _text(f.get("id")): _uid(f"flow:{surface_id}:{f.get('id')}") for f in flows
        }

        def _in_zone(element: dict[str, Any], zone_id: str) -> bool:
            own = _text(element.get("trust_zone_id"))
            return own == zone_id or zone_id in ancestry.get(own, [])

        boundary_elements = sorted(
            (
                (index, e)
                for index, e in enumerate(elements)
                if e.get("kind") == BOUNDARY_KIND
            ),
            key=lambda item: (
                len(ancestry.get(_text(item[1].get("trust_zone_id")), [])),
                item[0],
            ),
        )
        boundary_members: dict[str, set[str]] = {}
        cells: list[dict[str, Any]] = []
        for z_offset, (_, boundary) in enumerate(boundary_elements):
            zone_id = _text(boundary.get("trust_zone_id"))
            boundary_id = _uid(f"boundary:{surface_id}:{zone_id}")
            members = {
                _text(e.get("id")) for e in node_elements if _in_zone(e, zone_id)
            }
            boundary_members[boundary_id] = members
            crossing = sorted(
                flow_cell_ids[_text(f.get("id"))]
                for f in flows
                if (_text(f.get("source_ref")) in members)
                != (_text(f.get("target_ref")) in members)
            )
            zone = zones.get(zone_id, {})
            name = _text(zone.get("name")) or _text(boundary.get("name")) or zone_id
            position = boundary.get("position") or {}
            cells.append(
                {
                    "id": boundary_id,
                    "shape": "trust-boundary-box",
                    "zIndex": -1000 + z_offset,
                    "position": {
                        "x": _coord(position.get("left")),
                        "y": _coord(position.get("top")),
                    },
                    "size": {
                        "width": _coord(position.get("width")),
                        "height": _coord(position.get("height")),
                    },
                    "attrs": {"label": {"text": name}},
                    "data": {
                        "type": "tm.BoundaryBox",
                        "name": name,
                        "description": _text(zone.get("description")),
                        "hasOpenThreats": False,
                        "isTrustBoundary": True,
                        "containedElements": sorted(
                            node_cell_ids[member] for member in members
                        ),
                        "crossingFlows": crossing,
                        "threats": [],
                    },
                }
            )

        for z_offset, flow in enumerate(flows):
            flow_id = _text(flow.get("id"))
            spec_flow = spec_flows.get(flow_id, flow)
            where = f"data flow {flow_id}"
            bidirectional = _optional_bool(
                spec_flow.get("bidirectional"), f"{where} bidirectional"
            )
            encrypted = _optional_bool(spec_flow.get("encrypted"), f"{where} encrypted")
            public_network = _optional_bool(
                spec_flow.get("public_network"), f"{where} public_network"
            )
            threats = _threats_for(surface_index, f"flow:{flow_id}")
            has_open = any(threat["status"] == "Open" for threat in threats)
            name = _text(spec_flow.get("label")) or flow_id
            data: dict[str, Any] = {
                "type": "tm.Flow",
                "name": name,
                "description": _text(spec_flow.get("notes")),
                "hasOpenThreats": has_open,
                "isTrustBoundary": False,
                "outOfScope": False,
                "reasonOutOfScope": "",
            }
            protocol = _text(spec_flow.get("transport"))
            if protocol:
                data["protocol"] = protocol
            if bidirectional is not None:
                data["isBidirectional"] = bidirectional
            if encrypted is not None:
                data["isEncrypted"] = encrypted
            if public_network is not None:
                data["isPublicNetwork"] = public_network
            data["threats"] = threats
            source_ref = _text(flow.get("source_ref"))
            target_ref = _text(flow.get("target_ref"))
            data["trustBoundaryIds"] = sorted(
                boundary_id
                for boundary_id, members in boundary_members.items()
                if (source_ref in members) != (target_ref in members)
            )
            line = _stroke(has_open, False)
            cells.append(
                {
                    "id": flow_cell_ids[flow_id],
                    "shape": "flow",
                    "zIndex": 1000 + z_offset,
                    "attrs": {
                        "line": {
                            "stroke": line["stroke"],
                            "strokeWidth": line["strokeWidth"],
                            "targetMarker": {"name": "block"},
                            "sourceMarker": {"name": "block" if bidirectional else ""},
                            "strokeDasharray": None,
                        }
                    },
                    "labels": [{"position": 0.5, "attrs": {"label": {"text": name}}}],
                    "connector": "smooth",
                    "vertices": [],
                    "source": {"cell": node_cell_ids[source_ref]},
                    "target": {"cell": node_cell_ids[target_ref]},
                    "data": data,
                }
            )

        for z_offset, element in enumerate(node_elements):
            element_id = _text(element.get("id"))
            kind = _text(element.get("kind"))
            shape, data_type = NODE_SHAPES[kind]
            fact = facts.get((surface_id, element_id), {})
            where = f"element {element_id}"
            out_of_scope = bool(
                _optional_bool(fact.get("out_of_scope"), f"{where} out_of_scope")
            )
            threats = _threats_for(surface_index, f"node:{element_id}")
            has_open = any(threat["status"] == "Open" for threat in threats)
            name = _text(element.get("name")) or element_id
            stroke = _stroke(has_open, out_of_scope)
            attrs: dict[str, Any] = {"text": {"text": name}}
            if shape == "store":
                attrs["topLine"] = dict(stroke)
                attrs["bottomLine"] = dict(stroke)
            else:
                attrs["body"] = stroke
            position = element.get("position") or {}
            cells.append(
                {
                    "id": node_cell_ids[element_id],
                    "shape": shape,
                    "zIndex": 2000 + z_offset,
                    "position": {
                        "x": _coord(position.get("left")),
                        "y": _coord(position.get("top")),
                    },
                    "size": {
                        "width": _coord(position.get("width")),
                        "height": _coord(position.get("height")),
                    },
                    "attrs": attrs,
                    "data": {
                        "type": data_type,
                        "name": name,
                        "description": _text(fact.get("description")),
                        "hasOpenThreats": has_open,
                        "outOfScope": out_of_scope,
                        "reasonOutOfScope": (
                            _text(fact.get("out_of_scope_reason"))
                            if out_of_scope
                            else ""
                        ),
                        "isTrustBoundary": False,
                        **options.get(element_id, {}),
                        "threats": threats,
                    },
                }
            )

        representation = representations.get(surface_id, {})
        diagrams.append(
            {
                "id": surface_index,
                "title": _text(surface.get("name")) or surface_id,
                "description": _append_block(
                    _text(representation.get("description")),
                    f"HVE-Core representation\nID: {surface_id}",
                ),
                "diagramType": "STRIDE",
                "placeholder": "",
                "thumbnail": EXPECTED_THUMBNAIL,
                "version": THREAT_DRAGON_VERSION,
                "cells": cells,
            }
        )

    metadata = spec.get("project_metadata") or {}
    title = _text(metadata.get("name")) or "Threat model"
    return {
        "version": THREAT_DRAGON_VERSION,
        "summary": {
            "title": title,
            "owner": _text(metadata.get("owner")),
            "description": _append_block(
                _text(metadata.get("summary")), DISCLAIMER_TEXT
            ),
            "id": _uid(f"model:{title}"),
        },
        "detail": {
            "contributors": [],
            "diagrams": diagrams,
            "diagramTop": len(diagrams),
            "reviewer": "",
            "threatTop": max(threat_counter - 1, 0),
        },
    }


def serialize_model(model: dict[str, Any]) -> str:
    """Serialize a model deterministically with LF line endings."""
    return json.dumps(model, indent=2, ensure_ascii=False) + "\n"


def write_threat_dragon(output_path: Path, model: dict[str, Any]) -> None:
    """Validate the serialized model in a sibling file, then replace the output.

    A model that fails validation never reaches ``output_path``, so any existing
    output stays untouched.

    Raises:
        GenerationError: If the serialized model fails validation.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(  # noqa: SIM115 - closed in the with below
        mode="w",
        encoding="utf-8",
        newline="\n",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
        delete=False,
    )
    temporary_path = Path(handle.name)
    try:
        with handle:
            handle.write(serialize_model(model))
            handle.flush()
            os.fsync(handle.fileno())
        errors = validate_file(temporary_path)
        if errors:
            raise GenerationError(
                "generated Threat Dragon model failed validation: " + "; ".join(errors)
            )
        os.replace(temporary_path, output_path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def generate(spec_path: Path, output_path: Path) -> dict[str, Any]:
    """Generate and write a Threat Dragon model from a spec file.

    Profile, mode, and threat-generation resolution mirror
    ``generate_tm7.generate_tm7_candidate`` without overrides, so a spec lays
    out identically in both exporters.
    """
    spec = load_spec(spec_path)
    template_dir = Path(__file__).resolve().parent.parent
    profile = resolve_profile(spec, None, template_dir)
    profile["name"] = spec.get("template_profile") or "sdl_core_generic"
    default_mode = (
        "pre-populated-comprehensive"
        if spec.get("threats")
        else "diagram-only-defer-to-tmt"
    )
    mode = str(spec.get("mode") or default_mode)
    payload = build_tm7_payload(
        spec,
        profile,
        mode,
        threat_generation_enabled=_coerce_bool(
            spec.get("threat_generation_enabled"), default=False
        ),
    )
    model = build_threat_dragon_model(spec, payload)
    write_threat_dragon(output_path, model)
    return model


def create_parser() -> argparse.ArgumentParser:
    """Create the CLI parser for Threat Dragon generation."""
    parser = argparse.ArgumentParser(
        description="Generate an OWASP Threat Dragon v2.6.2 model"
    )
    parser.add_argument("spec", type=Path, help="Path to the input threat-model spec")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUTPUT)
    return parser


def main() -> int:
    """CLI entry point."""
    args = create_parser().parse_args()
    try:
        generate(args.spec, args.output)
    except (GenerationError, SchemaError, OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_ERROR
    print(f"Generated {args.output}")
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
