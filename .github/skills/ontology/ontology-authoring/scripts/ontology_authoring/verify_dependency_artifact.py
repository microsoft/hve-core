# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Verify a downloaded ontology dependency artifact before committing its lock."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
SHA256_PATTERN = re.compile(r"^(?:sha256:)?([0-9a-f]{64})$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
REQUIRED_FILES = {
    "artifact-manifest.json",
    "command-evidence.json",
    "dependency-generation-record.json",
    "dependency-license-inventory.json",
    "dependency-sbom.cdx.json",
    "dependency-tree.txt",
    "import-results.json",
    "pyproject.toml",
    "test-results.xml",
    "uv.lock",
}


class VerificationError(Exception):
    """Raised when an artifact fails provenance or integrity verification."""


def sha256_file(path: Path) -> str:
    """Return the lowercase SHA-256 digest for a file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(archive: zipfile.ZipFile, name: str) -> dict[str, Any]:
    """Read a JSON object from the artifact archive."""
    try:
        value = json.loads(archive.read(name))
    except (KeyError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise VerificationError(
            f"Invalid or missing JSON evidence: {name}") from error
    if not isinstance(value, dict):
        raise VerificationError(f"Evidence must be a JSON object: {name}")
    return value


def verify_archive(
    archive_path: Path,
    expected_digest: str,
    expected_repository: str,
    expected_source_commit: str,
    expected_workflow_run_id: str | None = None,
    expected_artifact_name: str | None = None,
) -> None:
    """Verify outer digest, provenance identity, and all inner file hashes."""
    digest_match = SHA256_PATTERN.fullmatch(expected_digest)
    if not digest_match:
        raise VerificationError(
            "expected artifact digest must be a SHA-256 value")
    if not COMMIT_PATTERN.fullmatch(expected_source_commit):
        raise VerificationError(
            "expected source commit must be a full lowercase SHA")
    if sha256_file(archive_path) != digest_match.group(1):
        raise VerificationError("outer artifact digest mismatch")

    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise VerificationError("artifact contains duplicate paths")
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name:
                raise VerificationError(
                    f"artifact contains an unsafe path: {name}")

        generation = read_json(archive, "dependency-generation-record.json")
        if generation.get("repository") != expected_repository:
            raise VerificationError("artifact repository identity mismatch")
        if generation.get("sourceCommit") != expected_source_commit:
            raise VerificationError("artifact source commit mismatch")
        if (
            expected_workflow_run_id is not None
            and generation.get("workflowRunId") != expected_workflow_run_id
        ):
            raise VerificationError("artifact workflow run identity mismatch")
        if (
            expected_artifact_name is not None
            and generation.get("artifactName") != expected_artifact_name
        ):
            raise VerificationError("artifact name mismatch")

        manifest = read_json(archive, "artifact-manifest.json")
        entries = manifest.get("files")
        if manifest.get("algorithm") != "SHA256" or not isinstance(entries, list):
            raise VerificationError("artifact manifest is malformed")
        expected_names = {"artifact-manifest.json"}
        for entry in entries:
            if not isinstance(entry, dict):
                raise VerificationError(
                    "artifact manifest contains a malformed entry")
            name = entry.get("path")
            expected_hash = entry.get("sha256")
            expected_size = entry.get("sizeBytes")
            if not isinstance(name, str) or PurePosixPath(name).name != name:
                raise VerificationError(
                    "artifact manifest path must be a root file")
            try:
                content = archive.read(name)
            except KeyError as error:
                raise VerificationError(
                    f"manifest file is missing: {name}") from error
            if len(content) != expected_size:
                raise VerificationError(f"size mismatch for {name}")
            if hashlib.sha256(content).hexdigest() != expected_hash:
                raise VerificationError(f"hash mismatch for {name}")
            expected_names.add(name)
        if set(names) != expected_names:
            raise VerificationError("artifact contains unlisted files")
        if expected_names != REQUIRED_FILES:
            missing = sorted(REQUIRED_FILES - expected_names)
            unexpected = sorted(expected_names - REQUIRED_FILES)
            raise VerificationError(
                f"artifact file set mismatch; missing={missing}, unexpected={unexpected}"
            )
        recorded_hashes = {
            "command-evidence.json": generation.get("commandEvidenceSha256"),
            "dependency-sbom.cdx.json": generation.get("sbomSha256"),
            "pyproject.toml": generation.get("pyprojectSha256"),
            "uv.lock": generation.get("lockSha256"),
        }
        for name, recorded_hash in recorded_hashes.items():
            if hashlib.sha256(archive.read(name)).hexdigest() != recorded_hash:
                raise VerificationError(
                    f"generation record hash mismatch for {name}")


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expected-digest", required=True)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--expected-source-commit", required=True)
    parser.add_argument("--expected-workflow-run-id", required=True)
    parser.add_argument("--expected-artifact-name", required=True)
    return parser


def main() -> int:
    """Run artifact verification."""
    try:
        args = create_parser().parse_args()
        verify_archive(
            args.archive,
            args.expected_digest,
            args.expected_repository,
            args.expected_source_commit,
            args.expected_workflow_run_id,
            args.expected_artifact_name,
        )
        print("Dependency artifact verification passed.")
        return EXIT_SUCCESS
    except (OSError, zipfile.BadZipFile, VerificationError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return EXIT_FAILURE
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
