#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Pure destination registry, dispatch, writeback, and hydration contracts."""

from __future__ import annotations

import pathlib
import re
from dataclasses import dataclass, replace
from typing import Any, Mapping, Protocol

import yaml

_ENTRY_FIELDS = {"id", "intent", "target", "loop_closure", "v1_retro"}
_REGISTRY_INTENTS = {"capture", "synthesize", "action", "archive"}
_ACTION_INTENTS = {"create", "mutate", "append", "no-op"}
_WRITEBACK_FIELDS = {"tags", "hyperlink", "parentId"}
_LINEAGE_PATTERN = re.compile(
    r"^\s*\[\s*dt\s*:.*?\bmethod\s*=\s*(?P<method>\d+).*?"
    r"\bsection\s*=\s*(?P<section>[^\s\]]+).*?"
    r"\brun\s*=\s*(?P<run>[A-Za-z0-9]+).*?\]"
)


@dataclass(frozen=True)
class DestinationEntry:
    """One validated destination-registry record."""

    id: str
    intent: str
    target: str
    loop_closure: str
    v1_retro: bool


@dataclass(frozen=True)
class DestinationRegistry:
    """Validated destinations keyed by stable adapter identifier."""

    entries: Mapping[str, DestinationEntry]


@dataclass(frozen=True)
class DispatchRequest:
    """Explicit destination and action intent passed to one adapter."""

    destination: str | None
    action_intent: str | None
    payload: Mapping[str, Any]
    idempotency_key: str | None = None
    external_id: str | None = None


@dataclass(frozen=True)
class DispatchResult:
    """Effect-free adapter result and lifecycle projection."""

    status: str
    external_id: str | None = None
    loop_closed: bool = False
    lifecycle: tuple[str, ...] = ()
    reason: str | None = None


class DestinationAdapter(Protocol):
    """Injected destination implementation used by the pure dispatcher."""

    def dispatch(self, request: DispatchRequest) -> DispatchResult:
        """Handle one explicit request and return its result."""


def _default_registry_path() -> pathlib.Path:
    repo_root = pathlib.Path(__file__).resolve().parents[6]
    return (
        repo_root
        / ".github"
        / "instructions"
        / "experimental"
        / "mural"
        / "destinations"
        / "registry.yml"
    )


def _default_override_path() -> pathlib.Path:
    return _default_registry_path().with_name("dt-sections.yml")


def _read_yaml(path: pathlib.Path) -> Mapping[str, Any]:
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"destination_registry_invalid: {path.name}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("destination_registry_invalid: root must be a mapping")
    return value


def _target_is_safe(target: str) -> bool:
    if not target.strip():
        return False
    normalized = target.replace("\\", "/")
    path = pathlib.PurePosixPath(normalized)
    windows_path = pathlib.PureWindowsPath(target)
    return (
        not path.is_absolute()
        and not windows_path.is_absolute()
        and not windows_path.drive
        and ".." not in path.parts
    )


def _entry_from_raw(raw: Any) -> DestinationEntry:
    if not isinstance(raw, dict):
        raise ValueError("destination_registry_invalid: entry must be a mapping")
    fields = set(raw)
    if fields != _ENTRY_FIELDS:
        raise ValueError(
            "destination_registry_invalid: entry fields must be exactly "
            + ", ".join(sorted(_ENTRY_FIELDS))
        )
    if not all(
        isinstance(raw[field], str) and raw[field].strip()
        for field in _ENTRY_FIELDS - {"v1_retro"}
    ):
        raise ValueError(
            "destination_registry_invalid: string fields must be non-empty"
        )
    if raw["intent"] not in _REGISTRY_INTENTS:
        raise ValueError("destination_registry_invalid: unsupported registry intent")
    if not isinstance(raw["v1_retro"], bool):
        raise ValueError("destination_registry_invalid: v1_retro must be boolean")
    if not _target_is_safe(raw["target"]):
        raise ValueError("destination_registry_invalid: unsafe target glob")
    return DestinationEntry(**{field: raw[field] for field in _ENTRY_FIELDS})


