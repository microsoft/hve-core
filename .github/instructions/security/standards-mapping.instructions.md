---
description: "OWASP and NIST security standards references with rpi-research activation for CIS, WAF, CAF, and other runtime lookups"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Standards Mapping

Frequently-used security standards are referenced from the durable skill material during Phase 3 of the security planning workflow. Specialized cloud frameworks (WAF and CAF) activate `rpi-research` at runtime instead of duplicating large, version-sensitive content.

At least one standard from each applicable framework should map to every component in the security plan. The Security Planner's Skill Reference Contract loads the durable standards references (`standards-cross-reference.md` and `nist-control-families.md` from the `security-planning` skill) via a mandatory `read_file` on Phase 3 entry, so the OWASP, NIST, and AI RMF mapping tables are not restated here. This instruction file stays orchestration-focused and defers the versioned standard tables to the skill loaded by that contract.

## Research Activation

Microsoft Well-Architected Framework (WAF) and Cloud Adoption Framework (CAF) lookups activate `rpi-research` at runtime. These frameworks evolve frequently and contain extensive cloud-specific guidance best retrieved on demand.

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

These skills are loaded by the Security Planner's Conditional Skill Map. Activate `rpi-research` only for standards with no matching skill (WAF, CAF, MCSB, PCI-DSS, and the others listed above).

### When to Activate Research

* User requests WAF or CAF alignment for a component.
* Phase 3 identifies cloud-specific controls that require runtime research beyond the baseline standards references.
* Compliance requirements demand cloud framework mapping beyond the current baseline standards references.
* Supply chain security analysis requires S2C2F or SLSA level mapping.
* Regulatory context requires PCI-DSS, HIPAA, SOC 2, or FedRAMP mapping.

### Activation Inputs

Provide `rpi-research` with the specific framework topic and mapping purpose; security authors, reviewers, control owners, and downstream consumers as the audience and intended use; explicit mapping questions and evidence criteria; component, bucket, technology, cloud, source, version, jurisdiction, and date scope plus non-goals; risk, licensing, privacy, deadline, phase-gate, and write-boundary constraints; supplied component, bucket, state, standards, control, and user evidence; requested outputs; and output mode (`analysis` or `comparison`).

Explicitly identify `.copilot-tracking/security-plans/{project-slug}/` as a trusted alternate evidence root and require the skill to mirror `research/YYYY-MM-DD/<task-slug>-research.md` and `research/subagents/...` beneath it. The skill owns the exact date, task slug, artifact paths, worker selection, lane contracts, budgets, and synthesis.

Read the completed primary research artifact and synthesize applicable Standards Coverage, Findings, and Recommendations into the component mapping. Treat `Blocked` and `Needs clarification` as unresolved evidence, not permission to infer a mapping. If `rpi-research` or a required lookup capability is unavailable, inform the user and stop the dependent mapping rather than synthesizing standards from training data. The skill decides whether independent questions warrant parallel research.

### Query Templates

Use these templates when defining questions for `rpi-research`:

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

**WAF/CAF Findings:** {delegated RPI evidence or N/A}

**Gap Analysis:** {identified gaps between current controls and standard requirements}
```

Include justification for each mapped standard, explaining why the control is relevant to the specific component. Flag gaps where a standard should apply based on the cross-reference table but no corresponding control exists in the current architecture.


