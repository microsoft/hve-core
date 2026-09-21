---
title: GitLab Skill Security Model
description: STRIDE threat model for the GitLab skill covering API egress, credentials, git project resolution, caller input, the OAuth callback listener, and profile storage
author: microsoft/hve-core
ms.date: 2026-08-18
ms.topic: reference
estimated_reading_time: 11
keywords:
  - security
  - STRIDE
  - gitlab
  - rest cli
  - threat model
---
<!-- markdownlint-disable-file -->
# GitLab Skill Security Model

This document records the STRIDE threat model for the GitLab skill (`scripts/gitlab.py`). The model is organized by trust bucket: CLI → GitLab API (B1), Credential configuration (B2), Git remote subprocess / project resolution (B3), CLI caller process (B4), Browser → fixed loopback callback (B5), and OAuth profile store and lock (B6). Each bucket enumerates all six STRIDE categories with the in-code mitigations that address them. Assets and adversaries are enumerated first. Acknowledged enterprise readiness gaps are listed at the end.

The skill is a standard-library-only CLI with provider-local OAuth and
credential modules. OAuth mode runs a bounded loopback listener for PKCE or a
human-assisted device flow and persists profile-bound tokens in a POSIX
mode-0600 store. OAuth persistence fails closed on Windows until a protected
backend exists. Explicit legacy mode reads a PAT from the environment. The CLI also
spawns one read-only `git remote get-url origin` subprocess when
`GITLAB_PROJECT` is unset.

