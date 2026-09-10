#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate synthetic-data operation records and commit one local replacement."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import shutil
import sys
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import Any, Literal

from jsonschema import Draft202012Validator

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
MAX_INPUT_BYTES = 2 * 1024 * 1024

FaultPoint = Literal[
    "predecessor",
    "staged-validation",
    "target-change",
    "before-replace",
]


class OperationError(ValueError):
    """A categorized failure that is safe to report without source values."""

    def __init__(
        self,
        category: str,
        exit_code: int = EXIT_FAILURE,
        *,
        categories: Sequence[str] | None = None,
        digests: dict[str, str] | None = None,
    ) -> None:
        super().__init__(category)
        self.category = category
        self.categories = tuple(categories or (category,))
        self.digests = digests or {}
        self.exit_code = exit_code


def _skill_root() -> Path:
    """Return the skill root containing the schema."""
    return Path(__file__).resolve().parent.parent


def load_schema(skill_root: Path | None = None) -> dict[str, Any]:
    """Load the bundled operation schema."""
    root = skill_root or _skill_root()
    try:
        return json.loads(
            (root / "assets" / "synthetic-data-operation-v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise OperationError("schema-configuration-error", EXIT_ERROR) from error


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Build a JSON object while rejecting duplicate keys."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise OperationError("duplicate-json-key", EXIT_ERROR)
        result[key] = value
    return result


def read_record(path: Path) -> dict[str, Any]:
    """Read one size-bounded JSON object."""
    try:
        if path.stat().st_size > MAX_INPUT_BYTES:
            raise OperationError("input-too-large", EXIT_ERROR)
        value = json.loads(
            path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object
        )
    except OperationError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise OperationError("record-read-error", EXIT_ERROR) from error
    if not isinstance(value, dict):
        raise OperationError("record-not-object", EXIT_ERROR)
    return value


def sha256_file(path: Path) -> str:
    """Return a prefixed SHA-256 digest for one file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _successor_revision(result: dict[str, Any], target_digest: str) -> str:
    """Return a bounded deterministic identity for the committed result revision."""
    material = f"{result['record_revision']}\n{target_digest}".encode()
    return f"committed:{hashlib.sha256(material).hexdigest()}"


def _structural_errors(record: dict[str, Any], schema: dict[str, Any]) -> set[str]:
    """Return stable categories for schema violations."""
    validator = Draft202012Validator(schema)
    return {"schema-invalid"} if next(validator.iter_errors(record), None) else set()


def _decision_errors(
    decision: dict[str, Any], required_roles: set[str], *, must_apply: bool
) -> set[str]:
    """Validate one qualified decision reference without reading policy values."""
    errors: set[str] = set()
    if decision["review_state"] != "approved":
        errors.add("decision-not-approved")
    if decision["status"] != "current":
        errors.add("decision-not-current")
    if must_apply and decision["applicability"] != "applicable":
        errors.add("decision-not-applicable")
    if not required_roles.issubset(decision["owner_roles"]):
        errors.add("decision-owner-role-missing")
    return errors


def _lineage_errors(entries: list[dict[str, Any]]) -> set[str]:
    """Validate field identity and transformation-reference conditions."""
    errors: set[str] = set()
    fields = [entry["output_field"] for entry in entries]
    if len(fields) != len(set(fields)):
        errors.add("lineage-output-field-duplicate")
    for entry in entries:
        needs_transform = entry["disposition"] in {"transformed", "derived"}
        if needs_transform != (entry["transformation_ref"] is not None):
            errors.add("lineage-transformation-invalid")
    return errors


def _preflight_errors(preflight: dict[str, Any]) -> set[str]:
    """Return semantic categories for a structurally valid preflight."""
    errors = _lineage_errors(preflight["field_lineage"])
    decisions = preflight["decision_refs"]
    errors |= _decision_errors(
        decisions["classification"], {"data-owner"}, must_apply=True
    )

    protected_active = (
        decisions["protected_attributes"]["applicability"] == "applicable"
    )
    errors |= _decision_errors(
        decisions["protected_attributes"],
        {"privacy-owner", "rai-fairness-owner", "domain-owner"}
        if protected_active
        else set(),
        must_apply=protected_active,
    )

    subgroup_active = decisions["subgroup_evaluation"]["applicability"] == "applicable"
    errors |= _decision_errors(
        decisions["subgroup_evaluation"],
        {"rai-fairness-owner", "domain-owner"} if subgroup_active else set(),
        must_apply=subgroup_active,
    )
    if subgroup_active and not preflight["activated_subgroups"]:
        errors.add("activated-subgroup-missing")
    if not subgroup_active and preflight["activated_subgroups"]:
        errors.add("inactive-subgroup-declared")

    replacement_active = preflight["mode"] == "replace-local"
    errors |= _decision_errors(
        decisions["replacement_authority"],
        {"data-owner"} if replacement_active else set(),
        must_apply=replacement_active,
    )
    if replacement_active and preflight["source"]["expected_digest"] is None:
        errors.add("replacement-digest-missing")
    if preflight["gate"]["state"] != "passed":
        errors.add("gate-blocked")
    return errors


def _result_errors(
    preflight: dict[str, Any], result: dict[str, Any], *, for_commit: bool
) -> set[str]:
    """Return linkage, evidence, and state errors for a result record."""
    errors = _lineage_errors(result["field_lineage"])
    if result["operation_id"] != preflight["operation_id"]:
        errors.add("result-operation-mismatch")
    if result["preflight_revision"] != preflight["record_revision"]:
        errors.add("result-preflight-mismatch")
    if result["mode"] != preflight["mode"]:
        errors.add("result-mode-mismatch")
    if result["source_reference"] != preflight["source"]["reference"]:
        errors.add("result-source-mismatch")

    expected_digest = preflight["source"]["expected_digest"]
    if (
        expected_digest is not None
        and result["observed_source_digest"] != expected_digest
    ):
        errors.add("source-digest-mismatch")

    activated = set(preflight["activated_subgroups"])
    reported = [entry["reference"] for entry in result["subgroup_results"]]
    if len(reported) != len(set(reported)):
        errors.add("subgroup-result-duplicate")
    if activated != set(reported):
        errors.add("subgroup-result-incomplete")
    if activated and any(
        entry["state"] == "not-applicable" for entry in result["subgroup_results"]
    ):
        errors.add("activated-subgroup-not-applicable")

    commit = result["commit"]
    if result["mode"] == "replace-local":
        legal_states = {
            ("not-attempted", "unchanged-original"),
            ("failed", "unchanged-original"),
            ("committed", "rollback-available"),
        }
    else:
        legal_states = {
            ("not-attempted", "not-applicable"),
            ("committed", "committed-new-output"),
        }
    if (commit["state"], commit["evidence_state"]) not in legal_states:
        errors.add("commit-state-invalid")
    if commit["state"] == "committed":
        if result["previous_result_revision"] is None:
            errors.add("committed-result-link-missing")
        if any(
            commit[field] is None
            for field in ("target_digest", "predecessor_ref", "predecessor_digest")
        ):
            errors.add("committed-evidence-missing")
    elif result["previous_result_revision"] is not None:
        errors.add("result-link-invalid")

    if for_commit:
        if result["mode"] != "replace-local":
            errors.add("commit-mode-unsupported")
        if commit["state"] != "not-attempted":
            errors.add("commit-state-not-ready")
        if any(entry["state"] != "passed" for entry in result["validation_evidence"]):
            errors.add("validation-not-passed")
    return errors


def validate_operation(
    preflight: dict[str, Any],
    result: dict[str, Any] | None = None,
    *,
    schema: dict[str, Any] | None = None,
    for_commit: bool = False,
) -> list[str]:
    """Return sorted stable validation categories for one operation."""
    contract_schema = schema or load_schema()
    errors = _structural_errors(preflight, contract_schema)
    if errors or preflight.get("record_type") != "preflight":
        return sorted(errors | {"preflight-invalid"})
    errors |= _preflight_errors(preflight)
    if result is not None:
        result_structure = _structural_errors(result, contract_schema)
        if result_structure or result.get("record_type") != "result":
            errors |= result_structure | {"result-invalid"}
        else:
            errors |= _result_errors(preflight, result, for_commit=for_commit)
    elif for_commit:
        errors.add("result-required")
    return sorted(errors)


def _contained_regular_file(path: Path, root: Path, category: str) -> Path:
    """Resolve one non-link regular file beneath an approved root."""
    try:
        resolved_root = root.resolve(strict=True)
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise OperationError(category) from error
    if not resolved.is_relative_to(resolved_root):
        raise OperationError(category)
    if path.is_symlink() or not resolved.is_file():
        raise OperationError(category)
    return resolved


def _contained_new_file(path: Path, root: Path, category: str) -> Path:
    """Resolve a not-yet-created file beneath an approved root."""
    try:
        resolved_root = root.resolve(strict=True)
        resolved_parent = path.parent.resolve(strict=True)
    except OSError as error:
        raise OperationError(category) from error
    if not resolved_parent.is_relative_to(resolved_root) or path.exists():
        raise OperationError(category)
    return resolved_parent / path.name


def _write_predecessor(source: Path, predecessor: Path) -> None:
    """Create and synchronize a recoverable predecessor without overwriting one."""
    with source.open("rb") as source_stream, predecessor.open("xb") as output:
        shutil.copyfileobj(source_stream, output)
        output.flush()
        os.fsync(output.fileno())


def commit_local(
    preflight: dict[str, Any],
    result: dict[str, Any],
    candidate: Path,
    target: Path,
    approved_root: Path,
    final_result_path: Path,
    *,
    fault_at: FaultPoint | None = None,
) -> dict[str, Any]:
    """Commit one validated candidate to one local target."""
    categories = validate_operation(preflight, result, for_commit=True)
    if categories:
        raise OperationError(categories[0])

    resolved_target = _contained_regular_file(target, approved_root, "target-invalid")
    resolved_candidate = _contained_regular_file(
        candidate, approved_root, "candidate-invalid"
    )
    resolved_final_result = _contained_new_file(
        final_result_path, approved_root, "final-result-invalid"
    )
    if resolved_candidate == resolved_target:
        raise OperationError("candidate-is-target")

    before_digest = sha256_file(resolved_target)
    expected_digest = preflight["source"]["expected_digest"]
    if before_digest != expected_digest:
        raise OperationError(
            "source-digest-mismatch",
            categories=("source-digest-mismatch", "unchanged-original"),
            digests={"original": before_digest, "current": before_digest},
        )
    candidate_digest = sha256_file(resolved_candidate)
    if candidate_digest != result["output_digest"]:
        raise OperationError(
            "candidate-digest-mismatch",
            categories=("candidate-digest-mismatch", "unchanged-original"),
            digests={"original": before_digest, "current": before_digest},
        )

    predecessor = resolved_target.with_name(
        f".{resolved_target.name}.{preflight['operation_id']}.previous"
    )
    staged: Path | None = None
    try:
        if fault_at == "predecessor":
            raise OSError("injected predecessor failure")
        _write_predecessor(resolved_target, predecessor)

        descriptor, staged_name = tempfile.mkstemp(
            prefix=f".{resolved_target.name}.",
            suffix=".staged",
            dir=resolved_target.parent,
        )
        staged = Path(staged_name)
        with (
            os.fdopen(descriptor, "wb") as output,
            resolved_candidate.open("rb") as source,
        ):
            shutil.copyfileobj(source, output)
            output.flush()
            os.fsync(output.fileno())
        if fault_at == "staged-validation" or sha256_file(staged) != candidate_digest:
            raise OperationError("staged-validation-failed")
        if fault_at == "target-change":
            resolved_target.write_bytes(b"external-change")
        current_digest = sha256_file(resolved_target)
        predecessor_digest = sha256_file(predecessor)
        if current_digest != expected_digest or predecessor_digest != expected_digest:
            raise OperationError(
                "source-digest-mismatch",
                categories=("source-digest-mismatch", "external-change-preserved"),
                digests={"approved": expected_digest, "current": current_digest},
            )
        if fault_at == "before-replace":
            raise OperationError("commit-interrupted")
        os.replace(staged, resolved_target)
        staged = None
    except OperationError as error:
        if "external-change-preserved" in error.categories:
            raise
        if sha256_file(resolved_target) != before_digest:
            raise OperationError("original-changed-unexpectedly") from error
        raise OperationError(
            error.category,
            categories=(error.category, "unchanged-original"),
            digests={"original": before_digest, "current": before_digest},
        ) from error
    except OSError as error:
        if sha256_file(resolved_target) != before_digest:
            raise OperationError("original-changed-unexpectedly") from error
        raise OperationError(
            "commit-io-failed",
            categories=("commit-io-failed", "unchanged-original"),
            digests={"original": before_digest, "current": before_digest},
        ) from error
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)

    target_digest = sha256_file(resolved_target)
    predecessor_digest = sha256_file(predecessor)
    final_result = copy.deepcopy(result)
    final_result["previous_result_revision"] = result["record_revision"]
    final_result["record_revision"] = _successor_revision(result, target_digest)
    final_result["commit"] = {
        "state": "committed",
        "target_digest": target_digest,
        "predecessor_ref": predecessor.name,
        "predecessor_digest": predecessor_digest,
        "evidence_state": "rollback-available",
    }
    final_errors = validate_operation(preflight, final_result)
    if final_errors:
        raise OperationError(
            "commit-evidence-invalid",
            categories=("commit-evidence-invalid", "rollback-available"),
            digests={"predecessor": predecessor_digest, "target": target_digest},
        )
    temporary_result = resolved_final_result.with_suffix(
        resolved_final_result.suffix + ".tmp"
    )
    try:
        with temporary_result.open("x", encoding="utf-8") as output:
            json.dump(final_result, output, indent=2, sort_keys=True)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary_result, resolved_final_result)
    except OSError as error:
        temporary_result.unlink(missing_ok=True)
        raise OperationError(
            "commit-evidence-write-failed",
            categories=("commit-evidence-write-failed", "rollback-available"),
            digests={"predecessor": predecessor_digest, "target": target_digest},
        ) from error

    return {
        "status": "committed",
        "record_identity": {
            "operation_id": preflight["operation_id"],
            "preflight_revision": preflight["record_revision"],
            "result_revision": final_result["record_revision"],
            "final_result": resolved_final_result.name,
        },
        "categories": [],
        "counts": {"targets": 1, "errors": 0},
        "digests": {
            "original": before_digest,
            "predecessor": predecessor_digest,
            "target": target_digest,
        },
    }


def _summary(
    status: str,
    preflight: dict[str, Any] | None,
    categories: Sequence[str],
    digests: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Build a sanitized command summary."""
    identity = {}
    if preflight:
        identity = {
            "operation_id": preflight.get("operation_id"),
            "preflight_revision": preflight.get("record_revision"),
        }
    return {
        "status": status,
        "record_identity": identity,
        "categories": list(categories),
        "counts": {"errors": len(categories)},
        "digests": digests or {},
    }


class JsonArgumentParser(argparse.ArgumentParser):
    """Argument parser that reports invocation failures through JSON."""

    def error(self, message: str) -> None:
        raise OperationError("invocation-error", EXIT_ERROR)

    def print_help(self, file: Any = None) -> None:
        """Suppress argparse prose so every CLI response remains JSON."""

    def exit(self, status: int = 0, message: str | None = None) -> None:
        category = "help-requested" if status == EXIT_SUCCESS else "invocation-error"
        raise OperationError(category, status if status else EXIT_SUCCESS)


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = JsonArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate")
    validate.add_argument("--preflight", type=Path, required=True)
    validate.add_argument("--result", type=Path)
    commit = commands.add_parser("commit-local")
    commit.add_argument("--preflight", type=Path, required=True)
    commit.add_argument("--result", type=Path, required=True)
    commit.add_argument("--candidate", type=Path, required=True)
    commit.add_argument("--target", type=Path, required=True)
    commit.add_argument("--approved-root", type=Path, required=True)
    commit.add_argument("--final-result", type=Path, required=True)
    return parser


def run(arguments: argparse.Namespace) -> int:
    """Run one parsed command and print a sanitized JSON summary."""
    preflight: dict[str, Any] | None = None
    try:
        preflight = read_record(arguments.preflight)
        result = read_record(arguments.result) if arguments.result else None
        if arguments.command == "validate":
            categories = validate_operation(preflight, result)
            status = "valid" if not categories else "blocked"
            print(json.dumps(_summary(status, preflight, categories), sort_keys=True))
            return EXIT_SUCCESS if not categories else EXIT_FAILURE
        if result is None:
            raise OperationError("result-required", EXIT_ERROR)
        summary = commit_local(
            preflight,
            result,
            arguments.candidate,
            arguments.target,
            arguments.approved_root,
            arguments.final_result,
        )
        print(json.dumps(summary, sort_keys=True))
        return EXIT_SUCCESS
    except OperationError as error:
        print(
            json.dumps(
                _summary("error", preflight, error.categories, error.digests),
                sort_keys=True,
            )
        )
        return error.exit_code


def main() -> int:
    """Run the synthetic-data operation CLI."""
    try:
        arguments = create_parser().parse_args()
        return run(arguments)
    except OperationError as error:
        status = "valid" if error.exit_code == EXIT_SUCCESS else "error"
        print(json.dumps(_summary(status, None, error.categories), sort_keys=True))
        return error.exit_code
    except Exception:
        print(
            json.dumps(_summary("error", None, ["unexpected-error"]), sort_keys=True)
        )
        return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
