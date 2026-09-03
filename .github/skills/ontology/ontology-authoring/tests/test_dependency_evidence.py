# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from email.message import Message
from importlib.metadata import Distribution
from pathlib import Path

import pytest
from ontology_authoring.dependency_evidence import (
    EvidenceError,
    collect_license_inventory,
    extract_license_fields,
    read_lock_packages,
)


class StubDistribution(Distribution):
    def __init__(self, version: str, metadata: Message) -> None:
        self._version = version
        self._metadata = metadata

    @property
    def version(self) -> str:
        return self._version

    @property
    def metadata(self) -> Message:
        return self._metadata


def write_lock(path: Path, registry: str = "https://pypi.org/simple") -> None:
    path.write_text(
        f'''version = 1

[[package]]
name = "ontology-authoring-skill"
version = "0.0.0"
source = {{ virtual = "." }}
dependencies = [{{ name = "example" }}]

[[package]]
name = "example"
version = "1.2.3"
source = {{ registry = "{registry}" }}

[[package]]
name = "transitive"
version = "2.0.0"
source = {{ registry = "{registry}" }}
''',
        encoding="utf-8",
    )


def metadata_with_license(expression: str | None = "MIT") -> Message:
    metadata = Message()
    if expression:
        metadata["License-Expression"] = expression
    return metadata


def test_given_public_lock_when_read_then_direct_dependency_is_identified(tmp_path: Path) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    write_lock(lock_path)

    # Act
    packages, direct_names = read_lock_packages(lock_path)

    # Assert
    assert ([package["name"] for package in packages], direct_names) == (
        ["example", "transitive"],
        {"example"},
    )


def test_given_private_source_when_read_then_evidence_is_rejected(tmp_path: Path) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    write_lock(lock_path, "https://packages.example.test/simple")

    # Act & Assert
    with pytest.raises(EvidenceError, match="not locked to"):
        read_lock_packages(lock_path)


def test_given_installed_graph_when_collect_then_relationships_are_recorded(
    tmp_path: Path,
) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    write_lock(lock_path)
    distributions = {
        "example": StubDistribution("1.2.3", metadata_with_license()),
        "transitive": StubDistribution("2.0.0", metadata_with_license("Apache-2.0")),
    }

    # Act
    inventory = collect_license_inventory(lock_path, distributions.__getitem__)

    # Assert
    assert [(item["name"], item["relationship"]) for item in inventory] == [
        ("example", "direct"),
        ("transitive", "transitive"),
    ]


def test_given_unknown_license_when_collect_then_evidence_is_rejected(tmp_path: Path) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    write_lock(lock_path)
    distributions = {
        "example": StubDistribution("1.2.3", metadata_with_license(None)),
        "transitive": StubDistribution("2.0.0", metadata_with_license()),
    }

    # Act & Assert
    with pytest.raises(EvidenceError, match="Unknown license metadata: example"):
        collect_license_inventory(lock_path, distributions.__getitem__)


def test_given_license_classifier_when_extract_then_license_is_known() -> None:
    # Arrange
    metadata = Message()
    metadata["Classifier"] = "License :: OSI Approved :: MIT License"

    # Act
    result = extract_license_fields(metadata)

    # Assert
    assert result["status"] == "known"


def test_given_conditional_package_when_collect_then_public_metadata_is_used(
    tmp_path: Path,
) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    write_lock(lock_path)
    distributions = {"example": StubDistribution(
        "1.2.3", metadata_with_license())}

    # Act
    inventory = collect_license_inventory(
        lock_path,
        distributions.__getitem__,
        lambda _name, _version: {
            "expression": "BSD-3-Clause",
            "declared": None,
            "classifiers": [],
            "status": "known",
        },
    )

    # Assert
    assert inventory[1]["metadataSource"] == "https://pypi.org/pypi"
