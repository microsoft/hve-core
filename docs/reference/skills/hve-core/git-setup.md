---
title: git-setup
description: "Audit Git configuration with one read-only baseline command, then propose confirmed, non-destructive fixes for identity, editor, and diff and merge tooling, with signing and safe.directory help only on request. Use when setting up or checking Git on a workstation."
sidebar_position: 6
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - hve-core
  - git-setup
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                    |
|-------------|------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                    |
| Source      | `.github/skills/hve-core/git-setup`                                                      |
| Invocation  | Invoked directly as `/git-setup`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Audit Git configuration with one read-only baseline command, then propose confirmed, non-destructive fixes for identity, editor, and diff and merge tooling, with signing and safe.directory help only on request. Use when setting up or checking Git on a workstation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `git-setup` to audit Git identity, editor, and diff and merge tooling on a workstation before changing anything. It helps with commit signing or `safe.directory` only when you ask or report a related error. Use direct `git config` commands when you already know the exact change you want.

## How to use it

Run `/git-setup` and answer only the questions for the gaps it reports. The skill reads the configuration with one `git config --list --show-origin` command, proposes small command groups, and applies a group only after an explicit yes. Never share private key material.

## Example usage

```text
/git-setup
```

The skill shows an audit table of current settings with their scopes, proposes fixes for missing identity or tooling values, and summarizes the changes you approved.
