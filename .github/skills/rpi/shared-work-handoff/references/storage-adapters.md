---
title: Shared Work Handoff Storage Adapters
description: Provider-neutral storage port and repository-files adapter contract for shared work handoffs
---

## Dependency Direction

Portable handoff policy depends on `HandoffStore`, opaque references, revisions, capabilities, and receipts. An adapter implements that port and maps provider evidence into the portable results. Core policy never derives authority from provider access and never imports provider-specific paths, revisions, or publication behavior.

V0 defines one adapter, `repository-files`. A future adapter must satisfy the same port and lifecycle semantics before it can be selected. There is no dynamic loader, registry, SDK, credential model, or fallback provider.

## Portable Types

* `HandoffId`: Stable handoff identity generated before first publication
* `FormatVersion`: Envelope format `1`; absent or unsupported versions are historical-only and cannot be mutated or projected into this lifecycle
* `ContentRevision`: Positive monotonic publication revision, starting at 1 and incremented for shared content, source baseline, audience, roles, scope, constraints, expiry, or other acceptance-relevant policy changes
* `EventSequence`: Positive contiguous sequence starting at 1 across the entire record; every effective event advances it, including responses that leave content revision unchanged
* `ConsumerKey`: Named recipient identity and the content revision being evaluated
* `PublicationPolicy`: Minimized revision-scoped recipients, publisher, canonical owner, resolver, disposition permissions, authority provenance, and exact verification pointers retained in publication history
* `HandoffRef`: Opaque provider reference returned by `locate` or `publish`
* `ProviderRevision`: Opaque concurrency token for one observed provider object
* `ExpectedRevision`: Content revision, event sequence, and predecessor `ProviderRevision`, or explicit first-publication absence
* `Capabilities`: Provider declarations for bounded discovery, optimistic concurrency, append, audience enforcement, retention, physical erasure, and receipt verification
* `Receipt`: Adapter ID, opaque handoff reference, provider revision, actor, observed time, and provider verification evidence
* `StoreFailure`: `not-found`, `ambiguous`, `conflict`, `unsupported-capability`, `unsupported-format`, `historical-verification-failed`, `unauthorized`, `inaccessible`, or `invalid-record`

Receipts prove what the adapter observed. They do not prove disclosure approval, recipient acceptance, business authority, or canonical adoption.

## HandoffStore Port

This section is a declarative behavioral contract. V0 does not ship an executable interface, loader, or provider SDK. Skill behavior applies these operations and result semantics when it prepares or verifies repository-file mutations.

### describe

`describe()` returns the adapter ID, required configuration, and capability declarations without reading handoff content. Core policy uses it to reject unsupported requirements before mutation.

### locate

`locate(handoffId, target)` performs bounded discovery inside the explicit target and returns zero or one opaque `HandoffRef`. More than one match returns `ambiguous`; the adapter does not choose by recency. Resolve only the supplied target or exact identity within its explicit root. Inaccessibility, ambiguity, revision mismatch, or a moved record without an explicit replacement stops discovery, never expands it.

### Work-Item Backlinks

A portable backlink contains handoff identity, owning repository/store scope, explicit bounded locator, content revision, and verified provider revision evidence. Provide two distinct references when available:

* Pinned publication reference: identifies the exact reviewed content/provider revision for reproducibility.
* Current locator: identifies the same record on an explicit current shared reference, so readers can verify its present publication status or declared successor.

A pinned historical publication does not establish present eligibility. Verify current publication status separately before continuation; unavailable current evidence blocks continuation, not historical reading. A URL, title, or tracker comment proves neither authority nor freshness. Follow a moved or superseded record only through an explicit replacement identity and bounded locator supplied for that purpose, never an inferred repository search.

Render a proposed backlink only after publication evidence has been verified. Review every title, summary, repository coordinate, and URL against the tracker's actual audience; broader disclosure needs separate approval. A local preview is not an externally resolvable record and cannot supply a publication link.

