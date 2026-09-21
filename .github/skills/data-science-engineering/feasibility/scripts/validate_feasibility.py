#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate Feasibility Study Interchange Profile Markdown artifacts."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
BEGIN_MARKER = "<!-- BEGIN FEASIBILITY-STUDY-INTERCHANGE -->"
END_MARKER = "<!-- END FEASIBILITY-STUDY-INTERCHANGE -->"
BLOCK_PATTERN = re.compile(
    re.escape(BEGIN_MARKER) + r"\s*```yaml\s*(.*?)\s*```\s*" + re.escape(END_MARKER),
    re.DOTALL,
)
# Deterministic scan bounds used instead of backtracking across the whole study.
BLOCK_OPEN_PATTERN = re.compile(re.escape(BEGIN_MARKER) + r"[^\S\n]*\n?[^\S\n]*```yaml")
BLOCK_CLOSE_PATTERN = re.compile(r"```[^\S\n]*\n?[^\S\n]*" + re.escape(END_MARKER))
# A fence opens on three or more backticks or tildes indented no more than three
# spaces. A backtick info string may not contain a backtick.
FENCE_PATTERN = re.compile(r"^ {0,3}(?P<fence>`{3,}|~{3,})(?P<info>.*)$")

# A study allocates a requirement only when an item identity or a narrative
# heading is itself an FR or NFR reference. Prose citations remain valid.
ALLOCATED_REQUIREMENT_PATTERN = re.compile(r"^(?:FR|NFR)-[0-9]{3,}$")
REQUIREMENT_HEADING_PATTERN = re.compile(
    r"^#{1,6}\s+((?:FR|NFR)-[0-9]{3,})(?::|\s|$)", re.MULTILINE
)
NARRATIVE_ANCHOR_PATTERN = re.compile(r"^###\s+(FS-[0-9]{3,})(?::|\s|$)", re.MULTILINE)

# Operational bound checked before any study content is read.
MAX_INPUT_BYTES = 5 * 1024 * 1024
MERGE_TAG = "tag:yaml.org,2002:merge"
RFC3339_DATE_TIME_PATTERN = re.compile(
    r"^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:\d{2})$"
)


class FeasibilityValidationError(ValueError):
    """Raised when the profile block cannot be parsed safely."""


class UniqueKeyLoader(yaml.SafeLoader):
    """Loader rejecting aliases, anchors, tags, merge keys, and duplicate keys."""

    def compose_node(
        self, parent: yaml.nodes.Node | None, index: Any
    ) -> yaml.nodes.Node:
        """Reject alias, anchor, and explicit-tag events before composition."""
        event = self.peek_event()
        if isinstance(event, yaml.AliasEvent):
            raise FeasibilityValidationError("YAML aliases are not permitted")
        if getattr(event, "anchor", None) is not None:
            raise FeasibilityValidationError("YAML anchors are not permitted")
        if getattr(event, "tag", None) is not None:
            raise FeasibilityValidationError("YAML explicit tags are not permitted")
        return super().compose_node(parent, index)


def _construct_unique_mapping(
    loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False
) -> dict[str, Any]:
    """Construct a mapping while rejecting merge keys and duplicate keys."""
    mapping: dict[str, Any] = {}
    for key_node, value_node in node.value:
        if key_node.tag == MERGE_TAG:
            raise FeasibilityValidationError("YAML merge keys are not permitted")
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str):
            raise FeasibilityValidationError("YAML keys must be strings")
        if key in mapping:
            raise FeasibilityValidationError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


def _reject_tagged_node(
    loader: UniqueKeyLoader, tag_suffix: str, node: yaml.nodes.Node
) -> Any:
    """Reject any node carrying a tag without a registered safe constructor."""
    raise FeasibilityValidationError("YAML explicit tags are not permitted")


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
)
UniqueKeyLoader.add_multi_constructor("", _reject_tagged_node)


def _sanitize_yaml_error(error: yaml.YAMLError) -> str:
    """Describe a YAML failure by position only, never by source content."""
    mark = getattr(error, "problem_mark", None) or getattr(error, "context_mark", None)
    if mark is None:
        return f"invalid YAML ({type(error).__name__})"
    return (
        f"invalid YAML ({type(error).__name__}) at line {mark.line + 1} "
        f"column {mark.column + 1}"
    )


def _skill_root() -> Path:
    """Return the skill root that owns the bundled schema."""
    return Path(__file__).resolve().parent.parent


