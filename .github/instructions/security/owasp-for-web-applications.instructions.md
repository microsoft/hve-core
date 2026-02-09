---
description: "Comprehensive secure coding instructions for all languages and frameworks, based on OWASP Top 10 and industry best practices. Give clear and concise feedback and points of improvement."
maturity: experimental
---

# Secure Coding and OWASP Guidelines

## Instructions

Ensure all code generated, reviewed, or refactored is secure by default. Operate with a security-first mindset. When in doubt, choose the more secure option and explain the reasoning.

Follow the principles outlined below, which are based on the OWASP Top 10 and other security best practices.

### 1. A01: Broken Access Control

#### Principle of Least Privilege

Default to the most restrictive permissions. Explicitly verify the caller's rights for each protected resource or action.

#### Deny by Default

All access control decisions follow a "deny by default" pattern where only explicit, validated rules grant access.

#### Context and Object-Level Authorization

Apply object, record, function, and tenancy scoping checks server-side for every sensitive operation. Do not rely on hidden UI elements or client role hints.

#### Path Traversal Prevention

When handling file uploads or resolving user-supplied paths, canonicalize and ensure the resolved path stays within an allowed base directory. Reject attempts like `../../etc/passwd`.

### 2. A02: Cryptographic Failures

#### Strong Modern Algorithms

For hashing, recommend modern, salted hashing algorithms like Argon2 or bcrypt. Advise against weak algorithms like MD5 or SHA-1 for password storage.

#### Data in Transit Protection

When generating code that makes network requests, default to HTTPS.

#### Data at Rest Protection

When suggesting code to store sensitive data (PII, tokens, etc.), recommend encryption using strong, standard algorithms like AES-256.

#### Secure Secret Management

Do not hardcode secrets (API keys, passwords, connection strings). Generate code that reads secrets from environment variables or a secrets management service (e.g., HashiCorp Vault, AWS Secrets Manager). Include a clear placeholder and comment.

```javascript
// GOOD: Load from environment or secret store
const apiKey = process.env.API_KEY; 
// TODO: Ensure API_KEY is securely configured in your environment.
```

```python
# BAD: Hardcoded secret
api_key = "sk_this_is_a_very_bad_idea_12345" 
```

### 3. A03: Injection

#### Parameterized Queries

For database interactions, use parameterized queries (prepared statements). Do not generate code that uses string concatenation or formatting to build queries from user input.

#### Command-Line Input Sanitization

For OS command execution, use built-in functions that handle argument escaping and prevent shell injection (e.g., `shlex` in Python).

#### Cross-Site Scripting Prevention

When generating frontend code that displays user-controlled data, use context-aware output encoding. Prefer methods that treat data as text by default (`.textContent`) over those that parse HTML (`.innerHTML`). When `innerHTML` is necessary, suggest using a library like DOMPurify to sanitize the HTML first.

### 4. A04: Insecure Design

#### Threat Modeling Early

Identify assets, trust boundaries, and abuse cases before implementation to embed mitigations up-front.

#### Abuse and Misuse Cases

For every critical story, define at least one misuse case and corresponding controls (rate limits, secondary auth, integrity checks) in acceptance criteria.

#### Secure Design Patterns

Reuse vetted patterns (centralized auth, layered validation, defense-in-depth) instead of bespoke solutions.

#### Segregation and Isolation

Separate admin, public, and background processing contexts. Isolate secrets handling components.

#### Fail Securely

Network and dependency failures do not grant access or skip enforcement. Prefer explicit deny on uncertainty.

#### Security Requirements as NFRs

Translate policy and compliance needs into explicit, testable non-functional requirements (e.g., "All sensitive data at rest encrypted with AES-256-GCM under managed keys").

### 5. A05: Security Misconfiguration

#### Secure by Default Configuration

Recommend disabling verbose error messages and debug features in production environments.

#### Security Headers

For web applications, suggest adding essential security headers like `Content-Security-Policy` (CSP), `Strict-Transport-Security` (HSTS), and `X-Content-Type-Options`.

