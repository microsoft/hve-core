# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from pathlib import Path

import pytest
from runtime_a11y._config import assert_target_allowed, load_config
from runtime_a11y._errors import EXIT_USAGE, ScriptError


def test_load_config_missing_file_raises_usage_error(tmp_path: Path) -> None:
    with pytest.raises(ScriptError) as excinfo:
        load_config(tmp_path / "nope.json")

    assert excinfo.value.exit_code == EXIT_USAGE


def test_load_config_invalid_json_raises_usage_error(tmp_path: Path) -> None:
    path = tmp_path / "config.json"
    path.write_text("{not valid json", encoding="utf-8")

    with pytest.raises(ScriptError) as excinfo:
        load_config(path)

    assert excinfo.value.exit_code == EXIT_USAGE


def test_load_config_non_object_root_raises_usage_error(tmp_path: Path) -> None:
    path = tmp_path / "config.json"
    path.write_text("[]", encoding="utf-8")

    with pytest.raises(ScriptError):
        load_config(path)


def test_assert_target_allowed_requires_a_host() -> None:
    with pytest.raises(ScriptError):
        assert_target_allowed({"baseUrl": "not-a-url"})


def test_assert_target_allowed_permits_allowlisted_host() -> None:
    assert_target_allowed(
        {"baseUrl": "https://staging.example.com", "allowlist": ["*.example.com"]}
    )


def test_assert_target_allowed_permits_external_when_confirmed() -> None:
    assert_target_allowed({"baseUrl": "https://example.com"}, allow_external=True)


def test_assert_target_allowed_blocks_unauthorized_host() -> None:
    with pytest.raises(ScriptError):
        assert_target_allowed({"baseUrl": "https://evil.example.net"})


def test_assert_target_allowed_permits_loopback() -> None:
    assert_target_allowed({"baseUrl": "http://127.0.0.1:3000"})


def test_assert_target_allowed_blocks_bind_all_address() -> None:
    # 0.0.0.0 is a bind-all address, not loopback, so it must not be treated as
    # unconditionally safe by the SSRF guard.
    with pytest.raises(ScriptError):
        assert_target_allowed({"baseUrl": "http://0.0.0.0:3000"})


def test_assert_target_allowed_permits_bind_all_when_allowlisted() -> None:
    assert_target_allowed({"baseUrl": "http://0.0.0.0:3000", "allowlist": ["0.0.0.0"]})
    assert_target_allowed({"baseUrl": "http://0.0.0.0:3000"}, allow_external=True)
