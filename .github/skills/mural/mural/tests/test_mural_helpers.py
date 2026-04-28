# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Unit tests for `mural` pure-helper surface (no transport)."""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
from email.message import Message
from typing import Any

import pytest
from test_constants import (
    ENV_TOKEN_STORE,
    ENV_XDG_DATA_HOME,
    TEST_REQUEST_ID,
)

# ---------------------------------------------------------------------------
# PKCE
# ---------------------------------------------------------------------------


def test_generate_pkce_pair_round_trip(mural_module: Any) -> None:
    verifier, challenge = mural_module._generate_pkce_pair()
    assert mural_module._verify_pkce(verifier, challenge) is True


def test_verify_pkce_rejects_mismatch(mural_module: Any) -> None:
    verifier, _ = mural_module._generate_pkce_pair()
    other_challenge = mural_module._b64url_nopad(b"\x00" * 32)
    assert mural_module._verify_pkce(verifier, other_challenge) is False


def test_b64url_nopad_strips_padding(mural_module: Any) -> None:
    encoded = mural_module._b64url_nopad(b"abc")
    assert "=" not in encoded
    assert encoded == "YWJj"


# ---------------------------------------------------------------------------
# Token store: path resolution + atomic 0600 persistence
# ---------------------------------------------------------------------------


