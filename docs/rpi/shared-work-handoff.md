---
title: Share Context and Continue Work
description: Read bounded repository context and decision rationale without accepting work, or continue independently through an approved handoff
sidebar_position: 5
author: Microsoft
ms.date: 2026-10-06
ms.topic: how-to
keywords:
  - shared work handoff
  - contributor handoff
  - rpi
  - repository collaboration
  - copilot tracking
estimated_reading_time: 12
---

Use `/shared-work-handoff` to read approved repository context without taking responsibility for paused work, or to prepare context that named contributors can independently accept. One checked-in Markdown record preserves bounded decisions and continuation evidence without copying private working state. The skill is optional, manual-only, and experimental; its storage port is a declarative contract, not a running service.

> [!IMPORTANT]
> A handoff is continuation context, not canonical authority. Normal repository review, ownership, and approval rules decide whether code, documentation, ADRs, or other artifacts are adopted.

## Choose the Right Continuation Method

| Situation                                                          | Use                                                             |
|--------------------------------------------------------------------|-----------------------------------------------------------------|
| You are continuing in the same working copy                        | Open the relevant workspace-local `.copilot-tracking` artifacts |
| You need context or rationale without taking over work             | Use `/shared-work-handoff read` with an exact shared reference  |
| Another named contributor must continue the work                   | Use `/shared-work-handoff` with `provider=repository-files`     |
| The authorized owner can update the canonical artifact now         | Make the direct change and use the `direct-adoption` outcome    |
| The content requires physical erasure or lacks disclosure approval | Stop with `blocked` or keep it `local-only`                     |

`.copilot-tracking` survives chat resets and can support later sessions in the same available working copy. Because it is gitignored, teammates and fresh clones cannot depend on it. The repository-files provider uses `.hve/handoffs/` by default for the minimized record that contributors intentionally review and share.

## Read Without Accepting Work

Supply one exact target and shared reference:

```text
/shared-work-handoff read provider=repository-files target=.hve/handoffs/cache-retry.md shared-ref=main
```

Reading verifies access, identity, format, revision, and observed publication evidence. It creates no local record, response, acceptance, or write receipt and needs no preview/finalize stage. You do not need to be a named continuation recipient. Expired, withdrawn, superseded, unsupported-version, or unverifiable material is labelled historical and cannot authorize continuation. Missing continuation evidence does not prevent safe inspection of an accessible record.

The approved disclosure audience is everyone who can read the repository, including the public for a public repository. Team relevance is metadata, not an access control. If a narrower audience or physical erasure is required, stop before reading private sources for preparation: this adapter cannot meet that requirement.

## Assign the Roles

| Role              | Responsibility                                                                  |
|-------------------|---------------------------------------------------------------------------------|
| Publisher         | Selects explicit sources, minimizes content, and has disclosure authority       |
| Reader            | Inspects accessible context without accepting work or acquiring ownership       |
| Named consumer    | Reviews one verified content revision and responds for their own identity       |
| Conflict resolver | Resolves competing revisions or is explicitly recorded as `none`                |
| Canonical owner   | Decides whether accepted work is adopted through ordinary repository governance |

Repository access permits reading but grants no response, publication, or disposition authority. Keep disclosure audience, intended relevance/owning team, named continuation recipients, and canonical owner distinct. Name actors before preparation; neither team membership nor the publisher can accept on a consumer's behalf. Publisher self-acceptance is prohibited.

## Distinguish Content, Events, and Provider Evidence

The versioned envelope separates acceptance identity from event ordering and storage concurrency:

| Evidence                    | Meaning                                             | When it is known                           |
|-----------------------------|-----------------------------------------------------|--------------------------------------------|
| Format version `1`          | Version of the declarative envelope contract        | Before preparation                         |
| Content revision            | Accepted content and acceptance-relevant policy     | Advances with each content publication     |
| Event sequence              | Global order of all publication and consumer events | Advances with every effective event        |
| Provider revision           | Opaque token for the whole stored object            | Observed through the selected provider     |
| Observed source revision    | Repository state that the work describes            | Before preparing or publishing the handoff |
| Handoff publication receipt | Commit and blob that contain the checked-in handoff | Only after publication and finalization    |

For a clean Git working tree, the observed source revision is usually the current `HEAD` commit. It is not the future commit that will add or update `.hve/handoffs/<handoff-id>.md`.

For a dirty working tree, the current `HEAD` still identifies the last committed baseline, but it does not include uncommitted changes. Mark the source state as `dirty` and provide a bounded summary of those changes. Use `unknown` rather than inventing a revision when no reliable baseline is available.

