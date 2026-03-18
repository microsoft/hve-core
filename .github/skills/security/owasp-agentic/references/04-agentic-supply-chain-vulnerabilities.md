---
title: 'ASI04: Agentic Supply Chain Vulnerabilities'
description: OWASP Agentic Top 10 reference for supply chain vulnerabilities in agent frameworks, plugins, and tool dependencies
---

# 04 Agentic Supply Chain Vulnerabilities

Identifier: ASI04:2026
Category: Supply Chain

## Description

Agentic supply chain vulnerabilities arise when agents, tools, and related artefacts they work
with are provided by third parties and may be malicious, compromised, or tampered with in transit.
These can be both static and dynamically sourced components, including models and model weights,
tools, plugins, datasets, other agents, agentic interfaces (MCP, A2A), agentic registries and
related artifacts, or update channels.
These dependencies may introduce unsafe code, hidden instructions, or deceptive behaviors into
the agent's execution chain.

Unlike traditional AI or software supply chains, agentic ecosystems often compose capabilities at
runtime, loading external tools and agent personas dynamically, thereby increasing the attack
surface.
This distributed run-time coordination combined with agentic autonomy creates a live supply chain
that can cascade vulnerabilities across agents.

## Risk

* Introduction of unsafe code, hidden instructions, or deceptive behaviors through compromised
  third-party components.
* Cascading vulnerabilities across agents through runtime composition of dynamically sourced
  tools, models, and plugins.
* Exfiltration of private repository data or sensitive information through poisoned tool
  descriptors.
* Interception and manipulation of communications through malicious server impersonation.
* Routing of sensitive requests through attacker-controlled agents via forged agent cards or
  exaggerated capabilities.
* Widespread exposure of tampered components through compromised registry servers or agent
  management platforms.

## Vulnerability checklist

* Agents automatically pull prompt templates from external sources that may contain hidden
  instructions leading to malicious behavior.
* Tool metadata or agent cards accept hidden instructions or malicious payloads that the host
  agent interprets as trusted guidance.
* Agents dynamically discover or connect to external tools or services that may be typosquatted
  or impersonated endpoints.
* Third-party agents with unpatched vulnerabilities or insecure defaults are invited into
  multi-agent workflows.
* Agent management or registry servers serve signed-looking manifests, plugins, or agent
  descriptors without proper verification.
* RAG plugins fetch context from third-party indexers that may be seeded with crafted entries to
  bias agent behavior.

## Prevention controls

1. Sign and attest manifests, prompts, and tool definitions. Require and operationalize SBOMs and
   AIBOMs with periodic attestations. Maintain inventory of AI components.
2. Allowlist and pin dependencies. Scan for typosquats. Verify provenance before install or
   activation. Auto-reject unsigned or unverified packages.
3. Run sensitive agents in sandboxed containers with strict network or syscall limits and require
   reproducible builds.
4. Put prompts, orchestration scripts, and memory schemas under version control with peer review.
   Scan for anomalies.
5. Enforce mutual auth and attestation via PKI and mTLS. Sign and verify all inter-agent messages.
6. Pin prompts, tools, and configs by content hash and commit ID. Require staged rollout with
   differential tests and auto-rollback on hash drift.
7. Implement emergency revocation mechanisms that can instantly disable specific tools, prompts,
   or agent connections across all deployments when a compromise is detected.
8. Design systems with zero-trust security model that assumes failure or exploitation of agentic
   function components.

## Example attack scenarios

### Scenario A — Code assistant supply chain compromise

A poisoned prompt in a coding assistant repository ships to thousands before detection.
Despite failing, it shows how upstream agent-logic tampering cascades via extensions.

### Scenario B — Tool descriptor poisoning

A prompt injection in a public tool hides commands in its metadata.
When invoked, the assistant exfiltrates private repo data without user knowledge.

### Scenario C — Malicious server impersonation

A malicious MCP server on npm impersonates a legitimate email service and secretly BCCs emails
to the attacker.

### Scenario D — Agent-in-the-middle via agent cards

A compromised peer advertises exaggerated capabilities in its agent card.
Host agents pick it for tasks, causing sensitive requests and data to be routed through the
attacker-controlled agent which then exfiltrates or corrupts responses.

## Detection guidance

* Re-check signatures, hashes, and SBOMs at runtime to detect tampered or modified components.
* Monitor behavior, privilege use, lineage, and inter-module telemetry for anomalies.
* Scan for typosquats across package registries including PyPI, npm, and AI tool registries.
* Verify provenance of all tools, agents, and plugins before activation and on an ongoing basis.
* Monitor agent card registrations for exaggerated capabilities or unverified descriptors.

## Remediation

* Implement emergency revocation to instantly disable compromised tools, prompts, or agent
  connections across all deployments.
* Remove or quarantine any unsigned, unverified, or tampered components from the agent ecosystem.
* Re-sign and re-attest all manifests, prompts, and tool definitions after remediation.
* Roll back to pinned versions by content hash and commit ID when drift is detected.
* Require staged rollout with differential tests and auto-rollback for any supply chain changes.
* Enforce reproducible builds for all sandboxed agent containers.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
