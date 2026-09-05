---
title: Accessibility Coverage Matrix
description: "Build, refresh, report, or probe an accessibility coverage matrix across criteria, surfaces, and methods."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - accessibility
  - accessibility-coverage-matrix
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                   |
|-------------|-------------------------------------------------------------------------|
| Kind        | prompt                                                                  |
| Source      | `.github/prompts/accessibility/accessibility-coverage-matrix.prompt.md` |
| Invocation  | Slash command `/accessibility-coverage-matrix`                          |
| Interactive | Yes                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Build, refresh, report, or probe an accessibility coverage matrix across criteria, surfaces, and methods.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to build, refresh, report on, or probe an accessibility coverage matrix for a defined scope. Use a focused framework assessment instead when you need findings for one standard rather than cross-surface coverage.

## How to use it

Provide the required `scope`, then optionally select frameworks, a mode, a base URL, or a serve command. Confirm before probing a non-loopback target, and treat qualified assistive-technology review as unresolved human work.

## Example usage

```text
/accessibility-coverage-matrix scope=docs/docusaurus frameworks=wcag-22,aria-apg mode=report
```

The prompt reports coverage across the selected frameworks without probing an external site.