def test_resolve_token_store_path_explicit_env(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    explicit = tmp_path / "explicit.json"
    env = {ENV_TOKEN_STORE: str(explicit)}
    assert mural_module._resolve_token_store_path(env=env) == explicit


def test_resolve_token_store_path_xdg(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    env = {ENV_XDG_DATA_HOME: str(tmp_path)}
    expected = tmp_path / "hve-core" / "mural-token.json"
    assert mural_module._resolve_token_store_path(env=env) == expected


def test_resolve_token_store_path_home_fallback(mural_module: Any) -> None:
    result = mural_module._resolve_token_store_path(env={})
    assert result.parts[-4:-1] == (".local", "share", "hve-core")
    assert result.name == "mural-token.json"


def test_load_token_store_missing_returns_none(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    missing = tmp_path / "no.json"
    assert mural_module._load_token_store(missing) is None


def test_load_token_store_invalid_json_raises(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    bad = tmp_path / "bad.json"
    bad.write_text("not json", encoding="utf-8")
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(bad)


def test_load_token_store_non_object_raises(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    bad = tmp_path / "list.json"
    bad.write_text("[1, 2, 3]", encoding="utf-8")
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(bad)


def test_save_token_store_writes_mode_0600(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    target = tmp_path / "subdir" / "store.json"
    payload = {"access_token": "abc", "refresh_token": "def"}
    mural_module._save_token_store(target, payload)
    assert target.exists()
    assert oct(target.stat().st_mode & 0o777) == "0o600"
    assert json.loads(target.read_text(encoding="utf-8")) == payload
    assert not (tmp_path / "subdir" / "store.json.tmp").exists()


def test_save_token_store_round_trip(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "store.json"
    data = {"access_token": "x", "expires_at": 1000}
    mural_module._save_token_store(path, data)
    assert mural_module._load_token_store(path) == data


# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "key", ["access_token", "refresh_token", "code_verifier", "code_challenge"]
)
def test_redact_json_style_tokens(mural_module: Any, key: str) -> None:
    text = f'before "{key}": "secret-value-12345" after'
    redacted = mural_module._redact(text)
    assert "secret-value-12345" not in redacted
    assert "***" in redacted


@pytest.mark.parametrize(
    "key",
    [
        "access_token",
        "refresh_token",
        "code_verifier",
        "code_challenge",
        "code",
    ],
)
def test_redact_form_style_tokens(mural_module: Any, key: str) -> None:
    text = f"prefix {key}=topsecret-AB.CD&other=keep"
    redacted = mural_module._redact(text)
    assert "topsecret-AB.CD" not in redacted
    assert f"{key}=***" in redacted
    assert "other=keep" in redacted


def test_redact_authorization_bearer(mural_module: Any) -> None:
    text = "Authorization: Bearer eyJabc.def.ghi"
    redacted = mural_module._redact(text)
    assert "eyJabc.def.ghi" not in redacted
    assert "***" in redacted


def test_redact_authorization_case_insensitive(mural_module: Any) -> None:
    text = "authorization=BEARER token-XYZ"
    redacted = mural_module._redact(text)
    assert "token-XYZ" not in redacted


def test_redact_azure_sas_signature(mural_module: Any) -> None:
    url = (
        "https://acct.blob.core.windows.net/container/blob.png?"
        "sv=2021&sig=SECRET-SIG-AAAA"
    )
    redacted = mural_module._redact(url)
    assert "SECRET-SIG-AAAA" not in redacted
    assert "sv=2021" not in redacted  # full querystring scrubbed
    assert "blob.core.windows.net/container/blob.png?***" in redacted


def test_redact_empty_passthrough(mural_module: Any) -> None:
    assert mural_module._redact("") == ""


# ---------------------------------------------------------------------------
# _extract_error_payload + _backoff_seconds
# ---------------------------------------------------------------------------


def _msg(headers: dict[str, str]) -> Message:
    msg = Message()
    for k, v in headers.items():
        msg[k] = v
    return msg


def test_extract_error_payload_full(mural_module: Any) -> None:
    body = json.dumps(
        {"code": "BAD_REQUEST", "message": "nope"}
    ).encode("utf-8")
    headers = _msg({"X-Request-Id": TEST_REQUEST_ID})
    code, message, request_id = mural_module._extract_error_payload(
        body, headers
    )
    assert code == "BAD_REQUEST"
    assert message == "nope"
    assert request_id == TEST_REQUEST_ID


def test_extract_error_payload_request_id_lowercase(mural_module: Any) -> None:
    headers = _msg({"x-request-id": TEST_REQUEST_ID})
    code, message, request_id = mural_module._extract_error_payload(
        b"", headers
    )
    assert code is None
    assert message is None
    assert request_id == TEST_REQUEST_ID


def test_extract_error_payload_falls_back_to_text(mural_module: Any) -> None:
    body = b"plain text failure"
    code, message, request_id = mural_module._extract_error_payload(body, None)
    assert code is None
    assert message == "plain text failure"
    assert request_id is None


def test_extract_error_payload_uses_error_field(mural_module: Any) -> None:
    body = json.dumps({"error": "go away"}).encode("utf-8")
    code, message, _ = mural_module._extract_error_payload(body, None)
    assert message == "go away"
    assert code is None


def test_backoff_seconds_uses_retry_after_header(mural_module: Any) -> None:
    headers = _msg({"Retry-After": "5"})
    assert mural_module._backoff_seconds(headers, attempt=0) == 5.0


def test_backoff_seconds_retry_after_case_insensitive(
    mural_module: Any,
) -> None:
    headers = _msg({"retry-after": "7"})
    assert mural_module._backoff_seconds(headers, attempt=0) == 7.0


def test_backoff_seconds_falls_back_to_exponential(mural_module: Any) -> None:
    assert mural_module._backoff_seconds(None, attempt=2) == 4.0
    assert mural_module._backoff_seconds(None, attempt=10) == 30.0


def test_backoff_seconds_caps_retry_after(mural_module: Any) -> None:
    headers = _msg({"Retry-After": "1000"})
    assert mural_module._backoff_seconds(headers, attempt=0) == 30.0


def test_backoff_seconds_invalid_retry_after_falls_back(
    mural_module: Any,
) -> None:
    headers = _msg({"Retry-After": "not-a-number"})
    assert mural_module._backoff_seconds(headers, attempt=1) == 2.0


# ---------------------------------------------------------------------------
# _parse_rate_limit_headers
# ---------------------------------------------------------------------------


def test_parse_rate_limit_headers_returns_values(mural_module: Any) -> None:
    headers = _msg(
        {"X-RateLimit-Remaining": "12", "X-RateLimit-Reset": "30"}
    )
    bucket = mural_module._TokenBucket()
    result = mural_module._parse_rate_limit_headers(headers, bucket=bucket)
    assert result == {"remaining": 12, "reset": 30}
    assert bucket.tokens > 0  # not drained


def test_parse_rate_limit_headers_drains_bucket_when_remaining_zero(
    mural_module: Any,
) -> None:
    headers = _msg(
        {"X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "10"}
    )
    bucket = mural_module._TokenBucket()
    bucket.tokens = 5.0
    result = mural_module._parse_rate_limit_headers(
        headers, bucket=bucket, now=lambda: 100.0
    )
    assert result == {"remaining": 0, "reset": 10}
    assert bucket.tokens == 0.0
    assert bucket.last_refill == 100.0


def test_parse_rate_limit_headers_missing_headers(mural_module: Any) -> None:
    bucket = mural_module._TokenBucket()
    result = mural_module._parse_rate_limit_headers(_msg({}), bucket=bucket)
    assert result == {"remaining": None, "reset": None}


def test_parse_rate_limit_headers_lowercase_lookup(mural_module: Any) -> None:
    headers = _msg(
        {"x-ratelimit-remaining": "5", "x-ratelimit-reset": "1"}
    )
    result = mural_module._parse_rate_limit_headers(headers)
    assert result == {"remaining": 5, "reset": 1}


# ---------------------------------------------------------------------------
# _validate_mural_id
# ---------------------------------------------------------------------------


def test_validate_mural_id_accepts_canonical(mural_module: Any) -> None:
    assert (
        mural_module._validate_mural_id("workspace1.mural-abc123")
        == "workspace1.mural-abc123"
    )


@pytest.mark.parametrize(
    "value",
    [
        "",
        "no-dot",
        "../etc/passwd",
        "ws/mural",
        "ws\\mural",
        "ws.mural\x00",
        "ws.mural with space",
        "ws..mural",
    ],
)
def test_validate_mural_id_rejects_bad_inputs(
    mural_module: Any, value: str
) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._validate_mural_id(value)


def test_validate_mural_id_rejects_non_string(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._validate_mural_id(None)  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# _validate_asset_url (SSRF allowlist)
# ---------------------------------------------------------------------------


def test_validate_asset_url_accepts_azure_blob(mural_module: Any) -> None:
    url = "https://acct.blob.core.windows.net/c/blob.png?sig=xyz"
    mural_module._validate_asset_url(url)  # no raise


@pytest.mark.parametrize(
    "url",
    [
        "",
        "http://acct.blob.core.windows.net/c/x",  # not https
        "https://user:pw@acct.blob.core.windows.net/c/x",  # userinfo
        "https://acct.blob.core.windows.net/c/x#frag",  # fragment
        "https://10.0.0.1/c/x",  # IPv4 literal
        "https://[::1]/c/x",  # IPv6 literal
        "https://evil.example.com/c/x",  # not on allowlist
        "https:///c/x",  # no host
    ],
)
def test_validate_asset_url_rejects_bad_inputs(
    mural_module: Any, url: str
) -> None:
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._validate_asset_url(url)


# ---------------------------------------------------------------------------
# _parse_pagination_cursor
# ---------------------------------------------------------------------------


def _b64url(payload: bytes) -> str:
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def test_parse_pagination_cursor_round_trip(mural_module: Any) -> None:
    token = _b64url(json.dumps({"offset": 50}).encode("utf-8"))
    assert mural_module._parse_pagination_cursor(token) == {"offset": 50}


@pytest.mark.parametrize(
    "value",
    ["", "!!!not-base64!!!", _b64url(b"not json"), _b64url(b'"a string"')],
)
def test_parse_pagination_cursor_rejects_bad(
    mural_module: Any, value: str
) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._parse_pagination_cursor(value)


def test_parse_pagination_cursor_rejects_oversize(mural_module: Any) -> None:
    big = "a" * (mural_module._MAX_CURSOR_BYTES + 1)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._parse_pagination_cursor(big)


# ---------------------------------------------------------------------------
# Body builders
# ---------------------------------------------------------------------------


def _ns(**kwargs: Any) -> argparse.Namespace:
    return argparse.Namespace(**kwargs)


def test_build_sticky_note_body_default_shape(mural_module: Any) -> None:
    args = _ns(text="hello", x=10, y=20, shape=None, width=None, height=None,
               style=None)
    body = mural_module._build_sticky_note_body(args)
    assert body == {"text": "hello", "x": 10.0, "y": 20.0, "shape": "rectangle"}


def test_build_sticky_note_body_with_style_and_dims(mural_module: Any) -> None:
    args = _ns(
        text="t", x="1", y="2", shape="circle", width=5, height=6,
        style='{"fill": "red"}',
    )
    body = mural_module._build_sticky_note_body(args)
    assert body["shape"] == "circle"
    assert body["width"] == 5.0
    assert body["height"] == 6.0
    assert body["style"] == {"fill": "red"}


def test_build_sticky_note_body_requires_text(mural_module: Any) -> None:
    args = _ns(text=None, x=0, y=0, shape=None, width=None, height=None,
               style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_sticky_note_body_invalid_xy(mural_module: Any) -> None:
    args = _ns(text="t", x="abc", y=0, shape=None, width=None, height=None,
               style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_sticky_note_body_invalid_style_json(mural_module: Any) -> None:
    args = _ns(text="t", x=0, y=0, shape=None, width=None, height=None,
               style="{not-json}")
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_textbox_body_happy(mural_module: Any) -> None:
    args = _ns(text="hi", x=1, y=2, width=None, height=None, style=None)
    assert mural_module._build_textbox_body(args) == {
        "text": "hi", "x": 1.0, "y": 2.0,
    }


def test_build_textbox_body_requires_text(mural_module: Any) -> None:
    args = _ns(text=None, x=0, y=0, width=None, height=None, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_textbox_body(args)


def test_build_shape_body_happy(mural_module: Any) -> None:
    args = _ns(shape="circle", x=0, y=0, width=10, height=10, text=None,
               style=None)
    body = mural_module._build_shape_body(args)
    assert body == {"shape": "circle", "x": 0.0, "y": 0.0,
                    "width": 10.0, "height": 10.0}


def test_build_shape_body_requires_shape(mural_module: Any) -> None:
    args = _ns(shape=None, x=0, y=0, width=None, height=None, text=None,
               style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_shape_body(args)


def test_build_arrow_body_happy(mural_module: Any) -> None:
    args = _ns(x1=0, y1=1, x2=2, y2=3, style=None)
    assert mural_module._build_arrow_body(args) == {
        "x1": 0.0, "y1": 1.0, "x2": 2.0, "y2": 3.0,
    }


def test_build_arrow_body_invalid_coord(mural_module: Any) -> None:
    args = _ns(x1="bad", y1=0, x2=0, y2=0, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_arrow_body(args)


def test_build_image_body_happy(mural_module: Any) -> None:
    args = _ns(x=10, y=20, width=None, height=None, title="caption")
    body = mural_module._build_image_body(asset_name="asset-1", args=args)
    assert body == {"name": "asset-1", "x": 10.0, "y": 20.0,
                    "title": "caption"}


def test_build_image_body_with_dims_no_title(mural_module: Any) -> None:
    args = _ns(x=0, y=0, width=100, height=200, title=None)
    body = mural_module._build_image_body(asset_name="img", args=args)
    assert body == {"name": "img", "x": 0.0, "y": 0.0,
                    "width": 100.0, "height": 200.0}


# ---------------------------------------------------------------------------
# _extract_field projection
# ---------------------------------------------------------------------------


def test_extract_field_dotted_path(mural_module: Any) -> None:
    obj = {"a": {"b": [{"c": 7}]}}
    assert mural_module._extract_field(obj, "a.b.0.c") == 7


def test_extract_field_missing_returns_none(mural_module: Any) -> None:
    assert mural_module._extract_field({"a": 1}, "a.b") is None
    assert mural_module._extract_field({"a": 1}, "missing") is None


def test_extract_field_empty_path_returns_object(mural_module: Any) -> None:
    obj = {"a": 1}
    assert mural_module._extract_field(obj, "") is obj
