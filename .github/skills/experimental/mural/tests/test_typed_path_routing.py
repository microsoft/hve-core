# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Regression tests for typed-path PATCH routing.

The Mural API rejects PATCH against the generic ``/widgets/{id}`` route with
404 PATH_NOT_FOUND. Two pieces of code must stay aligned to keep tag-write
operations working:

* :data:`mural._WIDGET_TYPE_API_TO_PATH_KEY` — must map every Mural type
  string the GET endpoint may emit (space form, hyphen form, underscore
  form, and concatenated form) to the internal path key.
* :func:`mural._merge_tags` — must discover the live widget type from a
  GET, then route the PATCH through the typed wrapper (never the generic
  path) so tag mutations land on ``/widgets/sticky-note/{id}``.
"""

from __future__ import annotations

from typing import Any

import pytest

# ---------------------------------------------------------------------------
# _WIDGET_TYPE_API_TO_PATH_KEY: type-string normalization table
# ---------------------------------------------------------------------------


_EXPECTED_TYPE_KEYS: dict[str, str] = {
    # GET-side variants (Mural normalizes types differently on read vs write)
    "sticky note": "stickynote",
    "sticky-note": "stickynote",
    "sticky_note": "stickynote",
    "stickynote": "stickynote",
    "text box": "textbox",
    "text-box": "textbox",
    "text_box": "textbox",
    "textbox": "textbox",
    "shape": "shape",
    "arrow": "arrow",
    "image": "image",
}


def test_widget_type_api_to_path_key_contains_all_known_variants(
    mural_module: Any,
) -> None:
    """Every API type string the GET endpoint may emit must map to a key."""
    table = mural_module._WIDGET_TYPE_API_TO_PATH_KEY
    for type_string, expected_key in _EXPECTED_TYPE_KEYS.items():
        assert type_string in table, (
            f"missing API type variant {type_string!r}; GET responses use "
            "this form and PATCH routing will fall back to the generic "
            "path (which Mural rejects with 404)"
        )
        assert table[type_string] == expected_key, (
            f"variant {type_string!r} routes to {table[type_string]!r} "
            f"but should route to {expected_key!r}"
        )


def test_widget_type_api_to_path_key_includes_sticky_space_form(
    mural_module: Any,
) -> None:
    """Regression: GET returns ``"sticky note"`` (space) for sticky notes."""
    assert "sticky note" in mural_module._WIDGET_TYPE_API_TO_PATH_KEY


def test_widget_type_api_to_path_key_includes_text_box_space_form(
    mural_module: Any,
) -> None:
    """Regression: GET returns ``"text box"`` (space) for text boxes."""
    assert "text box" in mural_module._WIDGET_TYPE_API_TO_PATH_KEY


# ---------------------------------------------------------------------------
# _typed_widget_path: per-variant routing
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("widget_type", "suffix"),
    [
        ("sticky note", "widgets/sticky-note"),
        ("sticky-note", "widgets/sticky-note"),
        ("sticky_note", "widgets/sticky-note"),
        ("stickynote", "widgets/sticky-note"),
        ("text box", "widgets/textbox"),
        ("text-box", "widgets/textbox"),
        ("text_box", "widgets/textbox"),
        ("textbox", "widgets/textbox"),
        ("shape", "widgets/shape"),
        ("arrow", "widgets/arrow"),
        ("image", "widgets/image"),
    ],
)
def test_typed_widget_path_routes_each_variant(
    mural_module: Any, widget_type: str, suffix: str
) -> None:
    """Every variant resolves to the type-specific PATCH/DELETE route."""
    path = mural_module._typed_widget_path("mural-1", "w-1", widget_type)
    assert path == f"/murals/mural-1/{suffix}/w-1"


def test_typed_widget_path_returns_none_for_unknown_type(
    mural_module: Any,
) -> None:
    assert mural_module._typed_widget_path("mural-1", "w-1", "table") is None


def test_typed_widget_path_returns_none_for_missing_type(
    mural_module: Any,
) -> None:
    assert mural_module._typed_widget_path("mural-1", "w-1", None) is None
    assert mural_module._typed_widget_path("mural-1", "w-1", "") is None


def test_typed_widget_path_is_case_and_whitespace_insensitive(
    mural_module: Any,
) -> None:
    assert (
        mural_module._typed_widget_path("mural-1", "w-1", "  Sticky Note  ")
        == "/murals/mural-1/widgets/sticky-note/w-1"
    )


# ---------------------------------------------------------------------------
# _merge_tags: must route PATCH through the typed wrapper
# ---------------------------------------------------------------------------


def _wire_typed_merge_tags(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    *,
    get_response: dict[str, Any],
) -> list[tuple[str, str]]:
    """Wire ``_authenticated_request`` so ``_merge_tags`` exercises routing.

    Returns a list of ``(method, path)`` tuples in call order. The GET
    response is reused for both the pre-PATCH read and the post-PATCH
    re-read so convergence succeeds on the first attempt; the PATCH echo
    response is overlaid for the convergence check.
    """
    calls: list[tuple[str, str]] = []
    state = {"phase": "pre"}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        calls.append((method, path))
        if method == "PATCH":
            sent = kwargs.get("json_body", {}).get("tags", [])
            # Mirror the typed-path response back into the GET envelope
            # so the post-PATCH GET reports the new tag set verbatim.
            state["last_target"] = list(sent)
            state["phase"] = "post"
            return {"id": "w-1", "tags": list(sent)}
        if method != "GET":
            raise AssertionError(f"unexpected method {method!r}")
        if state["phase"] == "post":
            response = dict(get_response)
            inner = dict(response.get("value") or {})
            inner["tags"] = list(state.get("last_target", []))
            response["value"] = inner
            state["phase"] = "pre"
            return response
        return get_response

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    monkeypatch.setattr(mural_module, "_tag_merge_backoff_seconds", lambda: 0.0)
    monkeypatch.setattr(mural_module.time, "sleep", lambda _s: None)
    return calls


def test_merge_tags_routes_through_typed_path_when_get_emits_space_form(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression: GET returns ``type: "sticky note"`` (space form)."""
    get_response = {
        "value": {
            "id": "w-1",
            "type": "sticky note",
            "tags": [],
        }
    }
    calls = _wire_typed_merge_tags(monkeypatch, mural_module, get_response=get_response)

    result = mural_module._merge_tags("mural-1", "w-1", additions=["tag-a"])

    assert result["ok"] is True
    patch_calls = [path for method, path in calls if method == "PATCH"]
    assert patch_calls == ["/murals/mural-1/widgets/sticky-note/w-1"], (
        f"PATCH must route to the typed path; observed {patch_calls!r}"
    )
    # Generic path must never be touched.
    assert "/murals/mural-1/widgets/w-1" not in [
        path for method, path in calls if method == "PATCH"
    ]