Content revision changes when shared content, source baseline, audience, roles, scope, constraints, expiry, or acceptance policy changes. A response-only append changes event sequence and provider revision, not content revision. Old unversioned or unsupported-version records can be inspected only as historical evidence; mutations stop with an explanation. There is no automatic migration or stable SDK/UI schema promise.

## Continue Independently From One Publication

In this synthetic example, the publisher names both Developer B and Developer C for content revision 1:

| Event                           | Publication | Developer B, revision 1 | Developer C, revision 1  |
|---------------------------------|-------------|-------------------------|--------------------------|
| Publisher publishes revision 1  | `shared`    | `unaccepted`            | `unaccepted`             |
| B accepts revision 1            | `shared`    | `accepted`              | `unaccepted`             |
| C requests clarification        | `shared`    | `accepted`              | `awaiting-clarification` |
| Canonical owner adopts B's work | `shared`    | `adopted`               | `awaiting-clarification` |
| Publisher publishes revision 2  | `shared`    | Historical `adopted`    | Historical clarification |

Revision 2 starts fresh consumer keys. C cannot accept the revision for which clarification was requested; a newer publication is required. Rejection and either closure are terminal only for that consumer/revision key. Adoption does not terminate the publication or another consumer's work. Conflicting canonical decisions go to the named owner through ordinary review, not automatic reconciliation.

If B and C preview writes from the same provider predecessor, a competing write returns `conflict`. There is no silent merge, overwrite, retry, or reference switch. After an explicit reread and new preview, unchanged content can preserve the other consumer's acceptance when all gates still hold. A content change, expiry, invalidity, withdrawal, or supersession blocks reliance on old acceptance for new continuation or disposition.

Each content publication retains its own eligible recipients, publisher, owner, resolver, disposition permissions, and verified authority provenance. If revision 2 removes B or replaces the owner, valid revision 1 events stay valid history under revision 1 policy, never current acceptance. Later enrollment cannot legitimize an earlier ineligible response. Missing historical verification evidence blocks lifecycle mutations while allowing labelled historical reading.

## Preserve Scoped Decision Rationale

Record the decision's bounded component or paths, owner, authority/status, and safe canonical or evidence pointer. An engineer's local decision is not a repository-wide rule.

For example, a synthetic cache record may say that a queue was deferred because the observed latency requirement did not justify another service. An optional Alternatives Considered entry records the option, rejected/deferred/not-investigated disposition, known reason, deciding constraint, and safe evidence pointer. If the supplied history does not explain why, record `unknown`; do not invent rationale or request private reasoning traces.

## Follow a Developer A-to-Developer B Example

Developer A researched and planned a cache retry feature, then completed phase 1 of 4 before pausing. Their detailed RPI files remain in their private `.copilot-tracking` directory. Developer B needs enough safe context to establish local RPI state and continue from the current branch.

### Developer A prepares the record

Developer A explicitly supplies the relevant private RPI artifacts, shared repository files, and external references. The skill reads only those sources and publishes safe summaries rather than private paths or source bodies.

```text
/shared-work-handoff prepare preview provider=repository-files target=.hve/handoffs/cache-retry.md

Sources:
- Private working artifact: cache retry research
- Private working artifact: approved four-phase cache retry plan
- Shared repository artifact: src/cache/retry.ts
- Shared repository artifact: tests/cache/retry.test.ts
- External reference: public retry guidance at <public URL>
Recipient: Developer B
Publisher: Developer A
Conflict resolver: Cache maintainers
Canonical owner: Cache maintainers
Disclosure audience: all repository readers, including public access if applicable
Disclosure authority: approved for that actual audience
Intended relevance: Cache team
Retention: repository history is acceptable
Source branch: feature/cache-retry
Observed source revision: abc123
Source state: clean
```

The continuation portion of the rendered record contains concrete content rather than broad placeholders:

