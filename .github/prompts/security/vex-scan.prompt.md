---
name: vex-scan
agent: SSSC Reviewer
description: "Run a full VEX pipeline that scans dependencies, enriches CVEs, analyzes exploitability, and drafts an OpenVEX document for review - Brought to you by microsoft/hve-core"
argument-hint: "[scope=path/to/dir] [product=pkg:npm/@org/name]"
---

# VEX Scan

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-drafted VEX status determinations — especially `not_affected` — **must** be reviewed and validated by qualified security professionals before the OpenVEX document is merged or published. The merge commit author is the accountable author of record. AI outputs may contain inaccuracies, miss exploitable paths, or misjudge reachability.

## Inputs

* ${input:scope}: (Optional) Directory or path focus to limit the dependency scan. When omitted, scans the full repository.
* ${input:product}: (Optional) Product identifier in PURL format for the generated statements (for example, `pkg:npm/@microsoft/hve-core`). Inferred from the manifest when not provided.

## Requirements

1. Use the SSSC Reviewer's VEX assessment capability to run the full VEX pipeline (scan, enrich, analyze, and draft an OpenVEX document), following the `vex` skill playbook and the VEX generation and standards instructions.
2. When `${input:scope}` is provided, limit the dependency scan to files within the specified directories or paths.
3. When `${input:product}` is provided, use it as the PURL product identifier for the generated VEX statements.
