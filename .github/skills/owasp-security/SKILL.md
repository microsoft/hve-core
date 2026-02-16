---
name: owasp-security
description: 'OWASP Top 10 security reference for web applications and LLM systems with Microsoft SDL practices - Brought to you by microsoft/hve-core'
---

# OWASP Security Reference Skill

Provides comprehensive security guidance based on the OWASP Top 10 (2021) for web applications and OWASP Top 10 for LLM Applications (2025), integrated with Microsoft Security Development Lifecycle (SDL) practices.

## Overview

This skill serves as a security reference library for code reviews, threat modeling, and secure development. The security-champion agent reads these references during security reviews. Developers can also reference this material directly when implementing security controls.

References load on demand during the appropriate review phase rather than injecting all content into every session, following a progressive disclosure model.

## Security Frameworks

### OWASP Top 10 for Web Applications

Covers the ten most critical web application security risks:

| ID  | Category                             | Primary Defense                          |
|-----|--------------------------------------|------------------------------------------|
| A01 | Broken Access Control                | Least privilege, deny by default         |
| A02 | Cryptographic Failures               | Strong algorithms, key management        |
| A03 | Injection                            | Parameterized queries, input validation  |
| A04 | Insecure Design                      | Threat modeling, secure patterns         |
| A05 | Security Misconfiguration            | Secure defaults, hardening               |
| A06 | Vulnerable and Outdated Components   | Dependency scanning, SBOM               |
| A07 | Identification and Authentication    | Session management, brute force defense  |
| A08 | Software and Data Integrity Failures | Deserialization controls, signing        |
| A09 | Logging and Monitoring Failures      | Structured logging, alerting             |
| A10 | Server-Side Request Forgery          | Allowlists, URL validation              |

Full reference with code examples: [owasp-web-applications.md](references/owasp-web-applications.md)

### OWASP Top 10 for LLM Applications (2025)

Covers security risks specific to AI/ML systems:

| ID    | Category                         | Primary Defense                              |
|-------|----------------------------------|----------------------------------------------|
| LLM01 | Prompt Injection                | Input validation, output schemas, boundaries |
| LLM02 | Sensitive Information Disclosure | Data sanitization, PII detection            |
| LLM03 | Supply Chain                    | Model provenance, dependency management      |
| LLM04 | Data and Model Poisoning        | Data validation, provenance tracking         |
| LLM05 | Improper Output Handling        | Context-aware encoding, sandboxing           |
| LLM06 | Excessive Agency                | Least privilege, human-in-the-loop           |
| LLM07 | System Prompt Leakage           | Externalize secrets, architecture controls   |
| LLM08 | Vector and Embedding Weaknesses | Permission-aware search, tenant isolation    |
| LLM09 | Misinformation                  | RAG grounding, fact verification             |
| LLM10 | Unbounded Consumption           | Rate limiting, token limits                  |

Full reference with code examples: [owasp-llm-applications.md](references/owasp-llm-applications.md)

### Microsoft SDL Practices

Ten practices that inform secure development across the lifecycle:

1. Establish security standards, metrics, and governance
2. Require proven security features, languages, and frameworks
3. Perform security design review and threat modeling
4. Define and use cryptography standards
5. Secure the software supply chain
6. Secure the engineering environment
7. Perform security testing
8. Ensure operational platform security
9. Implement security monitoring and response
10. Provide security training

## Quick-Reference Checklists

### Design Review Checklist

* Threat model covers all system components and data flows
* Trust boundaries are documented with Zero Trust assumptions
* Authentication and authorization architecture uses established patterns
* Data classification identifies sensitive data and protection requirements
* Cryptography uses approved standards (AES-256, Argon2/bcrypt, TLS 1.2+)

### Code Review Checklist

* User input is validated and sanitized before processing
* Database queries use parameterized statements
* Secrets are externalized to environment variables or vaults
* Output is context-encoded (HTML, SQL, shell, JavaScript)
* Dependencies are pinned with integrity verification
* Error handling does not expose internal details

### Build and Deploy Checklist

* CI/CD pipeline dependencies are pinned with SHA verification
* Container images use minimal base images with no root execution
* Security headers are configured (CSP, HSTS, X-Content-Type-Options)
* Debug features and verbose logging are disabled in production
* Code signing verifies artifact integrity

### Runtime Checklist

* Structured logging captures security events without sensitive data
* Rate limiting protects authentication and API endpoints
* Monitoring alerts on anomalous access patterns
* Incident response procedures are documented and tested
* Platform security baselines are enforced and audited

## When to Use Each Reference

### Web application reviews

Read [owasp-web-applications.md](references/owasp-web-applications.md) when reviewing traditional web applications, APIs, microservices, or any server-side code handling user input.

### LLM application reviews

Read [owasp-llm-applications.md](references/owasp-llm-applications.md) when reviewing code that integrates with LLMs, builds agent frameworks, implements RAG pipelines, or handles AI-generated content.

### Combined reviews

Read both references when an application uses LLMs within a web application context, such as a chatbot API, an AI-powered search feature, or a code generation service.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
