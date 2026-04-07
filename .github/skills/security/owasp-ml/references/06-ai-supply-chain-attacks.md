---
title: 'ML06: AI Supply Chain Attacks'
description: OWASP ML Top 10 reference for AI supply chain vulnerabilities including compromised packages, MLOps infrastructure, and malicious model hub artifacts
---

# 06 AI Supply Chain Attacks

Identifier: ML06:2023
Category: Supply Chain

## Description

In AI Supply Chain Attacks, threat actors target the supply chain of machine learning models. This
category is broad and important as the software supply chain in machine learning includes even
more elements than in classic software. It consists of specific elements such as MLOps platforms,
data management platforms, model management software, model hubs, and other specialized types of
software that enable ML engineers to effectively test and deploy models. Attackers may modify
open-source packages, exploit vulnerabilities in MLOps infrastructure, or deploy malicious models
through public model hubs.

## Risk

* Compromise of the machine learning infrastructure and potential harm to the organization.
* Malicious code introduced through compromised packages can go undetected for extended periods.
* Attackers can steal sensitive information, modify results, or lead the model to return erroneous
  predictions.
* Publicly exposed MLOps web interfaces allow unauthorized access to models and data.
* Impersonation of organization accounts on model hubs enables distribution of malicious models.

## Vulnerability checklist

* Package integrity is not verified through digital signatures before installation.
* Package versions are outdated and not monitored for updates or known vulnerabilities.
* Packages are installed from untrusted or unvetted third-party sources.
* MLOps infrastructure is not deployed following vendor security recommendations.
* Web UIs for MLOps platforms are exposed to the Internet without authentication.
* Cloud provider security features such as VPCs, security groups, and IAM roles are not
  leveraged.
* Access to MLOps platforms is not restricted to authorized personnel.
* Network traffic in the infrastructure is not monitored for anomalies.
* Models from public model hubs are not verified for authenticity before deployment.

## Prevention controls

1. Verify package integrity before use by checking digital signatures of all packages.
2. Constantly monitor and update package versions using tools such as OWASP Dependency Check.
3. Install packages only from secure third-party repositories such as Anaconda or pip that
   enforce strict security measures and have a vetting process for packages.
4. Deploy ML infrastructure securely following vendor deployment recommendations, limit web UI
   access from the Internet, and monitor infrastructure traffic for anomalies.
5. Leverage cloud provider security features such as VPCs, security groups, and IAM roles to
   restrict and control access.
6. Implement strict access control measures ensuring only authorized personnel have access to
   MLOps platforms.
7. Verify the authenticity of models downloaded from public model hubs before deploying them.
8. Audit organizational accounts on model hubs for impersonation or unauthorized access.

## Example attack scenarios

### Scenario A — Attack on a machine learning project dependency

An attacker who wants to compromise a machine learning project knows that the project relies on
several open-source packages and libraries. The attacker modifies the code of one of the packages
that the project depends on, such as NumPy or Scikit-learn. The modified version is uploaded to a
public repository such as PyPI, making it available for download. When the victim organization
downloads and installs the package, the malicious code is installed and can be used to compromise
the project. The attack can go unnoticed for a long time since the victim may not realize the
package has been compromised.

### Scenario B — Attack on a MLOps software platform

An organization builds a MLOps pipeline using multiple instances of supporting software. One of
the applications, an inference platform, is exposed publicly to the Internet. An attacker finds
the web interface available without authentication and gains access to models that were not meant
to be exposed publicly.

### Scenario C — Attack on a ML model hub

An organization decides to use a model from a public model hub. An attacker finds a way to
impersonate the organization's account in the model hub and deploys a malicious model. Organization
employees then download the malicious model and the malicious code runs in the organization's
environment.

## Detection guidance

* Run dependency scanning tools regularly to detect known vulnerabilities in packages.
* Monitor package repositories for unexpected version changes or newly published packages under
  known names.
* Audit MLOps platform access logs for unauthorized access or configuration changes.
* Scan network traffic for anomalous connections to or from MLOps infrastructure.
* Verify the provenance and digital signatures of models downloaded from public hubs.
* Monitor organizational accounts on model hubs for unauthorized modifications.

## Remediation

* Update all dependencies to patched versions and remove compromised packages.
* Verify digital signatures of all packages and models before installation or deployment.
* Restrict MLOps platform web interfaces to authenticated access behind VPN or private networks.
* Enable and enforce IAM roles, VPCs, and security groups for all cloud-deployed ML
  infrastructure.
* Audit and rotate credentials for organizational accounts on model hubs.
* Implement continuous dependency monitoring and automated alerts for vulnerable packages.
* Isolate ML infrastructure from public networks and enforce network segmentation.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
