---
description: 'Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Standards Reference

Frequently-used Responsible AI standards are embedded directly in this file for immediate reference during Phase 3 of the RAI planning workflow. The Microsoft RAI Standard v2 provides the principle framework with a Goal, Requirement, and Tool hierarchy. NIST AI RMF 1.0 provides the authoritative subcategory structure across 4 core functions and 72 subcategories. Evolving regulatory frameworks (EU AI Act, ISO 42001, domain-specific regulations) are delegated to the Researcher Subagent at runtime.

At least one principle from each embedded framework should map to every AI system component in the RAI plan. The phase mapping table provides starting-point alignments; refine these during Phase 3 analysis.

## Microsoft RAI Standard v2

Microsoft's Responsible AI Standard v2 (June 2022) organizes guidance into 6 principles, each following a hierarchical structure: Core Principle, Goals, Requirements, Assessment Criteria, and Tooling. Use this table to identify applicable principles for each AI system component and select appropriate assessment tools.

| Principle              | Goal                                                                                  | Assessment Criteria                                                                | Tooling                                      |
|------------------------|---------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|----------------------------------------------|
| Fairness               | AI systems treat everyone fairly and avoid affecting similar groups differently       | Demographic parity, equalized odds, group-level fairness metrics                   | Fairlearn, RAI Dashboard Fairness Analysis   |
| Reliability and Safety | Systems operate reliably, safely, and consistently as designed                        | Cohort error analysis, performance bounds, stress testing, robustness evaluation   | RAI Dashboard Error Analysis, Model Overview |
| Privacy and Security   | Protect privacy and secure personal and business information throughout the lifecycle | Differential privacy verification, data minimization, access control review        | SmartNoise, Microsoft Purview DSPM           |
| Inclusiveness          | AI technology benefits and empowers everyone                                          | Dataset representation analysis, accessibility testing, diverse cohort evaluation  | RAI Dashboard Data Analysis                  |
| Transparency           | Stakeholders understand how AI systems make decisions                                 | Feature importance, SHAP values, glass-box model analysis, model card completeness | InterpretML, RAI Dashboard Interpretability  |
| Accountability         | Designers and deployers are accountable for system operation                          | PDF scorecards, model cards, decision audit trails, governance review completeness | RAI Dashboard Scorecard, Audit logging       |

### Assessment Workflows

The RAI Dashboard supports two primary evaluation workflows:

* Model debugging (3-stage): Error Analysis, Fairness Analysis, Model Interpretability
* Responsible decision-making: Causal Inference, Counterfactual What-If, Data Analysis

Both workflows produce exportable PDF scorecards for stakeholder review.

> [!NOTE]
> Current RAI Dashboard tooling is designed for ML classification and regression models with tabular data. LLM and generative AI assessment requires separate evaluation approaches (Azure AI Content Safety and related services).

## NIST AI RMF 1.0 Core Functions

NIST AI Risk Management Framework (NIST.AI.100-1, January 2023) organizes AI governance into 4 core functions with 72 subcategories across 19 categories. The framework is voluntary, iterative, and context-dependent. Govern is the foundational cross-cutting function established before the other three. Map, Measure, and Manage iterate in any order after Govern is in place.

### Govern (Cross-Cutting Foundation)

Risk management culture, policies, accountability structures, and stakeholder engagement. 6 categories, 19 subcategories.

| ID     | Description                                                 |
|--------|-------------------------------------------------------------|
| GV-1   | Policies, processes, procedures, and practices              |
| GV-1.1 | Legal and regulatory requirements identified and integrated |
| GV-1.2 | Trustworthy AI characteristics integrated into policies     |
| GV-1.3 | Risk tolerance determined and documented                    |
| GV-1.4 | Transparent risk management policies established            |
| GV-1.5 | Ongoing monitoring processes defined                        |
| GV-1.6 | AI system inventory maintained                              |
| GV-1.7 | Decommissioning processes defined                           |
| GV-2   | Accountability structures                                   |
| GV-2.1 | Roles, responsibilities, and communication channels defined |
| GV-2.2 | Training programs for AI risk management established        |
| GV-2.3 | Executive leadership responsibility for AI risk             |
| GV-3   | Diversity, equity, inclusion, and accessibility (DEI&A)     |
| GV-3.1 | Diverse teams for AI development and oversight              |
| GV-3.2 | Human-AI oversight mechanisms defined                       |
| GV-4   | Organizational risk culture                                 |
| GV-4.1 | Safety-first mindset in AI development                      |
| GV-4.2 | Risk documentation and communication practices              |
| GV-4.3 | Testing and incident sharing protocols                      |
| GV-5   | Stakeholder engagement                                      |
| GV-5.1 | External feedback mechanisms established                    |
| GV-5.2 | Adjudicated feedback integration into risk management       |
| GV-6   | Third-party and supply chain risk                           |
| GV-6.1 | Third-party IP and rights risks assessed                    |
| GV-6.2 | Contingency plans for third-party failures                  |

