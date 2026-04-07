---
title: 'A01: Broken Access Control'
description: OWASP Web Top 10 reference for broken access control vulnerabilities including privilege escalation and unauthorized resource access
---

# 01 Broken Access Control

Identifier: A01:2025
Category: Access Control

## Description

Broken access control occurs when an application fails to enforce policies that prevent users from
acting outside their intended permissions.
This vulnerability allows unauthorized information disclosure, modification or destruction of data,
or performing business functions beyond the user's authorized limits.
Common manifestations include violation of the principle of least privilege, bypassing access
control checks through URL parameter tampering or API request modification, insecure direct object
references, missing access controls on API endpoints, elevation of privilege, metadata
manipulation of tokens and cookies, and CORS misconfiguration.
Access control weaknesses are pervasive across web applications, with 100% of tested applications
exhibiting some form of this vulnerability.

## Risk

* Unauthorized access to sensitive data belonging to other users or the organization.
* Modification or destruction of records the attacker should not be able to reach.
* Elevation of privilege from a standard user to an administrator role.
* Business logic bypass enabling actions outside the intended user workflow.
* Lateral movement across accounts through insecure direct object references.
* Server-side request forgery when access controls do not restrict internal resource access.
* Cross-site request forgery when anti-CSRF protections are absent or misconfigured.

## Vulnerability checklist

* Access is not denied by default; resources are available to anyone unless explicitly restricted.
* Access control checks can be bypassed by modifying the URL, application state, or API requests.
* Users can view or edit other users' records by supplying a different unique identifier.
* API endpoints for POST, PUT, and DELETE operations lack access control enforcement.
* A user can act as another user or gain administrator privileges without proper authentication.
* JWT tokens, cookies, or hidden fields can be tampered with to elevate privileges.
* CORS policy allows API access from unauthorized or untrusted origins.
* Authenticated pages are accessible to unauthenticated users through forced browsing.
* File metadata, backup files, or source control directories are present within web roots.

## Prevention controls

1. Deny access by default for all resources except those explicitly designated as public.
2. Implement access control mechanisms once and reuse them consistently throughout the
   application, including minimizing CORS usage.
3. Enforce record ownership in access control models rather than allowing users to create, read,
   update, or delete any record.
4. Enforce unique business limit requirements through domain models.
5. Disable web server directory listing and remove file metadata and backup files from web roots.
6. Log all access control failures and alert administrators on repeated failures.
7. Implement rate limits on API and controller access to reduce harm from automated attacks.
8. Invalidate stateful session identifiers on the server after logout and use short-lived
   stateless JWT tokens with refresh token rotation following OAuth standards.
9. Use well-established toolkits or patterns that provide simple, declarative access controls.
10. Include functional access control tests in unit and integration test suites.

## Example attack scenarios

### Scenario A — Insecure direct object reference

An application uses unverified data in a SQL call to access account information:

```
pstmt.setString(1, request.getParameter("acct"));
ResultSet results = pstmt.executeQuery( );
```

An attacker modifies the browser's `acct` parameter to send any desired account number.
The application returns the other user's data because it does not verify ownership:

```
https://example.com/app/accountInfo?acct=notmyacct
```

### Scenario B — Forced browsing to admin pages

An attacker forces the browser to target URLs that require admin rights:

```
https://example.com/app/getappInfo
https://example.com/app/admin_getappInfo
```

If an unauthenticated user can access either page, it is a flaw.
If a non-admin can access the admin page, it is a flaw.

### Scenario C — Client-side only access control

An application enforces all access control in its frontend JavaScript.
While the attacker cannot reach the admin endpoint through the browser, they bypass it entirely:

```
curl https://example.com/app/admin_getappInfo
```

The server returns the admin page because it does not enforce server-side access controls.

## Detection guidance

* Review application code for consistent enforcement of access control checks on all endpoints.
* Test for insecure direct object references by substituting resource identifiers in requests.
* Verify that forced browsing to authenticated or privileged pages fails for unauthorized users.
* Inspect CORS configuration for overly permissive origin policies.
* Check for the presence of file metadata, backup files, and source control directories in
  web-accessible paths.
* Monitor access control failure logs for patterns indicating automated or targeted attacks.

## Remediation

* Implement server-side access control enforcement on all endpoints and resource operations.
* Remove all file metadata, backup files, and source control directories from web roots.
* Restrict CORS policies to trusted origins only.
* Add access control failure logging with alerting for repeated violations.
* Invalidate sessions on logout and enforce session timeout policies.
* Conduct access control penetration testing and remediate all identified bypasses.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
