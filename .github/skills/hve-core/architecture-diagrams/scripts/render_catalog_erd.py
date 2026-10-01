#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Render a declared DS_CATALOG_V1 model as Mermaid or ASCII.

Usage:
    uv run python scripts/render_catalog_erd.py catalog.md --format mermaid
"""

from __future__ import annotations

import argparse
import datetime as dt
import math
import re
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

CONFIDENCE_VALUES = ("confirmed", "inferred", "assumed")
MINIMUM_VALUES = ("zero", "one")

# Operational bound checked before any catalog content is read.
MAX_INPUT_BYTES = 5 * 1024 * 1024
MERGE_TAG = "tag:yaml.org,2002:merge"

# Output-safety bounds. Every projected display value is rejected at the
# boundary rather than escaped, so no declared value can change the structure
# of the emitted Markdown or Mermaid.
MAX_DISPLAY_TEXT_LENGTH = 120
FORBIDDEN_DISPLAY_SUBSTRINGS = ("```", "%%{", "<", ">", "{", "}", '"')
MERMAID_ATTRIBUTE_TOKEN_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
MERMAID_ATTRIBUTE_TYPE = "string"
EXPECTED_FENCE_COUNT = 2
DEFAULT_HEADING_LEVEL = 2
MAX_HEADING_LEVEL = 5

# Maximum multiplicity for each endpoint, derived from the declared cardinality.
CARDINALITY_MAXIMUMS = {
    "one-to-one": ("one", "one"),
    "one-to-many": ("one", "many"),
    "many-to-many": ("many", "many"),
}

# Mermaid erDiagram notation keyed by (minimum, maximum). The left form mirrors
# the right so each marker points away from the entity it constrains.
MERMAID_LEFT = {
    ("zero", "one"): "|o",
    ("one", "one"): "||",
    ("zero", "many"): "}o",
    ("one", "many"): "}|",
}
MERMAID_RIGHT = {
    ("zero", "one"): "o|",
    ("one", "one"): "||",
    ("zero", "many"): "o{",
    ("one", "many"): "|{",
}
ASCII_MULTIPLICITY = {
    ("zero", "one"): "0..1",
    ("one", "one"): "1",
    ("zero", "many"): "0..*",
    ("one", "many"): "1..*",
}


class CatalogRenderError(ValueError):
    """Raised when a catalog cannot be rendered safely."""


class UniqueKeyLoader(yaml.SafeLoader):
    """Loader rejecting aliases, anchors, tags, merge keys, and duplicate keys."""

    def compose_node(self, parent: yaml.nodes.Node | None, index: Any) -> yaml.nodes.Node:
        """Reject alias, anchor, and explicit-tag events before composition."""
        event = self.peek_event()
        if isinstance(event, yaml.AliasEvent):
            raise CatalogRenderError("catalog YAML aliases are not permitted")
        if getattr(event, "anchor", None) is not None:
            raise CatalogRenderError("catalog YAML anchors are not permitted")
        if getattr(event, "tag", None) is not None:
            raise CatalogRenderError("catalog YAML explicit tags are not permitted")
        return super().compose_node(parent, index)


def _construct_unique_mapping(
    loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False
) -> dict[str, Any]:
    """Construct one mapping while rejecting merge keys and duplicate keys."""
    mapping: dict[str, Any] = {}
    for key_node, value_node in node.value:
        if key_node.tag == MERGE_TAG:
            raise CatalogRenderError("catalog YAML merge keys are not permitted")
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str):
            raise CatalogRenderError("catalog YAML keys must be strings")
        if key in mapping:
            raise CatalogRenderError(f"duplicate catalog YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


def _reject_tagged_node(loader: UniqueKeyLoader, tag_suffix: str, node: yaml.nodes.Node) -> Any:
    """Reject any node carrying a tag without a registered safe constructor."""
    raise CatalogRenderError("catalog YAML explicit tags are not permitted")


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
)
UniqueKeyLoader.add_multi_constructor("", _reject_tagged_node)


def _sanitize_yaml_error(error: yaml.YAMLError) -> str:
    """Describe a YAML failure by position only, never by source content."""
    mark = getattr(error, "problem_mark", None) or getattr(error, "context_mark", None)
    if mark is None:
        return f"invalid catalog YAML ({type(error).__name__})"
    return (
        f"invalid catalog YAML ({type(error).__name__}) at line {mark.line + 1} "
        f"column {mark.column + 1}"
    )


def _skill_root() -> Path:
    """Return the skill root that owns this renderer."""
    return Path(__file__).resolve().parent.parent


def _resolve_input_path(path: Path, allowed_roots: Sequence[Path]) -> Path:
    """Return a resolved input path contained by one permitted root."""
    segments = str(path).replace("\\", "/").split("/")
    if any(segment == ".." for segment in segments):
        raise CatalogRenderError("input path cannot contain '..' segments")
    resolved = path.resolve()
    for root in allowed_roots:
        if resolved.is_relative_to(root.resolve()):
            return resolved
    raise CatalogRenderError("input path resolves outside the permitted roots")


def read_catalog_text(path: Path, allowed_roots: Sequence[Path] | None = None) -> str:
    """Read a size-bounded catalog file from a permitted root."""
    roots = tuple(allowed_roots) if allowed_roots else (Path.cwd(), _skill_root())
    resolved = _resolve_input_path(path, roots)
    if resolved.stat().st_size > MAX_INPUT_BYTES:
        raise CatalogRenderError(f"catalog exceeds the {MAX_INPUT_BYTES} byte input limit")
    return resolved.read_text(encoding="utf-8")


def _assert_json_compatible(value: Any, path: str = "$") -> None:
    """Reject YAML-native values outside the JSON data model."""
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            raise CatalogRenderError(f"{path} must be a finite number")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _assert_json_compatible(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise CatalogRenderError(f"{path} has a non-string key")
            _assert_json_compatible(item, f"{path}.{key}")
        return
    if isinstance(value, dt.date):
        raise CatalogRenderError(f"{path} timestamp must be a quoted string")
    raise CatalogRenderError(f"{path} contains non-JSON YAML value {type(value).__name__}")


def extract_frontmatter(markdown: str) -> str:
    """Extract YAML frontmatter from a Markdown catalog."""
    lines = markdown.splitlines()
    if not lines or lines[0] != "---":
        raise CatalogRenderError("catalog must start with YAML frontmatter")
    try:
        closing = lines.index("---", 1)
    except ValueError as error:
        raise CatalogRenderError("catalog frontmatter is not closed") from error
    return "\n".join(lines[1:closing])


def parse_catalog(markdown: str) -> dict[str, Any]:
    """Parse a catalog and reject every malformed rendering-critical fact."""
    try:
        data = yaml.load(extract_frontmatter(markdown), Loader=UniqueKeyLoader)
    except CatalogRenderError:
        raise
    except yaml.YAMLError as error:
        raise CatalogRenderError(_sanitize_yaml_error(error)) from error
    except ValueError as error:
        raise CatalogRenderError("catalog frontmatter has an invalid scalar value") from error
    if not isinstance(data, dict):
        raise CatalogRenderError("catalog frontmatter must be an object")
    _assert_json_compatible(data)
    if data.get("catalog_version") != "DS_CATALOG_V1":
        raise CatalogRenderError("unsupported catalog_version; expected DS_CATALOG_V1")

    entities = data.get("entities")
    relationships = data.get("relationships")
    if not isinstance(entities, list) or not isinstance(relationships, list):
        raise CatalogRenderError("catalog entities and relationships must be arrays")

    entity_ids: set[str] = set()
    for entity in entities:
        if not isinstance(entity, dict):
            raise CatalogRenderError("every catalog entity must be an object")
        entity_id = _require_nonempty_string(entity.get("id"), "entity id")
        _require_nonempty_string(entity.get("name"), f"entity {entity_id} name")
        if entity_id in entity_ids:
            raise CatalogRenderError(f"duplicate catalog entity id: {entity_id}")
        entity_ids.add(entity_id)

    relationship_ids: set[str] = set()
    for relationship in relationships:
        if not isinstance(relationship, dict):
            raise CatalogRenderError("every catalog relationship must be an object")
        relationship_id = _require_nonempty_string(relationship.get("id"), "relationship id")
        if relationship_id in relationship_ids:
            raise CatalogRenderError(f"duplicate catalog relationship id: {relationship_id}")
        relationship_ids.add(relationship_id)

        if relationship.get("from") not in entity_ids or relationship.get("to") not in entity_ids:
            raise CatalogRenderError(
                f"relationship {relationship_id} endpoints must resolve declared entities"
            )
        if relationship.get("cardinality") not in CARDINALITY_MAXIMUMS:
            raise CatalogRenderError(f"relationship {relationship_id} cardinality is unsupported")
        for side in ("from_minimum", "to_minimum"):
            if relationship.get(side) not in MINIMUM_VALUES:
                raise CatalogRenderError(
                    f"relationship {relationship_id} {side} must be 'zero' or 'one'"
                )
        if relationship.get("confidence") not in CONFIDENCE_VALUES:
            raise CatalogRenderError(f"relationship {relationship_id} confidence is unsupported")
        _require_nonempty_string(relationship.get("basis"), f"relationship {relationship_id} basis")
        _validate_join_keys(relationship.get("join_keys"), relationship_id)
    assert_render_safe(data)
    return data


def _require_nonempty_string(value: Any, description: str) -> str:
    """Return a non-empty string value or raise a render error."""
    if not isinstance(value, str) or not value.strip():
        raise CatalogRenderError(f"{description} must be a non-empty string")
    return value


def _require_display_text(value: Any, description: str) -> str:
    """Return a bounded single-line value safe to place in generated output."""
    text = _require_nonempty_string(value, description)
    if len(text) > MAX_DISPLAY_TEXT_LENGTH:
        raise CatalogRenderError(
            f"{description} exceeds {MAX_DISPLAY_TEXT_LENGTH} display characters"
        )
    if "\n" in text or "\r" in text:
        raise CatalogRenderError(f"{description} must be a single line")
    for forbidden in FORBIDDEN_DISPLAY_SUBSTRINGS:
        if forbidden in text:
            raise CatalogRenderError(f"{description} cannot contain the sequence {forbidden!r}")
    return text


def _require_attribute_token(value: Any, description: str) -> str:
    """Return a value usable as a Mermaid ER attribute token."""
    token = _require_nonempty_string(value, description)
    if MERMAID_ATTRIBUTE_TOKEN_PATTERN.match(token) is None:
        raise CatalogRenderError(f"{description} is not a valid Mermaid attribute token")
    return token


def assert_render_safe(data: dict[str, Any]) -> None:
    """Reject every projected value that could escape its output boundary.

    Runs before any emission. Identifiers are validated before they appear in
    an error message so no unvalidated value reaches an operator log.
    """
    engagement = data.get("engagement")
    if isinstance(engagement, str) and engagement.strip():
        _require_display_text(engagement, "engagement")

    for index, entity in enumerate(data.get("entities", [])):
        entity_id = _require_display_text(entity.get("id"), f"entity[{index}] id")
        _require_display_text(entity.get("name"), f"entity {entity_id} name")

    for index, relationship in enumerate(data.get("relationships", [])):
        relationship_id = _require_display_text(relationship.get("id"), f"relationship[{index}] id")
        _require_display_text(relationship.get("basis"), f"relationship {relationship_id} basis")
        _validate_join_keys(relationship.get("join_keys"), relationship_id)

    _node_ids(data.get("entities", []))


def _validate_join_keys(join_keys: Any, relationship_id: str) -> list[tuple[str, str]]:
    """Return ordered join-key pairs, rejecting any malformed declaration."""
    if not isinstance(join_keys, dict):
        raise CatalogRenderError(f"relationship {relationship_id} join_keys must be an object")
    from_field = join_keys.get("from_field")
    to_field = join_keys.get("to_field")

    if isinstance(from_field, str) and isinstance(to_field, str):
        from_values: list[Any] = [from_field]
        to_values: list[Any] = [to_field]
    elif isinstance(from_field, list) and isinstance(to_field, list):
        from_values = from_field
        to_values = to_field
    else:
        raise CatalogRenderError(
            f"relationship {relationship_id} join keys must both be strings or both be arrays"
        )

    if not from_values or len(from_values) != len(to_values):
        raise CatalogRenderError(
            f"relationship {relationship_id} join keys must be non-empty and of equal length"
        )
    pairs = list(zip(from_values, to_values, strict=True))
    for index, (source, target) in enumerate(pairs):
        _require_attribute_token(source, f"relationship {relationship_id} from_field[{index}]")
        _require_attribute_token(target, f"relationship {relationship_id} to_field[{index}]")
    return pairs


def _safe_identifier(entity_id: str) -> str:
    """Derive a Mermaid-safe identifier by escaping every character outside a-z0-9."""
    escaped = re.sub(r"[^a-z0-9]", lambda match: f"_{ord(match.group()):02x}", entity_id.lower())
    return f"entity_{escaped}"


def _node_ids(entities: Sequence[dict[str, Any]]) -> dict[str, str]:
    """Map every entity ID to a distinct, deterministic Mermaid identifier.

    Two entity IDs that sanitize to the same token are disambiguated by an
    incrementing suffix in declaration order rather than merged into one node.
    """
    assigned: dict[str, str] = {}
    used: set[str] = set()
    for entity in entities:
        entity_id = entity["id"]
        base = _safe_identifier(entity_id)
        token = base
        suffix = 2
        while token in used:
            token = f"{base}_{suffix}"
            suffix += 1
        if MERMAID_ATTRIBUTE_TOKEN_PATTERN.match(token) is None:
            raise CatalogRenderError(f"entity {entity_id} yields an unsafe Mermaid identifier")
        used.add(token)
        assigned[entity_id] = token
    return assigned


def _quote(value: str) -> str:
    """Make a value safe to embed inside a Mermaid double-quoted string."""
    return value.replace('"', "'")


def _endpoints(relationship: dict[str, Any]) -> tuple[tuple[str, str], tuple[str, str]]:
    """Return the (minimum, maximum) pair for each relationship endpoint."""
    from_max, to_max = CARDINALITY_MAXIMUMS[relationship["cardinality"]]
    return (
        (relationship["from_minimum"], from_max),
        (relationship["to_minimum"], to_max),
    )


def _join_key_label(relationship: dict[str, Any]) -> str:
    """Render ordered join-key pairs without implying a key role."""
    pairs = _validate_join_keys(relationship["join_keys"], relationship["id"])
    return ", ".join(f"{source} = {target}" for source, target in pairs)


def _confidence_suffix(confidence: str) -> str:
    """Return the label suffix for a confidence value."""
    return "" if confidence == "confirmed" else f" ({confidence})"


def _heading_level(level: int) -> int:
    """Return a heading level that keeps every emitted heading within Markdown."""
    if not isinstance(level, int) or isinstance(level, bool):
        raise CatalogRenderError("heading level must be an integer")
    if not 1 <= level <= MAX_HEADING_LEVEL:
        raise CatalogRenderError(f"heading level must be between 1 and {MAX_HEADING_LEVEL}")
    return level


def _engagement_name(data: dict[str, Any]) -> str:
    """Return the catalog engagement name used in titles and descriptions."""
    engagement = data.get("engagement")
    return engagement if isinstance(engagement, str) and engagement.strip() else "Catalog"


def _title(data: dict[str, Any], level: int) -> str:
    """Return the catalog output title at the caller-selected depth."""
    return f"{'#' * level} {_engagement_name(data)} Data Model"


def _section(text: str, level: int) -> str:
    """Return a section heading one level below the document title."""
    return f"{'#' * (level + 1)} {text}"


def _entity_lines(data: dict[str, Any]) -> list[str]:
    """Return the Entities section body carrying business names and IDs."""
    return [f"* `{entity['id']}`: {entity['name']}" for entity in data["entities"]]


def _key_relationship_lines(data: dict[str, Any]) -> list[str]:
    """Return the Key Relationships section body."""
    entity_by_id = {entity["id"]: entity for entity in data["entities"]}
    if not data["relationships"]:
        return ["No relationships are declared in this catalog."]

    lines = []
    for relationship in data["relationships"]:
        source = entity_by_id[relationship["from"]]
        target = entity_by_id[relationship["to"]]
        (from_min, from_max), (to_min, to_max) = _endpoints(relationship)
        lines.append(
            f"* `{relationship['id']}`: {source['name']} (`{source['id']}`, "
            f"{ASCII_MULTIPLICITY[from_min, from_max]}) to {target['name']} "
            f"(`{target['id']}`, {ASCII_MULTIPLICITY[to_min, to_max]}); cardinality "
            f"`{relationship['cardinality']}` with minima `{from_min}` and `{to_min}`; "
            f"join keys {_join_key_label(relationship)}; confidence "
            f"`{relationship['confidence']}` because {relationship['basis']}"
        )
    return lines


def _shared_sections(data: dict[str, Any], level: int, legend: list[str]) -> list[str]:
    """Return the Entities, Legend, and Key Relationships sections."""
    lines = ["", _section("Entities", level), ""]
    lines.extend(_entity_lines(data))
    lines.extend(["", _section("Legend", level), ""])
    lines.extend(legend)
    lines.extend(["", _section("Key Relationships", level), ""])
    lines.extend(_key_relationship_lines(data))
    return lines


def _assert_fence_integrity(rendered: str) -> None:
    """Confirm no declared value changed the emitted code-fence structure."""
    if rendered.count("```") != EXPECTED_FENCE_COUNT:
        raise CatalogRenderError("rendered output has an unexpected code-fence count")


def render_mermaid(data: dict[str, Any], heading_level: int = DEFAULT_HEADING_LEVEL) -> str:
    """Render declared entities and relationships as a Mermaid ER diagram."""
    level = _heading_level(heading_level)
    assert_render_safe(data)
    name = _engagement_name(data)
    node_ids = _node_ids(data["entities"])
    lines = [
        _title(data, level),
        "",
        "```mermaid",
        "erDiagram",
        f"    accTitle: {name} Data Model",
        (
            f"    accDescr: Entity relationship diagram of {len(data['entities'])} declared "
            f"entities and {len(data['relationships'])} declared relationships in the "
            f"{name} catalog."
        ),
    ]

    attributes: dict[str, list[str]] = {entity["id"]: [] for entity in data["entities"]}
    for relationship in data["relationships"]:
        for source, target in _validate_join_keys(relationship["join_keys"], relationship["id"]):
            attributes[relationship["from"]].append(source)
            attributes[relationship["to"]].append(target)

    for entity in data["entities"]:
        lines.append(f'    {node_ids[entity["id"]]}["{_quote(entity["name"])}"] {{')
        seen: set[str] = set()
        for field in attributes[entity["id"]]:
            if field not in seen:
                seen.add(field)
                lines.append(f"        {MERMAID_ATTRIBUTE_TYPE} {field}")
        lines.append("    }")

    for relationship in data["relationships"]:
        (from_min, from_max), (to_min, to_max) = _endpoints(relationship)
        notation = f"{MERMAID_LEFT[from_min, from_max]}--{MERMAID_RIGHT[to_min, to_max]}"
        label = _join_key_label(relationship) + _confidence_suffix(relationship["confidence"])
        lines.append(
            f"    {node_ids[relationship['from']]} {notation} "
            f'{node_ids[relationship["to"]]} : "{_quote(label)}"'
        )
    lines.append("```")

    lines.extend(
        _shared_sections(
            data,
            level,
            [
                (
                    "* `||` requires exactly one, `|o` allows zero or one, `}|` requires "
                    "one or many, and `}o` allows zero or many on that side."
                ),
                (
                    "* Attributes list declared join-key field names only. They do not "
                    "declare primary keys, foreign keys, or uniqueness."
                ),
                (
                    "* Labels show the declared join-key pairing. An unmarked label is "
                    "`confirmed`; `(inferred)` and `(assumed)` mark unconfirmed "
                    "relationships."
                ),
                (
                    "* All connectors are solid. Identifying and non-identifying "
                    "semantics are not modelled by this catalog."
                ),
            ],
        )
    )
    rendered = "\n".join(lines) + "\n"
    _assert_fence_integrity(rendered)
    return rendered


def render_ascii(data: dict[str, Any], heading_level: int = DEFAULT_HEADING_LEVEL) -> str:
    """Render declared entities and relationships as compact ASCII."""
    level = _heading_level(heading_level)
    assert_render_safe(data)
    lines = [_title(data, level), "", "```text", "Entities:"]
    for entity in data["entities"]:
        lines.append(f"  [{entity['name']}] ({entity['id']})")

    lines.extend(["", "Relationships:"])
    if data["relationships"]:
        entity_by_id = {entity["id"]: entity for entity in data["entities"]}
        for relationship in data["relationships"]:
            (from_min, from_max), (to_min, to_max) = _endpoints(relationship)
            label = _join_key_label(relationship) + _confidence_suffix(relationship["confidence"])
            source = entity_by_id[relationship["from"]]
            target = entity_by_id[relationship["to"]]
            lines.append(
                f"  [{source['name']}] ({relationship['from']}) "
                f"{ASCII_MULTIPLICITY[from_min, from_max]} --- "
                f"{ASCII_MULTIPLICITY[to_min, to_max]} "
                f"[{target['name']}] ({relationship['to']}) : {label}"
            )
    else:
        lines.append("  No relationships are declared in this catalog.")
    lines.append("```")

    lines.extend(
        _shared_sections(
            data,
            level,
            [
                (
                    "* `1` requires exactly one, `0..1` allows zero or one, `1..*` "
                    "requires one or many, and `0..*` allows zero or many on that side."
                ),
                "* Each multiplicity sits beside the entity it constrains.",
                (
                    "* Join-key pairs show declared field names only. They do not declare "
                    "primary keys, foreign keys, or uniqueness."
                ),
                (
                    "* An unmarked relationship is `confirmed`; `(inferred)` and "
                    "`(assumed)` mark unconfirmed relationships."
                ),
            ],
        )
    )
    rendered = "\n".join(lines) + "\n"
    _assert_fence_integrity(rendered)
    return rendered


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Render declared DS_CATALOG_V1 relationships as an ERD"
    )
    parser.add_argument("catalog", type=Path, help="DS_CATALOG_V1 Markdown catalog")
    parser.add_argument(
        "--format",
        choices=("ascii", "mermaid"),
        required=True,
        help="Caller-selected output format",
    )
    parser.add_argument(
        "--heading-level",
        type=int,
        default=DEFAULT_HEADING_LEVEL,
        choices=range(1, MAX_HEADING_LEVEL + 1),
        help="Markdown depth of the rendered title in the host document",
    )
    return parser


def run(
    catalog_path: Path,
    output_format: str,
    heading_level: int = DEFAULT_HEADING_LEVEL,
    allowed_roots: Sequence[Path] | None = None,
) -> int:
    """Read one catalog and print its ERD."""
    try:
        data = parse_catalog(read_catalog_text(catalog_path, allowed_roots))
        rendered = (
            render_mermaid(data, heading_level)
            if output_format == "mermaid"
            else render_ascii(data, heading_level)
        )
    except (OSError, CatalogRenderError) as error:
        print(f"render_catalog_erd: {error}", file=sys.stderr)
        return EXIT_ERROR
    print(rendered, end="")
    return EXIT_SUCCESS


def main() -> int:
    """Run the catalog ERD renderer."""
    args = create_parser().parse_args()
    return run(args.catalog, args.format, args.heading_level)


if __name__ == "__main__":
    sys.exit(main())
