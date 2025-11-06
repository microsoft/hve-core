<!-- markdownlint-disable-file -->
# Task Research Documents: Edge AI Documentation Migration to HVE Core

This research identifies all Edge-AI specific documentation in the hve-core repository that was copied from the microsoft/edge-ai repository and needs to be updated to reflect the hve-core project identity, infrastructure, and team structure.

## Task Implementation Requests

* 🔄 **Update `CONTRIBUTING.md`** - Migrate Azure DevOps URLs to GitHub Issues, update Azure DevOps terminology, add build requirements section, update project identity
* 🔄 **Update `SUPPORT.md`** - Replace Edge AI references with HVE Core, update GitHub URLs, simplify support policy
* 🔄 **Update `.github/workflows/README.md`** - Update author metadata to "HVE Core Team"
* 🔄 **Update `.github/BRANCH_PROTECTION.md`** - Update author metadata to "HVE Core Team"
* 🔄 **Update `.github/chatmodes/pr-review.chatmode.md`** - Update attribution and optionally update Work Items → Issues terminology
* 🔄 **Update `.github/chatmodes/prompt-builder.chatmode.md`** - Update attribution from microsoft/edge-ai to microsoft/hve-core
* 🔄 **Update `.github/chatmodes/task-researcher.chatmode.md`** - Update attribution from microsoft/edge-ai to microsoft/hve-core
* 🔄 **Update `.github/chatmodes/task-planner.chatmode.md`** - Update attribution from microsoft/edge-ai to microsoft/hve-core
* 🔄 **Add standard footer to all root-level markdown files** - Apply Copilot attribution footer to 6 documentation files

## Scope and Success Criteria

* **Scope**: Identify and update all documentation files containing Edge-AI specific references (project names, URLs, team names, Azure DevOps links) to reflect hve-core repository identity
* **Assumptions**:
  * The hve-core repository was created by copying from microsoft/edge-ai
  * GitHub Issues are the correct replacement for Azure DevOps work items
  * Basic repository structure and workflows are correct
  * Core Microsoft policies (Code of Conduct, Security) remain unchanged
* **Success Criteria**:
  * ✅ All Edge AI project name references updated to HVE Core equivalent
  * ✅ All Edge AI Team author references updated to appropriate team name
  * ✅ All Azure DevOps URLs replaced with GitHub URLs
  * ✅ All microsoft/edge-ai repository references updated to microsoft/hve-core
  * ✅ References to non-existent documentation files removed or updated
  * ✅ Support metrics and Azure services lists reflect actual hve-core scope

## Outline

1. **Research Executed** - File analysis, search results, and external research
2. **Key Discoveries** - Project structure, naming conventions, and migration patterns
3. **Technical Scenarios** - Detailed file-by-file migration plans with priority levels

### Decisions Made

* ✅ **Official project name**: "HVE Core"
* ✅ **Team name**: "HVE Core Team"
* ✅ **Support metrics**: Keep response time commitments, remove specific performance data and dashboard references
* ✅ **Azure services**: Use generic phrasing (no service deployments, primarily markdown repository)
* ✅ **Documentation references**: Create basic contributing guide explaining build requirements (cspell, markdownlint, markdown-table-formatter)
* ✅ **Standard footer**: `🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.`

## Research Executed

### File Analysis

**Documentation files with Edge AI references:**

1. **`SUPPORT.md`** (Lines 1-103)
   * Line 3: Description "Edge AI Accelerator project"
   * Line 4: Author "Edge AI Team"
   * Line 18: "Edge AI Accelerator project"
   * Line 24: "Edge AI is an open-source project"
   * Line 47-48: GitHub Issues URLs pointing to microsoft/edge-ai
   * Line 82: Azure services list mentioning IoT Operations, Arc, AKS
   * Line 36-40: Specific performance metrics for support SLOs

2. **`CONTRIBUTING.md`** (Lines 1-198)
   * Line 4: Author "Edge AI Team"
   * Line 18: Title "Contributing to the AI on Edge Flagship Accelerator"
   * Lines 58, 62, 82, 97, 116, 121, 134: Multiple Azure DevOps URLs to `dev.azure.com/ai-at-the-edge-flagship-accelerator/`
   * References to non-existent documentation files:
     * `./docs/README.md`
     * `./docs/build-cicd/pipelines/azure-devops/templates/megalinter-template.md`
     * `./docs/coding-conventions.md`
     * `./docs/contributing/ai-assisted-engineering.md`

