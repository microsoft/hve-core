# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

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
