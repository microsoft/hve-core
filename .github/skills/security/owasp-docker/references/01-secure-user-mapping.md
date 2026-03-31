---
title: 'DKR01: Secure User Mapping'
description: OWASP Docker Top 6 reference for secure user mapping vulnerabilities including root container execution and privilege escalation
---

# 01 Secure User Mapping

Identifier: DKR01:2025
Category: Privilege Management

## Description

Insecure user mapping occurs when container microservices run under the root user inside the
container.
If the service contains a weakness the attacker gains full privileges within the container.
While default protections such as Linux capabilities, AppArmor, or SELinux profiles remain, running
as root removes one layer of defense.
This broadens the attack surface and violates the principle of least privilege.
Privileged containers started with the `--privileged` flag are especially dangerous, as a breakout
from the microservice into the container is nearly equivalent to running without any container
isolation.

## Risk

* Full root-level access within the container upon exploitation of any service vulnerability.
* Privileged containers grant access to all Linux capabilities, host devices under `/dev`, and the
  `/sys` and `/proc` filesystems.
* Kernel module loading on the host becomes possible from a privileged container.
* Lateral movement to the host or other containers is significantly easier from a root context.
* Violation of least privilege principle increases blast radius of any compromise.

## Vulnerability checklist

* Container processes run as `root` (UID 0) rather than a dedicated non-root user.
* Dockerfiles lack a `USER` directive before the service entrypoint.
* The `--privileged` flag is used when starting containers.
* No Linux user namespace remapping is configured on the Docker daemon.
* SUID/SGID binaries exist in the container image and are not neutralized.
* Pod security policies or equivalent controls do not enforce non-root execution.

## Prevention controls

1. Never use the `--privileged` flag; containers are unprivileged by default.
2. Add a dedicated user and group in the Dockerfile with `RUN useradd <username>` or
   `RUN adduser <username>`.
3. Switch to the non-root user before the entrypoint with the `USER <username>` directive.
4. Bind services to ports above 1024 and map them externally with the `EXPOSE` command.
5. Use `setcap` to grant specific capabilities to binaries that require elevated access rather
   than full root privileges.
6. Enable Linux user namespaces via the Docker daemon `--userns-remap` option to remap container
   root to an unprivileged host user.
7. Disable SUID/SGID bits with `--security-opt no-new-privileges` or drop capabilities with
   `--cap-drop=setuid --cap-drop=setgid`.
8. Enforce non-root execution through pod security policies in orchestrated environments.

## Example attack scenarios

### Scenario A — Root-running microservice

A web application container runs its service as root.
An attacker exploits a remote code execution vulnerability in the application layer.
Because the process runs as root inside the container, the attacker gains full access to the
container filesystem.
The attacker discovers the container has additional capabilities and pivots to probe the host
network and adjacent containers.

### Scenario B — Privileged container breakout

A development team deploys a container with `--privileged` for convenience during debugging.
The flag persists into the production deployment.
An attacker exploits a vulnerability in the containerized service, loads a kernel module on the
host through the container, and achieves full root access to the host machine and all sibling
containers.

## Detection guidance

* Inspect running containers for root execution: `docker top <containerID>` or
  `docker inspect $(docker ps -q) --format='{{.Config.User}}'`.
* Review process ownership on the host with `ps auxwf`.
* Check for user namespace configuration in `/etc/subuid`, `/etc/subgid`, and whether the Docker
  daemon was started with `--userns-remap`.
* Audit Dockerfiles for the presence of the `USER` directive.
* Scan for the `--privileged` flag in deployment configurations.

## Remediation

* Add a non-root user to all container images and set the `USER` directive in the Dockerfile.
* Remove the `--privileged` flag from all production container run configurations.
* Enable user namespace remapping on the Docker daemon.
* Audit and remove unnecessary SUID/SGID binaries from container images.
* Reconfigure services to bind to unprivileged ports (above 1024).
* Validate remediation by inspecting the runtime user of all deployed containers.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