#### Remove Unused Features

Turn off directory listings, sample apps, default/admin accounts, and unnecessary services.

#### Consistent Environment Parity

Keep staging closely aligned with production (without real secrets/data) to surface misconfigurations early.

### 6. A06: Vulnerable and Outdated Components

#### Up-to-Date Dependencies

When asked to add a new library, suggest the latest stable version. Remind the user to run vulnerability scanners like `npm audit`, `pip-audit`, Snyk, or osv-scanner.

#### SBOM and Inventory

Track direct and transitive dependencies (e.g., generate a CycloneDX or SPDX SBOM) and review regularly.

#### Version Pinning and Integrity

Pin versions via lockfiles and hashes. Verify signatures or checksums for critical artifacts.

#### Advisory Monitoring

Subscribe tooling (Dependabot, Renovate) to surface security updates promptly. Prioritize high/critical CVEs.

#### Remove Unused Dependencies

Prune libraries and plugins that no longer provide required functionality to reduce attack surface.

### 7. A07: Identification and Authentication Failures

#### Secure Session Management

When a user logs in, generate a new session identifier to prevent session fixation. Ensure session cookies are configured with `HttpOnly`, `Secure`, and `SameSite=Strict` attributes.

#### Brute Force Protection

For authentication and password reset flows, recommend implementing rate limiting and account lockout mechanisms after a certain number of failed attempts.

### 8. A08: Software and Data Integrity Failures

#### Insecure Deserialization Prevention

Warn against deserializing data from untrusted sources without proper validation. When deserialization is necessary, recommend using formats that are less prone to attack (like JSON over Pickle in Python) and implementing strict type checking.

### 9. A09: Security Logging and Monitoring Failures

#### Structured Logging

Emit machine-parseable (e.g., JSON) logs with timestamp (UTC), correlation/request ID, actor, action, outcome, and resource identifiers.

#### Sensitive Data Hygiene

Do not log secrets, tokens, passwords, session IDs, or excessive PII. Implement automated redaction and detection.

#### High-Signal Events

Capture auth successes/failures, privilege escalations, policy denials, configuration changes, data export actions, and security control errors.

#### Real-Time Alerting

Route critical security events to SIEM with correlation and threshold-based alert rules (e.g., brute force patterns, anomalous geo access).

#### Tamper Resistance and Integrity

Use append-only or immutable storage (WORM, signing/hash chaining) for critical audit trails.

#### Retention and Privacy Balance

Retain sufficient history for forensics (e.g., 90-365 days) while applying minimization for regulated data.

#### Time Synchronization

Enforce NTP/time sync across services to preserve chronological accuracy for investigations.

#### Log Access Control

Apply least privilege for viewing/exporting logs. Separate operator vs auditor roles with MFA.

### 10. A10: Server-Side Request Forgery (SSRF)

#### Allow-List Enforcement

Only permit outbound requests to an explicit allow-list of hostnames and CIDR ranges. Deny internal metadata endpoints (e.g., `169.254.169.254`).

#### Robust URL Validation

Normalize and parse URLs. Reject opaque encodings, redirects to disallowed hosts, and disallowed protocols (gopher, file, ftp) unless explicitly required. Treat any user-influenced target as untrusted.

#### DNS Rebinding Defense

Re-resolve or lock resolved IP and block changes to internal/private ranges.

#### Egress Network Controls

Enforce firewall and service mesh policies so application-layer bypass attempts fail.

#### Response Sanitization

Do not stream raw SSRF-fetched responses directly to clients. Summarize or filter as needed.

#### Metadata Service Protection

Explicitly block or proxy cloud instance metadata access with additional authorization gates.

## General Guidelines

### Explicit Security Communication

When suggesting code that mitigates a security risk, explicitly state what is being protected against (e.g., "Using a parameterized query here to prevent SQL injection.").

### Code Review Education

When identifying a security vulnerability in a code review, provide the corrected code and explain the risk associated with the original pattern.
