from __future__ import annotations

import re

from task_researcher_comparison.models import CapturedOutput, PairScore, Scenario, StaticScore

PATH_WITH_LINE_RE = re.compile(r"(?:^|\s)(?:\.github|evals|scripts|docs|README\.md)[^\s:]*:\d+(?:-\d+)?")
URL_RE = re.compile(r"https?://[^\s)]+")


def _score_coverage(scenario: Scenario, output: CapturedOutput) -> int:
    matches = sum(1 for evidence in scenario.required_evidence if evidence in output.text)
    if matches == len(scenario.required_evidence):
        return 2
    if matches > 0:
        return 1
    return 0


def _score_citation_precision(output: CapturedOutput) -> int:
    has_file_line = bool(PATH_WITH_LINE_RE.search(output.text))
    has_url = bool(URL_RE.search(output.text))
    if has_file_line and ("external" not in output.scenario_id or has_url):
        return 2
    if has_file_line or has_url:
        return 1
    return 0


def _score_actionability(output: CapturedOutput) -> int:
    text = output.text.lower()
    signals = ["recommendation", "recommended", "next step", "validation", "approach"]
    count = sum(1 for signal in signals if signal in text)
    if count >= 3:
        return 2
    if count >= 1:
        return 1
    return 0


def _score_noise_control(output: CapturedOutput) -> int:
    text = output.text.lower()
    unrelated_signals = ["unrelated", "speculative tangent", "broad repository scan", "not relevant"]
    if any(signal in text for signal in unrelated_signals):
        return 0
    if len(output.text.split()) > 1200:
        return 1
    return 2


def _score_mode_compliance(scenario: Scenario, output: CapturedOutput) -> int:
    text = output.text.lower()
    has_lane_markers = all(signal in text for signal in ["locator lane", "analyzer lane", "pattern finder lane"])
    has_external = "far quality note" in text or "external evidence" in text
    if output.variant == "with-subagents":
        if scenario.id == "focused-local":
            return 1 if has_lane_markers else 2
        if scenario.id == "external-api":
            return 2 if has_lane_markers and has_external else 1
        return 2 if has_lane_markers else 1
    if scenario.id == "focused-local" and not has_lane_markers:
        return 2
    return 1 if has_lane_markers else 2


def score_output(scenario: Scenario, output: CapturedOutput) -> StaticScore:
    return StaticScore(
        coverage=_score_coverage(scenario, output),
        citation_precision=_score_citation_precision(output),
        actionability=_score_actionability(output),
        noise_control=_score_noise_control(output),
        mode_compliance=_score_mode_compliance(scenario, output),
    )


def score_pair(scenario: Scenario, without_subagents: CapturedOutput, with_subagents: CapturedOutput) -> PairScore:
    return PairScore(
        scenario_id=scenario.id,
        without_subagents=score_output(scenario, without_subagents),
        with_subagents=score_output(scenario, with_subagents),
    )
