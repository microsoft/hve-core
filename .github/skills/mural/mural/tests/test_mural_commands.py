# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""CLI handler tests for mural.py (Phase 5).

Drives commands through ``mural_module.main([...])`` while monkey-patching
network seams (``_authenticated_request``, ``_paginate``, ``_create_asset_url``,
``_upload_to_sas``) and OAuth helpers.  Exercises happy paths, validation
errors, and exit-code mapping for each subcommand registered by
``_add_resource_subcommands`` and the ``auth`` group.
"""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest
from test_constants import (
    ENV_DEFAULT_WORKSPACE,
    ENV_TOKEN_STORE,
    TEST_MURAL_ID,
    TEST_WIDGET_ID,
    TEST_WORKSPACE_ID,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _patch_request(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    *,
    return_value: Any = None,
    side_effect: BaseException | None = None,
) -> list[dict[str, Any]]:
    """Replace ``_authenticated_request`` with a recorder."""
    calls: list[dict[str, Any]] = []

    def _fake(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        if side_effect is not None:
            raise side_effect
        return return_value

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake)
    return calls


def _patch_paginate(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    records: list[Any],
) -> list[dict[str, Any]]:
    """Replace ``_paginate`` with a recorder yielding ``records``."""
    calls: list[dict[str, Any]] = []

    def _fake(method: str, path: str, **kwargs: Any):
        calls.append({"method": method, "path": path, **kwargs})
        yield from records

    monkeypatch.setattr(mural_module, "_paginate", _fake)
    return calls


# ---------------------------------------------------------------------------
# auth login / logout / status
# ---------------------------------------------------------------------------


def test_auth_login_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    record = {"access_token": "x", "scope": "murals:read"}
    seen: dict[str, Any] = {}

    def _fake_login(*, scopes: str | None, timeout_seconds: int) -> dict[str, Any]:
        seen["scopes"] = scopes
        seen["timeout"] = timeout_seconds
        return record

    saved: list[tuple[pathlib.Path, dict[str, Any]]] = []

    monkeypatch.setattr(mural_module, "_run_login", _fake_login)
    monkeypatch.setattr(
        mural_module,
        "_save_token_store",
        lambda path, data: saved.append((path, data)),
    )

    rc = mural_module.main(["auth", "login", "--timeout", "12"])

    assert rc == mural_module.EXIT_SUCCESS
    assert seen == {"scopes": None, "timeout": 12}
    assert saved == [(fake_token_store, record)]


def test_auth_login_propagates_mural_error(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    def _boom(**_kwargs: Any) -> dict[str, Any]:
        raise mural_module.MuralError("login boom")

    monkeypatch.setattr(mural_module, "_run_login", _boom)

    rc = mural_module.main(["auth", "login"])

    assert rc == mural_module.EXIT_FAILURE


def test_auth_logout_removes_token_store(
    mural_module: Any, fake_token_store: pathlib.Path
) -> None:
    assert fake_token_store.exists()

    rc = mural_module.main(["auth", "logout"])

    assert rc == mural_module.EXIT_SUCCESS
    assert not fake_token_store.exists()


def test_auth_logout_missing_store_is_success(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing = tmp_path / "absent.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "logout"])

    assert rc == mural_module.EXIT_SUCCESS


def test_auth_logout_oserror_returns_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
) -> None:
    def _raise_oserror(self: pathlib.Path) -> None:
        raise OSError("permission denied")

    monkeypatch.setattr(pathlib.Path, "unlink", _raise_oserror)

    rc = mural_module.main(["auth", "logout"])

    assert rc == mural_module.EXIT_FAILURE


def test_auth_status_no_store(
    mural_module: Any,
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    missing = tmp_path / "no-store.json"
    monkeypatch.setenv(ENV_TOKEN_STORE, str(missing))

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out == {"authenticated": False, "token_store": str(missing)}


def test_auth_status_with_store(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "access_token": "x",
            "refresh_token": "y",
            "scope": "murals:read murals:write",
            "expires_at": 9999.0,
        },
    )

    rc = mural_module.main(["auth", "status"])

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out == {
        "authenticated": True,
        "token_store": str(fake_token_store),
        "scope": "murals:read murals:write",
        "expires_at": 9999.0,
        "has_refresh_token": True,
    }


# ---------------------------------------------------------------------------
# Workspace / room / mural list+get
# ---------------------------------------------------------------------------


def test_workspace_list_uses_paginate(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    calls = _patch_paginate(
        monkeypatch, mural_module, [{"id": "w1"}, {"id": "w2"}]
    )

    rc = mural_module.main(["workspace", "list", "--limit", "10"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {"method": "GET", "path": "/workspaces", "limit": 10, "page_size": None}
    ]
    assert json.loads(capsys.readouterr().out) == [{"id": "w1"}, {"id": "w2"}]


def test_workspace_get_resolves_from_env(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WORKSPACE_ID}
    )

    rc = mural_module.main(["workspace", "get"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {"method": "GET", "path": f"/workspaces/{TEST_WORKSPACE_ID}"}
    ]
    assert json.loads(capsys.readouterr().out) == {"id": TEST_WORKSPACE_ID}


def test_room_list_uses_workspace_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_paginate(monkeypatch, mural_module, [{"id": "r1"}])

    rc = mural_module.main(["room", "list"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/workspaces/{TEST_WORKSPACE_ID}/rooms"


def test_room_get_uses_room_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(monkeypatch, mural_module, return_value={"id": "r1"})

    rc = mural_module.main(["room", "get", "--room", "r1"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": "/rooms/r1"}]


def test_mural_list_uses_workspace_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(ENV_DEFAULT_WORKSPACE, TEST_WORKSPACE_ID)
    calls = _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(["mural", "list", "--page-size", "25"])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/workspaces/{TEST_WORKSPACE_ID}/murals"
    assert calls[0]["page_size"] == 25


def test_mural_get_invalid_id_returns_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(["mural", "get", "--mural", "not-valid"])

    assert rc == mural_module.EXIT_FAILURE


def test_mural_get_happy_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_MURAL_ID}
    )

    rc = mural_module.main(["mural", "get", "--mural", TEST_MURAL_ID])

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [{"method": "GET", "path": f"/murals/{TEST_MURAL_ID}"}]


# ---------------------------------------------------------------------------
# Widget list / get / update / delete
# ---------------------------------------------------------------------------


def test_widget_list_passes_filters(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "widget",
            "list",
            "--mural",
            TEST_MURAL_ID,
            "--type",
            "sticky-note",
            "--parent-id",
            "p1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets"
    assert calls[0]["params"] == {"type": "sticky-note", "parentId": "p1"}


def test_widget_list_rejects_oversized_page_size(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "widget",
            "list",
            "--mural",
            TEST_MURAL_ID,
            "--page-size",
            str(mural_module._MAX_PAGE_SIZE + 1),
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_get(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        ["widget", "get", "--mural", TEST_MURAL_ID, "--widget", TEST_WIDGET_ID]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls == [
        {
            "method": "GET",
            "path": f"/murals/{TEST_MURAL_ID}/widgets/{TEST_WIDGET_ID}",
        }
    ]


def test_widget_update_parses_json_body(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            '{"text": "updated"}',
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "PATCH"
    assert calls[0]["json_body"] == {"text": "updated"}


def test_widget_update_invalid_json_returns_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_request(monkeypatch, mural_module, return_value={})

    rc = mural_module.main(
        [
            "widget",
            "update",
            "--mural",
            TEST_MURAL_ID,
            "--widget",
            TEST_WIDGET_ID,
            "--body",
            "not-json",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_delete_prints_payload(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    calls = _patch_request(monkeypatch, mural_module, return_value=None)

    rc = mural_module.main(
        ["widget", "delete", "--mural", TEST_MURAL_ID, "--widget", TEST_WIDGET_ID]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "DELETE"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/{TEST_WIDGET_ID}"
    assert json.loads(capsys.readouterr().out) == {"deleted": TEST_WIDGET_ID}


# ---------------------------------------------------------------------------
# Widget create variants
# ---------------------------------------------------------------------------


def test_widget_create_sticky_note(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "sticky-note",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hello",
            "--x",
            "10",
            "--y",
            "20",
            "--style",
            '{"backgroundColor":"#fff"}',
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["method"] == "POST"
    assert calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/sticky-note"
    body = calls[0]["json_body"]
    assert body["text"] == "hello"
    assert body["x"] == 10.0
    assert body["y"] == 20.0
    assert body["shape"] == "rectangle"
    assert body["style"] == {"backgroundColor": "#fff"}


def test_widget_create_textbox(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "textbox",
            "--mural",
            TEST_MURAL_ID,
            "--text",
            "hi",
            "--x",
            "0",
            "--y",
            "0",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/textbox")
    assert calls[0]["json_body"]["text"] == "hi"


def test_widget_create_shape(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "shape",
            "--mural",
            TEST_MURAL_ID,
            "--shape",
            "circle",
            "--x",
            "5",
            "--y",
            "6",
            "--text",
            "label",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/shape")
    body = calls[0]["json_body"]
    assert body == {"shape": "circle", "x": 5.0, "y": 6.0, "text": "label"}


def test_widget_create_arrow(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "arrow",
            "--mural",
            TEST_MURAL_ID,
            "--x1",
            "1",
            "--y1",
            "2",
            "--x2",
            "3",
            "--y2",
            "4",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert calls[0]["path"].endswith("/widgets/arrow")
    assert calls[0]["json_body"] == {"x1": 1.0, "y1": 2.0, "x2": 3.0, "y2": 4.0}


def test_widget_create_image_happy_path(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
) -> None:
    image_path = tmp_path / "pic.png"
    image_path.write_bytes(b"\x89PNG\r\n\x1a\nfake")

    asset = {
        "url": "https://example.blob.core.windows.net/c/pic.png?sig=x",
        "name": "asset-1",
        "headers": {"x-ms-blob-type": "BlockBlob"},
    }

    asset_calls: list[tuple[str, str]] = []

    def _fake_create_asset(mural_id: str, ext: str, **_kwargs: Any) -> dict[str, Any]:
        asset_calls.append((mural_id, ext))
        return asset

    upload_calls: list[dict[str, Any]] = []

    def _fake_upload(**kwargs: Any) -> None:
        upload_calls.append(kwargs)

    monkeypatch.setattr(mural_module, "_create_asset_url", _fake_create_asset)
    monkeypatch.setattr(mural_module, "_upload_to_sas", _fake_upload)
    request_calls = _patch_request(
        monkeypatch, mural_module, return_value={"id": TEST_WIDGET_ID}
    )

    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(image_path),
            "--x",
            "0",
            "--y",
            "0",
            "--title",
            "Pic",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert asset_calls == [(TEST_MURAL_ID, ".png")]
    assert upload_calls == [
        {
            "url": asset["url"],
            "headers": asset["headers"],
            "body": image_path.read_bytes(),
            "content_type": "image/png",
        }
    ]
    assert request_calls[0]["method"] == "POST"
    assert request_calls[0]["path"] == f"/murals/{TEST_MURAL_ID}/widgets/image"
    assert request_calls[0]["json_body"]["name"] == "asset-1"
    assert request_calls[0]["json_body"]["title"] == "Pic"


def test_widget_create_image_missing_file_returns_failure(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(tmp_path / "nope.png"),
            "--x",
            "0",
            "--y",
            "0",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE


def test_widget_create_image_unsupported_extension_returns_failure(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    bad = tmp_path / "doc.txt"
    bad.write_bytes(b"hi")

    rc = mural_module.main(
        [
            "widget",
            "create",
            "image",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(bad),
            "--x",
            "0",
            "--y",
            "0",
        ]
    )

    assert rc == mural_module.EXIT_FAILURE
