---
title: 'D03: Network Segmentation and Firewalling'
description: OWASP Docker Top 6 reference for network segmentation vulnerabilities including unrestricted container communication and missing egress controls
---

# 03 Network Segmentation and Firewalling

Identifier: D03
Category: Network Security

## Description

Container environments frequently lack the network segmentation that traditional DMZ architectures
enforce.
Without explicit configuration the container network may be flat, allowing any microservice to
communicate with all other microservices and with the management backplane of the orchestration
tool.
Internet-exposed management interfaces of orchestration tools represent an especially severe risk,
as gaining access to them grants control over the entire container environment.
The microservice-per-container paradigm increases the number of network endpoints that must be
controlled.

## Risk

* Full environment compromise through internet-exposed orchestration management interfaces.
* Lateral movement from a compromised frontend container to backend services, databases, and
  management APIs.
* Access to host services (NFS, Samba, CI/CD, databases) from within a compromised container.
* Cross-tenant network access in multi-tenant environments sharing the same network.
* Exploitation of unnecessarily exposed microservice ports within the LAN or DMZ.

## Vulnerability checklist

* Orchestration management interfaces (dashboards, etcd, kubelet API) are reachable from the
  internet.
* Orchestration management interfaces are exposed in the DMZ without strict access controls.
* Containers can reach host services that they do not need.
* Microservices that do not need to communicate share the same network segment.
* Classical services (NFS, Samba, CI/CD tools, databases) are unnecessarily exposed in the
  container network.
* Multiple tenants share the same container network without isolation.
* No ingress or egress network policies are defined for the container environment.

## Prevention controls

1. Never expose orchestration management interfaces (dashboards, etcd, API servers) to the
   internet; if remote access is required restrict it to a whitelist of trusted source IPs.
2. Place management interfaces on a dedicated management network with strict whitelist-based
   access controls.
3. Choose the appropriate network driver for the environment.
4. Segment the DMZ so that frontend, middleware, and backend services reside in separate network
   segments.
5. Ensure multiple tenants use separate networks with no cross-tenant connectivity.
6. Define explicit ingress network and routing policies for all container traffic.
7. Define egress network policies to restrict outbound internet access from containers.
8. Allow only whitelisted inter-container communication; deny all other traffic by default.
9. Protect host services with the same network-level controls applied to orchestration interfaces.

## Example attack scenarios

### Scenario A — Internet-exposed dashboard

An orchestration dashboard is reachable from the public internet without authentication.
An attacker discovers the dashboard through internet scanning, gains access, and deploys
cryptocurrency mining containers across the entire cluster.

### Scenario B — Flat container network

A company runs frontend and backend containers on the same flat network without segmentation.
An attacker exploits a vulnerability in the internet-facing frontend container.
From the compromised container the attacker scans the network and discovers the etcd interface
and an internal database, both reachable without further authentication.
The attacker reads secrets from etcd and exfiltrates data from the database.

### Scenario C — Cross-tenant access

A Container-as-a-Service provider hosts multiple clients on shared infrastructure without network
isolation.
One client deploys a container with a remote code execution vulnerability.
The attacker exploits the flaw and, because all tenants share the same network, probes and accesses
containers belonging to other clients.

## Detection guidance

* Scan the environment from a random external IP to verify no management interfaces are
  internet-reachable.
* From within a container, probe for orchestration management interfaces and host services using
  `netcat` or `nmap`.
* List host network interfaces and routing tables: `ip a`, `ip ro`.
* Enumerate container networks: `docker network ls` and `docker inspect <network_id>`.
* Scan container IPs from the host:
  `nmap -sTV -p1-65535 $(docker inspect $(docker ps -q) --format '{{.NetworkSettings.IPAddress}}')`.
* Repeat scans from within containers to validate that inter-container traffic is restricted.

## Remediation

* Remove internet exposure of all orchestration management interfaces immediately.
* Implement network segmentation between frontend, middleware, backend, and management networks.
* Apply whitelist-based network policies for inter-container communication.
* Isolate tenant networks in multi-tenant environments.
* Define and enforce ingress and egress network policies.
* Schedule recurring external and internal network scans to detect configuration drift.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