3. **`.github/workflows/README.md`** (Lines 1-447)
   * Line 4: Author "Edge AI Team"
   * All other content accurately describes existing GitHub Actions workflows

4. **`.github/BRANCH_PROTECTION.md`** (Lines 1-84)
   * Line 4: Author "Edge AI Team"
   * Line 25: Correctly references `@microsoft/hve-core-admins` team
   * All other content accurately describes repository settings

5. **`.github/chatmodes/pr-review.chatmode.md`** (Lines 2, 92, 148)
   * Line 2: Description "Brought to you by microsoft/edge-ai"
   * Line 92: Template field "Linked Work Items" (optional: update to "Linked Issues")
   * Line 148: Instructions mention "linked work items" (optional: update to "linked issues")

6. **`.github/chatmodes/prompt-builder.chatmode.md`** (Line 2)
   * Description: "Brought to you by microsoft/edge-ai"

7. **`.github/chatmodes/task-researcher.chatmode.md`** (Line 2)
   * Description: "Brought to you by microsoft/edge-ai"

8. **`.github/chatmodes/task-planner.chatmode.md`** (Line 2)
   * Description: "Brought to you by microsoft/edge-ai"

9. **`CODE_OF_CONDUCT.md`** - ✅ No Edge AI specific content (generic Microsoft template)

10. **`SECURITY.md`** - ✅ No Edge AI specific content (generic Microsoft template)

### Code Search Results

**Pattern: `edge.?ai|Edge.?AI|ai.?at.?the.?edge|IoT Operations|Azure Arc`**

* Found 20+ matches across 6 markdown files
* Primary locations: SUPPORT.md, CONTRIBUTING.md, workflow documentation, chatmode files
* No matches in code files, only documentation

**Pattern: `dev.azure.com/ai-at-the-edge`**

* Found 8 matches in CONTRIBUTING.md
* All related to issue tracking, work items, features, and backlogs
* Links reference non-existent Azure DevOps organization

**Pattern: `github.com/microsoft/edge-ai`**

* Found 3 matches in SUPPORT.md and chatmode files
* All pointing to issue tracking or attribution

### External Research (Evidence Log)

* **Repository Identity**: `package.json`
  * Repository name: `hve-core`
  * Repository URL: `https://github.com/microsoft/hve-core.git`
  * Description: "HVE Core"
  * Owner: "Microsoft"
  * Source: c:\Users\wberry\src\hve-core\package.json

* **Terminal History**: Recent copy operation from edge-ai
  * Last Command: `Copy-Item "c:\Users\wberry\src\edge-ai\scripts\security\Update-DockerSHAPinning.ps1" "c:\Users\wberry\src\hve-core\scripts\security\Update-DockerSHAPinning.ps1" -Force`
  * Evidence: User has been migrating files from edge-ai to hve-core repository

### Project Conventions

* **Standards referenced**:
  * `.github/instructions/markdown.instructions.md` - Markdown formatting rules
  * `.markdownlint.json` and `.markdownlint-cli2.jsonc` - Linting configuration
  * `.copilot-tracking/**` exempted from linting per repository policy
* **Instructions followed**:
  * All markdown files should have YAML frontmatter with metadata
  * Documentation must be accessible and follow Microsoft conventions

## Key Discoveries

### Project Structure

The hve-core repository structure:

```
hve-core/
├── .github/
│   ├── workflows/          # GitHub Actions (not Azure DevOps)
│   ├── chatmodes/          # Copilot chat mode definitions
│   ├── instructions/       # Project-specific instructions
│   ├── BRANCH_PROTECTION.md
│   └── CODEOWNERS
├── scripts/
│   └── security/           # Security automation scripts
├── CODE_OF_CONDUCT.md      # ✅ Generic Microsoft template (no changes needed)
├── CONTRIBUTING.md         # ⚠️ Contains Azure DevOps URLs and Edge AI references
├── SECURITY.md             # ✅ Generic Microsoft template (no changes needed)
├── SUPPORT.md              # ⚠️ Contains Edge AI project name and wrong GitHub URLs
└── package.json            # Defines "hve-core" as project name
```

**Key Finding**: The repository uses **GitHub Issues and Projects**, not Azure DevOps. All references to Azure DevOps work items, backlogs, and queries must be replaced with GitHub equivalents.

### Implementation Patterns

**Documentation Frontmatter Pattern** (found across all documentation):

```yaml
---
title: Document Title
description: Brief description of the document
author: Edge AI Team  # ⚠️ Needs updating
ms.date: YYYY-MM-DD
ms.topic: reference|guide
keywords:
  - keyword1
  - keyword2
estimated_reading_time: N
---
```

