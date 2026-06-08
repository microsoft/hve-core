# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Unit tests for `mural` pure-helper surface (no transport)."""

from __future__ import annotations

import argparse
import base64
import importlib
import json
import math
import os
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


def test_save_token_store_round_trip(mural_module: Any, tmp_path: pathlib.Path) -> None:
    path = tmp_path / "store.json"
    envelope = {
        "schema_version": 2,
        "profiles": {
            "default": {
                "client_id": "cid",
                "access_token": "x",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 1000,
            },
        },
    }
    mural_module._save_token_store(path, envelope)
    assert mural_module._load_token_store(path) == envelope


# ---------------------------------------------------------------------------
# Token store v2: schema, profiles, migration, locking, Windows path
# ---------------------------------------------------------------------------


def test_resolve_token_store_path_windows_localappdata(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    if os.name != "nt":
        pytest.skip("Windows-only branch; pathlib.Path cannot be coerced cross-OS")
    env = {"LOCALAPPDATA": str(tmp_path)}
    expected = tmp_path / "hve-core" / "mural-token.json"
    assert mural_module._resolve_token_store_path(env=env) == expected


def test_resolve_token_store_path_windows_appdata_fallback(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    if os.name != "nt":
        pytest.skip("Windows-only branch; pathlib.Path cannot be coerced cross-OS")
    monkeypatch.setattr(
        mural_module.pathlib.Path, "home", classmethod(lambda cls: tmp_path)
    )
    env: dict[str, str] = {}
    expected = tmp_path / "AppData" / "Local" / "hve-core" / "mural-token.json"
    assert mural_module._resolve_token_store_path(env=env) == expected


def test_validate_profile_name_accepts_valid(mural_module: Any) -> None:
    for name in ("default", "dev_a.b-1", "a", "_x", "A1"):
        mural_module._validate_profile_name(name)


@pytest.mark.parametrize(
    "name",
    ["", ".", ".x", "a/b", "a b", "x" * 33, "-leading-dash"],
)
def test_validate_profile_name_rejects_invalid(mural_module: Any, name: str) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._validate_profile_name(name)


@pytest.mark.parametrize("bad", [123, None, [], ()])
def test_validate_profile_name_rejects_non_string(mural_module: Any, bad: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._validate_profile_name(bad)


def test_validate_profile_accepts_minimum_required(mural_module: Any) -> None:
    mural_module._validate_profile(
        {
            "client_id": "c",
            "access_token": "a",
            "token_type": "Bearer",
            "obtained_at": 0,
            "expires_at": 0,
        }
    )


@pytest.mark.parametrize(
    "missing", ["client_id", "access_token", "token_type", "obtained_at"]
)
def test_validate_profile_rejects_missing_required(
    mural_module: Any, missing: str
) -> None:
    base = {
        "client_id": "c",
        "access_token": "a",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 0,
    }
    base.pop(missing)
    with pytest.raises(mural_module.MuralError):
        mural_module._validate_profile(base)


def test_validate_profile_rejects_non_dict(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralError):
        mural_module._validate_profile("not a dict")  # type: ignore[arg-type]


def test_select_profile_returns_named(mural_module: Any) -> None:
    profile = {
        "client_id": "c",
        "access_token": "a",
        "token_type": "Bearer",
        "obtained_at": 0,
        "expires_at": 0,
    }
    store = {"schema_version": 2, "profiles": {"default": profile}}
    assert mural_module._select_profile(store, "default") is profile


def test_select_profile_missing_raises(mural_module: Any) -> None:
    store = {"schema_version": 2, "profiles": {}}
    with pytest.raises(mural_module.MuralError):
        mural_module._select_profile(store, "default")


def test_select_profile_missing_profiles_key_raises(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralError):
        mural_module._select_profile({"schema_version": 2}, "default")


def test_migrate_v1_to_v2_binds_client_id_from_env(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    legacy = {"access_token": "x", "refresh_token": "y", "expires_at": 1234}
    with caplog.at_level("WARNING"):
        envelope = mural_module._migrate_v1_to_v2(
            legacy, env={"MURAL_CLIENT_ID": "cid"}
        )
    assert envelope["schema_version"] == 2
    profile = envelope["profiles"]["default"]
    assert profile["client_id"] == "cid"
    assert profile["access_token"] == "x"
    assert profile["refresh_token"] == "y"
    assert profile["expires_at"] == 1234
    assert profile["token_type"] == "Bearer"
    assert profile["obtained_at"] == 0
    assert any(
        "legacy token cache had no client_id" in r.message for r in caplog.records
    )


def test_migrate_v1_to_v2_without_client_id_env_omits_client_id(
    mural_module: Any,
) -> None:
    legacy = {"access_token": "x"}
    envelope = mural_module._migrate_v1_to_v2(legacy, env={})
    profile = envelope["profiles"]["default"]
    assert "client_id" not in profile


def test_load_token_store_v1_without_client_id_raises(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("MURAL_CLIENT_ID", raising=False)
    path = tmp_path / "store.json"
    path.write_text(json.dumps({"access_token": "x"}), encoding="utf-8")
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(path)


def test_load_token_store_auto_migrates_v1_on_disk(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_CLIENT_ID", "cid")
    path = tmp_path / "store.json"
    path.write_text(json.dumps({"access_token": "x"}), encoding="utf-8")
    loaded = mural_module._load_token_store(path)
    assert loaded["schema_version"] == 2
    assert loaded["profiles"]["default"]["access_token"] == "x"
    assert loaded["profiles"]["default"]["client_id"] == "cid"
    # Migrated envelope is rewritten to disk under the same lock.
    on_disk = json.loads(path.read_text(encoding="utf-8"))
    assert on_disk == loaded


def test_load_token_store_rejects_unsupported_schema(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "store.json"
    path.write_text(
        json.dumps({"schema_version": 99, "profiles": {}}), encoding="utf-8"
    )
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(path)


def test_load_token_store_rejects_missing_profiles(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "store.json"
    path.write_text(json.dumps({"schema_version": 2}), encoding="utf-8")
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(path)


def test_load_token_store_rejects_bad_profile_name(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    path = tmp_path / "store.json"
    path.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "profiles": {
                    "bad name": {
                        "client_id": "c",
                        "access_token": "a",
                        "token_type": "Bearer",
                        "obtained_at": 0,
                        "expires_at": 0,
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(mural_module.MuralError):
        mural_module._load_token_store(path)


def test_save_token_store_locked_o_excl_collision_raises(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    import os as _os
    import threading as _threading

    target = tmp_path / "store.json"
    tmp_name = f"{target.name}.{_os.getpid()}.{_threading.get_ident()}.tmp"
    collision = tmp_path / tmp_name
    collision.write_text("conflict", encoding="utf-8")
    envelope = {
        "schema_version": 2,
        "profiles": {
            "default": {
                "client_id": "c",
                "access_token": "a",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 0,
            }
        },
    }
    with pytest.raises(FileExistsError):
        mural_module._save_token_store_locked(target, envelope)


def test_acquire_cache_lock_serializes_two_threads(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    import threading as _threading
    import time as _time

    target = tmp_path / "store.json"
    order: list[str] = []
    barrier = _threading.Barrier(2)

    def _worker(label: str, hold_seconds: float) -> None:
        barrier.wait()
        with mural_module._acquire_cache_lock(target):
            order.append(f"{label}-enter")
            _time.sleep(hold_seconds)
            order.append(f"{label}-exit")

    t1 = _threading.Thread(target=_worker, args=("a", 0.05))
    t2 = _threading.Thread(target=_worker, args=("b", 0.0))
    t1.start()
    t2.start()
    t1.join(timeout=2)
    t2.join(timeout=2)

    # Whichever thread won the lock first must release before the other enters.
    assert len(order) == 4
    assert order[1].endswith("-exit")
    assert order[0].split("-")[0] != order[2].split("-")[0]
    # Lockfile is created and never deleted by the lock helper.
    assert (tmp_path / "store.json.lock").exists()


def test_authenticated_request_rejects_client_id_mismatch(
    mural_module: Any, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_CLIENT_ID", "new-cid")
    target = tmp_path / "store.json"
    envelope = {
        "schema_version": 2,
        "profiles": {
            "default": {
                "client_id": "old-cid",
                "access_token": "a",
                "token_type": "Bearer",
                "obtained_at": 0,
                "expires_at": 9_999_999_999,
            }
        },
    }
    mural_module._save_token_store(target, envelope)
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._authenticated_request(
            "GET",
            "/workspaces",
            token_store_path=target,
            _http=lambda *a, **kw: None,
            _now=lambda: 0.0,
            _sleep=lambda _s: None,
        )


# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("key", ["access_token", "refresh_token", "code_verifier"])
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
        "code",
    ],
)
def test_redact_form_style_tokens(mural_module: Any, key: str) -> None:
    text = f"prefix {key}=topsecret-AB.CD&other=keep"
    redacted = mural_module._redact(text)
    assert "topsecret-AB.CD" not in redacted
    assert f"{key}=***" in redacted
    assert "other=keep" in redacted


def test_redact_preserves_pkce_code_challenge(mural_module: Any) -> None:
    # PKCE challenge is public by design (RFC 7636); only the verifier is secret.
    url = "https://app.mural.co/api/public/v1/authorization/oauth2/?code_challenge=ABC123XYZ&code_challenge_method=S256"
    redacted = mural_module._redact(url)
    assert "ABC123XYZ" in redacted
    assert "code_challenge=ABC123XYZ" in redacted


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
    body = json.dumps({"code": "BAD_REQUEST", "message": "nope"}).encode("utf-8")
    headers = _msg({"X-Request-Id": TEST_REQUEST_ID})
    code, message, request_id = mural_module._extract_error_payload(body, headers)
    assert code == "BAD_REQUEST"
    assert message == "nope"
    assert request_id == TEST_REQUEST_ID


def test_extract_error_payload_request_id_lowercase(mural_module: Any) -> None:
    headers = _msg({"x-request-id": TEST_REQUEST_ID})
    code, message, request_id = mural_module._extract_error_payload(b"", headers)
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
    headers = _msg({"X-RateLimit-Remaining": "12", "X-RateLimit-Reset": "30"})
    bucket = mural_module._TokenBucket()
    result = mural_module._parse_rate_limit_headers(headers, bucket=bucket)
    assert result == {"remaining": 12, "reset": 30}
    assert bucket.tokens > 0  # not drained


def test_parse_rate_limit_headers_drains_bucket_when_remaining_zero(
    mural_module: Any,
) -> None:
    headers = _msg({"X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "10"})
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
    headers = _msg({"x-ratelimit-remaining": "5", "x-ratelimit-reset": "1"})
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
def test_validate_mural_id_rejects_bad_inputs(mural_module: Any, value: str) -> None:
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
def test_validate_asset_url_rejects_bad_inputs(mural_module: Any, url: str) -> None:
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
def test_parse_pagination_cursor_rejects_bad(mural_module: Any, value: str) -> None:
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
    args = _ns(
        text="hello", x=10, y=20, shape=None, width=None, height=None, style=None
    )
    body = mural_module._build_sticky_note_body(args)
    assert body == {"text": "hello", "x": 10.0, "y": 20.0, "shape": "rectangle"}


def test_build_sticky_note_body_with_style_and_dims(mural_module: Any) -> None:
    args = _ns(
        text="t",
        x="1",
        y="2",
        shape="circle",
        width=5,
        height=6,
        style='{"fill": "red"}',
    )
    body = mural_module._build_sticky_note_body(args)
    assert body["shape"] == "circle"
    assert body["width"] == 5.0
    assert body["height"] == 6.0
    assert body["style"] == {"fill": "red"}


def test_build_sticky_note_body_requires_text(mural_module: Any) -> None:
    args = _ns(text=None, x=0, y=0, shape=None, width=None, height=None, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_sticky_note_body_invalid_xy(mural_module: Any) -> None:
    args = _ns(text="t", x="abc", y=0, shape=None, width=None, height=None, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_sticky_note_body_invalid_style_json(mural_module: Any) -> None:
    args = _ns(
        text="t", x=0, y=0, shape=None, width=None, height=None, style="{not-json}"
    )
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_sticky_note_body(args)


def test_build_textbox_body_happy(mural_module: Any) -> None:
    args = _ns(text="hi", x=1, y=2, width=None, height=None, style=None)
    assert mural_module._build_textbox_body(args) == {
        "text": "hi",
        "x": 1.0,
        "y": 2.0,
    }


def test_build_textbox_body_requires_text(mural_module: Any) -> None:
    args = _ns(text=None, x=0, y=0, width=None, height=None, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_textbox_body(args)


def test_build_shape_body_happy(mural_module: Any) -> None:
    args = _ns(shape="circle", x=0, y=0, width=10, height=10, text=None, style=None)
    body = mural_module._build_shape_body(args)
    assert body == {
        "shape": "circle",
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
    }


def test_build_shape_body_requires_shape(mural_module: Any) -> None:
    args = _ns(shape=None, x=0, y=0, width=None, height=None, text=None, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_shape_body(args)


def test_build_arrow_body_happy(mural_module: Any) -> None:
    args = _ns(x1=0, y1=1, x2=2, y2=3, style=None)
    assert mural_module._build_arrow_body(args) == {
        "x1": 0.0,
        "y1": 1.0,
        "x2": 2.0,
        "y2": 3.0,
    }


def test_build_arrow_body_invalid_coord(mural_module: Any) -> None:
    args = _ns(x1="bad", y1=0, x2=0, y2=0, style=None)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_arrow_body(args)


def test_build_image_body_happy(mural_module: Any) -> None:
    args = _ns(x=10, y=20, width=None, height=None, title="caption")
    body = mural_module._build_image_body(asset_name="asset-1", args=args)
    assert body == {"name": "asset-1", "x": 10.0, "y": 20.0, "title": "caption"}


def test_build_image_body_with_dims_no_title(mural_module: Any) -> None:
    args = _ns(x=0, y=0, width=100, height=200, title=None)
    body = mural_module._build_image_body(asset_name="img", args=args)
    assert body == {"name": "img", "x": 0.0, "y": 0.0, "width": 100.0, "height": 200.0}


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


# ---------------------------------------------------------------------------
# Phase 4: redaction, token-bucket concurrency, atomic token-store writes
# ---------------------------------------------------------------------------


def test_emit_redacts_all_redact_keys(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    """Step 4.1: every key in `_REDACT_KEYS` must be scrubbed from stderr."""
    import json as _json

    secrets = {key: f"SECRET-{key.upper()}-VALUE" for key in mural_module._REDACT_KEYS}
    mural_module._emit(_json.dumps(secrets))

    captured = capsys.readouterr().err
    for key, value in secrets.items():
        assert value not in captured, f"raw value for {key} leaked: {captured}"
        assert f'"{key}": "***"' in captured


def test_emit_redacts_form_and_authorization_shapes(
    mural_module: Any, capsys: pytest.CaptureFixture[str]
) -> None:
    """Step 4.1: form-style and Authorization-header shapes are also scrubbed."""
    mural_module._emit(
        "POST /token code=AUTHCODE access_token=ATKN refresh_token=RTKN "
        "Authorization: Bearer SHHH"
    )
    err = capsys.readouterr().err
    for token in ("AUTHCODE", "ATKN", "RTKN", "SHHH"):
        assert token not in err, f"{token} leaked: {err}"
    assert "***" in err


def test_token_bucket_acquire_is_thread_safe_under_contention(
    mural_module: Any,
) -> None:
    """Step 4.4: 32 threads x 100 acquires complete without races or deadlock."""
    import threading

    bucket = mural_module._TokenBucket()
    bucket.tokens = bucket.capacity

    clock = [0.0]
    clock_lock = threading.Lock()
    sleeps: list[float] = []

    def _now() -> float:
        with clock_lock:
            return clock[0]

    def _sleep(seconds: float) -> None:
        with clock_lock:
            clock[0] += float(seconds)
            sleeps.append(float(seconds))

    bucket.last_refill = _now()

    THREADS = 32
    PER_THREAD = 100
    EXPECTED = THREADS * PER_THREAD
    counter = {"value": 0}
    counter_lock = threading.Lock()

    def _worker() -> None:
        for _ in range(PER_THREAD):
            mural_module._token_bucket_acquire(bucket=bucket, now=_now, sleep=_sleep)
            with counter_lock:
                counter["value"] += 1

    threads = [threading.Thread(target=_worker) for _ in range(THREADS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=10.0)
        assert not t.is_alive(), "worker thread deadlocked"

    assert counter["value"] == EXPECTED
    assert bucket.tokens >= 0.0
    assert bucket.tokens <= bucket.capacity


def test_save_token_store_is_atomic_under_concurrent_writers(
    mural_module: Any, tmp_path: Any
) -> None:
    """Step 4.5: concurrent saves leave the file readable, JSON-valid, mode 0600."""
    import json as _json
    import threading

    store_path = tmp_path / "concurrent.json"
    seeds = list(range(16))
    barrier = threading.Barrier(len(seeds))

    def _writer(value: int) -> None:
        barrier.wait(timeout=5.0)
        mural_module._save_token_store(store_path, {"v": value})

    threads = [threading.Thread(target=_writer, args=(v,)) for v in seeds]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=5.0)
        assert not t.is_alive()

    import os as _os
    import stat as _stat

    mode = _stat.S_IMODE(_os.stat(store_path).st_mode)
    assert mode == 0o600, f"expected 0600, got {oct(mode)}"
    parsed = _json.loads(store_path.read_text(encoding="utf-8"))
    assert parsed["v"] in seeds


def test_save_token_store_corrects_loose_permissions(
    mural_module: Any, tmp_path: Any
) -> None:
    """Step 4.5: pre-existing 0644 file is normalized to 0600 on save."""
    import os as _os
    import stat as _stat

    store_path = tmp_path / "preexisting.json"
    store_path.write_text('{"old": true}', encoding="utf-8")
    _os.chmod(store_path, 0o644)
    assert _stat.S_IMODE(_os.stat(store_path).st_mode) == 0o644

    mural_module._save_token_store(store_path, {"refreshed": True})

    mode = _stat.S_IMODE(_os.stat(store_path).st_mode)
    assert mode == 0o600, f"expected 0600, got {oct(mode)}"


# ---------------------------------------------------------------------------
# Phase 2: bulk widget payload validation
# ---------------------------------------------------------------------------


def test_build_bulk_widgets_payload_accepts_top_level_list(
    mural_module: Any,
) -> None:
    payload = [{"type": "sticky-note", "text": "hi"}, {"type": "textbox"}]
    out = mural_module._build_bulk_widgets_payload(payload)
    assert out == payload


def test_build_bulk_widgets_payload_accepts_widgets_wrapper(
    mural_module: Any,
) -> None:
    out = mural_module._build_bulk_widgets_payload(
        {"widgets": [{"type": "sticky-note"}]}
    )
    assert out == [{"type": "sticky-note"}]


def test_build_bulk_widgets_payload_rejects_non_list(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload({"foo": "bar"})


def test_build_bulk_widgets_payload_rejects_empty(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload([])


def test_build_bulk_widgets_payload_rejects_oversize(mural_module: Any) -> None:
    huge = [{"type": "sticky-note"}] * (mural_module.MAX_BULK_WIDGETS + 1)
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload(huge)


def test_build_bulk_widgets_payload_rejects_non_dict_entry(
    mural_module: Any,
) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload([{"type": "x"}, "nope"])


def test_build_bulk_widgets_payload_rejects_missing_type(
    mural_module: Any,
) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload([{"text": "no type"}])


def test_build_bulk_widgets_payload_rejects_empty_type(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._build_bulk_widgets_payload([{"type": ""}])


# ---------------------------------------------------------------------------
# Phase 2: poll condition parsing + evaluation
# ---------------------------------------------------------------------------


def test_parse_poll_condition_simple_eq(mural_module: Any) -> None:
    segments, op, expected = mural_module._parse_poll_condition("status==active")
    assert segments == ["status"]
    assert op == "=="
    assert expected == "active"


def test_parse_poll_condition_dotted_neq(mural_module: Any) -> None:
    segments, op, expected = mural_module._parse_poll_condition("meta.foo!=bar")
    assert segments == ["meta", "foo"]
    assert op == "!="
    assert expected == "bar"


@pytest.mark.parametrize(
    "bad",
    ["", "   ", "noop", "==value", "path==", "path== "],
)
def test_parse_poll_condition_rejects_invalid(mural_module: Any, bad: str) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._parse_poll_condition(bad)


def test_resolve_dotted_walks_nested_dict(mural_module: Any) -> None:
    assert mural_module._resolve_dotted({"a": {"b": 1}}, ["a", "b"]) == 1


def test_resolve_dotted_returns_none_on_non_dict_cursor(
    mural_module: Any,
) -> None:
    assert mural_module._resolve_dotted({"a": [1, 2]}, ["a", "b"]) is None


def test_evaluate_poll_eq_match(mural_module: Any) -> None:
    assert (
        mural_module._evaluate_poll({"status": "active"}, ["status"], "==", "active")
        is True
    )


def test_evaluate_poll_eq_miss(mural_module: Any) -> None:
    assert (
        mural_module._evaluate_poll({"status": "draft"}, ["status"], "==", "active")
        is False
    )


def test_evaluate_poll_neq(mural_module: Any) -> None:
    assert (
        mural_module._evaluate_poll({"status": "draft"}, ["status"], "!=", "active")
        is True
    )


def test_evaluate_poll_missing_field_coerces_to_empty(
    mural_module: Any,
) -> None:
    assert mural_module._evaluate_poll({}, ["status"], "==", "") is True


# ---------------------------------------------------------------------------
# Phase 2: _poll_mural backoff + timeout
# ---------------------------------------------------------------------------


def test_poll_mural_matches_first_attempt(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda method, path, **kw: {"status": "active"},
    )
    result = mural_module._poll_mural(
        "ws.mural-1",
        interval_s=1.0,
        timeout_s=10.0,
        condition="status==active",
        sleep=lambda _s: None,
        monotonic=lambda: 0.0,
    )
    assert result["matched"] is True
    assert result["attempts"] == 1
    assert result["condition"] == "status==active"
    assert result["mural"] == {"status": "active"}


def test_poll_mural_times_out(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda method, path, **kw: {"status": "draft"},
    )
    clock = iter([0.0, 0.0, 100.0, 100.0, 100.0])
    with pytest.raises(mural_module.MuralValidationError) as excinfo:
        mural_module._poll_mural(
            "ws.mural-1",
            interval_s=1.0,
            timeout_s=1.0,
            condition="status==active",
            sleep=lambda _s: None,
            monotonic=lambda: next(clock),
        )
    assert "poll timeout" in str(excinfo.value)


@pytest.mark.parametrize(
    "interval,timeout",
    [(0.0, 1.0), (-1.0, 1.0), (1.0, 0.0), (1.0, -1.0)],
)
def test_poll_mural_rejects_non_positive(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    interval: float,
    timeout: float,
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda method, path, **kw: {},
    )
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._poll_mural(
            "ws.mural-1",
            interval_s=interval,
            timeout_s=timeout,
            condition="status==active",
            sleep=lambda _s: None,
            monotonic=lambda: 0.0,
        )


def test_poll_mural_rejects_oversize_interval(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda method, path, **kw: {},
    )
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._poll_mural(
            "ws.mural-1",
            interval_s=mural_module.POLL_MAX_INTERVAL_S + 1,
            timeout_s=10.0,
            condition="status==active",
            sleep=lambda _s: None,
            monotonic=lambda: 0.0,
        )


def test_poll_mural_rejects_oversize_timeout(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda method, path, **kw: {},
    )
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._poll_mural(
            "ws.mural-1",
            interval_s=1.0,
            timeout_s=mural_module.POLL_MAX_TIMEOUT_S + 1,
            condition="status==active",
            sleep=lambda _s: None,
            monotonic=lambda: 0.0,
        )


# ---------------------------------------------------------------------------
# Phase 2: template target body + payload file loader
# ---------------------------------------------------------------------------


def test_template_target_body_resolves_workspace_from_env(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_DEFAULT_WORKSPACE", "ws-default")
    body = mural_module._template_target_body(None, None, None)
    assert body == {"workspaceId": "ws-default"}


def test_template_target_body_includes_room_and_name(
    mural_module: Any,
) -> None:
    body = mural_module._template_target_body("ws-1", "room-1", "Hello")
    assert body == {"workspaceId": "ws-1", "roomId": "room-1", "name": "Hello"}


def test_load_payload_file_reads_utf8(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    target = tmp_path / "p.json"
    target.write_text('{"a": 1}', encoding="utf-8")
    assert mural_module._load_payload_file(str(target)) == '{"a": 1}'


def test_load_payload_file_rejects_empty_path(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._load_payload_file("")


def test_load_payload_file_raises_on_missing(
    mural_module: Any, tmp_path: pathlib.Path
) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._load_payload_file(str(tmp_path / "absent.json"))


# ---------------------------------------------------------------------------
# Phase 7: _merge_tags RMW + retries
# ---------------------------------------------------------------------------


def _patch_merge_tags(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    *,
    initial_tags: list[str],
    observed_after_patch: list[str] | None = None,
    raise_on_get: BaseException | None = None,
) -> dict[str, list[Any]]:
    """Wire `_authenticated_request` for `_merge_tags`.

    GET responses cycle through ``initial_tags`` (pre-patch) then
    ``observed_after_patch`` (post-patch). When ``observed_after_patch`` is
    ``None`` the post-patch GET echoes whatever ``target`` was sent in the
    PATCH so convergence succeeds.
    """
    calls: dict[str, list[Any]] = {"requests": [], "patched_target": []}
    state: dict[str, Any] = {"phase": "pre"}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        calls["requests"].append((method, path, kwargs))
        if method == "PATCH":
            sent = kwargs.get("json_body", {}).get("tags", [])
            calls["patched_target"].append(list(sent))
            state["phase"] = "post"
            return {"id": "w-1", "tags": list(sent)}
        if raise_on_get is not None and state["phase"] == "pre":
            raise raise_on_get
        if state["phase"] == "pre":
            return {"id": "w-1", "tags": list(initial_tags)}
        if observed_after_patch is None:
            return {"id": "w-1", "tags": list(calls["patched_target"][-1])}
        state["phase"] = "pre"
        return {"id": "w-1", "tags": list(observed_after_patch)}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    monkeypatch.setattr(mural_module, "_tag_merge_backoff_seconds", lambda: 0.0)
    monkeypatch.setattr(mural_module.time, "sleep", lambda _s: None)
    return calls


def test_merge_tags_noop_when_no_additions_or_removals(mural_module: Any) -> None:
    result = mural_module._merge_tags("mural-1", "w-1")
    assert result == {
        "ok": True,
        "widget": "w-1",
        "tags": [],
        "added": [],
        "removed": [],
        "attempts": 0,
        "noop": True,
    }


def test_merge_tags_dedups_and_sorts_target(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = _patch_merge_tags(monkeypatch, mural_module, initial_tags=["b", "c"])
    result = mural_module._merge_tags(
        "mural-1",
        "w-1",
        additions=["a", "a", "c"],
        removals=["b", "b"],
    )
    assert result["ok"] is True
    assert result["tags"] == ["a", "c"]
    assert result["added"] == ["a"]
    assert result["removed"] == ["b"]
    assert result["attempts"] == 1
    # PATCH was sent the sorted union/diff target
    assert calls["patched_target"] == [["a", "c"]]


def test_merge_tags_retries_until_convergence(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    # First post-patch GET shows drift, second succeeds (echo target).
    state = {"calls": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        state["calls"] += 1
        if method == "PATCH":
            return {"id": "w-1", "tags": kwargs["json_body"]["tags"]}
        # GETs alternate: pre1, post1(drift), pre2, post2(ok)
        i = state["calls"]
        if i == 1:
            return {"id": "w-1", "tags": []}
        if i == 3:
            return {"id": "w-1", "tags": ["x"]}  # post-patch1: dropped
        if i == 4:
            return {"id": "w-1", "tags": ["x"]}  # pre-patch2
        return {"id": "w-1", "tags": ["x", "y"]}  # post-patch2: ok

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    monkeypatch.setattr(mural_module, "_tag_merge_backoff_seconds", lambda: 0.0)
    monkeypatch.setattr(mural_module.time, "sleep", lambda _s: None)

    result = mural_module._merge_tags("mural-1", "w-1", additions=["x", "y"])
    assert result["ok"] is True
    assert result["attempts"] == 2
    assert result["tags"] == ["x", "y"]


def test_merge_tags_raises_conflict_after_max_retries(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_merge_tags(
        monkeypatch,
        mural_module,
        initial_tags=[],
        observed_after_patch=[],  # never converges
    )
    with pytest.raises(mural_module.MuralTagMergeConflict) as excinfo:
        mural_module._merge_tags("mural-1", "w-1", additions=["x"], max_retries=2)
    err = excinfo.value
    assert err.attempts == 2
    assert err.intended == ["x"]
    assert err.observed == []
    assert err.missing == ["x"]
    assert err.extra == []


def test_merge_tags_records_session_manifest_on_success(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_merge_tags(monkeypatch, mural_module, initial_tags=[])
    mural_module._merge_tags("mural-1", "w-1", additions=["alpha", "beta"])
    assert mural_module._SessionManifest[("mural-1", "w-1")] == {"alpha", "beta"}


# ---------------------------------------------------------------------------
# Phase 7: lineage prefix (format / apply / parse)
# ---------------------------------------------------------------------------


def test_lineage_prefix_formats_marker(mural_module: Any) -> None:
    assert (
        mural_module._lineage_prefix(3, "personas", "run-42")
        == "[dt:method=3 section=personas run=run-42]"
    )


def test_apply_lineage_prefix_sets_title_when_missing(mural_module: Any) -> None:
    payload: dict[str, Any] = {}
    out = mural_module._apply_lineage_prefix(payload, "[dt:method=1 section=s run=r]")
    assert out is payload
    assert payload["title"] == "[dt:method=1 section=s run=r]"


def test_apply_lineage_prefix_prepends_existing_title(mural_module: Any) -> None:
    payload = {"title": "Original copy"}
    mural_module._apply_lineage_prefix(payload, "[dt:method=1 section=s run=r]")
    assert payload["title"] == "[dt:method=1 section=s run=r] Original copy"


def test_apply_lineage_prefix_is_idempotent(mural_module: Any) -> None:
    marked = "[dt:method=2 section=story run=r1] hello"
    payload = {"title": marked}
    mural_module._apply_lineage_prefix(payload, "[dt:method=9 section=other run=r2]")
    assert payload["title"] == marked


def test_apply_lineage_prefix_skips_leading_whitespace_marker(
    mural_module: Any,
) -> None:
    marked = "   [dt:method=1 section=a run=r] padded"
    payload = {"title": marked}
    mural_module._apply_lineage_prefix(payload, "[dt:method=2 section=b run=r2]")
    assert payload["title"] == marked


def test_apply_lineage_prefix_returns_non_dict_unchanged(mural_module: Any) -> None:
    assert mural_module._apply_lineage_prefix(None, "[dt:...]") is None  # type: ignore[arg-type]


def test_parse_lineage_prefix_full_marker(mural_module: Any) -> None:
    parsed = mural_module._parse_lineage_prefix(
        "[dt:method=4 section=ideation run=abc123] body"
    )
    assert parsed == {"method": 4, "section": "ideation", "run_id": "abc123"}


def test_parse_lineage_prefix_is_positional(mural_module: Any) -> None:
    # Parser is order-sensitive: only fields appearing in the canonical
    # ``method=N section=S run=R`` order are recognized; out-of-order keys
    # before ``method`` are skipped to None.
    parsed = mural_module._parse_lineage_prefix("[dt:section=a run=r method=7]")
    assert parsed is not None
    assert parsed["method"] == 7
    assert parsed["section"] is None
    assert parsed["run_id"] is None


def test_parse_lineage_prefix_missing_keys(mural_module: Any) -> None:
    parsed = mural_module._parse_lineage_prefix("[dt:method=1]")
    assert parsed == {"method": 1, "section": None, "run_id": None}


def test_parse_lineage_prefix_returns_none_for_unmarked(mural_module: Any) -> None:
    assert mural_module._parse_lineage_prefix("plain title") is None


def test_parse_lineage_prefix_returns_none_for_non_string(mural_module: Any) -> None:
    assert mural_module._parse_lineage_prefix(None) is None  # type: ignore[arg-type]
    assert mural_module._parse_lineage_prefix(42) is None  # type: ignore[arg-type]


def test_parse_lineage_prefix_empty_string(mural_module: Any) -> None:
    assert mural_module._parse_lineage_prefix("") is None


# ---------------------------------------------------------------------------
# Phase 7: layout primitives + envelope/capacity/overflow
# ---------------------------------------------------------------------------


def test_layout_grid_places_widgets_row_major(mural_module: Any) -> None:
    widgets = [{"id": str(i)} for i in range(5)]
    placed = mural_module._layout_grid(
        widgets, columns=2, cell_width=100, cell_height=50, gutter=10
    )
    coords = [(w["x"], w["y"]) for w in placed]
    assert coords == [
        (0.0, 0.0),
        (110.0, 0.0),
        (0.0, 60.0),
        (110.0, 60.0),
        (0.0, 120.0),
    ]
    assert placed[0]["width"] == 100
    assert placed[0]["height"] == 50


def test_layout_grid_preserves_existing_geometry(mural_module: Any) -> None:
    widgets = [{"id": "a", "width": 200, "height": 80}]
    placed = mural_module._layout_grid(widgets, columns=1)
    assert placed[0]["width"] == 200
    assert placed[0]["height"] == 80


def test_layout_grid_rejects_zero_columns(mural_module: Any) -> None:
    with pytest.raises(mural_module.MuralValidationError):
        mural_module._layout_grid([], columns=0)


def test_layout_cluster_uses_ceil_sqrt_columns(mural_module: Any) -> None:
    widgets = [{"id": str(i)} for i in range(7)]
    placed = mural_module._layout_cluster(
        widgets, cell_width=10, cell_height=10, gutter=0
    )
    # ceil(sqrt(7)) == 3 columns -> rows 0,0,0,1,1,1,2
    rows = [int(w["y"] / 10) for w in placed]
    assert rows == [0, 0, 0, 1, 1, 1, 2]


def test_layout_cluster_empty_returns_empty(mural_module: Any) -> None:
    assert mural_module._layout_cluster([]) == []


def test_layout_column_stacks_vertically(mural_module: Any) -> None:
    widgets = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
    placed = mural_module._layout_column(
        widgets, cell_width=10, cell_height=10, gutter=2
    )
    assert [w["x"] for w in placed] == [0.0, 0.0, 0.0]
    assert [w["y"] for w in placed] == [0.0, 12.0, 24.0]


def test_layout_row_lays_horizontally(mural_module: Any) -> None:
    widgets = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
    placed = mural_module._layout_row(widgets, cell_width=10, cell_height=10, gutter=2)
    assert [w["y"] for w in placed] == [0.0, 0.0, 0.0]
    assert [w["x"] for w in placed] == [0.0, 12.0, 24.0]


def test_layout_row_empty_keeps_columns_at_one(mural_module: Any) -> None:
    # Defensive: empty list yields empty output even though row uses max(1, n).
    assert mural_module._layout_row([]) == []


def test_layout_funcs_registry_covers_four_kinds(mural_module: Any) -> None:
    assert set(mural_module._LAYOUT_FUNCS) == {"grid", "cluster", "column", "row"}


def test_layout_canonical_widget_drops_geometry(mural_module: Any) -> None:
    canonical = mural_module._layout_canonical_widget(
        {"id": "x", "x": 1, "y": 2, "width": 10, "height": 20, "text": "keep"}
    )
    assert canonical == {"text": "keep"}


def test_layout_canonical_widget_handles_non_dict(mural_module: Any) -> None:
    assert mural_module._layout_canonical_widget("nope") == {}  # type: ignore[arg-type]


def test_layout_hash_is_stable_across_equal_inputs(mural_module: Any) -> None:
    widgets = [{"id": "ignored", "text": "alpha"}, {"text": "beta"}]
    h1 = mural_module._layout_hash(area_id="a1", layout="grid", widgets=widgets)
    h2 = mural_module._layout_hash(
        area_id="a1",
        layout="grid",
        widgets=[
            {"id": "different", "text": "alpha", "x": 99, "y": 99},
            {"text": "beta", "width": 1, "height": 1},
        ],
    )
    assert h1 == h2
    assert len(h1) == 12


def test_layout_hash_changes_with_params(mural_module: Any) -> None:
    widgets = [{"text": "a"}]
    h1 = mural_module._layout_hash(area_id="a", layout="grid", widgets=widgets)
    h2 = mural_module._layout_hash(
        area_id="a", layout="grid", widgets=widgets, params={"columns": 3}
    )
    assert h1 != h2


def test_layout_envelope_for_empty_returns_zeros(mural_module: Any) -> None:
    assert mural_module._layout_envelope([]) == {
        "x": 0.0,
        "y": 0.0,
        "width": 0.0,
        "height": 0.0,
    }


def test_layout_envelope_computes_bounds(mural_module: Any) -> None:
    widgets = [
        {"x": 10, "y": 20, "width": 100, "height": 50},
        {"x": 50, "y": 80, "width": 200, "height": 30},
    ]
    env = mural_module._layout_envelope(widgets)
    assert env == {"x": 10.0, "y": 20.0, "width": 240.0, "height": 90.0}


def test_area_capacity_uses_top_level_dimensions(mural_module: Any) -> None:
    assert mural_module._area_capacity({"width": 500, "height": 400}) == {
        "width": 500.0,
        "height": 400.0,
    }


def test_area_capacity_falls_back_to_bounds(mural_module: Any) -> None:
    cap = mural_module._area_capacity({"bounds": {"width": 100, "height": 200}})
    assert cap == {"width": 100.0, "height": 200.0}


def test_area_capacity_missing_dimensions_yield_inf(mural_module: Any) -> None:
    cap = mural_module._area_capacity({})
    assert cap["width"] == float("inf")
    assert cap["height"] == float("inf")


def test_area_overflow_detects_overflow(mural_module: Any) -> None:
    overflow, capacity = mural_module._area_overflow(
        area={"width": 100, "height": 100},
        envelope={"x": 0, "y": 0, "width": 200, "height": 50},
    )
    assert overflow is True
    assert capacity == {"width": 100.0, "height": 100.0}


def test_area_overflow_no_overflow_within_bounds(mural_module: Any) -> None:
    overflow, _ = mural_module._area_overflow(
        area={"width": 1000, "height": 1000},
        envelope={"x": 0, "y": 0, "width": 100, "height": 100},
    )
    assert overflow is False


# ---------------------------------------------------------------------------
# Phase 7: _repair_tag_drift sweep
# ---------------------------------------------------------------------------


def test_repair_tag_drift_returns_empty_when_no_manifest(
    mural_module: Any,
) -> None:
    mural_module._SessionManifest.clear()
    assert mural_module._repair_tag_drift("mural-empty") == []


def test_repair_tag_drift_skips_widgets_in_sync(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    mural_module._SessionManifest.clear()
    mural_module._SessionManifest[("mural-1", "w-1")] = {"red"}
    monkeypatch.setattr(
        mural_module,
        "_ensure_tag_manifest",
        lambda _mid, _entries: {"red": "tag-red"},
    )

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        assert method == "GET"
        return {"id": "w-1", "tags": ["tag-red"]}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    assert mural_module._repair_tag_drift("mural-1") == []


def test_repair_tag_drift_repairs_missing_tags(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    mural_module._SessionManifest.clear()
    mural_module._SessionManifest[("mural-1", "w-1")] = {"red"}
    monkeypatch.setattr(
        mural_module,
        "_ensure_tag_manifest",
        lambda _mid, _entries: {"red": "tag-red"},
    )
    captured: dict[str, Any] = {}

    def fake_merge(
        mid: str,
        wid: str,
        *,
        additions: list[str],
        removals: list[str],
        max_retries: int,
    ) -> dict[str, Any]:
        captured["additions"] = additions
        return {"ok": True}

    monkeypatch.setattr(mural_module, "_merge_tags", fake_merge)
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *a, **kw: {"id": "w-1", "tags": []},
    )
    out = mural_module._repair_tag_drift("mural-1")
    assert out == [
        {"widget_id": "w-1", "repaired": True, "warning": "tag_drift_repaired"}
    ]
    assert captured["additions"] == ["tag-red"]


def test_repair_tag_drift_records_get_failures(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    mural_module._SessionManifest.clear()
    mural_module._SessionManifest[("mural-1", "w-1")] = {"red"}
    monkeypatch.setattr(
        mural_module,
        "_ensure_tag_manifest",
        lambda _mid, _entries: {"red": "tag-red"},
    )

    def fake_request(*a: Any, **kw: Any) -> Any:
        raise mural_module.MuralAPIError(
            status=500, code="ERR", message="boom", request_id="req"
        )

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    out = mural_module._repair_tag_drift("mural-1")
    assert len(out) == 1
    assert out[0]["repaired"] is False
    assert "boom" in out[0]["warning"]


def test_repair_tag_drift_records_merge_failures(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    mural_module._SessionManifest.clear()
    mural_module._SessionManifest[("mural-1", "w-1")] = {"red"}
    monkeypatch.setattr(
        mural_module,
        "_ensure_tag_manifest",
        lambda _mid, _entries: {"red": "tag-red"},
    )

    def fake_merge(*a: Any, **kw: Any) -> Any:
        raise mural_module.MuralTagMergeConflict(
            mural_id="mural-1",
            widget_id="w-1",
            intended=["tag-red"],
            observed=[],
            attempts=3,
        )

    monkeypatch.setattr(mural_module, "_merge_tags", fake_merge)
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *a, **kw: {"id": "w-1", "tags": []},
    )
    out = mural_module._repair_tag_drift("mural-1")
    assert out[0]["repaired"] is False
    assert "tag_merge_conflict" in out[0]["warning"]


# ---------------------------------------------------------------------------
# AABB rect helpers
# ---------------------------------------------------------------------------


def test_safe_rect_positive_dimensions(mural_module: Any) -> None:
    assert mural_module.safe_rect(0.0, 0.0, 10.0, 20.0) == {
        "x": 0.0,
        "y": 0.0,
        "w": 10.0,
        "h": 20.0,
    }


def test_safe_rect_negative_width_translates_origin(mural_module: Any) -> None:
    assert mural_module.safe_rect(0.0, 0.0, -10.0, 20.0) == {
        "x": -10.0,
        "y": 0.0,
        "w": 10.0,
        "h": 20.0,
    }


def test_safe_rect_negative_height_translates_origin(mural_module: Any) -> None:
    assert mural_module.safe_rect(5.0, 5.0, 4.0, -3.0) == {
        "x": 5.0,
        "y": 2.0,
        "w": 4.0,
        "h": 3.0,
    }


def test_safe_rect_both_negative_translates_both_axes(mural_module: Any) -> None:
    assert mural_module.safe_rect(0.0, 0.0, -10.0, -20.0) == {
        "x": -10.0,
        "y": -20.0,
        "w": 10.0,
        "h": 20.0,
    }


def test_safe_rect_zero_dimensions(mural_module: Any) -> None:
    assert mural_module.safe_rect(1.0, 2.0, 0.0, 0.0) == {
        "x": 1.0,
        "y": 2.0,
        "w": 0.0,
        "h": 0.0,
    }


def test_point_in_rect_interior_returns_true(mural_module: Any) -> None:
    rect = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.point_in_rect(5.0, 5.0, rect) is True


def test_point_in_rect_exact_boundary_returns_true(mural_module: Any) -> None:
    rect = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.point_in_rect(10.0, 10.0, rect) is True
    assert mural_module.point_in_rect(0.0, 0.0, rect) is True


def test_point_in_rect_within_eps_outside_returns_true(mural_module: Any) -> None:
    rect = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.point_in_rect(10.0 + 1e-7, 5.0, rect) is True


def test_point_in_rect_far_outside_returns_false(mural_module: Any) -> None:
    rect = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.point_in_rect(10.0 + 1e-3, 5.0, rect) is False


def test_point_in_rect_custom_eps(mural_module: Any) -> None:
    rect = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.point_in_rect(10.5, 5.0, rect, eps=1.0) is True
    assert mural_module.point_in_rect(11.5, 5.0, rect, eps=1.0) is False


def test_rects_overlap_disjoint_returns_false(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 5.0, "h": 5.0}
    b = {"x": 10.0, "y": 10.0, "w": 5.0, "h": 5.0}
    assert mural_module.rects_overlap(a, b) is False


def test_rects_overlap_touching_edge_returns_true(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    b = {"x": 10.0, "y": 0.0, "w": 5.0, "h": 5.0}
    assert mural_module.rects_overlap(a, b) is True


def test_rects_overlap_overlapping_returns_true(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    b = {"x": 5.0, "y": 5.0, "w": 10.0, "h": 10.0}
    assert mural_module.rects_overlap(a, b) is True


def test_rects_overlap_one_contains_other_returns_true(mural_module: Any) -> None:
    outer = {"x": 0.0, "y": 0.0, "w": 100.0, "h": 100.0}
    inner = {"x": 10.0, "y": 10.0, "w": 5.0, "h": 5.0}
    assert mural_module.rects_overlap(outer, inner) is True


def test_rect_intersection_disjoint_returns_none(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 5.0, "h": 5.0}
    b = {"x": 10.0, "y": 10.0, "w": 5.0, "h": 5.0}
    assert mural_module.rect_intersection(a, b) is None


def test_rect_intersection_overlapping_returns_overlap(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    b = {"x": 5.0, "y": 5.0, "w": 10.0, "h": 10.0}
    assert mural_module.rect_intersection(a, b) == {
        "x": 5.0,
        "y": 5.0,
        "w": 5.0,
        "h": 5.0,
    }


def test_rect_intersection_touching_returns_zero_area_rect(mural_module: Any) -> None:
    a = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    b = {"x": 10.0, "y": 0.0, "w": 5.0, "h": 5.0}
    assert mural_module.rect_intersection(a, b) == {
        "x": 10.0,
        "y": 0.0,
        "w": 0.0,
        "h": 5.0,
    }


def test_rect_contains_rect_inner_inside_returns_true(mural_module: Any) -> None:
    outer = {"x": 0.0, "y": 0.0, "w": 100.0, "h": 100.0}
    inner = {"x": 10.0, "y": 10.0, "w": 5.0, "h": 5.0}
    assert mural_module.rect_contains_rect(outer, inner) is True


def test_rect_contains_rect_partial_overlap_returns_false(
    mural_module: Any,
) -> None:
    outer = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    inner = {"x": 5.0, "y": 5.0, "w": 10.0, "h": 10.0}
    assert mural_module.rect_contains_rect(outer, inner) is False


def test_rect_contains_rect_identical_returns_true(mural_module: Any) -> None:
    outer = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    inner = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    assert mural_module.rect_contains_rect(outer, inner) is True


def test_rect_contains_rect_disjoint_returns_false(mural_module: Any) -> None:
    outer = {"x": 0.0, "y": 0.0, "w": 5.0, "h": 5.0}
    inner = {"x": 10.0, "y": 10.0, "w": 5.0, "h": 5.0}
    assert mural_module.rect_contains_rect(outer, inner) is False


def test_shape_to_rect_axis_aligned_widget(mural_module: Any) -> None:
    widget = {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0, "rotation": 0.0}
    assert mural_module._shape_to_rect(widget) == {
        "x": 0.0,
        "y": 0.0,
        "w": 10.0,
        "h": 10.0,
    }


def test_shape_to_rect_negative_dimensions_normalize(mural_module: Any) -> None:
    widget = {"x": 5.0, "y": 5.0, "width": -10.0, "height": -10.0}
    assert mural_module._shape_to_rect(widget) == {
        "x": -5.0,
        "y": -5.0,
        "w": 10.0,
        "h": 10.0,
    }


def test_shape_to_rect_missing_fields_default_to_zero(mural_module: Any) -> None:
    assert mural_module._shape_to_rect({}) == {
        "x": 0.0,
        "y": 0.0,
        "w": 0.0,
        "h": 0.0,
    }


def test_shape_to_rect_rotation_ignored_when_flag_off(mural_module: Any) -> None:
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
        "rotation": 45.0,
    }
    assert mural_module._shape_to_rect(widget, rotation_aware=False) == {
        "x": 0.0,
        "y": 0.0,
        "w": 10.0,
        "h": 10.0,
    }


def test_shape_to_rect_rotation_ninety_swaps_axes(mural_module: Any) -> None:
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 20.0,
        "rotation": 90.0,
    }
    out = mural_module._shape_to_rect(widget, rotation_aware=True)
    # 90-degree rotation about the rect center swaps width/height while the
    # AABB stays centered on (5, 10).
    assert out["x"] == pytest.approx(-5.0)
    assert out["y"] == pytest.approx(5.0)
    assert out["w"] == pytest.approx(20.0)
    assert out["h"] == pytest.approx(10.0)


def test_shape_to_rect_rotation_forty_five_expands_aabb(mural_module: Any) -> None:
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
        "rotation": 45.0,
    }
    out = mural_module._shape_to_rect(widget, rotation_aware=True)
    expected_side = 10.0 * math.sqrt(2.0)
    expected_origin = 5.0 - expected_side / 2.0
    assert out["x"] == pytest.approx(expected_origin)
    assert out["y"] == pytest.approx(expected_origin)
    assert out["w"] == pytest.approx(expected_side)
    assert out["h"] == pytest.approx(expected_side)


def test_shape_to_rect_env_flag_default_off(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("MURAL_SPATIAL_ROTATION_ENABLED", raising=False)
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
        "rotation": 45.0,
    }
    assert mural_module._shape_to_rect(widget) == {
        "x": 0.0,
        "y": 0.0,
        "w": 10.0,
        "h": 10.0,
    }


def test_shape_to_rect_env_flag_default_on(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_SPATIAL_ROTATION_ENABLED", "1")
    reloaded = importlib.reload(mural_module)
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
        "rotation": 45.0,
    }
    out = reloaded._shape_to_rect(widget)
    expected_side = 10.0 * math.sqrt(2.0)
    assert out["w"] == pytest.approx(expected_side)
    assert out["h"] == pytest.approx(expected_side)


def test_shape_to_rect_kwarg_overrides_env_flag(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_SPATIAL_ROTATION_ENABLED", "1")
    reloaded = importlib.reload(mural_module)
    widget = {
        "x": 0.0,
        "y": 0.0,
        "width": 10.0,
        "height": 10.0,
        "rotation": 45.0,
    }
    # Explicit False kwarg must beat the truthy constant set at import time.
    assert reloaded._shape_to_rect(widget, rotation_aware=False) == {
        "x": 0.0,
        "y": 0.0,
        "w": 10.0,
        "h": 10.0,
    }


def test_rotation_enabled_constant_reads_env_at_import(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("MURAL_SPATIAL_ROTATION_ENABLED", raising=False)
    off = importlib.reload(mural_module)
    assert off._ROTATION_ENABLED is False
    monkeypatch.setenv("MURAL_SPATIAL_ROTATION_ENABLED", "1")
    on = importlib.reload(mural_module)
    assert on._ROTATION_ENABLED is True


def test_parentid_filter_enabled_constant_reads_env_at_import(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("MURAL_SPATIAL_PARENTID_FILTER", raising=False)
    off = importlib.reload(mural_module)
    assert off._PARENTID_FILTER_ENABLED is False
    monkeypatch.setenv("MURAL_SPATIAL_PARENTID_FILTER", "1")
    on = importlib.reload(mural_module)
    assert on._PARENTID_FILTER_ENABLED is True


# ---------------------------------------------------------------------------
# spatial query helpers
# ---------------------------------------------------------------------------


def test_widgets_in_region_empty_input_returns_empty(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 100.0, "h": 100.0}
    assert mural_module.widgets_in_region([], region) == []
    assert mural_module.widgets_in_region([], region, mode="bbox") == []


def test_widgets_in_region_center_mode_all_inside(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 100.0, "h": 100.0}
    widgets = [
        {"id": "b", "x": 10.0, "y": 10.0, "width": 4.0, "height": 4.0},
        {"id": "a", "x": 50.0, "y": 50.0, "width": 4.0, "height": 4.0},
        {"id": "c", "x": 80.0, "y": 80.0, "width": 4.0, "height": 4.0},
    ]
    result = mural_module.widgets_in_region(widgets, region, mode="center")
    assert [w["id"] for w in result] == ["a", "b", "c"]


def test_widgets_in_region_center_mode_none_inside(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    widgets = [
        {"id": "x", "x": 100.0, "y": 100.0, "width": 4.0, "height": 4.0},
        {"id": "y", "x": 200.0, "y": 0.0, "width": 4.0, "height": 4.0},
    ]
    assert mural_module.widgets_in_region(widgets, region) == []


def test_widgets_in_region_center_mode_excludes_partial_overlap(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    widgets = [
        {"id": "p", "x": 8.0, "y": 8.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.widgets_in_region(widgets, region, mode="center") == []


def test_widgets_in_region_bbox_mode_includes_partial_overlap(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    widgets = [
        {"id": "p", "x": 8.0, "y": 8.0, "width": 10.0, "height": 10.0},
        {"id": "q", "x": 100.0, "y": 100.0, "width": 4.0, "height": 4.0},
    ]
    result = mural_module.widgets_in_region(widgets, region, mode="bbox")
    assert [w["id"] for w in result] == ["p"]


def test_widgets_in_region_sorts_by_widget_id_for_determinism(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 100.0, "h": 100.0}
    widgets = [
        {"id": "zebra", "x": 10.0, "y": 10.0, "width": 2.0, "height": 2.0},
        {"id": "alpha", "x": 20.0, "y": 20.0, "width": 2.0, "height": 2.0},
        {"id": "mango", "x": 30.0, "y": 30.0, "width": 2.0, "height": 2.0},
    ]
    result = mural_module.widgets_in_region(widgets, region)
    assert [w["id"] for w in result] == ["alpha", "mango", "zebra"]


def test_widgets_in_region_unknown_mode_raises_value_error(
    mural_module: Any,
) -> None:
    region = {"x": 0.0, "y": 0.0, "w": 10.0, "h": 10.0}
    widgets = [
        {"id": "a", "x": 1.0, "y": 1.0, "width": 2.0, "height": 2.0},
    ]
    with pytest.raises(ValueError):
        mural_module.widgets_in_region(widgets, region, mode="diagonal")


def test_widgets_in_shape_frame_container(mural_module: Any) -> None:
    frame = {
        "id": "frame-1",
        "x": 0.0,
        "y": 0.0,
        "width": 200.0,
        "height": 200.0,
    }
    widgets = [
        {"id": "in-1", "x": 10.0, "y": 10.0, "width": 4.0, "height": 4.0},
        {"id": "in-2", "x": 150.0, "y": 150.0, "width": 4.0, "height": 4.0},
        {"id": "out-1", "x": 500.0, "y": 500.0, "width": 4.0, "height": 4.0},
    ]
    result = mural_module.widgets_in_shape(widgets, frame)
    assert [w["id"] for w in result] == ["in-1", "in-2"]


def test_widgets_in_shape_area_container_bbox_mode(
    mural_module: Any,
) -> None:
    area = {
        "id": "area-1",
        "x": 0.0,
        "y": 0.0,
        "width": 50.0,
        "height": 50.0,
    }
    widgets = [
        {"id": "edge", "x": 45.0, "y": 45.0, "width": 20.0, "height": 20.0},
        {"id": "far", "x": 200.0, "y": 200.0, "width": 4.0, "height": 4.0},
    ]
    result = mural_module.widgets_in_shape(widgets, area, mode="bbox")
    assert [w["id"] for w in result] == ["edge"]


def test_widgets_in_shape_rotation_aware_expands_container(
    mural_module: Any,
) -> None:
    rotated_frame = {
        "id": "rot-frame",
        "x": 0.0,
        "y": 0.0,
        "width": 100.0,
        "height": 100.0,
        "rotation": 45.0,
    }
    diag_extent = 100.0 * math.sqrt(2.0) / 2.0
    far_corner_x = 50.0 + diag_extent - 5.0
    widgets = [
        {
            "id": "corner",
            "x": far_corner_x,
            "y": 50.0,
            "width": 2.0,
            "height": 2.0,
        },
    ]
    inactive = mural_module.widgets_in_shape(
        widgets, rotated_frame, rotation_aware=False
    )
    assert inactive == []
    active = mural_module.widgets_in_shape(widgets, rotated_frame, rotation_aware=True)
    assert [w["id"] for w in active] == ["corner"]


# ---------------------------------------------------------------------------
# pairwise_overlaps (STRtree)
# ---------------------------------------------------------------------------


def test_pairwise_overlaps_empty_input_returns_empty(mural_module: Any) -> None:
    assert mural_module.pairwise_overlaps([]) == []


def test_pairwise_overlaps_unknown_predicate_raises_value_error(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    with pytest.raises(ValueError):
        mural_module.pairwise_overlaps(widgets, predicate="touches")


def test_pairwise_overlaps_no_overlaps_returns_empty(mural_module: Any) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 100.0, "y": 100.0, "width": 10.0, "height": 10.0},
        {"id": "c", "x": 200.0, "y": 200.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.pairwise_overlaps(widgets) == []


def test_pairwise_overlaps_all_overlap_returns_full_pair_set(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 100.0, "height": 100.0},
        {"id": "b", "x": 10.0, "y": 10.0, "width": 100.0, "height": 100.0},
        {"id": "c", "x": 20.0, "y": 20.0, "width": 100.0, "height": 100.0},
    ]
    assert mural_module.pairwise_overlaps(widgets) == [
        ("a", "b"),
        ("a", "c"),
        ("b", "c"),
    ]


def test_pairwise_overlaps_partial_overlap_dedupes_symmetric_pairs(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "z", "x": 0.0, "y": 0.0, "width": 50.0, "height": 50.0},
        {"id": "a", "x": 25.0, "y": 25.0, "width": 50.0, "height": 50.0},
        {"id": "m", "x": 200.0, "y": 200.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.pairwise_overlaps(widgets) == [("a", "z")]


def test_pairwise_overlaps_predicate_contains_filters_strict_containment(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "outer", "x": 0.0, "y": 0.0, "width": 100.0, "height": 100.0},
        {"id": "inner", "x": 10.0, "y": 10.0, "width": 20.0, "height": 20.0},
        {"id": "edge", "x": 90.0, "y": 90.0, "width": 50.0, "height": 50.0},
    ]
    intersects = mural_module.pairwise_overlaps(widgets, predicate="intersects")
    assert intersects == [("edge", "outer"), ("inner", "outer")]
    contains = mural_module.pairwise_overlaps(widgets, predicate="contains")
    assert contains == [("inner", "outer")]


def test_pairwise_overlaps_rotation_aware_off_misses_rotated_overlap(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    rotated = {
        "id": "rot",
        "x": 0.0,
        "y": 0.0,
        "width": 100.0,
        "height": 100.0,
        "rotation": 45.0,
    }
    diag_extent = 100.0 * math.sqrt(2.0) / 2.0
    corner_x = 50.0 + diag_extent - 5.0
    widgets = [
        rotated,
        {"id": "corner", "x": corner_x, "y": 50.0, "width": 2.0, "height": 2.0},
    ]
    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", False)
    assert mural_module.pairwise_overlaps(widgets, rotation_aware=False) == []


def test_pairwise_overlaps_rotation_aware_on_detects_rotated_overlap(
    mural_module: Any,
) -> None:
    rotated = {
        "id": "rot",
        "x": 0.0,
        "y": 0.0,
        "width": 100.0,
        "height": 100.0,
        "rotation": 45.0,
    }
    diag_extent = 100.0 * math.sqrt(2.0) / 2.0
    corner_x = 50.0 + diag_extent - 5.0
    widgets = [
        rotated,
        {"id": "corner", "x": corner_x, "y": 50.0, "width": 2.0, "height": 2.0},
    ]
    assert mural_module.pairwise_overlaps(widgets, rotation_aware=True) == [
        ("corner", "rot"),
    ]


def test_pairwise_overlaps_env_flag_default_governs_rotation(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    rotated = {
        "id": "rot",
        "x": 0.0,
        "y": 0.0,
        "width": 100.0,
        "height": 100.0,
        "rotation": 45.0,
    }
    diag_extent = 100.0 * math.sqrt(2.0) / 2.0
    corner_x = 50.0 + diag_extent - 5.0
    widgets = [
        rotated,
        {"id": "corner", "x": corner_x, "y": 50.0, "width": 2.0, "height": 2.0},
    ]
    monkeypatch.setattr(mural_module, "_ROTATION_ENABLED", True)
    assert mural_module.pairwise_overlaps(widgets) == [("corner", "rot")]


def test_pairwise_overlaps_output_is_lex_sorted(mural_module: Any) -> None:
    widgets = [
        {"id": "zebra", "x": 0.0, "y": 0.0, "width": 100.0, "height": 100.0},
        {"id": "alpha", "x": 10.0, "y": 10.0, "width": 100.0, "height": 100.0},
        {"id": "mango", "x": 20.0, "y": 20.0, "width": 100.0, "height": 100.0},
    ]
    result = mural_module.pairwise_overlaps(widgets)
    assert result == sorted(result)


# ---------------------------------------------------------------------------
# cluster_widgets (DBSCAN)
# ---------------------------------------------------------------------------


def test_cluster_widgets_empty_input_returns_empty(mural_module: Any) -> None:
    assert mural_module.cluster_widgets([]) == []


def test_cluster_widgets_invalid_eps_raises_value_error(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    with pytest.raises(ValueError):
        mural_module.cluster_widgets(widgets, eps_px=0.0)


def test_cluster_widgets_invalid_min_samples_raises_value_error(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    with pytest.raises(ValueError):
        mural_module.cluster_widgets(widgets, min_samples=0)


def test_cluster_widgets_single_point_with_default_min_samples_returns_empty(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.cluster_widgets(widgets) == []


def test_cluster_widgets_all_noise_returns_empty(mural_module: Any) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 1000.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "c", "x": 0.0, "y": 1000.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.cluster_widgets(widgets, eps_px=50.0) == []


def test_cluster_widgets_one_tight_cluster_returns_single_group(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 20.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "c", "x": 40.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.cluster_widgets(widgets, eps_px=50.0) == [
        ["a", "b", "c"],
    ]


def test_cluster_widgets_two_well_separated_clusters_sorted_by_size(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a1", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "a2", "x": 20.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b1", "x": 1000.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b2", "x": 1020.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b3", "x": 1040.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.cluster_widgets(widgets, eps_px=50.0) == [
        ["b1", "b2", "b3"],
        ["a1", "a2"],
    ]


def test_cluster_widgets_eps_boundary_excludes_just_outside(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 60.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    # Centers at (5,5) and (65,5), distance 60. eps=59 → noise; eps=60 → cluster.
    assert mural_module.cluster_widgets(widgets, eps_px=59.0) == []
    assert mural_module.cluster_widgets(widgets, eps_px=60.0) == [["a", "b"]]


def test_cluster_widgets_min_samples_one_returns_singletons_for_isolated(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 1000.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "c", "x": 1020.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    assert mural_module.cluster_widgets(widgets, eps_px=50.0, min_samples=1) == [
        ["b", "c"],
        ["a"],
    ]


def test_sort_along_axis_empty_input_returns_empty(mural_module: Any) -> None:
    assert mural_module.sort_along_axis([]) == []


def test_sort_along_axis_invalid_axis_raises_value_error(
    mural_module: Any,
) -> None:
    with pytest.raises(ValueError, match="axis must be one of"):
        mural_module.sort_along_axis(
            [{"id": "a", "x": 0.0, "y": 0.0, "width": 1.0, "height": 1.0}],
            axis="z",
        )


def test_sort_along_axis_default_x_axis_orders_by_center_x(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "c", "x": 40.0, "y": 5.0, "width": 10.0, "height": 10.0},
        {"id": "a", "x": 0.0, "y": 100.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 20.0, "y": -50.0, "width": 10.0, "height": 10.0},
    ]
    ordered = mural_module.sort_along_axis(widgets)
    assert [w["id"] for w in ordered] == ["a", "b", "c"]


def test_sort_along_axis_y_axis_orders_by_center_y(mural_module: Any) -> None:
    widgets = [
        {"id": "c", "x": 999.0, "y": 40.0, "width": 10.0, "height": 10.0},
        {"id": "a", "x": -100.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 50.0, "y": 20.0, "width": 10.0, "height": 10.0},
    ]
    ordered = mural_module.sort_along_axis(widgets, axis="y")
    assert [w["id"] for w in ordered] == ["a", "b", "c"]


def test_sort_along_axis_diagonal_projects_onto_unit_diagonal(
    mural_module: Any,
) -> None:
    # Centers: a=(5,5) proj=10/sqrt2; b=(105,5) proj=110/sqrt2;
    # c=(5,105) proj=110/sqrt2 (tie with b).
    # Tie broken by id → b before c.
    widgets = [
        {"id": "c", "x": 0.0, "y": 100.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 100.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    ordered = mural_module.sort_along_axis(widgets, axis="diagonal")
    assert [w["id"] for w in ordered] == ["a", "b", "c"]


def test_sort_along_axis_origin_signed_projection_reverses_when_origin_past_center(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "b", "x": 20.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "c", "x": 40.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    near_origin = mural_module.sort_along_axis(widgets, origin=(0.0, 0.0))
    assert [w["id"] for w in near_origin] == ["a", "b", "c"]
    far_origin = mural_module.sort_along_axis(widgets, origin=(1000.0, 0.0))
    # All centers - 1000 are negative; smallest (most negative) is c at 45-1000.
    assert [w["id"] for w in far_origin] == ["c", "b", "a"]


def test_sort_along_axis_ties_broken_by_widget_id_for_determinism(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "z", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "a", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
        {"id": "m", "x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
    ]
    ordered = mural_module.sort_along_axis(widgets)
    assert [w["id"] for w in ordered] == ["a", "m", "z"]


def test_shoelace_area_unit_square_equals_one(mural_module: Any) -> None:
    square = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    assert mural_module.shoelace_area(square) == pytest.approx(1.0)


def test_shoelace_area_triangle(mural_module: Any) -> None:
    triangle = [(0.0, 0.0), (4.0, 0.0), (0.0, 3.0)]
    assert mural_module.shoelace_area(triangle) == pytest.approx(6.0)


def test_shoelace_area_concave_polygon(mural_module: Any) -> None:
    concave = [
        (0.0, 0.0),
        (4.0, 0.0),
        (4.0, 4.0),
        (2.0, 2.0),
        (0.0, 4.0),
    ]
    assert mural_module.shoelace_area(concave) == pytest.approx(12.0)


def test_shoelace_area_winding_invariant(mural_module: Any) -> None:
    cw = [(0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0)]
    ccw = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    assert mural_module.shoelace_area(cw) == pytest.approx(
        mural_module.shoelace_area(ccw)
    )


def test_shoelace_area_too_few_vertices_returns_zero(
    mural_module: Any,
) -> None:
    assert mural_module.shoelace_area([]) == 0.0
    assert mural_module.shoelace_area([(0.0, 0.0)]) == 0.0
    assert mural_module.shoelace_area([(0.0, 0.0), (1.0, 1.0)]) == 0.0


def test_ray_cast_pip_interior_returns_true(mural_module: Any) -> None:
    square = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]
    assert mural_module.ray_cast_pip((5.0, 5.0), square) is True


def test_ray_cast_pip_far_outside_returns_false(
    mural_module: Any,
) -> None:
    square = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]
    assert mural_module.ray_cast_pip((100.0, 100.0), square) is False
    assert mural_module.ray_cast_pip((-5.0, 5.0), square) is False


def test_ray_cast_pip_concave_polygon_notch(mural_module: Any) -> None:
    arrow = [
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (5.0, 5.0),
        (0.0, 10.0),
    ]
    assert mural_module.ray_cast_pip((5.0, 8.0), arrow) is False
    assert mural_module.ray_cast_pip((5.0, 2.0), arrow) is True


def test_ray_cast_pip_too_few_vertices_returns_false(
    mural_module: Any,
) -> None:
    assert mural_module.ray_cast_pip((0.0, 0.0), []) is False
    assert mural_module.ray_cast_pip((0.0, 0.0), [(0.0, 0.0)]) is False
    assert mural_module.ray_cast_pip((0.0, 0.0), [(0.0, 0.0), (1.0, 1.0)]) is False


# ---------------------------------------------------------------------------
# build_arrow_graph / arrow_graph_summary
# ---------------------------------------------------------------------------


def _w(
    wid: str, x: float, y: float, *, w: float = 10.0, h: float = 10.0
) -> dict[str, Any]:
    return {"id": wid, "type": "shape", "x": x, "y": y, "width": w, "height": h}


def _a(aid: str, x1: float, y1: float, x2: float, y2: float) -> dict[str, Any]:
    return {"id": aid, "type": "arrow", "x1": x1, "y1": y1, "x2": x2, "y2": y2}


def test_build_arrow_graph_zero_arrows_creates_nodes_only(
    mural_module: Any,
) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    graph = mural_module.build_arrow_graph(widgets, [])
    assert sorted(graph.nodes()) == ["a", "b"]
    assert graph.number_of_edges() == 0


def test_build_arrow_graph_single_arrow_creates_edge(
    mural_module: Any,
) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    arrows = [_a("e1", 5.0, 5.0, 105.0, 5.0)]
    graph = mural_module.build_arrow_graph(widgets, arrows, snap_radius=24.0)
    edges = list(graph.edges(keys=True, data=True))
    assert len(edges) == 1
    src, dst, key, data = edges[0][0], edges[0][1], edges[0][2], edges[0][3]
    assert (src, dst, key) == ("a", "b", "e1")
    assert data["arrow_widget"]["id"] == "e1"


def test_build_arrow_graph_multi_edge_same_pair_preserved(
    mural_module: Any,
) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    arrows = [
        _a("e1", 5.0, 5.0, 105.0, 5.0),
        _a("e2", 5.0, 5.0, 105.0, 5.0),
    ]
    graph = mural_module.build_arrow_graph(widgets, arrows)
    keys = sorted(k for _, _, k in graph.edges(keys=True))
    assert keys == ["e1", "e2"]


def test_build_arrow_graph_one_end_unanchored_skipped(
    mural_module: Any, caplog: pytest.LogCaptureFixture
) -> None:
    widgets = [_w("a", 0.0, 0.0)]
    arrows = [_a("e1", 5.0, 5.0, 10000.0, 10000.0)]
    with caplog.at_level("WARNING", logger="mural"):
        graph = mural_module.build_arrow_graph(widgets, arrows, snap_radius=24.0)
    assert graph.number_of_edges() == 0
    assert any("e1" in r.getMessage() for r in caplog.records)


def test_build_arrow_graph_both_ends_unanchored_skipped(
    mural_module: Any,
) -> None:
    widgets = [_w("a", 0.0, 0.0)]
    arrows = [_a("e1", 9000.0, 9000.0, 10000.0, 10000.0)]
    graph = mural_module.build_arrow_graph(widgets, arrows, snap_radius=24.0)
    assert graph.number_of_edges() == 0


def test_build_arrow_graph_snap_radius_inclusive_at_boundary(
    mural_module: Any,
) -> None:
    # Center of widget "a" is (5,5); arrow start at (5,29) → distance 24.0.
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    arrows = [_a("e1", 5.0, 29.0, 105.0, 5.0)]
    graph = mural_module.build_arrow_graph(widgets, arrows, snap_radius=24.0)
    assert graph.number_of_edges() == 1


def test_arrow_graph_summary_empty_graph(mural_module: Any) -> None:
    graph = mural_module.build_arrow_graph([], [])
    summary = mural_module.arrow_graph_summary(graph)
    assert summary == {
        "nodes": [],
        "edges": [],
        "stats": {"node_count": 0, "edge_count": 0, "is_dag": True},
    }


def test_arrow_graph_summary_single_edge_shape(mural_module: Any) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    graph = mural_module.build_arrow_graph(widgets, [_a("e1", 5.0, 5.0, 105.0, 5.0)])
    summary = mural_module.arrow_graph_summary(graph)
    assert summary["nodes"] == ["a", "b"]
    assert summary["edges"] == [{"id": "e1", "source": "a", "target": "b"}]
    assert summary["stats"]["edge_count"] == 1
    assert summary["stats"]["is_dag"] is True


def test_arrow_graph_summary_cycle_is_not_dag(mural_module: Any) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    arrows = [
        _a("e1", 5.0, 5.0, 105.0, 5.0),
        _a("e2", 105.0, 5.0, 5.0, 5.0),
    ]
    graph = mural_module.build_arrow_graph(widgets, arrows)
    summary = mural_module.arrow_graph_summary(graph)
    assert summary["stats"]["is_dag"] is False


def test_arrow_graph_summary_dag(mural_module: Any) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0), _w("c", 200.0, 0.0)]
    arrows = [
        _a("e1", 5.0, 5.0, 105.0, 5.0),
        _a("e2", 105.0, 5.0, 205.0, 5.0),
    ]
    graph = mural_module.build_arrow_graph(widgets, arrows)
    summary = mural_module.arrow_graph_summary(graph)
    assert summary["stats"]["is_dag"] is True


def test_arrow_graph_summary_round_trips_json(mural_module: Any) -> None:
    widgets = [_w("a", 0.0, 0.0), _w("b", 100.0, 0.0)]
    graph = mural_module.build_arrow_graph(widgets, [_a("e1", 5.0, 5.0, 105.0, 5.0)])
    summary = mural_module.arrow_graph_summary(graph)
    assert json.loads(json.dumps(summary)) == summary


# ---------------------------------------------------------------------------
# widget_center: canonical AABB-center contract for region/column membership
# (WI-20 prophylactic — see .copilot-tracking/plans/logs/2026-05-01/
# mural-live-integration-log.md)
# ---------------------------------------------------------------------------


def test_widget_center_returns_aabb_center(mural_module: Any) -> None:
    widget = {"id": "s", "x": 0.0, "y": 0.0, "width": 100.0, "height": 50.0}
    assert mural_module.widget_center(widget) == (50.0, 25.0)


def test_widget_center_sign_corrects_negative_dimensions(
    mural_module: Any,
) -> None:
    # _shape_to_rect normalizes negative width/height by mirroring origin,
    # so widget_center must report the geometric center of the corrected AABB.
    widget = {"id": "s", "x": 100.0, "y": 100.0, "width": -40.0, "height": -20.0}
    cx, cy = mural_module.widget_center(widget)
    assert cx == 80.0
    assert cy == 90.0


def test_widget_center_classifies_straddling_widget_into_majority_column(
    mural_module: Any,
) -> None:
    # WI-20 contract: a wide sticky whose left edge sits in column A but
    # whose mass sits in column B must be attributed to column B by any
    # caller that uses widgets_in_region in the default "center" mode.
    col_a = {"x": 0.0, "y": 0.0, "w": 60.0, "h": 200.0}
    col_b = {"x": 60.0, "y": 0.0, "w": 60.0, "h": 200.0}
    straddler = {
        "id": "wide",
        "x": 40.0,
        "y": 10.0,
        "width": 60.0,
        "height": 40.0,
    }
    cx, _cy = mural_module.widget_center(straddler)
    assert cx == 70.0
    assert mural_module.widgets_in_region([straddler], col_a, mode="center") == []
    assert mural_module.widgets_in_region([straddler], col_b, mode="center") == [
        straddler
    ]


# ---------------------------------------------------------------------------
# WI-16: read coalesce of htmlText -> text on widget-shaped records
# ---------------------------------------------------------------------------


def test_strip_html_removes_tags_and_trims(mural_module: Any) -> None:
    assert mural_module._strip_html("<p>Hello <b>world</b></p>") == "Hello world"
    assert mural_module._strip_html("  plain  ") == "plain"
    assert mural_module._strip_html("") == ""
    assert mural_module._strip_html(None) == ""
    assert mural_module._strip_html(42) == ""


def test_coalesce_widget_text_prefers_html_then_text(mural_module: Any) -> None:
    # Portal edit: text is empty, htmlText carries body.
    assert (
        mural_module._coalesce_widget_text({"text": "", "htmlText": "<p>Hi</p>"})
        == "Hi"
    )
    # API create: text is set, htmlText empty.
    assert (
        mural_module._coalesce_widget_text({"text": "raw body", "htmlText": ""})
        == "raw body"
    )
    # Both empty.
    assert mural_module._coalesce_widget_text({"text": "", "htmlText": ""}) == ""
    # Missing keys.
    assert mural_module._coalesce_widget_text({}) == ""


def test_apply_widget_text_coalesce_mutates_widget_records(
    mural_module: Any,
) -> None:
    widgets = [
        {"id": "a", "text": "", "htmlText": "<p>One</p>"},
        {"id": "b", "text": "Two", "htmlText": ""},
        {"id": "c", "text": "", "htmlText": "<p>Three</p><p>Four</p>"},
    ]
    mural_module._apply_widget_text_coalesce(widgets)
    assert [w["text"] for w in widgets] == ["One", "Two", "ThreeFour"]
    # htmlText preserved for round-trip callers.
    assert widgets[0]["htmlText"] == "<p>One</p>"


def test_apply_widget_text_coalesce_skips_non_widget_dicts(
    mural_module: Any,
) -> None:
    # Tags carry text but no htmlText; must remain untouched.
    tag = {"id": "t1", "text": "important"}
    mural_module._apply_widget_text_coalesce(tag)
    assert tag == {"id": "t1", "text": "important"}


def test_apply_widget_text_coalesce_walks_with_context_envelope(
    mural_module: Any,
) -> None:
    envelope = {
        "widget": {"id": "w", "text": "", "htmlText": "<p>Body</p>"},
        "area_chain": [{"id": "a", "title": "Area"}],
        "siblings": [
            {"id": "s1", "text": "", "htmlText": "<b>Sib</b>"},
            {"id": "s2", "text": "ok", "htmlText": ""},
        ],
        "cluster": None,
    }
    mural_module._apply_widget_text_coalesce(envelope)
    assert envelope["widget"]["text"] == "Body"
    assert envelope["siblings"][0]["text"] == "Sib"
    assert envelope["siblings"][1]["text"] == "ok"
    # area chain entries lack htmlText and stay unchanged.
    assert envelope["area_chain"][0] == {"id": "a", "title": "Area"}


# ---------------------------------------------------------------------------
# bulk-create per-type dispatch
# ---------------------------------------------------------------------------


def test_bulk_create_widgets_batch_success_full(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[dict[str, Any]] = []
    counter = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        counter["n"] += 1
        calls.append({"method": method, "path": path, **kwargs})
        return {"id": f"w{counter['n']}"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = mural_module._bulk_create_widgets(
        "ws.mural-abc",
        [{"type": "sticky-note", "text": "a"}, {"type": "textbox", "text": "b"}],
    )
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", "/murals/ws.mural-abc/widgets/sticky-note"),
        ("POST", "/murals/ws.mural-abc/widgets/textbox"),
    ]
    for c in calls:
        assert "type" not in c["json_body"]
    assert result["succeeded"] == [{"id": "w1"}, {"id": "w2"}]
    assert result["failed"] == []
    assert result["skipped"] == []
    assert result["warnings"] == []


def test_bulk_create_widgets_per_type_partial_failure(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[dict[str, Any]] = []
    counter = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        counter["n"] += 1
        calls.append({"method": method, "path": path, **kwargs})
        if counter["n"] == 1:
            return {"id": "w-a"}
        raise mural_module.MuralAPIError(400, "BAD", "rejected")

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    items = [
        {"type": "sticky-note", "text": "a"},
        {"type": "sticky-note", "text": "b"},
    ]
    result = mural_module._bulk_create_widgets("ws.mural-abc", items)
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", "/murals/ws.mural-abc/widgets/sticky-note"),
        ("POST", "/murals/ws.mural-abc/widgets/sticky-note"),
    ]
    assert result["succeeded"] == [{"id": "w-a"}]
    assert len(result["failed"]) == 1
    assert result["failed"][0]["item"] == items[1]
    assert "rejected" in result["failed"][0]["error"]
    assert result["skipped"] == []


def test_bulk_create_widgets_all_skipped_returns_envelope(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_request(*args: Any, **kwargs: Any) -> Any:
        raise AssertionError("should not POST when all widgets are skipped")

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    monkeypatch.setattr(
        mural_module,
        "_existing_layout_hashes",
        lambda *a, **kw: {"abc"},
    )
    items = [
        {
            "type": "sticky-note",
            "text": "x",
            "areaId": "area-1",
            "tags": [f"{mural_module._LAYOUT_HASH_PREFIX}abc"],
        }
    ]
    result = mural_module._bulk_create_widgets("ws.mural-abc", items)
    assert result["succeeded"] == []
    assert result["failed"] == []
    assert len(result["skipped"]) == 1
    assert result["skipped"][0]["reason"] == "layout_hash_match"


def test_bulk_create_widgets_atomic_success(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[dict[str, Any]] = []
    counter = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        counter["n"] += 1
        calls.append({"method": method, "path": path, **kwargs})
        return {"id": f"w{counter['n']}"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = mural_module._bulk_create_widgets(
        "ws.mural-abc",
        [{"type": "sticky-note", "text": "a"}, {"type": "textbox", "text": "b"}],
        atomic=True,
    )
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", "/murals/ws.mural-abc/widgets/sticky-note"),
        ("POST", "/murals/ws.mural-abc/widgets/textbox"),
    ]
    assert result["succeeded"] == [{"id": "w1"}, {"id": "w2"}]
    assert result["failed"] == []
    assert result["warnings"] == []


def test_bulk_create_widgets_atomic_first_failure_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[dict[str, Any]] = []

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        raise mural_module.MuralAPIError(500, "BOOM", "boom")

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    items = [
        {"type": "sticky-note", "text": "a"},
        {"type": "sticky-note", "text": "b"},
    ]
    with pytest.raises(mural_module.MuralBulkAtomicAbort) as excinfo:
        mural_module._bulk_create_widgets("ws.mural-abc", items, atomic=True)
    assert len(calls) == 1
    summary = excinfo.value.summary
    assert summary["succeeded"] == []
    assert len(summary["failed"]) == 1
    assert summary["failed"][0]["item"] == items[0]
    assert "boom" in summary["failed"][0]["error"]
    assert summary["warnings"] == []


# ---------------------------------------------------------------------------
# WI-21 cursor pagination regression
# ---------------------------------------------------------------------------


def test_paginate_follows_next_cursor_across_pages(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    pages = [
        {"value": [{"id": "a"}, {"id": "b"}], "next": "tok1"},
        {"value": [{"id": "c"}, {"id": "d"}], "next": "tok2"},
        {"value": [{"id": "e"}], "next": None},
    ]
    calls: list[dict[str, Any]] = []

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        params = dict(kwargs.get("params") or {})
        calls.append({"method": method, "path": path, "params": params})
        return pages[len(calls) - 1]

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = list(mural_module._paginate("GET", "/murals/m/widgets", page_size=2))
    assert [r["id"] for r in result] == ["a", "b", "c", "d", "e"]
    assert len(calls) == 3
    assert calls[0]["params"] == {"limit": 2}
    assert calls[1]["params"]["next"] == "tok1"
    assert calls[2]["params"]["next"] == "tok2"


def test_paginate_max_pages_short_circuits(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    pages = [
        {"value": [{"id": "a"}], "next": "tok1"},
        {"value": [{"id": "b"}], "next": "tok2"},
        {"value": [{"id": "c"}], "next": "tok3"},
    ]
    call_count = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        idx = call_count["n"]
        call_count["n"] += 1
        return pages[idx]

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = list(mural_module._paginate("GET", "/murals/m/widgets", max_pages=2))
    assert [r["id"] for r in result] == ["a", "b"]
    assert call_count["n"] == 2


def test_paginate_max_pages_one_disables_cursor_following(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    call_count = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        call_count["n"] += 1
        return {"value": [{"id": "a"}, {"id": "b"}], "next": "tok1"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = list(mural_module._paginate("GET", "/murals/m/widgets", max_pages=1))
    assert [r["id"] for r in result] == ["a", "b"]
    assert call_count["n"] == 1


def test_paginate_limit_caps_total_records(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    pages = [
        {"value": [{"id": "a"}, {"id": "b"}, {"id": "c"}], "next": "tok1"},
        {"value": [{"id": "d"}, {"id": "e"}], "next": None},
    ]
    call_count = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        idx = call_count["n"]
        call_count["n"] += 1
        return pages[idx]

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = list(mural_module._paginate("GET", "/murals/m/widgets", limit=2))
    assert [r["id"] for r in result] == ["a", "b"]
    assert call_count["n"] == 1


def test_paginate_handles_bare_list_response(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        return [{"id": "a"}, {"id": "b"}]

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)
    result = list(mural_module._paginate("GET", "/murals/m/widgets"))
    assert [r["id"] for r in result] == ["a", "b"]


# WI-22 widget diff CLI command


def test_diff_widget_lists_detects_added_removed_changed(mural_module: Any) -> None:
    baseline = [
        {"id": "a", "type": "sticky-note", "text": "hello", "x": 0, "y": 0},
        {"id": "b", "type": "sticky-note", "text": "stay"},
    ]
    current = [
        {"id": "b", "type": "sticky-note", "text": "stay"},
        {"id": "c", "type": "sticky-note", "text": "new"},
    ]
    result = mural_module._diff_widget_lists(baseline, current)
    assert result["summary"] == {"added": 1, "removed": 1, "changed": 0}
    assert [w["id"] for w in result["added"]] == ["c"]
    assert [w["id"] for w in result["removed"]] == ["a"]
    assert result["changed"] == []


def test_diff_widget_lists_groups_field_categories(mural_module: Any) -> None:
    baseline = [
        {
            "id": "a",
            "type": "sticky-note",
            "x": 0,
            "y": 0,
            "width": 100,
            "text": "hello",
            "style": {"backgroundColor": "#fff"},
            "parentId": None,
            "tag": "old",
        }
    ]
    current = [
        {
            "id": "a",
            "type": "sticky-note",
            "x": 10,
            "y": 0,
            "width": 100,
            "text": "world",
            "style": {"backgroundColor": "#000"},
            "parentId": "p1",
            "tag": "new",
        }
    ]
    result = mural_module._diff_widget_lists(baseline, current)
    assert result["summary"]["changed"] == 1
    delta = result["changed"][0]["delta"]
    assert delta["geometry"] == {"x": [0, 10]}
    assert delta["content"] == {"text": ["hello", "world"]}
    assert delta["style"] == {
        "style": [{"backgroundColor": "#fff"}, {"backgroundColor": "#000"}]
    }
    assert delta["anchor"] == {"parentId": [None, "p1"]}
    assert delta["other"] == {"tag": ["old", "new"]}


def test_diff_widget_lists_canonicalizes_html_text(mural_module: Any) -> None:
    baseline = [{"id": "a", "type": "sticky-note", "text": "hello"}]
    current = [{"id": "a", "type": "sticky-note", "htmlText": "<p>hello</p>"}]
    result = mural_module._diff_widget_lists(baseline, current)
    assert result["summary"]["changed"] == 0


def test_diff_widget_lists_skips_ignored_metadata(mural_module: Any) -> None:
    baseline = [{"id": "a", "type": "sticky-note", "createdOn": 1, "updatedOn": 2}]
    current = [{"id": "a", "type": "sticky-note", "createdOn": 1, "updatedOn": 999}]
    result = mural_module._diff_widget_lists(baseline, current)
    assert result["summary"]["changed"] == 0


def test_cmd_widget_diff_invokes_paginate(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch, tmp_path: Any
) -> None:
    snapshot = [{"id": "a", "type": "sticky-note", "text": "hello"}]
    snapshot_file = tmp_path / "snap.json"
    snapshot_file.write_text(json.dumps(snapshot), encoding="utf-8")

    captured: dict[str, Any] = {}

    def fake_paginate(method: str, path: str, **kwargs: Any) -> Any:
        captured["method"] = method
        captured["path"] = path
        return iter([{"id": "a", "type": "sticky-note", "text": "world"}])

    emitted: dict[str, Any] = {}

    def fake_emit(record: Any, args: Any) -> int:
        emitted["record"] = record
        return 0

    monkeypatch.setattr(mural_module, "_paginate", fake_paginate)
    monkeypatch.setattr(mural_module, "_emit_record", fake_emit)

    args = argparse.Namespace(
        mural="workspace.mural-id",
        file=str(snapshot_file),
        output="json",
    )
    rc = mural_module._cmd_widget_diff(args)
    assert rc == 0
    assert captured["path"] == "/murals/workspace.mural-id/widgets"
    assert emitted["record"]["summary"]["changed"] == 1


# ---------------------------------------------------------------------------
# widget diff --apply
# ---------------------------------------------------------------------------


def test_apply_widget_diff_routes_create_update_delete(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    baseline = [
        {"id": "keep", "type": "sticky-note", "text": "snap", "x": 10},
        {"id": "missing-on-live", "type": "sticky-note", "text": "new"},
    ]
    diff = {
        "summary": {"added": 1, "removed": 1, "changed": 1},
        "added": [{"id": "extra-on-live", "type": "sticky-note"}],
        "removed": [{"id": "missing-on-live", "type": "sticky-note", "text": "new"}],
        "changed": [
            {
                "id": "keep",
                "type": "sticky-note",
                "delta": {
                    "content": {"text": ["snap", "drift"]},
                    "geometry": {"x": [10, 99]},
                },
            }
        ],
    }
    create_calls: list[Any] = []
    update_calls: list[Any] = []
    delete_calls: list[Any] = []

    def fake_create(mural_id: str, widgets: Any, *, atomic: bool = False) -> Any:
        create_calls.append((mural_id, widgets, atomic))
        return {
            "succeeded": list(widgets),
            "skipped": [],
            "failed": [],
            "warnings": [],
        }

    def fake_update(mural_id: str, updates: Any, *, atomic: bool = False) -> Any:
        update_calls.append((mural_id, updates, atomic))
        return {
            "succeeded": [{"widget_id": u["widget_id"]} for u in updates],
            "failed": [],
            "warnings": [],
        }

    def fake_request(method: str, path: str, **_: Any) -> Any:
        delete_calls.append((method, path))
        return {}

    monkeypatch.setattr(mural_module, "_bulk_create_widgets", fake_create)
    monkeypatch.setattr(mural_module, "_bulk_update_widgets", fake_update)
    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._apply_widget_diff("M.id", baseline, diff, atomic=False)

    assert create_calls == [("M.id", [{"type": "sticky-note", "text": "new"}], False)]
    assert update_calls == [
        (
            "M.id",
            [
                {
                    "widget_id": "keep",
                    "body": {"text": "snap", "x": 10},
                    "type": "sticky-note",
                }
            ],
            False,
        )
    ]
    assert delete_calls == [("DELETE", "/murals/M.id/widgets/extra-on-live")]
    assert result["create"]["succeeded"] == [{"type": "sticky-note", "text": "new"}]
    assert result["update"]["succeeded"] == [{"widget_id": "keep"}]
    assert result["delete"]["succeeded"] == ["extra-on-live"]


def test_apply_widget_diff_warns_when_baseline_cannot_unset(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    baseline = [{"id": "w", "type": "sticky-note"}]
    diff = {
        "summary": {"added": 0, "removed": 0, "changed": 1},
        "added": [],
        "removed": [],
        "changed": [
            {
                "id": "w",
                "type": "sticky-note",
                "delta": {
                    "content": {"text": [None, "live-text"]},
                },
            }
        ],
    }
    monkeypatch.setattr(
        mural_module,
        "_bulk_update_widgets",
        lambda *_a, **_kw: pytest.fail("update should not run with empty body"),
    )

    result = mural_module._apply_widget_diff("M.id", baseline, diff, atomic=False)

    assert result["update"]["succeeded"] == []
    assert any("cannot unset fields" in w for w in result["update"]["warnings"])


def test_apply_widget_diff_propagates_atomic_abort(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    baseline = [{"id": "x", "type": "sticky-note", "text": "v"}]
    diff = {
        "summary": {"added": 0, "removed": 1, "changed": 0},
        "added": [],
        "removed": [{"id": "x", "type": "sticky-note", "text": "v"}],
        "changed": [],
    }

    def fake_create(*_a: Any, **_kw: Any) -> Any:
        raise mural_module.MuralBulkAtomicAbort(
            {
                "succeeded": [],
                "skipped": [],
                "failed": [{"error": "boom"}],
                "warnings": [],
            }
        )

    monkeypatch.setattr(mural_module, "_bulk_create_widgets", fake_create)

    with pytest.raises(mural_module.MuralBulkAtomicAbort):
        mural_module._apply_widget_diff("M.id", baseline, diff, atomic=True)


def test_bulk_delete_widgets_aborts_under_atomic(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    seen: list[str] = []

    def fake_request(method: str, path: str, **_: Any) -> Any:
        seen.append(path)
        if path.endswith("/widgets/w2"):
            raise mural_module.MuralError("bad request")
        return {}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    with pytest.raises(mural_module.MuralBulkAtomicAbort):
        mural_module._bulk_delete_widgets("M.id", ["w1", "w2", "w3"], atomic=True)
    # w3 must not be attempted under --atomic abort
    assert seen == [
        "/murals/M.id/widgets/w1",
        "/murals/M.id/widgets/w2",
    ]


def test_bulk_delete_widgets_collects_failures_without_atomic(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_request(method: str, path: str, **_: Any) -> Any:
        if path.endswith("/widgets/bad"):
            raise mural_module.MuralError("nope")
        return {}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._bulk_delete_widgets(
        "M.id", ["good", "bad", "ok"], atomic=False
    )
    assert result["succeeded"] == ["good", "ok"]
    assert len(result["failed"]) == 1
    assert result["failed"][0]["widget_id"] == "bad"


def test_cmd_widget_diff_apply_invokes_apply_helper(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch, tmp_path: Any
) -> None:
    snapshot = [{"id": "a", "type": "sticky-note", "text": "snap"}]
    snapshot_file = tmp_path / "snap.json"
    snapshot_file.write_text(json.dumps(snapshot), encoding="utf-8")

    monkeypatch.setattr(
        mural_module,
        "_paginate",
        lambda *_a, **_kw: iter([{"id": "a", "type": "sticky-note", "text": "live"}]),
    )

    apply_calls: list[Any] = []

    def fake_apply(
        mural_id: str, baseline: Any, diff: Any, *, atomic: bool = False
    ) -> Any:
        apply_calls.append((mural_id, baseline, diff, atomic))
        return {
            "create": {"succeeded": [], "skipped": [], "failed": [], "warnings": []},
            "update": {"succeeded": [{"widget_id": "a"}], "failed": [], "warnings": []},
            "delete": {"succeeded": [], "failed": [], "warnings": []},
        }

    monkeypatch.setattr(mural_module, "_apply_widget_diff", fake_apply)

    emitted: dict[str, Any] = {}

    def fake_emit(record: Any, _args: Any) -> int:
        emitted["record"] = record
        return 0

    monkeypatch.setattr(mural_module, "_emit_record", fake_emit)

    args = argparse.Namespace(
        mural="workspace.mural-id",
        file=str(snapshot_file),
        apply=True,
        atomic=True,
        output="json",
    )
    rc = mural_module._cmd_widget_diff(args)

    assert rc == 0
    assert len(apply_calls) == 1
    assert apply_calls[0][3] is True
    assert emitted["record"]["applied"] is True
    assert "create" in emitted["record"]
    assert "update" in emitted["record"]
    assert "delete" in emitted["record"]
    assert emitted["record"]["summary"]["changed"] == 1


def test_cmd_widget_diff_without_apply_preserves_legacy_envelope(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch, tmp_path: Any
) -> None:
    snapshot = [{"id": "a", "type": "sticky-note", "text": "snap"}]
    snapshot_file = tmp_path / "snap.json"
    snapshot_file.write_text(json.dumps(snapshot), encoding="utf-8")

    monkeypatch.setattr(
        mural_module,
        "_paginate",
        lambda *_a, **_kw: iter([{"id": "a", "type": "sticky-note", "text": "snap"}]),
    )
    monkeypatch.setattr(
        mural_module,
        "_apply_widget_diff",
        lambda *_a, **_kw: pytest.fail("apply must not run without --apply"),
    )
    emitted: dict[str, Any] = {}

    def fake_emit_legacy(record: Any, _args: Any) -> int:
        emitted["record"] = record
        return 0

    monkeypatch.setattr(mural_module, "_emit_record", fake_emit_legacy)

    args = argparse.Namespace(
        mural="workspace.mural-id",
        file=str(snapshot_file),
        output="json",
    )
    rc = mural_module._cmd_widget_diff(args)
    assert rc == 0
    assert "applied" not in emitted["record"]
    assert "create" not in emitted["record"]
