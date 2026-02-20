---
description: 'Comprehensive coding guidelines and instructions for hve-core'
---

# General Instructions

Items in the Highest Priority Rules section from attached instructions files override any conflicting guidance.

<!-- <highest-priority-rules> -->
## Priority Rules

* Conventions and styling from the codebase take precedence for all changes.
* Instructions files not already attached are read before deciding on edits.
* Breaking changes are acceptable.
* Backward-compatibility layers or legacy support are added only when explicitly requested.
* Tests, scripts, and one-off markdown docs are created or modified only when explicitly requested.

Rules for comments:

* Remain brief and factual, describing behavior, intent, invariants, and edge cases.
* Thought processes, step-by-step reasoning, and narrative comments do not appear in code.
* Comments that contradict current behavior are removed or updated.
* Temporal markers (phase references, dates, task IDs) are removed from code files during any edit.

Rules for fixing errors:

* Proactively fix any problem encountered while working in the codebase, even when unrelated to the original request.
* Root-cause fixes are preferred over symptom-only patches.
* Further investigation of the codebase or through tools is always allowed.
<!-- </highest-priority-rules> -->

<!-- <project-structure> -->
## Project Structure

This repository contains documentation, scripts, and tooling for the HVE (Hyper Velocity Engineering) Core project.

### Directory Organization

The project is organized into these main areas:

* Documentation (`docs/`) - Getting started guides, templates, RPI workflow documentation, and contribution guidelines.
* Scripts (`scripts/`) - Automation for linting, security validation, extension packaging, and development tools.
* Skills (`.github/skills/{collection-id}/`) - Self-contained skill packages, by convention organized by collection.
* Extension (`extension/`) - VS Code extension source and packaging.
* GitHub Configuration (`.github/`) - Workflows, instructions, prompts, agents, and issue templates, typically organized into `{collection-id}` subdirectories.
* Collections (`collections/`) - YAML and markdown manifests defining bundled sets of agents, prompts, instructions, and skills.
* Logs (`logs/`) - Output from validation and analysis scripts.

### Scripts Organization

Scripts are organized by function:

* Extension (`scripts/extension/`) - Extension packaging and preparation.
* Linting (`scripts/linting/`) - Markdown validation, link checking, frontmatter validation, and PowerShell analysis.
* Security (`scripts/security/`) - Dependency pinning validation and SHA staleness checks.
* Library (`scripts/lib/`) - Shared utilities such as verified downloads.

### Skills Organization

By convention, skills are self-contained packages organized under `.github/skills/{collection-id}/{skill-name}/`. Each skill folder contains a `SKILL.md` file with domain-specific instructions, and may include other markdown files that are referenced by `SKILL.md` along with `scripts/`, `references/`, `assets/`, or other subdirectories.

### Documentation Structure

* HVE Guide (`docs/hve-guide/`) - Project lifecycle stages and role-specific guides.
  * Lifecycle (`docs/hve-guide/lifecycle/`) - AI-assisted project lifecycle stage documentation.
  * Roles (`docs/hve-guide/roles/`) - Role-specific guides for engineers, leads, architects, and other contributors.
* Getting Started (`docs/getting-started/`) - Installation and first workflow guides with multiple setup methods.
* RPI (`docs/rpi/`) - Task researcher, planner, and implementor workflow documentation.
* Contributing (`docs/contributing/`) - Guidelines for instructions, prompts, agents, and AI artifacts.
* Templates (`docs/templates/`) - Templates for custom agents, instructions, and prompts.

### Copilot Tracking

The `.copilot-tracking/` directory (gitignored) contains AI-assisted workflow artifacts:

* Work Items (`.copilot-tracking/workitems/`) - ADO work item discovery and planning.
* Pull Requests (`.copilot-tracking/pr/`) - PR reference generation, handoff, and review tracking.
* Changes (`.copilot-tracking/changes/`) - Change tracking and implementation logs.
* Plans (`.copilot-tracking/plans/`) - Task implementation plans and planning logs.
* Details (`.copilot-tracking/details/`) - Task plan implementation details.
* Research (`.copilot-tracking/research/`) - Technical research findings and subagent research outputs.
* Reviews (`.copilot-tracking/reviews/`) - Review logs and validation findings.
* ADRs (`.copilot-tracking/adrs/`) - Architecture Decision Record drafts.
* BRD Sessions (`.copilot-tracking/brd-sessions/`) - Business requirements document session state.
* PRD Sessions (`.copilot-tracking/prd-sessions/`) - Product requirements document session state.
* GitHub Issues (`.copilot-tracking/github-issues/`) - GitHub issue search, triage, and workflow tracking.
* Sandbox (`.copilot-tracking/sandbox/`) - Prompt testing sandbox environments.
* Prompts (`.copilot-tracking/prompts/`) - Prompt updater tracking files.
* Doc Ops (`.copilot-tracking/doc-ops/`) - Documentation operations session tracking.
* Memory (`.copilot-tracking/memory/`) - Cross-session memory files.

All tracking files use markdown format with frontmatter and follow patterns from `.github/instructions/ado/ado-*.instructions.md`.

### Agents and Subagents

