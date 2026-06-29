#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot Atheris fuzz harness for OSSF Scorecard compliance.

This file satisfies the fuzzing requirement when run via Atheris, and
acts as a no-op when imported by pytest.
"""

import sys

from task_researcher_comparison.models import CapturedOutput, Scenario
from task_researcher_comparison.static_metrics import score_output


def fuzz_static_metric_input(data: bytes) -> None:
    """Fuzz target for deterministic static metric scoring."""
    text = data.decode("utf-8", errors="ignore")
    scenario = Scenario(
        id="fuzz",
        title="Fuzz scenario",
        prompt="Fuzz static scoring",
        expected_mode_without_subagents="focused",
        expected_mode_with_subagents="lanes",
        required_evidence=(".github/agents/hve-core/task-researcher.agent.md",),
        grading_focus={},
    )
    output = CapturedOutput(scenario_id="fuzz", variant="with-subagents", text=text)
    score_output(scenario, output)


def main() -> None:
    """Entry point for Atheris fuzzing."""
    try:
        import atheris  # type: ignore
    except ImportError:
        print("atheris not installed; skipping fuzz harness", file=sys.stderr)
        sys.exit(0)

    atheris.Setup(sys.argv, fuzz_static_metric_input)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
