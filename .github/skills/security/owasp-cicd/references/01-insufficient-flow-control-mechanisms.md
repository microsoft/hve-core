---
title: 'CICD-SEC-1: Insufficient Flow Control Mechanisms'
description: OWASP CI/CD Top 10 reference for insufficient flow control vulnerabilities including unauthorized code changes and deployment bypass
---

# 01 Insufficient Flow Control Mechanisms

Identifier: CICD-SEC-1:2025
Category: Flow Control

## Description

Insufficient flow control mechanisms refer to the ability of an attacker that has obtained permissions
to a system within the CI/CD process (SCM, CI, artifact repository) to single-handedly push malicious
code or artifacts down the pipeline, due to a lack of mechanisms that enforce additional approval or
review.

CI/CD flows are designed for speed. New code can be created on a developer's machine and reach
production within minutes, often with full reliance on automation and minimal human involvement.
Since CI/CD processes are the highway to highly gated and secured production environments,
organizations must introduce measures and controls to ensure that no single entity (human or
application) can push code or artifacts through the pipeline without undergoing a strict set of
reviews and approvals.

## Risk

* An attacker with access to the SCM, CI, or downstream systems can deploy malicious artifacts
  potentially all the way to production without any approval or review.
* Pushing code to a repository branch that is automatically deployed through the pipeline to
  production.
* Abusing auto-merge rules that automatically merge pull requests meeting a predefined set of
  requirements, pushing malicious unreviewed code.
* Abusing insufficient branch protection rules, such as excluding specific users or branches, to
  bypass protections and push malicious unreviewed code.
* Uploading artifacts to a repository in the guise of a legitimate artifact created by the build
  environment, which may be picked up by a deploy pipeline and deployed to production.
* Directly changing application code or infrastructure in production without additional verification.

## Vulnerability checklist

* Repository branches hosting production code lack branch protection rules.
* Users or branches are excluded from branch protection rules.
* Auto-merge rules exist that can be bypassed or manipulated.
* Pipeline triggers do not require additional approval for production deployments.
* Artifacts uploaded by non-CI service accounts are not blocked or reviewed before flowing through
  the pipeline.
* No drift detection exists between code running in production and its CI/CD origin.
* Single accounts have both push-to-repository and trigger-deployment permissions.

## Prevention controls

1. Configure branch protection rules on branches hosting code used in production and other
   sensitive systems.
2. Avoid excluding user accounts or branches from branch protection rules.
3. Ensure accounts with permission to push unreviewed code do not also have permission to trigger
   deployment pipelines connected to the repository.
4. Limit auto-merge rule usage and ensure they apply to the minimal number of contexts.
5. Review auto-merge rule code thoroughly to prevent bypass and avoid importing third-party code
   in the auto-merge process.
6. Prevent accounts from triggering production build and deployment pipelines without additional
   approval or review.
7. Allow artifacts to flow through the pipeline only when created by a pre-approved CI service
   account.
8. Detect and prevent drifts between code running in production and its CI/CD origin, and modify
   any resource that contains a drift.

## Example attack scenarios

### Scenario A — Unprotected branch deployment

An attacker gains access to a developer account on the SCM. The main branch lacks branch protection
rules. The attacker pushes malicious code directly to the main branch, triggering an automated
pipeline that deploys the code to production without any review or approval gate.

### Scenario B — Auto-merge rule bypass

An organization uses auto-merge rules to merge pull requests that pass automated checks. An attacker
crafts a pull request that satisfies the auto-merge criteria while containing a malicious payload
hidden in an overlooked file type. The PR is automatically merged and deployed to production without
human review.

## Detection guidance

* Audit branch protection rule configurations across all repositories hosting production code.
* Review auto-merge rule logic and history of auto-merged pull requests for anomalies.
* Monitor pipeline triggers and correlate them with code review and approval records.
* Detect configuration drifts between deployed resources and their CI/CD source definitions.
* Alert on artifacts flowing through deployment pipelines that were not produced by approved CI
  service accounts.

## Remediation

* Enable and enforce branch protection rules on all branches linked to production deployments.
* Remove all user and branch exclusions from branch protection rules.
* Separate push-to-repository and trigger-deployment permissions across distinct accounts.
* Audit and harden all auto-merge rules, removing those that are overly permissive.
* Implement artifact provenance validation to ensure only CI-produced artifacts enter deploy
  pipelines.
* Deploy drift detection tooling to identify and alert on unauthorized production changes.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