### Map (Context and Risk Framing)

System characterization, intended context, stakeholder mapping, and risk framing. 5 categories, 18 subcategories.

| ID     | Description                                           |
|--------|-------------------------------------------------------|
| MP-1   | Intended context and purpose                          |
| MP-1.1 | Intended purposes, laws, and settings documented      |
| MP-1.2 | Diverse actors and competencies identified            |
| MP-1.3 | Mission and organizational goals alignment            |
| MP-1.4 | Business value assessment                             |
| MP-1.5 | Risk tolerances for the specific AI system            |
| MP-1.6 | System requirements including socio-technical factors |
| MP-2   | AI system categorization                              |
| MP-2.1 | Tasks and methods defined                             |
| MP-2.2 | Knowledge limits and human oversight requirements     |
| MP-2.3 | Scientific integrity and TEVV planning                |
| MP-3   | Capabilities and benchmarks                           |
| MP-3.1 | Potential benefits enumerated                         |
| MP-3.2 | Potential costs and negative impacts                  |
| MP-3.3 | Targeted scope of deployment                          |
| MP-3.4 | Operator proficiency requirements                     |
| MP-3.5 | Human oversight processes for deployment              |
| MP-4   | Third-party risks                                     |
| MP-4.1 | Legal and IP risk mapping for third-party components  |
| MP-4.2 | Internal risk controls for third-party dependencies   |
| MP-5   | Impact assessment                                     |
| MP-5.1 | Likelihood and magnitude of impacts assessed          |
| MP-5.2 | Regular stakeholder engagement practices              |

### Measure (Trustworthiness Evaluation)

Quantitative and qualitative testing, evaluation, verification, and validation (TEVV). 4 categories, 22 subcategories. MS-2.5 through MS-2.11 map directly to the 7 trustworthiness characteristics.

| ID      | Description                                     |
|---------|-------------------------------------------------|
| MS-1    | Methods and metrics selection                   |
| MS-1.1  | Risk-based metric selection                     |
| MS-1.2  | Metric appropriateness assessment               |
| MS-1.3  | Independent assessors engaged                   |
| MS-2    | Trustworthiness evaluation                      |
| MS-2.1  | TEVV tools and documentation                    |
| MS-2.2  | Human subject evaluations                       |
| MS-2.3  | Performance evaluation in deployment conditions |
| MS-2.4  | Production monitoring established               |
| MS-2.5  | Validity and reliability demonstration          |
| MS-2.6  | Safety evaluation                               |
| MS-2.7  | Security and resilience evaluation              |
| MS-2.8  | Transparency and accountability assessment      |
| MS-2.9  | Explainability and interpretability evaluation  |
| MS-2.10 | Privacy risk assessment                         |
| MS-2.11 | Fairness and bias evaluation                    |
| MS-2.12 | Environmental impact assessment                 |
| MS-2.13 | TEVV process effectiveness review               |
| MS-3    | Risk tracking                                   |
| MS-3.1  | Risk identification and tracking approaches     |
| MS-3.2  | Difficult-to-assess risk tracking               |
| MS-3.3  | End user feedback and appeal mechanisms         |
| MS-4    | Measurement efficacy feedback                   |
| MS-4.1  | Deployment context connection to measurements   |
| MS-4.2  | Domain expert validation of measurements        |
| MS-4.3  | Performance improvement and decline tracking    |

### Manage (Risk Response and Recovery)

Risk prioritization, treatment, monitoring, and continuous improvement. 4 categories, 13 subcategories.

