Assess AI systems for responsible AI risks using structured standards-aligned analysis and impact assessment.

> [!CAUTION]
> The RAI agents and prompts in this collection are **assistive tools only**. They do not replace qualified human review, organizational RAI review boards, or regulatory compliance programs. All AI-generated RAI artifacts **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risks, or produce recommendations that are incomplete or inappropriate for your context.

This collection includes agents and prompts for:

- **RAI Assessment** - Conduct structured responsible AI assessments aligned to Microsoft RAI Standard v2 and NIST AI RMF
- **Impact Analysis** - Evaluate fairness, reliability, privacy, security, inclusiveness, transparency, and accountability impacts
- **Security Model Analysis** - Identify AI-specific threats using extended STRIDE methodology with ML-specific attack patterns
- **Backlog Handoff** - Generate prioritized RAI work items in ADO or GitHub formats

## Prerequisites

The RAI Planner works as a standalone agent but produces the best results when paired with the **Security Planner** collection. Running a security assessment first provides threat context that enriches RAI impact analysis.

## Interaction Model

The RAI Planner follows a Sequential interaction model (Model A) with the Security Planner:

1. **Security Planner** runs first and detects AI components during Phase 1
2. **Security Planner** completes its security assessment and hands off to the RAI Planner
3. **RAI Planner** inherits threat context and performs RAI-specific analysis

The RAI Planner can also run independently using `capture`, `prd`, or `resume` entry modes.
