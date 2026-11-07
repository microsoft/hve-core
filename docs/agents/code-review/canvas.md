---
title: Code Review Canvas
description: Follow a code review stage by stage in a canvas beside the chat, inspect captured changes and findings, and send the agent your questions
sidebar_position: 3
sidebar_label: Canvas
author: Microsoft
ms.date: 2026-11-06
ms.topic: how-to
keywords:
  - code review canvas
  - code review
  - canvas
  - copilot canvases
  - coverage board
  - findings
  - review and send
tags:
  - agents
estimated_reading_time: 6
---

The Code Review canvas shows one review in a panel beside the chat: what changed, which areas each perspective has covered, the findings, and the pull request discussion. You can ask for an explanation, dispute a finding, or draft a comment, and the agent reads each item back so you can see how it understood you. The canvas uses the same layout, colors, and controls as the [RPI Workflow canvas](../../rpi/rpi-workflow-canvas).

The review folder under `.copilot-tracking/reviews/code-reviews/` stays the record. The canvas reads it and keeps your feedback in that review's `feedback.json`. It never edits source files, posts comments, or approves anything.

## Before You Start

You need a host that shows canvases and the hve-core plugin, which carries the canvas. The hve-core VS Code extension does not carry canvases.

| Host               | What to turn on                                                                                                |
|--------------------|----------------------------------------------------------------------------------------------------------------|
| VS Code desktop    | Turn on `chat.canvases.enabled`, start a new local session with the Copilot harness, and send a first message. |
| GitHub Copilot app | Canvases open in the app's right side panel.                                                                   |
| Copilot CLI        | Turn on experimental features with `--experimental` or `/experimental on`.                                     |

> [!NOTE]
> Canvases are a preview feature, so a host update can change how they open or look.

## Open the Canvas

Run `/code-review` or select **Code Review** and name what to review. When the host offers the canvas, Code Review opens it on the current review. To return to an earlier review, ask the agent to open the Code Review canvas for it; the agent passes the review's `review-state.json` path.

The canvas is optional. Without it, the review runs in chat with the same evidence and decisions.

## Find Your Way Around

* The header names the review target, such as the pull request title, a branch comparison, a commit, local changes, or selected code. Chips show the provider, the base and head commits, the review ID, and the record's revision.
* **Needs you** counts High and Critical findings you haven't marked seen. Select it, or press `n`, to step through them.
* **Review and send** shows how many of your items wait to go to the agent.
* **Live** shows that the canvas follows the review as it changes. Select it to stop following the agent's focus requests; updates still arrive.
* The stage rail shows **Capture**, **Review**, **Verify**, and **Outcome**. Each stage reports Done, In progress, Not started, or Needs attention, worked out from the review record alone.
* The navigator on the left lists areas and files, or findings and discussion. The box at its top filters the list.
* The steering panel on the right holds **Needs you**, **Your feedback**, and **Add input**. Narrow windows open both side panels as drawers.

## What Each Stage Shows

### Capture

The captured target: kind, provider, base, head, and merge base, when it was captured, and the snapshot and review IDs. It also shows how many files, hunks, and lines changed, the review's scope (profile, depth, mode, and perspectives), the pull request details with any readiness findings tied to them, and the evidence limits. Missing pull request details are shown as missing, not as a passed check.

### Review

The coverage board sorts areas into **Needs review**, **In progress**, **Needs attention**, and **Reviewed**, with a pill for each perspective's progress. Reviewed means every required perspective finished its assigned files. It is not approval, and an area with no findings has not passed anything.

Select an area to see its summary, before and after behavior, and an impact map. Every link on the map cites captured evidence or says what is uncertain; uncertain links are dashed, and the list under the map describes each link in words. Below that are the area's files and the selected file's diff, with findings and comments beside the lines they refer to. Diffs load when you open them.

### Verify

