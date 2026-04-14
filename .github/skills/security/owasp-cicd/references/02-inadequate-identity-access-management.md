---
title: 'CICD-SEC-2: Inadequate Identity and Access Management'
description: OWASP CI/CD Top 10 reference for identity and access management vulnerabilities including overprivileged accounts and stale permissions
---

# 02 Inadequate Identity and Access Management

Identifier: CICD-SEC-2:2025
Category: Identity Management

## Description

Inadequate identity and access management risks stem from the difficulties in managing the vast
amount of identities spread across the different systems in the engineering ecosystem, from source
control to deployment. The existence of poorly managed identities, both human and programmatic
accounts, increases the potential and the extent of damage of their compromise.

Software delivery processes consist of multiple systems connected together with the aim of moving
code and artifacts from development to production. Each system provides multiple methods of access
and integration (username and password, personal access tokens, marketplace applications, OAuth
applications, plugins, SSH keys). The different types of accounts and methods of access can
potentially have their own unique provisioning method, set of security policies, and authorization
model. This complexity creates challenges in managing identities throughout the entire identity
lifecycle and ensuring their permissions are aligned with the principle of least privilege.

Major concerns include overly permissive identities, stale identities that are no longer active,
local identities not federated with a centralized identity provider, external identities registered
with unmanaged email domains or belonging to external collaborators, self-registered identities
with overly broad default permissions, and shared identities used across multiple humans or
applications.

## Risk

* Compromising nearly any user account on any CI/CD system could grant powerful capabilities to
  the environment and serve as a path into the production environment.
* Hundreds or thousands of identities across the ecosystem, paired with a lack of strong IAM
  practices and overly permissive accounts, drastically expand the attack surface.
* Stale accounts remain valid entry points for attackers long after the original user has departed.
* Local accounts bypass centralized security policies including MFA enforcement and lockout rules.
* External collaborator accounts reduce overall security to the level of the external party's
  environment.
* Shared identities eliminate accountability and expand credential exposure footprint.

## Vulnerability checklist

* Human or programmatic accounts have permissions beyond what is required for their role.
* Inactive accounts exist that have not been disabled or removed within the acceptable period.
* Local user accounts exist on CI/CD systems that are not federated with a centralized IdP.
* Employees use personal email addresses or domains not owned by the organization.
* External collaborators have access without predetermined expiry dates.
* Self-registration is enabled on CI/CD systems with non-zero default permissions.
* Shared accounts are in use across multiple humans or applications.
* No periodic review process exists for identity permissions across the ecosystem.

## Prevention controls

1. Conduct continuous analysis and mapping of all identities across all systems within the
   engineering ecosystem, covering all methods of programmatic access.
2. Remove permissions not necessary for the ongoing work of each identity across all systems.
3. Determine an acceptable period for disabling or removing stale accounts and enforce it.
4. Avoid creating local user accounts; manage identities using a centralized identity provider.
5. Continuously map all external collaborators and ensure their identities follow least privilege,
   with predetermined expiry dates for both human and programmatic accounts.
6. Prevent employees from using personal email addresses or non-organization-owned domains on
   CI/CD platforms.
7. Disable self-registration on CI/CD systems and grant permissions on an as-needed basis.
8. Avoid granting base permissions to all users or large automatically-assigned groups.
9. Avoid using shared accounts; create dedicated accounts for each specific context with exact
   required permissions.

## Example attack scenarios

### Scenario A — Stale account compromise

An engineer leaves the organization but their accounts on the SCM and CI system are not
deprovisioned. An attacker compromises the former engineer's credentials through a credential
stuffing attack. The stale account still has write access to production repositories, allowing
the attacker to push malicious code through the pipeline.

### Scenario B — Overly permissive self-registration

A self-managed CI system allows self-registration. New accounts are assigned a base set of
permissions that includes access to pipeline configurations and build logs. An attacker
self-registers, gains access to the system, and discovers secrets exposed in build logs, which
they use to access production cloud environments.

## Detection guidance

* Periodically enumerate all identities across SCM, CI, artifact repositories, and deployment
  systems, checking for stale, overly permissive, or shared accounts.
* Monitor for logins from non-organization-owned email domains.
* Audit self-registration settings and default permission assignments.
* Alert on identity creation events and permission escalation events across CI/CD systems.
* Review external collaborator access lists and expiration dates.

## Remediation

* Deprovision all stale accounts across every CI/CD system.
* Federate all local accounts to the centralized identity provider.
* Enforce MFA on all human accounts across all CI/CD systems.
* Remove base permissions from self-registered or automatically-assigned groups.
* Replace all shared accounts with dedicated, individually-scoped accounts.
* Establish automated workflows to disable external collaborator access upon contract expiry.
* Implement periodic access reviews with mandatory re-certification of identity permissions.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
