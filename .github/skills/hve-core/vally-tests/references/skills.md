---
title: Skills Conformance Checks
description: Ten conformance checks the vally-tests skill emits for SKILL.md artifacts, with contract citations, stimulus shapes, and Vally grader recommendations
---
<!-- markdownlint-disable-file -->

# Skills Conformance Checks

## Overview

This reference enumerates the ten conformance checks the `vally-tests` skill knows how to express for `SKILL.md` artifacts. Skill contracts emphasize the metadata that drives semantic invocation, the structure that supports progressive disclosure, and the portability constraints that let a skill move between in-repo, extension, and plugin distribution contexts.

The canonical eval target for this kind, per `eval-suite-routing.md`, is `evals/behavior-conformance/skill-behavior.eval.yaml`. New stimulus blocks are appended to its `stimuli:` array, tagged `tags.advisory: true`, and labeled with `tags.skill: <skill-slug>` and `tags.shape: knowledge | tool-trigger | bleed-detection`. The DR-03 fallback to `evals/skill-quality/eval.yaml` applies when the primary target is absent at consumption time; a fallback append carries a leading YAML comment `# Deferred cutover per DR-03; see WI-12.` per `eval-suite-routing.md`. Authors MUST run every candidate stimulus through `refusal-taxonomy.md` before emission and refuse any match.

Grader identifiers below use the Vally CLI 0.4.0 catalog (`semantic_similarity`, `contains`, `regex`, `json_schema`) per `grader-catalog.md`. Where the research phrasing recommended `output-matches`, the equivalent here is `regex`; where it recommended `llm-grader`, the equivalent is `semantic_similarity`.

## Contract Summary

| Topic                         | Section in prompt-builder.instructions.md | Line range |
|-------------------------------|-------------------------------------------|------------|
| Frontmatter and name          | Skill frontmatter structure               | L346-L400  |
| File location and portability | Self-contained skill packaging            | L401-L550  |
| Optional subdirectories       | scripts, references, assets               | L410-L450  |
| Content sections              | Required SKILL.md body sections           | L451-L487  |
| Progressive disclosure        | Token budgets and lazy loading            | L488-L510  |
| Semantic invocation           | Description-driven matching               | L511-L540  |
| Attribution                   | Frontmatter and footer attribution        | L552-L562  |

## Conformance Checks

### Check 1: Required Frontmatter Fields

* Contract source: `prompt-builder.instructions.md` L346-L400.
* Testable behavior: SKILL.md frontmatter MUST include a `name:` field in lowercase kebab-case AND a `description:` field that is non-empty and under 120 characters.
* Suggested stimulus: ask the assistant to identify a named skill by its frontmatter `name:` and `description:` values.
* Grader recommendation: `regex` with pattern `(?m)^name:\s*['"]?[a-z0-9][a-z0-9-]*['"]?` combined with `(?m)^description:\s*['"].{1,120}`.
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` L1-L7 demonstrates the required pair.

### Check 2: Name Matches Directory

* Contract source: `prompt-builder.instructions.md` L360-L365.
* Testable behavior: the `name:` frontmatter value MUST equal the skill's directory name in lowercase kebab-case (for example a skill at `.github/skills/hve-core/vally-tests/` MUST declare `name: vally-tests`).
* Suggested stimulus: ask the assistant where on disk a named skill lives and to confirm that the directory matches the frontmatter name.
* Grader recommendation: `semantic_similarity` with rubric "Does the skill's frontmatter name field equal the final segment of its directory path in lowercase kebab-case?".
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` L1 declares `name: vscode-playwright` matching the directory.

### Check 4: H1 Title Matches Skill Purpose