**Migration Pattern Identified**:
1. Keep YAML frontmatter structure
2. Update `author` field from "Edge AI Team" to appropriate team name
3. Update `ms.date` to current date (2025-11-05)
4. Update description fields containing "Edge AI" references
5. Keep all other metadata intact

**URL Replacement Pattern**:

| Old URL Pattern | New URL Pattern |
|----------------|----------------|
| `https://dev.azure.com/ai-at-the-edge-flagship-accelerator/IaC%20for%20the%20Edge/_queries/...` | `https://github.com/microsoft/hve-core/issues` |
| `https://dev.azure.com/ai-at-the-edge-flagship-accelerator/IaC%20for%20the%20Edge/_workitems/...` | `https://github.com/microsoft/hve-core/issues` |
| `https://dev.azure.com/ai-at-the-edge-flagship-accelerator/edge-ai/_workitems/...` | `https://github.com/microsoft/hve-core/issues` |
| `https://github.com/microsoft/edge-ai/issues` | `https://github.com/microsoft/hve-core/issues` |

### Complete Examples

**Example: SUPPORT.md YAML Frontmatter Update**

Current:
```yaml
---
title: Support
description: Community support commitments, response times, and escalation paths for the Edge AI Accelerator project
author: Edge AI Team
ms.date: 2025-11-04
---
```

Proposed:
```yaml
---
title: Support
description: Community support commitments, response times, and escalation paths for the HVE Core project
author: HVE Core Team
ms.date: 2025-11-05
---
```

**Example: CONTRIBUTING.md Issue Tracking Updates**

Current:
```markdown
Before you ask a question, it is best to search for existing [Issues](https://dev.azure.com/ai-at-the-edge-flagship-accelerator/IaC%20for%20the%20Edge/_queries/query/a8d3e164-fe33-43a9-83c3-b60c4c51934d/) that might help you.
```

Proposed:
```markdown
Before you ask a question, it is best to search for existing [Issues](https://github.com/microsoft/hve-core/issues) that might help you.
```

**Example: Chatmode Attribution Update**

Current:
```yaml
description: 'Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/edge-ai'
```

Proposed:
```yaml
description: 'Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core'
```

### Configuration Examples

No configuration file changes required. All updates are documentation-only.

## Technical Scenarios

### 1. Critical Priority: Azure DevOps to GitHub Migration in CONTRIBUTING.md

**Description**: The CONTRIBUTING.md file contains 8+ Azure DevOps URLs pointing to a non-existent organization (`ai-at-the-edge-flagship-accelerator`). This blocks contributors from filing issues, finding existing work items, or understanding the contribution workflow.

**Requirements:**
* Replace all Azure DevOps issue tracking URLs with GitHub Issues
* Update Azure DevOps terminology: "workitem" → "issue", "User Story or Task" → "issue"
* Update project title from "AI on Edge Flagship Accelerator" to "HVE Core"
* Update author metadata to "HVE Core Team"
* Add new section explaining build requirements (cspell, markdownlint, markdown-table-formatter)
* Remove references to non-existent documentation files (4 missing docs)
* Update work item closure notation link from Azure DevOps to GitHub

**Update CONTRIBUTING.md Structure**

```text
CONTRIBUTING.md                           # Update all Azure DevOps URLs and project references
├── YAML Frontmatter                      # Update author, description, title
├── Title Section                         # "Contributing to HVE Core"
├── Build Requirements Section            # NEW: Explain cspell, markdownlint, markdown-table-formatter
├── I Have a Question                     # Replace Azure DevOps query URLs with GitHub Issues
├── Reporting Bugs                        # Replace Azure DevOps bug tracker with GitHub Issues
├── Suggesting Enhancements               # Replace Azure DevOps Features with GitHub Issues
├── Your First Code Contribution          # Update work item → issue terminology, remove non-existent doc refs
└── Attribution Section                   # Keep as-is
```

**Implementation Details:**

**Update YAML Frontmatter**
```yaml
---
title: Contributing
description: Guidelines for contributing code, documentation, and improvements to the HVE Core project
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: guide
keywords:
  - contributing
  - code contributions
  - development workflow
  - pull requests
  - code review
  - development environment
estimated_reading_time: 8
---
```

**Update Main Title**
```markdown
# Contributing to HVE Core

First off, thanks for taking the time to contribute! ❤️
```

