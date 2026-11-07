---
name: code-review
description: 'Review a PR, branch comparison, commit, local changes, or selected code using shared evidence and focused perspectives, with an optional Code Review canvas.'
argument-hint: '[target] [profile=standard|full|custom] [depth=basic|standard|comprehensive] [mode=sweep|guided]'
license: CC-BY-4.0
user-invocable: true
---

# Code Review

## Goal

Explain the consequential defects in a change, what was reviewed, and what still
needs evidence. Keep one captured review surface and a human-editable report.

## Start

Activate `code-review-core` and `disclaimer-language` unless already loaded.
Use the core's contract and resolved script location. Show the canonical
Code-Review notice according to the disclaimer skill's cadence.

Resolve the explicit target before capturing evidence: PR/MR identity and its
base/head revisions, a named branch comparison, local mode, a commit, or selected
code. Reuse an existing review only when its repository and target match the
request. Ask about ambiguous targets; do not guess a base, fetch, check out a
branch, or mix dirty local content into a PR snapshot. An explicitly requested
local overlay is a separate review and cannot supply PR inline comments.

For PRs, use the available provider read capability to collect immutable target
identity, description, required checks, template checkboxes, and linked issues.
Paginate both inline discussion and timeline comments. Preserve provider IDs,
reply relationships, original/current anchors, and unknown resolution states.
Record partial or unavailable reads rather than inventing empty discussion.
Import only necessary sanitized data through the core snapshot contract.

## Scope and depth

Default to `sweep`: proceed after a clear target and a compact scope summary.
Use `guided` when requested; wait for the user's area, perspective, or depth
choices at those decision points. Keep the chosen scope visible and overridable.
Material ambiguity still requires input in either mode.

* `standard` selects functional, standards, and readiness. Add accessibility for
  interactive UI, markup, user-facing content, or accessibility documentation;
  add security for changed trust boundaries, auth, secrets, parsing, networking,
  persistence, or confirmed Security Plan Drift context.
* `full` selects all five perspectives. A perspective with no relevant surface
  returns a reasoned not-applicable result, not fabricated findings.
* `custom` uses the caller's selected perspectives. Clarify an ambiguous choice.
* A host's explicit `basic` profile selects functional and standards; preserve a
  more specific host-supplied perspective set.

Before selecting perspectives, find and confirm any Security Plan Drift baseline
as [references/integrations.md](references/integrations.md) describes, so a
confirmed baseline can add the security perspective. Correlation still waits
until the security findings are accepted.

Depth is independent of perspective selection. Use `standard` unless the caller
chooses otherwise or concrete risk supports another recommendation. Describe
the evidence and missing checks that matter; no fixed risk questionnaire is
required. The core owns the depth expectations shared with workers.

## Review flow

1. Capture the surface once through the core helper, or reuse identity-matched
   supplied evidence. Group files into coherent areas and record intent,
   before/after behavior, and relevant entry points from bounded evidence.
   Every captured file belongs to an area, including lockfiles, configuration,
   renames, deletions, and omissions. A file no perspective needs gets a
   reasoned not-applicable result rather than being left out.
2. Record scope and work assignments in the parent state. Opening an area or
   having no findings does not complete it. Give acceptance-criteria coverage
   one owner: functional for behavior, readiness for deliverable-only criteria.
   When neither is selected, assess the criteria inline or record them as
   unassessed. Missing story definitions remain unassessed.
3. Use inline review when the evidence fits one direct pass or the trace is
   tightly coupled. Activate the matching perspective skills and produce the
   same result records. For substantial independent work, dispatch every
   selected dependency-ready worker in one parallel batch. Context work can run
   alongside review; orientation is never a mandatory dispatch barrier.
4. Verify each returned claim against captured anchors, the relevant contract,
   and counter-evidence. Read additional context when needed; reuse unchanged
   evidence and do not rescan the entire source set at synthesis. Malformed or
   missing output leaves work incomplete. Retry only after a transient failure
   or a specific repair gives a reason to expect progress.
