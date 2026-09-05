# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Helper-oriented unit tests for gitlab.py."""

from __future__ import annotations

import ast
import dataclasses
import json
import logging
import pathlib

import gitlab
import pytest
from pytest_mock import MockerFixture
from test_constants import TEST_API_URL

SOURCE = pathlib.Path(gitlab.__file__).read_text(encoding="utf-8")
SOURCE_TREE = ast.parse(SOURCE)
SCRIPTS_ROOT = pathlib.Path(gitlab.__file__).parent
SECRET = "s3cr3t-Value_123"
EXPECTED_REDACT_KEYS = (
    "access_token",
    "refresh_token",
    "code_verifier",
    "client_secret",
    "id_token",
    "assertion",
    "client_assertion",
    "device_code",
    "password",
    "private_token",
    "oauth_token",
    "deploy_token",
    "job_token",
)


class _NetworkInvocationVisitor(ast.NodeVisitor):
    """Collect credentialed network invocations with their owning function."""

    def __init__(self, module: str) -> None:
        self.module = module
        self.function = "<module>"
        self.invocations: list[tuple[str, str, str]] = []

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        previous = self.function
        self.function = node.name
        self.generic_visit(node)
        self.function = previous

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_Call(self, node: ast.Call) -> None:
        function = node.func
        if (
            isinstance(function, ast.Attribute)
            and function.attr == "open"
            and isinstance(function.value, ast.Name)
            and function.value.id == "_OPENER"
        ):
            self.invocations.append((self.module, self.function, "_OPENER.open"))
        elif isinstance(function, ast.Name) and function.id == "opener":
            self.invocations.append((self.module, self.function, "opener"))
        elif (
            isinstance(function, ast.Attribute)
            and function.attr == "urlopen"
            and isinstance(function.value, ast.Attribute)
            and isinstance(function.value.value, ast.Name)
            and function.value.value.id == "urllib"
            and function.value.attr == "request"
        ):
            self.invocations.append(
                (self.module, self.function, "urllib.request.urlopen")
            )
        self.generic_visit(node)


def _network_invocations(source: str, module: str) -> list[tuple[str, str, str]]:
    visitor = _NetworkInvocationVisitor(module)
    visitor.visit(ast.parse(source))
    return visitor.invocations


def _is_main_guard(node: ast.AST) -> bool:
    """Report whether a node is the ``if __name__ == "__main__":`` guard."""
    if not isinstance(node, ast.If) or not isinstance(node.test, ast.Compare):
        return False
    left = node.test.left
    operators = node.test.ops
    comparators = node.test.comparators
    return (
        isinstance(left, ast.Name)
        and left.id == "__name__"
        and len(operators) == 1
        and isinstance(operators[0], ast.Eq)
        and len(comparators) == 1
        and isinstance(comparators[0], ast.Constant)
        and comparators[0].value == "__main__"
    )


