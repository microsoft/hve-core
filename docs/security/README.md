---
title: Security Documentation
description: Index of security documentation including security model and assurance case for HVE Core
sidebar_position: 1
author: Microsoft
ms.date: 2026-07-01
ms.topic: overview
keywords:
  - security
  - documentation
  - index
estimated_reading_time: 2
---

## Overview

This directory contains security documentation for HVE Core, demonstrating defense-in-depth security practices.

## Documents

| Document                                                                   | Description                                                                                                               |
|----------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| [Security Model](security-model.md)                                        | Comprehensive security model and security assurance case                                                                  |
| [Branch Protection](branch-protection.md)                                  | Main branch protection requirements and repository controls                                                               |
| [Dependency Pinning](dependency-pinning.md)                                | Pinning strategies and CI enforcement for all dependency types                                                            |
| [SBOM Verification](sbom-verification.md)                                  | SBOM attestation verification and consumption guide                                                                       |
| [VEX Verification](vex-verification.md)                                    | Download, verify, and interpret the published OpenVEX document                                                            |
| [Fuzzing](fuzzing.md)                                                      | OSSF Scorecard fuzz harness convention and compliance                                                                     |
| [Dangerous Workflow Detection](dangerous-workflow-detection.md)            | Hybrid CI control: a homegrown template-injection gate plus the Poutine supply-chain scanner for GitHub Actions workflows |
| [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/SECURITY.md) | Vulnerability disclosure and reporting process                                                                            |

## Skill Security Models

Skills that ship executable runtimes (network egress, credential handling, subprocess execution, or untrusted document/content parsing) carry a per-skill STRIDE threat model in a `SECURITY.md` alongside their `SKILL.md`. Skills that are pure markdown knowledge packs, or whose scripts only perform local validation with no external surface, do not require one.

| Skill                                   | Runtime surface                                                   | Security model                                                                                                              |
|-----------------------------------------|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| **jira**                                | REST CLI; environment credentials                                 | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/jira/jira/SECURITY.md)                         |
| **gitlab**                              | REST CLI; environment credentials; git-remote subprocess          | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/gitlab/gitlab/SECURITY.md)                     |
| **mural** (experimental)                | REST CLI; embedded MCP server; OAuth token store                  | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/mural/SECURITY.md)                |
| **tts-voiceover** (experimental)        | Azure Speech egress; key/Entra credentials; SSML + PPTX parsing   | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/tts-voiceover/SECURITY.md)        |
| **accessibility**                       | Arbitrary-URL scan egress; `npx @axe-core/cli` subprocess         | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/accessibility/accessibility/SECURITY.md)       |
| **powerpoint** (experimental)           | Sandboxed `content-extra.py` execution; LibreOffice/MuPDF parsing | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/powerpoint/SECURITY.md)           |
| **video-to-gif** (experimental)         | Local CLI (bash + PowerShell); FFmpeg/ffprobe subprocess          | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/video-to-gif/SECURITY.md)         |
| **gh-code-scanning**                    | GitHub code-scanning read via `gh` CLI subprocess                 | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/github/gh-code-scanning/SECURITY.md)           |
| **customer-card-render** (experimental) | Local Python CLI; DT markdown to `content.yaml` emission          | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/customer-card-render/SECURITY.md) |
| **vex**                                 | Local Python gate; untrusted issue-body + OpenVEX doc parsing     | [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/security/vex/SECURITY.md)                      |

## Security Posture

HVE Core is an enterprise prompt engineering framework that:

* Contains no runtime services or user data storage
* Operates as development-time tooling consumed by GitHub Copilot
* Relies on defense-in-depth with 20+ automated security controls

The [security model](security-model.md) documents:

* 36 threats across STRIDE, AI-specific, and Responsible AI categories
* Security controls mapped to each threat
* MCP server trust analysis
* Quantitative security metrics
* GSN-style assurance argument

## Related Resources

* [Branch Protection](branch-protection.md): Repository protection configuration
* [MCP Configuration](../getting-started/mcp-configuration.md): MCP server setup and trust guidance
* [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md): Project governance and maintainer roles

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
