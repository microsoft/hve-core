# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Versioned source adapters for accessibility evidence composition."""

from __future__ import annotations

import re
from typing import Any

from runtime_a11y._errors import EXIT_USAGE, ScriptError
from runtime_a11y.evidence_bundle._canonical import canonical_digest
from runtime_a11y.evidence_bundle._validate import (
    reject_prohibited_content,
    validate_document,
)

_RUN_ALL_STATUS = {
    "pass": "PASS",
    "fail": "FAIL",
    "candidate": "CANT_TELL",
    "partial": "CANT_TELL",
    "unsupported": "CANT_TELL",
    "error": "CANT_TELL",
}
_VISUAL_STATUS = {
    "deterministic-pass": "PASS",
    "real-at-pass": "PASS",
    "human-confirmed": "PASS",
    "deterministic-fail": "FAIL",
    "real-at-fail": "FAIL",
    "model-flagged": "CANT_TELL",
    "model-clear-advisory": "CANT_TELL",
    "ambiguous": "CANT_TELL",
    "unavailable": "CANT_TELL",
}
_VISUAL_METHODS = frozenset({"visual", "visual-review"})
_VISUAL_MEDIA_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".json": "application/json",
    ".zip": "application/zip",
}
_ARTIFACT_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
SUPPORTED_HVE_SOURCE_VERSIONS = {
    "runtime_a11y.run-all": frozenset({"unversioned-current"}),
    "runtime_a11y.visual-review": frozenset({"1.0"}),
}


def _source_digest(envelope: dict[str, Any]) -> str:
    material = {key: value for key, value in envelope.items() if key != "sourceDigest"}
    return canonical_digest(material, domain="hve-a11y:evidence-source:v1")


def _state_proof_id(
    journey_id: str,
    state: str,
    state_proofs: list[dict[str, Any]],
) -> str | None:
    matches = [
        proof["proofId"]
        for proof in state_proofs
        if proof["journeyId"] == journey_id and proof["state"] == state
    ]
    if len(matches) > 1:
        raise ScriptError("Source mapping has ambiguous state proofs", EXIT_USAGE)
    return matches[0] if matches else None


def _require_mapping(
    candidates: list[dict[str, Any]], source_label: str
) -> dict[str, Any]:
    if len(candidates) != 1:
        raise ScriptError(
            f"{source_label} requires exactly one selected catalog mapping; "
            f"found {len(candidates)}",
            EXIT_USAGE,
        )
    return candidates[0]


def _run_all_envelope(
    source: dict[str, Any],
    expected_cells: list[dict[str, Any]],
    asset_catalog: dict[str, Any],
    requirement_catalog: dict[str, Any],
    state_proofs: list[dict[str, Any]],
    run_context: dict[str, Any],
) -> dict[str, Any]:
    if "schemaVersion" in source:
        raise ScriptError("Unsupported runtime_a11y run-all schema version", EXIT_USAGE)
    if source.get("command") not in {None, "run-all"}:
        raise ScriptError("Unsupported runtime_a11y source command", EXIT_USAGE)
    if not isinstance(source.get("runs"), list) or not isinstance(
        source.get("results"), list
    ):
        raise ScriptError("Invalid runtime_a11y run-all source shape", EXIT_USAGE)
    reject_prohibited_content(source)
    requirements = {
        requirement["requirementId"]: requirement
        for requirement in requirement_catalog["requirements"]
    }
    journeys = {journey["journeyId"]: journey for journey in asset_catalog["journeys"]}
    raw_digest = canonical_digest(source, domain="hve-a11y:run-all-source:v1")
    results: list[dict[str, Any]] = []
    for index, row in enumerate(source["results"]):
        if not isinstance(row, dict):
            raise ScriptError("Invalid runtime_a11y run-all result", EXIT_USAGE)
        criterion_id = str(row.get("criterionId") or "")
        framework = str(row.get("framework") or "")
        surface_id = str(row.get("surfaceId") or "")
        state = str(row.get("state") or "")
        method = str(row.get("method") or "runtime-automation")
        probe = str(row.get("probeId") or "")
        candidates = []
        for cell in expected_cells:
            requirement = requirements[cell["requirementId"]]
            journey = journeys[cell["journeyId"]]
            if (
                not cell.get("human")
                and criterion_id
                == str(requirement.get("criterionId", requirement["requirementId"]))
                and (not framework or framework == requirement["framework"])
                and surface_id == str(journey.get("surfaceId", journey["journeyId"]))
                and state == cell["state"]
                and method == cell["method"]
                and probe == cell["probe"]
            ):
                candidates.append(cell)
        cell = _require_mapping(candidates, "runtime_a11y run-all result")
        status = _RUN_ALL_STATUS.get(str(row.get("status") or "").lower())
        if status is None:
            raise ScriptError("Unsupported runtime_a11y result status", EXIT_USAGE)
        result = {
            "resultId": "result-run-all-"
            + canonical_digest(
                [raw_digest, index, row], domain="hve-a11y:adapted-result:v1"
            )[:20],
            "requirementId": cell["requirementId"],
            "journeyId": cell["journeyId"],
            "state": cell["state"],
            "method": cell["method"],
            "probe": cell["probe"],
            "disposition": cell["disposition"],
            "status": status,
            "expected": cell["expected"],
            "observed": str(row.get("evidence") or f"runtime_a11y reported {status}"),
            "artifactIds": [],
        }
        proof_id = _state_proof_id(cell["journeyId"], cell["state"], state_proofs)
        if proof_id is not None:
            result["stateProofId"] = proof_id
        results.append(result)
    envelope = {
        "schemaVersion": "1.0.0",
        "sourceKind": "hve-probe",
        "producer": "runtime_a11y run-all",
        "sourceRunId": f"run-all-{raw_digest[:20]}",
        "observedAt": source.get("runAt"),
        "sourceDigest": "",
        "boundTo": _binding(run_context),
        "quarantined": bool(source.get("quarantined")),
        "quarantineReasons": [str(source["operationalFailure"])]
        if source.get("operationalFailure")
        else [],
        "results": results,
        "artifacts": [],
    }
    envelope["sourceDigest"] = _source_digest(envelope)
    return envelope


