# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for Mural skill helper logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import os
import sys
import tempfile
from contextlib import suppress

import mural
import pytest

# The Atheris/libFuzzer subprocess can run with ``HOME`` unset, which makes
# bare ``~`` expansion fall back to ``pathlib.Path.home()``. Provide a
# deterministic fallback so the home-directory branch is exercised instead of
# aborting the run. Note: ``~user`` forms (e.g. ``~unknownuser``) still raise
# ``RuntimeError`` from ``expanduser`` regardless of ``HOME``; targets that feed
# arbitrary paths to ``expanduser`` suppress that explicitly.
os.environ.setdefault("HOME", tempfile.gettempdir())

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


class _FakeTokenResponse:
    """Minimal HTTP response stand-in for ``_parse_token_response`` fuzzing."""

    def __init__(self, status: int, content_type: str, body: bytes) -> None:
        self.status = status
        self.headers = {"Content-Type": content_type}
        self._body = body

    def read(self, n: int = -1) -> bytes:
        if n is None or n < 0:
            data, self._body = self._body, b""
            return data
        chunk, self._body = self._body[:n], self._body[n:]
        return chunk


def fuzz_redact(data: bytes) -> None:
    """Fuzz the secret-redaction helper with arbitrary text."""
    provider = atheris.FuzzedDataProvider(data)
    text = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    mural._redact(text)


def fuzz_validate_mural_id(data: bytes) -> None:
    """Fuzz mural-id validation; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    candidate = provider.ConsumeUnicodeNoSurrogates(60)
    with suppress(mural.MuralValidationError):
        mural._validate_mural_id(candidate)


def fuzz_extract_field(data: bytes) -> None:
    """Fuzz nested field extraction across representative payload shapes."""
    provider = atheris.FuzzedDataProvider(data)
    payload = {
        "id": provider.ConsumeUnicodeNoSurrogates(20),
        "fields": {
            "title": provider.ConsumeUnicodeNoSurrogates(40),
            "labels": [provider.ConsumeUnicodeNoSurrogates(12) for _ in range(3)],
            "metadata": {"count": provider.ConsumeIntInRange(0, 50)},
        },
    }
    path_options = [
        "id",
        "fields.title",
        "fields.labels.0",
        "fields.metadata.count",
        provider.ConsumeUnicodeNoSurrogates(30),
    ]
    mural._extract_field(
        payload,
        path_options[provider.ConsumeIntInRange(0, len(path_options) - 1)],
    )


def fuzz_parse_pagination_cursor(data: bytes) -> None:
    """Fuzz opaque cursor decoding; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    token = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._parse_pagination_cursor(token)


def fuzz_validate_asset_url(data: bytes) -> None:
    """Fuzz the SSRF allowlist; only ``MuralSecurityError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    url = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralSecurityError):
        mural._validate_asset_url(url)


def fuzz_validate_redirect_uri(data: bytes) -> None:
    """Fuzz the OAuth loopback redirect URI validator.

    Only ``MuralSecurityError`` is expected.
    """
    provider = atheris.FuzzedDataProvider(data)
    uri = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralSecurityError):
        mural._validate_redirect_uri(uri)


def fuzz_parse_json_arg(data: bytes) -> None:
    """Fuzz JSON argument parsing; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    text = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._parse_json_arg(text, "--body")


def fuzz_verify_pkce(data: bytes) -> None:
    """Fuzz PKCE verification with arbitrary verifier/challenge pairs."""
    provider = atheris.FuzzedDataProvider(data)
    verifier = provider.ConsumeUnicodeNoSurrogates(64)
    challenge = provider.ConsumeUnicodeNoSurrogates(64)
    mural._verify_pkce(verifier, challenge)


def fuzz_extract_error_payload(data: bytes) -> None:
    """Fuzz Mural API error payload extraction with arbitrary body bytes and headers."""
    provider = atheris.FuzzedDataProvider(data)
    body_len = provider.ConsumeIntInRange(0, max(0, provider.remaining_bytes() - 1))
    body = provider.ConsumeBytes(body_len)
    header_choice = provider.ConsumeIntInRange(0, 3)
    headers_obj: object | None
    if header_choice == 0:
        headers_obj = None
    elif header_choice == 1:
        headers_obj = {}
    elif header_choice == 2:
        headers_obj = {"X-Request-Id": provider.ConsumeUnicodeNoSurrogates(32)}
    else:
        headers_obj = {"x-request-id": provider.ConsumeUnicodeNoSurrogates(32)}
    mural._extract_error_payload(body, headers_obj)


