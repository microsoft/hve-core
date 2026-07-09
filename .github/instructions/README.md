---
title: GitHub Copilot Instructions
description: Repository-specific coding guidelines and conventions for GitHub Copilot
author: HVE Core Team
ms.date: 2026-07-09
ms.topic: reference
keywords:
  - copilot
  - instructions
  - coding standards
  - guidelines
estimated_reading_time: 5
---

## GitHub Copilot Instructions

Repository-specific guidelines that GitHub Copilot automatically applies when
editing files. Instructions ensure consistent code style and conventions across
the codebase.

## How Instructions Work

1. Instruction files declare which file patterns they apply to using `applyTo`
   in frontmatter
2. GitHub Copilot reads instructions when editing matching files
3. Suggestions follow the documented standards automatically

Custom agents and the `prompt-builder` agent respect these instructions and can create new ones.
See [Contributing Instructions](../../docs/contributing/instructions.md) for authoring guidance.

## Available Instructions

### Language and Technology

| File                                                                                                                           | Applies To                                     | Purpose                                  |
|--------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------|------------------------------------------|
| [coding-standards/bash/bash.instructions.md](coding-standards/bash/bash.instructions.md)                                       | `**/*.sh`                                      | Bash script implementation standards     |
| [coding-standards/bicep/bicep.instructions.md](coding-standards/bicep/bicep.instructions.md)                                   | `**/bicep/**`                                  | Bicep infrastructure as code patterns    |
| [coding-standards/code-review/diff-computation.instructions.md](coding-standards/code-review/diff-computation.instructions.md) | Code review agents                             | Diff computation for code review         |
| [coding-standards/code-review/review-artifacts.instructions.md](coding-standards/code-review/review-artifacts.instructions.md) | `**/.copilot-tracking/reviews/code-reviews/**` | Code review artifact persistence         |
| [coding-standards/csharp/csharp.instructions.md](coding-standards/csharp/csharp.instructions.md)                               | `**/*.cs`                                      | C# implementation and coding conventions |
| [coding-standards/csharp/csharp-tests.instructions.md](coding-standards/csharp/csharp-tests.instructions.md)                   | `**/*.cs`                                      | C# test code standards                   |
| [coding-standards/powershell/powershell.instructions.md](coding-standards/powershell/powershell.instructions.md)               | `**/*.ps1, **/*.psm1, **/*.psd1`               | PowerShell scripting conventions         |
| [coding-standards/powershell/pester.instructions.md](coding-standards/powershell/pester.instructions.md)                       | `**/*.Tests.ps1`                               | Pester testing conventions               |
| [coding-standards/python-script.instructions.md](coding-standards/python-script.instructions.md)                               | `**/*.py`                                      | Python scripting implementation          |
| [coding-standards/python-tests.instructions.md](coding-standards/python-tests.instructions.md)                                 | `**/*.py`                                      | Python test code standards               |
| [coding-standards/rust/rust.instructions.md](coding-standards/rust/rust.instructions.md)                                       | `**/*.rs`                                      | Rust development conventions             |
| [coding-standards/rust/rust-tests.instructions.md](coding-standards/rust/rust-tests.instructions.md)                           | `**/*.rs`                                      | Rust test code standards                 |
| [coding-standards/terraform/terraform.instructions.md](coding-standards/terraform/terraform.instructions.md)                   | `**/*.tf, **/*.tfvars, **/terraform/**`        | Terraform infrastructure as code         |
| [coding-standards/uv-projects.instructions.md](coding-standards/uv-projects.instructions.md)                                   | `**/*.py, **/*.ipynb`                          | Python virtual environments using uv     |

### Documentation and Content

| File                                                                               | Applies To                                            | Purpose                               |
|------------------------------------------------------------------------------------|-------------------------------------------------------|---------------------------------------|
| [hve-core/markdown.instructions.md](hve-core/markdown.instructions.md)             | `**/*.md`                                             | Markdown formatting standards         |
| [hve-core/writing-style.instructions.md](hve-core/writing-style.instructions.md)   | `**/*.md`                                             | Voice, tone, and language conventions |
| [hve-core/prompt-builder.instructions.md](hve-core/prompt-builder.instructions.md) | `**/*.prompt.md, **/*.agent.md, **/*.instructions.md` | Prompt engineering artifact authoring |
| [docusaurus-edits.instructions.md](docusaurus-edits.instructions.md)               | `docs/**`                                             | Docusaurus documentation authoring    |

