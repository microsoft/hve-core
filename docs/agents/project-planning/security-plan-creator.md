---
title: Security Plan Creator
description: Agent that generates security assessment plans using an 8-category threat analysis framework
sidebar_position: 5
author: Microsoft
ms.date: 2026-03-07
ms.topic: tutorial
---

The Security Plan Creator generates security assessment plans by applying an 8-category threat analysis framework to your project architecture. It walks through scope definition, threat analysis, risk assessment, mitigation planning, and plan generation to produce a structured security document.

> [!IMPORTANT]
> This agent is an assistive tool for security planning. Its output supports but does not replace professional security review, penetration testing, or compliance auditing.

## Workflow

The agent follows a 5-phase process:

### Phase 1: Blueprint Selection

Define the systems, boundaries, and compliance requirements under assessment. The agent identifies the architecture scope and selects applicable security blueprints based on the technology stack.

### Phase 2: Architecture Analysis

Analyze the project's infrastructure, code patterns, and deployment model to map the attack surface. The agent examines existing security controls and identifies gaps.

### Phase 3: Threat Assessment

Apply the 8-category threat framework to evaluate risks across all security dimensions. Each category receives a structured assessment with identified threats, affected components, and severity ratings.

### Phase 4: Security Plan Generation

Propose controls and countermeasures organized by threat category. Each mitigation includes implementation guidance, priority level, and alignment with the four security fundamentals.

### Phase 5: Validation

Review the complete plan for coverage gaps, conflicting controls, and implementation feasibility. The agent cross-references mitigations against the threat assessment to verify all identified risks have corresponding responses.

## 8-Category Threat Framework

The agent evaluates security across these categories:

| Category                             | Code | Focus Area                                                  |
|--------------------------------------|------|-------------------------------------------------------------|
| DevOps Security                      | DS   | Pipeline integrity, supply chain, artifact signing          |
| Network Security                     | NS   | Segmentation, traffic filtering, DDoS protection            |
| Privileged Access                    | PA   | Admin controls, just-in-time access, break-glass procedures |
| Identity Management                  | IM   | Authentication, authorization, federation                   |
| Data Protection                      | DP   | Encryption, classification, lifecycle management            |
| Posture and Vulnerability Management | PV   | Scanning, patching, configuration baselines                 |
| Endpoint Security                    | ES   | Device compliance, runtime protection, isolation            |
| Governance and Strategy              | GS   | Policy frameworks, risk management, compliance mapping      |

Each category maps to one or more of the four security fundamentals: Confidentiality, Integrity, Availability, and Privacy.

## Session Persistence

The agent tracks plan progress in markdown files under `.copilot-tracking/`. Security plan outputs are written to `security-plan-outputs/` using the template at `docs/templates/security-plan-template.md` (135 lines).

## Collection Membership

> [!NOTE]
> The Security Plan Creator agent source is located in `.github/agents/security-planning/` as part of the security-planning collection. It is documented here under Project Planning because security assessment is a core project planning activity.

## How to Use

### Option 1: Prompt Shortcut

```text
Create a security plan for the payment processing service in
src/services/payment/. The service handles credit card transactions
via Stripe API and stores transaction records in Azure SQL.
Scope:
- PCI DSS compliance requirements for card-present and card-not-present flows
- Data encryption at rest and in transit for cardholder data
- Access control for the payment admin dashboard
- Incident response procedures for potential data breaches
Focus on the Data Protection (DP) and Identity Management (IM) categories.
Output using the template at docs/templates/security-plan-template.md.
```

```text
Assess threats for the API gateway and backend services defined in
infra/bicep/api-gateway.bicep and k8s/services/. The gateway handles
5,000 requests/second with JWT authentication via Azure AD B2C.
Evaluate:
- Network Security (NS): DDoS protection, WAF rules, rate limiting
- Identity Management (IM): token validation, scope enforcement, API key rotation
- DevOps Security (DS): pipeline integrity for the gateway deployment in .github/workflows/
- Posture and Vulnerability (PV): dependency scanning results and patch cadence
Include severity ratings for each identified threat.
```

```text
Generate a security assessment focused on identity management and
data protection for our multi-tenant SaaS platform. Tenants are
isolated at the database level (Azure SQL elastic pools) with
shared compute (AKS). Authentication uses Azure AD B2C with custom
policies in infra/b2c-policies/.
Assess:
- Tenant isolation boundaries and cross-tenant data leakage vectors
- Token lifecycle management (refresh, revocation, session timeout)
- Data classification and encryption for tenant-specific PII
- Privileged access controls for support engineers accessing tenant data
Compliance context: SOC 2 Type II and GDPR for EU tenants.
```