def _entries_from_document(document: Mapping[str, Any]) -> list[DestinationEntry]:
    destinations = document.get("destinations")
    if not isinstance(destinations, list):
        raise ValueError("destination_registry_invalid: destinations must be a list")
    entries = [_entry_from_raw(raw) for raw in destinations]
    ids = [entry.id for entry in entries]
    if len(ids) != len(set(ids)):
        raise ValueError("destination_registry_invalid: duplicate destination id")
    return entries


def _merge_override(
    entries: dict[str, DestinationEntry],
    document: Mapping[str, Any],
) -> None:
    unknown_root_fields = set(document) - {"destinations", "remove"}
    if unknown_root_fields:
        raise ValueError("destination_registry_invalid: unknown override field")
    removals = document.get("remove", [])
    if not isinstance(removals, list) or not all(
        isinstance(item, str) and item for item in removals
    ):
        raise ValueError("destination_registry_invalid: remove must be a string list")
    for destination_id in removals:
        entries.pop(destination_id, None)

    raw_overrides = document.get("destinations", [])
    if not isinstance(raw_overrides, list):
        raise ValueError("destination_registry_invalid: destinations must be a list")
    override_ids: list[str] = []
    for raw_override in raw_overrides:
        if not isinstance(raw_override, dict):
            raise ValueError("destination_registry_invalid: entry must be a mapping")
        unknown_fields = set(raw_override) - _ENTRY_FIELDS
        if unknown_fields or "id" not in raw_override:
            raise ValueError("destination_registry_invalid: invalid override fields")
        destination_id = raw_override["id"]
        if not isinstance(destination_id, str) or not destination_id.strip():
            raise ValueError("destination_registry_invalid: id must be non-empty")
        override_ids.append(destination_id)
        merged = (
            {field: getattr(entries[destination_id], field) for field in _ENTRY_FIELDS}
            if destination_id in entries
            else {}
        )
        merged.update(raw_override)
        entries[destination_id] = _entry_from_raw(merged)
    if len(override_ids) != len(set(override_ids)):
        raise ValueError("destination_registry_invalid: duplicate destination id")


def load_destination_registry(
    *,
    base_path: pathlib.Path | None = None,
    override_path: pathlib.Path | None = None,
) -> DestinationRegistry:
    """Load, merge by ID, and validate the destination registry."""
    resolved_base = base_path or _default_registry_path()
    entries = {
        entry.id: entry for entry in _entries_from_document(_read_yaml(resolved_base))
    }
    resolved_override = override_path or _default_override_path()
    if resolved_override.exists():
        _merge_override(entries, _read_yaml(resolved_override))
    return DestinationRegistry(entries=entries)


def dispatch_destination(
    request: DispatchRequest,
    registry: DestinationRegistry,
    adapters: Mapping[str, DestinationAdapter],
) -> DispatchResult:
    """Dispatch explicit intent to exactly one injected adapter."""
    if not request.destination or not request.action_intent:
        return DispatchResult(status="no-dispatch", reason="explicit_intent_required")
    if request.action_intent not in _ACTION_INTENTS:
        return DispatchResult(status="no-dispatch", reason="invalid_action_intent")
    if request.destination not in registry.entries:
        return DispatchResult(status="no-dispatch", reason="unknown_destination")
    if request.external_id:
        if not request.idempotency_key:
            return DispatchResult(
                status="no-dispatch", reason="resume_requires_idempotency_key"
            )
        return DispatchResult(
            status="resumed",
            external_id=request.external_id,
            lifecycle=("lifecycle:committed",),
            reason="existing_external_id",
        )
    adapter = adapters.get(request.destination)
    if adapter is None:
        return DispatchResult(status="no-dispatch", reason="adapter_unavailable")
    result = adapter.dispatch(request)
    lifecycle: list[str] = []
    if result.external_id:
        lifecycle.append("lifecycle:committed")
        if result.loop_closed:
            lifecycle.append("lifecycle:loop-closed")
    return replace(result, lifecycle=tuple(lifecycle))


