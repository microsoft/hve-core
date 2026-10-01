#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Populate a TM7 model with explicitly mapped threat instances."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

import yaml
from tm7_threat_contract import (
    KNOWLEDGE_NS,
    MODEL_NS,
    XSD_NS,
    ThreatContractError,
    UnsafeXmlError,
    _local_name,
    _normalize_text,
    build_custom_threat_type_id,
    build_entry_key,
    build_interaction_key,
    build_mitigation_text,
    collect_mapping_failures,
    parse_hardened_xml_bytes,
    prepare_threat_instances,
    reconcile_authored_base,
    serialize_threat_instances,
    tm7_serialization_namespaces,
)

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
# SIGINT convention: 128 + signal number.
EXIT_INTERRUPTED = 130

# Namespace constants are re-exported from the shared contract module so callers
# and tests can read them from this entry point.
__all__ = ["KNOWLEDGE_NS", "MODEL_NS", "XSD_NS"]


class GenerationError(Exception):
    """Raised when input validation or population fails."""


def _load_yaml_or_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise GenerationError(f"Spec file not found: {path}")
    try:
        with path.open("r", encoding="utf-8") as handle:
            loaded = (
                json.load(handle)
                if path.suffix.lower() == ".json"
                else yaml.safe_load(handle) or {}
            )
    except (json.JSONDecodeError, yaml.YAMLError, UnicodeDecodeError) as exc:
        raise GenerationError(f"Unable to parse spec: {exc}") from exc
    if not isinstance(loaded, dict):
        raise GenerationError("Spec root must be an object")
    return loaded


def _parse_model(path: Path) -> ET.Element:
    if not path.is_file():
        raise GenerationError(f"TM7 model not found: {path}")
    try:
        return parse_hardened_xml_bytes(path.read_bytes())
    except UnsafeXmlError as exc:
        raise GenerationError(f"Unable to parse TM7 model: {exc}") from exc


def _direct_text(element: ET.Element, name: str) -> str:
    return next(
        (
            _normalize_text(child.text)
            for child in element
            if _local_name(child.tag) == name
        ),
        "",
    )


def _display_name(element: ET.Element) -> str:
    properties = next(
        (child for child in element if _local_name(child.tag) == "Properties"),
        None,
    )
    if properties is None:
        return ""
    for attribute in properties:
        display_name = _direct_text(attribute, "DisplayName")
        if display_name == "Name":
            return _direct_text(attribute, "Value")
    return ""


def _canonical_hash(element: ET.Element | None) -> str:
    if element is None:
        return hashlib.sha256(b"").hexdigest()
    return hashlib.sha256(
        ET.tostring(element, encoding="utf-8", xml_declaration=False)
    ).hexdigest()


def _hash_semantic_subtrees(root: ET.Element) -> dict[str, str]:
    drawing_surface_list = next(
        (child for child in root if _local_name(child.tag) == "DrawingSurfaceList"),
        None,
    )
    knowledge_base = next(
        (child for child in root if _local_name(child.tag) == "KnowledgeBase"),
        None,
    )
    return {
        "drawing_surface_list": _canonical_hash(drawing_surface_list),
        "knowledge_base": _canonical_hash(knowledge_base),
    }


def _find_child(root: ET.Element, name: str) -> ET.Element | None:
    return next(
        (child for child in root if _local_name(child.tag) == name),
        None,
    )


def _find_generation_enabled(root: ET.Element) -> bool:
    node = _find_child(root, "ThreatGenerationEnabled")
    if node is None:
        return False
    return _normalize_text(node.text).lower() == "true"


def _index_model(root: ET.Element) -> dict[str, Any]:
    """Index the embedded KnowledgeBase threat types of a model."""
    type_ids: set[str] = set()
    type_ids_by_title: dict[str, str] = {}
    duplicate_titles: set[str] = set()
    for threat_type in root.findall(".//{*}ThreatType"):
        type_id = _direct_text(threat_type, "Id")
        if type_id:
            type_ids.add(type_id)
        title = _direct_text(threat_type, "ShortTitle")
        if not type_id or not title:
            continue
        if title in type_ids_by_title:
            duplicate_titles.add(title)
        type_ids_by_title[title] = type_id
    for title in duplicate_titles:
        type_ids_by_title.pop(title, None)
    return {
        "type_ids": type_ids,
        "type_ids_by_title": type_ids_by_title,
    }