def fuzz_build_authorize_url(data: bytes) -> None:
    """Fuzz OAuth authorize URL builder; only ``MuralError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    client_id = provider.ConsumeUnicodeNoSurrogates(32)
    redirect_uri = provider.ConsumeUnicodeNoSurrogates(64)
    state = provider.ConsumeUnicodeNoSurrogates(32)
    code_challenge = provider.ConsumeUnicodeNoSurrogates(64)
    scopes = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralError):
        mural._build_authorize_url(
            client_id, redirect_uri, state, code_challenge, scopes
        )


def fuzz_loopback_callback_request(data: bytes) -> None:
    """Fuzz ``_LoopbackHandler`` request parsing with arbitrary raw HTTP bytes.

    Drives the handler via an in-memory ``socket.socketpair`` so the full
    request-line, header, path, and query-string parsing path runs against
    fuzzer-controlled bytes. Any exception inside the handler is suppressed
    because crash-free behavior on malformed input is the property under test.
    """
    import http.server
    import socket
    import threading

    # Cap input size so the in-process socket buffer never blocks.
    payload = data[:8192]
    if not payload:
        return

    class _FuzzServer(http.server.HTTPServer):
        """Minimal HTTPServer stand-in that records callback results."""

        # Skip socket setup; we plumb the request socket manually.
        def __init__(self) -> None:  # noqa: D401 - stub
            self.server_port = 8765
            self.server_address = ("127.0.0.1", 8765)
            self.callback_result = mural._CallbackResult()
            self.callback_received = threading.Event()

        def shutdown_request(self, request: object) -> None:  # noqa: D401 - stub
            with suppress(Exception):
                request.close()  # type: ignore[union-attr]

        def close_request(self, request: object) -> None:  # noqa: D401 - stub
            with suppress(Exception):
                request.close()  # type: ignore[union-attr]

    server_sock, client_sock = socket.socketpair()
    try:
        # Push fuzzer bytes into the handler's read side, then half-close
        # so the parser sees EOF rather than blocking.
        with suppress(OSError):
            server_sock.sendall(payload)
        with suppress(OSError):
            server_sock.shutdown(socket.SHUT_WR)
        with suppress(Exception):
            mural._LoopbackHandler(client_sock, ("127.0.0.1", 0), _FuzzServer())
    finally:
        with suppress(OSError):
            server_sock.close()
        with suppress(OSError):
            client_sock.close()


def fuzz_parse_token_response(data: bytes) -> None:
    """Fuzz the OAuth token endpoint response parser.

    Only ``MuralError`` (covering ``MuralAPIError`` and ``ResponseTooLarge``)
    is expected.
    """
    provider = atheris.FuzzedDataProvider(data)
    ct_choice = provider.ConsumeIntInRange(0, 4)
    if ct_choice == 0:
        content_type = "application/json"
    elif ct_choice == 1:
        content_type = "application/json; charset=utf-8"
    elif ct_choice == 2:
        content_type = "text/html"
    elif ct_choice == 3:
        content_type = ""
    else:
        content_type = provider.ConsumeUnicodeNoSurrogates(32)
    status = provider.ConsumeIntInRange(100, 599)
    body = provider.ConsumeBytes(provider.remaining_bytes())
    resp = _FakeTokenResponse(status, content_type, body)
    with suppress(mural.MuralError):
        mural._parse_token_response(resp)


def fuzz_unwrap_value_envelope(data: bytes) -> None:
    """Fuzz the single-GET envelope unwrap helper.

    The function never raises; this asserts crash-free behavior and the
    documented passthrough invariants across representative input shapes.
    """
    provider = atheris.FuzzedDataProvider(data)
    shape = provider.ConsumeIntInRange(0, 7)
    inner = provider.ConsumeUnicodeNoSurrogates(32)
    record: object
    if shape == 0:
        record = {"value": {"id": inner}}
    elif shape == 1:
        record = {"value": inner}
    elif shape == 2:
        record = {"value": [inner]}
    elif shape == 3:
        record = {"value": {"id": inner}, "next": inner}
    elif shape == 4:
        record = {"id": inner}
    elif shape == 5:
        record = [inner]
    elif shape == 6:
        record = inner
    else:
        record = None
    result = mural._unwrap_value_envelope(record)
    if (
        isinstance(record, dict)
        and list(record.keys()) == ["value"]
        and isinstance(record["value"], dict)
    ):
        assert result is record["value"]
    else:
        assert result is record


def fuzz_validate_hyperlink(data: bytes) -> None:
    """Fuzz the hyperlink validator; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    value = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._validate_hyperlink(value)


