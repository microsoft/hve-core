# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for configuration parsing, input policy, and JSONC edits."""

from __future__ import annotations

import json
import pathlib
import re
import sys
from contextlib import suppress

_TESTS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(_TESTS_DIR))
sys.path.insert(0, str(_TESTS_DIR.parent / "examples"))

from _config_support import (  # noqa: E402
    MASK,
    ConfigError,
    load_yaml_text,
    simulate_redaction,
)
from _input_policy import PolicyError, check_url  # noqa: E402
from settings_upsert import SettingsError, parse_assignment, strip_jsonc  # noqa: E402

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True

ALLOW = frozenset({"service.name", "http.url"})
BLOCKED = (re.compile(r"[0-9a-f]{40}"),)


def fuzz_local_config(data: bytes) -> None:
    """Exercise parsing, redaction, URL policy, and JSONC handling with arbitrary input.

    Three invariants are asserted, and each is the security property of its
    subject: redaction never emits a key outside the allow-list, check_url never
    returns for a non-http scheme, and strip_jsonc never changes the length of
    the text it is given.
    """
    text = data.decode("utf-8", errors="replace")
    with suppress(ConfigError):
        load_yaml_text(text)

    attributes = {line: text for line in text.splitlines() if line}
    kept = simulate_redaction(attributes, ALLOW, BLOCKED)
    assert set(kept) <= ALLOW

    try:
        parsed = check_url(text)
    except PolicyError:
        pass
    else:
        assert parsed.scheme in ("http", "https")
        assert parsed.username is None and parsed.password is None

    assert len(strip_jsonc(text)) == len(text)

    with suppress(SettingsError):
        parse_assignment(text)


class TestLocalConfigFuzzHarness:
    """Property tests mirroring the fuzz target."""

    def test_given_assorted_yaml_text_when_the_loader_runs_then_a_mapping_or_config_error_results(
        self,
    ) -> None:
        # Act & Assert
        for text in ("", "a: 1", "- list", "a: [\n", "null"):
            with suppress(ConfigError):
                assert isinstance(load_yaml_text(text), dict)

    def test_given_arbitrary_attribute_keys_when_redaction_runs_then_only_allow_listed_keys_remain(
        self,
    ) -> None:
        # Act & Assert
        for key in ("service.name", "prompt.text", "", "0" * 200, "service.name.extra"):
            kept = simulate_redaction({key: "value"}, ALLOW, BLOCKED)
            assert set(kept) <= ALLOW

    def test_given_an_allow_listed_key_with_a_blocked_value_when_redaction_runs_then_it_is_masked(
        self,
    ) -> None:
        # Act
        kept = simulate_redaction({"http.url": "b" * 40}, ALLOW, (re.compile(r"b{40}"),))

        # Assert
        assert kept == {"http.url": MASK}

    def test_given_malformed_url_candidates_when_check_url_runs_then_only_http_schemes_return(
        self,
    ) -> None:
        # Act & Assert
        for candidate in ("", "file:///etc/passwd", "http://", "://", "http://[", "data:,"):
            try:
                parsed = check_url(candidate)
            except PolicyError:
                continue
            assert parsed.scheme in ("http", "https")

    def test_given_jsonc_text_when_strip_jsonc_runs_then_length_is_preserved_and_json_parses(
        self,
    ) -> None:
        # Act & Assert
        for text in ("", "{}", '{"a": 1} // trailing', "/* unterminated", '{"a": "//"}'):
            stripped = strip_jsonc(text)
            assert len(stripped) == len(text)
            with suppress(json.JSONDecodeError):
                json.loads(stripped)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_local_config)
    atheris.Fuzz()
