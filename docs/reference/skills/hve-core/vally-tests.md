---
title: vally-tests
description: "Authors Vally conformance tests for prompts, instructions, agents, and skills, including refusals for jailbreak, prompt-injection, harmful-elicitation, TOS, CoC, and PII-extraction stimuli"
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - hve-core
  - vally-tests
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/skills/hve-core/vally-tests`                                         |
| Invocation  | Invoked directly as `/vally-tests`, or loaded on demand by referencing agents |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Authors Vally conformance tests for prompts, instructions, agents, and skills, including refusals for jailbreak, prompt-injection, harmful-elicitation, TOS, CoC, and PII-extraction stimuli
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to author Vally conformance stimuli for behavior already claimed by
a prompt, instruction, agent, or skill. From-artifact mode derives tests from one
source artifact; corpus-import mode converts a template-shaped CSV or XLSX batch.
Both select graders, apply the safety check, and deduplicate before appending to
the routed eval file.

It is not a red-team or refusal-quality testing tool. Requests for adversarial
payloads, hidden instructions, personal data, secrets, or policy-boundary mapping
are outside its authoring scope. Creating tests does not mean they have run or passed.

## Example usage

Ask: `/vally-tests Author conformance tests for the attached sample summary prompt's
documented JSON output fields and required citation section. Use benign synthetic
input and do not run model evaluations.` Supply the actual artifact and its stated
output contract; do not invent new behavior for the test to demand.

Expect artifact-kind detection, matching reference checks, an appropriate grader
such as `json_schema` for structured output, safety review, and append-only routing
to the prompt conformance eval file. Success is novel, source-traceable stimuli
plus a run report identifying appended and skipped duplicates, written paths, and
blockers. That report is authoring evidence, not a model-quality verdict.

For a batch, provide rows matching the shipped corpus template instead. The CSV is
the canonical interchange source; its XLSX mirror is regenerated rather than
edited directly. Normalized prompt hashes prevent duplicate appends, and refused
content must not be stored in eval specs or public summaries as an example.
