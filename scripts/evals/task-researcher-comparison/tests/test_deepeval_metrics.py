# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
from pathlib import Path

import pytest
from deepeval import assert_test

from task_researcher_comparison.deepeval_metrics import (
    build_comparison_test_case,
    build_metrics,
    require_deepeval_llm_enabled,
)
from task_researcher_comparison.fixtures import load_fixture_pair, load_scenarios

FIXTURE_ROOT = Path(__file__).resolve().parents[1] / "fixtures"


@pytest.mark.deepeval
def test_deepeval_metric_definitions_are_available() -> None:
    metrics = build_metrics()
    assert [metric.name for metric in metrics] == [
        "Evidence Coverage",
        "Citation Precision",
        "Actionability",
        "Noise Control",
        "Mode Compliance",
    ]


@pytest.mark.deepeval
def test_codebase_lane_output_with_deepeval() -> None:
    require_deepeval_llm_enabled()
    scenario = next(item for item in load_scenarios(FIXTURE_ROOT / "scenarios.yml") if item.id == "codebase-lane")
    without, with_subagents = load_fixture_pair(FIXTURE_ROOT, scenario.id)
    test_case = build_comparison_test_case(scenario, without, with_subagents)

    assert_test(test_case, build_metrics())
