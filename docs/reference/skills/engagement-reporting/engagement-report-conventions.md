---
title: engagement-report-conventions
description: "Style, terminology, and data-handling rules for engagement reports, their sources, working files, and engagement.yaml. Preloaded by the engagement report generator and its subagents."
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-31
ms.topic: reference
keywords:
  - skill
  - engagement-reporting
  - engagement-report-conventions
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                               |
|-------------|---------------------------------------------------------------------|
| Kind        | skill                                                               |
| Source      | `.github/skills/engagement-reporting/engagement-report-conventions` |
| Invocation  | Loaded on demand by referencing agents                              |
| Interactive | No                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Style, terminology, and data-handling rules for engagement reports, their sources, working files, and engagement.yaml. Preloaded by the engagement report generator and its subagents.
<!-- END AUTO-GENERATED: overview -->

## When to use it

The engagement report generator and its subagents preload this skill. It holds
the rules for report language, names, and data:

* Style: keep status language concise, separate completed work from planned
  work, and match detail and tone to the configured internal or external
  audience. The report template owns section structure; this skill owns the
  language inside it.
* Terminology: when `engagement.yaml` defines canonical names for
  stakeholders, teams, products, or programs, use them consistently. When it
  defines none, keep the spellings that primary sources use.
* Data handling: keep raw content and unneeded personal data out of reports,
  keep working files apart from final artifacts, and get explicit approval
  before creating an Outlook draft. These rules do not replace an
  organization's information-protection, retention, or records-management
  policies.

## Example usage

Instead of writing `The team made great progress on deployment`, a report
states the evidenced result and status, such as `The team completed staging
deployment and is validating production prerequisites`. If `engagement.yaml`
maps `Project North Star` and `North-Star` to `North Star`, the report uses
`North Star` throughout and leaves the source record unchanged.
