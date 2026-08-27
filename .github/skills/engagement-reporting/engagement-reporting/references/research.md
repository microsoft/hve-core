---
title: Engagement Reporting Research
description: Source discovery, WorkIQ retrieval, board normalization, and coverage gates for engagement reporting.
ms.date: 2026-08-27
ms.topic: reference
---

## Research outcome

Produce normalized, source-referenced findings for the reporting period. Do not
draft until required sources have completed or the user accepts a documented
coverage gap.

## Research depth

Use the configured report option:

* `standard` for routine weekly reporting. Limit retrieval to the requested
  period, combine stakeholder and meeting-series queries where possible, reuse
  already retrieved results, and stop when the required report sections have
  sufficient current evidence. Batch paths and remain within the six-call
  source-tool budget.
* `thorough` only when configured or explicitly requested for deep research or
  an audit. Expand across configured sources and document detailed coverage.

Treat the configured depth as authoritative. Do not silently upgrade a
`standard` run because it is the first report or covers a longer date range.

Do not enumerate historical mailboxes, chats, meetings, OneNote, and SharePoint
when a standard weekly report is already supported by current-period evidence.
Do not repeat a failed query through multiple equivalent tools. Try one
targeted fallback, record the gap, and continue.

## Source hierarchy

| Source type           | Authority       | Reporting use              |
|-----------------------|-----------------|----------------------------|
| Primary source        | Ground truth    | Factual claims             |
| Workstream lead input | Scope authority | Corrections and context    |
| Previous report       | Continuity only | Progression and prior work |
| Inference             | Not citable     | Flag for verification      |

Primary sources include board data, meeting transcripts, email, chat, calendar
events, and documents retrieved through approved tools.

## Research files

Write findings under `.working/{date}-{report-type}/research/`:

* `workiq-findings.md`
* `board-findings.md`
* `transcript-findings.md`
* `manual-input.md`
* `coverage.md`

Each finding records a stable identifier, source type, source reference,
reporting-period date, concise evidence summary, confidence, and any
directionality or attribution caveat.

## WorkIQ retrieval

When WorkIQ requires EULA acceptance, obtain the user's explicit confirmation
before invoking the EULA acceptance operation. Stop WorkIQ research when the
user declines. Feature-detect available read operations rather than assuming
one API shape.

### Natural-language retrieval

When the `ask` operation is available, prefer one combined current-period query
covering configured participants, engagement identity, and meeting series.
Split it only when the response omits a configured source or produces an
unusable result.

Prefer stakeholder and series queries over subject keyword matching.

### Entity retrieval

When natural-language retrieval is unavailable:

1. Discover supported paths and schemas
2. Enumerate messages by stakeholder envelope fields
3. Enumerate calendar events by attendee and meeting series
4. Retrieve transcripts for matching meetings
5. Enumerate chats, then fetch messages for matching chat IDs
6. Retrieve configured channel, OneNote, and SharePoint content
7. Run optional keyword matching only as a fallback

If a broad chat endpoint fails in delegated context, enumerate `/me/chats`,
filter by stakeholders, meeting series, topic, and activity date, then fetch
messages per chat. Record blocked chat IDs and metadata in a coverage-gaps
section rather than reporting no chat activity.

## Board research

Boards are optional. Detect the configured provider and available capability.
Query work items and pull requests changed during the reporting period, then
normalize findings:

```markdown
## Board Findings

### Completed

* **{Title}** ({id})
  * Completed: {date}
  * Summary: {outcome}

### In Progress

* **{Title}** ({id})
  * State: {state}
  * Summary: {current status}

### Blocked

* **{Title}** ({id})
  * Blocker: {description}
  * Impact: {affected outcome}

### Upcoming

* **{Title}** ({id})
  * Target: {date or iteration}
  * Summary: {planned outcome}

### Pull Request Activity

* **{Title}** ({id})
  * State: {open, merged, or closed}
  * Review status: {status}
```

Do not equate a changed board state with completed business outcome without
supporting evidence.

## Local transcripts

Read supported VTT, DOCX, and plain-text files from the configured transcript
directory. Summarize and minimize; do not copy raw excerpts containing names,
email addresses, customer identifiers, or confidential detail.

## Coverage gate

Before synthesis:

1. Record every configured source as `complete`, `partial`, `unavailable`, or
   `not configured`
2. For standard weekly reports, compare coverage by required section rather
   than raw finding count
3. Use the 30-percent prior-period sanity check only in thorough mode
4. Flag meetings without transcripts only when their missing content could
   materially change the report
5. Ask for manual input only for a specific material gap

Missing evidence is a coverage gap, not evidence that no activity occurred.
