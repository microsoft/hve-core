# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for TTS voice-over skill modules.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
import tempfile
import xml.sax.saxutils
from contextlib import suppress
from pathlib import Path

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

from generate_voiceover import (
    _DEFAULT_ACRONYMS,
    apply_acronym_aliases,
    load_acronyms,
    wrap_ssml,
)

# ---------------------------------------------------------------------------
# Fuzz targets — pure functions exercised by both modes
# ---------------------------------------------------------------------------


def fuzz_apply_acronym_aliases(data):
    """Fuzz apply_acronym_aliases with random text and the default acronym dict."""
    if not FUZZING:
        return
    fdp = atheris.FuzzedDataProvider(data)
    raw_text = fdp.ConsumeUnicodeNoSurrogates(500)
    text = xml.sax.saxutils.escape(raw_text)
    with suppress(ValueError, TypeError):
        apply_acronym_aliases(text, dict(_DEFAULT_ACRONYMS))


def fuzz_wrap_ssml(data):
    """Fuzz wrap_ssml with random text, voice, and rate strings."""
    if not FUZZING:
        return
    fdp = atheris.FuzzedDataProvider(data)
    raw_text = fdp.ConsumeUnicodeNoSurrogates(200)
    text = xml.sax.saxutils.escape(raw_text)
    voice = fdp.ConsumeUnicodeNoSurrogates(50)
    rate = fdp.ConsumeUnicodeNoSurrogates(10)
    with suppress(ValueError, TypeError):
        wrap_ssml(text, voice, rate)


def fuzz_load_acronyms(data):
    """Fuzz load_acronyms with random YAML content written to a temp file."""
    if not FUZZING:
        return
    fdp = atheris.FuzzedDataProvider(data)
    content = fdp.ConsumeUnicodeNoSurrogates(300)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yaml", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)
    try:
        with suppress(Exception):
            load_acronyms(tmp_path)
    finally:
        tmp_path.unlink(missing_ok=True)


FUZZ_TARGETS = [
    fuzz_apply_acronym_aliases,
    fuzz_wrap_ssml,
    fuzz_load_acronyms,
]


def fuzz_dispatch(data):
    """Route Atheris input to one of the registered fuzz targets."""
    if len(data) < 2:
        return
    idx = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[idx](data[1:])


# ---------------------------------------------------------------------------
# pytest mode — property-based tests for the same targets
# ---------------------------------------------------------------------------


class TestFuzzApplyAcronymAliases:
    """Property tests for apply_acronym_aliases."""

    def test_given_known_acronym_when_applied_then_sub_element_inserted(self):
        result = apply_acronym_aliases("Check OWASP guidelines", _DEFAULT_ACRONYMS)
        assert "Oh wasp" in result
        assert "<sub" in result

    def test_given_text_without_acronyms_when_applied_then_text_unchanged(self):
        result = apply_acronym_aliases("no acronyms here", _DEFAULT_ACRONYMS)
        assert result == "no acronyms here"

    def test_given_empty_text_when_applied_then_returns_empty(self):
        result = apply_acronym_aliases("", _DEFAULT_ACRONYMS)
        assert result == ""

    def test_given_empty_acronyms_when_applied_then_text_unchanged(self):
        result = apply_acronym_aliases("OWASP test", {})
        assert result == "OWASP test"

    def test_given_multiple_acronyms_when_applied_then_all_replaced(self):
        result = apply_acronym_aliases("ISE uses MCP", _DEFAULT_ACRONYMS)
        assert "I S E" in result
        assert "M C P" in result


class TestFuzzWrapSsml:
    """Property tests for wrap_ssml."""

    def test_given_voice_name_when_wrapped_then_voice_tag_present(self):
        result = wrap_ssml("hello", "en-US-Jenny", "+5%")
        assert "en-US-Jenny" in result
        assert "<voice" in result

    def test_given_rate_when_wrapped_then_prosody_rate_present(self):
        result = wrap_ssml("hello", "en-US-Jenny", "+10%")
        assert "+10%" in result
        assert "<prosody" in result

    def test_given_text_when_wrapped_then_text_in_output(self):
        result = wrap_ssml("test content", "voice", "rate")
        assert "test content" in result

    def test_given_any_input_when_wrapped_then_speak_root_element(self):
        result = wrap_ssml("x", "v", "r")
        assert result.startswith("<speak")
        assert result.endswith("</speak>")


class TestFuzzLoadAcronyms:
    """Property tests for load_acronyms."""

    def test_given_nonexistent_file_when_loaded_then_returns_defaults(self):
        result = load_acronyms(Path("/nonexistent/acronyms.yaml"))
        assert result == _DEFAULT_ACRONYMS

    def test_given_valid_yaml_when_loaded_then_returns_custom_map(self, tmp_path):
        lexicon = tmp_path / "acronyms.yaml"
        lexicon.write_text('acronyms:\n  FOO: "bar"\n', encoding="utf-8")
        result = load_acronyms(lexicon)
        assert result == {"FOO": "bar"}

    def test_given_invalid_format_when_loaded_then_returns_defaults(self, tmp_path):
        lexicon = tmp_path / "acronyms.yaml"
        lexicon.write_text("acronyms: not-a-dict\n", encoding="utf-8")
        result = load_acronyms(lexicon)
        assert result == _DEFAULT_ACRONYMS

    def test_given_empty_file_when_loaded_then_returns_defaults(self, tmp_path):
        lexicon = tmp_path / "acronyms.yaml"
        lexicon.write_text("", encoding="utf-8")
        result = load_acronyms(lexicon)
        assert result == _DEFAULT_ACRONYMS


# ---------------------------------------------------------------------------
# Atheris entry point — only runs when executed directly with Atheris installed
# ---------------------------------------------------------------------------

if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