By convention, custom agents are organized under `.github/agents/{collection-id}/`. Each collection typically places its agents in a dedicated subdirectory (e.g., `.github/agents/hve-core/`, `.github/agents/ado/`). Subagents are typically organized under `.github/agents/{collection-id}/subagents/`.
Parent agents reference subagents using glob paths like `.github/agents/**/researcher-subagent.agent.md` so resolution works regardless of nesting depth.

Collection manifests in `collections/` define bundles of agents, prompts, instructions, and skills:

* Each collection has a YAML file (`*.collection.yml`) listing items with `path` and `kind` fields, and a markdown file (`*.collection.md`) describing the collection.
* Collections must include all subagent dependencies used by their referenced custom agents. When a parent agent declares subagents in its `agents:` frontmatter, those subagent files must appear in the collection YAML.
* When adding, updating, or removing prompt instructions, custom agents, subagents, or skills, update all affected `collections/*.collection.yml` and `collections/*.collection.md` files.
* After any change to collection YAML or markdown files, run `npm run plugin:generate` to regenerate plugin outputs under `plugins/`. Do not edit `plugins/` files directly.
* Run `npm run plugin:validate` to confirm collection metadata is correct.
<!-- </project-structure> -->

<!-- <script-operations> -->
## Script Operations

* Scripts follow instructions provided by the codebase for convention and standards.
* Scripts used by the codebase have an `npm run` script for ease of use.
* Files under the root `plugins/` directory are generated outputs and are not edited directly.
* Regenerate plugin outputs using `npm run plugin:generate`; this also runs `lint:md:fix` and `format:tables` as post-processing. Markdown files under `plugins/` can be symlinked or generated, so direct edits can cause conflicts and non-durable changes.
* Artifacts at the root of `.github/agents/`, `.github/instructions/`, `.github/prompts/`, or `.github/skills/` (without a subdirectory) are repo-specific and excluded from collection manifests, plugin generation, and extension packaging. Validation enforces this rule.

PowerShell scripts follow PSScriptAnalyzer rules from `scripts/linting/PSScriptAnalyzer.psd1` and include proper comment-based help. Validation runs via `npm run lint:ps` with results output to `logs/`.
<!-- </script-operations> -->

<!-- <coding-agent-environment> -->
## Coding Agent Environment

Copilot Coding Agent uses a cloud-based GitHub Actions environment, separate from the local devcontainer. The `.github/workflows/copilot-setup-steps.yml` workflow pre-installs tools to match devcontainer capabilities.

### Pre-installed Tools

* Node.js 20 with npm dependencies from `package.json`
* Python 3.11
* PowerShell 7 with PSScriptAnalyzer, PowerShell-Yaml, and Pester 5.7.1 modules
* shellcheck for bash script validation (pre-installed on ubuntu-latest)
* actionlint for GitHub Actions workflow validation

### Using npm Scripts

Agents should use npm scripts for all validation:

* `npm run lint:md` - Markdown linting
* `npm run lint:ps` - PowerShell analysis
* `npm run lint:yaml` - YAML validation
* `npm run lint:frontmatter` - Frontmatter validation
* `npm run lint:links` - Link language checking
* `npm run lint:md-links` - Markdown link checking
* `npm run lint:collections-metadata` - Collection metadata validation
* `npm run lint:version-consistency` - Action version consistency
* `npm run lint:all` - Run all linters (chains `format:tables`, `lint:md`, `lint:ps`, `lint:yaml`, `lint:links`, `lint:frontmatter`, `lint:collections-metadata`, `lint:version-consistency`, and `validate:skills`)
* `npm run validate:copyright` - Copyright header validation
* `npm run validate:skills` - Skill structure validation
* `npm run format:tables` - Markdown table formatting
* `npm run test:ps` - PowerShell tests

### PowerShell Testing

PowerShell tests run exclusively through `npm run test:ps`. Never invoke Pester or test scripts directly.

Run specific tests by passing a `-TestPath` argument:

```bash
npm run test:ps -- -TestPath "scripts/tests/linting/"
npm run test:ps -- -TestPath "scripts/tests/security/Validate-DependencyPinning.Tests.ps1"
```

Test results are always written to the `logs/` directory:

* `logs/pester-summary.json` - Overall pass/fail counts, duration, and result status.
* `logs/pester-failures.json` - Failure details including test name, file path, error message, and stack trace.

#### Inline execution protocol

Pipe output through `tail` to capture the summary:

```bash
npm run test:ps 2>&1 | tail -20
npm run test:ps -- -TestPath "scripts/tests/linting/" 2>&1 | tail -20
```

After the command completes, read `logs/pester-summary.json` to confirm overall status. If failures exist, read `logs/pester-failures.json` to identify which tests failed and why. If `logs/pester-summary.json` does not exist, review the terminal output for startup errors. Use tools that include ignored files when searching the `logs/` directory since it is gitignored.

### Environment Synchronization

The `copilot-setup-steps.yml` and `.devcontainer/scripts/on-create.sh` share most tools but differ intentionally: gitleaks is devcontainer-only (not needed during agent-driven development). When adding or removing tools in either environment, evaluate whether both need the change and update accordingly.
<!-- </coding-agent-environment> -->

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
