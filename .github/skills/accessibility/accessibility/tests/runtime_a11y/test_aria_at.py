# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest
from runtime_a11y.matrix._aria_at import (
    load_catalog,
    resolve_aria_at_mapping,
)

STARTER_MAPPINGS = [
    {
        "id": "aria-at-modal-dialog",
        "pattern": "dialog-modal",
        "state": "open",
        "expectedUpstreamPath": "tests/apg/modal-dialog",
        "upstreamSha": "01923da5f533dda74c9f33a68ee20e112069c6de",
        "expectedTestId": "openModalDialog",
        "expectedVariants": ["nvda", "jaws"],
    },
    {
        "id": "aria-at-checkbox",
        "pattern": "checkbox",
        "state": "default",
        "expectedUpstreamPath": "tests/apg/checkbox",
        "upstreamSha": "46ef988700398d189de78072dd1b5883f41ffbcf",
        "expectedTestId": "operateNotCheckedCheckbox",
        "expectedVariants": ["nvda", "jaws"],
    },
    {
        "id": "aria-at-combobox-select-only",
        "pattern": "combobox",
        "state": "default",
        "expectedUpstreamPath": "tests/apg/combobox-select-only",
        "upstreamSha": "01923da5f533dda74c9f33a68ee20e112069c6de",
        "expectedTestId": "1",
        "expectedVariants": ["nvda", "jaws"],
    },
    {
        "id": "aria-at-menu-button-actions",
        "pattern": "menu-button",
        "state": "default",
        "expectedUpstreamPath": "tests/apg/menu-button-actions",
        "upstreamSha": "01923da5f533dda74c9f33a68ee20e112069c6de",
        "expectedTestId": "openMenu",
        "expectedVariants": ["nvda", "jaws"],
    },
    {
        "id": "aria-at-tabs-manual-activation",
        "pattern": "tabs",
        "state": "default",
        "expectedUpstreamPath": "tests/apg/tabs-manual-activation",
        "upstreamSha": "01923da5f533dda74c9f33a68ee20e112069c6de",
        "expectedTestId": "navForwardsToTabListWhereATabIsNotSelected",
        "expectedVariants": ["nvda", "jaws"],
    },
]


def _make_source(
    *,
    canonical_url: str = "https://example.com/one",
    immutable_url: str = "https://example.com/one",
    pattern_url: str = "https://example.com/pattern",
    example_url: str = "https://example.com/example",
    upstream_path: str = "tests/apg/modal-dialog",
    upstream_sha: str = "01923da5f533dda74c9f33a68ee20e112069c6de",
    catalog_version: str = "2026-07-15",
) -> dict[str, Any]:
    return {
        "canonicalUrl": canonical_url,
        "immutableUrl": immutable_url,
        "patternUrl": pattern_url,
        "exampleUrl": example_url,
        "ariaAtReportsUrl": None,
        "upstreamRepositoryPath": upstream_path,
        "upstreamRepositoryUrl": (
            f"https://github.com/w3c-cg/aria-at/tree/{upstream_sha}/{upstream_path}"
        ),
        "upstreamRepositoryFileUrl": (
            f"https://raw.githubusercontent.com/w3c-cg/aria-at/{upstream_sha}"
            f"/{upstream_path}/data/references.csv"
        ),
        "upstreamSha": upstream_sha,
        "catalogVersion": catalog_version,
    }


def _make_variant(
    *,
    variant_id: str,
    at: str,
    platform: str = "windows",
    automation_eligible: bool = False,
    automation_exclusion_reason: str = "manual-only",
) -> dict[str, Any]:
    return {
        "id": variant_id,
        "at": at,
        "platform": platform,
        "automationEligible": automation_eligible,
        "automationExclusionReason": automation_exclusion_reason,
        "commands": [],
        "assertions": [],
    }


