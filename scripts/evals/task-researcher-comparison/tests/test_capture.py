# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
from __future__ import annotations

import pytest

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


def test_given_invalid_runner_argv_when_parsed_then_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TASK_RESEARCHER_RUNNER_ARGV", '{"cmd": "agent-runner"}')

    with pytest.raises(ValueError, match="JSON string array"):
        runner_argv_from_env("prompt")
