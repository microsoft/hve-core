# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Behavioral tests for the settings upsert executable.

Every test runs against a temporary file. Nothing here reads or writes a real
VS Code settings file.
"""

from __future__ import annotations

import datetime
import json
import pathlib

import pytest
from settings_upsert import (
    BACKUP_RETENTION,
    EXIT_INTERRUPTED,
    EXIT_OK,
    EXIT_REFUSED,
    SCHEMA,
    SCHEMA_SOURCE,
    SettingsError,
    apply_changes,
    backup_path_for,
    check_policy,
    main,
    parse_assignment,
    prune_backups,
    read_settings,
    resolve_audit_path,
    strip_jsonc,
    summarize,
    top_level_spans,
    upsert,
)

ENABLED = "github.copilot.chat.otel.enabled"
EXPORTER = "github.copilot.chat.otel.exporterType"
ENDPOINT = "github.copilot.chat.otel.otlpEndpoint"
CAPTURE = "github.copilot.chat.otel.captureContent"
OUTFILE = "github.copilot.chat.otel.outfile"
MAXSIZE = "github.copilot.chat.otel.maxAttributeSizeChars"

EXISTING = """{
  // A comment the edit must not disturb.
  "editor.fontSize": 13,
  "github.copilot.chat.otel.enabled": false,
  /* block comment */
  "workbench.colorTheme": "Default Dark+"
}
"""


@pytest.fixture()
def settings_file(tmp_path: pathlib.Path) -> pathlib.Path:
    path = tmp_path / "settings.json"
    path.write_text(EXISTING, encoding="utf-8")
    return path


class TestSchemaProvenance:
    """The schema records where it came from and matches the verified build."""

    def test_given_schema_source_when_provenance_fields_read_then_each_is_populated(self) -> None:
        # Act & Assert
        for field in ("artifact", "extension", "version", "retrieved_from", "verified"):
            assert SCHEMA_SOURCE[field]

    def test_given_the_schema_when_keys_counted_then_seven_otel_prefixed_keys_exist(self) -> None:
        # Act & Assert
        assert len(SCHEMA) == 7
        assert all(key.startswith("github.copilot.chat.otel.") for key in SCHEMA)


class TestAssignmentParsing:
    """Keys and types are checked before anything else happens."""

    def test_given_an_unknown_setting_key_when_parsing_assignment_then_unknown_key_is_raised(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="unknown key"):
            parse_assignment("github.copilot.chat.otel.protocol=grpc")

    def test_given_an_assignment_without_an_equals_when_parsing_then_key_value_is_raised(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="key=value"):
            parse_assignment(ENABLED)

    def test_given_a_boolean_key_when_parsing_a_non_boolean_value_then_boolean_error_is_raised(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="boolean"):
            parse_assignment(f"{ENABLED}=yes")

    def test_given_an_integer_key_when_parsing_a_non_integer_value_then_integer_error_is_raised(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="integer"):
            parse_assignment(f"{MAXSIZE}=lots")

    @pytest.mark.parametrize(("raw", "expected"), [("true", True), ("false", False)])
    def test_given_a_boolean_key_when_parsing_true_or_false_then_a_python_bool_is_returned(
        self,
        raw: str,
        expected: bool,
    ) -> None:
        # Act & Assert
        assert parse_assignment(f"{ENABLED}={raw}") == (ENABLED, expected)

    def test_given_an_integer_key_when_parsing_a_numeric_value_then_an_int_is_returned(
        self,
    ) -> None:
        # Act & Assert
        assert parse_assignment(f"{MAXSIZE}=2048") == (MAXSIZE, 2048)


class TestPolicy:
    """Value combinations the schema cannot express are refused."""

    def test_given_capture_content_true_when_checking_policy_then_capture_content_is_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="captureContent"):
            check_policy({CAPTURE: True})

    def test_given_capture_content_false_when_checking_policy_then_no_error_is_raised(self) -> None:
        # Act & Assert
        check_policy({CAPTURE: False})

    def test_given_an_unknown_exporter_type_when_checking_policy_then_exporter_type_is_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="exporterType"):
            check_policy({EXPORTER: "otlp-quic"})

    @pytest.mark.parametrize(
        "endpoint",
        [
            "http://evil.example.com:4318",
            "file:///tmp/spans",
            "http://user:pass@localhost:4318",
            "http://localhost:22",
        ],
    )
    def test_given_an_unsafe_endpoint_when_checking_policy_then_otlp_endpoint_is_refused(
        self,
        endpoint: str,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="otlpEndpoint"):
            check_policy({ENDPOINT: endpoint})

    def test_given_the_localhost_collector_endpoint_when_checking_policy_then_it_is_allowed(
        self,
    ) -> None:
        # Act & Assert
        check_policy({ENDPOINT: "http://localhost:4318"})

    def test_given_an_outfile_and_otlp_exporter_when_checking_policy_then_outfile_is_refused(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        outfile = str(tmp_path / "spans.jsonl")

        # Act & Assert
        with pytest.raises(SettingsError, match="outfile"):
            check_policy({OUTFILE: outfile, EXPORTER: "otlp-http"})

    def test_given_an_outfile_and_file_exporter_when_checking_policy_then_it_is_allowed(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        check_policy({OUTFILE: str(tmp_path / "spans.jsonl"), EXPORTER: "file"})

    def test_given_a_negative_max_attribute_size_when_checking_policy_then_negative_is_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="negative"):
            check_policy({MAXSIZE: -1})


class TestMergedStatePolicy:
    """Cross-setting rules are judged on the file that would result.

    Checking only this invocation's arguments let a contradiction be assembled
    across two runs: set `outfile` once, set `exporterType` later, and each run
    passes while the resulting file says both.
    """

    def test_given_an_existing_outfile_when_checking_a_new_otlp_exporter_then_outfile_is_refused(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        existing = {OUTFILE: str(tmp_path / "spans.jsonl")}

        # Act & Assert
        with pytest.raises(SettingsError, match="outfile"):
            check_policy({EXPORTER: "otlp-http"}, existing=existing)

    def test_given_an_existing_otlp_exporter_when_checking_a_new_outfile_then_outfile_is_refused(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="outfile"):
            check_policy({OUTFILE: str(tmp_path / "spans.jsonl")}, existing={EXPORTER: "otlp-http"})

    def test_given_an_existing_otlp_exporter_when_outfile_and_file_exporter_are_set_then_allowed(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Act & Assert
        check_policy(
            {OUTFILE: str(tmp_path / "spans.jsonl"), EXPORTER: "file"},
            existing={EXPORTER: "otlp-http"},
        )

    def test_given_an_existing_unknown_exporter_when_checking_an_unrelated_change_then_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="exporterType"):
            check_policy({ENABLED: True}, existing={EXPORTER: "otlp-quic"})

    def test_given_an_existing_off_policy_endpoint_when_setting_an_exporter_then_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="already holds an otlpEndpoint"):
            check_policy(
                {EXPORTER: "otlp-http"}, existing={ENDPOINT: "http://evil.example.com:4318"}
            )

    def test_given_an_existing_off_policy_endpoint_when_a_local_endpoint_replaces_it_then_allowed(
        self,
    ) -> None:
        # Act & Assert
        check_policy(
            {ENDPOINT: "http://localhost:4318"},
            existing={ENDPOINT: "http://evil.example.com:4318"},
        )

    def test_given_capture_content_already_enabled_when_enabling_otel_then_refused(self) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="already enabled"):
            check_policy({ENABLED: True}, existing={CAPTURE: True})

    def test_given_capture_content_already_enabled_when_it_is_turned_off_then_allowed(self) -> None:
        # Act & Assert
        check_policy({CAPTURE: False}, existing={CAPTURE: True})


class TestSplitInvocationWrites:
    """What reaches disk is validated, not just the arguments of the run writing it.

    This is the shape a single-invocation test cannot reach. The off-policy
    value is already in the file -- hand-edited, or written before this policy
    existed -- and the current run's own argument is clean. Checking only the
    argument writes the combined document without ever judging it.

    These go through `apply_changes` rather than `check_policy` because the
    claim is about the write path, and `apply_changes` is the only caller of
    `write_atomically`, which is the only writer of the settings document.
    """

    def test_given_a_file_holding_an_off_policy_endpoint_when_applying_a_clean_edit_then_refused(
        self, settings_file: pathlib.Path
    ) -> None:
        # Arrange
        settings_file.write_text(
            json.dumps({ENDPOINT: "http://evil.example.com:4318"}, indent=2), encoding="utf-8"
        )

        # Act & Assert
        with pytest.raises(SettingsError, match="already holds an otlpEndpoint"):
            apply_changes(settings_file, {ENABLED: True}, apply=True)

    def test_given_a_refused_apply_when_the_document_is_reread_then_it_is_byte_identical(
        self, settings_file: pathlib.Path
    ) -> None:
        # Arrange
        original = json.dumps({ENDPOINT: "http://evil.example.com:4318"}, indent=2)
        settings_file.write_text(original, encoding="utf-8")

        # Act
        with pytest.raises(SettingsError):
            apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        assert settings_file.read_text(encoding="utf-8") == original

    def test_given_a_file_holding_enabled_capture_content_when_applying_a_clean_edit_then_refused(
        self, settings_file: pathlib.Path
    ) -> None:
        # Arrange
        settings_file.write_text(json.dumps({CAPTURE: True}, indent=2), encoding="utf-8")

        # Act & Assert
        with pytest.raises(SettingsError, match="already enabled"):
            apply_changes(settings_file, {ENABLED: True}, apply=True)

    def test_given_a_stored_off_policy_endpoint_when_applying_a_local_endpoint_then_it_is_written(
        self, settings_file: pathlib.Path
    ) -> None:
        # Arrange
        settings_file.write_text(
            json.dumps({ENDPOINT: "http://evil.example.com:4318"}, indent=2), encoding="utf-8"
        )

        # Act
        apply_changes(settings_file, {ENDPOINT: "http://localhost:4318"}, apply=True)

        # Assert
        written = json.loads(settings_file.read_text(encoding="utf-8"))
        assert written[ENDPOINT] == "http://localhost:4318"


class TestOutfilePolicy:
    """Captured spans may not land somewhere nobody chose."""

    def test_given_a_relative_outfile_path_when_checking_policy_then_absolute_is_required(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="absolute"):
            check_policy({OUTFILE: "spans.jsonl", EXPORTER: "file"})

    def test_given_an_outfile_inside_this_repository_when_checking_policy_then_it_is_refused(
        self,
    ) -> None:
        # Arrange
        inside = str(pathlib.Path(__file__).resolve().parent / "spans.jsonl")

        # Act & Assert
        with pytest.raises(SettingsError, match="inside this repository"):
            check_policy({OUTFILE: inside, EXPORTER: "file"})

    def test_given_a_foreign_platform_absolute_outfile_when_checking_policy_then_it_is_accepted(
        self,
    ) -> None:
        """A settings file is routinely authored on one platform for another."""
        # Act & Assert
        check_policy({OUTFILE: "/var/log/copilot/spans.jsonl", EXPORTER: "file"})


class TestRemoteEndpointOptIn:
    """A remote endpoint is a deliberate choice, not a default."""

    def test_given_a_remote_endpoint_when_checking_policy_without_the_opt_in_then_it_is_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="otlpEndpoint"):
            check_policy({ENDPOINT: "https://93.184.216.34:4318"})

    def test_given_a_remote_https_endpoint_when_the_opt_in_is_set_then_it_is_allowed(self) -> None:
        # Act & Assert
        check_policy({ENDPOINT: "https://93.184.216.34:4318"}, allow_remote_endpoint=True)

    def test_given_a_plaintext_remote_endpoint_when_the_opt_in_is_set_then_it_is_still_refused(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="otlpEndpoint"):
            check_policy({ENDPOINT: "http://93.184.216.34:4318"}, allow_remote_endpoint=True)


class TestJsoncHandling:
    """Comments survive, offsets line up, and only the target value moves."""

    def test_given_a_document_with_comments_when_stripping_jsonc_then_length_is_unchanged(
        self,
    ) -> None:
        # Act
        stripped = strip_jsonc(EXISTING)

        # Assert
        assert len(stripped) == len(EXISTING)
        assert "//" not in stripped
        assert "block comment" not in stripped
        assert json.loads(stripped)["editor.fontSize"] == 13

    def test_given_a_url_inside_a_string_when_stripping_jsonc_then_the_string_survives(
        self,
    ) -> None:
        # Arrange
        text = '{"a": "http://example.com/x"}'

        # Act & Assert
        assert json.loads(strip_jsonc(text))["a"] == "http://example.com/x"

    def test_given_a_jsonc_document_when_scanning_top_level_spans_then_each_key_is_located(
        self,
    ) -> None:
        # Act
        spans = top_level_spans(EXISTING)

        # Assert
        assert set(spans) >= {"editor.fontSize", ENABLED, "workbench.colorTheme"}
        start, end = spans[ENABLED]
        assert EXISTING[start:end] == "false"

    def test_given_a_commented_document_when_upserting_a_key_then_only_that_value_changes(
        self,
    ) -> None:
        # Act
        updated = upsert(EXISTING, {ENABLED: True})

        # Assert
        assert "// A comment the edit must not disturb." in updated
        assert "/* block comment */" in updated
        assert json.loads(strip_jsonc(updated))[ENABLED] is True
        assert json.loads(strip_jsonc(updated))["editor.fontSize"] == 13

    def test_given_a_document_without_the_key_when_upserting_then_the_key_is_appended(self) -> None:
        # Act
        updated = upsert(EXISTING, {ENDPOINT: "http://localhost:4318"})

        # Assert
        assert json.loads(strip_jsonc(updated))[ENDPOINT] == "http://localhost:4318"
        assert "// A comment the edit must not disturb." in updated

    def test_given_an_empty_json_object_when_upserting_a_key_then_the_key_is_the_only_entry(
        self,
    ) -> None:
        # Act
        updated = upsert("{}\n", {ENABLED: True})

        # Assert
        assert json.loads(strip_jsonc(updated)) == {ENABLED: True}

    def test_given_a_language_scoped_override_when_upserting_then_only_the_top_level_key_changes(
        self,
    ) -> None:
        """A language-scoped override must not absorb the edit.

        The span scanner is hand-written, so this is the case most likely to
        break silently under a later change: the write would land in a
        `"[python]"` block and the user's real setting would stay unchanged.
        """
        # Arrange
        nested = '{\n  "[python]": { "' + ENABLED + '": false },\n  "' + ENABLED + '": false\n}\n'

        # Act & Assert
        assert set(top_level_spans(nested)) == {"[python]", ENABLED}

        parsed = json.loads(strip_jsonc(upsert(nested, {ENABLED: True})))
        assert parsed[ENABLED] is True, "the top-level key was not updated"
        assert parsed["[python]"][ENABLED] is False, "the nested override was overwritten"


class TestCommandLine:
    """Argument handling refuses ambiguous input before touching a file."""

    def test_given_two_set_flags_for_one_key_when_running_main_then_it_exits_refused(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        code = main(
            [
                "--settings",
                str(settings_file),
                "--set",
                f"{ENABLED}=true",
                "--set",
                f"{ENABLED}=false",
                "--apply",
            ]
        )

        # Assert
        assert code == EXIT_REFUSED
        assert settings_file.read_text(encoding="utf-8") == EXISTING

    def test_given_no_set_flags_when_running_main_then_it_exits_refused(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act & Assert
        assert main(["--settings", str(settings_file)]) == EXIT_REFUSED
        assert settings_file.read_text(encoding="utf-8") == EXISTING


class TestExitConventions:
    """The exit code distinguishes a refusal from a crash and from an interrupt."""

    def test_given_a_valid_assignment_when_running_main_without_apply_then_it_exits_ok(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act & Assert
        assert main(["--settings", str(settings_file), "--set", f"{ENABLED}=true"]) == EXIT_OK

    def test_given_a_policy_violating_assignment_when_running_main_then_it_exits_refused(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        code = main(["--settings", str(settings_file), "--set", f"{CAPTURE}=true", "--apply"])

        # Assert
        assert code == EXIT_REFUSED

    def test_given_a_keyboard_interrupt_during_apply_when_running_main_then_it_exits_interrupted(
        self, settings_file: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        def interrupt(*args: object, **kwargs: object) -> str:
            raise KeyboardInterrupt

        monkeypatch.setattr("settings_upsert.apply_changes", interrupt)

        # Act
        code = main(["--settings", str(settings_file), "--set", f"{ENABLED}=true"])

        # Assert
        assert code == EXIT_INTERRUPTED

    def test_given_the_example_module_source_when_inspecting_the_entry_point_then_sys_exit_main(
        self,
    ) -> None:
        """`raise SystemExit(main())` and `sys.exit(main())` differ to a reader."""
        # Act
        source = (
            pathlib.Path(__file__).resolve().parents[1] / "examples" / "settings_upsert.py"
        ).read_text(encoding="utf-8")

        # Assert
        assert "sys.exit(main())" in source

    def test_given_the_example_module_source_when_inspecting_diagnostics_then_a_module_logger(
        self,
    ) -> None:
        # Act
        source = (
            pathlib.Path(__file__).resolve().parents[1] / "examples" / "settings_upsert.py"
        ).read_text(encoding="utf-8")

        # Assert
        assert 'LOGGER = logging.getLogger("settings_upsert")' in source
        assert "def configure_logging(" in source

    def test_given_print_raising_broken_pipe_when_running_main_then_it_is_silenced_and_exits_ok(
        self, settings_file: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """A quit pager is the reader leaving, not the edit failing.

        The real redirect replaces this process's stdout descriptor, which
        would take the test runner's capture with it, so the handler's effect
        is recorded rather than performed.
        """
        # Arrange
        silenced: list[str] = []

        def broken(*args: object, **kwargs: object) -> None:
            raise BrokenPipeError

        monkeypatch.setattr("builtins.print", broken)
        monkeypatch.setattr(
            "settings_upsert.silence_broken_pipe", lambda: silenced.append("silenced")
        )

        # Act & Assert
        assert main(["--settings", str(settings_file), "--set", f"{ENABLED}=true"]) == EXIT_OK
        assert silenced == ["silenced"]


class TestApply:
    """Dry runs write nothing; applied edits are backed up and reversible."""

    def test_given_a_settings_file_when_applying_changes_with_apply_false_then_it_is_unchanged(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=False)

        # Assert
        assert settings_file.read_text(encoding="utf-8") == EXISTING

    def test_given_a_settings_file_when_applying_a_change_then_it_is_written_and_backed_up(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        assert json.loads(strip_jsonc(settings_file.read_text(encoding="utf-8")))[ENABLED] is True
        backups = list(settings_file.parent.glob(f"{settings_file.name}.*.bak"))
        assert len(backups) == 1
        assert backups[0].read_text(encoding="utf-8") == EXISTING

    def test_given_other_settings_in_the_file_when_applying_a_change_then_they_are_preserved(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        parsed = json.loads(strip_jsonc(settings_file.read_text(encoding="utf-8")))
        assert parsed["editor.fontSize"] == 13
        assert parsed["workbench.colorTheme"] == "Default Dark+"

    def test_given_a_policy_violating_change_when_applying_then_no_write_or_backup_occurs(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        with pytest.raises(SettingsError):
            apply_changes(settings_file, {CAPTURE: True}, apply=True)

        # Assert
        assert settings_file.read_text(encoding="utf-8") == EXISTING
        assert list(settings_file.parent.glob(f"{settings_file.name}.*.bak")) == []

    def test_given_a_malformed_jsonc_file_when_applying_a_change_then_not_valid_jsonc_is_raised(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        broken = tmp_path / "settings.json"
        broken.write_text('{"a": [1, 2', encoding="utf-8")

        # Act
        with pytest.raises(SettingsError, match="not valid JSONC"):
            apply_changes(broken, {ENABLED: True}, apply=True)

        # Assert
        assert broken.read_text(encoding="utf-8") == '{"a": [1, 2'

    def test_given_a_missing_settings_file_when_applying_a_change_then_only_that_key_is_written(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        target = tmp_path / "settings.json"

        # Act
        apply_changes(target, {ENABLED: True}, apply=True)

        # Assert
        assert json.loads(strip_jsonc(target.read_text(encoding="utf-8"))) == {ENABLED: True}


class TestAudit:
    """Audit evidence is durable and carries no sensitive value verbatim."""

    def test_given_an_audit_path_when_applying_a_change_then_a_record_with_the_diff_is_appended(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Arrange
        audit = settings_file.parent / "audit.jsonl"

        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True, audit_path=audit)

        # Assert
        record = json.loads(audit.read_text(encoding="utf-8").strip())
        assert record["changes"][ENABLED] == {"from": False, "to": True}
        assert record["schema_version"] == SCHEMA_SOURCE["version"]

    def test_given_an_audit_path_when_applying_two_changes_then_two_records_are_written(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Arrange
        audit = settings_file.parent / "audit.jsonl"

        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True, audit_path=audit)
        apply_changes(settings_file, {ENABLED: False}, apply=True, audit_path=audit)

        # Assert
        assert len(audit.read_text(encoding="utf-8").strip().splitlines()) == 2

    def test_given_an_outfile_path_when_summarizing_then_only_a_length_is_recorded(self) -> None:
        # Act
        summarized = summarize(OUTFILE, "/home/someone/private/spans.jsonl")

        # Assert
        assert "private" not in str(summarized)
        assert "length" in str(summarized)

    def test_given_an_ordinary_boolean_when_summarizing_then_the_value_is_returned_unchanged(
        self,
    ) -> None:
        # Act & Assert
        assert summarize(ENABLED, True) is True

    def test_given_an_endpoint_with_a_path_and_query_when_summarizing_then_only_the_origin_remains(
        self,
    ) -> None:
        """A path or query on an OTLP endpoint is operator-supplied.

        It is where a tenant identifier or a token would sit, and it is not
        needed to answer the question the record is kept for.
        """
        # Act
        summarized = summarize(ENDPOINT, "https://ingest.example.com:4318/v1/traces?token=abc123")

        # Assert
        assert summarized == "https://ingest.example.com:4318"
        assert "token" not in str(summarized)
        assert "v1/traces" not in str(summarized)

    def test_given_an_endpoint_with_userinfo_when_summarizing_then_the_credential_is_dropped(
        self,
    ) -> None:
        """The netloc carries the credential; the host and port do not."""
        # Act
        summarized = summarize(ENDPOINT, "https://someone:s3cret@ingest.example.com:4318/v1")

        # Assert
        assert summarized == "https://ingest.example.com:4318"
        assert "s3cret" not in str(summarized)
        assert "someone" not in str(summarized)

    def test_given_a_loopback_endpoint_with_a_path_when_summarizing_then_the_origin_remains(
        self,
    ) -> None:
        # Act & Assert
        assert summarize(ENDPOINT, "http://localhost:4318/v1/traces") == "http://localhost:4318"

    def test_given_an_unparseable_endpoint_when_summarizing_then_the_secret_path_is_not_kept(
        self,
    ) -> None:
        # Act
        summarized = summarize(ENDPOINT, "not-a-url-at-all/secret-path")

        # Assert
        assert "secret-path" not in str(summarized)

    def test_given_an_absent_endpoint_when_summarizing_then_none_is_returned(self) -> None:
        # Act & Assert
        assert summarize(ENDPOINT, None) is None


class TestDocumentShapes:
    """A settings file a person can reasonably have is editable.

    Refusing an empty or comments-only document meant the tool could not make
    the first edit to a settings file that had never held a setting, which is
    exactly when it is most useful.
    """

    @pytest.mark.parametrize("content", ["", "   \n\n", "// nothing set yet\n"])
    def test_given_an_effectively_empty_document_when_applying_a_change_then_the_key_is_written(
        self, tmp_path: pathlib.Path, content: str
    ) -> None:
        # Arrange
        target = tmp_path / "settings.json"
        target.write_text(content, encoding="utf-8")

        # Act
        apply_changes(target, {ENABLED: True}, apply=True)

        # Assert
        assert json.loads(strip_jsonc(target.read_text(encoding="utf-8-sig")))[ENABLED] is True

    def test_given_a_comments_only_document_when_applying_a_change_then_the_comment_survives(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        target = tmp_path / "settings.json"
        target.write_text("// a note the operator left\n", encoding="utf-8")

        # Act
        apply_changes(target, {ENABLED: True}, apply=True)

        # Assert
        assert "a note the operator left" in target.read_text(encoding="utf-8")

    def test_given_a_document_with_a_byte_order_mark_when_applying_a_change_then_the_mark_remains(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        """VS Code wrote it; removing it is an unrelated change to the file."""
        # Arrange
        target = tmp_path / "settings.json"
        target.write_bytes(b"\xef\xbb\xbf" + EXISTING.encode("utf-8"))

        # Act
        apply_changes(target, {ENABLED: True}, apply=True)

        # Assert
        assert target.read_bytes().startswith(b"\xef\xbb\xbf")
        assert json.loads(strip_jsonc(target.read_text(encoding="utf-8-sig")))[ENABLED] is True

    def test_given_a_document_without_a_byte_order_mark_when_applying_a_change_then_none_is_added(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        assert not settings_file.read_bytes().startswith(b"\xef\xbb\xbf")

    def test_given_a_file_with_a_byte_order_mark_when_reading_settings_then_it_is_returned_apart(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        target = tmp_path / "settings.json"
        target.write_bytes(b"\xef\xbb\xbf{}\n")

        # Act
        bom, text = read_settings(target)

        # Assert
        assert bom == "\ufeff"
        assert not text.startswith("\ufeff")


class TestAtomicWrite:
    """An interrupted write may not leave a truncated settings file.

    Writing in place truncates before it writes, so a failure at the wrong
    moment destroys the document. Staging beside the target and replacing means
    the file is either the old one or the new one.
    """

    def test_given_os_replace_failing_when_applying_a_change_then_the_original_file_is_intact(
        self, settings_file: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        def fail(*args: object, **kwargs: object) -> None:
            raise OSError("disk full")

        monkeypatch.setattr("settings_upsert.os.replace", fail)

        # Act
        with pytest.raises(OSError, match="disk full"):
            apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        assert settings_file.read_text(encoding="utf-8") == EXISTING

    def test_given_os_replace_failing_when_applying_a_change_then_no_staged_file_remains(
        self, settings_file: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        def fail(*args: object, **kwargs: object) -> None:
            raise OSError("disk full")

        monkeypatch.setattr("settings_upsert.os.replace", fail)

        # Act
        with pytest.raises(OSError):
            apply_changes(settings_file, {ENABLED: True}, apply=True)

        # Assert
        assert list(settings_file.parent.glob("*.staged")) == []

    def test_given_os_replace_failing_when_applying_to_a_missing_file_then_none_is_created(
        self, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        target = tmp_path / "settings.json"

        def fail(*args: object, **kwargs: object) -> None:
            raise OSError("disk full")

        monkeypatch.setattr("settings_upsert.os.replace", fail)

        # Act
        with pytest.raises(OSError):
            apply_changes(target, {ENABLED: True}, apply=True)

        # Assert
        assert not target.exists()


class TestAuditPathAliases:
    """An audit path may not be an alias for the file being protected.

    Containing the path to the settings directory was worse than useless: it
    silently moved the operator's chosen path into the one directory where an
    appended JSON line destroys the settings file or its backup.
    """

    def test_given_the_settings_path_as_the_audit_path_when_resolving_then_it_is_refused(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="settings file itself"):
            resolve_audit_path(str(settings_file), settings_file)

    def test_given_a_backup_path_as_the_audit_path_when_resolving_then_it_is_refused(
        self, settings_file: pathlib.Path
    ) -> None:
        # Arrange
        backup = backup_path_for(settings_file)

        # Act & Assert
        with pytest.raises(SettingsError, match="settings backup"):
            resolve_audit_path(str(backup), settings_file)

    def test_given_a_directory_as_the_audit_path_when_resolving_then_it_is_refused(
        self, settings_file: pathlib.Path, tmp_path: pathlib.Path
    ) -> None:
        # Act & Assert
        with pytest.raises(SettingsError, match="directory"):
            resolve_audit_path(str(tmp_path), settings_file)

    def test_given_an_audit_path_outside_the_settings_directory_when_resolving_then_it_is_kept(
        self, settings_file: pathlib.Path, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        chosen = tmp_path.parent / "audit-elsewhere.jsonl"

        # Act & Assert
        assert resolve_audit_path(str(chosen), settings_file) == chosen.resolve()

    def test_given_a_relative_audit_path_when_resolving_then_it_resolves_against_the_cwd(
        self, settings_file: pathlib.Path, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        elsewhere = tmp_path / "cwd"
        elsewhere.mkdir()
        monkeypatch.chdir(elsewhere)

        # Act & Assert
        assert (
            resolve_audit_path("audit.jsonl", settings_file)
            == (elsewhere / "audit.jsonl").resolve()
        )


class TestBackupRetention:
    """A backup that overwrites the previous backup is not a backup.

    The original defect was a constant `.bak` name: the first run preserved the
    operator's file, and the second run replaced that preserved copy with the
    already-edited one, destroying the only record of the original.
    """

    def test_given_two_applies_when_listing_backups_then_both_originals_are_retained(
        self, settings_file: pathlib.Path
    ) -> None:
        # Act
        apply_changes(settings_file, {ENABLED: True}, apply=True)
        after_first = settings_file.read_text(encoding="utf-8")
        apply_changes(settings_file, {ENABLED: False}, apply=True)

        # Assert
        backups = sorted(settings_file.parent.glob(f"{settings_file.name}.*.bak"))
        assert len(backups) == 2
        contents = {path.read_text(encoding="utf-8") for path in backups}
        assert EXISTING in contents, "the operator's original file was not retained"
        assert after_first in contents

    def test_given_an_existing_backup_name_when_building_another_then_a_distinct_name_is_returned(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text("{}\n", encoding="utf-8")
        first = backup_path_for(settings)
        first.write_text("taken", encoding="utf-8")

        # Act
        second = backup_path_for(settings)

        # Assert
        assert second != first
        assert not second.exists()

    def test_given_three_backups_created_in_order_when_sorting_names_then_creation_order_is_kept(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        """Retention reads name order to decide what to delete.

        An optional collision suffix put `...Z-1.bak` before `...Z.bak`, which
        would have made pruning remove the newest backups and keep the oldest.
        """
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text("{}\n", encoding="utf-8")
        names = []

        # Act
        for _ in range(3):
            candidate = backup_path_for(settings)
            candidate.write_text("taken", encoding="utf-8")
            names.append(candidate.name)

        # Assert
        assert names == sorted(names)

    def test_given_a_deleted_backup_in_one_second_when_building_another_then_the_index_advances(
        self, tmp_path: pathlib.Path
    ) -> None:
        """Retention frees a low index; reusing it would invert creation order.

        Every name here shares one timestamp, which is what happens when
        several applies land inside the same second.
        """
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text("{}\n", encoding="utf-8")
        stamp = datetime.datetime(2026, 1, 1, tzinfo=datetime.UTC)
        first = backup_path_for(settings, now=stamp)
        first.write_text("oldest", encoding="utf-8")
        second = backup_path_for(settings, now=stamp)
        second.write_text("newer", encoding="utf-8")
        first.unlink()

        # Act
        third = backup_path_for(settings, now=stamp)

        # Assert
        assert third.name != first.name
        assert third.name > second.name

    def test_given_a_settings_path_when_building_a_backup_path_then_it_sits_beside_the_file(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        settings = tmp_path / "settings.json"

        # Act & Assert
        assert backup_path_for(settings).parent == tmp_path
        assert backup_path_for(settings).name.startswith("settings.json.")
        assert backup_path_for(settings).name.endswith(".bak")

    def test_given_more_applies_than_the_retention_limit_when_listing_backups_then_the_limit_holds(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        """Each backup is a full copy of a file naming an endpoint and an output path.

        Unbounded retention left a growing pile of them beside the settings
        file, which is a disclosure surface that grows with ordinary use.
        """
        # Act
        for index in range(BACKUP_RETENTION + 3):
            apply_changes(settings_file, {MAXSIZE: index + 1}, apply=True)

        # Assert
        backups = sorted(settings_file.parent.glob(f"{settings_file.name}.*.bak"))
        assert len(backups) == BACKUP_RETENTION

    def test_given_backups_beyond_the_retention_limit_when_pruning_then_removed_paths_are_returned(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text("{}\n", encoding="utf-8")
        created = []
        for index in range(BACKUP_RETENTION + 2):
            backup = settings.with_name(f"{settings.name}.2026010{index}T000000Z-000.bak")
            backup.write_text("{}\n", encoding="utf-8")
            created.append(backup)

        # Act
        removed = prune_backups(settings)

        # Assert
        assert removed == created[:2]
        assert all(not path.exists() for path in removed)

    def test_given_a_clock_that_moves_backwards_when_building_a_backup_then_it_sorts_last(
        self, tmp_path: pathlib.Path
    ) -> None:
        """Retention reads name order, so a regressing clock must not reorder it.

        An NTP correction on a shared runner is enough to move the wall clock
        back a second. Without this the newest backup takes the lowest name and
        retention deletes it first, which loses the only copy that matters.
        """
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text("{}\n", encoding="utf-8")
        later = datetime.datetime(2026, 1, 2, 3, 4, 5, tzinfo=datetime.UTC)
        earlier = later - datetime.timedelta(seconds=30)

        first = backup_path_for(settings, now=later)
        first.write_text("{}\n", encoding="utf-8")

        # Act
        second = backup_path_for(settings, now=earlier)

        # Assert
        assert second.name > first.name

    def test_given_pruning_after_many_applies_when_reading_the_last_backup_then_it_is_the_newest(
        self,
        settings_file: pathlib.Path,
    ) -> None:
        # Act
        for index in range(BACKUP_RETENTION + 2):
            apply_changes(settings_file, {MAXSIZE: index + 1}, apply=True)

        # Assert
        backups = sorted(settings_file.parent.glob(f"{settings_file.name}.*.bak"))
        newest = json.loads(strip_jsonc(backups[-1].read_text(encoding="utf-8-sig")))
        assert newest[MAXSIZE] == BACKUP_RETENTION + 1


class TestTrailingCommas:
    """A trailing comma is accepted; a comma inside a string is untouchable.

    The suggested fix for this finding was a regex that removed any comma
    followed by a closing brace. That rewrites string literals too, and the
    untouched-key comparison guarding this edit could not have caught it,
    because both sides of that comparison are produced by the same pass.
    """

    def test_given_an_object_with_a_trailing_comma_when_stripping_jsonc_then_it_parses(
        self,
    ) -> None:
        # Act & Assert
        assert json.loads(strip_jsonc('{"a": 1,}')) == {"a": 1}

    def test_given_an_array_with_a_trailing_comma_when_stripping_jsonc_then_it_parses(self) -> None:
        # Act & Assert
        assert json.loads(strip_jsonc('{"a": [1, 2,],}')) == {"a": [1, 2]}

    def test_given_a_trailing_comma_before_a_comment_when_stripping_jsonc_then_it_parses(
        self,
    ) -> None:
        # Act & Assert
        assert json.loads(strip_jsonc('{"a": 1, // note\n}')) == {"a": 1}

    def test_given_a_comma_inside_a_string_literal_when_stripping_jsonc_then_it_survives_intact(
        self,
    ) -> None:
        # Arrange
        source = '{"note": "literal, }", "a": 1,}'

        # Act
        stripped = strip_jsonc(source)

        # Assert
        assert len(stripped) == len(source), "offsets were not preserved"
        assert '"literal, }"' in stripped, "a comma inside a string was rewritten"
        assert json.loads(stripped) == {"note": "literal, }", "a": 1}

    def test_given_a_trailing_comma_and_comment_when_stripping_jsonc_then_the_length_is_unchanged(
        self,
    ) -> None:
        # Arrange
        source = '{\n  "a": 1, // trailing\n}\n'

        # Act & Assert
        assert len(strip_jsonc(source)) == len(source)

    def test_given_a_document_with_a_trailing_comma_when_applying_a_change_then_both_keys_parse(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text('{\n  "editor.fontSize": 13,\n}\n', encoding="utf-8")

        # Act
        apply_changes(settings, {ENABLED: True}, apply=True)

        # Assert
        parsed = json.loads(strip_jsonc(settings.read_text(encoding="utf-8")))
        assert parsed[ENABLED] is True
        assert parsed["editor.fontSize"] == 13

    def test_given_a_string_containing_a_brace_when_applying_a_change_then_the_string_is_intact(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        settings = tmp_path / "settings.json"
        settings.write_text('{\n  "note": "literal, }",\n}\n', encoding="utf-8")

        # Act
        apply_changes(settings, {ENABLED: True}, apply=True)

        # Assert
        text = settings.read_text(encoding="utf-8")
        assert '"literal, }"' in text
        assert json.loads(strip_jsonc(text))["note"] == "literal, }"
