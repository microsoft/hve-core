# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for Mural skill helper logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

import mural
import pytest

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


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


def fuzz_parse_mcp_frame(data: bytes) -> None:
    """Fuzz NDJSON frame decoding; only ``MCPProtocolError`` is expected."""
    with suppress(mural.MCPProtocolError):
        mural._parse_mcp_frame(data)


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


def fuzz_frame_mcp_message(data: bytes) -> None:
    """Fuzz NDJSON framing of MCP messages with arbitrary JSON-shaped dicts."""
    provider = atheris.FuzzedDataProvider(data)
    obj: dict[str, object] = {
        "jsonrpc": "2.0",
        "id": provider.ConsumeIntInRange(-(2**31), 2**31 - 1),
        "method": provider.ConsumeUnicodeNoSurrogates(32),
        "params": {
            "name": provider.ConsumeUnicodeNoSurrogates(32),
            "arguments": {
                "value": provider.ConsumeUnicodeNoSurrogates(
                    provider.remaining_bytes()
                ),
            },
        },
    }
    framed = mural._frame_mcp_message(obj)
    # Round-trip: framed output must be parseable back to a dict.
    parsed = mural._parse_mcp_frame(framed.rstrip(b"\n"))
    assert isinstance(parsed, dict)


def fuzz_validate_tool_input_schema(data: bytes) -> None:
    """Fuzz the minimal JSON Schema validator.

    Only ``MCPInvalidParamsError`` is expected.
    """
    provider = atheris.FuzzedDataProvider(data)
    type_choice = provider.ConsumeIntInRange(0, 7)
    type_names = ("string", "integer", "number", "boolean", "array", "object", "null")
    schema: dict[str, object] = {}
    if type_choice < len(type_names):
        schema["type"] = type_names[type_choice]
    else:
        schema["type"] = list(type_names[: provider.ConsumeIntInRange(1, 3)])
    if provider.ConsumeBool():
        schema["minLength"] = provider.ConsumeIntInRange(0, 16)
    if provider.ConsumeBool():
        schema["maxLength"] = provider.ConsumeIntInRange(0, 64)
    if provider.ConsumeBool():
        schema["enum"] = [
            provider.ConsumeUnicodeNoSurrogates(8),
            provider.ConsumeIntInRange(0, 10),
        ]
    value_choice = provider.ConsumeIntInRange(0, 5)
    value: object
    if value_choice == 0:
        value = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    elif value_choice == 1:
        value = provider.ConsumeIntInRange(-1000, 1000)
    elif value_choice == 2:
        value = provider.ConsumeBool()
    elif value_choice == 3:
        value = None
    elif value_choice == 4:
        value = [provider.ConsumeIntInRange(0, 10) for _ in range(3)]
    else:
        value = {"key": provider.ConsumeUnicodeNoSurrogates(16)}
    with suppress(mural.MCPInvalidParamsError):
        mural._validate_tool_input_schema(schema, value)


FUZZ_TARGETS = [
    fuzz_redact,
    fuzz_validate_mural_id,
    fuzz_extract_field,
    fuzz_parse_pagination_cursor,
    fuzz_validate_asset_url,
    fuzz_parse_mcp_frame,
    fuzz_parse_json_arg,
    fuzz_verify_pkce,
    fuzz_extract_error_payload,
    fuzz_build_authorize_url,
    fuzz_frame_mcp_message,
    fuzz_validate_tool_input_schema,
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

    @pytest.mark.parametrize(
        "frame",
        [b"\x80\x81", b"not-json\n", b'"string"\n', b"[]\n"],
    )
    def test_parse_mcp_frame_rejects_invalid(self, frame: bytes) -> None:
        with pytest.raises(mural.MCPProtocolError):
            mural._parse_mcp_frame(frame)

    def test_parse_mcp_frame_round_trip(self) -> None:
        encoded = mural._frame_mcp_message({"jsonrpc": "2.0", "id": 1})
        assert mural._parse_mcp_frame(encoded) == {"jsonrpc": "2.0", "id": 1}

    def test_parse_mcp_frame_empty_returns_none(self) -> None:
        assert mural._parse_mcp_frame(b"   \n") is None

    def test_parse_json_arg_round_trip(self) -> None:
        assert mural._parse_json_arg('{"x":1}', "--body") == {"x": 1}

    def test_parse_json_arg_rejects_invalid(self) -> None:
        with pytest.raises(mural.MuralValidationError):
            mural._parse_json_arg("not json", "--body")

    def test_verify_pkce_round_trip(self) -> None:
        verifier, challenge = mural._generate_pkce_pair()
        assert mural._verify_pkce(verifier, challenge) is True
        assert mural._verify_pkce(verifier, "wrong") is False


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
