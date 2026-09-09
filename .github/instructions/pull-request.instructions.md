---
description: 'HVE Core repository conventions for preparing, creating, or updating pull requests, including template mapping, AI artifact checkboxes, validation reporting, and GHCP membership changes.'
applyTo: '**/.copilot-tracking/pr/**'
---

# HVE Core Pull Request Conventions

Apply these repository-specific rules when the pull request skill prepares or updates a pull request
for HVE Core.

## Human-Only Checkboxes

Leave these items unchecked:

* HVE Builder review attestations
* AI artifact contribution verification
* Free-form `Other` change type
* Manual testing and qualified-human review
* Hosted CI checks without a successful hosted result

Do not annotate an unchecked human-only item as failed.

## AI Artifact Sections

For changed `.instructions.md`, `.prompt.md`, `.agent.md`, or `SKILL.md` files, populate Sample
Prompts with a compact, natural request, a short execution summary, the user-visible output, and one
observable success signal. Keep preview content brief. Remove the section when it is not applicable
and the template permits deletion.

Select each AI artifact change type proven by changed paths. A `SKILL.md` change is a skill even
though it is Markdown. Leave `Other` for a human.

## Testing And Checks

List only commands that ran, with their results. Do not list inferred or planned checks as passed.
Leave the local validation aggregate unchecked when only targeted checks ran. Check documentation,
naming, compatibility, and test-coverage items only when direct diff evidence proves the exact
statement.

For security considerations:

* Leave the sensitive-information attestation for a human.
* Assess dependency security only when dependency manifests or lockfiles changed.
* Assess least privilege only when security-sensitive scripts or permission declarations changed.

## Distribution Changes

When distributable Copilot artifact membership changed, add `## GHCP Membership Changes` before
`## Additional Notes`. Determine membership from root `plugin.json` after required synchronization,
and list only added or removed artifacts. Mention `npm run plugin:sync` and
`npm run plugin:validate` in Validation when those commands ran.

## Change Types

Infer types from branch and commit prefixes plus changed paths. Common mappings include:

* `fix`, `bugfix`, or `hotfix` to Bug fix
* `feat` or `feature` to New feature
* `BREAKING CHANGE` or a conventional-commit `!` to Breaking change
* `docs/` to Documentation update
* `.github/workflows/` to GitHub Actions workflow
* dependency manifests and lockfiles to Dependency update
* `.instructions.md`, `.prompt.md`, `.agent.md`, and `SKILL.md` to their matching AI artifact types
* `.ps1`, `.sh`, and `.py` to Script or automation

Select all supported types. Do not infer a generic type only to avoid leaving every item unchecked.
