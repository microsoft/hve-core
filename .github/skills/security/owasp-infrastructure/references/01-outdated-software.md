---
title: 'ISR01: Outdated Software'
description: OWASP Infrastructure Top 10 reference for outdated software vulnerabilities including unpatched systems and end-of-life components
---

# 01 Outdated Software

Identifier: ISR01:2024
Category: Patch Management

## Description

Outdated software occurs when software components, including libraries and dependencies, are not
kept on current, stable, and supported versions.
Updates frequently include security-relevant patches, meaning unpatched software may contain
vulnerabilities in its current version state.
These vulnerabilities are often publicly known and can be discovered by security scanners.
Due to the lack of updates and update management, many software components and underlying systems
become vulnerable over time, with increasing criticality as time passes.

## Risk

* Vulnerabilities ranging from low criticality to full system compromise.
* Severity and count of vulnerabilities in outdated software increase over time as more flaws are
  discovered and published.
* Publicly known vulnerabilities are easily exploitable using available scanning tools and exploit
  databases.
* Vendors may cease support for older versions, leaving no remediation path.

## Vulnerability checklist

* Software components are not on the latest stable and supported version.
* No update management process exists to track and apply patches regularly.
* Vendor sites and security advisories are not monitored for zero-day exploits.
* Retired or end-of-life software remains deployed in the environment.
* Libraries and dependencies are not inventoried or checked for updates.

## Prevention controls

1. Keep all software components, including libraries, on an up-to-date, stable, and supported
   version.
2. Regularly check every software component for updates and new patches.
3. Implement an update management process to ensure no components are missed and checks are timely.
4. Monitor vendor sites and information security hubs for news about zero-day exploits.
5. Take precautions to reduce impact or probability of vulnerabilities when no patch is available.

## Example attack scenarios

### Scenario A — Outdated web server

A company hosts an internal website for employees.
The company lacks an update management process and does not regularly check or update its software.
The web server runs on an outdated version with known vulnerabilities, including a Remote Code
Execution flaw.
An attacker who gained access to an employee's computer enumerates the internal web server version
and finds a related CVE.
The attacker uses a publicly available exploit to gain access to the underlying server.

### Scenario B — Deprecated old server

A company has an update management process for its software components.
The process fails to inventory an old internal server containing confidential construction plans.
An attacker who gained access to the internal network discovers this server and enumerates its OS
version.
The vendor no longer supports the version, and it is prone to several critical vulnerabilities.
The attacker uses a publicly available exploit to access the server and exfiltrate the confidential
plans, selling them to competitors.

## Detection guidance

* Automated vulnerability scanning to identify outdated software versions.
* Inventory reconciliation against vendor-supported version lists.
* CVE database monitoring for components in the environment.
* Alerting on end-of-life or end-of-support software still in production.

## Remediation

* Update all identified outdated software to the latest stable, supported version.
* Decommission or isolate systems running software that can no longer be patched.
* Establish a recurring update management cycle with defined ownership.
* Subscribe to vendor security advisory feeds for all deployed software.
* Conduct post-update validation to confirm patches are applied and effective.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
