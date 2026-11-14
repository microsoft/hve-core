# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Read each RPI artifact kind into a model of the fields the rules and board use."""

from __future__ import annotations

import re
from typing import Any

from ._discovery import Artifact
from ._markdown import (
    bullet_fields,
    field_table,
    is_placeholder_value,
    labeled_blocks,
    real_bullets,
    short,
    strip_fences_and_comments,
    table_blocks,
    table_rows,
    vocab_match,
)
from ._rules import (
    ALIGNMENT_VALUES,
    ANY_PLAN_ID,
    CHECKBOX,
    CRITIQUE_EXECUTION,
    DECISION_STEMS,
    DESTINATION_VARIANT,
    DESTINATIONS,
    EVIDENCE_CELL,
    EVIDENCE_CITE,
    EVIDENCE_DEF,
    EVIDENCE_LINE,
    EXECUTION,
    EXTERNAL_REQ_CITE,
    ID_HEADING,
    NEGATION_BEFORE,
    NOT_A_DECISION,
    OUTCOMES,
    PC_ID,
    PHASE_DIAGRAM,
    PHASE_ID,
    PLAN_DECISION_OPEN,
    PLAN_DECISION_WORDS,
    PLAN_READINESS,
    RD_ID,
    READINESS_NEGATION,
    REQ_CITE,
    REQ_DEF,
    RESEARCH_DISPOSITIONS,
    REVIEW_BLOCKED,
    REVIEW_EXECUTION,
    RV_ID,
    SKIP_NOTE,
    STARTED,
    SUPERSEDED_BEFORE,
    TASK_ID,
    TASK_ID_IN_TEXT,
    VERDICTS,
)

Model = dict[str, Any]


def _marker_before(
    doc_lines: list[str],
    i: int,
    marker_lines: dict[int, tuple[str, str]],
    loose_lines: set[int],
) -> tuple[tuple[str, str] | None, bool]:
    """The marker on the line directly above a heading, and whether one sits further up.

    The phase skills and the RPI Workflow canvas read a marker only on the line directly
    above its heading, so a marker separated by blank lines does not count; the second
    value reports that case so the marker, not the heading, carries the finding.
    """
    if i - 1 in marker_lines:
        return marker_lines[i - 1], False
    j = i - 1
    while j >= 0 and doc_lines[j].strip() == "" and i - j <= 2:
        j -= 1
    # a malformed marker near the heading is reported from the marker side as well
    return None, j >= 0 and (j in marker_lines or j in loose_lines)


