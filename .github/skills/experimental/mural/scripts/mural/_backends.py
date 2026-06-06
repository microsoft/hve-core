#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Credential storage backends for the Mural CLI.

Carved from ``mural/__init__.py`` (Step 2.1 of the modularization plan).
Contains the :class:`CredentialBackend` protocol and the concrete
``KeyringBackend`` and ``FileBackend`` implementations, plus the
``resolve_backend`` selector that honors ``MURAL_CREDENTIAL_BACKEND``.

Helpers that stay in the package ``__init__`` (``_KeyringUnavailable``,
``_NullBackend``, ``_check_credential_file_perms``, ``_emit``,
``_maybe_warn_concurrent_state``) are imported from the package and bound
when this submodule is first imported by ``__init__.py`` (which happens
after those helpers are defined). ``resolve_backend`` reads the shared
dedup sets through the live ``_state`` binding so one-WARN-per-process
semantics survive across module boundaries.
"""

from __future__ import annotations

import contextlib
import logging
import os
import pathlib
import sys

from . import (  # noqa: E402 - package siblings defined before this import runs
    _check_credential_file_perms,
    _emit,
    _KeyringUnavailable,
    _maybe_warn_concurrent_state,
    _NullBackend,
    _state,
)
from ._constants import _LINE_RE, ENV_NONINTERACTIVE
from ._credentials import _resolve_credential_file
from ._exceptions import MuralError
from ._protocols import CredentialBackend


def _bootstrap_is_interactive() -> bool:
    """Return True when `mural auth bootstrap` may prompt the operator."""
    return (
        sys.stdin.isatty()
        and sys.stdout.isatty()
        and os.environ.get(ENV_NONINTERACTIVE) != "1"
        and os.environ.get("CI", "").lower() != "true"
    )


class KeyringBackend:
    """Backend that delegates to the OS keychain via the ``keyring`` package.

    Lazy-imports ``keyring`` in ``__init__`` so module load does not pay
    the cost of resolving a platform backend until a keyring lookup is
    requested. Honors ``MURAL_KEYRING_BACKEND`` to override the default
    backend selection (``module.path.ClassName`` form, applied via
    ``keyring.set_keyring``).
    """

    name = "keyring"

    def __init__(self) -> None:
        try:
            import keyring
            from keyring import errors as keyring_errors
        except ImportError as exc:
            raise _KeyringUnavailable(f"keyring package not importable: {exc}") from exc
        override = os.environ.get("MURAL_KEYRING_BACKEND")
        if override:
            try:
                import importlib

                module_path, _, class_name = override.rpartition(".")
                if not module_path or not class_name:
                    raise _KeyringUnavailable(
                        f"MURAL_KEYRING_BACKEND={override!r} must be "
                        "'module.path.ClassName'"
                    )
                module = importlib.import_module(module_path)
                backend_cls = getattr(module, class_name)
                keyring.set_keyring(backend_cls())
            except _KeyringUnavailable:
                raise
            except Exception as exc:
                raise _KeyringUnavailable(
                    f"failed to apply MURAL_KEYRING_BACKEND={override!r}: {exc}"
                ) from exc
        try:
            self.backend_name = keyring.get_keyring().name
        except Exception as exc:
            raise _KeyringUnavailable(
                f"failed to resolve keyring backend: {exc}"
            ) from exc
        self._keyring = keyring
        self._errors = keyring_errors

    def get(self, service: str, key: str) -> str | None:
        try:
            return self._keyring.get_password(service, key)
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc

    def set(self, service: str, key: str, value: str) -> None:
        try:
            self._keyring.set_password(service, key, value)
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc

    def delete(self, service: str, key: str) -> None:
        try:
            self._keyring.delete_password(service, key)
        except self._errors.PasswordDeleteError:
            return  # idempotent: missing entry is success
        except self._errors.KeyringError as exc:
            raise _KeyringUnavailable(str(exc)) from exc


class FileBackend:
    """Backend that reads and writes a per-profile mode-0600 env file.

    The ``service`` argument is accepted for protocol parity but unused;
    the backing path (resolved by :func:`_resolve_credential_file`) is
    bound at construction time.
    """

    name = "file"

    def __init__(self, path: pathlib.Path) -> None:
        self._path = path

    def _read_all(self) -> dict[str, str]:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        try:
            fd = os.open(str(self._path), flags)
        except FileNotFoundError:
            return {}
        with os.fdopen(fd, "r", encoding="utf-8", errors="strict") as fh:
            text = fh.read()
        result: dict[str, str] = {}
        for line in text.splitlines():
            stripped = line.lstrip()
            if not stripped or stripped.startswith("#"):
                continue
            match = _LINE_RE.match(line)
            if match is None:
                continue
            key = match.group("k")
            value = match.group("v")
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                value = value[1:-1]
            result[key] = value
        return result

    def get(self, service: str, key: str) -> str | None:
        return self._read_all().get(key)

    def set(self, service: str, key: str, value: str) -> None:
        existing = self._read_all()
        existing[key] = value
        self._write_all(existing)

    def delete(self, service: str, key: str) -> None:
        if not self._path.exists():
            return
        _check_credential_file_perms(self._path, os.environ)
        existing = self._read_all()
        if key not in existing:
            return
        existing.pop(key)
        if existing:
            self._write_all(existing)
        else:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(self._path)

    def _write_all(self, entries: dict[str, str]) -> None:
        # Mirrors _cmd_auth_bootstrap: 0o077 umask + O_EXCL temp + os.replace.
        body_lines = [
            "# Mural credentials (managed by FileBackend).",
            "# File mode MUST be 0600. Override only via MURAL_ENV_FILE_RELAXED=1.",
        ]
        for k in sorted(entries):
            body_lines.append(f"{k}={entries[k]}")
        body = ("\n".join(body_lines) + "\n").encode("utf-8")
        self._path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self._path.with_name(f"{self._path.name}.{os.getpid()}.tmp")
        prev_umask = os.umask(0o077)
        try:
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_TRUNC
            fd = os.open(str(tmp), flags, 0o600)
            try:
                with os.fdopen(fd, "wb") as fh:
                    fh.write(body)
            except BaseException:
                with contextlib.suppress(OSError):
                    os.close(fd)
                raise
            os.replace(tmp, self._path)
            with contextlib.suppress(OSError):
                os.chmod(self._path, 0o600)
        finally:
            os.umask(prev_umask)
            with contextlib.suppress(FileNotFoundError):
                tmp.unlink()


def resolve_backend(profile: str = "default") -> CredentialBackend:
    """Return the credential backend for ``profile`` honoring env overrides.

    ``MURAL_CREDENTIAL_BACKEND`` selects the backend (``auto`` default,
    ``keyring``, ``file``, ``env-only``). On ``auto``, KeyringBackend is
    tried first and falls back to FileBackend when ``_KeyringUnavailable``
    is raised; a one-shot WARN per profile records the fallback. After
    backend selection (skipped for env-only), a probe checks whether the
    other persistent backend also holds non-empty values and emits a
    second one-shot WARN per ``(profile, selected_backend)`` pair when so.
    The probe never raises and never affects the returned backend.
    """
    selector = os.environ.get("MURAL_CREDENTIAL_BACKEND", "auto").lower()
    file_path = _resolve_credential_file(profile, os.environ)
    selected: CredentialBackend
    if selector == "env-only":
        return _NullBackend()
    if selector == "file":
        selected = FileBackend(file_path)
    elif selector == "keyring":
        selected = KeyringBackend()  # let _KeyringUnavailable propagate
    elif selector == "auto":
        try:
            selected = KeyringBackend()
        except _KeyringUnavailable as exc:
            if profile not in _state.seen_fallback_warn():
                _state.seen_fallback_warn().add(profile)
                _emit(
                    f"keyring backend unavailable for profile {profile!r} "
                    f"({exc}); falling back to file backend at {file_path}",
                    level=logging.WARNING,
                )
            selected = FileBackend(file_path)
    else:
        raise MuralError(
            f"MURAL_CREDENTIAL_BACKEND={selector!r} is not one of "
            "'auto', 'keyring', 'file', 'env-only'"
        )
    _maybe_warn_concurrent_state(profile, selected, file_path)
    return selected
