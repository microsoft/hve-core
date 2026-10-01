# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Regression tests for `_redact` and the `_REDACT_KEYS` contract.

These tests guard the secret-scrubbing surface that protects logs from
leaking OAuth tokens, PKCE values, and the confidential client secret. A
break here means a real secret can land in a real log line, so the
intent is to fail loud on any silent regression of the key set or the
substitution patterns.
"""

from __future__ import annotations

import argparse
import json
import logging
import pathlib
from typing import Any

import pytest

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
)

SECRET_VALUE = "s3cr3t-VALUE.with-symbols_42"


def _package_src(mural_module: Any) -> str:
    """Concatenate the source of every `.py` file in the `mural` package.

    Source-level redaction contracts must hold across the whole package, not
    just `__init__.py`. As tiers are carved into sibling modules (e.g.
    `_transport.py`), call sites relocate; scanning every package module keeps
    these defense-in-depth checks resilient to that movement.
    """
    package_dir = pathlib.Path(mural_module.__file__).parent
    return "\n".join(
        path.read_text(encoding="utf-8") for path in sorted(package_dir.glob("*.py"))
    )


# ---------------------------------------------------------------------------
# Structural contract
# ---------------------------------------------------------------------------


def test_redact_keys_match_documented_set(mural_module: Any) -> None:
    """`_REDACT_KEYS` is exactly the documented set (4 active + 5 defense-in-depth)."""
    assert mural_module._REDACT_KEYS == EXPECTED_REDACT_KEYS


def test_client_secret_is_redacted_key(mural_module: Any) -> None:
    """Guards the G-INF-1 fix: `client_secret` must remain in the key set."""
    assert "client_secret" in mural_module._REDACT_KEYS


# ---------------------------------------------------------------------------
# Per-key masking — JSON and form shapes
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("key", EXPECTED_REDACT_KEYS)
def test_redact_masks_json_payload(mural_module: Any, key: str) -> None:
    payload = f'{{"{key}": "{SECRET_VALUE}"}}'
    result = mural_module._redact(payload)
    assert SECRET_VALUE not in result
    assert f'"{key}": "***"' in result


@pytest.mark.parametrize("key", EXPECTED_REDACT_KEYS)
def test_redact_masks_form_payload(mural_module: Any, key: str) -> None:
    payload = f"{key}={SECRET_VALUE}&grant_type=authorization_code"
    result = mural_module._redact(payload)
    assert SECRET_VALUE not in result
    assert f"{key}=***" in result
    assert "grant_type=authorization_code" in result


@pytest.mark.parametrize("key", EXPECTED_REDACT_KEYS)
def test_redact_masks_json_with_whitespace_variants(
    mural_module: Any, key: str
) -> None:
    payload = f'{{ "{key}"   :   "{SECRET_VALUE}" }}'
    result = mural_module._redact(payload)
    assert SECRET_VALUE not in result


# ---------------------------------------------------------------------------
# Auxiliary patterns documented alongside the key set
# ---------------------------------------------------------------------------


def test_redact_masks_form_authorization_code(mural_module: Any) -> None:
    """`code=` form param is masked even though it is not a `_REDACT_KEYS` entry."""
    payload = f"code={SECRET_VALUE}&state=abc"
    result = mural_module._redact(payload)
    assert SECRET_VALUE not in result
    assert "code=***" in result


def test_redact_masks_authorization_bearer_header(mural_module: Any) -> None:
    line = f"Authorization: Bearer {SECRET_VALUE}"
    result = mural_module._redact(line)
    assert SECRET_VALUE not in result
    assert "Bearer ***" in result


def test_redact_masks_authorization_non_bearer_header(mural_module: Any) -> None:
    line = f"authorization={SECRET_VALUE}"
    result = mural_module._redact(line)
    assert SECRET_VALUE not in result


def test_redact_masks_azure_blob_sas_query(mural_module: Any) -> None:
    url = (
        "https://example.blob.core.windows.net/container/blob.png"
        f"?sig={SECRET_VALUE}&sv=2024-01-01"
    )
    result = mural_module._redact(url)
    assert SECRET_VALUE not in result
    assert "?***" in result


@pytest.mark.parametrize(
    "host",
    [
        "example.blob.core.windows.net",
        "example.Blob.Core.Windows.Net",
        "EXAMPLE.BLOB.CORE.WINDOWS.NET",
    ],
)
def test_redact_masks_azure_blob_sas_query_any_host_casing(
    mural_module: Any, host: str
) -> None:
    """Host casing must not defeat redaction.

    ``_validate_asset_url`` admits the URL on its lowercased ``parsed.hostname``,
    so a mixed-case host reaches the redactor. Before the pattern carried
    ``(?i)`` the validator accepted URLs the redactor could not mask.
    Parameters are ordered as Azure emits them, with ``sig`` last.
    """
    url = (
        f"https://{host}/container/blob.png"
        "?sv=2024-11-04&st=2026-01-01T00%3A00%3A00Z&se=2026-01-01T01%3A00%3A00Z"
        f"&sr=b&sp=cw&spr=https&sig={SECRET_VALUE}"
    )
    result = mural_module._redact(url)
    assert SECRET_VALUE not in result


def test_redact_masks_bare_sas_signature(mural_module: Any) -> None:
    """A `sig=` with no host prefix still masks.

    Upstream error bodies quote SAS parameters without the URL, and truncation
    can strip the host, so the signature cannot rely on the host-anchored
    pattern alone.
    """
    result = mural_module._redact(f"sv=2024-11-04&sr=b&sig={SECRET_VALUE}")
    assert SECRET_VALUE not in result
    assert "sig=***" in result


def test_redact_masks_sas_signature_in_json_error_body(mural_module: Any) -> None:
    """A signature quoted inside a JSON error body masks without eating the quote."""
    body = f'{{"detail": "upload rejected for sig={SECRET_VALUE}"}}'
    result = mural_module._redact(body)
    assert SECRET_VALUE not in result
    assert result.endswith('"}')


# ---------------------------------------------------------------------------
# Composition + edge cases
# ---------------------------------------------------------------------------


def test_redact_masks_multiple_keys_in_one_payload(mural_module: Any) -> None:
    """All keys mask even when several appear together."""
    payload = (
        f'{{"access_token": "{SECRET_VALUE}-a", '
        f'"refresh_token": "{SECRET_VALUE}-r", '
        f'"client_secret": "{SECRET_VALUE}-c"}}'
    )
    result = mural_module._redact(payload)
    for suffix in ("-a", "-r", "-c"):
        assert f"{SECRET_VALUE}{suffix}" not in result


def test_redact_empty_string_returns_empty(mural_module: Any) -> None:
    assert mural_module._redact("") == ""


def test_redact_passes_through_unrelated_text(mural_module: Any) -> None:
    text = "GET /api/v1/murals/xyz 200 12ms"
    assert mural_module._redact(text) == text


def test_redact_does_not_affect_non_secret_form_fields(mural_module: Any) -> None:
    """Form fields whose names are not redaction keys are preserved verbatim."""
    payload = f"workspace_id=ws123&name={SECRET_VALUE}"
    result = mural_module._redact(payload)
    assert f"name={SECRET_VALUE}" in result


# ---------------------------------------------------------------------------
# LOGGER call-site contracts (defense-in-depth)
# ---------------------------------------------------------------------------
#
# The `_emit` channel routes through `_redact`, but the module also uses the
# stdlib `LOGGER` directly with format-string interpolation. Format-string
# args bypass `_emit`, so every URL or exception fed to LOGGER MUST be wrapped
# in `_redact()` at the call site. These tests pin the wrapping in source so a
# future regression fails loudly here instead of silently in production logs.


def test_logger_token_post_wraps_url_in_redact(mural_module: Any) -> None:
    """Token endpoint POST debug log must redact `token_url`."""
    src = _package_src(mural_module)
    assert 'LOGGER.debug("POST %s", _redact(token_url))' in src


def test_logger_authenticated_request_wraps_url_in_redact(
    mural_module: Any,
) -> None:
    """`_authenticated_request` per-call debug log must redact `url`."""
    src = _package_src(mural_module)
    assert 'LOGGER.debug("%s %s", method.upper(), _redact(url))' in src


def test_logger_area_chain_warning_wraps_exc_in_redact(
    mural_module: Any,
) -> None:
    """Area chain walk warning must redact the caught exception text."""
    src = _package_src(mural_module)
    assert 'LOGGER.warning("area chain walk stopped: %s", _redact(str(exc)))' in src


def test_logger_no_bare_exception_calls(mural_module: Any) -> None:
    """`LOGGER.exception()` auto-formats traceback whose message embeds the
    caught exception's `str()`. Replace with `LOGGER.error(..., _redact(repr(exc)))`
    so that exceptions whose repr embeds credentials cannot leak through the
    traceback formatter.
    """
    src = _package_src(mural_module)
    assert "LOGGER.exception(" not in src, (
        "LOGGER.exception() embeds untrusted exception repr in the traceback; "
        "use LOGGER.error('... %s', _redact(repr(exc))) instead"
    )


def test_top_level_error_wraps_exc_repr_in_redact(
    mural_module: Any,
) -> None:
    """Top-level error handling must redact `repr(exc)`."""
    src = _package_src(mural_module)
    assert "_redact(repr(exc))" in src


# ---------------------------------------------------------------------------
# Runtime LOGGER behavior (caplog)
# ---------------------------------------------------------------------------


def test_logger_format_string_redacts_token_url_at_runtime(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    """Runtime guard: LOGGER format-string interpolation of a `_redact()`-wrapped
    URL must not surface a `code` query value."""
    secret_url = f"https://example.com/oauth/token?code={SECRET_VALUE}&state=xyz"
    with caplog.at_level(logging.DEBUG, logger=mural_module.LOGGER.name):
        mural_module.LOGGER.debug("POST %s", mural_module._redact(secret_url))
    assert SECRET_VALUE not in caplog.text
    assert "code=***" in caplog.text


def test_logger_format_string_redacts_authenticated_url_at_runtime(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    """Runtime guard: API URLs carrying Azure SAS query strings must not leak."""
    sas_url = (
        "https://example.blob.core.windows.net/c/asset.png"
        f"?sig={SECRET_VALUE}&sv=2024-01-01"
    )
    with caplog.at_level(logging.DEBUG, logger=mural_module.LOGGER.name):
        mural_module.LOGGER.debug("%s %s", "GET", mural_module._redact(sas_url))
    assert SECRET_VALUE not in caplog.text


def test_logger_format_string_redacts_exception_str_at_runtime(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    """Runtime guard: warnings carrying `MuralAPIError.__str__` must not leak
    response bodies that embed `refresh_token` or similar fields."""
    exc = mural_module.MuralAPIError(
        status=500,
        message=f'{{"refresh_token": "{SECRET_VALUE}"}}',
        code="internal_error",
        request_id="req-abc",
    )
    with caplog.at_level(logging.WARNING, logger=mural_module.LOGGER.name):
        mural_module.LOGGER.warning(
            "area chain walk stopped: %s", mural_module._redact(str(exc))
        )
    assert SECRET_VALUE not in caplog.text


def test_logger_format_string_redacts_exception_repr_at_runtime(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    """Runtime guard: unexpected failures must not leak credentials
    that appear in the raised exception's `repr()`."""
    exc = RuntimeError(f"client_secret={SECRET_VALUE}")
    with caplog.at_level(logging.ERROR, logger=mural_module.LOGGER.name):
        mural_module.LOGGER.error(
            "unexpected error for command %s: %s",
            "mural workspace list",
            mural_module._redact(repr(exc)),
        )
    assert SECRET_VALUE not in caplog.text


