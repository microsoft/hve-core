---
title: Security Documentation
description: Index of security documentation including threat model and assurance case for HVE Core
sidebar_position: 1
author: Microsoft
ms.date: 2026-01-23
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

| Document                                                                   | Description                                            |
|----------------------------------------------------------------------------|--------------------------------------------------------|
| [Threat Model](threat-model.md)                                            | Comprehensive threat model and security assurance case |
| [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/SECURITY.md) | Vulnerability disclosure and reporting process         |

## Security Posture

HVE Core is an enterprise prompt engineering framework that:

* Contains no runtime services or user data storage
* Operates as development-time tooling consumed by GitHub Copilot
* Relies on defense-in-depth with 18+ automated security controls

The [threat model](threat-model.md) documents:

* 36 threats across STRIDE, AI-specific, and Responsible AI categories
* Security controls mapped to each threat
* MCP server trust analysis
* Quantitative security metrics
* GSN-style assurance argument

## Related Resources

* [Branch Protection](../contributing/branch-protection.md): Repository protection configuration
* [MCP Configuration](../getting-started/mcp-configuration.md): MCP server setup and trust guidance
* [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md): Project governance and maintainer roles

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