def fuzz_validate_tag_text(data: bytes) -> None:
    """Fuzz the tag text validator; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    value = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._validate_tag_text(value)


def fuzz_validate_area_layout(data: bytes) -> None:
    """Fuzz the area layout validator; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    choice = provider.ConsumeIntInRange(0, 4)
    if choice == 0:
        value: object = "free"
    elif choice == 1:
        value = "column"
    elif choice == 2:
        value = "row"
    elif choice == 3:
        value = ""
    else:
        value = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._validate_area_layout(value)


def fuzz_validate_profile_name(data: bytes) -> None:
    """Fuzz the profile-name validator; only ``MuralValidationError`` is expected."""
    provider = atheris.FuzzedDataProvider(data)
    candidate = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    with suppress(mural.MuralValidationError):
        mural._validate_profile_name(candidate)


def fuzz_validate_profile(data: bytes) -> None:
    """Fuzz the persisted-profile shape validator across representative dicts.

    ``_validate_profile`` raises bare :class:`mural.MuralError` on shape or
    type violations, so suppression is on the parent exception class.
    """
    provider = atheris.FuzzedDataProvider(data)
    shape = provider.ConsumeIntInRange(0, 6)
    valid_base: dict[str, object] = {
        "client_id": provider.ConsumeUnicodeNoSurrogates(32),
        "access_token": provider.ConsumeUnicodeNoSurrogates(64),
        "token_type": "Bearer",
        "obtained_at": provider.ConsumeIntInRange(0, 2_000_000_000),
        "expires_at": provider.ConsumeIntInRange(0, 2_000_000_000),
    }
    profile: object
    if shape == 0:
        profile = valid_base
    elif shape == 1:
        profile = {**valid_base, "expires_at": True}
    elif shape == 2:
        profile = {**valid_base, "expires_at": "0"}
    elif shape == 3:
        partial = dict(valid_base)
        partial.pop("client_id", None)
        profile = partial
    elif shape == 4:
        profile = {}
    elif shape == 5:
        profile = None
    else:
        profile = [valid_base]
    with suppress(mural.MuralError):
        mural._validate_profile(profile)


def fuzz_parse_rate_limit_headers(data: bytes) -> None:
    """Fuzz ``X-RateLimit-*`` parsing against an isolated bucket.

    The parser does not raise on malformed values; this asserts the dict
    contract and crash-free behavior. An isolated :class:`mural._TokenBucket`
    keeps the module-level limiter unaffected.
    """
    provider = atheris.FuzzedDataProvider(data)
    remaining_choice = provider.ConsumeIntInRange(0, 4)
    if remaining_choice == 0:
        remaining_value: object = provider.ConsumeUnicodeNoSurrogates(16)
    elif remaining_choice == 1:
        remaining_value = str(provider.ConsumeIntInRange(-100, 1000))
    elif remaining_choice == 2:
        remaining_value = "0"
    elif remaining_choice == 3:
        remaining_value = ""
    else:
        remaining_value = None
    reset_choice = provider.ConsumeIntInRange(0, 3)
    if reset_choice == 0:
        reset_value: object = provider.ConsumeUnicodeNoSurrogates(16)
    elif reset_choice == 1:
        reset_value = str(provider.ConsumeIntInRange(0, 1_000_000))
    elif reset_choice == 2:
        reset_value = ""
    else:
        reset_value = None
    headers: dict[str, object] = {}
    if remaining_value is not None:
        headers["X-RateLimit-Remaining"] = remaining_value
    if reset_value is not None:
        headers["X-RateLimit-Reset"] = reset_value
    bucket = mural._TokenBucket()
    result = mural._parse_rate_limit_headers(headers, bucket=bucket)
    assert isinstance(result, dict)
    assert set(result.keys()) == {"remaining", "reset"}


