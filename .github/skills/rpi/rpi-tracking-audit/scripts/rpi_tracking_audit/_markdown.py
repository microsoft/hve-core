# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Markdown parsing, redaction, and small text helpers for the RPI tracking audit."""

from __future__ import annotations

import re
from bisect import bisect_left, bisect_right
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from ._rules import (
    ANSI_ESCAPE,
    BACKTICK_RUN,
    BOLD_WRAP,
    BULLET_FIELD,
    CHANGES_IN_MAP,
    CODE_TAG_START,
    CONTROL_CHARS,
    EMPTY_BULLET,
    FENCE,
    HARD_CONTROLS,
    HEADING,
    HTML_TAG_START,
    INVISIBLE_CHARS,
    LABEL_BLOCK,
    LINE_REF_ANCHOR,
    LINE_REF_PHRASE,
    LINE_REF_TOKEN,
    LIST_CAP,
    LONG_LINE,
    MARKER,
    MARKER_LOOSE,
    MD_LINK,
    NEGATION_BEFORE,
    PLACEHOLDER,
    PRIVATE_KEY_BEGIN,
    PRIVATE_KEY_END,
    PRIVATE_KEY_SPAN,
    PRIVATE_KEY_TAIL,
    QUALIFIED_BEFORE,
    SECRET_KEY,
    SECRET_PATTERNS,
    SURROGATES,
    TABLE_SEP,
    ZERO_WIDTH_SPACE,
)


def read_text_checked(path: Path) -> tuple[str, str | None]:
    """The file as UTF-8 with normalized newlines, or '' and the read error.

    Control characters other than newline and tab are replaced or removed here, so a
    value that only takes a credential's shape once they are gone is already in that
    shape when the text is redacted and scanned.
    """
    try:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError as exc:
        return "", exc.strerror or type(exc).__name__
    return strip_controls(text.replace("\r\n", "\n").replace("\r", "\n")), None


MAX_NESTING = 64
# control characters on one line that are tried in every combination of neighbours
MAX_SPLIT_CONTROLS = 4
_CODE_SPAN = re.compile(r"(`[^`]+`)")
NORMAL, FENCE_LINE, FENCED, COMMENTED = range(4)


def strip_controls(text: str) -> str:
    """Replace control characters other than newline and tab; drop invisible ones.

    Artifact text can carry terminal escape sequences and bare carriage returns; neither
    may reach a console or start a new Markdown block in the report. Characters that
    take no space, such as bidirectional overrides, are removed. A control character
    inside a credential-shaped value is removed as well, so the value is whole when it
    is redacted and scanned.
    """
    text = INVISIBLE_CHARS.sub("", text)
    if "\x1b" in text or "\x9b" in text:
        # a colour sequence around a token would leave its letter beside the token
        text = ANSI_ESCAPE.sub("\x1b", text)
    if HARD_CONTROLS.search(text):
        text = "\n".join(_join_split_credentials(line) for line in text.split("\n"))
    return CONTROL_CHARS.sub(" ", text)


def _join_split_credentials(line: str) -> str:
    """Drop the control characters that sit inside a credential-shaped value.

    Every run of neighbouring control characters is tried as the inside of one value,
    with the other control characters standing as spaces, so one may split a token
    while another separates it from the text before. Only the characters inside a
    match are dropped; the rest stay and become spaces. A line with more than
    MAX_SPLIT_CONTROLS of them is tried only with all of them removed.
    """
    controls = [m.start() for m in HARD_CONTROLS.finditer(line)]
    if not controls:
        return line
    count = len(controls)
    runs = [(0, count)]
    if count <= MAX_SPLIT_CONTROLS:
        runs += [
            (first, last)
            for first in range(count)
            for last in range(first + 1, count + 1)
            if (first, last) != (0, count)
        ]
    spaced = HARD_CONTROLS.sub(" ", line)
    drop: set[int] = set()
    for first, last in runs:
        removed = controls[first:last]
        pieces, pos = [], 0
        for index in removed:
            pieces.append(spaced[pos:index])
            pos = index + 1
        pieces.append(spaced[pos:])
        view = "".join(pieces)
        for _, pat in SECRET_PATTERNS:
            for match in pat.finditer(view):
                lo = _line_index(removed, match.start())
                hi = _line_index(removed, match.end() - 1)
                drop.update(
                    removed[bisect_right(removed, lo) : bisect_left(removed, hi)]
                )
    if not drop:
        return line
    return "".join(ch for i, ch in enumerate(line) if i not in drop)


