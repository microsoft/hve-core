Security review, planning, incident response, risk assessment, vulnerability analysis, supply chain security, and responsible AI assessment for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

This collection includes agents and prompts for:

- **Security Plan Creation** - Generate threat models and security architecture documents
- **Security Review** - Evaluate code and architecture for security vulnerabilities
- **Incident Response** - Build incident response runbooks and playbooks
- **Risk Assessment** - Evaluate security risks with structured assessment frameworks
- **Vulnerability Analysis** - Identify and prioritize security vulnerabilities
- **Root Cause Analysis** - Structured RCA templates and guided analysis workflows
- **SSSC Planning** - Supply chain security assessment and backlog generation against OpenSSF standards
- **RAI Planning** - Responsible AI impact assessment and RAI backlog generation

Supporting subagents included:

- **Researcher Subagent** - Research subagent using search tools, read tools, fetch web page, github repo, and MCP tools
- **Codebase Profiler** - Scans the repository to build a technology profile and identify which OWASP skills apply
- **Finding Deep Verifier** - Deep adversarial verification of FAIL and PARTIAL findings for a single OWASP skill
- **Report Generator** - Collates verified OWASP skill assessment findings and generates a comprehensive vulnerability report
- **Skill Assessor** - Assesses a single OWASP skill against the codebase, reading vulnerability references and returning structured findings

Skills included:

- **OWASP Top 10** - OWASP Top 10 for Web Applications (2025) vulnerability knowledge base
- **OWASP LLM Top 10** - OWASP Top 10 for LLM Applications (2025) vulnerability knowledge base
- **OWASP Agentic Top 10** - OWASP Agentic Security Top 10 vulnerability knowledge base for AI agent systems
- **OWASP MCP Top 10** - OWASP MCP Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in Model Context Protocol environments
- **OWASP Infrastructure Top 10** - OWASP Infrastructure Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in internal IT infrastructure environments
- **OWASP CI/CD Top 10** - OWASP CI/CD Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in continuous integration and continuous delivery environments
- **Security Reviewer Formats** - Format specifications and data contracts for the security reviewer orchestrator and its subagents
