# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for embed_audio module."""

import wave
from pathlib import Path
from unittest.mock import MagicMock

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

    def test_given_1s_wav_when_get_duration_then_includes_buffer(self, tmp_path):
        # Arrange
        wav = _make_wav(tmp_path, duration_ms=1000)

        # Act
        result = get_wav_duration_ms(wav)

        # Assert — 1000ms audio + 1500ms buffer = ~2500ms
        assert 2400 <= result <= 2600

    def test_given_short_wav_when_get_duration_then_includes_buffer(self, tmp_path):
        # Arrange
        wav = _make_wav(tmp_path, duration_ms=50)

        # Act
        result = get_wav_duration_ms(wav)

        # Assert — 50ms audio + 1500ms buffer = ~1550ms
        assert result >= 1500


class TestAddNarrationTiming:
    """Tests for _add_narration_timing."""

    def test_given_slide_xml_when_add_timing_then_timing_element_appended(self):
        """Verify p:timing is added with the correct spid attribute."""
        from lxml import etree

        # Arrange
        nsmap = {"p": "http://schemas.openxmlformats.org/presentationml/2006/main"}
        slide_xml = etree.Element(f"{{{nsmap['p']}}}sld", nsmap=nsmap)
        mock_slide = MagicMock()
        mock_slide._element = slide_xml

        # Act
        _add_narration_timing(mock_slide, shape_id=42, duration_ms=5000)

        # Assert
        timing = slide_xml.find(
            "{http://schemas.openxmlformats.org/presentationml/2006/main}timing"
        )
        assert timing is not None
        xml_str = etree.tostring(timing, encoding="unicode")
        assert 'spid="42"' in xml_str
        assert 'dur="5000"' in xml_str

    def test_given_existing_timing_when_add_timing_then_old_replaced(self):
        """Verify existing p:timing is removed before adding new one."""
        from lxml import etree

        # Arrange
        ns = "http://schemas.openxmlformats.org/presentationml/2006/main"
        slide_xml = etree.Element(f"{{{ns}}}sld")
        old_timing = etree.SubElement(slide_xml, f"{{{ns}}}timing")
        etree.SubElement(old_timing, "old-content")
        mock_slide = MagicMock()
        mock_slide._element = slide_xml

        # Act
        _add_narration_timing(mock_slide, shape_id=10, duration_ms=3000)

        # Assert
        timings = slide_xml.findall(f"{{{ns}}}timing")
        assert len(timings) == 1
        xml_str = etree.tostring(timings[0], encoding="unicode")
        assert "old-content" not in xml_str
        assert 'spid="10"' in xml_str

    def test_timing_template_parsed_with_hardened_parser_blocks_entity_expansion(self):
        """Verify _add_narration_timing uses a hardened parser that blocks XXE.

        Calls etree.fromstring directly with a DOCTYPE + entity reference and
        confirms lxml raises XMLSyntaxError rather than resolving the entity.
        This is the same defence applied to _TIMING_TEMPLATE via the
        XMLParser(resolve_entities=False, no_network=True) added in the fix.
        """
        from lxml import etree

        xxe_payload = (
            b'<?xml version="1.0"?>'
            b'<!DOCTYPE root [<!ENTITY xxe "injected">]>'
            b"<root>&xxe;</root>"
        )
        parser = etree.XMLParser(resolve_entities=False, no_network=True)
        # With resolve_entities=False lxml leaves &xxe; as an unresolved reference;
        # accessing .text then raises etree.XMLSyntaxError on serialisation, OR
        # tostring emits the unexpanded entity.  Either way the value "injected"
        # must not reach the output.
        root = etree.fromstring(xxe_payload, parser)
        serialised = etree.tostring(root, encoding="unicode")
        assert "injected" not in serialised

    def test_add_narration_timing_uses_hardened_xml_parser(self, mocker):
        """_add_narration_timing must pass a hardened XMLParser to etree.fromstring."""
        from lxml import etree

        original_fromstring = etree.fromstring

        captured: list = []

        def capturing_fromstring(text, parser=None, *args, **kwargs):
            captured.append(parser)
            return original_fromstring(text, parser, *args, **kwargs)

        mocker.patch("embed_audio.etree.fromstring",
                     side_effect=capturing_fromstring)
        mock_slide = MagicMock()
        mock_slide.element.find.return_value = None

        ns = "http://schemas.openxmlformats.org/presentationml/2006/main"
        mock_slide._element = etree.Element(f"{{{ns}}}sld")

        _add_narration_timing(mock_slide, shape_id=1, duration_ms=1000)

        assert captured, "etree.fromstring was never called"
        parser = captured[0]
        assert parser is not None, (
            "_add_narration_timing must pass a parser to etree.fromstring"
        )
        # lxml.etree.XMLParser does not expose resolve_entities as a readable
        # attribute, so verify the security property behaviourally: a parser
        # with resolve_entities=False must not expand entity references.
        xxe_probe = (
            b'<?xml version="1.0"?>'
            b'<!DOCTYPE root [<!ENTITY probe "expanded">]>'
            b"<root>&probe;</root>"
        )
        probe_root = etree.fromstring(xxe_probe, parser)
        assert "expanded" not in etree.tostring(probe_root, encoding="unicode"), (
            "parser must have resolve_entities=False"
        )


class TestEmbedSlideAudio:
    """Tests for embed_slide_audio."""

    def test_given_valid_slide_when_embed_then_returns_true(self, tmp_path, mocker):
        # Arrange
        wav = _make_wav(tmp_path)
        mock_slide = MagicMock()
        mock_shape = MagicMock()
        mock_shape.shape_id = 42
        mock_slide.shapes.add_movie.return_value = mock_shape
        mocker.patch("embed_audio._add_narration_timing")
        mocker.patch("embed_audio._set_slide_transition")

        # Act
        result = embed_slide_audio(mock_slide, wav)

        # Assert
        assert result is True

    def test_given_no_shape_id_when_embed_then_returns_false(self, tmp_path, mocker):
        # Arrange
        wav = _make_wav(tmp_path)
        mock_slide = MagicMock()
        mock_shape = MagicMock()
        mock_shape.shape_id = None
        mock_slide.shapes.add_movie.return_value = mock_shape

        # Act
        result = embed_slide_audio(mock_slide, wav)

        # Assert
        assert result is False

    def test_given_exception_when_embed_audio_then_returns_false(self, tmp_path):
        # Arrange
        wav = _make_wav(tmp_path)
        mock_slide = MagicMock()
        mock_slide.shapes.add_movie.side_effect = RuntimeError("test error")

        # Act
        result = embed_slide_audio(mock_slide, wav)

        # Assert
        assert result is False
