---
title: 'MCP05: Command Injection and Execution'
description: OWASP MCP Top 10 reference for command injection vulnerabilities including shell execution and unsanitized input patterns
---

# 05 Command Injection and Execution

Identifier: MCP05:2025
Category: Injection

## Description

Command injection in MCP environments occurs when an AI agent constructs and executes system
commands, shell scripts, API calls, or code snippets using untrusted input without proper
validation or sanitization.
Unlike traditional command injection where attackers directly control input fields, MCP-based
injection is mediated through the model layer.
The agent interprets natural language instructions and translates them into executable operations,
creating a unique attack surface where prompt-driven execution, dynamic command construction,
tool-mediated execution, and chained execution converge.
Agents operate autonomously and often with elevated privileges, so successful injection can lead to
complete system compromise, data exfiltration, or lateral movement.

## Impact

* Arbitrary code execution with agent privileges.
* Data exfiltration of sensitive files, databases, or environment variables.
* System compromise through backdoors, rootkits, or persistent access mechanisms.
* Privilege escalation via SUID binaries, sudo misconfigurations, or service accounts.
* Denial of service through fork bombs, infinite loops, or system shutdowns.
* Lateral movement using compromised MCP servers as pivot points.
* Supply chain poisoning of build pipelines, CI/CD systems, or deployment artifacts.
* Regulatory violations from unauthorized system modifications or data access.

## Vulnerability checklist

* Agents construct shell commands by concatenating user input without escaping.
* Tool implementations pass agent outputs directly to exec(), system(), eval(), or shell=True.
* No input validation exists for parameters before system calls.
* Model-generated code is automatically executed without sandboxing or human review.
* File path operations accept unsanitized input allowing directory traversal.
* API or database calls use string interpolation rather than parameterized queries.
* Agent outputs are not constrained to allowlists of permitted commands.
* Special characters (;, |, &, $(), backticks) are not stripped or escaped.
* Environment variables or secrets are accessible through command substitution.
* No runtime sandboxing isolates tool execution from the host system.
* Tools run with excessive privileges (root, admin, or broad service accounts).

## Prevention controls

1. Use allowlists for permitted commands, arguments, and file paths.
2. Reject shell metacharacters (; | & $() <> && || backticks).
3. Normalize and validate all file paths to block traversal.
4. Never use shell=True, eval(), exec(), or string-built commands.
5. Execute with structured parameters (e.g., subprocess.run(['ls', 'logs'])).
6. Disable direct execution of model-generated code unless manually reviewed.
7. Run tools inside containers, micro-VMs, gVisor/Kata, or jailed users.
8. Enforce timeouts, resource limits, and read-only file systems.
9. Run tools as non-root with minimal filesystem, API, and DB permissions.
10. Require human approval for destructive, privileged, or system-modifying operations.

## Example attack scenarios

### Scenario A — Shell metacharacter injection

A user asks an agent to "list files in the logs directory" but appends "; cat /etc/passwd".
The agent generates "ls logs; cat /etc/passwd" and the tool executes it as a single shell command.

### Scenario B — API parameter injection

An attacker submits input containing SQL injection payload.
The agent constructs an unparameterized query and the injection destroys the database.

## Detection signals

* Shell metacharacters detected in tool parameters or logs.
* Execution of sudo, su, or SUID binaries by agent processes.
* Outbound connections from agent hosts to unknown domains.
* Access to sensitive paths (/etc/passwd, /root, /proc/, ~/.ssh).
* Abnormal syscall patterns detected by Falco, auditd, or osquery.
* CPU spikes, memory exhaustion, or disk I/O storms from malicious scripts.

## Remediation

* Terminate active sessions where injection is detected.
* Revoke compromised agent credentials.
* Audit all recent tool executions for unauthorized commands.
* Patch tool implementations to use parameterized execution.
* Deploy sandboxing and least-privilege enforcement.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
