---
description: "OWASP and NIST security standards references and evidence requirements for CIS, WAF, CAF, and other current mappings"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Standards Mapping

Use durable security references during Phase 3. Resolve specialized cloud requirements (WAF and CAF) from current primary sources rather than duplicating version-sensitive content.

At least one standard from each applicable framework should map to every component in the security plan. The Security Planner's Skill Reference Contract loads the durable standards references (`standards-cross-reference.md` and `nist-control-families.md` from the `security-planning` skill) via a mandatory read on Phase 3 entry, so the OWASP, NIST, and AI RMF mapping tables are not restated here. This instruction file stays orchestration-focused and defers the versioned standard tables to the skill loaded by that contract.

## Research Activation

For Microsoft Well-Architected Framework (WAF) and Cloud Adoption Framework (CAF) decisions, use an authoritative supplied reference or an available scoped research capability.

The following standards are also delegated for runtime lookup due to version sensitivity, domain specificity, or rapid evolution:

| Standard                                          | Rationale for Delegation                                   |
|---------------------------------------------------|------------------------------------------------------------|
| WAF / CAF                                         | Cloud-specific, frequently updated, extensive content      |
| MCSB per-service control mappings                 | Azure-specific, frequently updated per-service baselines   |
| PCI-DSS                                           | Domain-specific, version-dependent compliance requirements |
| S2C2F (Secure Supply Chain Consumption Framework) | Emerging standard, evolving maturity levels                |
| SLSA (Supply Chain Levels for Software Artifacts) | Version-dependent build integrity requirements             |
| SOC 2                                             | Audit-framework specific, organization-dependent scope     |
| HIPAA                                             | Regulated domain, requires current interpretation          |
| FedRAMP                                           | Government-specific, dynamic control baselines             |
| CIS Critical Security Controls                    | License terms prohibit redistribution; use runtime lookup  |

Do NOT delegate OWASP, NIST 800-53, OWASP LLM Top 10, or NIST AI RMF lookups. Those standards are covered by the durable skill references listed above.

### Conditional Standards Skills

When buckets or AI components from Phases 1–2 match, prefer the matching specialized security skill over a runtime delegation:

* AI/ML components → `owasp-agentic`, and `owasp-mcp` when MCP tooling is used (alongside the always-loaded `owasp-llm`)
* `infrastructure` bucket → `owasp-infrastructure`
* Azure cloud resources → `mcsb` (stable MCSB control-domain taxonomy and crosswalk; delegate volatile per-service control lookups)
* `build` / `devops-platform-ops` buckets → `owasp-cicd`, `supply-chain-security`
* Cross-cutting GS overlay → `secure-by-design`

Apply the planner's Conditional Skill Map. Seek additional evidence for standards not covered there and for volatile MCSB service baselines.

### When to Activate Research

* User requests WAF or CAF alignment for a component.
* Phase 3 identifies cloud-specific controls that require runtime research beyond the baseline standards references.
* Compliance requirements demand cloud framework mapping beyond the current baseline standards references.
* Supply chain security analysis requires S2C2F or SLSA level mapping.
* Regulatory context requires PCI-DSS, HIPAA, SOC 2, or FedRAMP mapping.

### Activation Inputs

Scope the lookup by framework, mapping purpose, audience, component, bucket, cloud, source version, jurisdiction and date. Specify evidence criteria, licensing, privacy and write limits, and the comparison or analysis needed. Do not send private plan or control evidence beyond the authorized scope.

Explicitly identify `.copilot-tracking/security-plans/{project-slug}/` as a trusted alternate evidence root.

Read the primary evidence before incorporating coverage, findings or recommendations. Record a blocked or unclear source and stop the dependent mapping rather than inferring a standard.

### Query Templates

Use these templates to define bounded source questions:

* WAF/CAF: "Map {component} to WAF {pillar} and CAF {area} controls for {technology stack} on {cloud platform}."
* MCSB: "Identify MCSB controls applicable to {component} of type {resource type} in {Azure service}."
* PCI-DSS: "Map {component} handling {data classification} to PCI-DSS v{version} requirements."
* S2C2F: "Evaluate {component} dependency consumption against S2C2F maturity levels."
* SLSA: "Assess {component} build pipeline against SLSA v{version} level requirements."
* SOC 2: "Map {component} to SOC 2 Trust Services Criteria relevant to {trust principle}."
* HIPAA: "Identify HIPAA Security Rule requirements for {component} handling {PHI context}."
* FedRAMP: "Map {component} to FedRAMP {impact level} baseline controls."

Research evidence stays under the active Security Planner's mirrored `research/` structure. Read the returned primary artifact and incorporate applicable findings into the component's standards mapping under the WAF/CAF Findings section.

## Mapping Output Format

For each component, produce the standards mapping block defined in the skill reference and adapt it to the current component context.

```markdown
### {Component Name} ({Bucket})

**Applicable Standards:**
- OWASP: {items with justification}
- NIST: {families with justification}
- CIS: {researched, include primary-artifact evidence or N/A}

**WAF/CAF Findings:** {verified source evidence or N/A}

**Gap Analysis:** {identified gaps between current controls and standard requirements}
```

Include justification for each mapped standard, explaining why the control is relevant to the specific component. Flag gaps where a standard should apply based on the cross-reference table but no corresponding control exists in the current architecture.