def _line_index(controls: list[int], joined_index: int) -> int:
    """A character's position in the line, given its position without `controls`."""
    # controls[k] - k is how many kept characters come before control k
    lo, hi = 0, len(controls)
    while lo < hi:
        mid = (lo + hi) // 2
        if controls[mid] - mid <= joined_index:
            lo = mid + 1
        else:
            hi = mid
    return joined_index + lo


def escape_inline(text: object) -> str:
    """Redact and escape a value written into a report line outside a table.

    Control characters and newlines become spaces, credential-shaped values are
    replaced, backslashes are doubled so the text
    cannot escape the report's own escapes, and runs of two or more backticks become an
    apostrophe. Outside code spans `<` before a tag name, images, and links are
    escaped, and a backtick left without a partner becomes an apostrophe, so the result
    is balanced and cannot pair with a backtick in the text written beside it. Inside a
    code span the same syntax is broken with a zero-width space, so it stays inert
    even where a renderer, or a later change to the line, does not treat the span as
    code.
    """
    value = strip_controls(str(text)).replace("\n", " ").replace("\t", " ")
    # redaction comes after the characters are settled and before any escaping, so a
    # placeholder is escaped like the rest and nothing rewrites the line afterwards
    value = redact(value)
    # with no longer runs left, single backticks pair left to right here exactly as a
    # Markdown renderer pairs them
    value = BACKTICK_RUN.sub("'", value)
    parts = _CODE_SPAN.split(value.replace("\\", "\\\\"))
    return "".join(
        _defuse_code(part) if i % 2 else _neutralize(part).replace("`", "'")
        for i, part in enumerate(parts)
    )


def md_escape(text: object) -> str:
    """Escape a value for a Markdown table cell: escape_inline, then the pipes.

    Backslashes are doubled before pipes are escaped, so an artifact's own `\\|` cannot
    end the cell.
    """
    return escape_inline(text).replace("|", "\\|")


def plural(count: int, noun: str, plural_noun: str | None = None) -> str:
    """Format a count with the singular or plural noun."""
    return f"{count} {noun if count == 1 else (plural_noun or noun + 's')}"


def capped(items: Iterable[str], cap: int = LIST_CAP, sep: str = ", ") -> str:
    """Join items, listing at most `cap` and counting the rest."""
    items = list(items)
    if len(items) <= cap:
        return sep.join(items)
    return sep.join(items[:cap]) + f" and {len(items) - cap} more"


def redact(text: str) -> str:
    """Replace credential-shaped values with a labeled placeholder.

    The line count is preserved so line numbers stay valid.
    """
    # a lone surrogate, as a JSON escape can produce, cannot be written as UTF-8
    text = _redact_key_blocks(SURROGATES.sub("\ufffd", text))
    # a credential written straight after another one can be bounded only once the
    # first is replaced, so the patterns run again while they still change the text
    for _ in range(3):
        before = text
        for label, pat in SECRET_PATTERNS:
            text = pat.sub(f"[redacted {label}]", text)
        if text == before:
            break
    return text


def _neutralize(text: str) -> str:
    """Escape raw HTML, images, and links in text that sits outside a code span."""
    text = HTML_TAG_START.sub(r"\\<", text)
    return text.replace("![", "!\\[").replace("](", "]\\(")


def _defuse_code(text: str) -> str:
    """Break tag and link syntax inside a code span without changing how it reads.

    A zero-width space after `<` and between `](` is invisible in rendered code. A
    comment such as `<!-- rpi:phase id=P01 -->` is left whole, so a marker quoted in a
    finding can be copied as it is.
    """
    text = CODE_TAG_START.sub("<" + ZERO_WIDTH_SPACE, text)
    return text.replace("](", "]" + ZERO_WIDTH_SPACE + "(")


