# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_module():
    script_path = (
        Path(__file__).resolve().parents[1] / "scripts" / "generate_cards.py"
    )
    spec = importlib.util.spec_from_file_location(
        "generate_cards", script_path)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    sys.modules["generate_cards"] = module
    spec.loader.exec_module(module)
    return module


MODULE = _load_module()


def _exercise_parser(data: bytes) -> None:
    text = data.decode("utf-8", errors="ignore")
    MODULE.parse_frontmatter(text)
    for heading in [
        "Description",
        "Scenario Narrative",
        "How Might We",
        "Use Case Description",
        "User Goal",
    ]:
        MODULE.extract_section(text, heading)


if __name__ == "__main__":
    import sys

    import atheris

    atheris.Setup(sys.argv, _exercise_parser)
    atheris.Fuzz()
