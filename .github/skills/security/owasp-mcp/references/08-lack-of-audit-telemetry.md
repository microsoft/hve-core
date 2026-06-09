---
title: 'MCP08: Lack of Audit and Telemetry'
description: OWASP MCP Top 10 reference for audit and telemetry vulnerabilities including logging gaps and observability deficiency patterns
---

# 08 Lack of Audit and Telemetry

Identifier: MCP08:2025
Category: Observability

## Description

MCP systems orchestrate complex, autonomous workflows performing data retrieval, tool execution,
and decision-making with minimal human intervention.
When audit logging and telemetry are absent or poorly implemented, organizations lose visibility
into agent actions, data access patterns, and decision provenance.
This gap undermines incident response, obscures compliance violations and insider abuse, and
allows unmonitored agents to silently perform sensitive operations or exfiltrate data for extended
periods without detection.

## Impact

* No traceability for agent actions or context decisions.
* Compliance failure with GDPR, PCI DSS, ISO 27001 requirements.
* Delayed breach detection increasing dwell time and damage.
* Integrity loss making outcome verification impossible.
* Operational blind spots hiding model drift, behavioral anomalies, or prompt injections.
* Regulatory penalties and reputation damage from inability to demonstrate due diligence.

## Vulnerability checklist

* Agent activity is not logged in a structured, centralized format.
* Logs are stored locally, deleted frequently, or lack integrity protections.
* Tool invocations, prompt contents, and system events are not captured or correlated.
* No integration with SIEM/XDR or centralized monitoring platforms.
* Logs do not include user identity, timestamps, or schema versioning.
* No alerting for anomalous tool use or unauthorized API calls.
* Privacy concerns led to overly broad log suppression instead of redaction.
* Audit retention policies are undefined or misaligned with compliance requirements.

## Prevention controls

1. Log all agent actions, tool invocations, schema versions, and context snapshots in structured format (JSON, CEF, OTEL).
2. Apply cryptographic hashing (HMAC, SHA-256) to log files for integrity.
3. Store logs in append-only or write-once media (S3 Object Lock, WORM storage).
4. Forward MCP logs to enterprise SIEM systems for correlation.
5. Establish automated alert rules for high-risk activities.
6. Implement PII-safe logging with tokenization or field-level encryption.
7. Build behavioral baselines and use anomaly detection for deviations.
8. Restrict log access with separation of duties and least privilege.
9. Use OpenTelemetry or equivalent to trace requests across the MCP pipeline.
10. Align log retention with applicable compliance frameworks.

## Example attack scenarios

### Scenario A — Silent exfiltration

A compromised healthcare analytics agent exports small amounts of patient data via legitimate tool
calls and the breach remains undetected for months because telemetry is disabled.

### Scenario B — Insider manipulation

A developer disables telemetry for a testing session and uses the agent to extract pricing model
data with no audit trail to establish accountability.

### Scenario C — Prompt injection leading to data theft

A malicious PDF causes an agent to retrieve credentials and send them to an external domain.
No logs exist for context transformations or network calls.

### Scenario D — Drift without detection

A compliance bot drifts in behavior after retraining cycles, approving violating actions.
Without telemetry and baselines, changes go unnoticed until a manual audit months later.

## Detection signals

* Gaps or inconsistencies in audit trails.
* Unexplained spikes in API billing, latency, or resource consumption.
* Lack of log entries during active usage periods.
* Incident response teams reporting "no data available" during investigations.
* Sudden drops in telemetry ingestion volume.

## Remediation

* Re-enable detailed logging at all MCP layers (agent, tool, network).
* Deploy forwarders to central SIEM/XDR with retention guarantees.
* Implement masking and pseudonymization for privacy-sensitive fields.
* Reconstruct minimal timeline from external system logs.
* Enforce mandatory logging for all MCP agents going forward.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
