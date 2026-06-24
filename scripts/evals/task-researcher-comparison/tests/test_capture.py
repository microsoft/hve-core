# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
from __future__ import annotations

from types import SimpleNamespace

import pytest

from task_researcher_comparison import capture
from task_researcher_comparison.capture import build_prompt, runner_argv_from_env


def test_given_with_subagents_variant_when_build_prompt_then_uses_lanes() -> None:
    prompt = build_prompt("Research the mode selector", "with-subagents")

    assert prompt == '/task-research topic="Research the mode selector" mode=lanes subagents=true'


def test_given_no_subagents_variant_when_build_prompt_then_uses_focused() -> None:
    prompt = build_prompt("Research the mode selector", "no-subagents")

    assert prompt == '/task-research topic="Research the mode selector" mode=focused subagents=false'


def test_given_runner_argv_json_when_parsed_then_prompt_is_argument(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", '["agent-runner", "--prompt", "{prompt}"]')

    argv = runner_argv_from_env('/task-research topic="x; rm -rf /"')

    assert argv == ["agent-runner", "--prompt", '/task-research topic="x; rm -rf /"']


def test_given_malformed_runner_argv_json_when_parsed_then_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", '{"cmd": "agent-runner"}')

    with pytest.raises(ValueError, match="JSON string array"):
        runner_argv_from_env("prompt")


def test_given_mixed_type_runner_argv_array_when_parsed_then_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", '["agent-runner", 1]')

    with pytest.raises(ValueError, match="JSON string array"):
        runner_argv_from_env("prompt")


def test_given_empty_runner_argv_env_when_parsed_then_returns_none(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", "")

    assert runner_argv_from_env("prompt") is None


def test_given_malformed_runner_argv_when_running_main_then_returns_exit_code_2(
    monkeypatch: pytest.MonkeyPatch, tmp_path
) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", '{"cmd": "agent-runner"}')
    monkeypatch.setattr(
        "task_researcher_comparison.capture.load_scenarios",
        lambda _path: [SimpleNamespace(id="scenario-1", prompt="prompt")],
    )
    monkeypatch.setattr(
        "task_researcher_comparison.capture.sys.argv",
        ["capture.py", "--fixtures-root", str(tmp_path), "--output-root", str(tmp_path / "out")],
    )

    assert capture.main() == 2
