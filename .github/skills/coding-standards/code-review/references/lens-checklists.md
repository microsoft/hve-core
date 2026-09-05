---
title: Code Review Lens Checklists
description: Perspective-specific review questions for functional, standards, accessibility, PR, security, readiness, and full-review workflows.
ms.date: 2026-06-26
---

## Functional review

* Does the change meet its intended behavior and acceptance criteria?
* Are the main success paths and primary failure paths covered?
* Are there regressions in adjacent workflows or interfaces?
* Are tests, fixtures, or rollback guidance updated when needed?

## Standards review

* Does the implementation follow repository conventions and established patterns?
* Are naming, structure, typing, and documentation aligned with the existing codebase?
* Are acceptance criteria covered in a way the team can verify?
* Are there maintainability issues, duplicated logic, or ambiguous ownership?

## Accessibility review

* Is the experience keyboard accessible and operable without a mouse?
* Are focus order, focus visibility, and interactive semantics correct?
* Are screen-reader labels, announcements, and form error states sufficient?
* Are contrast, motion, and error messaging accessible and understandable?

## PR review

* Does the change summary explain the purpose and scope clearly?
* Is the diff understandable, scoped, and appropriately small for the stated risk?
* Are validation steps, test evidence, and follow-up items included?
* Are any unrelated or out-of-scope changes called out explicitly?

## Security review

* Are authentication, authorization, and permission checks present and correct?
* Is untrusted input validated and boundaries enforced?
* Are secrets, credentials, and sensitive data handled safely?
* Are dependencies, serialization, parsing, and data handling paths reviewed for abuse or misuse?

## Readiness review

This lens reviews the change as a *deliverable* and covers the non-code surface not owned by the other perspectives. PR-metadata checks apply only when PR context (`prContext`) is supplied; documentation checks apply to changed non-code files.

PR description:

* Does the PR description accurately describe what the diff actually does, with no claims the changes do not support?
* Are all material changes covered, and is the "Type of Change" / file-area summary current?

Linked-issue alignment:

* Does the change satisfy the intent and acceptance criteria of each linked issue?
* Are any linked-issue requirements unaddressed, partially addressed, or contradicted?

Checklist completion:

* Are all checkboxes under Required sections (required automated checks, required review checks) complete?
* Are unchecked required items listed as concrete follow-up actions? (Never check a human-review checkbox on the author's behalf.)

Mergeable state:

* Is the PR open, conflict-free, and against the expected base, with required status checks passing?
* When merge state is blocked, behind, or dirty, is the remediation called out?

Changed documentation content:

* Is changed documentation factually accurate against the code change, free of stale or contradictory instructions?
* Do cross-references and links resolve and stay current, and is the content clear and complete enough not to mislead a reader?

## Full review

A full review should synthesize the functional, standards, accessibility, PR, security, and readiness lenses into one merged assessment rather than re-running the same checks in parallel.
