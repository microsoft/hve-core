---
title: GitLab Skill Security Model
description: STRIDE threat model for the GitLab skill organized by assets, adversaries, and trust buckets (CLI to GitLab API, environment credentials, git remote subprocess, CLI caller process) with in-code mitigations and acknowledged enterprise readiness gaps
author: microsoft/hve-core
ms.topic: reference
ms.date: 2026-06-29
---
<!-- markdownlint-disable-file -->
# GitLab Skill Security Model

This document records the STRIDE threat model for the GitLab skill (`scripts/gitlab.py`). The model is organized by trust bucket: CLI → GitLab API (B1), Environment credentials (B2), Git remote subprocess / project resolution (B3), and CLI caller process (B4). Each bucket enumerates all six STRIDE categories with the in-code mitigations that address them. Assets and adversaries are enumerated first. Acknowledged enterprise readiness gaps are listed at the end.

The skill is a single-file, standard-library-only CLI. It persists no tokens to disk and runs no network listener. It does spawn one read-only subprocess — `git remote get-url origin` — when `GITLAB_PROJECT` is not set; that path is enumerated as bucket B3.

## Assets

| Id | Asset                                       | Lifetime         | Notes                                                                                                                                       |
|----|---------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| A1 | GitLab personal access token                 | Operator-managed | Read from `GITLAB_TOKEN` env at invocation. Sent as `PRIVATE-TOKEN` header over TLS.                                                       |
| A2 | `GITLAB_URL`                                 | Operator-managed | Origin of the GitLab instance. Used to construct every API URL.                                                                            |
| A3 | Git remote URL (local)                       | Command lifetime | Read from `git remote get-url origin`; may embed credentials. Sanitized before appearing in any diagnostic output.                         |
| A4 | Job traces, MR/pipeline payloads, responses  | Command lifetime | Server responses and CI traces may contain secrets or content authored by others; downstream automation must treat as untrusted.          |
| A5 | Diagnostic / audit output                    | Command lifetime | stderr diagnostics and the optional audit log; must never contain unredacted secrets.                                                      |

## Adversaries

| Id    | Adversary                                              | In-scope mitigations                                                                                                                                                              |
|-------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ADV-a | Same-uid malware on the operator workstation           | **Not defended.** A process running as the operator can read the environment and git config directly. Workstation hygiene is the controlling defense.                            |
| ADV-b | Network attacker on the CLI ↔ GitLab channel           | TLS with stdlib certificate validation; HTTP redirects refused (`_NoRedirect`); HTTPS required for non-loopback hosts; capped, content-type-checked response parser.             |
| ADV-c | Hostile or malformed GitLab server / response          | No-redirect opener; response size cap (`MAX_BODY_BYTES`); JSON content-type fail-closed; error and non-JSON bodies redacted and size-previewed before display.                  |
| ADV-d | Hostile local git remote                               | Subprocess uses an arg list (no shell) with an explicit timeout; embedded credentials stripped for logging (`_sanitize_remote_url`); resolved path validated (`_validate_project_path`). |
| ADV-e | Hostile caller process controlling argv / stdin / env  | Inputs validated/encoded; `GITLAB_URL` canonicalized to origin-only; `state`/`ref`/numeric IDs validated; stdin/JSON size-capped before parse.                                  |

## Bucket B1: CLI → GitLab API

All REST calls target the configured `GITLAB_URL` over `urllib.request` through a hardened opener.

### Spoofing

* TLS certificate validation is enforced by the stdlib default `SSLContext` (system trust store).
* `GITLAB_URL` is reduced to an origin-only URL by `_normalize_base_url`, which rejects embedded userinfo so a crafted value cannot impersonate a host with inline credentials.

### Tampering

* TLS protects request and response bodies in transit.
* The shared opener `_OPENER` is built with `_NoRedirect`, which raises on any 30x so a redirect cannot silently retarget the request.
* Interpolated values are validated/encoded: the project path via `urllib.parse.quote(safe="")`, merge-request `state` via `validate_state`, pipeline `ref` via `validate_ref`, and numeric IDs via `validate_numeric_id` / `validate_positive_int` (which reject `0` and enforce upper bounds).

### Repudiation

* Commands emit deterministic exit codes (`EXIT_SUCCESS`/`EXIT_FAILURE`/`EXIT_USAGE`).
* An optional best-effort audit record is emitted when the audit sink is configured; see Enterprise Readiness Gaps for limitations.

### Information Disclosure

* The `PRIVATE-TOKEN` header is sent only over TLS and is never logged.
* The token-bearing opener blocks 30x, preventing a hostile redirect from forwarding the token to a non-GitLab origin (`_NoRedirect`).
* The transport requires a JSON content type when JSON is expected and reads through `_read_capped`; a missing or non-JSON content type fails closed.
* HTTP error bodies are parsed first, then redacted for presentation; a dict error without `message`/`error` produces a single structured redacted summary (`_request_bytes`). Non-JSON bodies that the CLI prints for usability are passed through `_redact` and capped via `_preview_text`. `_redact` covers `PRIVATE-TOKEN`/`X-API-Key`/`Authorization`/`Proxy-Authorization`/`Cookie`/`Set-Cookie`/`token`/`password`/`secret` and query-string secrets.

### Denial of Service

* Response bodies are read through `_read_capped` with a `MAX_BODY_BYTES` cap.
* Requests use `REQUEST_TIMEOUT` so a stalled server cannot hang the CLI.

### Elevation of Privilege

* The skill issues only the operations exposed by its explicit subcommands; request URLs are built only from validated, encoded segments.

### TLS posture

