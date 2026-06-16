# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Single-writer for ``last_decision_id`` and atomic ADR supersession updates.

Implements lineage rules 1-5:

1. Each project has a single canonical ``.adr-config.yml`` whose top-level
   ``last_decision_id`` field tracks the most recently issued ADR id.
2. IDs are 4-digit zero-padded and strictly monotonically increasing.
3. Allocation is the only path that mutates ``last_decision_id`` and is
   single-writer (file lock via atomic ``os.replace``).
4. Supersession updates exactly two ADR files atomically: the new ADR gains
   ``supersedes: <old>``; the old ADR receives ``superseded-by: <new>`` and
   ``status: superseded``.
5. Atomic writes use temp files in the same directory followed by
   ``os.replace``; any validation failure rolls back without leaving partial
   writes.

Usage::

    python update_lineage.py allocate --project-dir <path> --slug <slug>
    python update_lineage.py supersede --superseded <old-adr-path> \\
        --superseder <new-adr-path>
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

import yaml

try:
    from ._utils import has_traversal_segments, safe_resolve
except ImportError:  # executed directly as ``python update_lineage.py``
    from _utils import has_traversal_segments, safe_resolve

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SKILL_ROOT = Path(__file__).resolve().parent.parent

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
ID_RE = re.compile(r"^\d{4}$")
ID_PREFIX_RE = re.compile(r"^(\d{4})-")
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
CONFIG_FILENAME = ".adr-config.yml"


def validate_lineage(*_args: Any, **_kwargs: Any) -> None:
    """Post-write validation hook; tests patch this attribute to inject errors."""
    return None


def _safe_slug(slug: str) -> str:
    """Validate ``slug`` against the allow-list regex; raise on mismatch."""
    if not SLUG_RE.match(slug):
        raise ValueError(f"invalid project slug '{slug}': must match {SLUG_RE.pattern}")
    return slug


def _load_yaml_config(path: Path) -> dict[str, Any]:
    """Load a pure-YAML config file into a mapping."""
    raw = path.read_text(encoding="utf-8")
    data = yaml.safe_load(raw) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path.name} must be a YAML mapping")
    return data


