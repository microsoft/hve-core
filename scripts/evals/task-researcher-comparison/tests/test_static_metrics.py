# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
from pathlib import Path

from task_researcher_comparison.fixtures import load_fixture_pair, load_scenarios
from task_researcher_comparison.models import CapturedOutput
from task_researcher_comparison.static_metrics import score_output, score_pair

FIXTURE_ROOT = Path(__file__).resolve().parents[1] / "fixtures"
LOCAL_LANE_MARKERS = (
    "codebase locator",
    "codebase analyzer",
    "codebase pattern finder",
)
WEB_LANE_MARKER = "web search researcher"


def test_loads_three_scenarios() -> None:
    scenarios = load_scenarios(FIXTURE_ROOT / "scenarios.yml")
    assert [scenario.id for scenario in scenarios] == ["codebase-lane", "focused-local", "external-api"]


def test_with_subagents_scores_lane_markers_for_codebase_case() -> None:
    scenario = next(item for item in load_scenarios(FIXTURE_ROOT / "scenarios.yml") if item.id == "codebase-lane")
    without, with_subagents = load_fixture_pair(FIXTURE_ROOT, scenario.id)

    score = score_pair(scenario, without, with_subagents)

    assert all(marker in with_subagents.text.lower() for marker in LOCAL_LANE_MARKERS)
    assert WEB_LANE_MARKER not in with_subagents.text.lower()
    assert not any(marker in without.text.lower() for marker in (*LOCAL_LANE_MARKERS, WEB_LANE_MARKER))
    assert score.with_subagents.mode_compliance == 2
    assert score.without_subagents.mode_compliance == 2
    assert score.with_subagents.coverage > score.without_subagents.coverage
    assert score.delta_total >= 0


def test_focused_case_rewards_no_lane_fanout() -> None:
    scenario = next(item for item in load_scenarios(FIXTURE_ROOT / "scenarios.yml") if item.id == "focused-local")
    without, with_subagents = load_fixture_pair(FIXTURE_ROOT, scenario.id)

    score = score_pair(scenario, without, with_subagents)

    assert score.with_subagents.mode_compliance == 2
    assert score.with_subagents.noise_control >= 1


def test_external_case_detects_far_quality_note() -> None:
    scenario = next(item for item in load_scenarios(FIXTURE_ROOT / "scenarios.yml") if item.id == "external-api")
    without, with_subagents = load_fixture_pair(FIXTURE_ROOT, scenario.id)

    score = score_pair(scenario, without, with_subagents)

    assert score.with_subagents.coverage == 2
    assert score.with_subagents.citation_precision == 2
    assert score.with_subagents.mode_compliance == 2


def test_focused_case_penalizes_any_lane_fanout() -> None:
    scenario = next(item for item in load_scenarios(FIXTURE_ROOT / "scenarios.yml") if item.id == "focused-local")
    without, _ = load_fixture_pair(FIXTURE_ROOT, scenario.id)
    output = CapturedOutput(
        scenario_id=scenario.id,
        variant="with-subagents",
        text=f"{without.text}\nCodebase Locator: unnecessary fan-out.",
    )

    score = score_output(scenario, output)

    assert score.mode_compliance == 1
