---
title: Contributing
description: Guidelines for contributing code, documentation, and improvements to the HVE Core project
author: HVE Core Team
ms.date: 2026-02-07
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

First off, thanks for taking the time to contribute! ❤️

All types of contributions are encouraged and valued. See the [Table of Contents](#table-of-contents) for different ways to help and details about how this project handles them. Please make sure to read the relevant section before making your contribution. It will make it a lot easier for us maintainers and smooth out the experience for all involved. The community looks forward to your contributions. 🎉

> And if you like the project, but just don't have time to contribute, that's fine. There are other easy ways to support the project and show your appreciation, which we would also be very happy about:
>
> - Star the project or add it to your favorites
> - Mention the project to your peer studio crews and tell your work friends/colleagues

## Build and Validation Requirements

This project uses several tools to maintain code quality and consistency:

### Required Tools

- **markdownlint** - Validates markdown formatting and style
- **cspell** - Spell checking across all file types
- **markdown-table-formatter** - Ensures consistent table formatting

### Validation Commands

Run these npm scripts to validate your changes before submitting:

```bash
npm run lint:all         # Run all linters
npm run lint:md          # Run markdownlint
npm run lint:ps          # Run PowerShell analyzer
npm run lint:yaml        # Run YAML linter
npm run lint:frontmatter # Validate markdown frontmatter
npm run validate:skills  # Validate skill directory structure
npm run lint:md-links    # Check markdown links
npm run spell-check      # Run cspell
npm run format:tables    # Format markdown tables
npm run test:ps          # Run PowerShell tests
```

For additional validation commands specific to AI artifacts (agents, prompts, instructions, skills), see [Common Standards](./docs/contributing/ai-artifacts-common.md).

### Development Environment

We strongly recommend using the provided DevContainer, which comes pre-configured with all required tools. See the [DevContainer README](./.devcontainer/README.md) for setup instructions.

## Table of Contents

- [Build and Validation Requirements](#build-and-validation-requirements)
  - [Required Tools](#required-tools)
  - [Validation Commands](#validation-commands)
  - [Development Environment](#development-environment)
- [Table of Contents](#table-of-contents)
- [Code of Conduct](#code-of-conduct)
- [I Have a Question](#i-have-a-question)
- [I Want To Contribute](#i-want-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
    - [Before Submitting a Bug Report](#before-submitting-a-bug-report)
    - [How Do I Submit a Good Bug Report?](#how-do-i-submit-a-good-bug-report)
  - [Suggesting Enhancements](#suggesting-enhancements)
    - [Before Submitting an Enhancement](#before-submitting-an-enhancement)
    - [How Do I Submit a Good Enhancement Suggestion?](#how-do-i-submit-a-good-enhancement-suggestion)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Improving The Documentation](#improving-the-documentation)
- [AI Artifact Contributions](#ai-artifact-contributions)
  - [Getting Started with AI Artifacts](#getting-started-with-ai-artifacts)
  - [Artifact Types](#artifact-types)
  - [Essential Resources](#essential-resources)
  - [Quick Reference](#quick-reference)
- [Pull Request Inactivity Policy](#pull-request-inactivity-policy)
  - [Active Pull Requests](#active-pull-requests)
  - [Draft Pull Requests](#draft-pull-requests)
  - [Exemptions](#exemptions)
- [Style Guides](#style-guides)
  - [Local Development Setup](#local-development-setup)
  - [Coding Conventions](#coding-conventions)
  - [Copyright and License Headers](#copyright-and-license-headers)
- [Testing Requirements](#testing-requirements)
  - [When Tests Are Required](#when-tests-are-required)
  - [Test Conventions](#test-conventions)
  - [Running Tests Locally](#running-tests-locally)
- [Release Process](#release-process)
  - [How Releases Work](#how-releases-work)
  - [Version Determination](#version-determination)
  - [Commit Message Examples](#commit-message-examples)
  - [Release Validation](#release-validation)
- [Attribution](#attribution)

## Code of Conduct

This project and everyone participating in it is governed by the
[Code of Conduct](./CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please see the [Code of Conduct](./CODE_OF_CONDUCT.md) instructions on how to report unacceptable behavior.

For maintainer authority, decision-making processes, and role definitions, see [GOVERNANCE.md](./GOVERNANCE.md).

## I Have a Question

> If you want to ask a question, we assume that you have read the [README](./README.md) and available documentation in [`.github/`](./.github/).

Before you ask a question, it is best to search for existing [Issues](https://github.com/microsoft/hve-core/issues) that might help you. In case you have found a suitable issue and still need clarification, you can write your question in this issue. It is also advisable to search the internet for answers first.

If you then still feel the need to ask a question and need clarification, we recommend the following:

- Open an [Issue](https://github.com/microsoft/hve-core/issues/new).
- Provide as much context as you can about what you're running into.
- Provide project and platform versions (nodejs, npm, etc), depending on what seems relevant.

We will then take care of the issue as soon as possible.

## I Want To Contribute

> ### Legal Notice
>
> When contributing to this project, you must agree that you have authored 100% of the content, that you have the necessary rights to the content and that the content you contribute may be provided under the project license.

### Reporting Bugs

#### Before Submitting a Bug Report

A good bug report shouldn't leave others needing to chase you up for more information. Therefore, we ask you to investigate carefully, collect information and describe the issue in detail in your report. Please complete the following steps in advance to help us fix any potential bug as fast as possible.

- Make sure that you are using the latest version of the project.
- Determine if your bug is really a bug and not an error on your side e.g. using incompatible environment components/versions (Make sure that you have read the [README](./README.md) and [documentation](./.github/). If you are looking for support, you might want to check [this section](#i-have-a-question)).
- To see if other users have experienced (and potentially already solved) the same issue you are having, check if there is not already a bug report existing for your bug or error in [GitHub Issues](https://github.com/microsoft/hve-core/issues).
- Also make sure to search the internet (including internal and external Stack Overflow) to see if users outside of the GitHub community have discussed the issue.
- Collect information about the bug:
  - Stack trace (Traceback)
  - OS, Platform and Version (Windows, Linux, macOS, x86, ARM)
  - Version of the interpreter, compiler, SDK, runtime environment, package manager, depending on what seems relevant.
  - Possibly your input and the output
- Can you reliably reproduce the issue? And can you also reproduce it with older versions?

#### How Do I Submit a Good Bug Report?

We use GitHub Issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](https://github.com/microsoft/hve-core/issues/new). (Since we can't be sure at this point whether it is a bug or not, we ask you not to talk about a "bug" yet and not to label the issue as a "bug.")
- Explain the behavior you would expect and the actual behavior.
- Please provide as much context as possible and describe the *reproduction steps* that someone else can follow to recreate the issue on their own. This usually includes your code. For good bug reports you should isolate the problem and create a reduced test case.
- Provide the information you collected in the previous section.

Once it's filed:

- The project team will label the issue accordingly.
- A team member will try to reproduce the issue with your provided steps. If there are no reproduction steps or no obvious way to reproduce the issue, the team will ask you for those steps and mark the issue as `needs-repro`. Bugs with the `needs-repro` tag will not be addressed until they are reproduced.
- If the team is able to reproduce the issue, it will be marked `needs-fix`, as well as possibly other tags (such as `critical`), and the issue will be left to be [implemented by someone](#your-first-code-contribution).

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for HVE Core, **including completely new features and minor improvements to existing functionality**. Following these guidelines will help maintainers and the community to understand your suggestion and find related suggestions.

#### Before Submitting an Enhancement

- Make sure that you are using the latest version.
- Read the [README](./README.md) and [documentation](./.github/) carefully and find out if the functionality is already covered, maybe by an individual configuration.
- Perform a [search](https://github.com/microsoft/hve-core/issues) to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.
- Find out whether your idea fits with the scope and aims of the project. It's up to you to make a strong case to convince the project's developers of the merits of this feature. Keep in mind that we want features that will be useful to the majority of our users and not just a small subset. If you're just targeting a minority of users, consider writing an add-on/plugin library or a sub-project.

#### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub Issues](https://github.com/microsoft/hve-core/issues).

- Use a **clear and descriptive title** for the issue to identify the suggestion.
- Provide a **step-by-step description of the suggested enhancement** in as many details as possible.
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why. At this point you can also tell which alternatives do not work for you.
- You may want to **include screenshots and animated GIFs** which help you demonstrate the steps or point out the part which the suggestion is related to. You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](http://git.gnome.org/browse/byzanz/) on Linux.
- **Explain why this enhancement would be useful** to most HVE Core users. You may also want to point out the other projects that solved it better and which could serve as inspiration.

### Your First Code Contribution

When contributing code to the project, please consider the following guidance:

- Assign an issue to yourself before beginning any effort, and update the issue status accordingly.
- If an issue for your contribution does not exist, [please file an issue](https://github.com/microsoft/hve-core/issues/new) first to engage with the project maintainers for guidance.
- Commits should reference related issues for traceability (e.g., "Fixes #123" or "Relates to #456").
- When creating a PR, use [GitHub's closing keywords](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue) in the description to automatically link and close related issues.
- All code PRs destined for the `main` branch will be reviewed by pre-determined reviewer groups that are automatically added to each PR.

This project also includes a Dev Container for development work, and using that dev container is preferred, to ensure you are using the same toolchains and tool versions as other contributors. You can read more about the Dev Container in its [ReadMe](./.devcontainer/README.md).

### Improving The Documentation

If you see issues with the documentation, please follow the [your first code contribution](#your-first-code-contribution) guidance.

For AI artifact documentation (agents, prompts, instructions, skills), see the [AI Artifact Contributions](#ai-artifact-contributions) section below and refer to the specialized guides in [docs/contributing/](./docs/contributing/README.md).

## AI Artifact Contributions

HVE Core includes specialized contribution guides for AI artifacts that enhance GitHub Copilot functionality. These artifacts define custom agents, reusable prompts, coding guidelines (instructions), and executable skills.

### Getting Started with AI Artifacts

Start with the [AI Artifacts Contributing Hub](./docs/contributing/README.md) for an overview of all artifact types and contribution standards.

### Artifact Types

| Artifact Type    | Purpose                                                                                           | Guide                                                       |
|------------------|---------------------------------------------------------------------------------------------------|-------------------------------------------------------------|
| **Agents**       | Define specialized AI assistants with domain expertise and specific workflows                     | [Custom Agents Guide](./docs/contributing/custom-agents.md) |
| **Instructions** | Establish repository-specific coding standards and conventions that Copilot follows automatically | [Instructions Guide](./docs/contributing/instructions.md)   |
| **Prompts**      | Create reusable prompt templates for common tasks and workflows                                   | [Prompts Guide](./docs/contributing/prompts.md)             |
| **Skills**       | Build self-contained packages with documentation and executable scripts for specific tasks        | [Skills Guide](./docs/contributing/skills.md)               |

### Essential Resources

Before contributing AI artifacts, review these resources:

- [Common Standards](./docs/contributing/ai-artifacts-common.md) - Shared quality gates, conventions, and rejection criteria that apply to all artifact types
- [Release Process](./docs/contributing/release-process.md) - Extension channels, maturity levels, version calculation, and publishing workflow
- [Branch Protection](./docs/contributing/branch-protection.md) - CI requirements, automated checks, and code review expectations
- [Project Roadmap](./docs/contributing/ROADMAP.md) - Current focus areas and future direction

### Quick Reference

- Agents directory: [`.github/agents/`](./.github/agents/)
- Instructions directory: [`.github/instructions/`](./.github/instructions/)
- Prompts directory: [`.github/prompts/`](./.github/prompts/)
- Skills directory: [`.github/skills/`](./.github/skills/)

## Pull Request Inactivity Policy

Pull requests that remain inactive accumulate merge conflicts and delay feedback loops. This section defines closure timelines for inactive PRs. Automation that enforces this policy is a separate effort that references these thresholds.

For issue and discussion inactivity policy, see [Inactivity Closure Policy](./GOVERNANCE.md#inactivity-closure-policy) in GOVERNANCE.md.

### Active Pull Requests

The inactivity clock runs only when the PR is waiting on the author. Reviewer-side delays do not count against the author.

| Stage  | Trigger                                                           | Label                 | Action                  |
|:-------|:------------------------------------------------------------------|:----------------------|:------------------------|
| Active | Author activity within the past 14 days while `waiting-on-author` | (none)                | Normal review cycle     |
| Paused | PR is labeled `waiting-on-reviewer`                               | `waiting-on-reviewer` | Inactivity clock paused |
| Stale  | 14 days without author activity while `waiting-on-author`         | `stale`               | Reminder comment posted |
| Closed | 7 days after `stale` label without author activity                | `closed-stale`        | PR closed with summary  |

Label usage:

- `waiting-on-author` is applied when the reviewer requests changes or the author needs to resolve conflicts. The inactivity clock starts.
- `waiting-on-reviewer` is applied when the author has addressed feedback and awaits re-review. The inactivity clock pauses.

### Draft Pull Requests

Draft PRs are fully exempt from inactivity closure. Converting a draft to "ready for review" starts the normal active PR lifecycle.

### Exemptions

The following conditions prevent automatic closure of a pull request:

- PR is in draft state
- PR is labeled `do-not-close`
- PR is labeled `waiting-on-reviewer`

Reopening rules:

- Authors can reopen a stale-closed PR at any time with updated changes
- Reopening removes the `stale` label and resets the inactivity clock

## Style Guides

This project uses automated linters to ensure code quality and consistency. These linters can be run locally using the npm scripts described in the [Build and Validation Requirements](#build-and-validation-requirements) section.

### Local Development Setup

We strongly recommend using the provided [DevContainer](./.devcontainer/README.md) for development work. The DevContainer:

- Ensures consistent tooling across all developers
- Comes pre-configured with all required linters and development tools
- Provides npm scripts for common development tasks

Refer to the [DevContainer README](./.devcontainer/README.md) for detailed information on:

- Setting up your development environment
- Available linting commands and tools
- Spell checking configuration
- Git configuration in the container

### Coding Conventions

- Follow the markdown style guide defined in `.github/instructions/hve-core/markdown.instructions.md`
- Use consistent formatting as enforced by markdownlint
- Run spell checking before committing changes
- Format tables using the markdown-table-formatter tool

### Copyright and License Headers

All source files must include copyright and license headers to meet OpenSSF Best Practices badge criteria. See [Copyright Header Guidelines](./docs/contributing/copyright-headers.md) for format requirements and placement rules by file type.

## Testing Requirements

New functionality MUST include tests. This policy ensures code quality and prevents regressions.

### When Tests Are Required

- New PowerShell scripts require corresponding `*.Tests.ps1` files
- Bug fixes should include a regression test when feasible
- Documentation-only or configuration-only changes do not require tests

CI reports coverage at an 18% informational baseline; focus on meaningful coverage for new code rather than a strict percentage.

### Test Conventions

| Item      | Convention                                            |
|-----------|-------------------------------------------------------|
| Location  | `scripts/tests/` (mirrors source directory structure) |
| Naming    | `*.Tests.ps1` suffix matching source script name      |
| Framework | Pester 5.x                                            |

Skill scripts use a different test location. Skill tests are co-located inside each skill directory at `.github/skills/<skill-name>/tests/` rather than mirrored under `scripts/tests/`. See [Skills Guide](./docs/contributing/skills.md#unit-testing-requirements) for details.

Minimal example:

```powershell
Describe 'Get-Example' {
    It 'Returns expected output' {
        Get-Example | Should -Be 'expected'
    }
}
```

### Running Tests Locally

```bash
npm run test:ps
```

All PRs run Pester tests automatically via GitHub Actions. Tests must pass before merge.

## Release Process

This project uses [release-please](https://github.com/googleapis/release-please) for automated version management and releases.

### How Releases Work

1. **Commit with Conventional Commits** - All commits to `main` must follow conventional commit format (see [commit message instructions](./.github/instructions/hve-core/commit-message.instructions.md))
2. **Release PR Creation** - After commits are pushed to `main`, release-please automatically creates or updates a "release PR"
3. **Review Release PR** - Maintainers review the release PR to verify version bump and changelog accuracy
4. **Merge to Release** - When the release PR is merged, a git tag and GitHub Release are automatically created

### Version Determination

Version bumps are determined by commit types:

| Commit Type                    | Version Bump | Example                  |
|--------------------------------|--------------|--------------------------|
| `feat:`                        | Minor        | 1.0.0 → 1.1.0            |
| `fix:`                         | Patch        | 1.0.0 → 1.0.1            |
| `docs:`, `chore:`, `refactor:` | No bump      | Appear in changelog only |
| `feat!:` or `BREAKING CHANGE:` | Major        | 1.0.0 → 2.0.0            |

### Commit Message Examples

```bash
# Feature addition (minor bump)
git commit -m "feat(instructions): add Terraform best practices"

# Bug fix (patch bump)
git commit -m "fix(workflows): correct frontmatter validation path"

# Documentation update (no version bump)
git commit -m "docs(readme): update installation steps"

# Breaking change (major bump)
git commit -m "feat!: redesign prompt file structure

BREAKING CHANGE: prompt files now require category frontmatter field"
```

For complete commit message format requirements, see [commit-message.instructions.md](./.github/instructions/hve-core/commit-message.instructions.md).

For complete release process documentation including extension publishing, maturity lifecycle, and detailed version calculation workflows, see the [Release Process Guide](./docs/contributing/release-process.md).

### Release Validation

All releases must pass:

- Spell checking
- Markdown linting
- Table format checking
- Dependency pinning checks

## Attribution

This guide is based on the **contributing.md**. [Make your own](https://contributing.md/)!

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
