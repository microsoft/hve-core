---
title: 'ASI05: Unexpected Code Execution'
description: OWASP Agentic Top 10 reference for unexpected code execution where agents generate and run unintended or malicious code
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - agentic
  - code-execution
  - security
estimated_reading_time: 5
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

## Common examples

1. Prompt injection that leads to execution of attacker-defined code.
2. Code hallucination generating malicious or exploitable constructs.
3. Shell command invocation from reflected prompts.
4. Unsafe function calls, object deserialization, or code evaluation.
5. Use of exposed, unsanitized eval() functions powering agent memory that have access to
   untrusted content.
6. Unverified or malicious package installs can escalate beyond supply-chain compromise when
   hostile code executes during installation or import.

## Attack scenarios

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

## Prevention and mitigation

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
7. Do static scans before execution. Enable runtime monitoring. Watch for prompt-injection
   patterns. Log and audit all generation and runs.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
