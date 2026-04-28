---
title: 'D04: Secure Defaults and Hardening'
description: OWASP Docker Top 6 reference for secure defaults and hardening vulnerabilities including disabled security profiles and excessive capabilities
---

# 04 Secure Defaults and Hardening

Identifier: D04
Category: Configuration Management

## Description

Container environments expose services across three domains: the orchestration tool (dashboards,
etcd, APIs), the host (RPC services, OpenSSHD, avahi, systemd network services), and the
containers themselves (microservice endpoints and distribution-bundled tools).
Default configurations frequently leave unnecessary services running or insufficiently protected.
Network-based mitigations (see D03) address the symptom rather than the root cause; disabling or
hardening an unneeded service eliminates the attack surface entirely.
Linux kernel syscalls accessible from within containers present an additional vector; a defective
syscall can escalate privileges from a container user to root on the host.

## Risk

* Compromise of the orchestration tool through unprotected management interfaces with weak or no
  authentication.
* Host compromise through unnecessary or misconfigured services exposed in the container network.
* Privilege escalation from within a container through unrestricted Linux capabilities or syscalls.
* Expanded attack surface from unnecessary packages and binaries inside container images.
* Loss of defense-in-depth when AppArmor or SELinux protections are disabled to resolve
  configuration conflicts.

## Vulnerability checklist

* Orchestration management interfaces run with default credentials or without authentication.
* The host runs non-essential services (desktop applications, compilers, unneeded daemons).
* The host OS is a general-purpose distribution rather than a container-optimized minimal build.
* Container images include unnecessary packages, compilers, or debugging tools.
* Docker capabilities are not restricted beyond the default set of 14.
* Seccomp profiles are set to `unconfined` or AppArmor is set to `apparmor=unconfined`.
* SUID/SGID binaries remain in container images without mitigation.
* AppArmor or SELinux has been disabled on the host to resolve operational issues.
* The host OS has reached or is approaching end of support lifetime.

## Prevention controls

1. Select a minimal, container-optimized host distribution; avoid general-purpose desktop or
   server distributions.
2. Install only the packages required for container hosting on the host OS.
3. Verify the support lifetime of the host OS and plan for migration before end of life.
4. Audit all network-listening services on the host; disable those that are not required.
5. For services that must run, bind them to localhost or a restricted interface where possible
   and enable authentication.
6. Review orchestration tool documentation for security-relevant configuration and apply
   authentication to all management interfaces.
7. Use minimal or distroless base images for containers to reduce available binaries an attacker
   could leverage.
8. Drop unnecessary Linux capabilities with `--cap-drop`; never use `--cap-add=all`.
9. Apply seccomp profiles (`--security-opt seccomp=<profile>.json`) to restrict syscalls beyond
   the default 44 disabled; never use `unconfined`.
10. Disable SUID/SGID bits with `--security-opt no-new-privileges`.
11. Never disable AppArmor or SELinux; diagnose and relax specific rules instead.

## Example attack scenarios

### Scenario A — Unprotected orchestration API

An orchestration tool exposes its kubelet API without authentication by default.
An attacker who gained access to the container network discovers the API, executes commands on
nodes, and backdoors the cluster.

### Scenario B — Bloated container image

A container image is built from a full Ubuntu base and includes `wget`, `curl`, `gcc`, and
`netcat`.
An attacker exploits an application vulnerability and breaks out into the container.
Using the available tools the attacker downloads additional exploit payloads and establishes a
reverse shell to an external command-and-control server.

### Scenario C — Unrestricted capabilities

A container runs with the default set of 14 capabilities, including `NET_RAW`.
An attacker exploits a vulnerability in the containerized service and uses `NET_RAW` to craft
raw network packets, perform ARP spoofing on the container network, and intercept traffic between
other containers.

## Detection guidance

* Scan the host network for exposed services: `netstat -tulpn | grep -v ESTABLISHED` or
  `lsof -i -Pn | grep -v ESTABLISHED`.
* Scan the container network from within a container using `nmap` to discover reachable services.
* List capabilities of running containers with `pscap` on the host.
* Inspect container security options: `docker inspect <containerID>` to check seccomp and
  AppArmor profiles.
* Verify host firewall rules: `iptables -t nat -L -nv` and `iptables -L -nv`.
* Audit container images for unnecessary packages and SUID/SGID binaries.

## Remediation

* Enable authentication on all orchestration management interfaces.
* Remove unnecessary packages from host systems and container images.
* Rebuild container images from minimal or distroless base images.
* Drop all unnecessary capabilities and apply restrictive seccomp profiles.
* Enable `--security-opt no-new-privileges` on all production containers.
* Re-enable AppArmor or SELinux if previously disabled and address specific rule conflicts.
* Decommission or replace host operating systems approaching end of support.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
