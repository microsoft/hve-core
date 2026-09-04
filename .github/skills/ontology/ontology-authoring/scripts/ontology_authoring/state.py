# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Create, validate, mutate, and atomically persist Ontology Builder state."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

from jsonschema import Draft202012Validator, FormatChecker

from ontology_authoring.paths import PathBoundaryError, resolve_descendant

SCHEMA_VERSION = "1.0.0"
CONTEXT_FIELDS = (
    "businessActivity",
    "ontologyPurpose",
    "domainScope",
    "usersAndDecisions",
    "sourceBoundary",
)
GATE_ORDER = ("research", "design", "implement")
GATE_DEPENDENCIES: dict[str, GateName] = {
    "context": "research",
    "evidence": "research",
    "researchBrief": "research",
    "designSpecification": "design",
    "namespacePolicy": "design",
    "mappingSpecification": "design",
    "ontologyPackage": "implement",
    "shapeInputs": "implement",
}
PHASE_BY_GATE = {
    "research": "research",
    "design": "design",
    "implement": "implement",
}
GateName = Literal["research", "design", "implement"]
PhaseName = Literal["research", "design", "implement", "deploy-handoff"]


class StateError(ValueError):
    """Raised when ontology state cannot be trusted or persisted."""


def utc_now() -> str:
    """Return a schema-compatible UTC timestamp."""
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def default_schema_path() -> Path:
    """Return the canonical Ontology Builder state-schema path."""
    repository_root = Path(__file__).resolve().parents[6]
    schema_name = "ontology-builder-state.schema.json"
    return repository_root / "scripts" / "linting" / "schemas" / schema_name


def load_validator(schema_path: Path | None = None) -> Draft202012Validator:
    """Load and check the canonical state schema."""
    path = (schema_path or default_schema_path()).resolve(strict=True)
    schema = json.loads(path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=FormatChecker())


