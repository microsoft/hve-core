#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Structural typing protocols for the Mural CLI.

Leaf module with no intra-package imports. Hosting the
:class:`CredentialBackend` protocol here lets both ``_backends`` (the
concrete implementations) and ``_credentials`` (which annotates against
the protocol) depend on a shared leaf instead of importing each other,
breaking what would otherwise be a runtime import cycle.
"""

from __future__ import annotations

from typing import Protocol


class CredentialBackend(Protocol):
    """Protocol for Mural credential storage backends.

    Implementations route credential reads and writes through a uniform
    ``(service, key)`` namespace where ``service`` is the keyring service
    name (e.g. ``"hve-core/mural/{profile}"``) and ``key`` is one of the
    entries in :data:`_KNOWN_CREDENTIAL_KEYS`.
    """

    name: str

    def get(self, service: str, key: str) -> str | None:
        """Return the stored secret for ``(service, key)`` or ``None``."""

    def set(self, service: str, key: str, value: str) -> None:
        """Store ``value`` as the secret for ``(service, key)``."""

    def delete(self, service: str, key: str) -> None:
        """Remove the secret stored under ``(service, key)``."""
