# 03 Software Supply Chain Failures

Identifier: A03:2025
Category: Supply Chain

## Description

Software supply chain failures are breakdowns or compromises in the process of building,
distributing, or updating software.
They are caused by vulnerabilities or malicious changes in third-party code, tools, or other
dependencies that the system relies on.
The risk scope includes direct dependencies, transitive dependencies, build tools, CI/CD
pipelines, IDE extensions, artifact repositories, container registries, and any other component in
the software delivery chain.
This vulnerability ranked number one in the OWASP Top 10 community survey, reflecting the
growing severity and frequency of supply chain attacks.

## Risk

* Full system compromise through a compromised trusted vendor distributing malicious updates.
* Remote code execution through vulnerable third-party libraries or frameworks included in the
  application.
* Data exfiltration through malicious packages that harvest credentials, tokens, or sensitive
  data from developer environments.
* Self-propagating attacks through supply chain worms that use compromised tokens to push
  malicious versions of accessible packages.
* Widespread organizational exposure when CI/CD pipelines have weaker security than the systems
  they build and deploy.
* Loss of patching capability when components reach end of life without a migration plan.

## Vulnerability checklist

* The versions of all components (direct and transitive dependencies) are not tracked.
* Software components are vulnerable, unsupported, or out of date, including the OS, web server,
  DBMS, APIs, runtime environments, and libraries.
* Regular vulnerability scanning and security bulletin subscriptions are not in place for
  deployed components.
* No change management process tracks modifications to CI/CD settings, code repositories,
  developer IDEs, artifact repositories, or third-party integrations.
* Supply chain systems lack hardened access controls and least privilege enforcement.
* No separation of duty exists; a single person can write code and promote it to production
  without oversight.
* Components from untrusted sources are used in or can impact production environments.
* Patching is deferred on a monthly or quarterly schedule, leaving extended exposure windows.
* Library compatibility is not tested after updates or upgrades.
* The CI/CD pipeline is complex and has weaker security than the systems it deploys.

## Prevention controls

1. Generate and centrally manage a Software Bill of Materials (SBOM) for the entire software
   stack, including transitive dependencies.
2. Continuously inventory and monitor component versions using tools such as OWASP Dependency
   Track, OWASP Dependency Check, or retire.js.
3. Monitor CVE, NVD, and OSV databases for vulnerabilities in deployed components, and subscribe
   to vendor security advisories.
4. Obtain components only from official trusted sources over secure links and prefer signed
   packages.
5. Deliberately choose dependency versions and upgrade only when there is a documented need.
6. Remove unused dependencies, unnecessary features, components, files, and documentation to
   reduce attack surface.
7. Monitor for unmaintained libraries and plan migration to alternatives when patching is not
   possible.
8. Update CI/CD, IDE, and all developer tooling regularly.
9. Use staged rollouts or canary deployments to limit exposure from compromised vendor updates.
10. Harden code repositories, developer workstations, build servers, artifact repositories, and
    infrastructure-as-code with MFA, access control, signed builds, and tamper-evident logs.
11. Implement separation of duties so that no single person can promote code to production
    without review.

## Example attack scenarios

### Scenario A — Compromised trusted vendor

A trusted software vendor is compromised with malware.
Organizations that upgrade to the compromised version have their systems backdoored.
The 2019 SolarWinds attack compromised approximately 18,000 organizations through this vector.

### Scenario B — Self-propagating package worm

An attacker seeds malicious versions of popular npm packages that execute post-install scripts to
harvest and exfiltrate sensitive data.
The malware detects npm tokens in victim environments and uses them to push malicious versions of
any accessible package.
The worm reaches over 500 package versions before disruption.

### Scenario C — Vulnerable third-party library

An application includes a third-party library with a known remote code execution vulnerability.
The vulnerability has been publicly disclosed for months but the application has not been updated.
Attackers fingerprint the service version and exploit the flaw to gain a foothold.

## Detection guidance

* Continuously scan all dependencies for known vulnerabilities using software composition
  analysis tools.
* Monitor SBOM outputs for newly disclosed vulnerabilities affecting deployed components.
* Track component build dates and compare against current upstream releases.
* Audit CI/CD pipeline configurations and access logs for unauthorized changes.
* Verify that all deployed artifacts are signed and that signatures are validated before
  deployment.
* Review developer workstations and build environments for unauthorized IDE extensions or tools.

## Remediation

* Update all vulnerable dependencies to patched versions immediately.
* Rebuild and redeploy applications from updated base images and libraries.
* Decommission or isolate components that have reached end of life.
* Harden CI/CD pipelines with access controls, signed builds, and separation of duties.
* Establish automated patch scanning and notification for all dependency domains.
* Validate that deployed artifacts match expected signed versions.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
