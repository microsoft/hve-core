# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Property tests for pptx_tables module."""

import pytest
from conftest import make_blank_slide
from hypothesis import given, settings
from hypothesis import strategies as st
from pptx_tables import add_table_element, extract_table
from strategies import position, table_element


def _build_elem(draw):
    """Merge table_element and position into a complete element dict."""
    elem = draw(table_element())
    pos = draw(position)
    elem.update(pos)
    return elem


@st.composite
def full_table_element(draw):
    """Table element with position keys required by add_table_element."""
    return _build_elem(draw)


@st.composite
def merge_exceeding_element(draw):
    """Table element where merge_right or merge_down exceed table dimensions."""
    elem = _build_elem(draw)
    rows = elem["rows"]
    n_rows = len(rows)
    n_cols = len(elem["columns"])
    # Pick a random cell and add an out-of-bounds merge
    row_idx = draw(st.integers(min_value=0, max_value=n_rows - 1))
    col_idx = draw(st.integers(min_value=0, max_value=n_cols - 1))
    cell = rows[row_idx]["cells"][col_idx]
    direction = draw(st.sampled_from(["merge_right", "merge_down"]))
    overflow = draw(st.integers(min_value=1, max_value=5))
    if direction == "merge_right":
        cell["merge_right"] = n_cols - col_idx + overflow
    else:
        cell["merge_down"] = n_rows - row_idx + overflow
    return elem


@pytest.mark.hypothesis
class TestFuzzTableRoundTrip:
    """Property tests for table add/extract round-trip invariants."""

    @given(data=st.data())
    @settings(deadline=None)
    def test_preserves_row_count(self, data):
        elem = data.draw(full_table_element())
        slide = make_blank_slide()
        add_table_element(slide, elem, colors={}, typography={})
        shape = slide.shapes[-1]
        result = extract_table(shape)
        assert len(result["rows"]) == len(elem["rows"])

    @given(data=st.data())
    @settings(deadline=None)
    def test_preserves_column_count(self, data):
        elem = data.draw(full_table_element())
        slide = make_blank_slide()
        add_table_element(slide, elem, colors={}, typography={})
        shape = slide.shapes[-1]
        result = extract_table(shape)
        assert len(result["columns"]) == len(elem["columns"])

    @given(data=st.data())
    @settings(deadline=None)
    def test_preserves_cell_text(self, data):
        elem = data.draw(full_table_element())
        slide = make_blank_slide()
        add_table_element(slide, elem, colors={}, typography={})
        shape = slide.shapes[-1]
        result = extract_table(shape)
        for row_in, row_out in zip(elem["rows"], result["rows"]):
            for cell_in, cell_out in zip(row_in["cells"], row_out["cells"]):
                expected = str(cell_in.get("text", ""))
                assert cell_out["text"] == expected


@pytest.mark.hypothesis
class TestFuzzMergeBoundary:
    """Property tests for merge operations that exceed table dimensions."""

    @given(data=st.data())
    @settings(deadline=None)
    def test_merge_exceeding_bounds(self, data):
        elem = data.draw(merge_exceeding_element())
        slide = make_blank_slide()
        with pytest.raises(IndexError):
            add_table_element(slide, elem, colors={}, typography={})
