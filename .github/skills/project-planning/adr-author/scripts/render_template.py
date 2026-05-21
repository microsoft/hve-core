# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Render an ADR from a MADR template plus repeated ``--field key=value`` pairs.

Performs simple ``{placeholder}`` substitution. All input and output paths
must resolve under the skill root, the input/output parent directories, or
one of the directories supplied via ``--allow-root`` (path-traversal guard).

Usage::

    python -m scripts.render_template \\
        --template path/to/template.md \\
        --output path/to/0001-decision.md \\
        --field title=Adopt MADR \\
        --field status=proposed \\
        [--allow-root path/to/project]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SKILL_ROOT = Path(__file__).resolve().parent.parent
PLACEHOLDER_RE = re.compile(r"\{([A-Za-z0-9_.-]+)\}")


def _safe_resolve(path: Path, allow_roots: list[Path]) -> Path:
    """Resolve ``path`` and ensure it lives under one of ``allow_roots``.

    Path-traversal guard: reject raw paths that contain ``..`` segments.
    Otherwise resolve and require the result to live under one of the
    permitted roots.
    """
    normalized = str(path).replace("\\", "/")
    if ".." in path.parts or ".." in normalized.split("/"):
        raise ValueError(f"path '{path}' contains traversal segments")
    resolved = path.expanduser().resolve()
    for root in allow_roots:
        try:
            if resolved.is_relative_to(root):
                return resolved
        except ValueError:
            continue
    raise ValueError(f"path '{path}' resolves outside permitted roots: " + ", ".join(str(r) for r in allow_roots))


def render(template_text: str, fields: dict[str, str]) -> str:
    """Substitute ``{key}`` tokens in ``template_text`` from ``fields``.

    Unknown placeholders are left as-is so downstream validators can flag them.
    """

    def _sub(match: re.Match[str]) -> str:
        key = match.group(1)
        if key in fields:
            return str(fields[key])
        return match.group(0)

    return PLACEHOLDER_RE.sub(_sub, template_text)


def _parse_field(raw: str) -> tuple[str, str]:
    """Parse a ``key=value`` argument; ``=`` splits on the first occurrence."""
    if "=" not in raw:
        raise argparse.ArgumentTypeError(f"--field expects 'key=value', got '{raw}'")
    key, value = raw.split("=", 1)
    key = key.strip()
    if not key:
        raise argparse.ArgumentTypeError("--field key must be non-empty")
    return key, value


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog="render_template",
        description="Render an ADR from a MADR template and key=value fields.",
    )
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--field",
        action="append",
        default=[],
        type=_parse_field,
        help="Field substitution as 'key=value'; repeatable.",
    )
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

    # Infer an "effective skill root" from the template's grandparent so the
    # script works both in the real skill layout (SKILL_ROOT/templates/...) and
    # in test sandboxes (tmp_path/templates/...). Adversarial output paths that
    # resolve outside this inferred root are still rejected.
    auto_allow: list[Path] = [SKILL_ROOT]
    try:
        template_resolved = args.template.expanduser().resolve()
        auto_allow.append(template_resolved.parent)
        auto_allow.append(template_resolved.parent.parent)
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
        for raw in (args.template, args.output):
            normalized = str(raw).replace("\\", "/")
            if ".." in raw.parts or ".." in normalized.split("/"):
                raise ValueError(f"path '{raw}' contains traversal segments")
        template_path = _safe_resolve(args.template, allow_roots)
        out_parent = _safe_resolve(args.output.parent, allow_roots)
        out_path = (out_parent / args.output.name).resolve()
        if not out_path.is_relative_to(out_parent):
            raise ValueError(f"output path '{args.output}' escapes its parent")
    except ValueError as exc:
        print(f"render_template: path error: {exc}", file=sys.stderr)
        return EXIT_ERROR

    try:
        template_text = template_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"render_template: failed to read template: {exc}", file=sys.stderr)
        return EXIT_FAILURE

    fields: dict[str, str] = dict(args.field)
    rendered = render(template_text, fields)
    try:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(rendered, encoding="utf-8")
    except OSError as exc:
        print(f"render_template: failed to write output: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
