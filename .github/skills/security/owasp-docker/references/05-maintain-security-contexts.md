---
title: 'D05: Maintain Security Contexts'
description: OWASP Docker Top 6 reference for security context vulnerabilities including mixed trust-level containers and insufficient isolation boundaries
---

# 05 Maintain Security Contexts

Identifier: D05
Category: Isolation

## Description

Mixing containers with different security statuses or contexts on the same host undermines
isolation.
A single host may run production containers alongside test or development containers, containers
with different information security classifications (frontend vs. backend), or containers from
separate tenants in a Container-as-a-Service environment.
If a lower-security container is compromised, the attacker may pivot to higher-security containers
on the same host through shared resources, kernel vulnerabilities, or access to the orchestration
management plane.
The desire to maximize hardware utilization often drives organizations to co-locate containers
that should be separated.

## Risk

* Compromise of a development or test container leads to lateral movement into production
  containers on the same host.
* A single tenant's vulnerability in a multi-tenant environment endangers the availability,
  confidentiality, and integrity of all tenants.
* Kernel-level exploits (e.g., Dirty COW) from one container grant root access to the host and
  all sibling containers.
* Insecure orchestration interfaces reachable from any container on the host expose the
  management plane.
* Mixing security classifications (databases, middleware, authentication services, frontend)
  on one host increases blast radius.

## Vulnerability checklist

* Production and non-production (test, development, staging) containers share the same host.
* Containers handling data of different sensitivity classifications run on the same host.
* Multi-tenant containers share the same physical or virtual host without VM-level separation.
* No formal policy defines which container types may be co-located.
* The orchestration control plane components run on the same host as application containers.
* Hardware utilization concerns override security separation requirements.

## Prevention controls

1. Deploy production containers on dedicated hosts and enforce strict controls on who may deploy
   to those hosts; no non-production containers allowed.
2. Separate containers by information security classification: databases, middleware,
   authentication services, frontend, and orchestration control plane components on different
   hosts.
3. Use virtual machines to separate security contexts when physical hardware is limited;
   this is the minimum requirement for running different tenants on shared hardware.
4. Never mix multi-tenant workloads on the same host without VM-level isolation.
5. Define and enforce a formal policy that specifies which container types and security contexts
   may coexist on a given host.
6. Review system architecture regularly to validate that host assignments reflect current security
   context requirements.

## Example attack scenarios

### Scenario A — Test container compromises production

A company runs test and production containers on the same host due to limited hardware.
A developer deploys a test container with a remote code execution vulnerability.
Scanning bots discover and exploit the vulnerability, granting the attacker access to the
container.
The attacker exploits a kernel vulnerability to escape the container and gains root access to the
host, compromising all production containers.

### Scenario B — Multi-tenant CaaS breach

A Container-as-a-Service provider runs all clients on shared hosts without VM-level separation.
One client deploys a container with a vulnerability that an attacker exploits.
The attacker reaches the orchestration management interface from the compromised container and
gains access to the entire environment, affecting all clients' containers.

## Detection guidance

* Request and review the system architecture to understand which containers share hosts.
* Log in to bare metal hosts and check for virtualization processes (`qemu-system-x86_64`,
  `virsh list --all`) to confirm whether VMs provide isolation.
* If only Docker processes run on the host without VM separation, verify that all containers
  share the same security context.
* Inspect container labels and metadata to identify which environment (production, test,
  development) each container belongs to.
* Verify that the separation of systems reflects their security context requirements.

## Remediation

* Relocate production containers to dedicated hosts with no non-production workloads.
* Introduce VM-level isolation for multi-tenant and mixed-environment hosts.
* Separate containers by security classification onto distinct hosts or VM boundaries.
* Document and enforce a host assignment policy based on security context.
* Audit host assignments on a recurring schedule to detect drift.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