def model_plan(art: Artifact) -> Model:
    """Phases, tasks, markers, requirements, readiness, critique, and decisions."""
    doc = art.doc
    m = art.model
    meta = bullet_fields(doc.section("Task Metadata"))
    m["task_id"] = meta.get("Task ID", "")
    m["task_slug"] = meta.get("Task slug", "")
    m["plan_date"] = meta.get("Plan date", "")
    phases: list[dict[str, Any]] = []
    tasks: list[dict[str, Any]] = []
    marker_lines = {i: (k, mid) for k, mid, i in doc.markers if k in ("phase", "task")}
    loose_lines = {i for k, _, i in doc.loose_markers if k in ("phase", "task")}
    for _, _, i in doc.headings:
        hm = ID_HEADING.match(doc.lines[i])
        if not hm:
            continue
        hid = hm.group(3)
        if not (PHASE_ID.match(hid) or TASK_ID.match(hid)):
            continue
        body = doc.own_body_lines(i)
        blocks = labeled_blocks(body)
        marker, marker_gap = _marker_before(doc.lines, i, marker_lines, loose_lines)
        entry: dict[str, Any] = {
            "id": hid,
            "line": i,
            "checked": (hm.group(2) or " ").lower() == "x",
            "has_box": hm.group(2) is not None,
            "marker": marker,
            "marker_gap": marker_gap,
            "blocks": blocks,
            "title": hm.string[hm.end() :].strip(" :-"),
        }
        if PHASE_ID.match(hid):
            # a plan written with phase diagrams shows the phase's changes in its own
            # diagram
            entry["has_diagram"] = any(
                PHASE_DIAGRAM.match(line.strip()) for line in body
            )
            entry["tasks"] = []
            phases.append(entry)
            continue
        entry["phase"] = hid.split("-")[0]
        deps = TASK_ID_IN_TEXT.findall(blocks.get("Dependencies", ""))
        entry["deps"] = [d for d in deps if d != hid]
        # phases are collected in line order, so the last one encloses this task
        encl = phases[-1] if phases else None
        entry["enclosing"] = encl["id"] if encl else None
        entry["enclosing_line"] = encl["line"] if encl else None
        if encl is not None:
            encl["tasks"].append(hid)
        tasks.append(entry)
    m["phases"] = phases
    m["tasks"] = tasks
    # markers not followed by an ID heading; a marker before a heading with a different
    # plan ID is reported from the heading side
    orphan_markers = []
    for k, mid, i in doc.markers:
        if k not in ("phase", "task"):
            continue
        if i + 1 < len(doc.lines) and ID_HEADING.match(doc.lines[i + 1]):
            continue
        j = i + 1
        while j < len(doc.lines) and doc.lines[j].strip() == "" and j - i <= 2:
            j += 1
        gap = j < len(doc.lines) and ID_HEADING.match(doc.lines[j]) is not None
        orphan_markers.append((mid, i, "gap" if gap else "orphan"))
    for k, mid, i in doc.loose_markers:
        if k in ("phase", "task"):
            orphan_markers.append((mid, i, "loose"))
    m["orphan_markers"] = sorted(orphan_markers, key=lambda o: o[1])
    reqs_text = doc.section("Functional Requirements") + "\n"
    reqs_text += doc.section("Non-Functional Requirements")
    m["req_defined"] = [f"{a}-{b}" for a, b in REQ_DEF.findall(reqs_text)]
    cited: set[str] = set()
    for t in tasks:
        own = EXTERNAL_REQ_CITE.sub(" ", t["blocks"].get("Requirements", ""))
        cited.update(REQ_CITE.findall(own))
    m["req_cited"] = sorted(cited)
    ready_tbl = field_table(doc.section("Planning Readiness and Next Step"))
    m["readiness_raw"] = ready_tbl.get("Planning execution and readiness", "")
    # the row reads "<execution> and <readiness>"; Blocked belongs to both vocabularies
    readiness_part = re.split(r"\band\b", m["readiness_raw"], maxsplit=1)[-1]
    # a cell written without the "and" still names its readiness somewhere
    m["readiness"] = vocab_match(readiness_part, PLAN_READINESS) or vocab_match(
        m["readiness_raw"], PLAN_READINESS
    )
    m["latest_critique_raw"] = ready_tbl.get("Latest critique", "")
    m["blockers_raw"] = ready_tbl.get("Blockers", "")
    m["next_action_raw"] = ready_tbl.get("Next action", "")
    m["continuation_owner"] = ready_tbl.get("Continuation owner", "")
    m["relevant_research_raw"] = ready_tbl.get("Relevant research", "")
    cd = doc.section("Critique Disposition")
    cdf = bullet_fields(cd)
    m["critique_setting"] = cdf.get("Critique setting and provenance", "")
    m["critique_status"] = cdf.get("Critique status", "")
    m["critique_latest"] = cdf.get("Latest critique and verdict", "")
    disposed: set[str] = set()
    for cells in table_rows(cd):
        if cells and PC_ID.search(cells[0]):
            disposed.update(PC_ID.findall(cells[0]))
    m["pc_disposed"] = sorted(disposed)
    claims = " ".join(
        [
            m["critique_setting"],
            m["critique_status"],
            m["critique_latest"],
            m["latest_critique_raw"],
        ]
    )
    latest = m["critique_latest"] + " " + m["latest_critique_raw"]
    # paths and slugs such as skip-link-a11y are not a recorded skip
    claim_words = re.sub(r"(?<!\S)(?:\S*[/\\]\S*|\S+\.md\b)", " ", claims)
    # "chose not to skip" and "never skipped" record no skip
    m["critique_skipped"] = any(
        not NEGATION_BEFORE.search(claim_words[max(0, s.start() - 60) : s.start()])
        for s in re.finditer(r"\bskip(?:s|ped)?\b(?!-)", claim_words, re.I)
    )
    m["critique_verdict"] = vocab_match(
        latest, ("Pass", "Revise", "Blocked"), strip_paths=True
    )
    m["critique_path_claimed"] = (
        re.search(r"plan-critique(?:-\d+)?\.md", latest) is not None
    )
    open_decisions = []
    deferred_decisions = []
    for cells in table_rows(doc.section("User Decisions and Requirements")):
        if len(cells) < 3 or is_placeholder_value(cells[1]):
            continue
        entry = (cells[0], short(cells[1], 60), cells[2])
        status = _plan_decision_status(cells[2])
        if status in PLAN_DECISION_OPEN:
            open_decisions.append(entry)
        elif status == "deferred":
            # a deferral is a recorded choice not to decide now; it does not block the
            # plan
            deferred_decisions.append(entry)
    m["open_decisions"] = open_decisions
    m["deferred_decisions"] = deferred_decisions
    m["follow_ups"] = real_bullets(doc.section("Follow-Up Items"))
    m["h2"] = doc.h2_titles()
    return m


