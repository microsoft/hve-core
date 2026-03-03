---
description: 'Repository-specific pull request conventions for hve-core including template mapping, change detection, and maturity tracking - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/pr/**'
---

# Pull Request Conventions

Repository-specific conventions for pull request generation in hve-core. Follow #file:hve-core/pull-request.instructions.md for the pull request generation workflow.

## Template Integration

When a repository template exists, keep unfilled placeholders for manual completion.

Rich markdown formatting is permitted within all sections, including `###` sub-headings, bold, italics, blockquotes, and prose paragraphs.

Report that the repository template was used once generation completes.

### Manual-Only Sections

These sections require human verification. The agent does not modify them:

* AI artifact contribution verification checkboxes (under the checklist section)
* Prompt-builder review attestation checkbox (under type of change)
* Free-form other type checkbox (under type of change)

### Section Fill Guidance

#### Sample Prompts

When AI artifact changes are detected (`.instructions.md`, `.prompt.md`, `.agent.md`, `SKILL.md`), fill sub-sections from pr-reference-log.md analysis:

| Sub-section        | Content Source                                              |
|--------------------|-------------------------------------------------------------|
| User Request       | Describe how to trigger or invoke the modified artifact     |
| Execution Flow     | Summarize key steps, tool usage, and decision points        |
| Output Artifacts   | List files or content created with brief previews           |
| Success Indicators | Describe how users verify correct operation                 |

> [!NOTE]
> Human review is recommended for agent-populated Sample Prompts content.

Leave the section empty with placeholder comments intact when the PR does not include AI artifact changes.

#### Testing

Document all testing performed by the agent:

* List each automated validation command run in Step 6 and its pass/fail status.
* Summarize security analysis findings.
* Summarize diff-based assessments performed.
* Note that manual testing was not performed when applicable.

> [!NOTE]
> Add manual testing descriptions when applicable.

### Special Insertion Rules

* Insert a GHCP Maturity section before `## Additional Notes` when non-stable GHCP artifacts are detected.

## Checkbox Reference

Single authoritative reference for all checkbox handling in the PR template. All other sections that mention checkboxes defer to this table.

> [!NOTE]
> Review this table when the PR template changes to ensure checkbox purposes and template locations remain accurate.

| Template Location | Checkbox Purpose | Handling | Step | Rule Summary |
|---|---|---|---|---|
| Type of Change | Auto-detected change type categories | Agent (auto) | Step 5 | Check via Change Type Detection pattern match |
| Type of Change | Prompt-builder review attestation | Manual | N/A | Human verification; never checked by agent |
| Type of Change | Free-form other type | Manual | N/A | Human verification; never checked by agent |
| Security Considerations | Sensitive data attestation | Agent (auto) | Step 5 | Check when customer data and secrets analysis both pass |
| Security Considerations | Dependency security review | Agent (conditional) | Step 5 | Evaluate only when dependency changes exist |
| Security Considerations | Privilege scope attestation | Agent (conditional) | Step 5 | Evaluate only when security scripts are modified |
| Checklist > Required Checks | Documentation update verification | Agent (assessed) | Step 5 | Check when docs/ changes accompany code changes |
| Checklist > Required Checks | Naming convention compliance | Agent (assessed) | Step 5 | Check when changed files follow repository patterns |
| Checklist > Required Checks | Backwards compatibility verification | Agent (assessed) | Step 5 | Check only when diff shows no removal of public API surfaces |
| Checklist > Required Checks | Test coverage verification | Agent (assessed) | Step 5 | Check only when test files are in changes |
| Checklist > AI Artifact Contributions | AI artifact contribution verification | Manual | N/A | Human verification; never checked by agent |
| Checklist > Required Automated Checks | Validation command results | Agent (automated) | Step 6 | Check for each command that passed in Step 6B |
| GHCP Maturity (inserted) | Non-stable artifact acknowledgment | Manual | N/A | Inserted only when non-stable GHCP artifacts detected; left unchecked |

When a conditional checkbox's trigger condition is not met, annotate the checkbox inline with `(N/A — {brief reason})` to distinguish skipped-as-not-applicable from evaluated-and-failed.

## Change Type Detection Patterns

Analyze changed files from the pr-reference-log.md analysis. This table maps file patterns, branch patterns, and commit patterns to the change type checkboxes in the PR template.

> [!NOTE]
> Detection pattern values are matched against PR template checkbox labels. Synchronize this table when template checkbox text changes.

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