# ---------------------------------------------------------------------------
# `main()` error sinks
# ---------------------------------------------------------------------------
#
# `main()` is the last place an exception can reach a human. Its typed handlers
# print exception text and structured envelopes straight to stderr, so each one
# is an independent redaction barrier: repairing one while leaving another bare
# keeps the leak reachable. These tests drive `main()` end-to-end through a fake
# parser so a regression fails here rather than in an operator's terminal.


def _drive_main(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    func: Any,
) -> int:
    """Run `main()` with a stub parser that dispatches straight to `func`."""
    fake_args = argparse.Namespace(log_level="WARNING", func=func)

    class FakeParser:
        def parse_args(self, argv: list[str] | None = None) -> argparse.Namespace:
            return fake_args

        def print_help(self, *args: Any, **kwargs: Any) -> None:
            return None

    monkeypatch.setattr(mural_module, "_build_parser", FakeParser)
    return mural_module.main([])


@pytest.mark.parametrize(
    ("code", "request_id", "expected"),
    [
        (
            "REFRESH_FAILED",
            f"code={SECRET_VALUE}",
            "error: HTTP 400 code=REFRESH_FAILED: "
            "client_secret=*** request_id=code=***\n",
        ),
        (None, None, "error: HTTP 400: client_secret=***\n"),
        ("", "", "error: HTTP 400: client_secret=***\n"),
    ],
)
def test_main_preserves_api_diagnostics_and_redacts_untrusted_fields(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    code: str | None,
    request_id: str | None,
    expected: str,
) -> None:
    """Typed API errors keep structural fields and redact untrusted fields."""

    def boom(_args: argparse.Namespace) -> int:
        raise mural_module.MuralAPIError(
            status=400,
            code=code,
            message=f"client_secret={SECRET_VALUE}",
            request_id=request_id,
        )

    result = _drive_main(mural_module, monkeypatch, boom)

    captured = capsys.readouterr()
    assert result == 1
    assert captured.out == ""
    assert SECRET_VALUE not in captured.err
    assert captured.err == expected


