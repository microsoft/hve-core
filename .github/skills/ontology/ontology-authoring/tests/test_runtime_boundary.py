# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

import tomllib
from pathlib import Path


def test_given_skill_manifest_when_read_then_runtime_dependencies_are_isolated() -> None:
    # Arrange
    project_path = Path(__file__).parents[1] / "pyproject.toml"

    # Act
    project = tomllib.loads(project_path.read_text(encoding="utf-8"))

    # Assert
    assert project["project"]["dependencies"] == [
        "jsonschema==4.25.1",
        "pyshacl==0.40.1",
        "rdflib==7.6.0",
    ]
    assert project["dependency-groups"]["fuzz"] == ["atheris>=3.0"]
    assert "pytest>=9.0" in project["dependency-groups"]["dev"]