def fuzz_profile_from_credential_path(data: bytes) -> None:
    """Fuzz credential-path → profile-name parsing; never raises."""
    import pathlib as _pathlib

    provider = atheris.FuzzedDataProvider(data)
    name = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    # ``pathlib.Path`` rejects embedded NULs; strip so the parser is the focus.
    name = name.replace("\x00", "").replace("/", "")
    if not name:
        return
    path = _pathlib.Path("/tmp") / name
    result = mural._profile_from_credential_path(path)
    assert isinstance(result, str)


def fuzz_resolve_credential_file(data: bytes) -> None:
    """Fuzz credential-file path resolution from arbitrary environ + profile."""
    import pathlib as _pathlib

    provider = atheris.FuzzedDataProvider(data)
    profile = provider.ConsumeUnicodeNoSurrogates(32).replace("\x00", "")
    if not profile:
        profile = mural.DEFAULT_PROFILE_NAME
    explicit = provider.ConsumeUnicodeNoSurrogates(64).replace("\x00", "")
    xdg = provider.ConsumeUnicodeNoSurrogates(64).replace("\x00", "")
    appdata = provider.ConsumeUnicodeNoSurrogates(64).replace("\x00", "")
    environ: dict[str, str] = {}
    shape = provider.ConsumeIntInRange(0, 3)
    if shape == 0 and explicit:
        environ[mural.ENV_ENV_FILE] = explicit
    elif shape == 1 and xdg:
        environ[mural.ENV_XDG_CONFIG_HOME] = xdg
    elif shape == 2 and appdata:
        environ["APPDATA"] = appdata
    # ``expanduser`` raises RuntimeError for unresolvable ``~user`` forms in the
    # fuzzed MURAL_ENV_FILE value; that is a valid input outcome, not a defect.
    with suppress(ValueError, RuntimeError):
        result = mural._resolve_credential_file(profile, environ)
        assert isinstance(result, _pathlib.Path)


