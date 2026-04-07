---
name: network-azure-guidance
description: 'Runtime lookup guidance for ISA-95 network planning across Azure IoT Operations layered networking, Well-Architected Framework, and Cloud Adoption Framework references. Use when brownfield reuse tradeoffs or greenfield target-state mapping require current Microsoft guidance. - Brought to you by microsoft/hve-core'
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-07"
---

# Network Azure Guidance Skill

## Overview

Provides reusable research prompts and output templates for delegated Microsoft guidance lookups during ISA-95 network planning.

Use this skill when planning needs current Microsoft references for:

* Azure IoT Operations layered networking
* Microsoft Well-Architected Framework
* Microsoft Cloud Adoption Framework

## Delegation Triggers

Use delegated runtime lookup when one or more of these conditions is true:

* The user asks for Microsoft architecture alignment
* Greenfield planning requires target reference architecture mapping
* Brownfield reuse decisions require cloud architecture tradeoff justification

## Core References

Start delegated research from these sources:

* <https://learn.microsoft.com/en-us/azure/iot-operations/manage-layered-network/concept-iot-operations-in-layered-network>
* <https://github.com/Azure-Samples/explore-iot-operations/blob/main/samples/layered-networking/aio-layered-network.md>
* <https://learn.microsoft.com/en-us/azure/well-architected/>
* <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/>

## Research Query Templates

Use these templates when calling Researcher Subagent.

AIO layered networking mapping:

```text
Map ISA-95 zones and conduits to Azure IoT Operations layered networking guidance. Return recommended trust boundaries, connectivity patterns, and constraints for site-to-cloud traffic.
```

Brownfield reuse tradeoff:

```text
Evaluate brownfield reuse options for existing reverse proxies, gateways, VPN or ExpressRoute edge, and firewall/NAT/DMZ controls against Microsoft WAF and CAF guidance. Return keep/refactor/retire tradeoffs with risk and migration sequence implications.
```

Greenfield target-state baseline:

```text
Produce a greenfield target-state architecture baseline aligned to Microsoft WAF and CAF for ISA-95 segmented edge Kubernetes environments, including private connectivity controls and landing-zone guardrails.
```

## Expected Output Format

The delegated research output should include:

* Guidance source list with direct URLs
* Scenario type: brownfield or greenfield
* Recommendation summary tied to ISA-95 zones and conduits
* Control baseline recommendations
* Tradeoff notes with rationale
* Confidence and known gaps

## Notes

* Keep standards guidance dynamic through delegation instead of copying static framework text into agent instructions.
* Mark assumptions explicitly when references are unavailable or incomplete.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