def _split_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Split markdown text into (frontmatter dict, remainder)."""
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise ValueError("missing or invalid YAML frontmatter")
    fm = yaml.safe_load(match.group(1)) or {}
    if not isinstance(fm, dict):
        raise ValueError("frontmatter must be a YAML mapping")
    body = text[match.end() :]
    return fm, body


def _join_frontmatter(fm: dict[str, Any], body: str) -> str:
    """Reassemble markdown text from frontmatter dict + body."""
    dumped = yaml.safe_dump(fm, sort_keys=False, allow_unicode=True).rstrip("\n")
    return f"---\n{dumped}\n---\n{body}"


def _atomic_write(path: Path, content: str) -> None:
    """Atomically write ``content`` to ``path`` via same-dir temp + replace."""
    parent = path.parent
    parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=".tmp-", dir=parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.replace(tmp_path, path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
        raise


def _id_from_filename(path: Path) -> str:
    """Extract the leading 4-digit id prefix from an ADR filename stem."""
    match = ID_PREFIX_RE.match(path.stem)
    if not match:
        raise ValueError(f"ADR filename '{path.name}' missing 4-digit id prefix")
    return match.group(1)


def allocate(project_dir: Path, slug: str) -> str:
    """Allocate the next NNNN id for ``slug``; mutate ``.adr-config.yml``."""
    _safe_slug(slug)
    if has_traversal_segments(project_dir):
        raise ValueError(f"project dir '{project_dir}' contains traversal segments")
    project_dir = project_dir.expanduser().resolve()
    cfg_path = project_dir / CONFIG_FILENAME
    if not cfg_path.is_file():
        raise FileNotFoundError(f"{CONFIG_FILENAME} not found in project dir '{project_dir}'")
    cfg = _load_yaml_config(cfg_path)

    last_raw = cfg.get("last_decision_id", "0000")
    if isinstance(last_raw, bool):
        raise ValueError("last_decision_id: must be int or NNNN string")
    if isinstance(last_raw, str):
        if not ID_RE.match(last_raw):
            raise ValueError(f"last_decision_id '{last_raw}' must be 4-digit string or int")
        last = int(last_raw)
    elif isinstance(last_raw, int):
        last = last_raw
    else:
        raise ValueError("last_decision_id: must be int or NNNN string")

    if last >= 9999:
        raise ValueError("last_decision_id exhausted (>= 9999)")

    new_id = f"{last + 1:04d}"
    cfg["last_decision_id"] = new_id
    dumped = yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True)
    _atomic_write(cfg_path, dumped)
    return new_id


def supersede(superseded: Path, superseder: Path, allow_roots: list[Path] | None = None) -> None:
    """Atomically mark ``superseded`` as replaced by ``superseder``.

    Both paths are containment-checked against ``allow_roots``; when omitted,
    each ADR's own parent directory is used so traversal segments are still
    rejected while preserving the default in-project usage.
    """
    roots = allow_roots or [
        superseded.parent.expanduser().resolve(),
        superseder.parent.expanduser().resolve(),
    ]
    superseded = safe_resolve(superseded, roots)
    superseder = safe_resolve(superseder, roots)

    if superseded == superseder:
        raise ValueError("superseded and superseder must be different files")
    if not superseded.is_file():
        raise FileNotFoundError(f"superseded ADR not found: {superseded}")
    if not superseder.is_file():
        raise FileNotFoundError(f"superseder ADR not found: {superseder}")

    old_id = _id_from_filename(superseded)
    new_id = _id_from_filename(superseder)
    if old_id == new_id:
        raise ValueError(f"superseded and superseder share id {old_id}; ids must differ")

    old_text_before = superseded.read_text(encoding="utf-8")
    new_text_before = superseder.read_text(encoding="utf-8")
    old_fm, old_body = _split_frontmatter(old_text_before)
    new_fm, new_body = _split_frontmatter(new_text_before)

    existing_parent = old_fm.get("superseded-by")
    if existing_parent not in (None, ""):
        raise PermissionError(f"GP-06 single-parent violation: ADR {old_id} already superseded by '{existing_parent}'")

    new_fm["supersedes"] = old_id
    old_fm["superseded-by"] = new_id
    old_fm["status"] = "superseded"

    new_candidate = _join_frontmatter(new_fm, new_body)
    old_candidate = _join_frontmatter(old_fm, old_body)

    new_fd, new_tmp_name = tempfile.mkstemp(prefix=".tmp-", dir=superseder.parent)
    old_fd, old_tmp_name = tempfile.mkstemp(prefix=".tmp-", dir=superseded.parent)
    new_tmp = Path(new_tmp_name)
    old_tmp = Path(old_tmp_name)
    committed = False
    try:
        with os.fdopen(new_fd, "w", encoding="utf-8") as fh:
            fh.write(new_candidate)
        with os.fdopen(old_fd, "w", encoding="utf-8") as fh:
            fh.write(old_candidate)
        os.replace(new_tmp, superseder)
        try:
            os.replace(old_tmp, superseded)
        except Exception:
            superseder.write_text(new_text_before, encoding="utf-8")
            raise
        committed = True
    finally:
        for tmp in (new_tmp, old_tmp):
            if tmp.exists():
                tmp.unlink(missing_ok=True)

    if committed:
        try:
            validate_lineage(superseded=superseded, superseder=superseder)
        except Exception:
            superseded.write_text(old_text_before, encoding="utf-8")
            superseder.write_text(new_text_before, encoding="utf-8")
            raise


def create_parser() -> argparse.ArgumentParser:
    """Build the argparse parser for the ``update_lineage`` CLI."""
    parser = argparse.ArgumentParser(
        prog="update_lineage",
        description="Allocate ADR ids and atomically apply supersessions.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_alloc = sub.add_parser("allocate", help="Allocate the next NNNN id for a project.")
    p_alloc.add_argument(
        "--project-dir",
        required=True,
        type=Path,
        help="Project directory containing .adr-config.yml.",
    )
    p_alloc.add_argument(
        "--slug",
        required=True,
        help="Project slug (validated against allow-list regex).",
    )

    p_sup = sub.add_parser("supersede", help="Atomically supersede one ADR with another.")
    p_sup.add_argument(
        "--superseded",
        required=True,
        type=Path,
        help="Path to the ADR being superseded (older).",
    )
    p_sup.add_argument(
        "--superseder",
        required=True,
        type=Path,
        help="Path to the ADR doing the superseding (newer).",
    )
    p_sup.add_argument(
        "--allow-root",
        action="append",
        type=Path,
        default=[],
        dest="allow_root",
        help="Additional directory under which the ADR paths are allowed to live.",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    args = create_parser().parse_args(argv)
    try:
        if args.command == "allocate":
            print(allocate(args.project_dir, args.slug))
            return EXIT_SUCCESS
        if args.command == "supersede":
            allow_roots = [p.expanduser().resolve() for p in args.allow_root] or None
            supersede(args.superseded, args.superseder, allow_roots)
            return EXIT_SUCCESS
    except PermissionError as exc:
        print(f"update_lineage: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except (ValueError, FileNotFoundError, RuntimeError) as exc:
        print(f"update_lineage: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    except OSError as exc:
        print(f"update_lineage: I/O error: {exc}", file=sys.stderr)
        return EXIT_FAILURE
    return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