> **See also: repo-wide STRIDE model.** This skill participates in the repository-wide threat model at [`docs/security/security-model.md`](../../../../docs/security/security-model.md) and is registered in its [Skill Security Models](../../../../docs/security/security-model.md#skill-security-models) section.

## Executive Summary

The GitLab skill uses public-client OAuth with PKCE or human-assisted device
authorization by default. Short-lived access tokens refresh through rotating
refresh tokens stored in an instance/client-bound POSIX mode-0600 profile store.
Explicit `legacy-token` mode retains PAT support. All OAuth and API egress uses
TLS and the hardened no-redirect opener. Residual risks include the
provider/local refresh-commit crash window, same-user access to the token store,
and server-side authorization that local logout does not revoke.

### Security Posture Overview

| Dimension          | Value                                                                                       |
|--------------------|---------------------------------------------------------------------------------------------|
| Runtime surface    | REST CLI (stdlib only); OAuth loopback/device flow; token store; read-only `git` subprocess |
| Trust buckets      | B1 API, B2 config, B3 git remote, B4 caller, B5 callback, B6 profile store                  |
| Credentials        | OAuth Bearer access/refresh tokens by default; explicit PAT legacy mode                     |
| Network egress     | HTTPS to GitLab OAuth/API endpoints (no-redirect); fixed HTTP loopback callback             |
| Open residual gaps | 8 (EoP-Med: skill cannot revoke a leaked token)                                             |

## Contents

* [System Description](#system-description)
* [Trust Boundaries](#trust-boundaries)
* [Assets](#assets)
* [Adversaries](#adversaries)
* [Bucket B1: CLI → GitLab API](#bucket-b1-cli--gitlab-api)
* [Bucket B2: Credential profiles and environment](#bucket-b2-credential-profiles-and-environment)
* [Bucket B3: Git remote subprocess / project resolution](#bucket-b3-git-remote-subprocess--project-resolution)
* [Bucket B4: CLI caller process](#bucket-b4-cli-caller-process)
* [Bucket B5: Browser → fixed loopback OAuth callback](#bucket-b5-browser--fixed-loopback-oauth-callback)
* [Bucket B6: OAuth profile store and lock](#bucket-b6-oauth-profile-store-and-lock)
* [Enterprise Readiness Gaps](#enterprise-readiness-gaps)
* [References](#references)

## System Description

### Components

1. `scripts/gitlab.py` — CLI entry point, API transport, command dispatch, and audit logging.
2. `scripts/_gitlab_oauth.py` — public-client PKCE, device authorization, token parsing, and refresh exchange.
3. `scripts/_gitlab_credentials.py` — profile validation, POSIX mode-0600 persistence, Windows fail-close, and cross-process locking.
4. Hardened opener (`_OPENER` / `_NoRedirect`) — enforces TLS, refuses 30x redirects, and caps response bodies.
5. `git remote get-url origin` subprocess — read-only project resolution when `GITLAB_PROJECT` is unset.

### Data Flow

```mermaid
flowchart TD
    subgraph HOST["Operator Workstation / Runner (trust zone)"]
        CLI["gitlab.py CLI"]
        ENVCRED["URL / auth mode / public client ID<br/>or explicit legacy PAT"]
        GIT["git remote get-url origin<br/>(argv, no shell)"]
        LOOP["Fixed callback<br/>127.0.0.1:8766/callback"]
        STORE["OAuth profile store + lock<br/>(0700 dir, 0600 files)"]
        OUT["JSON / redacted job traces / audit log"]
    end
    subgraph BROWSER["User browser (authorization boundary)"]
        CONSENT["GitLab consent page"]
    end
    subgraph GL["GitLab Instance (network boundary)"]
        OAUTH["OAuth authorize / device / token endpoints"]
        API["GitLab REST API + CI job traces"]
    end
    CLI -->|"reads per invocation"| ENVCRED
    CLI -->|"resolve project on cache miss"| GIT
    CLI -->|"open authorize URL + PKCE challenge"| CONSENT
    CONSENT -->|"code + state over HTTP loopback"| LOOP
    LOOP -->|"validated code + state"| CLI
    CLI -->|"token exchange / device poll / refresh<br/>(HTTPS, no-redirect)"| OAUTH
    OAUTH -->|"short-lived access + rotating refresh token"| CLI
    CLI -->|"atomic profile commit"| STORE
    STORE -->|"locked bound profile read"| CLI
    CLI -->|"Bearer or explicit PRIVATE-TOKEN<br/>(HTTPS, no-redirect)"| API
    API -->|"MR/pipeline payloads + CI trace (untrusted)"| CLI
    CLI -->|"writes (redacted, truncated)"| OUT
```

## Trust Boundaries

### Boundary Diagram

```text
┌──────────────────────────────────────────────────┐
│ TRUST BOUNDARY: Operator Workstation / Runner                 │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌─────────┐  │
│  │ gitlab   │  │ Env config│  │ git remote│  │ output   │  │
│  │ CLI      │  │ / PAT     │  │ subprocess│  │          │  │
│  └────┬─────┘  └───────────┘  └──────────┘  └─────────┘  │
│       ├── 127.0.0.1:8766 callback                          │
│       └── POSIX owner-only OAuth profile store + lock      │
└────────────────────────┬──────────────────────────┘
       open browser      │ HTTPS (TLS, no-redirect)
   ┌───────────────┐  ┌────▼──────────────────────────────┐
   │ User browser  │  │ BOUNDARY: GitLab Instance        │
   │ consent page  │  │ OAuth endpoints + REST API       │
   └───────────────┘  └───────────────────────────────────┘
```

### Boundary Descriptions

| Boundary                      | Assets Protected                  | Controls Enforced                                                                                                     |
|-------------------------------|-----------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Operator Workstation / Runner | PAT, output, local git config     | Per-invocation env resolution; redaction; sanitized remote URL; argv (no shell)                                       |
| User browser and callback     | Code, state, PKCE verifier        | Fixed loopback address/path; Host and state checks; bounded wait; PKCE                                                |
| OAuth profile store and lock  | Access/refresh tokens, binding    | POSIX owner-only directory; `0600`; `O_NOFOLLOW`; descriptor validation; lock; atomic replacement; Windows fail-close |
| GitLab Instance               | Request/response integrity, token | TLS (system trust store); `_NoRedirect`; origin-only base URL; capped JSON parser; CI trace redacted/truncated        |

## Assets

| Id | Asset                                    | Lifetime         | Notes                                                                                                       |
|----|------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------|
| A1 | GitLab OAuth access token                | Short-lived      | Stored in a bound profile and sent as `Authorization: Bearer`.                                              |
| A2 | Rotating OAuth refresh token             | Provider-managed | Exchanged only against the trusted issuer/client binding and stored in the owner-only profile store.        |
| A3 | Explicit legacy PAT                      | Operator-managed | Read from `GITLAB_TOKEN` only when `GITLAB_AUTH_MODE=legacy-token`.                                         |
| A4 | OAuth code, device code, state, verifier | One flow         | Temporary capabilities; the PKCE verifier and state remain process-local.                                   |
| A5 | Profile store and lock state             | Persistent       | Schema, issuer/client binding, usability, expiry, scopes, and cross-process coordination state.             |
| A6 | `GITLAB_URL` and public client ID        | Operator-managed | Trusted issuer/client identity used to bind profiles and egress.                                            |
| A7 | Git remote URL                           | Command lifetime | May embed credentials; sanitized before diagnostics.                                                        |
| A8 | API payloads, CI traces, diagnostics     | Command lifetime | Untrusted server content and optional operational audit data; never contains intentional credential output. |

## Adversaries

| Id    | Adversary                                             | In-scope mitigations                                                                                                                                                                     |
|-------|-------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ADV-a | Same-uid malware on the operator workstation          | **Not defended.** A process running as the operator can read the environment and git config directly. Workstation hygiene is the controlling defense.                                    |
| ADV-b | Network attacker on the CLI ↔ GitLab channel          | TLS with stdlib certificate validation; HTTP redirects refused (`_NoRedirect`); HTTPS required for non-loopback hosts; capped, content-type-checked response parser.                     |
| ADV-c | Hostile or malformed GitLab server / response         | No-redirect opener; response size cap (`MAX_BODY_BYTES`); JSON content-type fail-closed; error and non-JSON bodies redacted and size-previewed before display.                           |
| ADV-d | Hostile local git remote                              | Subprocess uses an arg list (no shell) with an explicit timeout; embedded credentials stripped for logging (`_sanitize_remote_url`); resolved path validated (`_validate_project_path`). |
| ADV-e | Hostile caller process controlling argv / stdin / env | Inputs validated/encoded; `GITLAB_URL` canonicalized to origin-only; `state`/`ref`/numeric IDs validated; stdin/JSON size-capped before parse.                                           |

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
* The attempt audit record is write-ahead and fail-closed. The outcome record is best-effort; see Enterprise Readiness Gaps.

### Information Disclosure

* OAuth uses `Authorization: Bearer`; explicit legacy mode uses `PRIVATE-TOKEN`. Both are sent only over TLS and are never logged.
* The token-bearing opener blocks 30x, preventing a hostile redirect from forwarding the token to a non-GitLab origin (`_NoRedirect`).
* The transport requires a JSON content type when JSON is expected and reads through `_read_capped`; a missing or non-JSON content type fails closed.
* HTTP error bodies are parsed first, then redacted for presentation; a dict error without `message`/`error` produces a single structured redacted summary (`_request_bytes`). Non-JSON bodies that the CLI prints for usability are passed through `_redact` and capped via `_preview_text`.
* `_redact` scrubs the `Bearer`/`Basic` scheme-plus-value pair first, then `PRIVATE-TOKEN`/`X-API-Key`/`Authorization`/`Proxy-Authorization`/`Cookie`/`Set-Cookie`/`token`/`password`/`secret` and query-string secrets. It additionally applies `_REDACT_PATTERNS`, which mask every `_REDACT_KEYS` entry in JSON shape (`"key": "value"`), bare form shape (`key=value`, with no leading `?` or `&` required), and Azure Blob SAS query strings. `code_challenge` is deliberately excluded because a PKCE challenge is public by design and masking it would corrupt an authorization URL.
* Transport failures raise `GitLabAPIError`, whose `__str__` renders only the status, method, query-stripped resource, redacted summary, and a character-validated request ID. The raw response body, the query-bearing request URL, and the header dictionary are never part of the rendered string (`_scrub_url`, `_response_request_id`).
* The resolved credential lives only on the frozen `AuthContext`, whose `token` field carries `repr=False`. There is no module-level token global, so `repr(globals())`, an accidental `repr(auth_context)`, and traceback frame dumps cannot surface the PAT. A source-contract test asserts the global stays absent.

### Denial of Service

* Response bodies are read through `_read_capped` with a `MAX_BODY_BYTES` cap.
* Requests use `REQUEST_TIMEOUT` so a stalled server cannot hang the CLI.

### Elevation of Privilege

* The skill issues only the operations exposed by its explicit subcommands; request URLs are built only from validated, encoded segments.

### TLS posture

Every GitLab call uses the stdlib opener with no custom `SSLContext`, CA-bundle flag, or pinning. Operators inherit Python's default HTTPS behavior: validation uses the system trust store; internal CAs require `SSL_CERT_FILE`/`SSL_CERT_DIR`; there is no pinning or mTLS (G-TLS-1). HTTPS is required for non-loopback hosts; plaintext `http://` is refused for non-loopback hosts even when `GITLAB_ALLOW_INSECURE=1` is set, and is permitted only for loopback hosts when `GITLAB_ALLOW_INSECURE=1` is explicitly set — an opt-in gate mirroring the jira skill. `cmd_job_log` continues to emit redacted, untrusted CI trace content with truncation.

### Risk Rating

| Threat                                  | Likelihood | Impact | Residual Risk | Status                          |
|-----------------------------------------|------------|--------|---------------|---------------------------------|
| TLS MITM / hostile redirect retargeting | Low        | High   | Low           | Mitigated (TLS + `_NoRedirect`) |
| Plaintext HTTP to a non-loopback host   | Low        | High   | Low           | Mitigated (refused)             |
| Oversized-response memory exhaustion    | Low        | Low    | Low           | Mitigated (cap + timeout)       |

## Bucket B2: Credential profiles and environment

The instance origin and mode are read from the environment. OAuth mode loads an
instance/client-bound local profile containing short-lived access and rotating
refresh tokens. Legacy mode reads a PAT from `GITLAB_TOKEN`.

### Spoofing

* `GITLAB_URL` is parsed with `urllib.parse.urlsplit`, must use `http`/`https`, and HTTPS is enforced for non-loopback hosts (`_is_loopback`).

### Tampering

* `_normalize_base_url` rejects control characters, embedded userinfo, query, fragment, and non-root paths, reducing the value to an origin-only URL before any request is built.

### Repudiation

* Missing, malformed, mixed, or mismatched credentials fail fast with a usage
    exit code via `die`.

### Information Disclosure

* OAuth profiles use atomic mode-0600 writes in a dedicated POSIX owner-only directory and never appear in status output. Windows OAuth persistence fails closed. PAT values remain environment-only. Neither credential form is logged.

### Denial of Service

* Profile reads and writes are serialized with an advisory lock whose cross-process acquisition is bounded by a finite timeout.

### Elevation of Privilege

* The token's effective permissions are governed entirely by GitLab; the skill adds no privilege.

### Risk Rating

| Threat                                          | Likelihood | Impact | Residual Risk | Status                               |
|-------------------------------------------------|------------|--------|---------------|--------------------------------------|
| Base-URL host impersonation (embedded userinfo) | Low        | Med    | Low           | Mitigated (origin-only)              |
| OAuth refresh token at rest                     | Med        | High   | Med           | Partially mitigated (0600 + binding) |
| PAT at rest in operator environment             | Low        | High   | Med           | Not defended (workstation hygiene)   |

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

### Risk Rating

| Threat                                   | Likelihood | Impact | Residual Risk | Status                               |
|------------------------------------------|------------|--------|---------------|--------------------------------------|
| Shell injection via hostile remote URL   | Low        | High   | Low           | Mitigated (argv, no shell)           |
| Path traversal via resolved project path | Low        | Med    | Low           | Mitigated (`_validate_project_path`) |
| Credential leak from remote URL in logs  | Low        | High   | Low           | Mitigated (`_sanitize_remote_url`)   |
| Stalled `git` subprocess hang            | Low        | Low    | Low           | Mitigated (timeout)                  |

## Bucket B4: CLI caller process

The caller controls argv, environment, stdin, stdout, and stderr; the CLI treats that process as operator-controlled.

### Spoofing

* API commands have no listener or attach surface. The bounded `auth login` listener is modeled separately in B5.

### Tampering

* Arguments are parsed locally; handlers validate identifiers, `state`, `ref`, and numeric IDs, and encode interpolated segments before issuing requests.
* JSON payloads are parsed through `load_json_payload` with a size cap enforced before `json.loads`.

### Repudiation

* Validation, authentication, and runtime failures map to distinct exit codes for attribution by a calling step.

### Information Disclosure

* Command output is JSON-encoded GitLab payloads; tokens never appear in normal output.
* Diagnostic and raw-text writes use `_emit`, `_emit_stdout`, or `_emit_debug_traceback` and apply `_redact`. Successful structured JSON and TSV are sanitized by sensitive key before `_emit_structured_stdout`, preserving syntax and field arity. Arbitrary credentials copied into non-sensitive successful free text remain a residual gap.
* Job traces are redacted via `_redact` and truncated at `MAX_LOG_BYTES` before printing (`cmd_job_log`), so a token echoed into a CI trace is masked and an oversized trace is truncated rather than hard-failing.
* Credentialed traffic has two explicit owners: REST requests use `gitlab._request_bytes`, and OAuth forms use `_gitlab_oauth.post_form`. A recursive production-module source contract rejects direct egress elsewhere, while behavioral tests prove write-ahead audit attempts and bounded outcomes for both owners.
* `GITLAB_DEBUG=1` enables a traceback on the failure path; the formatted traceback is redacted before it is written. `LOGGER.exception` is banned by a source-contract test because it would emit an unredacted traceback.
* GitLab-authored text returned in output must be treated as untrusted by downstream automation.

### Denial of Service

* HTTP bodies are read through `_read_capped`; job logs are truncated at `MAX_LOG_BYTES`; stdin/JSON payloads are size-capped; pagination is bounded by `validate_positive_int`.

### Elevation of Privilege

* No command path bypasses input validation or constructs an unencoded request URL from caller input.

### Risk Rating

| Threat                                         | Likelihood | Impact | Residual Risk | Status                              |
|------------------------------------------------|------------|--------|---------------|-------------------------------------|
| Token echoed into a CI job trace               | Med        | High   | Low           | Mitigated (`_redact` + truncate)    |
| Untrusted GitLab / CI text consumed downstream | Med        | Med    | Med           | By design (consumer responsibility) |
| Oversized stdin / job-log payload              | Low        | Low    | Low           | Mitigated (caps / truncation)       |
| Leaked token not revocable by the skill        | Low        | High   | Med           | Accepted upstream (G-EOP-1)         |

## Bucket B5: Browser → fixed loopback OAuth callback

`auth login` binds `127.0.0.1:8766` before opening the authorization URL and accepts a callback only at `/callback`.

### Spoofing

* The handler validates the exact Host header and callback path, then compares UTF-8 state bytes with `secrets.compare_digest` before accepting completion.
* PKCE S256 binds a captured authorization code to the verifier held by the CLI process.

### Tampering

* The listener binds only to IPv4 loopback, sets `allow_reuse_address = False`, and rejects wrong hosts, paths, missing state, and incomplete callback parameters.

### Repudiation

* Authentication commands use distinct operation names and deterministic exit codes. Authorization URL output contains no secret verifier or token.

### Information Disclosure

* The callback response is minimal text and contains no token, authorization code, or profile content.
* Token exchange uses the HTTPS no-redirect opener only after state validation.
* Device verification instructions are validated before display. Values carrying Unicode control characters, and verification URIs with embedded credentials, raw spaces, backslashes, unparseable components, or an origin that differs from the configured issuer, are rejected instead of printed. The user code itself is preserved unchanged because its format belongs to the authorization server. This is local defense-in-depth and deliberately narrows support for deployments that publish device verification on a different host.

### Denial of Service

* Bind failure is converted to a typed error with a device-login recovery path. Invalid local requests do not terminate the serve loop, each accepted peer has a five-second read timeout, and one shared deadline bounds listener service and caller waiting.

### Elevation of Privilege

* The handler accepts only a valid code or provider error paired with the expected state. Authorization remains subject to the user-visible GitLab consent page and registered application scopes.

### Risk Rating

| Threat                               | Likelihood | Impact | Residual Risk | Status                               |
|--------------------------------------|------------|--------|---------------|--------------------------------------|
| Forged callback or code interception | Low        | High   | Low           | Mitigated (state + PKCE)             |
| Local callback-port denial           | Low        | Low    | Low           | Mitigated (typed device flow)        |
| Callback wait exhaustion             | Low        | Low    | Low           | Mitigated (shared deadline)          |
| Hostile device-instruction output    | Low        | Med    | Low           | Mitigated (validated before display) |

## Bucket B6: OAuth profile store and lock

On POSIX, OAuth profiles are stored beneath a dedicated owner-only directory with a sibling advisory lock. The store contains access and refresh tokens plus issuer/client binding and usability state. Windows persistence fails closed before filesystem access.

### Spoofing

* Every stored issuer is validated as an origin-only HTTPS URL (or explicit loopback HTTP), and each locked reread must match the already trusted issuer and client ID before refresh or API use.

### Tampering

* Store and lock opens use `O_NOFOLLOW`; opened descriptors must be regular files owned by the effective user without group or world permissions.
* Writes validate the schema, use mode `0600`, fsync file content, atomically replace the store, and fsync the parent directory. Cross-process updates require an advisory lock.

### Repudiation

* Profiles record obtained and expiry timestamps, scopes, issuer, client ID, and usability. The store is not a signed audit record and must not be treated as one.

### Information Disclosure

* The dedicated POSIX directory is owner-only and store/lock files use mode `0600`. Status output excludes access and refresh tokens.
* Same-uid malware remains outside the defended boundary (G-INF-3).

### Denial of Service

* Missing locking primitives fail closed. Corrupt schemas, unsafe permissions, and symlinks fail before credential use. Windows OAuth persistence is unavailable until a protected backend exists.
* Cross-process lock acquisition is non-blocking with a finite deadline, so a stalled lock holder surfaces a typed timeout instead of hanging the CLI. Only lock-contention errors are retried; other locking failures propagate unchanged. The bound covers acquisition, not in-process waiting or work performed while the lock is held.
* A provider/local refresh-commit uncertainty can require re-login (G-DOS-1).

### Elevation of Privilege

* Profiles cannot change the trusted issuer/client binding during a locked refresh. GitLab remains the authority for granted scopes; local storage cannot broaden them.

### Risk Rating

| Threat                            | Likelihood | Impact | Residual Risk | Status                                       |
|-----------------------------------|------------|--------|---------------|----------------------------------------------|
| Cross-user POSIX store disclosure | Low        | High   | Low           | Mitigated (owner-only directory and files)   |
| Unsupported Windows persistence   | Low        | High   | Low           | Mitigated (fails closed before store access) |
| Symlink or replacement tampering  | Low        | High   | Low           | Mitigated (no-follow + descriptor checks)    |
| Same-uid credential access        | Med        | High   | Med           | Accepted boundary (G-INF-3)                  |
| Refresh commit uncertainty        | Low        | Med    | Med           | Fail closed; re-login (G-DOS-1)              |

## Enterprise Readiness Gaps

The following are known limitations recorded so operators can make informed deployment decisions. Severity ratings are the project's own assessment and are not equivalent to a CVSS score.

| Id      | Gap                                                                                                                                                                                  | Severity        | Status                                                                                                        |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------|---------------------------------------------------------------------------------------------------------------|
| G-REP-1 | The write-ahead attempt is fail-closed, but the outcome is best-effort and the operator-supplied file is not signed or append-only.                                                  | Repudiation-Med | By design; integrate with host telemetry for tamper-evident logging.                                          |
| G-INF-1 | The CLI prints redacted non-JSON response bodies to stdout/stderr for usability; redaction is a broad regex backstop that may over- or under-cover novel secret formats.             | InfoDisc-Low    | Accepted; monitor and extend `_redact` as new secret formats appear.                                          |
| G-INF-2 | `_REDACT_KEYS` enumerates known credential field names; a novel or vendor-specific field name is masked only if it also matches the header, `Bearer`/`Basic`, or query-string rules. | InfoDisc-Low    | Accepted; extend `_REDACT_KEYS` as new credential shapes appear. `tests/test_gitlab_helpers.py` pins the set. |
| G-INF-3 | Same-uid processes can read the OAuth store despite owner-only filesystem permissions.                                                                                               | InfoDisc-Med    | Accepted workstation boundary; evaluate an OS keyring separately where policy requires it.                    |
| G-DOS-1 | A crash or malformed successful response between provider refresh rotation and durable local commit can invalidate the retained refresh token and require re-login.                  | DoS-Med         | Fail closed by marking uncertain profiles unusable; re-run login.                                             |
| G-EOP-1 | Local logout cannot revoke OAuth authorization, and the skill cannot revoke a leaked OAuth access token, refresh token, or legacy PAT.                                               | EoP-Med         | Upstream control; rotate or revoke at the GitLab instance on suspicion of compromise.                         |
| G-SUP-1 | Python dependencies are declared in `pyproject.toml` but transitive hashes are not pinned and no SBOM is published; transport/subprocess/redaction fuzz coverage is partial.         | SupplyChain-Med | Tracked at the repository level.                                                                              |
| G-TLS-1 | No certificate pinning for the GitLab origin; TLS validation depends entirely on the system trust store.                                                                             | InfoDisc-Low    | Operator-acceptable for a managed GitLab endpoint; documented for customers whose policy mandates pinning.    |

For an active issue tracker entry covering these gaps, see [microsoft/hve-core#2225](https://github.com/microsoft/hve-core/issues/2225).

## References

* [STRIDE Threat Model](https://learn.microsoft.com/azure/security/develop/threat-modeling-tool-threats)
* [OWASP Top 10 for Web Applications](https://owasp.org/www-project-top-ten/)
* [GitLab REST API](https://docs.gitlab.com/ee/api/rest/)
* [Repository security model](../../../../docs/security/security-model.md)

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
