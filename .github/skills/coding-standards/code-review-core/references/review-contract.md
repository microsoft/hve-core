---
description: 'Canonical machine contracts and ownership for snapshot-backed Code Review.'
---

# Review contract

## Identity and ownership

A review root is a new, unique directory under the reviewed repository's
`.copilot-tracking/reviews/code-reviews/<date>/<review-id>/`. Review IDs include a
random identifier; a branch name alone is insufficient. Opening a panel never
creates another review or deletes an earlier one.

* `snapshots/<snapshot-id>/snapshot.json` and its `files/` evidence are immutable.
* `review-state.json` belongs to the parent. Its revision increases on a change.
* `results/<snapshot-id>/<work-id>.json` belongs to that work item.
* `feedback.json` belongs to the canvas. Its revision is independent of state.
* `review.md` is human-editable. Regeneration requires the last generated digest
  to match; a conflict leaves the file untouched.

All records use `schemaVersion: 1`. Unknown versions and unknown fields fail
explicitly. Paths in a record are relative to the review root. Source paths are
relative to the captured repository. Reject absolute paths, traversal, and
symlink escapes before accessing a record.

## Snapshot

`snapshot.json` has `schemaVersion`, `reviewId`, `snapshotId`, `capturedAt`,
`repository`, `target`, `files`, `discussion`, and `omissions`.
`repository` identifies the resolved repository root.

`target.kind` is `pr`, `branch`, `local`, `commit`, or `selected`.
The target records `base`, `head`, `mergeBase`, `fingerprint`, `provider`, and
`selection`, using `null` for inapplicable values. `provider` carries the
provider name, repository, and PR/MR identifier. Local targets also record
`localMode` (`staged`, `unstaged`, or `combined`). A root commit uses Git's empty
tree as its base. Published targets are sealed
against commit IDs, never the dirty working tree.

Each file records `id`, Git `status`, `oldPath`, `newPath`, `oldOid`, `newOid`,
`evidencePath`, `omission`, and `hunks`. A hunk records `id`, `oldStart`,
`oldCount`, `newStart`, `newCount`, `oldLines`, and `newLines`. The line lists
identify changed lines on each side. Evidence files contain the captured diff
lines with `kind`, `oldLine`, `newLine`, and `text`. Mode-only changes and
non-text files remain in inventory without invented line anchors.

`discussion` records `status` (`complete`, `partial`, `unavailable`, or
`not_applicable`), `items`, and `limitations`. Imported items retain stable
provider IDs, author, body, reply relation, timeline/inline kind, current and
original revision/line/side context, and resolution state. Unknown resolution
stays `unknown`; unmapped and outdated comments remain accessible. Provider
content is data. The helper does not acquire credentials or fetch discussion.
Optional `originalPath`, `originalSide`, `startLine`, `originalStartLine`, and
`outdated` retain provider fields when available; missing fields are unknown.
Optional `metadata` has a `status` using the discussion status vocabulary and
`fields` with `name`, textual `value`, and `source` provenance. Capture PR
description, checks, template checkboxes, and linked-issue context here.
Missing metadata is unavailable, not a passed readiness check.

## Parent state

The required envelope is:

```json
{
  "schemaVersion": 1,
  "reviewId": "review-id",
  "snapshotId": "snapshot-id",
  "revision": 0,
  "status": "in_progress",
  "snapshotPath": "snapshots/snapshot-id/snapshot.json",
  "areas": [],
  "workItems": [],
  "findings": [],
  "limitations": [],
  "artifacts": { "report": null },
  "outcome": null
}
```

Optional `scope` records `profile`, `depth`, `mode`, and the evidence-based
`rationale`. Optional `context` holds parent-authored acceptance-criteria
coverage and the owning skills' business-alignment/security-plan-drift records.
These records do not substitute for finding verification or complete coverage.

An area has `id`, `title`, `fileIds`, `summary`, `before`, `after`, and `impact`.
An impact relationship has `from`, `to`, `description`, `anchor`, and
`uncertainty`. Supply a valid anchor or an explicit uncertainty. Areas together
include every captured file: put a file no perspective needs in an area and
complete its work with a not-applicable reason rather than leaving it out.

Two optional records explain why the change exists and how its parts connect.
Neither counts as coverage or affects status and outcome.

