---
title: mcsb
description: Microsoft Cloud Security Benchmark (MCSB v2) control-domain taxonomy and NIST 800-53 / CIS Controls crosswalk for planning and reviewing Azure cloud resources.
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - mcsb
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/mcsb`         |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Microsoft Cloud Security Benchmark (MCSB v2) control-domain taxonomy and NIST 800-53 / CIS Controls crosswalk for planning and reviewing Azure cloud resources.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this load-only reference with the Security Planner or Security Reviewer when
an Azure design needs a consistent control-domain vocabulary and a domain-level
crosswalk to NIST SP 800-53 or CIS Controls. It targets MCSB v2 preview, not a
service-specific compliance certification.

The packaged taxonomy is separate from changing service baselines, Azure Policy
mappings, and Defender for Cloud details. Those require current research through
the source's lookup playbook before a compliance decision.

## Example usage

Ask the Security Planner to load `mcsb` for an illustrative storage-backed API.
Provide a sanitized architecture showing its identity, network boundary, data
classification, and logging design. Request a domain-level control map, with
service-specific claims left unverified until researched.

The planner should connect the supplied design to relevant domains such as
identity management, data protection, and logging, then identify evidence needed
for gaps. Success is a traceable control map that labels the preview version and
separates packaged guidance from freshly verified service facts. It is not a claim
that a deployed subscription passed an assessment, and it authorizes no resource
changes.
