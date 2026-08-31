---
title: Shared Work Handoff Storage Adapters
description: Provider-neutral storage port and repository-files adapter contract for shared work handoffs
---

## Dependency Direction

Portable handoff policy depends on `HandoffStore`, opaque references, revisions, capabilities, and receipts. An adapter implements that port and maps provider evidence into the portable results. Core policy never derives authority from provider access and never imports provider-specific paths, revisions, or publication behavior.

V0 defines one adapter, `repository-files`. A future adapter must satisfy the same port and lifecycle semantics before it can be selected. There is no dynamic loader, registry, SDK, credential model, or fallback provider.

## Portable Types

* `HandoffId`: Stable handoff identity generated before first publication
* `SemanticRevision`: Monotonic record revision changed whenever portable content or a pending event changes
* `HandoffRef`: Opaque provider reference returned by `locate` or `publish`
* `ProviderRevision`: Opaque concurrency token for one observed provider object
* `ExpectedRevision`: Semantic revision plus optional predecessor `ProviderRevision`
* `Capabilities`: Provider declarations for bounded discovery, optimistic concurrency, append, audience enforcement, retention, physical erasure, and receipt verification
* `Receipt`: Adapter ID, opaque handoff reference, provider revision, actor, observed time, and provider verification evidence
* `StoreFailure`: `not-found`, `ambiguous`, `conflict`, `unsupported-capability`, `unauthorized`, `inaccessible`, or `invalid-record`

Receipts prove what the adapter observed. They do not prove disclosure approval, recipient acceptance, business authority, or canonical adoption.

## HandoffStore Port

This section is a declarative behavioral contract. V0 does not ship an executable interface, loader, or provider SDK. Skill behavior applies these operations and result semantics when it prepares or verifies repository-file mutations.

### describe

`describe()` returns the adapter ID, required configuration, and capability declarations without reading handoff content. Core policy uses it to reject unsupported requirements before mutation.

### locate

`locate(handoffId, target)` performs bounded discovery inside the explicit target and returns zero or one opaque `HandoffRef`. More than one match returns `ambiguous`; the adapter does not choose by recency.

### read

`read(handoffRef, selectedSharedRef)` returns the parsed portable record, ordered events, current `ProviderRevision`, and a recomputed finalized receipt for the observed object. It rejects malformed identity, duplicate sequence numbers, invalid revisions, and unsupported event vocabulary.

### publish

`publish(record, target, expectedRevision)` prepares or writes one complete provider object using optimistic concurrency. It returns the proposed `HandoffRef`, expected successor evidence, and publication instructions. It does not make a local object shared and cannot return a finalized receipt before the separately authorized publication is observable on the selected shared reference.

### append

`append(handoffRef, event, expectedRevision)` prepares or writes one ordered event using optimistic concurrency. It rejects a changed predecessor, duplicate sequence, invalid transition, or terminal record. The event remains pending until finalization verifies the published object.

The port intentionally has no universal delete operation. Adapters declare physical-erasure capability, and core policy blocks affected content when the selected adapter cannot satisfy it.

## Repository-Files Adapter

### Capabilities

| Capability             | Declaration | Behavior                                                          |
|------------------------|-------------|-------------------------------------------------------------------|
| Bounded discovery      | Supported   | Searches only the explicit tracked root for one handoff ID        |
| Optimistic concurrency | Supported   | Compares semantic revision, predecessor object ID, and content ID |
| Ordered append         | Supported   | Rewrites one Markdown record with one next-sequence event         |
| Audience enforcement   | Unsupported | Repository access is not audience or disclosure authorization     |
| Configurable retention | Limited     | Working-tree policy cannot remove published history               |
| Physical erasure       | Unsupported | Affected content is rejected before preparation                   |
| Finalized receipt      | Supported   | Recomputed from the selected shared reference after publication   |

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

* Handoff ID and proposed semantic revision
* Target path and selected shared reference
* Expected predecessor semantic revision
* Expected predecessor commit ID and blob ID, or explicit first-publication absence
* Explicit source branch and its observed current commit ID when the handoff describes repository-backed source work
* Proposed event sequence and actor
* Exact local file mutation
* Exact publication action requiring separate user consent

The template adapter block stores the target coordinates and predecessor evidence. It never stores the finalized receipt for the current blob.

An optional observed source revision belongs to the portable record, not this adapter block. It identifies the repository baseline the described work started from or was observed against. It never predicts the later commit and blob that publish the handoff. When uncommitted source changes matter, the record marks the source state as dirty and summarizes their bounded scope separately.

### Finalize

After the user separately authorizes and performs publication, re-read the mapped file from the same selected shared reference. Compare:

1. Target path and handoff ID
2. Parsed semantic revision
3. Expected predecessor revision recorded by the prepared mutation
4. Expected event sequence and content
5. Observed commit ID and blob ID

When all values match, return a finalized receipt containing adapter ID, opaque handoff reference, provider revision, actor, observed time, selected shared reference, commit ID, and blob ID. The receipt is returned out of band or recomputed by `read`; embedding it in the blob it identifies would create a self-reference.

If the object is absent from the selected shared reference, return `still-prepared`. If any value differs, return `conflict` with the mismatched fields. Do not retry, select another reference, overwrite, preserve prior acceptance, or make the pending event effective automatically.

### Source-State Comparison

During `resume preview`, resolve only the explicit source branch and compare its current commit ID with the portable observed source revision:

* `unchanged`: The commit IDs are equal
* `advanced`: The observed source revision is an ancestor of the current source commit
* `diverged`: The revisions differ and the observed source revision is not an ancestor of the current source commit
* `unknown`: Either revision is absent or cannot be resolved

Return both commit IDs and the comparison result without changing the branch. For `advanced`, `diverged`, or `unknown`, core policy requires the recipient to select `observed-source` or `current-source`, or request clarification, before acceptance. Store the comparison, choice, and selected revision in the prepared response event. This evidence records a continuation decision; it does not change repository state or grant canonical authority.

## Future Adapter Conformance

A proposed adapter must document all five operations, capability declarations, bounded identity resolution, opaque concurrency tokens, preview and finalize behavior, receipt evidence, conflict handling, audience limitations, retention and erasure behavior, and the mapping from provider objects to ordered portable events.

Conformance requires the same actor-authorized transitions and semantic revision rules. Provider-specific strengths may add capabilities, but cannot weaken disclosure review, recipient acceptance, terminal exclusivity, conflict visibility, or consent for external mutation.
