# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Translate runtime probe results into a Design Intent verification artifact.

A Design Intent Record is human-authored, committed source that states what a
surface must convey and names the check that settles each claim. The runtime
harness reports findings per criterion. Neither knows about the other. This
module joins them and emits the verification sidecar the design-intent contract
defines, so that a declared intent becomes something a build can check.

The adapter never reads or writes human-authored content. It computes the
digest of the record it describes so a consumer can detect that results have
gone stale against a record that changed after the run.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import stat
from datetime import datetime, timezone
from importlib.resources import files
from pathlib import Path
from typing import Any, Iterable

import jsonschema
import yaml
from yaml.constructor import ConstructorError

from runtime_a11y._errors import EXIT_USAGE, ScriptError

SCHEMA_VERSION = "1.1"
ASSERTED_BY = "runtime_a11y intent adapter"

# EARL-derived outcome vocabulary, ordered worst first. An expectation is one
# claim over one or more criteria, so the worst criterion outcome governs.
_OUTCOME_PRECEDENCE = ("failed", "cantTell", "passed")

_STATUS_TO_OUTCOME = {
    "pass": "passed",
    "fail": "failed",
    "candidate": "cantTell",
    # A partial probe settled some but not all of what it examined. It is
    # evidence without a verdict, so it maps to cantTell explicitly rather
    # than reaching the default and looking like a deliberate mapping.
    "partial": "cantTell",
}

_CUSTOM_ASSERT = "custom"
_AXE_PROBE_ID = "probe-axe"
_AXE_METHOD = "axe-auto"
_RUNTIME_METHOD = "runtime-automation"


class _UniqueKeySafeLoader(yaml.SafeLoader):
    """Safe YAML loader that rejects duplicate mapping keys."""


