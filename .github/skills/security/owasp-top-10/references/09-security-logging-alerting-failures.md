# 09 Security Logging and Alerting Failures

Identifier: A09:2025
Category: Logging and Monitoring

## Description

Security logging and alerting failures occur when applications cannot detect, escalate, or alert
on active attacks in real time or near real time.
Without sufficient logging, monitoring, and alerting, breaches cannot be detected and incidents
cannot be responded to effectively.
Common weaknesses include auditable events not being logged or logged inconsistently, warnings and
errors generating inadequate log messages, log integrity not being protected from tampering, logs
not being monitored for suspicious activity, logs stored only locally without backups, missing
alerting thresholds and escalation processes, penetration testing and DAST scans not triggering
alerts, sensitive information leaking into logs, and log data not being encoded to prevent
injection attacks against logging systems.

## Risk

* Breaches persisting undetected for extended periods due to lack of monitoring and alerting.
* Inability to perform forensic analysis when logging is insufficient or logs are not retained.
* Regulatory penalties when logging and monitoring requirements mandated by compliance frameworks
  are not met.
* Sensitive data exposure through logs that are visible to unauthorized users or that contain PII.
* Log injection attacks that corrupt log data or exploit monitoring systems when log output is
  not encoded.
* Alert fatigue from excessive false positives preventing identification of genuine attacks.
* Inability to respond to incidents when playbooks for alerting use cases are missing or outdated.

## Vulnerability checklist

* Auditable events such as logins, failed logins, and high-value transactions are not logged or
  logged inconsistently.
* Warnings and errors generate no, inadequate, or unclear log messages.
* Log integrity is not protected from tampering.
* Application and API logs are not monitored for suspicious activity.
* Logs are only stored locally and not backed up.
* Alerting thresholds and response escalation processes are not in place or are ineffective.
* Penetration testing and DAST scans do not trigger alerts.
* The application cannot detect or alert on active attacks in real time.
* Logging and alerting events are visible to unauthorized users or attackers.
* Log data is not encoded correctly, enabling injection attacks against logging systems.
* Detected alerts cannot be processed because playbooks are incomplete or outdated.

## Prevention controls

1. Log all login, access control, and server-side input validation failures with sufficient user
   context for forensic analysis.
2. Log every security control invocation, whether it succeeds or fails.
3. Generate logs in a format that log management solutions can easily consume.
4. Encode log data correctly to prevent injection attacks against logging and monitoring systems.
5. Ensure all transactions have an audit trail with integrity controls such as append-only
   database tables to prevent tampering or deletion.
6. Ensure all transactions that throw an error are rolled back and fail closed.
7. Establish effective monitoring and alerting use cases with playbooks so suspicious activities
   are detected and responded to by the security operations team.
8. Deploy honeytokens in the application and database to detect unauthorized access with minimal
   false positives.
9. Establish or adopt an incident response and recovery plan.
10. Limit or rate-limit repeated identical errors to prevent log flooding and append statistical
    summaries to the original message.

## Example attack scenarios

### Scenario A — Undetected long-term breach

A health plan provider lacks monitoring and logging on its website.
An attacker accesses and modifies thousands of sensitive health records over a period of years.
The breach is discovered only when an external party reports it.

### Scenario B — Third-party cloud breach

An airline's data is hosted by a third-party cloud provider.
The provider detects a breach involving years of passenger personal data, passport details, and
credit card information.
The airline is notified after the breach has already occurred and has limited forensic capability.

### Scenario C — Undetected payment skimming

An airline's payment application has security vulnerabilities exploited by attackers who harvest
over 400,000 customer payment records.
The breach leads to a regulatory fine of 20 million pounds because logging and monitoring did
not detect the attack.

## Detection guidance

* Verify that all auditable events generate log entries with sufficient context.
* Confirm that log integrity is protected through append-only storage or similar controls.
* Test whether DAST scans and penetration testing activities trigger alerts.
* Review alerting rules for appropriate thresholds and confirm that alerts are received and
  reviewed within a defined time window.
* Check that logs are forwarded to centralized log management and backed up.
* Inspect log output for sensitive information that should not be logged.

## Remediation

* Implement comprehensive logging for all authentication, access control, and security events.
* Deploy centralized log management with tamper-evident storage and offsite backup.
* Configure alerting rules with appropriate thresholds and escalation procedures.
* Create and maintain incident response playbooks for all alerting use cases.
* Encode all log output to prevent log injection vulnerabilities.
* Conduct a logging and monitoring gap analysis and remediate identified deficiencies.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