def test_main_redacts_autoload_credentials_error_text(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """The credential-autoload guard runs before dispatch and is its own sink."""

    def explode(_profile: str) -> None:
        raise mural_module.MuralError(f"credential load failed: code={SECRET_VALUE}")

    monkeypatch.setattr(mural_module, "_autoload_credentials", explode)

    result = _drive_main(mural_module, monkeypatch, lambda _args: 0)

    err = capsys.readouterr().err
    assert result == mural_module.EXIT_FAILURE
    assert SECRET_VALUE not in err
    assert "code=***" in err


def test_main_redacts_auth_scope_error_text(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """The scope handler prints exception text and is redacted for uniformity."""

    def boom(_args: argparse.Namespace) -> int:
        exc = mural_module.MuralAuthScopeError("mural:write", ())
        exc.args = (f"missing scope; client_secret={SECRET_VALUE}",)
        raise exc

    result = _drive_main(mural_module, monkeypatch, boom)

    err = capsys.readouterr().err
    assert result == 77
    assert SECRET_VALUE not in err
    assert "client_secret=***" in err


@pytest.mark.parametrize(
    ("scenario", "expected_exit", "expected_error", "expected_keys"),
    [
        (
            "human-authored",
            "EXIT_NOPERM",
            "human_authored_widget_protected",
            {"error", "mural", "widget"},
        ),
        (
            "tag-merge",
            "EXIT_TEMPFAIL",
            "tag_merge_conflict",
            {
                "error",
                "mural",
                "widget",
                "intended",
                "observed",
                "missing",
                "extra",
                "attempts",
            },
        ),
        (
            "area-capacity",
            "EXIT_AREA_CAPACITY",
            "AREA_CAPACITY_EXCEEDED",
            {
                "error",
                "exit_code",
                "area_id",
                "area_capacity",
                "computed_extent",
                "suggestion",
            },
        ),
        (
            "bulk-atomic",
            "EXIT_TEMPFAIL",
            "bulk_atomic_abort",
            {"error", "aborted", "succeeded", "failed", "warnings"},
        ),
    ],
)
def test_main_redacts_structured_stderr_envelope(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    scenario: str,
    expected_exit: str,
    expected_error: str,
    expected_keys: set[str],
) -> None:
    """Every structured handler emits redacted, parseable stderr JSON."""
    credential_shaped = f"code={SECRET_VALUE}"

    def boom(_args: argparse.Namespace) -> int:
        if scenario == "human-authored":
            raise mural_module.MuralHumanAuthoredProtected(
                mural_id=credential_shaped,
                widget_id="w-1",
            )
        if scenario == "tag-merge":
            raise mural_module.MuralTagMergeConflict(
                mural_id="m-1",
                widget_id="w-1",
                intended=[credential_shaped],
                observed=[],
                attempts=3,
            )
        if scenario == "area-capacity":
            raise mural_module.MuralAreaCapacityExceeded(
                area_id="a-1",
                area_capacity={"width": 100, "height": 100},
                computed_extent={"width": 200, "height": 200},
                suggestion=credential_shaped,
            )
        summary = {
            "succeeded": [],
            "failed": [{"widget_id": "w-1", "error": credential_shaped}],
            "warnings": [],
        }
        raise mural_module.MuralBulkAtomicAbort(summary)

    result = _drive_main(mural_module, monkeypatch, boom)

    captured = capsys.readouterr()
    assert result == getattr(mural_module, expected_exit)
    assert captured.out == ""
    err = captured.err
    assert SECRET_VALUE not in err
    assert "code=***" in err
    envelope = json.loads(err)
    assert envelope["error"] == expected_error
    assert set(envelope) == expected_keys


def test_emit_json_error_writes_redacted_json_to_stderr(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """`_emit_json_error` is the redacting stderr channel for envelopes."""
    mural_module._emit_json_error({"error": "boom", "detail": f"code={SECRET_VALUE}"})

    captured = capsys.readouterr()
    assert captured.out == ""
    assert SECRET_VALUE not in captured.err
    assert json.loads(captured.err)["detail"] == "code=***"


# ---------------------------------------------------------------------------
# `_redact_payload` container coverage
# ---------------------------------------------------------------------------
#
# `_redact_payload` walks an envelope before it is serialized. A container it
# does not recurse into is a hole in the barrier, because its strings reach
# `json.dumps` untouched. Sets are rebuilt as sets rather than coerced to
# lists: `json.dumps` cannot serialize a set, and coercing here would change
# which payloads the sink accepts, which is a serialization decision rather
# than a redaction one.


def test_redact_payload_recurses_tuples(mural_module: Any) -> None:
    result = mural_module._redact_payload((f"code={SECRET_VALUE}", 1))

    assert isinstance(result, tuple)
    assert result == ("code=***", 1)


def test_redact_payload_recurses_sets(mural_module: Any) -> None:
    result = mural_module._redact_payload({f"code={SECRET_VALUE}"})

    assert isinstance(result, set)
    assert "code=***" in result
    assert not any(SECRET_VALUE in member for member in result)


def test_redact_payload_preserves_and_redacts_frozenset(mural_module: Any) -> None:
    """Type preservation alone would pass against an unfixed helper."""
    result = mural_module._redact_payload(frozenset({f"code={SECRET_VALUE}"}))

    assert isinstance(result, frozenset)
    assert "code=***" in result


def test_redact_payload_composes_across_container_kinds(mural_module: Any) -> None:
    payload = [{"detail": (f"code={SECRET_VALUE}",)}]

    result = mural_module._redact_payload(payload)

    assert result == [{"detail": ("code=***",)}]


def test_redact_payload_passes_through_non_string_scalars(mural_module: Any) -> None:
    assert mural_module._redact_payload(7) == 7
    assert mural_module._redact_payload(True) is True
    assert mural_module._redact_payload(None) is None


def test_emit_json_error_redacts_inside_a_tuple(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """A tuple serializes as a JSON array, so it must be walked before dumping."""
    mural_module._emit_json_error(
        {"error": "boom", "detail": (f"code={SECRET_VALUE}",)}
    )

    err = capsys.readouterr().err
    assert SECRET_VALUE not in err
    assert json.loads(err)["detail"] == ["code=***"]


def test_main_redacts_tuple_inside_bulk_abort_summary(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """`summary` is the only envelope surface whose value types are unconstrained."""
    summary = {
        "succeeded": [],
        "failed": ({"widget_id": "w-1", "error": f"code={SECRET_VALUE}"},),
        "warnings": [],
    }

    def boom(_args: argparse.Namespace) -> int:
        raise mural_module.MuralBulkAtomicAbort(summary)

    result = _drive_main(mural_module, monkeypatch, boom)

    err = capsys.readouterr().err
    assert result == mural_module.EXIT_TEMPFAIL
    assert SECRET_VALUE not in err
    assert json.loads(err)["failed"][0]["error"] == "code=***"


# ---------------------------------------------------------------------------
# Sensitive mapping keys
# ---------------------------------------------------------------------------
#
# Redacting the serialized text used to mask a top-level `"client_secret":
# "value"` pair, because `json.dumps` leaves those quotes unescaped. Redacting
# values in isolation cannot see the key, so `_redact_payload` masks by key as
# well. That is stronger than the regex ever was: it does not depend on
# quoting, escaping, or serialization order, and it covers non-string values.


def test_redact_payload_masks_value_under_sensitive_key(mural_module: Any) -> None:
    result = mural_module._redact_payload({"client_secret": SECRET_VALUE})

    assert result == {"client_secret": "***"}


def test_redact_payload_matches_sensitive_key_case_insensitively(
    mural_module: Any,
) -> None:
    result = mural_module._redact_payload({"Client_Secret": SECRET_VALUE})

    assert result == {"Client_Secret": "***"}


def test_redact_payload_masks_non_string_value_under_sensitive_key(
    mural_module: Any,
) -> None:
    """A value-only redactor cannot mask this, because it is not a string."""
    result = mural_module._redact_payload({"access_token": {"nested": 1}})

    assert result == {"access_token": "***"}


def test_redact_payload_does_not_match_env_style_key_names(mural_module: Any) -> None:
    """Pins NFR-1: `auth logout --json` records backend errors under these keys.

    Matching is exact after lowercasing, never by suffix. Widening it would
    change shipped output, so this guards against a future well-meaning switch.
    """
    payload = {"errors": {"MURAL_CLIENT_SECRET": "read failed: keyring locked"}}

    result = mural_module._redact_payload(payload)

    assert result == payload


def test_redact_payload_masks_sensitive_keys_nested_in_containers(
    mural_module: Any,
) -> None:
    payload = [{"outer": {"refresh_token": SECRET_VALUE}}]

    result = mural_module._redact_payload(payload)

    assert result == [{"outer": {"refresh_token": "***"}}]


# ---------------------------------------------------------------------------
# `_emit_json` stdout channel
# ---------------------------------------------------------------------------


def test_emit_json_emits_parseable_json_for_trailing_secret(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Redacting serialized text consumed the closing quote and brace.

    The form-style pattern matches every non-whitespace character after
    ``key=``, so a secret at the tail of a JSON string swallowed the string
    terminator and the output stopped parsing.
    """
    mural_module._emit_json({"detail": f"code={SECRET_VALUE}"})

    captured = capsys.readouterr()
    assert captured.err == ""
    assert SECRET_VALUE not in captured.out
    assert json.loads(captured.out)["detail"] == "code=***"


def test_emit_json_stays_pretty_printed_on_stdout(
    mural_module: Any,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """`indent=2` is part of the operator-facing `--json` contract."""
    mural_module._emit_json({"status": "cleared", "scope": "all"})

    out = capsys.readouterr().out
    assert "\n" in out.strip()
    assert json.loads(out) == {"status": "cleared", "scope": "all"}


# ---------------------------------------------------------------------------
# Record output preserves authored content and masks validated SAS URLs
#
# `_emit_records` is the primary stdout data path for every list command. It
# carries arbitrary Mural-authored values, so diagnostic key and pattern
# redaction would alter legitimate content. Only complete Azure Blob SAS URL
# values are transport credentials at this boundary.
# ---------------------------------------------------------------------------


def _json_args() -> argparse.Namespace:
    return argparse.Namespace(format="json", fields=None)


def test_emit_records_json_preserves_credential_shaped_content(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    records = [
        {
            "id": "w1",
            "text": "use code=ALPHA and access_token=placeholder",
            "client_secret": "workshop field label",
        }
    ]

    mural_module._emit_records(records, _json_args())

    out = capsys.readouterr().out
    assert json.loads(out) == records


def test_emit_record_table_preserves_credential_shaped_content(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    record = {
        "id": "w1",
        "text": "use code=ALPHA and access_token=placeholder",
        "client_secret": "workshop field label",
    }
    args = argparse.Namespace(format="table", fields=None)

    mural_module._emit_record(record, args)

    out = capsys.readouterr().out
    assert "use code=ALPHA and access_token=placeholder" in out
    assert "workshop field label" in out


def test_emit_records_masks_validated_azure_blob_sas_url(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    sas_url = (
        "https://example.blob.core.windows.net/container/blob.png"
        f"?sv=2024-11-04&sp=cw&sig={SECRET_VALUE}"
    )
    records = [{"id": "w1", "assetUrl": sas_url}]

    mural_module._emit_records(records, _json_args())

    out = capsys.readouterr().out
    assert SECRET_VALUE not in out
    assert json.loads(out) == [
        {
            "id": "w1",
            "assetUrl": "https://example.blob.core.windows.net/container/blob.png?***",
        }
    ]


def test_emit_records_preserves_benign_content(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    """Redaction must not disturb records that carry no secret shape."""
    records = [{"id": "w1", "text": "retrospective"}, {"id": "w2", "text": "blockers"}]

    mural_module._emit_records(records, _json_args())

    assert json.loads(capsys.readouterr().out) == records
