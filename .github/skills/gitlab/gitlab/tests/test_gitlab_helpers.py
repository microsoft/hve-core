# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Helper-oriented unit tests for gitlab.py."""

from __future__ import annotations

import pytest

import gitlab


class TestDie:
    """Tests for die."""

    def test_prints_error_and_exits(self, capsys: pytest.CaptureFixture[str]) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.die("boom", gitlab.EXIT_USAGE)

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert capsys.readouterr().err.strip() == "error: boom"


class TestStripGitSuffix:
    """Tests for strip_git_suffix."""

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            ("group/project.git", "group/project"),
            ("group/project", "group/project"),
            (".git", ""),
            ("project.git.git", "project.git"),
        ],
    )
    def test_strips_expected_suffix(self, value: str, expected: str) -> None:
        assert gitlab.strip_git_suffix(value) == expected


class TestValidateNumericId:
    """Tests for validate_numeric_id."""

    @pytest.mark.parametrize("value", ["0", "7", "123456"])
    def test_accepts_numeric_strings(self, value: str) -> None:
        gitlab.validate_numeric_id(value)

    @pytest.mark.parametrize("value", ["", "abc", "12a", "-1", "1.2", " 5 "])
    def test_rejects_non_numeric_values(
        self,
        value: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.validate_numeric_id(value)

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert f"expected numeric ID, got: {value}" in capsys.readouterr().err


class TestValidatePositiveInt:
    """Tests for validate_positive_int."""

    @pytest.mark.parametrize("value", ["0", "1", "250"])
    def test_accepts_digit_strings(self, value: str) -> None:
        gitlab.validate_positive_int(value, "max_results")

    @pytest.mark.parametrize("value", ["", "ten", "5x", "-2", "3.14"])
    def test_rejects_invalid_values(
        self,
        value: str,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.validate_positive_int(value, "max_results")

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert (
            f"max_results must be a positive integer, got: {value}"
            in capsys.readouterr().err
        )


class TestParseFields:
    """Tests for parse_fields."""

    def test_returns_arguments_without_fields(self) -> None:
        arguments = ["mr-list", "opened", "20"]

        cleaned = gitlab.parse_fields(arguments)

        assert cleaned == arguments
        assert gitlab.selected_fields is None

    def test_extracts_fields_and_strips_option(self) -> None:
        cleaned = gitlab.parse_fields(
            ["mr-list", "opened", "--fields", "iid,title,author.name"]
        )

        assert cleaned == ["mr-list", "opened"]
        assert gitlab.selected_fields == ["iid", "title", "author.name"]

    def test_fields_can_appear_before_command_arguments(self) -> None:
        cleaned = gitlab.parse_fields(["--fields", "iid,title", "mr-get", "7"])

        assert cleaned == ["mr-get", "7"]
        assert gitlab.selected_fields == ["iid", "title"]

    def test_requires_value_after_fields(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.parse_fields(["mr-list", "--fields"])

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert (
            "usage: --fields requires a comma-separated value list"
            in capsys.readouterr().err
        )


class TestExtractField:
    """Tests for extract_field."""

    @pytest.mark.parametrize(
        ("payload", "path", "expected"),
        [
            ({"iid": 7}, "iid", "7"),
            ({"author": {"name": "Ada"}}, "author.name", "Ada"),
            ({"labels": ["bug", "urgent"]}, "labels", "bug, urgent"),
            ({"author": None}, "author.name", ""),
            ({"author": {"name": None}}, "author.name", ""),
            ({"author": {"name": "Ada"}}, "author.email", ""),
            ({"nested": {"deep": {"value": 9}}}, "nested.deep.value", "9"),
        ],
    )
    def test_extracts_supported_values(
        self, payload: object, path: str, expected: str
    ) -> None:
        assert gitlab.extract_field(payload, path) == expected

    def test_returns_empty_for_non_mapping_intermediate_value(self) -> None:
        assert gitlab.extract_field({"author": "Ada"}, "author.name") == ""


class TestPrintFields:
    """Tests for print_fields."""

    def test_does_nothing_when_no_fields_selected(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        gitlab.print_fields({"iid": 7})

        assert capsys.readouterr().out == ""

    def test_prints_tabular_output_for_lists(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        gitlab.selected_fields = ["iid", "title"]

        gitlab.print_fields(
            [
                {"iid": 1, "title": "First"},
                {"iid": 2, "title": "Second"},
            ]
        )

        assert capsys.readouterr().out.splitlines() == [
            "iid\ttitle",
            "1\tFirst",
            "2\tSecond",
        ]

    def test_prints_key_value_output_for_single_object(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        gitlab.selected_fields = ["iid", "author.name"]

        gitlab.print_fields({"iid": 9, "author": {"name": "Grace"}})

        assert capsys.readouterr().out.splitlines() == [
            "iid: 9",
            "author.name: Grace",
        ]


class TestLoadJsonPayload:
    """Tests for load_json_payload."""

    @pytest.mark.parametrize(
        ("raw_payload", "expected"),
        [
            ('{"title": "MR"}', {"title": "MR"}),
            ("[1, 2, 3]", [1, 2, 3]),
            ("true", True),
        ],
    )
    def test_parses_valid_json(self, raw_payload: str, expected: object) -> None:
        assert gitlab.load_json_payload(raw_payload, "usage: gitlab") == expected

    def test_raises_usage_error_for_invalid_json(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        with pytest.raises(SystemExit) as exc_info:
            gitlab.load_json_payload("{bad json}", "usage: gitlab mr-create <json>")

        assert exc_info.value.code == gitlab.EXIT_USAGE
        assert "invalid JSON payload" in capsys.readouterr().err
