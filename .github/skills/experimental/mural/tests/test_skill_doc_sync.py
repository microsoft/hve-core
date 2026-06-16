# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""SKILL.md ↔ `_build_parser` drift guard."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

ANCHOR = re.compile(
    r"<!-- COMMANDS:BEGIN -->(.*?)<!-- COMMANDS:END -->",
    re.S,
)

SKILL_PATH = Path(__file__).resolve().parents[1] / "SKILL.md"

COMMAND_ROW = re.compile(r"`(mural(?: [\w-]+)+)`")


def _walk(parser: argparse.ArgumentParser, prefix: str) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for action in parser._actions:
        if not isinstance(action, argparse._SubParsersAction):
            continue
        help_by_name = {
            choice_action.dest: (choice_action.help or "")
            for choice_action in action._choices_actions
        }
        for name, sub in action.choices.items():
            full = f"{prefix} {name}".strip()
            help_text = help_by_name.get(name, "").strip()
            rows.append((full, help_text))
            rows.extend(_walk(sub, full))
    return rows


def _anchor_body() -> str:
    skill = SKILL_PATH.read_text(encoding="utf-8")
    match = ANCHOR.search(skill)
    assert match, "SKILL.md is missing the COMMANDS anchor block"
    return match.group(1)


def test_skill_md_anchor_covers_every_parser_command(mural_module: Any) -> None:
    rows = _walk(mural_module._build_parser(), "mural")
    body = _anchor_body()
    missing = [command for command, _ in rows if f"`{command}`" not in body]
    assert not missing, f"SKILL.md anchor block is missing parser commands: {missing}"


def test_skill_md_anchor_has_no_unknown_commands(mural_module: Any) -> None:
    parser = mural_module._build_parser()
    parser_commands = {command for command, _ in _walk(parser, "mural")}
    body = _anchor_body()
    documented = set(COMMAND_ROW.findall(body))
    extras = sorted(documented - parser_commands)
    assert not extras, (
        "SKILL.md anchor block contains commands not emitted by _build_parser: "
        f"{extras}"
    )