def _build_authored_base_index(
    spec: dict[str, Any],
    model_root: ET.Element,
) -> dict[str, Any]:
    """Index an authored base model against the spec by stable surface identity.

    An authored drawing surface is bound to its declared surface through the
    deterministic surface GUID, never through list position, so reordering the
    authored surfaces cannot rebind connectors to the wrong diagram. Authored
    surfaces that match no declared surface are indexed with an empty id and are
    ignored by reconciliation.
    """
    index = _index_model(model_root)
    connectors: dict[str, list[dict[str, str]]] = {}
    surfaces: list[dict[str, Any]] = []
    components = {
        _normalize_text(component.get("id")): component
        for component in spec.get("components") or []
        if isinstance(component, dict) and component.get("id")
    }
    declared_by_guid: dict[str, dict[str, Any]] = {}
    representations = spec.get("representations") or {}
    for group in (
        "context_diagrams",
        "functional_scenarios",
        "operational_views",
    ):
        for declared in representations.get(group) or []:
            if not isinstance(declared, dict):
                continue
            declared_id = _normalize_text(declared.get("id"))
            if not declared_id:
                raise GenerationError(
                    "Authored-base reconciliation failed:\n"
                    "a declared surface is missing a stable id"
                )
            expected_guid = _deterministic_guid(f"surface:{declared_id}")
            if expected_guid in declared_by_guid:
                raise GenerationError(
                    "Authored-base reconciliation failed:\n"
                    f"declared surface {declared_id} is defined more than once"
                )
            declared_by_guid[expected_guid] = declared

    for surface in model_root.findall("{*}DrawingSurfaceList/{*}DrawingSurfaceModel"):
        surface_guid = _direct_text(surface, "Guid")
        declared_surface = declared_by_guid.get(surface_guid, {})
        declared_entries = (
            declared_surface.get("components") or declared_surface.get("elements") or []
        )
        expected_names: dict[str, str] = {}
        for entry in declared_entries:
            if not isinstance(entry, dict):
                continue
            element_id = _normalize_text(entry.get("id"))
            component = components.get(element_id, {})
            expected_names[element_id] = _normalize_text(
                entry.get("name") or component.get("name") or element_id
            )

        actual_elements_by_name: dict[str, str] = {}
        borders = next(
            (child for child in surface if _local_name(child.tag) == "Borders"),
            None,
        )
        if borders is not None:
            for entry in borders:
                value = next(
                    (child for child in entry if _local_name(child.tag) == "Value"),
                    None,
                )
                if value is None:
                    continue
                element_guid = _direct_text(value, "Guid")
                element_name = _display_name(value)
                if element_name and element_guid:
                    actual_elements_by_name[element_name] = element_guid
        surface_elements = {
            element_id: actual_elements_by_name[name]
            for element_id, name in expected_names.items()
            if name in actual_elements_by_name
        }
        surface_flow_ids: dict[tuple[str, str], str] = {}
        for flow in spec.get("data_flows") or []:
            if not isinstance(flow, dict):
                continue
            flow_id = _normalize_text(flow.get("id"))
            source_ref = _normalize_text(flow.get("source_ref"))
            target_ref = _normalize_text(flow.get("target_ref"))
            if not flow_id or not source_ref or not target_ref:
                continue
            source_guid = surface_elements.get(source_ref)
            target_guid = surface_elements.get(target_ref)
            if source_guid and target_guid:
                surface_flow_ids[(source_guid, target_guid)] = flow_id
        surfaces.append(
            {
                "id": _normalize_text(declared_surface.get("id")),
                "guid": surface_guid,
                "elements": surface_elements,
            }
        )
        lines = next(
            (child for child in surface if _local_name(child.tag) == "Lines"),
            None,
        )
        if lines is None:
            continue
        for entry in lines:
            value = next(
                (child for child in entry if _local_name(child.tag) == "Value"),
                None,
            )
            if value is None:
                continue
            flow_name = _display_name(value)
            if not flow_name:
                continue
            connector = {
                "surface_id": _normalize_text(declared_surface.get("id")),
                "drawing_surface_guid": surface_guid,
                "flow_guid": _direct_text(value, "Guid"),
                "source_guid": _direct_text(value, "SourceGuid"),
                "target_guid": _direct_text(value, "TargetGuid"),
                "interaction_string": flow_name,
            }
            flow_id = surface_flow_ids.get(
                (
                    connector["source_guid"],
                    connector["target_guid"],
                )
            )
            connectors.setdefault(flow_id or flow_name, []).append(connector)
    return {
        "surfaces": surfaces,
        "connectors": connectors,
        "type_ids": index["type_ids"],
        "type_ids_by_title": index["type_ids_by_title"],
    }


