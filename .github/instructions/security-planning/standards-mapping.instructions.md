---
description: "Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Standards Mapping

Frequently-used security standards are embedded directly in this file for immediate reference during Phase 3 of the security planning workflow. Specialized cloud frameworks (WAF and CAF) are delegated to the Researcher Subagent at runtime instead of duplicating large, version-sensitive content.

At least one standard from each embedded framework should map to every component in the security plan. The cross-reference table provides starting-point mappings by bucket; refine these during Phase 3 analysis.

## Embedded OWASP Top 10

The OWASP Top 10 (2025) covers the most critical web application security risks. At least one OWASP item must map to every web/UI/reporting and identity/auth component.

| ID       | Description                                                                                                                      |
|----------|----------------------------------------------------------------------------------------------------------------------------------|
| A01:2025 | Broken Access Control: Access restrictions not properly enforced, enabling privilege escalation or unauthorized data access.     |
| A02:2025 | Cryptographic Failures: Weak encryption, cleartext data transmission, or improper key management exposing sensitive information. |
| A03:2025 | Injection: SQL, XSS, command injection, and other untrusted-input attacks that execute unintended commands.                      |
| A04:2025 | Insecure Design: Missing threat modeling, insecure business logic, or absent security controls by design.                        |
| A05:2025 | Security Misconfiguration: Default configurations, unnecessary features enabled, or improper permission settings.                |
| A06:2025 | Vulnerable and Outdated Components: Unpatched dependencies, end-of-life software, or unsupported libraries.                      |
| A07:2025 | Identification and Authentication Failures: Weak passwords, broken session management, or missing multi-factor authentication.   |
| A08:2025 | Software and Data Integrity Failures: CI/CD pipeline compromise, unsigned updates, or insecure deserialization.                  |
| A09:2025 | Security Logging and Monitoring Failures: Insufficient audit trails, missing alerts, or inadequate incident detection.           |
| A10:2025 | Server-Side Request Forgery: Fetching remote resources without validating user-supplied URLs.                                    |

## Embedded OWASP Top 10 for LLM Applications

> [!NOTE]
> This section applies only when `raiEnabled` is true in the security plan state.

The OWASP Top 10 for LLM Applications covers security risks specific to large language models and generative AI. At least one OWASP LLM item must map to every ai-ml component.

| ID    | Description                                                                                                            |
|-------|------------------------------------------------------------------------------------------------------------------------|
| LLM01 | Prompt Injection: Crafted inputs that override model instructions, bypass guardrails, or execute unintended actions.   |
| LLM02 | Insecure Output Handling: Insufficient validation of model outputs before passing to downstream systems.               |
| LLM03 | Training Data Poisoning: Manipulation of training data to introduce backdoors, biases, or targeted misclassifications. |
| LLM04 | Model Denial of Service: Inputs crafted to consume excessive compute resources or degrade model availability.          |
| LLM05 | Supply Chain Vulnerabilities: Compromised model weights, datasets, plugins, or fine-tuning pipelines.                  |
| LLM06 | Sensitive Information Disclosure: Model outputs revealing training data, system prompts, or confidential information.  |
| LLM07 | Insecure Plugin Design: Plugins with excessive permissions, insufficient input validation, or missing access controls. |
| LLM08 | Excessive Agency: Models granted too much autonomy, scope, or access without adequate human oversight.                 |
| LLM09 | Overreliance: Uncritical dependence on model outputs without verification, leading to factual errors or security gaps. |
| LLM10 | Model Theft: Unauthorized extraction of model weights, parameters, or proprietary training data through API queries.   |

## SDL Lite Top Controls

SDL Lite provides a lightweight secure development lifecycle suitable for agent-driven security planning. These controls complement the standards-based mapping by ensuring development process coverage.

Key controls:

* Security model analysis: structured identification of threats per component (covered in Phase 4)
* Security requirements definition: explicit security criteria derived from standards mapping
* Attack surface analysis: enumeration of entry points, trust boundaries, and data flows
* Static analysis tooling: automated code scanning integrated into CI/CD pipelines
* Third-party component governance: dependency inventory, vulnerability tracking, and license compliance
* Incident response planning: detection, containment, and recovery procedures
* Security review gates: approval checkpoints at design, implementation, and deployment stages

## NIST AI RMF Subcategory Mappings

> [!NOTE]
> This section applies only when `raiEnabled` is true in the security plan state.

The NIST AI Risk Management Framework (AI RMF 1.0) organizes AI governance into four core functions. Security Planner phases map to these functions to ensure AI risk coverage.