def validate_state(
    state: Mapping[str, Any],
    *,
    schema_path: Path | None = None,
) -> None:
    """Reject state that does not satisfy the canonical schema."""
    errors = sorted(
        load_validator(schema_path).iter_errors(state),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        error = errors[0]
        location = ".".join(str(part)
                            for part in error.absolute_path) or "<root>"
        raise StateError(f"Invalid state at {location}: {error.message}")


def create_state(project_slug: str, project_name: str, *, now: str | None = None) -> dict[str, Any]:
    """Create valid initial Research state with all source operations denied."""
    timestamp = now or utc_now()
    context = {
        field: {"value": None, "confirmed": False}
        for field in CONTEXT_FIELDS
    }
    state = {
        "schemaVersion": SCHEMA_VERSION,
        "project": {"slug": project_slug, "name": project_name},
        "phase": "research",
        "context": {"status": "pending", **context},
        "sourceInventory": [],
        "evidenceDocuments": [],
        "contributions": [],
        "decisions": [],
        "candidates": [],
        "approvals": [],
        "gates": {
            gate: {
                "status": "pending",
                "inputDigests": [],
                "downstreamInvalidated": False,
            }
            for gate in GATE_ORDER
        },
        "artifacts": [],
        "reports": [],
        "timestamps": {"createdAt": timestamp, "updatedAt": timestamp},
    }
    state["gates"]["deployHandoff"] = {
        "status": "deferred",
        "target": "033 Fabric Ontology Edge AI Agent",
    }
    validate_state(state)
    return state


def context_digest(state: Mapping[str, Any]) -> str:
    """Return a canonical digest for the five business-context values."""
    context = state["context"]
    values = {field: context[field]["value"] for field in CONTEXT_FIELDS}
    canonical = json.dumps(values, sort_keys=True,
                           separators=(",", ":")).encode()
    return hashlib.sha256(canonical).hexdigest()


def update_context(
    state: Mapping[str, Any],
    values: Mapping[str, str | None],
    *,
    confirm: bool = False,
    confirmed_by: str | None = None,
    now: str | None = None,
) -> dict[str, Any]:
    """Apply provisional context values or explicitly confirm all five fields."""
    unknown_fields = set(values) - set(CONTEXT_FIELDS)
    if unknown_fields:
        raise StateError(
            f"Unknown context fields: {', '.join(sorted(unknown_fields))}")

    updated = copy.deepcopy(state)
    timestamp = now or utc_now()
    changed = False
    for field, value in values.items():
        if updated["context"][field]["value"] != value:
            changed = True
            updated["context"][field] = {"value": value, "confirmed": False}

    if changed:
        updated["context"]["status"] = "pending"
        for field in CONTEXT_FIELDS:
            context_field = updated["context"][field]
            context_field["confirmed"] = False
            context_field.pop("confirmedBy", None)
            context_field.pop("confirmedAt", None)
        updated["sourceInventory"] = []
        updated["evidenceDocuments"] = []
        updated = update_gate_inputs(
            updated,
            "research",
            [context_digest(updated)],
            reason="Confirmed business context changed",
            now=timestamp,
        )

    if confirm:
        if not confirmed_by:
            raise StateError(
                "Explicit context confirmation requires confirmer attribution")
        missing = [
            field
            for field in CONTEXT_FIELDS
            if not isinstance(updated["context"][field]["value"], str)
            or not updated["context"][field]["value"].strip()
        ]
        if missing:
            raise StateError(
                f"Cannot confirm empty context fields: {', '.join(missing)}")
        for field in CONTEXT_FIELDS:
            updated["context"][field].update(
                {
                    "confirmed": True,
                    "confirmedBy": confirmed_by,
                    "confirmedAt": timestamp,
                }
            )
        updated["context"]["status"] = "confirmed"
        updated["gates"]["research"]["inputDigests"] = [
            context_digest(updated)]

    updated["timestamps"]["updatedAt"] = timestamp
    validate_state(updated)
    return updated


def read_state(
    project_root: Path,
    expected_project_slug: str,
    *,
    schema_path: Path | None = None,
) -> dict[str, Any]:
    """Read validated state and reject project identity mismatch."""
    try:
        state_path = resolve_descendant(
            project_root, Path("state.json"), must_exist=True)
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, PathBoundaryError) as error:
        raise StateError(
            f"Could not read trusted project state: {error}") from error
    if not isinstance(state, dict):
        raise StateError("Project state must be a JSON object")
    validate_state(state, schema_path=schema_path)
    if state["project"]["slug"] != expected_project_slug:
        raise StateError(
            "Project identity does not match the requested project")
    return state


