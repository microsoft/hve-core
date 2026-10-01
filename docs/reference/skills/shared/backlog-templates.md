---
title: backlog-templates
description: "Shared work-item templates and conventions for ADO and GitHub backlog handoff across the RAI, Security, SSSC, Accessibility, and Privacy planners"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - shared
  - backlog-templates
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/shared/backlog-templates`                                           |
| Invocation  | Invoked directly as `/backlog-templates`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Shared work-item templates and conventions for ADO and GitHub backlog handoff across the RAI, Security, SSSC, Accessibility, and Privacy planners
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a RAI, Security, SSSC, Accessibility, or Privacy planner needs
consistent ADO and GitHub handoff formats. It supplies shared skeletons, identifier
conventions, sanitization, and disclaimer placement. Domain fields, hierarchy,
severity mappings, and reviewer roles remain the owning planner's responsibility.

These are reference templates, not tracker access. Choose `backlog-execute` for
an approved execution pass. The planner vocabulary distinguishes manual,
supervised, and autonomous output; `coached` is not a selectable planner tier.

## Example usage

Ask: `/backlog-templates Prepare ADO and GitHub handoff drafts for the attached
sample security control and its acceptance criteria. Use manual handoff only.`
Supply the planner's threat reference, risk mapping, implementation evidence,
and required ADO area path; do not supply credentials or real personal data.

Expect an HTML description for ADO and metadata plus Markdown for GitHub, each
retaining security-specific fields and the authoritative review disclaimer.
Success means the two formats describe the same control, preserve standards
identifiers, remove local-only paths, and leave human-review checkboxes unchecked.
Temporary planning identifiers are resolved before later tracker creation. The
drafts do not create work items or establish qualified review, even if every
template field has been filled.