### Git and Workflow

| File                                                                               | Applies To                   | Purpose                               |
|------------------------------------------------------------------------------------|------------------------------|---------------------------------------|
| [hve-core/commit-message.instructions.md](hve-core/commit-message.instructions.md) | Commit actions               | Conventional commit message format    |
| [hve-core/git-merge.instructions.md](hve-core/git-merge.instructions.md)           | Git operations               | Merge, rebase, and conflict handling  |
| [hve-core/pull-request.instructions.md](hve-core/pull-request.instructions.md)     | `**/.copilot-tracking/pr/**` | PR generation workflow with subagents |
| [pull-request.instructions.md](pull-request.instructions.md)                       | `**/.copilot-tracking/pr/**` | Repo-specific PR conventions          |

### Repository Workflow

| File                                                                                     | Applies To                              | Purpose                                          |
|------------------------------------------------------------------------------------------|-----------------------------------------|--------------------------------------------------|
| [hve-core/copilot-tracking.instructions.md](hve-core/copilot-tracking.instructions.md)   | `.copilot-tracking/**`                  | Intermediate tracking artifact conventions       |
| [hve-core/licensing-posture.instructions.md](hve-core/licensing-posture.instructions.md) | `**/skills/**, **/.copilot-tracking/**` | Licensing, reproduction, and attribution posture |
| [skill-security-model.instructions.md](skill-security-model.instructions.md)             | `**/.github/skills/**/SECURITY.md`      | Per-skill STRIDE security model rules            |
| [workflows.instructions.md](workflows.instructions.md)                                   | `**/.github/workflows/*.yml`            | GitHub Actions workflow conventions              |

### Azure DevOps Integration

| File                                                                                           | Applies To                                          | Purpose                               |
|------------------------------------------------------------------------------------------------|-----------------------------------------------------|---------------------------------------|
| [ado/ado-backlog-sprint.instructions.md](ado/ado-backlog-sprint.instructions.md)               | `**/.copilot-tracking/workitems/sprint/**`          | Sprint planning coverage and capacity |
| [ado/ado-backlog-triage.instructions.md](ado/ado-backlog-triage.instructions.md)               | `**/.copilot-tracking/workitems/triage/**`          | Work item triage workflow             |
| [ado/ado-create-pull-request.instructions.md](ado/ado-create-pull-request.instructions.md)     | `**/.copilot-tracking/pr/new/**`                    | Pull request creation protocol        |
| [ado/ado-get-build-info.instructions.md](ado/ado-get-build-info.instructions.md)               | `**/.copilot-tracking/pr/*-build-*.md`              | Build status and log retrieval        |
| [ado/ado-interaction-templates.instructions.md](ado/ado-interaction-templates.instructions.md) | `**/.github/instructions/ado/**`                    | Work item content templates           |
| [ado/ado-update-wit-items.instructions.md](ado/ado-update-wit-items.instructions.md)           | `**/.copilot-tracking/workitems/**/handoff-logs.md` | Work item creation and updates        |
| [ado/ado-wit-discovery.instructions.md](ado/ado-wit-discovery.instructions.md)                 | `**/.copilot-tracking/workitems/discovery/**`       | Work item discovery protocol          |
| [ado/ado-wit-planning.instructions.md](ado/ado-wit-planning.instructions.md)                   | `**/.copilot-tracking/workitems/**`                 | Work item planning specifications     |

### GitHub Integration

| File                                                                                               | Applies To                                                 | Purpose                              |
|----------------------------------------------------------------------------------------------------|------------------------------------------------------------|--------------------------------------|
| [github/community-interaction.instructions.md](github/community-interaction.instructions.md)       | `**/.github/instructions/github-backlog-*.instructions.md` | GitHub-facing communication patterns |
| [github/github-backlog-discovery.instructions.md](github/github-backlog-discovery.instructions.md) | `**/.copilot-tracking/github-issues/discovery/**`          | Issue discovery protocol             |
| [github/github-backlog-planning.instructions.md](github/github-backlog-planning.instructions.md)   | `**/.copilot-tracking/github-issues/**`                    | Backlog planning specifications      |
| [github/github-backlog-triage.instructions.md](github/github-backlog-triage.instructions.md)       | `**/.copilot-tracking/github-issues/triage/**`             | Issue triage workflow                |
| [github/github-backlog-update.instructions.md](github/github-backlog-update.instructions.md)       | `**/.copilot-tracking/github-issues/**/handoff-logs.md`    | Issue execution workflow             |