class _ExitMechanismVisitor(ast.NodeVisitor):
    """Collect process-exit violations using lexical import bindings."""

    _IMPLICIT_BINDINGS = {
        "SystemExit": "builtins.SystemExit",
        "sys": "sys",
    }

    def __init__(self, guarded: set[int]) -> None:
        self.guarded = guarded
        self.scope_stack: list[tuple[dict[str, str], dict[str, str]]] = []
        self.violations: list[str] = []

    def visit(self, node: ast.AST) -> object:
        if id(node) in self.guarded:
            return None
        return super().visit(node)

    def visit_Module(self, node: ast.Module) -> None:
        self._visit_scope(node.body, self._IMPLICIT_BINDINGS, is_class=False)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        if node.name == "die":
            self.violations.append("def die")
        self._visit_function(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        if node.name == "die":
            self.violations.append("def die")
        self._visit_function(node)

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        for decorator in node.decorator_list:
            self.visit(decorator)
        for base in node.bases:
            self.visit(base)
        for keyword in node.keywords:
            self.visit(keyword)
        self._visit_scope(node.body, self._child_bindings(), is_class=True)

    def visit_Raise(self, node: ast.Raise) -> None:
        raised = node.exc.func if isinstance(node.exc, ast.Call) else node.exc
        if self._resolve_target(raised) == "builtins.SystemExit":
            self.violations.append("raise SystemExit")
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if self._resolve_target(node.func) == "sys.exit":
            self.violations.append("sys.exit")
        self.generic_visit(node)

    def _visit_function(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> None:
        for decorator in node.decorator_list:
            self.visit(decorator)
        self.visit(node.args)
        if node.returns is not None:
            self.visit(node.returns)
        self._visit_scope(node.body, self._child_bindings(), is_class=False)

    def _visit_scope(
        self,
        body: list[ast.stmt],
        inherited: dict[str, str],
        *,
        is_class: bool,
    ) -> None:
        bindings = inherited.copy()
        for statement in body:
            self._collect_import_bindings(statement, bindings)
        child_bindings = inherited if is_class else bindings
        self.scope_stack.append((bindings, child_bindings))
        for statement in body:
            self.visit(statement)
        self.scope_stack.pop()

    def _collect_import_bindings(self, node: ast.AST, bindings: dict[str, str]) -> None:
        if id(node) in self.guarded or isinstance(
            node,
            (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda),
        ):
            return
        if isinstance(node, ast.Import):
            for alias in node.names:
                bound_name = alias.asname or alias.name.partition(".")[0]
                bindings[bound_name] = alias.name if alias.asname else bound_name
            return
        if isinstance(node, ast.ImportFrom) and node.module is not None:
            for alias in node.names:
                if alias.name != "*":
                    bindings[alias.asname or alias.name] = f"{node.module}.{alias.name}"
            return
        for child in ast.iter_child_nodes(node):
            self._collect_import_bindings(child, bindings)

    def _child_bindings(self) -> dict[str, str]:
        return self.scope_stack[-1][1]

    def _resolve_target(self, node: ast.AST | None) -> str | None:
        if isinstance(node, ast.Name):
            return self.scope_stack[-1][0].get(node.id)
        if isinstance(node, ast.Attribute):
            parent = self._resolve_target(node.value)
            if parent is not None:
                return f"{parent}.{node.attr}"
        return None


def _exit_mechanism_violations(source: str) -> list[str]:
    """Return violations of the single-failure-mechanism contract.

    ``GitLabError`` is the module's only failure mechanism. Process exit belongs
    to the ``__main__`` guard alone, so a ``raise SystemExit`` or ``sys.exit``
    anywhere else, or any ``die`` definition, reintroduces the second mechanism
    this contract exists to prevent.
    """
    tree = ast.parse(source)
    guarded: set[int] = set()
    for node in ast.walk(tree):
        if _is_main_guard(node):
            for statement in node.body:
                for child in ast.walk(statement):
                    guarded.add(id(child))

    visitor = _ExitMechanismVisitor(guarded)
    visitor.visit(tree)
    return visitor.violations


class TestRedact:
    """Tests for _redact."""

    def test_masks_header_and_query_string_secrets(self) -> None:
        payload = (
            "PRIVATE-TOKEN: secret123\n"
            "X-API-Key: api-key-456\n"
            "Cookie: session=xyz\n"
            "https://example.com/?private_token=abc&access_token=def&token=ghi"
            "&api_key=789&password=secret&secret=hidden"
        )

        redacted = gitlab._redact(payload)

        assert "PRIVATE-TOKEN=[REDACTED]" in redacted
        assert "X-API-Key=[REDACTED]" in redacted
        assert "Cookie=[REDACTED]" in redacted
        assert "private_token=[REDACTED]" in redacted
        assert "access_token=[REDACTED]" in redacted
        assert "token=[REDACTED]" in redacted
        assert "api_key=[REDACTED]" in redacted
        assert "password=[REDACTED]" in redacted
        assert "secret=[REDACTED]" in redacted
        assert "secret123" not in redacted
        assert "abc" not in redacted

    def test_masks_oauth_secrets_in_escaped_and_encoded_forms(self) -> None:
        payload = (
            '{"Access_Token":"mixed-secret"} '
            r"{\"refresh_token\":\"escaped-secret\"} "
            "access_token%3Dencoded-secret"
        )

        redacted = gitlab._redact(payload)

        assert "mixed-secret" not in redacted
        assert "escaped-secret" not in redacted
        assert "encoded-secret" not in redacted

    @pytest.mark.parametrize("key", EXPECTED_REDACT_KEYS)
    def test_masks_all_pinned_json_and_form_keys(self, key: str) -> None:
        payload = f'{{"{key}": "{SECRET}"}} {key}={SECRET}'

        redacted = gitlab._redact(payload)

        assert SECRET not in redacted
        assert "[REDACTED]" in redacted

    def test_masks_azure_sas_query_string(self) -> None:
        """SAS tokens ride in the query string, so drop everything after the ?."""
        url = f"https://acct.blob.core.windows.net/c/b?sig={SECRET}&se=2026"

        redacted = gitlab._redact(url)

        assert redacted == "https://acct.blob.core.windows.net/c/b?[REDACTED]"

    def test_masks_basic_authorization_header(self) -> None:
        """Basic credentials are base64(user:token) and must not survive."""
        encoded = "dXNlckBleGFtcGxlLmNvbTp0b2tlbg=="

        redacted = gitlab._redact(f"Authorization: Basic {encoded}")

        assert encoded not in redacted

    def test_masks_every_secret_in_a_multi_secret_line(self) -> None:
        payload = f"a access_token={SECRET}1 b private_token={SECRET}2 c"

        redacted = gitlab._redact(payload)

        assert f"{SECRET}1" not in redacted
        assert f"{SECRET}2" not in redacted

    def test_is_idempotent(self) -> None:
        """Re-redacting already-redacted text must not corrupt the marker."""
        once = gitlab._redact(f"access_token={SECRET}")

        assert gitlab._redact(once) == once

    @pytest.mark.parametrize("payload", ["", "   "])
    def test_handles_empty_payloads(self, payload: str) -> None:
        assert gitlab._redact(payload).strip() == ""

    def test_preserves_unicode_around_masked_secrets(self) -> None:
        redacted = gitlab._redact(f"\u65e5\u672c\u8a9e access_token={SECRET} \u2713")

        assert SECRET not in redacted
        assert "\u65e5\u672c\u8a9e" in redacted
        assert "\u2713" in redacted

    def test_pinned_keyset_excludes_public_pkce_challenge(self) -> None:
        assert gitlab._REDACT_KEYS == EXPECTED_REDACT_KEYS
        assert "code_challenge" not in gitlab._REDACT_KEYS


class TestCredentialExposureContracts:
    """Tests for credential-safe objects, errors, and output sinks."""

    def test_credential_is_not_a_module_level_global(self) -> None:
        """The PAT lives only on AuthContext, never in mutable module state."""
        assert not hasattr(gitlab, "gitlab_token")
        assert "gitlab_token" not in SOURCE

    def test_auth_context_is_immutable_and_secret_free(self) -> None:
        context = gitlab.AuthContext(
            mode="legacy-token",
            issuer="https://gitlab.example.com",
            token=SECRET,
        )

        assert SECRET not in repr(context)
        with pytest.raises(dataclasses.FrozenInstanceError):
            context.token = "replacement"  # type: ignore[misc]

    def test_api_error_excludes_message_from_repr_and_redacts_str(self) -> None:
        error = gitlab.GitLabAPIError(
            status=403,
            method="GET",
            resource=f"{TEST_API_URL}/projects/1",
            message=f"private_token={SECRET}",
        )

        assert SECRET not in str(error)
        assert SECRET not in repr(error)

    def test_emit_and_debug_traceback_redact(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        monkeypatch.setenv("GITLAB_DEBUG", "1")
        error = gitlab.GitLabAPIError(message=f"private_token={SECRET}")
        with caplog.at_level(logging.ERROR, logger="gitlab"):
            gitlab._emit(f"private_token={SECRET}")
        gitlab._emit_debug_traceback(error)

        captured = capsys.readouterr()
        assert SECRET not in captured.err
        assert SECRET not in caplog.text


class TestSourceContracts:
    """Structural guards for redacted output and hardened transport ownership."""

    def test_print_calls_remain_in_emit_helpers(self) -> None:
        owners: list[str] = []
        for node in ast.walk(SOURCE_TREE):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if any(
                isinstance(child, ast.Call)
                and isinstance(child.func, ast.Name)
                and child.func.id == "print"
                for child in ast.walk(node)
            ):
                owners.append(node.name)

        assert set(owners) <= {
            "_emit",
            "_emit_stdout",
            "_emit_structured_stdout",
            "_emit_debug_traceback",
        }
        assert "LOGGER.exception(" not in SOURCE

    def test_credentialed_egress_has_exactly_two_owners(self) -> None:
        invocations: list[tuple[str, str, str]] = []
        for path in SCRIPTS_ROOT.rglob("*.py"):
            if "__pycache__" in path.parts:
                continue
            invocations.extend(
                _network_invocations(path.read_text(encoding="utf-8"), path.name)
            )

        assert set(invocations) == {
            ("_gitlab_oauth.py", "post_form", "opener"),
            ("gitlab.py", "_request_bytes", "_OPENER.open"),
        }

    @pytest.mark.parametrize(
        ("source", "expected"),
        [
            (
                "def bypass():\n    return urllib.request.urlopen('https://x')\n",
                "bypass",
            ),
            ("def other():\n    return _OPENER.open('https://x')\n", "other"),
            ("def other(opener):\n    return opener('https://x')\n", "other"),
        ],
    )
    def test_source_contract_detects_non_owner_invocations(
        self, source: str, expected: str
    ) -> None:
        invocations = _network_invocations(source, "unexpected.py")
        assert invocations
        assert invocations[0][1] == expected

    def test_gitlab_error_is_the_only_failure_mechanism(self) -> None:
        assert _exit_mechanism_violations(SOURCE) == []
        assert not hasattr(gitlab, "die")

    @pytest.mark.parametrize(
        ("source", "expected"),
        [
            ("def bypass():\n    raise SystemExit(2)\n", "raise SystemExit"),
            ("def bypass():\n    sys.exit(2)\n", "sys.exit"),
            ("def die(message):\n    return message\n", "def die"),
            (
                "import builtins\n\ndef bypass():\n    raise builtins.SystemExit(2)\n",
                "raise SystemExit",
            ),
            (
                "def owner():\n    import builtins as bi\n"
                "    raise bi.SystemExit(2)\n\n"
                "def sibling():\n    raise bi.SystemExit(2)\n",
                "raise SystemExit",
            ),
            (
                "class Owner:\n"
                "    from builtins import SystemExit as Stop\n"
                "    raise Stop(2)\n\n"
                "    def method(self):\n        raise Stop(2)\n",
                "raise SystemExit",
            ),
            (
                "def outer():\n    import sys as system\n\n"
                "    def inner():\n        system.exit(2)\n",
                "sys.exit",
            ),
            (
                "from sys import exit\n\ndef bypass():\n    exit(2)\n",
                "sys.exit",
            ),
            (
                "def bypass():\n    from sys import exit as stop\n    stop(2)\n",
                "sys.exit",
            ),
        ],
    )
    def test_source_contract_detects_second_failure_mechanism(
        self, source: str, expected: str
    ) -> None:
        assert _exit_mechanism_violations(source) == [expected]

    def test_source_contract_allows_guarded_process_exit(self) -> None:
        guarded = 'if __name__ == "__main__":\n    sys.exit(main())\n'

        assert _exit_mechanism_violations(guarded) == []

    @pytest.mark.parametrize(
        "source",
        [
            (
                "class Owner:\n    from sys import exit\n\n"
                "    def method(self):\n"
                "        def exit(code):\n            return code\n\n"
                "        exit(2)\n"
            ),
            (
                "def owner():\n    import sys as target\n\n"
                "def sibling(target):\n    target.exit(2)\n"
            ),
        ],
    )
    def test_source_contract_allows_unrelated_exit_forms(self, source: str) -> None:
        assert _exit_mechanism_violations(source) == []

    @pytest.mark.parametrize(
        "source",
        [
            'if __name__ != "__main__":\n    sys.exit(2)\n',
            ('if __name__ == "__main__":\n    main()\nelse:\n    sys.exit(2)\n'),
        ],
    )
    def test_source_contract_rejects_exit_outside_canonical_guard_body(
        self, source: str
    ) -> None:
        assert _exit_mechanism_violations(source) == ["sys.exit"]

    def test_job_log_output_is_redacted(
        self,
        configured_gitlab: object,
        capsys: pytest.CaptureFixture[str],
        mocker: MockerFixture,
    ) -> None:
        del configured_gitlab
        mocker.patch("gitlab.project", return_value="group%2Fproject")
        mocker.patch(
            "gitlab._request_bytes",
            return_value=f"access_token={SECRET}".encode(),
        )

        gitlab.cmd_job_log(["7"])

        assert SECRET not in capsys.readouterr().out


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

    @pytest.mark.parametrize("value", ["7", "123456"])
    def test_accepts_numeric_strings(self, value: str) -> None:
        gitlab.validate_numeric_id(value)

    @pytest.mark.parametrize("value", ["", "abc", "12a", "-1", "1.2", " 5 "])
    def test_rejects_non_numeric_values(self, value: str) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.validate_numeric_id(value)

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert f"expected numeric ID, got: {value}" in str(exc_info.value)


class TestValidatePositiveInt:
    """Tests for validate_positive_int."""

    @pytest.mark.parametrize("value", ["1", "50", "100"])
    def test_accepts_digit_strings(self, value: str) -> None:
        gitlab.validate_positive_int(value, "max_results")

    @pytest.mark.parametrize("value", ["", "ten", "5x", "-2", "3.14"])
    def test_rejects_invalid_values(self, value: str) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.validate_positive_int(value, "max_results")

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert f"max_results must be a positive integer, got: {value}" in str(
            exc_info.value
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

    def test_requires_value_after_fields(self) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.parse_fields(["mr-list", "--fields"])

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "usage: --fields requires a comma-separated value list" in str(
            exc_info.value
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

    def test_preserves_tsv_arity_and_ordinary_credential_words(
        self, capsys: pytest.CaptureFixture[str]
    ) -> None:
        gitlab.selected_fields = ["first", "title", "last"]

        gitlab.print_fields(
            [{"first": "", "title": "fix secret token password", "last": ""}]
        )

        lines = capsys.readouterr().out.splitlines()
        assert lines[1].split("\t") == ["", "fix secret token password", ""]


def test_sanitize_structured_preserves_containers_and_redacts_descendants() -> None:
    payload = {
        "title": "fix secret",
        "access_token": {"value": SECRET, "nested": [SECRET, {"x": SECRET}]},
        "items": [{"password": [SECRET]}, "unchanged"],
    }

    sanitized = gitlab._sanitize_structured(payload)

    assert sanitized == {
        "title": "fix secret",
        "access_token": {
            "value": "[REDACTED]",
            "nested": ["[REDACTED]", {"x": "[REDACTED]"}],
        },
        "items": [{"password": ["[REDACTED]"]}, "unchanged"],
    }
    assert json.loads(json.dumps(sanitized)) == sanitized


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

    def test_raises_usage_error_for_invalid_json(self) -> None:
        with pytest.raises(gitlab.GitLabError) as exc_info:
            gitlab.load_json_payload("{bad json}", "usage: gitlab mr-create <json>")

        assert exc_info.value.exit_code == gitlab.EXIT_USAGE
        assert "invalid JSON payload" in str(exc_info.value)


def test_emit_writes_exactly_one_stderr_line() -> None:
    """_emit prints once; logging's lastResort must not echo the record.

    _emit both logs at ERROR and prints to stderr. A logger with no handler
    falls back to logging.lastResort, which writes WARNING-or-above records to
    stderr as well, so every CLI error would appear twice.
    """
    assert any(isinstance(h, logging.NullHandler) for h in gitlab.LOGGER.handlers)


def test_emit_is_not_duplicated_by_last_resort(
    capsys: pytest.CaptureFixture[str],
) -> None:
    gitlab._emit("single line")

    lines = [line for line in capsys.readouterr().err.splitlines() if line.strip()]

    assert lines == ["single line"]
