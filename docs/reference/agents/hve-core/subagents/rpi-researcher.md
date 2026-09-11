---
title: RPI Researcher
description: "Gathers candidate sources for one bounded research question and returns source pointers, exact locations, contract excerpts, and brief relevance notes as suggestions for the calling agent to verify. Use during research when isolating source gathering would help."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-researcher
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-researcher.agent.md`              |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Gathers candidate sources for one bounded research question and returns source pointers, exact locations, contract excerpts, and brief relevance notes as suggestions for the calling agent to verify. Use during research when isolating source gathering would help.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Researcher` is an optional helper that [rpi-research](../../../skills/rpi/rpi-research) may use, not a required step and not something a user selects. The research context decides whether isolating a bounded gathering task, such as collecting candidate sources for one question or retrieving an exact API, schema, or example, would improve evidence quality or protect its working context.

The helper gathers and returns; it does not conclude. Its return lists each suggested source with an exact location (a workspace-relative path and heading or symbol, or a URL with retrieval date), a line on what it appears to contain, a line on why it seems relevant, verbatim excerpts when a contract was requested, and a brief interpretation labeled as unverified.

The research context keeps every decision: it reads the sources it chooses, assigns `C#` and `W#` IDs, classifies evidence state, and records findings in the primary research artifact. The helper writes no file and never speaks to the user.

## Example usage

A representative dispatch supplies one bounded question and the return kind:

```text
Question: Q2 chunk size and concurrency defaults, Q3 retry semantics on partial upload,
  for azure-storage-blob async uploads over 1 GB.
Scope: current official documentation or SDK source; no third-party blogs.
Return: source pointers plus the exact upload_blob signature.
Limit: none.
```

The helper returns suggestions rather than findings:

```text
* Status: Complete
* Question: Q2 and Q3 for azure-storage-blob async uploads over 1 GB
* Suggested sources:
  * https://learn.microsoft.com/python/api/azure-storage-blob/... (retrieved 2026-09-11): BlobClient.upload_blob reference; appears to define max_block_size and max_concurrency; relevance High for Q2
  * https://github.com/Azure/azure-sdk-for-python/... _upload_helpers.py (retrieved 2026-09-11): chunk upload loop; appears to show no retry on a failed block; relevance Medium for Q3
* Exact material: `upload_blob(data, blob_type=..., length=None, metadata=None, **kwargs)` from the reference page above
* Interpretation (unverified): defaults look like 4 MiB blocks with one concurrent upload; Q3 may need the SDK source rather than the docs
* Conflicts and gaps: the reference page does not state retry behavior
* Suggested next look: the retry policy section of the SDK README
* Stop reason: sources covered
```
