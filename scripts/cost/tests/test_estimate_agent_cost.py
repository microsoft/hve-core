# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.cost.estimate_agent_cost import (  # noqa: E402
    CostEstimatorError,
    Tokenizer,
    build_result,
    normalize_text,
    parse_frontmatter,
    to_serializable,
    to_workspace_relative,
)


@pytest.fixture()
def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def test_given_known_agent_when_build_result_then_returns_expected_artifacts(
    repo_root: Path,
) -> None:
    # Arrange
    agent_name = "prd-builder"

    # Act
    result = build_result(agent_name, None, repo_root, None)

    # Assert
    assert result.agent == agent_name
    assert result.total_bytes >= 0
    assert result.estimated_tokens >= 0
    assert result.artifacts
    assert result.estimator == "heuristic"
    assert result.approximate is True
    assert result.fallback_reason is None
    artifact_paths = {artifact.path for artifact in result.artifacts}
    expected_skills = {
        ".github/skills/hve-core/architecture-diagrams/SKILL.md",
        ".github/skills/project-planning/requirements-author/SKILL.md",
        ".github/skills/shared/telemetry-foundations/SKILL.md",
    }
    assert expected_skills.issubset(artifact_paths)
    assert result.unresolved == []


def test_given_unknown_agent_when_build_result_then_raises_error(repo_root: Path) -> None:
    # Arrange
    agent_name = "missing-agent"

    # Act / Assert
    with pytest.raises(CostEstimatorError, match="Unable to resolve agent"):
        build_result(agent_name, None, repo_root, None)


def test_given_ambiguous_name_when_resolve_agent_then_errors(tmp_path: Path) -> None:
    # Arrange
    first_agent = tmp_path / ".github" / "agents" / "alpha" / "foo.agent.md"
    second_agent = tmp_path / ".github" / "agents" / "beta" / "foo.agent.md"
    first_agent.parent.mkdir(parents=True, exist_ok=True)
    second_agent.parent.mkdir(parents=True, exist_ok=True)
    first_agent.write_text("---\nname: Foo\n---\nhello\n", encoding="utf-8")
    second_agent.write_text("---\nname: Foo\n---\nworld\n", encoding="utf-8")

    # Act / Assert
    with pytest.raises(CostEstimatorError, match="Ambiguous agent match"):
        build_result("foo", None, tmp_path, None)


def test_given_same_inputs_when_build_result_then_deterministic_output(repo_root: Path) -> None:
    # Arrange
    first = build_result("prd-builder", None, repo_root, None)

    # Act
    second = build_result("prd-builder", None, repo_root, None)

    # Assert
    assert to_serializable(first) == to_serializable(second)


def test_given_multiline_frontmatter_agents_when_parse_frontmatter_then_returns_list(
    tmp_path: Path,
) -> None:
    # Arrange
    agent_path = tmp_path / "sample.agent.md"
    agent_path.write_text(
        "---\nname: Sample\nagents:\n  - Alpha\n  - Beta\n---\nbody\n",
        encoding="utf-8",
    )

    # Act
    frontmatter = parse_frontmatter(agent_path)

    # Assert
    assert frontmatter["agents"] == ["Alpha", "Beta"]


def test_given_missing_named_skill_when_build_result_then_records_unresolved(
    tmp_path: Path,
) -> None:
    # Arrange
    agent_path = tmp_path / ".github" / "agents" / "sample.agent.md"
    agent_path.parent.mkdir(parents=True)
    agent_path.write_text(
        "---\nname: Sample\n---\nUse the `missing-skill` skill.\n",
        encoding="utf-8",
    )

    # Act
    result = build_result("sample", None, tmp_path, None)

    # Assert
    assert result.unresolved == ["skill:missing-skill"]


def test_given_ambiguous_named_skill_when_build_result_then_records_unresolved(
    tmp_path: Path,
) -> None:
    # Arrange
    agent_path = tmp_path / ".github" / "agents" / "sample.agent.md"
    agent_path.parent.mkdir(parents=True)
    agent_path.write_text(
        "---\nname: Sample\n---\nUse the `shared` skill.\n",
        encoding="utf-8",
    )
    for collection in ("alpha", "beta"):
        skill_path = tmp_path / ".github" / "skills" / collection / "shared" / "SKILL.md"
        skill_path.parent.mkdir(parents=True)
        skill_path.write_text("# Shared\n", encoding="utf-8")

    # Act
    result = build_result("sample", None, tmp_path, None)

    # Assert
    assert result.unresolved == ["skill:shared (ambiguous)"]


