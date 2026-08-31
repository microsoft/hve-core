---
title: Coding Standards/Rust/Rust Tests
description: Rust test code authoring conventions
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - coding-standards
  - coding-standards/rust/rust-tests
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                   |
|-------------|-------------------------------------------------------------------------|
| Kind        | instruction                                                             |
| Source      | `.github/instructions/coding-standards/rust/rust-tests.instructions.md` |
| Invocation  | Applied automatically to `**/*.rs`                                      |
| Interactive | No                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Rust test code authoring conventions
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use these conventions when adding Rust unit tests, crate-level integration
tests, fixtures, or trait and HTTP mocks. They extend the base Rust rules with
test placement and behavioral naming; keep unit tests beside the code and use
the crate `tests/` directory only for public-API integration coverage.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
