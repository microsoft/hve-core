---
title: 'SBD-06: Detect and Respond'
description: Secure by Design reference for detection and response covering security logging, monitoring, alerting, and incident response capabilities
---

# 06 Detect and Respond

Identifier: SBD-06
Category: Detection and Response

## Source mapping

* **UK Principle 5** — Build in detect and respond security
* **AU Foundation 5** — Continuous assurance (monitoring aspects)

## Description

Systems must be designed for the inevitability of security vulnerabilities and incidents.
Appropriate security logging, monitoring, alerting, and response capabilities must be integrated
from the outset and continually tested and iterated.

Technology manufacturers should build automated detection and defense into their products to enable
consumers to gather quality evidence of intrusion or compromise. Effective monitoring and incident
response significantly reduce the impact of malicious activity by blocking it before negative
effects are realized.

## Principle checklist

* Security events are logged with sufficient detail for forensic analysis.
* Logs are stored in immutable, centralized, tamper-evident storage.
* Alerting is configured for security-relevant events with appropriate thresholds.
* An incident response plan exists, is documented, and is regularly tested.
* Log retention policies meet regulatory and operational requirements.
* Monitoring covers authentication failures, privilege escalation attempts, and anomalous access.
* Response capabilities include isolation, containment, and recovery procedures.
* Detection capabilities are tested through red team exercises or adversarial simulations.

## Controls and mitigations

1. Implement structured security logging for all authentication, authorization, and data access
   events.
2. Store logs in centralized, immutable storage with tamper-detection mechanisms.
3. Configure alerting for critical security events: repeated auth failures, privilege changes,
   anomalous data access, and configuration changes.
4. Document and maintain an incident response plan with roles, escalation paths, and runbooks.
5. Conduct regular incident response drills and tabletop exercises.
6. Implement automated blocking or throttling for detected attack patterns.
7. Monitor for indicators of compromise aligned with current threat intelligence.
8. Ensure log and telemetry analysis capabilities support real-time and retrospective investigation.
9. Define and enforce log retention periods aligned with regulatory requirements.

## Anti-patterns

* Security events are logged to local files that can be modified by an attacker.
* No alerting exists for critical security events; incidents are discovered by users.
* Logging captures only application errors, not security-relevant events.
* Incident response plans exist on paper but have never been tested.
* Logs lack sufficient context (timestamps, user IDs, source IPs) for investigation.
* Monitoring dashboards exist but are not actively reviewed.
* Response procedures require manual intervention with no automation support.

## OWASP cross-references

* A09:2025 Security Logging and Alerting Failures — insufficient logging and monitoring.
* A01:2025 Broken Access Control — undetected unauthorized access attempts.
* A10:2025 Mishandling of Exceptional Conditions — unmonitored error conditions.

---

Content derived from works by the **UK Government Security Group** (Crown Copyright) licensed
under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
and the **Australian Signals Directorate / ACSC** (© Commonwealth of Australia) licensed under
[CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/).
Modifications: Synthesized into structured principle-checklist format with OWASP cross-references;
merged UK and AU guidance into unified principle areas.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
