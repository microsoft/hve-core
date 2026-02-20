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
| Automated check results | ## Checklist > ### Required Automated Checks | Map | Check `- [x]` for each validation command that passed in Step 6 |
| Assessable required checks | ## Checklist > ### Required Checks | Map | Check items the agent can confidently verify from diff analysis; leave others unchecked |
| Post-generation validation | ## Checklist | Insert | Insert `### PR Generation Validation` subsection with confirmed items checked |
| GHCP Maturity section | (new section)              | Insert | Insert before ## Additional Notes when non-stable GHCP files detected |
| Notes or Important    | ## Additional Notes        | Map    | Insert content                                    |
| Sample prompts        | ## Sample Prompts          | Preserve | Left for manual completion; do not modify       |
| Testing               | ## Testing                 | Preserve | Left for manual completion; do not modify       |
| AI Artifact checks    | ## Checklist > ### AI Artifact Contributions | Preserve | Left for manual completion; do not modify |

`Map` mode defines where content goes, not how it is formatted. Rich markdown formatting is permitted within mapped sections, including `###` sub-headings, bold, italics, blockquotes, and prose paragraphs.

* Preserve template formatting and remove only placeholder comments that were filled.
* Keep unfilled placeholders for manual completion.
* Report that the repository template was used once generation completes.

## Checkbox Reference

Single authoritative reference for all checkbox handling in PULL_REQUEST_TEMPLATE.md. All other sections that mention checkboxes defer to this table.

| Template Location                          | Checkbox Group                    | Handling     | Step   | Rule Summary                                                                 |
|--------------------------------------------|-----------------------------------|--------------|--------|------------------------------------------------------------------------------|
| ## Type of Change                          | All detection-matched types (Code & Documentation, Infrastructure & Configuration, AI Artifacts, Script/automation) | Agent (auto) | Step 5 | Check via Change Type Detection pattern match                                |
| ## Type of Change                          | Reviewed contribution with `prompt-builder` | Manual       | N/A    | Human verification; never checked by agent                                   |
| ## Type of Change                          | Other (please describe)           | Manual       | N/A    | Human verification; never checked by agent                                   |
| ## Security Considerations                 | No sensitive or NDA information   | Agent (auto) | Step 5 | Check when customer data and secrets analysis both pass                      |
| ## Security Considerations                 | Dependencies reviewed             | Agent (conditional) | Step 5 | Evaluate only when dependency changes exist; check if appropriate            |
| ## Security Considerations                 | Least privilege                   | Agent (conditional) | Step 5 | Evaluate only when security scripts are modified; check if appropriate       |
| ## Checklist > ### Required Checks         | Documentation, naming, backwards-compat, tests | Agent (assessed) | Step 5 | Diff-based assessment with confidence threshold; leave unchecked when uncertain |
| ## Checklist > ### AI Artifact Contributions | All items                        | Manual       | N/A    | Human verification; never checked by agent                                   |
| ## Checklist > ### Required Automated Checks | Each validation command         | Agent (automated) | Step 6 | Check for each command that passed in Step 6B                                |
| ## Checklist > ### PR Generation Validation | Self-audit items                 | Agent (self-audit) | Step 5 | Insert subsection; check confirmed items after post-generation review        |
| GHCP Maturity Acknowledgment               | Non-stable artifact acknowledgment | Manual      | N/A    | Inserted only when non-stable GHCP artifacts detected; left unchecked        |

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
* When changed files do not match any detection pattern, leave "Other" unchecked for manual completion.

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

After PR generation, analyze the pr-reference-log.md for security and compliance issues. Report results in chat, then update pr.md checkboxes per the Checkbox Reference table.

### Checkbox-Mapped Analysis

These items determine Security Considerations checkbox state:

* **Customer information leaks** and **secrets or credentials**: When both pass, check the "no sensitive or NDA information" checkbox.
* **Dependency changes**: When dependency changes exist, evaluate and check the "dependencies reviewed" checkbox if appropriate.
* **Security scripts modified**: When security scripts are modified, evaluate and check the "least privilege" checkbox if appropriate.

### Supplementary Analysis

These items do not map to checkboxes. Report findings in chat and note issues in pr.md's Additional Notes:

* Non-compliant language (FIXME, WIP, or to-do language in committed code)
* Unintended changes or accidental inclusion of files
* Missing referenced files
* Conventional commits compliance for title and reviewed commit messages

## Post-generation Checklist

After generating the PR, review pr.md and confirm:

* [ ] PR description preserves all template sections
* [ ] pr-reference-log.md analysis is reflected in the description
* [ ] Description uses past tense, avoids conventional commit style in body, and follows writing-style conventions
* [ ] PR description includes all significant changes and omits trivial or auto-generated ones
* [ ] Referenced files and paths are accurate
* [ ] Follow-up tasks are actionable and clearly scoped

Insert a `### PR Generation Validation` subsection under `## Checklist` in pr.md with confirmed items checked `[x]` and unconfirmed items left unchecked `[ ]`. This subsection must be finalized before PR creation in Step 7.

## Assessable Required Checks

When populating `## Checklist > ### Required Checks` in pr.md during Step 5, evaluate the non-automated required checks that the agent can assess with high confidence. Refer to the Checkbox Reference table for handling rules.

* **Documentation is updated**: Verify docs/ changes accompany code changes that affect documented behavior. Check the box when documentation changes are present or when the PR does not affect documented behavior.
* **Files follow existing naming conventions**: Verify new or renamed files match the naming patterns established in the repository. Check the box when all files follow conventions.
* **Changes are backwards compatible**: Check only when the diff clearly shows no removal or modification of public API surfaces, exported interfaces, or shared contracts. Leave unchecked when assessment requires domain judgment beyond diff analysis.
* **Tests added for new functionality**: Check only when test files are included for new feature code. Leave unchecked when tests are not applicable or when the assessment is uncertain.

Leave items unchecked when the agent cannot make a confident assessment.
