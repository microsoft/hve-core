---
title: code-review-accessibility
description: "Review changed interaction, markup, and user-facing content with the consolidated accessibility capability. Use for Code Review accessibility work."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-accessibility
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | skill                                                       |
| Source      | `.github/skills/coding-standards/code-review-accessibility` |
| Invocation  | Loaded on demand by referencing agents                      |
| Interactive | No                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review changed interaction, markup, and user-facing content with the consolidated accessibility capability. Use for Code Review accessibility work.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill for the accessibility perspective when a change touches interactive UI, markup, user-facing content, or accessibility documentation. It activates the consolidated `accessibility` skill and applies only the framework references the surface needs, such as WCAG or ARIA authoring patterns.
When the assigned change has no accessibility-relevant surface, it completes with a not-applicable reason.

The skill reviews the assigned change only. A broader audit is a separate follow-up that Code Review can recommend when that capability exists.

## Example usage

For a change that adds a modal dialog, Code Review assigns the dialog component and the page that opens it. The skill reads the source and reports a finding if focus doesn't move into the dialog or return to the trigger on close, citing the WCAG criterion or ARIA dialog pattern and naming who is affected.
The result records that the check used source inspection, so keyboard and screen reader behavior stay listed as limitations. The skill doesn't install browsers or start services to close that gap.
