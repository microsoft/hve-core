---
title: Code Review Canvas
description: Follow a code review in a canvas beside the chat, see why the change was made and what it touches, assess findings, and send the agent your questions
sidebar_position: 3
sidebar_label: Canvas
author: Microsoft
ms.date: 2026-11-08
ms.topic: how-to
keywords:
  - code review canvas
  - code review
  - canvas
  - copilot canvases
  - coverage board
  - change map
  - why these changes
  - findings
  - review and send
tags:
  - agents
estimated_reading_time: 8
---

The Code Review canvas shows one review in a panel beside the chat: what changed and why, how the changed parts connect, which areas each perspective has covered, the findings, and the pull request discussion. You can ask for an explanation, dispute a finding, or draft a comment, and the agent reads each item back so you can see how it understood you. The canvas uses the same layout, colors, and controls as the [RPI Workflow canvas](../../rpi/rpi-workflow-canvas).

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
* The stage rail shows **Capture**, **Review**, and **Outcome**. Each stage reports Done, In progress, Not started, or Needs attention, worked out from the review record alone.
* In Review, the navigator on the left lists areas and their files, then findings and discussion. In Capture and Outcome, it outlines the stage. The box at its top filters the list.
* The steering panel on the right holds **Needs you**, **Your feedback**, and **Add input**. Narrow windows open both side panels as drawers.

## What Each Stage Shows

### Capture

The captured target: kind, provider, base, head, and merge base, when it was captured, and the snapshot and review IDs. It also shows how many files, hunks, and lines changed, the review's scope (profile, depth, mode, and perspectives), the pull request details with any readiness findings tied to them, and the evidence limits. Missing pull request details are shown as missing, not as a passed check.

### Review

Review is where you understand and assess the change. From top to bottom it shows the coverage board, why the changes were made, a change map, the findings, the selected area with its files and diff, and the pull request discussion.

#### Coverage Board

The board has three lanes, **Needs review**, **In progress**, and **Reviewed**, and each lane shows one card. Needs review shows the next area, In progress shows the area the agent is working on or else one whose work has stopped, and Reviewed shows the area you selected or else the last one. Areas whose required work is blocked, unavailable, skipped, or stale stay in In progress with their status words and a red edge.

The board stays pinned under the context bar while you scroll Review, and its collapse button shrinks it to its title. On panels 560 pixels tall or less, it scrolls with the page instead.

When a lane holds more areas, select its title to list all of them over the page. Escape, a click outside, or moving focus away closes the list. Reviewed means every required perspective finished its assigned files. It is not approval, and an area with no findings has not passed anything.

#### Why These Changes

This row lists the reasons the agent found for the change, such as "Move the review procedure from the agents into skills", each with its files and findings. Every reason is the agent's reading, not the author's words. Changes no reason covers stay visible under **Not explained yet**.

Select a reason to narrow the files, findings, and change map to it, and select **All changes** to go back. File rows and diff hunks name their reason, and a file split across reasons shows a small bar. To question a reason, select it and use **Explain** or **Comment**.

#### Change Map

The change map shows the parts the change touches and how they connect. Its three views share one layout, so no part moves when you switch:

| View              | What it shows                                             |
|-------------------|-----------------------------------------------------------|
| Changes (default) | Every part and link, with each change marked              |
| Before            | The parts and links as they were, without anything new    |
| After             | The parts and links as they will be, without what is gone |

Every mark pairs a border style, a glyph, and words, so none depends on color:

| Mark                                   | Meaning                                           |
|----------------------------------------|---------------------------------------------------|
| Dashed border and `+`                  | A new part                                        |
| Thick border and `Δ`                   | A changed part                                    |
| Dotted border, struck through, and `−` | A removed part                                    |
| Muted                                  | An unchanged part that a changed part connects to |
| `+` or `−` before an arrow label       | A new or removed link                             |
| Dashed arrow                           | A test or document that checks a part             |
| "(unsure)" on an arrow                 | A link the agent could not point to evidence for  |

Hover over or focus a part to preview its before and after lines, line counts, files, reasons, and findings. The preview stays open while you point at it, and Escape closes it from anywhere on the page. Select a part, or press Enter or Space, to pin its preview and use its links.

The selected reason or area fills its parts. **Show as text** lists the same map in words, with each link's description and a chip that goes to its evidence. When the agent recorded no map, the canvas draws one from the review areas and says so.

#### Findings

The Findings row opens with counts by severity, how many findings are being checked, and how many areas each perspective has checked. Findings group by severity: Critical and High start open, Medium and Low start folded, and rejected findings sit under **Set aside**. **Show** narrows the list to the selected area.

Each finding is one line. Select it to open the full card in place, which closes any other. A finding the agent hasn't verified yet reads **Being checked**.

