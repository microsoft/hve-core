# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

import json
import subprocess
from pathlib import Path

import pytest
from ontology_authoring.paths import (
    PathBoundaryError,
    is_ignored_path,
    resolve_descendant,
    resolve_project_root,
)
from ontology_authoring.state import (
    StateError,
    assert_source_access,
    context_digest,
    create_state,
    earliest_resumable_gate,
    read_state,
    replace_reports,
    resume_state,
    transition_phase,
    update_context,
    update_gate_inputs,
    update_material_inputs,
    validate_state,
    write_state_atomic,
)

NOW = "2026-09-04T12:00:00Z"
DIGEST_A = "a" * 64
DIGEST_B = "b" * 64


def test_given_new_project_when_create_then_valid_pending_state_is_returned() -> None:
    # Act
    state = create_state("service-operations", "Service Operations", now=NOW)

    # Assert
    validate_state(state)
    assert state["context"]["status"] == "pending"
    assert state["sourceInventory"] == []


def test_given_pending_context_when_source_access_then_operation_is_denied() -> None:
    # Arrange
    state = create_state("service-operations", "Service Operations", now=NOW)

    # Act & Assert
    with pytest.raises(StateError, match="confirmed business context"):
        assert_source_access(state)


def test_given_all_context_values_when_confirm_then_source_access_is_allowed() -> None:
    # Arrange
    state = create_state("service-operations", "Service Operations", now=NOW)
    values = {
        field: f"Confirmed {field}" for field in state["context"] if field != "status"}

    # Act
    result = update_context(
        state,
        values,
        confirm=True,
        confirmed_by="operator@example.com",
        now=NOW,
    )

    # Assert
    assert_source_access(result)
    assert result["context"]["status"] == "confirmed"
    assert result["gates"]["research"]["inputDigests"] == [
        context_digest(result)]


