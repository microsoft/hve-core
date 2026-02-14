Enforce language-specific coding conventions and best practices across your projects. This collection provides instructions for bash, Bicep, C#, Python, and Terraform that are automatically applied based on file patterns.

This collection includes instructions for:

- **Bash** — Shell scripting conventions and best practices
- **Bicep** — Infrastructure as code implementation standards
- **C#** — Code and test conventions including nullable reference types, async patterns, and xUnit testing
- **Python** — Scripting implementation with type hints, docstrings, and uv project management
- **Terraform** — Infrastructure as code with provider configuration and module structure

Supporting subagents included:

- **Codebase Researcher** — Searches workspace for code patterns, conventions, and implementations
- **External Researcher** — Retrieves external documentation, SDK references, and code samples
- **Phase Implementor** — Executes single implementation phases with change tracking
- **Artifact Validator** — Validates implementation work against plans and conventions
- **Prompt Tester** — Tests prompt files by following them literally in a sandbox
- **Prompt Evaluator** — Evaluates prompt execution results against quality criteria
