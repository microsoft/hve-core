# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Regression tests for spatial helpers using locked golden fixtures."""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest

FIXTURES = pathlib.Path(__file__).parent / "fixtures"
CLUSTERS_DIR = FIXTURES / "clusters"
ARROWS_DIR = FIXTURES / "arrows"


def _load(path: pathlib.Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


@pytest.mark.parametrize(
    "fixture_name",
    ["two_clusters", "tight_cluster", "all_noise"],
)
def test_cluster_widgets_matches_golden_fixture(
    mural_module: Any, fixture_name: str
) -> None:
    fixture = _load(CLUSTERS_DIR / f"{fixture_name}.json")
    expected = _load(CLUSTERS_DIR / "expected" / f"{fixture_name}.json")
    params = fixture.get("params", {})
    actual = mural_module.cluster_widgets(
        fixture["widgets"],
        eps_px=float(params.get("eps_px", 120.0)),
        min_samples=int(params.get("min_samples", 2)),
    )
    actual_json = json.dumps(actual, sort_keys=True, indent=2)
    expected_json = json.dumps(expected, sort_keys=True, indent=2)
    assert actual_json == expected_json


def test_build_arrow_graph_iteration_order_is_deterministic(
    mural_module: Any,
) -> None:
    fixture = _load(ARROWS_DIR / "sample.json")
    widgets = fixture["widgets"]
    arrows = fixture["arrows"]
    snap_radius = float(fixture.get("snap_radius", 24.0))

    first_graph = mural_module.build_arrow_graph(
        widgets, arrows, snap_radius=snap_radius
    )
    first_nodes = list(first_graph.nodes())
    first_edges = list(first_graph.edges(keys=True))
    first_summary = mural_module.arrow_graph_summary(first_graph)

    for _ in range(9):
        graph = mural_module.build_arrow_graph(widgets, arrows, snap_radius=snap_radius)
        assert list(graph.nodes()) == first_nodes
        assert list(graph.edges(keys=True)) == first_edges
        summary = mural_module.arrow_graph_summary(graph)
        assert json.dumps(summary, sort_keys=True, indent=2) == json.dumps(
            first_summary, sort_keys=True, indent=2
        )
