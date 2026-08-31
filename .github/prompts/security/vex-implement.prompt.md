---
description: "Plan the work to stand up VEX in a target project as a backlog for Task-* implementors - Brought to you by microsoft/hve-core"
name: vex-implement
agent: SSSC Planner
argument-hint: "[scope=path/to/dir] [product=pkg:npm/@org/name]"
---

# VEX Implement

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All VEX implementation planning must be reviewed and validated by qualified security professionals before the target project adopts or publishes the resulting workflow and document changes. The merge commit author is the accountable author of record. AI-produced planning may miss repository-specific constraints, release workflow details, or ownership requirements.

## Inputs

* ${input:scope}: (Optional) Directory or path focus for the target project. When omitted, the planner uses the current repository context.
* ${input:product}: (Optional) Product identifier in PURL format for the planned VEX document and rollout steps. When omitted, infer it from repository context when possible.

## Requirements

1. Drive the SSSC Planner's VEX planning capability to produce an implementation plan and backlog for standing up VEX in the target project.
2. Keep the work in planning mode only; do not implement the VEX changes directly in the target project.
3. Use the `vex` skill as the reference source for the implement playbook and the VEX rules so the backlog can encode the required stand-up steps.
4. Produce backlog work items that cover scaffolding the OpenVEX document under `security/vex`, wiring the `vex-detect` and `vex-draft` workflows, referencing the PR-body scaffold asset, wiring release attestation, and setting CODEOWNERS where appropriate.
5. Make the handoff explicit: the Planner authors the plan and backlog, and the downstream Task-* agents execute the implementation using the `vex` skill.
6. If the target project already has VEX-related assets, incorporate them as context and avoid redundant planning steps.
