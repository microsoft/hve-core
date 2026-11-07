---
title: code-review-security
description: Review assigned changes for realistic security consequences across trust boundaries. Use for the security perspective of Code Review.
sidebar_position: 7
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-security
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | skill                                                  |
| Source      | `.github/skills/coding-standards/code-review-security` |
| Invocation  | Loaded on demand by referencing agents                 |
| Interactive | No                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned changes for realistic security consequences across trust boundaries. Use for the security perspective of Code Review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill for the security perspective when a change affects a trust boundary, such as authentication, authorization, secrets, parsing, serialization, networking, persistence, dependencies, or external programs. It traces untrusted input through validation, authorization, parsing, storage, and output.
A finding needs a plausible actor, a reachable changed path, a failed control, and a consequence supported by evidence, so theoretical attacks and harmless string patterns aren't reported.

For a full audit, use the Security Reviewer. Code Review can also correlate accepted findings with a confirmed security plan.

## Example usage

For a change that adds a file upload endpoint, Code Review assigns the handler and its validation code. The skill traces the uploaded filename from the request to the storage call and reports a finding if a path traversal sequence can write outside the upload directory, naming the actor, path, failed control, and consequence, anchored to the changed lines.
It checks existing controls and counter-evidence first, keeps any demonstration benign, and never records secret values.
