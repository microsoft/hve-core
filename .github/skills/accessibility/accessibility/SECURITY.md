---
title: Accessibility Skill Security Model
description: STRIDE threat model for the accessibility skill scanners, runtime browser harness, generated evidence, and design-intent verification boundary
author: microsoft/hve-core
ms.date: 2026-08-31
ms.topic: reference
estimated_reading_time: 18
keywords:
  - security
  - STRIDE
  - accessibility
  - SSRF
  - browser automation
  - threat model
---
<!-- markdownlint-disable-file -->
# Accessibility Skill Security Model

This model covers the Path A axe CLI wrapper (`scripts/scan.py`), the Path B Playwright runtime (`scripts/runtime_a11y/` and its Node runner), generated evidence, and offline design-intent verification. The trust buckets are Path A targets (B1), Path A toolchain supply chain (B2), target-derived output (B3), caller and filesystem authority (B4), design-intent verification (B5), Path B configuration and navigation (B6), Playwright and endpoint-managed Chrome (B7), and Path B evidence and child environment (B8). Each bucket enumerates all six STRIDE categories with the implemented mitigations and residual risks.

> **See also: repo-wide STRIDE model.** This skill participates in the repository-wide threat model at [`docs/security/security-model.md`](../../../../docs/security/security-model.md) and is registered in its [Skill Security Models](../../../../docs/security/security-model.md#skill-security-models) section.

## Executive Summary

The accessibility skill has two browser-backed scanning paths. Path A accepts explicitly authorized HTTP(S) targets or operator-selected local files and invokes the version-pinned axe CLI without a shell. Path B validates project configuration, authorizes its HTTP(S) base target, runs same-origin probes through Playwright's system Chrome channel, and writes bounded evidence beneath controlled run roots.

The skill controls initial destinations, configured routes and triggers, one direct-request redirect chain, machine identifiers, launch arguments, and evidence paths. It does not claim complete Chromium egress control or DNS-rebinding resistance. Endpoint application control owns system Chrome identity and patch posture, while browser-derived requests, inherited child environments, upstream parsers, and Path A remote redirects remain explicit residual risks.

### Security Posture Overview

| Dimension          | Value                                                                                                                                                   |
|--------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| Runtime surface    | Python CLI and configuration guard; Node/Playwright runners; system Chrome; axe CLI; local evidence writers; offline design-intent adapter              |
| Trust buckets      | B1 Path A targets, B2 Path A supply chain, B3 output, B4 caller/filesystem, B5 design intent, B6 Path B navigation, B7 browser, B8 evidence/environment |
| Credentials        | No first-party credential store; child processes inherit the caller environment (G-INF-3)                                                               |
| Network egress     | Authorized Path A HTTP(S), npm on Path A cache miss, Path B HTTP(S) browser/direct requests, and target-derived browser requests                        |
| Open residual gaps | 7; highest per-skill residuals are Medium                                                                                                               |

## Contents

* [System Description](#system-description)
* [Trust Boundaries](#trust-boundaries)
* [Assets](#assets)
* [Adversaries](#adversaries)
* [Bucket B1: Path A remote and local targets](#bucket-b1-path-a-remote-and-local-targets)
* [Bucket B2: Path A scanner toolchain supply chain](#bucket-b2-path-a-scanner-toolchain-supply-chain)
* [Bucket B3: Target-derived output](#bucket-b3-target-derived-output)
* [Bucket B4: Caller process and filesystem authority](#bucket-b4-caller-process-and-filesystem-authority)
* [Bucket B5: Design-intent verification](#bucket-b5-design-intent-verification)
* [Bucket B6: Path B configuration and navigation](#bucket-b6-path-b-configuration-and-navigation)
* [Bucket B7: Playwright and endpoint-managed Chrome](#bucket-b7-playwright-and-endpoint-managed-chrome)
* [Bucket B8: Path B evidence and child environment](#bucket-b8-path-b-evidence-and-child-environment)
* [Enterprise Readiness Gaps](#enterprise-readiness-gaps)
* [References](#references)

## System Description

### Components

1. `scripts/scan.py` classifies a Path A target, authorizes non-loopback HTTP(S), invokes `npx --yes @axe-core/cli@4.12.1`, normalizes JSON, and writes output.
2. `scripts/runtime_a11y/_config.py` loads Path B JSON configuration, enforces schema and URL semantics, and authorizes the base host.
3. `scripts/runtime_a11y/__main__.py` selects surfaces and probes, then starts Node/npm/PowerShell children with the caller environment.
4. `scripts/runtime_a11y/runner/*.mjs` validates navigation and identifiers, launches Playwright, drives probes, and emits evidence.
5. Playwright 1.61.1 and `@axe-core/playwright` 4.12.1 are installed from the skill-local lockfile.
6. Endpoint-managed system Chrome is selected by Playwright `channel: 'chrome'` with fixed launch arguments and an ephemeral automation profile.
7. `_intent.py` and `_projection.py` perform offline design-intent verification and rendering.

### Data Flow

```mermaid
accTitle: Accessibility scanner and runtime data flow
accDescr: Operator input passes through Path A or Path B validation to browser-backed scanners and bounded local evidence.
flowchart TD
    subgraph HOST["Operator Workstation / Runner"]
        ACLI["Path A scan.py"]
        PCFG["Path B Python config guard"]
        NODE["Path B Node runner"]
        PW["Playwright 1.61.1"]
        CHROME["Endpoint-managed system Chrome"]
        OUT["Normalized reports, traces, screenshots"]
        INTENT["Design-intent verifier"]
    end
    subgraph LOCAL["Operator-selected local filesystem"]
        FILE["Existing regular local file"]
        RECORD["Authored intent and local results"]
    end
    subgraph NPM["npm registry boundary"]
        AXE["@axe-core/cli@4.12.1"]
    end
    subgraph TARGET["Untrusted HTTP(S) target"]
        WEB["Authorized initial origin and target content"]
    end
    ACLI -->|"classify + authorize"| FILE
    ACLI -->|"argv, no shell"| AXE
    AXE -->|"HTTP(S) fetch and render"| WEB
    AXE -->|"JSON stdout"| ACLI
    ACLI -->|"normalized JSON write"| OUT
    PCFG -->|"validated config + inherited environment"| NODE
    NODE -->|"Playwright API"| PW
    PW -->|"channel: chrome"| CHROME
    CHROME -->|"HTTP(S) navigation and browser requests"| WEB
    NODE -->|"bounded direct request"| WEB
    NODE -->|"reports, traces, screenshots"| OUT
    RECORD -->|"YAML/JSON read"| INTENT
    INTENT -->|"digest-bound verification output"| OUT
```

## Trust Boundaries

### Boundary Diagram

```text
┌───────────────────────────────────────────────────────────────────┐
│ TRUST BOUNDARY: Operator Workstation / Runner                     │
│  Path A CLI ── axe CLI       Path B Python ── Node ── Playwright  │
│       │                            │                    │           │
│       └────────────── evidence writers ────────────────┘           │
│                               │                     system Chrome  │
└──────────┬────────────────────┼──────────────────────────┬─────────┘
           │ npm                │ local file/evidence      │ HTTP(S)
   ┌───────▼────────┐   ┌───────▼────────────────┐   ┌─────▼──────────┐
   │ npm registry  │   │ Operator filesystem    │   │ Untrusted web  │
   │ package input │   │ selected files/output  │   │ target/content │
   └────────────────┘   └────────────────────────┘   └────────────────┘
```

### Boundary Descriptions

| Boundary                                           | Assets Protected                                            | Controls Enforced                                                                                                                                                                                                             |
|----------------------------------------------------|-------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Path A CLI target to classifier                    | Host network position, local filesystem, argument semantics | Reject leading dash, credentials, unsupported/ambiguous schemes, network shares, remote file authorities, missing files, and directories; classify before npx                                                                 |
| Path A remote HTTP(S) target                       | Internal services reachable from the workstation            | Loopback permitted by default; other hosts require `--allow-host` or `--allow-external`; residual redirect, DNS, subresource, and browser egress remains G-INF-1                                                              |
| Path A local filesystem                            | Operator-selected local content                             | Accept an explicit existing regular local path or local `file:` URI; reject network-shaped resolved paths before any filesystem probe; reject non-local authority; access runs as the operator and is not repository-confined |
| npm registry                                       | Path A scanner integrity                                    | Exact package version; argv without shell; no lockfile integrity for npx resolution (G-SUP-1)                                                                                                                                 |
| Path B config and CLI to Python guard              | Browser destination and host network position               | JSON Schema; absolute credential-free HTTP(S); host authorization; external authorization never overrides scheme validation                                                                                                   |
| Path B config/environment to JavaScript navigation | Navigation and artifact identity                            | Reassert and reauthorize the effective HTTP(S) base URL after CLI overrides; route paths and trigger destinations remain same-origin; portable path-bearing identifiers are rejected before writes                            |
| Python to Node/npm/PowerShell child                | Caller environment and execution context                    | Argument-list spawning; full inherited environment is explicit residual G-INF-3                                                                                                                                               |
| Playwright to system Chrome                        | Browser identity, parser surface, network position          | Fixed channel and launch arguments; ephemeral profile; launch-bound readiness/version evidence; endpoint owns binary identity and patching (G-SUP-2)                                                                          |
| Browser and direct requests to web content         | Host network position and target-derived data               | Broken-link direct requests retry GET after unsupported HEAD responses and use at most five validated same-origin redirect hops; no complete browser redirect, DNS, worker, socket, download, or process-egress control       |
| Browser/runner to evidence                         | Artifact integrity and confidentiality                      | Portable identifiers, run-root containment, bounded normalized shape, hashes where supported, and target-derived content treated as untrusted                                                                                 |
| Design-intent record to verifier                   | Human decision integrity                                    | Safe YAML loading, schema/semantic validation, digest binding, contained atomic writes, and no generator-authored override                                                                                                    |

## Assets

| Id | Asset                                 | Lifetime                | Notes                                                                                       |
|----|---------------------------------------|-------------------------|---------------------------------------------------------------------------------------------|
| A1 | Authorized remote target              | Invocation              | Initial HTTP(S) target and same-origin configured navigation                                |
| A2 | Operator-selected local file          | Invocation              | Explicit existing regular file; readable with operator permissions; not repository-confined |
| A3 | Path A and Path B toolchains          | Installation/invocation | axe CLI, skill-local Node dependencies, Python environment, and system Chrome               |
| A4 | Runtime configuration and environment | Invocation              | Project config, CLI values, and inherited child environment                                 |
| A5 | Browser execution context             | Invocation              | Ephemeral Playwright context/profile and endpoint-managed Chrome process                    |
| A6 | Reports and runtime evidence          | Run lifetime            | JSON, traces, screenshots, measurements, transcripts, and hashes                            |
| A7 | Design-intent record                  | Repository lifetime     | Human-authored committed source that the skill reads but does not rewrite                   |
| A8 | Verification artifact                 | CI/run lifetime         | Digest-bound result generated beside the authored record                                    |

## Adversaries

| Id    | Adversary                                                                     | In-scope mitigations                                                                                                         |
|-------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| ADV-a | Caller supplying a hostile target, route, trigger, identifier, or output path | URL and host authorization, same-origin navigation, portable identifiers, containment, and argument-list execution           |
| ADV-b | Hostile target or page content                                                | Browser isolation properties, bounded direct redirects, defensive normalization, target-derived content treated as untrusted |
| ADV-c | Compromised scanner, dependency, or browser                                   | Version/lock pins, endpoint application control, fixed Chrome channel, and explicit residual gaps                            |
| ADV-d | Repository contributor tampering with config, intent, or evidence paths       | Schema/semantic validation, no-follow containment where implemented, atomic writes, and digest binding                       |
| ADV-e | Less-trusted process observing inherited environment or generated evidence    | No first-party secret handling; explicit environment and evidence residuals; operators control deployment trust              |

## Bucket B1: Path A remote and local targets

### Spoofing

* The classifier parses HTTP(S) authority before host authorization and rejects credentials. The skill does not authenticate target identity beyond URL and endpoint transport behavior.

### Tampering

* Target text is classified before subprocess execution. Local targets become canonical file URIs; remote targets retain their authorized HTTP(S) form.
* Target content remains untrusted browser input and can influence accessibility results.

### Repudiation

* The normalized result records the resolved target. The skill does not provide durable network-request non-repudiation.

### Information Disclosure

* Loopback HTTP(S) is allowed by default. Non-loopback hosts require a repeated host allowlist value or explicit external confirmation.
* Initial authorization does not bind later DNS answers or constrain every redirect and browser-derived request (G-INF-1).
* Local-file access is intentional operator authority. Existing regular files are not limited to the repository, and the skill avoids claiming confinement that it does not enforce.

### Denial of Service

* Hostile pages and large local files can consume browser CPU or memory. Invocation remains operator-scoped and upstream browser limits apply.

### Elevation of Privilege

* Network shares, non-local file authorities, leading-dash targets, and shell interpretation are rejected. Network-shaped paths are rejected at the filesystem boundary on the resolved path, so a `file:` URI cannot decode into a UNC path and elicit an outbound request before the scan starts. Reads still occur with the invoking user's filesystem permissions.

### Risk Rating

| Threat                                                                            | Likelihood | Impact | Residual Risk | Status                        |
|-----------------------------------------------------------------------------------|------------|--------|---------------|-------------------------------|
| Remote target reaches unintended internal service after authorization or redirect | Med        | High   | Med           | Partially Mitigated (G-INF-1) |
| Operator selects a sensitive local regular file                                   | Low        | High   | Low           | Accepted operator capability  |
| Hostile target exhausts local browser resources                                   | Low        | Med    | Low           | Partially Mitigated           |

## Bucket B2: Path A scanner toolchain supply chain

### Spoofing

* The axe CLI package name and version are fixed. Registry compromise or substitution of that exact release remains G-SUP-1.

### Tampering

* `npx --yes @axe-core/cli@4.12.1 -- <target>` uses an argument list and parser boundary without a shell.
* npx may resolve the pinned package at runtime without a committed integrity lock for this path.

### Repudiation

* npm/npx logs are external to the skill; no package-resolution audit record is generated by Path A.

### Information Disclosure

* The subprocess receives the resolved target and inherited environment. The wrapper adds no credential material.

### Denial of Service

* Missing Node/npx or scanner failure produces a typed nonzero result rather than silent degradation.

### Elevation of Privilege

* Shell injection through the target is mitigated by argument-list invocation and leading-dash rejection. Browser parser exploitation remains G-TAM-1.

### Risk Rating

| Threat                             | Likelihood | Impact | Residual Risk | Status                        |
|------------------------------------|------------|--------|---------------|-------------------------------|
| Substituted pinned scanner package | Low        | High   | Med           | Partially Mitigated (G-SUP-1) |
| Target argument command injection  | Low        | High   | Low           | Mitigated                     |
| Axe browser parser exploitation    | Low        | High   | Med           | Accepted upstream (G-TAM-1)   |

## Bucket B3: Target-derived output

### Spoofing

* Output does not establish an identity. Target-reported text and metadata are data, not authority.

### Tampering

* Path A requires valid JSON and emits a fixed normalized shape. Path B validates and contains generated artifacts according to each evidence writer's contract.

### Repudiation

* Run metadata, artifact hashes where present, target identifiers, and intent digests support traceability. The skill does not claim cryptographic non-repudiation.

### Information Disclosure

* Target-controlled rule descriptions, URLs, DOM snapshots, screenshots, traces, announcements, and metadata can enter evidence (G-INF-2).
* Traces and screenshots can preserve page content. Operators must avoid targets containing personal or secret data unless the owning workflow permits that evidence.

### Denial of Service

* Normalized Path A results bound propagated structure. Path B limits specific collections and artifact sizes where configured, but browser-generated evidence can still be large.

### Elevation of Privilege

* Evidence is never interpreted as instructions by the runtime. Downstream agents and users must retain the untrusted-content boundary.

### Risk Rating

| Threat                                        | Likelihood | Impact | Residual Risk | Status                        |
|-----------------------------------------------|------------|--------|---------------|-------------------------------|
| Target-derived content leaks through evidence | Med        | Med    | Med           | Partially Mitigated (G-INF-2) |
| Malformed scanner output changes control flow | Med        | Low    | Low           | Mitigated                     |
| Oversized browser evidence consumes disk      | Low        | Med    | Low           | Partially Mitigated           |

## Bucket B4: Caller process and filesystem authority

### Spoofing

* The CLIs run as the invoking OS user and do not assert a separate identity.

### Tampering

* Argument parsers, typed configuration, path containment, regular-file checks, and portable identifiers constrain caller-selected values at their owning boundaries.

### Repudiation

* Deterministic exit codes and run metadata identify success, usage failure, and runtime failure, but caller identity is not independently attested.

### Information Disclosure

* The caller can direct output to paths writable by that user. The skill does not elevate permissions or protect data from the invoking user.

### Denial of Service

* The caller controls invocation frequency and target selection. The skill runs no shared network listener.

### Elevation of Privilege

* Output and local-file operations execute with caller privileges. Existing no-follow and containment controls protect runtime-owned paths; arbitrary caller-owned output remains operator authority.

### Risk Rating

| Threat                                               | Likelihood | Impact | Residual Risk | Status                                |
|------------------------------------------------------|------------|--------|---------------|---------------------------------------|
| Operator overwrites an unintended writable output    | Low        | Med    | Low           | Accepted operator authority           |
| Repository path redirection targets runtime evidence | Low        | High   | Low           | Mitigated where runtime owns the path |

## Bucket B5: Design-intent verification

### Spoofing

* The adapter evaluates local authored input against local results and does not assert external identity.

### Tampering

* Duplicate-key rejection, safe YAML loading, authored schema and semantic validation, boolean-only blocking, identifier validation, and deterministic digest binding protect the verification contract.
* The verifier reads human override outcome only to derive effective gate behavior; it does not rewrite the observed outcome or authored record.

### Repudiation

* Verification output records intent and expectation identities plus a digest of the authored revision. Human override metadata remains in the authored record.

### Information Disclosure

* Verification artifacts echo authored identifiers and selected rationale-adjacent metadata but are not designed to carry credentials.

### Denial of Service

* Malformed structures fail with typed errors before partial verification output is accepted.

### Elevation of Privilege

* Directory handles, no-follow checks, regular-file enforcement, exclusive temporary files, and handle-relative atomic rename mitigate repository-controlled output redirection on supported platforms.

### Risk Rating

| Threat                                                  | Likelihood | Impact | Residual Risk | Status                       |
|---------------------------------------------------------|------------|--------|---------------|------------------------------|
| Consuming project skips equivalent authoring validation | Med        | Med    | Med           | Accepted repository boundary |
| Symlink redirects verification output                   | Low        | High   | Low           | Mitigated                    |
| Malformed record creates ambiguous outcome              | Low        | Med    | Low           | Mitigated                    |

## Bucket B6: Path B configuration and navigation

### Spoofing

* The Python guard requires an absolute credential-free HTTP(S) base URL with a host, then permits loopback, a configured host allowlist, or explicit external authorization. A CLI base-URL override re-enters this guard before `run-all` or `probe` can start browser work.
* The JavaScript runner reasserts the HTTP(S) invariant before browser launch.

### Tampering

* JSON Schema and Python semantic validation reject invalid configuration before child execution. Configured route paths remain relative to the base origin.
* Navigate and visit triggers resolve relative or absolute HTTP(S) against the authorized origin and reject origin changes before permissive action handling.

### Repudiation

* Selected probe, surface, state, target, and result metadata provide run attribution. No remote server identity attestation is claimed.

### Information Disclosure

* External authorization controls the configured initial host, not every browser-derived request. Route and trigger same-origin checks reduce explicit navigation authority but do not create a network firewall.

### Denial of Service

* Invalid targets and identifiers fail before browser work. Authorized pages can still stall or consume resources within probe-specific timeouts and browser behavior.

### Elevation of Privilege

* Protocol-relative, unsupported-scheme, credential-bearing, malformed, and off-origin configured navigation is rejected. Explicit external authorization never overrides scheme or trigger-origin policy.

### Risk Rating

| Threat                                                             | Likelihood | Impact | Residual Risk | Status              |
|--------------------------------------------------------------------|------------|--------|---------------|---------------------|
| Configured navigation escapes the authorized origin                | Low        | High   | Low           | Mitigated           |
| Authorized target causes browser resource exhaustion               | Low        | Med    | Low           | Partially Mitigated |
| External authorization is mistaken for browser-wide egress control | Med        | Med    | Med           | Documented residual |

## Bucket B7: Playwright and endpoint-managed Chrome

### Spoofing

* Playwright selects `channel: 'chrome'`; launch-bound preflight records the browser-reported version. Binary signature, installation provenance, and patch posture are owned by endpoint controls (G-SUP-2).

### Tampering

* Playwright and axe dependencies are locked in the skill-local package lock. Chrome receives fixed hardening arguments; generic caller arguments are not accepted.
* Target content reaches independent Playwright/system-Chrome parser and rendering surfaces (G-TAM-2).

### Repudiation

* Readiness records the selected channel and browser-reported version. It does not attest a binary hash or signature.

### Information Disclosure

* Browser requests originate from the workstation network position. No complete interception policy constrains redirects, subresources, Service Workers, WebSockets, downloads, DNS changes, peer IPs, or browser-internal connections.
* The broken-link direct-request helper is narrower: it disables automatic redirects, retries with GET when HEAD returns 405 or 501, and follows at most five validated same-origin HTTP(S) hops.

### Denial of Service

* Browser launch and cleanup failures fail readiness. Hostile content can still exhaust or crash Chrome during an authorized run.

### Elevation of Privilege

* Playwright creates an ephemeral automation profile and does not receive a caller-controlled user-data directory or generic launch arguments. Browser sandbox and endpoint policy remain external controls.

### Risk Rating

| Threat                                                 | Likelihood | Impact | Residual Risk | Status                        |
|--------------------------------------------------------|------------|--------|---------------|-------------------------------|
| Substituted or stale system Chrome                     | Low        | High   | Med           | Endpoint-owned (G-SUP-2)      |
| Browser/parser exploitation by target content          | Low        | High   | Med           | Partially Mitigated (G-TAM-2) |
| Browser-derived request reaches unintended destination | Med        | High   | Med           | Accepted workstation residual |

## Bucket B8: Path B evidence and child environment

### Spoofing

* Probe, route, surface, state, journey, and visual-review machine identifiers use one portable grammar and are validated before path construction. The grammar rejects trailing-dot aliases and Windows reserved device names, including device names followed by an extension.
* Configuration-supplied aliases do not override a schema-validated identifier. The calibration journey identifier is taken from the validated `id` and re-asserted before any path is composed.

### Tampering

* Runtime-owned evidence uses contained roots, regular-file checks, atomic patterns, and hashes where supported. Invalid identifiers are rejected rather than normalized into collisions.
* Calibration evidence paths are asserted to remain beneath the resolved run root before any directory is created, so a configured identifier cannot steer a write outside that root.
* Visual-review artifact paths carry route, surface, and state as separate validated segments, so distinct routes sharing a surface and state cannot overwrite each other's evidence.

### Repudiation

* Evidence records probe, surface, state, timestamps, browser metadata, and hashes where available. It is traceability evidence, not a non-repudiation guarantee.

### Information Disclosure

* Python-spawned Node/npm/PowerShell children inherit the complete caller environment (G-INF-3). The skill does not claim secret filtering.
* Traces, screenshots, transcripts, and measurements can include target content as described in B3.

### Denial of Service

* Artifact limits and bounded collections constrain selected outputs. Child tools and browser evidence can still consume local process, disk, and memory resources.

### Elevation of Privilege

* Child commands use argument lists and fixed runner modules. Environment inheritance can alter tool behavior, but no untrusted caller-to-command-string boundary is introduced.

### Risk Rating

| Threat                                                   | Likelihood | Impact | Residual Risk | Status                        |
|----------------------------------------------------------|------------|--------|---------------|-------------------------------|
| Ambient secret exposed to a child process                | Low        | High   | Med           | Accepted residual (G-INF-3)   |
| Identifier collision or path traversal corrupts evidence | Low        | High   | Low           | Mitigated                     |
| Target content leaks through trace or screenshot         | Med        | Med    | Med           | Partially Mitigated (G-INF-2) |

## Enterprise Readiness Gaps

The following limitations let operators choose an appropriate execution environment. Severity values are project assessments, not CVSS scores.

| Id      | Gap                                                                                                                                                                                                                                                            | Severity        | Status                                                                                                                                |
|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------|---------------------------------------------------------------------------------------------------------------------------------------|
| G-SUP-1 | Path A pins `@axe-core/cli@4.12.1`, but npx resolves it without a committed integrity lock for that invocation. (audit: A-SUP-1)                                                                                                                               | SupplyChain-Low | Review upgrades and prefer pre-provisioned trusted caches where stronger integrity is required                                        |
| G-INF-1 | Path A authorizes the initial remote HTTP(S) host, but browser redirects, DNS rebinding/address changes, subresources, Service Workers, WebSockets, downloads, and browser-internal requests can still use the workstation network position. (audit: A-SSRF-1) | InfoDisc-Med    | Run only against intended targets from a network position with matching trust; use network-level egress policy for stronger isolation |
| G-TAM-1 | Path A renders targets in the browser engine bundled by the axe CLI toolchain. (audit: A-BRWS-1)                                                                                                                                                               | Tampering-Med   | Keep the toolchain patched and isolate hostile targets                                                                                |
| G-INF-2 | Reports, traces, screenshots, transcripts, and metadata from both paths can reproduce target-controlled content. (audit: A-INF-1)                                                                                                                              | InfoDisc-Med    | Treat evidence as untrusted and avoid secret or personal-data targets unless the workflow permits retention                           |
| G-SUP-2 | Path B selects endpoint-managed system Chrome but does not authenticate its binary, signature, installation source, or patch posture                                                                                                                           | SupplyChain-Med | Endpoint application control and patch management own Chrome trust                                                                    |
| G-TAM-2 | Playwright and system Chrome expose an independent parser, rendering, and automation surface to target content                                                                                                                                                 | Tampering-Med   | Keep locked dependencies and Chrome patched; use controlled workstations for untrusted content                                        |
| G-INF-3 | Node/npm/PowerShell children inherit the caller environment, which may contain ambient secrets or behavior-changing settings                                                                                                                                   | InfoDisc-Med    | Run in a least-privilege environment and avoid unrelated secrets; filtering awaits a supported cross-platform contract                |

Path A local-file scanning is not folded into G-INF-1. It is an explicit operator-authorized capability to read any selected existing regular local file with the operator's permissions, without repository confinement. A separate local-file disclosure gap is warranted only if a less-trusted caller or confinement requirement becomes supported.

For active work associated with this model, see [hve-core issue #2786](https://github.com/microsoft/hve-core/issues/2786).

## References

* [STRIDE Threat Model](https://learn.microsoft.com/azure/security/develop/threat-modeling-tool-threats)
* [OWASP Server-Side Request Forgery Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
* [Playwright BrowserType launch options](https://playwright.dev/docs/api/class-browsertype#browser-type-launch)
* [Playwright request routing](https://playwright.dev/docs/network#handle-requests)
* [Python URL parsing security](https://docs.python.org/3/library/urllib.parse.html#url-parsing-security)
* [Accessibility skill](SKILL.md)
* [Repository security model](../../../../docs/security/security-model.md)

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.