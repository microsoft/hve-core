---
title: python-foundational
description: "Foundational Python best practices, idioms, and code quality fundamentals"
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - python-foundational
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | skill                                                 |
| Source      | `.github/skills/coding-standards/python-foundational` |
| Invocation  | Loaded on demand by referencing agents                |
| Interactive | No                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Foundational Python best practices, idioms, and code quality fundamentals
<!-- END AUTO-GENERATED: overview -->

## When to use it

An authoring or reviewing agent loads this foundation for Python changes before
higher-order guidance. It covers idioms, type safety, exceptions, resource
management, maintainability, and architectural fit. It is not a user-invocable
command or a replacement for the repository's interpreter, tests, and lint rules.

## Example usage

Ask a code reviewing agent to load `python-foundational` for a sample import
utility diff. Supply the changed `.py` file and tests; the sample has a mutable
default list, an unclosed input file, and a broad exception handler. Request
findings rather than edits.

Expect evidence-backed recommendations for per-call state, context-managed file
access, and specific exceptions, with severity based on actual impact rather than
style preference. The review should preserve public entry points and framework
hooks instead of calling them unused without checking consumers. Success is an
actionable review whose `Skills Loaded` footer identifies the foundation and whose
claims distinguish runtime defects from maintainability concerns. Never execute
untrusted input or include credentials in sample data to demonstrate an issue.
