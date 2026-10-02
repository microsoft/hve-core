# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Region, credential, SSML, partial-output, and rerun tests for voice-over generation.

Synthesis runs against the fake Speech SDK from ``conftest.py``; notes are
synthetic and no network connection is permitted.
"""

from __future__ import annotations

import time
import xml.etree.ElementTree as ET

import generate_voiceover
import pytest
from conftest import (
    PLACEHOLDER_KEY,
    PLACEHOLDER_RESOURCE_ID,
    make_content_tree,
    make_token,
)

_SSML_NS = "{http://www.w3.org/2001/10/synthesis}"


def _run(tmp_path, *extra):
    args = generate_voiceover.create_parser().parse_args(
        [
            "--content-dir",
            str(tmp_path / "content"),
            "--output-dir",
            str(tmp_path / "voice-over"),
            *extra,
        ]
    )
    return generate_voiceover._run(args)


class TestRegionRequirement:
    """Synthesis requires an explicit region; dry-run does not."""

    def test_given_blank_region_when_synthesize_then_exits_2(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "   ")

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 2
        assert fake_speech.synthesis_calls == []

    def test_given_no_region_when_dry_run_then_succeeds_without_sdk(
        self, tmp_path, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])

        # Act
        exit_code = _run(tmp_path, "--dry-run")

        # Assert
        assert exit_code == 0
        assert fake_speech.configs == []

    def test_given_no_region_when_synthesize_then_exits_2_before_sdk_use(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 2
        assert fake_speech.configs == []

    def test_given_region_when_key_auth_then_fake_config_receives_region_and_key(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "westus3")

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 0
        assert [(c.region, c.subscription) for c in fake_speech.configs] == [
            ("westus3", PLACEHOLDER_KEY)
        ]


class TestCredentialPrecedence:
    """Key auth wins over Entra when both are configured (current behavior)."""

    def test_given_key_and_resource_id_when_synthesize_then_key_auth_used(
        self, tmp_path, monkeypatch, fake_speech, install_credential
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_RESOURCE_ID", PLACEHOLDER_RESOURCE_ID)
        monkeypatch.setenv("SPEECH_REGION", "westus3")
        credential = install_credential([make_token("tok-1", time.time() + 3600)])

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 0
        assert fake_speech.configs[0].subscription == PLACEHOLDER_KEY
        assert credential.scopes == []

    def test_given_no_credentials_when_synthesize_then_exits_2(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_REGION", "westus3")

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 2
        assert fake_speech.synthesis_calls == []

    def test_given_resource_id_only_when_synthesize_then_entra_token_used(
        self, tmp_path, monkeypatch, fake_speech, install_credential
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_RESOURCE_ID", PLACEHOLDER_RESOURCE_ID)
        monkeypatch.setenv("SPEECH_REGION", "westus3")
        install_credential([make_token("tok-1", time.time() + 3600)])

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 0
        assert fake_speech.configs[0].auth_token == (
            f"aad#{PLACEHOLDER_RESOURCE_ID}#tok-1"
        )

    def test_given_token_refresh_failure_when_synthesizing_then_stale_config_reused(
        self, tmp_path, monkeypatch, fake_speech, install_credential
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["First note.", "Second note."])
        monkeypatch.setenv("SPEECH_RESOURCE_ID", PLACEHOLDER_RESOURCE_ID)
        monkeypatch.setenv("SPEECH_REGION", "westus3")
        install_credential(
            [
                make_token("tok-1", time.time() + 60),
                RuntimeError("credential service unavailable"),
                RuntimeError("credential service unavailable"),
            ]
        )

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 0
        assert len(fake_speech.configs) == 1
        assert [call["config"] for call in fake_speech.synthesis_calls] == [
            fake_speech.configs[0],
            fake_speech.configs[0],
        ]


class TestSsmlSafety:
    """Hostile notes, voice, and rate values cannot inject SSML elements."""

    def test_given_hostile_values_when_synthesize_then_ssml_has_no_injected_elements(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        hostile_note = (
            'Tom & Jerry <break time="5s"/> </prosody></voice>'
            '<voice name="x"> "double" \'single\''
        )
        hostile_voice = 'en-US-Synthetic" name="injected'
        hostile_rate = '+10%"><break time="9s"/>'
        make_content_tree(tmp_path / "content", [hostile_note])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "westus3")

        # Act
        exit_code = _run(tmp_path, "--voice", hostile_voice, "--rate", hostile_rate)

        # Assert
        root = ET.fromstring(fake_speech.synthesis_calls[0]["ssml"])
        tags = [element.tag for element in root.iter()]
        voice = root.find(f"{_SSML_NS}voice")
        assert exit_code == 0
        assert tags == [f"{_SSML_NS}speak", f"{_SSML_NS}voice", f"{_SSML_NS}prosody"]
        assert voice.get("name") == hostile_voice
        assert voice.find(f"{_SSML_NS}prosody").get("rate") == hostile_rate

    def test_given_plain_note_when_synthesize_then_note_sent_unfiltered(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Plain synthetic note for egress."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "westus3")

        # Act
        _run(tmp_path)

        # Assert
        assert (
            "Plain synthetic note for egress."
            in (fake_speech.synthesis_calls[0]["ssml"])
        )


class TestPartialSynthesis:
    """Failed synthesis leaves no partial WAV; reruns regenerate every slide."""

    def test_given_cancel_after_partial_write_when_synthesize_then_wav_removed(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["Synthetic narration."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "westus3")
        fake_speech.outcomes = ["cancel-partial"]

        # Act
        exit_code = _run(tmp_path)

        # Assert
        assert exit_code == 1
        assert not (tmp_path / "voice-over" / "slide-001.wav").exists()

    def test_given_rerun_after_partial_failure_when_synthesize_then_all_regenerated(
        self, tmp_path, monkeypatch, fake_speech
    ):
        # Arrange
        make_content_tree(tmp_path / "content", ["First note.", "Second note."])
        monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
        monkeypatch.setenv("SPEECH_REGION", "westus3")
        fake_speech.outcomes = ["success", "cancel-partial"]
        first_exit_code = _run(tmp_path)
        first_call_count = len(fake_speech.synthesis_calls)

        # Act
        second_exit_code = _run(tmp_path)

        # Assert
        assert (first_exit_code, second_exit_code) == (1, 0)
        assert len(fake_speech.synthesis_calls) - first_call_count == 2


@pytest.mark.parametrize("note", [None, "", "   "])
def test_given_empty_notes_when_synthesize_then_no_synthesis_and_exit_1(
    tmp_path, monkeypatch, fake_speech, note
):
    # Arrange
    make_content_tree(tmp_path / "content", [note])
    monkeypatch.setenv("SPEECH_KEY", PLACEHOLDER_KEY)
    monkeypatch.setenv("SPEECH_REGION", "westus3")

    # Act
    exit_code = _run(tmp_path)

    # Assert
    assert exit_code == 1
    assert fake_speech.synthesis_calls == []
