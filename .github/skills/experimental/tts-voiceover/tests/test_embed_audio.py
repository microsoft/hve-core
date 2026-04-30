# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for embed_audio module."""

import wave
from pathlib import Path
from unittest.mock import MagicMock, patch

from embed_audio import (
    _add_narration_timing,
    embed_slide_audio,
    get_wav_duration_ms,
)


def _make_wav(tmp_path: Path, name: str = "test.wav", duration_ms: int = 100) -> Path:
    """Create a minimal valid WAV file."""
    sample_rate = 16000
    num_samples = int(sample_rate * duration_ms / 1000)
    path = tmp_path / name
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * num_samples)
    return path


class TestGetWavDurationMs:
    """Tests for get_wav_duration_ms."""

    def test_returns_duration_with_buffer(self, tmp_path):
        wav = _make_wav(tmp_path, duration_ms=1000)
        result = get_wav_duration_ms(wav)
        # 1000ms audio + 1500ms buffer = ~2500ms
        assert 2400 <= result <= 2600

    def test_short_file(self, tmp_path):
        wav = _make_wav(tmp_path, duration_ms=50)
        result = get_wav_duration_ms(wav)
        # 50ms audio + 500ms buffer
        assert result >= 500


class TestAddNarrationTiming:
    """Tests for _add_narration_timing."""

    def test_appends_timing_element(self):
        """Verify p:timing is added with the correct spid attribute."""
        from lxml import etree

        nsmap = {"p": "http://schemas.openxmlformats.org/presentationml/2006/main"}
        slide_xml = etree.Element(f"{{{nsmap['p']}}}sld", nsmap=nsmap)
        mock_slide = MagicMock()
        mock_slide._element = slide_xml

        _add_narration_timing(mock_slide, shape_id=42, duration_ms=5000)

        timing = slide_xml.find(
            "{http://schemas.openxmlformats.org/presentationml/2006/main}timing"
        )
        assert timing is not None

        # Verify spid references the correct shape
        xml_str = etree.tostring(timing, encoding="unicode")
        assert 'spid="42"' in xml_str
        assert 'dur="5000"' in xml_str

    def test_replaces_existing_timing(self):
        """Verify existing p:timing is removed before adding new one."""
        from lxml import etree

        ns = "http://schemas.openxmlformats.org/presentationml/2006/main"
        slide_xml = etree.Element(f"{{{ns}}}sld")
        old_timing = etree.SubElement(slide_xml, f"{{{ns}}}timing")
        etree.SubElement(old_timing, "old-content")

        mock_slide = MagicMock()
        mock_slide._element = slide_xml

        _add_narration_timing(mock_slide, shape_id=10, duration_ms=3000)

        timings = slide_xml.findall(f"{{{ns}}}timing")
        assert len(timings) == 1
        xml_str = etree.tostring(timings[0], encoding="unicode")
        assert "old-content" not in xml_str
        assert 'spid="10"' in xml_str


class TestEmbedSlideAudio:
    """Tests for embed_slide_audio."""

    def test_returns_true_on_success(self, tmp_path):
        wav = _make_wav(tmp_path)
        mock_slide = MagicMock()
        mock_shape = MagicMock()
        mock_shape.shape_id = 99
        mock_slide.shapes.add_movie.return_value = mock_shape
        mock_slide.shapes.__iter__ = MagicMock(return_value=iter([]))

        with patch("embed_audio._find_audio_shape_id", return_value=None):
            result = embed_slide_audio(mock_slide, wav)
        assert result is True

    def test_returns_false_on_exception(self, tmp_path):
        wav = _make_wav(tmp_path)
        mock_slide = MagicMock()
        mock_slide.shapes.add_movie.side_effect = RuntimeError("test error")

        result = embed_slide_audio(mock_slide, wav)
        assert result is False
