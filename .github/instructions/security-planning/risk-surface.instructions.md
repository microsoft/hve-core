---
description: "STRIDE-based risk surface analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Risk Surface

Systematic STRIDE-based threat identification applied per operational bucket. This guidance drives Phase 4 of the security planning workflow, building on bucket analyses from Phase 2 and standards mappings from Phase 3. Each bucket receives a structured threat assessment producing threat tables with risk ratings and mitigation strategies linked to standards controls.

## STRIDE Methodology

Apply all six STRIDE categories to each component within a bucket. Evaluate categories in the priority order specified per bucket, then check remaining categories.

### Spoofing

Pretending to be something or someone else.

* Guiding question: "Can an attacker impersonate a user, service, or component?"
* Commonly affected buckets: identity/auth, web, messaging
* Typical mitigations: strong authentication, certificate validation, mutual TLS, token verification

### Tampering

Modifying data or code without authorization.

* Guiding question: "Can data be modified in transit or at rest?"
* Commonly affected buckets: data, build, devops, messaging
* Typical mitigations: integrity checks, digital signatures, access controls, immutable infrastructure

### Repudiation

Denying an action occurred without proof to the contrary.

* Guiding question: "Can a user deny performing an action?"
* Commonly affected buckets: data, messaging, identity/auth
* Typical mitigations: audit logging, non-repudiation controls, tamper-proof logs, centralized log aggregation

### Information Disclosure

Exposing data to unauthorized parties.

* Guiding question: "Can sensitive data leak to unauthorized parties?"
* Commonly affected buckets: data, web, build, infra
* Typical mitigations: encryption at rest and in transit, access controls, data classification, secure defaults

### Denial of Service

Making a resource unavailable to legitimate users.

* Guiding question: "Can the system be made unavailable?"
* Commonly affected buckets: infra, web, messaging
* Typical mitigations: rate limiting, resource quotas, redundancy, auto-scaling, circuit breakers

### Elevation of Privilege

Gaining unauthorized access levels beyond assigned permissions.

* Guiding question: "Can an attacker escalate their permissions?"
* Commonly affected buckets: identity/auth, infra, devops
* Typical mitigations: least privilege, RBAC/ABAC, privilege separation, input validation, boundary enforcement

### AI-Specific STRIDE Extensions

> [!NOTE]
> The following AI-specific guiding questions apply only when `raiEnabled` is true. Add these questions to each STRIDE category during threat analysis of ai-ml bucket components and AI-integrated components in other buckets.

| STRIDE Category        | AI-Specific Question                                                      |
|------------------------|---------------------------------------------------------------------------|
| Spoofing               | Can adversarial inputs cause the model to impersonate legitimate outputs? |
| Spoofing               | Can model identity be spoofed in multi-agent systems?                     |
| Tampering              | Can training data be poisoned to alter model behavior?                    |
| Tampering              | Can inference inputs be crafted to produce targeted misclassification?    |
| Repudiation            | Can model decisions be traced to specific inputs and model versions?      |
| Repudiation            | Are AI-generated outputs attributed and logged?                           |
| Information Disclosure | Can model weights or training data be extracted through query patterns?   |
| Information Disclosure | Does the model memorize and leak sensitive training data?                 |
| Denial of Service      | Can adversarial inputs cause excessive compute (model DoS)?               |
| Denial of Service      | Can prompt injection cause resource exhaustion in LLM pipelines?          |
| Elevation of Privilege | Can prompt injection bypass content safety guardrails?                    |
| Elevation of Privilege | Can agent tool access be escalated through prompt manipulation?           |

## Per-Bucket Threat Analysis Protocol

Follow this 6-step process for each operational bucket identified in Phase 2.

1. Review the bucket analysis: components, data flows, integration points, and external dependencies.
2. For each component, evaluate all 6 STRIDE categories starting with the bucket's priority categories.
3. Identify threats with clear descriptions of the attack vector and affected component.
4. Assess likelihood (High/Medium/Low) and impact (High/Medium/Low) collaboratively with the user. Mark unassessed values with ❓ until the user confirms or adjusts.
5. Calculate the risk rating using the risk matrix defined in the Threat Table Format section.
6. Propose mitigations linked to specific standards controls from the Phase 3 mappings.

### Bucket-Specific STRIDE Focus Areas

Prioritize these categories first per bucket, then evaluate remaining categories:

* infra: Tampering (config drift), Denial of Service (resource exhaustion), Elevation of Privilege (misconfiguration)
* devops/platform-ops: Tampering (pipeline poisoning), Elevation of Privilege (secret exposure), Spoofing (supply chain attacks)
* build: Tampering (dependency substitution), Information Disclosure (artifact leakage)
* messaging: Spoofing (message injection), Tampering (message modification), Repudiation (unlogged events)
* data: Information Disclosure (data breach), Tampering (unauthorized writes), Repudiation (audit gaps)
* web/UI/reporting: Spoofing (session hijacking), Tampering (XSS/CSRF), Information Disclosure (input validation failures)
* identity/auth: Spoofing (credential theft), Elevation of Privilege (privilege escalation), Repudiation (auth log gaps)
* ai-ml: Tampering (data poisoning, adversarial inputs), Information Disclosure (model extraction, training data leakage), Elevation of Privilege (prompt injection, tool escalation). Applies only when `raiEnabled` is true.