def _make_mapping(
    *,
    mapping_id: str,
    pattern: str,
    state: str,
    upstream_test_id: str,
    upstream_path: str = "tests/apg/modal-dialog",
    upstream_sha: str = "01923da5f533dda74c9f33a68ee20e112069c6de",
    source: dict[str, Any] | None = None,
    variants: list[dict[str, Any]] | None = None,
    automation_eligible: bool = False,
    automation_exclusion_reason: str = "manual-only",
) -> dict[str, Any]:
    if source is None:
        source = _make_source(
            upstream_path=upstream_path,
            upstream_sha=upstream_sha,
        )

    return {
        "id": mapping_id,
        "pattern": pattern,
        "state": state,
        "upstreamTestId": upstream_test_id,
        "functionalExpectations": [
            "The widget should expose the expected semantics to assistive "
            "technology users."
        ],
        "adaptationNotes": [
            "The catalog preserves upstream provenance while keeping this "
            "starter mapping manual-only."
        ],
        "source": source,
        "commands": [],
        "assertions": [],
        "variants": variants
        or [_make_variant(variant_id=f"{mapping_id}-variant", at="nvda")],
        "automationEligible": automation_eligible,
        "automationExclusionReason": automation_exclusion_reason,
    }


def _write_catalog(path: Path, mappings: list[dict[str, Any]]) -> None:
    path.write_text(
        json.dumps(
            {
                "catalogVersion": "2026-07-15",
                "mappings": mappings,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def test_given_catalog_when_loading_then_provenance_is_verified_and_strict() -> None:
    catalog = load_catalog()

    assert catalog["catalogVersion"] == "2026-07-15"
    mapping = catalog["mappings"][0]
    assert mapping["pattern"] == "dialog-modal"
    assert mapping["state"] == "open"
    assert (
        mapping["source"]["upstreamSha"] == "01923da5f533dda74c9f33a68ee20e112069c6de"
    )
    assert mapping["source"]["upstreamRepositoryFileUrl"].endswith(
        "tests/apg/modal-dialog/data/references.csv"
    )
    assert mapping["source"]["ariaAtReportsUrl"] is None
    assert (
        mapping["source"]["patternUrl"]
        == "https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/"
    )
    assert (
        mapping["source"]["exampleUrl"]
        == "https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/examples/dialog/"
    )
    assert mapping["functionalExpectations"]
    assert mapping["adaptationNotes"]
    assert mapping["upstreamTestId"] == "openModalDialog"


@pytest.mark.parametrize("entry", STARTER_MAPPINGS)
def test_given_starter_catalog_when_loading_then_expected_mappings_are_present(
    entry: dict[str, object],
) -> None:
    catalog = load_catalog()
    mapping = next(
        item for item in catalog["mappings"] if item.get("id") == entry["id"]
    )

    assert mapping["pattern"] == entry["pattern"]
    assert mapping["state"] == entry["state"]
    assert mapping["source"]["upstreamSha"] == entry["upstreamSha"]
    assert mapping["source"]["patternUrl"].startswith(
        "https://www.w3.org/WAI/ARIA/apg/"
    )
    assert mapping["source"]["exampleUrl"].startswith(
        "https://www.w3.org/WAI/ARIA/apg/"
    )
    assert mapping["source"]["upstreamRepositoryUrl"].startswith(
        "https://github.com/w3c-cg/aria-at/tree/"
    )
    assert mapping["source"]["upstreamRepositoryFileUrl"].startswith(
        "https://raw.githubusercontent.com/w3c-cg/aria-at/"
    )
    assert mapping["source"]["upstreamRepositoryPath"] == entry["expectedUpstreamPath"]
    assert mapping["source"]["catalogVersion"] == catalog["catalogVersion"]
    assert mapping["upstreamTestId"] == entry["expectedTestId"]
    assert [variant["at"] for variant in mapping["variants"]] == entry[
        "expectedVariants"
    ]
    assert all(variant["at"] != "voiceover" for variant in mapping["variants"])


@pytest.mark.parametrize("entry", STARTER_MAPPINGS)
def test_given_starter_catalog_when_resolving_then_variants_are_manual_only(
    entry: dict[str, object],
) -> None:
    catalog = load_catalog()
    mapping = next(
        item for item in catalog["mappings"] if item.get("id") == entry["id"]
    )

    assert mapping["commands"] == []
    assert mapping["assertions"] == []
    assert mapping["automationEligible"] is False
    assert mapping["automationExclusionReason"]
    for variant in mapping["variants"]:
        assert variant["automationEligible"] is False
        assert variant["automationExclusionReason"]
        if entry["id"] == "aria-at-checkbox" and variant["at"] == "nvda":
            assert variant["commands"] == [{"kind": "key", "value": "Space"}]
            assert variant["assertions"] == [
                {"type": "contains", "value": "checkbox"},
                {"type": "contains", "value": "accept terms"},
                {"type": "matches", "value": "checked|not checked"},
            ]
        elif (
            entry["id"] == "aria-at-tabs-manual-activation" and variant["at"] == "nvda"
        ):
            assert variant["commands"] == [
                {"kind": "key", "value": "ArrowRight"},
                {"kind": "key", "value": "ArrowLeft"},
                {"kind": "key", "value": "Home"},
                {"kind": "key", "value": "End"},
                {"kind": "key", "value": "Space"},
                {"kind": "key", "value": "Enter"},
            ]
            assert variant["assertions"] == [
                {"type": "contains", "value": "active tab"},
                {"type": "contains", "value": "selected"},
            ]
        else:
            assert variant["commands"] == []
            assert variant["assertions"] == []


def test_given_catalog_when_loading_then_mapping_has_jaws_contract() -> None:
    catalog = load_catalog()

    for mapping in catalog["mappings"]:
        jaws_variant = next(
            (variant for variant in mapping["variants"] if variant["at"] == "jaws"),
            None,
        )
        assert jaws_variant is not None
        assert jaws_variant["automationEligible"] is False
        assert jaws_variant["manualEvidenceRequired"] is True
        assert jaws_variant["manualCommandGuidance"]
        assert jaws_variant["functionalExpectation"]
        assert jaws_variant["manualEvidence"]["jawsVersion"]
        assert jaws_variant["manualEvidence"]["browserVersion"]
        assert jaws_variant["manualEvidence"]["windowsVersion"]
        assert jaws_variant["manualEvidence"]["interactionMode"]
        assert jaws_variant["manualEvidence"]["commandsPerformed"]
        assert jaws_variant["manualEvidence"]["observedOutput"]
        assert jaws_variant["manualEvidence"]["tester"]
        assert jaws_variant["manualEvidence"]["date"]
        assert jaws_variant["manualEvidence"]["evidenceUri"]
        assert jaws_variant["runbookReference"].endswith(
            "real-screen-reader-testing.md"
        )
        assert jaws_variant["commands"] == []
        assert jaws_variant["assertions"] == []


def test_given_unknown_pattern_when_resolving_then_mapping_is_unmapped() -> None:
    result = resolve_aria_at_mapping("unknown-pattern", "open", "dialog")

    assert result["mappingStatus"] == "unmapped"
    assert result["automationEligible"] is False
    assert result["mappingId"] is None
    assert result["automationExclusionReason"].startswith("The widget pattern")


def test_given_ambiguous_matches_when_resolving_then_value_error_is_raised(
    tmp_path: Path,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mappings = [
        _make_mapping(
            mapping_id="first",
            pattern="dialog-modal",
            state="open",
            upstream_test_id="openModalDialog",
            source=_make_source(
                canonical_url="https://example.com/one",
                immutable_url="https://example.com/one",
                pattern_url="https://example.com/one",
                example_url="https://example.com/one",
            ),
        ),
        _make_mapping(
            mapping_id="second",
            pattern="dialog-modal",
            state="open",
            upstream_test_id="openModalDialog",
            source=_make_source(
                canonical_url="https://example.com/two",
                immutable_url="https://example.com/two",
                pattern_url="https://example.com/two",
                example_url="https://example.com/two",
            ),
        ),
    ]
    _write_catalog(catalog_path, mappings)

    with pytest.raises(ValueError):
        resolve_aria_at_mapping(
            "dialog-modal",
            "open",
            "dialog",
            catalog_path=catalog_path,
        )


def test_given_specific_and_generic_matches_when_resolving_then_specific_state_wins(
    tmp_path: Path,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mappings = [
        _make_mapping(
            mapping_id="generic",
            pattern="dialog-modal",
            state="",
            upstream_test_id="genericModalDialog",
            source=_make_source(
                canonical_url="https://example.com/generic",
                immutable_url="https://example.com/generic",
                pattern_url="https://example.com/generic",
                example_url="https://example.com/generic",
            ),
        ),
        _make_mapping(
            mapping_id="open",
            pattern="dialog-modal",
            state="open",
            upstream_test_id="openModalDialog",
            source=_make_source(
                canonical_url="https://example.com/open",
                immutable_url="https://example.com/open",
                pattern_url="https://example.com/open",
                example_url="https://example.com/open",
            ),
        ),
    ]
    _write_catalog(catalog_path, mappings)

    result = resolve_aria_at_mapping(
        "dialog-modal",
        "open",
        "dialog",
        catalog_path=catalog_path,
    )

    assert result["mappingId"] == "open"
    assert result["commands"] == []


def test_given_runtime_config_override_when_resolving_then_state_override_wins() -> (
    None
):
    runtime_config = {
        "surfaces": [
            {
                "id": "dialog",
                "ariaAt": {
                    "commands": [{"kind": "command", "value": "surface-command"}],
                    "assertions": [
                        {"type": "contains", "value": "surface announcement"}
                    ],
                },
                "states": [
                    {
                        "state": "open",
                        "ariaAt": {
                            "commands": [],
                            "assertions": [],
                        },
                    }
                ],
            }
        ]
    }

    result = resolve_aria_at_mapping("dialog-modal", "open", "dialog", runtime_config)

    assert result["commands"] == []
    assert result["assertions"] == []
    assert result["automationEligible"] is False
    assert result["mappingStatus"] == "mapped"


def test_given_runtime_pattern_when_resolving_then_state_fallback_applies() -> None:
    runtime_config = {
        "surfaces": [
            {
                "id": "dialog",
                "widgetPattern": "dialog-modal",
                "states": [
                    {
                        "state": "open",
                        "ariaAt": {
                            "commands": [{"kind": "key", "value": "Escape"}],
                            "assertions": [{"type": "contains", "value": "Closed"}],
                        },
                    }
                ],
            }
        ]
    }

    result = resolve_aria_at_mapping(
        None,
        "open",
        "dialog",
        runtime_config,
    )

    assert result["mappingStatus"] == "mapped"
    assert result["commands"] == [{"kind": "key", "value": "Escape"}]
    assert result["assertions"] == [{"type": "contains", "value": "Closed"}]
    assert result["automationEligible"] is False


def test_given_empty_overrides_when_resolving_then_variants_become_human_only(
    tmp_path: Path,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mapping = _make_mapping(
        mapping_id="empty-override",
        pattern="dialog-modal",
        state="open",
        upstream_test_id="openModalDialog",
        variants=[
            _make_variant(variant_id="variant", at="nvda", automation_eligible=True)
        ],
    )
    mapping["commands"] = [{"kind": "command", "value": "Escape"}]
    mapping["assertions"] = [{"type": "contains", "value": "Closed"}]
    _write_catalog(catalog_path, [mapping])

    runtime_config = {
        "surfaces": [
            {
                "id": "dialog",
                "states": [
                    {
                        "state": "open",
                        "ariaAt": {"commands": [], "assertions": []},
                    }
                ],
            }
        ]
    }

    result = resolve_aria_at_mapping(
        "dialog-modal",
        "open",
        "dialog",
        runtime_config,
        catalog_path=catalog_path,
    )

    assert result["automationEligible"] is False
    assert result["commands"] == []
    assert result["assertions"] == []
    assert result["variants"][0]["automationEligible"] is False


def test_given_invalid_sha_when_loading_catalog_then_validation_error_is_raised(
    tmp_path: Path,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mapping = _make_mapping(
        mapping_id="invalid-sha",
        pattern="dialog-modal",
        state="open",
        upstream_test_id="openModalDialog",
    )
    mapping["source"]["upstreamSha"] = "not-a-sha"
    _write_catalog(catalog_path, [mapping])

    with pytest.raises(jsonschema.ValidationError):
        load_catalog(catalog_path)


def test_given_invalid_uri_when_loading_catalog_then_validation_error_is_raised(
    tmp_path: Path,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mapping = _make_mapping(
        mapping_id="invalid-uri",
        pattern="dialog-modal",
        state="open",
        upstream_test_id="openModalDialog",
    )
    mapping["source"]["patternUrl"] = {"not": "a-uri"}
    _write_catalog(catalog_path, [mapping])

    with pytest.raises(jsonschema.ValidationError):
        load_catalog(catalog_path)


@pytest.mark.parametrize(
    ("mutate_mapping", "expected_error"),
    [
        (lambda mapping: mapping.pop("upstreamTestId"), "upstreamTestId"),
        (
            lambda mapping: mapping["variants"][0].pop("automationExclusionReason"),
            "automationExclusionReason",
        ),
    ],
)
def test_missing_required_fields_when_loading_catalog_then_validation_error_is_raised(
    tmp_path: Path,
    mutate_mapping: Any,
    expected_error: str,
) -> None:
    catalog_path = tmp_path / "catalog.json"
    mapping = _make_mapping(
        mapping_id="missing-field",
        pattern="dialog-modal",
        state="open",
        upstream_test_id="openModalDialog",
    )
    mutate_mapping(mapping)
    _write_catalog(catalog_path, [mapping])

    with pytest.raises(jsonschema.ValidationError) as exc_info:
        load_catalog(catalog_path)

    assert expected_error in str(exc_info.value)


def test_catalog_versions_and_manual_only_state_are_preserved() -> None:
    catalog = load_catalog()

    assert len(catalog["mappings"]) == 5
    for mapping in catalog["mappings"]:
        assert mapping["source"]["catalogVersion"] == catalog["catalogVersion"]
        assert mapping["commands"] == []
        assert mapping["assertions"] == []
        assert mapping["automationEligible"] is False
        assert mapping["automationExclusionReason"]
        for variant in mapping["variants"]:
            assert variant["automationEligible"] is False
            assert variant["automationExclusionReason"]
            if mapping["id"] == "aria-at-checkbox" and variant["at"] == "nvda":
                assert variant["commands"] == [{"kind": "key", "value": "Space"}]
                assert variant["assertions"] == [
                    {"type": "contains", "value": "checkbox"},
                    {"type": "contains", "value": "accept terms"},
                    {"type": "matches", "value": "checked|not checked"},
                ]
            elif (
                mapping["id"] == "aria-at-tabs-manual-activation"
                and variant["at"] == "nvda"
            ):
                assert variant["commands"] == [
                    {"kind": "key", "value": "ArrowRight"},
                    {"kind": "key", "value": "ArrowLeft"},
                    {"kind": "key", "value": "Home"},
                    {"kind": "key", "value": "End"},
                    {"kind": "key", "value": "Space"},
                    {"kind": "key", "value": "Enter"},
                ]
                assert variant["assertions"] == [
                    {"type": "contains", "value": "active tab"},
                    {"type": "contains", "value": "selected"},
                ]
            else:
                assert variant["commands"] == []
                assert variant["assertions"] == []
