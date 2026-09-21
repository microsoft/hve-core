# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Provenance and non-attestation metadata shared by every rendered artifact.

Disclosure lives here rather than inside a renderer because each export is read
independently. The EARL document in particular is designed for machine ingestion
by conformance tooling, so a notice carried only by the Markdown sibling never
reaches the reader who acts on it. Every renderer receives one metadata object
built once per bundle and serializes it in its own idiom.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Custom terms are defined at this namespace. Emitting a term without a
# published definition leaves a conformance consumer unable to interpret it.
HVE_NAMESPACE = "https://microsoft.github.io/hve-core/ns/accessibility#"

TOOL_NAME = "hve-core runtime_a11y"

NON_ATTESTATION_STATEMENT = (
    "Automated and AI-assisted accessibility evidence. This is not an "
    "accessibility conformance attestation, VPAT, Accessibility Conformance "
    "Report, or European Accessibility Act determination. A qualified "
    "accessibility reviewer must validate these results before external "
    "publication, customer disclosure, procurement response, or regulatory "
    "submission."
)

EVIDENCE_LIMITS_STATEMENT = (
    "A verdict reflects the evidence method recorded for each cell. Automated "
    "observation cannot decide criteria that depend on judging meaning, "
    "quality, or intent. Real assistive-technology results reflect the single "
    "technology, browser, and profile recorded in the run."
)


def _tool_version() -> str:
    """Read the harness version from its package manifest."""
    import json

    manifest = Path(__file__).resolve().parent.parent / "package.json"
    try:
        return json.loads(manifest.read_text(encoding="utf-8")).get("version", "0.0.0")
    except (OSError, ValueError):
        return "0.0.0"


@dataclass(slots=True)
class ArtifactMetadata:
    """Identity, provenance, and review state for one rendered bundle."""

    generatedAt: str
    tool: str
    toolVersion: str
    repository: str | None = None
    catalog: dict[str, Any] = field(default_factory=dict)
    humanReviewCompleted: bool = False
    quarantined: bool = False
    quarantineReason: str | None = None
    nonAttestation: str = NON_ATTESTATION_STATEMENT
    evidenceLimits: str = EVIDENCE_LIMITS_STATEMENT

    def to_dict(self) -> dict[str, Any]:
        """Serialize for JSON and YAML exports."""
        payload: dict[str, Any] = {
            "generatedAt": self.generatedAt,
            "tool": self.tool,
            "toolVersion": self.toolVersion,
            "repository": self.repository,
            "criteriaCatalog": self.catalog,
            "aiAssisted": True,
            "humanReviewCompleted": self.humanReviewCompleted,
            "quarantined": self.quarantined,
            "nonAttestation": self.nonAttestation,
            "evidenceLimits": self.evidenceLimits,
        }
        if self.quarantined:
            payload["quarantineReason"] = self.quarantineReason
        return payload

    def to_earl_terms(self) -> dict[str, Any]:
        """Serialize as namespaced terms for the EARL document root."""
        payload = {
            "dct:created": self.generatedAt,
            "dct:rights": self.nonAttestation,
            "hve:aiAssisted": True,
            "hve:humanReviewCompleted": self.humanReviewCompleted,
            "hve:evidenceLimits": self.evidenceLimits,
            "hve:toolVersion": self.toolVersion,
            "hve:criteriaCatalog": self.catalog,
            "hve:quarantined": self.quarantined,
        }
        if self.quarantined:
            payload["hve:quarantineReason"] = self.quarantineReason
        return payload


def build_artifact_metadata(
    *,
    repository: str | None = None,
    catalog: dict[str, Any] | None = None,
    quarantined: bool = False,
    quarantine_reason: str | None = None,
    generated_at: str | None = None,
) -> ArtifactMetadata:
    """Build the metadata every artifact in one bundle shares.

    Human review defaults to incomplete. An agent never records that a person
    reviewed the output, so the flag stays false until a reviewer sets it.
    """
    return ArtifactMetadata(
        generatedAt=generated_at
        or datetime.now(timezone.utc).isoformat(timespec="seconds"),
        tool=TOOL_NAME,
        toolVersion=_tool_version(),
        repository=repository,
        catalog=catalog or {},
        quarantined=quarantined,
        quarantineReason=quarantine_reason,
    )
