# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Command-line interface for the RPI tracking audit."""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import sys
from collections import Counter
from datetime import date, datetime
from pathlib import Path

from ._audit import Audit, UsageError
from ._discovery import is_link
from ._markdown import plural, redact, strip_controls
from ._render import render_markdown, to_json
from ._rules import SEVERITY_ORDER, TRACKING_DIR

VERSION = "0.0.0"
EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
DEFAULT_STALE_DAYS = 30
AS_OF = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        prog="rpi_tracking_audit",
        description=(
            "Audit the RPI tracking artifacts under .copilot-tracking/ against the "
            "hve-core RPI conventions. Read-only: the audit changes no file it reads."
        ),
    )
    parser.add_argument(
        "root",
        nargs="?",
        type=Path,
        default=None,
        help="repository or workspace root (default: current directory)",
    )
    parser.add_argument(
        "--md", type=Path, help="write the Markdown report to this file"
    )
    parser.add_argument("--json", type=Path, help="write the JSON report to this file")
    parser.add_argument(
        "--brief", action="store_true", help="chat-sized Markdown report"
    )
    parser.add_argument("--task", help="report one task slug only")
    parser.add_argument("--file", type=Path, help="audit one tracking artifact alone")
    parser.add_argument(
        "--stale-days",
        type=int,
        default=None,
        help=(
            "days without a change after which an open task is stale (default: 30; 0 "
            "disables)"
        ),
    )
    parser.add_argument("--as-of", help="reference date YYYY-MM-DD (default: today)")
    parser.add_argument(
        "--max-rows", type=int, default=25, help="rows per table before truncation"
    )
    parser.add_argument(
        "--fail-on",
        choices=tuple(SEVERITY_ORDER),
        help=(
            "exit with 1 when a finding of this severity or higher is reported "
            "(default: never)"
        ),
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    return parser


def _validate(args: argparse.Namespace) -> date:
    as_of = date.today()
    if args.as_of is not None:
        try:
            if not AS_OF.match(args.as_of):
                raise ValueError(args.as_of)
            as_of = datetime.strptime(args.as_of, "%Y-%m-%d").date()
        except ValueError as exc:
            raise UsageError("--as-of expects YYYY-MM-DD") from exc
    if args.max_rows < 1:
        raise UsageError("--max-rows must be at least 1")
    if args.stale_days is not None and args.stale_days < 0:
        raise UsageError("--stale-days must be 0 or more")
    if args.file and args.task:
        raise UsageError("--task cannot be combined with --file")
    if args.file and args.root is not None:
        raise UsageError("--file audits one file; it cannot be combined with a root")
    if args.file and args.stale_days is not None:
        raise UsageError(
            "--stale-days needs a workspace run; it cannot be combined with --file"
        )
    if args.task is not None and not args.task.strip():
        raise UsageError("--task needs a task slug")
    if args.md and args.json and _same_target(args.md, args.json):
        raise UsageError("--md and --json name the same file")
    return as_of


def _absolute(path: Path) -> Path:
    return Path(os.path.normpath(path.absolute()))


def _same_file(first: Path, second: Path) -> bool:
    """Whether two existing paths are one file, whatever their spelling or case."""
    try:
        return os.path.samefile(first, second)
    except OSError:
        return False


def _same_target(first: Path, second: Path) -> bool:
    """Whether two report paths would be one file, including on a case-blind disk."""
    one, two = _absolute(first), _absolute(second)
    return one == two or (
        _name_key(one.name) == _name_key(two.name)
        and _same_file(one.parent, two.parent)
    )


def _name_key(name: str) -> str:
    """A file name as a disk that ignores case and trailing dots and spaces sees it."""
    return name.rstrip(". ").lower() or name.lower()


def _check_report_path(path: Path, root: Path, inputs: list[Path]) -> None:
    """Refuse a report path that would change a file the audit reads.

    The audit is read-only over tracking folders. A path with a `.copilot-tracking`
    component, in any letter case and after links are resolved, is refused whichever
    workspace it belongs to; a single-file run does not know the workspace, and a
    nested tracking folder is still one. The audited folder is also recognized by file
    identity, so another name for it is refused too. A report path that is a link, a
    file with other hard links, or one of the audit's own inputs is refused as well.
    """
    target = _absolute(path)
    tracking = root / TRACKING_DIR
    # links in the path are resolved first, so a linked parent folder cannot hide it
    probe = Path(os.path.realpath(target))
    if probe.parts[1:2] == (".vol",):
        # macOS names any folder by volume and file ID here, which hides where it is
        raise UsageError(
            f"report path {path} names a folder by its file ID; give its folder path"
        )
    inside = any(part.lower() == TRACKING_DIR for part in (*target.parts, *probe.parts))
    while not inside:
        inside = _same_file(probe, tracking)
        if probe.parent == probe:
            break
        probe = probe.parent
    if inside:
        raise UsageError(
            f"report path {path} is inside a {TRACKING_DIR}/ folder; the audit writes "
            "no file there"
        )
    if is_link(target):
        raise UsageError(
            f"report path {path} is a symbolic link; the audit follows no links"
        )
    if not target.exists():
        return
    if not target.is_file():
        raise UsageError(f"report path {path} is not a regular file")
    if any(_same_file(target, source) for source in inputs):
        raise UsageError(f"report path {path} is a file the audit reads")
    if target.stat().st_nlink > 1:
        raise UsageError(
            f"report path {path} has other hard links; the audit would change them too"
        )


def _write_reports(reports: list[tuple[Path, bytes]]) -> None:
    """Write each report to a temporary file beside its target, then move it in place.

    Nothing is written through an existing file, so a hard link or a link planted after
    the check is not followed, and a failure while writing leaves every existing file
    untouched. A report that replaces a file keeps that file's permissions.
    """
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    flags |= getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_BINARY", 0)
    staged: list[tuple[Path, Path]] = []
    try:
        for path, data in reports:
            target = _absolute(path)
            temporary = target.with_name(f".{target.name}.{os.getpid()}.tmp")
            descriptor = os.open(temporary, flags, 0o666)
            # only a file this run created is ever removed
            staged.append((temporary, target))
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(data)
            try:
                os.chmod(temporary, stat.S_IMODE(os.stat(target).st_mode))
            except OSError:
                pass  # a new report takes the default permissions
        for temporary, target in staged:
            os.replace(temporary, target)
    finally:
        for temporary, _ in staged:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass  # moved into place
            except OSError:
                # a read-only mode copied from the file it was to replace
                try:
                    os.chmod(temporary, stat.S_IREAD | stat.S_IWRITE)
                    temporary.unlink()
                except OSError:
                    pass


def run(args: argparse.Namespace) -> int:
    """Run the audit and write the requested reports."""
    as_of = _validate(args)
    single_path = None
    if args.file:
        if not args.file.is_file():
            raise UsageError(f"not a file: {args.file}")
        path = Path(os.path.normpath(args.file.absolute()))
        audit = Audit(path.parent, as_of, 0, single=True)
        audit.run_single(path)
        single_path = str(args.file)
    else:
        root = _absolute(args.root or Path("."))
        if not root.is_dir():
            raise UsageError(f"not a folder: {root}")
        stale_days = DEFAULT_STALE_DAYS if args.stale_days is None else args.stale_days
        audit = Audit(root, as_of, stale_days)
        audit.run_workspace()
        if args.task is not None:
            audit.filter_task(args.task)
    audit.finalize()
    inputs = [audit.root / ".gitignore"]
    if args.file:
        inputs.append(_absolute(args.file))
    for report in (args.md, args.json):
        if report:
            _check_report_path(report, audit.root, inputs)

    # every quoted value is redacted and escaped where it is written; no pass rewrites
    # the finished report, because that could undo the escaping
    md = render_markdown(
        audit,
        VERSION,
        brief=args.brief,
        max_rows=args.max_rows,
        single_path=single_path,
    )
    # every report is built and encoded before any is written, and each is written
    # through a temporary file, so a failure while writing leaves no partial report
    reports: list[tuple[Path, bytes]] = []
    if args.md:
        reports.append((args.md, md.encode("utf-8", errors="replace")))
    if args.json:
        payload = json.dumps(
            to_json(audit, VERSION, single_path), indent=2, default=str, allow_nan=False
        )
        reports.append((args.json, (payload + "\n").encode("utf-8", errors="replace")))
    _write_reports(reports)
    if not args.md and not args.json:
        sys.stdout.write(md)
        sys.stdout.flush()
        return _gate(audit, args.fail_on)
    sev = Counter(f.severity for f in audit.findings)
    legacy = (
        f", {plural(len(audit.legacy_tasks), 'legacy task')}"
        if audit.legacy_tasks
        else ""
    )
    written = " and ".join(str(p) for p in (args.md, args.json) if p)
    sys.stdout.write(
        f"{plural(len(audit.findings), 'finding')}, {sev['high']} high, "
        f"{sev['medium']} medium; "
        f"{plural(len(audit.board), 'task')}{legacy}. Wrote {written}\n"
    )
    sys.stdout.flush()
    return _gate(audit, args.fail_on)


def _gate(audit: Audit, fail_on: str | None) -> int:
    """The exit code: success unless --fail-on names a severity the findings reach."""
    if fail_on is None:
        return EXIT_SUCCESS
    reached = [
        f
        for f in audit.findings
        if SEVERITY_ORDER[f.severity] <= SEVERITY_ORDER[fail_on]
    ]
    if not reached:
        return EXIT_SUCCESS
    print(
        f"{plural(len(reached), 'finding')} at or above `{fail_on}` (--fail-on "
        f"{fail_on})",
        file=sys.stderr,
    )
    return EXIT_FAILURE


def _report_error(message: str) -> None:
    """Print an error on one line; names in it can carry control characters."""
    text = redact(strip_controls(message).replace("\n", " ").replace("\t", " "))
    print(f"Error: {text}", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    """Main entry point with error handling."""
    args = create_parser().parse_args(argv)
    if sys.stdout is None:
        # started with stdout closed: there is nowhere to print, which is not an error
        sys.stdout = open(os.devnull, "w", encoding="utf-8")  # noqa: SIM115
    if hasattr(sys.stdout, "reconfigure"):
        # A console that cannot encode a character gets a replacement, not a crash. A
        # pipe or a redirected file gets UTF-8, as report files do, whatever the
        # platform's default encoding is, unless the caller chose one.
        if sys.stdout.isatty() or os.environ.get("PYTHONIOENCODING"):
            sys.stdout.reconfigure(errors="replace")
        else:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    try:
        return run(args)
    except UsageError as exc:
        _report_error(str(exc))
        return EXIT_ERROR
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        # the reader closed the pipe: point stdout at the null device so the
        # interpreter's
        # exit-time flush cannot raise a second time
        try:
            os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        except (OSError, ValueError):
            pass
        return EXIT_FAILURE
    except OSError as exc:
        _report_error(str(exc))
        return EXIT_FAILURE
    except (RecursionError, ValueError) as exc:
        # no input should reach here; report it as a failure, never as a traceback
        print(
            f"Error: the audit could not finish ({type(exc).__name__})", file=sys.stderr
        )
        return EXIT_FAILURE
