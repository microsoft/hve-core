#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tag manifest, merge, and authorship helper implementations."""

from __future__ import annotations

import sys
import time
from typing import Any, Callable

from ._constants import _RESERVED_TAG_PREFIXES, _RESERVED_TAGS


def _is_reserved_tag_text(text: str) -> bool:
    """Return ``True`` for literal-reserved or reserved-prefix tag texts."""
    if not isinstance(text, str):
        return False
    if text in _RESERVED_TAGS:
        return True
    return any(text.startswith(prefix) for prefix in _RESERVED_TAG_PREFIXES)


def _is_tag_cap_error_impl(
    exc: Any,
    *,
    tag_cap_hints: tuple[str, ...],
) -> bool:
    if exc.status != 400:
        return False
    haystack = " ".join(str(part).lower() for part in (exc.code, exc.message) if part)
    return any(hint in haystack for hint in tag_cap_hints)


def _create_tag_impl(
    mural_id: str,
    text: str,
    color: str | None = None,
    *,
    validate_tag_text: Callable[[str], str],
    authenticated_request: Callable[..., Any],
    is_tag_cap_error: Callable[[Any], bool],
    MuralAPIError: type[Exception],
    MuralValidationError: type[Exception],
) -> dict[str, Any]:
    body: dict[str, Any] = {"text": validate_tag_text(text)}
    if color:
        body["color"] = color
    try:
        return authenticated_request("POST", f"/murals/{mural_id}/tags", json_body=body)
    except MuralAPIError as exc:
        if is_tag_cap_error(exc):
            raise MuralValidationError(
                f"tag_cap_reached: {exc.message or exc.code}"
            ) from exc
        raise


def _ensure_tag_manifest_impl(
    mural_id: str,
    manifest: list[dict[str, Any]],
    *,
    paginate: Callable[..., Any],
    create_tag: Callable[[str, str, str | None], dict[str, Any]],
    MuralAPIError: type[Exception],
    MuralValidationError: type[Exception],
) -> dict[str, str]:
    """Idempotently materialise ``manifest`` and return ``{text -> tag_id}``."""
    if not isinstance(manifest, list):
        raise MuralValidationError("tag manifest must be a list of objects")
    existing = list(paginate("GET", f"/murals/{mural_id}/tags"))
    by_text: dict[str, str] = {}
    for tag in existing:
        if not isinstance(tag, dict):
            continue
        text = tag.get("text")
        tag_id = tag.get("id")
        if isinstance(text, str) and isinstance(tag_id, str):
            by_text[text] = tag_id
    for entry in manifest:
        if not isinstance(entry, dict):
            raise MuralValidationError("tag manifest entries must be objects")
        text = entry.get("text")
        if not isinstance(text, str):
            raise MuralValidationError("tag manifest entry missing text")
        if text in by_text:
            continue
        created = create_tag(mural_id, text, entry.get("color"))
        new_id = created.get("id") if isinstance(created, dict) else None
        if not isinstance(new_id, str):
            raise MuralAPIError(0, "TAG_INVALID", "tag create response missing id")
        by_text[text] = new_id
    return by_text


def _widget_tag_ids_impl(widget: Any) -> list[str]:
    """Normalize a widget's ``tags`` field to a list of tag-id strings."""
    if not isinstance(widget, dict):
        return []
    inner = widget.get("value")
    if isinstance(inner, dict) and "tags" in inner:
        widget = inner
    raw = widget.get("tags")
    if not isinstance(raw, list):
        return []
    out: list[str] = []
    for entry in raw:
        if isinstance(entry, str):
            out.append(entry)
        elif isinstance(entry, dict):
            for key in ("id", "tagId", "tag_id"):
                value = entry.get(key)
                if isinstance(value, str):
                    out.append(value)
                    break
    return out


def _tag_merge_backoff_seconds_impl(
    *,
    randbelow: Callable[[int], int],
    backoff_min_ms: int,
    backoff_max_ms: int,
) -> float:
    """Return a jittered backoff delay for tag merge retries."""
    span = backoff_max_ms - backoff_min_ms + 1
    millis = backoff_min_ms + randbelow(span)
    return millis / 1000.0