def _redact_key_blocks(text: str) -> str:
    """Replace each private key block in one forward pass.

    A block runs from its BEGIN line to an END line within PRIVATE_KEY_SPAN characters.
    Without one, the key material after the BEGIN line is replaced instead: armor
    headers and the base64 runs that follow. The bounded search keeps the pass linear
    and stops a quoted BEGIN from hiding text up to an unrelated END.
    """
    out: list[str] = []
    pos = 0
    while True:
        begin = PRIVATE_KEY_BEGIN.search(text, pos)
        if begin is None:
            break
        end = PRIVATE_KEY_END.search(text, begin.end(), begin.end() + PRIVATE_KEY_SPAN)
        # a heading between the two lines means they are two mentions, not one block
        if end is not None and "\n#" in text[begin.end() : end.start()]:
            end = None
        if end is None:
            stop = PRIVATE_KEY_TAIL.match(text, begin.end()).end()  # type: ignore[union-attr]
        else:
            stop = end.end()
        out.append(text[pos : begin.start()])
        out.append(
            "[redacted private key block]"
            + "\n" * text.count("\n", begin.start(), stop)
        )
        pos = stop
    out.append(text[pos:])
    return "".join(out)


def nesting_depth(obj: Any, limit: int = MAX_NESTING) -> int:
    """The nesting depth of dicts and lists, without recursion, up to limit + 1."""
    depth = 0
    level = [obj]
    while level and depth <= limit:
        nxt: list[Any] = []
        for item in level:
            if isinstance(item, dict):
                nxt.extend(item.values())
            elif isinstance(item, (list, tuple)):
                nxt.extend(item)
        if not nxt:
            break
        level = nxt
        depth += 1
    return depth


def redact_obj(obj: Any, by_key: bool = True, _depth: int = 0) -> Any:
    """Apply redact() to every string in nested dicts and lists.

    With by_key, a string of eight or more characters under a key named like a
    credential is replaced whole; that suits untrusted JSON, not the audit's own report
    keys. Values nested deeper than MAX_NESTING are replaced with a placeholder, so no
    input can exhaust the interpreter's recursion limit.
    """
    if isinstance(obj, str):
        return redact(strip_controls(obj))
    if _depth >= MAX_NESTING and isinstance(obj, (dict, list, tuple)):
        return "[nested too deeply to report]"
    if isinstance(obj, dict):
        out = obj.__class__()
        for key, value in obj.items():
            key = redact(strip_controls(key)) if isinstance(key, str) else key
            if (
                by_key
                and isinstance(key, str)
                and isinstance(value, str)
                and len(value) >= 8
                and SECRET_KEY.search(key)
            ):
                out[key] = f"[redacted value of {key}]"
            else:
                out[key] = redact_obj(value, by_key, _depth + 1)
        return out
    if isinstance(obj, (list, tuple)):
        return [redact_obj(v, by_key, _depth + 1) for v in obj]
    return obj


def short(text: object, cap: int = 90) -> str:
    """Collapse whitespace, redact, and truncate to `cap` characters."""
    value = redact(" ".join(strip_controls(str(text)).split()))
    return value if len(value) <= cap else value[: cap - 1] + "…"


def dash(value: object) -> str:
    """Render an empty value as '-'."""
    return "-" if value in (None, "", "None") else str(value)


_CELL_SEP = re.compile(r"(?<!\\)\|")


def scan_lines(lines: list[str]) -> list[int]:
    """Classify each line as NORMAL, FENCE_LINE, FENCED, or COMMENTED.

    A fence closes only on a line of the same character, at least as long as the opening
    run, with nothing after it, so a fenced example can show a shorter fence or the
    other fence character. COMMENTED marks the lines after the one that opens a
    multi-line HTML comment, through the line that closes it.
    """
    states: list[int] = []
    fence: tuple[str, int] | None = None
    in_comment = False
    for line in lines:
        stripped = line.strip()
        if in_comment:
            states.append(COMMENTED)
            closed = line.find("-->")
            # the text after the close can open the next comment
            in_comment = closed == -1 or _opens_comment(line[closed + 3 :])
            continue
        m = FENCE.match(stripped[:LONG_LINE])
        if fence is not None:
            closes = (
                m is not None
                and m.group(1)[0] == fence[0]
                and len(m.group(1)) >= fence[1]
                and not m.group(2).strip()
            )
            states.append(FENCE_LINE if closes else FENCED)
            if closes:
                fence = None
            continue
        if m is not None and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            fence = (m.group(1)[0], len(m.group(1)))
            states.append(FENCE_LINE)
            continue
        states.append(NORMAL)
        in_comment = _opens_comment(line)
    return states


