---
title: 'ISR05: Insecure Use of Cryptography'
description: OWASP Infrastructure Top 10 reference for cryptography vulnerabilities including weak algorithms and unencrypted internal communications
---

# 05 Insecure Use of Cryptography

Identifier: ISR05:2024
Category: Data Protection

## Description

Insecure use of cryptography occurs when encryption and cryptographic methods are not sufficiently
implemented on systems and protocols used in the internal network.
This is well understood for external applications but is often overlooked for internal
infrastructure.
If sufficient encryption is absent, an adjacent threat actor may read, modify, or inject data
into communications and systems.
A defense line only to the outside does not fully protect internal systems; once an attacker gains
internal network access (e.g., via phishing), external defenses are largely bypassed.
Internal infrastructure security must be as strong as, or stronger than, external system security.

## Risk

* Information leakage and compromise of privileged accounts when insecure cryptographic methods
  or configurations are used.
* Significantly increased chance of devastating cyberattacks and greater impact.
* Unencrypted remote access protocols allow adjacent threat actors to read credentials from
  network traffic.
* Protocols without cryptographic integrity checks enable man-in-the-middle attacks where data
  is modified in transit.

## Vulnerability checklist

* Remote access tools (e.g., Telnet, unencrypted RDP) transmit credentials in clear text.
* Protocols in use do not perform cryptographic identity or integrity checks.
* Insecure or deprecated cryptographic algorithms are configured on internal systems.
* Internally developed cryptographic implementations are used instead of established libraries.
* Communication paths between internal systems lack encryption.

## Prevention controls

1. Ensure all protocols, communication tools, remote access tools, and data transfer tools are
   configured to use secure cryptographic methods and configurations.
2. Migrate protocols that do not support secure encryption to secure alternatives (Telnet to SSH,
   FTP to SFTP).
3. Verify that cryptographic methods and configurations are sufficient, implemented per best
   practices, and follow official recommendations.
4. Use publicly available and established cryptographic libraries; do not develop custom
   cryptographic implementations.

## Example attack scenarios

### Scenario A — Unencrypted remote access tools

A company has an internal infrastructure with servers providing applications to employees,
including a CRM system holding sensitive customer data.
A threat actor gains access to the internal network through a misconfigured internet-exposed
system.
The threat actor sniffs internal network traffic from the compromised machine.
An administrator connects to an internal file server using Telnet to perform an update.
Because Telnet transmits data without encryption, the administrator's credentials are sent in
clear text.
The threat actor captures the credentials and uses them to log on to the CRM server, exfiltrating
all customer data.

### Scenario B — Insufficient use of cryptography

A company has an internal infrastructure with an invoice management application.
A threat actor gains access to the internal network and can inspect and inject packets into
traffic.
An employee connects to the invoice system to create invoices.
The communication protocol is encrypted but does not perform a cryptographic identity or integrity
check.
The threat actor performs a man-in-the-middle attack, modifying data packets to redirect invoice
payments from the company's account to an attacker-controlled account.
Customers unknowingly transfer money to the attacker.

## Detection guidance

* Scan internal network traffic for unencrypted protocols (Telnet, FTP, unencrypted RDP).
* Audit cryptographic configurations on servers, remote access tools, and data transfer services.
* Identify use of deprecated algorithms or cipher suites in internal communications.
* Monitor for man-in-the-middle indicators such as certificate warnings or unexpected traffic
  patterns.

## Remediation

* Replace all unencrypted protocols with secure alternatives (SSH, SFTP, encrypted RDP).
* Update cryptographic configurations to use current, recommended algorithms and cipher suites.
* Remove internally developed cryptographic implementations and adopt established libraries.
* Enable cryptographic identity and integrity verification on all internal communication
  protocols.
* Conduct a full audit of internal communication paths and remediate any unencrypted channels.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