## Threat Table Format

Record each threat using the following table structure per bucket.

### Threat ID Pattern

Use `T-{BUCKET_ABBREV}-{NNN}` where the abbreviation matches the bucket name in uppercase (for example, `T-INFRA-001`, `T-DATA-003`, `T-BUILD-002`).

When `raiEnabled` is true, AI-specific threats in existing buckets use `T-{BUCKET_ABBREV}-AI-{NNN}` (for example, `T-DATA-AI-001`, `T-WEB-AI-002`). The `T-RAI-{NNN}` convention is reserved for the RAI Planner and is not used by the Security Planner.

### ML Model STRIDE Matrix

> [!NOTE]
> This matrix applies only when `raiEnabled` is true. Use it as a quick reference for common AI/ML threats when populating threat tables.

| Component          | S                   | T                 | R               | I                 | D                  | E                    |
|--------------------|---------------------|-------------------|-----------------|-------------------|--------------------|----------------------|
| Training Pipeline  | —                   | Data Poisoning    | Lineage Gaps    | Data Leakage      | Compute Exhaustion | Pipeline Injection   |
| Inference Endpoint | Model Impersonation | Adversarial Input | Attribution Gap | Model Extraction  | Query Flooding     | Prompt Injection     |
| RAG Pipeline       | Source Spoofing     | Context Poisoning | Source Gap      | Data Leakage      | Index Corruption   | Context Manipulation |
| Agent Framework    | Identity Spoofing   | Tool Manipulation | Action Gap      | Conversation Leak | Resource Abuse     | Tool Escalation      |

### Table Columns

```markdown
| ID          | STRIDE          | Description                           | Component      | Likelihood | Impact | Risk     | Mitigation                       | Standards             |
|-------------|-----------------|---------------------------------------|----------------|------------|--------|----------|----------------------------------|-----------------------|
| T-INFRA-001 | Tampering       | Config drift via unauthorized changes | IaC pipeline   | High       | High   | Critical | Immutable infra, drift detection | CIS 5.1, NIST CM-3    |
| T-DATA-003  | Info Disclosure | Unencrypted PII in backup storage     | Backup service | Medium     | High   | High     | Encrypt backups, access controls | OWASP A02, NIST SC-28 |
```

### Risk Matrix

Calculate risk from the combination of Likelihood and Impact:

* High x High = **Critical**
* High x Medium or Medium x High = **High**
* Medium x Medium = **Medium**
* Low x any or any x Low = **Low**

### Assessment Guidance

Likelihood and Impact are assessed collaboratively with the user during Phase 4 questioning. Use ❓ for unassessed values. Each threat must have at least one mitigation strategy, and each mitigation should reference at least one standards control.

## Data Flow Analysis

For each bucket, document data flows using text-based format to identify trust boundaries and sensitive data paths.

### Data Flow Template

```markdown
### {Bucket} Data Flows

**Inbound:**
- {source} → {component} via {protocol} [trust: {internal|external|mixed}]

**Internal:**
- {component_a} → {component_b}: {data_description}

**Outbound:**
- {component} → {destination} via {protocol} [trust: {level}]

**Trust Boundaries:**
- {boundary_description}

**Sensitive Paths:**
- {path_description}: {classification}
```

### Flow Documentation Guidance

For each bucket, capture:

* Data entering the bucket: sources, protocols, and trust level (internal, external, or mixed)
* Data processed within the bucket: transformations, storage mechanisms, and intermediate formats
* Data leaving the bucket: destinations, protocols, and downstream trust level
* Trust boundaries crossed between buckets or external systems
* Sensitive data paths requiring encryption, access controls, or extra audit coverage

Use data flow information to identify threats at trust boundaries and integration points where multiple buckets interact.

### AI Element Types

> [!NOTE]
> The following AI-specific DFD element types apply only when `raiEnabled` is true. Include these in data flow diagrams for ai-ml bucket components.

1. ML Model — trained model artifact
2. Training Pipeline — data to model workflow
3. Inference Endpoint — prediction API
4. Vector Store — embedding database
5. RAG Pipeline — retrieval and generation workflow
6. Agent Orchestrator — multi-step LLM agent
7. Content Filter — input and output guardrail
8. Model Registry — artifact storage

### AI Trust Boundaries

> [!NOTE]
> The following AI-specific trust boundaries apply only when `raiEnabled` is true. Evaluate these boundaries during data flow analysis for ai-ml and AI-integrated components.

1. Training to Inference — model deployment boundary
2. User Input to LLM Context — prompt injection boundary
3. Model to External Tools — agent tool access boundary
4. Embedding Pipeline to Vector Store — data ingestion boundary
5. Model Output to Application Logic — output handling boundary

## Summary Format

After analyzing all buckets, produce a risk surface summary.

### Required Summary Contents

* Total threats by STRIDE category (table or list with counts per category)
* Risk distribution: counts for Critical, High, Medium, and Low ratings
* Top 5 highest-risk threats across all buckets with threat ID, description, and risk rating
* Unmapped threats: threats without clear standards references or proposed mitigations
* Coverage gaps: buckets or components where one or more STRIDE categories have no identified threats
