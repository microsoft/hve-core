# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Behavior tests for the deterministic accessibility validation manifest."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path

import pytest

from runtime_a11y._errors import ScriptError
from runtime_a11y.validation_manifest import (
    build_schema_validation_report,
    build_validation_manifest,
    manifest_is_current,
    validate_public_claim_posture,
    validate_retained_document,
    verify_validation_manifest,
)

_DIGEST = "a" * 64
_OTHER = "b" * 64
_REVISION = "c" * 40


def _inputs() -> dict:
    return {
        "revision": {
            "sourceRevision": _REVISION,
            "diffDigest": _DIGEST,
            "tracked": True,
        },
        "environment": {
            "operatingSystem": "Windows test image",
            "toolVersions": {"node": "24.19.0", "python": "3.11.9"},
        },
        "commands": [
            {
                "commandId": "runtime-contracts",
                "command": "npm run test:a11y:contracts",
                "workingDirectory": ".",
                "status": "passed",
                "resultArtifactDigest": _DIGEST,
            },
            {
                "commandId": "python-composer",
                "command": "uv run pytest tests/runtime_a11y -q",
                "workingDirectory": "skill-root",
                "status": "passed",
                "resultArtifactDigest": _OTHER,
            },
        ],
        "generated_inventory": [{"path": "docs/slides/deck.html", "sha256": _DIGEST}],
        "untracked_deliverables": [{"path": "artifacts/report.json", "sha256": _OTHER}],
        "assistive_technology_sample": {
            "advisory": True,
            "journeys": ["screen-reader-integrity"],
            "boundary": "One prepared host; advisory and never a conformance claim",
        },
    }


def test_given_reordered_inputs_when_built_then_bytes_match() -> None:
    forward = build_validation_manifest(**_inputs())

    shuffled = _inputs()
    shuffled["commands"].reverse()
    shuffled["environment"]["toolVersions"] = {"python": "3.11.9", "node": "24.19.0"}
    reversed_order = build_validation_manifest(**shuffled)

    assert forward == reversed_order


def test_given_built_manifest_when_verified_then_digest_covers_content() -> None:
    manifest = build_validation_manifest(**_inputs())

    verify_validation_manifest(manifest)

    # The digest must not cover itself, and must cover everything else.
    assert "manifestDigest" in manifest
    tampered = deepcopy(manifest)
    tampered["revision"]["sourceRevision"] = "d" * 40
    with pytest.raises(ScriptError, match="digest mismatch"):
        verify_validation_manifest(tampered)


def test_given_manifest_without_timestamps_then_none_are_recorded() -> None:
    # Timestamps would make the manifest irreproducible from the same bytes.
    manifest = build_validation_manifest(**_inputs())

    serialized = str(manifest)
    assert "composedAt" not in serialized
    assert "generatedAt" not in serialized


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda data: data.__setitem__("commands", []), "at least one command"),
        (
            lambda data: data["commands"].append(deepcopy(data["commands"][0])),
            "Duplicate validation command identity",
        ),
        (
            lambda data: data["generated_inventory"].append(
                deepcopy(data["generated_inventory"][0])
            ),
            "Duplicate generated inventory path",
        ),
        (
            lambda data: data["untracked_deliverables"].append(
                deepcopy(data["untracked_deliverables"][0])
            ),
            "Duplicate untracked deliverable path",
        ),
    ],
)
def test_given_invalid_inputs_when_built_then_fails_closed(mutate, message) -> None:
    data = _inputs()
    mutate(data)

    with pytest.raises(ScriptError, match=message):
        build_validation_manifest(**data)


def test_given_failed_command_when_checked_then_manifest_is_not_current() -> None:
    data = _inputs()
    data["commands"][0]["status"] = "failed"
    manifest = build_validation_manifest(**data)

    # A manifest that records a failure cannot support a completed PASS claim.
    assert _is_current(manifest) is False


def test_given_other_revision_when_checked_then_manifest_is_not_current() -> None:
    manifest = build_validation_manifest(**_inputs())

    assert _is_current(manifest) is True
    assert _is_current(manifest, source_revision="e" * 40) is False


def _is_current(manifest: dict, **overrides) -> bool:
    data = _inputs()
    boundary = {
        "source_revision": data["revision"]["sourceRevision"],
        "diff_digest": data["revision"]["diffDigest"],
        "generated_inventory": data["generated_inventory"],
        "untracked_deliverables": data["untracked_deliverables"],
    }
    boundary.update(overrides)
    return manifest_is_current(manifest, **boundary)


