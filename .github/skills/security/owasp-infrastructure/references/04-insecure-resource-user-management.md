---
title: 'ISR04: Insecure Resource and User Management'
description: OWASP Infrastructure Top 10 reference for insecure resource and user management vulnerabilities including overprivileged accounts and missing access reviews
---

# 04 Insecure Resource and User Management

Identifier: ISR04:2024
Category: Access Control

## Description

Insecure resource and user management occurs when an organization fails to plan and enforce proper
access controls for its resources and users.
Most companies rely on centralized tools like Active Directory or Microsoft Entra ID, but rolling
out these tools without a proper security concept introduces vulnerabilities.
Permission and rights management are often neglected, resulting in users or technical accounts
having more permissions than required.
Accounts may not be deleted after an employee departs, and password policies may not be technically
enforced.

## Risk

* Excessive permissions increase the blast radius when a user account is compromised, giving
  threat actors more access and leading to devastating cyberattacks.
* Rights and permissions may not be revoked when employees leave the organization.
* Lack of enforced password policies puts account security at risk.
* Resources and users accumulate over time, making it difficult to maintain oversight, and risks
  arise from unmanaged growth.

## Vulnerability checklist

* Users or technical accounts hold more permissions than needed for their role.
* No need-to-know principle is applied to permission assignments.
* Departed employees' accounts remain active in the directory.
* Password policies are documented but not technically enforced.
* No Privileged Access Management (PAM) solution is implemented.
* Domain administrator accounts are used for routine administration tasks.
* Local administration rights are granted to all employees by default.

## Prevention controls

1. Develop a strategy for which resources exist and who needs access to them; apply the
   need-to-know principle.
2. Apply the strategy to the infrastructure and its centralized management tools (e.g., Active
   Directory).
3. Ensure restrictions are enforced and the management tool is configured securely.
4. Implement Privileged Access Management (PAM) to harden resource and user management.
5. Establish an Authorization Management team that decides who receives which rights, permissions,
   and for how long.
6. Maintain an updated inventory of resources and users, adding new assets and removing retired
   ones promptly.

## Example attack scenarios

### Scenario A — Insecure privilege management

A company uses Active Directory for resource and user management.
All employees have local administration rights, and every IT administrator has domain-admin
rights used for routine tasks.
An employee opens a malicious email attachment via social engineering.
The infected laptop is exploited with a credential extraction tool because local admin rights
allow it to run.
An IT administrator's cached credentials are extracted from the laptop because they logged on
recently to help with a printer problem.
The threat actor obtains domain-admin credentials and compromises the entire infrastructure from
a single system, due to the absence of privileged user management following the need-to-know
principle.

### Scenario B — Deprecated and insecure user accounts

A company has an internal infrastructure with a central customer data management system.
The company does not technically enforce its password policy.
An employee leaves their locked laptop in a café and steps away.
A threat actor tries standard passwords and gains access after a few attempts.
They find a link to the central customer data system and copy all data to their phone.
They also discover an administrative share holding sensitive configuration data and exfiltrate
it.
The weak password and lack of resource management enabled unauthorized access and data theft.

## Detection guidance

* Audit user accounts for excessive or stale permissions on a recurring schedule.
* Monitor for active accounts belonging to departed employees.
* Check for local administrator rights granted broadly across endpoints.
* Review domain-admin account usage for routine non-administrative tasks.

## Remediation

* Remove excessive permissions and enforce the need-to-know principle across all accounts.
* Disable or delete accounts for departed employees immediately.
* Technically enforce password policies through the centralized management platform.
* Remove default local administration rights from standard employee accounts.
* Deploy PAM for all privileged accounts and restrict domain-admin usage to designated tasks.
* Establish an ongoing access review cycle with defined ownership.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