def _opens_comment(text: str) -> bool:
    """Whether text leaves an HTML comment open; one inside inline code does not."""
    probe = strip_inline_code(text)
    opened = probe.rfind("<!--")
    return opened != -1 and probe.find("-->", opened + 4) == -1


def parse_heading(line: str) -> tuple[int, str] | None:
    """(level, text) of an ATX heading line, or None.

    Lines over LONG_LINE are never headings; closing hashes are stripped in code so the
    pattern stays linear.
    """
    if len(line) > LONG_LINE:
        return None
    m = HEADING.match(line)
    if not m:
        return None
    text = m.group(2).rstrip()
    unclosed = text.rstrip("#")
    if unclosed != text and (not unclosed or unclosed[-1] in " \t"):
        text = unclosed.rstrip()
    return (len(m.group(1)), text)


class Doc:
    """A parsed tracking Markdown file: lines, headings, markers, and H2 sections."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.lines = text.split("\n")
        self.headings: list[tuple[int, str, int]] = []  # (level, text, line_index)
        self.markers: list[tuple[str, str, int]] = []  # (kind, id, line_index)
        # marker-shaped comments the canvas cannot read: (kind, id, line_index)
        self.loose_markers: list[tuple[str, str, int]] = []
        for i, (line, state) in enumerate(zip(self.lines, scan_lines(self.lines))):
            if state != NORMAL or len(line) > LONG_LINE:
                continue
            heading = parse_heading(line)
            if heading:
                self.headings.append((heading[0], heading[1], i))
            marker = MARKER.fullmatch(line.strip())
            if marker:
                self.markers.append((marker.group(1), marker.group(2), i))
                continue
            # a marker quoted in inline code is an example, not a marker
            for mm in MARKER_LOOSE.finditer(strip_inline_code(line)):
                self.loose_markers.append((mm.group(1), mm.group(2), i))
        self.sections: dict[str, tuple[int, int]] = {}  # H2 title -> (start, end)
        h2 = [(t, i) for lvl, t, i in self.headings if lvl == 2]
        for idx, (title, start) in enumerate(h2):
            end = h2[idx + 1][1] if idx + 1 < len(h2) else len(self.lines)
            self.sections.setdefault(title, (start, end))
        # Body ends, precomputed so lookups stay linear in the number of headings.
        self._range_end: dict[int, int] = {}
        open_headings: list[tuple[int, int]] = []
        for lvl, _, i in self.headings:
            while open_headings and open_headings[-1][0] >= lvl:
                self._range_end[open_headings.pop()[1]] = i
            open_headings.append((lvl, i))
        for _, i in open_headings:
            self._range_end[i] = len(self.lines)
        starts = [i for _, _, i in self.headings]
        # zip stops at the shorter list, so a file without headings maps nothing
        self._next_heading: dict[int, int] = dict(
            zip(starts, [*starts[1:], len(self.lines)])
        )

    def section(self, name: str) -> str:
        """The H2 section whose title starts with `name`, ignoring case, or ''."""
        for title, (start, end) in self.sections.items():
            if title.lower().startswith(name.lower()):
                return "\n".join(self.lines[start + 1 : end])
        return ""

    def has_section(self, name: str) -> bool:
        """Whether an H2 section title starts with `name`."""
        return any(t.lower().startswith(name.lower()) for t in self.sections)

    def h2_titles(self) -> list[str]:
        """The H2 titles in order."""
        return list(self.sections.keys())

    def heading_range(self, line_index: int) -> tuple[int, int]:
        """The heading's body: until the next heading of equal or higher level."""
        return (line_index, self._range_end.get(line_index, line_index + 1))

    def body_lines(self, line_index: int) -> list[str]:
        """Lines under the heading at `line_index`, nested headings included."""
        start, end = self.heading_range(line_index)
        return self.lines[start + 1 : end]

    def own_body_lines(self, line_index: int) -> list[str]:
        """Lines under a heading up to the next heading of any level."""
        return self.lines[
            line_index + 1 : self._next_heading.get(line_index, line_index + 1)
        ]

    def subsection_bodies(
        self, section_name: str, level: int = 3
    ) -> list[tuple[str, str, int]]:
        """(title, body, line) for each `level` heading inside the named H2 section."""
        out = []
        for title, (start, end) in self.sections.items():
            if not title.lower().startswith(section_name.lower()):
                continue
            for lvl, t, i in self.headings:
                if lvl == level and start < i < end:
                    out.append((t, "\n".join(self.body_lines(i)), i))
            break
        return out


