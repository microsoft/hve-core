---
title: 'D02: Patch Management Strategy'
description: OWASP Docker Top 6 reference for patch management vulnerabilities including outdated base images and unpatched container components
---

# 02 Patch Management Strategy

Identifier: D02
Category: Patch Management

## Description

Failure to patch container infrastructure in a timely fashion remains one of the most frequent
security problems.
Container environments introduce four distinct patch domains: container images, container runtime
software (Docker), orchestration software (Kubernetes, Mesos, OpenShift), and the host operating
system.
Each domain requires an independent patching strategy covering regular and emergency patch cycles.
Unpatched components expose the environment to known vulnerabilities that scanning tools and public
exploit databases can discover and weaponize.

## Risk

* Full host compromise through unpatched kernel vulnerabilities exploited from within a container.
* Compromise of the orchestration tool grants control over all containers on all managed hosts.
* Known vulnerabilities accumulate over time with increasing severity as more exploits become
  publicly available.
* End-of-life software components receive no security updates, leaving no remediation path.
* Weak default configurations in orchestration tools (e.g., etcd, kubelet APIs) compound the
  risk when left unpatched.

## Vulnerability checklist

* No documented patch management strategy exists for all four domains (images, container runtime,
  orchestration, host OS).
* Regular patch cycles are not defined or not automated.
* Emergency patch procedures for critical vulnerabilities are absent.
* Software components have reached or are approaching end-of-life without a migration plan.
* Patches are applied but services are not restarted, leaving the old vulnerable code in memory.
* Vendor security advisory feeds are not monitored for deployed components.

## Prevention controls

1. Define and document a patch management strategy for each of the four domains: images, container
   runtime, orchestration software, and host operating system.
2. Set a regular patch cycle cadence for each domain; automate where possible.
3. Define emergency patch procedures for critical vulnerabilities with a target application window
   of days rather than weeks.
4. Track end-of-life dates for all components and maintain migration plans for each.
5. Ensure patches that require service restarts, new deployments, or host reboots are followed
   through to completion.
6. Plan for redundancy so that patching and reboots do not cause service outages.
7. Subscribe to vendor security advisory feeds and security mailing lists for all deployed
   components.
8. Deploy freshly built container images rather than patching running containers in place.

## Example attack scenarios

### Scenario A — Unpatched host kernel

A container environment runs on a host with an outdated Linux kernel.
A kernel vulnerability similar to Dirty COW (CVE-2016-5195) allows a container process to exploit
a syscall flaw and escalate to root on the host.
The attacker gains control of the host and all containers running on it.

### Scenario B — Exposed orchestration interface

An orchestration tool runs with weak default credentials on its etcd data store.
The interface is reachable from the container network because no patch or configuration update has
been applied.
An attacker who compromised a single container discovers the interface, accesses the etcd store,
and gains control over the entire cluster.

### Scenario C — Stale container image

A company does not rebuild container images regularly.
An image running in production contains a library with a known remote code execution vulnerability
published months ago.
Internet-facing scanning bots fingerprint the service version and exploit the flaw to gain a
foothold inside the container.

## Detection guidance

* Check host uptime and last patch dates: `uptime`, `rpm --qa --last`, or
  `tail -f /var/log/dpkg.log`.
* List pending patches: RHEL/CentOS `yum check-update`, Debian/Ubuntu `apt-get upgrade --dry-run`.
* Compare running kernel (`uname -a`) against installed kernels (`ls -lrt /boot/vmlinu*`).
* Inspect runtime of critical processes: `dockerd`, `containerd`, and `kube*` via `top`.
* Use authenticated vulnerability scanners (e.g., OpenVAS) against hosts and container images.
* Monitor container image build dates and compare against current base image releases.

## Remediation

* Apply all pending patches to host operating systems and restart affected services.
* Rebuild and redeploy container images from updated base images.
* Update container runtime and orchestration software to the latest supported versions.
* Establish automated patch scanning and notification for all four domains.
* Decommission or isolate components that have reached end-of-life.
* Validate that patches are effective by confirming new binary versions are running.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
