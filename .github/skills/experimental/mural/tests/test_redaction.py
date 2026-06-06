# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Regression tests for `_redact` and the `_REDACT_KEYS` contract.

These tests guard the secret-scrubbing surface that protects logs from
leaking OAuth tokens, PKCE values, and the confidential client secret. A
break here means a real secret can land in a real log line, so the
intent is to fail loud on any silent regression of the key set or the
substitution patterns.
"""

from __future__ import annotations

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
