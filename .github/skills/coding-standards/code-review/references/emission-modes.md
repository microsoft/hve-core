---
title: Code Review Emission Modes
description: Capability-gated emission modes and the persisted emission record contract.
ms.date: 2026-06-26
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

## Interactive emission guardrails

The interactive (default) review path is human-gated. Before any native or external emission it follows this sequence:

1. **Human-editable draft first.** Persist the canonical `review.md` to the review folder as the pre-emission draft. The human may edit this draft on disk before it is submitted. Never emit externally before the draft exists.
2. **Active-engagement self-review gate.** Before the confirmation step, surface coverage from the dispatch manifest: the number of board items still pending or never opened, and an enumerated list of every Critical or High finding with file:line. Ask one active prompt that requires the human to either name which high-severity findings or unopened areas to open now, or explicitly acknowledge proceeding without further review. Keep the draft and review state intact until one of those choices is made. Reuse the existing Code-Review reviewer-responsibility wording from [Disclaimer Language](../../../../instructions/shared/disclaimer-language.instructions.md) and do not add separate disclaimer prose.
3. **Explicit human confirmation.** Present the draft path and summary, then pause for explicit human confirmation before submitting a native PR/MR/ADO review or posting external comments. If the human declines, the draft `review.md` is the delivered result.
4. **PR-state validation before emission.** Immediately before the confirmed submission, re-validate that the PR/MR is still open, the head and target still match the reviewed diff, and prepared line comments are not stale against a changed diff. If the state changed, stop, refresh context, and ask the human how to proceed.
5. **PR comment draft gate.** For a pull request or merge request scope, `review.md` carries a human-editable **PR Comment Draft** section with a posting checkbox (see the PR comment draft section in the [Output Formats](output-formats.md) reference). The general PR or MR comment is not posted while that box is unchecked; the human checking the box is the authorization to post the drafted comment. Link the draft section in the closeout; do not reproduce the full body inline.

These guardrails apply only to the interactive path. They protect a human reviewer from silently posting stale or unreviewed comments.

## Workflow (automation) emission

The hidden workflow/automation path never pauses for human confirmation. It performs equivalent PR-state validation programmatically and defers output, persistence, and submission to the host's output contract. Do not surface or describe the workflow path in human conversation.

## Closeout contract

After `review.md` and `metadata.json` are persisted, end an interactive run with an explicit, ordered next-actions hand-back so the human knows what to do with the review. Present, in order:

1. A link to `review.md` on disk plus the compact summary defined by the [Output Formats](output-formats.md) reference.
2. An instruction to open and edit the report before acting on it; the human owns the final findings and verdict.
3. The proposed emission action gated by the interactive emission guardrails. For a pull request or merge request target, point the human to the **PR Comment Draft** section, state the event that will be used, and offer to post the review once the human confirms. Link the draft section; do not reproduce the full drafted comment body inline.
4. Any remaining `nextActions` or pending board items from the dispatch manifest that the human may still want to inspect.

Set the manifest `phaseGates.emissionReady` to `true` only after the human confirms the target and event, and, for a pull request or merge request, the posting checkbox is checked. Emit only after that gate is set. Do not end the run on the compact summary alone; this closeout block is the final conversational output in interactive mode. In workflow (automation) mode this contract does not apply: defer to the host output contract.

## Emission record

Persist an emission record with the chosen mode, target, status, and a short summary of what was emitted. A lightweight record should include:

- `mode` — native or canonical,
- `target` — PR, MR, ADO, or review artifact,
- `status` — completed or skipped,
- `summary` — a brief description of the emission outcome.
