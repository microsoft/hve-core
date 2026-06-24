# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
from __future__ import annotations

from pathlib import Path

import yaml

from task_researcher_comparison.models import CapturedOutput, Scenario


def load_scenarios(path: Path) -> list[Scenario]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    scenarios = data["scenarios"]
    return [
        Scenario(
            id=item["id"],
            title=item["title"],
            prompt=item["prompt"],
            expected_mode_without_subagents=item["expected_mode_without_subagents"],
            expected_mode_with_subagents=item["expected_mode_with_subagents"],
            required_evidence=tuple(item["required_evidence"]),
            grading_focus=dict(item["grading_focus"]),
        )
        for item in scenarios
    ]


def load_output(path: Path, scenario_id: str, variant: str) -> CapturedOutput:
    return CapturedOutput(scenario_id=scenario_id, variant=variant, text=path.read_text(encoding="utf-8"))


def load_fixture_pair(fixture_root: Path, scenario_id: str) -> tuple[CapturedOutput, CapturedOutput]:
    scenario_dir = fixture_root / "outputs" / scenario_id
    return (
        load_output(scenario_dir / "no-subagents.md", scenario_id, "no-subagents"),
        load_output(scenario_dir / "with-subagents.md", scenario_id, "with-subagents"),
    )
