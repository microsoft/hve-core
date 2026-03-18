---
title: 'ASI05: Unexpected Code Execution'
description: OWASP Agentic Top 10 reference for unexpected code execution where agents generate and run unintended or malicious code
---

# 05 Unexpected Code Execution

Identifier: ASI05:2026
Category: Execution Safety

## Description

Agentic systems, including popular vibe coding tools, often generate and execute code.
Attackers exploit code-generation features or embedded tool access to escalate actions into
remote code execution (RCE), local misuse, or exploitation of internal systems.
Because this code is often generated in real-time by the agent it can bypass traditional
security controls.

Prompt injection, tool misuse, or unsafe serialization can convert text into unintended
executable behavior.
This entry focuses on unexpected or adversarial execution of code (scripts, binaries, JIT/WASM
modules, deserialized objects, template engines, in-memory evaluations) that leads to host or
container compromise, persistence, or sandbox escape.
These outcomes require host and runtime-specific mitigations beyond ordinary tool-use controls.

## Risk

* Remote code execution enabling attackers to gain unauthorized access to host or container
  systems.
* Deletion or overwriting of production data through unreviewed agent-generated commands.
* Installation of hidden backdoors through hallucinated or adversarially influenced code.
* Data exfiltration through shell command injection disguised as legitimate instructions.
* Sandbox escape and persistence through multi-tool chain exploitation.
* Supply chain compromise through dependency lockfile poisoning during automated build tasks.
* Direct code execution through unsafe eval functions in agent memory systems.

## Vulnerability checklist

* Prompt injection can lead to execution of attacker-defined code by the agent.
* Code hallucination can generate malicious or exploitable constructs that appear legitimate.
* Shell command invocation can be triggered from reflected prompts without validation.
* Unsafe function calls, object deserialization, or code evaluation are used without
  sanitization.
* Exposed, unsanitized eval() functions powering agent memory have access to untrusted content.
* Unverified or malicious package installs execute hostile code during installation or import.

## Prevention controls

1. Apply input validation and output encoding to sanitize agent-generated code.
2. Prevent direct agent-to-production systems and operationalize use of vibe coding systems with
   pre-production checks including security evaluations, adversarial unit tests, and detection
   of unsafe memory evaluators.
3. Ban eval in production agents. Require safe interpreters and taint-tracking on generated code.
4. Never run as root. Run code in sandboxed containers with strict limits including network access.
   Restrict filesystem access to a dedicated working directory and log file diffs for critical
   paths.
5. Isolate per-session environments with permission boundaries. Apply least privilege. Fail secure
   by default. Separate code generation from execution with validation gates.
6. Require human approval for elevated runs. Keep an allowlist for auto-execution under version
   control. Enforce role and action-based controls.

## Example attack scenarios

### Scenario A — Vibe coding runaway execution

During automated self-repair tasks, an agent generates and executes unreviewed install or shell
commands in its own workspace, deleting or overwriting production data.

### Scenario B — Direct shell injection

An attacker submits a prompt containing embedded shell commands disguised as legitimate
instructions. The agent processes the input and executes the embedded commands, resulting in
unauthorized system access or data exfiltration.

### Scenario C — Code hallucination with backdoor

A development agent tasked with generating security patches hallucinates code that appears
legitimate but contains a hidden backdoor, potentially due to exposure to poisoned training
data or adversarial prompts.

### Scenario D — Multi-tool chain exploitation

An attacker crafts a prompt that causes the agent to invoke a series of tools in sequence
(file upload, path traversal, dynamic code loading), ultimately achieving code execution
through the orchestrated tool chain.

### Scenario E — Memory system RCE

An attacker exploits an unsafe eval() function in the agent's memory system by embedding
executable code within prompts. The memory system processes this input without sanitization,
leading to direct code execution.

### Scenario F — Dependency lockfile poisoning

The agent regenerates a lockfile from unpinned specs and pulls a backdoored minor version
during fix-build tasks.

## Detection guidance

* Perform static scans on agent-generated code before execution to identify injection-prone
  patterns or known-vulnerable constructs.
* Enable runtime monitoring to detect unexpected code execution, sandbox escape attempts, or
  privilege escalation.
* Watch for prompt-injection patterns in agent inputs that could trigger code generation or
  execution.
* Log and audit all code generation and execution events including parameters, environment, and
  outcomes.
* Monitor for unsafe eval() usage or deserialization of untrusted objects in agent memory systems.

## Remediation

* Remove or replace all unsafe eval() functions and deserialization of untrusted objects in agent
  code.
* Deploy sandboxed execution environments with strict filesystem, network, and privilege
  restrictions.
* Implement validation gates between code generation and execution stages.
* Add static analysis scanning to all agent-generated code before execution.
* Enforce human approval for elevated or production-impacting code execution.
* Pin dependencies by content hash and verify lockfile integrity before automated builds.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