def _resolve_type_id(
    spec_threat: dict[str, Any],
    model_type_ids: set[str],
    type_ids_by_title: dict[str, str],
) -> str:
    source_id = _normalize_text(spec_threat.get("id"))
    if source_id in model_type_ids:
        return source_id
    title_match = type_ids_by_title.get(_normalize_text(spec_threat.get("title")))
    if title_match:
        return title_match
    return build_custom_threat_type_id(source_id)


def _mitigation_text(spec: dict[str, Any], threat: dict[str, Any]) -> str:
    return build_mitigation_text(spec, threat)


def _canonical_surface(spec: dict[str, Any], threat: dict[str, Any]) -> str:
    """Return the declared surface id that carries a threat, or an empty string."""
    representations = spec.get("representations") or {}
    for group in (
        "context_diagrams",
        "functional_scenarios",
        "operational_views",
    ):
        for surface in representations.get(group) or []:
            if not isinstance(surface, dict):
                continue
            members = surface.get("components") or surface.get("elements") or []
            member_ids = {
                _normalize_text(member.get("id"))
                for member in members
                if isinstance(member, dict)
            }
            flow_ids = {
                _normalize_text(item.get("id"))
                if isinstance(item, dict)
                else _normalize_text(item)
                for item in surface.get("flows") or []
            }
            if (
                _normalize_text(threat.get("target_ref")) in member_ids
                and _normalize_text(threat.get("interaction_ref")) in flow_ids
            ):
                return _normalize_text(surface.get("id"))
    return ""


def _deterministic_guid(value: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, value))


def _build_threat_instances(
    spec: dict[str, Any],
    model_root: ET.Element,
    *,
    allow_missing_connectors: bool,
    authored_base_index: dict[str, Any] | None = None,
) -> tuple[list[dict[str, Any]], set[str], list[dict[str, Any]]]:
    index = _index_model(model_root)
    resolved: list[dict[str, Any]] = []
    diagnostics: list[dict[str, Any]] = []
    failures: list[str] = []
    type_ids = index["type_ids"]
    authored_base_index = authored_base_index or _build_authored_base_index(
        spec, model_root
    )

    for threat in spec.get("threats") or []:
        if not isinstance(threat, dict):
            continue
        source_id = _normalize_text(threat.get("id"))
        interaction_ref = _normalize_text(threat.get("interaction_ref"))
        title = _normalize_text(threat.get("title"))
        surface_id = _canonical_surface(spec, threat)
        interaction = None
        if surface_id:
            matching_connectors = authored_base_index.get("connectors", {}).get(
                interaction_ref, []
            )
            if isinstance(matching_connectors, list):
                interaction = next(
                    (
                        value
                        for value in matching_connectors
                        if _normalize_text(value.get("surface_id")) == surface_id
                    ),
                    None,
                )
            if interaction is None and allow_missing_connectors:
                flow = next(
                    (
                        item
                        for item in spec.get("data_flows") or []
                        if isinstance(item, dict)
                        and _normalize_text(item.get("id")) == interaction_ref
                    ),
                    {},
                )
                interaction = {
                    "drawing_surface_guid": _deterministic_guid(
                        f"surface:{surface_id}"
                    ),
                    "flow_guid": _deterministic_guid(f"{surface_id}:{interaction_ref}"),
                    "source_guid": _deterministic_guid(
                        f"{surface_id}:{_normalize_text(flow.get('source_ref'))}"
                    ),
                    "target_guid": _deterministic_guid(
                        f"{surface_id}:{_normalize_text(flow.get('target_ref'))}"
                    ),
                    "interaction_string": _normalize_text(
                        flow.get("display_label") or flow.get("id")
                    ),
                }
        type_id = _resolve_type_id(
            threat,
            type_ids,
            index["type_ids_by_title"],
        )
        if type_id not in type_ids:
            failures.append(
                f"{source_id}: embedded type {type_id} is absent from KnowledgeBase"
            )
            continue
        if interaction is None:
            failures.append(f"{source_id}: connector {interaction_ref} is absent")
            continue
        source_guid = interaction["source_guid"]
        flow_guid = interaction["flow_guid"]
        target_guid = interaction["target_guid"]
        resolved.append(
            {
                "source_id": source_id,
                "target_ref": _normalize_text(threat.get("target_ref")),
                "interaction_ref": interaction_ref,
                "interaction_string": _normalize_text(
                    interaction.get("interaction_string") or interaction_ref
                ),
                "title": title,
                "description": _normalize_text(threat.get("description")) or title,
                "category": _normalize_text(threat.get("category")),
                "state": _normalize_text(threat.get("state")) or "Open",
                "mitigations": _mitigation_text(spec, threat),
                "type_id": type_id,
                "drawing_surface_guid": interaction["drawing_surface_guid"],
                "source_guid": source_guid,
                "flow_guid": flow_guid,
                "target_guid": target_guid,
                "interaction_key": build_interaction_key(
                    source_guid, flow_guid, target_guid
                ),
                "dictionary_key": build_entry_key(
                    type_id, source_guid, flow_guid, target_guid
                ),
            }
        )
        diagnostics.append(
            {
                "source_id": source_id,
                "interaction_ref": interaction_ref,
                "type_id": type_id,
                "drawing_surface_guid": interaction["drawing_surface_guid"],
                "source_guid": source_guid,
                "flow_guid": flow_guid,
                "target_guid": target_guid,
            }
        )
    if failures:
        raise GenerationError(
            "Threat resolution failed:\n" + "\n".join(sorted(failures))
        )
    return resolved, type_ids, diagnostics