**Add Build Requirements Section**
```markdown
## Build and Validation Requirements

This repository uses automated tooling to maintain documentation quality and consistency:

### Linting and Formatting Tools

* **[markdownlint](https://github.com/DavidAnson/markdownlint)** - Enforces markdown style rules defined in `.markdownlint.json`
* **[cspell](https://cspell.org/)** - Spell checker with custom dictionary in `.cspell.json`
* **[markdown-table-formatter](https://github.com/nvuillam/markdown-table-formatter)** - Formats markdown tables consistently

### Running Validation Locally

Use the provided npm scripts from `package.json`:

```bash
# Run markdown linting
npm run lint:md

# Run spell checking
npm run spell-check

# Run all linters (includes markdown, spelling, and other checks)
npm run lint
```

### Development Environment

We strongly recommend using the provided [DevContainer](./.devcontainer/README.md) for development work. The DevContainer includes all required tools pre-configured.
```

**Update "I Have a Question" Section**
```markdown
Before you ask a question, it is best to search for existing [Issues](https://github.com/microsoft/hve-core/issues) that might help you.

If you then still feel the need to ask a question and need clarification, we recommend the following:

- Open an [Issue](https://github.com/microsoft/hve-core/issues/new/choose).
- Provide as much context as you can about what you're running into.
- Provide project and platform versions (nodejs, npm, etc), depending on what seems relevant.
```

**Update "Reporting Bugs" Section**
```markdown
To see if other users have experienced (and potentially already solved) the same issue you are having, check if there is not already a bug report existing for your bug or error in the [issue tracker](https://github.com/microsoft/hve-core/issues).

We use GitHub Issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](https://github.com/microsoft/hve-core/issues/new/choose).
```

**Update "Suggesting Enhancements" Section**
```markdown
Perform a [search](https://github.com/microsoft/hve-core/issues) to see if the enhancement has already been suggested.

Enhancement suggestions are tracked as [GitHub Issues](https://github.com/microsoft/hve-core/issues/new/choose).
```

**Update "Your First Code Contribution" Section**

Replace Azure DevOps terminology and links:

```markdown
When contributing code to the project, please consider the following guidance:

- Assign an issue to yourself before beginning any effort.
- If an issue for your contribution does not exist, [please file an issue](https://github.com/microsoft/hve-core/issues/new/choose) first to engage the project maintainers for guidance.
- Commits (or at least one in a commit chain) should reference an issue from the issue tracker for traceability.
- When creating a PR, ensure descriptions reference associated issues using [GitHub's linking keywords](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue).
- All code PRs destined for the `main` branch will be reviewed by pre-determined reviewer groups that are automatically added to each PR.
```

**Key Terminology Updates:**
* Line 116: "workitem" → "issue"
* Line 133: "workitem" → "issue"
* Line 135: "User Story or Task item from the backlog" → "issue from the issue tracker"
* Line 136: Replace Azure DevOps work item notation link with GitHub issue linking documentation

**Remove Non-Existent Documentation References**

Remove all references to:
* `./docs/README.md`
* `./docs/megalinter-template.md`
* `./docs/coding-conventions.md`
* `./docs/contributing/ai-assisted-engineering.md`

The build requirements section above replaces these references with concrete tool information.

#### Considered Alternatives

**Alternative: Keep Azure DevOps References**
- ❌ Not viable - Azure DevOps organization doesn't exist, would block all contributor workflows

**Alternative: Minimal Updates (URLs only)**
- ❌ Incomplete - leaves outdated terminology and missing build requirement documentation

---

### 2. High Priority: GitHub URL and Project Identity Updates in SUPPORT.md

**Description**: The SUPPORT.md file serves as the primary support contact point for users. It currently references the wrong GitHub repository (microsoft/edge-ai) and contains Edge AI-specific project names, performance metrics, and Azure services lists that may not apply to hve-core.

**Requirements:**
* Update all GitHub Issues URLs from microsoft/edge-ai to microsoft/hve-core
* Replace "Edge AI Accelerator" with "HVE Core"
* Update author metadata to "HVE Core Team"
* Keep response time commitments, remove specific performance metrics and dashboard references
* Use generic phrasing for Microsoft Support (no specific Azure services)

**Update SUPPORT.md Structure**