| Security Planner Phase            | AI RMF Function  | Key Subcategories                                                                                            |
|-----------------------------------|------------------|--------------------------------------------------------------------------------------------------------------|
| Phase 1 (Scoping)                 | Govern + Map     | GV-1 (policies), MP-1 through MP-5 (context, requirements, benefits/costs, risks, impact characterization)   |
| Phase 3 (Standards Mapping)       | Govern + Measure | GV-3 (workforce diversity), MS-1 (risk metrics), MS-2 (AI system evaluation)                                 |
| Phase 4 (Security Model Analysis) | Measure          | MS-2.5 through MS-2.11 (privacy, security, resilience, explanation, bias, homogeneity, environmental impact) |
| Phase 5 (Backlog Generation)      | Manage           | MN-1 (risk prioritization), MN-2 (risk response), MN-3 (risk monitoring), MN-4 (escalation)                  |

Use these mappings to verify that the security plan addresses AI governance requirements when AI/ML components are present.

## Embedded NIST 800-53 Control Families

NIST 800-53 organizes security controls into 18 families. These are grouped into three priority tiers based on how frequently they apply across typical architectures.

### High Priority

These families apply to nearly every component:

| Family | Description                                                                                                                       |
|--------|-----------------------------------------------------------------------------------------------------------------------------------|
| AC     | Access Control: Policies, enforcement mechanisms, least-privilege principles, and account management.                             |
| AU     | Audit and Accountability: Event logging, audit review and analysis, non-repudiation, and retention.                               |
| IA     | Identification and Authentication: User and device identity verification, multi-factor authentication, and credential management. |
| SC     | System and Communications Protection: Encryption in transit and at rest, boundary protection, and network segmentation.           |
| SI     | System and Information Integrity: Patch management, malware protection, integrity monitoring, and error handling.                 |

### Medium Priority

These families apply based on component context and architecture:

| Family | Description                                                                                                               |
|--------|---------------------------------------------------------------------------------------------------------------------------|
| AT     | Awareness and Training: Security awareness programs and role-based training requirements.                                 |
| CA     | Assessment, Authorization, and Monitoring: Security assessments, authorization decisions, and continuous monitoring.      |
| CM     | Configuration Management: Baseline configurations, change control processes, and software inventory.                      |
| CP     | Contingency Planning: Backup and recovery procedures, alternate processing sites, and continuity testing.                 |
| IR     | Incident Response: Detection procedures, analysis workflows, containment strategies, and recovery actions.                |
| MA     | Maintenance: System maintenance controls, remote maintenance access, and maintenance tool oversight.                      |
| MP     | Media Protection: Media access restrictions, sanitization procedures, and transport protections.                          |
| PE     | Physical and Environmental Protection: Physical access controls, environmental monitoring, and facility protections.      |
| RA     | Risk Assessment: Risk identification, vulnerability scanning, and threat intelligence integration.                        |
| SA     | System and Services Acquisition: Secure development lifecycle, supply chain risk management, and third-party assessments. |

### Lower Priority

These families address organizational and personnel-level controls:

| Family | Description                                                                                                   |
|--------|---------------------------------------------------------------------------------------------------------------|
| PL     | Planning: Security plan development, rules of behavior, and activity planning.                                |
| PM     | Program Management: Enterprise-wide security program, risk management strategy, and architecture integration. |
| PS     | Personnel Security: Personnel screening, access agreements, and role-change or termination procedures.        |

## Embedded CIS Controls

The CIS Critical Security Controls provide prioritized, actionable guidance. The top 10 controls most commonly applicable to software architectures follow.

| Control | Description                                                                                                                 |
|---------|-----------------------------------------------------------------------------------------------------------------------------|
| CIS 1   | Inventory and Control of Enterprise Assets: Maintain an accurate inventory of all hardware assets connected to the network. |
| CIS 2   | Inventory and Control of Software Assets: Track and manage all software running in the environment.                         |
| CIS 3   | Data Protection: Identify, classify, and protect sensitive data at rest and in transit.                                     |
| CIS 4   | Secure Configuration of Enterprise Assets and Software: Establish and maintain hardened configurations for all assets.      |
| CIS 5   | Account Management: Manage lifecycle of system and application accounts including creation, use, and deactivation.          |
| CIS 6   | Access Control Management: Create, assign, manage, and revoke access credentials and privileges.                            |
| CIS 7   | Continuous Vulnerability Management: Continuously identify and remediate vulnerabilities across the environment.            |
| CIS 8   | Audit Log Management: Collect, review, and retain audit logs for detection and forensic purposes.                           |
| CIS 9   | Email and Web Browser Protections: Improve protections against email and web-based threats.                                 |
| CIS 10  | Malware Defenses: Prevent or control installation and execution of malicious software.                                      |

## Researcher Subagent Delegation

Microsoft Well-Architected Framework (WAF) and Cloud Adoption Framework (CAF) lookups are delegated to the Researcher Subagent at runtime. These frameworks evolve frequently and contain extensive cloud-specific guidance best retrieved on demand.

