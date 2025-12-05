---
description: 'Comprehensive coding guidelines and instructions for hve-core'
---

# General Instructions

Items in **HIGHEST PRIORITY** sections from attached instructions files override any conflicting guidance.

## **HIGHEST PRIORITY**

**Breaking changes:** Do not add backward-compatibility layers or legacy support unless explicitly requested. Breaking changes are acceptable.

**Artifacts:** Do not create or modify tests, scripts, or one-off markdown docs unless explicitly requested.

**Comment policy:** Never include thought processes, step-by-step reasoning, or narrative comments in code.

* Keep comments brief and factual; describe **behavior/intent, invariants, edge cases**.
* Remove or update comments that contradict the current behavior. Do not restate obvious functionality.
* Do NOT add temporal or plan-phase markers (e.g. "Phase 1 cleanup", "... after migration", dates, or task references) to code files. When editing or updating any code files, always remove or replace these types of comments.

**Conventions and Styling:** Always follow conventions and styling in this codebase FIRST for all changes, edits, updates, and new files.

* Conventions and styling are in instruction files and must be read in with the `read_file` tool if not already added as an `<attachment>`.

**Proactive fixes:** Always fix problems and errors you encounter, even if unrelated to the original request. Prefer root-cause, constructive fixes over symptom-only patches.

**Deleting files and folders:** Use `rm` with the run_in_terminal tool when needing to delete files or folders.

**Prefer safe commands**: Use commands that do not have the potential to mutate files or trigger unnecessary interactive prompts.

* Avoid commands like `sed -n '/pattern/p' file` to print data when non-mutating alternatives like `grep` exist.
* Avoid shell redirects like `2>/dev/null` unless necessary, as they may trigger interactive approval prompts in certain AI assistant environments.

**Edit tools:** Never use `insert_edit_into_file` tool when other edit and file modification tools are available.

### CRITICAL - Required Prompts & Instruction Compliance

**Context-first:** Evaluate the current user prompt, any attachments, target folders, repo conventions, and files already read.

**Discover & match (do this BEFORE any edit):**

* Run `<search-for-prompts-files>` using the rules below (see table).
* For each matched prompts/instructions/copilot file:
  * If it is NOT already provided as a full, non-summarized `<attachment>` in this conversation and NOT already fetched via `read_file`, then read it now.
  * Use read_file to **page through the entire file**: read **2,000 lines per call**; make additional calls until EOF.
  * If the file references other prompts/instructions/copilot files, **recursively read those** to completion under the same paging rule.

**Apply instructions:** Treat the union of all matched files as **HIGHEST PRIORITY** for this task.

**Re-check cadence:** Re-run discovery and re-read all matched instruction files if missing **before each major editing phase**.

<!-- <search-for-prompts-files> -->
## Prompts Files Search Process

When working with specific types of files or contexts, you must:

1. Detect patterns and contexts that match the predefined rules
2. Search for and read the corresponding prompts files
3. Read a minimum of 2000 lines from these files before proceeding with any changes

### Matching Patterns and Files for Prompts

| Pattern/Context                   | Required Prompts Files                                 |
|-----------------------------------|--------------------------------------------------------|
| Any pull request creation context | `./.github/prompts/pull-request.prompt.md`             |
| Any ADO context                   | `./.github/prompts/ado-*.prompt.md`                    |
| Any git context                   | `./.github/prompts/git-*.prompt.md`                    |
| Any shell or bash context         | `./.github/instructions/shell.instructions.md`         |
| Any bash in scripts context       | `./.github/instructions/bash/bash.instructions.md`     |
| Any python context                | `./.github/instructions/python-script.instructions.md` |
| Any PowerShell context            | PowerShell best practices and PSScriptAnalyzer rules   |
| Any markdown context              | `./.github/instructions/markdown.instructions.md`      |

<!-- </search-for-prompts-files> -->

<!-- <project-structure> -->
## Project Structure Understanding