def test_given_valid_state_when_write_and_read_then_identity_is_preserved(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    state = create_state("service-operations", "Service Operations", now=NOW)

    # Act
    state_path = write_state_atomic(project_root, state)
    result = read_state(project_root, "service-operations")

    # Assert
    assert state_path == project_root / "state.json"
    assert result == state
    assert list(project_root.glob(".state-*.tmp")) == []


def test_given_invalid_persisted_json_when_read_then_state_is_rejected(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    project_root.mkdir()
    (project_root / "state.json").write_text("{invalid", encoding="utf-8")

    # Act & Assert
    with pytest.raises(StateError, match="Could not read trusted project state"):
        read_state(project_root, "service-operations")


def test_given_identity_mismatch_when_read_then_state_is_rejected(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    state = create_state("service-operations", "Service Operations", now=NOW)
    write_state_atomic(project_root, state)

    # Act & Assert
    with pytest.raises(StateError, match="identity does not match"):
        read_state(project_root, "different-project")


def test_given_unknown_schema_version_when_read_then_state_is_rejected(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    state = create_state("service-operations", "Service Operations", now=NOW)
    state["schemaVersion"] = "2.0.0"
    project_root.mkdir()
    (project_root / "state.json").write_text(json.dumps(state), encoding="utf-8")

    # Act & Assert
    with pytest.raises(StateError, match="Invalid state at schemaVersion"):
        read_state(project_root, "service-operations")


def test_given_traversal_when_resolve_descendant_then_path_is_rejected(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    project_root.mkdir()

    # Act & Assert
    with pytest.raises(PathBoundaryError, match="escapes project root"):
        resolve_descendant(project_root, Path("../outside.json"))


def test_given_symlink_escape_when_resolve_descendant_then_path_is_rejected(tmp_path: Path) -> None:
    # Arrange
    project_root = tmp_path / "project"
    outside = tmp_path / "outside"
    project_root.mkdir()
    outside.mkdir()
    (project_root / "linked").symlink_to(outside, target_is_directory=True)

    # Act & Assert
    with pytest.raises(PathBoundaryError, match="escapes project root"):
        resolve_descendant(project_root, Path("linked/state.json"))


def test_given_symlink_project_root_when_resolve_descendant_then_path_is_rejected(
    tmp_path: Path,
) -> None:
    # Arrange
    actual_root = tmp_path / "actual"
    linked_root = tmp_path / "linked"
    actual_root.mkdir()
    linked_root.symlink_to(actual_root, target_is_directory=True)

    # Act & Assert
    with pytest.raises(PathBoundaryError, match="Project root contains a symlink"):
        resolve_descendant(linked_root, Path("state.json"))


def test_given_invalid_slug_when_resolve_project_then_project_is_rejected(tmp_path: Path) -> None:
    # Act & Assert
    with pytest.raises(PathBoundaryError, match="Invalid project slug"):
        resolve_project_root(tmp_path, "../outside")


def test_given_gitignored_path_when_evaluate_then_path_is_ignored(tmp_path: Path) -> None:
    # Arrange
    subprocess.run(["git", "init", "--quiet", str(tmp_path)], check=True)
    (tmp_path / ".gitignore").write_text("ignored/\n", encoding="utf-8")
    ignored_path = tmp_path / "ignored" / "source.csv"
    ignored_path.parent.mkdir()
    ignored_path.touch()

    # Act
    result = is_ignored_path(tmp_path, ignored_path)

    # Assert
    assert result is True


def test_given_equivalent_gate_inputs_when_update_then_approval_remains_current() -> None:
    # Arrange
    state = create_state("service-operations", "Service Operations", now=NOW)
    state["gates"]["research"] = {
        "status": "approved",
        "approvalId": "approval:research-1",
        "inputDigests": [DIGEST_A],
        "downstreamInvalidated": False,
    }

    # Act
    result = update_gate_inputs(
        state,
        "research",
        [DIGEST_A],
        reason="Research evidence changed",
        now="2026-09-04T13:00:00Z",
    )

    # Assert
    assert result == state


@pytest.mark.parametrize(
    ("input_kind", "expected_stale"),
    [
        ("researchBrief", {"research", "design", "implement"}),
        ("designSpecification", {"design", "implement"}),
        ("namespacePolicy", {"design", "implement"}),
        ("mappingSpecification", {"design", "implement"}),
        ("ontologyPackage", {"implement"}),
        ("shapeInputs", {"implement"}),
    ],
)
def test_given_material_input_change_when_update_then_dependent_gates_are_stale(
    input_kind: str,
    expected_stale: set[str],
) -> None:
    # Arrange
    state = _all_gates_approved_state()

    # Act
    result = update_material_inputs(
        state,
        input_kind,
        [DIGEST_B],
        now="2026-09-04T13:00:00Z",
    )

    # Assert
    actual_stale = {
        gate_name
        for gate_name in ("research", "design", "implement")
        if result["gates"][gate_name]["status"] == "stale"
    }
    assert actual_stale == expected_stale


def test_given_changed_research_inputs_when_update_then_downstream_approvals_are_stale() -> None:
    # Arrange
    state_path = Path(
        __file__).parents[1] / "assets" / "schemas" / "examples" / "state.valid.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    state["phase"] = "implement"
    state["gates"]["research"] = _approved_gate("approval:research-1")
    state["gates"]["design"] = _approved_gate("approval:design-1")
    state["approvals"] = [
        _approval("approval:research-1", "research"),
        _approval("approval:design-1", "design"),
    ]
    validate_state(state)

    # Act
    result = update_gate_inputs(
        state,
        "research",
        [DIGEST_B],
        reason="Research evidence changed",
        now="2026-09-04T13:00:00Z",
    )

    # Assert
    validate_state(result)
    assert result["phase"] == "research"
    assert result["gates"]["research"]["status"] == "stale"
    assert result["gates"]["design"]["status"] == "stale"
    assert [approval["status"]
            for approval in result["approvals"]] == ["stale", "stale"]


def test_given_confirmed_context_edit_when_update_then_sources_are_invalidated() -> None:
    # Arrange
    state_path = Path(
        __file__).parents[1] / "assets" / "schemas" / "examples" / "state.valid.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    state["sourceInventory"] = [
        {
            "id": "source:file-1",
            "kind": "file",
            "displayPath": "sources/input.csv",
            "status": "supported",
            "adapter": "csv",
            "sha256": DIGEST_A,
            "limitations": [],
        }
    ]
    state["gates"]["research"] = _approved_gate("approval:research-1")
    state["approvals"] = [_approval("approval:research-1", "research")]

    # Act
    result = update_context(
        state,
        {"ontologyPurpose": "A changed purpose"},
        now="2026-09-04T13:00:00Z",
    )

    # Assert
    assert result["context"]["status"] == "pending"
    assert result["sourceInventory"] == []
    assert result["gates"]["research"]["status"] == "stale"
    assert result["approvals"][0]["status"] == "stale"


def test_given_changed_design_inputs_when_resume_then_design_is_earliest_gate() -> None:
    # Arrange
    state = _all_gates_approved_state()

    # Act
    result, gate_name = resume_state(
        state,
        {"research": [DIGEST_A], "design": [
            DIGEST_B], "implement": [DIGEST_A]},
        now="2026-09-04T13:00:00Z",
    )

    # Assert
    assert gate_name == "design"
    assert earliest_resumable_gate(result) == "design"


def test_given_pending_research_when_transition_to_design_then_state_is_rejected() -> None:
    # Arrange
    state = create_state("service-operations", "Service Operations", now=NOW)

    # Act & Assert
    with pytest.raises(StateError, match="Invalid state"):
        transition_phase(state, "design", now="2026-09-04T13:00:00Z")


def test_given_report_regeneration_when_replace_then_gates_are_unchanged() -> None:
    # Arrange
    state = _all_gates_approved_state()
    gates = json.loads(json.dumps(state["gates"]))
    reports = [
        {
            "id": "report:syntax-1",
            "kind": "syntax",
            "status": "passed",
            "path": "reports/syntax.json",
            "generatedAt": "2026-09-04T13:00:00Z",
        }
    ]

    # Act
    result = replace_reports(state, reports, now="2026-09-04T13:00:00Z")

    # Assert
    assert result["gates"] == gates


def _approved_gate(approval_id: str) -> dict[str, object]:
    return {
        "status": "approved",
        "approvalId": approval_id,
        "inputDigests": [DIGEST_A],
        "downstreamInvalidated": False,
    }


def _all_gates_approved_state() -> dict[str, object]:
    state = create_state("service-operations", "Service Operations", now=NOW)
    for gate_name in ("research", "design", "implement"):
        state["gates"][gate_name] = _approved_gate(f"approval:{gate_name}-1")
    state["phase"] = "implement"
    validate_state(state)
    return state


def _approval(approval_id: str, gate: str) -> dict[str, object]:
    return {
        "id": approval_id,
        "gate": gate,
        "status": "approved",
        "approver": {"contributor": "operator@example.com", "role": "owner"},
        "rationale": "Approved for testing.",
        "decidedAt": NOW,
        "inputDigests": [DIGEST_A],
    }