def _resolve_input_path(path: Path, allowed_roots: Sequence[Path]) -> Path:
    """Return a resolved input path contained by one permitted root."""
    segments = str(path).replace("\\", "/").split("/")
    if any(segment == ".." for segment in segments):
        raise FeasibilityValidationError("input path cannot contain '..' segments")
    resolved = path.resolve()
    for root in allowed_roots:
        if resolved.is_relative_to(root.resolve()):
            return resolved
    raise FeasibilityValidationError("input path resolves outside the permitted roots")


def read_study_text(path: Path, allowed_roots: Sequence[Path] | None = None) -> str:
    """Read a size-bounded study file from a permitted root."""
    roots = tuple(allowed_roots) if allowed_roots else (Path.cwd(), _skill_root())
    resolved = _resolve_input_path(path, roots)
    if resolved.stat().st_size > MAX_INPUT_BYTES:
        raise FeasibilityValidationError(
            f"study exceeds the {MAX_INPUT_BYTES} byte input limit"
        )
    return resolved.read_text(encoding="utf-8")


def _is_rfc3339_date_time(value: Any) -> bool:
    """Return True when a string value is a strict RFC 3339 timestamp."""
    if not isinstance(value, str):
        return True
    if RFC3339_DATE_TIME_PATTERN.match(value) is None:
        return False
    normalized = f"{value[:-1]}+00:00" if value[-1] in "Zz" else value
    try:
        dt.datetime.fromisoformat(normalized)
    except ValueError:
        return False
    return True


def build_format_checker() -> FormatChecker:
    """Return a format checker restricted to RFC 3339 date-time."""
    if "date-time" in FormatChecker.checkers:
        return FormatChecker(formats=["date-time"])
    checker = FormatChecker(formats=[])
    checker.checks("date-time")(_is_rfc3339_date_time)
    return checker


def extract_profile_yaml(markdown: str) -> str:
    """Extract the one authoritative profile block.

    Scans forward deterministically instead of applying a lazy pattern across
    the whole study, so a study carrying many unterminated begin markers cannot
    force quadratic backtracking before the block count is known.
    """
    blocks: list[str] = []
    search_from = 0
    while True:
        opening = BLOCK_OPEN_PATTERN.search(markdown, search_from)
        if opening is None:
            break
        closing = BLOCK_CLOSE_PATTERN.search(markdown, opening.end())
        if closing is None:
            break
        blocks.append(markdown[opening.end() : closing.start()].strip("\r\n"))
        search_from = closing.end()
        if len(blocks) > 1:
            break
    if len(blocks) != 1:
        raise FeasibilityValidationError(
            "study must contain exactly one named FEASIBILITY-STUDY-INTERCHANGE block"
        )
    return blocks[0]


def _blank_lines(text: str) -> str:
    """Return a line- and column-preserving blank replacement."""
    return re.sub(r"[^\r\n]", " ", text)


def _strip_fenced_blocks(markdown: str) -> str:
    """Blank every CommonMark fenced code block.

    A fence closes on the same character, at the same length or longer, with no
    info string. Content is blanked rather than deleted so removed regions
    cannot splice neighbouring text into a match.
    """
    stripped: list[str] = []
    open_fence: str | None = None
    for line in markdown.split("\n"):
        match = FENCE_PATTERN.match(line)
        marker = match.group("fence") if match else ""
        info = match.group("info") if match else ""
        if open_fence is None:
            if marker and not (marker[0] == "`" and "`" in info):
                open_fence = marker
                stripped.append("")
                continue
            stripped.append(line)
            continue
        if (
            marker
            and marker[0] == open_fence[0]
            and len(marker) >= len(open_fence)
            and not info.strip()
        ):
            open_fence = None
        stripped.append("")
    return "\n".join(stripped)


def narrative_text(markdown: str) -> str:
    """Return prose with the authoritative block and fenced code blanked."""
    without_block = BLOCK_PATTERN.sub(
        lambda match: _blank_lines(match.group(0)), markdown
    )
    return _strip_fenced_blocks(without_block)