Findings appear under **To verify**, **Retained**, **Rejected**, or **All**. Each finding shows its severity, the agent's decision, the perspective that raised it, the consequence, a suggested change, the criterion it applies, and evidence chips that jump to the lines or pull request details involved.

**Bookmark** and **Seen** are private marks for you. They don't change coverage, a finding's status, or the outcome.

The pull request discussion stays separate from the agent's findings. Each comment shows its author, whether it is inline or part of the conversation, whether it is resolved (or that the resolution is unknown), and where it was originally made. Outdated or unmapped comments stay visible with that context.

### Outcome

The recommendation (approve, approve with comments, or request changes) appears only for a completed review whose record is readable. Until then the stage lists what blocks it, such as blocked review work. Reviewed coverage is not human approval: the report's human-review checkbox stays yours to check.

The saved report opens read-only here. Edit it on disk.

## Send Your Input

1. Choose an action on a finding, area, file, or comment: **Explain**, **Investigate**, **Dispute**, **Draft a comment**, **Review next**, **Comment**, or **Draft a reply**. The **Add input** composer opens with that item as its subject, or you can write about the whole review.
2. **Save draft** keeps your words private, even across reconnects. **Queue for the agent** marks them ready.
3. **Review and send** lists the queued items and sends them to the agent. Sending doesn't mean the agent acted.
4. The agent reads each item back. **The agent understood** shows its reading and what it changed, and the item moves to **Read back**.

If the host can't deliver a message, your items are marked Not delivered, and the agent still collects them at its next checkpoint. Items that point at an earlier snapshot are sent with an Earlier snapshot label, so the agent can map them to current evidence.

## What the Canvas Never Does

The canvas never edits source files, posts comments, submits or approves reviews, resolves threads, or merges, and it holds no provider credentials. Before anything is staged or posted, the agent shows what it would send, checks the pull request again, and asks you.

## Themes, Accessibility, and Keyboard

The **Appearance** menu offers **System**, **Light**, and **Dark**, plus **More contrast**. System follows your editor or operating system. The choice lasts while the canvas extension runs.

Status pairs an icon and a word with its color. Compact perspective chips show the perspective name and a status icon, with the status word in their tooltip and accessible name. Forced colors keep every border, reduced motion turns off the Live pulse and other movement, and the layout reflows to a 320-pixel-wide window without sideways scrolling.

| Key         | Action                                        |
|-------------|-----------------------------------------------|
| `1` to `4`  | View Capture, Review, Verify, or Outcome      |
| Arrow keys  | Move between stages in the rail               |
| `n`         | Go to the next item that needs you            |
| `[` and `]` | Previous and next file in the area            |
| `/`         | Filter the navigator                          |
| `b` and `s` | Show or hide the navigator and steering panel |
| `?`         | Show the shortcut list                        |
| `Escape`    | Close a menu, drawer, or dialog               |

Single-key shortcuts pause while you type, and the shortcut list has a switch that turns them off.

## Troubleshooting

| Problem                                                | What to do                                                                                                                          |
|--------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| The Code Review canvas isn't listed                    | Check the host requirements above and install the hve-core plugin.                                                                  |
| The host reports multiple matching canvas providers    | Ask the agent to open the canvas with a host-reported `extensionId`, such as `project:code-review`, and to reuse it when reopening. |
| A notice says the canvas shows the last valid evidence | The review record couldn't be read. No outcome appears until the agent repairs the record.                                          |
| Review and send can't deliver                          | Leave the items queued. The agent collects them at its next checkpoint.                                                             |
| A comment says it isn't mapped                         | It belongs to another revision. Its original location stays with the comment in the discussion.                                     |
| Appearance went back to System                         | The canvas keeps your choice while its extension runs. Choose again after the host restarts it.                                     |

## Related Guides

* [Code Review](./) explains entry points, profiles, depth, and publication.
* [Language Skills](language-skills) explains how the standards perspective picks its criteria.
* [RPI Workflow Canvas](../../rpi/rpi-workflow-canvas) is the sibling canvas for RPI sessions.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