def _set_generation_enabled(root: ET.Element, enabled: bool) -> None:
    node = _find_child(root, "ThreatGenerationEnabled")
    if node is None:
        node = ET.SubElement(root, "ThreatGenerationEnabled")
    node.text = "true" if enabled else "false"


def _write_model(root: ET.Element, destination: Path) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(
        mode="wb",
        dir=str(destination.parent),
        prefix=f"{destination.name}.",
        suffix=".tmp",
        delete=False,
    )
    temp_path = Path(handle.name)
    try:
        with tm7_serialization_namespaces(root):
            with handle:
                ET.ElementTree(root).write(
                    handle,
                    encoding="utf-8",
                    xml_declaration=True,
                )
        return temp_path
    except Exception:
        temp_path.unlink(missing_ok=True)
        raise


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def populate_tm7_threats(
    spec_path: str | Path,
    model_path: str | Path,
    output_path: str | Path | None = None,
    *,
    generation_state: bool | None = None,
    expected_threat_count: int | None = None,
) -> dict[str, Any]:
    """Resolve and optionally write explicit threats into an existing model.

    ``expected_threat_count`` is an optional caller assertion. It defaults to
    ``None`` so any internally consistent spec is accepted; a fixed count would
    reject every model of a different size.
    """
    spec = _load_yaml_or_json(Path(spec_path))
    mapping_failures = collect_mapping_failures(
        spec,
        expected_count=expected_threat_count,
    )
    if mapping_failures:
        raise GenerationError(
            "Threat mapping contract validation failed:\n" + "\n".join(mapping_failures)
        )
    model_path = Path(model_path)
    destination = Path(output_path) if output_path is not None else None
    if destination is not None and destination.resolve() == model_path.resolve():
        raise GenerationError(
            f"Refusing to overwrite the immutable base model at {model_path}"
        )
    if destination is not None and generation_state is None:
        generation_state = False

    base_sha256 = _sha256_file(model_path)
    model_root = _parse_model(model_path)
    before_hashes = _hash_semantic_subtrees(model_root)

    authored_base_index = None
    if output_path is not None:
        authored_base_index = _build_authored_base_index(spec, model_root)
        authored_base_failures = reconcile_authored_base(spec, authored_base_index)
        if authored_base_failures:
            raise GenerationError(
                "Authored-base reconciliation failed:\n"
                + "\n".join(authored_base_failures)
            )

    threats, type_ids, diagnostics = _build_threat_instances(
        spec,
        model_root,
        allow_missing_connectors=output_path is None,
        authored_base_index=authored_base_index,
    )
    try:
        prepared = prepare_threat_instances(threats, type_ids=type_ids)
    except ThreatContractError as exc:
        raise GenerationError(str(exc)) from exc

    selected_state = (
        _find_generation_enabled(model_root)
        if generation_state is None
        else generation_state
    )
    serialize_threat_instances(model_root, threats, type_ids=type_ids)
    _set_generation_enabled(model_root, selected_state)
    after_hashes = _hash_semantic_subtrees(model_root)
    if before_hashes != after_hashes:
        raise GenerationError(
            "Threat population mutated the DrawingSurfaceList or KnowledgeBase subtree"
        )
    if _sha256_file(model_path) != base_sha256:
        raise GenerationError("The immutable base model changed during population")

    referenced_type_ids = {item["type_id"] for item in prepared}

    result = {
        "ThreatGenerationEnabled": selected_state,
        "ThreatInstances": prepared,
        "KnowledgeBaseTypeIds": sorted(type_ids),
        "counts": {
            "threat_instances": len(prepared),
            "custom_types": len(referenced_type_ids),
            "source_mappings": len(diagnostics),
        },
        "hashes": {
            "drawing_surface_list_before": before_hashes["drawing_surface_list"],
            "drawing_surface_list_after": after_hashes["drawing_surface_list"],
            "knowledge_base_before": before_hashes["knowledge_base"],
            "knowledge_base_after": after_hashes["knowledge_base"],
            "base_sha256_before": base_sha256,
            "base_sha256_after": _sha256_file(model_path),
        },
        "state": {
            "generation_state": selected_state,
            "source_path": str(model_path),
            "output_path": str(output_path) if output_path is not None else None,
            "in_place": False,
        },
        "diagnostics": {
            "mapping_failures": mapping_failures,
            "mappings": diagnostics,
        },
    }

    if output_path is None:
        return result

    assert destination is not None
    temp_path = _write_model(model_root, destination)
    try:
        written_root = _parse_model(temp_path)
        written_hashes = _hash_semantic_subtrees(written_root)
        if written_hashes != after_hashes:
            raise GenerationError("Post-write semantic hashes did not validate")
        written_state = _find_generation_enabled(written_root)
        written_instances = len(
            written_root.findall(
                "{*}ThreatInstances/{*}KeyValueOfstringThreatpc_P0_PhOB"
            )
        )
        if written_state != selected_state or written_instances != len(prepared):
            raise GenerationError("Post-write validation failed")
        os.replace(temp_path, destination)
    except Exception:
        temp_path.unlink(missing_ok=True)
        raise

    result["state"]["output_path"] = str(destination)
    result["state"]["in_place"] = False
    return result


