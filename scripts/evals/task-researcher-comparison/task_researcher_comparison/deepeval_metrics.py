from __future__ import annotations

import os

import pytest
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCase, SingleTurnParams

from task_researcher_comparison.models import CapturedOutput, Scenario


class LazyGEval:
    """Wrapper for GEval that defers LLM model initialization until used."""

    def __init__(self, name: str, criteria: str, evaluation_params: list, threshold: float):
        self.name = name
        self.criteria = criteria
        self.evaluation_params = evaluation_params
        self.threshold = threshold
        self._metric = None

    def _get_metric(self) -> GEval:
        if self._metric is None:
            self._metric = GEval(
                name=self.name,
                criteria=self.criteria,
                evaluation_params=self.evaluation_params,
                threshold=self.threshold,
            )
        return self._metric

    def __getattr__(self, name: str):
        if name in ("name", "criteria", "evaluation_params", "threshold", "_metric"):
            return object.__getattribute__(self, name)
        return getattr(self._get_metric(), name)


def require_deepeval_llm_enabled() -> None:
    if os.getenv("DEEPEVAL_RUN_LLM") != "1":
        pytest.skip("Set DEEPEVAL_RUN_LLM=1 to run DeepEval LLM-judge tests.")
    if not (os.getenv("OPENAI_API_KEY") or os.getenv("AZURE_OPENAI_API_KEY") or os.getenv("ANTHROPIC_API_KEY")):
        pytest.skip("DeepEval LLM-judge tests require an LLM provider key.")


def build_comparison_test_case(
    scenario: Scenario,
    without_subagents: CapturedOutput,
    with_subagents: CapturedOutput,
) -> LLMTestCase:
    return LLMTestCase(
        input=scenario.prompt,
        actual_output=(
            "WITHOUT SUBAGENTS:\n"
            f"{without_subagents.text}\n\n"
            "WITH SUBAGENTS:\n"
            f"{with_subagents.text}"
        ),
        expected_output=(
            f"Required evidence: {', '.join(scenario.required_evidence)}\n"
            f"Expected no-subagent mode: {scenario.expected_mode_without_subagents}\n"
            f"Expected with-subagents mode: {scenario.expected_mode_with_subagents}\n"
            f"Grading focus: {scenario.grading_focus}"
        ),
    )


def build_metrics() -> list[LazyGEval | GEval]:
    params = [
        SingleTurnParams.INPUT,
        SingleTurnParams.ACTUAL_OUTPUT,
        SingleTurnParams.EXPECTED_OUTPUT,
    ]
    return [
        LazyGEval(
            name="Evidence Coverage",
            criteria="Score whether both variants cover the scenario's required evidence, and whether the with-subagents variant improves coverage when lane fan-out is expected.",
            evaluation_params=params,
            threshold=0.7,
        ),
        LazyGEval(
            name="Citation Precision",
            criteria="Score whether claims use precise workspace-relative file citations, line ranges where available, and relevant external URLs only when external research is expected.",
            evaluation_params=params,
            threshold=0.7,
        ),
        LazyGEval(
            name="Actionability",
            criteria="Score whether outputs provide a selected approach, rejected alternatives, implementation-ready next steps, and validation guidance.",
            evaluation_params=params,
            threshold=0.7,
        ),
        LazyGEval(
            name="Noise Control",
            criteria="Score whether outputs avoid unrelated codebase scanning, external tangents, and excessive detail not needed for the scenario.",
            evaluation_params=params,
            threshold=0.7,
        ),
        LazyGEval(
            name="Mode Compliance",
            criteria="Score whether the no-subagent and with-subagents variants follow their expected modes, including avoiding lane fan-out for simple local work and using applicable lanes for medium-hard or external-uncertainty cases.",
            evaluation_params=params,
            threshold=0.7,
        ),
    ]

