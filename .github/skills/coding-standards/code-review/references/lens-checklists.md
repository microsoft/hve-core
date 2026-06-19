---
title: Code Review Lens Checklists
description: Perspective-specific review questions for functional, standards, accessibility, PR, security, and full-review workflows.
ms.date: 2026-06-18
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

## Full review

A full review should synthesize the functional, standards, accessibility, PR, and security lenses into one merged assessment rather than re-running the same checks in parallel.
