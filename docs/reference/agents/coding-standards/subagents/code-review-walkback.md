---
title: Code Review Walkback
description: Thin wrapper subagent that activates rpi-research for bounded Register 2 investigations and anchors results to a review board item
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-walkback
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/coding-standards/subagents/code-review-walkback.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Thin wrapper subagent that activates rpi-research for bounded Register 2 investigations and anchors results to a review board item
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Walkback when a bookmarked question needs investigation beyond a factual explanation. It activates bounded RPI Research and anchors the result to the originating board item. Use the parent workflow to select the question; the worker does not choose a new review scope.

## Example usage

The parent supplies the board item, explicit research question and criteria, a trusted review evidence root, and `register2ArtifactPath` for a cancellation-race investigation. The worker returns the research and anchored investigation paths with unresolved evidence. Missing scope or invalid paths require clarification; unavailable research capability is reported as blocked rather than replaced with guessed conclusions.
