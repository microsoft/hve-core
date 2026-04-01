---
title: Engineering Fundamentals
description: Language-agnostic design principles applied to every Code Review Standards review
sidebar_position: 8
author: microsoft/hve-core
ms.date: 2026-03-26
ms.topic: reference
---

<!-- Keep this file under 60 lines. Move extended rationale to separate reference files. -->

These principles apply to every review regardless of language or framework. Skills provide language-specific rules; these fundamentals apply universally.

## DRY

* Never duplicate logic, business rules, or data transformations.
* Extract repeated code into functions, methods, helpers, or classes.
* Prefer composition and small reusable utilities over copy-paste.

## Simplicity First

* No features beyond the requirements.
* No abstractions for single-use code.
* No "flexibility" or "configurability" that wasn't requested.
* No error handling for impossible scenarios.
* If you write 200 lines and it could be 50, rewrite it.

## Surgical Changes

* Don't "improve" adjacent code, comments, or formatting.
* Don't refactor code that isn't broken.
* Match existing style, even if you'd do it differently.
* Remove imports/variables/functions that YOUR changes made unused.
* Every changed line should trace directly to the user's request.

## Approach Proportionality

* Is the change scope proportional to the problem described in the PR or work item definition? Flag changes that modify significantly more files or modules than the stated intent requires.
* Does the approach introduce coordination overhead (new shared state, cross-module dependencies, or event-based coupling) that a simpler local change would avoid?

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
