---
title: hve-artifact-authoring
description: "Create and validate HVE Core agents, prompts, instructions, and skills with current frontmatter, package membership, delegation, tracking, documentation, and validation conventions. Use when authoring a GitHub Copilot customization artifact in this repository."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-29
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - hve-artifact-authoring
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                    |
|-------------|------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                    |
| Source      | `.github/skills/coding-standards/hve-artifact-authoring`                                 |
| Invocation  | Invoked directly as `/hve-artifact-authoring`, or loaded on demand by referencing agents |
| Interactive | No                                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create and validate HVE Core agents, prompts, instructions, and skills with current frontmatter, package membership, delegation, tracking, documentation, and validation conventions. Use when authoring a GitHub Copilot customization artifact in this repository.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to select, create, and validate an HVE Core agent, prompt, instruction, or skill.
It provides starter assets, current frontmatter boundaries, package synchronization steps, and
targeted validation ownership.

Use the `hve-builder` skill instead when the task requires lifecycle-managed creation,
independent review, behavior testing, or host validation.

## Example usage

```text
/hve-artifact-authoring targets=.github/skills/example/sample requirements="Create a reusable skill with one reference"
```

The skill selects the skill artifact type, applies the starter and frontmatter contracts,
synchronizes plugin and documentation projections, and reports targeted validation evidence.