def bullet_fields(text: str) -> dict[str, str]:
    """`* Label: value` bullets as label -> value; bold allowed, first one wins."""
    out: dict[str, str] = {}
    for line in text.split("\n"):
        m = BULLET_FIELD.match(line[:LONG_LINE])
        if not m:
            continue
        label = BOLD_WRAP.sub("", m.group(1)).strip()
        value = m.group(2).strip()
        if value.startswith(
            ("**", "__")
        ):  # `* **Status:** Partial` closes the bold after the colon
            value = value[2:].strip()
        if label and label not in out:
            out[label] = value
    return out


def _split_cells(line: str) -> list[str]:
    """The cells of a pipe-table row; `\\|` is a literal pipe inside a cell."""
    s = line.strip()
    cells = _CELL_SEP.split(s)
    if s.startswith("|"):
        cells = cells[1:]
    if cells and s.endswith("|") and not s.endswith("\\|"):
        cells = cells[:-1]
    return [c.replace("\\|", "|").strip() for c in cells]


def table_blocks(text: str) -> list[tuple[list[str], list[list[str]]]]:
    """Pipe tables in text as (header_cells, rows) pairs, separator rows dropped.

    Accepts tables with or without outer pipes; a block counts as a table when its
    second line is a separator row.
    """
    blocks: list[tuple[list[str], list[list[str]]]] = []
    block: list[str] = []

    def flush() -> None:
        if len(block) >= 2 and all(
            TABLE_SEP.match(c or "-") for c in _split_cells(block[1])
        ):
            blocks.append(
                (_split_cells(block[0]), [_split_cells(line) for line in block[2:]])
            )
        block.clear()

    for line in text.split("\n"):
        if "|" in line and not FENCE.match(line.strip()):
            block.append(line)
        else:
            flush()
    flush()
    return blocks


def table_rows(text: str) -> list[list[str]]:
    """Rows of pipe tables in text, header and separator rows dropped."""
    return [row for _, rows in table_blocks(text) for row in rows]


def field_table(text: str) -> dict[str, str]:
    """A two-column `| Field | Record |` table as a dict."""
    out: dict[str, str] = {}
    for cells in table_rows(text):
        if len(cells) >= 2 and cells[0] and cells[0] not in out:
            out[BOLD_WRAP.sub("", cells[0]).strip()] = cells[1]
    return out


def labeled_blocks(body_lines: list[str]) -> dict[str, str]:
    """Labeled blocks (Goals:, Requirements:, ...) inside a task or phase body.

    Stops at the first heading outside a code fence so a phase does not absorb its
    tasks' blocks; marker comments end a block, and a fenced block stays in the block it
    follows. A phase's `Changes in the map:` line is kept as its own one-line block.
    """
    blocks: dict[str, list[str]] = {}
    current = None
    for line, state in zip(body_lines, scan_lines(body_lines)):
        if state == COMMENTED:
            continue
        if state in (FENCE_LINE, FENCED):
            pass
        elif parse_heading(line):
            break
        elif MARKER_LOOSE.search(line[:LONG_LINE]):
            current = None
            continue
        elif CHANGES_IN_MAP.match(line.strip()):
            blocks["Changes in the map"] = [line.strip().split(":", 1)[1].strip()]
            current = None
            continue
        elif m := LABEL_BLOCK.match(line.strip()):
            current = m.group(1)
            blocks.setdefault(current, [])
            continue
        if current is not None:
            blocks[current].append(strip_comments(line))
    return {k: "\n".join(v) for k, v in blocks.items()}


