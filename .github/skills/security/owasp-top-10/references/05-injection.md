---
title: 'A05: Injection'
description: OWASP Web Top 10 reference for injection vulnerabilities including SQL, XSS, command injection, and related attack patterns
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - web
  - injection
  - sql-injection
  - xss
  - security
estimated_reading_time: 5
---

# 05 Injection

Identifier: A05:2025
Category: Input Validation

## Description

Injection vulnerabilities occur when an application sends untrusted user input to an interpreter
and the interpreter executes parts of that input as commands.
This happens when user-supplied data is not validated, filtered, or sanitized, when dynamic
queries or non-parameterized calls are used without context-aware escaping, when hostile data is
used within ORM search parameters, or when hostile data is directly concatenated into dynamic
queries, commands, or stored procedures.
Common injection types include SQL, NoSQL, OS command, ORM, LDAP, Expression Language, and
cross-site scripting.
Injection is one of the most tested vulnerability categories, with 100% of applications tested
for some form of injection, and it has the greatest number of CVEs of any category.

## Risk

* Full database compromise through SQL injection enabling unauthorized data access, modification,
  or deletion.
* Remote code execution on the server through OS command injection.
* Cross-site scripting enabling session hijacking, credential theft, and defacement.
* LDAP injection enabling authentication bypass and directory information disclosure.
* ORM injection enabling unauthorized data extraction through manipulated query parameters.
* Server-side template injection enabling arbitrary code execution within the application context.
* Stored injection attacks that execute against all users who access the compromised data.

## Vulnerability checklist

* User-supplied data is not validated, filtered, or sanitized before processing.
* Dynamic queries or non-parameterized calls are used without context-aware escaping.
* Hostile data is used within ORM search parameters to extract additional records.
* Hostile data is directly concatenated into SQL queries, OS commands, or LDAP queries.
* User-supplied structure names such as table names or column names are used in dynamic queries.
* The application does not use parameterized interfaces or safe APIs that avoid interpreter use.
* Source code review and automated testing (SAST, DAST, IAST) are not integrated into the
  CI/CD pipeline.

## Prevention controls

1. Use safe APIs that provide parameterized interfaces or migrate to Object Relational Mapping
   tools to avoid using the interpreter directly.
2. Use positive server-side input validation for all user-supplied data.
3. Escape special characters using the specific escape syntax for the target interpreter for any
   residual dynamic queries.
4. Use LIMIT and other SQL controls within queries to prevent mass disclosure of records in case
   of SQL injection.
5. Integrate SAST, DAST, and IAST tools into the CI/CD pipeline to detect injection flaws before
   production deployment.
6. Avoid concatenating user input into queries even when using ORM frameworks.
7. Never use user-supplied values as SQL structure names such as table or column identifiers.

## Example attack scenarios

### Scenario A — SQL injection via parameter manipulation

An application uses untrusted data in the construction of a vulnerable SQL call:

```
String query = "SELECT * FROM accounts WHERE custID='" + request.getParameter("id") + "'";
```

An attacker modifies the `id` parameter value in the browser to send `' OR '1'='1`:

```
http://example.com/app/accountView?id=' OR '1'='1
```

This changes the meaning of the query to return all records from the accounts table.

### Scenario B — ORM injection

An application uses Hibernate Query Language but constructs queries by concatenating user input:

```
Query HQLQuery = session.createQuery("FROM accounts WHERE custID='" + request.getParameter("id") + "'");
```

An attacker supplies `' OR custID IS NOT NULL OR custID='` which bypasses the filter and returns
all accounts.
While HQL has fewer dangerous functions than raw SQL, unauthorized data access still occurs.

### Scenario C — OS command injection

An application passes user input directly to an OS command without sanitization:

```
String cmd = "nslookup " + request.getParameter("domain");
Runtime.getRuntime().exec(cmd);
```

An attacker supplies `example.com; cat /etc/passwd` to execute arbitrary commands on the server.

## Detection guidance

* Review source code for dynamic query construction that concatenates user input.
* Run automated SAST scans to identify injection-prone code patterns.
* Execute DAST scans against all application endpoints with injection payloads.
* Fuzz all parameters, headers, URLs, cookies, and data inputs for injection responses.
* Inspect parameterized query usage to verify that parameters are not bypassed through
  concatenation.
* Monitor application logs for SQL errors, command execution failures, or unexpected query
  patterns.

## Remediation

* Replace all dynamic query construction with parameterized queries or safe APIs.
* Add server-side input validation to all user-supplied data entry points.
* Apply context-appropriate output encoding and escaping to all dynamic content.
* Remove or replace any code that concatenates user input into interpreter commands.
* Deploy WAF rules to block common injection patterns as an interim measure while code is
  remediated.
* Re-test all remediated endpoints with injection payloads to confirm the fix.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
