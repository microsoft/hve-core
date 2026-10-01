---
title: Vally Test Author
description: "Authors Vally conformance test stimuli in two modes: from-artifact (read a prompt, instructions, agent, or skill file and draft a stimulus block) and corpus-import (turn a CSV or XLSX corpus into stimulus blocks), with safety-lint refusal enforcement and SHA-256 dedupe before append-only writes to the routed eval file"
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - agent
  - hve-core
  - vally-test-author
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/vally-test-author.agent.md`           |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Authors Vally conformance test stimuli in two modes: from-artifact (read a prompt, instructions, agent, or skill file and draft a stimulus block) and corpus-import (turn a CSV or XLSX corpus into stimulus blocks), with safety-lint refusal enforcement and SHA-256 dedupe before append-only writes to the routed eval file
<!-- END AUTO-GENERATED: overview -->

## When to use it

The Vally authoring workflow dispatches this worker to draft conformance stimuli from an artifact or import an approved corpus. It routes tests by artifact kind, applies safety checks, deduplicates them, and appends advisory cases. It does not execute Vally or promote cases to authoritative status.

## Example usage

The parent supplies `mode=from-artifact`, a supported target artifact, and the requested documented behaviors. The worker resolves the suite through the Vally skill, checks safety and duplicate hashes, and appends eligible advisory stimuli with an output summary. The source artifact remains unchanged, and unsuitable stimuli are rejected rather than stored as executable test payloads.
