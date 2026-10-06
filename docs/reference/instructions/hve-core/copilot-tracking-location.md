---
title: Hve Core/Copilot Tracking Location
description: "Where .copilot-tracking/ lives (codebase root, not a host session folder) and how to find its gitignored files. Use when creating, finding, listing, or reading tracking files or storing intermediate files."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-29
ms.topic: reference
keywords:
  - instruction
  - hve-core
  - hve-core/copilot-tracking-location
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | instruction                                                               |
| Source      | `.github/instructions/hve-core/copilot-tracking-location.instructions.md` |
| Invocation  | Applied automatically to `**/.copilot-tracking/**`                        |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Where .copilot-tracking/ lives (codebase root, not a host session folder) and how to find its gitignored files. Use when creating, finding, listing, or reading tracking files or storing intermediate files.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Rely on this instruction whenever a workflow creates, finds, or reads files
under `.copilot-tracking/`. Hosts attach it automatically when a tracking file
is created or edited, and agents can load it on demand when they search for
tracking files or choose where to store intermediate files. It keeps the
tracking folder at the primary workspace root instead of a subdirectory or a
host session folder, and it makes searches include the folder's gitignored
files. For subfolder names and file conventions, use the owning workflow's
instruction instead, such as `copilot-tracking.instructions.md` for RPI and
HVE Builder evidence.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
