from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Scenario:
    id: str
    title: str
    prompt: str
    expected_mode_without_subagents: str
    expected_mode_with_subagents: str
    required_evidence: tuple[str, ...]
    grading_focus: dict[str, str]


@dataclass(frozen=True)
class CapturedOutput:
    scenario_id: str
    variant: str
    text: str


@dataclass(frozen=True)
class StaticScore:
    coverage: int
    citation_precision: int
    actionability: int
    noise_control: int
    mode_compliance: int

    @property
    def total(self) -> int:
        return (
            self.coverage
            + self.citation_precision
            + self.actionability
            + self.noise_control
            + self.mode_compliance
        )


@dataclass(frozen=True)
class PairScore:
    scenario_id: str
    without_subagents: StaticScore
    with_subagents: StaticScore

    @property
    def delta_total(self) -> int:
        return self.with_subagents.total - self.without_subagents.total
