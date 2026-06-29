---
title: Branch Protection
description: Main branch protection requirements for the hve-core repository
sidebar_position: 2
author: Microsoft
ms.date: 2026-06-29
ms.topic: reference
keywords:
  - branch protection
  - codeowners
  - security
  - pull requests
estimated_reading_time: 3
---

## Overview

The main branch for hve-core is protected to reduce the risk of unreviewed or unauthorized changes to workflow and release automation.

> This page describes the security policy and rationale for branch protection. For contributor-facing configuration steps, required status checks, and OpenSSF Scorecard guidance, see [Branch Protection Configuration](../contributing/branch-protection.md).

## Required Controls

The repository enforces the following main-branch protections:

* Require a pull request before merging
* Require review from a Code Owner before merging
* Dismiss stale approvals when new commits are pushed
* Disallow force-pushes to the branch

## CODEOWNERS Coverage

The repository's `CODEOWNERS` file assigns ownership for repository configuration and workflow definitions under the `.github/` path to the core team. That ownership is the review path that supports the branch protection requirement for Code Owner approval.

## Rationale

These controls strengthen the repository's supply-chain posture by ensuring that changes to workflows, automation, and release logic are reviewed by the appropriate maintainers before they can merge.

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
