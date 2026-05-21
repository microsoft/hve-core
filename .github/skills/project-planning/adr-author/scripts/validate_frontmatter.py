# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Validate YAML frontmatter of one or more ADR markdown files.

Validates structural fields: ``id`` (4-digit zero-padded), ``title``,
``status`` (enum), ``proposed_date`` (ISO 8601 YYYY-MM-DD), ``deciders`` (list),
optional ``consulted``/``informed`` (lists of strings), ``related`` (list
of ``{path, relation, note?}`` objects), scalar single-parent ``supersedes``
and ``superseded-by`` (NNNN string or null per GP-06), and ``asr_triggers``
(list of ``{kind, evidence, note}`` objects with ``kind`` in the 8-enum:
cost, performance, security, compliance, availability, scalability,
maintainability, evolvability per GP-07; ``note`` <= 280 chars).

Optionally consumes ``scripts/linting/schemas/adr-frontmatter.schema.json``
when present (lazy load); absence emits a warning but does not fail.

Usage::

    python -m scripts.validate_frontmatter <adr-path> [<adr-path> ...]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SKILL_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = SKILL_ROOT.parents[3] if len(SKILL_ROOT.parents) >= 4 else SKILL_ROOT
SCHEMA_PATH = REPO_ROOT / "scripts" / "linting" / "schemas" / "adr-frontmatter.schema.json"

STATUS_ENUM = {
    "proposed",
    "accepted",
    "rejected",
    "deprecated",
    "superseded",
    "withdrawn",
}
ASR_KIND_ENUM = {
    "cost",
    "performance",
    "security",
    "compliance",
    "availability",
    "scalability",
    "maintainability",
    "evolvability",
}
RELATION_ENUM = {"informational", "influenced-by", "influences"}
EFFORT_ENUM = {"S", "M", "L", "XL"}
SUCCESS_CRITERION_FIELDS = ("metric", "target", "measurement_window", "source")
ID_RE = re.compile(r"^\d{4}$")
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
NOTE_MAX = 280

REQUIRED_BODY_HEADERS = (
    "## Risks and Mitigations",
    "## Rollback / Exit Strategy",
    "## Affected Components",
)
CONTEXT_HEADER_RE = re.compile(r"^##\s+Context\s*$", re.MULTILINE)
DECISION_HEADER_RE = re.compile(r"^##\s+(Decision Outcome|Decision)\s*$", re.MULTILINE)
NEXT_H2_RE = re.compile(r"^##\s+\S", re.MULTILINE)
MIN_CONTEXT_CITATIONS = 3


def _safe_resolve(path: Path, allow_roots: list[Path]) -> Path:
    """Resolve ``path`` ensuring it lives under one of ``allow_roots``."""
    if ".." in path.parts:
        raise ValueError(f"path '{path}' contains traversal segments and is rejected")
    resolved = path.expanduser().resolve()
    for root in allow_roots:
        try:
            if resolved.is_relative_to(root):
                return resolved
        except ValueError:
            continue
    raise ValueError(f"path '{path}' resolves outside permitted roots: " + ", ".join(str(r) for r in allow_roots))


def _load_schema(schema_path: Path | None = None) -> dict[str, Any] | None:
    """Lazily load the optional JSON schema; return ``None`` if missing."""
    target = schema_path if schema_path is not None else SCHEMA_PATH
    if not target.is_file():
        return None
    try:
        return json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(
            f"validate_frontmatter: warning: schema unreadable ({exc})",
            file=sys.stderr,
        )
        return None


def _extract_frontmatter(text: str) -> dict[str, Any] | None:
    """Return parsed YAML frontmatter mapping, or ``None`` if absent/invalid."""
    match = FRONTMATTER_RE.match(text)
    if not match:
        return None
    try:
        loaded = yaml.safe_load(match.group(1))
    except yaml.YAMLError:
        return None
    return loaded if isinstance(loaded, dict) else None


def _validate_list_of_str(value: Any, field: str, errors: list[str]) -> None:
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        errors.append(f"{field}: must be a list of strings")


def _validate_id_scalar(value: Any, field: str, errors: list[str]) -> None:
    """Validate scalar single-parent supersession field per GP-06.

    Accepts ``None`` or a 4-digit NNNN string. Rejects lists outright so that
    multi-parent supersession is caught at validation time.
    """
    if value is None:
        return
    if isinstance(value, list):
        errors.append(f"{field}: must be a single NNNN string (GP-06 single-parent), not a list")
        return
    if not (isinstance(value, str) and ID_RE.match(value)):
        errors.append(f"{field}: must be a 4-digit ID string or null")