This contract supplies only a convention and optional local suggestion. Creating or updating a GitHub, Azure DevOps, or Jira backlink is a separate approved tracker mutation under the `backlog-management` skill's platform, sanitization, autonomy, and human-review controls. If those controls are unavailable, stop before tracker mutation. Publication consent is not backlink consent.

Synthetic pointer example: record `component-review`, store `example-repository`, bounded locator `.hve/handoffs/component-review.md`, content revision `2`, pinned reference `<verified-commit-and-blob>`, current reference `<explicit-shared-branch>`. Replace placeholders only from verified evidence and approved disclosure; no index or registry is implied.

### read

`read(handoffRef, selectedSharedRef)` returns the parsed portable record, ordered events, observed `ProviderRevision`, and recomputed observation evidence. For supported valid records, derive publication and consumer projections through the replay rules below. Never accept record-authored projections as authority. Unsupported formats or unavailable replay evidence may be inspected as labelled historical material but cannot produce current continuation eligibility. An observation receipt proves a read, not a new write or publisher approval.

### publish

`publish(record, target, expectedRevision)` prepares or writes one complete provider object using optimistic concurrency. It returns the proposed `HandoffRef`, expected successor evidence, and publication instructions. It does not make a local object shared and cannot return a finalized receipt before the separately authorized publication is observable on the selected shared reference.

### append

`append(handoffRef, event, expectedRevision)` prepares or writes one ordered event using whole-object optimistic concurrency. It rejects changed predecessors, invalid replay, terminal publications, and terminal consumer keys for consumer events. Consumer events require a subject; publication events omit it. A response-only append preserves content revision and every unaffected consumer projection. The event remains pending until finalization verifies the published object.

The port intentionally has no universal delete operation. Adapters declare physical-erasure capability, and core policy blocks affected content when the selected adapter cannot satisfy it.

### Deterministic Replay

Verify format and identity, then replay the single event stream in contiguous sequence order. `published` starts content revision 1 or increments the preceding content revision by one, retains the prior history unchanged, and binds the new policy snapshot and content to verified publication evidence. Verify initial publisher/disclosure authority independently; authorize later publications and policy replacements using the predecessor publication's verified policy, not the proposed replacement.

For every event, verify its content reference and applicable authority. `published` uses the predecessor policy or independently verified initial authority; other events use their own content revision's publication policy for actor authority and consumer eligibility. Evaluate each historical transition at its stream position and verified event time. Present-day expiry or invalidity blocks new continuation and disposition, not valid historical events.

Historical publisher, recipient, owner, resolver and disposition evidence comes from the retained snapshot and its exact verified provider references, not today's roster or the event's claimed role. A former eligible consumer remains valid history; later enrollment cannot authorize an earlier ineligible event. Missing required historical evidence returns `historical-verification-failed` and blocks every lifecycle mutation without reclassifying the subject as unauthorized.

Reject duplicate or skipped sequences, altered retained history, unknown subjects under verified policy, contradictory stored projections, invalid transitions, mismatched content references, and unsupported event vocabulary. Apply the owning skill's actor matrix per consumer/content-revision key. Publication state is `prepared`, `shared`, `withdrawn`, or `superseded`, never an aggregate consumer response. New content starts fresh consumers; response-only events do not. Expiry and invalidity block new continuation or disposition without deleting valid historical outcomes.

Store the policy snapshot in the same record. Map exact verification pointers into the adapter block. Current publication evidence is verified out of band, avoiding a receipt that claims its own blob; later publications can retain exact historical references once observed. Missing or unsupported format versions have no automatic migration or compatibility adapter. These are experimental declarative semantics, not an executable store or stable SDK/UI schema.

## Repository-Files Adapter

### Capabilities

| Capability             | Declaration | Behavior                                                        |
|------------------------|-------------|-----------------------------------------------------------------|
| Bounded discovery      | Supported   | Searches only the explicit tracked root for one handoff ID      |
| Optimistic concurrency | Supported   | Compares content revision, sequence, and provider predecessor   |
| Ordered append         | Supported   | Rewrites one Markdown record with one next-sequence event       |
| Audience enforcement   | Unsupported | Repository access is not audience or disclosure authorization   |
| Configurable retention | Limited     | Working-tree policy cannot remove published history             |
| Physical erasure       | Unsupported | Affected content is rejected before preparation                 |
| Finalized receipt      | Supported   | Recomputed from the selected shared reference after publication |