```markdown
## RPI Continuation

* Journey summary: Research established bounded retry behavior and planning divided delivery into four phases. Implementation completed phase 1 before the publisher paused.
* Current pause point: Implement, phase P01 complete; P02 is next.
* Completed scope: Research, Plan, and P01 configuration model.
* Remaining scope: P02 retry execution, P03 tests, and P04 documentation and validation.
* Exact next RPI action: Use the accepted handoff and selected branch baseline as explicit inputs to `/rpi-plan` to create recipient-local planning state, then continue with `/rpi-implement` after confirming the remaining phases.

### Mode History

| RPI mode  | Minimized prompt intent                                     | Outcome and status                           | Artifact pointer                         |
|-----------|-------------------------------------------------------------|----------------------------------------------|------------------------------------------|
| Research  | Determine retry safety, limits, and existing cache behavior | Complete; selected bounded exponential retry | Private working artifact summarized here |
| Plan      | Define four independently verifiable delivery phases        | Complete; approved before implementation     | Private working artifact summarized here |
| Implement | Execute the approved phases                                 | Paused after P01                             | Current branch and shared source files   |
| Review    | Compare implementation with the approved plan               | Not started                                  | None                                     |

### Supplied Context

| Source class               | Pointer or safe label     | Recipient availability | Safe background and contribution                | Sensitivity handling                      |
|----------------------------|---------------------------|------------------------|-------------------------------------------------|-------------------------------------------|
| Private working artifact   | Cache retry research      | Publisher-only         | Established retry limits and failure risks      | Path and working notes excluded           |
| Private working artifact   | Approved cache retry plan | Publisher-only         | Defined P01 through P04 and completion criteria | Path and private session content excluded |
| Shared repository artifact | src/cache/retry.ts        | Shared                 | Contains the completed P01 configuration model  | Repository content referenced, not copied |
| External reference         | Public retry guidance     | External               | Supports the selected backoff limits            | Pointer and safe synopsis only            |

### Issues and Learnings

| Kind     | Minimized detail                                | Disposition or continuation effect                 | Evidence pointer         |
|----------|-------------------------------------------------|----------------------------------------------------|--------------------------|
| Issue    | Initial retry ownership was ambiguous           | Resolved with Cache maintainers as canonical owner | Handoff decision summary |
| Learning | Existing timeout behavior must remain unchanged | Applies to P02 implementation and P03 tests        | Shared test pointer      |

### Phase Map

| Phase | Purpose                    | Status      | Completion meaning                                                    | Evidence pointer                |
|-------|----------------------------|-------------|-----------------------------------------------------------------------|---------------------------------|
| P01   | Define retry configuration | Complete    | Configuration parses and preserves current defaults                   | Current branch and shared tests |
| P02   | Implement retry execution  | Not started | Retry count, backoff, and timeout behavior meet the accepted criteria | Handoff acceptance criteria     |
| P03   | Add behavior coverage      | Not started | Success, exhaustion, timeout, and disabled paths pass                 | Handoff acceptance criteria     |
| P04   | Document and validate      | Not started | User guidance and owning validation pass                              | Handoff acceptance criteria     |
```

### Developer B chooses the continuation baseline

Before Developer B reviews the handoff, `feature/cache-retry` advances from `abc123` to `def456`. `resume preview` reports `advanced`, presents both revisions, and does not infer which one to use.

Developer B chooses `current-source` at `def456` after inspecting the current branch. The prepared acceptance event records that choice. If Developer B instead needs the earlier state, they can choose `observed-source` at `abc123` or request clarification.

After `resume finalize` verifies the acceptance event, Developer B uses the accepted handoff and selected revision as explicit inputs to `/rpi-plan`. This creates recipient-local planning state from the minimized phase map before `/rpi-implement` continues the remaining work. The handoff never exposes Developer A's private RPI files.

## Prepare the Handoff

Invoke preview with explicit sources, audience, roles, target, and revision expectations:

```text
/shared-work-handoff prepare preview provider=repository-files target=.hve/handoffs/api-timeout.md

Sources: src/api/timeouts.ts, tests/api/timeouts.test.ts
Recipient: @recipient
Publisher: @publisher
Conflict resolver: @maintainer
Canonical owner: API maintainers
Disclosure audience: all repository readers, including public access if applicable
Disclosure authority: approved for that actual audience
Intended relevance: API team
Retention: repository history is acceptable
Observed source revision: current HEAD
Source state: dirty; timeout implementation and tests are uncommitted
```

Preview checks the provider capabilities and renders the exact proposed file mutation. Review it for secrets, unnecessary personal data, inaccessible evidence pointers, and unrelated task content.

The skill must stop before publication when:

* The audience or disclosure authority is missing
* Content requires physical erasure from Git history
* Secrets or unauthorized personal data remain
* The target, actor authority, or expected revision is ambiguous
* Required evidence pointers are inaccessible

## Publish and Finalize

Preview does not commit or push. It identifies the external publication action and asks for separate consent. Follow your repository's normal Git and review process to publish the handoff file.

After publication, invoke the same mutation mode with `finalize` and the selected shared reference. Finalization compares identity, format, content revision, predecessor evidence, event sequence, exact event, actor, consumer subject when applicable, commit, and blob. The receipt stays out of band so it cannot claim its own blob.

| Result           | Meaning                                                             |
|------------------|---------------------------------------------------------------------|
| `shared`         | The selected shared object matches the prepared handoff             |
| `still-prepared` | The expected object is not present on the selected shared reference |
| `conflict`       | Identity, revision, event, commit, or blob evidence differs         |

Publication approval is requested for every exact action. No remembered approval or setup-memory mode is provided. Do not silently retry a conflict against another branch or carry acceptance across changed content.

