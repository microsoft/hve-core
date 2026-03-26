---
description: "Shared review artifact persistence protocol for code review agents - folder structure, metadata schema, verdict normalization, and writing rules - Brought to you by microsoft/hve-core"
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
        review.md       # full markdown review output
        metadata.json   # machine-readable summary (see schema below)
```

Sanitize the branch name by replacing every `/` with `-`
(e.g. `feat/my-feature` → `feat-my-feature`).

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
  "reviewer": "<agent or prompt name, e.g. code-review-standards, code-review-functional, or code-review-full>"
}
```

## Verdict Normalization

| Agent Output Verdict     | `verdict` value         |
|--------------------------|-------------------------|
| ✅ Approve                | `approve`               |
| 💬 Approve with comments | `approve_with_comments` |
| ❌ Request changes        | `request_changes`       |

## Writing Rules

* Always overwrite any existing `review.md` and `metadata.json` for the branch: only the latest review per branch is retained.
* Obtain the HEAD commit SHA with `git rev-parse HEAD` immediately before writing artifacts.
* Obtain the current UTC timestamp immediately before writing artifacts:
  * In POSIX-compatible shells, use `date -u +%Y-%m-%dT%H:%M:%SZ`.
  * In PowerShell, use `Get-Date -AsUtc -Format "yyyy-MM-ddTHH:mm:ssZ"`.
* `files_changed` must list only source files present in the diff (additions, modifications, or deletions). Filter by relevance - e.g. `.py`, `.sh`, `.ts`, `.tf` - excluding lock files, binaries, and build output.
* Do not write artifacts if the diff was empty and the review was aborted.
* The `reviewer` field must match the agent's or prompt's `name` from its frontmatter.

---

Brought to you by microsoft/hve-core
