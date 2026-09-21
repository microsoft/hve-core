# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Deterministic validation manifest binding a validation run to one revision."""

from __future__ import annotations

import re
from typing import Any

from runtime_a11y._errors import EXIT_USAGE, ScriptError
from runtime_a11y.evidence_bundle._canonical import canonical_digest
from runtime_a11y.evidence_bundle._validate import validate_document

_SCHEMA = "validation-manifest.schema.json"
_REPORT_SCHEMA = "schema-validation-report.schema.json"
_DIGEST_DOMAIN = "hve-a11y:validation-manifest:v1"
_RETAINED_SCHEMAS = {
    "evidence-bundle.json": "evidence-bundle.schema.json",
    "composition-summary.json": "composition-summary.schema.json",
    "accessibility-validation-manifest.json": _SCHEMA,
    "schema-validation-report.json": _REPORT_SCHEMA,
}
_NONCURRENT_CLAIM_PATTERNS = (
    re.compile(r"automated(?: accessibility| wcag [^.]*)? checks pass", re.IGNORECASE),
    re.compile(r"validated by automated accessibility testing", re.IGNORECASE),
    re.compile(r"assessment date\s*:?\s*</strong>\s*\d{4}-\d{2}-\d{2}", re.IGNORECASE),
)


def _require_unique(paths: list[dict[str, Any]], label: str) -> None:
    values = [entry["path"] for entry in paths]
    if len(values) != len(set(values)):
        raise ScriptError(f"Duplicate {label} path", EXIT_USAGE)


def _ordered_inventory(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted((dict(entry) for entry in entries), key=lambda item: item["path"])


def _validate_commands(commands: list[dict[str, Any]]) -> None:
    for command in commands:
        status = command["status"]
        if status in {"passed", "failed"} and not command.get("resultArtifactDigest"):
            raise ScriptError(
                f"Validation command {command['commandId']} requires a result "
                "artifact digest",
                EXIT_USAGE,
            )
        if status in {"skipped", "unavailable"} and not command.get("reason"):
            raise ScriptError(
                f"Validation command {command['commandId']} requires a reason",
                EXIT_USAGE,
            )


def build_validation_manifest(
    *,
    revision: dict[str, Any],
    environment: dict[str, Any],
    commands: list[dict[str, Any]],
    generated_inventory: list[dict[str, Any]],
    untracked_deliverables: list[dict[str, Any]],
    assistive_technology_sample: dict[str, Any],
) -> dict[str, Any]:
    """Build a manifest whose digest covers every input except the digest itself.

    Ordering is normalized so the same validation run produces the same bytes
    regardless of the order inputs were collected in.
    """
    if not commands:
        raise ScriptError(
            "A validation manifest requires at least one command", EXIT_USAGE
        )
    command_ids = [command["commandId"] for command in commands]
    if len(command_ids) != len(set(command_ids)):
        raise ScriptError("Duplicate validation command identity", EXIT_USAGE)
    _validate_commands(commands)
    _require_unique(generated_inventory, "generated inventory")
    _require_unique(untracked_deliverables, "untracked deliverable")

    manifest: dict[str, Any] = {
        "schemaVersion": "1.0.0",
        "revision": dict(revision),
        "environment": {
            "operatingSystem": environment["operatingSystem"],
            "toolVersions": dict(sorted(environment["toolVersions"].items())),
        },
        "commands": sorted(commands, key=lambda item: item["commandId"]),
        "generatedInventory": _ordered_inventory(generated_inventory),
        "untrackedDeliverables": _ordered_inventory(untracked_deliverables),
        "assistiveTechnologySample": {
            "advisory": True,
            "journeys": sorted(assistive_technology_sample["journeys"]),
            "boundary": assistive_technology_sample["boundary"],
        },
    }
    manifest["manifestDigest"] = canonical_digest(manifest, domain=_DIGEST_DOMAIN)
    validate_document(manifest, _SCHEMA)
    return manifest


def verify_validation_manifest(manifest: dict[str, Any]) -> None:
    """Reject a manifest whose recorded digest does not cover its own content."""
    validate_document(manifest, _SCHEMA)
    material = {
        key: value for key, value in manifest.items() if key != "manifestDigest"
    }
    if manifest["manifestDigest"] != canonical_digest(material, domain=_DIGEST_DOMAIN):
        raise ScriptError("Validation manifest digest mismatch", EXIT_USAGE)


def build_schema_validation_report(
    documents: list[dict[str, str]],
) -> dict[str, Any]:
    """Build a deterministic report for documents validated by the emitter."""
    if not documents:
        raise ScriptError("Schema validation report requires a document", EXIT_USAGE)
    paths = [document["path"] for document in documents]
    if len(paths) != len(set(paths)):
        raise ScriptError("Duplicate schema validation report path", EXIT_USAGE)
    report = {
        "schemaVersion": "1.0.0",
        "status": "valid",
        "documents": sorted(
            (
                {
                    "path": document["path"],
                    "schema": document["schema"],
                    "status": "valid",
                }
                for document in documents
            ),
            key=lambda item: item["path"],
        ),
    }
    validate_document(report, _REPORT_SCHEMA)
    return report


def validate_retained_document(name: str, document: dict[str, Any]) -> None:
    """Validate one allowlisted retained document against its owning schema."""
    schema = _RETAINED_SCHEMAS.get(name)
    if schema is None:
        raise ScriptError(f"Unlisted retained document: {name}", EXIT_USAGE)
    validate_document(document, schema)
    if name == "accessibility-validation-manifest.json":
        verify_validation_manifest(document)


def manifest_is_current(
    manifest: dict[str, Any],
    *,
    source_revision: str,
    diff_digest: str,
    generated_inventory: list[dict[str, Any]],
    untracked_deliverables: list[dict[str, Any]],
) -> bool:
    """Report whether a manifest matches the complete frozen boundary and passed."""
    try:
        verify_validation_manifest(manifest)
    except ScriptError:
        return False
    if manifest["revision"]["sourceRevision"] != source_revision:
        return False
    if manifest["revision"]["diffDigest"] != diff_digest:
        return False
    if manifest["generatedInventory"] != _ordered_inventory(generated_inventory):
        return False
    if manifest["untrackedDeliverables"] != _ordered_inventory(untracked_deliverables):
        return False
    return all(command["status"] == "passed" for command in manifest["commands"])


def validate_public_claim_posture(
    documents: dict[str, str], *, manifest_current: bool
) -> None:
    """Reject completed or dated public claims without a current manifest."""
    if manifest_current:
        return
    for path, text in documents.items():
        for pattern in _NONCURRENT_CLAIM_PATTERNS:
            if pattern.search(text):
                raise ScriptError(
                    f"Public accessibility claim requires a current manifest: {path}",
                    EXIT_USAGE,
                )
