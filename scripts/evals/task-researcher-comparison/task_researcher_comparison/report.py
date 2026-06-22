from __future__ import annotations

import json
from pathlib import Path

from task_researcher_comparison.models import PairScore


def _score_to_dict(score: PairScore) -> dict[str, object]:
    return {
        "scenario_id": score.scenario_id,
        "without_subagents": {
            "coverage": score.without_subagents.coverage,
            "citation_precision": score.without_subagents.citation_precision,
            "actionability": score.without_subagents.actionability,
            "noise_control": score.without_subagents.noise_control,
            "mode_compliance": score.without_subagents.mode_compliance,
            "total": score.without_subagents.total,
        },
        "with_subagents": {
            "coverage": score.with_subagents.coverage,
            "citation_precision": score.with_subagents.citation_precision,
            "actionability": score.with_subagents.actionability,
            "noise_control": score.with_subagents.noise_control,
            "mode_compliance": score.with_subagents.mode_compliance,
            "total": score.with_subagents.total,
        },
        "delta_total": score.delta_total,
    }


def write_reports(scores: list[PairScore], output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "summary.json"
    markdown_path = output_dir / "summary.md"
    payload = {
        "scenario_count": len(scores),
        "scores": [_score_to_dict(score) for score in scores],
    }
    json_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Task Researcher Subagent Comparison",
        "",
        "| Scenario | No subagents | With subagents | Delta | Recommendation |",
        "|----------|--------------|----------------|-------|----------------|",
    ]
    for score in scores:
        recommendation = "Prefer with-subagents" if score.delta_total >= 2 else "Prefer no-subagents or tie-break manually"
        lines.append(
            f"| {score.scenario_id} | {score.without_subagents.total} | "
            f"{score.with_subagents.total} | {score.delta_total} | {recommendation} |"
        )
    markdown_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return json_path, markdown_path