def validate_writeback_patch(patch: Mapping[str, Any]) -> dict[str, Any]:
    """Return a metadata-only writeback patch or reject it."""
    unexpected = set(patch) - _WRITEBACK_FIELDS
    if unexpected:
        raise ValueError("writeback permits only tags, hyperlink, and parentId")
    return dict(patch)


def _parse_lineage(title: Any) -> dict[str, Any] | None:
    if not isinstance(title, str):
        return None
    match = _LINEAGE_PATTERN.match(title)
    if match is None:
        return None
    return {
        "method": int(match.group("method")),
        "section": match.group("section"),
        "run_id": match.group("run"),
    }


def hydrate_destination_record(
    context: Mapping[str, Any],
    *,
    room: Mapping[str, Any],
    mural: Mapping[str, Any],
    workspace: Mapping[str, Any],
    tag_text_by_id: Mapping[str, str],
    widget_url: str,
) -> dict[str, Any]:
    """Normalize a source widget without mutating its authored content."""
    widget = dict(context.get("widget") or {})
    tag_ids = list(widget.get("tags") or [])
    tags = [tag_text_by_id[tag_id] for tag_id in tag_ids if tag_id in tag_text_by_id]
    unresolved_tag_ids = [tag_id for tag_id in tag_ids if tag_id not in tag_text_by_id]
    missing = list(context.get("hydration_missing") or [])
    if unresolved_tag_ids:
        missing.append("tags")
    for field, value in (
        ("room", room.get("name")),
        ("mural", mural.get("title") or mural.get("name")),
        ("workspace", workspace.get("name")),
        ("source_ref", widget_url),
    ):
        if not value:
            missing.append(field)
    return {
        "widget_id": widget.get("id"),
        "text": widget.get("text"),
        "htmlText": widget.get("htmlText"),
        "parent_chain": list(context.get("area_chain") or []),
        "room": {"id": room.get("id"), "name": room.get("name")},
        "mural": {
            "id": mural.get("id"),
            "name": mural.get("title") or mural.get("name"),
        },
        "workspace": {"id": workspace.get("id"), "name": workspace.get("name")},
        "tags": tags,
        "hyperlink": widget.get("hyperlink"),
        "source_ref": widget_url,
        "spatial_neighbors": list(context.get("siblings") or []),
        "freshness": context.get("freshness"),
        "image_asset_urls": list(context.get("image_asset_urls") or []),
        "lineage": _parse_lineage(widget.get("title")),
        "authored_by_ai": "authored-by-ai" in tags,
        "partial": bool(missing),
        "hydration_missing": sorted(set(missing)),
    }


_DESTINATION_FIELDS: Mapping[str, tuple[str, ...]] = {
    "backlog-item": ("parent_chain", "tags", "hyperlink", "source_ref"),
    "instructions-file": ("parent_chain", "tags", "source_ref", "spatial_neighbors"),
    "adr": ("parent_chain", "tags", "source_ref", "spatial_neighbors"),
    "living-document": ("parent_chain", "tags", "source_ref", "freshness"),
    "powerpoint-deck": (
        "parent_chain",
        "tags",
        "source_ref",
        "image_asset_urls",
    ),
    "next-workshop-seed": (
        "parent_chain",
        "room",
        "mural",
        "workspace",
        "tags",
        "source_ref",
        "lineage",
    ),
    "unactioned": ("parent_chain", "tags", "source_ref"),
}


def project_destination_record(
    record: Mapping[str, Any], destination: str
) -> dict[str, Any]:
    """Project only the context fields required by ``destination``."""
    fields = _DESTINATION_FIELDS.get(destination)
    if fields is None:
        raise ValueError("unknown destination projection")
    projection = {field: record.get(field) for field in fields}
    projection.update(
        {
            "widget_id": record.get("widget_id"),
            "text": record.get("text"),
            "htmlText": record.get("htmlText"),
            "authored_by_ai": record.get("authored_by_ai"),
            "partial": record.get("partial"),
            "hydration_missing": record.get("hydration_missing"),
        }
    )
    return projection