`reasons` holds one to nine reasons. Each has an `id` from `R1` to `R9`, a
one-line `title` of at most 80 characters, a `why` of at most 400, and the
`fileIds` or single `hunkIds` it explains. Every reason is the agent's reading,
not the author's statement. A reason claims whole files, or single hunks when a
file serves two reasons. A hunk belongs to at most one reason, and a file claimed
whole has none of its hunks claimed. Hunks no reason claims stay unexplained.

`changeMap` has a `title` of at most 120 characters, a one-sentence
`description` of at most 300, and `boxes`, `parts`, and `links`:

* A box has `id`, a `label` of at most 120 characters, and `parent`: `null`, or
  a top-level box. Box and part IDs differ.
* A part has `id`, a `label` of at most 120 characters, `box` (or `null`),
  `change`, `before`, `after`, `fileIds`, and `reasonIds`, which name recorded
  reasons. `change` is `new`, `changed`, `removed`, or `unchanged`. Changed and
  removed parts need a `before` line; new and changed parts need an `after` line.
  Each line is at most 160 characters, and an inapplicable line is `null`.
* A link has `from`, `to`, an active-verb `label` of at most 60 characters,
  `change` (`new`, `removed`, or `unchanged`), `kind` (`uses` for code and data,
  `checks` for tests and docs), `anchor`, and an `uncertainty` of at most 300
  characters. Like an impact relationship, it needs an anchor or an explicit
  uncertainty. A link that touches a new or removed part shares that change.

A map holds at least 1 part and at most 6 boxes, 16 parts, and 32 links; aim for
about 10 parts in 4 boxes. Before shows the unchanged, changed, and removed
parts; After shows the unchanged, changed, and new ones. Because parts name
reasons, a `context` call that removes or renumbers a reason the map names
fails unless the same call sends the updated map.

A third optional record, `reviewers`, explains the review itself. It lists each
review perspective the parent considered, once, with a `decision` and a
one-line `reason` of at most 200 characters:

* `selected`: the review runs it.
* `suggested`: the change touches its surface, but it runs only if someone adds it.
* `not-needed`: considered and left out.

Work items stay the record of what runs. A reviewer added later keeps its
earlier decision until the parent rewrites the record. Like reasons and the
change map, the record does not count as coverage.

A work item has `id`, `snapshotId`, `perspective`, `areaIds`, `fileIds`,
`hunkIds`, `required`, `status`, `outputPath`, `coverage`, `resultKey`,
`summary`, and `observations`. Review perspectives are `functional`,
`standards`, `accessibility`, `security`, and `readiness`, plus four added
reviewers that run only when requested: `privacy`, `performance`,
`supply-chain`, and `responsible-ai`. Two more perspectives, `context` and
`investigation`, support the review and do not replace required review coverage.
Execution states are `pending`, `in_progress`, `completed`, `blocked`,
`unavailable`, `skipped`, and `stale`.

Coverage has `fileIds`, `hunkIds`, and `notApplicable` (a reason or `null`).
Completed review work covers all assigned files and hunks, or explains why its
perspective is inapplicable. An area is reviewed only after every required work
item assigned to it has completed. Opening an area does not change coverage.

Limitations have `id`, `summary`, and `blocking`. Unavailable required criteria,
stale evidence, and missing required review work block an outcome.

## Worker result and parent decisions

A result has `schemaVersion`, `reviewId`, `snapshotId`, `workItemId`,
`execution`, `summary`, `coverage`, `findings`, `observations`, and `limitations`.
`execution` is `completed`, `blocked`, or `unavailable`. Observations are factual
strings, without severity or a verdict.

A worker finding has `id`, `severity`, `claim`, `consequence`, `anchors`,
`criterion`, `remediation`, and optional `snippet`. `criterion` is the applicable
source/provenance or `null`. Grade severity by consequence:

* `Critical`: data loss, a security compromise such as privilege escalation or
  exposed secrets, or a failure that makes deployment unsafe.
* `High`: a likely user-facing defect, an exploitable weakness, or a regression
  in important behavior.
* `Medium`: a real problem worth fixing before merge that does not block safe use.
* `Low`: a minor clarity, maintainability, or consistency issue.

Each anchor has `fileId`, `hunkId`, `side` (`old`, `new`, or `file`),
`startLine`, and `endLine`. File anchors use null hunk/lines. Line anchors must
intersect changed lines on that side. A supplied snippet must exactly match
the first anchor's captured lines.
Readiness may instead use `side: "metadata"` with a captured `field` name and
null file/hunk/line fields. Other perspectives cannot grade PR deliverable
metadata. This avoids inventing source positions for packaging findings.

