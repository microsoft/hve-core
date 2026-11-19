#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate a deterministic native TB7 template from a vendor-neutral spec."""

from __future__ import annotations

import argparse
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
    UnsafeXmlError,
    _coerce_list,
    _local_name,
    _make_guid,
    _normalize_text,
    parse_hardened_xml_bytes,
)


class GenerationError(Exception):
    """Raised when input validation or generation fails."""

    def __init__(self, message: str, exit_code: int = 1) -> None:
        super().__init__(message)
        self.exit_code = exit_code


def _load_yaml_or_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise GenerationError(f"Spec file not found: {path}")
    try:
        with path.open("r", encoding="utf-8") as handle:
            if path.suffix.lower() == ".json":
                loaded = json.load(handle)
            else:
                loaded = yaml.safe_load(handle) or {}
    except (json.JSONDecodeError, yaml.YAMLError, UnicodeDecodeError) as exc:
        raise GenerationError(f"Unable to parse spec: {exc}") from exc
    if not isinstance(loaded, dict):
        raise GenerationError("Spec root must be an object")
    return loaded


def _stable_type_id(source_template: Path, source_id: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"{source_template}:{source_id}"))


def _build_generation_filters() -> ET.Element:
    element = ET.Element("GenerationFilters")
    include = ET.SubElement(element, "Include")
    include.text = "source is 'ROOT'"
    exclude = ET.SubElement(element, "Exclude")
    exclude.text = ""
    return element


def _build_property_metadata() -> ET.Element:
    properties = ET.Element("PropertiesMetaData")
    names = [
        ("UserThreatDescription", "Description"),
        ("PossibleMitigations", "Possible Mitigations"),
        ("Priority", "Priority"),
        ("SDLPhase", "SDL Phase"),
    ]
    for name, label in names:
        datum = ET.SubElement(properties, "ThreatMetaDatum")
        name_el = ET.SubElement(datum, "Name")
        name_el.text = name
        label_el = ET.SubElement(datum, "Label")
        label_el.text = label
        values = ET.SubElement(datum, "Values")
        ET.SubElement(values, "Value")
        id_el = ET.SubElement(datum, "Id")
        # The metadatum identity is fixed by its property name, so it is
        # derived from that name. A random identifier contradicted this
        # module's deterministic contract and made two runs over identical
        # input produce templates that never compared equal.
        id_el.text = _make_guid(f"tb7:property-metadata:{name}")
        attribute_type = ET.SubElement(datum, "AttributeType")
        attribute_type.text = "0"
    return properties


def _build_threat_type(
    spec_threat: dict[str, Any],
    source_template: Path,
    spec: dict[str, Any],
) -> ET.Element:
    threat_type = ET.Element("ThreatType")
    threat_type.append(_build_generation_filters())
    threat_id = ET.SubElement(threat_type, "Id")
    threat_id.text = _stable_type_id(source_template, str(spec_threat.get("id", "")))
    short_title = ET.SubElement(threat_type, "ShortTitle")
    short_title.text = _normalize_text(spec_threat.get("title")) or "Threat"
    category = ET.SubElement(threat_type, "Category")
    category.text = _map_category_to_native_category(spec_threat.get("category"))
    description = ET.SubElement(threat_type, "Description")
    description.text = (
        _normalize_text(spec_threat.get("description")) or short_title.text
    )
    properties = _build_property_metadata()
    threat_type.append(properties)

    values = {
        "UserThreatDescription": _normalize_text(spec_threat.get("description"))
        or short_title.text,
        "PossibleMitigations": _build_mitigation_values(
            spec_threat,
            spec,
            spec_threat.get("mitigation_ids"),
        ),
        "Priority": "Medium",
        "SDLPhase": "Design",
    }
    for datum in properties.findall("ThreatMetaDatum"):
        name = datum.findtext("Name")
        values_for_name = values.get(name, "")
        if name == "PossibleMitigations":
            values_el = datum.find("Values")
            assert values_el is not None
            values_el.clear()
            if isinstance(values_for_name, list):
                for value in values_for_name:
                    value_el = ET.SubElement(values_el, "Value")
                    value_el.text = value
            elif values_for_name:
                value_el = ET.SubElement(values_el, "Value")
                value_el.text = values_for_name
        else:
            values_el = datum.find("Values")
            if values_el is None:
                continue
            values_el.clear()
            if values_for_name:
                value_el = ET.SubElement(values_el, "Value")
                value_el.text = values_for_name
    return threat_type


def _map_category_to_native_category(category: Any) -> str:
    mapping = {
        "tampering": "T",
        "spoofing": "S",
        "repudiation": "R",
        "information-disclosure": "I",
        "denial-of-service": "D",
        "elevation-of-privilege": "E",
    }
    if not category:
        return "T"
    normalized = str(category).strip().lower()
    return mapping.get(normalized, "T")