def _plan_decision_status(cell: str) -> str | None:
    """The first status word in a planning decision cell that is not negated.

    "resolved (was proposed)" is resolved, and "no longer unresolved" is not unresolved.
    """
    for found in PLAN_DECISION_WORDS.finditer(cell):
        if not NEGATION_BEFORE.search(cell[max(0, found.start() - 60) : found.start()]):
            return found.group(1).lower()
    return None


def decision_kind(status: str) -> str | None:
    """The decision a Decision History status records, or None when it decides nothing.

    `pending`, `proposed`, and a negated word such as "not resolved" or "no change yet"
    record the item without deciding it.
    """
    if NOT_A_DECISION.search(status):
        return None
    # the stems are ordered so the word that leaves a finding open wins: "accepted,
    # but deferred to the next release" is deferred. A word that is negated, or that
    # describes an earlier state ("was deferred in RD-001"), is passed over.
    for kind, stem in DECISION_STEMS:
        for found in stem.finditer(status):
            before = status[max(0, found.start() - 60) : found.start()]
            if not (NEGATION_BEFORE.search(before) or SUPERSEDED_BEFORE.search(before)):
                return kind
    return None


FINAL_UNDECIDED = re.compile(
    r"\b(?:proposed|proposes|proposal|awaiting|tbd|undecided|not yet|to be decided"
    r"|to be confirmed|unconfirmed|provisional(?:ly)?|tentative(?:ly)?|not final"
    r"|conditional(?:ly)?|subject to|rejected|declined|overruled|if|unless|until"
    r"|once)\b",
    re.I,
)
NOTHING_PENDING = re.compile(
    r"\b(?:nothing|none|no(?:\s+[\w-]+){0,2})\s+(?:(?:is|are|remains?)\s+)?pending\b",
    re.I,
)


_OUTCOME_LEAD = (
    r"[\s`*_\"'\u201c\u2018]*(?:final(?:\s+outcome)?\s*[:\u2013-]\s*)?"
    r"[\s`*_\"'\u201c\u2018]*"
)


def _leading_outcome(raw: str) -> str | None:
    """The outcome a Final outcome value starts with.

    Emphasis marks, quotation marks, and a `Final:` label may come first.
    """
    if is_placeholder_value(raw):
        return None
    for entry in sorted(OUTCOMES, key=len, reverse=True):
        if re.match(_OUTCOME_LEAD + re.escape(entry) + r"(?![\w-])", raw, re.I):
            return entry
    return None


def _destination(raw: str) -> str | None:
    """The route a destination cell names; `rpi_implement` and `follow up` count too."""
    return vocab_match(DESTINATION_VARIANT.sub(r"\1-\2", raw), DESTINATIONS)


def model_critique(art: Artifact) -> Model:
    """Execution, verdict, findings, and the follow-up reconciliation."""
    doc = art.doc
    m = art.model
    meta = bullet_fields(doc.section("Metadata"))
    m["task_id"] = meta.get("Task ID", "")
    m["plan_ref"] = meta.get("Plan", "")
    m["execution_raw"] = meta.get("Critique execution", "")
    m["execution"] = vocab_match(m["execution_raw"], CRITIQUE_EXECUTION)
    m["started"] = m["execution"] == STARTED
    m["type"] = meta.get("Critique type", "")
    m["depth"] = meta.get("Critique depth", "")
    m["verdict_raw"] = bullet_fields(doc.section("Verdict")).get("Verdict", "")
    m["verdict"] = vocab_match(m["verdict_raw"], VERDICTS, strip_paths=True)
    ids_h, sev = [], {}
    for _, _, i in doc.headings:
        hm = ID_HEADING.match(doc.lines[i])
        if hm and hm.group(3).startswith("PC-"):
            ids_h.append(hm.group(3))
            sev[hm.group(3)] = (hm.group(4) or "").capitalize()
    m["finding_ids"] = ids_h
    m["marker_ids"] = [mid for k, mid, _ in doc.markers if k == "critique"]
    m["severities"] = sev
    m["has_reconciliation"] = doc.has_section("Earlier Finding Reconciliation")
    m["next_action"] = bullet_fields(doc.section("Recommended Next Action"))
    m["h2"] = doc.h2_titles()
    return m


