---
title: vex
description: OpenVEX v0.2.0 specification reference plus VEX management playbooks - Brought to you by microsoft/hve-core.
sidebar_position: 13
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - vex
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/vex`          |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OpenVEX v0.2.0 specification reference plus VEX management playbooks - Brought to you by microsoft/hve-core.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Load this reference in a VEX implementation or review workflow when a project
needs OpenVEX v0.2.0 documents, evidence-backed status decisions, or release
attestation validation. The CVE Analyzer supplies per-CVE exploitability analysis;
detection, drafting, and attestation remain owned by their workflows.

Use the implementation playbook for document, workflow, and CODEOWNERS setup.
Use the review playbook to assess existing statements without granting the reviewer
authority to generate attestations or approve its own conclusions.

## Example usage

Ask a VEX reviewing agent to load `vex` and assess a draft statement for a sample
package version. Supply the package URL, advisory record, dependency-tree evidence,
and available call-path analysis. In this illustrative case, a runtime feature
flag makes reachability uncertain.

The expected recommendation is `under_investigation` with specific questions for
the human reviewer, not `not_affected` based on the absence of a reproduced exploit.
A later `fixed` claim needs a release or patch reference. Success means the draft
status, evidence, and required statement fields agree, forbidden transitions are
avoided, and human review remains outstanding. No statement publication or
attestation is implied by this read-only assessment.
