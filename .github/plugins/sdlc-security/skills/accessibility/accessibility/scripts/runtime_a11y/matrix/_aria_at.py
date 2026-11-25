# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Resolve ARIA-AT mapping metadata for generated manual accessibility cases."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import jsonschema

_PACKAGE_DIR = Path(__file__).resolve().parent.parent
_CATALOG_PATH = _PACKAGE_DIR / "aria-at-catalog.json"
_SCHEMA_PATH = _PACKAGE_DIR / "aria-at-catalog.schema.json"
_RUNBOOK_URL = (
    "https://github.com/microsoft/hve-core/blob/main/docs/planning/runbooks/"
    "accessibility/real-screen-reader-testing.md"
)
_MISSING = object()


def _catalog_schema() -> dict[str, Any]:
    return json.loads(_SCHEMA_PATH.read_text(encoding="utf-8"))


def load_catalog(catalog_path: str | Path | None = None) -> dict[str, Any]:
    """Load and validate the local ARIA-AT catalog."""
    path = Path(catalog_path) if catalog_path is not None else _CATALOG_PATH
    payload = json.loads(path.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(
        _catalog_schema(),
        format_checker=jsonschema.FormatChecker(),
    )
    validator.validate(payload)
    return payload


def _resolve_override(
    runtime_config: dict[str, Any] | None,
    surface_id: str | None,
    state: str,
    key: str,
) -> Any:
    if not runtime_config or not surface_id:
        return _MISSING
    for entry in runtime_config.get("surfaces", []) or []:
        if entry.get("id") != surface_id:
            continue
        for state_entry in entry.get("states", []) or []:
            if state_entry.get("state") != state:
                continue
            aria_at = (
                state_entry.get("ariaAt") or state_entry.get("realScreenReader") or {}
            )
            if key in aria_at:
                return aria_at[key]
        aria_at = entry.get("ariaAt") or entry.get("realScreenReader") or {}
        if key in aria_at:
            return aria_at[key]
    return _MISSING


def _resolve_pattern(
    surface_pattern: str | None,
    surface_id: str | None,
    runtime_config: dict[str, Any] | None,
) -> str | None:
    if surface_pattern:
        return surface_pattern
    if not runtime_config or not surface_id:
        return None
    for entry in runtime_config.get("surfaces", []) or []:
        if entry.get("id") != surface_id:
            continue
        if entry.get("widgetPattern"):
            return str(entry.get("widgetPattern"))
        break
    return None


def resolve_aria_at_mapping(
    pattern: str | None,
    state: str,
    surface_id: str | None = None,
    runtime_config: dict[str, Any] | None = None,
    catalog_path: str | Path | None = None,
) -> dict[str, Any]:
    """Resolve a mapping result with deterministic precedence and fallback."""
    catalog = load_catalog(catalog_path)
    pattern = _resolve_pattern(pattern, surface_id, runtime_config)
    if not pattern:
        return {
            "mappingStatus": "unmapped",
            "mappingId": None,
            "sourceUrl": None,
            "immutableUrl": None,
            "upstreamSha": None,
            "catalogVersion": catalog.get("catalogVersion"),
            "automationEligible": False,
            "automationExclusionReason": "No widget pattern was supplied.",
            "commands": [],
            "assertions": [],
            "variants": [],
            "runbookReference": _RUNBOOK_URL,
        }

    matches = [
        item
        for item in catalog.get("mappings", [])
        if str(item.get("pattern", "")).lower() == str(pattern).lower()
        and (
            not item.get("state")
            or str(item.get("state", "")).lower() == str(state).lower()
        )
    ]
    scored_matches: list[tuple[int, dict[str, Any]]] = []
    for item in matches:
        item_state = str(item.get("state", "") or "").lower()
        target_state = str(state).lower()
        if item_state and item_state != target_state:
            continue
        score = 2 if item_state == target_state else 1
        scored_matches.append((score, item))
    matches = [item for _, item in scored_matches if _]
    if not matches:
        return {
            "mappingStatus": "unmapped",
            "mappingId": None,
            "sourceUrl": None,
            "immutableUrl": None,
            "upstreamSha": None,
            "catalogVersion": catalog.get("catalogVersion"),
            "automationEligible": False,
            "automationExclusionReason": (
                "The widget pattern is unknown to the local ARIA-AT catalog."
            ),
            "commands": [],
            "assertions": [],
            "variants": [],
            "runbookReference": _RUNBOOK_URL,
        }
    if len(matches) > 1:
        highest_score = max(score for score, _ in scored_matches)
        best_matches = [
            item for score, item in scored_matches if score == highest_score
        ]
        if len(best_matches) > 1:
            raise ValueError(
                "Multiple equally specific ARIA-AT mappings matched the same "
                "pattern and state."
            )
        matches = best_matches
    if len(matches) > 1:
        raise ValueError(
            "Multiple equally specific ARIA-AT mappings matched the same "
            "pattern and state."
        )
    entry = matches[0]
    commands_override = _resolve_override(
        runtime_config,
        surface_id,
        state,
        "commands",
    )
    assertions_override = _resolve_override(
        runtime_config,
        surface_id,
        state,
        "assertions",
    )
    mapping_commands = list(entry.get("commands", []))
    mapping_assertions = list(entry.get("assertions", []))

    variant_payloads = []
    for variant in entry.get("variants", []):
        variant_commands = list(variant.get("commands", mapping_commands))
        variant_assertions = list(variant.get("assertions", mapping_assertions))
        automation_eligible = bool(variant.get("automationEligible", True))
        effective_commands = (
            commands_override if commands_override is not _MISSING else variant_commands
        )
        effective_assertions = (
            assertions_override
            if assertions_override is not _MISSING
            else variant_assertions
        )
        exclusion_reason = variant.get("automationExclusionReason")
        if commands_override is not _MISSING and commands_override == []:
            automation_eligible = False
            exclusion_reason = (
                "Explicit empty command override makes this variant human-only."
            )
        elif assertions_override is not _MISSING and assertions_override == []:
            automation_eligible = False
            exclusion_reason = (
                "Explicit empty assertion override makes this variant human-only."
            )
        elif not effective_commands:
            automation_eligible = False
            exclusion_reason = exclusion_reason or (
                "The catalog variant has no executable commands."
            )
        elif not effective_assertions:
            automation_eligible = False
            exclusion_reason = exclusion_reason or (
                "The catalog variant has no executable assertions."
            )
        elif not automation_eligible:
            exclusion_reason = exclusion_reason or "The variant is human-only."
        if not automation_eligible:
            effective_commands = []
            effective_assertions = []
            if not exclusion_reason:
                exclusion_reason = (
                    variant.get("automationExclusionReason")
                    or "The variant is human-only."
                )
        variant_payloads.append(
            {
                "id": variant.get("id"),
                "at": variant.get("at"),
                "platform": variant.get("platform"),
                "automationEligible": automation_eligible,
                "automationExclusionReason": exclusion_reason,
                "commands": effective_commands,
                "assertions": effective_assertions,
                "humanOnly": bool(variant.get("humanOnly", False)),
                "manualEvidenceRequired": bool(
                    variant.get("manualEvidenceRequired", False)
                ),
                "manualCommandGuidance": list(variant.get("manualCommandGuidance", [])),
                "functionalExpectation": variant.get("functionalExpectation"),
                "runbookReference": variant.get("runbookReference", _RUNBOOK_URL),
                "manualEvidence": dict(variant.get("manualEvidence", {})),
            }
        )

    eligible_variants = [
        variant
        for variant in variant_payloads
        if variant.get("automationEligible", False)
    ]
    resolved_commands = (
        commands_override if commands_override is not _MISSING else mapping_commands
    )
    resolved_assertions = (
        assertions_override
        if assertions_override is not _MISSING
        else mapping_assertions
    )

    mapping_automation_eligible = bool(
        entry.get("automationEligible", bool(eligible_variants)) and eligible_variants
    )
    mapping_exclusion_reason = entry.get("automationExclusionReason")
    if not mapping_exclusion_reason:
        mapping_exclusion_reason = next(
            (
                variant.get("automationExclusionReason")
                for variant in variant_payloads
                if variant.get("automationExclusionReason")
            ),
            None,
        )

    return {
        "mappingStatus": "mapped",
        "mappingId": entry.get("id"),
        "upstreamTestId": entry.get("upstreamTestId"),
        "functionalExpectations": list(entry.get("functionalExpectations", [])),
        "adaptationNotes": list(entry.get("adaptationNotes", [])),
        "sourceUrl": entry.get("source", {}).get("canonicalUrl"),
        "immutableUrl": entry.get("source", {}).get("immutableUrl"),
        "patternUrl": entry.get("source", {}).get("patternUrl"),
        "exampleUrl": entry.get("source", {}).get("exampleUrl"),
        "ariaAtReportsUrl": entry.get("source", {}).get("ariaAtReportsUrl"),
        "upstreamRepositoryPath": entry.get("source", {}).get("upstreamRepositoryPath"),
        "upstreamRepositoryUrl": entry.get("source", {}).get("upstreamRepositoryUrl"),
        "upstreamRepositoryFileUrl": entry.get("source", {}).get(
            "upstreamRepositoryFileUrl"
        ),
        "upstreamSha": entry.get("source", {}).get("upstreamSha"),
        "catalogVersion": entry.get("source", {}).get("catalogVersion")
        or catalog.get("catalogVersion"),
        "automationEligible": bool(mapping_automation_eligible),
        "automationExclusionReason": mapping_exclusion_reason,
        "commands": resolved_commands,
        "assertions": resolved_assertions,
        "variants": variant_payloads,
        "runbookReference": _RUNBOOK_URL,
    }
