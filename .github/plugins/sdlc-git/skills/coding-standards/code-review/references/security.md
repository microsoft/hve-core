---
description: 'Opt-in security review reference for Code Review. Read only when the user explicitly requests a security review.'
---

# Security review (opt-in)

> [!IMPORTANT]
> Read this reference and load domain security skills **only** when the user explicitly requests a `security` review (either for specific areas or for the whole review). Never preload this file during a default functional review.

## Goal

Identify changed paths in the assigned scope that permit a concrete security failure across a trust boundary. Follow [review-contract.md](review-contract.md) and tag findings with vector `security`.

## Review

Trace untrusted input across the assigned areas through validation, authentication, authorization, parsing, serialization, storage, external-program execution, and output. Activate a matching domain security skill only when the assigned surface warrants its specific criteria.

Every `security` finding requires a plausible actor, a reachable changed path, a failed or missing control, and a concrete security consequence backed by captured anchors. Check existing mitigations and counter-evidence before reporting. Do not report theoretical attacks without reachability, benign string matches, or general code-quality issues that belong in `functional`. Keep all demonstrations benign and never persist secret values.

If repository rules require a per-skill or component `SECURITY.md` threat model for a changed runtime surface, verify whether the model and registry reflect the change; cite that rule and record a stale or missing model without inventing an exploit severity from documentation drift alone.

## Completion

Include risk-pattern provenance in `criterion` when applicable. Stop `blocked` when the relevant trust boundary cannot be established from available context. Correlate accepted findings with a Security Plan Drift baseline ([integrations.md](integrations.md)) only when explicitly requested by the user.