### Option 2: Direct Agent

Start a Copilot Chat session and mention the agent:

```text
@security-plan-creator Evaluate the security posture for the customer
data platform. Architecture: React SPA frontend deployed to Azure Static
Web Apps, .NET 8 backend API on AKS, Azure SQL and Blob Storage for
persistence. Authentication via Azure AD with MSAL.js.
Scope:
- Full 8-category threat assessment across the platform
- Map each finding to the four security fundamentals (C, I, A, P)
- Prioritize mitigations by implementation effort and risk reduction
- Cross-reference against our existing controls in infra/security/
Compliance: HIPAA for healthcare tenant data, SOC 2 for all tenants.
Output the plan to security-plan-outputs/ using the standard template.
```

The agent begins with Blueprint Selection, gathering information about your architecture and compliance requirements before proceeding through threat analysis.

### Option 3: Category Focus

Narrow the assessment to specific threat categories from the 8-category framework:

```text
@security-plan-creator Assess the DevOps Security (DS) and Privileged
Access (PA) categories for our CI/CD pipeline. The pipeline is defined
in .github/workflows/ with 12 workflows deploying to 3 environments
(dev, staging, production).
Evaluate:
- Pipeline integrity: unsigned actions, mutable tags, missing hash pinning
- Secret management: rotation cadence, scope of GITHUB_TOKEN permissions
- Artifact signing: container image provenance and SBOM generation
- Break-glass procedures: emergency production access without approval chain
- Just-in-time access: Azure PIM configuration for production subscriptions
Include a severity-rated findings table with remediation priority order.
```

The agent applies only the selected categories, producing a focused plan instead of a full-spectrum assessment.

## Example Prompt

```text
Create a security plan for the customer data platform that processes
healthcare records under HIPAA requirements. The architecture:
- React frontend on Azure Static Web Apps with MSAL.js authentication
- .NET 8 backend API on AKS behind Azure API Management
- Azure SQL with TDE enabled for structured data
- Azure Blob Storage with customer-managed keys for document uploads
- Azure AD B2C for patient portal authentication

Focus on the Data Protection (DP) and Identity Management (IM) categories.
Assess:
- PHI encryption at rest and in transit across all data stores
- Access control matrix for 4 user roles (patient, provider, admin, auditor)
- Session management and token lifetime policies in B2C custom flows
- Data retention and right-to-deletion compliance for HIPAA and GDPR
- Audit logging coverage for all PHI access operations

Map each finding to the four security fundamentals (Confidentiality,
Integrity, Availability, Privacy) and include a prioritized mitigation
plan with implementation effort estimates (S/M/L).
Output using the template at docs/templates/security-plan-template.md.
```

## Tips

* ✅ Specify compliance requirements (GDPR, HIPAA, SOC 2) at invocation for targeted controls
* ✅ Focus on 2-3 threat categories per session for depth over breadth
* ✅ Use the plan output as input for professional security review and penetration testing
* ✅ Re-run after architecture changes to catch new attack surface areas
* ❌ Do not treat the output as a substitute for professional security audit
* ❌ Do not skip the Blueprint Selection phase (architecture context drives accurate threat analysis)
* ❌ Do not assess all 8 categories simultaneously for large systems (split into focused sessions)
* ❌ Do not ignore low-severity findings (they may combine into higher-risk patterns)

## Common Pitfalls

| Pitfall                              | Solution                                                                                     |
|--------------------------------------|----------------------------------------------------------------------------------------------|
| Generic threat findings              | Provide specific architecture details (tech stack, cloud provider, data types) at invocation |
| Missing compliance mappings          | Specify applicable frameworks (GDPR, HIPAA, SOC 2) during Blueprint Selection                |
| Assessment scope too broad           | Focus on 2-3 threat categories per session and iterate                                       |
| Controls conflict with each other    | Review the Validation phase output for cross-reference conflicts                             |
| Plan does not reflect recent changes | Re-run the assessment; the agent analyzes current project state                              |

## Next Steps

1. Feed security findings into an [ADR](adr-creation.md) to document security architecture decisions
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Run the security assessment after completing your [BRD or PRD](brd-prd-builders.md) to align threat analysis with documented requirements and system boundaries.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
