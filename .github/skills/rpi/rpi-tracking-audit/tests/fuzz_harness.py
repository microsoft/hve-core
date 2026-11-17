# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the RPI tracking audit parsers.

Runs as a pytest test when Atheris is not installed: the property tests below run,
and every seed in tests/corpus/ is replayed through its target.
Runs as an Atheris coverage-guided fuzz target when executed directly.
The first byte of each file in tests/corpus/ selects the target: 0 models,
1 vocabulary, 2 state loading and redaction, 3 paths and tables.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from rpi_tracking_audit._discovery import classify_file, state_defect
from rpi_tracking_audit._markdown import (
    MAX_NESTING,
    Doc,
    md_escape,
    nesting_depth,
    redact,
    redact_obj,
    table_blocks,
    vocab_match,
)
from rpi_tracking_audit._models import (
    model_changes,
    model_critique,
    model_legacy,
    model_plan,
    model_research,
    model_review,
)
from rpi_tracking_audit._rules import OUTCOMES, PLAN_READINESS, VERDICTS

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True

MODELS = (
    model_plan,
    model_critique,
    model_changes,
    model_review,
    model_research,
    model_legacy,
)


def parse_all_models(text: str) -> None:
    """Parse one Markdown text as every artifact kind."""
    redacted = redact(text)
    for model in MODELS:
        art = SimpleNamespace(doc=Doc(redacted), model={}, text=redacted, raw_text=text)
        model(art)


def check_models(text: str) -> None:
    """Every artifact model parses any text without raising."""
    parse_all_models(text)


def check_vocab(text: str) -> None:
    """Vocabulary matching returns an entry or None, with and without path stripping."""
    for vocabulary, strip in (
        (PLAN_READINESS, False),
        (OUTCOMES, False),
        (VERDICTS, True),
    ):
        assert vocab_match(text, vocabulary, strip_paths=strip) in (None, *vocabulary)


def check_state(text: str) -> None:
    """State loading and redaction accept any text and keep no deep or raw value."""
    redact(text)
    state, defect = state_defect(text)
    assert (state is None) != (defect is None)
    if state is not None:
        assert nesting_depth(state) <= MAX_NESTING
    try:
        value = json.loads(text)
    except (ValueError, RecursionError):
        return
    assert nesting_depth(redact_obj(value)) <= MAX_NESTING + 1


def check_paths_and_tables(text: str) -> None:
    """Paths and pipe tables accept any text; an escaped cell stays one cell."""
    classify_file(text.replace("\\", "/").lstrip("/") or "x")
    table_blocks(text)
    escaped = md_escape(text)
    assert "\n" not in escaped and "\r" not in escaped
    assert "|" not in escaped.replace("\\|", "")


CHECKS = [check_models, check_vocab, check_state, check_paths_and_tables]
CORPUS = sorted((Path(__file__).resolve().parent / "corpus").iterdir())


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one check; the first byte selects it."""
    if len(data) < 2:
        return
    provider = atheris.FuzzedDataProvider(data[1:])
    CHECKS[data[0] % len(CHECKS)](
        provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    )


class TestRpiTrackingAuditFuzzHarness:
    """Property tests mirroring the fuzz targets (run under pytest)."""

    @pytest.mark.parametrize("seed", CORPUS, ids=lambda p: p.name)
    def test_given_corpus_seed_when_replayed_then_its_check_holds(
        self, seed: Path
    ) -> None:
        # Arrange
        data = seed.read_bytes()
        text = data[1:].decode("utf-8", errors="replace")

        # Act and assert: an empty seed selects nothing, as in fuzz_dispatch
        if len(data) >= 2:
            CHECKS[data[0] % len(CHECKS)](text)

    @pytest.mark.parametrize(
        "text",
        [
            "",
            "#",
            "<!-- rpi:task id=P01-T01 -->",
            "## Phase Checklist\n#### [x] P01-T01\n| a |\n|---|\n",
            "## Parent Decision Record\n| RD-001 | RV-001 |\n|-|-|\n| RD-001 | RV-001 "
            "| x |",
            "```\n## Findings\n",
            "<!--\n## Findings\n",
            "````md\n```\n## Findings\n",
        ],
    )
    def test_given_malformed_markdown_when_modeled_then_no_error(
        self, text: str
    ) -> None:
        check_models(text)

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            ("", None),
            ("Ready", "Ready"),
            ("No Ready", None),
            ("{{x}}", None),
            ("Not Ready", None),
        ],
    )
    def test_given_value_when_vocab_matched_then_entry_or_none(
        self, value: str, expected: str | None
    ) -> None:
        assert vocab_match(value, ("Ready", "Blocked")) == expected
        check_vocab(value)

    @pytest.mark.parametrize(
        "text",
        [
            "[]",
            '{"token": "xxxxxxxxx"}',
            '{"task_slug": "a", "active_phase": null, "artifact_paths": {}}',
            '{"task_slug": "a", "active_phase": null, "artifact_paths": '
            + "[" * 200
            + "]" * 200
            + "}",
            "[" * 100_000,
            "NaN",
        ],
    )
    def test_given_json_text_when_loaded_as_state_then_no_error(
        self, text: str
    ) -> None:
        check_state(text)

    def test_given_credential_key_when_redacted_then_value_is_replaced(self) -> None:
        assert redact_obj({"token": "x" * 9}) == {"token": "[redacted value of token]"}

    @pytest.mark.parametrize("rel", ["x", "plans", "a|b\\|c\r\n", "reviews/logs/x.md"])
    def test_given_any_path_when_classified_and_escaped_then_no_error(
        self, rel: str
    ) -> None:
        check_paths_and_tables(rel)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
