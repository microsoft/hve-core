---
description: "Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules"
applyTo: "**/.copilot-tracking/reviews/code-reviews/**"
---

<!-- markdownlint-disable-file -->

# Review Artifacts Persistence Protocol

Any code review agent that produces a structured verdict follows this protocol to enable CI integration and cross-agent artifact compatibility.

## Folder Structure

```text
.copilot-tracking/
  reviews/
    code-reviews/
      <sanitized-branch>/
        review.md              # full markdown review output
        metadata.json          # machine-readable summary (see schema below)
        diff-state.json         # shared subagent input (branch, base, files, depth)
        dispatch-manifest.json  # canonical loop state (phase gates, next actions, board items)
        dispatch-board.md       # human-readable enumerated dispatch board
        walkthrough.md          # factual Register 1 orientation narrative
        emission-record.json    # selected emission mode, target, status, outcome
        explanations/
          <board-item>-<symbol>.md   # per-item Register 1 explanation artifacts
        walkback/
          <board-item>-research.md   # per-item Register 2 investigation artifacts
```

Sanitize the branch name by replacing every `/` with `-`
(e.g. `feat/my-feature` → `feat-my-feature`).

The `review.md`, `metadata.json`, `diff-state.json`, and `dispatch-manifest.json`
artifacts are always produced. The orientation-first artifacts
(`dispatch-board.md`, `walkthrough.md`, `explanations/`, `walkback/`, and
`emission-record.json`) are produced only when the review runs in interactive
orientation-first mode; omit them in non-interactive workflow runs.

## metadata.json Schema

```json
{
  "schema_version": "1",
  "branch": "<original branch name, e.g. feat/my-feature>",
  "head_commit": "<full SHA of HEAD at time of review>",
  "reviewed_at": "<ISO 8601 UTC timestamp, e.g. 2026-02-27T10:00:00Z>",
  "verdict": "<normalized verdict - see table below>",
  "files_changed": ["<workspace-relative paths of source files in the diff>"],
  "findings_count": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "reviewer": "<agent or prompt name, e.g. code-review>",
  "artifacts": {
    "dispatch_manifest": "dispatch-manifest.json",
    "dispatch_board": "dispatch-board.md",
    "walkthrough": "walkthrough.md",
    "emission_record": "emission-record.json",
    "explanations": ["explanations/<board-item>-<symbol>.md"],
    "walkbacks": ["walkback/<board-item>-research.md"]
  }
}
```

The `artifacts` object records the orientation-first artifacts produced during
the review. Omit any key whose artifact was not produced (for example, omit
`artifacts` entirely for a non-interactive workflow run, or omit `explanations`
when no per-item explanation was requested). The `explanations` and `walkbacks`
values are arrays of review-folder-relative paths, one entry per board item
that was explained or investigated.

## Verdict Normalization

| Agent Output Verdict     | `verdict` value         |
|--------------------------|-------------------------|
| ✅ Approve                | `approve`               |
| 💬 Approve with comments | `approve_with_comments` |
| ❌ Request changes        | `request_changes`       |

## Orientation-First Artifacts

Interactive orientation-first reviews persist the following artifacts alongside
`review.md` and `metadata.json`. Each is referenced from `review.md` so the
markdown report links to the supporting evidence.

* `dispatch-manifest.json` — the canonical loop state: `phaseGates`,
  `currentPhase`, `nextActions`, and `boardItems`. This is the machine-readable
  source of truth for the human-steered walk-back loop.
* `dispatch-board.md` — the human-readable enumerated board rendered from the
  manifest `boardItems`: id, area, status, register, summary, openable links,
  and selectable symbols.
* `walkthrough.md` — the factual Register 1 orientation narrative (diff summary,
  runway summary, and appendices) presented before any findings register. It
  contains no severity grades or verdicts.
* `explanations/<board-item>-<symbol>.md` — per-item Register 1 explanation
  artifacts written by the explainer when a human asks a shallow factual
  question about a symbol. Each includes the answer, source file reference,
  relevant code excerpt, and follow-on symbols.
* `walkback/<board-item>-research.md` — per-item Register 2 investigation
  artifacts written by the walk-back researcher when a human asks a deep
  investigative question. Each is anchored to its board item.
* `emission-record.json` — the selected emission `mode` (native or canonical),
  `target` (PR, MR, ADO, or review artifact), `status` (completed or skipped),
  and a short outcome `summary`.

## Writing Rules

* Always overwrite any existing `review.md` and `metadata.json` for the branch: only the latest review per branch is retained.
* Obtain the HEAD commit SHA with `git rev-parse HEAD` immediately before writing artifacts.
* Obtain the current UTC timestamp immediately before writing artifacts:
  * In POSIX-compatible shells, use `date -u +%Y-%m-%dT%H:%M:%SZ`.
  * In PowerShell, use `Get-Date -AsUtc -Format "yyyy-MM-ddTHH:mm:ssZ"`.
* `files_changed` must list only source files present in the diff (additions, modifications, or deletions). Filter by relevance - e.g. `.py`, `.sh`, `.ts`, `.tf` - excluding lock files, binaries, and build output.
* Do not write artifacts if the diff was empty and the review was aborted.
* The `reviewer` field must use the kebab-case form of the agent's or prompt's `name` from its frontmatter (e.g. `Code Review` → `code-review`).
* Write orientation-first artifacts only when the review runs in interactive orientation-first mode; record each produced artifact under the `artifacts` key in `metadata.json` and link it from `review.md`.
* Keep `walkthrough.md` and `explanations/` artifacts factual (Register 1): no severity grades or verdicts. Keep `walkback/` artifacts in the structured investigation register (Register 2).
* Create the `explanations/` and `walkback/` subfolders only when at least one explanation or investigation artifact is written.
* Every `review.md` ends with a **Disclaimer and Human Review** section: the verbatim `## Code-Review` CAUTION disclaimer from `disclaimer-language.instructions.md` followed by an unchecked `- [ ] Reviewed and validated by a qualified human reviewer` checkbox. This section is always present, is always the final section, and the agent never checks the checkbox; only a human may convert `[ ]` to `[x]`.
* When the review scope targets a pull request or merge request, `review.md` includes a mandatory human-editable **PR Comment Draft** section with an unchecked posting checkbox. This section is the only place the general PR or MR comment is authored; the agent never reproduces the full drafted comment body in the conversational summary. The agent never checks the posting box; only the human may convert `[ ]` to `[x]`, and that check is the gate that authorizes posting the general PR or MR comment.
