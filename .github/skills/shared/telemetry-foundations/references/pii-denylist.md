---
description: "Authoritative denylist of fields treated as PII for HVE Core telemetry, with redaction strategies for each entry."
---

# PII Denylist

This denylist is the authoritative list of fields treated as Personally Identifiable Information for telemetry purposes. The list is default-deny: any field appearing here must not be emitted as a span attribute, metric dimension, or log field without an explicit redaction strategy. When introducing a new field that could contain PII, add it to this list first and assign a redaction strategy before emitting.

| Field            | Category   | Redaction Strategy        |
|------------------|------------|---------------------------|
| `user.email`     | Contact    | Hash (SHA-256, truncated) |
| `user.phone`     | Contact    | Drop                      |
| `user.address.*` | Location   | Drop                      |
| `payment.card.*` | Financial  | Drop                      |
| `auth.password`  | Credential | Drop                      |
| `auth.token`     | Credential | Drop                      |

Redaction strategy definitions live in the parent skill under PII Handling. To propose a new entry, follow the intake process in [proposed-additions.md](proposed-additions.md).