Findings that arrive while you read wait behind **Show N new findings**, so the list never shifts under you. Until you show them, they also stay out of the diff, the file rows, and the counts on the board and the reasons; only that button, **Needs you**, and the stage rail count them. When the selected reason or area would hide one of them, **Show N new findings** clears that narrowing and says so.

The card shows the finding's severity, the agent's decision, the perspective that raised it, the consequence, a suggested change, the criterion it applies, and evidence chips that jump to the lines or pull request details involved. **Bookmark** and **Seen** are private marks for you. They don't change coverage, a finding's status, or the outcome.

#### Area, Files, and Diff

Select an area to see its summary and before and after behavior, then its files and the selected file's diff, with findings and comments beside the lines they refer to. Diffs load when you open them.

#### Discussion

The pull request discussion stays separate from the agent's findings and sits folded at the end of Review; select its title to open it. Each comment shows its author, whether it is inline or part of the conversation, whether it is resolved (or that the resolution is unknown), and where it was originally made. Outdated or unmapped comments stay visible with that context.

### Outcome

The recommendation (approve, approve with comments, or request changes) appears only for a completed review whose record is readable. Until then the stage lists what blocks it, such as blocked review work. Reviewed coverage is not human approval: the report's human-review checkbox stays yours to check.

The saved report opens read-only here. Edit it on disk.

## Send Your Input

1. Choose an action on a finding, area, reason, file, or comment: **Explain**, **Investigate**, **Dispute**, **Draft a comment**, **Review next**, **Comment**, or **Draft a reply**. The **Add input** composer opens with that item as its subject, or you can write about the whole review.
2. **Save draft** keeps your words private, even across reconnects. **Queue for the agent** marks them ready.
3. **Review and send** lists the queued items and sends them to the agent. Sending doesn't mean the agent acted.
4. The agent reads each item back. **The agent understood** shows its reading and what it changed, and the item moves to **Read back**.

If the host can't deliver a message, your items are marked Not delivered, and the agent still collects them at its next checkpoint. Items that point at an earlier snapshot are sent with an Earlier snapshot label, so the agent can map them to current evidence.

## What the Canvas Never Does

The canvas never edits source files, posts comments, submits or approves reviews, resolves threads, or merges, and it holds no provider credentials. Before anything is staged or posted, the agent shows what it would send, checks the pull request again, and asks you.

## Themes, Accessibility, and Keyboard

The **Appearance** menu offers **System**, **Light**, and **Dark**, plus **More contrast**. System follows your editor or operating system. The choice lasts while the canvas extension runs.

Status pairs an icon and a word with its color. Compact perspective chips show the perspective name and a status icon, with the status word in their tooltip and accessible name. Change map parts are named buttons, and the map has a text version. Forced colors keep every border, reduced motion turns off the Live pulse and other movement, and the layout reflows to a 320-pixel-wide window without sideways scrolling; only a wide change map scrolls sideways inside its own frame.

| Key                              | Action                                                  |
|----------------------------------|---------------------------------------------------------|
| `1` to `3`                       | View Capture, Review, or Outcome                        |
| Arrow keys                       | Move between stages in the rail                         |
| `n`                              | Go to the next item that needs you                      |
| `[` and `]`                      | Previous and next file in the area                      |
| `/`                              | Filter the navigator                                    |
| `b` and `s`                      | Show or hide the navigator and steering panel           |
| `?`                              | Show the shortcut list                                  |
| `Enter` or `Space` on a map part | Pin the part's preview                                  |
| `Escape`                         | Close a menu, drawer, dialog, lane list, or map preview |

Single-key shortcuts pause while you type, and the shortcut list has a switch that turns them off.

## Troubleshooting

| Problem                                                               | What to do                                                                                                                          |
|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| The Code Review canvas isn't listed                                   | Check the host requirements above and install the hve-core plugin.                                                                  |
| The host reports multiple matching canvas providers                   | Ask the agent to open the canvas with a host-reported `extensionId`, such as `project:code-review`, and to reuse it when reopening. |
| A notice says the canvas shows the last valid evidence                | The review record couldn't be read. No outcome appears until the agent repairs the record.                                          |
| Review and send can't deliver                                         | Leave the items queued. The agent collects them at its next checkpoint.                                                             |
| A comment says it isn't mapped                                        | It belongs to another revision. Its original location stays with the comment in the discussion.                                     |
| Appearance went back to System                                        | The canvas keeps your choice while its extension runs. Choose again after the host restarts it.                                     |
| The change map says it was drawn from areas                           | The agent recorded no change map. Ask it to describe how the changed parts connect.                                                 |
| **Needs you** or the stage rail counts findings the list doesn't show | New findings wait behind **Show N new findings** until you select it, and a selected reason or area may narrow the list.            |

## Related Guides

* [Code Review](./) explains entry points, profiles, depth, and publication.
* [Language Skills](language-skills) explains how the standards perspective picks its criteria.
* [RPI Workflow Canvas](../../rpi/rpi-workflow-canvas) is the sibling canvas for RPI sessions.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
