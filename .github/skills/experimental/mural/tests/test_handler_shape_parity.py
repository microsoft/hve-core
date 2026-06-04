# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""AST-based contract tests for CLI/tool JSON output shapes.

Statically parses every ``*.py`` file under the ``mural`` package and compares the
literal-dict output shapes of paired ``_cmd_<name>`` and ``_op_<name>`` handlers.
Catches the bug class where both sides build independent literal dicts that drift in
their top-level key sets (the original instances were ``auth_status`` and
``widget_delete``).

Conservative by design: a pair is only compared when each side has exactly one
statically-extractable literal dict shape. Passthrough returns of API calls,
list comprehensions, ``**`` unpacking, and heterogeneous output paths produce no
extractable shape and are skipped.
"""

from __future__ import annotations

import ast
import pathlib

import pytest

MURAL_PKG = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "mural"

# CLI commands that have no tool counterpart by design.
ALLOWED_CLI_ONLY: frozenset[str] = frozenset(
    {
        "auth_login",
        "auth_setup",
        "auth_bootstrap",
        "auth_list",
        "auth_use",
        "auth_logout",
        "auth_migrate",
        "widget_diff",
        "spatial_not_implemented",
    }
)

# Tool handlers that have no CLI counterpart by design.
ALLOWED_TOOL_ONLY: frozenset[str] = frozenset({"voting_run"})

# Internal helpers under the ``_op_`` prefix that are not first-class tools.
TOOL_HELPERS: frozenset[str] = frozenset({"layout"})

# Pair-name aliasing: ``_op_<key>`` corresponds to ``_cmd_<value>``.
NAME_QUIRKS: dict[str, str] = {
    "workspace_summary": "compose_workspace_summary",
    "parking_lot_sweep": "compose_parking_lot_sweep",
    "bootstrap_dt_board": "compose_bootstrap_dt_board",
    "bootstrap_ux_board": "compose_bootstrap_ux_board",
    "populate_dt_section": "compose_populate_dt_section",
    "create_affinity_cluster": "compose_affinity_cluster",
    "repair_tag_drift": "mural_repair_tag_drift",
}


def _dict_top_level_keys(node: ast.Dict) -> frozenset[str] | None:
    """Return top-level string keys of a dict literal, or ``None`` if not stable.

    A shape is considered unstable (and skipped) when the dict contains any
    ``**`` unpack (``key is None``) or any non-string-constant key.
    """
    keys: set[str] = set()
    for k in node.keys:
        if k is None:
            return None
        if isinstance(k, ast.Constant) and isinstance(k.value, str):
            keys.add(k.value)
        else:
            return None
    return frozenset(keys)


def _collect_cmd_output_shapes(func: ast.FunctionDef) -> list[frozenset[str]]:
    """Return literal-dict output shapes emitted by a ``_cmd_*`` handler.

    Recognized output channels:
        * ``print(json.dumps(<dict-literal>, ...))``
        * ``_emit_record(<dict-literal>, ...)``
        * ``_emit_records([<dict-literal>, ...], ...)``

    Only directly-attached literal ``ast.Dict`` nodes are collected; dicts nested
    inside other calls (e.g. a ``payload`` argument passed to ``_op_X``) are not
    output and are intentionally ignored.
    """
    shapes: list[frozenset[str]] = []
    for node in ast.walk(func):
        if not isinstance(node, ast.Call):
            continue
        callee = node.func
        if not isinstance(callee, ast.Name):
            continue
        if callee.id == "print" and node.args:
            inner = node.args[0]
            if (
                isinstance(inner, ast.Call)
                and isinstance(inner.func, ast.Attribute)
                and inner.func.attr == "dumps"
                and isinstance(inner.func.value, ast.Name)
                and inner.func.value.id == "json"
                and inner.args
                and isinstance(inner.args[0], ast.Dict)
            ):
                keys = _dict_top_level_keys(inner.args[0])
                if keys is not None:
                    shapes.append(keys)
        elif (
            callee.id == "_emit_record"
            and node.args
            and isinstance(node.args[0], ast.Dict)
        ):
            keys = _dict_top_level_keys(node.args[0])
            if keys is not None:
                shapes.append(keys)
        elif (
            callee.id == "_emit_records"
            and node.args
            and isinstance(node.args[0], ast.List)
        ):
            for elt in node.args[0].elts:
                if isinstance(elt, ast.Dict):
                    keys = _dict_top_level_keys(elt)
                    if keys is not None:
                        shapes.append(keys)
    return shapes


def _collect_tool_output_shapes(func: ast.FunctionDef) -> list[frozenset[str]]:
    """Return literal-dict shapes returned by a ``_op_*`` handler.

    Only ``return <dict-literal>`` patterns are collected; returns of call
    expressions, comprehensions, and names are skipped (no static shape).
    """
    shapes: list[frozenset[str]] = []
    for node in ast.walk(func):
        if isinstance(node, ast.Return) and isinstance(node.value, ast.Dict):
            keys = _dict_top_level_keys(node.value)
            if keys is not None:
                shapes.append(keys)
    return shapes


def _parse_handlers() -> tuple[dict[str, ast.FunctionDef], dict[str, ast.FunctionDef]]:
    """Return ``({cmd_basename: node}, {tool_basename: node})`` from ``mural`` pkg.

    Walks every ``*.py`` file under ``scripts/mural/`` and aggregates handler
    definitions across all submodules, so that the parity contract holds after
    the source is split into a package.
    """
    if not MURAL_PKG.is_dir():
        raise FileNotFoundError(
            f"mural package not found at {MURAL_PKG}; "
            "expected a Python package directory"
        )
    cmds: dict[str, ast.FunctionDef] = {}
    tools: dict[str, ast.FunctionDef] = {}
    for path in sorted(MURAL_PKG.rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in tree.body:
            if not isinstance(node, ast.FunctionDef):
                continue
            if node.name.startswith("_cmd_"):
                cmds[node.name[len("_cmd_") :]] = node
            elif node.name.startswith("_op_"):
                tools[node.name[len("_op_") :]] = node
    return cmds, tools


@pytest.fixture(scope="module")
def handlers() -> tuple[dict[str, ast.FunctionDef], dict[str, ast.FunctionDef]]:
    return _parse_handlers()


def test_no_unaccounted_cli_handlers(
    handlers: tuple[dict[str, ast.FunctionDef], dict[str, ast.FunctionDef]],
) -> None:
    """Every ``_cmd_*`` pairs with a ``_op_*`` or appears in ``ALLOWED_CLI_ONLY``."""
    cmds, tools = handlers
    cmd_to_tool: dict[str, str] = {cmd: tool for tool, cmd in NAME_QUIRKS.items()}
    unaccounted = sorted(
        cmd
        for cmd in cmds
        if cmd not in ALLOWED_CLI_ONLY and cmd_to_tool.get(cmd, cmd) not in tools
    )
    assert not unaccounted, (
        "_cmd_* handlers without a paired _op_* and not in ALLOWED_CLI_ONLY: "
        f"{unaccounted}. Either add a paired tool, register a name quirk, "
        "or update ALLOWED_CLI_ONLY."
    )


def test_no_unaccounted_tool_handlers(
    handlers: tuple[dict[str, ast.FunctionDef], dict[str, ast.FunctionDef]],
) -> None:
    """Every ``_op_*`` pairs with a ``_cmd_*`` or is exempt via the allowlists."""
    cmds, tools = handlers
    unaccounted = sorted(
        tool
        for tool in tools
        if tool not in ALLOWED_TOOL_ONLY
        and tool not in TOOL_HELPERS
        and NAME_QUIRKS.get(tool, tool) not in cmds
    )
    assert not unaccounted, (
        "_op_* handlers without a paired _cmd_* and not exempt: "
        f"{unaccounted}. Add a paired command, register a name quirk, "
        "or update ALLOWED_TOOL_ONLY / TOOL_HELPERS."
    )


def test_handler_pair_shape_parity(
    handlers: tuple[dict[str, ast.FunctionDef], dict[str, ast.FunctionDef]],
) -> None:
    """Paired handlers with comparable literal-dict shapes share top-level keys."""
    cmds, tools = handlers
    drifts: list[str] = []
    for tool_name, tool_node in tools.items():
        if tool_name in ALLOWED_TOOL_ONLY or tool_name in TOOL_HELPERS:
            continue
        cmd_name = NAME_QUIRKS.get(tool_name, tool_name)
        cmd_node = cmds.get(cmd_name)
        if cmd_node is None:
            continue
        cmd_set = set(_collect_cmd_output_shapes(cmd_node))
        tool_set = set(_collect_tool_output_shapes(tool_node))
        if len(cmd_set) != 1 or len(tool_set) != 1:
            continue
        cmd_keys = next(iter(cmd_set))
        tool_keys = next(iter(tool_set))
        if cmd_keys != tool_keys:
            only_cmd = sorted(cmd_keys - tool_keys)
            only_tool = sorted(tool_keys - cmd_keys)
            drifts.append(
                f"  _cmd_{cmd_name} vs _op_{tool_name}: "
                f"only in CLI: {only_cmd}, only in tool: {only_tool}"
            )
    assert not drifts, (
        "CLI/tool handler pairs emit different top-level JSON keys:\n"
        + "\n".join(drifts)
        + "\nAlign the literal-dict shapes on both sides."
    )
