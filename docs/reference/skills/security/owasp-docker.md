---
title: owasp-docker
description: "OWASP Docker Top 6 knowledge base for identifying, assessing, and remediating Docker container security risks."
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-docker
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/owasp-docker` |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP Docker Top 6 knowledge base for identifying, assessing, and remediating Docker container security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use the repository-local reference for agent-assisted review of container user
mapping, patching, network isolation, hardening, security contexts, and resource
protection. It is a load-only knowledge package, not a container scanner or a
command to start a workload.

The source marks this skill as removed from distribution because its OWASP-derived
content uses CC BY-NC-SA 4.0. Do not assume an installed extension includes it or
copy its reference material into a redistributable package without licensing review.

## Example usage

When the repository-local skill is available, ask a reviewing agent to load
`owasp-docker` and assess a sample Dockerfile plus a sanitized deployment manifest.
The sample runs as root, has no resource limits, and exposes an application port;
ask for design findings only, without building or running the image.

The expected review links observations to the relevant packaged references and
suggests changes for the author to evaluate. Success is a bounded set of
file-backed findings with runtime assumptions identified, not a claim that the
container is secure. If the skill is unavailable in the installed distribution,
report that limitation rather than inventing a slash invocation.