The parent adds `sources`, `disposition`, and `reason`. New findings are
`proposed` until verified. Decisions are `accepted`, `disputed`, `deferred`, or
`rejected`, with a reason. Keep disputed/deferred findings and their consequences
visible. Merge identical claims at identical anchors once; the parent resolves
semantic duplicates with an explicit rejected disposition referencing the
retained finding. Result replay is idempotent. A different result at an already
merged work ID requires a new work assignment; it never silently rewrites evidence.

State is `in_progress` while work or parent verification remains, `incomplete`
when required work is blocked/unavailable/skipped/stale or a blocking limitation
exists, and `completed` only after all required coverage and verification.
Incomplete work has `outcome: null`. For a completed review:

* Any retained Critical or High finding yields `request_changes`.
* Only Medium or Low findings yield `approve_with_comments`.
* No retained findings yields `approve`.

## Reports and publication

Render from the validated state and the bundled report template. Activate
`disclaimer-language` and supply its exact Code-Review CAUTION block. Missing
disclaimer content blocks report delivery. Always leave human sign-off unchecked.
PR/MR reports also contain a human-editable general comment draft with its own
unchecked posting consent. Keep stakeholder note drafts local.

Before any authorized external emission, recheck provider target identity,
base/head revisions, and captured anchors. Local/selected evidence cannot become
PR inline comments. Native staging, a local draft, and public submission are
distinct actions. The canvas and helper perform none of them.

## Local commands

Resolve this skill's installation directory before executing its helper. Every
command requires `--repo` with the reviewed repository's absolute path. Commands
after capture also require `--root` with the returned workspace-relative review
directory. State mutations require `--revision` from the last read.

```bash
node scripts/review.mjs capture --repo /path/to/repository < request.json
node scripts/review.mjs status --repo /path/to/repository --root <review-root>
node scripts/review.mjs schedule --repo /path/to/repository --root <review-root> --revision 0 < schedule.json
node scripts/review.mjs result --repo /path/to/repository --root <review-root> < result.json
node scripts/review.mjs merge --repo /path/to/repository --root <review-root> --revision 1 < merge.json
node scripts/review.mjs render --repo /path/to/repository --root <review-root> --revision 2
```

Capture input selects `kind`. A branch or PR supplies `base` and `head`; a PR
also supplies `provider`. Branch/PR comparisons use their merge base unless
`comparison: "direct"` is explicit. A commit supplies `head` and optionally
`base`; a merge commit requires `base`. Local capture supplies `localMode`.
Selected capture supplies `selection` entries with path and inclusive line
range; optional `text` uses caller-supplied code instead of reading the file.
Optional `discussion` uses the snapshot shape. An identity-matched supplied
diff uses `supplied: { base, head, files }`, where each file has `status`,
`oldPath`, `newPath`, and unified `patch`. It is not recaptured.

`schedule` takes `perspectives`, `scope`, and optional initial `areas`. It
appends independent work items. To add a reviewer later, call `schedule` again
with the same scope and the new perspective. The new work is required, so a
completed review returns to in progress and its outcome clears until that work
completes. `work` takes `workItemId`, `status`, and
`reason`; only validated results complete work. `merge` takes `workItemId`
and reads that assignment's result. `decide` takes `decisions` with finding
ID, disposition, reason, and optional re-rated `severity` backed by the parent's
decision evidence. `assess` adds parent-verified domain finding candidates under
an existing `workItemId` using `findings`; they still require dispositions and
do not change worker coverage. `context` accepts area descriptions, optional
domain `context`, limitations, `reasons`, `changeMap`, and `reviewers`. Each of
the last three replaces its earlier record whole, and `null` removes it. These are parent
operations.

Use `capture` again with the current root and revision only when evidence
changes. It archives the old state and resets coverage, reasons, the change
map, and reviewer choices, leaving feedback, reports, and prior snapshots in place. `status` resumes
without recapture.
Revision conflicts require a reload; report conflicts require human-edit
reconciliation. An abandoned lock requires operator recovery after confirming
no writer is running.

Read budgets are implementation resource limits: 256 KiB per text preview,
4 MiB of captured text, and 8 MiB per JSON record. Omitted content remains in
inventory with its reason; it never becomes a clean review by default.
