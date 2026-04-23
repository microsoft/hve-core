---
title: 'D07: Resource Protection'
description: OWASP Docker Top 6 reference for resource protection vulnerabilities including missing resource limits and container resource exhaustion
---

# 06 Resource Protection

Identifier: D07
Category: Resource Management

## Description

By default, containers may have no restrictions on CPU, memory, network, or disk I/O consumption.
A container that exhausts physical resources — whether through a software defect, misconfiguration,
or deliberate attack — affects the underlying host and all other containers sharing that host.
The Linux kernel's OOM (Out of Memory) killer activates when the host is short of memory and
terminates processes to recover; the killed processes are not necessarily the ones responsible for
excessive consumption.
Even containers that are otherwise well-isolated still share physical resources with sibling
containers and the host.

## Risk

* A single container exhausting CPU or memory causes degraded performance or outages for all
  containers on the same host.
* The OOM killer may terminate critical processes in unrelated containers or on the host itself.
* Denial of service against the host operating system when a container consumes all available
  memory or CPU.
* Disk I/O saturation by one container blocks storage operations for others.
* Network bandwidth exhaustion by one container starves network access for sibling containers.

## Vulnerability checklist

* Containers are deployed without memory limits (`--memory` and `--memory-swap` not set).
* Containers are deployed without CPU limits.
* No memory reservation (`--memory-reservation`) is configured for soft limits.
* The OOM killer is not managed for critical containers (`--oom-kill-disable` not evaluated).
* Host RAM is oversubscribed without resource limits on individual containers.
* No monitoring is in place to detect resource exhaustion trends.

## Prevention controls

1. Set hard memory limits on every container using `--memory` and `--memory-swap`.
2. Configure soft memory limits with `--memory-reservation` for graceful resource management.
3. Set CPU limits on every container to prevent individual containers from monopolizing CPU.
4. Evaluate use of `--oom-kill-disable` for containers running critical processes; note that the
   container daemon itself has a lower OOM score and is normally not killed.
5. Avoid oversubscribing host RAM; ensure the sum of container memory limits does not exceed
   available physical memory.
6. Monitor resource consumption of all containers and the host to detect saturation trends.

## Example attack scenarios

### Scenario A — Memory exhaustion denial of service

An attacker exploits a vulnerability in a containerized application to trigger unbounded memory
allocation.
The container has no memory limits configured.
The container consumes all available host memory, triggering the OOM killer.
The OOM killer terminates processes in a different production container, causing a service outage
for an unrelated application.

### Scenario B — CPU starvation

A container running a computationally intensive workload has no CPU limits.
The workload consumes all available CPU cycles on the host.
Other containers on the same host experience severe performance degradation, and time-sensitive
operations fail due to CPU starvation.

## Detection guidance

* Check configured resource limits: `docker inspect <containerID>`.
* Monitor live resource consumption: `docker stats`.
* Inspect memory cgroup details: `/sys/fs/cgroup/memory/docker/$CONTAINERID/*`.
* Review host-level resource utilization for signs of oversubscription.
* Alert on containers approaching their configured limits or on OOM events in kernel logs.

## Remediation

* Apply memory and CPU limits to all running containers.
* Update deployment configurations and orchestration templates to include resource limits by
  default.
* Review and adjust limits based on observed resource consumption patterns.
* Configure monitoring and alerting for resource exhaustion and OOM events.
* Validate that the aggregate of all container resource limits does not oversubscribe the host.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
