#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate that threat-model gap citations resolve to a declaring skill."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import tm7_threat_contract
import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

GAP_ID_PATTERN = re.compile(r"\bG-[A-Z]{3}-\d+\b")


def build_registers(skills_root: Path) -> dict[str, set[str]]:
    """Read every per-skill SECURITY.md and index the gap ids it declares."""
    registers: dict[str, set[str]] = {}
    for security_file in sorted(skills_root.glob("**/SECURITY.md")):
        skill = security_file.parent.name
        text = security_file.read_text(encoding="utf-8")
        registers[skill] = set(GAP_ID_PATTERN.findall(text))
    return registers


def load_spec(path: Path) -> dict[str, Any]:
    """Load a YAML or JSON threat-model spec."""
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return json.loads(text)
    return yaml.safe_load(text)


def create_parser() -> argparse.ArgumentParser:
    """Create the CLI parser for gap-citation validation."""
    parser = argparse.ArgumentParser(
        description="Validate threat-model gap citations against per-skill registers"
    )
    parser.add_argument("spec", type=Path, help="Path to the input threat-model spec")
    parser.add_argument(
        "--skills-root",
        type=Path,
        default=Path(".github/skills"),
        help="Root directory containing per-skill SECURITY.md files",
    )
    return parser


def main() -> int:
    """Report unresolvable gap citations and exit non-zero when any remain."""
    args = create_parser().parse_args()
    registers = build_registers(args.skills_root)
    if not registers:
        print(f"No SECURITY.md files found under {args.skills_root}", file=sys.stderr)
        return EXIT_FAILURE

    spec = load_spec(args.spec)
    failures = tm7_threat_contract.collect_gap_citation_failures(spec, registers)
    if failures:
        print("Gap citation validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return EXIT_FAILURE

    print(
        f"Gap citations resolve against {len(registers)} skill registers "
        f"({sum(len(v) for v in registers.values())} declared gap ids)"
    )
    return EXIT_SUCCESS


if __name__ == "__main__":
    raise SystemExit(main())
