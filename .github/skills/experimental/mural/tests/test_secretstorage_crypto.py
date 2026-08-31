# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Regression coverage for the cryptography>=50.0.0 upgrade (CVE-2026-69247).

The mural skill does not call cryptography directly; it is pulled in
transitively via keyring's secretstorage backend on Linux (Secret Service
D-Bus API). secretstorage uses cryptography's AES-CBC cipher with PKCS7-style
padding to encrypt/decrypt secrets exchanged with the D-Bus daemon -- the
exact primitive affected by CVE-2026-69247 (Bleichenbacher oracle in PKCS7
decrypt), fixed upstream in cryptography 50.0.0.

This test exercises that real encrypt/decrypt round trip (bypassing the D-Bus
transport, which is unavailable in CI) to verify the upgraded cryptography
release still produces correct plaintext through secretstorage's own
Session/format_secret helpers and the same Cipher/AES/CBC construction used
by secretstorage.item.Item.get_secret.
"""

from __future__ import annotations

import pytest

secretstorage = pytest.importorskip(
    "secretstorage", reason="secretstorage is a Linux-only transitive dependency"
)


def test_secretstorage_aes_cbc_pkcs7_round_trip() -> None:
    """Encrypt via secretstorage's Session/format_secret, decrypt via the same
    Cipher/AES/CBC construction secretstorage.item.Item.get_secret uses, and
    confirm the recovered plaintext matches -- exercising cryptography's
    AES-CBC decrypt path post-upgrade to 50.0.0.
    """
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from secretstorage.dhcrypto import DH_PRIME_1024, Session
    from secretstorage.util import format_secret

    session = Session()
    # Simulate a completed Diffie-Hellman exchange by deriving the AES key
    # from a fixed peer public key, mirroring set_server_public_key's flow
    # without a live D-Bus session. object_path is normally populated by
    # open_session() after the D-Bus round trip; format_secret only asserts
    # it is set, so any placeholder value is sufficient here.
    session.set_server_public_key(pow(2, 12345, DH_PRIME_1024))
    session.object_path = "/org/freedesktop/secrets/session/test"
    assert session.aes_key is not None
    assert len(session.aes_key) == 16  # 128-bit AES key

    plaintext = b"mural-oauth-refresh-token-fixture"
    _object_path, aes_iv, encrypted_secret, content_type = format_secret(
        session, plaintext, "text/plain"
    )
    assert encrypted_secret != plaintext  # sanity: ciphertext isn't plaintext
    assert content_type == "text/plain"

    # Mirror secretstorage.item.Item.get_secret's decrypt logic.
    aes = algorithms.AES(session.aes_key)
    decryptor = Cipher(aes, modes.CBC(aes_iv), default_backend()).decryptor()
    padded_secret = decryptor.update(encrypted_secret) + decryptor.finalize()
    recovered = padded_secret[: -padded_secret[-1]]

    assert recovered == plaintext
