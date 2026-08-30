#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Reversible, audited upsert of Copilot OTel settings into a JSONC settings file.

Every key, type, and value combination is checked against a schema before a
byte is written. Non-target bytes are preserved exactly, the previous file is
backed up, the write is staged and replaced atomically, and a result that fails
to parse restores the backup.

    settings_upsert.py --settings <path> --set key=value [--set ...]      # dry run
    settings_upsert.py --settings <path> --set key=value --apply          # write

Schema provenance is recorded in SCHEMA_SOURCE. Re-verify it against the
installed build before trusting this tool on a newer extension; the settings
surface follows the extension, not this file.
"""

from __future__ import annotations

import argparse
import datetime
import json
import logging
import os
import pathlib
import shutil
import sys
import urllib.parse

from _input_policy import DEFAULT_ALLOWED_PORTS, PolicyError, check_url

LOGGER = logging.getLogger("settings_upsert")

# Exit codes. 2 marks a refused request, distinct from a crash; 130 is the
# shell convention for an interrupt.
EXIT_OK = 0
EXIT_REFUSED = 2
EXIT_INTERRUPTED = 130

# Backups accumulate on every apply. Bounded so a settings directory does not
# fill with copies of a file that may name an output path.
BACKUP_RETENTION = 5

UTF8_BOM = "\ufeff"

# Provenance for the schema below.
SCHEMA_SOURCE = {
    "artifact": "GitHub Copilot Chat extension manifest (package.json)",
    "extension": "GitHub.copilot-chat",
    "version": "0.52.0",
    "retrieved_from": "contributes.configuration[].properties of the installed build",
    "verified": "2026-08-13",
}

# The OTel settings this build declares, with their declared types. A key that
# is not here is refused rather than written: writing a key the build does not
# declare produces a setting that is silently inert.
SCHEMA: dict[str, type | tuple[type, ...]] = {
    "github.copilot.chat.otel.enabled": bool,
    "github.copilot.chat.otel.exporterType": str,
    "github.copilot.chat.otel.otlpEndpoint": str,
    "github.copilot.chat.otel.captureContent": bool,
    "github.copilot.chat.otel.maxAttributeSizeChars": int,
    "github.copilot.chat.otel.outfile": str,
    "github.copilot.chat.otel.dbSpanExporter.enabled": bool,
}

EXPORTER_TYPES = frozenset({"otlp-grpc", "otlp-http", "console", "file"})

# Keys whose value can never be summarized safely in an audit record.
SENSITIVE_KEYS = frozenset({"github.copilot.chat.otel.outfile"})

# Keys whose value is a URL. The audit record keeps the authority so an
# operator can tell which destination was configured, and drops the path,
# query, and fragment, which is where a token or an identifier would sit.
ENDPOINT_KEYS = frozenset({"github.copilot.chat.otel.otlpEndpoint"})


class SettingsError(ValueError):
    """Raised when a requested edit is refused. Nothing has been written."""


def parse_assignment(raw: str) -> tuple[str, object]:
    """Split a key=value argument and coerce the value to its declared type."""
    key, separator, text = raw.partition("=")
    if not separator:
        raise SettingsError(f"expected key=value, got '{raw}'")
    key = key.strip()
    if key not in SCHEMA:
        raise SettingsError(
            f"refusing unknown key '{key}'. This build declares: {', '.join(sorted(SCHEMA))}"
        )

    expected = SCHEMA[key]
    text = text.strip()
    if expected is bool:
        if text not in ("true", "false"):
            raise SettingsError(f"{key} is boolean; expected true or false, got '{text}'")
        return key, text == "true"
    if expected is int:
        try:
            return key, int(text)
        except ValueError as exc:
            raise SettingsError(f"{key} is integer; got '{text}'") from exc
    return key, text


def repository_root() -> pathlib.Path:
    """The checkout this script is part of, or the skill directory if none."""
    here = pathlib.Path(__file__).resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists():
            return candidate
    return here.parents[1]


def check_outfile(outfile: str) -> None:
    """Refuse an output path that would write telemetry somewhere unsafe.

    A relative path resolves against whatever directory VS Code happened to
    start in, which is not a location anyone chose. A path inside this checkout
    puts captured spans where a commit would pick them up.

    Absoluteness is judged under both path flavours, because a settings file is
    routinely authored on one platform for another and `/var/log/spans.jsonl`
    is a deliberate absolute path even when this script runs on Windows.
    """
    expanded = os.path.expanduser(outfile)
    # Judged on the supplied text: constructing a `pathlib.Path` first would
    # rewrite `/var/log/spans.jsonl` into a rootless Windows path and report a
    # deliberate POSIX absolute path as relative.
    if not (
        pathlib.PurePosixPath(expanded).is_absolute()
        or pathlib.PureWindowsPath(expanded).is_absolute()
    ):
        raise SettingsError(
            f"outfile must be an absolute path, got '{outfile}'. A relative path "
            "resolves against the editor's working directory."
        )

    candidate = pathlib.Path(expanded)
    if not candidate.is_absolute():
        # A path absolute only under the other platform's rules cannot name a
        # location inside this checkout.
        return
    root = repository_root()
    resolved = candidate.resolve()
    if resolved == root or root in resolved.parents:
        raise SettingsError(
            f"refusing an outfile inside this repository: {resolved}. Captured "
            "telemetry would be a commit away from being published."
        )


def check_policy(
    values: dict[str, object],
    *,
    existing: dict[str, object] | None = None,
    allow_remote_endpoint: bool = False,
) -> None:
    """Apply the rules the schema alone cannot express.

    Every rule is evaluated against the settings that would result, not against
    this invocation's arguments. Two invocations that each pass alone can
    otherwise combine into a document no invocation ever validated: setting
    `exporterType` while the file already holds an off-policy `otlpEndpoint`
    writes that endpoint's document without ever checking it.

    A pre-existing value that fails policy is refused rather than carried
    through, and the refusal says the value was already there. That is the same
    posture `outfile` and `maxAttributeSizeChars` already had; `captureContent`
    and `otlpEndpoint` were the two rules that looked only at the invocation.
    """
    merged = {**(existing or {}), **values}

    if values.get("github.copilot.chat.otel.captureContent") is True:
        raise SettingsError(
            "refusing to enable captureContent. It puts prompt text, responses, system "
            "instructions, and tool arguments onto spans. Set it by hand, deliberately."
        )

    if merged.get("github.copilot.chat.otel.captureContent") is True:
        raise SettingsError(
            "refusing to write while captureContent is already enabled in this file. This "
            "invocation did not set it, but the document it would produce still puts prompt "
            "text, responses, system instructions, and tool arguments onto spans. Turn it off, "
            "or make this edit by hand."
        )

    exporter = merged.get("github.copilot.chat.otel.exporterType")
    if exporter is not None and exporter not in EXPORTER_TYPES:
        raise SettingsError(
            f"exporterType must be one of {', '.join(sorted(EXPORTER_TYPES))}, got '{exporter}'"
        )

    endpoint = merged.get("github.copilot.chat.otel.otlpEndpoint")
    if endpoint:
        try:
            check_url(
                str(endpoint),
                allow_remote=allow_remote_endpoint,
                allowed_ports=DEFAULT_ALLOWED_PORTS,
            )
        except PolicyError as exc:
            if "github.copilot.chat.otel.otlpEndpoint" in values:
                raise SettingsError(f"otlpEndpoint rejected: {exc}") from exc
            raise SettingsError(
                "refusing to write: this file already holds an otlpEndpoint that this "
                f"invocation did not set, and it fails policy ({exc}). Correct or remove "
                "that value first."
            ) from exc

    outfile = merged.get("github.copilot.chat.otel.outfile")
    if outfile:
        check_outfile(str(outfile))
        if exporter is not None and str(exporter).startswith("otlp-"):
            raise SettingsError(
                "outfile forces the file exporter, which contradicts the resulting "
                f"exporterType '{exporter}'. Set one or the other."
            )

    size = merged.get("github.copilot.chat.otel.maxAttributeSizeChars")
    if size is not None and int(size) < 0:
        raise SettingsError("maxAttributeSizeChars cannot be negative")


def strip_jsonc(text: str) -> str:
    """Return the text with comments and trailing commas blanked out.

    Offsets are preserved: nothing is removed, and every blanked byte becomes a
    space in the same position, so spans found by the scanner still line up
    with the original bytes.

    Trailing commas are handled by this scanner rather than a regex, which
    cannot distinguish a comma inside a string literal from a structural one.
    """
    out = list(text)
    index, length = 0, len(text)
    # Position of the most recent structural comma with only blank output
    # between it and the current cursor. A trailing comma is one that is still
    # a candidate when a closing bracket arrives.
    comma_candidate: int | None = None
    while index < length:
        char = text[index]
        if char == '"':
            comma_candidate = None
            index += 1
            while index < length:
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == '"':
                    break
                index += 1
            index += 1
            continue
        if char == "/" and index + 1 < length:
            if text[index + 1] == "/":
                while index < length and text[index] != "\n":
                    out[index] = " "
                    index += 1
                continue
            if text[index + 1] == "*":
                while index < length and not (
                    text[index] == "*" and text[index + 1 : index + 2] == "/"
                ):
                    if text[index] != "\n":
                        out[index] = " "
                    index += 1
                for offset in range(index, min(index + 2, length)):
                    out[offset] = " "
                index += 2
                continue
        if char == ",":
            comma_candidate = index
        elif char in "}]":
            if comma_candidate is not None:
                out[comma_candidate] = " "
            comma_candidate = None
        elif not char.isspace():
            comma_candidate = None
        index += 1
    return "".join(out)


def top_level_spans(text: str) -> dict[str, tuple[int, int]]:
    """Map each top-level key to the (start, end) offsets of its value."""
    scan = strip_jsonc(text)
    spans: dict[str, tuple[int, int]] = {}
    index, length, depth = 0, len(scan), 0
    while index < length:
        char = scan[index]
        if char == '"':
            start = index + 1
            index += 1
            while index < length:
                if scan[index] == "\\":
                    index += 2
                    continue
                if scan[index] == '"':
                    break
                index += 1
            key = scan[start:index]
            index += 1
            if depth == 1:
                cursor = index
                while cursor < length and scan[cursor] in " \t\r\n":
                    cursor += 1
                if cursor < length and scan[cursor] == ":":
                    cursor += 1
                    while cursor < length and scan[cursor] in " \t\r\n":
                        cursor += 1
                    value_start = cursor
                    value_depth = 0
                    while cursor < length:
                        current = scan[cursor]
                        if current == '"':
                            cursor += 1
                            while cursor < length:
                                if scan[cursor] == "\\":
                                    cursor += 2
                                    continue
                                if scan[cursor] == '"':
                                    break
                                cursor += 1
                        elif current in "{[":
                            value_depth += 1
                        elif current in "}]":
                            if value_depth == 0:
                                break
                            value_depth -= 1
                        elif current == "," and value_depth == 0:
                            break
                        cursor += 1
                    spans[key] = (value_start, len(scan[:cursor].rstrip()))
                    index = cursor
            continue
        if char in "{[":
            depth += 1
        elif char in "}]":
            depth -= 1
        index += 1
    return spans


def upsert(text: str, values: dict[str, object]) -> str:
    """Return the text with each key set, changing nothing else."""
    result = text
    for key, value in values.items():
        encoded = json.dumps(value)
        spans = top_level_spans(result)
        if key in spans:
            start, end = spans[key]
            result = result[:start] + encoded + result[end:]
            continue
        closing = result.rstrip().rfind("}")
        if closing == -1:
            raise SettingsError("settings file has no top-level object to edit")
        head = result[:closing].rstrip()
        # A document that already ends its last entry with a trailing comma
        # needs no second one; emitting both produces `,,`, which no amount of
        # trailing-comma tolerance makes valid.
        separator = "" if head.endswith(("{", ",")) else ","
        result = f'{head}{separator}\n  "{key}": {encoded}\n{result[closing:]}'
    return result


def summarize(key: str, value: object) -> object:
    """Return an audit-safe rendering of a value.

    The record exists to show what changed, not to become a second copy of the
    settings. A path is reduced to its shape and an endpoint to its authority,
    so the record stays useful without retaining more than it needs.
    """
    if value is None:
        return None
    if key in SENSITIVE_KEYS:
        return f"<{type(value).__name__} of length {len(str(value))}>"
    if key in ENDPOINT_KEYS and isinstance(value, str):
        return summarize_endpoint(value)
    return value


def summarize_endpoint(value: str) -> str:
    """Reduce a URL to scheme, host, and port.

    The authority is not safe to keep whole: `https://user:token@host:4318`
    puts a credential in the netloc, and an audit record that copies it turns a
    record of what changed into a second place the credential lives. An OTLP
    endpoint's path and query are operator-supplied and can carry a tenant
    identifier or a token for the same reason. Host and port answer the only
    question the record is kept for, which is where telemetry was pointed.
    """
    parsed = urllib.parse.urlparse(value)
    try:
        host, port = parsed.hostname, parsed.port
    except ValueError:
        return f"<str of length {len(value)}>"
    if not parsed.scheme or not host:
        return f"<str of length {len(value)}>"
    return f"{parsed.scheme}://{host}:{port}" if port else f"{parsed.scheme}://{host}"


def write_audit(audit_path: pathlib.Path, record: dict[str, object]) -> None:
    """Append one audit line. Values are summarized, never copied verbatim."""
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    with audit_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def backup_path_for(
    settings_path: pathlib.Path, *, now: datetime.datetime | None = None
) -> pathlib.Path:
    """Return a backup path that sorts after every existing backup.

    The timestamp is to the second and the counter is always present and
    zero-padded, so name order is creation order. The counter resumes after the
    highest index already used for this second rather than filling the lowest
    free slot: retention can delete a low index, and reusing it would place a
    newer backup ahead of an older one in the order retention reads.

    The counter only orders backups within one second, so a clock that steps
    backwards would name the newest backup lowest and retention would delete it
    first. A regressing stamp is held at the newest one on disk.
    """
    stamp = (now or datetime.datetime.now(datetime.UTC)).strftime("%Y%m%dT%H%M%SZ")
    existing = existing_backups(settings_path)
    if existing:
        newest = existing[-1].name[len(f"{settings_path.name}.") :].rsplit("-", 1)[0]
        stamp = max(stamp, newest)
    prefix = f"{settings_path.name}.{stamp}-"
    used = []
    for sibling in settings_path.parent.glob(f"{prefix}*.bak"):
        index = sibling.name[len(prefix) : -len(".bak")]
        if index.isdigit():
            used.append(int(index))
    collision = max(used) + 1 if used else 0
    candidate = settings_path.with_name(f"{prefix}{collision:03d}.bak")
    while candidate.exists():
        collision += 1
        candidate = settings_path.with_name(f"{prefix}{collision:03d}.bak")
    return candidate


def existing_backups(settings_path: pathlib.Path) -> list[pathlib.Path]:
    """Backups this tool wrote for one settings file, oldest first.

    Sorted by name, which carries the stamp this tool assigned; a copy
    operation does not preserve modification-time ordering.
    """
    return sorted(settings_path.parent.glob(f"{settings_path.name}.*.bak"), key=lambda p: p.name)


def prune_backups(
    settings_path: pathlib.Path, *, retain: int = BACKUP_RETENTION
) -> list[pathlib.Path]:
    """Delete all but the newest `retain` backups and return what was removed.

    Unbounded retention was the earlier behaviour, which left a growing set of
    copies of a file whose contents include an output path and an endpoint.
    Removals are returned so the caller can report them rather than deleting
    silently.
    """
    backups = existing_backups(settings_path)
    removed: list[pathlib.Path] = []
    for stale in backups[: max(len(backups) - retain, 0)]:
        try:
            stale.unlink()
        except OSError as exc:
            LOGGER.warning("could not remove old backup %s: %s", stale, exc)
            continue
        removed.append(stale)
    return removed


def read_settings(settings_path: pathlib.Path) -> tuple[str, str]:
    """Return the document's byte-order mark and its text without it.

    VS Code writes `settings.json` with a BOM on some installs. Decoding with
    `utf-8-sig` and writing back without it silently rewrites a byte the editor
    put there; keeping the BOM as a separate value means the write puts back
    exactly what it found.

    A missing, empty, whitespace-only, or comments-only file is an editable
    empty object. All four are documents a person can reasonably have, and
    refusing them meant the tool could not perform the first edit on a settings
    file that had never held a setting.
    """
    if not settings_path.is_file():
        return "", "{}\n"

    try:
        raw = settings_path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        raise SettingsError(f"cannot read {settings_path}: {exc}") from exc

    bom = UTF8_BOM if settings_path.read_bytes().startswith(b"\xef\xbb\xbf") else ""
    if not strip_jsonc(raw).strip():
        # Comments are preserved: they are the only content this document has,
        # and discarding them would be the unrelated change this tool refuses
        # to make everywhere else.
        return bom, f"{raw.rstrip()}\n{{}}\n" if raw.strip() else "{}\n"
    return bom, raw


def write_atomically(settings_path: pathlib.Path, text: str) -> None:
    """Stage beside the target, validate the staged bytes, then replace.

    Writing in place truncates first, so an interrupted write leaves a settings
    file that is neither the old document nor the new one. Staging in the same
    directory keeps the replace on one filesystem, which is what makes it
    atomic.
    """
    staged = settings_path.with_name(f"{settings_path.name}.{os.getpid()}.staged")
    try:
        staged.write_text(text, encoding="utf-8")
        json.loads(strip_jsonc(staged.read_text(encoding="utf-8-sig")) or "{}")
        os.replace(staged, settings_path)
    except BaseException:
        staged.unlink(missing_ok=True)
        raise


def apply_changes(
    settings_path: pathlib.Path,
    values: dict[str, object],
    *,
    apply: bool,
    audit_path: pathlib.Path | None = None,
    allow_remote_endpoint: bool = False,
) -> str:
    """Validate, then optionally write, leaving the original intact on any failure."""
    bom, original = read_settings(settings_path)

    try:
        before = json.loads(strip_jsonc(original) or "{}")
    except json.JSONDecodeError as exc:
        raise SettingsError(f"existing settings file is not valid JSONC: {exc}") from exc

    check_policy(values, existing=before, allow_remote_endpoint=allow_remote_endpoint)

    updated = upsert(original, values)

    try:
        after = json.loads(strip_jsonc(updated) or "{}")
    except json.JSONDecodeError as exc:
        raise SettingsError(f"refusing to write: the result would not parse ({exc})") from exc

    untouched_before = {k: v for k, v in before.items() if k not in values}
    untouched_after = {k: v for k, v in after.items() if k not in values}
    if untouched_before != untouched_after:
        raise SettingsError("refusing to write: the edit would change unrelated settings")
    for key, value in values.items():
        if after.get(key) != value:
            raise SettingsError(f"refusing to write: {key} did not take the requested value")

    if not apply:
        return updated

    backup_path = backup_path_for(settings_path)
    if settings_path.is_file():
        shutil.copy2(settings_path, backup_path)
    write_atomically(settings_path, bom + updated)

    for removed in prune_backups(settings_path):
        LOGGER.info("removed old backup %s", removed)

    if audit_path is not None:
        write_audit(
            audit_path,
            {
                "timestamp": datetime.datetime.now(datetime.UTC).isoformat(),
                "settings_file": str(settings_path),
                "backup_file": str(backup_path),
                "schema_version": SCHEMA_SOURCE["version"],
                "changes": {
                    key: {
                        "from": summarize(key, before.get(key)),
                        "to": summarize(key, value),
                    }
                    for key, value in values.items()
                },
            },
        )
    return updated


def resolve_audit_path(argument: str, settings_path: pathlib.Path) -> pathlib.Path:
    """Resolve the audit path against the caller's directory, refusing aliases.

    The audit path used to be contained to the settings directory, which
    silently relocated an operator's chosen path into the one directory where
    an appended JSON line can destroy the file being edited. Resolving from the
    current directory keeps the operator's choice, and the aliases that would
    corrupt settings or a backup are refused outright instead.
    """
    path = pathlib.Path(argument).expanduser()
    if not path.is_absolute():
        path = pathlib.Path.cwd() / path
    path = path.resolve()

    if path == settings_path.resolve():
        raise SettingsError("refusing an audit path that is the settings file itself")
    if path.name.endswith(".bak") and path.parent == settings_path.resolve().parent:
        raise SettingsError(f"refusing an audit path that is a settings backup: {path}")
    if path.is_dir():
        raise SettingsError(f"audit path is a directory: {path}")
    return path


def silence_broken_pipe() -> None:
    """Point stdout at the null device after the reader has gone away.

    Without this the interpreter reports the same broken pipe again while
    flushing during shutdown, turning a pager quit into a second error message
    and a non-zero status.
    """
    devnull = os.open(os.devnull, os.O_WRONLY)
    try:
        os.dup2(devnull, sys.stdout.fileno())
    finally:
        os.close(devnull)


def configure_logging(verbose: bool = False) -> None:
    """Send diagnostics to stderr so stdout carries only the document."""
    logging.basicConfig(
        stream=sys.stderr,
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", required=True, help="path to the settings.json to edit")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE")
    parser.add_argument("--apply", action="store_true", help="write; omit for a dry run")
    parser.add_argument("--audit", help="append an audit record to this path")
    parser.add_argument(
        "--allow-remote-endpoint",
        action="store_true",
        help="permit an https endpoint outside this machine; loopback is the default",
    )
    parser.add_argument("--verbose", action="store_true", help="log at debug level")
    args = parser.parse_args(argv)
    configure_logging(args.verbose)

    try:
        values: dict[str, object] = {}
        for assignment in args.set:
            key, value = parse_assignment(assignment)
            if key in values:
                raise SettingsError(f"duplicate key '{key}'")
            values[key] = value
        if not values:
            raise SettingsError("nothing to do: pass at least one --set key=value")

        settings_path = pathlib.Path(args.settings).expanduser()
        audit_path = resolve_audit_path(args.audit, settings_path) if args.audit else None
        updated = apply_changes(
            settings_path,
            values,
            apply=args.apply,
            audit_path=audit_path,
            allow_remote_endpoint=args.allow_remote_endpoint,
        )
    except (SettingsError, PolicyError) as exc:
        print(str(exc), file=sys.stderr)
        return EXIT_REFUSED
    except KeyboardInterrupt:
        return EXIT_INTERRUPTED

    try:
        if not args.apply:
            print(updated)
            print("\n(dry run; pass --apply to write)", file=sys.stderr)
        sys.stdout.flush()
    except BrokenPipeError:
        # A closed reader is the pager quitting, not a failure of the edit.
        silence_broken_pipe()
        return EXIT_OK
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
