#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Exception classes for the Mural CLI package.

All custom exception types live here so submodules can raise / catch them
without circular imports against the legacy monolith. Constants referenced
in error messages (``ENV_DEFAULT_WORKSPACE``, ``_AUTHORED_BY_AI_TAG_TEXT``)
are re-imported from :mod:`mural._constants`.
"""

from __future__ import annotations

from typing import Any

from ._constants import _AUTHORED_BY_AI_TAG_TEXT, ENV_DEFAULT_WORKSPACE


class MuralError(Exception):
    """Base exception for Mural CLI errors."""


class MuralAPIError(MuralError):
    """Raised when Mural responds with a non-2xx status."""

    def __init__(
        self,
        status: int,
        code: str | None,
        message: str,
        request_id: str | None = None,
    ) -> None:
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
        self.request_id = request_id

    def __str__(self) -> str:  # pragma: no cover - trivial formatting
        rid = f" request_id={self.request_id}" if self.request_id else ""
        code = f" code={self.code}" if self.code else ""
        return f"HTTP {self.status}{code}: {self.message}{rid}"


class MuralSecurityError(MuralError):
    """Raised when a security invariant is violated (e.g. unsafe redirect)."""


class MuralAmbiguousWorkspaceError(MuralError):
    """Raised when a workspace-scoped command is invoked without a selector."""

    def __init__(
        self,
        workspace_ids: list[str] | None = None,
        message: str | None = None,
    ) -> None:
        self.workspace_ids = list(workspace_ids or [])
        if message is None:
            available = (
                ", ".join(self.workspace_ids) if self.workspace_ids else "unknown"
            )
            message = (
                "multiple workspaces available; pass --workspace <id> or set "
                f"{ENV_DEFAULT_WORKSPACE} (available: {available})"
            )
        super().__init__(message)


class MuralValidationError(MuralError):
    """Raised when client-side validation rejects user input before any HTTP call."""


class MuralAuthScopeError(MuralError):
    """Raised when the stored token lacks an OAuth scope required by a tool."""

    def __init__(self, scope: str, granted: tuple[str, ...] | list[str]) -> None:
        self.scope = scope
        self.granted = list(granted)
        super().__init__(
            f"missing required OAuth scope {scope!r}; "
            "re-authenticate with: mural auth login --write"
        )


class MuralTagMergeConflict(MuralError):
    """Raised when concurrent tag mutations cannot converge after retries.

    The widget tag PATCH endpoint is a full-array replace with no ETag, so
    racing writers can clobber each other. ``_merge_tags`` performs a
    read-modify-write loop with bounded retries; on exhaustion this error
    carries the diagnostic payload so callers can surface a structured
    ``tag_merge_conflict`` envelope.
    """

    def __init__(
        self,
        *,
        mural_id: str,
        widget_id: str,
        intended: list[str],
        observed: list[str],
        attempts: int,
    ) -> None:
        self.mural_id = mural_id
        self.widget_id = widget_id
        self.intended = list(intended)
        self.observed = list(observed)
        self.attempts = attempts
        intended_set = set(self.intended)
        observed_set = set(self.observed)
        self.missing = sorted(intended_set - observed_set)
        self.extra = sorted(observed_set - intended_set)
        super().__init__(
            "tag_merge_conflict: widget "
            f"{widget_id} on mural {mural_id} did not converge after "
            f"{attempts} attempts (missing={self.missing}, extra={self.extra})"
        )


class MuralHumanAuthoredProtected(MuralError):
    """Raised when a guarded mutation targets a widget without the AI tag.

    Triggered when ``--require-author-tag`` is set on ``widget update`` or
    ``widget delete`` and the target widget lacks the ``authored-by-ai``
    reserved tag. Operators can opt out per-call with ``--force-human``.
    """

    def __init__(self, *, mural_id: str, widget_id: str) -> None:
        self.mural_id = mural_id
        self.widget_id = widget_id
        super().__init__(
            "human_authored_widget_protected: widget "
            f"{widget_id} on mural {mural_id} is missing the "
            f"{_AUTHORED_BY_AI_TAG_TEXT!r} tag; pass --force-human to override"
        )


class MuralAreaCapacityExceeded(MuralError):
    """Raised when a layout would overflow the target area's bounds.

    Carries the structured payload required by the refuse-don't-coerce
    contract so the CLI surface can render ``AREA_CAPACITY_EXCEEDED``
    envelopes with a deterministic exit code.
    """

    def __init__(
        self,
        *,
        area_id: str,
        area_capacity: dict[str, Any],
        computed_extent: dict[str, Any],
        suggestion: str,
    ) -> None:
        self.area_id = area_id
        self.area_capacity = dict(area_capacity)
        self.computed_extent = dict(computed_extent)
        self.suggestion = suggestion
        super().__init__(
            f"AREA_CAPACITY_EXCEEDED: area {area_id} capacity "
            f"{area_capacity} cannot fit computed extent {computed_extent}"
        )


class MuralBulkAtomicAbort(MuralError):
    """Raised when a bulk widget update is aborted at first failure under ``--atomic``.

    The ``summary`` attribute carries the partial ``{succeeded, failed,
    warnings}`` envelope that was assembled before the abort.
    """

    def __init__(self, summary: dict[str, Any]) -> None:
        self.summary = summary
        failed = summary.get("failed") or []
        widget_id = (failed[0].get("widget_id") if failed else None) or "?"
        super().__init__(
            f"BULK_ATOMIC_ABORT: bulk update aborted at widget {widget_id}; "
            f"{len(summary.get('succeeded') or [])} succeeded before failure"
        )


class ResponseTooLarge(MuralError):
    """Raised when an HTTP response body exceeds ``MURAL_MAX_BODY_BYTES``."""


class MCPInvalidParamsError(Exception):
    """Parameter validation error retained for CLI helper compatibility.

    The ``path`` attribute points to the offending location using a
    dotted/JSON-pointer-ish notation (e.g. ``$.arguments.mural``).
    """

    def __init__(self, message: str, path: str = "$") -> None:
        super().__init__(message)
        self.message = message
        self.path = path