This repository contains documentation, scripts, and tooling for the HVE (Hybrid Virtual Environment) Core project.

### Directory Organization

The project is organized into the following main areas:

* **Documentation**: `**/docs/**` - Architecture Decision Records (ADRs) and solution documentation
* **Scripts**: `**/scripts/**` - Automation scripts for linting, security, and development
* **GitHub Configuration**: `**/.github/**` - Workflows, instructions, prompts, and issue templates
* **Logs**: `**/logs/**` - Output from various validation and analysis scripts

### Scripts Organization

Scripts are organized by function:

* **Development Tools**: `**/scripts/dev-tools/**` - Development utilities like PR reference generation
* **Linting**: `**/scripts/linting/**` - Markdown validation, link checking, PowerShell analysis
* **Security**: `**/scripts/security/**` - Dependency pinning validation, SHA staleness checks

### Documentation Structure

Documentation follows a standardized pattern:

* **ADR Library**: `**/docs/solution-adr-library/**` - Architecture Decision Record templates
* **Solution Docs**: `**/docs/solution-*/**` - Solution-specific documentation
* **Markdown Standards**: All markdown must include valid frontmatter with `description` field

### GitHub Configuration

**Instructions**: `**/.github/instructions/**` - Technology-specific coding standards

* Applied automatically based on file patterns
* Include guidelines for shell, bash, python, markdown, and Azure DevOps

**Prompts**: `**/.github/prompts/**` - Workflow-specific guidance

* ADO workflows (work items, PRs, builds)
* Git operations (merge, commit, setup)
* Documentation creation (ADRs)

**Workflows**: `**/.github/workflows/**` - GitHub Actions automation
<!-- </project-structure> -->

<!-- <script-operations> -->
## Script Operations Requirements

### PowerShell Scripts

* Follow PSScriptAnalyzer rules defined in `PSScriptAnalyzerSettings.psd1`
* Use `npm run psscriptanalyzer` to validate PowerShell scripts
* Scripts output JSON results to `**/logs/**` directory
* All scripts must include proper comment-based help

### Bash Scripts

* Follow conventions from `.github/instructions/bash/bash.instructions.md` and `.github/instructions/shell.instructions.md`
* Use shellcheck for validation
* Scripts should be POSIX-compliant where possible

### Python Scripts

* Follow conventions from `.github/instructions/python-script.instructions.md`
* Use appropriate virtual environment management
* Include type hints and docstrings

<!-- </script-operations> -->

<!-- <copilot-tracking-instructions> -->
## Copilot Tracking Structure

The `.copilot-tracking/` directory contains AI-assisted workflow artifacts:

### Tracking Organization

* **Work Items**: `.copilot-tracking/workitems/**` - ADO work item discovery and planning
* **Pull Requests**: `.copilot-tracking/pr/**` - PR reference generation and handoff
* **Changes**: `.copilot-tracking/changes/**` - Change tracking and implementation logs
* **Plans**: `.copilot-tracking/plans/**` - Task planning documents
* **Research**: `.copilot-tracking/research/**` - Technical research findings

### Tracking Conventions

* All tracking files use markdown format with frontmatter
* Handoff logs document completion status and next actions
* Follow patterns from `.github/instructions/ado-*.instructions.md`
<!-- </copilot-tracking-instructions> -->

<!-- <project-structure-instructions> -->
## Project Structure Instructions

This project contains documentation, automation scripts, and tooling for the HVE Core initiative.

### Root Configuration Files

Configuration files that control project behavior, tooling, and metadata.