def write_state_atomic(
    project_root: Path,
    state: Mapping[str, Any],
    *,
    schema_path: Path | None = None,
) -> Path:
    """Validate state before atomically replacing the project state file."""
    validate_state(state, schema_path=schema_path)
    project_root.mkdir(parents=True, exist_ok=True)
    try:
        state_path = resolve_descendant(project_root, Path("state.json"))
        descriptor, temporary_name = tempfile.mkstemp(
            dir=project_root,
            prefix=".state-",
            suffix=".json.tmp",
        )
        temporary_path = Path(temporary_name)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(state, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        temporary_path.replace(state_path)
    except (OSError, PathBoundaryError) as error:
        if "temporary_path" in locals():
            temporary_path.unlink(missing_ok=True)
        raise StateError(
            f"Could not persist project state: {error}") from error
    return state_path


def assert_source_access(state: Mapping[str, Any]) -> None:
    """Deny source operations until all five context fields are confirmed."""
    context = state.get("context")
    if not isinstance(context, Mapping) or context.get("status") != "confirmed":
        raise StateError("Source access requires confirmed business context")
    if any(
        not isinstance(context.get(field), Mapping)
        or context[field].get("confirmed") is not True
        for field in CONTEXT_FIELDS
    ):
        raise StateError(
            "Source access requires confirmation of all five context fields")


def earliest_resumable_gate(state: Mapping[str, Any]) -> GateName | None:
    """Return the earliest gate that is not currently approved."""
    validate_state(state)
    for gate_name in GATE_ORDER:
        if state["gates"][gate_name]["status"] != "approved":
            return gate_name  # type: ignore[return-value]
    return None


def resume_state(
    state: Mapping[str, Any],
    current_inputs: Mapping[GateName, Sequence[str]],
    *,
    now: str | None = None,
) -> tuple[dict[str, Any], GateName | None]:
    """Verify supplied gate inputs and identify the earliest resumable gate."""
    updated = copy.deepcopy(state)
    for gate_name in GATE_ORDER:
        supplied_digests = current_inputs.get(gate_name)
        if supplied_digests is None:
            continue
        updated = update_gate_inputs(
            updated,
            gate_name,  # type: ignore[arg-type]
            supplied_digests,
            reason=f"{gate_name.title()} gate inputs changed during resume",
            now=now,
        )
    return updated, earliest_resumable_gate(updated)


def transition_phase(
    state: Mapping[str, Any],
    phase: PhaseName,
    *,
    now: str | None = None,
) -> dict[str, Any]:
    """Move to a phase only when schema-defined upstream gates permit it."""
    updated = copy.deepcopy(state)
    updated["phase"] = phase
    updated["timestamps"]["updatedAt"] = now or utc_now()
    validate_state(updated)
    return updated


def update_material_inputs(
    state: Mapping[str, Any],
    input_kind: str,
    input_digests: Sequence[str],
    *,
    now: str | None = None,
) -> dict[str, Any]:
    """Route material input changes through the declared gate dependency matrix."""
    try:
        gate_name = GATE_DEPENDENCIES[input_kind]
    except KeyError as error:
        raise StateError(f"Unknown gate input kind: {input_kind}") from error
    return update_gate_inputs(
        state,
        gate_name,
        input_digests,
        reason=f"{input_kind} inputs changed",
        now=now,
    )


def replace_reports(
    state: Mapping[str, Any],
    reports: Sequence[Mapping[str, Any]],
    *,
    now: str | None = None,
) -> dict[str, Any]:
    """Replace derived reports without invalidating semantically unchanged gates."""
    updated = copy.deepcopy(state)
    updated["reports"] = copy.deepcopy(list(reports))
    updated["timestamps"]["updatedAt"] = now or utc_now()
    validate_state(updated)
    return updated


def update_gate_inputs(
    state: Mapping[str, Any],
    gate_name: GateName,
    input_digests: Sequence[str],
    *,
    reason: str,
    now: str | None = None,
) -> dict[str, Any]:
    """Update gate inputs and stale approved gates from the earliest changed gate."""
    updated = copy.deepcopy(state)
    gate_index = GATE_ORDER.index(gate_name)
    current_gate = updated["gates"][gate_name]
    digests = list(dict.fromkeys(input_digests))
    if current_gate["inputDigests"] == digests:
        return updated

    timestamp = now or utc_now()
    current_gate["inputDigests"] = digests
    for affected_name in GATE_ORDER[gate_index:]:
        affected_gate = updated["gates"][affected_name]
        if affected_gate["status"] in {"approved", "rejected", "stale"}:
            affected_gate.update(
                {
                    "status": "stale",
                    "downstreamInvalidated": True,
                    "invalidatedAt": timestamp,
                    "invalidationReason": reason,
                }
            )
            affected_gate.pop("approvalId", None)
    affected_names = set(GATE_ORDER[gate_index:])
    for approval in updated["approvals"]:
        if approval["gate"] in affected_names and approval["status"] in {"approved", "rejected"}:
            approval.update(
                {
                    "status": "stale",
                    "invalidatedAt": timestamp,
                    "invalidationReason": reason,
                }
            )
    updated["phase"] = PHASE_BY_GATE[gate_name]
    updated["timestamps"]["updatedAt"] = timestamp
    validate_state(updated)
    return updated