```text
SUPPORT.md                                # Update project identity and GitHub URLs
├── YAML Frontmatter                      # Update author, description
├── Opening Paragraph                     # "HVE Core project"
├── Community Support Section             # "HVE Core is an open-source project"
├── Support Performance Section           # Keep commitments, remove specific metrics
├── Filing Issues Section                 # Update GitHub URLs to microsoft/hve-core
├── Security Vulnerabilities Section      # Keep as-is (MSRC process is universal)
├── Microsoft Support Policy Section      # Generic phrasing for documentation repo
└── Footer Sections                       # Keep as-is (generic Microsoft content)
```

**Implementation Details:**

**Update YAML Frontmatter**
```yaml
---
title: Support
description: Community support commitments, response times, and escalation paths for the HVE Core project
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - support
  - community support
  - response times
  - escalation
  - security vulnerabilities
  - contributing
  - microsoft support
estimated_reading_time: 5
---
```

**Update Opening Paragraph**
```markdown
Thank you for using the HVE Core project! This document explains how to get help with issues, questions, and contributions.

## How to Get Support

### Community Support

HVE Core is an open-source project maintained by Microsoft and community contributors. We provide community support through GitHub issue tracking with the following response commitments:
```

**Update GitHub Issues URLs**
```markdown
## Filing Issues

### General Issues, Bugs, and Feature Requests

1. **Search existing issues** in our [GitHub Issues](https://github.com/microsoft/hve-core/issues)
2. **Create a new issue** if yours isn't already tracked: [New Issue](https://github.com/microsoft/hve-core/issues/new/choose)
```

**Update Support Performance Section**

Remove specific metrics and dashboard reference, keep response time commitments:

```markdown
### Our Support Performance

We are committed to responsive community support and strive to:

* Acknowledge new issues within 48 hours
* Provide initial responses to questions and bug reports promptly
* Review pull requests in a timely manner

Response times may vary based on issue complexity and maintainer availability.
```

**Update Microsoft Support Policy Section**

Use generic phrasing for a primarily documentation-focused repository:

```markdown
## Microsoft Support Policy

This is an open-source project maintained by Microsoft. For issues with the HVE Core repository, documentation, or tooling, please use our [GitHub Issues](https://github.com/microsoft/hve-core/issues).

For support with Microsoft products and services referenced in this documentation, please contact [Microsoft Support](https://support.microsoft.com/).
```

#### Considered Alternatives

**Alternative: Minimal URL Updates Only**
- ❌ Incomplete - leaves project identity mismatched, confusing for users

**Alternative: Wait for Official Branding**
- ❌ Blocks repository usability - users need correct support channels immediately

---

### 3. Medium Priority: Author Metadata Updates in Workflow Documentation

**Description**: The `.github/workflows/README.md` and `.github/BRANCH_PROTECTION.md` files contain accurate technical content but have outdated "Edge AI Team" author metadata in YAML frontmatter.

**Requirements:**
* Update author metadata to "HVE Core Team"
* Preserve all technical content (workflows, branch protection rules)
* Update documentation date to 2025-11-05

**Preferred Approach:**

Simple metadata-only updates without content changes.

```text
.github/workflows/README.md               # Update author metadata only
└── YAML Frontmatter                      # Author field only

.github/BRANCH_PROTECTION.md              # Update author metadata only
└── YAML Frontmatter                      # Author field only
```

**Implementation Details:**

**.github/workflows/README.md Update**
```yaml
---
title: GitHub Actions Workflows
description: Modular CI/CD workflow architecture for validation, security scanning, and automated maintenance
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - github actions
  - ci/cd
  - workflows
  - security scanning
  - automation
  - reusable workflows
estimated_reading_time: 15
---
```

**.github/BRANCH_PROTECTION.md Update**
```yaml
---
title: Branch Protection Rules
description: Required branch protection settings and validation requirements for the main branch
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - branch protection
  - pull requests
  - code review
  - required checks
  - repository settings
estimated_reading_time: 4
---
```

**Note**: All other content in these files is accurate and repository-specific. The `.github/BRANCH_PROTECTION.md` correctly references `@microsoft/hve-core-admins` team, confirming proper repository identity elsewhere in the content.

#### Considered Alternatives

No alternatives - straightforward metadata update with no technical implications.

---

### 5. Medium Priority: Additional Chatmode Attribution Updates

**Description**: Two additional chatmode files (`task-researcher.chatmode.md` and `task-planner.chatmode.md`) were discovered during technical review, both containing `microsoft/edge-ai` attribution.

**Requirements:**
* Update attribution from microsoft/edge-ai to microsoft/hve-core
* Maintain consistency with pr-review and prompt-builder chatmode updates

**Files to Update:**