## Resume as the Recipient

The named consumer uses `resume preview` with one explicit handoff and shared reference. The skill verifies eligibility under the current publication policy, actual access, expiry, publication and consumer state, revisions, and evidence accessibility before offering continuation.

The recipient prepares one response:

* `accepted` for that identity, verified content revision, source comparison, and selected baseline/revision
* `rejected` with a minimized reason
* `clarification-requested` before a newer publication

The event has no lifecycle effect until `resume finalize` verifies it in the selected shared object. A response-only append leaves other consumers unchanged; a new content revision requires fresh acceptance. When source comparison is advanced, diverged, or unknown, explicitly choose observed-source or current-source and its revision, or request clarification. Unchanged source records the observed-source baseline. Acceptance never changes a branch.

## Close the Handoff

Use `close preview` to prepare exactly one permitted disposition and its scope:

* `adopted` for one accepted consumer/current-revision key after canonical-owner review
* `closed-without-adoption` for one accepted consumer/current-revision key under the policy's disposition authority
* `withdrawn` publication-wide by an authorized publisher only when no current-revision consumer is accepted
* `superseded` with the successor handoff identifier when another handoff replaces it

Run `close finalize` after the terminal event is published. The skill can render sanitized local experiment feedback, but it does not submit telemetry or task content.

For consumer closure, the acting canonical owner and consumer subject are distinct fields. For withdrawal or supersession, omit the consumer subject. Supersession requires the publisher or named resolver and a successor identity; use it instead of withdrawal when a current consumer is accepted. Neither publication-wide outcome erases Git history or prior terminal evidence.

## Follow a Work-Item Backlink

A synthetic work-item pointer might identify `cache-retry` in `example-repository`, the bounded target `.hve/handoffs/cache-retry.md`, content revision 2, a verified pinned commit/blob, and an explicit current branch locator. The pinned reference reproduces reviewed content; the current locator reveals current publication status or supersession. Neither the URL nor the comment grants authority or proves freshness.

Only the supplied target or exact identity in its explicit root is resolved. Ambiguous, inaccessible, moved-without-replacement, or revision-mismatched records stop discovery without a broader scan. Verify current status separately before continuing from a pinned historical reference.

A proposed backlink needs verified publication first. Review its title, summary, coordinates, and URL for the tracker audience, obtaining separate approval for broader disclosure. Creating or updating a GitHub, Azure DevOps, or Jira link is a separate approved tracker operation under backlog-management controls, never an automatic handoff step.

## Take the Optional PR Offer

PR preparation may offer this command with proposed sources, target, and actual audience for you to complete and invoke:

```text
/shared-work-handoff prepare preview
```

The PR workflow does not load or invoke the manual-only skill or prepare the handoff itself. Declining the offer changes nothing. Diff access does not authorize private-source reading. A preview stages, commits, pushes, submits, finalizes, and backlinks nothing.

Resume ordinary PR preparation by explicit direction after taking this detour; only independently verified publication and disclosure approval permit a link in the PR body. Final PR-write approval remains separate from handoff and tracker approvals.

## Use a Closed Handoff for Later RPI Work

A finished or closed handoff can inform a later feature built on the completed work. Supply its exact path explicitly to the appropriate new RPI mode, usually `/rpi-research` when assumptions need revalidation or `/rpi-plan` when the new feature is already understood.

The new RPI flow must:

* Verify the relevant historical publication or consumer state and canonical disposition
* Compare its source baseline with the then-current branch
* Treat prior decisions and learnings as historical evidence rather than current authority
* Create new workspace-local research, plan, details, changes, and review records as needed
* Preserve terminal consumer keys and terminal publications instead of reopening them for new feature work

This supports Developer B handing established context to Developer C later without turning the handoff into a permanent task ledger or silently resuming old work.

## Experimental Boundary

This is an experimental declarative contract for repository-readable context and independent continuation, not an executable store, stable SDK/UI API, or measured scaling result. For example, the two-consumer walkthrough above checks document consistency; it does not prove model behavior or concurrent storage enforcement. Git retention remains the actual retention boundary, with no physical-erasure guarantee.

Restricted-team adapters, remembered consent, native-session integration, UI implementation, and general ledger/indexing services remain deferred. Lint and documentation checks do not establish model conformance, host interoperability, tracker behavior, or scalability. Evaluation/Vally work requires separately authorized scope.

## Related Guidance

* [RPI overview](./) for the workspace-local lifecycle artifacts
* [Using RPI Together](using-together) for the complete RPI workflow
* [Context Engineering](context-engineering) for chat resets and focused resumption
* [Skill reference](../reference/skills/rpi/shared-work-handoff) for invocation metadata

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