def test_given_phase_when_build_result_then_includes_phase_skill_section(repo_root: Path) -> None:
    # Arrange
    agent_name = "brd-builder"

    # Act
    result = build_result(agent_name, "define", repo_root, None)

    # Assert
    phase_sections = [artifact.path for artifact in result.artifacts if "#define" in artifact.path]
    assert len(phase_sections) == 1
    assert result.unresolved == []
    requirements_artifacts = [
        artifact.path
        for artifact in result.artifacts
        if "/requirements-author/SKILL.md" in artifact.path
    ]
    assert requirements_artifacts == phase_sections


def test_given_encoding_available_when_build_result_then_uses_tiktoken_path(
    repo_root: Path,
) -> None:
    # Arrange
    pytest.importorskip("tiktoken")

    # Act
    result = build_result("prd-builder", None, repo_root, "cl100k_base")

    # Assert
    assert result.estimator == "cl100k_base"
    assert result.approximate is False
    assert result.encoding == "cl100k_base"
    assert result.fallback_reason is None


def test_given_invalid_encoding_when_estimate_then_reports_fallback_reason(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    class InvalidEncodingModule:
        @staticmethod
        def get_encoding(name: str) -> None:
            raise ValueError(name)

    tokenizer = Tokenizer("not-an-encoding")
    monkeypatch.setattr(tokenizer, "_tiktoken", InvalidEncodingModule())

    # Act
    token_count, estimator, approximate, fallback_reason = tokenizer.estimate("hello")

    # Assert
    assert token_count >= 0
    assert estimator == "heuristic"
    assert approximate is True
    assert fallback_reason == (
        "Encoding 'not-an-encoding' is unavailable in tiktoken; used the heuristic estimator."
    )


def test_given_requested_encoding_without_tiktoken_when_estimate_then_reports_fallback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    tokenizer = Tokenizer("cl100k_base")
    monkeypatch.setattr(tokenizer, "_tiktoken", None)

    # Act
    _, estimator, approximate, fallback_reason = tokenizer.estimate("hello")

    # Assert
    assert estimator == "heuristic"
    assert approximate is True
    assert fallback_reason == "tiktoken is not installed; used the heuristic estimator."


def test_given_cli_run_when_json_output_then_includes_required_keys(
    repo_root: Path,
) -> None:
    # Arrange
    command = [
        sys.executable,
        "scripts/cost/estimate_agent_cost.py",
        "--agent",
        "prd-builder",
        "--format",
        "json",
    ]

    # Act
    completed = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )

    # Assert
    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert {
        "agent",
        "phase",
        "estimator",
        "approximate",
        "encoding",
        "fallback_reason",
        "total_bytes",
        "estimated_tokens",
        "artifacts",
        "unresolved",
        "limitations",
    }.issubset(payload.keys())
    assert isinstance(payload["total_bytes"], int)
    assert isinstance(payload["estimated_tokens"], int)
    assert payload["total_bytes"] >= 0
    assert payload["estimated_tokens"] >= 0
    assert all("\\" not in artifact["path"] for artifact in payload["artifacts"])


def test_given_unknown_agent_when_cli_runs_then_exits_with_configuration_error(
    repo_root: Path,
) -> None:
    # Arrange
    command = [
        sys.executable,
        "scripts/cost/estimate_agent_cost.py",
        "--agent",
        "missing-agent",
    ]

    # Act
    completed = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )

    # Assert
    assert completed.returncode == 2
    assert "Unable to resolve agent 'missing-agent'" in completed.stderr


def test_given_text_when_normalize_text_then_uses_consistent_line_endings() -> None:
    # Arrange
    text = "alpha\r\n\r\nbeta"

    # Act
    normalized = normalize_text(text)

    # Assert
    assert normalized == "alpha\n\nbeta"


def test_given_external_path_when_relativized_then_error_omits_parent_directories(
    tmp_path: Path,
) -> None:
    # Arrange
    repo_root = tmp_path / "repo"
    external_path = tmp_path / "private" / "artifact.md"
    repo_root.mkdir()

    # Act / Assert
    with pytest.raises(CostEstimatorError) as error:
        to_workspace_relative(repo_root, external_path)
    assert "artifact.md" in str(error.value)
    assert "private" not in str(error.value)