5. Apply confirmed optional domain comparisons from
   [references/integrations.md](references/integrations.md). Merge supported
   results, join duplicate defects once, and record accepted, disputed,
   deferred, or rejected dispositions with reasons. The parent owns the verdict;
   worker opinions do not override the core's coverage/severity rules.
6. Render the local report with the core helper. Preserve human edits, the
   canonical disclaimer, and unchecked human-review/posting boxes. Explain any
   incomplete coverage and the next useful action.

## Workers

| Responsibility                | Skill                       | Subagent                  |
|-------------------------------|-----------------------------|---------------------------|
| Correctness                   | `code-review-functional`    | Code Review Functional    |
| Project conventions           | `code-review-standards`     | Code Review Standards     |
| Accessibility                 | `code-review-accessibility` | Code Review Accessibility |
| Security consequences         | `code-review-security`      | Code Review Security      |
| Deliverable and documentation | `code-review-readiness`     | Code Review Readiness     |
| Area overview                 | `code-review-context`       | Code Review Orientation   |
| Factual explanation           | `code-review-context`       | Code Review Explainer     |
| Bounded investigation         | `code-review-investigation` | Code Review Walkback      |

Every dispatch supplies the resolved review root, review/snapshot IDs, state and
snapshot paths, work ID, assigned areas/files/hunks, depth and rationale,
applicable criteria, available validation, explicit question when relevant, and
the exact result path. Include the core write boundary and no nested dispatch.
Workers get no parent custom instructions. Consume their result, execution,
coverage, and limitations; validate before marking work complete.

If dispatch is unavailable, perform the selected work inline when feasible.
Otherwise record unavailable work and its missing capability. Do not silently
drop a selected perspective.

## Canvas and feedback

When `hve-core-code-review` is available, inspect its capabilities and open it
with `{ "state": "<workspace-relative review-state.json>" }`. Use a stable panel
ID and the host-reported provider; prefer the project provider when both project
and plugin providers apply. Never invent a provider identifier.

At dispatch/completion boundaries, before a material decision, and before
closeout, use `take_feedback` with `checkpoint: true`. Collect explicitly sent
items once by review/item ID; drafts remain private. Apply each item within the
review's authority, then call `record_interpretation` with what changed.
An investigation can run alongside unrelated review work. A simple explanation
uses existing evidence inline.

Use `get_state` to check source warnings and pending feedback, `focus_item` to
show an area/file/hunk/finding/comment, and `show_review` to reconnect an existing
panel. A missing or failed canvas does not block the report/chat workflow:
disclose the exact limitation and keep the same evidence and decisions.

## Host-managed automation

An explicit non-interactive host contract owns target acquisition, output,
freshness checks, and any authorized publication. Use its supplied evidence,
profile, and validation facts; mark derived choices as agent-owned. Do not ask
routine questions, require a canvas, or require local tracking artifacts when
the host forbids them. Use the same criteria, finding verification, and
incomplete-coverage rules in memory. An unresolved target or required evidence
gap returns a blocked/incomplete result through the host's contract.

## Authority and delivery

Keep reviewed source and Git state read-only. Even a validation command must
respect the review-owned write boundary. Source edits, installs, credentials,
and provider mutations are not implied by review.

For interactive publication, read
[references/delivery.md](references/delivery.md). Local reports, native staging,
and external posting are distinct. A canvas action grants none of those extra
permissions. Stop publication on stale evidence, incomplete required review,
unverified claims, missing human consent, or a draft conflict.

## Success and response

Success means the selected scope has validated coverage, findings have verified
evidence and dispositions, and the report is persisted without losing human
input. Unavailable evidence remains visible and cannot become approval.

Lead with the findings and their consequences, or state that no findings were
identified within the completed scope. Give execution and outcome separately,
link the report, explain limitations and pending work, and tell the user to
review the report before acting. For PRs, link the comment-draft section and
state its proposed event without pasting the draft or implying it was posted.
