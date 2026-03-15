"""Property tests for build_deck module."""

import re
import tempfile
from pathlib import Path

import pytest
from build_deck import discover_slides, get_slide_layout
from conftest import make_blank_presentation
from hypothesis import given, settings
from hypothesis import strategies as st


@pytest.mark.hypothesis
class TestFuzzDiscoverSlides:
    """Property tests for discover_slides invariants."""

    @given(
        slide_nums=st.lists(
            st.integers(min_value=1, max_value=99), unique=True, max_size=10
        )
    )
    @settings(deadline=None)
    def test_output_is_sorted(self, slide_nums):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            for n in slide_nums:
                d = tmp_path / f"slide-{n}"
                d.mkdir()
                (d / "content.yaml").write_text("title: test")
            result = discover_slides(tmp_path)
            numbers = [num for num, _ in result]
            assert numbers == sorted(numbers)

    @given(
        names=st.lists(
            st.one_of(
                st.integers(min_value=1, max_value=99).map(lambda n: f"slide-{n}"),
                st.text(
                    alphabet="abcdefghijklmnopqrstuvwxyz0123456789-_",
                    min_size=1,
                    max_size=20,
                ),
            ),
            unique=True,
            max_size=12,
        )
    )
    @settings(deadline=None)
    def test_only_matching_dirs(self, names):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            for name in names:
                d = tmp_path / name
                d.mkdir(exist_ok=True)
                (d / "content.yaml").write_text("title: test")
            result = discover_slides(tmp_path)
            for _, path in result:
                assert re.match(r"slide-(\d+)", path.name)
                assert (path / "content.yaml").exists()


@pytest.mark.hypothesis
class TestFuzzGetSlideLayout:
    """Property tests for get_slide_layout fallback chain."""

    @given(layout_name=st.text(min_size=0, max_size=30))
    @settings(deadline=None)
    def test_always_returns_layout(self, layout_name):
        prs = make_blank_presentation()
        result = get_slide_layout(prs, {"layout": layout_name}, {})
        assert result is not None
