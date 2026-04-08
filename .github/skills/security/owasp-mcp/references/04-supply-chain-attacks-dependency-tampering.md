---
title: 'MCP04: Software Supply Chain Attacks and Dependency Tampering'
description: OWASP MCP Top 10 reference for supply chain attack vulnerabilities including dependency tampering and compromised component patterns
---

# 04 Software Supply Chain Attacks and Dependency Tampering

Identifier: MCP04:2025
Category: Supply Chain / Integrity

## Description

MCP environments rely on third-party components including SDKs, connectors, protocol servers,
vector database clients, plugins, and model-side tool integrations.
These modules often run within trusted execution paths, so a compromised dependency can alter agent
behavior, introduce hidden backdoors, or modify protocol semantics without triggering detection.
Attackers may target MCP server libraries, third-party plugins, dependency updates, open-source
model tooling, build pipelines, and package registries.
Compromised components can call unsafe APIs, exfiltrate context data, insert rogue schemas, tamper
with tool execution, or issue silent privilege escalation.

## Impact

* Unauthorized access and code execution.
* Context poisoning and data exfiltration.
* Privilege escalation through manipulated tools or schemas.
* Silent corruption of MCP logic and decisioning.
* Cross-tenant compromise if shared connectors are affected.
* Propagation into downstream systems (CI/CD, cloud infrastructure).

## Vulnerability checklist

* MCP connectors or plugins are installed without signing or provenance checks.
* Dependencies are fetched automatically during runtime or build.
* SBOM or dependency inventory is incomplete or unavailable.
* Teams use "latest" or floating version references.
* No dependency integrity verification (hash, signature, attestation) exists.
* No sandboxing isolates third-party components.
* Vendors or maintainers have no formal security process.
* Open-source components are directly modified and redistributed.
* Plugin code performs network calls without review.

## Prevention controls

1. Require cryptographic signing for SDKs, plugins, tool manifests, and container images.
2. Validate signatures during install and startup.
3. Generate SBOM and CBOM snapshots for each MCP server and plugin package.
4. Track versions, hashes, licenses, and provenance metadata.
5. Pin component versions and avoid "latest" references.
6. Use internal package mirrors or registries.
7. Block direct downloads from the public internet.
8. Apply SCA and code scanning tools to detect known CVEs and malicious indicators.
9. Run plugins in constrained environments (WASM, container isolation).
10. Maintain vendor risk profiles and require signed attestations from suppliers.

## Example attack scenarios

### Scenario A — Trojanized plugin

A popular open-source connector gains a malicious update that silently exfiltrates customer support
transcripts to an adversary-controlled endpoint.

### Scenario B — Registry compromise

An MCP package registry is compromised and replaces specific versions of a library used for context
ingestion with a modified version that injects instructions into shared context memory.

### Scenario C — Dependency confusion

An attacker publishes a dependency to a public registry with the same name as an internal MCP
plugin, and agents pull the attacker's version via default resolution behavior.

### Scenario D — Build pipeline attack

CI systems are compromised and append rogue instructions to MCP manifests, adding privileged schema
methods that call destructive APIs.

## Detection signals

* Hash or signature changes in installed packages.
* Plugins making calls to unknown domains.
* Silent installation of new dependencies.
* Unauthorized schema or configuration diffs.
* Sudden behavior drift in MCP agents.

## Remediation

* Quarantine and remove compromised dependencies.
* Roll back to last known-good versions with verified hashes.
* Rotate all credentials that may have been exposed.
* Audit build pipelines and package registries for tampering.
* Enforce signing and provenance checks across all dependency ingestion paths.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