def _construct_unique_mapping(
    loader: _UniqueKeySafeLoader,
    node: yaml.MappingNode,
    deep: bool = False,
) -> dict[Any, Any]:
    """Construct one mapping, failing closed on a duplicate key."""
    mapping: dict[Any, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ConstructorError(
                "while constructing a mapping",
                node.start_mark,
                f"found duplicate key {key!r}",
                key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


_UniqueKeySafeLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_unique_mapping,
)


def _load_authored_schema() -> dict[str, Any]:
    """Load the generated packaged copy of the authored-record schema."""
    schema_path = files("runtime_a11y").joinpath("design-intent.schema.json")
    try:
        payload = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ScriptError(
            "Packaged Design Intent authored schema is missing or invalid",
            EXIT_USAGE,
        ) from exc
    if not isinstance(payload, dict):
        raise ScriptError(
            "Packaged Design Intent authored schema must be a JSON object",
            EXIT_USAGE,
        )
    return payload


def compute_intent_digest(raw_text: str) -> str:
    """Return the contract digest for an authored record's raw text.

    Line endings are normalized to LF so a CRLF checkout does not report false
    staleness. Callers must pass BOM-stripped text.
    """
    normalized = raw_text.replace("\r\n", "\n")
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def read_record_text(record_path: Path) -> str:
    """Read an authored record as text, stripping any byte-order mark."""
    try:
        return record_path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise ScriptError(
            f"Design intent record is unreadable: {record_path}", EXIT_USAGE
        ) from exc


def parse_record(
    raw_text: str,
    record_path: Path,
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Parse and validate an authored Design Intent Record."""
    try:
        record = yaml.load(raw_text, Loader=_UniqueKeySafeLoader)
    except yaml.YAMLError as exc:
        raise ScriptError(
            f"Design intent record is not valid YAML: {record_path}: {exc}"
        ) from exc
    if not isinstance(record, dict):
        raise ScriptError(
            f"Design intent record must parse to a mapping: {record_path}"
        )
    try:
        jsonschema.Draft202012Validator(_load_authored_schema()).validate(record)
    except jsonschema.ValidationError as exc:
        location = ".".join(str(part) for part in exc.absolute_path) or "<root>"
        raise ScriptError(
            f"Design intent record violates the authored schema at "
            f"{location}: {exc.message}",
            EXIT_USAGE,
        ) from exc
    _validate_record_semantics(record, record_path, config)
    return record


def _validate_calendar_date(value: str, label: str) -> None:
    """Reject an ISO-looking date that is not a real calendar date."""
    try:
        datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise ScriptError(f"{label} '{value}' is not a real calendar date") from exc


def _load_probe_adequacy() -> dict[str, dict[str, set[tuple[str, str, str]]]]:
    """Load the packaged probe adequacy map into deciding/informing sets."""
    map_path = files("runtime_a11y").joinpath("probe-criteria-map.json")
    payload = json.loads(map_path.read_text(encoding="utf-8"))
    adequacy: dict[str, dict[str, set[tuple[str, str, str]]]] = {}
    for probe in payload.get("probes", []):
        probe_id = str(probe.get("probeId", ""))
        entry = {"decides": set(), "informs": set()}
        for relation in ("decides", "informs"):
            for item in probe.get(relation, []):
                for state in item.get("states", []):
                    entry[relation].add(
                        (
                            str(item.get("framework", "")),
                            str(item.get("criterionId", "")),
                            str(state),
                        )
                    )
        adequacy[probe_id] = entry
    return adequacy


def _surface_states(config: dict[str, Any]) -> dict[str, set[str]]:
    """Project one runtime config into a surface-to-state lookup."""
    return {
        str(surface["id"]): {str(state["state"]) for state in surface.get("states", [])}
        for surface in config.get("surfaces", [])
        if isinstance(surface, dict) and surface.get("id")
    }


def _validate_record_semantics(
    record: dict[str, Any],
    record_path: Path,
    config: dict[str, Any] | None,
) -> None:
    """Apply authored-record rules not fully expressed by JSON Schema."""
    surface_id = str(record["surfaceId"])
    stem = record_path.name.removesuffix(".intent.yaml")
    if stem != surface_id:
        raise ScriptError(
            f"Record surfaceId '{surface_id}' does not match filename "
            f"'{record_path.name}'"
        )

    _validate_calendar_date(str(record["decidedOn"]), "decidedOn")
    surfaces = _surface_states(config) if config is not None else None
    if surfaces is not None and surface_id not in surfaces:
        raise ScriptError(
            f"Record surfaceId '{surface_id}' is not declared in the runtime config"
        )
    adequacy = _load_probe_adequacy()
    intent_ids: set[str] = set()
    expectation_ids: set[str] = set()
    for intent in record["intents"]:
        intent_id = str(intent["id"])
        if intent_id in intent_ids:
            raise ScriptError(f"Duplicate intent id '{intent_id}'")
        intent_ids.add(intent_id)
        state = str(intent["binding"]["state"])
        if (
            surfaces is not None
            and state != "default"
            and state not in surfaces[surface_id]
        ):
            raise ScriptError(
                f"Intent '{intent_id}' binds undeclared state '{state}' for "
                f"surface '{surface_id}'"
            )
        for expectation in intent["expectations"]:
            expectation_id = str(expectation["id"])
            if expectation_id in expectation_ids:
                raise ScriptError(f"Duplicate expectation id '{expectation_id}'")
            expectation_ids.add(expectation_id)
            _validate_expectation_semantics(expectation, intent_id, state, adequacy)


def _validate_expectation_semantics(
    expectation: dict[str, Any],
    intent_id: str,
    state: str,
    adequacy: dict[str, dict[str, set[tuple[str, str, str]]]],
) -> None:
    """Validate method pairing and override date semantics."""
    expectation_id = str(expectation["id"])
    assert_id = str(expectation["assert"])
    method = str(expectation["method"])
    if assert_id == _AXE_PROBE_ID and method != _AXE_METHOD:
        raise ScriptError(
            f"Expectation '{expectation_id}' in intent '{intent_id}' asserts "
            f"'{assert_id}', which requires method '{_AXE_METHOD}'"
        )
    if assert_id not in {_CUSTOM_ASSERT, _AXE_PROBE_ID} and method != _RUNTIME_METHOD:
        raise ScriptError(
            f"Expectation '{expectation_id}' in intent '{intent_id}' asserts "
            f"'{assert_id}', which requires method '{_RUNTIME_METHOD}'"
        )
    override = expectation.get("override")
    if isinstance(override, dict):
        _validate_calendar_date(
            str(override["reviewedOn"]),
            f"Expectation '{expectation_id}' override.reviewedOn",
        )
    if assert_id == _CUSTOM_ASSERT:
        return
    if assert_id not in adequacy:
        raise ScriptError(
            f"Expectation '{expectation_id}' in intent '{intent_id}' asserts "
            f"unknown probe '{assert_id}'"
        )
    requires_deciding = expectation["role"] == "decides" or expectation["blocking"]
    for reference in expectation["criteria"]:
        framework, criterion = split_criterion_reference(str(reference))
        key = (framework, criterion, state)
        probe = adequacy[assert_id]
        if requires_deciding and key not in probe["decides"]:
            raise ScriptError(
                f"Expectation '{expectation_id}' in intent '{intent_id}' claims "
                f"a deciding result that probe '{assert_id}' does not provide "
                f"for '{reference}' in state '{state}'"
            )
        if (
            not requires_deciding
            and key not in probe["decides"]
            and key not in probe["informs"]
        ):
            raise ScriptError(
                f"Expectation '{expectation_id}' in intent '{intent_id}' "
                f"references unsupported criterion '{reference}' for probe "
                f"'{assert_id}' in state '{state}'"
            )


def load_results(results_path: Path) -> dict[str, Any]:
    """Load a harness results document, requiring a JSON object at the root."""
    try:
        payload = json.loads(results_path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ScriptError(
            f"Results document is unreadable: {results_path}", EXIT_USAGE
        ) from exc
    except json.JSONDecodeError as exc:
        raise ScriptError(
            f"Results document is not valid JSON: {results_path}"
        ) from exc
    if not isinstance(payload, dict):
        raise ScriptError(f"Results document must be a JSON object: {results_path}")
    if payload.get("quarantined") is True or "operationalFailure" in payload:
        raise ScriptError(
            "Results document is incomplete or quarantined and cannot be used "
            f"for Design Intent verification: {results_path}",
            EXIT_USAGE,
        )
    return payload


def split_criterion_reference(reference: str) -> tuple[str, str]:
    """Split a 'framework:criterionId' reference on its FIRST colon.

    Criterion ids may themselves contain colons, so only the leading segment is
    the framework. Splitting on every colon would silently drop a framework.
    """
    framework, separator, criterion = reference.partition(":")
    if not separator or not framework or not criterion:
        raise ScriptError(
            f"Criterion reference must be 'framework:criterionId': {reference}"
        )
    return framework, criterion


def _matching_rows(
    rows: Iterable[dict[str, Any]],
    surface_id: str,
    state: str,
    probe_id: str,
    criteria: set[tuple[str, str]],
) -> list[dict[str, Any]]:
    """Select result rows that answer one expectation."""
    matches = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("surfaceId") != surface_id or row.get("state") != state:
            continue
        if row.get("probeId") != probe_id:
            continue
        key = (str(row.get("framework", "")), str(row.get("criterionId", "")))
        if key in criteria:
            matches.append(row)
    return matches


def _worst_outcome(rows: list[dict[str, Any]]) -> str:
    """Reduce matched rows to one outcome, worst result winning."""
    outcomes = {
        _STATUS_TO_OUTCOME.get(str(row.get("status", "")), "cantTell") for row in rows
    }
    for candidate in _OUTCOME_PRECEDENCE:
        if candidate in outcomes:
            return candidate
    return "cantTell"


def build_assertions(
    record: dict[str, Any], results: dict[str, Any]
) -> list[dict[str, Any]]:
    """Build exactly one assertion per authored expectation.

    An expectation the run did not cover reports 'untested' rather than being
    omitted, so a missing check is visible instead of silently absent.
    """
    surface_id = str(record.get("surfaceId", ""))
    rows = results.get("results")
    rows = rows if isinstance(rows, list) else []

    assertions: list[dict[str, Any]] = []
    for intent in _iter_intents(record):
        intent_id = intent.get("id")
        binding = intent.get("binding")
        if binding is not None and not isinstance(binding, dict):
            raise ScriptError(
                f"Intent '{intent_id}' binding must be a mapping, got "
                f"{type(binding).__name__}"
            )
        state = str((binding or {}).get("state", "default"))
        for expectation in _iter_expectations(intent):
            # Validate the blocking flag before anything is written. Deferring
            # it to evaluate_blocking would raise only after the artifact
            # exists, leaving a misleading file behind.
            is_blocking(expectation)
            assertion = _build_assertion(
                intent_id, expectation, surface_id, state, rows
            )
            assertions.append(_with_override_fields(assertion, expectation))
    return assertions


_CONCLUSIVE_OUTCOMES = frozenset({"passed", "failed"})


def _with_override_fields(
    assertion: dict[str, Any], expectation: dict[str, Any]
) -> dict[str, Any]:
    """Add the contract's effective outcome and conflict flag to one assertion.

    'outcome' stays the observed probe result and is never overwritten, so the
    artifact keeps saying what the run actually saw. 'effectiveOutcome' carries
    the authored override when present, matching the outcome the gate applies.

    'overrideConflict' is true only when observation and override are each
    conclusive and disagree. An override that settles an untested, cantTell, or
    inapplicable expectation is the documented use, not a conflict, so flagging
    it would train consumers to ignore the signal.
    """
    observed = assertion["outcome"]
    effective = _effective_outcome(expectation, observed)
    override = expectation.get("override")
    authored = override.get("outcome") if isinstance(override, dict) else None
    assertion["effectiveOutcome"] = effective
    assertion["overrideConflict"] = (
        observed in _CONCLUSIVE_OUTCOMES
        and authored in _CONCLUSIVE_OUTCOMES
        and observed != authored
    )
    return assertion


def _iter_intents(record: dict[str, Any]) -> list[dict[str, Any]]:
    """Return the record's intents, rejecting a malformed nested shape.

    A record whose 'intents' is a list of strings would otherwise raise
    AttributeError deep in the walk. Failing here reports the documented
    typed error with the offending shape named.
    """
    intents = record.get("intents")
    if intents is None:
        return []
    if not isinstance(intents, list):
        raise ScriptError(
            f"Record 'intents' must be a list, got {type(intents).__name__}"
        )
    for entry in intents:
        if not isinstance(entry, dict):
            raise ScriptError(
                f"Each intent must be a mapping, got {type(entry).__name__}"
            )
    return intents


def _iter_expectations(intent: dict[str, Any]) -> list[dict[str, Any]]:
    """Return one intent's expectations, rejecting a malformed nested shape."""
    expectations = intent.get("expectations")
    if expectations is None:
        return []
    if not isinstance(expectations, list):
        raise ScriptError(
            f"Intent '{intent.get('id')}' expectations must be a list, got "
            f"{type(expectations).__name__}"
        )
    for entry in expectations:
        if not isinstance(entry, dict):
            raise ScriptError(
                f"Each expectation of intent '{intent.get('id')}' must be a "
                f"mapping, got {type(entry).__name__}"
            )
    return expectations


def is_blocking(expectation: dict[str, Any]) -> bool:
    """Return one expectation's blocking flag, rejecting a non-boolean value.

    A quoted 'true' is not a boolean. Coercing it would silently disable the
    gate for an expectation the author marked blocking, so it fails closed.
    """
    blocking = expectation.get("blocking", False)
    if blocking is None:
        return False
    if not isinstance(blocking, bool):
        raise ScriptError(
            f"Expectation '{expectation.get('id')}' has a non-boolean "
            f"'blocking' value {blocking!r}; use an unquoted true or false"
        )
    return blocking


def _build_assertion(
    intent_id: Any,
    expectation: dict[str, Any],
    surface_id: str,
    state: str,
    rows: list[dict[str, Any]],
) -> dict[str, Any]:
    """Resolve one authored expectation against the run's result rows."""
    expectation_id = expectation.get("id")
    assert_id = str(expectation.get("assert", ""))

    if assert_id == _CUSTOM_ASSERT:
        # A custom assertion has no runtime probe, so its observed outcome is
        # untested. Informational custom assertions do not gate. A deciding
        # custom assertion may be settled only by its authored override.
        return {
            "intentId": intent_id,
            "expectationId": expectation_id,
            "outcome": "untested",
            "mode": "manual",
            "pointer": None,
            "info": (
                "Custom assertion has no registered runtime implementation; "
                "resolve it through human review."
            ),
        }

    criteria = {
        split_criterion_reference(str(reference))
        for reference in expectation.get("criteria") or []
    }
    matches = _matching_rows(rows, surface_id, state, assert_id, criteria)

    if not matches:
        return {
            "intentId": intent_id,
            "expectationId": expectation_id,
            "outcome": "untested",
            "mode": "automatic",
            "pointer": None,
            "info": (
                f"No result row for probe '{assert_id}' on surface "
                f"'{surface_id}' state '{state}' matched this expectation's "
                "criteria."
            ),
        }

    outcome = _worst_outcome(matches)
    covered = {
        (str(row.get("framework", "")), str(row.get("criterionId", "")))
        for row in matches
    }
    uncovered = criteria - covered
    info = None
    if uncovered:
        # Some declared criterion was never evaluated. The expectation is one
        # claim over all of its criteria, so an unevaluated criterion means the
        # claim is unsettled no matter how the evaluated ones resolved. Without
        # this, a partially covered expectation resolves 'passed'.
        missing = ", ".join(sorted(f"{f}:{c}" for f, c in uncovered))
        if outcome != "failed":
            outcome = "cantTell"
        info = (
            f"Probe '{assert_id}' did not evaluate every declared criterion "
            f"for this expectation; missing: {missing}."
        )
    elif outcome == "cantTell":
        info = (
            f"Probe '{assert_id}' gathered evidence but did not settle every "
            "criterion for this expectation."
        )
    return {
        "intentId": intent_id,
        "expectationId": expectation_id,
        "outcome": outcome,
        "mode": "automatic",
        "pointer": None,
        "info": info,
    }


def build_verification(
    record: dict[str, Any],
    raw_text: str,
    results: dict[str, Any],
    timestamp: str | None = None,
) -> dict[str, Any]:
    """Build the complete verification artifact for one authored record."""
    generated_at = timestamp or datetime.now(timezone.utc).isoformat()
    assertions = build_assertions(record, results)
    _validate_identifiers(assertions)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "surfaceId": record.get("surfaceId"),
        "intentDigest": compute_intent_digest(raw_text),
        "assertedBy": ASSERTED_BY,
        "timestamp": generated_at,
        "assertions": assertions,
    }


def _validate_identifiers(assertions: list[dict[str, Any]]) -> None:
    """Reject missing or duplicated assertion identity before anything writes.

    Downstream consumers key on the (intentId, expectationId) pair. A null or
    duplicated pair produces an artifact that looks well formed while silently
    conflating two claims, so it fails before the file is emitted rather than
    after a consumer has trusted it.
    """
    seen: set[tuple[Any, Any]] = set()
    for item in assertions:
        intent_id = item["intentId"]
        expectation_id = item["expectationId"]
        if not intent_id or not expectation_id:
            raise ScriptError(
                "Every intent and expectation needs an id; found "
                f"intentId={intent_id!r} expectationId={expectation_id!r}"
            )
        key = (intent_id, expectation_id)
        if key in seen:
            raise ScriptError(
                f"Duplicate expectation id '{expectation_id}' within intent "
                f"'{intent_id}'; ids must be unique inside their intent"
            )
        seen.add(key)


BLOCKING_OK = "ok"
BLOCKING_FAILED = "failed"
BLOCKING_UNCOVERED = "uncovered"


def _effective_outcome(expectation: dict[str, Any], observed: str) -> str:
    """Return the gate-level outcome for one expectation.

    Either an observed or human-authored failure is authoritative. A documented
    human pass settles only an unresolved observation; it never masks a current
    observed failure. This preserves manual settlement for platforms no probe
    can drive while failing closed on conclusive disagreement.
    """
    override = expectation.get("override")
    if isinstance(override, dict):
        outcome = override.get("outcome")
        if observed == "failed" or outcome == "failed":
            return "failed"
        if observed in {"untested", "cantTell", "inapplicable"} and outcome == "passed":
            return "passed"
    return observed


def evaluate_blocking(record: dict[str, Any], assertions: list[dict[str, Any]]) -> str:
    """Classify the record's blocking expectations against their assertions.

    Returns BLOCKING_FAILED when a blocking expectation resolved 'failed',
    BLOCKING_UNCOVERED when one was never evaluated, and BLOCKING_OK otherwise.
    A failure outranks missing coverage because it is the stronger signal.

    Blocking identity is the (intentId, expectationId) pair. Expectation ids are
    unique only within their intent, so matching on a bare id lets one intent's
    blocking flag govern another intent's assertion.
    """
    blocking = {
        (intent.get("id"), expectation.get("id")): expectation
        for intent in _iter_intents(record)
        for expectation in _iter_expectations(intent)
        if is_blocking(expectation)
    }
    if not blocking:
        return BLOCKING_OK

    uncovered = False
    for item in assertions:
        expectation = blocking.get((item["intentId"], item["expectationId"]))
        if expectation is None:
            continue
        outcome = item.get("effectiveOutcome") or _effective_outcome(
            expectation, item["outcome"]
        )
        if item.get("overrideConflict"):
            return BLOCKING_FAILED
        if outcome == "failed":
            return BLOCKING_FAILED
        if outcome in ("untested", "cantTell"):
            uncovered = True
    return BLOCKING_UNCOVERED if uncovered else BLOCKING_OK


def default_output_path(record_path: Path, surface_id: str) -> Path:
    """Return the contract location for a record's verification artifact."""
    return record_path.parent / ".verification" / f"{surface_id}.earl.json"


def _require_secure_write_support() -> None:
    """Require the POSIX handle-relative primitives used by artifact writes."""
    required_dir_fd = (os.open, os.mkdir, os.stat, os.rename, os.unlink)
    flags = ("O_DIRECTORY", "O_NOFOLLOW")
    if (
        os.name != "posix"
        or any(function not in os.supports_dir_fd for function in required_dir_fd)
        or any(not hasattr(os, flag) for flag in flags)
    ):
        raise ScriptError(
            "Secure verification artifact writes require POSIX dir_fd, "
            "O_DIRECTORY, and O_NOFOLLOW support",
            EXIT_USAGE,
        )


def _open_absolute_directory(path: Path) -> int:
    """Open one absolute directory path without following any symlink."""
    absolute = Path(os.path.abspath(path))
    current_fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in absolute.parts[1:]:
            next_fd = os.open(
                part,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                dir_fd=current_fd,
            )
            os.close(current_fd)
            current_fd = next_fd
        return current_fd
    except OSError as exc:
        os.close(current_fd)
        raise ScriptError(
            f"Verification output root is unsafe: {absolute}", EXIT_USAGE
        ) from exc


def _open_destination_directory(root_fd: int, parts: tuple[str, ...]) -> int:
    """Open or safely create destination parents relative to one root handle."""
    current_fd = os.dup(root_fd)
    try:
        for part in parts:
            try:
                next_fd = os.open(
                    part,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                    dir_fd=current_fd,
                )
            except FileNotFoundError:
                try:
                    os.mkdir(part, mode=0o755, dir_fd=current_fd)
                except FileExistsError:
                    # A concurrent run created the component first. Reopening
                    # below validates it rather than trusting this creation.
                    pass
                next_fd = os.open(
                    part,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                    dir_fd=current_fd,
                )
            os.close(current_fd)
            current_fd = next_fd
        return current_fd
    except OSError as exc:
        os.close(current_fd)
        raise ScriptError(
            "Verification output parent is unsafe or not a directory",
            EXIT_USAGE,
        ) from exc


def _reject_unsafe_final_entry(directory_fd: int, name: str) -> None:
    """Reject an existing destination that is not a regular file."""
    try:
        metadata = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        return
    except OSError as exc:
        raise ScriptError(
            f"Verification destination is unreadable: {name}", EXIT_USAGE
        ) from exc
    if not stat.S_ISREG(metadata.st_mode):
        raise ScriptError(
            f"Verification destination is not a regular file: {name}",
            EXIT_USAGE,
        )


def _write_verification_artifact(
    record_path: Path,
    destination: Path,
    document: dict[str, Any],
) -> Path:
    """Write one artifact atomically beneath the authored-record directory."""
    _require_secure_write_support()
    # The contract stores records under <project>/design-intent/. Default output
    # stays below that directory, while an explicit --out may select another
    # location inside the same consuming project root.
    record_directory = Path(os.path.abspath(record_path.parent))
    approved_root = (
        record_directory.parent
        if record_directory.name == "design-intent"
        else record_directory
    )
    absolute_destination = Path(os.path.abspath(destination))
    try:
        relative = absolute_destination.relative_to(approved_root)
    except ValueError as exc:
        raise ScriptError(
            f"Verification destination escapes the record directory: {destination}",
            EXIT_USAGE,
        ) from exc
    if relative.name in {"", ".", ".."}:
        raise ScriptError("Verification destination needs a filename", EXIT_USAGE)

    root_fd = _open_absolute_directory(approved_root)
    directory_fd = -1
    temporary_created = False
    temporary_name = f".{relative.name}.{secrets.token_hex(8)}.tmp"
    try:
        directory_fd = _open_destination_directory(root_fd, relative.parent.parts)
        _reject_unsafe_final_entry(directory_fd, relative.name)
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
        temporary_fd = os.open(temporary_name, flags, 0o600, dir_fd=directory_fd)
        temporary_created = True
        try:
            payload = json.dumps(document, indent=2) + "\n"
            try:
                stream = os.fdopen(temporary_fd, "w", encoding="utf-8")
            except Exception:
                try:
                    os.close(temporary_fd)
                except OSError:
                    # The descriptor never reached a stream, so there is no
                    # further recovery. The original failure still raises.
                    pass
                raise
            with stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
        except Exception:
            raise

        # This check detects tampering. Handle-relative rename below provides
        # the atomic replacement and does not follow a destination symlink.
        _reject_unsafe_final_entry(directory_fd, relative.name)
        os.rename(
            temporary_name,
            relative.name,
            src_dir_fd=directory_fd,
            dst_dir_fd=directory_fd,
        )
    except BaseException as exc:
        try:
            # Only an entry this invocation created may be removed. A failed
            # exclusive create means the name belongs to something else.
            if temporary_created and directory_fd >= 0:
                os.unlink(temporary_name, dir_fd=directory_fd)
        except FileNotFoundError:
            # Cleanup is best effort; the temporary entry is already gone.
            pass
        if isinstance(exc, ScriptError):
            raise
        if not isinstance(exc, OSError):
            raise
        raise ScriptError(
            f"Failed to write verification artifact safely: {destination}",
            EXIT_USAGE,
        ) from exc
    finally:
        if directory_fd >= 0:
            os.close(directory_fd)
        os.close(root_fd)
    return absolute_destination


def generate(
    record_path: Path,
    results_path: Path,
    out_path: Path | None = None,
    timestamp: str | None = None,
    *,
    prepared: tuple[str, dict[str, Any]] | None = None,
) -> tuple[Path, dict[str, Any]]:
    """Generate and write a verification artifact for one authored record.

    Nothing is written when the record, results, or surface binding is invalid,
    so a failed run never leaves a misleading artifact behind.

    Pass 'prepared' as the (raw_text, record) a caller already read so the
    digest and the blocking verdict describe the same revision. Reading twice
    lets an edit between reads produce an artifact whose digest and verdict
    disagree.
    """
    if prepared is None:
        raw_text = read_record_text(record_path)
        record = parse_record(raw_text, record_path)
    else:
        raw_text, record = prepared
    surface_id = record.get("surfaceId")
    if not isinstance(surface_id, str) or not surface_id:
        raise ScriptError(f"Record declares no surfaceId: {record_path}")

    stem = record_path.name.removesuffix(".intent.yaml")
    if stem != surface_id:
        raise ScriptError(
            f"Record surfaceId '{surface_id}' does not match filename "
            f"'{record_path.name}'"
        )

    results = load_results(results_path)
    document = build_verification(record, raw_text, results, timestamp)

    destination = out_path or default_output_path(record_path, surface_id)
    written = _write_verification_artifact(record_path, destination, document)
    return written, document
