# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Adopt-template ingest and normalization (GP-05 / GP-08).

Reads a user-supplied (BYO) ADR template, attempts to map its sections and
frontmatter onto the canonical MADR v4 structure, and emits a normalized
template file.

GP-05 hard-fail: if the input lacks any canonical *must-map* anchor
(``title``, ``context-and-problem-statement``, ``decision-drivers``,
``considered-options``, ``decision-outcome``, ``consequences``,
``more-information``, or an equivalent), exit non-zero with a structured
stderr report listing each missing anchor.

Usage::

    python -m scripts.normalize_template \\
        --input path/to/byo-template.md \\
        --output path/to/normalized-template.md \\
        [--allow-root path/to/project]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
EXIT_GP05 = 3

SKILL_ROOT = Path(__file__).resolve().parent.parent

# Canonical MADR v4 must-map anchors keyed by canonical kebab-case anchor id.
# Each entry maps an anchor id -> regex patterns (case-insensitive, multiline)
# that detect equivalent BYO sections.
MUST_MAP_ANCHORS: list[tuple[str, list[str]]] = [
    ("title", [r"^#\s+.+$"]),
    (
        "context-and-problem-statement",
        [
            r"^##\s*context\s+and\s+problem\s+statement\b",
            r"^##\s*context\b",
            r"^##\s*problem\s+statement\b",
        ],
    ),
    (
        "decision-drivers",
        [
            r"^##\s*decision\s+drivers\b",
            r"^##\s*drivers\b",
            r"^##\s*forces\b",
        ],
    ),
    (
        "considered-options",
        [
            r"^##\s*considered\s+options\b",
            r"^##\s*options\b",
            r"^##\s*alternatives\b",
        ],
    ),
    (
        "decision-outcome",
        [
            r"^##\s*decision\s+outcome\b",
            r"^##\s*decision\b",
            r"^##\s*chosen\s+option\b",
        ],
    ),
    (
        "consequences",
        [
            r"^##\s*consequences\b",
            r"^###\s*consequences\b",
        ],
    ),
    (
        "more-information",
        [
            r"^##\s*more\s+information\b",
            r"^##\s*references\b",
            r"^##\s*links\b",
        ],
    ),
]

CANONICAL_TEMPLATE = """\
---
id: "{{id}}"
title: "{{title}}"
status: "proposed"
date: "{{date}}"
deciders: []
consulted: []
informed: []
supersedes: []
superseded-by: null
related: []
asr_triggers: []
---

# {{title}}

## Context and Problem Statement

{{context}}

## Decision Drivers

{{decision_drivers}}

## Considered Options

{{considered_options}}

## Decision Outcome

{{decision_outcome}}

### Consequences

{{consequences}}

## More Information

{{more_information}}
"""


def _has_traversal_segments(path: Path) -> bool:
    """Return True if ``path`` contains ``..`` segments separated by ``/`` or ``\\``.

    Cross-platform: on Linux ``Path("..\\..\\evil")`` parses as a single
    filename, so checking only ``path.parts`` misses backslash-separated
    traversals. This helper normalizes both separators before splitting.
    """
    normalized = str(path).replace("\\", "/")
    return ".." in path.parts or ".." in normalized.split("/")


def _safe_resolve(path: Path, allow_roots: list[Path]) -> Path:
    """Resolve ``path`` and ensure it lives under one of ``allow_roots``.

    Path-traversal guard: reject raw paths that contain ``..`` segments.
    Otherwise resolve and require the result to live under one of the
    permitted roots.
    """
    if _has_traversal_segments(path):
        raise ValueError(f"path '{path}' contains traversal segments")
    resolved = path.expanduser().resolve()
    for root in allow_roots:
        try:
            if resolved.is_relative_to(root):
                return resolved
        except ValueError:
            continue
    raise ValueError(f"path '{path}' resolves outside permitted roots: " + ", ".join(str(r) for r in allow_roots))


def find_missing_anchors(text: str) -> list[str]:
    """Return canonical anchor keys not detected in ``text``."""
    missing: list[str] = []
    for key, patterns in MUST_MAP_ANCHORS:
        compiled = [re.compile(p, re.IGNORECASE | re.MULTILINE) for p in patterns]
        if not any(rx.search(text) for rx in compiled):
            missing.append(key)
    return missing


def normalize(_input_text: str) -> str:
    """Produce the canonical MADR v4 template body.

    The current implementation emits the canonical template verbatim; future
    iterations may carry over BYO-specific frontmatter keys or section bodies
    once mapping rules are finalized in ``references/``.
    """
    return CANONICAL_TEMPLATE


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog="normalize_template",
        description="Normalize a BYO ADR template onto the canonical MADR v4 shape.",
    )
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--allow-root",
        type=Path,
        action="append",
        default=[],
        help="Additional directory under which paths are allowed to live.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    args = create_parser().parse_args(argv)

    # Auto-allow the input's grandparent so the script works in real skill
    # layouts (SKILL_ROOT/templates/...) and in test sandboxes
    # (tmp_path/templates/...). Raw ``..`` segments are rejected separately.
    auto_allow: list[Path] = [SKILL_ROOT]
    try:
        input_resolved = args.input.expanduser().resolve()
        auto_allow.append(input_resolved.parent)
        auto_allow.append(input_resolved.parent.parent)
    except OSError:
        # Path resolution failed (missing file, permission denied, symlink loop).
        # Fall back to SKILL_ROOT plus explicitly provided --allow-root entries;
        # _safe_resolve below will reject anything outside that allow-list.
        pass
    allow_roots = [
        *auto_allow,
        *(p.expanduser().resolve() for p in args.allow_root),
    ]

    try:
        # Validate raw arg paths first: on Linux, backslash-separated traversals
        # parse as a single filename whose ``.parent`` is ``.``, so checking
        # only the decomposed parent/name lets them slip through.
        for raw in (args.input, args.output):
            if _has_traversal_segments(raw):
                raise ValueError(f"path '{raw}' contains traversal segments")
        in_path = _safe_resolve(args.input, allow_roots)
        out_parent = _safe_resolve(args.output.parent, allow_roots)
        out_path = (out_parent / args.output.name).resolve()
        if not out_path.is_relative_to(out_parent):
            raise ValueError(f"output path '{args.output}' escapes its parent")
    except ValueError as exc:
        print(f"normalize_template: {exc}", file=sys.stderr)
        return EXIT_ERROR

    try:
        text = in_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"normalize_template: failed to read input: {exc}", file=sys.stderr)
        return EXIT_FAILURE

    missing = find_missing_anchors(text)
    if missing:
        report = {
            "error": "GP-05: input template is missing canonical must-map anchors",
            "input": str(in_path),
            "missing_anchors": missing,
        }
        print(json.dumps(report, indent=2), file=sys.stderr)
        return EXIT_GP05

    try:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(normalize(text), encoding="utf-8")
    except OSError as exc:
        print(f"normalize_template: failed to write output: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