```text
.github/chatmodes/task-researcher.chatmode.md  # Update description attribution
└── YAML Frontmatter                           # Description field only

.github/chatmodes/task-planner.chatmode.md     # Update description attribution
└── YAML Frontmatter                           # Description field only
```

**Implementation Details:**

**.github/chatmodes/task-researcher.chatmode.md Update**
```yaml
---
description: 'Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core'
tools: ['usages', 'think', 'problems', 'fetch', 'githubRepo', 'runCommands', 'edit/createFile', 'edit/createDirectory', 'edit/editFiles', 'search', 'Bicep (EXPERIMENTAL)/*', 'terraform/*', 'context7/*', 'microsoft-docs/*']
---
```

**.github/chatmodes/task-planner.chatmode.md Update**
```yaml
---
description: 'Task planner for creating actionable implementation plans - Brought to you by microsoft/hve-core'
tools: ['usages', 'think', 'problems', 'fetch', 'githubRepo', 'runCommands', 'edit/createFile', 'edit/createDirectory', 'edit/editFiles', 'search', 'Bicep (EXPERIMENTAL)/*', 'terraform/*', 'context7/*', 'microsoft-docs/*']
---
```

**Estimated Effort:** 2 minutes

#### Considered Alternatives

No alternatives - maintains consistency with other chatmode attribution updates.

---

### 6. Optional Enhancement: GitHub Issue Terminology in pr-review.chatmode.md

**Description**: The pr-review chatmode contains Azure DevOps terminology ("Work Items") in its functional template and instructions. For consistency with GitHub-based workflows, consider updating to "Issues".

**Requirements:**
* Update template field from "Linked Work Items" to "Linked Issues"
* Update instructions from "linked work items" to "linked issues"

**Files to Update:**

```text
.github/chatmodes/pr-review.chatmode.md  # Update Work Items → Issues terminology
├── Line 92                              # Template field
└── Line 148                             # Instructions
```

**Implementation Details:**

**Line 92 Update:**
```markdown
* Linked Issues: {{links or `None`}}
```

**Line 148 Update:**
```markdown
* Record branch metadata, normalized branch name, command outputs, author-declared intent, linked issues, and explicit success criteria or assumptions gathered from the PR description or conversation.
```

**Note**: This is optional - the chatmode is functional as-is. This change improves consistency with GitHub terminology used throughout the repository.

**Estimated Effort:** 1 minute

#### Considered Alternatives

**Alternative: Keep "Work Items" terminology**
- ⚠️ Functional but inconsistent with GitHub Issues migration in other documentation
- Selected approach provides better consistency

---

### 7. High Priority: Documentation Footer Standardization

**Description**: Add standardized Copilot-generated footer to all root-level markdown documentation files (excluding chatmodes, prompts, and instructions) to provide consistent attribution.

**Requirements:**
* Add footer to 6 root-level documentation files
* Use approved footer text: `🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.`
* Exclude: `.github/chatmodes/*.chatmode.md`, `.github/instructions/*.md`, `.copilot-tracking/**`

**Files to Update:**

```text
CODE_OF_CONDUCT.md                      # Add footer at end
CONTRIBUTING.md                         # Add footer at end
SECURITY.md                             # Add footer at end
SUPPORT.md                              # Add footer at end
.github/workflows/README.md             # Add footer at end
.github/BRANCH_PROTECTION.md            # Add footer at end
```

**Implementation Details:**

**Standard Footer Format:**
```markdown

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
```

**Placement:**
* Add at end of file after final content
* Insert blank line before horizontal rule
* No additional blank lines after footer text

**Example Application (SUPPORT.md):**
```markdown
[...existing content...]

## Additional Resources

* [GitHub Docs](https://docs.github.com)
* [Microsoft Open Source Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
```

**Estimated Effort:** 5 minutes

#### Considered Alternatives

**Alternative: No footer attribution**
- ❌ Loses transparency about AI assistance in documentation creation
- Footer provides clear attribution and acknowledgment

**Alternative: Shorter footer**
- ❌ User-specified footer text provides appropriate detail and tone
- Selected text balances AI acknowledgment with human oversight

---

### 4. Low Priority: Chatmode Attribution Updates

**Description**: The chatmode definition files (`.github/chatmodes/pr-review.chatmode.md` and `.github/chatmodes/prompt-builder.chatmode.md`) contain "Brought to you by microsoft/edge-ai" attribution in their description metadata.

**Requirements:**
* Update attribution from microsoft/edge-ai to microsoft/hve-core
* Preserve all functional chatmode content