def _visual_artifacts(source: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
    """Project visual manifest entries onto the canonical artifact contract.

    Entries without a byte size cannot be verified, so they are reported as
    unverifiable rather than admitted on the strength of the manifest alone.
    """
    artifacts: list[dict[str, Any]] = []
    unverifiable: list[str] = []
    for category, entries in sorted(source["artifacts"].items()):
        values = entries if isinstance(entries, list) else [entries]
        for entry in values:
            artifact_id = f"{category}:{entry['id']}"
            if not _ARTIFACT_ID_PATTERN.match(artifact_id):
                raise ScriptError(
                    f"Visual artifact identity is not a valid id: {artifact_id}",
                    EXIT_USAGE,
                )
            if "sizeBytes" not in entry:
                unverifiable.append(artifact_id)
                continue
            suffix = entry["path"][entry["path"].rfind(".") :].lower()
            artifacts.append(
                {
                    "artifactId": artifact_id,
                    "path": entry["path"],
                    "mediaType": _VISUAL_MEDIA_TYPES.get(
                        suffix, "application/octet-stream"
                    ),
                    "sizeBytes": entry["sizeBytes"],
                    "sha256": entry["sha256"],
                }
            )
    seen: set[str] = set()
    for artifact in artifacts:
        if artifact["artifactId"] in seen:
            raise ScriptError(
                f"Duplicate visual artifact identity: {artifact['artifactId']}",
                EXIT_USAGE,
            )
        seen.add(artifact["artifactId"])
    return artifacts, unverifiable


def _visual_envelope(
    source: dict[str, Any],
    expected_cells: list[dict[str, Any]],
    asset_catalog: dict[str, Any],
    state_proofs: list[dict[str, Any]],
    run_context: dict[str, Any],
) -> dict[str, Any]:
    if (
        source.get("schemaVersion")
        not in SUPPORTED_HVE_SOURCE_VERSIONS["runtime_a11y.visual-review"]
    ):
        raise ScriptError("Unsupported visual-review manifest version", EXIT_USAGE)
    validate_document(source, "visual-review-manifest.schema.json")
    journeys = {journey["journeyId"]: journey for journey in asset_catalog["journeys"]}
    candidates = [
        cell
        for cell in expected_cells
        if not cell.get("human")
        and source["surface"]
        == str(journeys[cell["journeyId"]].get("surfaceId", cell["journeyId"]))
        and source["state"] == cell["state"]
        and (cell["method"] in _VISUAL_METHODS or cell["probe"] in _VISUAL_METHODS)
    ]
    if not candidates:
        raise ScriptError(
            "Visual-review manifest has no selected catalog mapping", EXIT_USAGE
        )
    raw_digest = canonical_digest(source, domain="hve-a11y:visual-source:v1")
    artifacts, unverifiable = _visual_artifacts(source)
    status = _VISUAL_STATUS[source["evidenceState"]]
    artifact_ids = [artifact["artifactId"] for artifact in artifacts]
    limitation = None
    if unverifiable:
        # A deciding PASS cannot rest on bytes the bundle never verified.
        if status == "PASS":
            status = "CANT_TELL"
        limitation = (
            "Visual artifacts without a declared byte size were not verified: "
            + ", ".join(sorted(unverifiable))
        )
    results = []
    for cell in candidates:
        result = {
            "resultId": "result-visual-"
            + canonical_digest(
                [raw_digest, cell["cellId"]], domain="hve-a11y:adapted-result:v1"
            )[:20],
            "requirementId": cell["requirementId"],
            "journeyId": cell["journeyId"],
            "state": cell["state"],
            "method": cell["method"],
            "probe": cell["probe"],
            "disposition": cell["disposition"],
            "status": status,
            "expected": cell["expected"],
            "observed": f"Visual review evidence state: {source['evidenceState']}",
            "artifactIds": artifact_ids,
        }
        if limitation is not None:
            result["limitation"] = limitation
        proof_id = _state_proof_id(cell["journeyId"], cell["state"], state_proofs)
        if proof_id is not None:
            result["stateProofId"] = proof_id
        results.append(result)
    envelope = {
        "schemaVersion": "1.0.0",
        "sourceKind": "visual",
        "producer": "runtime_a11y capture-visual-review",
        "sourceRunId": source["runId"],
        "observedAt": source["createdAt"],
        "sourceDigest": "",
        "boundTo": _binding(run_context),
        "results": results,
        "artifacts": artifacts,
    }
    envelope["sourceDigest"] = _source_digest(envelope)
    return envelope


_BINDING_FIELDS = ("sourceRevision", "buildDigest", "configDigest", "fixtureDigest")


def _binding(run_context: dict[str, Any]) -> dict[str, Any]:
    """Project the run context fields a source must be bound to."""
    return {field: run_context[field] for field in _BINDING_FIELDS}


def normalize_sources(
    sources: list[dict[str, Any]],
    *,
    run_context: dict[str, Any],
    expected_cells: list[dict[str, Any]] | None = None,
    asset_catalog: dict[str, Any] | None = None,
    requirement_catalog: dict[str, Any] | None = None,
    state_proofs: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """Validate and flatten versioned source envelopes."""
    normalized: list[dict[str, Any]] = []
    for source in sources:
        source_schema = str(source.get("schemaVersion") or "unversioned-current")
        if source.get("tool") == "runtime_a11y" and "runs" in source:
            if (
                expected_cells is None
                or asset_catalog is None
                or requirement_catalog is None
            ):
                raise ScriptError(
                    "run-all adaptation requires catalog context", EXIT_USAGE
                )
            envelope = _run_all_envelope(
                source,
                expected_cells,
                asset_catalog,
                requirement_catalog,
                state_proofs or [],
                run_context,
            )
        elif "probeOutcomes" in source and "evidenceState" in source:
            if expected_cells is None or asset_catalog is None:
                raise ScriptError(
                    "visual adaptation requires catalog context", EXIT_USAGE
                )
            envelope = _visual_envelope(
                source, expected_cells, asset_catalog, state_proofs or [], run_context
            )
        else:
            envelope = source
        validate_document(envelope, "evidence-source.schema.json")
        if envelope["sourceDigest"] != _source_digest(envelope):
            raise ScriptError("Evidence source digest mismatch", EXIT_USAGE)
        # A self-consistent envelope from another revision must not speak for
        # this run, so identity is compared before any result is indexed.
        expected_binding = _binding(run_context)
        for field, value in expected_binding.items():
            if envelope["boundTo"].get(field) != value:
                raise ScriptError(
                    f"Evidence source is bound to a different {field}", EXIT_USAGE
                )
        for result in envelope["results"]:
            normalized.append(
                {
                    **result,
                    "sourceKind": envelope["sourceKind"],
                    "sourceSchemaVersion": source_schema,
                    "producer": envelope["producer"],
                    "sourceRunId": envelope["sourceRunId"],
                    "sourceDigest": envelope["sourceDigest"],
                    "observedAt": envelope["observedAt"],
                    "quarantined": bool(envelope.get("quarantined")),
                    "quarantineReasons": list(envelope.get("quarantineReasons", [])),
                    "transcript": envelope.get("transcript"),
                }
            )
    return normalized


def collect_artifacts(sources: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return uniquely identified artifacts from validated source envelopes."""
    artifacts: dict[str, dict[str, Any]] = {}
    for source in sources:
        if source.get("tool") == "runtime_a11y" and "runs" in source:
            continue
        if "probeOutcomes" in source and "evidenceState" in source:
            entries, _ = _visual_artifacts(source)
        else:
            entries = source.get("artifacts", [])
        for artifact in entries:
            artifact_id = artifact["artifactId"]
            if artifact_id in artifacts and artifacts[artifact_id] != artifact:
                raise ScriptError(
                    f"Conflicting artifact identity: {artifact_id}", EXIT_USAGE
                )
            artifacts[artifact_id] = artifact
    return [artifacts[key] for key in sorted(artifacts)]