def _assert_json_compatible(value: Any, path: str = "$") -> None:
    """Reject YAML-native values outside the JSON data model."""
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            raise FeasibilityValidationError(f"{path} must be a finite number")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _assert_json_compatible(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise FeasibilityValidationError(f"{path} has a non-string key")
            _assert_json_compatible(item, f"{path}.{key}")
        return
    if isinstance(value, dt.date):
        raise FeasibilityValidationError(f"{path} timestamp must be a quoted string")
    raise FeasibilityValidationError(
        f"{path} contains non-JSON YAML value {type(value).__name__}"
    )


def parse_profile(markdown: str) -> dict[str, Any]:
    """Parse the constrained YAML profile block."""
    try:
        parsed = yaml.load(extract_profile_yaml(markdown), Loader=UniqueKeyLoader)
    except FeasibilityValidationError:
        raise
    except yaml.YAMLError as error:
        raise FeasibilityValidationError(_sanitize_yaml_error(error)) from error
    except RecursionError as error:
        raise FeasibilityValidationError(
            "profile block is nested too deeply"
        ) from error
    except ValueError as error:
        raise FeasibilityValidationError(
            "profile block has an invalid scalar value"
        ) from error
    if not isinstance(parsed, dict):
        raise FeasibilityValidationError("profile block must parse to an object")
    try:
        _assert_json_compatible(parsed)
    except RecursionError as error:
        raise FeasibilityValidationError(
            "profile block is nested too deeply"
        ) from error
    return parsed


def load_schema(skill_root: Path) -> dict[str, Any]:
    """Load the local profile schema."""
    schema_path = (
        skill_root / "assets" / "feasibility-study-interchange-1.0.0.schema.json"
    )
    return json.loads(schema_path.read_text(encoding="utf-8"))


def _duplicates(values: list[str]) -> set[str]:
    """Return duplicated strings."""
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return duplicates


def _find_cycles(parents: dict[str, str | None]) -> list[str]:
    """Return revision IDs participating in parent cycles."""
    cycles: set[str] = set()
    for start in parents:
        path: list[str] = []
        current: str | None = start
        while current is not None and current in parents:
            if current in path:
                cycles.update(path[path.index(current) :])
                break
            path.append(current)
            current = parents[current]
    return sorted(cycles)


def requirement_allocation_errors(
    items: list[dict[str, Any]], markdown: str
) -> list[str]:
    """Return errors for items or headings that allocate a requirement identity.

    Allocation is keyed on the item's own declared reference. A requirement
    identifier merely cited in prose is an upstream citation, not an allocation.
    """
    errors = []
    for item in items:
        display_ref = item["display_ref"]
        if ALLOCATED_REQUIREMENT_PATTERN.match(display_ref):
            errors.append(
                f"{display_ref} cannot allocate an FR or NFR identifier as its "
                "own display_ref"
            )
    for heading_ref in REQUIREMENT_HEADING_PATTERN.findall(narrative_text(markdown)):
        errors.append(
            f"narrative heading cannot allocate FR or NFR identifier {heading_ref}"
        )
    return errors


def validate_profile(
    data: dict[str, Any], markdown: str, schema: dict[str, Any]
) -> list[str]:
    """Return structural, semantic, and Markdown-linkage errors."""
    validator = Draft202012Validator(schema, format_checker=build_format_checker())
    errors = [error.message for error in sorted(validator.iter_errors(data), key=str)]
    if errors:
        return errors

    study = data["study"]
    items = data["items"]
    registry = data["revision_registry"]
    item_by_id = {item["item_id"]: item for item in items}

    concept_ids = [study["study_id"], *(item["item_id"] for item in items)]
    relation_ids = [
        relation["relation_id"] for item in items for relation in item["relations"]
    ]
    current_revision_ids = [
        study["study_revision_id"],
        *(item["item_revision_id"] for item in items),
    ]
    registry_revision_ids = [entry["revision_id"] for entry in registry]

    for label, values in (
        ("conceptual IDs", concept_ids),
        ("relation IDs", relation_ids),
        ("revision registry IDs", registry_revision_ids),
    ):
        duplicates = _duplicates(values)
        if duplicates:
            errors.append(f"{label} must be unique: {', '.join(sorted(duplicates))}")

    collisions = (set(concept_ids) | set(relation_ids)) & set(registry_revision_ids)
    if collisions:
        errors.append(
            "concept, relation, and revision identities must be disjoint: "
            + ", ".join(sorted(collisions))
        )

    registry_by_revision = {entry["revision_id"]: entry for entry in registry}
    for revision_id in current_revision_ids:
        if revision_id not in registry_by_revision:
            errors.append(f"current revision is absent from registry: {revision_id}")

    current_pairs = [
        (study["study_id"], study["study_revision_id"], study["revision_of"]),
        *(
            (item["item_id"], item["item_revision_id"], item["revision_of"])
            for item in items
        ),
    ]
    for concept_id, revision_id, revision_of in current_pairs:
        entry = registry_by_revision.get(revision_id)
        if entry and (
            entry["concept_id"] != concept_id or entry["revision_of"] != revision_of
        ):
            errors.append(
                f"current revision metadata disagrees with registry: {revision_id}"
            )

    revisions_by_concept: dict[str, set[str]] = {}
    for entry in registry:
        revisions_by_concept.setdefault(entry["concept_id"], set()).add(
            entry["revision_id"]
        )
    for entry in registry:
        parent = entry["revision_of"]
        known_revisions = revisions_by_concept[entry["concept_id"]]
        if parent is not None and parent not in known_revisions:
            errors.append(
                f"revision {entry['revision_id']} points outside its concept lineage"
            )
    cycles = _find_cycles(
        {entry["revision_id"]: entry["revision_of"] for entry in registry}
    )
    if cycles:
        errors.append("revision lineage is cyclic: " + ", ".join(cycles))

    known_items = set(item_by_id)
    for item in items:
        if item["display_ref"].lower() != item["narrative_anchor"]:
            errors.append(
                f"{item['display_ref']} narrative_anchor must match its alias"
            )
        review = item["review"]
        if review["needs_review"] != bool(review["reasons"]):
            errors.append(
                f"{item['display_ref']} review reasons must match needs_review"
            )
        criteria = item["acceptance_criteria"]
        if item["criteria_status"] == "defined" and not criteria:
            errors.append(f"{item['display_ref']} defined criteria cannot be empty")
        empty_statuses = {"not-yet-defined", "not-applicable"}
        if item["criteria_status"] in empty_statuses and criteria:
            errors.append(
                f"{item['display_ref']} criteria must be empty for "
                f"{item['criteria_status']}"
            )

        for evidence_id in item["evidence_refs"]:
            evidence = item_by_id.get(evidence_id)
            if evidence is None:
                errors.append(f"{item['display_ref']} has unknown evidence reference")
            elif evidence["class"] != "evidence":
                errors.append(
                    f"{item['display_ref']} evidence reference does not target evidence"
                )

        relation_types = {relation["type"] for relation in item["relations"]}
        for relation in item["relations"]:
            if relation["target"] not in known_items:
                errors.append(f"relation {relation['relation_id']} has unknown target")
            relation_review = relation["review"]
            if relation_review["needs_review"] != bool(relation_review["reasons"]):
                errors.append(
                    f"relation {relation['relation_id']} review reasons "
                    "are inconsistent"
                )

        lifecycle = item["lifecycle"]
        for target in lifecycle["predecessor_ids"] + lifecycle["successor_ids"]:
            if target not in known_items:
                errors.append(
                    f"{item['display_ref']} lifecycle target is unknown: {target}"
                )
        if item["status"] in {"withdrawn", "superseded"}:
            if lifecycle["effective_at"] is None or not lifecycle["reason"]:
                errors.append(
                    f"{item['display_ref']} has an incomplete "
                    f"{item['status']} tombstone"
                )
        if item["status"] == "superseded" and not lifecycle["successor_ids"]:
            errors.append(
                f"{item['display_ref']} superseded tombstone needs a successor"
            )
        if "split-from" in relation_types and not lifecycle["predecessor_ids"]:
            errors.append(f"{item['display_ref']} split lineage needs a predecessor")
        if "merged-from" in relation_types and len(lifecycle["predecessor_ids"]) < 2:
            errors.append(f"{item['display_ref']} merge lineage needs two predecessors")

    expected_anchors = {item["display_ref"] for item in items}
    actual_anchors = NARRATIVE_ANCHOR_PATTERN.findall(narrative_text(markdown))
    duplicate_anchors = _duplicates(actual_anchors)
    if duplicate_anchors:
        errors.append(
            "duplicate narrative anchors: " + ", ".join(sorted(duplicate_anchors))
        )
    missing_anchors = expected_anchors - set(actual_anchors)
    unknown_anchors = set(actual_anchors) - expected_anchors
    if missing_anchors:
        errors.append("orphaned YAML items: " + ", ".join(sorted(missing_anchors)))
    if unknown_anchors:
        errors.append(
            "unknown narrative anchors: " + ", ".join(sorted(unknown_anchors))
        )
    errors.extend(requirement_allocation_errors(items, markdown))
    return errors


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Validate a Feasibility Study Interchange Profile"
    )
    parser.add_argument("study", type=Path, help="Markdown study to validate")
    return parser


def run(study_path: Path, allowed_roots: Sequence[Path] | None = None) -> int:
    """Validate one study and print a JSON result.

    Operational failures report on stderr with EXIT_ERROR. Validation failures
    report on stdout with EXIT_FAILURE.
    """
    try:
        markdown = read_study_text(study_path, allowed_roots)
        data = parse_profile(markdown)
        schema = load_schema(_skill_root())
    except (OSError, FeasibilityValidationError, json.JSONDecodeError) as error:
        print(f"validate_feasibility: {error}", file=sys.stderr)
        return EXIT_ERROR

    errors = validate_profile(data, markdown, schema)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return EXIT_FAILURE if errors else EXIT_SUCCESS


def main() -> int:
    """Run the feasibility profile validator CLI."""
    return run(create_parser().parse_args().study)


if __name__ == "__main__":
    sys.exit(main())
