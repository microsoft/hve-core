---
title: security-planning
description: "Security planning reference set for operational buckets, STRIDE analysis, standards mapping, NIST control families, backlog scaffolding, and deterministic TM7 (.tm7) plus markdown dual-output generation."
sidebar_position: 6
ms.date: 2026-07-30
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/project-planning/security-planning`                                 |
| Invocation  | Invoked directly as `/security-planning`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Security planning reference set for operational buckets, STRIDE analysis, standards mapping, NIST control families, backlog scaffolding, and deterministic TM7 (.tm7) plus markdown dual-output generation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a threat model needs to become a durable artifact rather than a conversation: producing a `.tm7` model the Microsoft Threat Modeling Tool can open, rendering a markdown threat-model report, or mapping findings onto STRIDE, NIST control families, and a prioritized backlog.

Reach for a different asset when the work is Responsible AI risk classification (`rai-standards`), supply-chain posture against Scorecard or SLSA (`supply-chain-security`), a specific OWASP catalog (`owasp-*`), or vulnerability triage and VEX authoring (`vex`).

## Example usage

Generate a `.tm7` model from a threat-model spec:

```bash
uv run --project .github/skills/project-planning/security-planning \
  python .github/skills/project-planning/security-planning/scripts/generate_tm7.py \
  docs/planning/threat-models/hve-core-comprehensive.yaml \
  -o hve-core.tm7
```

The generator emits a deterministic model with one diagram surface per scope in the spec, trust-boundary rectangles containing their nodes, and data flows between them. Regenerating from an unchanged spec produces byte-identical output.

Rendering the same spec as markdown uses `generate_markdown.py` with identical arguments. Validating a generated model against the native Threat Modeling Tool requires Windows and a pinned TMT version; see the skill's [README](https://github.com/microsoft/hve-core/blob/main/.github/skills/project-planning/security-planning/README.md) for the harness contract, exit codes, and evidence layout.
