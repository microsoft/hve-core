---
title: 'CICD-SEC-9: Improper Artifact Integrity Validation'
description: OWASP CI/CD Top 10 reference for artifact integrity validation vulnerabilities including unsigned artifacts and missing provenance
---

# 09 Improper Artifact Integrity Validation

Identifier: CICD-SEC-9:2025
Category: Artifact Integrity

## Description

Improper artifact integrity validation risks allow an attacker with access to one of the systems in
the CI/CD process to push malicious (although seemingly benign) code or artifacts down the pipeline,
due to insufficient mechanisms for ensuring the validation of code and artifacts.

CI/CD processes consist of multiple steps, ultimately responsible for taking code all the way from
an engineer's workstation to production. There are multiple resources being fed into each step,
combining internal resources and artifacts with third-party packages and artifacts fetched from
remote locations. The fact that the ultimate resource is reliant upon multiple sources spread across
different steps, provided by multiple contributors, creates multiple entry points through which this
ultimate resource can be tampered with.

If a tampered resource is able to infiltrate the delivery process without raising suspicion or
encountering security gates, it will most likely continue flowing through the pipeline, all the
way to production, in the guise of a legitimate resource.

## Risk

* A malicious artifact shipped through the pipeline can result in the execution of malicious code
  on systems within the CI/CD process or in production.
* Unsigned or unverified code commits can introduce tampered code without attribution.
* Tampered artifacts persisting across pipeline stages can compromise downstream systems.
* Third-party resources fetched without hash verification can be substituted with malicious
  versions.
* Configuration drifts between deployed resources and CI/CD-managed templates may indicate
  unauthorized changes deployed by untrusted sources.

## Vulnerability checklist

* Code commits are not signed and the pipeline does not enforce commit signature verification.
* No artifact signing infrastructure exists to sign resources generated during the pipeline.
* Artifacts are not verified against a signing authority before being consumed in subsequent
  pipeline stages.
* Third-party resources fetched during build or deploy are not verified against published hashes.
* No configuration drift detection exists for production resources versus their CI/CD source
  definitions.
* Pipeline stages accept artifacts from untrusted sources without integrity checks.
* Container images used in production are not signed or verified before deployment.
* No software bill of materials (SBOM) is generated or tracked for pipeline-produced artifacts.

## Prevention controls

1. Implement code signing and enforce signature verification on all commits before they enter the
   pipeline.
2. Sign all artifacts generated during the pipeline using an external resource signing
   infrastructure.
3. Verify artifact integrity against the signing authority before consuming resources in
   subsequent pipeline stages.
4. Calculate and cross-reference hashes of third-party resources against the official published
   hashes of the resource provider before use in build or deploy pipelines.
5. Implement configuration drift detection for production resources, alerting on resources that
   are not managed through a signed infrastructure-as-code template.
6. Generate and track software bills of materials for all pipeline-produced artifacts.
7. Enforce container image signing and verification before deployment to any environment.

## Example attack scenarios

### Scenario A — Tampered build artifact

An attacker gains access to the build server and modifies the application binary after it is
compiled but before it is uploaded to the artifact repository. No signing or integrity validation
exists between the build and deploy stages. The tampered binary is picked up by the deployment
pipeline and deployed to production, executing the attacker's backdoor code on production servers.

### Scenario B — Compromised third-party script

A CI pipeline fetches a third-party script from an external URL during the build process to perform
a specific build task. An attacker gains access to the hosting environment of the third-party script
and replaces it with a malicious version. Because the pipeline does not verify the script's hash
against a known-good value, the compromised script is executed during the next build, stealing
credentials and injecting a backdoor into the build output.

## Detection guidance

* Audit pipeline configurations for stages that consume artifacts without integrity verification.
* Monitor for unsigned commits entering protected branches.
* Detect configuration drifts between production resources and their CI/CD source definitions.
* Compare hashes of fetched third-party resources against known-good reference values.
* Track artifact provenance across pipeline stages and alert on artifacts without valid
  signatures.
* Monitor for container images deployed without valid signatures.

## Remediation

* Deploy an artifact signing infrastructure and integrate signing into all pipeline stages.
* Enforce commit signature verification on all branches feeding into CI/CD pipelines.
* Implement hash verification for all third-party resources fetched during pipeline execution.
* Deploy configuration drift detection tooling for all production environments.
* Establish a policy requiring all artifacts to be signed before entering subsequent pipeline
  stages.
* Implement container image signing and enforce verification before deployment.
* Generate and maintain SBOMs for all artifacts produced by CI/CD pipelines.
* Audit and remediate all existing pipeline stages that currently lack integrity validation.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