The following standards are also delegated for runtime lookup due to version sensitivity, domain specificity, or rapid evolution:

| Standard                                          | Rationale for Delegation                                   |
|---------------------------------------------------|------------------------------------------------------------|
| WAF / CAF                                         | Cloud-specific, frequently updated, extensive content      |
| MCSB (Microsoft Cloud Security Benchmark)         | Azure-specific, frequently updated control mappings        |
| PCI-DSS                                           | Domain-specific, version-dependent compliance requirements |
| S2C2F (Secure Supply Chain Consumption Framework) | Emerging standard, evolving maturity levels                |
| SLSA (Supply Chain Levels for Software Artifacts) | Version-dependent build integrity requirements             |
| SOC 2                                             | Audit-framework specific, organization-dependent scope     |
| HIPAA                                             | Regulated domain, requires current interpretation          |
| FedRAMP                                           | Government-specific, dynamic control baselines             |

Do NOT delegate OWASP, NIST 800-53, CIS, OWASP LLM Top 10, or NIST AI RMF lookups. Those standards are embedded above.

### When to Delegate

* User requests WAF or CAF alignment for a component.
* Phase 3 identifies cloud-specific controls that exceed embedded standards.
* Compliance requirements demand cloud framework mapping beyond what embedded standards cover.
* Supply chain security analysis requires S2C2F or SLSA level mapping.
* Regulatory context requires PCI-DSS, HIPAA, SOC 2, or FedRAMP mapping.

### Invocation Pattern

Use `runSubagent` with the Researcher Subagent:

```text
Agent: Researcher Subagent
Topic: {specific framework area to research}
Context: Component "{name}" in bucket "{bucket}" using {technology stack}
Output: .copilot-tracking/research/subagents/{date}/{component-name}-{framework}.md
```

Response format: Return findings as a markdown document with Standards Coverage, Findings, and Recommendations sections.

Execution constraints: Complete research within a single invocation. Do not delegate to additional subagents.

### Query Templates

Use these templates when delegating to the Researcher Subagent:

* WAF/CAF: "Map {component} to WAF {pillar} and CAF {area} controls for {technology stack} on {cloud platform}."
* MCSB: "Identify MCSB controls applicable to {component} of type {resource type} in {Azure service}."
* PCI-DSS: "Map {component} handling {data classification} to PCI-DSS v{version} requirements."
* S2C2F: "Evaluate {component} dependency consumption against S2C2F maturity levels."
* SLSA: "Assess {component} build pipeline against SLSA v{version} level requirements."
* SOC 2: "Map {component} to SOC 2 Trust Services Criteria relevant to {trust principle}."
* HIPAA: "Identify HIPAA Security Rule requirements for {component} handling {PHI context}."
* FedRAMP: "Map {component} to FedRAMP {impact level} baseline controls."

Subagent research outputs follow the repository-wide `.copilot-tracking/research/subagents/` convention and are not subject to the parent agent's own file creation constraints.

Collect findings from the output path and incorporate them into the component's standards mapping under the WAF/CAF Findings section.

## Cross-Reference Table

This table maps operational buckets to their baseline standard references. Use these as starting points and refine during Phase 3 analysis.

| Bucket              | OWASP                        | NIST 800-53    | CIS        |
|---------------------|------------------------------|----------------|------------|
| infra               | A05, A06                     | CM, PE, SC, SI | 1, 2, 4, 7 |
| devops/platform-ops | A05, A06, A08                | CA, CM, SA, SI | 2, 4, 7    |
| build               | A06, A08                     | SA, SI         | 2, 4, 7    |
| messaging           | A01, A03, A08                | AC, SC, SI     | 3, 4, 8    |
| data                | A01, A02, A03                | AC, AU, SC, SI | 3, 5, 6, 8 |
| web/UI/reporting    | A01, A02, A03, A05, A07, A10 | AC, IA, SC, SI | 4, 5, 6, 9 |
| identity/auth       | A01, A02, A07                | AC, IA, PS     | 5, 6       |
| ai-ml               | A04, A06, A08                | SA, SI, RA     | 2, 7       |

> [!NOTE]
> The ai-ml row applies only when `raiEnabled` is true. When applicable, also map components against OWASP LLM Top 10 and NIST AI RMF subcategories from the sections above.

## Mapping Output Format

For each component, produce a standards mapping block following this structure:

```markdown
### {Component Name} ({Bucket})

**Applicable Standards:**
- OWASP: {items with justification}
- NIST: {families with justification}
- CIS: {controls with justification}

**WAF/CAF Findings:** {researcher subagent results or N/A}

**Gap Analysis:** {identified gaps between current controls and standard requirements}
```

Include justification for each mapped standard, explaining why the control is relevant to the specific component. Flag gaps where a standard should apply based on the cross-reference table but no corresponding control exists in the current architecture.