def _validate_related(value: Any, errors: list[str]) -> None:
    """Validate ``related`` as a list of ``{path, relation, note?}`` objects."""
    if value in (None, []):
        return
    if not isinstance(value, list):
        errors.append("related: must be a list of objects")
        return
    for idx, item in enumerate(value):
        prefix = f"related[{idx}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: must be an object")
            continue
        path = item.get("path")
        relation = item.get("relation")
        note = item.get("note")
        if not (isinstance(path, str) and path.strip()):
            errors.append(f"{prefix}.path: must be a non-empty string")
        if relation not in RELATION_ENUM:
            errors.append(f"{prefix}.relation: '{relation}' not in {sorted(RELATION_ENUM)}")
        if note is not None:
            if not isinstance(note, str):
                errors.append(f"{prefix}.note: must be a string")
            elif len(note) > NOTE_MAX:
                errors.append(f"{prefix}.note: exceeds {NOTE_MAX} chars (got {len(note)})")


def _validate_asr_triggers(value: Any, errors: list[str]) -> None:
    if value in (None, []):
        return
    if not isinstance(value, list):
        errors.append("asr_triggers: must be a list of objects")
        return
    for idx, item in enumerate(value):
        prefix = f"asr_triggers[{idx}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: must be an object")
            continue
        kind = item.get("kind")
        evidence = item.get("evidence")
        note = item.get("note")
        if kind not in ASR_KIND_ENUM:
            errors.append(f"{prefix}.kind: '{kind}' not in {sorted(ASR_KIND_ENUM)}")
        if not isinstance(evidence, str) or not evidence.strip():
            errors.append(f"{prefix}.evidence: must be a non-empty string")
        if not isinstance(note, str):
            errors.append(f"{prefix}.note: must be a non-empty string")
        elif not note.strip():
            errors.append(f"{prefix}.note: must be a non-empty string")
        elif len(note) > NOTE_MAX:
            errors.append(f"{prefix}.note: exceeds {NOTE_MAX} chars (got {len(note)})")


def _validate_iso_date(value: Any, field: str, errors: list[str]) -> None:
    """Validate an ISO 8601 (YYYY-MM-DD) date scalar."""
    if isinstance(value, date):
        return
    if isinstance(value, str):
        try:
            date.fromisoformat(value)
        except ValueError:
            errors.append(f"{field}: must be ISO 8601 (YYYY-MM-DD)")
        return
    errors.append(f"{field}: must be ISO 8601 (YYYY-MM-DD)")


def _validate_affected_components(value: Any, errors: list[str]) -> None:
    if not isinstance(value, list) or not value:
        errors.append("affected_components: must be a non-empty list of strings")
        return
    for idx, item in enumerate(value):
        if not (isinstance(item, str) and item.strip()):
            errors.append(f"affected_components[{idx}]: must be a non-empty string")


def _validate_effort(value: Any, errors: list[str]) -> None:
    if value is None:
        return
    if value not in EFFORT_ENUM:
        errors.append(f"effort: '{value}' not in {sorted(EFFORT_ENUM)}")


def _validate_success_criteria(value: Any, asr_triggers: Any, errors: list[str]) -> None:
    """Validate ``success_criteria``; require non-empty list when ASRs present."""
    has_asrs = isinstance(asr_triggers, list) and len(asr_triggers) > 0
    if value in (None, []):
        if has_asrs:
            errors.append("success_criteria: required and non-empty when asr_triggers is non-empty")
        return
    if not isinstance(value, list):
        errors.append("success_criteria: must be a list of objects")
        return
    for idx, item in enumerate(value):
        prefix = f"success_criteria[{idx}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: must be an object")
            continue
        for sub in SUCCESS_CRITERION_FIELDS:
            sub_val = item.get(sub)
            if not (isinstance(sub_val, str) and sub_val.strip()):
                errors.append(f"{prefix}.{sub}: must be a non-empty string")


def validate_frontmatter(fm: dict[str, Any]) -> list[str]:
    """Run structural checks; return a list of human-readable error strings."""
    errors: list[str] = []

    adr_id = fm.get("id")
    if not (isinstance(adr_id, str) and ID_RE.match(adr_id)):
        errors.append("id: must be a 4-digit zero-padded string (e.g., '0007')")

    title = fm.get("title")
    if not (isinstance(title, str) and title.strip()):
        errors.append("title: must be a non-empty string")

    status = fm.get("status")
    if status not in STATUS_ENUM:
        errors.append(f"status: '{status}' not in {sorted(STATUS_ENUM)}")

    if "proposed_date" not in fm:
        errors.append("proposed_date: required")
    else:
        _validate_iso_date(fm["proposed_date"], "proposed_date", errors)

    accepted_date = fm.get("accepted_date")
    if status == "accepted":
        if accepted_date is None:
            errors.append("accepted_date: required when status is 'accepted'")
        else:
            _validate_iso_date(accepted_date, "accepted_date", errors)
    elif accepted_date is not None:
        _validate_iso_date(accepted_date, "accepted_date", errors)

    if "deciders" not in fm:
        errors.append("deciders: required")
    else:
        _validate_list_of_str(fm["deciders"], "deciders", errors)

    if "affected_components" not in fm:
        errors.append("affected_components: required")
    else:
        _validate_affected_components(fm["affected_components"], errors)

    _validate_effort(fm.get("effort"), errors)

    for opt in ("consulted", "informed"):
        if opt in fm and fm[opt] is not None:
            _validate_list_of_str(fm[opt], opt, errors)

    if "related" in fm:
        _validate_related(fm["related"], errors)

    _validate_id_scalar(fm.get("supersedes"), "supersedes", errors)
    _validate_id_scalar(fm.get("superseded-by"), "superseded-by", errors)

    _validate_asr_triggers(fm.get("asr_triggers"), errors)
    _validate_success_criteria(fm.get("success_criteria"), fm.get("asr_triggers"), errors)

    return errors