**Preferred Approach:**

Simple description field updates in YAML frontmatter.

```text
.github/chatmodes/pr-review.chatmode.md   # Update description attribution
└── YAML Frontmatter                      # Description field only

.github/chatmodes/prompt-builder.chatmode.md  # Update description attribution
└── YAML Frontmatter                      # Description field only
```

**Implementation Details:**

**.github/chatmodes/pr-review.chatmode.md Update**
```yaml
---
description: 'Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core'
tools: ['usages', 'think', 'problems', 'fetch', 'githubRepo', 'edit/createFile', 'edit/createDirectory', 'edit/editFiles', 'search', 'runCommands', 'runTasks', 'Bicep (EXPERIMENTAL)/*', 'terraform/*', 'context7/*', 'microsoft-docs/*']
---
```

**.github/chatmodes/prompt-builder.chatmode.md Update**
```yaml
---
description: 'Expert prompt engineering and validation system for creating high-quality prompts - Brought to you by microsoft/hve-core'
tools: ['usages', 'think', 'problems', 'fetch', 'githubRepo', 'runCommands', 'edit/createFile', 'edit/createDirectory', 'edit/editFiles', 'search', 'Bicep (EXPERIMENTAL)/*', 'terraform/*', 'context7/*', 'microsoft-docs/*']
---
```

#### Considered Alternatives (Removed After Selection)

**Alternative 1: Remove Attribution Entirely**
- ⚠️ Loses credit for origin repository
- Preferred approach maintains acknowledgment while updating repository reference

**Alternative 2: Keep Edge-AI Attribution**
- ❌ Misleading for users of hve-core repository
- Makes it unclear which repository the chatmodes are for

---

## Outstanding Decisions Required

### 🤔 Decision 1: Official Project Name

**Question**: What is the official full name of the HVE Core project?

**Current Evidence**:
* `package.json` uses "HVE Core" as project name
* Repository name is `hve-core`
* No expanded acronym found in existing documentation

**Options**:
1. **"HVE Core"** (matches package.json exactly)
2. **"Hyperscale Virtualization Engine Core"** (example expansion)
3. **"HVE Core Platform"** (add descriptor)
4. **Other** (pending team decision)

**Impact**: Affects CONTRIBUTING.md title, SUPPORT.md content, and all user-facing documentation

**Recommendation**: Use "HVE Core" as documented in package.json unless team provides alternative

---

### 🤔 Decision 2: Team Name for Author Metadata

**Question**: What team name should replace "Edge AI Team" in documentation author fields?

**Current Evidence**:
* Repository owner: "Microsoft"
* Repository: `microsoft/hve-core`
* No team name found in existing files

**Options**:
1. **"HVE Core Team"** (mirrors project name)
2. **"Microsoft HVE Core Team"** (include parent org)
3. **Specific team name** (e.g., "Azure Infrastructure Team")
4. **Remove author field entirely** (use Microsoft as sole attribution)

**Impact**: Affects YAML frontmatter in all 6 documentation files

**Recommendation**: Use "HVE Core Team" for consistency with project naming

---

### 🤔 Decision 3: Support Performance Metrics

**Question**: Do the Edge AI support metrics (87.5%-100% SLO compliance, 2.91 day average) apply to HVE Core?

**Current Evidence**:
* Metrics reference non-existent `docs/contributions.md` dashboard
* Specific numbers suggest data from operational Edge AI project
* No equivalent data source found in hve-core repository

**Options**:
1. **Remove section entirely** (no performance data available)
2. **Keep structure, remove numbers** (commitment without metrics)
3. **Keep as-is** (if metrics transfer or dashboard will be created)

**Impact**: Affects SUPPORT.md credibility and user expectations

**Recommendation**: Remove specific metrics until HVE Core establishes its own performance tracking

---

### 🤔 Decision 4: Azure Services Scope

**Question**: What Azure services does HVE Core actually use or support?

**Current Evidence**:
* Edge AI listed: "Azure IoT Operations, Azure Arc, Azure Kubernetes Service"
* No clear indication if hve-core uses same services
* Repository contains GitHub Actions workflows and security scripts

**Options**:
1. **Keep Edge AI services list** (if scope is identical)
2. **Update to different services** (if hve-core has different scope)
3. **Remove specific services** (use generic "Azure services" phrasing)
4. **Remove paragraph entirely** (if not applicable)

**Impact**: Affects SUPPORT.md Microsoft Support Policy section and user expectations