### Jira Integration

| File                                                                                       | Applies To                                            | Purpose                              |
|--------------------------------------------------------------------------------------------|-------------------------------------------------------|--------------------------------------|
| [jira/jira-backlog-discovery.instructions.md](jira/jira-backlog-discovery.instructions.md) | `**/.copilot-tracking/jira-issues/discovery/**`       | Jira issue discovery protocol        |
| [jira/jira-backlog-planning.instructions.md](jira/jira-backlog-planning.instructions.md)   | `**/.copilot-tracking/jira-issues/**`                 | Jira backlog planning specifications |
| [jira/jira-backlog-triage.instructions.md](jira/jira-backlog-triage.instructions.md)       | `**/.copilot-tracking/jira-issues/triage/**`          | Jira issue triage workflow           |
| [jira/jira-backlog-update.instructions.md](jira/jira-backlog-update.instructions.md)       | `**/.copilot-tracking/jira-issues/**/handoff-logs.md` | Jira issue execution workflow        |
| [jira/jira-wit-planning.instructions.md](jira/jira-wit-planning.instructions.md)           | `**/.copilot-tracking/jira-issues/prds/**`            | Jira PRD work item planning          |

### Planning and Governance Agents

The instructions below are scoped to specific planning agents and their `.copilot-tracking/` working directories rather than to general source edits.

#### Accessibility

| File                                                                                                                       | Applies To                                                                  | Purpose                                     |
|----------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------|
| [accessibility/accessibility-identity.instructions.md](accessibility/accessibility-identity.instructions.md)               | `**/.copilot-tracking/accessibility/**`                                     | Accessibility Planner identity and workflow |
| [accessibility/accessibility-license-posture.instructions.md](accessibility/accessibility-license-posture.instructions.md) | `**/.github/skills/accessibility/**, **/.copilot-tracking/accessibility/**` | Accessibility licensing overlay             |

#### Privacy

| File                                                                                 | Applies To                              | Purpose                               |
|--------------------------------------------------------------------------------------|-----------------------------------------|---------------------------------------|
| [privacy/privacy-identity.instructions.md](privacy/privacy-identity.instructions.md) | `**/.copilot-tracking/privacy-plans/**` | Privacy Planner identity and workflow |

#### Responsible AI

| File                                                                                                 | Applies To                                              | Purpose                           |
|------------------------------------------------------------------------------------------------------|---------------------------------------------------------|-----------------------------------|
| [rai-planning/rai-identity.instructions.md](rai-planning/rai-identity.instructions.md)               | `**/.copilot-tracking/rai-plans/**`                     | RAI Planner identity and workflow |
| [rai-planning/rai-license-posture.instructions.md](rai-planning/rai-license-posture.instructions.md) | `**/skills/rai**/**, **/.copilot-tracking/rai-plans/**` | RAI licensing overlay             |

#### Project Planning (ADRs)

| File                                                                                                   | Applies To                                                    | Purpose                                    |
|--------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|--------------------------------------------|
| [project-planning/adr-identity.instructions.md](project-planning/adr-identity.instructions.md)         | `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**` | ADR Creator identity and state machine     |
| [project-planning/adr-standards.instructions.md](project-planning/adr-standards.instructions.md)       | `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**` | Embedded ADR standards (MADR, Y-Statement) |
| [project-planning/adr-byo-template.instructions.md](project-planning/adr-byo-template.instructions.md) | `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**` | BYO ADR template contract                  |
| [project-planning/adr-handoff.instructions.md](project-planning/adr-handoff.instructions.md)           | `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**` | ADR Govern-phase handoff protocol          |

#### Security

| File                                                                                     | Applies To                                                 | Purpose                                |
|------------------------------------------------------------------------------------------|------------------------------------------------------------|----------------------------------------|
| [security/identity.instructions.md](security/identity.instructions.md)                   | `**/.copilot-tracking/security-plans/**`                   | Security Planner identity and workflow |
| [security/standards-mapping.instructions.md](security/standards-mapping.instructions.md) | `**/.copilot-tracking/security-plans/**`                   | OWASP and NIST standards references    |
| [security/sssc-planner.instructions.md](security/sssc-planner.instructions.md)           | `**/.copilot-tracking/sssc-plans/**`                       | SSSC Planner identity and workflow     |
| [security/vex-standards.instructions.md](security/vex-standards.instructions.md)         | `**/security/vex/**, **/.copilot-tracking/security/vex/**` | OpenVEX document standards             |
| [security/vex-generation.instructions.md](security/vex-generation.instructions.md)       | Security reviewer agents                                   | VEX generation rules                   |

