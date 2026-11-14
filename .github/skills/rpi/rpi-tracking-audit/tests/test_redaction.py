# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Credential detection: forms that are redacted and ordinary text that is not."""

from __future__ import annotations

import pytest
from rpi_tracking_audit._markdown import redact, strip_controls

GITHUB = "ghp_aB3dE6gH9jK2mN5pQ8sT1vW4yZ7bC0dF3gH6"
AWS = "AKIAIOSFODNN7EXAMPLE"


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        # coloured terminal output pasted into notes
        (f"deploy output: \x1b[32m{GITHUB}\x1b[0m", GITHUB[4:]),
        (f"\x1b[01;31m\x1b[K{AWS}\x1b[m\x1b[K", AWS[4:]),
        (f"{GITHUB[:20]}\x1b[1m{GITHUB[20:]}", GITHUB[20:]),
        # characters that take no space
        (f"{GITHUB[:20]}⁣{GITHUB[20:]}", GITHUB[20:]),
        (f"{GITHUB[:20]}️{GITHUB[20:]}", GITHUB[20:]),
        (f"{GITHUB[:20]}᠎{GITHUB[20:]}", GITHUB[20:]),
        (f"{GITHUB[:20]}͏{GITHUB[20:]}", GITHUB[20:]),
        # one control character separates the token and another splits it
        (f"key\x01{AWS[:8]}\x01{AWS[8:]}", AWS[8:]),
        (f"key\x1b[32m{AWS[:8]}\x1b[1m{AWS[8:]}\x1b[0mmore", AWS[8:]),
        # two credentials with nothing between them
        (GITHUB + GITHUB, GITHUB[4:]),
        (AWS + GITHUB, AWS[4:]),
        (AWS + GITHUB, GITHUB[4:]),
    ],
)
def test_given_token_in_terminal_or_invisible_wrapping_when_redacted_then_gone(
    text: str, secret: str
) -> None:
    # Act
    result = redact(strip_controls(text))

    # Assert
    assert secret not in result
    assert "[redacted" in result


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        ('Server=x;Password="Hunter2Hunter";', "Hunter2Hunter"),
        ('password = "S3cretPass99"', "S3cretPass99"),
        ("Password: `Hunter2Hunter2`", "Hunter2Hunter2"),
        ("**Password:** Hunter2Hunter2", "Hunter2Hunter2"),
        ("**Password**: Hunter2Hunter2", "Hunter2Hunter2"),
        ("mysql --password Hunter2Hunter2 -h db", "Hunter2Hunter2"),
        ("postgres://admin:1234567890@db/x", "1234567890"),
        ("**API key:** abcd1234efgh5678ijkl9012mnop", "abcd1234efgh5678ijkl9012mnop"),
        ("client secret: abcd1234efgh5678ijkl9012mnop", "abcd1234efgh5678ijkl9012mnop"),
        ("Server=db;Password=$Zx9Kq7Lm2Vt4;", "Zx9Kq7Lm2Vt4"),
        # a connection string used as a folder name, so a `/` follows the value
        ("research/Server=db;User Id=sa;Pwd=a1ehxrNx702oq6rd/x.md", "a1ehxrNx702oq6rd"),
    ],
)
def test_given_password_in_a_common_written_form_when_redacted_then_gone(
    text: str, secret: str
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert secret not in result


@pytest.mark.parametrize(
    "text",
    [
        "* Password: 12-character minimum",
        "* Password: FR-001,FR-002",
        "pwd: src/auth/login_v2.py",
        "pwd=~/projects/app2",
        "password=./secrets/db_password_v2.txt",
        "password=$DB_PASSWORD_1",
        "PASSWORD: ${DB_PASSWORD:-default1}",
        "Password: `$DB_PASSWORD_1`",
        "password=self.config.password2",
        "password: settings.db_password1",
        "Password: 2024-11-01T10:00:00Z rotated",
        "Password: 2024-11-01 rotated",
        "password: [see-RFC-1234](https://example.invalid/rfc)",
        "s3://bucket-name-2024-logs-archive-prod@us-east-1",
        "api key rotation: see runbook-2024-11-01-v2-final",
        "max_tokens=4096",
        "token: P01-T02",
    ],
)
def test_given_ordinary_text_after_a_password_word_when_redacted_then_unchanged(
    text: str,
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert result == text


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("\x1b[32mok\x1b[0m done", " ok  done"),
        ("a\x1b[2Kb", "a b"),
        ("x⁣y ᅟz", "xy z"),
    ],
)
def test_given_terminal_sequences_when_stripped_then_parameters_are_gone(
    text: str, expected: str
) -> None:
    # Act
    result = strip_controls(text)

    # Assert
    assert result == expected