Every GitLab call uses the stdlib opener with no custom `SSLContext`, CA-bundle flag, or pinning. Operators inherit Python's default HTTPS behavior: validation uses the system trust store; internal CAs require `SSL_CERT_FILE`/`SSL_CERT_DIR`; there is no pinning or mTLS (G-TLS-1). HTTPS is required for non-loopback hosts; `http://` is permitted only for loopback or when `GITLAB_ALLOW_INSECURE=1` is set for local development.

## Bucket B2: Environment credentials

The token and instance origin are read from the environment per invocation (`require_environment`). Nothing is persisted to disk.

### Spoofing

* `GITLAB_URL` is parsed with `urllib.parse.urlsplit`, must use `http`/`https`, and HTTPS is enforced for non-loopback hosts (`_is_loopback`).

### Tampering

* `_normalize_base_url` rejects control characters, embedded userinfo, query, fragment, and non-root paths, reducing the value to an origin-only URL before any request is built.

### Repudiation

* Missing or malformed credentials/URL fail fast with a usage exit code via `die`.

### Information Disclosure

* The token is never written to disk and never logged; it is used only as the `PRIVATE-TOKEN` header.

### Denial of Service

* Not applicable; credential resolution is a bounded, in-process step.

### Elevation of Privilege

* The token's effective permissions are governed entirely by GitLab; the skill adds no privilege.

## Bucket B3: Git remote subprocess / project resolution

When `GITLAB_PROJECT` is unset, the skill resolves the project from the local git remote (`project()`).

### Spoofing

* The remote is read from the local git configuration, which is operator-controlled; a hostile local remote is modeled as ADV-d and constrained by path validation below.

### Tampering

* The subprocess is invoked with an argument list (`["git", "remote", "get-url", "origin"]`) and `shell` is never used, so remote values cannot inject shell commands.
* The resolved path is validated by `_validate_project_path`, which rejects `%`, backslashes, and empty/`.`/`..` segments before it is URL-encoded — blocking path traversal and encoded-separator escapes.

### Repudiation

* Resolution failures (`CalledProcessError`, `FileNotFoundError`, `TimeoutExpired`) map to explicit exit codes with messages that reference only the sanitized remote URL.

### Information Disclosure

* `_sanitize_remote_url` strips embedded credentials from the remote URL before it appears in any error message, so a remote like `https://user:pass@host/group/project.git` never leaks its secret to stderr.

### Denial of Service

* `subprocess.check_output` is bounded by `timeout=REQUEST_TIMEOUT`; a stalled or blocked `git` invocation surfaces as a typed timeout error rather than hanging the CLI.

### Elevation of Privilege

* The resolved project path becomes an API path component, but it is validated and encoded; `GITLAB_PROJECT` can be set explicitly to bypass remote resolution entirely for privileged or destructive operations.

## Bucket B4: CLI caller process

The caller controls argv, environment, stdin, stdout, and stderr; the CLI treats that process as operator-controlled.

### Spoofing

* The CLI has no network listener or attach surface; it runs as the invoking OS user.

### Tampering

* Arguments are parsed locally; handlers validate identifiers, `state`, `ref`, and numeric IDs, and encode interpolated segments before issuing requests.
* JSON payloads are parsed through `load_json_payload` with a size cap enforced before `json.loads`.

### Repudiation

* Validation, authentication, and runtime failures map to distinct exit codes for attribution by a calling step.

### Information Disclosure

* Command output is JSON-encoded GitLab payloads; tokens never appear in normal output.
* Job traces are redacted via `_redact` and truncated at `MAX_LOG_BYTES` before printing (`cmd_job_log`), so a token echoed into a CI trace is masked and an oversized trace is truncated rather than hard-failing.
* GitLab-authored text returned in output must be treated as untrusted by downstream automation.

### Denial of Service

* HTTP bodies are read through `_read_capped`; job logs are truncated at `MAX_LOG_BYTES`; stdin/JSON payloads are size-capped; pagination is bounded by `validate_positive_int`.

### Elevation of Privilege

* No command path bypasses input validation or constructs an unencoded request URL from caller input.

## Enterprise Readiness Gaps

The following are known limitations recorded so operators can make informed deployment decisions. Severity ratings are the project's own assessment and are not equivalent to a CVSS score.

| Id      | Gap                                                                                                                                                                              | Severity        | Status                                                                                              |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------|-----------------------------------------------------------------------------------------------------|
| G-REP-1 | The optional audit record is best-effort and written after the request to an operator-supplied path; it is not a signed or append-only sink.                                   | Repudiation-Med | By design; integrate with host telemetry for tamper-evident logging.                                |
| G-INF-1 | The CLI prints redacted non-JSON response bodies to stdout/stderr for usability; redaction is a broad regex backstop that may over- or under-cover novel secret formats.        | InfoDisc-Low    | Accepted; monitor and extend `_redact` as new secret formats appear.                                |
| G-EOP-1 | The skill cannot revoke a leaked GitLab token; revocation is performed at the GitLab instance. A leaked PAT remains valid until revoked there.                                  | EoP-Med         | Upstream control; rotate/revoke at the GitLab instance on suspicion of compromise.                  |
| G-SUP-1 | Python dependencies are declared in `pyproject.toml` but transitive hashes are not pinned and no SBOM is published; transport/subprocess/redaction fuzz coverage is partial.   | SupplyChain-Med | Tracked at the repository level.                                                                     |
| G-TLS-1 | No certificate pinning for the GitLab origin; TLS validation depends entirely on the system trust store.                                                                       | InfoDisc-Low    | Operator-acceptable for a managed GitLab endpoint; documented for customers whose policy mandates pinning. |

For an active issue tracker entry covering these gaps, see [microsoft/hve-core#2225](https://github.com/microsoft/hve-core/issues/2225).

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
