HVE Core provides the complete collection of AI chat agents, prompts, instructions, and skills for VS Code with GitHub Copilot. This edition includes every artifact across all domains: development workflows, architecture, Azure DevOps, GitHub and Jira backlog workflows, data science, design thinking, security, and more.

Use this edition when you want access to everything without choosing a focused collection.

> [!CAUTION]
> This collection includes security, responsible AI, and supply chain security agents and prompts that are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security and compliance artifacts **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

Code review agents included (via coding-standards collection):

- **Code Review Functional** - Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps
- **Code Review Standards** - Skills-based code reviewer that enforces project-defined coding standards via dynamic skill loading
- **Code Review Full** - Orchestrates both functional and standards reviews in a single pass

Security and planning agents included (via security collection):

- **Security Planner** - STRIDE-based security model analysis with operational bucket classification, standards mapping, and automated backlog generation
- **SSSC Planner** - Supply chain security assessment against OpenSSF Scorecard, SLSA, and SBOM standards
- **RAI Planner** - Responsible AI assessment with impact assessment and dual-format backlog handoff

Supporting subagents included:

- **Codebase Researcher** - Searches workspace for code patterns, conventions, and implementations
- **External Researcher** - Retrieves external documentation, SDK references, and code samples
- **Phase Implementor** - Executes single implementation phases with change tracking
- **Artifact Validator** - Validates implementation work against plans and conventions
- **Prompt Tester** - Tests prompt files by following them literally in a sandbox
- **Prompt Evaluator** - Evaluates prompt execution results against quality criteria

Skills included:

- **HVE Core Installer** - Decision-driven installer skill for deploying HVE Core across workspace configurations
- **GitLab Integration** - GitLab merge request and pipeline workflows through a Python skill
- **Jira Integration** - Jira backlog discovery, triage, execution, and PRD planning workflows backed by Jira issue operations and field discovery
- **PR Reference** - Generates PR reference XML files with commit history and diffs for pull request workflows
- **Video to GIF** - Converts video files to optimized GIF animations using FFmpeg two-pass palette optimization