FUZZ_TARGETS = [
    fuzz_redact,
    fuzz_validate_mural_id,
    fuzz_extract_field,
    fuzz_parse_pagination_cursor,
    fuzz_validate_asset_url,
    fuzz_validate_redirect_uri,
    fuzz_parse_json_arg,
    fuzz_verify_pkce,
    fuzz_extract_error_payload,
    fuzz_build_authorize_url,
    fuzz_loopback_callback_request,
    fuzz_parse_token_response,
    fuzz_unwrap_value_envelope,
    fuzz_validate_hyperlink,
    fuzz_validate_tag_text,
    fuzz_validate_area_layout,
    fuzz_validate_profile_name,
    fuzz_validate_profile,
    fuzz_parse_rate_limit_headers,
    fuzz_profile_from_credential_path,
    fuzz_resolve_credential_file,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestMuralFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    @pytest.mark.parametrize(
        ("text", "should_change"),
        [
            ("plain log line with no secrets", False),
            ("Authorization: Bearer abc.def.ghi token=value", True),
            ("", False),
        ],
    )
    def test_redact_is_safe_for_arbitrary_text(
        self, text: str, should_change: bool
    ) -> None:
        result = mural._redact(text)
        assert isinstance(result, str)
        if should_change:
            assert result != text or text == ""

    @pytest.mark.parametrize(
        "candidate",
        ["workspace1.mural-abc123", "ws.mural-xyz"],
    )
    def test_validate_mural_id_accepts_valid_values(self, candidate: str) -> None:
        assert mural._validate_mural_id(candidate) == candidate

    @pytest.mark.parametrize(
        "candidate",
        ["", "../etc/passwd", "ws/mural", "ws\\mural", "ws.mural\x00", "no-dot"],
    )
    def test_validate_mural_id_rejects_invalid_values(self, candidate: str) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._validate_mural_id(candidate)

    def test_extract_field_handles_nested_values(self) -> None:
        payload = {
            "fields": {
                "title": "Sticky note",
                "labels": ["a", "b", "c"],
                "metadata": {"count": 3},
            }
        }
        assert mural._extract_field(payload, "fields.title") == "Sticky note"
        assert mural._extract_field(payload, "fields.labels.1") == "b"
        assert mural._extract_field(payload, "fields.metadata.count") == 3
        assert mural._extract_field(payload, "fields.missing") is None
        assert mural._extract_field(payload, "") == payload

    def test_parse_pagination_cursor_round_trip(self) -> None:
        import base64
        import json as _json

        token = (
            base64.urlsafe_b64encode(_json.dumps({"page": 2}).encode("utf-8"))
            .rstrip(b"=")
            .decode("ascii")
        )
        assert mural._parse_pagination_cursor(token) == {"page": 2}

    @pytest.mark.parametrize(
        "token",
        ["", "!!!not-base64!!!", "Zm9vYmFy"],
    )
    def test_parse_pagination_cursor_rejects_invalid(self, token: str) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._parse_pagination_cursor(token)

    @pytest.mark.parametrize(
        "url",
        [
            "",
            "http://account.blob.core.windows.net/upload",
            "https://example.com/upload",
            "https://user:pass@account.blob.core.windows.net/upload",
            "https://account.blob.core.windows.net/upload#frag",
            "https://10.0.0.1/upload",
        ],
    )
    def test_validate_asset_url_rejects_unsafe(self, url: str) -> None:
        with pytest.raises(mural.MuralSecurityError):
            mural._validate_asset_url(url)

    def test_validate_asset_url_accepts_azure_blob(self) -> None:
        mural._validate_asset_url(
            "https://account.blob.core.windows.net/c/asset?sig=xyz"
        )

    def test_parse_json_arg_round_trip(self) -> None:
        assert mural._parse_json_arg('{"x":1}', "--body") == {"x": 1}

    def test_parse_json_arg_rejects_invalid(self) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._parse_json_arg("not json", "--body")

    def test_verify_pkce_round_trip(self) -> None:
        verifier, challenge = mural._generate_pkce_pair()
        assert mural._verify_pkce(verifier, challenge) is True
        assert mural._verify_pkce(verifier, "wrong") is False

    def test_parse_token_response_round_trip(self) -> None:
        resp = _FakeTokenResponse(200, "application/json", b'{"access_token":"x"}')
        assert mural._parse_token_response(resp) == {"access_token": "x"}

    @pytest.mark.parametrize(
        ("content_type", "body"),
        [
            ("text/html", b"<html/>"),
            ("", b"{}"),
            ("application/json", b"not json"),
            ("application/json", b"[1,2,3]"),
            ("application/json", b"null"),
        ],
    )
    def test_parse_token_response_rejects_invalid(
        self, content_type: str, body: bytes
    ) -> None:
        resp = _FakeTokenResponse(200, content_type, body)
        with pytest.raises(mural.MuralAPIError):
            mural._parse_token_response(resp)

    def test_validate_hyperlink_accepts_short_string(self) -> None:
        assert mural._validate_hyperlink("https://example.com") == "https://example.com"

    @pytest.mark.parametrize(
        "value",
        [
            None,
            "",
            123,
            "x" * (mural._MAX_HYPERLINK_LEN + 1),
            "javascript:alert(1)",
            "data:text/html,x",
            "vbscript:msg",
            "file:///etc/passwd",
        ],
    )
    def test_validate_hyperlink_rejects_invalid(self, value: object) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._validate_hyperlink(value)

    def test_validate_tag_text_accepts_short_string(self) -> None:
        assert mural._validate_tag_text("todo") == "todo"

    @pytest.mark.parametrize(
        "value",
        [None, "", 7, "x" * (mural._MAX_TAG_TEXT_LEN + 1)],
    )
    def test_validate_tag_text_rejects_invalid(self, value: object) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._validate_tag_text(value)

    @pytest.mark.parametrize("value", ["free", "column", "row"])
    def test_validate_area_layout_accepts_valid(self, value: str) -> None:
        assert mural._validate_area_layout(value) == value

    @pytest.mark.parametrize("value", ["", "grid", "FREE", None, 1])
    def test_validate_area_layout_rejects_invalid(self, value: object) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._validate_area_layout(value)

    @pytest.mark.parametrize(
        "name",
        ["default", "prod", "user_1", "team.dev", "test-env", "_underscore"],
    )
    def test_validate_profile_name_accepts_valid(self, name: str) -> None:
        assert mural._validate_profile_name(name) == name

    @pytest.mark.parametrize(
        "name",
        [None, "", 7, "..", "../etc", "has space", ".leading-dot", "x" * 33],
    )
    def test_validate_profile_name_rejects_invalid(self, name: object) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._validate_profile_name(name)

    def test_validate_profile_accepts_minimal_valid(self) -> None:
        profile = {
            "client_id": "abc",
            "access_token": "tok",
            "token_type": "Bearer",
            "obtained_at": 0,
            "expires_at": 0,
        }
        assert mural._validate_profile(profile) is None

    @pytest.mark.parametrize(
        "profile",
        [
            None,
            [],
            "string",
            {},
            {
                "client_id": "c",
                "access_token": "t",
                "token_type": "B",
                "obtained_at": 0,
                "expires_at": True,
            },
            {
                "client_id": "c",
                "access_token": "t",
                "token_type": "B",
                "obtained_at": 0,
                "expires_at": "0",
            },
        ],
    )
    def test_validate_profile_rejects_invalid(self, profile: object) -> None:
        with pytest.raises(mural.MuralError):
            mural._validate_profile(profile)

    def test_parse_rate_limit_headers_parses_ints(self) -> None:
        bucket = mural._TokenBucket()
        headers = {"X-RateLimit-Remaining": "5", "X-RateLimit-Reset": "60"}
        assert mural._parse_rate_limit_headers(headers, bucket=bucket) == {
            "remaining": 5,
            "reset": 60,
        }

    def test_parse_rate_limit_headers_returns_none_for_missing(self) -> None:
        bucket = mural._TokenBucket()
        assert mural._parse_rate_limit_headers({}, bucket=bucket) == {
            "remaining": None,
            "reset": None,
        }

    def test_parse_rate_limit_headers_drains_bucket_on_exhaustion(self) -> None:
        bucket = mural._TokenBucket()
        bucket.tokens = 4.0
        headers = {"X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "30"}
        mural._parse_rate_limit_headers(headers, bucket=bucket)
        assert bucket.tokens == 0.0

    def test_profile_from_credential_path_extracts_profile(self) -> None:
        import pathlib as _pathlib

        assert (
            mural._profile_from_credential_path(_pathlib.Path("/tmp/mural.team_x.env"))
            == "team_x"
        )

    def test_profile_from_credential_path_falls_back_to_default(self) -> None:
        import pathlib as _pathlib

        assert (
            mural._profile_from_credential_path(_pathlib.Path("/tmp/random.txt"))
            == mural.DEFAULT_PROFILE_NAME
        )

    def test_resolve_credential_file_honors_explicit_env(self) -> None:
        path = mural._resolve_credential_file(
            "default", {mural.ENV_ENV_FILE: "/tmp/explicit.env"}
        )
        assert str(path) == "/tmp/explicit.env"

    def test_resolve_credential_file_uses_xdg_when_set(self) -> None:
        path = mural._resolve_credential_file(
            "team_a", {mural.ENV_XDG_CONFIG_HOME: "/tmp/xdg"}
        )
        assert str(path) == "/tmp/xdg/hve-core/mural.team_a.env"


_CORPUS_ROOT = __import__("pathlib").Path(__file__).parent / "corpus"


def _collect_corpus_seeds() -> list[tuple[str, str]]:
    if not _CORPUS_ROOT.is_dir():
        return []
    seeds: list[tuple[str, str]] = []
    for target in FUZZ_TARGETS:
        target_dir = _CORPUS_ROOT / target.__name__
        if not target_dir.is_dir():
            continue
        for seed_path in sorted(target_dir.iterdir()):
            if seed_path.is_file() and seed_path.suffix == ".bin":
                seeds.append((target.__name__, str(seed_path)))
    return seeds


_CORPUS_SEEDS = _collect_corpus_seeds()


@pytest.mark.skipif(not _CORPUS_SEEDS, reason="No corpus seeds present")
@pytest.mark.parametrize(("target_name", "seed_path"), _CORPUS_SEEDS)
def test_corpus_seed_does_not_crash(target_name: str, seed_path: str) -> None:
    """Replay each seed file through its fuzz target without unhandled errors."""
    if atheris is None:
        pytest.skip("Atheris not installed; skipping corpus replay")
    target = next(t for t in FUZZ_TARGETS if t.__name__ == target_name)
    data = __import__("pathlib").Path(seed_path).read_bytes()
    target(data)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
