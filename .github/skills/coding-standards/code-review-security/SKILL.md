---
name: code-review-security
description: 'Review assigned changes for realistic security consequences across trust boundaries. Use for the security perspective of Code Review.'
license: CC-BY-4.0
user-invocable: false
---

# Security review

## Goal

Identify changed paths that permit a concrete security failure. Use
`code-review-core`, activating it when not preloaded.

## Review

Trace relevant untrusted input through validation, authorization, parsing,
storage, and output. Examine authentication, permissions, sensitive-data
handling, injection, serialization, dependencies, and external-program
boundaries where the change affects them. Apply an available domain security
skill when it provides the relevant criterion.

A finding needs a plausible actor, reachable changed path, failed control, and
consequence supported by evidence. Verify existing controls and counter-evidence.
Do not report theoretical attacks, harmless string patterns, or pure logic/style
issues without a security consequence. Keep demonstrations benign and do not
persist secret values.

If repository rules require a security model for the changed runtime surface,
check whether its model and registration reflect the change. Cite that rule and
report a missing/stale model as an advisory standards-related observation; do
not invent an exploit severity from missing documentation alone.

## Completion

Give each finding its risk-pattern provenance when applicable and its realistic
consequence. Stop blocked when the trust boundary cannot be established. The
parent may correlate accepted findings with a confirmed security plan. Do not
launch a standalone audit.
