import json
from pathlib import Path

from task_researcher_comparison.fixtures import load_fixture_pair, load_scenarios
from task_researcher_comparison.report import write_reports
from task_researcher_comparison.static_metrics import score_pair

FIXTURE_ROOT = Path(__file__).resolve().parents[1] / "fixtures"


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
