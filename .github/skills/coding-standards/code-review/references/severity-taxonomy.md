---
title: Code Review Severity Taxonomy
description: Severity levels, verdict normalization, and risk classification guidance for code review findings.
ms.date: 2026-06-18
---

## Severity levels

Use the following severity levels consistently:

* `Critical` — data loss, privilege escalation, critical security or reliability failure, or a defect that blocks safe deployment.
* `High` — important correctness, security, or maintainability issue likely to cause user impact or significant regressions.
* `Medium` — notable issue that should be addressed but is not an immediate blocker.
* `Low` — minor polish, clarity, or maintainability concern.

## Verdict normalization

Map findings to a final verdict as follows:

* `request_changes` when any finding is `Critical` or `High`.
* `approve_with_comments` when the review has only `Medium` or `Low` findings.
* `approve` when no findings are present.

## Risk classification

Assign file-level risk using the component context:

* `High` for files handling authentication, authorization, secrets, cryptography, parsing, deserialization, persistence, or financial logic.
* `Medium` for core business logic, API boundaries, and shared utilities with broad impact.
* `Low` for configuration, documentation, cosmetic changes, and isolated helper code.

## Severity count convention

Aggregate findings into `severity_counts` with the counts for `critical`, `high`, `medium`, and `low`. When a finding is not applicable to the chosen perspective, omit it from that perspective-specific report but preserve it in the merged report if it was surfaced by another lane.