| ID     | Description                                                        |
|--------|--------------------------------------------------------------------|
| MN-1   | Risk prioritization                                                |
| MN-1.1 | Go/no-go determination based on risk assessment                    |
| MN-1.2 | Risk treatment prioritization by impact and likelihood             |
| MN-1.3 | High-priority risk response plans                                  |
| MN-1.4 | Residual risk documentation                                        |
| MN-2   | Benefit maximization and impact minimization                       |
| MN-2.1 | Resource management with non-AI alternatives considered            |
| MN-2.2 | Sustaining deployed value                                          |
| MN-2.3 | Unknown risk response procedures                                   |
| MN-2.4 | Supersede, disengage, or deactivate mechanisms                     |
| MN-3   | Third-party risk management                                        |
| MN-3.1 | Third-party monitoring and controls                                |
| MN-3.2 | Pre-trained model monitoring                                       |
| MN-4   | Risk treatment documentation                                       |
| MN-4.1 | Post-deployment monitoring, incident response, and decommissioning |
| MN-4.2 | Continual improvement activities                                   |
| MN-4.3 | Incident/error communication and recovery                          |

## RAI-Security Overlap Mapping

RAI and security concerns overlap at specific intersection points. Use this mapping to identify components requiring both RAI principle evaluation and security risk surface analysis.

| RAI Principle          | STRIDE Category                   | Overlap Area                                                       |
|------------------------|-----------------------------------|--------------------------------------------------------------------|
| Privacy and Security   | Information Disclosure, Tampering | Data protection, model inversion attacks, training data extraction |
| Reliability and Safety | Denial of Service, Tampering      | Adversarial examples, data poisoning, model degradation            |
| Fairness               | Tampering                         | Biased training data injection, demographic targeting              |
| Accountability         | Repudiation                       | Audit trail integrity, decision provenance                         |
| Transparency           | Information Disclosure            | Model explanation versus intellectual property protection          |

## Security-Adjacent Subcategories

These Measure subcategories overlap directly with security risk surface analysis. Cross-reference them with the Security Planner's STRIDE analysis when both RAI and security assessments apply to the same component.

| Subcategory | Focus                        | Security Relevance                                                 |
|-------------|------------------------------|--------------------------------------------------------------------|
| MS-2.5      | Validity and reliability     | OWASP A04 Insecure Design; robustness under adversarial conditions |
| MS-2.6      | Safety evaluation            | STRIDE Denial of Service; failure mode analysis                    |
| MS-2.7      | Security and resilience      | All STRIDE categories; adversarial ML, model exfiltration          |
| MS-2.10     | Privacy risk assessment      | STRIDE Information Disclosure; data minimization, PET evaluation   |
| MS-2.11     | Fairness and bias evaluation | RAI-specific work items; biased training data injection detection  |

## Phase-to-NIST AI RMF Mapping

This table maps RAI Planner phases to NIST AI RMF subcategories. Use these alignments as starting points for each phase's standards coverage.

| RAI Planner Phase           | AI RMF Function  | Key Subcategories                                                                                                    |
|-----------------------------|------------------|----------------------------------------------------------------------------------------------------------------------|
| Phase 1 (Scoping)           | Govern + Map     | GV-1 (policies), MP-1 through MP-5 (context, requirements, benefits and costs, third-party risks, impact assessment) |
| Phase 2 (Sensitive Uses)    | Map              | MP-3 (capabilities), MP-4 (third-party risks), sensitive uses screening                                              |
| Phase 3 (Standards Mapping) | Govern + Measure | GV-1 through GV-6 (full governance), MS-1 (measurement approach)                                                     |
| Phase 4 (Assessment)        | Measure          | MS-2.5 through MS-2.11 (trustworthiness evaluation per characteristic)                                               |
| Phase 5 (Mitigation)        | Manage           | MN-1 through MN-4 (risk prioritization, response, monitoring, documentation)                                         |
| Phase 6 (Review)            | Manage           | MN-3 (third-party monitoring), MN-4 (continual improvement, incident communication)                                  |

### Trustworthiness Characteristics Hierarchy

NIST AI RMF defines 7 trustworthiness characteristics with a specific dependency structure:

