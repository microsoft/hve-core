#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Argument-parser construction tier for the Mural CLI.

Carved from ``mural/__init__`` (Step 3.4 of the __init__ modularization plan).
Holds ``_build_parser``, the ``_add_*`` flag helpers, and
``_add_resource_subcommands`` that wires every resource subparser to its
``_cmd_*`` callback default.

The ``_cmd_*`` callbacks and shared constants are imported from the package so
each ``func=`` default is the same object as the ``mural.<name>`` facade
attribute, preserving the ``args.func is mural._cmd_*`` identity that tests
assert. ``main`` remains in the package ``__init__`` and calls the
facade-level ``_build_parser`` so ``monkeypatch.setattr`` interception holds.
"""

from __future__ import annotations

import argparse

from . import (
    _DEFAULT_PAGE_SIZE,
    _MAX_PAGE_SIZE,
    _VALID_AREA_LAYOUTS,
    EXIT_TEMPFAIL,
    MAX_BULK_WIDGETS,
    POLL_DEFAULT_INTERVAL_S,
    POLL_DEFAULT_TIMEOUT_S,
    _cmd_area_create,
    _cmd_area_get,
    _cmd_area_list,
    _cmd_area_probe,
    _cmd_auth_bootstrap,
    _cmd_auth_list,
    _cmd_auth_login,
    _cmd_auth_logout,
    _cmd_auth_migrate,
    _cmd_auth_setup,
    _cmd_auth_status,
    _cmd_auth_use,
    _cmd_clone_with_tags,
    _cmd_compose_affinity_cluster,
    _cmd_compose_bootstrap_dt_board,
    _cmd_compose_bootstrap_ux_board,
    _cmd_compose_parking_lot_sweep,
    _cmd_compose_populate_dt_section,
    _cmd_compose_workspace_summary,
    _cmd_layout_cluster,
    _cmd_layout_column,
    _cmd_layout_grid,
    _cmd_layout_row,
    _cmd_mural_archive,
    _cmd_mural_create,
    _cmd_mural_duplicate,
    _cmd_mural_find,
    _cmd_mural_get,
    _cmd_mural_lineage_lookup,
    _cmd_mural_list,
    _cmd_mural_poll,
    _cmd_mural_repair_tag_drift,
    _cmd_mural_unarchive,
    _cmd_room_create,
    _cmd_room_get,
    _cmd_room_list,
    _cmd_spatial_arrow_graph,
    _cmd_spatial_cluster,
    _cmd_spatial_pairwise_overlaps,
    _cmd_spatial_sort_along_axis,
    _cmd_spatial_widgets_in_region,
    _cmd_spatial_widgets_in_shape,
    _cmd_tag_apply,
    _cmd_tag_create,
    _cmd_tag_list,
    _cmd_tag_remove,
    _cmd_template_create,
    _cmd_template_instantiate,
    _cmd_template_list,
    _cmd_voting_poll,
    _cmd_voting_results,
    _cmd_voting_session_close,
    _cmd_voting_session_create,
    _cmd_voting_session_delete,
    _cmd_voting_session_get,
    _cmd_voting_session_list,
    _cmd_voting_session_open,
    _cmd_widget_create_arrow,
    _cmd_widget_create_bulk,
    _cmd_widget_create_image,
    _cmd_widget_create_shape,
    _cmd_widget_create_sticky_note,
    _cmd_widget_create_textbox,
    _cmd_widget_delete,
    _cmd_widget_diff,
    _cmd_widget_get,
    _cmd_widget_get_with_context,
    _cmd_widget_list,
    _cmd_widget_list_with_context,
    _cmd_widget_update,
    _cmd_widget_update_bulk,
    _cmd_workspace_get,
    _cmd_workspace_list,
    _cmd_workspace_search,
    _parse_parent_id,
)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mural",
        description="Mural REST API CLI.",
    )
    parser.add_argument(
        "--log-level",
        default="WARNING",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity (default: WARNING).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress informational stderr output (errors still print).",
    )
    parser.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        help="Force JSON output, overriding any --format value.",
    )
    parser.add_argument(
        "--color",
        choices=["auto", "always", "never"],
        default="auto",
        help=(
            "Colorize stderr output. Default 'auto' honours NO_COLOR / "
            "FORCE_COLOR and falls back to TTY detection."
        ),
    )
    parser.add_argument(
        "--profile",
        default=None,
        help=(
            "Profile name override. Precedence: --profile > MURAL_PROFILE "
            "env var > active_profile in the token store > 'default'."
        ),
    )
    sub = parser.add_subparsers(dest="command", required=True)

    auth = sub.add_parser("auth", help="OAuth 2.0 + PKCE authentication helpers")
    auth_sub = auth.add_subparsers(dest="auth_command", required=True)

    login = auth_sub.add_parser("login", help="Interactive loopback OAuth login")
    login.add_argument(
        "--scopes",
        default=None,
        help="Override the default scope string.",
    )
    login.add_argument(
        "--write",
        action="store_true",
        help=(
            "Request write scopes (murals:write) in addition to the default "
            "read-only set. Ignored when --scopes is supplied."
        ),
    )
    login.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Seconds to wait for the OAuth callback (default: 300).",
    )
    login.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Profile name to write the resulting tokens under.",
    )
    login.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Continue even when the active credential backend already "
            "holds tokens for this profile."
        ),
    )
    login.set_defaults(func=_cmd_auth_login)

    setup = auth_sub.add_parser(
        "setup",
        help="Provision a profile non-interactively (env- or flag-driven).",
    )
    setup.add_argument("--profile", dest="profile", default=argparse.SUPPRESS)
    setup.add_argument("--client-id", dest="client_id", default=None)
    setup.add_argument("--scope", dest="scope", default=None)
    setup.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help=(
            "Emit a JSON status envelope instead of the human-readable "
            "OAuth setup walkthrough."
        ),
    )
    setup.set_defaults(func=_cmd_auth_setup)

    bootstrap = auth_sub.add_parser(
        "bootstrap",
        help="Interactively store Mural app credentials (one-time setup)",
        description=(
            "Open the Mural developer portal in a browser and prompt for "
            "Client ID / Client Secret, then persist them via the active "
            "credential backend (MURAL_CREDENTIAL_BACKEND={auto|keyring|"
            "file|env-only}). Subsequent CLI runs resolve credentials "
            "through the same backend."
        ),
    )
    bootstrap.add_argument("--profile", dest="profile", default=argparse.SUPPRESS)
    bootstrap.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Overwrite credentials already stored in the active backend "
            "for this profile."
        ),
    )
    bootstrap.add_argument(
        "--no-test",
        dest="no_test",
        action="store_true",
        default=False,
        help=(
            "Skip the post-bootstrap credential probe against Mural's "
            "/token endpoint (use for offline runs or to debug a "
            "rejected credential separately)."
        ),
    )
    bootstrap.set_defaults(func=_cmd_auth_bootstrap)

    list_p = auth_sub.add_parser("list", help="List configured profiles")
    list_p.add_argument(
        "--format",
        dest="format",
        choices=("json", "table"),
        default="json",
        help="Output format (default: json).",
    )
    list_p.set_defaults(func=_cmd_auth_list)

    use = auth_sub.add_parser("use", help="Set the active profile")
    use.add_argument("name", help="Profile name to mark active")
    use.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of a human log line.",
    )
    use.set_defaults(func=_cmd_auth_use)

    logout = auth_sub.add_parser(
        "logout",
        help="Remove credentials (current profile, named profile, or all)",
    )
    logout_target = logout.add_mutually_exclusive_group()
    logout_target.add_argument(
        "--all",
        dest="all",
        action="store_true",
        help="Remove every profile (atomically replaces the envelope).",
    )
    logout_target.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Remove only the named profile.",
    )
    logout.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of a human log line.",
    )
    logout.add_argument(
        "--keep-credentials",
        dest="keep_credentials",
        action="store_true",
        help=(
            "Remove tokens from the token store but leave Mural app "
            "credentials (client_id / client_secret) untouched in the "
            "active credential backend."
        ),
    )
    logout.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Required to remove credentials from the file backend (deletes "
            "the credential file). Has no effect on keyring removals."
        ),
    )
    logout.set_defaults(func=_cmd_auth_logout)

    status = auth_sub.add_parser("status", help="Show current auth status")
    status.set_defaults(func=_cmd_auth_status)

    migrate = auth_sub.add_parser(
        "migrate",
        help="Move Mural app credentials between keyring and file backends",
        description=(
            "Round-trip MURAL_CLIENT_ID and MURAL_CLIENT_SECRET between the "
            "OS keyring and the per-user credential file. Bypasses "
            "MURAL_CREDENTIAL_BACKEND so the operator can move secrets "
            "regardless of the active selector."
        ),
    )
    migrate.add_argument(
        "--to",
        dest="to",
        choices=("keyring", "file"),
        required=True,
        help="Destination backend.",
    )
    migrate.add_argument(
        "--profile",
        dest="profile",
        default=argparse.SUPPRESS,
        help="Profile name (default: $MURAL_PROFILE or 'default').",
    )
    migrate.add_argument(
        "--cleanup",
        dest="cleanup",
        action="store_true",
        help="Remove credentials from the source backend after a successful migration.",
    )
    migrate.add_argument(
        "--force",
        dest="force",
        action="store_true",
        help=(
            "Required with --cleanup when the source backend is the file "
            "backend (deletes the credential file)."
        ),
    )
    migrate.add_argument(
        "--yes",
        dest="yes",
        action="store_true",
        help=(
            "Skip the interactive confirmation prompt for --cleanup. "
            "Required when MURAL_NONINTERACTIVE=1."
        ),
    )
    migrate.add_argument(
        "--json",
        dest="json",
        action="store_true",
        help="Emit a JSON status envelope instead of human log lines.",
    )
    migrate.set_defaults(func=_cmd_auth_migrate)

    _add_resource_subcommands(sub)

    return parser


def _add_output_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--fields",
        default=None,
        help="Comma-separated dotted field paths to project from each record.",
    )
    parser.add_argument(
        "--format",
        default="json",
        choices=["json", "table"],
        help="Output format (default: json).",
    )


def _add_pagination_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help=(
            "Maximum total records to return (default: unbounded; paginate to "
            "exhaustion)."
        ),
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=_DEFAULT_PAGE_SIZE,
        help=(
            f"Per-page limit forwarded to Mural "
            f"(default: {_DEFAULT_PAGE_SIZE}, max {_MAX_PAGE_SIZE})."
        ),
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=None,
        help=(
            "Maximum number of API pages to fetch (default: unbounded). "
            "Use --max-pages 1 to disable pagination for debugging."
        ),
    )


def _add_xy(parser: argparse.ArgumentParser, *, required: bool = True) -> None:
    parser.add_argument("--x", type=float, required=required, help="X coordinate")
    parser.add_argument("--y", type=float, required=required, help="Y coordinate")
    parser.add_argument("--width", type=float, default=None, help="Width")
    parser.add_argument("--height", type=float, default=None, help="Height")


def _add_no_author_tag_flag(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--no-author-tag",
        dest="no_author_tag",
        action="store_true",
        help="Skip attaching the reserved 'authored-by-ai' tag to created widgets",
    )


def _add_author_guard_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--require-author-tag",
        dest="require_author_tag",
        action="store_true",
        help=(
            "Refuse to mutate widgets unless they carry the reserved "
            "'authored-by-ai' tag (use --force-human to override)"
        ),
    )
    parser.add_argument(
        "--force-human",
        dest="force_human",
        action="store_true",
        help="Override --require-author-tag and act on human-authored widgets",
    )


def _add_resource_subcommands(sub: argparse._SubParsersAction) -> None:
    workspace = sub.add_parser("workspace", help="Workspace operations")
    ws_sub = workspace.add_subparsers(dest="workspace_command", required=True)
    ws_list = ws_sub.add_parser("list", help="List workspaces")
    _add_output_flags(ws_list)
    _add_pagination_flags(ws_list)
    ws_list.set_defaults(func=_cmd_workspace_list)
    ws_get = ws_sub.add_parser("get", help="Get a workspace")
    ws_get.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(ws_get)
    ws_get.set_defaults(func=_cmd_workspace_get)

    ws_search = ws_sub.add_parser(
        "search", help="Full-text search murals in a workspace"
    )
    ws_search.add_argument("--workspace", default=None, help="Workspace id")
    ws_search.add_argument(
        "--query", required=True, help="Search query (`q` parameter)"
    )
    _add_output_flags(ws_search)
    _add_pagination_flags(ws_search)
    ws_search.set_defaults(func=_cmd_workspace_search)

    room = sub.add_parser("room", help="Room operations")
    room_sub = room.add_subparsers(dest="room_command", required=True)
    room_list = room_sub.add_parser("list", help="List rooms in a workspace")
    room_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(room_list)
    _add_pagination_flags(room_list)
    room_list.set_defaults(func=_cmd_room_list)
    room_get = room_sub.add_parser("get", help="Get a room")
    room_get.add_argument("--room", required=True, help="Room id")
    _add_output_flags(room_get)
    room_get.set_defaults(func=_cmd_room_get)
    room_create = room_sub.add_parser("create", help="Create a room in a workspace")
    room_create.add_argument("--workspace", default=None, help="Workspace id")
    room_create.add_argument("--name", required=True, help="Room name")
    room_create.add_argument(
        "--type",
        choices=["private", "open"],
        default="private",
        help="Room type (default: private)",
    )
    room_create.add_argument(
        "--description", default=None, help="Optional room description"
    )
    _add_output_flags(room_create)
    room_create.set_defaults(func=_cmd_room_create)

    mural_p = sub.add_parser("mural", help="Mural operations")
    mural_sub = mural_p.add_subparsers(dest="mural_command", required=True)
    mural_list = mural_sub.add_parser("list", help="List murals in a workspace")
    mural_list.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(mural_list)
    _add_pagination_flags(mural_list)
    mural_list.set_defaults(func=_cmd_mural_list)
    mural_get = mural_sub.add_parser("get", help="Get a mural")
    mural_get.add_argument("--mural", required=True, help="Mural id (workspace.slug)")
    _add_output_flags(mural_get)
    mural_get.set_defaults(func=_cmd_mural_get)

    mural_create = mural_sub.add_parser("create", help="Create a mural in a room")
    mural_create.add_argument("--room", required=True, help="Room id (integer)")
    mural_create.add_argument("--title", required=True, help="Mural title")
    _add_output_flags(mural_create)
    mural_create.set_defaults(func=_cmd_mural_create)

    mural_dup = mural_sub.add_parser(
        "duplicate", help="Duplicate a mural and return the new mural id"
    )
    mural_dup.add_argument("--mural", required=True, help="Source mural id")
    _add_output_flags(mural_dup)
    mural_dup.set_defaults(func=_cmd_mural_duplicate)

    mural_clone = mural_sub.add_parser(
        "clone-with-tags",
        help="Duplicate a mural and replay its tag manifest on the new mural",
    )
    mural_clone.add_argument("--mural", required=True, help="Source mural id")
    _add_output_flags(mural_clone)
    mural_clone.set_defaults(func=_cmd_clone_with_tags)

    mural_poll = mural_sub.add_parser(
        "poll", help="Poll a mural until a dotted-path condition matches"
    )
    mural_poll.add_argument("--mural", required=True, help="Mural id")
    mural_poll.add_argument(
        "--condition",
        required=True,
        help="Condition 'path op value' where op is == or !=",
    )
    mural_poll.add_argument(
        "--interval",
        type=float,
        default=POLL_DEFAULT_INTERVAL_S,
        help=f"Initial poll interval in seconds (default {POLL_DEFAULT_INTERVAL_S})",
    )
    mural_poll.add_argument(
        "--timeout",
        type=float,
        default=POLL_DEFAULT_TIMEOUT_S,
        help=f"Timeout in seconds (default {POLL_DEFAULT_TIMEOUT_S})",
    )
    _add_output_flags(mural_poll)
    mural_poll.set_defaults(func=_cmd_mural_poll)

    mural_archive = mural_sub.add_parser(
        "archive", help="Archive a mural (status=archived)"
    )
    mural_archive.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_archive)
    mural_archive.set_defaults(func=_cmd_mural_archive)

    mural_unarchive = mural_sub.add_parser(
        "unarchive", help="Unarchive a mural (status=active)"
    )
    mural_unarchive.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_unarchive)
    mural_unarchive.set_defaults(func=_cmd_mural_unarchive)

    mural_find = mural_sub.add_parser(
        "find", help="Search murals by title (trigram similarity)"
    )
    mural_find.add_argument("--workspace", default=None, help="Workspace id")
    mural_find.add_argument("--query", required=True, help="Search text")
    mural_find.add_argument(
        "--min-score", type=float, default=None, help="Minimum trigram score (0..1)"
    )
    mural_find.add_argument(
        "--limit", type=int, default=None, help="Maximum candidates to return"
    )
    _add_output_flags(mural_find)
    mural_find.set_defaults(func=_cmd_mural_find)

    mural_repair = mural_sub.add_parser(
        "repair-tag-drift", help="Re-assert reserved tags on widgets in a mural"
    )
    mural_repair.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(mural_repair)
    mural_repair.set_defaults(func=_cmd_mural_repair_tag_drift)

    template = sub.add_parser("template", help="Template operations")
    template_sub = template.add_subparsers(dest="template_command", required=True)

    tpl_inst = template_sub.add_parser(
        "instantiate", help="Create a new mural from a template"
    )
    tpl_inst.add_argument("--template", required=True, help="Template id")
    tpl_inst.add_argument("--workspace", default=None, help="Target workspace id")
    tpl_inst.add_argument("--room", default=None, help="Target room id")
    tpl_inst.add_argument("--name", default=None, help="Optional mural name")
    _add_output_flags(tpl_inst)
    tpl_inst.set_defaults(func=_cmd_template_instantiate)

    tpl_create = template_sub.add_parser(
        "create", help="Create a template from an existing mural"
    )
    tpl_create.add_argument("--mural", required=True, help="Source mural id")
    tpl_create.add_argument("--workspace", default=None, help="Target workspace id")
    tpl_create.add_argument("--room", default=None, help="Target room id")
    tpl_create.add_argument("--name", default=None, help="Optional template name")
    _add_output_flags(tpl_create)
    tpl_create.set_defaults(func=_cmd_template_create)

    tpl_list = template_sub.add_parser(
        "list", help="List known templates from the local registry"
    )
    tpl_list.add_argument("--workspace", default=None, help="Optional workspace filter")
    _add_output_flags(tpl_list)
    tpl_list.set_defaults(func=_cmd_template_list)

    widget = sub.add_parser("widget", help="Widget operations")
    widget_sub = widget.add_subparsers(dest="widget_command", required=True)

    w_list = widget_sub.add_parser("list", help="List widgets on a mural")
    w_list.add_argument("--mural", required=True, help="Mural id")
    w_list.add_argument("--type", default=None, help="Filter by widget type")
    w_list.add_argument("--parent-id", default=None, help="Filter by parent widget id")
    _add_output_flags(w_list)
    _add_pagination_flags(w_list)
    w_list.set_defaults(func=_cmd_widget_list)

    w_get = widget_sub.add_parser("get", help="Get a single widget")
    w_get.add_argument("--mural", required=True, help="Mural id")
    w_get.add_argument("--widget", required=True, help="Widget id")
    _add_output_flags(w_get)
    w_get.set_defaults(func=_cmd_widget_get)

    w_update = widget_sub.add_parser("update", help="Patch a widget with a JSON body")
    w_update.add_argument("--mural", required=True, help="Mural id")
    w_update.add_argument("--widget", required=True, help="Widget id")
    w_update.add_argument("--body", default=None, help="JSON patch body")
    w_update.add_argument(
        "--body-file",
        default=None,
        help=(
            "Path to a UTF-8 JSON file containing the patch body; "
            "mutually exclusive with --body"
        ),
    )
    w_update.add_argument(
        "--hyperlink", default=None, help="Optional URL to attach to the widget"
    )
    _add_author_guard_flags(w_update)
    _add_output_flags(w_update)
    w_update.set_defaults(func=_cmd_widget_update)

    w_delete = widget_sub.add_parser("delete", help="Delete a widget")
    w_delete.add_argument("--mural", required=True, help="Mural id")
    w_delete.add_argument("--widget", required=True, help="Widget id")
    _add_author_guard_flags(w_delete)
    w_delete.set_defaults(func=_cmd_widget_delete)

    w_create_bulk = widget_sub.add_parser(
        "create-bulk",
        help=(
            f"Create up to {MAX_BULK_WIDGETS} widgets from a JSON file via "
            "one POST per widget to the matching per-type endpoint"
        ),
    )
    w_create_bulk.add_argument("--mural", required=True, help="Mural id")
    w_create_bulk.add_argument(
        "--file",
        required=True,
        help="Path to a JSON file containing the widgets array",
    )
    w_create_bulk.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "Abort the run on the first per-widget failure "
            f"and exit {EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_no_author_tag_flag(w_create_bulk)
    _add_output_flags(w_create_bulk)
    w_create_bulk.set_defaults(func=_cmd_widget_create_bulk)

    w_update_bulk = widget_sub.add_parser(
        "update-bulk",
        help=(
            f"Update up to {MAX_BULK_WIDGETS} widgets from a JSON file with "
            "concurrent PATCH and per-widget retry"
        ),
    )
    w_update_bulk.add_argument("--mural", required=True, help="Mural id")
    w_update_bulk.add_argument(
        "--file",
        required=True,
        help=("Path to a JSON file containing an array of `{widget_id, body}` entries"),
    )
    w_update_bulk.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "Abort the run on the first per-widget failure and exit "
            f"{EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_author_guard_flags(w_update_bulk)
    _add_output_flags(w_update_bulk)
    w_update_bulk.set_defaults(func=_cmd_widget_update_bulk)

    w_diff = widget_sub.add_parser(
        "diff",
        help="Diff a local widget snapshot against the live mural state",
    )
    w_diff.add_argument("--mural", required=True, help="Mural id")
    w_diff.add_argument(
        "--file",
        required=True,
        help=(
            "Path to a JSON file containing a widgets array or an object "
            "with a 'widgets' array (the snapshot baseline)"
        ),
    )
    w_diff.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Push the snapshot to the live mural: create missing widgets, "
            "patch changed widgets to match the snapshot, and delete extras"
        ),
    )
    w_diff.add_argument(
        "--atomic",
        action="store_true",
        help=(
            "With --apply, abort on the first failure in any phase and exit "
            f"{EXIT_TEMPFAIL} (EX_TEMPFAIL)"
        ),
    )
    _add_output_flags(w_diff)
    w_diff.set_defaults(func=_cmd_widget_diff)

    w_create = widget_sub.add_parser("create", help="Create a widget by type")
    create_sub = w_create.add_subparsers(dest="widget_create_kind", required=True)

    sticky = create_sub.add_parser("sticky-note", help="Create a sticky-note widget")
    sticky.add_argument("--mural", required=True, help="Mural id")
    sticky.add_argument("--text", required=True, help="Sticky note text")
    sticky.add_argument(
        "--shape", default=None, help="Sticky shape (default: rectangle)"
    )
    sticky.add_argument("--style", default=None, help="JSON style overrides")
    sticky.add_argument("--hyperlink", default=None, help="Optional URL")
    sticky.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(sticky)
    _add_no_author_tag_flag(sticky)
    _add_output_flags(sticky)
    sticky.set_defaults(func=_cmd_widget_create_sticky_note)

    textbox = create_sub.add_parser("textbox", help="Create a textbox widget")
    textbox.add_argument("--mural", required=True, help="Mural id")
    textbox.add_argument("--text", required=True, help="Textbox text")
    textbox.add_argument("--style", default=None, help="JSON style overrides")
    textbox.add_argument("--hyperlink", default=None, help="Optional URL")
    textbox.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(textbox)
    _add_no_author_tag_flag(textbox)
    _add_output_flags(textbox)
    textbox.set_defaults(func=_cmd_widget_create_textbox)

    shape = create_sub.add_parser("shape", help="Create a shape widget")
    shape.add_argument("--mural", required=True, help="Mural id")
    shape.add_argument("--shape", required=True, help="Shape kind")
    shape.add_argument("--text", default=None, help="Optional shape text")
    shape.add_argument("--style", default=None, help="JSON style overrides")
    shape.add_argument("--hyperlink", default=None, help="Optional URL")
    shape.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(shape)
    _add_no_author_tag_flag(shape)
    _add_output_flags(shape)
    shape.set_defaults(func=_cmd_widget_create_shape)

    arrow = create_sub.add_parser("arrow", help="Create an arrow widget")
    arrow.add_argument("--mural", required=True, help="Mural id")
    arrow.add_argument("--x1", type=float, required=True, help="Start x")
    arrow.add_argument("--y1", type=float, required=True, help="Start y")
    arrow.add_argument("--x2", type=float, required=True, help="End x")
    arrow.add_argument("--y2", type=float, required=True, help="End y")
    arrow.add_argument("--style", default=None, help="JSON style overrides")
    arrow.add_argument("--hyperlink", default=None, help="Optional URL")
    arrow.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_no_author_tag_flag(arrow)
    _add_output_flags(arrow)
    arrow.set_defaults(func=_cmd_widget_create_arrow)

    image = create_sub.add_parser("image", help="Upload an image and create a widget")
    image.add_argument("--mural", required=True, help="Mural id")
    image.add_argument("--file", required=True, help="Local image file path")
    image.add_argument(
        "--alt-text",
        dest="alt_text",
        required=True,
        help=(
            "Alternative text describing the image (WCAG 2.2 SC 1.1.1). "
            "Required; must be a non-empty string."
        ),
    )
    image.add_argument("--title", default=None, help="Optional image title")
    image.add_argument("--hyperlink", default=None, help="Optional URL")
    image.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_xy(image)
    _add_no_author_tag_flag(image)
    _add_output_flags(image)
    image.set_defaults(func=_cmd_widget_create_image)

    w_get_ctx = widget_sub.add_parser(
        "get-with-context", help="Get a widget plus area-chain and siblings"
    )
    w_get_ctx.add_argument("--mural", required=True, help="Mural id")
    w_get_ctx.add_argument("--widget", required=True, help="Widget id")
    _add_output_flags(w_get_ctx)
    w_get_ctx.set_defaults(func=_cmd_widget_get_with_context)

    w_list_ctx = widget_sub.add_parser(
        "list-with-context", help="List widgets including area-chain ancestry"
    )
    w_list_ctx.add_argument("--mural", required=True, help="Mural id")
    w_list_ctx.add_argument("--type", default=None, help="Filter by widget type")
    w_list_ctx.add_argument(
        "--parent-id", default=None, help="Filter by parent widget id"
    )
    _add_output_flags(w_list_ctx)
    _add_pagination_flags(w_list_ctx)
    w_list_ctx.set_defaults(func=_cmd_widget_list_with_context)

    tag = sub.add_parser("tag", help="Tag operations")
    tag_sub = tag.add_subparsers(dest="tag_command", required=True)

    t_list = tag_sub.add_parser("list", help="List tags on a mural")
    t_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(t_list)
    _add_pagination_flags(t_list)
    t_list.set_defaults(func=_cmd_tag_list)

    t_create = tag_sub.add_parser("create", help="Create a tag on a mural")
    t_create.add_argument("--mural", required=True, help="Mural id")
    t_create.add_argument("--text", required=True, help="Tag text (max 25 chars)")
    t_create.add_argument("--color", default=None, help="Optional color token")
    _add_output_flags(t_create)
    t_create.set_defaults(func=_cmd_tag_create)

    t_apply = tag_sub.add_parser("apply", help="Apply a tag to a widget")
    t_apply.add_argument("--mural", required=True, help="Mural id")
    t_apply.add_argument("--widget", required=True, help="Widget id")
    t_apply.add_argument("--tag", default=None, help="Existing tag id")
    t_apply.add_argument("--text", default=None, help="Tag text (creates if missing)")
    t_apply.add_argument("--color", default=None, help="Optional color token")
    _add_output_flags(t_apply)
    t_apply.set_defaults(func=_cmd_tag_apply)

    t_remove = tag_sub.add_parser("remove", help="Remove a tag from a widget")
    t_remove.add_argument("--mural", required=True, help="Mural id")
    t_remove.add_argument("--widget", required=True, help="Widget id")
    t_remove.add_argument("--tag", required=True, help="Tag id to remove")
    t_remove.add_argument(
        "--force-reserved",
        dest="force_reserved",
        action="store_true",
        help="Allow removal of reserved tags such as 'authored-by-ai'",
    )
    _add_output_flags(t_remove)
    t_remove.set_defaults(func=_cmd_tag_remove)

    area = sub.add_parser("area", help="Area operations")
    area_sub = area.add_subparsers(dest="area_command", required=True)

    a_list = area_sub.add_parser("list", help="List areas on a mural")
    a_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(a_list)
    _add_pagination_flags(a_list)
    a_list.set_defaults(func=_cmd_area_list)

    a_get = area_sub.add_parser("get", help="Get a single area (caches result)")
    a_get.add_argument("--mural", required=True, help="Mural id")
    a_get.add_argument("--area", required=True, help="Area id")
    _add_output_flags(a_get)
    a_get.set_defaults(func=_cmd_area_get)

    a_create = area_sub.add_parser("create", help="Create an area on a mural")
    a_create.add_argument("--mural", required=True, help="Mural id")
    a_create.add_argument("--title", required=True, help="Area title")
    a_create.add_argument("--x", type=float, default=None, help="Optional x")
    a_create.add_argument("--y", type=float, default=None, help="Optional y")
    a_create.add_argument("--width", type=float, default=None, help="Optional width")
    a_create.add_argument("--height", type=float, default=None, help="Optional height")
    a_create.add_argument(
        "--layout",
        default=None,
        choices=sorted(_VALID_AREA_LAYOUTS),
        help="Layout: free | column | row",
    )
    a_create.add_argument(
        "--parent-id",
        dest="parent_id",
        type=_parse_parent_id,
        default=None,
        help="Optional parent area id",
    )
    _add_output_flags(a_create)
    a_create.set_defaults(func=_cmd_area_create)

    a_probe = area_sub.add_parser(
        "probe",
        help="Probe area z-order visibility",
    )
    a_probe.add_argument("--mural", required=True, help="Mural id")
    a_probe.add_argument("--area", required=True, help="Area id")
    _add_output_flags(a_probe)
    a_probe.set_defaults(func=_cmd_area_probe)

    layout = sub.add_parser("layout", help="Layout placement operations")
    layout_sub = layout.add_subparsers(dest="layout_command", required=True)
    for _name, _func, _needs_columns in (
        ("grid", _cmd_layout_grid, True),
        ("cluster", _cmd_layout_cluster, False),
        ("column", _cmd_layout_column, False),
        ("row", _cmd_layout_row, False),
    ):
        _p = layout_sub.add_parser(_name, help=f"Place widgets in a {_name} layout")
        _p.add_argument("--mural", required=True, help="Mural id")
        _p.add_argument("--area", required=True, help="Area id")
        _p.add_argument(
            "--widgets",
            required=True,
            help="Widgets payload (JSON array string, @path, or - for stdin)",
        )
        _p.add_argument(
            "--cell-width", type=float, default=None, help="Optional cell width"
        )
        _p.add_argument(
            "--cell-height", type=float, default=None, help="Optional cell height"
        )
        _p.add_argument("--gutter", type=float, default=None, help="Optional gutter")
        _p.add_argument("--origin", default=None, help='Optional origin "x,y"')
        if _needs_columns:
            _p.add_argument("--columns", type=int, required=True, help="Column count")
        _add_output_flags(_p)
        _p.set_defaults(func=_func)

    compose = sub.add_parser("compose", help="Composite Design Thinking operations")
    compose_sub = compose.add_subparsers(dest="compose_command", required=True)

    c_boot = compose_sub.add_parser(
        "bootstrap-dt-board", help="Create or reuse a Design Thinking mural"
    )
    c_boot.add_argument("--workspace", required=True, help="Workspace id")
    c_boot.add_argument("--room", required=True, help="Room id")
    c_boot.add_argument("--method", type=int, required=True, help="Method number 1..9")
    c_boot.add_argument("--title", default=None, help="Optional mural title")
    c_boot.add_argument(
        "--override-path",
        dest="override_path",
        default=None,
        help="Optional path to dt-sections override YAML",
    )
    _add_output_flags(c_boot)
    c_boot.set_defaults(func=_cmd_compose_bootstrap_dt_board)

    c_uxb = compose_sub.add_parser(
        "bootstrap-ux-board",
        help="Add the five UX research areas to an existing mural",
    )
    c_uxb.add_argument("--workspace", required=True, help="Workspace id")
    c_uxb.add_argument("--mural", required=True, help="Target mural id")
    _add_output_flags(c_uxb)
    c_uxb.set_defaults(func=_cmd_compose_bootstrap_ux_board)

    c_pop = compose_sub.add_parser(
        "populate-dt-section", help="Populate a Design Thinking section area"
    )
    c_pop.add_argument("--mural", required=True, help="Mural id")
    c_pop.add_argument("--area", required=True, help="Area id")
    c_pop.add_argument("--method", type=int, required=True, help="Method number 1..9")
    c_pop.add_argument("--section", required=True, help="Section name")
    c_pop.add_argument(
        "--items",
        required=True,
        help="Items payload (JSON array string, @path, or - for stdin)",
    )
    _add_output_flags(c_pop)
    c_pop.set_defaults(func=_cmd_compose_populate_dt_section)

    c_aff = compose_sub.add_parser(
        "affinity-cluster", help="Place pre-clustered items as affinity clusters"
    )
    c_aff.add_argument("--mural", required=True, help="Mural id")
    c_aff.add_argument("--area", required=True, help="Area id")
    c_aff.add_argument(
        "--clusters",
        required=True,
        help="Clusters payload (JSON array string, @path, or - for stdin)",
    )
    _add_output_flags(c_aff)
    c_aff.set_defaults(func=_cmd_compose_affinity_cluster)

    c_park = compose_sub.add_parser(
        "parking-lot-sweep", help="List parked widgets in a mural"
    )
    c_park.add_argument("--mural", required=True, help="Mural id")
    c_park.add_argument("--area", default=None, help="Optional area id")
    c_park.add_argument("--tag", default=None, help="Optional tag id override")
    _add_output_flags(c_park)
    c_park.set_defaults(func=_cmd_compose_parking_lot_sweep)

    c_sum = compose_sub.add_parser("workspace-summary", help="Summarize a workspace")
    c_sum.add_argument("--workspace", default=None, help="Workspace id")
    _add_output_flags(c_sum)
    c_sum.set_defaults(func=_cmd_compose_workspace_summary)

    lineage = sub.add_parser("lineage", help="Lineage operations")
    lineage_sub = lineage.add_subparsers(dest="lineage_command", required=True)

    l_lookup = lineage_sub.add_parser(
        "lookup", help="Look up widgets by Design Thinking lineage marker"
    )
    l_lookup.add_argument("--mural-id", required=True, help="Mural id")
    l_lookup.add_argument("--run-id", default=None, help="Filter by run id")
    l_lookup.add_argument(
        "--method", type=int, default=None, help="Filter by DT method (1..9)"
    )
    l_lookup.add_argument("--section", default=None, help="Filter by section name")
    _add_output_flags(l_lookup)
    l_lookup.set_defaults(func=_cmd_mural_lineage_lookup)

    spatial = sub.add_parser("spatial", help="Spatial query operations")
    spatial_sub = spatial.add_subparsers(dest="spatial_command", required=True)

    s_in_shape = spatial_sub.add_parser(
        "widgets-in-shape",
        help="Filter widgets contained by a shape (frame, area, or widget)",
    )
    s_in_shape.add_argument("--mural-id", required=True, help="Mural id")
    s_in_shape.add_argument(
        "--shape-id", required=True, help="Container shape widget id"
    )
    s_in_shape.add_argument(
        "--mode",
        default="center",
        choices=["center", "bbox"],
        help="Inclusion test (default: center).",
    )
    s_in_shape.add_argument(
        "--rotation-aware",
        dest="rotation_aware",
        action="store_true",
        help=(
            "Force rotation-aware AABB expansion of the shape; overrides "
            "MURAL_SPATIAL_ROTATION_ENABLED when set."
        ),
    )
    _add_output_flags(s_in_shape)
    _add_pagination_flags(s_in_shape)
    s_in_shape.set_defaults(func=_cmd_spatial_widgets_in_shape)

    s_in_region = spatial_sub.add_parser(
        "widgets-in-region",
        help="Filter widgets inside an axis-aligned rectangle",
    )
    s_in_region.add_argument("--mural-id", required=True, help="Mural id")
    s_in_region.add_argument("--x", type=float, required=True, help="Region origin X")
    s_in_region.add_argument("--y", type=float, required=True, help="Region origin Y")
    s_in_region.add_argument(
        "--w",
        type=float,
        required=True,
        help="Region width (sign-corrected via safe_rect).",
    )
    s_in_region.add_argument(
        "--h",
        type=float,
        required=True,
        help="Region height (sign-corrected via safe_rect).",
    )
    s_in_region.add_argument(
        "--mode",
        default="center",
        choices=["center", "bbox"],
        help="Inclusion test (default: center).",
    )
    _add_output_flags(s_in_region)
    _add_pagination_flags(s_in_region)
    s_in_region.set_defaults(func=_cmd_spatial_widgets_in_region)

    s_pairwise = spatial_sub.add_parser(
        "pairwise-overlaps",
        help="Find overlapping widget pairs across the mural",
    )
    s_pairwise.add_argument("--mural-id", required=True, help="Mural id")
    s_pairwise.add_argument(
        "--predicate",
        default="intersects",
        choices=["intersects", "contains"],
        help="AABB relationship test (default: intersects).",
    )
    s_pairwise.add_argument(
        "--rotation-aware",
        dest="rotation_aware",
        action="store_true",
        help=(
            "Force rotation-aware AABB expansion of widgets; overrides "
            "MURAL_SPATIAL_ROTATION_ENABLED when set."
        ),
    )
    _add_output_flags(s_pairwise)
    _add_pagination_flags(s_pairwise)
    s_pairwise.set_defaults(func=_cmd_spatial_pairwise_overlaps)

    s_cluster = spatial_sub.add_parser(
        "cluster",
        help="Cluster widgets by spatial proximity using DBSCAN",
    )
    s_cluster.add_argument("--mural-id", required=True, help="Mural id")
    s_cluster.add_argument(
        "--eps-px",
        dest="eps_px",
        type=float,
        default=120.0,
        help="DBSCAN neighborhood radius in pixels (default: 120.0).",
    )
    s_cluster.add_argument(
        "--min-samples",
        dest="min_samples",
        type=int,
        default=2,
        help=(
            "DBSCAN density threshold; min_samples=1 keeps isolated "
            "widgets as singleton clusters (default: 2)."
        ),
    )
    _add_output_flags(s_cluster)
    _add_pagination_flags(s_cluster)
    s_cluster.set_defaults(func=_cmd_spatial_cluster)

    s_sort_axis = spatial_sub.add_parser(
        "sort-along-axis",
        help="Sort widgets by AABB-center projection along an axis",
    )
    s_sort_axis.add_argument("--mural-id", required=True, help="Mural id")
    s_sort_axis.add_argument(
        "--axis",
        default="x",
        choices=["x", "y", "diagonal"],
        help="Axis to project centers onto (default: x).",
    )
    s_sort_axis.add_argument(
        "--origin-x",
        dest="origin_x",
        type=float,
        default=None,
        help=(
            "Optional anchor X used with --origin-y to sort by signed "
            "projection from an origin along the axis."
        ),
    )
    s_sort_axis.add_argument(
        "--origin-y",
        dest="origin_y",
        type=float,
        default=None,
        help=(
            "Optional anchor Y used with --origin-x to sort by signed "
            "projection from an origin along the axis."
        ),
    )
    _add_output_flags(s_sort_axis)
    _add_pagination_flags(s_sort_axis)
    s_sort_axis.set_defaults(func=_cmd_spatial_sort_along_axis)

    s_arrow_graph = spatial_sub.add_parser(
        "arrow-graph",
        help="Build a directed multigraph from arrow widgets",
    )
    s_arrow_graph.add_argument("--mural-id", required=True, help="Mural id")
    s_arrow_graph.add_argument(
        "--snap-radius",
        type=float,
        default=24.0,
        help=(
            "Maximum Euclidean distance (pixels) from an arrow endpoint "
            "to a widget AABB center for snapping (default 24)"
        ),
    )
    s_arrow_graph.add_argument(
        "--format",
        choices=["summary", "full", "dot"],
        default="summary",
        help=(
            "Output format: summary JSON (default), full JSON with the "
            "arrow widget attached to each edge, or Graphviz dot text"
        ),
    )
    s_arrow_graph.add_argument(
        "--output",
        default=None,
        help="Optional path to write rendered output instead of stdout",
    )
    _add_pagination_flags(s_arrow_graph)
    s_arrow_graph.set_defaults(func=_cmd_spatial_arrow_graph)

    voting = sub.add_parser("voting", help="Voting session operations")
    voting_sub = voting.add_subparsers(dest="voting_command", required=True)

    v_create = voting_sub.add_parser(
        "session-create", help="Create a voting session from a JSON file"
    )
    v_create.add_argument("--mural", required=True, help="Mural id")
    v_create.add_argument(
        "--file", required=True, help="Path to JSON body for the session"
    )
    _add_output_flags(v_create)
    v_create.set_defaults(func=_cmd_voting_session_create)

    v_get = voting_sub.add_parser("session-get", help="Get a voting session")
    v_get.add_argument("--mural", required=True, help="Mural id")
    v_get.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_get)
    v_get.set_defaults(func=_cmd_voting_session_get)

    v_list = voting_sub.add_parser(
        "session-list", help="List voting sessions on a mural"
    )
    v_list.add_argument("--mural", required=True, help="Mural id")
    _add_output_flags(v_list)
    _add_pagination_flags(v_list)
    v_list.set_defaults(func=_cmd_voting_session_list)

    v_open = voting_sub.add_parser(
        "session-open", help="Open a voting session (status=active)"
    )
    v_open.add_argument("--mural", required=True, help="Mural id")
    v_open.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_open)
    v_open.set_defaults(func=_cmd_voting_session_open)

    v_close = voting_sub.add_parser(
        "session-close", help="Close a voting session (status=closed)"
    )
    v_close.add_argument("--mural", required=True, help="Mural id")
    v_close.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_close)
    v_close.set_defaults(func=_cmd_voting_session_close)

    v_delete = voting_sub.add_parser("session-delete", help="Delete a voting session")
    v_delete.add_argument("--mural", required=True, help="Mural id")
    v_delete.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_delete)
    v_delete.set_defaults(func=_cmd_voting_session_delete)

    v_results = voting_sub.add_parser("results", help="Fetch voting session results")
    v_results.add_argument("--mural", required=True, help="Mural id")
    v_results.add_argument("--session", required=True, help="Voting session id")
    _add_output_flags(v_results)
    v_results.set_defaults(func=_cmd_voting_results)

    v_poll = voting_sub.add_parser(
        "poll", help="Poll a voting session until a condition matches"
    )
    v_poll.add_argument("--mural", required=True, help="Mural id")
    v_poll.add_argument("--session", required=True, help="Voting session id")
    v_poll.add_argument(
        "--condition",
        required=True,
        help="Dotted-path condition (e.g. `status==closed`)",
    )
    v_poll.add_argument(
        "--interval",
        type=float,
        default=POLL_DEFAULT_INTERVAL_S,
        help=f"Poll interval seconds (default {POLL_DEFAULT_INTERVAL_S})",
    )
    v_poll.add_argument(
        "--timeout",
        type=float,
        default=POLL_DEFAULT_TIMEOUT_S,
        help=f"Poll timeout seconds (default {POLL_DEFAULT_TIMEOUT_S})",
    )
    _add_output_flags(v_poll)
    v_poll.set_defaults(func=_cmd_voting_poll)
