# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
import json
from pathlib import Path

from task_researcher_comparison.fixtures import load_fixture_pair, load_scenarios
from task_researcher_comparison.models import PairScore, StaticScore
from task_researcher_comparison.report import write_reports
from task_researcher_comparison.static_metrics import score_pair

FIXTURE_ROOT = Path(__file__).resolve().parents[1] / "fixtures"


def _pair(without: StaticScore, with_subagents: StaticScore) -> PairScore:
    return PairScore(scenario_id="case", without_subagents=without, with_subagents=with_subagents)


def _recommendation_in_report(score: PairScore, tmp_path: Path) -> str:
    json_path, _ = write_reports([score], tmp_path)
    data = json.loads(json_path.read_text(encoding="utf-8"))
    return data["scores"][0]["recommendation"]


def test_recommends_with_subagents_on_coverage_actionability_gain(tmp_path: Path) -> None:
    # +2 combined coverage/actionability gain, no noise-control loss.
    score = _pair(
        StaticScore(coverage=0, citation_precision=1, actionability=0, noise_control=2, mode_compliance=1),
        StaticScore(coverage=2, citation_precision=1, actionability=0, noise_control=2, mode_compliance=1),
    )
    assert _recommendation_in_report(score, tmp_path) == "Prefer with-subagents"


def test_does_not_recommend_when_noise_control_loss_exceeds_one(tmp_path: Path) -> None:
    # +2 gain but noise control drops by 2, which the README rule disqualifies.
    score = _pair(
        StaticScore(coverage=0, citation_precision=1, actionability=0, noise_control=2, mode_compliance=1),
        StaticScore(coverage=2, citation_precision=1, actionability=0, noise_control=0, mode_compliance=1),
    )
    assert _recommendation_in_report(score, tmp_path) == "Prefer no-subagents or tie-break manually"


def test_does_not_recommend_when_gain_below_threshold(tmp_path: Path) -> None:
    # Only +1 combined coverage/actionability gain, below the 2-point threshold.
    score = _pair(
        StaticScore(coverage=1, citation_precision=1, actionability=1, noise_control=2, mode_compliance=1),
        StaticScore(coverage=1, citation_precision=1, actionability=2, noise_control=2, mode_compliance=1),
    )
    assert _recommendation_in_report(score, tmp_path) == "Prefer no-subagents or tie-break manually"


def test_write_reports(tmp_path: Path) -> None:
    scenarios = load_scenarios(FIXTURE_ROOT / "scenarios.yml")
    scores = []
    for scenario in scenarios:
        without, with_subagents = load_fixture_pair(FIXTURE_ROOT, scenario.id)
        scores.append(score_pair(scenario, without, with_subagents))

    json_path, markdown_path = write_reports(scores, tmp_path)

    data = json.loads(json_path.read_text(encoding="utf-8"))
    assert data["scenario_count"] == 3
    assert "Task Researcher Subagent Comparison" in markdown_path.read_text(encoding="utf-8")
