---
title: Codebase Profiler
description: Scans the repository to build a technology profile and select applicable security skills
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - codebase-profiler
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/security/subagents/codebase-profiler.agent.md`           |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Scans the repository to build a technology profile and select applicable security skills
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reviewer orchestrators dispatch Codebase Profiler to identify technologies, infrastructure patterns, and applicable assessment skills before detailed checks. It supplies context and selection signals, not vulnerability findings or a security verdict. Use the parent reviewer to initiate the assessment.

## Example usage

The parent supplies a repository path and a focus on the API and deployment directories. The profiler returns a structured technology profile and applicable skill candidates backed by discovered files. For diff or plan work, the parent supplies the corresponding changed-file or plan context. The worker does not infer that detected technology is securely configured or expand the requested review scope.
