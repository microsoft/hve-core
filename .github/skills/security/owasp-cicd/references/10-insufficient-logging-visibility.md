---
title: 'CICD-SEC-10: Insufficient Logging and Visibility'
description: OWASP CI/CD Top 10 reference for insufficient logging and visibility vulnerabilities including blind spots and inadequate audit trails
---

# 10 Insufficient Logging and Visibility

Identifier: CICD-SEC-10:2025
Category: Logging and Visibility

## Description

Insufficient logging and visibility risks allow an adversary to carry out malicious activities
within the CI/CD environment without being detected during any phase of the attack kill chain,
including identifying the attacker's TTPs (Techniques, Tactics, and Procedures) as part of any
post-incident investigation.

The existence of strong logging and visibility capabilities is essential for an organization's
ability to prepare for, detect, and investigate a security-related incident. While workstations,
servers, network devices, and key IT and business applications are typically covered in depth within
an organization's logging and visibility programs, it is often not the case with systems and
processes in engineering environments.

Given the amount of potential attack vectors leveraging engineering environments and processes, it is
imperative that security teams build the appropriate capabilities to detect these attacks as soon as
they happen. As many of these vectors involve leveraging programmatic access against the different
systems, a key aspect is to create strong levels of visibility around both human and programmatic
access.

Both audit logs (user access, user creation, permission modification) and applicative logs (push
events, build executions, artifact uploads) are equally important for maintaining sufficient
visibility.

## Risk

* Organizations that do not ensure appropriate logging and visibility around engineering
  environments may fail to detect a breach entirely.
* Minimal investigative capabilities create great difficulties in mitigation and remediation after
  a breach.
* Time and data are the most valuable commodities during incident response, and the absence of
  all relevant data sources in a centralized location can be the difference between a successful
  and devastating outcome.
* Attackers can operate undetected for extended periods within CI/CD systems.
* Post-incident analysis is severely hampered without comprehensive audit trails across all
  CI/CD systems.
* Inability to correlate events across SCM, CI, artifact repositories, and deployment systems
  prevents detection of multi-stage attacks.

## Vulnerability checklist

* No complete inventory exists of all CI/CD systems, including all instances of self-managed
  systems.
* Audit logs are not enabled on all CI/CD systems, or are not enabled to their full extent.
* Applicative logs (pipeline execution, artifact operations, code operations) are not captured.
* Logs from CI/CD systems are not shipped to a centralized location such as a SIEM.
* No alerts exist to detect anomalies or potential malicious activity in CI/CD systems.
* Programmatic access to CI/CD systems is not logged or monitored to the same degree as human
  access.
* No correlation rules exist to detect anomalies across the code shipping process involving
  multiple systems.
* Log retention periods are insufficient for investigation of incidents discovered with a delay.

## Prevention controls

1. Build and maintain a comprehensive inventory of all CI/CD systems in use, including every
   instance of self-managed systems.
2. Identify and enable all relevant log sources across every CI/CD system, covering both human
   and programmatic access through all available methods.
3. Enable both audit log sources (user access, user creation, permission changes) and applicative
   log sources (push events, build executions, artifact operations).
4. Ship all CI/CD logs to a centralized location such as a SIEM to support aggregation and
   correlation across systems.
5. Create alerts to detect anomalies and potential malicious activity within each system as well
   as across the code shipping process spanning multiple systems.
6. Ensure log retention periods are sufficient for post-incident investigation requirements.
7. Monitor programmatic access with the same rigor as human access.

## Example attack scenarios

### Scenario A — Undetected credential exfiltration

An attacker compromises a CI pipeline through a poisoned dependency and exfiltrates credentials
stored as environment variables. Because no logging exists for outbound network connections from
build nodes and pipeline execution events are not shipped to a centralized monitoring system, the
credential theft goes undetected. The attacker uses the stolen credentials for months, laterally
moving across production environments, before the breach is discovered through an unrelated
investigation.

### Scenario B — Delayed incident response due to missing logs

A build server is compromised and used to inject a backdoor into production artifacts. When the
compromise is eventually discovered, the incident response team attempts to reconstruct the attack
timeline. However, audit logs were not enabled on the CI system, and execution logs were retained
for only seven days. The team cannot determine when the compromise began, what credentials were
accessed, or which artifacts were affected, leading to a full rebuild of all production
infrastructure.

## Detection guidance

* Verify that all CI/CD systems have audit and applicative logging enabled and configured.
* Confirm that logs from all CI/CD systems are being shipped to and received by the centralized
  SIEM.
* Test alert rules by simulating anomalous activities across CI/CD systems.
* Periodically review log coverage to identify CI/CD systems or event types that are not being
  captured.
* Validate that programmatic access events (API calls, token usage, webhook invocations) are
  logged.
* Confirm log retention periods meet investigation requirements.

## Remediation

* Conduct a comprehensive inventory of all CI/CD systems and instances, identifying gaps in log
  coverage.
* Enable all audit and applicative log sources on every CI/CD system.
* Configure log shipping from all CI/CD systems to the centralized SIEM or logging platform.
* Develop and deploy detection rules and alerts for anomalous activity across CI/CD systems,
  including multi-system correlation rules.
* Extend log retention periods to meet organizational incident investigation requirements.
* Ensure programmatic access is logged and monitored at parity with human access.
* Conduct periodic log coverage reviews to catch newly-added systems or configuration drifts.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