```plaintext
hve-core/
├── .checkov.yaml                              # Security and compliance scanning configuration
├── .cspell.json                               # Spell checker configuration
├── .gitattributes                             # Git attributes configuration
├── .gitignore                                 # Git ignore patterns
├── .markdownlint.json                         # Markdown linting rules
├── .markdownlint-cli2.jsonc                   # Markdown linting CLI configuration
├── .npmrc                                     # NPM package manager configuration
├── package.json                               # NPM scripts for linting and validation
├── package-lock.json                          # NPM dependency lock file
├── CODE_OF_CONDUCT.md                         # Community guidelines and behavioral expectations
├── CONTRIBUTING.md                            # Guidelines for contributing to the project
├── LICENSE                                    # Legal license terms
├── README.md                                  # Main project documentation
├── SECURITY.md                                # Security policy and vulnerability reporting
└── SUPPORT.md                                 # Support resources and community assistance
```

### Development Environment

Development containers and IDE settings.

```plaintext
hve-core/
├── .devcontainer/                             # VS Code development container configuration
├── .github/                                   # GitHub configuration
│   ├── chatmodes/                             # AI chat mode definitions
│   ├── instructions/                          # Technology-specific coding standards
│   ├── prompts/                               # Workflow-specific guidance
│   ├── workflows/                             # GitHub Actions automation
│   ├── ISSUE_TEMPLATE/                        # Issue templates
│   ├── CODEOWNERS                             # Code ownership definitions
│   ├── PULL_REQUEST_TEMPLATE.md               # PR template
│   ├── copilot-instructions.md                # This file
│   └── dependabot.yml                         # Dependency update configuration
└── .vscode/                                   # VS Code workspace settings
```

### Documentation

Project documentation organized by solution area.

```plaintext
docs/
├── solution-adr-library/                      # Architecture Decision Record templates
│   └── adr-template-solutions.md              # ADR template for solutions
└── solution-data-science/                     # Data science solution documentation
    └── hve-ds.md                              # HVE data science documentation
```

### Automation Scripts

Utility scripts for validation, linting, and security.

```plaintext
scripts/
├── README.md                                  # Scripts documentation
├── dev-tools/                                 # Development utilities
│   ├── Generate-PrReference.ps1               # PR reference generation script
│   └── pr-ref-gen.sh                          # PR reference generation (bash)
├── linting/                                   # Linting and validation scripts
│   ├── Invoke-LinkLanguageCheck.ps1           # Link language consistency checker
│   ├── Invoke-PSScriptAnalyzer.ps1            # PowerShell script analyzer
│   ├── Link-Lang-Check.ps1                    # Link language validation
│   ├── Markdown-Link-Check.ps1                # Markdown link validation
│   ├── Validate-MarkdownFrontmatter.ps1       # Markdown frontmatter validation
│   ├── markdown-link-check.config.json        # Link checker configuration
│   ├── PSScriptAnalyzer.psd1                  # PSScriptAnalyzer settings
│   ├── README.md                              # Linting documentation
│   └── Modules/                               # Shared PowerShell modules
│       └── LintingHelpers.psm1                # Helper functions
└── security/                                  # Security validation scripts
    ├── Test-DependencyPinning.ps1             # Dependency pinning validation
    ├── Test-SHAStaleness.ps1                  # SHA staleness checking
    └── Update-ActionSHAPinning.ps1            # Update GitHub Action SHA pins
```

### Output Logs

Automated script outputs and validation results.

```plaintext
logs/
├── dependency-pinning-results.json            # Dependency pinning check results
├── frontmatter-validation-results.json        # Frontmatter validation results
├── link-lang-check-results.json               # Link language check results
├── markdown-link-check-results.json           # Link validation results
├── psscriptanalyzer-results.json              # PowerShell analysis results
├── psscriptanalyzer-summary.json              # PowerShell analysis summary
└── test-pinning.sarif                         # SARIF format pinning results
```

### Copilot Tracking

AI-assisted workflow artifacts (gitignored, local only).

```plaintext
.copilot-tracking/
├── workitems/                                 # ADO work item discovery and planning
├── pr/                                        # PR reference generation
├── changes/                                   # Change tracking logs
├── plans/                                     # Task planning documents
└── research/                                  # Technical research findings
```
<!-- </project-structure-instructions> -->