#### Shared Planner Scaffolds

| File                                                                                                   | Applies To                                                         | Purpose                                           |
|--------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|---------------------------------------------------|
| [shared/hve-core-location.instructions.md](shared/hve-core-location.instructions.md)                   | `**`                                                               | Fallback location guidance for hve-core artifacts |
| [shared/content-policy-citation.instructions.md](shared/content-policy-citation.instructions.md)       | `**/*.agent.md, **/*.prompt.md, **/*.instructions.md, **/SKILL.md` | Content-policy and terms-of-service guardrails    |
| [shared/story-quality.instructions.md](shared/story-quality.instructions.md)                           | `**/*.agent.md, **/.github/instructions/ado/**`                    | Story quality conventions                         |
| [shared/coaching-patterns.instructions.md](shared/coaching-patterns.instructions.md)                   | Planning agents                                                    | Exploration-first coaching patterns               |
| [shared/planner-identity-base.instructions.md](shared/planner-identity-base.instructions.md)           | Planning agents                                                    | Shared planner identity scaffold                  |
| [shared/disclaimer-language.instructions.md](shared/disclaimer-language.instructions.md)               | Planning and review agents                                         | Professional-review disclaimer language           |
| [shared/telemetry-overlay.instructions.md](shared/telemetry-overlay.instructions.md)                   | Planning and review agents                                         | Telemetry vocabulary overlay                      |
| [shared/untrusted-content-boundary.instructions.md](shared/untrusted-content-boundary.instructions.md) | Planning and DT/UX agents                                          | Untrusted-content boundary rules                  |

#### Experimental

| File                                                                                                 | Applies To                    | Purpose                                       |
|------------------------------------------------------------------------------------------------------|-------------------------------|-----------------------------------------------|
| [experimental/experiment-designer.instructions.md](experimental/experiment-designer.instructions.md) | `**/.copilot-tracking/mve/**` | MVE experiment designer conventions           |
| [experimental/graphify.instructions.md](experimental/graphify.instructions.md)                       | `**/graphify-out/**`          | Graphify knowledge-graph evidence conventions |
| [experimental/pptx.instructions.md](experimental/pptx.instructions.md)                               | `**/.copilot-tracking/ppt/**` | PowerPoint builder conventions                |

The `experimental/mural/` directory holds the Mural workflow instruction set (bootstrap, seeding, writeback, and log-hygiene rules) scoped to the DT, RAI, and UX/UI agents; see [experimental/mural/mural-bootstrap.instructions.md](experimental/mural/mural-bootstrap.instructions.md) as the entry point.

### GitLab Workflow Entry Points

This README indexes instruction files. GitLab delivery support is currently discoverable through the local skill and provider-aware project-planning agents.

* Use [../skills/gitlab/gitlab/SKILL.md](../skills/gitlab/gitlab/SKILL.md) when delivery context lives in GitLab and you need merge request, pipeline, or job operations.
* Keep GitLab delivery workflows distinct from backlog planning unless GitLab is also the system of record for work tracking.

## XML-Style Blocks

Instructions use XML-style comment blocks for structured content:

* **Purpose**: Enables automated extraction, better navigation, and consistency
* **Format**: Kebab-case tags in HTML comments on their own lines
* **Examples**: `<!-- <example-bash> -->`, `<!-- <schema-config> -->`
* **Nesting**: Allowed with distinct tag names
* **Closing**: Always required with matching tag names

````markdown
<!-- <example-terraform> -->
```terraform
resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "eastus"
}
```
<!-- </example-terraform> -->
````

## Creating New Instructions

Use the **prompt-builder** agent to create new instruction files:

1. Open Copilot Chat and select **prompt-builder** from the agent picker
2. Provide context (files, folders, or requirements)
3. Prompt Builder researches and drafts instructions
4. Auto-validates with Prompt Tester (up to 3 iterations)
5. Delivered to `.github/instructions/`