def model_changes(art: Artifact) -> Model:
    """Execution status, scope, entries, validation, alignment, and blockers."""
    doc = art.doc
    m = art.model
    meta = bullet_fields(doc.section("Metadata"))
    m["task_id"] = meta.get("Task ID", "")
    m["plan_ref"] = meta.get("Related plan", "")
    es = bullet_fields(doc.section("Execution Status"))
    m["status_raw"] = es.get("Status", "")
    m["status"] = vocab_match(m["status_raw"], EXECUTION)
    m["scope_raw"] = es.get("Declared invocation scope", "")
    m["full_plan_scope"] = (
        re.search(r"full[\s-]*plan", m["scope_raw"], re.I) is not None
    )
    m["completed_markers"] = sorted(
        set(ANY_PLAN_ID.findall(es.get("Completed scope markers", "")))
    )
    remaining = es.get("All remaining active-plan markers", "")
    m["remaining_markers"] = sorted(set(ANY_PLAN_ID.findall(remaining)))
    entries = []
    for title, body, i in doc.subsection_bodies("Completed Work", 3):
        f = bullet_fields(body)
        related = sorted(set(ANY_PLAN_ID.findall(f.get("Related phase or task", ""))))
        entries.append(
            {
                "title": title,
                "related": related,
                "validation": f.get("Validation", ""),
                "line": i,
            }
        )
    m["entries"] = entries
    m["entry_markers"] = sorted({r for e in entries for r in e["related"]})
    m["all_mentioned"] = sorted(
        set(m["completed_markers"])
        | set(m["entry_markers"])
        | set(m["remaining_markers"])
    )
    m["validation_rows"] = [
        c for c in table_rows(doc.section("Validation Record")) if len(c) >= 3
    ]
    m["alignment_values"] = [
        vocab_match(bullet_fields(body).get("Alignment", ""), ALIGNMENT_VALUES)
        for _, body, _ in doc.subsection_bodies("Business Alignment", 3)
    ]
    pr = bullet_fields(doc.section("Pre-Review Reconciliation"))
    m["review_readiness_raw"] = pr.get("Review readiness", "")
    m["review_ready"] = (
        re.match(r"^\s*ready\b", m["review_readiness_raw"], re.I) is not None
    )
    # the readiness line says review must wait: `not ready`, `blocked`, or `pending`
    # "not blocked" and "nothing pending" say the opposite
    readiness_raw = m["review_readiness_raw"]
    m["review_blocked"] = not is_placeholder_value(readiness_raw) and any(
        not READINESS_NEGATION.search(
            readiness_raw[max(0, hit.start() - 60) : hit.start()]
        )
        for hit in REVIEW_BLOCKED.finditer(readiness_raw)
    )
    m["blockers"] = real_bullets(doc.section("Blockers"))
    m["remaining_work"] = [
        b
        for b in real_bullets(doc.section("Remaining Work"))
        if not b.startswith("Canonical")
    ]
    m["h2"] = doc.h2_titles()
    return m


