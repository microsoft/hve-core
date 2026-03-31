---
title: 'ISR03: Insecure Configurations'
description: OWASP Infrastructure Top 10 reference for insecure configuration vulnerabilities including default settings and configuration drift
---

# 03 Insecure Configurations

Identifier: ISR03:2024
Category: Configuration Management

## Description

Insecure configurations arise when hardware, software, or network components are not properly set
up, exposing them to potential cyber threats.
These vulnerabilities often serve as low-hanging fruit for attackers, offering a relatively easy
path into an organization's network.
Addressing insecure configurations requires a proactive approach involving regular auditing, robust
configuration management, and adherence to security best practices throughout an organization.

## Risk

* Insecure configurations create openings for exploits, potential data breaches, and lateral
  movement.
* They represent an easily exploitable path into the organization's network.
* Misconfigured systems can enable client-side attacks, cross-site scripting, and data exfiltration.
* Lack of network separation allows attackers to traverse from one operational area to another.

## Vulnerability checklist

* Security headers (CSP, X-Content-Type-Options) are missing from internal web applications.
* Network separation between operational areas is absent or insufficient.
* Default or vendor-shipped configurations are deployed without hardening.
* No regular security audits or vulnerability assessments are performed.
* Vendor hardening guides and security advisories are not followed.

## Prevention controls

1. Conduct regular security audits and vulnerability assessments to identify insecure
   configurations; use automated scanning tools for proactive detection and remediation.
2. Follow vendor security advisories and apply hardening guides to configure software securely.
3. Provide cybersecurity training and awareness programs for employees to reduce the likelihood
   of insecure configurations resulting from not implementing best practices.
4. Implement network segmentation between different operational areas.
5. Apply security headers and secure defaults to all internal web applications.

## Example attack scenarios

### Scenario A — Missing security headers

A company uses an internal web application hosting sensitive client data.
The application lacks essential security headers such as Content Security Policy and
X-Content-Type-Options.
A disgruntled employee with basic technical knowledge discovers this oversight and crafts a
cross-site scripting attack, exploiting the missing headers to inject malicious scripts.
The script exfiltrates sensitive client data to an external server controlled by the insider.

### Scenario B — No network separation

A healthcare provider relies on a single network for administrative operations and patient data
management with no segmentation between the two areas.
A system administrator upset over workplace issues exploits this lack of separation.
Using elevated access privileges, they traverse from the administrative segment to the patient
data management segment and maliciously alter patient records, causing data integrity issues and
potentially endangering patient care.

## Detection guidance

* Scan for missing or misconfigured security headers on internal web applications.
* Audit network topology for absent or insufficient segmentation.
* Compare deployed configurations against vendor hardening baselines.
* Review change management logs for unauthorized configuration changes.

## Remediation

* Apply vendor-recommended hardening guides to all hardware, software, and network components.
* Implement missing security headers on all internal web applications.
* Establish network segmentation between distinct operational areas.
* Create and enforce a configuration management baseline with automated drift detection.
* Schedule recurring security audits and remediate findings promptly.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