@pytest.mark.parametrize(
    ("overrides", "description"),
    [
        ({"diff_digest": _OTHER}, "diff"),
        ({"generated_inventory": []}, "generated inventory"),
        ({"untracked_deliverables": []}, "untracked inventory"),
    ],
)
def test_given_changed_frozen_boundary_when_checked_then_manifest_is_not_current(
    overrides: dict, description: str
) -> None:
    manifest = build_validation_manifest(**_inputs())

    assert _is_current(manifest, **overrides) is False, description


@pytest.mark.parametrize("status", ["passed", "failed"])
def test_given_completed_command_without_artifact_digest_when_built_then_rejected(
    status: str,
) -> None:
    data = _inputs()
    data["commands"][0]["status"] = status
    del data["commands"][0]["resultArtifactDigest"]

    with pytest.raises(ScriptError, match="requires a result artifact digest"):
        build_validation_manifest(**data)


@pytest.mark.parametrize("status", ["skipped", "unavailable"])
def test_given_nonexecuted_command_without_reason_when_built_then_rejected(
    status: str,
) -> None:
    data = _inputs()
    data["commands"][0]["status"] = status
    del data["commands"][0]["resultArtifactDigest"]

    with pytest.raises(ScriptError, match="requires a reason"):
        build_validation_manifest(**data)


def test_given_documents_when_report_built_then_order_is_deterministic() -> None:
    documents = [
        {"path": "z.json", "schema": "z.schema.json"},
        {"path": "a.json", "schema": "a.schema.json"},
    ]

    report = build_schema_validation_report(documents)

    assert report == {
        "schemaVersion": "1.0.0",
        "status": "valid",
        "documents": [
            {"path": "a.json", "schema": "a.schema.json", "status": "valid"},
            {"path": "z.json", "schema": "z.schema.json", "status": "valid"},
        ],
    }


def test_given_duplicate_report_path_when_built_then_rejected() -> None:
    with pytest.raises(ScriptError, match="Duplicate schema validation report path"):
        build_schema_validation_report(
            [
                {"path": "same.json", "schema": "a.schema.json"},
                {"path": "same.json", "schema": "b.schema.json"},
            ]
        )


def test_given_tampered_manifest_when_staged_then_rejected() -> None:
    manifest = build_validation_manifest(**_inputs())
    manifest["revision"]["diffDigest"] = _OTHER

    with pytest.raises(ScriptError, match="digest mismatch"):
        validate_retained_document("accessibility-validation-manifest.json", manifest)


@pytest.mark.parametrize(
    ("name", "document"),
    [
        ("schema-validation-report.json", {}),
        ("composition-summary.json", {}),
    ],
)
def test_given_schema_invalid_document_when_staged_then_rejected(
    name: str, document: dict
) -> None:
    with pytest.raises(ScriptError, match="schema validation failed"):
        validate_retained_document(name, document)


def test_given_unlisted_document_when_staged_then_rejected() -> None:
    with pytest.raises(ScriptError, match="Unlisted retained document"):
        validate_retained_document("other.json", {})


def test_noncurrent_manifest_requires_capability_based_public_pages() -> None:
    data = _inputs()
    data["commands"][0]["status"] = "failed"
    manifest = build_validation_manifest(**data)
    repo_root = Path(__file__).resolve().parents[6]
    paths = (
        repo_root / "docs/docusaurus/src/pages/accessibility.tsx",
        repo_root / "docs/docusaurus/src/pages/accessibility/vpat.tsx",
    )

    validate_public_claim_posture(
        {
            str(path.relative_to(repo_root)): path.read_text(encoding="utf-8")
            for path in paths
        },
        manifest_current=_is_current(manifest),
    )


@pytest.mark.parametrize(
    "claim",
    [
        "Automated accessibility checks pass across the declared inventory.",
        "Validated by automated accessibility testing.",
        "<strong>Assessment date:</strong> 2026-09-17",
    ],
)
def test_given_noncurrent_manifest_when_completed_claim_checked_then_rejected(
    claim: str,
) -> None:
    with pytest.raises(ScriptError, match="requires a current manifest"):
        validate_public_claim_posture(
            {"public-page.tsx": claim}, manifest_current=False
        )