def test_merge_tags_routes_through_typed_path_when_get_emits_hyphen_form(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression: GET returns ``type: "sticky-note"`` (hyphen form)."""
    get_response = {
        "value": {
            "id": "w-1",
            "type": "sticky-note",
            "tags": [],
        }
    }
    calls = _wire_typed_merge_tags(monkeypatch, mural_module, get_response=get_response)

    mural_module._merge_tags("mural-1", "w-1", additions=["tag-a"])

    patch_calls = [path for method, path in calls if method == "PATCH"]
    assert patch_calls == ["/murals/mural-1/widgets/sticky-note/w-1"]


def test_merge_tags_uses_top_level_type_when_value_envelope_absent(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """When GET returns a flat record, the top-level ``type`` still routes."""
    get_response = {
        "id": "w-1",
        "type": "shape",
        "tags": [],
    }
    calls = _wire_typed_merge_tags(monkeypatch, mural_module, get_response=get_response)

    mural_module._merge_tags("mural-1", "w-1", additions=["tag-a"])

    patch_calls = [path for method, path in calls if method == "PATCH"]
    assert patch_calls == ["/murals/mural-1/widgets/shape/w-1"]


@pytest.mark.parametrize(
    ("api_type", "suffix"),
    [
        ("sticky note", "sticky-note"),
        ("sticky-note", "sticky-note"),
        ("text box", "textbox"),
        ("text-box", "textbox"),
        ("shape", "shape"),
        ("arrow", "arrow"),
        ("image", "image"),
    ],
)
def test_merge_tags_routes_typed_path_for_every_supported_type(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    api_type: str,
    suffix: str,
) -> None:
    """Each supported widget type drives PATCH to its typed endpoint."""
    get_response = {
        "value": {
            "id": "w-1",
            "type": api_type,
            "tags": [],
        }
    }
    calls = _wire_typed_merge_tags(monkeypatch, mural_module, get_response=get_response)

    mural_module._merge_tags("mural-1", "w-1", additions=["tag-a"])

    patch_calls = [path for method, path in calls if method == "PATCH"]
    assert patch_calls == [f"/murals/mural-1/widgets/{suffix}/w-1"]


# ---------------------------------------------------------------------------
# _patch_widget_or_disambiguate_404: typed path is preferred when known
# ---------------------------------------------------------------------------


def test_patch_widget_uses_typed_path_when_widget_type_supplied(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[str, str]] = []

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        calls.append((method, path))
        return {"id": "w-1"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    mural_module._patch_widget_or_disambiguate_404(
        "mural-1", "w-1", {"tags": []}, widget_type="sticky note"
    )

    assert calls == [("PATCH", "/murals/mural-1/widgets/sticky-note/w-1")]


def test_patch_widget_falls_back_to_get_when_typed_returns_404(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A 404 on the supplied typed path triggers a GET-driven retry."""
    calls: list[tuple[str, str]] = []
    state = {"calls": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        calls.append((method, path))
        state["calls"] += 1
        if state["calls"] == 1:
            # First PATCH against the supplied (incorrect) typed path: 404
            raise mural_module.MuralAPIError(404, "PATH_NOT_FOUND", "wrong type")
        if method == "GET":
            return {"value": {"id": "w-1", "type": "shape"}}
        return {"id": "w-1"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    mural_module._patch_widget_or_disambiguate_404(
        "mural-1", "w-1", {"tags": []}, widget_type="sticky note"
    )

    methods_paths = [(m, p) for m, p in calls]
    assert methods_paths == [
        ("PATCH", "/murals/mural-1/widgets/sticky-note/w-1"),
        ("GET", "/murals/mural-1/widgets/w-1"),
        ("PATCH", "/murals/mural-1/widgets/shape/w-1"),
    ]