def _body_after_frontmatter(text: str) -> str:
    """Return the body text following the YAML frontmatter block."""
    match = FRONTMATTER_RE.match(text)
    return text[match.end() :] if match else text


def _section_text(body: str, header_re: re.Pattern[str]) -> str | None:
    """Return the text of the first section matched by ``header_re``."""
    match = header_re.search(body)
    if not match:
        return None
    start = match.end()
    next_header = NEXT_H2_RE.search(body, pos=start)
    end = next_header.start() if next_header else len(body)
    return body[start:end]


def validate_body(text: str) -> list[str]:
    """Validate required body sections and citations; return error strings."""
    errors: list[str] = []
    body = _body_after_frontmatter(text)

    for header in REQUIRED_BODY_HEADERS:
        pattern = re.compile(r"^" + re.escape(header) + r"\s*$", re.MULTILINE)
        if not pattern.search(body):
            errors.append(f"body: required section missing: '{header}'")

    context = _section_text(body, CONTEXT_HEADER_RE)
    if context is None:
        errors.append("body: required section missing: '## Context'")
    else:
        citation_lines = [line for line in context.splitlines() if line.lstrip().startswith("> ")]
        if len(citation_lines) < MIN_CONTEXT_CITATIONS:
            errors.append(
                f"body: '## Context' must include at least "
                f"{MIN_CONTEXT_CITATIONS} blockquote citation lines (found "
                f"{len(citation_lines)})"
            )

    decision = _section_text(body, DECISION_HEADER_RE)
    if decision is not None:
        table_lines = [line for line in decision.splitlines() if line.lstrip().startswith("|")]
        if len(table_lines) < 2:
            errors.append(
                "body: decision section must include a driver-by-option comparison table (markdown pipe table)"
            )

    return errors


def validate_file(path: Path) -> list[str]:
    """Validate a single file; return list of errors (empty == valid)."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"{path}: cannot read ({exc})"]

    fm = _extract_frontmatter(text)
    if fm is None:
        return [f"{path}: missing or invalid YAML frontmatter"]

    errors = validate_frontmatter(fm)
    errors.extend(validate_body(text))
    return [f"{path}: {err}" for err in errors]


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog="validate_frontmatter",
        description="Validate ADR markdown frontmatter.",
    )
    parser.add_argument("paths", type=Path, nargs="+", help="ADR markdown files")
    parser.add_argument(
        "--allow-root",
        type=Path,
        action="append",
        default=[],
        help="Additional directory under which paths are allowed to live.",
    )
    parser.add_argument(
        "--schema",
        type=Path,
        default=None,
        help="Optional override for the JSON schema path.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    args = create_parser().parse_args(argv)
    auto_allow: list[Path] = [SKILL_ROOT, REPO_ROOT]
    for raw in args.paths:
        try:
            r = raw.expanduser().resolve()
            auto_allow.append(r.parent)
            if r.parent != r.parent.parent:
                auto_allow.append(r.parent.parent)
        except OSError:
            continue
    allow_roots = [
        *auto_allow,
        *(p.expanduser().resolve() for p in args.allow_root),
    ]

    schema_path = args.schema if args.schema is not None else SCHEMA_PATH
    schema = _load_schema(schema_path)
    if schema is None:
        print(
            f"validate_frontmatter: schema not found at {schema_path}; using built-in structural checks only",
            file=sys.stderr,
        )

    all_errors: list[str] = []
    for raw in args.paths:
        try:
            resolved = _safe_resolve(raw, allow_roots)
        except ValueError as exc:
            all_errors.append(f"validate_frontmatter: {exc}")
            continue
        all_errors.extend(validate_file(resolved))

    for err in all_errors:
        print(err, file=sys.stderr)
    return EXIT_SUCCESS if not all_errors else EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
