# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Lexical heuristics that approximate the manual rubric over synthetic fixtures.

These checks score keyword and structure presence, not semantic quality. They
exist as fast, deterministic regression signals for the committed fixtures and
are not authoritative quality measures. Use the manual rubric in README.md or
the DeepEval LLM judge for grading decisions.
"""
from __future__ import annotations

import re

from task_researcher_comparison.models import CapturedOutput, PairScore, Scenario, StaticScore

PATH_WITH_LINE_RE = re.compile(r"(?:^|\s)(?:\.github|evals|scripts|docs|README\.md)[^\s:]*:\d+(?:-\d+)?")
URL_RE = re.compile(r"https?://[^\s)]+")
LOCAL_LANE_MARKERS = (
    "codebase locator",
    "codebase analyzer",
    "codebase pattern finder",
)
WEB_LANE_MARKER = "web search researcher"


def _score_coverage(scenario: Scenario, output: CapturedOutput) -> int:
    """Heuristic: exact-substring presence of each required evidence string."""
    matches = sum(1 for evidence in scenario.required_evidence if evidence in output.text)
    if matches == len(scenario.required_evidence):
        return 2
    if matches > 0:
        return 1
    return 0


def _score_citation_precision(output: CapturedOutput) -> int:
    """Heuristic: presence of a file:line citation and, for external scenarios, a URL."""
    has_file_line = bool(PATH_WITH_LINE_RE.search(output.text))
    has_url = bool(URL_RE.search(output.text))
    if has_file_line and ("external" not in output.scenario_id or has_url):
        return 2
    if has_file_line or has_url:
        return 1
    return 0


def _score_actionability_signal(output: CapturedOutput) -> int:
    """Lexical signal only: counts actionability keywords. Keyword presence does
    not guarantee a genuine recommendation, so treat this as a proxy."""
    text = output.text.lower()
    signals = ["recommendation", "recommended", "next step", "validation", "approach"]
    count = sum(1 for signal in signals if signal in text)
    if count >= 3:
        return 2
    if count >= 1:
        return 1
    return 0


def _score_noise_control_proxy(output: CapturedOutput) -> int:
    """Proxy only: penalizes on output length. Phrases documenting intentional
    exclusions (e.g. "unrelated", "not relevant") are noise-control evidence,
    not noise, so this does not inspect content."""
    if len(output.text.split()) > 1200:
        return 1
    return 2


def _score_mode_compliance(scenario: Scenario, output: CapturedOutput) -> int:
    """Heuristic: keys off named-lane marker presence per known scenario id."""
    text = output.text.lower()
    has_any_lane_marker = any(signal in text for signal in (*LOCAL_LANE_MARKERS, WEB_LANE_MARKER))
    has_local_lane_markers = all(signal in text for signal in LOCAL_LANE_MARKERS)
    has_web_lane_marker = WEB_LANE_MARKER in text
    has_external = "far quality note" in text or "external evidence" in text
    if output.variant == "with-subagents":
        if scenario.id == "focused-local":
            return 1 if has_any_lane_marker else 2
        if scenario.id == "external-api":
            return 2 if has_local_lane_markers and has_web_lane_marker and has_external else 1
        return 2 if has_local_lane_markers and not has_web_lane_marker else 1
    if scenario.id == "focused-local" and not has_any_lane_marker:
        return 2
    return 1 if has_any_lane_marker else 2


def score_output(scenario: Scenario, output: CapturedOutput) -> StaticScore:
    return StaticScore(
        coverage=_score_coverage(scenario, output),
        citation_precision=_score_citation_precision(output),
        actionability=_score_actionability_signal(output),
        noise_control=_score_noise_control_proxy(output),
        mode_compliance=_score_mode_compliance(scenario, output),
    )


def score_pair(scenario: Scenario, without_subagents: CapturedOutput, with_subagents: CapturedOutput) -> PairScore:
    return PairScore(
        scenario_id=scenario.id,
        without_subagents=score_output(scenario, without_subagents),
        with_subagents=score_output(scenario, with_subagents),
    )
