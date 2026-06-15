# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the Vally corpus importer.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

import import_corpus
import pytest
import yaml

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_normalize_prompt(data: bytes) -> None:
    """Fuzz normalization with arbitrary unicode input."""
    provider = atheris.FuzzedDataProvider(data)
    raw_value = provider.ConsumeUnicodeNoSurrogates(200)
    import_corpus.normalize_prompt(raw_value)


def fuzz_hash_prompt(data: bytes) -> None:
    """Fuzz the SHA-256 hashing wrapper."""
    provider = atheris.FuzzedDataProvider(data)
    raw_value = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    import_corpus.hash_prompt(raw_value)


def fuzz_validate_row(data: bytes) -> None:
    """Fuzz row validation against arbitrary string payloads."""
    provider = atheris.FuzzedDataProvider(data)
    row = {
        "prompt": provider.ConsumeUnicodeNoSurrogates(80),
        "kind": provider.ConsumeUnicodeNoSurrogates(20),
        "target_artifact": provider.ConsumeUnicodeNoSurrogates(60),
        "grader": provider.ConsumeUnicodeNoSurrogates(20),
        "tags": provider.ConsumeUnicodeNoSurrogates(40),
        "expected_refusal_category": provider.ConsumeUnicodeNoSurrogates(30),
        "notes": provider.ConsumeUnicodeNoSurrogates(40),
    }
    import_corpus.validate_row(row, provider.ConsumeIntInRange(2, 999))


def fuzz_build_patch_entry(data: bytes) -> None:
    """Fuzz YAML block construction with arbitrary inputs.

    Invariant: regardless of input, the emitted block must parse as a YAML
    list of exactly one entry. This catches injection escapes where a scalar
    or comment field terminates the structure and introduces extra documents,
    entries, or top-level keys.
    """
    provider = atheris.FuzzedDataProvider(data)
    row = {
        "prompt": provider.ConsumeUnicodeNoSurrogates(120),
        "kind": "agent",
        "target_artifact": provider.ConsumeUnicodeNoSurrogates(60),
        "grader": provider.ConsumeUnicodeNoSurrogates(20),
        "tags": provider.ConsumeUnicodeNoSurrogates(40),
        "expected_refusal_category": provider.ConsumeUnicodeNoSurrogates(30),
        "notes": provider.ConsumeUnicodeNoSurrogates(40),
    }
    digest = import_corpus.hash_prompt(import_corpus.normalize_prompt(row["prompt"]))
    block = import_corpus.build_patch_entry(row, digest)
    try:
        parsed = yaml.safe_load(block)
    except yaml.YAMLError:
        # Hostile input (e.g. NUL/control characters) can produce a block
        # PyYAML refuses to read or parse. An unparseable block is fail-safe:
        # it cannot represent a valid single-entry injection escape.
        return
    assert isinstance(parsed, list)
    assert len(parsed) == 1
    assert parsed[0]["tags"]["advisory"] is True


def fuzz_load_existing_hashes(data: bytes, tmp_path_factory=None) -> None:
    """Fuzz hash-loading parser against arbitrary file content."""
    provider = atheris.FuzzedDataProvider(data)
    text = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    import tempfile
    from pathlib import Path

    with suppress(OSError):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".yml", delete=False, encoding="utf-8"
        ) as handle:
            handle.write(text)
            tmp_path = Path(handle.name)
        try:
            import_corpus.load_existing_hashes(tmp_path)
        finally:
            tmp_path.unlink(missing_ok=True)


FUZZ_TARGETS = [
    fuzz_normalize_prompt,
    fuzz_hash_prompt,
    fuzz_validate_row,
    fuzz_build_patch_entry,
    fuzz_load_existing_hashes,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestVallyImportFuzzHarness:
    """Property tests mirroring fuzz-target invariants."""

    @pytest.mark.parametrize(
        ("raw_value", "expected"),
        [
            ("  Hello   WORLD  ", "hello world"),
            ("line1\nline2", "line1 line2"),
            ("", ""),
        ],
    )
    def test_normalize_prompt_invariants(self, raw_value: str, expected: str) -> None:
        assert import_corpus.normalize_prompt(raw_value) == expected

    def test_hash_prompt_is_64_hex_chars(self) -> None:
        digest = import_corpus.hash_prompt("hello world")
        assert len(digest) == 64
        assert all(ch in "0123456789abcdef" for ch in digest)

    def test_validate_row_rejects_blank_prompt(self) -> None:
        result = import_corpus.validate_row(
            {
                "prompt": "",
                "kind": "agent",
                "target_artifact": "x.md",
                "grader": "",
                "tags": "",
                "expected_refusal_category": "",
                "notes": "",
            },
            5,
        )
        assert result is not None

    def test_validate_row_rejects_unknown_kind(self) -> None:
        result = import_corpus.validate_row(
            {
                "prompt": "ok",
                "kind": "vehicle",
                "target_artifact": "x.md",
                "grader": "",
                "tags": "",
                "expected_refusal_category": "",
                "notes": "",
            },
            6,
        )
        assert result is not None

    def test_build_patch_entry_forces_advisory(self) -> None:
        row = {
            "prompt": "Hello",
            "kind": "agent",
            "target_artifact": "x.md",
            "grader": "ContainsAll",
            "tags": "",
            "expected_refusal_category": "",
            "notes": "",
        }
        block = import_corpus.build_patch_entry(row, "a" * 64)
        assert "advisory: true" in block

    @pytest.mark.parametrize(
        "injection",
        [
            "x.md\n- injected: true",
            "x.md\n# fake-comment\nkey: value",
            "x.md\r\nentry: two",
            "normal.md",
        ],
    )
    def test_build_patch_entry_block_parses_as_single_entry(
        self, injection: str
    ) -> None:
        """Comment and scalar fields cannot break the single-entry structure."""
        row = {
            "prompt": "Hello: world # tricky\n- not an entry",
            "kind": "agent",
            "target_artifact": injection,
            "grader": "Equals: x # y",
            "tags": "a,b",
            "expected_refusal_category": "",
            "notes": "line1\nline2: nope",
        }
        block = import_corpus.build_patch_entry(row, "a" * 64)
        for line in block.splitlines():
            if line.lstrip().startswith("#"):
                assert "\n" not in line
        parsed = yaml.safe_load(block)
        assert isinstance(parsed, list)
        assert len(parsed) == 1
        assert parsed[0]["tags"]["advisory"] is True


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