* Valid and Reliable serves as the base characteristic supporting all others (assess first)
* Accountable and Transparent is a vertical cross-cutting characteristic enabling all others (assess throughout)
* Safe, Secure and Resilient, Explainable and Interpretable, Privacy-Enhanced, and Fair build on the base

This hierarchy informs assessment ordering: establish validity and reliability before evaluating downstream characteristics. Tradeoffs between characteristics (privacy versus accuracy, interpretability versus performance, fairness versus model complexity) are inherent and must be documented rather than assumed resolvable.

## Researcher Subagent Delegation

Evolving regulatory frameworks and emerging AI governance standards are delegated to the Researcher Subagent at runtime. These frameworks change frequently, vary by jurisdiction, or contain extensive domain-specific content best retrieved on demand.

| Standard                 | Rationale for Delegation                                                                           |
|--------------------------|----------------------------------------------------------------------------------------------------|
| EU AI Act                | Rapidly evolving risk classification tiers, version-dependent compliance requirements              |
| ISO 42001                | Emerging AI Management System standard, evolving certification guidance                            |
| WAF AI / CAF AI          | Cloud-specific AI governance guidance, frequently updated Azure content                            |
| HIPAA AI                 | Domain-specific healthcare AI regulations, requires current interpretation                         |
| Financial ML Regulations | Domain-specific financial services AI requirements, jurisdiction-dependent                         |
| Regional AI Frameworks   | Jurisdiction-specific AI governance (Singapore Model AI Governance, Canada AIDA, UK AI Regulation) |

Do NOT delegate Microsoft RAI Standard v2, NIST AI RMF, or RAI-Security overlap lookups. Those standards are embedded above.

### When to Delegate

* Phase 3 identifies regulatory requirements beyond embedded frameworks.
* Compliance context requires EU AI Act risk tier classification.
* The AI system operates in a regulated domain (healthcare, finance, government).
* Regional or jurisdictional AI governance alignment is required.
* ISO 42001 certification readiness assessment is requested.

### Invocation Pattern

Use `runSubagent` with the Researcher Subagent:

```text
Agent: Researcher Subagent
Topic: {specific AI governance framework area to research}
Context: AI system "{name}" with depth tier "{tier}" in domain "{domain}"
Output: .copilot-tracking/research/subagents/{date}/{system-name}-{framework}.md
```

Response format: Return findings as a markdown document with Standards Coverage, Findings, and Recommendations sections.

Execution constraints: Complete research within a single invocation. Do not delegate to additional subagents.

### Query Templates

Use these templates when delegating to the Researcher Subagent:

* EU AI Act: "Classify {AI system} under EU AI Act risk tiers and identify applicable requirements for {use case} in {deployment context}."
* ISO 42001: "Map {AI system} governance practices against ISO 42001 AI Management System requirements for {organizational context}."
* WAF AI / CAF AI: "Identify Azure WAF AI and CAF AI governance controls applicable to {AI system} deployed on {Azure service}."
* HIPAA AI: "Evaluate {AI system} handling {PHI context} against HIPAA AI-specific requirements and OCR guidance."
* Financial ML: "Map {AI system} providing {financial service} against applicable ML regulations in {jurisdiction}."
* Regional: "Identify {jurisdiction} AI governance framework requirements applicable to {AI system} for {use case}."

Subagent research outputs follow the repository-wide `.copilot-tracking/research/subagents/` convention and are not subject to the parent agent's own file creation constraints.

Collect findings from the output path and incorporate them into the component's RAI standards mapping.

## Mapping Output Format

For each AI system component, produce a standards mapping block following this structure:

```markdown
### {Component Name} ({Depth Tier})

**RAI Principles:**
- {Principle}: {assessment criteria with justification}

**NIST AI RMF Coverage:**
- {Function}: {subcategories with justification}

**Security Overlap:**
- {overlap areas identified from RAI-Security Overlap Mapping}

**Delegated Framework Findings:** {researcher subagent results or N/A}

**Gap Analysis:** {identified gaps between current practices and standard requirements}
```

Include justification for each mapped standard, explaining why the principle or subcategory is relevant to the specific component. Flag gaps where a standard should apply based on the phase mapping table but no corresponding assessment exists.