def model_review(art: Artifact) -> Model:
    """Execution, outcomes, findings with proposed and final routes, and decisions."""
    doc = art.doc
    m = art.model
    summ = bullet_fields(doc.section("Executive Summary"))
    rrf = bullet_fields(doc.section("Review Record"))
    m["execution_raw"] = summ.get("Review execution", "")
    m["execution"] = vocab_match(m["execution_raw"], EXECUTION)
    m["record_execution"] = vocab_match(
        rrf.get("Review execution", ""), REVIEW_EXECUTION
    )
    # the record is saved while execution stays `started`; the summary fields follow
    # later
    m["started"] = m["record_execution"] == STARTED and m["execution"] is None
    m["outcome_raw"] = summ.get("Assessed outcome", "")
    m["outcome"] = vocab_match(m["outcome_raw"], OUTCOMES)
    findings = []
    for title, body, i in doc.subsection_bodies("Findings and Proposed Routes", 3):
        hm = ID_HEADING.match(doc.lines[i])
        if not hm or not hm.group(3).startswith("RV-"):
            continue
        dest_raw = bullet_fields(body).get("Proposed destination", "")
        findings.append(
            {
                "id": hm.group(3),
                "severity": (hm.group(4) or "").capitalize(),
                "destination": _destination(dest_raw),
                "destination_raw": dest_raw,
                "title": short(title.split(":", 1)[-1], 60),
                "line": i,
            }
        )
    m["findings"] = findings
    m["marker_ids"] = [mid for k, mid, _ in doc.markers if k == "review"]
    decided: set[str] = set()
    decisions: dict[str, str] = {}
    kinds: dict[str, str] = {}
    final_dests: dict[str, str | None] = {}
    pdr = doc.section("Parent Decision Record")
    for header, rows in table_blocks(pdr):
        fin_col = next(
            (
                i
                for i, h in enumerate(header)
                if h.strip().lower() == "final destination"
            ),
            None,
        )
        for cells in rows:
            if len(cells) < 4 or not RD_ID.search(cells[0]):
                continue
            # a row whose status is `pending` or `proposed` records the item, not a
            # decision
            kind = decision_kind(cells[3])
            if kind is None:
                continue
            status = cells[3]
            # a walkthrough Skip is recorded as a rejected route; the finding stays open
            if kind == "rejected" and any(SKIP_NOTE.search(c) for c in cells[4:]):
                kind = "skipped"
                status += " (skipped)"
            for rv in RV_ID.findall(cells[1]):
                decided.add(rv)
                decisions[rv] = status
                kinds[rv] = kind
                # the latest event governs; a recorded route replaces the proposal,
                # `none` drops it
                if fin_col is not None and fin_col < len(cells):
                    cell = cells[fin_col]
                    if not is_placeholder_value(cell):
                        route = _destination(cell)
                        none = re.search(r"\bnone\b", cell, re.I)
                        final_dests[rv] = route or ("none" if none else None)
    m["decided"] = sorted(decided)
    m["decisions"] = decisions
    m["decision_kinds"] = kinds
    for f in findings:
        fd = final_dests.get(f["id"])
        f["final_destination"] = fd
        f["route"] = f["destination"] if fd is None else (None if fd == "none" else fd)
    cur = bullet_fields(pdr)
    m["final_outcome_raw"] = cur.get("Final outcome", "")
    raw = m["final_outcome_raw"]
    # the outcome is final only when it leads the value; one quoted later, as in
    # "Awaiting parent decision (assessed: Conformant)", is the reviewer's proposal
    m["final_outcome"] = _leading_outcome(raw)
    m["final_pending"] = (
        m["final_outcome"] is None
        or FINAL_UNDECIDED.search(raw) is not None
        or (
            re.search(r"\bpending\b", raw, re.I) is not None
            and NOTHING_PENDING.search(raw) is None
        )
    )
    m["task_id"] = rrf.get("Task ID", "")
    m["plan_ref"] = rrf.get("Plan", "")
    m["changes_ref"] = rrf.get("Changes", "")
    scope_raw = rrf.get("Review scope", "")
    m["scope_raw"] = scope_raw
    m["bounded_scope"] = ANY_PLAN_ID.search(scope_raw) is not None and not re.search(
        r"\bfull\b", scope_raw, re.I
    )
    m["h2"] = doc.h2_titles()
    return m


def model_research(art: Artifact) -> Model:
    """Readiness, disposition, and evidence IDs defined and cited."""
    doc = art.doc
    m = art.model
    tbl = field_table(doc.section("Planning Readiness and Next Step"))
    m["readiness_raw"] = tbl.get("Planning Readiness", "")
    m["readiness"] = vocab_match(m["readiness_raw"], PLAN_READINESS)
    m["disposition_raw"] = tbl.get("Research disposition", "")
    m["disposition"] = vocab_match(m["disposition_raw"], RESEARCH_DISPOSITIONS)
    m["next_action_raw"] = tbl.get("Next action", "")
    m["blockers_raw"] = tbl.get("Blockers", "")
    m["status_raw"] = bullet_fields(doc.section("Executive Summary")).get(
        "Research status", ""
    )
    m["evidence_defined"] = sorted(
        set(EVIDENCE_DEF.findall(doc.section("Research Record")))
    )
    user_facing = "\n".join(
        doc.section(name)
        for name in (
            "Findings",
            "Recommendation and Alternatives",
            "Decisions and Feedback",
            "What You May Not Know",
        )
    )
    # cite only where the template cites evidence, so prose such as "C4 model" is not an
    # ID
    text = strip_fences_and_comments(user_facing)
    cited = {
        c
        for line in text.split("\n")
        if EVIDENCE_LINE.match(line)
        for c in EVIDENCE_CITE.findall(line)
    }
    for cells in table_rows(text):
        for cell in cells:
            if EVIDENCE_CELL.match(cell.strip("` ")):
                cited.update(EVIDENCE_CITE.findall(cell))
    m["evidence_cited"] = sorted(cited)
    m["h2"] = doc.h2_titles()
    return m


def model_legacy(art: Artifact) -> Model:
    """Checklist progress and title of a retired-format file."""
    m = art.model
    boxes = CHECKBOX.findall(art.text)
    m["steps_total"] = len(boxes)
    m["steps_checked"] = sum(1 for b in boxes if b.lower() == "x")
    m["title"] = art.doc.headings[0][1] if art.doc.headings else ""
    return m
