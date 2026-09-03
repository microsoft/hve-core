# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for dependency authority evidence boundaries."""

from __future__ import annotations

import hashlib
import sys
import tempfile
import zipfile
from pathlib import Path

from ontology_authoring.dependency_evidence import EvidenceError, read_lock_packages
from ontology_authoring.verify_dependency_artifact import VerificationError, verify_archive

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_lock_parser(data: bytes) -> None:
    """Fuzz uv lock parsing with arbitrary TOML bytes."""
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "uv.lock"
        path.write_bytes(data)
        try:
            read_lock_packages(path)
        except (EvidenceError, UnicodeDecodeError, ValueError):
            pass


def fuzz_archive_verifier(data: bytes) -> None:
    """Fuzz artifact parsing while requiring fail-closed verification."""
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "artifact.zip"
        path.write_bytes(data)
        try:
            verify_archive(
                path,
                hashlib.sha256(data).hexdigest(),
                "microsoft/hve-core",
                "a" * 40,
            )
        except (OSError, VerificationError, zipfile.BadZipFile):
            pass


FUZZ_TARGETS = [fuzz_archive_verifier, fuzz_lock_parser]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    FUZZ_TARGETS[data[0] % len(FUZZ_TARGETS)](data[1:])


class TestDependencyEvidenceFuzzHarness:
    """Property tests mirroring fuzz-target behavior under pytest."""

    def test_given_arbitrary_lock_when_parsed_then_failure_is_bounded(self) -> None:
        for data in (b"", b"not toml", b"version = 1", b"[[package]]\nname = 1"):
            fuzz_lock_parser(data)

    def test_given_arbitrary_archive_when_verified_then_failure_is_bounded(self) -> None:
        for data in (b"", b"PK", b"not a zip", b"\x00" * 32):
            fuzz_archive_verifier(data)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
