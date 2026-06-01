# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Validate the per-project ``.adr-config.yml`` against its JSON schema.

Loads the YAML file with ``yaml.safe_load`` and validates it against
``scripts/linting/schemas/adr-config.schema.json`` (draft-07).

Usage::

    python -m scripts.validate_config <config-path> [<config-path> ...]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft7Validator

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

SKILL_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = SKILL_ROOT.parents[3] if len(SKILL_ROOT.parents) >= 4 else SKILL_ROOT
SCHEMA_PATH = REPO_ROOT / "scripts" / "linting" / "schemas" / "adr-config.schema.json"


def _load_schema(schema_path: Path) -> dict[str, Any]:
    with schema_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _load_config(config_path: Path) -> dict[str, Any]:
    with config_path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{config_path}: top-level YAML must be a mapping, got {type(data).__name__}")
    return data


def validate(config_path: Path, schema: dict[str, Any]) -> list[str]:
    try:
        config = _load_config(config_path)
    except (yaml.YAMLError, ValueError, OSError) as exc:
        return [f"{config_path}: load error: {exc}"]

    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(config), key=lambda e: list(e.absolute_path))
    return [
        f"{config_path}: {'/'.join(str(p) for p in err.absolute_path) or '<root>'}: {err.message}" for err in errors
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="Config file path(s)")
    parser.add_argument(
        "--schema",
        type=Path,
        default=SCHEMA_PATH,
        help="Override schema path (default: repo adr-config.schema.json)",
    )
    args = parser.parse_args(argv)

    if not args.schema.exists():
        print(f"error: schema not found: {args.schema}", file=sys.stderr)
        return EXIT_ERROR

    schema = _load_schema(args.schema)
    failures: list[str] = []
    for path in args.paths:
        if not path.exists():
            failures.append(f"{path}: file not found")
            continue
        failures.extend(validate(path, schema))

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return EXIT_FAILURE

    print(f"OK: {len(args.paths)} config file(s) validated")
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
