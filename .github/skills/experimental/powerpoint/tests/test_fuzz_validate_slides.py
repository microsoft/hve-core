"""Property tests for validate_slides and validate_deck modules."""

import tempfile
from pathlib import Path

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st
from strategies import severity_results
from validate_deck import max_severity
from validate_slides import IMAGE_PATTERN, discover_images


@pytest.mark.hypothesis
class TestFuzzDiscoverImages:
    """Property tests for discover_images."""

    @settings(deadline=None)
    @given(
        slide_nums=st.lists(
            st.integers(min_value=1, max_value=99), unique=True, max_size=10
        )
    )
    def test_output_is_sorted(self, slide_nums):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            for n in slide_nums:
                (tmp_path / f"slide-{n}.jpg").write_bytes(b"fake")
            result = discover_images(tmp_path)
            numbers = [num for num, _ in result]
            assert numbers == sorted(numbers)

    @settings(deadline=None)
    @given(
        slide_nums=st.lists(
            st.integers(min_value=1, max_value=99), unique=True, max_size=10
        ),
        noise_names=st.lists(
            st.text(
                alphabet="abcdefghijklmnopqrstuvwxyz0123456789-_.",
                min_size=1,
                max_size=20,
            ),
            max_size=5,
        ),
    )
    def test_all_paths_match_pattern(self, slide_nums, noise_names):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            for n in slide_nums:
                (tmp_path / f"slide-{n}.jpg").write_bytes(b"fake")
            for name in noise_names:
                path = tmp_path / name
                if not path.exists():
                    try:
                        path.write_bytes(b"noise")
                    except OSError:
                        pass
            result = discover_images(tmp_path)
            for _, p in result:
                assert IMAGE_PATTERN.match(p.name)


@pytest.mark.hypothesis
class TestFuzzMaxSeverity:
    """Property tests for max_severity."""

    @given(data=severity_results)
    def test_ordering_monotonic(self, data):
        baseline = max_severity(data)
        augmented = {
            "slides": data["slides"]
            + [
                {
                    "slide_number": 999,
                    "issues": [
                        {
                            "check_type": "injected",
                            "severity": "error",
                            "description": "",
                            "location": "",
                        }
                    ],
                }
            ],
            "deck_issues": data.get("deck_issues", []),
        }
        assert max_severity(augmented) == "error"
        # Adding error never decreases severity
        severity_rank = {"none": 0, "info": 1, "warning": 2, "error": 3}
        assert severity_rank[max_severity(augmented)] >= severity_rank[baseline]

    def test_empty_returns_none(self):
        assert max_severity({"slides": []}) == "none"

    @given(data=severity_results)
    def test_result_in_valid_set(self, data):
        result = max_severity(data)
        assert result in {"none", "info", "warning", "error"}