* Contract source: `prompt-builder.instructions.md` L451-L487.
* Testable behavior: the SKILL.md H1 heading MUST state the skill's purpose clearly and SHOULD align in intent with the `description:` frontmatter.
* Suggested stimulus: ask the assistant to summarize a named skill in one sentence and compare against the H1 heading.
* Grader recommendation: `semantic_similarity` with rubric "Does the SKILL.md H1 heading describe the skill's purpose in a way that aligns with the description frontmatter?".
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` L10-L11 carries an H1 that matches the description's intent.

### Check 5: Required Content Sections

* Contract source: `prompt-builder.instructions.md` L451-L487.
* Testable behavior: SKILL.md MUST present the following sections in order: H1 Title, Overview, Prerequisites, Quick Start (or Architecture plus Workflow Steps), and either a Parameters Reference (when the skill exposes parameters) or a Troubleshooting section.
* Suggested stimulus: ask the assistant to list the section headings of a named skill in order.
* Grader recommendation: `regex` with pattern `(?m)^##\s+(?:Overview|Purpose)\b` AND `(?m)^##\s+(?:Prerequisites|Requirements)\b` AND `(?m)^##\s+(?:Quick\s+Start|Architecture|Workflow)\b`.
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` L10-L27 lays out the required section sequence.

### Check 6: Relative Path Portability

* Contract source: `prompt-builder.instructions.md` L401-L550.
* Testable behavior: all file path references within SKILL.md MUST be relative to the skill root. Repo-root-relative paths starting with `.github/` and absolute paths (Unix `/` or Windows drive-letter) are non-conforming.
* Suggested stimulus: ask the assistant to enumerate the file references inside a named skill's SKILL.md and confirm none are repo-root-relative.
* Grader recommendation: `regex` with negate pattern `(?m)(?:\]\(|\s|^)(?:\.github/|/[a-z]|[A-Za-z]:[\\/])` evaluated over SKILL.md path references.
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` references resources by skill-root-relative paths under its own directory.

### Check 7: Progressive Disclosure Structure

* Contract source: `prompt-builder.instructions.md` L488-L540.
* Testable behavior: SKILL.md SHOULD respect progressive disclosure: frontmatter holds metadata of roughly 100 tokens, the body holds activation instructions of under 5000 tokens, and large or domain-specific resources live in `references/`, `scripts/`, or `assets/` subdirectories rather than inline.
* Suggested stimulus: ask the assistant whether a named skill keeps its SKILL.md body within the activation budget and which subdirectories it uses for on-demand resources.
* Grader recommendation: `semantic_similarity` with rubric "Does the skill follow progressive disclosure, with a focused SKILL.md body under the activation budget and large references moved to separate files?".
* Evidence: `.github/skills/hve-core/vally-tests/SKILL.md` body delegates regex sets and routing tables to files under `references/`.

### Check 8: Script Parity for Cross-Platform Helpers

* Contract source: `prompt-builder.instructions.md` L410-L430.
* Testable behavior: when a skill ships executable helpers, the helpers SHOULD be provided in parity pairs of a bash (`.sh`) implementation and a PowerShell (`.ps1`) implementation, unless the workflow requires Python.
* Suggested stimulus: ask the assistant which helper scripts a named skill ships and whether each non-Python script has both bash and PowerShell forms.
* Grader recommendation: `semantic_similarity` with rubric "If the skill ships non-Python helpers, does each helper appear in both .sh and .ps1 forms for cross-platform parity?".
* Evidence: skills under `.github/skills/` consistently pair `.sh` and `.ps1` helpers for cross-platform helpers.

### Check 9: Troubleshooting Section

* Contract source: `prompt-builder.instructions.md` L451-L487.
* Testable behavior: SKILL.md SHOULD include a Troubleshooting section that documents common failure modes and their resolutions, or that explicitly states no common issues exist.
* Suggested stimulus: ask the assistant which common issues a named skill calls out under Troubleshooting and what the recommended fix is for each.
* Grader recommendation: `regex` with pattern `(?m)^##\s+Troubleshooting\b`.
* Evidence: the `.github/skills/experimental/vscode-playwright/` skill exposes a Troubleshooting section in line with the convention.

### Check 10: Semantic Invocation Alignment

* Contract source: `prompt-builder.instructions.md` L511-L540.
* Testable behavior: the `description:` frontmatter MUST be domain-specific enough that natural-language task descriptions matching the skill's domain (for example "extract VS Code screenshots") semantically correlate with the declared description.
* Suggested stimulus: present several phrasings of a task in the skill's domain and ask the assistant whether the named skill is the right choice for each, with justification.
* Grader recommendation: `semantic_similarity` with rubric "Is the skill's description specific and domain-focused enough that natural-language task phrasings in the domain semantically match the description?".
* Evidence: `.github/skills/experimental/vscode-playwright/SKILL.md` L2 carries a domain-specific description that pairs VS Code and Playwright.

## Cross-References

* Skill index: [SKILL.md](../SKILL.md).
* Grader catalog and selection rules: [grader-catalog.md](./grader-catalog.md).
* Refusal categories and regex source of truth: [refusal-taxonomy.md](./refusal-taxonomy.md).
* Eval target routing for `skill` kind (primary plus DR-03 fallback): [eval-suite-routing.md](./eval-suite-routing.md).
