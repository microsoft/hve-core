---
name: pull-request
description: 'Drafts or opens a GitHub pull request from the current branch with a concise, template-aware description and changed-area preflight checks. Use when a user asks to prepare, create, open, or update a pull request.'
argument-hint: '[base=auto] [draft=false] [action=prepare|create|update]'
license: MIT
user-invocable: true
compatibility: 'Requires git on PATH and a GitHub integration for create or update actions'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0.0"
  last_updated: "2026-09-04"
---

# Pull Request

## Goal

Turn the current branch into a review-ready GitHub pull request with a short, accurate description
and enough targeted local evidence to catch likely CI failures without running broad validation by
default.

Success means the title and body reflect the committed branch diff, the repository template is
preserved when present, changed-area preflight checks pass, and an external pull request is created
or updated only after one final approval.

## Inputs

* `base`: Base branch or ref. Default to the remote default branch without fetching.
* `draft`: Whether a newly created pull request is a draft. Default to `false`.
* `action`: `prepare`, `create`, or `update`. Infer from the request and default to `prepare` when
  external write intent is unclear.

Use the current checked-out branch as the head. Ask only for an input that cannot be inferred and
changes the resulting pull request.

## Flow

1. Run the platform-matching script in `scripts/` to collect branch, commit, changed-file, diff-stat,
   worktree, base-divergence, and template context. The script uses the local remote-tracking ref and
   does not fetch, merge, rebase, push, or edit the branch.
2. Stop if the repository, head branch, base ref, or merge base cannot be resolved. If the branch has
   no committed changes from the merge base, report that there is nothing to submit. Treat
   uncommitted files as excluded from the pull request and ask whether to continue only when the
   user's intent appears to include them. Before an external write, stop with sync guidance when the
   reported upstream push state is `behind` or `diverged`.
3. Inspect the committed diff from the reported merge base. Start with changed files and diff stats,
   then read the diffs that determine reviewer-visible behavior. Group related files and use
   delegation only when a large, separable diff would materially benefit from isolated review.
4. Derive the title from the branch and commits. Follow the repository's title convention when one
   exists; otherwise use a concise imperative title. Extract closing issue references only when they
   appear in branch or commit evidence.
5. Build `.copilot-tracking/pr/pr.md`. Use the discovered repository template and preserve its
   heading order, comments, and manual-review checkboxes. If no template exists, copy
   `templates/pull-request.md`. Replace instructional placeholders with verified content while
   keeping unsupported human attestations unchecked. Apply any repository instructions that match
   the pull request artifact.
6. Write for a human reviewer. Open with one plain-language summary, group the material changes by
   reviewer concern, and include only evidence-backed impact, compatibility, security, migration,
   testing, and follow-up details. Omit empty optional sections in the fallback template. Avoid a
   commit transcript, exhaustive file inventory, implementation chronology, and claims not supported
   by the diff or commits.
7. Apply the public-output guard from the applicable content-policy instructions. Do not copy private
   classifications, sensitive values, or raw suspect content into the pull request body.
8. Run the CI-confidence gate. Always run `git diff --check` against the committed branch diff, then
   select the smallest non-mutating checks that own the changed areas from package scripts,
   path-scoped instructions, and workflow configuration. Prefer focused tests, syntax checks,
   check-mode generators, and artifact validators. Do not run full validation aggregates, CI-prefixed
   commands, browser suites, service-dependent tests, security scans, or unrelated checks unless the
   user explicitly requests them or no narrower reliable owner exists. Follow repository dependency
   bootstrap rules before dependency-backed commands.
9. Record only checks that actually ran in the pull request. Leave hosted CI checks and human review
   attestations unchecked. If a required targeted check fails, keep the prepared description but stop
   before external creation or update; report the failure without changing branch source unless the
   user asks for a fix.
10. For `prepare`, return the proposed title, the body path, base and head branches, divergence, and
    preflight result. For `create` or `update`, also search for an open pull request with the same head
    and base, then present the final title, body path, target, draft state, validation result, and
   upstream push state. Ask once for approval covering any needed push and the pull request write.
11. After approval, push the current branch when needed and use the available GitHub integration to
    create or update the pull request. Never force-push. If an open pull request already exists, update
    it only when the requested action permits; otherwise return its URL instead of creating a
    duplicate.

## Template Rules

Resolve templates in this order:

1. A caller-specified template
2. `.github/PULL_REQUEST_TEMPLATE.md` or `.github/pull_request_template.md`
3. A single Markdown template under `.github/PULL_REQUEST_TEMPLATE/`
4. `docs/PULL_REQUEST_TEMPLATE.md` or `docs/pull_request_template.md`
5. `templates/pull-request.md` in this skill

When multiple repository templates remain equally applicable, ask the user to choose. Repository
instructions may define section-specific mapping and manual-only checkboxes; apply those rules without
reintroducing a separate end-to-end workflow.

## CI Confidence

The local gate predicts likely CI outcomes; it does not claim that unrun hosted checks passed. Use
these priorities:

1. Checks explicitly required by applicable repository instructions for the changed paths
2. Focused tests for changed executable behavior
3. Linters, type checks, parsers, or check-mode generators for changed artifacts
4. `git diff --check` for patch hygiene

Do not mark the pull request ready for external creation when a required selected check failed,
dependencies needed for that check are unavailable, or generated projections known to be required are
stale. Report hosted status checks as pending after creation.

## Description Standard

Describe the final branch state in direct, neutral language. Give reviewers the context needed to
understand scope and risk, with the most important change first. Use short paragraphs and flat bullets
unless the repository template requires another shape. Mention files only when they help a reviewer
navigate or understand an important boundary.

Check a non-human template checkbox only when direct diff or command evidence proves its statement.
Never check a qualified-human review, security attestation, manual test, or hosted CI checkbox on the
user's behalf.

## Stop Rules

* Stop as `Blocked` when branch identity, base identity, merge base, template choice, or write authority
  cannot be resolved.
* Stop as `Revise` before an external write when a required targeted preflight check fails or the
  description has an unsupported claim.
* Stop as `Prepared` after writing and validating the local description when no external action was
  requested.
* Stop as `Created` or `Updated` only after returning the pull request URL and hosted CI state.

## Final Response

Return the outcome, title, base and head, pull request body path, targeted checks and results, skipped
broad checks, material limitations, and pull request URL when one exists. Keep the response brief and
do not repeat the full body.
