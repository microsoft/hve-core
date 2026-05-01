---
title: 'ISR08: Information Leakage'
description: OWASP Infrastructure Top 10 reference for information leakage vulnerabilities including exposed sensitive data and insufficient data classification
---

# 08 Information Leakage

Identifier: ISR08:2024
Category: Data Protection

## Description

Information leakage occurs when confidential or sensitive data is unintentionally or maliciously
exposed, either within or outside an organization, due to inadequate security measures or personnel
negligence.
This leakage can manifest in various forms: improper disposal of documents, misconfigured
permissions on network shares, or unsecured communication channels.
It can also result from insider threats where disgruntled employees or malicious insiders
intentionally exfiltrate data for personal gain or sabotage.
This threat requires a holistic approach encompassing robust access control, data encryption,
regular audits, and a culture of security awareness among employees.

## Risk

* The severity depends on what information is leaked; internal IP addresses expose new network
  targets, while personally identifiable information or protected data can lead to fraud, identity
  theft, or competitive disadvantage.
* Information leakage can expose an organization to extortion threats from malicious actors.
* Cumulative risk emphasizes the need for stringent cybersecurity measures, continuous monitoring,
  and a well-informed workforce.

## Vulnerability checklist

* Access permissions on network shares or databases are misconfigured or overly permissive.
* Sensitive data is transmitted over unsecured communication channels.
* Documents containing sensitive information are improperly disposed of.
* No data handling policies exist or adherence to regulatory compliance is not enforced.
* Employees lack security awareness training on data leakage prevention.
* Incident reporting processes are absent or slow.

## Prevention controls

1. Employ encryption technologies to ensure data remains unintelligible in case of interception
   or unauthorized access.
2. Implement strict access control measures so only authorized individuals can access sensitive
   information.
3. Conduct regular security audits and network monitoring to identify and rectify potential
   weaknesses.
4. Provide comprehensive security training and awareness programs to equip employees with
   knowledge to recognize and prevent data leakage scenarios.
5. Foster a culture of accountability and quick incident reporting to mitigate damage when
   leakage occurs.
6. Establish clear data handling policies and ensure adherence to regulatory compliance.

## Example attack scenarios

### Scenario A — Customer data access for all employees

Due to a system misconfiguration, all employees gain unrestricted access to a database containing
sensitive customer information.
A curious employee browses the database and inadvertently shares customer data externally while
on a public network.
Simultaneously, a malicious insider extracts and sells the data on the dark web.
Customers report fraudulent activities traced back to the data leakage, resulting in significant
financial, legal, and reputational damage.

## Detection guidance

* Monitor access logs for unusual or broad access patterns to sensitive data stores.
* Scan network shares and databases for overly permissive access configurations.
* Detect sensitive data patterns in outbound network traffic.
* Review document disposal and data handling practices during audits.

## Remediation

* Restrict access permissions to sensitive data stores following the principle of least privilege.
* Encrypt all sensitive data at rest and in transit.
* Remediate misconfigured network shares and database permissions immediately.
* Establish and enforce data classification and handling policies.
* Implement data loss prevention (DLP) monitoring on egress points.
* Conduct organization-wide security awareness training focused on data handling.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
