# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path

import pytest
from runtime_a11y._config import (
    assert_target_allowed,
    load_config,
    load_validated_config,
    validate_config,
)
from runtime_a11y._errors import ScriptError


@pytest.fixture()
def config_path(tmp_path: Path) -> Path:
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", '
        '"surfaces": [{"id": "web", "type": "page"}]}',
        encoding="utf-8",
    )
    return config_path


def test_given_valid_config_when_validate_then_succeeds(config_path: Path) -> None:
    config = load_config(config_path)

    validate_config(config)


def test_given_invalid_config_when_validate_then_raises_script_error(
    config_path: Path,
) -> None:
    config = load_config(config_path)
    config["surfaces"][0]["type"] = "invalid"

    with pytest.raises(ScriptError, match="Invalid a11y-runtime config"):
        validate_config(config)


def test_given_invalid_calibration_profile_version_when_validate_then_raises_script_error(  # noqa: E501
    config_path: Path,
) -> None:
    config = load_config(config_path)
    config["calibration"] = {
        "profileVersion": 7,
        "manualBoundary": [{"bugId": "14402", "reason": "manual-only"}],
    }

    with pytest.raises(ScriptError, match="Invalid a11y-runtime config"):
        validate_config(config)


@pytest.mark.parametrize(
    ("base_url", "allow_external", "allowlist", "expected"),
    [
        ("http://127.0.0.1:3000", False, None, None),
        ("http://localhost:3000", False, None, None),
        ("https://example.com", False, ["example.com"], None),
        ("https://example.com", True, None, None),
    ],
)
def test_given_allowed_target_when_assert_target_allowed_then_succeeds(
    base_url: str,
    allow_external: bool,
    allowlist: list[str] | None,
    expected: None,
) -> None:
    config = {"baseUrl": base_url}
    if allowlist is not None:
        config["allowlist"] = allowlist

    assert_target_allowed(config, allow_external=allow_external)


def test_given_external_target_without_override_then_raises() -> None:
    with pytest.raises(ScriptError, match="Refusing to probe non-loopback host"):
        assert_target_allowed({"baseUrl": "https://example.com"})


def test_given_path_when_load_validated_config_then_returns_config(
    config_path: Path,
) -> None:
    config = load_validated_config(config_path)

    assert config["baseUrl"] == "http://127.0.0.1:3000"


def test_given_calibration_trigger_sequence_when_validate_then_succeeds(
    tmp_path: Path,
) -> None:
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", '
        '"calibration": {"journeys": [{"id": "14399", '
        '"triggerAfterDriverStart": true, '
        '"triggerSequence": [{"action": "focus", "target": "input"}], '
        '"commands": [{"kind": "keyboard", "value": "ArrowDown"}], '
        '"assertions": [{"id": "speech", "type": "contains", "value": "result"}]}]}}',
        encoding="utf-8",
    )

    config = load_validated_config(config_path)

    assert (
        config["calibration"]["journeys"][0]["triggerSequence"][0]["action"] == "focus"
    )


def test_given_type_command_when_validate_then_succeeds(tmp_path: Path) -> None:
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", '
        '"calibration": {"journeys": [{"id": "14399", '
        '"commands": [{"kind": "type", "value": "agent"}], '
        '"assertions": [{"id": "speech", "type": "contains", "value": "result"}]}]}}',
        encoding="utf-8",
    )

    config = load_validated_config(config_path)

    assert config["calibration"]["journeys"][0]["commands"][0]["kind"] == "type"


def test_validate_controlled_calibration_journeys_reach_targets_by_keyboard() -> None:
    config_path = (
        Path(__file__).resolve().parents[6]
        / "docs"
        / "docusaurus"
        / "a11y-runtime.config.json"
    )
    config = json.loads(config_path.read_text(encoding="utf-8"))

    journeys = {journey["id"]: journey for journey in config["calibration"]["journeys"]}

    # Programmatic focus does not move NVDA's browse-mode review caret, so the
    # combobox must be reached with the documented Control+K shortcut. Preparation
    # only parks the caret in the document body.
    search_journey = journeys["search-keyboard-reachability"]
    assert search_journey["triggerSequence"][0]["action"] == "focus"
    assert search_journey["triggerSequence"][0]["target"] == "body"
    search_commands = search_journey["commands"]
    search_kinds = [command["kind"] for command in search_commands]
    reach_index = next(
        index
        for index, command in enumerate(search_commands)
        if command["kind"] == "key" and command["value"] == "Control+K"
    )
    assert reach_index < search_kinds.index("type")
    assert search_kinds.index("waitFor") > search_kinds.index("type")
    assert search_kinds[-1] == "pause"

    # NVDA leaves focus mode after the first typed character, so both journeys
    # send exactly one character and then hold idle. The resulting polite
    # live-region update supplies the announcement under test.
    for journey_id in ("search-keyboard-reachability", "search-status-announcement"):
        typed = [
            command
            for command in journeys[journey_id]["commands"]
            if command["kind"] == "type"
        ]
        assert len(typed) == 1
        assert len(typed[0]["value"]) == 1

    # The polite status region settles after the first character, so a single
    # keystroke followed by an idle hold keeps the announcement from being
    # superseded by further character echo.
    status_journey = journeys["search-status-announcement"]
    assert status_journey["triggerSequence"][0]["action"] == "click"
    assert status_journey["triggerSequence"][0]["target"] == 'input[name="q"]'
    status_commands = status_journey["commands"]
    status_kinds = [command["kind"] for command in status_commands]
    assert status_kinds.index("waitFor") > status_kinds.index("type")
    assert status_kinds[-1] == "pause"
