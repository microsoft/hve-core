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

## Common examples

1. Poisoned prompt templates loaded remotely: an agent automatically pulls prompt templates from
   an external source that contain hidden instructions leading to execution of malicious behavior.
2. Tool-descriptor injection: an attacker embeds hidden instructions or malicious payloads into
   a tool's metadata or agent-card, which the host agent interprets as trusted guidance.
3. Impersonation and typosquatting: a malicious service deliberately impersonates a legitimate
   tool or agent, mimicking its identity, API, and behavior to gain trust.
4. Vulnerable third-party agent: a third-party agent with unpatched vulnerabilities or insecure
   defaults is invited into multi-agent workflows. A compromised peer agent can be used to pivot,
   leak data, or relay malicious instructions.
5. Compromised registry server: a malicious agent-management or registry server serves
   signed-looking manifests, plugins, or agent descriptors, allowing wide exposure of tampered
   components at scale.
6. Poisoned knowledge plugin: a popular RAG plugin fetches context from a third-party indexer
   seeded with crafted entries. The agent gets biased gradually and exfiltrates sensitive data
   during normal use.

## Attack scenarios

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

## Prevention and mitigation

1. Sign and attest manifests, prompts, and tool definitions. Require and operationalize SBOMs and
   AIBOMs with periodic attestations. Maintain inventory of AI components.
2. Allowlist and pin dependencies. Scan for typosquats. Verify provenance before install or
   activation. Auto-reject unsigned or unverified packages.
3. Run sensitive agents in sandboxed containers with strict network or syscall limits and require
   reproducible builds.
4. Put prompts, orchestration scripts, and memory schemas under version control with peer review.
   Scan for anomalies.
5. Enforce mutual auth and attestation via PKI and mTLS. Sign and verify all inter-agent messages.
6. Re-check signatures, hashes, and SBOMs at runtime. Monitor behavior, privilege use, lineage,
   and inter-module telemetry for anomalies.
7. Pin prompts, tools, and configs by content hash and commit ID. Require staged rollout with
   differential tests and auto-rollback on hash drift.
8. Implement emergency revocation mechanisms that can instantly disable specific tools, prompts,
   or agent connections across all deployments when a compromise is detected.
9. Design systems with zero-trust security model that assumes failure or exploitation of agentic
   function components.
