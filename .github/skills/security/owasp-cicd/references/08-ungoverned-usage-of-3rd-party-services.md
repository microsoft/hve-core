---
title: 'CICD-SEC-8: Ungoverned Usage of 3rd Party Services'
description: OWASP CI/CD Top 10 reference for ungoverned third-party service usage including excessive permissions and unaudited integrations
---

# 08 Ungoverned Usage of 3rd Party Services

Identifier: CICD-SEC-8:2025
Category: Third-Party Governance

## Description

The CI/CD attack surface consists of an organization's organic assets, such as the SCM or CI, and
the third-party services which are granted access to those organic assets. Risks having to do with
ungoverned usage of third-party services rely on the extreme ease with which a third-party service
can be granted access to resources in CI/CD systems, effectively expanding the attack surface of the
organization.

Third-party applications can be connected through many methods depending on the platform, including
marketplace applications, OAuth applications, provisioned access tokens, provisioned SSH keys, and
webhook events. Each method takes seconds to minutes to implement and can grant third parties
numerous capabilities, ranging from reading code in a single repository to fully administering the
organization. In many cases no special permissions or approvals are required by the organization
prior to implementation.

Build systems also allow easy integration of third parties by adding one or two lines of code to
the pipeline configuration file or installing a plugin from a marketplace. The third-party
functionality is imported and executed as part of the build process with full access to whatever
resources are available from the pipeline stage.

Organizations face significant challenges in obtaining full visibility around which third parties
have access to different systems, what methods of access they have, what level of permissions they
have been granted, and what level of permissions they actually use.

## Risk

* Organizations are only as secure as the third parties they implement.
* Insufficient RBAC and least privilege around third parties, coupled with minimal governance and
  diligence, significantly increase the organization's attack surface.
* Compromise of a single third party can cause damage far outside the scope of the system the
  third party is connected to.
* Third parties with write permissions on a repository can be leveraged to push code that
  triggers a build and runs malicious code on the build system.
* Third parties integrated into build processes execute with full access to pipeline stage
  resources including secrets.
* Lack of visibility over the actual permissions used by third parties versus permissions granted
  prevents effective access control.

## Vulnerability checklist

* Third-party services are granted access to CI/CD systems without a formal approval or vetting
  process.
* Third-party permissions exceed the minimum required for their function.
* No comprehensive inventory exists of all third parties integrated with CI/CD systems.
* Third-party integrations are not reviewed for all methods of access (marketplace apps, OAuth,
  tokens, SSH keys, webhooks).
* Third parties integrated into build processes run without scoped access to secrets and code.
* No ingress or egress filters exist for third-party components executing within pipelines.
* Unused or redundant third-party integrations are not periodically removed.
* Third-party integrations lack predetermined expiry or review dates.

## Prevention controls

1. Establish vetting procedures to ensure third parties are approved prior to being granted
   access and that their permissions align with the principle of least privilege.
2. Introduce controls and procedures to maintain continuous visibility over all third parties
   integrated to CI/CD systems, including method of integration, permissions granted, and
   permissions actually used.
3. Limit and scope each third party to the specific resources it requires access to.
4. Ensure third parties executing as part of the build process run inside a scoped context with
   limited access to secrets and code, and with strict ingress and egress filters.
5. Remove unused and redundant third-party permissions.
6. Periodically review all third-party integrations and deprovision those no longer in use.
7. Require predetermined expiry dates for third-party access grants.

## Example attack scenarios

### Scenario A — Compromised code coverage tool

A popular code coverage tool is integrated into the CI pipeline through a marketplace application.
The tool's infrastructure is compromised by an attacker, who modifies the tool's script to
exfiltrate environment variables from builds. Since the tool executes within the build context with
access to all pipeline secrets, the attacker steals credentials for cloud providers, artifact
registries, and the SCM from every organization using the compromised tool.

### Scenario B — OAuth token theft from analytics platform

A git analytics platform is granted OAuth access to the organization's GitHub repositories for
code analysis. An attacker gains access to the analytics platform's database and steals the stored
OAuth tokens for all customers. The attacker uses the tokens to access and modify source code in
production repositories, inject backdoors, and trigger deployment pipelines.

## Detection guidance

* Enumerate all third-party integrations across CI/CD systems, covering all methods of access
  (marketplace apps, OAuth applications, access tokens, SSH keys, webhooks).
* Compare permissions granted to each third party against permissions actually used.
* Monitor third-party activity logs for unexpected access patterns.
* Alert on new third-party integrations being added without going through the approval process.
* Audit pipeline configurations for third-party components that execute with pipeline-level
  credentials.
* Review webhook configurations for endpoints that are no longer maintained or recognized.

## Remediation

* Conduct a comprehensive inventory of all third-party integrations across every CI/CD system.
* Remove all third-party integrations that are unused, redundant, or unrecognized.
* Reduce permissions of remaining third-party integrations to the minimum required.
* Implement an approval workflow for new third-party integrations with mandatory security review.
* Scope third-party components in build pipelines to isolated contexts with restricted secret
  access and network filtering.
* Establish expiry dates on all third-party access grants and implement periodic re-certification.
* Rotate all credentials that third-party services have had access to after removing unnecessary
  integrations.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