### Configuration and Mapping

* Adapter ID: `repository-files`
* Default tracked root: `.hve/handoffs/`
* Optional root: An explicit normalized repository-relative path outside `.git/` and `.copilot-tracking/`
* Object mapping: One handoff ID maps to `<tracked-root>/<handoff-id>.md`
* Discovery: Search only the configured tracked root for the exact handoff ID; reject zero or multiple matches
* Shared reference: An explicitly selected branch, tag, or commit that the recipient can resolve
* Provider revision: The observed commit ID and content blob ID for the mapped file
* Source branch: The explicit branch whose current implementation state is compared with the portable observed source revision

Reject absolute paths, traversal, symlink escape, a target outside the selected repository, or a broad repository search. The adapter does not infer a branch, remote, repository, or publication action.

### Preview

Before local mutation, capture:

* Handoff ID, format version, and proposed content revision
* Target path and selected shared reference
* Expected predecessor content revision and event sequence
* Expected predecessor commit ID and blob ID, or explicit first-publication absence
* Explicit source branch and its observed current commit ID when the handoff describes repository-backed source work
* Proposed next event sequence, exact event, actor, and consumer subject when relevant
* Exact local file mutation
* Exact publication action requiring separate user consent

The template adapter block stores the target coordinates and predecessor evidence. It never stores the finalized receipt for the current blob.

An optional observed source revision belongs to the portable record, not this adapter block. It identifies the repository baseline the described work started from or was observed against. It never predicts the later commit and blob that publish the handoff. When uncommitted source changes matter, the record marks the source state as dirty and summarizes their bounded scope separately.

### Finalize

After the user separately authorizes and performs publication, re-read the mapped file from the same selected shared reference. Compare:

1. Target path and handoff ID
2. Parsed format version and content revision
3. Expected predecessor revision recorded by the prepared mutation
4. Expected event sequence, exact content, actor, subject, and derived projections
5. Observed commit ID and blob ID

When all values match, return a finalized receipt containing adapter ID, opaque handoff reference, provider revision, actor, observed time, selected shared reference, commit ID, and blob ID. The receipt is returned out of band or recomputed by `read`; embedding it in the blob it identifies would create a self-reference.

If the object is absent from the selected shared reference, return `still-prepared`. If any value differs, return `conflict` with the mismatched fields. Do not silently merge, retry, select another reference, overwrite, or make a pending event effective. Two writers previewing the same predecessor cannot both finalize against different successor objects. Require explicit reread and a fresh preview after conflict. Another consumer's acceptance survives that new preview only when its content revision is unchanged and all gates still hold; a conflict itself does not invalidate unrelated acceptance.

### Source-State Comparison

During `resume preview`, resolve only the explicit source branch and compare its current commit ID with the portable observed source revision:

* `unchanged`: The commit IDs are equal
* `advanced`: The observed source revision is an ancestor of the current source commit
* `diverged`: The revisions differ and the observed source revision is not an ancestor of the current source commit
* `unknown`: Either revision is absent or cannot be resolved

Return both commit IDs and the comparison result without changing the branch. For `advanced`, `diverged`, or `unknown`, core policy requires the recipient to select `observed-source` or `current-source`, or request clarification, before acceptance. Store the comparison, choice, and selected revision in the prepared response event. This evidence records a continuation decision; it does not change repository state or grant canonical authority.

## Future Adapter Conformance

A proposed adapter must document all five operations, capability declarations, bounded identity resolution, opaque concurrency tokens, preview and finalize behavior, receipt evidence, conflict handling, audience limitations, retention and erasure behavior, and the mapping from provider objects to ordered portable events.

Conformance requires the same format boundary, revision-scoped authority replay, independent consumer transitions, content and event revision rules, and terminal scope. Provider-specific strengths may add capabilities, but cannot weaken disclosure review, recipient acceptance, historical verification, conflict visibility, or consent for external mutation.
