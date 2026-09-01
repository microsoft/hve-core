---
title: Coding Standards/Python Tests
description: Python test code authoring conventions
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - coding-standards
  - coding-standards/python-tests
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                |
|-------------|----------------------------------------------------------------------|
| Kind        | instruction                                                          |
| Source      | `.github/instructions/coding-standards/python-tests.instructions.md` |
| Invocation  | Applied automatically to `**/*.py`                                   |
| Interactive | No                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Python test code authoring conventions
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use these conventions when Python files define pytest tests, fixtures,
parameterized cases, or mocks. They extend the general Python script rules
with behavioral naming and Arrange/Act/Assert structure; prefer `pytest-mock`
for new spy and patch behavior while retaining simple `monkeypatch` use.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
