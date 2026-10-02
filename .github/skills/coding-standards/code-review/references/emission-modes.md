---
title: Code Review Emission Modes
description: Capability-gated emission modes and the persisted emission record contract.
ms.date: 2026-10-02
---

## Purpose

The review should emit results in the most capable native format available. When a direct poster is unavailable, fall back to the canonical findings report so the review still completes and persists its value.

## Emission modes

1. Native PR or MR comments
   - Use line comments or review comments when a capable poster is detected.
   - Prefer GitLab `mr-comment` support when that capability is present.
   - Use Azure DevOps templates when the repository context supports ADO comment formatting.
   - Use GitHub review comments when a GitHub poster is available.

2. Canonical findings report
   - Use the canonical report when no native poster is available.
   - Persist the report to the review folder and summarize the result in the conversation.

## Gating rules

- Detect the available poster capability before emission.
- Only emit in a native format when the target and capability are both available.
- Keep the review output deterministic by preferring one mode over another based on the detected environment.

## Default interactive emission guardrails

The interactive (default) review path is human-gated. Before any native or external emission it follows this sequence:

1. **Human-editable draft first.** Persist the canonical `review.md` to the review folder as the pre-emission draft. The human may edit this draft on disk before it is submitted. Never emit externally before the draft exists.
2. **Active-engagement self-review gate.** Before the confirmation step, surface coverage from the dispatch manifest: the number of board items still pending or never opened, and an enumerated list of every Critical or High finding with file:line. Ask one active prompt that requires the human to either name which high-severity findings or unopened areas to open now, or explicitly acknowledge proceeding without further review. Keep the draft and review state intact until one of those choices is made. Reuse the existing Code-Review reviewer-responsibility wording from `disclaimer-language.instructions.md` and do not add separate disclaimer prose. When that instruction content is unavailable, state that the standard reviewer-responsibility wording could not be loaded and keep the gate itself in force rather than authoring replacement prose. This site degrades rather than stops because the gate's mechanics are specified in place and only the standard wording is missing; halting here would disable a working safety prompt over absent boilerplate.
3. **Explicit human confirmation.** Present the draft path and summary, then pause for explicit human confirmation before submitting a native PR/MR/ADO review or posting external comments. If the human declines, the draft `review.md` is the delivered result.
4. **PR-state validation before emission.** Immediately before the confirmed submission, re-validate that the PR/MR is still open; its provider and stable target identifier, base ref, and head ref match the reviewed target; its current head SHA matches the reviewed head SHA; and prepared line comments are not stale against a changed diff. If stable identity is unavailable or the state changed, stop, refresh context, and ask the human how to proceed.
5. **Output-policy guard.** Apply the canonical `content-policy-citation` instruction to the exact review event, general comment body, and line comments that would be emitted. A policy concern blocks the affected payload until a human resolves it.
6. **PR comment draft gate.** For a pull request or merge request scope, `review.md` carries a human-editable **PR Comment Draft** section with a posting checkbox (see the PR comment draft section in the [Output Formats](output-formats.md) reference). The general PR or MR comment is not posted while that box is unchecked; the human checking the box is the authorization to post the drafted comment. Link the draft section in the closeout; do not reproduce the full body inline.

These guardrails apply to the default interactive path. They protect a human reviewer from silently posting stale or unreviewed comments.

## Preauthorized interactive emission

A human may explicitly set `autoApprove=true` for one invocation to authorize the recommended dispatch defaults and the final normalized review emission in advance. The agent never infers this mode, carries it into another run, or activates it from general language such as "go ahead" or "be automatic."

Preauthorization changes only the two pauses. The review still persists its canonical draft, reports pending coverage and every Critical or High finding, applies the canonical `content-policy-citation` instruction to the exact payload, derives the event from accepted findings, and re-validates the pull request identity immediately before emission. `autoApprove=true` never forces an `APPROVE` event: `request_changes` still emits `REQUEST_CHANGES`, `approve_with_comments` still emits `COMMENT`, and only `approve` emits `APPROVE`.

Record the authorization source as `invocation-input`. Set `phaseGates.emissionReady` and `pr_comment_draft.approved_for_posting` to `true` only after all emission eligibility checks pass. A missing provider, stable target identifier, or reviewed head SHA; a closed pull request; a changed provider, target identifier, base ref, head ref, or head SHA; an unavailable poster; or a failed output guard blocks emission and invalidates the preauthorization. Do not reinterpret or repair it after the target changes.

The preauthorized report records invocation authorization instead of rendering a pending posting checkbox. Its final qualified-human-review checkbox remains present and unchecked; preauthorization to emit is not a claim that a qualified human validated the generated review.

## Workflow (automation) emission

The hidden workflow/automation path never pauses for human confirmation. It performs equivalent PR-state validation programmatically and defers output, persistence, and submission to the host's output contract. Do not surface or describe the workflow path in human conversation.

## Closeout contract

After `review.md` and `metadata.json` are persisted, end an interactive run with an explicit, ordered next-actions hand-back so the human knows what happened and what remains. Present, in order:

1. A link to `review.md` on disk plus the compact summary defined by the [Output Formats](output-formats.md) reference.
2. In default interactive mode, an instruction to open and edit the report before acting on it; the human owns the final findings and verdict. In preauthorized mode, state that the draft was persisted before the attempted emission and keep the qualified-human-review limitation visible.
3. In default interactive mode, the proposed emission action gated by the interactive emission guardrails. For a pull request or merge request target, point the human to the **PR Comment Draft** section, state the event that will be used, and offer to post the review once the human confirms. In preauthorized mode, report the normalized event and emission status instead of offering another confirmation. Do not reproduce the full drafted comment body inline.
4. Any remaining `nextActions` or pending board items from the dispatch manifest that the human may still want to inspect.

In default interactive mode, set the manifest `phaseGates.emissionReady` to `true` only after the human confirms the target and event and, for a pull request or merge request, checks the posting checkbox. In preauthorized mode, set it only after the explicit invocation authorization and all eligibility checks are recorded. Emit only after the applicable gate is set. Do not end the run on the compact summary alone; this closeout block is the final conversational output in either interactive mode. In workflow (automation) mode this contract does not apply: defer to the host output contract.

## Emission record

Persist an emission record with the chosen mode, target, status, and a short summary of what was emitted. A lightweight record should include:

- `mode` — native or canonical,
- `target` — PR, MR, ADO, or review artifact,
- `status` — completed or skipped,
- `summary` — a brief description of the emission outcome.
