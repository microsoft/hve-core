---
title: Authoring Custom Skills
description: Build self-contained skill packages that bundle domain knowledge, reference materials, and scripts for on-demand use
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - skills
  - SKILL.md
  - knowledge packages
  - copilot
estimated_reading_time: 7
---

## What Skills Are

Skills are self-contained knowledge packages that Copilot loads on demand. Unlike instructions (always-on guidance) or agents (interactive workflows), skills activate only when a user's request matches the skill's domain. This keeps context lean: Copilot reads the skill metadata, decides whether the domain applies, and loads the full instructions only when needed.

Use a skill when the knowledge you want to share is:

* **Domain-specific**: Relevant to a narrow topic rather than all files
* **Reference-heavy**: Includes data schemas, API specs, or compliance checklists
* **Reusable across agents**: Multiple agents or prompts can reference the same skill
* **Large**: Exceeds the practical size of an instruction file

Instructions work better for coding conventions and file-level rules that should apply passively to every edit. Skills work better for structured knowledge that Copilot should pull in selectively.

Skills are referenced using the `copilot-skill:` URI scheme. When Copilot encounters a skill reference, it reads the SKILL.md metadata first, then progressively loads deeper content as needed.

## Directory Structure

Skills live under `.github/skills/{collection-id}/{skill-name}/`:

```text
.github/skills/
└── contoso/
    └── api-review/
        ├── SKILL.md
        ├── api-standards.md
        ├── scripts/
        │   └── validate-openapi.sh
        └── references/
            └── error-codes.md
```

Each skill folder must contain a `SKILL.md` file. Supporting files are optional and organized by convention:

* `scripts/`: Automation scripts the skill may reference or invoke
* `references/`: Supplementary documentation, schemas, or data files
* `assets/`: Images, diagrams, or other binary resources

The skill name comes from the folder name. Keep folder names lowercase with hyphens: `api-review`, `compliance-check`, `data-pipeline`.

## SKILL.md Anatomy

The SKILL.md file has two parts: YAML frontmatter for metadata and a Markdown body for instructions.

### Frontmatter

```yaml
---
name: API Review
description: >-
  Reviews API designs against Contoso's REST conventions, validates
  OpenAPI specifications, and checks for breaking changes.
---
```

Required fields:

* `name`: Human-readable skill name displayed in Copilot's skill list
* `description`: A concise summary (one to three sentences) that helps Copilot decide when to activate the skill

The description drives activation decisions. Write it to match the vocabulary users employ when requesting help in the skill's domain.

### Body

The body contains the full skill instructions. Structure it with clear sections, concrete examples, and actionable rules:

```markdown
## Review Protocol

1. Validate the OpenAPI specification against the schema in
   `references/api-schema.json`.
2. Check each endpoint for consistent naming, proper HTTP method usage,
   and standard error response shapes.
3. Flag any breaking changes relative to the previous API version.

## Naming Conventions

* Resource names are plural nouns: `/users`, `/orders`, `/products`
* Use camelCase for query parameters and request body fields
* Use kebab-case for URL path segments

## Error Response Shape

All error responses follow this structure:

\`\`\`json
{
  "error": {
    "code": "ResourceNotFound",
    "message": "The requested resource does not exist.",
    "target": "/users/12345"
  }
}
\`\`\`
```

## Accelerating with Prompt Builder

The Prompt Builder agent automates skill creation and improvement. Use its commands to generate a well-structured SKILL.md and validate existing skills.

Create a new skill or improve an existing one with `/prompt-build`:

```text
/prompt-build files=.github/skills/shared/pr-reference/SKILL.md promptFiles=.github/skills/contoso/api-review/SKILL.md
```

Provide `files` for reference context (existing skills to use as structural templates, related instruction files) and `promptFiles` for the SKILL.md files to create or update. Prompt Builder follows the progressive disclosure model and organizes reference materials appropriately.

Evaluate a skill's quality with `/prompt-analyze`:

```text
/prompt-analyze promptFiles=.github/skills/contoso/api-review/SKILL.md
```

The report assesses purpose clarity, description effectiveness for activation decisions, instruction structure, and reference material organization.

Refactor related skills with `/prompt-refactor`:

```text
/prompt-refactor promptFiles=.github/skills/contoso/*/SKILL.md requirements="consolidate overlapping compliance skills into a unified package"
```

> [!TIP]
> Pay attention to the description quality feedback from `/prompt-analyze`. The skill description drives Copilot's activation decisions, so a well-crafted description determines whether the skill loads at the right time.

## Progressive Disclosure

Skills follow a three-level disclosure model that minimizes context consumption:

1. **Metadata** (~100 tokens): The `name` and `description` from frontmatter. Copilot reads this first to decide relevance.
2. **Instructions** (\<5000 tokens): The SKILL.md body. Loaded when Copilot determines the skill applies to the current request.
3. **Resources** (on demand): Supporting files in `references/`, `scripts/`, or other subdirectories. Loaded only when the instructions reference them explicitly.

This model matters for large skills. A compliance-review skill might include hundreds of pages of regulatory text in its `references/` folder, but Copilot reads only the SKILL.md body until a specific regulation is needed.

The [pr-reference skill](pathname://../../.github/skills/shared/pr-reference/SKILL.md) in this repository demonstrates this pattern: the SKILL.md defines the protocol, and supporting files provide templates and helper scripts that load only during active use.

## Including Reference Materials

Reference materials expand the skill's knowledge base without bloating the core instructions. Link to reference files from within SKILL.md using relative paths:

```markdown
For the full list of approved error codes, see
[Error Codes](references/error-codes.md).

Run the validation script to check for breaking changes:

\`\`\`bash
./scripts/validate-openapi.sh --spec openapi.yaml --baseline v2.json
\`\`\`
```

Guidelines for organizing reference materials:

* Keep each reference file focused on a single topic
* Use descriptive filenames that match section headings in SKILL.md
* Place executable scripts in `scripts/` with a shebang line and usage comments
* Store schema files, example payloads, and data samples in `references/`

When a reference file exceeds 2000 tokens, consider splitting it into smaller, topic-focused files. Copilot loads referenced files individually, so smaller files reduce unnecessary context.

## Role Scenarios

**Woodgrove Bank's Security Architect** creates a compliance-review skill at `.github/skills/woodgrove/compliance-review/`. The SKILL.md defines audit steps for OWASP Top 10 and SOC 2 controls. A `references/` folder contains control mappings, approved cryptographic algorithms, and authentication flow templates. Security agents across the organization reference this skill using `copilot-skill:/compliance-review/SKILL.md`, ensuring every review applies the same standards.

**Northwind's Data Scientist** builds a data-pipeline skill that encodes the team's ETL conventions. The SKILL.md covers naming standards for pipeline stages, schema validation rules, and lineage tracking requirements. Scripts in `scripts/` validate pipeline YAML against the expected schema. New team members get consistent guidance without reading the full internal wiki.

**Tailspin Toys' SRE** authors an incident-response skill that guides Copilot through runbook steps during outages. The SKILL.md defines triage phases, escalation criteria, and communication templates. Reference files contain service dependency maps and SLA thresholds. The skill activates when engineers ask for help with production incidents.

For full validation rules, directory requirements, and collection packaging guidance, see [Contributing: Skills](../contributing/skills.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
