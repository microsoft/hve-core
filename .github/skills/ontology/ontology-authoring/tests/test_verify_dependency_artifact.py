# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

import hashlib
import json
import zipfile
from pathlib import Path

import pytest
from ontology_authoring.verify_dependency_artifact import VerificationError, verify_archive

SOURCE_COMMIT = "a" * 40
REPOSITORY = "microsoft/hve-core"
ARTIFACT_NAME = f"ontology-dependency-authority-{SOURCE_COMMIT}"
WORKFLOW_RUN_ID = "12345"


def write_archive(path: Path, *, extra_file: bool = False) -> str:
    contents = {
        "command-evidence.json": b"{}\n",
        "dependency-license-inventory.json": b"{}\n",
        "dependency-sbom.cdx.json": b"{}\n",
        "dependency-tree.txt": b"example v1\n",
        "import-results.json": b"{}\n",
        "pyproject.toml": b"[project]\nname = 'example'\n",
        "test-results.xml": b"<testsuites />\n",
        "uv.lock": b"version = 1\n",
    }
    generation = json.dumps(
        {
            "artifactName": ARTIFACT_NAME,
            "commandEvidenceSha256": hashlib.sha256(contents["command-evidence.json"]).hexdigest(),
            "lockSha256": hashlib.sha256(contents["uv.lock"]).hexdigest(),
            "pyprojectSha256": hashlib.sha256(contents["pyproject.toml"]).hexdigest(),
            "repository": REPOSITORY,
            "sbomSha256": hashlib.sha256(contents["dependency-sbom.cdx.json"]).hexdigest(),
            "sourceCommit": SOURCE_COMMIT,
            "workflowRunId": WORKFLOW_RUN_ID,
        },
        sort_keys=True,
    ).encode()
    contents["dependency-generation-record.json"] = generation
    manifest = json.dumps(
        {
            "algorithm": "SHA256",
            "files": [
                {
                    "path": name,
                    "sha256": hashlib.sha256(content).hexdigest(),
                    "sizeBytes": len(content),
                }
                for name, content in sorted(contents.items())
            ],
        },
        sort_keys=True,
    ).encode()
    with zipfile.ZipFile(path, "w") as archive:
        for name, content in contents.items():
            archive.writestr(name, content)
        archive.writestr("artifact-manifest.json", manifest)
        if extra_file:
            archive.writestr("unlisted.txt", b"unexpected")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_given_valid_archive_when_verify_then_all_integrity_checks_pass(tmp_path: Path) -> None:
    # Arrange
    archive_path = tmp_path / "artifact.zip"
    digest = write_archive(archive_path)

    # Act
    verify_archive(
        archive_path,
        f"sha256:{digest}",
        REPOSITORY,
        SOURCE_COMMIT,
        WORKFLOW_RUN_ID,
        ARTIFACT_NAME,
    )

    # Assert
    assert archive_path.is_file()


def test_given_wrong_outer_digest_when_verify_then_archive_is_rejected(tmp_path: Path) -> None:
    # Arrange
    archive_path = tmp_path / "artifact.zip"
    write_archive(archive_path)

    # Act & Assert
    with pytest.raises(VerificationError, match="outer artifact digest mismatch"):
        verify_archive(archive_path, "0" * 64, REPOSITORY, SOURCE_COMMIT)


def test_given_unlisted_file_when_verify_then_archive_is_rejected(tmp_path: Path) -> None:
    # Arrange
    archive_path = tmp_path / "artifact.zip"
    digest = write_archive(archive_path, extra_file=True)

    # Act & Assert
    with pytest.raises(VerificationError, match="unlisted files"):
        verify_archive(archive_path, digest, REPOSITORY, SOURCE_COMMIT)
