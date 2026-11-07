---
title: code-review-standards
description: "Review assigned changes against applicable repository instructions and domain skills, preserving criterion provenance. Use for Code Review standards work."
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-standards
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | skill                                                   |
| Source      | `.github/skills/coding-standards/code-review-standards` |
| Invocation  | Loaded on demand by referencing agents                  |
| Interactive | No                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned changes against applicable repository instructions and domain skills, preserving criterion provenance. Use for Code Review standards work.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill for the standards perspective, inline or through the Code Review Standards subagent. It checks the assigned changes against the repository instructions that apply to them and the skills that match the changed language, framework, or file type.
Every finding cites the instruction or exact skill name and the criterion behind it, and a departure needs a consequence beyond preference.

The skill loads every distinct match the change needs, with no fixed cap, and prefers Workspace, then User, then Bundled copies of a same-named skill. Functional defects belong to the functional perspective.

## Example usage

For a change to a Python module, Code Review assigns the changed hunks and the result path. The skill reads the applicable Python instruction files, selects `python-foundational` and any matching repository skill, and reports a bare `except:` that hides failures, citing `python-foundational` and its error-handling criterion.
The result's observations list each criteria source with its location or origin label. If no instructions or skills had applied, the result would record standards evidence as unavailable, which doesn't count as a pass.
