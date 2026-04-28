Create architecture decision records, requirements documents, and diagrams — all through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and conduct STRIDE-based security model analysis with automated backlog generation.

This collection includes agents for:

- **Agile Coach** — Create or refine goal-oriented user stories with clear acceptance criteria
- **Product Manager Advisor** — Product management advisor for requirements discovery, validation, and issue creation
- **UX/UI Designer** — UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements
- **Architecture Decision Records** — Create structured ADRs with solution comparison matrices
- **Architecture Diagrams** — Generate ASCII-art architecture diagrams from descriptions
- **Business Requirements Documents** — Build BRDs through guided Q&A sessions
- **System Architecture Reviewer** — System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment
- **RPI Agent** — Autonomous RPI orchestrator running specialized subagents through Research, Plan, Implement, and Review phases
- **Product Requirements Documents** — Build PRDs with stakeholder-driven refinement
- **Requirements Builder** — Unified six-phase agent for PRDs, BRDs, and other requirements artifacts; resolves Framework Skills under `.github/skills/requirements/` and persists session state to `.copilot-tracking/requirements-sessions/{slug}/`
- **RAI Planner** — Responsible AI assessment with security model analysis, impact assessment, and dual-format backlog handoff
- **Security Planner** — STRIDE-based security model analysis with operational bucket classification, standards mapping, and automated backlog generation
- **SSSC Planner** — Software supply-chain security assessment with gap analysis, standards mapping, and automated backlog generation

Supporting subagents included:

- **Researcher Subagent** — Research subagent using search tools, read tools, fetch web page, github repo, and MCP tools
- **Plan Validator** — Validates implementation plans against research documents with severity-graded findings
- **Phase Implementor** — Executes a single implementation phase from a plan with full codebase access and change tracking
- **RPI Validator** — Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents
- **Implementation Validator** — Validates implementation quality against architectural requirements, design principles, and code standards

Skills included:

- **ADR Template** — Architecture Decision Record template Framework Skill providing guided section prompts, trade-off analysis templates, and phased authoring workflow for content-generation hosts
- **PRD Template** — Product Requirements Document template Framework Skill providing guided section prompts and variable-driven inputs for content-generation hosts
- **Requirements PRD** — Framework Skill providing 17 PRD document sections (problem, goals, target users, scope, success metrics, requirements, technical approach, rollout, risks, more) with manifest-level token globals
- **Requirements BRD** — Framework Skill providing 14 BRD document sections (executive summary, business context, stakeholders, business requirements, success criteria, governance, more) with manifest-level token globals
- **NIST AI RMF** — NIST AI Risk Management Framework 1.0 (NIST.AI.100-1) core functions and 72 subcategories as machine-readable per-item YAML for the RAI Planner agent's Phase 1-6 standards mapping
- **EU AI Act — Prohibited Practices** — EU AI Act (Regulation (EU) 2024/1689) Article 5 prohibited AI practices encoded as paraphrased per-principle YAML for the RAI Planner Phase 2 Prohibited Uses Gate
- **RAI Default Risk Indicators** — Default Responsible AI risk indicators (safety/reliability, rights/fairness/privacy, security/explainability) used by the RAI Planner Phase 2 Risk Classification screen
- **RAI Threat Catalog** — RAI threat catalog covering 8 AI element types and 6 trust boundaries with the AI-extended ML STRIDE matrix and dual T-RAI/T-{BUCKET}-AI threat ID convention for the RAI Planner Phase 4 Security Model
- **RAI Control Surface** — RAI control surface taxonomy mapping each NIST trustworthiness characteristic to preventive, detective, and corrective control types for the RAI Planner Phase 5 Impact Assessment
- **RAI Tradeoffs** — Documented Responsible AI characteristic tradeoffs (privacy/accuracy, explainability/accuracy, fairness/accuracy, safety/accuracy, accountability/security) consumed by the RAI Planner Phase 5 Impact Assessment
- **RAI Output Formats** — RAI Planner output-format library with 12 document-section templates covering risk classification, standards mapping, security-model tables, impact-assessment artifacts, and Phase 6 dual-format backlog handoff