def _build_mitigation_values(
    spec_threat: dict[str, Any],
    spec: dict[str, Any],
    mitigation_ids: Any,
) -> list[str]:
    values: list[str] = []
    citations = spec_threat.get("citations")
    if isinstance(citations, dict):
        if isinstance(citations.get("stride"), list):
            stride_values = [str(item) for item in citations["stride"] if str(item)]
            if stride_values:
                values.append("STRIDE: " + ", ".join(stride_values))
        if isinstance(citations.get("nist"), list):
            nist_values = [str(item) for item in citations["nist"] if str(item)]
            if nist_values:
                values.append("NIST: " + ", ".join(nist_values))

    mitigations = {
        str(item.get("id", "")): str(item.get("name", ""))
        for item in _coerce_list(spec.get("mitigations"))
        if isinstance(item, dict)
    }
    mitigation_names: list[str] = []
    for mitigation_id in _coerce_list(mitigation_ids):
        if isinstance(mitigation_id, str) and mitigation_id:
            resolved_name = mitigations.get(mitigation_id, mitigation_id)
            if resolved_name:
                mitigation_names.append(resolved_name)
            else:
                mitigation_names.append(mitigation_id)
    if mitigation_names:
        values.append("Mitigations: " + ", ".join(mitigation_names))
    return values or ["No mitigations specified"]


def _load_source_template(path: Path) -> ET.Element:
    if not path.exists():
        raise GenerationError(f"Source template not found: {path}")
    # The template is read through the same fail-closed policy as every other
    # XML reader. Plain `ET.parse` rejected an undefined entity only as a side
    # effect of ElementTree's behavior, not as a declared control.
    try:
        return parse_hardened_xml_bytes(path.read_bytes())
    except UnsafeXmlError as exc:
        raise GenerationError(f"Unable to parse source template: {exc}") from exc


def _clone_manifest(source_root: ET.Element, spec: dict[str, Any]) -> ET.Element:
    manifest = ET.Element("Manifest")
    name = _normalize_text(spec.get("project_metadata", {}).get("name"))
    manifest.set("name", f"{name} Threat Model Template")
    manifest.set(
        "id",
        _make_guid(f"tb7:{spec.get('project_metadata', {}).get('name', 'template')}"),
    )
    manifest.set(
        "version",
        _normalize_text(spec.get("project_metadata", {}).get("version")) or "1.0",
    )
    manifest.set("author", "Microsoft Security Planning")
    return manifest


def _clone_threat_types(
    source_root: ET.Element,
    spec: dict[str, Any],
    source_template: Path,
) -> list[ET.Element]:
    threat_types = []
    for spec_threat in _coerce_list(spec.get("threats")):
        if not isinstance(spec_threat, dict):
            continue
        threat_types.append(_build_threat_type(spec_threat, source_template, spec))
    return threat_types


def generate_tb7(
    spec_path: Path,
    source_template_path: Path,
    output_path: Path,
) -> Path:
    spec = _load_yaml_or_json(spec_path)
    source_root = _load_source_template(source_template_path)
    root = ET.Element(source_root.tag)
    for child in source_root:
        if _local_name(child.tag) == "Manifest":
            root.append(_clone_manifest(source_root, spec))
        elif _local_name(child.tag) == "ThreatTypes":
            threat_types = ET.SubElement(root, "ThreatTypes")
            for stock_type in child.findall("ThreatType"):
                threat_types.append(stock_type)
            for appended_type in _clone_threat_types(
                source_root,
                spec,
                source_template_path,
            ):
                threat_types.append(appended_type)
        else:
            root.append(copy_element(child))
    tree = ET.ElementTree(root)
    _write_tb7_tree(tree, output_path)
    return output_path


def _write_tb7_tree(tree: ET.ElementTree, output_path: Path) -> None:
    """Write a TB7 tree through a sibling temporary file.

    Writing directly required the destination directory to already exist, so a
    nested output path raised an unhandled ``FileNotFoundError`` that escaped
    the CLI as a traceback. The write is also staged through a sibling
    temporary file so a failure part-way through leaves any prior template
    intact instead of a truncated one.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(  # noqa: SIM115 - closed in the with below
        mode="wb",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
        delete=False,
    )
    temporary_path = Path(handle.name)
    try:
        with handle:
            tree.write(handle, encoding="utf-8", xml_declaration=True)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, output_path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def copy_element(element: ET.Element) -> ET.Element:
    clone = ET.Element(element.tag, element.attrib)
    for child in element:
        clone.append(copy_element(child))
    clone.text = element.text
    clone.tail = element.tail
    return clone


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate a native TB7 template")
    parser.add_argument("spec", type=Path, help="Path to the input threat-model spec")
    parser.add_argument(
        "source_template",
        type=Path,
        help="Path to the source TB7 template",
    )
    parser.add_argument("-o", "--output", type=Path, default=Path("out.tb7"))
    return parser


def main() -> int:
    parser = create_parser()
    args = parser.parse_args()
    try:
        output_path = generate_tb7(args.spec, args.source_template, args.output)
    except GenerationError as exc:
        print(str(exc), file=sys.stderr)
        return exc.exit_code
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return 1
    print(output_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