def create_parser() -> argparse.ArgumentParser:
    """Create the population command-line parser."""
    parser = argparse.ArgumentParser(
        description="Populate a TM7 file with explicit threats"
    )
    parser.add_argument("spec", type=Path, help="Input threat-model spec")
    parser.add_argument("model", type=Path, help="Base TM7 model")
    parser.add_argument("-o", "--output", type=Path, default=None)
    parser.add_argument(
        "--generation-state",
        choices=["true", "false"],
        default=None,
        help="Explicitly set ThreatGenerationEnabled in the output",
    )
    parser.add_argument(
        "--expected-threat-count",
        type=int,
        default=None,
        help=(
            "Assert the spec declares exactly this many unique threat ids. "
            "Omit to accept any internally consistent count."
        ),
    )
    return parser


def main() -> int:
    """Run the TM7 population command."""
    args = create_parser().parse_args()
    try:
        generation_state = None
        if args.generation_state is not None:
            generation_state = args.generation_state.lower() == "true"
        result = populate_tm7_threats(
            args.spec,
            args.model,
            args.output,
            generation_state=generation_state,
            expected_threat_count=args.expected_threat_count,
        )
    except GenerationError as exc:
        print(str(exc), file=sys.stderr)
        return EXIT_FAILURE
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return EXIT_INTERRUPTED
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_FAILURE
    print(
        f"Populated {len(result['ThreatInstances'])} threat instances with "
        f"ThreatGenerationEnabled={result['ThreatGenerationEnabled']}"
    )
    return EXIT_SUCCESS


if __name__ == "__main__":
    raise SystemExit(main())
