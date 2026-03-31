---
title: 'ISR06: Insecure Network Access Management'
description: OWASP Infrastructure Top 10 reference for network access management vulnerabilities including flat networks and missing segmentation
---

# 06 Insecure Network Access Management

Identifier: ISR06:2024
Category: Network Security

## Description

Network Access Management is a fundamental aspect of internal infrastructure architecture and
access control regulation.
Qualitative Network Access Management prevents a variety of attacks and can reduce the impact of
cyberattacks as well as the movement of threat actors inside the internal infrastructure.
A critical risk is the lack of network separation, which would restrict access from one part of
the infrastructure to another.
Organizations often fail to prevent threat actors from accessing the internal network when the
attacker gains physical access to a network port or nearby Wi-Fi.
Traffic should be supervised and regulated context-based, close to the application layers, for
communication paths that must be allowed.

## Risk

- Absence of network separation severely increases the risk of cyberattacks spreading through the
  internal infrastructure and compromising the entire environment from a single compromised
  component.
- Without Network Access Control (NAC), an attacker who gains physical access to network
  components, convinces employees to plug in malicious devices, or reaches nearby Wi-Fi can access
  internal networks.
- Insufficient access regulation at the application layer allows threat actors to abuse commonly
  allowed communication paths.

## Vulnerability checklist

- No network separation exists between distinct infrastructure segments.
- No Network Access Control (NAC) mechanisms (e.g., certificate-based NAC) are implemented.
- Communication paths between network segments are not dynamically regulated at the application
  layer.
- Remote access is not secured with technologies like VPNs.
- No access matrix exists to plan and enforce network access management.

## Prevention controls

1. Implement NAC mechanisms (e.g., certificate-based NAC) to ensure only approved devices can
   access the company network.
2. Design network separation in the architecture phase; keep network segments as small as possible
   following the need-to-know principle.
3. Use VLANs to separate the infrastructure.
4. Supervise and regulate communication paths between isolated network segments.
5. Dynamically regulate bridges and network transitions based on application layer context.
6. Secure remote access using VPN technologies.
7. Develop an access matrix to plan the network access management structure.

## Example attack scenarios

### Scenario A — Insufficient network separation
A company hosts different customer-facing applications accessible online.
Multiple database servers hold data for those applications, alongside servers for internal
applications and data.
A threat actor finds a vulnerability in one publicly accessible application server and gains
complete control.
Because of absent network separation, the attacker moves laterally and compromises all database
servers as well as internal application and data servers from a single entry point.
The exfiltrated data is later sold to other cybercriminals.

### Scenario B — Missing NAC allowing rogue device
A company uses a common internal infrastructure with application servers and employee file shares.
New network printers are ordered to replace old ones.
A threat actor injects malicious hardware into a new printer before it arrives at the company.
When the printer is connected to the internal network, the embedded small computer also gains
network access because no NAC is in place.
The malicious hardware connects to a remote host controlled by the threat actor, establishing a
pivot point into the internal network for additional attacks.

## Detection guidance

- Audit network topology for missing segmentation between operational zones.
- Check for NAC enforcement on all physical and wireless network ports.
- Monitor for unauthorized or unknown devices appearing on the network.
- Review application-layer traffic controls at segment boundaries.

## Remediation

- Implement network segmentation with VLANs and firewall rules between operational zones.
- Deploy certificate-based NAC on all network ports and wireless access points.
- Create and enforce an access matrix governing inter-segment communication.
- Implement dynamic application-layer filtering at network boundaries.
- Secure all remote access channels with VPN or equivalent encrypted tunneling.
- Conduct regular network topology reviews and penetration tests.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
