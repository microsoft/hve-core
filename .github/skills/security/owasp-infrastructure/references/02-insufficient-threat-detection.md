---
title: 'ISR02: Insufficient Threat Detection'
description: OWASP Infrastructure Top 10 reference for insufficient threat detection vulnerabilities including missing monitoring and detection blind spots
---

# 02 Insufficient Threat Detection

Identifier: ISR02:2024
Category: Observability

## Description

Insufficient threat detection occurs when an organization lacks the processes and mechanisms
needed to identify threat actors and malicious activities before severe damage is caused.
In most cyberattacks, especially internal ones, the first detection of threat actors happens too
late, typically when ransomware encrypts data or an important server is disrupted.
Threat actors are normally present in an internal network for weeks or months before performing
conspicuous actions.
Qualitative threat detection is needed to identify threat actors in the initial access phase or,
at the latest, in the command and control phase.

## Risk

* If threat actors are not detected early, the target organization may be powerless to mount
  further defense actions.
* Insufficient threat detection is one of the primary reasons sophisticated cyberattacks succeed.
* Without proper detection and monitoring, organizations cannot observe attackers accessing the
  internal network or moving laterally through it.
* Late detection allows attackers to reach critical assets and cause maximum damage before any
  response occurs.

## Vulnerability checklist

* No Security Incident and Event Management (SIEM) system is deployed.
* Endpoint Detection and Response (EDR) is the only detection mechanism without network-level
  coverage.
* Detection sensors are not deployed across multiple infrastructure levels and ISO/OSI layers.
* No anomaly detection for unusual data transfers or access patterns.
* Monitoring coverage gaps exist for servers, network devices, or specific network segments.

## Prevention controls

1. Implement processes and mechanisms on different levels and points of the internal infrastructure
   to build a comprehensive threat detection system.
2. Deploy SIEM systems to aggregate and correlate security events.
3. Deploy Firewalls with inspection and logging capabilities.
4. Deploy EDR applications on endpoints.
5. Implement detection sensors on computers, servers, and the network across different ISO/OSI
   layers.
6. Implement anomaly detection for unusual data transfers and access patterns.

## Example attack scenarios

### Scenario A — Insufficient network detection

A company has an internal infrastructure with endpoint systems and servers for internal
applications holding mandatory business data.
EDR software is deployed on every employee's device.
An employee accidentally downloads and executes malware written by an Advanced Persistent Threat
group, and the EDR fails to detect it.
The malware compromises an internal server from the employee's computer and moves laterally,
compromising all internal servers.
These lateral movements are undetected because no network-level threat detection system exists.
The malware encrypts all server data, halting business operations.
A redundant and complete threat detection system beyond EDR would have detected this activity.

### Scenario B — Insufficient anomaly detection

A company hosts internal services for employees to share critical data and files, providing
laptops and VPN software for remote work.
An employee's laptop is stolen on a train; the cybercriminal gains access to the laptop and the
employee's account.
The criminal finds internal shares and downloads all files.
The company fails to detect this data exfiltration because it lacks anomaly detection that would
have noticed the large data transfer or access to shares the employee typically does not use.
The exfiltrated data and files are later sold to competitors.

## Detection guidance

* Monitor for gaps in logging coverage across the infrastructure.
* Validate that detection sensors cover endpoints, servers, and network segments.
* Test detection capabilities with simulated attack exercises and red team engagements.
* Review alert volumes and false positive rates to confirm detection fidelity.

## Remediation

* Deploy SIEM and centralized log aggregation across all infrastructure tiers.
* Add network-level detection sensors to complement endpoint-only solutions.
* Implement anomaly detection for data transfer volumes and access patterns.
* Conduct detection coverage gap analysis and address identified blind spots.
* Establish regular detection testing through adversary simulation exercises.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
