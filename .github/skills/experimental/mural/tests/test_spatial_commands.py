# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""CLI handler tests for ``mural spatial`` verbs.

Extends the spatial coverage in ``test_mural_commands.py`` with the gap
cases identified during planning: empty pagination results, default mode
selection, default-off rotation-aware behaviour, and bbox-mode region
filtering. Drives commands through ``mural_module.main([...])`` while
monkey-patching ``_authenticated_request`` and ``_paginate``.
"""

from __future__ import annotations

import json
from typing import Any

import pytest
from test_constants import TEST_MURAL_ID


def _patch_request(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    *,
    return_value: Any = None,
) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []

    def _fake(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        return return_value

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake)
    return calls


def _patch_paginate(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    records: list[Any],
) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []

    def _fake(method: str, path: str, **kwargs: Any):
        calls.append({"method": method, "path": path, **kwargs})
        yield from records

    monkeypatch.setattr(mural_module, "_paginate", _fake)
    return calls


# ---------------------------------------------------------------------------
# widgets-in-shape: empty result, default mode, default-off rotation-aware
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_shape_empty_widget_list_emits_empty_array(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert json.loads(capsys.readouterr().out) == []


def test_spatial_widgets_in_shape_default_mode_is_center(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake_widgets_in_shape(widgets, shape, *, mode, rotation_aware):
        captured["mode"] = mode
        captured["rotation_aware"] = rotation_aware
        return []

    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "widgets_in_shape", _fake_widgets_in_shape)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["mode"] == "center"


def test_spatial_widgets_in_shape_rotation_aware_default_off(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake_widgets_in_shape(widgets, shape, *, mode, rotation_aware):
        captured["rotation_aware"] = rotation_aware
        return []

    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    monkeypatch.delenv("MURAL_SPATIAL_ROTATION_ENABLED", raising=False)
    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", False)
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "widgets_in_shape", _fake_widgets_in_shape)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["rotation_aware"] is False


def test_spatial_widgets_in_shape_env_flag_enables_rotation_aware(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake_widgets_in_shape(widgets, shape, *, mode, rotation_aware):
        captured["rotation_aware"] = rotation_aware
        return []

    shape = {"id": "shape1", "x": 0, "y": 0, "width": 100, "height": 100}
    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", True)
    _patch_request(monkeypatch, mural_module, return_value=shape)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "widgets_in_shape", _fake_widgets_in_shape)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-shape",
            "--mural-id",
            TEST_MURAL_ID,
            "--shape-id",
            "shape1",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["rotation_aware"] is True


# ---------------------------------------------------------------------------
# widgets-in-region: empty result, bbox mode, default mode
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_region_empty_widget_list_emits_empty_array(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "100",
            "--h",
            "100",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert json.loads(capsys.readouterr().out) == []


def test_spatial_widgets_in_region_bbox_mode_includes_partial_overlap(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    # bbox mode uses ``rects_overlap`` semantics, so the widget at
    # (90,90)+50x50 (center at (115,115)) overlaps the (0,0)-(100,100)
    # region and is included even though its center lies outside.
    widgets = [
        {"id": "w-contained", "x": 10, "y": 10, "width": 20, "height": 20},
        {"id": "w-partial", "x": 90, "y": 90, "width": 50, "height": 50},
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "100",
            "--h",
            "100",
            "--mode",
            "bbox",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert sorted(w["id"] for w in out) == ["w-contained", "w-partial"]


def test_spatial_widgets_in_region_default_mode_is_center(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake_widgets_in_region(widgets, region, *, mode):
        captured["mode"] = mode
        return []

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "widgets_in_region", _fake_widgets_in_region)

    rc = mural_module.main(
        [
            "spatial",
            "widgets-in-region",
            "--mural-id",
            TEST_MURAL_ID,
            "--x",
            "0",
            "--y",
            "0",
            "--w",
            "100",
            "--h",
            "100",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["mode"] == "center"


# ---------------------------------------------------------------------------
# pairwise-overlaps: empty pagination, default predicate, rotation defaults
# ---------------------------------------------------------------------------


def test_spatial_pairwise_overlaps_empty_widget_list_emits_empty_array(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert json.loads(capsys.readouterr().out) == []


def test_spatial_pairwise_overlaps_default_predicate_is_intersects(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, predicate, rotation_aware):
        captured["predicate"] = predicate
        captured["rotation_aware"] = rotation_aware
        return []

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "pairwise_overlaps", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["predicate"] == "intersects"


def test_spatial_pairwise_overlaps_predicate_contains_propagates(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, predicate, rotation_aware):
        captured["predicate"] = predicate
        return []

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "pairwise_overlaps", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
            "--predicate",
            "contains",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["predicate"] == "contains"


def test_spatial_pairwise_overlaps_rotation_aware_default_off(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, predicate, rotation_aware):
        captured["rotation_aware"] = rotation_aware
        return []

    monkeypatch.delenv("MURAL_SPATIAL_ROTATION_ENABLED", raising=False)
    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", False)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "pairwise_overlaps", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["rotation_aware"] is False


def test_spatial_pairwise_overlaps_env_flag_enables_rotation_aware(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, predicate, rotation_aware):
        captured["rotation_aware"] = rotation_aware
        return []

    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", True)
    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "pairwise_overlaps", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["rotation_aware"] is True


def test_spatial_pairwise_overlaps_emits_pair_records_as_dicts(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    def _fake(widgets, *, predicate, rotation_aware):
        return [("a", "b"), ("a", "c")]

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "pairwise_overlaps", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "pairwise-overlaps",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out == [{"a": "a", "b": "b"}, {"a": "a", "b": "c"}]


# ---------------------------------------------------------------------------
# spatial cluster: empty result, defaults, flag propagation, record emission
# ---------------------------------------------------------------------------


def test_spatial_cluster_empty_widget_list_emits_empty_array(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "cluster",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert json.loads(capsys.readouterr().out) == []


def test_spatial_cluster_default_eps_and_min_samples(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, eps_px, min_samples):
        captured["eps_px"] = eps_px
        captured["min_samples"] = min_samples
        return []

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "cluster_widgets", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "cluster",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["eps_px"] == pytest.approx(120.0)
    assert captured["min_samples"] == 2


def test_spatial_cluster_eps_and_min_samples_propagate(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, eps_px, min_samples):
        captured["eps_px"] = eps_px
        captured["min_samples"] = min_samples
        return []

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "cluster_widgets", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "cluster",
            "--mural-id",
            TEST_MURAL_ID,
            "--eps-px",
            "75.5",
            "--min-samples",
            "4",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["eps_px"] == pytest.approx(75.5)
    assert captured["min_samples"] == 4


def test_spatial_cluster_emits_member_records_as_dicts(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    def _fake(widgets, *, eps_px, min_samples):
        return [["a", "b", "c"], ["d", "e"]]

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "cluster_widgets", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "cluster",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert out == [
        {"members": ["a", "b", "c"]},
        {"members": ["d", "e"]},
    ]


# ---------------------------------------------------------------------------
# spatial sort-along-axis: ordering, output file, axis enum validation,
# origin pairing rule
# ---------------------------------------------------------------------------


def _sort_widget(
    wid: str, x: float, y: float, w: float = 10.0, h: float = 10.0
) -> dict[str, Any]:
    return {"id": wid, "x": x, "y": y, "width": w, "height": h}


def test_spatial_sort_along_axis_default_x_emits_ordered_widgets(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [
        _sort_widget("c", 40.0, 0.0),
        _sort_widget("a", 0.0, 0.0),
        _sort_widget("b", 20.0, 0.0),
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "sort-along-axis",
            "--mural-id",
            TEST_MURAL_ID,
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["a", "b", "c"]


def test_spatial_sort_along_axis_y_axis_orders_by_center_y(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [
        _sort_widget("c", 0.0, 40.0),
        _sort_widget("a", 0.0, 0.0),
        _sort_widget("b", 0.0, 20.0),
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "sort-along-axis",
            "--mural-id",
            TEST_MURAL_ID,
            "--axis",
            "y",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = json.loads(capsys.readouterr().out)
    assert [w["id"] for w in out] == ["a", "b", "c"]


def test_spatial_sort_along_axis_origin_propagates_to_helper(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def _fake(widgets, *, axis, origin):
        captured["axis"] = axis
        captured["origin"] = origin
        return widgets

    _patch_paginate(monkeypatch, mural_module, [])
    monkeypatch.setattr(mural_module, "sort_along_axis", _fake)

    rc = mural_module.main(
        [
            "spatial",
            "sort-along-axis",
            "--mural-id",
            TEST_MURAL_ID,
            "--axis",
            "diagonal",
            "--origin-x",
            "10.5",
            "--origin-y",
            "-3.25",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert captured["axis"] == "diagonal"
    assert captured["origin"] == (10.5, -3.25)


def test_spatial_sort_along_axis_partial_origin_returns_usage_exit_code(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, [])

    rc = mural_module.main(
        [
            "spatial",
            "sort-along-axis",
            "--mural-id",
            TEST_MURAL_ID,
            "--origin-x",
            "5.0",
        ]
    )

    assert rc == mural_module.EXIT_USAGE
    err = capsys.readouterr().err
    assert "--origin-x and --origin-y" in err


def test_spatial_sort_along_axis_invalid_axis_rejected_by_argparse(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    with pytest.raises(SystemExit) as exc:
        mural_module.main(
            [
                "spatial",
                "sort-along-axis",
                "--mural-id",
                TEST_MURAL_ID,
                "--axis",
                "z",
            ]
        )
    assert exc.value.code == 2
    err = capsys.readouterr().err
    assert "--axis" in err


def test_spatial_sort_along_axis_format_table_emits_table(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [
        _sort_widget("b", 20.0, 0.0),
        _sort_widget("a", 0.0, 0.0),
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)

    rc = mural_module.main(
        [
            "spatial",
            "sort-along-axis",
            "--mural-id",
            TEST_MURAL_ID,
            "--format",
            "table",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    # Table output contains both ids in sorted (a before b) order.
    assert out.index("a") < out.index("b")


# ---------------------------------------------------------------------------
# arrow-graph: format selection, snap-radius, output redirection
# ---------------------------------------------------------------------------


def _ag_widgets() -> list[dict[str, Any]]:
    return [
        {
            "id": "a",
            "type": "shape",
            "x": 0.0,
            "y": 0.0,
            "width": 10.0,
            "height": 10.0,
        },
        {
            "id": "b",
            "type": "shape",
            "x": 100.0,
            "y": 0.0,
            "width": 10.0,
            "height": 10.0,
        },
        {
            "id": "e1",
            "type": "arrow",
            "x1": 5.0,
            "y1": 5.0,
            "x2": 105.0,
            "y2": 5.0,
        },
    ]


def test_spatial_arrow_graph_default_format_is_summary_json(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, _ag_widgets())
    rc = mural_module.main(["spatial", "arrow-graph", "--mural-id", TEST_MURAL_ID])
    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert sorted(payload["nodes"]) == ["a", "b"]
    assert payload["edges"] == [{"id": "e1", "source": "a", "target": "b"}]
    assert payload["stats"]["edge_count"] == 1
    assert payload["stats"]["is_dag"] is True
    assert "arrow_widget" not in payload["edges"][0]


def test_spatial_arrow_graph_format_full_includes_arrow_widget(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, _ag_widgets())
    rc = mural_module.main(
        [
            "spatial",
            "arrow-graph",
            "--mural-id",
            TEST_MURAL_ID,
            "--format",
            "full",
        ]
    )
    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload["edges"][0]["arrow_widget"]["id"] == "e1"


def test_spatial_arrow_graph_format_dot_emits_digraph_text(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, _ag_widgets())
    rc = mural_module.main(
        [
            "spatial",
            "arrow-graph",
            "--mural-id",
            TEST_MURAL_ID,
            "--format",
            "dot",
        ]
    )
    assert rc == mural_module.EXIT_SUCCESS
    out = capsys.readouterr().out
    assert out.lstrip().startswith("digraph")
    assert '"a"' in out and '"b"' in out
    assert "->" in out


def test_spatial_arrow_graph_snap_radius_too_small_drops_edge(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    widgets = [
        {
            "id": "a",
            "type": "shape",
            "x": 0.0,
            "y": 0.0,
            "width": 10.0,
            "height": 10.0,
        },
        {
            "id": "b",
            "type": "shape",
            "x": 100.0,
            "y": 0.0,
            "width": 10.0,
            "height": 10.0,
        },
        {
            "id": "e1",
            "type": "arrow",
            "x1": 50.0,
            "y1": 50.0,
            "x2": 150.0,
            "y2": 50.0,
        },
    ]
    _patch_paginate(monkeypatch, mural_module, widgets)
    rc = mural_module.main(
        [
            "spatial",
            "arrow-graph",
            "--mural-id",
            TEST_MURAL_ID,
            "--snap-radius",
            "0.5",
        ]
    )
    assert rc == mural_module.EXIT_SUCCESS
    payload = json.loads(capsys.readouterr().out)
    assert payload["edges"] == []
    assert payload["stats"]["edge_count"] == 0


def test_spatial_arrow_graph_invalid_snap_radius_returns_usage(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _patch_paginate(monkeypatch, mural_module, _ag_widgets())
    rc = mural_module.main(
        [
            "spatial",
            "arrow-graph",
            "--mural-id",
            TEST_MURAL_ID,
            "--snap-radius",
            "0",
        ]
    )
    assert rc == mural_module.EXIT_USAGE


def test_spatial_arrow_graph_output_writes_to_file(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    tmp_path: Any,
) -> None:
    _patch_paginate(monkeypatch, mural_module, _ag_widgets())
    target = tmp_path / "graph.json"
    rc = mural_module.main(
        [
            "spatial",
            "arrow-graph",
            "--mural-id",
            TEST_MURAL_ID,
            "--output",
            str(target),
        ]
    )
    assert rc == mural_module.EXIT_SUCCESS
    captured = capsys.readouterr().out
    assert captured == ""
    payload = json.loads(target.read_text(encoding="utf-8"))
    assert payload["edges"][0]["id"] == "e1"


# ---------------------------------------------------------------------------
# _area_probe_verdict: occluded branch escalation contract
# ---------------------------------------------------------------------------


def test_area_probe_verdict_occluded_recommends_operator_escalation(
    mural_module: Any,
) -> None:
    """The occluded recommendation must route operators to the Mural UI.

    Mural's REST API exposes no canvas z-order operation, so the verdict
    payload is the only place the skill can prevent callers from retrying
    the probe, destroying-and-recreating widgets, or hand-tuning offsets.
    Pin the contract here so future drift in the recommendation string
    fails the build.
    """
    area_id = "area-1"
    probe = {"id": "probe-1", "x": 10, "y": 10, "width": 20, "height": 20}
    occluder = {"id": "occluder-1", "x": 0, "y": 0, "width": 100, "height": 100}
    area_chain = [{"id": area_id, "type": "area"}]

    result = mural_module._area_probe_verdict(
        probe=probe,
        siblings=[occluder],
        area_chain=area_chain,
        expected_area_id=area_id,
    )

    assert result["verdict"] == "occluded"
    assert result["siblings_above"] == ["occluder-1"]
    rec = result["recommendation"]
    assert "occluder-1" in rec
    assert "Mural UI" in rec
    assert "'Send to Back'" in rec and "'Bring to Front'" in rec
    assert "anchor restructure" in rec
    assert "Pause the workflow" in rec
    assert "Do not re-run the probe" in rec
    assert "destroy and recreate" in rec
    assert "hand-tune (x, y) offsets" in rec
    assert "mural-seeding-patterns.instructions.md" in rec
