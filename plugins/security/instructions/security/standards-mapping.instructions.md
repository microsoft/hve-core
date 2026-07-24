---
description: "OWASP and NIST security standards references with researcher subagent delegation for CIS, WAF, CAF, and other runtime lookups"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Standards Mapping

Frequently-used security standards are referenced from the durable skill material during Phase 3 of the security planning workflow. Specialized cloud frameworks (WAF and CAF) are delegated to the Researcher Subagent at runtime instead of duplicating large, version-sensitive content.

At least one standard from each applicable framework should map to every component in the security plan. The Security Planner's Skill Reference Contract loads the durable standards references (`standards-cross-reference.md` and `nist-control-families.md` from the `security-planning` skill) via a mandatory `read_file` on Phase 3 entry, so the OWASP, NIST, and AI RMF mapping tables are not restated here. This instruction file stays orchestration-focused and defers the versioned standard tables to the skill loaded by that contract.

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
| CIS Critical Security Controls                    | License terms prohibit redistribution; use runtime lookup  |

Do NOT delegate OWASP, NIST 800-53, OWASP LLM Top 10, or NIST AI RMF lookups. Those standards are covered by the durable skill references listed above.

### Conditional Standards Skills

When buckets or AI components from Phases 1–2 match, prefer the matching specialized security skill over a runtime delegation:

* AI/ML components → `owasp-agentic`, and `owasp-mcp` when MCP tooling is used (alongside the always-loaded `owasp-llm`)
* `infrastructure` bucket → `owasp-infrastructure`
* `build` / `devops-platform-ops` buckets → `owasp-cicd`, `supply-chain-security`
* Cross-cutting GS overlay → `secure-by-design`

These skills are loaded by the Security Planner's Conditional Skill Map. Delegate to the Researcher Subagent only for standards with no matching skill (WAF, CAF, MCSB, PCI-DSS, and the others listed above).

### When to Delegate

* User requests WAF or CAF alignment for a component.
* Phase 3 identifies cloud-specific controls that require runtime research beyond the baseline standards references.
* Compliance requirements demand cloud framework mapping beyond the current baseline standards references.
* Supply chain security analysis requires S2C2F or SLSA level mapping.
* Regulatory context requires PCI-DSS, HIPAA, SOC 2, or FedRAMP mapping.

### Invocation Pattern

Use `runSubagent` with the Researcher Subagent:

```text
Agent: Researcher Subagent
Topic: {specific framework area to research}
Context: Component "{name}" in bucket "{bucket}" using {technology stack}
Output: .copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{component-name}-{framework}.md
```

Response format: Return findings as a markdown document with Standards Coverage, Findings, and Recommendations sections.

Execution constraints: Complete research within a single invocation. Do not delegate to additional subagents.

The Researcher Subagent returns: subagent research document path, research status, important discovered details, recommended next research not yet completed, and any clarifying questions.

When neither `runSubagent` nor `task` tools are available, inform the user that one of these tools is required and should be enabled. Do not synthesize or fabricate answers for delegated standards from training data.

Subagents can run in parallel when researching independent components or standards.

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

## Mapping Output Format

For each component, produce the standards mapping block defined in the skill reference and adapt it to the current component context.

```markdown
### {Component Name} ({Bucket})

**Applicable Standards:**
- OWASP: {items with justification}
- NIST: {families with justification}
- CIS: {delegated — include Researcher Subagent findings or N/A}

**WAF/CAF Findings:** {researcher subagent results or N/A}

**Gap Analysis:** {identified gaps between current controls and standard requirements}
```

Include justification for each mapped standard, explaining why the control is relevant to the specific component. Flag gaps where a standard should apply based on the cross-reference table but no corresponding control exists in the current architecture.