def _merge_tags_impl(
    mural_id: str,
    widget_id: str,
    *,
    additions: list[str] | tuple[str, ...] = (),
    removals: list[str] | tuple[str, ...] = (),
    max_retries: int,
    authenticated_request: Callable[..., Any],
    widget_tag_ids: Callable[[Any], list[str]],
    patch_widget_or_disambiguate_404: Callable[..., Any],
    session_manifest_record: Callable[[str, str, list[str]], Any],
    tag_merge_backoff_seconds: Callable[[], float],
    MuralTagMergeConflict: type[Exception],
) -> dict[str, Any]:
    """Read-modify-write the ``tags`` array on a widget with bounded retries."""
    add_set = set(additions or ())
    remove_set = set(removals or ())
    if not add_set and not remove_set:
        return {
            "ok": True,
            "widget": widget_id,
            "tags": [],
            "added": [],
            "removed": [],
            "attempts": 0,
            "noop": True,
        }
    attempts = 0
    last_observed: list[str] = []
    target: list[str] = []
    while attempts < max_retries:
        attempts += 1
        widget = authenticated_request("GET", f"/murals/{mural_id}/widgets/{widget_id}")
        current = set(widget_tag_ids(widget))
        target_set = (current | add_set) - remove_set
        target = sorted(target_set)
        inner = widget.get("value") if isinstance(widget, dict) else None
        discovered_type: str | None = None
        if isinstance(inner, dict):
            widget_type = inner.get("type")
            if isinstance(widget_type, str):
                discovered_type = widget_type
        if discovered_type is None and isinstance(widget, dict):
            widget_type = widget.get("type")
            if isinstance(widget_type, str):
                discovered_type = widget_type
        patch_widget_or_disambiguate_404(
            mural_id, widget_id, {"tags": target}, widget_type=discovered_type
        )
        observed_widget = authenticated_request(
            "GET", f"/murals/{mural_id}/widgets/{widget_id}"
        )
        last_observed = sorted(set(widget_tag_ids(observed_widget)))
        if set(last_observed) == target_set:
            actually_added = sorted(target_set - current)
            actually_removed = sorted(current & remove_set)
            session_manifest_record(mural_id, widget_id, target)
            return {
                "ok": True,
                "widget": widget_id,
                "tags": target,
                "added": actually_added,
                "removed": actually_removed,
                "attempts": attempts,
            }
        if attempts < max_retries:
            time.sleep(tag_merge_backoff_seconds())
    raise MuralTagMergeConflict(
        mural_id=mural_id,
        widget_id=widget_id,
        intended=target,
        observed=last_observed,
        attempts=attempts,
    )


def _ensure_reserved_author_tag_impl(
    mural_id: str,
    *,
    ensure_tag_manifest: Callable[[str, list[dict[str, Any]]], dict[str, str]],
    authored_by_ai_tag_text: str,
) -> str:
    """Return the tag id for ``authored-by-ai`` on ``mural_id``."""
    mapping = ensure_tag_manifest(mural_id, [{"text": authored_by_ai_tag_text}])
    return mapping[authored_by_ai_tag_text]


def _resolve_widget_id_impl(record: Any) -> str | None:
    """Best-effort extraction of a widget id from a create response payload."""
    if not isinstance(record, dict):
        return None
    candidate = record.get("id")
    if isinstance(candidate, str) and candidate:
        return candidate
    value = record.get("value")
    if isinstance(value, dict):
        candidate = value.get("id")
        if isinstance(candidate, str) and candidate:
            return candidate
    return None


def _maybe_apply_author_tag_impl(
    mural_id: str,
    record: Any,
    *,
    skip: bool,
    resolve_widget_id: Callable[[Any], str | None],
    ensure_reserved_author_tag: Callable[[str], str],
    merge_tags: Callable[..., dict[str, Any]],
    MuralError: type[Exception],
) -> dict[str, Any] | None:
    """Attach the reserved ``authored-by-ai`` tag to a freshly-created widget."""
    if skip:
        return None
    widget_id = resolve_widget_id(record)
    if not widget_id:
        return None
    try:
        tag_id = ensure_reserved_author_tag(mural_id)
        return merge_tags(mural_id, widget_id, additions=[tag_id])
    except MuralError as exc:
        print(
            f"warning: could not attach 'authored-by-ai' tag to {widget_id}: {exc}",
            file=sys.stderr,
        )
        return None


def _assert_widget_has_author_tag_impl(
    mural_id: str,
    widget_id: str,
    *,
    ensure_reserved_author_tag: Callable[[str], str],
    authenticated_request: Callable[..., Any],
    widget_tag_ids: Callable[[Any], list[str]],
    MuralHumanAuthoredProtected: type[Exception],
) -> None:
    """Raise when the AI authorship tag is absent."""
    tag_id = ensure_reserved_author_tag(mural_id)
    widget = authenticated_request("GET", f"/murals/{mural_id}/widgets/{widget_id}")
    if tag_id not in widget_tag_ids(widget):
        raise MuralHumanAuthoredProtected(mural_id=mural_id, widget_id=widget_id)


def _is_reserved_tag_id_impl(
    mural_id: str,
    tag_id: str,
    *,
    paginate: Callable[..., Any],
    is_reserved_tag_text: Callable[[str], bool],
) -> bool:
    """Return ``True`` when ``tag_id`` matches a reserved tag."""
    for tag in paginate("GET", f"/murals/{mural_id}/tags"):
        if not isinstance(tag, dict):
            continue
        if tag.get("id") == tag_id and is_reserved_tag_text(tag.get("text") or ""):
            return True
    return False
