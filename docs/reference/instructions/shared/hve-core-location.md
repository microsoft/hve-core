---
title: Shared/Hve Core Location
description: "Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree."
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - shared
  - shared/hve-core-location
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                           |
|-------------|-----------------------------------------------------------------|
| Kind        | instruction                                                     |
| Source      | `.github/instructions/shared/hve-core-location.instructions.md` |
| Invocation  | Applied automatically to `**`                                   |
| Interactive | No                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this fallback when an HVE-Core prompt, agent, skill, instruction, or script
reference is missing at its expected location in a repository, extension, or
plugin distribution. Walk up from the attached instruction to the artifact
root and resolve the distribution's mapped location; do not invent a missing
artifact or treat an unrelated workspace path as authoritative.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
