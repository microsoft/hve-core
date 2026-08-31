---
title: Share Work for Another Contributor
description: Prepare, publish, resume, and close optional repository-backed handoffs without committing private workflow state
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-31
ms.topic: how-to
keywords:
  - shared work handoff
  - contributor handoff
  - rpi
  - repository collaboration
  - copilot tracking
estimated_reading_time: 12
---

Use `/shared-work-handoff` when a named contributor needs a minimized, reviewable continuation record that survives workspace, device, and contributor boundaries. The skill is optional and experimental. It publishes one checked-in Markdown file without committing private `.copilot-tracking` state.

> [!IMPORTANT]
> A handoff is continuation context, not canonical authority. Normal repository review, ownership, and approval rules decide whether code, documentation, ADRs, or other artifacts are adopted.

## Choose the Right Continuation Method

| Situation                                                          | Use                                                             |
|--------------------------------------------------------------------|-----------------------------------------------------------------|
| You are continuing in the same working copy                        | Open the relevant workspace-local `.copilot-tracking` artifacts |
| Another named contributor must continue the work                   | Use `/shared-work-handoff` with `provider=repository-files`     |
| The authorized owner can update the canonical artifact now         | Make the direct change and use the `direct-adoption` outcome    |
| The content requires physical erasure or lacks disclosure approval | Stop with `blocked` or keep it `local-only`                     |

`.copilot-tracking` survives chat resets and can support later sessions in the same available working copy. Because it is gitignored, teammates and fresh clones cannot depend on it. The repository-files provider uses `.hve/handoffs/` by default for the minimized record that contributors intentionally review and share.

## Assign the Roles

| Role              | Responsibility                                                                  |
|-------------------|---------------------------------------------------------------------------------|
| Publisher         | Selects explicit sources, minimizes content, and has disclosure authority       |
| Recipient         | Reviews one verified revision and accepts, rejects, or requests clarification   |
| Conflict resolver | Resolves competing revisions or is explicitly recorded as `none`                |
| Canonical owner   | Decides whether accepted work is adopted through ordinary repository governance |

Repository access does not grant any of these authorities. Name the actors before preparing a handoff, and do not let the publisher accept on the recipient's behalf.

## Understand the Two Revisions

The record can carry two different kinds of revision evidence:

| Evidence                    | Meaning                                             | When it is known                           |
|-----------------------------|-----------------------------------------------------|--------------------------------------------|
| Observed source revision    | Repository state that the work describes            | Before preparing or publishing the handoff |
| Handoff publication receipt | Commit and blob that contain the checked-in handoff | Only after publication and finalization    |

For a clean Git working tree, the observed source revision is usually the current `HEAD` commit. It is not the future commit that will add or update `.hve/handoffs/<handoff-id>.md`.

For a dirty working tree, the current `HEAD` still identifies the last committed baseline, but it does not include uncommitted changes. Mark the source state as `dirty` and provide a bounded summary of those changes. Use `unknown` rather than inventing a revision when no reliable baseline is available.

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
Disclosure authority: approved for repository contributors
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
Disclosure authority: approved for repository contributors
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

After publication, invoke the same mode with `finalize` and the selected shared reference. Finalization reads the published object and compares its identity, semantic revision, predecessor evidence, event sequence, commit, and blob.

| Result           | Meaning                                                             |
|------------------|---------------------------------------------------------------------|
| `shared`         | The selected shared object matches the prepared handoff             |
| `still-prepared` | The expected object is not present on the selected shared reference |
| `conflict`       | Identity, revision, event, commit, or blob evidence differs         |

Do not silently retry a conflict against another branch or preserve acceptance from an older semantic revision.

## Resume as the Recipient

The recipient uses `resume preview` with one explicit handoff and shared reference. The skill verifies audience membership, expiry, lifecycle state, revisions, and evidence accessibility before presenting the minimized context.

The recipient prepares one response:

* `accepted` for the verified semantic revision
* `rejected` with a minimized reason
* `clarification-requested` before a newer publication

The event has no lifecycle effect until `resume finalize` verifies the appended event in the selected shared object. A changed semantic revision invalidates prior acceptance.

## Close the Handoff

Use `close preview` to prepare exactly one permitted terminal event:

* `adopted` after the canonical owner completes the applicable repository governance
* `closed-without-adoption` when accepted work will not change a canonical artifact
* `withdrawn` by an authorized publisher before acceptance
* `superseded` with the successor handoff identifier when another handoff replaces it

Run `close finalize` after the terminal event is published. The skill can render sanitized local experiment feedback, but it does not submit telemetry or task content.

## Use a Closed Handoff for Later RPI Work

A finished or closed handoff can inform a later feature built on the completed work. Supply its exact path explicitly to the appropriate new RPI mode, usually `/rpi-research` when assumptions need revalidation or `/rpi-plan` when the new feature is already understood.

The new RPI flow must:

* Verify the handoff's terminal state and canonical disposition
* Compare its source baseline with the then-current branch
* Treat prior decisions and learnings as historical evidence rather than current authority
* Create new workspace-local research, plan, details, changes, and review records as needed
* Preserve the old handoff as closed instead of appending new feature work to it

This supports Developer B handing established context to Developer C later without turning the handoff into a permanent task ledger or silently resuming old work.

## Experimental Boundary

This first delivery tests accountable cross-person continuation with repository files. It does not provide a general knowledge store, run manifest, execution trace, evaluation evidence service, repository graph, automatic discovery configuration, telemetry backend, or second storage provider.

Evaluate the practice against a simpler branch-and-conversation baseline. Track preparation effort, time to recipient understanding, conflict frequency, unsafe-content blocks, adoption outcome, and whether another contributor could act without private workspace state. Broader repository-memory architecture requires separate evidence and governance decisions.

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
