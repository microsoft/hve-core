# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator
from ontology_authoring.runtime_provisioning import (
    ProvisioningError,
    build_export_command,
    build_pip_sync_command,
    build_sync_command,
    classify_restore,
    default_environment_path,
    environment_python_path,
    parse_uv_version,
    redact_configured_indexes,
    validate_python_version,
    verify_public_lock,
)


def test_given_runtime_sync_when_build_command_then_non_runtime_groups_are_excluded() -> None:
    # Arrange
    project_root = Path("/skill")

    # Act
    command = build_sync_command("uv", project_root)

    # Assert
    assert command == [
        "uv",
        "sync",
        "--project",
        "/skill",
        "--frozen",
        "--no-dev",
        "--no-group",
        "fuzz",
        "--no-install-project",
    ]


def test_given_configured_index_when_build_commands_then_hashes_and_wheels_are_required() -> None:
    # Arrange
    project_root = Path("/skill")
    runtime_python = Path("/runtime/bin/python")
    requirements_path = Path("/tmp/runtime-requirements.txt")

    # Act
    export_command = build_export_command("uv", project_root, requirements_path)
    sync_command = build_pip_sync_command("uv", runtime_python, requirements_path)

    # Assert
    assert export_command[1:] == [
        "export",
        "--project",
        "/skill",
        "--frozen",
        "--no-dev",
        "--no-group",
        "fuzz",
        "--no-emit-project",
        "--format",
        "requirements.txt",
        "--output-file",
        "/tmp/runtime-requirements.txt",
    ]
    assert sync_command[1:] == [
        "pip",
        "sync",
        "--python",
        "/runtime/bin/python",
        "--require-hashes",
        "--strict",
        "--only-binary",
        ":all:",
        "/tmp/runtime-requirements.txt",
    ]


@pytest.mark.parametrize("version_info", [(3, 10), (3, 12)])
def test_given_unsupported_python_when_validate_then_actionable_error_is_raised(
    version_info: tuple[int, int],
) -> None:
    # Act & Assert
    with pytest.raises(ProvisioningError, match="Python 3.11 is required"):
        validate_python_version(version_info)


def test_given_wrong_uv_when_parse_version_then_actionable_error_is_raised() -> None:
    # Act & Assert
    with pytest.raises(ProvisioningError, match="uv 0.10.8 is required; found 0.10.7"):
        parse_uv_version("uv 0.10.7")


def test_given_index_environment_when_classify_then_endpoint_values_are_not_returned(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Arrange
    monkeypatch.setenv("UV_DEFAULT_INDEX", "https://private.example.invalid/simple")

    # Act
    result = classify_restore()

    # Assert
    assert result == "environment-configured-index"


def test_given_command_error_when_redact_then_configured_index_is_removed() -> None:
    # Arrange
    index = "https://private.example.invalid/simple"

    # Act
    result = redact_configured_indexes(
        f"Failed to fetch {index}/package.whl",
        {"UV_DEFAULT_INDEX": index},
    )

    # Assert
    assert result == "Failed to fetch <configured-index>/package.whl"


@pytest.mark.parametrize(
    ("system", "suffix"),
    [
        ("Linux", "bin/python"),
        ("Darwin", "bin/python"),
        ("Windows", "Scripts/python.exe"),
    ],
)
def test_given_host_when_resolve_environment_python_then_platform_path_is_used(
    system: str,
    suffix: str,
) -> None:
    # Act
    result = environment_python_path(Path("runtime"), system)

    # Assert
    assert result.as_posix().endswith(suffix)


@pytest.mark.parametrize("system", ["Linux", "Darwin", "Windows"])
def test_given_host_when_default_environment_then_lock_digest_keys_cache(
    monkeypatch: pytest.MonkeyPatch,
    system: str,
) -> None:
    # Arrange
    monkeypatch.delenv("XDG_CACHE_HOME", raising=False)
    monkeypatch.delenv("LOCALAPPDATA", raising=False)

    # Act
    result = default_environment_path("a" * 64, system)

    # Assert
    assert result.parts[-3:] == ("hve-core", "ontology-authoring", "a" * 16)


def test_given_private_registry_when_verify_lock_then_lock_is_rejected(tmp_path: Path) -> None:
    # Arrange
    lock_path = tmp_path / "uv.lock"
    lock_path.write_text(
        'version = 1\nrequires-python = "==3.11.*"\n'
        '[[package]]\nname = "unsafe"\nversion = "1.0.0"\n'
        'source = { registry = "https://private.example.invalid/simple" }\n',
        encoding="utf-8",
    )

    # Act & Assert
    with pytest.raises(ProvisioningError, match="is not locked to https://pypi.org/simple"):
        verify_public_lock(lock_path)


def test_given_successful_evidence_when_validate_then_schema_accepts_record() -> None:
    # Arrange
    schema_path = (
        Path(__file__).parents[1]
        / "assets"
        / "schemas"
        / "runtime-provisioning-evidence.schema.json"
    )
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    evidence = {
        "schemaVersion": "1.0",
        "createdAt": "2026-09-04T12:00:00+00:00",
        "status": "passed",
        "environmentClass": "external-lock-keyed-cache",
        "lockSha256": "a" * 64,
        "networkVerification": "socket-connect-denied-during-imports",
        "packages": {
            "jsonschema": "4.25.1",
            "pyshacl": "0.40.1",
            "rdflib": "7.6.0",
        },
        "restoreClass": "canonical-public-index",
        "target": {
            "architecture": "x86_64",
            "operatingSystem": "Linux",
            "pythonAbi": "cpython-311-x86_64-linux-gnu",
            "pythonImplementation": "CPython",
            "pythonVersion": "3.11.16",
            "uvVersion": "0.10.8",
        },
    }

    # Act
    errors = list(Draft202012Validator(schema).iter_errors(evidence))

    # Assert
    assert errors == []
