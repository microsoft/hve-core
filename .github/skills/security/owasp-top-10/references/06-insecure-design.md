# 06 Insecure Design

Identifier: A06:2025
Category: Architecture and Design

## Description

Insecure design is a broad category representing missing or ineffective security control design at
the architectural level.
This is distinct from implementation defects; a secure design can still have implementation
vulnerabilities, but an insecure design cannot be fixed by a perfect implementation because the
necessary security controls were never created.
The root cause is a lack of business risk profiling during the design phase and the failure to
determine what level of security design is required.
The category calls for increased use of threat modeling, secure design patterns, and reference
architectures.
Key aspects include requirements and resource management, secure design methodology, and a secure
development lifecycle with threat modeling integrated into refinement sessions.

## Risk

* Business logic bypass enabling actions outside the intended user workflow, such as bulk
  reservation abuse or scalper bot exploitation.
* Missing security controls that cannot be retroactively added through code fixes alone.
* Credential recovery mechanisms that rely on insecure methods such as knowledge-based questions.
* Insufficient tenant segregation enabling cross-tenant data access or interference.
* Missing rate limiting allowing automated abuse of business-critical functionality.
* Inadequate threat modeling resulting in unidentified attack vectors persisting through
  production.

## Vulnerability checklist

* No threat modeling is performed during the design phase of the application.
* Business requirements do not include protection requirements for confidentiality, integrity,
  availability, and authenticity of data assets.
* No secure design patterns or reference architectures are used.
* Security controls are not integrated into user stories.
* Plausibility checks are missing from application tiers.
* Unit and integration tests do not validate resistance to the threat model.
* Tenant segregation is absent or insufficient at system and network layers.
* The application uses insecure credential recovery mechanisms such as knowledge-based questions.
* No secure development lifecycle is established or followed.

## Prevention controls

1. Establish and use a secure development lifecycle with application security professionals to
   evaluate and design security and privacy controls.
2. Establish and use a library of secure design patterns or paved-road components.
3. Use threat modeling for critical application areas including authentication, access control,
   business logic, and key flows.
4. Integrate security language and controls into user stories.
5. Integrate plausibility checks at each tier of the application from frontend to backend.
6. Write unit and integration tests that validate all critical flows against the threat model,
   including both use cases and misuse cases.
7. Segregate tier layers on system and network layers depending on exposure and protection needs.
8. Segregate tenants robustly by design throughout all tiers.

## Example attack scenarios

### Scenario A — Insecure credential recovery

A credential recovery workflow includes knowledge-based questions and answers.
The questions and answers cannot be trusted as evidence of identity because multiple people may
know the answers.
An attacker answers the questions using publicly available information and resets the victim's
password.

### Scenario B — Business logic abuse

A cinema chain allows group booking discounts with a maximum of fifteen attendees before requiring
a deposit.
An attacker exploits the flow to book six hundred seats across all cinemas in a few requests,
causing massive revenue loss without making a deposit.

### Scenario C — Scalper bot exploitation

A retail e-commerce site does not implement anti-bot protections or rate limiting.
Scalper bots purchase all available high-demand inventory within seconds of release.
Legitimate customers cannot purchase the products at listed prices.

## Detection guidance

* Review the application design documentation for the presence of threat models and secure
  design artifacts.
* Verify that security requirements are documented in user stories and business requirements.
* Test business logic flows for abuse scenarios including bulk operations, rate limits, and
  state manipulation.
* Inspect tenant segregation at all tiers to confirm that cross-tenant access is not possible.
* Check credential recovery mechanisms for reliance on knowledge-based questions or other
  insecure methods.
* Review unit and integration tests for coverage of misuse cases and threat model scenarios.

## Remediation

* Conduct threat modeling for all critical application areas and implement identified controls.
* Replace insecure credential recovery mechanisms with secure alternatives such as
  multi-factor authentication or secure token-based recovery.
* Implement rate limiting and anti-bot protections on all business-critical endpoints.
* Add plausibility checks and business logic validation at each application tier.
* Ensure tenant segregation is enforced at system and network layers.
* Integrate security testing including misuse case validation into the CI/CD pipeline.
