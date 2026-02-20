---
description: 'Repository-specific pull request conventions for hve-core including template mapping, change detection, and maturity tracking - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/pr/**'
---

# Pull Request Conventions

Repository-specific conventions for pull request generation in hve-core. Follow #file:hve-core/pull-request.instructions.md for the pull request generation workflow.

## Template Integration

Map PR content to the repository template at `.github/PULL_REQUEST_TEMPLATE.md`. The template defines these H2 sections:

| pr.md Component       | Template Section           | Mode   | Guidance                                          |
|-----------------------|----------------------------|--------|---------------------------------------------------|
| H1 Title              | Document title             | Map    | Replace the existing title with the generated one |
| Summary paragraph     | ## Description             | Map    | Add after the placeholder comment if present      |
| Change bullets        | ## Description             | Map    | Append after the summary                          |
| Detected issue refs   | ## Related Issue(s)        | Map    | Replace placeholder comment if present            |
| Detected change types | ## Type of Change          | Map    | Check matching `- [ ]` boxes                      |
| Security analysis     | ## Security Considerations | Map    | Check boxes and add notes when issues exist       |
| GHCP Maturity section | (new section)              | Insert | Insert before ## Additional Notes when non-stable GHCP files detected |
| Notes or Important    | ## Additional Notes        | Map    | Insert content                                    |

* For each detected change type, replace the matching `- [ ]` checkbox with `- [x]`.
* Extract related issues using patterns from the shared instructions and place them in the Related Issue(s) section.
* Check the security section checkbox that confirms no secrets or sensitive data when applicable.
* Leave dependency review checkboxes unchecked.
* Preserve template formatting and remove only placeholder comments that were filled.
* Keep unfilled placeholders for manual completion.
* Report that the repository template was used once generation completes.

## Change Type Detection Patterns

Analyze changed files from the pr-reference-log.md analysis. This table maps file patterns, branch patterns, and commit patterns to the change type checkboxes in the PR template.

| Change Type                | File Pattern             | Branch Pattern            | Commit Pattern            |
|----------------------------|--------------------------|---------------------------|---------------------------|
| Bug fix                    | N/A                      | `^(fix\|bugfix\|hotfix)/` | `^fix(\(.+\))?:`          |
| New feature                | N/A                      | `^(feat\|feature)/`       | `^feat(\(.+\))?:`         |
| Breaking change            | N/A                      | N/A                       | `BREAKING CHANGE:\|^.+!:` |
| Documentation update       | `^docs/.*\.md$`          | `^docs/`                  | `^docs(\(.+\))?:`         |
| GitHub Actions workflow    | `^\.github/workflows/.*` | N/A                       | `^ci(\(.+\))?:`           |
| Linting configuration      | `\.markdownlint.*`       | N/A                       | `^lint(\(.+\))?:`         |
| Security configuration     | `^scripts/security/.*`   | N/A                       | N/A                       |
| DevContainer configuration | `^\.devcontainer/.*`     | N/A                       | N/A                       |
| Dependency update          | `package.*\.json`        | `^deps/`                  | `^deps(\(.+\))?:`         |
| Copilot instructions       | `.*\.instructions\.md$`  | N/A                       | N/A                       |
| Copilot prompt             | `.*\.prompt\.md$`        | N/A                       | N/A                       |
| Copilot agent              | `.*\.agent\.md$`         | N/A                       | N/A                       |
| Copilot skill              | `.*/SKILL\.md$`          | N/A                       | N/A                       |
| Script or automation       | `.*\.(ps1\|sh\|py)$`    | N/A                       | N/A                       |

Priority rules:

* AI artifact patterns (`.instructions.md`, `.prompt.md`, `.agent.md`, `SKILL.md`) take precedence over documentation updates.
* Any breaking change in commits marks the PR as breaking.
* Multiple change types can be selected.

## GHCP Maturity Detection

Skip this section when no GHCP artifact files (`.instructions.md`, `.prompt.md`, `.agent.md`, `SKILL.md`) are included in the changes.

After detecting GHCP files from change type detection, look up maturity levels from collection manifest item metadata:

1. For each file matching `.instructions.md`, `.prompt.md`, `.agent.md`, or `SKILL.md` patterns, find matching entries in `collections/*.collection.yml`.
2. Read each item's optional `maturity` field; use `stable` when omitted.
3. When the same file appears in multiple collections, use the highest-risk effective value in this order: `deprecated`, `experimental`, `preview`, `stable`.

Categorize files by maturity:

| Maturity Level | Risk Level  | Indicator                 | Action                          |
|----------------|-------------|---------------------------|---------------------------------|
| stable         | ✅ Low       | Production-ready          | Include in standard change list |
| preview        | 🔶 Medium   | Pre-release feature       | Flag in dedicated section       |
| experimental   | ⚠️ High     | May have breaking changes | Add warning banner              |
| deprecated     | 🚫 Critical | Scheduled for removal     | Add deprecation notice          |

## GHCP Maturity Output

If non-stable GHCP files are detected, add this section before Notes.

For experimental files:

```markdown
> [!WARNING]
> This PR includes **experimental** GHCP artifacts that may have breaking changes.
> - `path/to/file.prompt.md`
```

For deprecated files:

```markdown
> [!CAUTION]
> This PR includes **deprecated** GHCP artifacts scheduled for removal.
> - `path/to/legacy.agent.md`
```

Always include the maturity summary table when any GHCP files are detected:

```markdown
## GHCP Artifact Maturity

| File                     | Type         | Maturity        | Notes            |
|--------------------------|--------------|-----------------|------------------|
| `new-feature.prompt.md`  | Prompt       | ⚠️ experimental | Pre-release only |
| `helper.agent.md`        | Agent        | 🔶 preview      | Pre-release only |
| `video-to-gif/SKILL.md`  | Skill        | ✅ stable        | All builds       |
| `coding.instructions.md` | Instructions | ✅ stable        | All builds       |
```

If any non-stable files detected, add:

```markdown
### GHCP Maturity Acknowledgment
- [ ] I acknowledge this PR includes non-stable GHCP artifacts
- [ ] Non-stable artifacts are intentional for this change
```

## Security Analysis

After PR generation, analyze the pr-reference-log.md for security and compliance issues. Report results in the chat:

1. ✅/❌ Customer information leaks
2. ✅/❌ Secrets or credentials
3. ✅/❌ Non-compliant language (FIXME, WIP, or to-do language in committed code)
4. ✅/❌ Unintended changes or accidental inclusion of files
5. ✅/❌ Missing referenced files
6. ✅/❌ Conventional commits compliance for title and reviewed commit messages

## Post-generation Checklist

After generating the PR, review pr.md and confirm:

* [ ] Core guidance was followed
* [ ] Required steps were followed
* [ ] PR writing standards were followed
* [ ] PR description includes all significant changes and omits trivial or auto-generated ones
* [ ] Referenced files and paths are accurate
* [ ] Follow-up tasks are actionable and clearly scoped
