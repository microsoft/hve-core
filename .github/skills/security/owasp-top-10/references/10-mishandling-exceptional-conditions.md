---
title: 'A10: Mishandling of Exceptional Conditions'
description: OWASP Web Top 10 reference for mishandling exceptional conditions including improper error handling and uncontrolled resource consumption
---

# 10 Mishandling of Exceptional Conditions

Identifier: A10:2025
Category: Error Handling

## Description

Mishandling of exceptional conditions occurs when applications fail to prevent, detect, and
respond to unusual and unpredictable situations, leading to crashes, unexpected behavior, and
security vulnerabilities.
This involves three failure modes: the application does not prevent an unusual situation from
occurring, it does not identify the situation as it happens, or it responds poorly or not at all
afterward.
Exceptional conditions can be caused by missing or incomplete input validation, late or high-level
error handling instead of handling at the function where errors occur, unexpected environmental
states such as memory or network issues, inconsistent exception handling, or exceptions that are
not handled at all, leaving the system in an unknown state.
The resulting vulnerabilities include logic bugs, overflows, race conditions, fraudulent
transactions, and issues with memory, state, resource, timing, authentication, and authorization.

## Risk

* Denial of service through resource exhaustion when exceptions do not properly release allocated
  resources.
* Sensitive data exposure through error messages that reveal system internals, stack traces, or
  database structure.
* State corruption in financial transactions when multi-step operations are not rolled back on
  failure.
* Race conditions exploitable by attackers interrupting transactions at critical points.
* Authentication and authorization bypass when error handling falls through to permissive default
  states.
* System instability from uncaught exceptions leaving the application in an unknown and
  unpredictable state.

## Vulnerability checklist

* Exceptions are caught at a high level but not handled at the functions where they occur.
* Error messages expose sensitive system information including stack traces, database structure,
  or component versions.
* Resources are not released when exceptions are thrown, leading to memory leaks or resource
  exhaustion.
* Multi-step transactions are not rolled back completely when an error occurs mid-transaction.
* Exceptional conditions are not logged or alerted on, preventing detection of ongoing attacks.
* No global exception handler exists as a safety net for unhandled exceptions.
* Error handling is implemented inconsistently across different parts of the application.
* Rate limiting, resource quotas, and throttling are not implemented to prevent exceptional
  conditions from occurring.
* Identical repeated errors are not aggregated, leading to log flooding.

## Prevention controls

1. Catch every possible error directly at the function where it occurs and handle it with a
   meaningful recovery action.
2. Implement a global exception handler as a safety net for any unhandled exceptions.
3. Ensure all transactions that throw an error are rolled back completely and fail closed.
4. Include error logging and alerting as part of every exception handling path.
5. Return generic error messages to users and log detailed error information internally.
6. Add rate limiting, resource quotas, and throttling to prevent exceptional conditions from
   occurring.
7. Aggregate identical repeated errors above a threshold into statistical summaries appended to
   the original message.
8. Implement centralized error handling so that the entire application handles exceptions
   consistently.
9. Perform strict input validation with sanitization to prevent exceptional conditions from
   reaching internal functions.
10. Execute stress, performance, and penetration testing to identify error handling weaknesses.

## Example attack scenarios

### Scenario A — Resource exhaustion through exception handling

An application catches exceptions during file uploads but does not release resources after each
exception.
Each new exception leaves resources locked or unavailable.
An attacker repeatedly triggers the exception until all resources are consumed and the
application becomes unavailable.

### Scenario B — Information disclosure through error messages

An application returns detailed database error messages to the user when an operation fails.
An attacker deliberately triggers errors to harvest system information from the error output.
The attacker uses the exposed information to craft a targeted SQL injection attack.

### Scenario C — Financial state corruption

An attacker interrupts a multi-step financial transaction through network disruption.
The transaction order is debit user account, credit destination account, log transaction.
The system does not roll back the entire transaction on failure, and the attacker exploits the
partial state to drain the user account or trigger duplicate credits.

## Detection guidance

* Review application code for exception handling coverage and consistency across all modules.
* Test error responses to verify that no sensitive system information is exposed to users.
* Monitor application logs for patterns of repeated exceptions indicating ongoing attack
  attempts.
* Verify that all multi-step transactions implement complete rollback on failure.
* Load test the application to identify resource leaks under sustained exception conditions.
* Check that a global exception handler is in place and functioning as a safety net.

## Remediation

* Implement consistent exception handling at every function that can fail, with proper resource
  cleanup.
* Deploy a global exception handler to catch and safely handle any unhandled exceptions.
* Replace all user-facing error messages with generic responses and log details internally.
* Add complete rollback logic to all multi-step transactions.
* Deploy rate limiting and resource quotas on endpoints susceptible to abuse.
* Standardize error handling across the entire application using a centralized mechanism.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