def strip_comments(text: str) -> str:
    """Replace each closed HTML comment with a space, in one forward pass."""
    out: list[str] = []
    pos = 0
    while True:
        start = text.find("<!--", pos)
        end = text.find("-->", start + 4) if start != -1 else -1
        if end == -1:
            out.append(text[pos:])
            return "".join(out)
        out.append(text[pos:start])
        out.append(" ")
        pos = end + 3


def strip_fences_and_comments(text: str) -> str:
    """Remove HTML comments and fenced code blocks.

    Lines inside a fence or a multi-line comment are dropped, closed comments on a
    remaining line are removed, and the line that opens a multi-line comment is cut at
    the opener.
    """
    lines = text.split("\n")
    states = scan_lines(lines)
    out: list[str] = []
    for i, (line, state) in enumerate(zip(lines, states)):
        if state != NORMAL:
            continue
        line = strip_comments(line)
        if i + 1 < len(states) and states[i + 1] == COMMENTED:
            opened = line.rfind("<!--")
            line = line[:opened] if opened != -1 else line
        out.append(line)
    return "\n".join(out)


def strip_inline_code(text: str) -> str:
    """Remove inline code spans."""
    return re.sub(r"`[^`\n]*`", " ", text)


def is_placeholder_value(value: str | None) -> bool:
    """Whether a value is empty or still holds a `{{placeholder}}`."""
    v = (value or "").strip()
    return not v or PLACEHOLDER.search(v) is not None


def vocab_match(
    value: str | None, vocabulary: Iterable[str], strip_paths: bool = False
) -> str | None:
    """The vocabulary entry that occurs earliest in value as a whole word, or None.

    The longest entry wins a tie. Placeholders count as absent. With strip_paths,
    Markdown links and path-like tokens are removed first so a verdict is not read out
    of a file name such as `revise-login-plan-critique.md`. A negated entry ("No defects
    found", "Not yet ready", "did not pass"), a qualified one ("unable to complete",
    "partially complete"), and a labeled-none entry ("Blocked: none") are skipped, so
    such a value reads as outside the vocabulary, never as its opposite.
    """
    vocabulary = list(vocabulary)
    v = (value or "")[:LONG_LINE]
    if is_placeholder_value(v):
        return None
    if strip_paths:
        v = MD_LINK.sub(" ", v)
        v = re.sub(r"\S*/\S*|\S+\.md\b", " ", v)
    alternatives = "|".join(
        re.escape(e) for e in sorted(vocabulary, key=len, reverse=True)
    )
    pattern = r"(?<![\w-])(" + alternatives + r")(?![\w-])"
    for m in re.finditer(pattern, v, re.I):
        before = v[max(0, m.start() - 60) : m.start()]
        if NEGATION_BEFORE.search(before) or QUALIFIED_BEFORE.search(before):
            continue
        if re.match(r"\s*:\s*none\b(?!\s+of\b)", v[m.end() :], re.I):
            continue
        low = m.group(1).lower()
        for entry in vocabulary:
            if entry.lower() == low:
                return entry
    return None


def real_bullets(text: str) -> list[str]:
    """A section's top-level bullets that record something.

    `None`, `Not applicable`, `No blockers`, and unfilled placeholders record nothing.
    """
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if not s.startswith(("* ", "- ")):
            continue
        item = s[2:].strip()
        # emphasis around the whole bullet, as in `*None*`, changes nothing
        plain = item.strip("*_`").strip()
        if not plain or EMPTY_BULLET.match(plain) or is_placeholder_value(item):
            continue
        out.append(item)
    return out


def line_number_reference(text: str) -> str | None:
    """The first line-number reference outside code, or None.

    Token-based so very long lines stay linear.
    """
    for line in strip_inline_code(text).split("\n"):
        if len(line) > LONG_LINE:
            continue
        m = LINE_REF_ANCHOR.search(line) or LINE_REF_PHRASE.search(line)
        if m:
            return m.group(0)
        for tok in line.split():
            if LINE_REF_TOKEN.match(tok):
                return tok
    return None
