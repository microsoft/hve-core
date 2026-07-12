# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from scripts.cost.aggregate_token_priors import (
    ScanDiagnostics,
    TokenMeasurement,
    aggregate_summaries,
    build_priors_result,
    load_session_summaries,
    merge_subagent_summaries,
    percentile,
)


def write_jsonl(path: Path, records: list[object]) -> None:
    """Write test records as JSONL."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(record) + "\n" for record in records), encoding="utf-8")


def create_agent(repo_root: Path, name: str = "sample") -> None:
    """Create a minimal agent for static-floor fallback tests."""
    agent_path = repo_root / ".github" / "agents" / f"{name}.agent.md"
    agent_path.parent.mkdir(parents=True, exist_ok=True)
    agent_path.write_text(f"---\nname: {name}\n---\nAgent body.\n", encoding="utf-8")


def summary_record(sid: str, input_tokens: int, output_tokens: int) -> dict[str, object]:
    """Build a complete SessionSummary test record."""
    usage = {
        "input_tokens": input_tokens,
        "input_tokens_uncached": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "requests": 1,
    }
    return {
        "event": "SessionSummary",
        "sid": sid,
        "ts": f"2026-07-{sid[-2:]}T00:00:00Z",
        "last_ts": f"2026-07-{sid[-2:]}T00:00:00Z",
        "token_source": "process_log",
        **usage,
        "agent_usage": {"sample": usage},
        "model_usage": {"test-model": usage},
    }


def test_given_values_when_percentile_then_interpolates_and_rounds_up() -> None:
    # Arrange
    values = [100, 200]

    # Act
    p50 = percentile(values, 0.50)
    p90 = percentile(values, 0.90)

    # Assert
    assert (p50, p90) == (150, 190)


def test_given_invalid_percentile_when_calculated_then_raises_value_error() -> None:
    # Arrange
    values = [100]

    # Act
    try:
        percentile(values, 1.1)
    except ValueError as error:
        message = str(error)
    else:
        message = ""

    # Assert
    assert message == "percentile must be between 0 and 1"


def test_given_duplicate_summaries_when_loaded_then_prefers_process_log(
    tmp_path: Path,
) -> None:
    # Arrange
    telemetry_dir = tmp_path / "telemetry"
    fallback = summary_record("session-01", 900, 90)
    fallback.update(token_source="state_fallback", last_ts="2026-07-12T00:00:00Z")
    process_log = summary_record("session-01", 100, 10)
    write_jsonl(telemetry_dir / "sessions-2026-07-11.jsonl", [process_log, fallback])

    # Act
    summaries, diagnostics = load_session_summaries(telemetry_dir)

    # Assert
    assert summaries["session-01"]["input_tokens"] == 100
    assert diagnostics.superseded_summaries == 1


def test_given_equal_provenance_when_loaded_then_prefers_freshest_summary(
    tmp_path: Path,
) -> None:
    # Arrange
    telemetry_dir = tmp_path / "telemetry"
    older = summary_record("session-01", 100, 10)
    newer = summary_record("session-01", 200, 20)
    newer["last_ts"] = "2026-07-12T00:00:00Z"
    write_jsonl(telemetry_dir / "sessions-2026-07-11.jsonl", [older, newer])

    # Act
    summaries, _ = load_session_summaries(telemetry_dir)

    # Assert
    assert summaries["session-01"]["input_tokens"] == 200


def test_given_malformed_records_when_loaded_then_skips_and_counts_them(
    tmp_path: Path,
) -> None:
    # Arrange
    telemetry_dir = tmp_path / "telemetry"
    telemetry_file = telemetry_dir / "sessions-2026-07-11.jsonl"
    telemetry_dir.mkdir()
    telemetry_file.write_text(
        "not-json\n[]\n" + json.dumps(summary_record("session-01", 100, 10)) + "\n",
        encoding="utf-8",
    )

    # Act
    summaries, diagnostics = load_session_summaries(telemetry_dir)

    # Assert
    assert len(summaries) == 1
    assert diagnostics.malformed_records == 2


def test_given_summary_when_aggregated_then_emits_agent_and_model_priors() -> None:
    # Arrange
    summaries = {"session-01": summary_record("session-01", 100, 25)}
    diagnostics = ScanDiagnostics()

    # Act
    session_prior, by_agent, by_model = aggregate_summaries(summaries, diagnostics, 1)

    # Assert
    assert session_prior is not None
    assert session_prior["p90"]["total_tokens"] == 125
    assert by_agent[0]["agent"] == "sample"
    assert by_model[0]["model"] == "test-model"


def test_given_summary_without_agent_usage_when_aggregated_then_uses_root() -> None:
    # Arrange
    summary = summary_record("session-01", 100, 25)
    summary.pop("agent_usage")

    # Act
    _, by_agent, _ = aggregate_summaries(
        {"session-01": summary},
        ScanDiagnostics(),
        1,
    )

    # Assert
    assert by_agent[0]["agent"] == "root"


def test_given_root_agent_when_aggregated_then_uses_whole_session_for_workflow() -> None:
    # Arrange
    summary = summary_record("session-01", 100, 25)
    summary["gen_ai.agent.name"] = "RPI Agent"
    summary["agent_usage"] = {
        "root": {
            "input_tokens": 40,
            "input_tokens_uncached": 40,
            "output_tokens": 10,
            "requests": 1,
        },
        "Researcher": {
            "input_tokens": 60,
            "input_tokens_uncached": 60,
            "output_tokens": 15,
            "requests": 1,
        },
    }

    # Act
    _, by_agent, _ = aggregate_summaries(
        {"session-01": summary},
        ScanDiagnostics(),
        1,
    )

    # Assert
    priors = {item["agent"]: item for item in by_agent}
    assert priors["RPI Agent"]["p90"]["total_tokens"] == 125
    assert priors["Researcher"]["p90"]["total_tokens"] == 75


def test_given_root_agent_without_agent_usage_when_aggregated_then_labels_session() -> None:
    # Arrange
    summary = summary_record("session-01", 100, 25)
    summary["gen_ai.agent.name"] = "RPI Agent"
    summary.pop("agent_usage")

    # Act
    _, by_agent, _ = aggregate_summaries(
        {"session-01": summary},
        ScanDiagnostics(),
        1,
    )

    # Assert
    assert by_agent[0]["agent"] == "RPI Agent"


def test_given_linked_child_when_merged_then_parent_contains_full_workflow_usage() -> None:
    # Arrange
    parent = summary_record("parent-01", 100, 20)
    parent["gen_ai.agent.name"] = "RPI Agent"
    parent.pop("agent_usage")
    parent["subagent_map"] = {"child-01": "Researcher"}
    child = summary_record("child-01", 50, 10)
    child.pop("agent_usage")
    diagnostics = ScanDiagnostics()

    # Act
    merged = merge_subagent_summaries(
        {"parent-01": parent, "child-01": child},
        diagnostics,
    )
    _, by_agent, _ = aggregate_summaries(merged, diagnostics, 1)

    # Assert
    priors = {item["agent"]: item for item in by_agent}
    assert set(merged) == {"parent-01"}
    assert priors["RPI Agent"]["p90"]["total_tokens"] == 180
    assert priors["Researcher"]["p90"]["total_tokens"] == 60
    assert diagnostics.merged_subagent_sessions == 1


def test_given_child_already_attributed_when_merged_then_does_not_double_count() -> None:
    # Arrange
    parent = summary_record("parent-01", 150, 30)
    parent["subagent_map"] = {"child-01": "Researcher"}
    parent["agent_usage"] = {
        "root": summary_record("root-01", 100, 20)["agent_usage"]["sample"],
        "Researcher": summary_record("agent-01", 50, 10)["agent_usage"]["sample"],
    }
    child = summary_record("child-01", 50, 10)
    diagnostics = ScanDiagnostics()

    # Act
    merged = merge_subagent_summaries(
        {"parent-01": parent, "child-01": child},
        diagnostics,
    )

    # Assert
    assert merged["parent-01"]["input_tokens"] == 150
    assert merged["parent-01"]["output_tokens"] == 30
    assert diagnostics.merged_subagent_sessions == 1


def test_given_sparse_agent_history_when_built_then_uses_static_floor(tmp_path: Path) -> None:
    # Arrange
    create_agent(tmp_path)
    telemetry_dir = tmp_path / ".copilot-tracking" / "telemetry"
    write_jsonl(
        telemetry_dir / "sessions-2026-07-11.jsonl",
        [summary_record("session-01", 100, 25)],
    )

    # Act
    result = build_priors_result(
        tmp_path,
        telemetry_dir,
        "sample",
        None,
        None,
        None,
        2,
    )

    # Assert
    assert result["forecast"]["source"] == "static_floor"
    assert result["forecast"]["historical_prior"]["sample_count"] == 1


def test_given_sufficient_agent_history_when_built_then_uses_historical_p90(
    tmp_path: Path,
) -> None:
    # Arrange
    create_agent(tmp_path)
    telemetry_dir = tmp_path / ".copilot-tracking" / "telemetry"
    write_jsonl(
        telemetry_dir / "sessions-2026-07-11.jsonl",
        [summary_record("session-01", 100, 20), summary_record("session-02", 200, 40)],
    )

    # Act
    result = build_priors_result(
        tmp_path,
        telemetry_dir,
        "sample",
        None,
        None,
        None,
        2,
    )

    # Assert
    assert result["forecast"]["source"] == "historical_p90"
    assert result["forecast"]["estimated_tokens"] == 228


def test_given_named_parent_with_child_when_built_then_forecast_includes_child(
    tmp_path: Path,
) -> None:
    # Arrange
    create_agent(tmp_path)
    telemetry_dir = tmp_path / ".copilot-tracking" / "telemetry"
    parent = summary_record("parent-01", 100, 20)
    parent["gen_ai.agent.name"] = "sample"
    parent.pop("agent_usage")
    parent["subagent_map"] = {"child-01": "Researcher"}
    child = summary_record("child-01", 50, 10)
    child.pop("agent_usage")
    write_jsonl(
        telemetry_dir / "sessions-2026-07-11.jsonl",
        [parent, child],
    )

    # Act
    result = build_priors_result(
        tmp_path,
        telemetry_dir,
        "sample",
        None,
        None,
        None,
        1,
    )

    # Assert
    assert result["forecast"]["source"] == "historical_p90"
    assert result["forecast"]["estimated_tokens"] == 180
    assert result["telemetry"]["merged_subagent_sessions"] == 1


def test_given_empty_history_when_cli_runs_then_writes_json_fallback(tmp_path: Path) -> None:
    # Arrange
    create_agent(tmp_path)
    script_path = Path(__file__).resolve().parents[1] / "aggregate_token_priors.py"
    command = [
        sys.executable,
        str(script_path),
        "--agent",
        "sample",
        "--repo-root",
        str(tmp_path),
        "--format",
        "json",
    ]

    # Act
    completed = subprocess.run(command, capture_output=True, text=True, check=False)

    # Assert
    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert payload["forecast"]["source"] == "static_floor"
    assert (tmp_path / "logs" / "cost" / "sample-priors.json").is_file()


def test_given_measurements_when_aggregated_then_p90_waits_for_minimum() -> None:
    # Arrange
    measurement = TokenMeasurement(100, 90, 20, 120, 10, 0, 1)
    summary = summary_record("session-01", 100, 20)
    diagnostics = ScanDiagnostics()

    # Act
    session_prior, _, _ = aggregate_summaries(
        {"session-01": summary},
        diagnostics,
        2,
    )

    # Assert
    assert measurement.total_tokens == 120
    assert session_prior is not None
    assert session_prior["quality"] == "sparse"
    assert session_prior["p90"] is None