**Recommendation**: Use generic phrasing ("Azure services used by HVE Core") until specific services are confirmed

---

### 🤔 Decision 5: Non-Existent Documentation References

**Question**: How should CONTRIBUTING.md handle references to documentation that doesn't exist?

**Current References**:
* `./docs/README.md`
* `./docs/build-cicd/pipelines/azure-devops/templates/megalinter-template.md`
* `./docs/coding-conventions.md`
* `./docs/contributing/ai-assisted-engineering.md`

**Options**:
1. **Remove all references** (cleanest, acknowledges current state)
2. **Create stub files** (requires additional work)
3. **Link to GitHub repository root** (generic fallback)
4. **Keep references as TODO** (technical debt marker)

**Impact**: Affects contributor workflow and documentation completeness

**Recommendation**: Remove references to non-existent docs and replace with generic guidance until documentation is created

---

## Summary of Changes by Priority

### 🔴 Critical Priority (Blocks Contributors)

1. **CONTRIBUTING.md** - 8+ broken Azure DevOps URLs, wrong project name, non-existent docs
   * Azure DevOps → GitHub Issues migration
   * Project title update
   * Work item → Issue terminology
   * Remove non-existent doc references

### 🟡 High Priority (User-Facing Errors)

2. **SUPPORT.md** - Wrong GitHub repository URLs, wrong project name
   * microsoft/edge-ai → microsoft/hve-core URLs
   * Edge AI Accelerator → HVE Core project name
   * Validate or remove performance metrics
   * Update or generalize Azure services list

### 🟢 Medium Priority (Metadata Accuracy)

3. **.github/workflows/README.md** - Author metadata only
4. **.github/BRANCH_PROTECTION.md** - Author metadata only

### 🔵 Low Priority (Internal Tool Attribution)

5. **.github/chatmodes/pr-review.chatmode.md** - Attribution line
6. **.github/chatmodes/prompt-builder.chatmode.md** - Attribution line

### ✅ No Changes Needed

7. **CODE_OF_CONDUCT.md** - Generic Microsoft template
8. **SECURITY.md** - Generic Microsoft template

---

## Next Steps

To proceed with implementation:

1. ✅ **Decisions obtained** - All 5 decisions provided by user
2. **Create implementation branch** (suggested name: `docs/migrate-edge-ai-references`)
3. **Apply updates** in priority order:
   * Critical: CONTRIBUTING.md (Azure DevOps URLs, terminology, project identity, build requirements)
   * High: SUPPORT.md (GitHub URLs, project identity, metrics, Azure services)
   * High: Footer standardization (6 root-level documentation files)
   * Medium: .github/workflows/README.md and .github/BRANCH_PROTECTION.md (author metadata)
   * Medium: All 4 chatmode attribution updates (pr-review, prompt-builder, task-researcher, task-planner)
   * Optional: pr-review.chatmode.md Work Items terminology
4. **Validate changes** with linting and spelling checks:
   * `npm run lint:md`
   * `npm run spell-check`
5. **Create pull request** with comprehensive change documentation

**Estimated Implementation Time**: 3-3.5 hours

**Breakdown:**
* CONTRIBUTING.md: 45-60 minutes (Critical - URLs, YAML, build requirements, terminology, doc references)
* SUPPORT.md: 30-40 minutes (High - URLs, project naming, metrics, Azure services)
* Footer standardization: 5 minutes (High - 6 files)
* .github/workflows/README.md: 5 minutes (Medium - author metadata)
* .github/BRANCH_PROTECTION.md: 5 minutes (Medium - author metadata)
* pr-review.chatmode.md: 3 minutes (Medium - attribution)
* prompt-builder.chatmode.md: 3 minutes (Medium - attribution)
* task-researcher.chatmode.md: 2 minutes (Medium - attribution)
* task-planner.chatmode.md: 2 minutes (Medium - attribution)
* Validation: 15-20 minutes (linting and spell-check)
* PR documentation: 25-35 minutes

---

*📋 Research completed: 2025-11-05*
*🔍 Files analyzed: 10 documentation files*
*⚠️ Critical issues found: 1 (CONTRIBUTING.md blocks contributor workflow)*
*🔴 High priority: 2 (SUPPORT.md blocks support channels + Footer standardization)*
*🟢 Medium priority: 6 (2 workflow docs + 4 chatmode files)*
*🔵 Optional: 1 (pr-review Work Items terminology)*
*✅ No Edge-AI changes: 2 (CODE_OF_CONDUCT.md, SECURITY.md require footer only)*
