---
title: rpi-walkthrough
description: "Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed."
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-walkthrough
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | skill                                                                             |
| Source      | `.github/skills/rpi/rpi-walkthrough`                                              |
| Invocation  | Invoked directly as `/rpi-walkthrough`, or loaded on demand by referencing agents |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-walkthrough` when you want to understand code, a feature flow, a UI or UX area, a prompt-engineering artifact, or a `.copilot-tracking` research, plan, changes, or review document before deciding what to change. The skill reviews the target with a subagent first, plans coherent segments, then explains one segment per turn with inline links, a reference table, and at most two questions.

It is read-only by default. When you make a material decision or request a change during the walkthrough, it creates a decisions-and-changes ledger under `.copilot-tracking/walkthroughs/` and reconciles each entry with you as applied now, handed off to RPI work, deferred, or declined.

Reach for a different asset when:

* You need new external or codebase evidence with citations. Use [rpi-research](rpi-research); the walkthrough activates it itself when an explanation depends on a library or standard.
* You want to challenge assumptions rather than learn how something works. Use [rpi-challenger](rpi-challenger).
* You are ready to change the code. Use [rpi-plan](rpi-plan) or [rpi-implement](rpi-implement) for the entry the walkthrough handed off.

See the [RPI Walkthrough guide](../../../rpi/rpi-walkthrough) for the full segment loop.

## Example usage

```text
/rpi-walkthrough target=src/pipeline/writers/base.py detail=normal
```

Each turn covers one segment and ends with the reference table and questions:

```text
### Segment 1: WriterBase defines the contract every writer implements

WriterBase exists so the factory can construct any writer without knowing its storage.
It declares `open`, `write_batch`, and `close`, and the factory calls them in that order.

| Reference                                                           | What to look at                           |
|---------------------------------------------------------------------|-------------------------------------------|
| [src/pipeline/writers/base.py](src/pipeline/writers/base.py#L8-L31) | The abstract methods and their docstrings |
| [src/pipeline/factory.py](src/pipeline/factory.py#L44)              | Where the factory constructs a writer     |
```

The closing summary names the covered segments and detail level. It links the ledger only when one was created; otherwise it states that no decisions-and-changes artifact was needed.
