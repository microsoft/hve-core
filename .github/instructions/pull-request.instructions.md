---
description: 'HVE Core pull request conventions for change-type mapping, human-only items, AI artifact sections, validation and security checkboxes, and GHCP membership changes'
applyTo: '**/.copilot-tracking/pr/**'
---

# HVE Core Pull Request Conventions

Apply these rules to pull request descriptions under `.copilot-tracking/pr/`.

## Change Types

Select every type that branch names, commit messages, or changed paths prove.

| Evidence                                                                                                | Type of Change             |
|---------------------------------------------------------------------------------------------------------|----------------------------|
| `fix`, `bugfix`, or `hotfix` prefix                                                                     | Bug fix                    |
| `feat` or `feature` prefix                                                                              | New feature                |
| `BREAKING CHANGE` footer or `!` after the type                                                          | Breaking change            |
| `docs/` or a `README.md`                                                                                | Documentation update       |
| `.github/workflows/` or `.github/actions/`                                                              | GitHub Actions workflow    |
| `.markdownlint*`, `.cspell*`, or `scripts/linting/` configuration files                                 | Linting configuration      |
| `.gitleaks.toml`, `.github/codeql/`, `scripts/security/*.json`, or `skill-security-classification.json` | Security configuration     |
| `.devcontainer/`                                                                                        | DevContainer configuration |
| Dependency manifests or lockfiles                                                                       | Dependency update          |
| `*.instructions.md`                                                                                     | Copilot instructions       |
| `*.agent.md`                                                                                            | Copilot agent              |
| `SKILL.md` or other files in a skill folder                                                             | Copilot skill              |
| `evals/`                                                                                                | Eval spec added/updated    |
| `.ps1`, `.sh`, or `.py` files                                                                           | Script/automation          |

Leave Copilot hook unchecked; this repository has no hooks.

## Human-Only Items

Leave these unchecked, without marking them as failed:

* `Other` under Type of Change
* The `hve-builder` review items under Type of Change and AI Artifact Contributions
* The common-standards verification under AI Artifact Contributions
* The sensitive-information statement under Security Considerations

## AI Artifact Sections

When an `.instructions.md`, `.agent.md`, or `SKILL.md` file changed, fill Sample Prompts with a short request, a brief execution summary, the visible output, and one observable success signal. Otherwise delete the section.

## Validation and Security

* Check a Required Local Checks item only when that exact command ran and passed. Targeted checks don't satisfy `npm run validate:local`.
* Check the documentation, naming, compatibility, and test-coverage items only when the diff proves the exact statement.
* Assess dependency security only when a manifest or lockfile changed, and least privilege only when security-sensitive scripts or permission declarations changed.

## GHCP Membership Changes

When distributable artifact membership changed, add `## GHCP Membership Changes` before `## Additional Notes`, listing only artifacts added to or removed from the root `plugin.json` after any required sync. Mention `npm run plugin:sync` and `npm run plugin:validate` under Testing when they ran.
