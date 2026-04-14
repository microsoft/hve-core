---
title: 'CICD-SEC-3: Dependency Chain Abuse'
description: OWASP CI/CD Top 10 reference for dependency chain abuse vulnerabilities including dependency confusion and typosquatting attacks
---

# 03 Dependency Chain Abuse

Identifier: CICD-SEC-3:2025
Category: Supply Chain

## Description

Dependency chain abuse risks refer to an attacker's ability to abuse flaws relating to how
engineering workstations and build environments fetch code dependencies. Dependency chain abuse
results in a malicious package inadvertently being fetched and executed locally when pulled.

Managing dependencies and external packages is increasingly complex given the total number of
systems involved across all development contexts. Packages are fetched using dedicated clients
per programming language, typically from a combination of self-managed package repositories and
language-specific SaaS repositories. Inadequate configurations may cause an engineer or the build
system to download a malicious package instead of the intended one, and in many cases the package
is immediately executed after download due to pre-install scripts.

The main attack vectors are dependency confusion (publishing malicious packages in public
repositories with the same name as internal packages), dependency hijacking (compromising a
package maintainer's account to upload malicious versions), typosquatting (publishing packages
with names similar to popular packages), and brandjacking (publishing packages that mimic a
trusted brand's naming conventions).

## Risk

* Malicious code executes on developer workstations or build servers when a poisoned package is
  pulled.
* Credential theft and lateral movement within the environment where the malicious code executes.
* Malicious code can make its way to production from the build server, potentially maintaining
  the original safe functionality to reduce probability of discovery.
* Internal package names leaked to public repositories enable dependency confusion attacks.
* Build environments fetching packages directly from the internet without proxy controls are
  exposed to all dependency chain attack vectors.

## Vulnerability checklist

* Clients fetch packages directly from external repositories without routing through an internal
  proxy.
* Internal package names are not registered under the organization's scope.
* No checksum or signature verification is configured for pulled packages.
* Clients are configured to pull the latest version of a package rather than a pinned version.
* Package manager configuration files (such as .npmrc) are absent from project repositories.
* Pre-install scripts execute in a context with access to secrets and sensitive resources.
* Names of internal projects are published or discoverable in public repositories.
* No controls exist to prevent dependency confusion between internal and external registries.

## Prevention controls

1. Route all package fetches through an internal proxy rather than directly from the internet.
2. Where applicable, configure all clients to pull packages only from internal repositories
   containing pre-vetted packages, and enforce this client configuration.
3. Enable checksum verification and signature verification for all pulled packages.
4. Pin package versions to pre-vetted versions or ranges and use framework-specific lock files.
5. Register all private packages under the organization's scope.
6. Ensure all code referencing a private package uses the package's scope.
7. Force clients to fetch scoped packages solely from the internal registry.
8. Run pre-install scripts in a separate context without access to secrets or other sensitive
   resources.
9. Include package manager configuration files in every project repository to override insecure
   default client configurations.
10. Avoid publishing names of internal projects in public repositories.

## Example attack scenarios

### Scenario A — Dependency confusion

An attacker discovers the name of an internal NPM package used by the organization by finding
references in a public repository. The attacker publishes a package with the same name on the
public NPM registry with a higher version number. The build system, configured to check both
internal and public registries, pulls the higher-versioned malicious package. The pre-install
script executes, exfiltrating environment variables containing cloud credentials.

### Scenario B — Dependency hijacking

An attacker compromises the account of a maintainer of a widely-used Python package on PyPI.
They upload a new version containing a backdoor that executes during installation. Organizations
configured to pull the latest version of the package automatically fetch and execute the
compromised version on their build servers, granting the attacker access to build secrets and
deployment credentials.

## Detection guidance

* Monitor package manager audit logs for unexpected package sources or version changes.
* Compare checksums of fetched packages against known-good values.
* Alert on packages pulled from public registries that share names with internal packages.
* Audit package manager client configurations across build environments and developer
  workstations.
* Scan dependency lock files for unexpected version changes or new dependencies.
* Monitor outbound network connections from build nodes during dependency installation.

## Remediation

* Configure internal proxies as the sole package source for all build environments and developer
  workstations.
* Register all internal package names under the organization's scope on relevant public
  registries to prevent namespace squatting.
* Pin all dependency versions and enforce lock file usage.
* Enable checksum and signature verification across all package manager configurations.
* Isolate pre-install script execution from secrets and sensitive build resources.
* Remove any references to internal package names from public repositories.
* Harden all build environments according to the guidelines under CICD-SEC-7.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
