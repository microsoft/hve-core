"""Tests for pptx_utils module."""

import pytest
import yaml
from pptx_utils import emu_to_inches, load_yaml


class TestEmuToInches:
    """Tests for emu_to_inches conversion."""

    @pytest.mark.parametrize(
        "emu,expected",
        [
            (914400, 1.0),
            (0, 0.0),
            (None, 0.0),
            (457200, 0.5),
            (-914400, -1.0),
            (914400 * 13, 13.0),
        ],
    )
    def test_conversion(self, emu, expected):
        assert emu_to_inches(emu) == expected

    def test_fractional(self):
        result = emu_to_inches(914401)
        assert isinstance(result, float)
        assert result == pytest.approx(1.0, abs=0.001)


class TestLoadYaml:
    """Tests for load_yaml file loading."""

    def test_valid_yaml(self, tmp_path):
        f = tmp_path / "test.yaml"
        f.write_text(yaml.dump({"key": "value", "num": 42}), encoding="utf-8")
        result = load_yaml(f)
        assert result == {"key": "value", "num": 42}

    def test_empty_yaml(self, tmp_path):
        f = tmp_path / "empty.yaml"
        f.write_text("", encoding="utf-8")
        result = load_yaml(f)
        assert result == {}

    def test_yaml_with_list(self, tmp_path):
        f = tmp_path / "list.yaml"
        data = {"items": [1, 2, 3]}
        f.write_text(yaml.dump(data), encoding="utf-8")
        result = load_yaml(f)
        assert result == data

    def test_nested_yaml(self, tmp_path):
        f = tmp_path / "nested.yaml"
        data = {"outer": {"inner": "value"}}
        f.write_text(yaml.dump(data), encoding="utf-8")
        result = load_yaml(f)
        assert result == data