For manual creation, see [Contributing Instructions](../../docs/contributing/instructions.md).

## Directory Structure

```text
.github/instructions/
├── accessibility/                    # Accessibility planning
│   ├── accessibility-identity.instructions.md
│   └── accessibility-license-posture.instructions.md
├── ado/                              # Azure DevOps workflows
│   ├── ado-backlog-sprint.instructions.md
│   ├── ado-backlog-triage.instructions.md
│   ├── ado-create-pull-request.instructions.md
│   ├── ado-get-build-info.instructions.md
│   ├── ado-interaction-templates.instructions.md
│   ├── ado-update-wit-items.instructions.md
│   ├── ado-wit-discovery.instructions.md
│   └── ado-wit-planning.instructions.md
├── coding-standards/                 # Language and technology conventions
│   ├── bash/
│   │   └── bash.instructions.md
│   ├── bicep/
│   │   └── bicep.instructions.md
│   ├── code-review/
│   │   ├── diff-computation.instructions.md
│   │   └── review-artifacts.instructions.md
│   ├── csharp/
│   │   ├── csharp.instructions.md
│   │   └── csharp-tests.instructions.md
│   ├── powershell/
│   │   ├── pester.instructions.md
│   │   └── powershell.instructions.md
│   ├── rust/
│   │   ├── rust.instructions.md
│   │   └── rust-tests.instructions.md
│   ├── terraform/
│   │   └── terraform.instructions.md
│   ├── python-script.instructions.md
│   ├── python-tests.instructions.md
│   └── uv-projects.instructions.md
├── experimental/                     # Experimental workflows
│   ├── mural/
│   │   ├── destinations/
│   │   ├── mural-bootstrap.instructions.md
│   │   ├── mural-destinations.instructions.md
│   │   ├── mural-human-record.instructions.md
│   │   ├── mural-log-hygiene.instructions.md
│   │   ├── mural-seeding-patterns.instructions.md
│   │   ├── mural-writeback-hygiene.instructions.md
│   │   └── mural-writing-style.instructions.md
│   ├── experiment-designer.instructions.md
│   ├── graphify.instructions.md
│   └── pptx.instructions.md
├── github/                           # GitHub integration
│   ├── community-interaction.instructions.md
│   ├── github-backlog-discovery.instructions.md
│   ├── github-backlog-planning.instructions.md
│   ├── github-backlog-triage.instructions.md
│   └── github-backlog-update.instructions.md
├── hve-core/                         # HVE Core workflow
│   ├── commit-message.instructions.md
│   ├── copilot-tracking.instructions.md
│   ├── git-merge.instructions.md
│   ├── licensing-posture.instructions.md
│   ├── markdown.instructions.md
│   ├── prompt-builder.instructions.md
│   ├── pull-request.instructions.md
│   └── writing-style.instructions.md
├── jira/                             # Jira backlog workflows
│   ├── jira-backlog-discovery.instructions.md
│   ├── jira-backlog-planning.instructions.md
│   ├── jira-backlog-triage.instructions.md
│   ├── jira-backlog-update.instructions.md
│   └── jira-wit-planning.instructions.md
├── privacy/                          # Privacy planning
│   └── privacy-identity.instructions.md
├── project-planning/                 # Project planning and ADRs
│   ├── adr-byo-template.instructions.md
│   ├── adr-handoff.instructions.md
│   ├── adr-identity.instructions.md
│   └── adr-standards.instructions.md
├── rai-planning/                     # Responsible AI planning
│   ├── rai-identity.instructions.md
│   └── rai-license-posture.instructions.md
├── security/                         # Security planning
│   ├── identity.instructions.md
│   ├── sssc-planner.instructions.md
│   ├── standards-mapping.instructions.md
│   ├── vex-generation.instructions.md
│   └── vex-standards.instructions.md
├── shared/                           # Cross-collection
│   ├── coaching-patterns.instructions.md
│   ├── content-policy-citation.instructions.md
│   ├── disclaimer-language.instructions.md
│   ├── hve-core-location.instructions.md
│   ├── planner-identity-base.instructions.md
│   ├── story-quality.instructions.md
│   ├── telemetry-overlay.instructions.md
│   └── untrusted-content-boundary.instructions.md
├── docusaurus-edits.instructions.md
├── pull-request.instructions.md
├── skill-security-model.instructions.md
├── workflows.instructions.md
└── README.md
```

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
