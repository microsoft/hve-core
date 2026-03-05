---
title: Customizing with Instructions
description: Configure Copilot behavior using copilot-instructions.md and instruction files with applyTo targeting and stacking patterns
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - instructions
  - copilot-instructions
  - applyTo
  - customization
estimated_reading_time: 8
---

## The Foundation: copilot-instructions.md

The single most impactful customization point is `.github/copilot-instructions.md`. Copilot loads this file for every interaction in your repository, making it the global baseline for AI behavior. Every agent, prompt, and instruction file builds on top of whatever you define here.

The file sits at the top of the artifact hierarchy. When Copilot processes a request, it merges guidance from four tiers:

1. **User settings** (VS Code profile)
2. **Prompt or agent** invoked for the current task
3. **Instruction files** matched by `applyTo` patterns
4. **`copilot-instructions.md`** (always loaded)

A minimal starter file establishes coding conventions and project context:

```markdown
# General Instructions

* Use TypeScript for all new source files.
* Follow the existing module structure under `src/`.
* Prefer named exports over default exports.
```

A more developed file adds priority rules, project structure guidance, and operational constraints:

```markdown
# General Instructions

## Priority Rules

* Conventions and styling from the codebase take precedence for all changes.
* Breaking changes are acceptable.
* Tests are created or modified only when explicitly requested.

## Project Structure

This repository contains a Node.js API with the following layout:

* `src/routes/` for HTTP route handlers
* `src/services/` for business logic
* `src/models/` for data models and schemas

## Coding Conventions

* Use `async`/`await` instead of raw promises.
* Variable names use camelCase; constants use UPPER_SNAKE_CASE.
* All public functions include JSDoc comments.
```

> [!TIP]
> Start small. A few targeted rules produce better results than a sprawling document. Add guidance incrementally as you observe Copilot behavior in your codebase.

## Instruction Files

Instruction files (`.instructions.md`) live in `.github/instructions/` and provide scoped guidance for specific file types, languages, or workflows. Unlike `copilot-instructions.md`, each instruction file declares which files it applies to through `applyTo` glob patterns.

Organization follows a collection subdirectory convention:

```text
.github/instructions/
├── coding-standards/
│   ├── python-script.instructions.md
│   └── typescript.instructions.md
├── hve-core/
│   ├── markdown.instructions.md
│   └── writing-style.instructions.md
└── shared/
    └── cross-collection.instructions.md
```

Every instruction file requires YAML frontmatter with `description` and `applyTo` fields:

```yaml
---
description: "Python coding conventions for data pipeline modules"
applyTo: '**/*.py'
---
```

The body contains the guidance Copilot follows when working with matched files: coding standards, naming conventions, framework-specific patterns, or operational constraints.

## Accelerating with Prompt Builder

The Prompt Builder agent automates instruction file creation and evaluation. Use its commands to generate well-structured instruction files that follow repository conventions.

Create a new instruction file or improve an existing one with `/prompt-build`:

```text
/prompt-build files=.github/instructions/coding-standards/typescript.instructions.md promptFiles=.github/instructions/coding-standards/python-script.instructions.md
```

Provide `files` for reference context (existing instruction files to use as style templates, `copilot-instructions.md` for project conventions) and `promptFiles` for the instruction files to create or update.

Evaluate an instruction file's quality with `/prompt-analyze`:

```text
/prompt-analyze promptFiles=.github/instructions/coding-standards/python-script.instructions.md
```

The report identifies issues with structure, clarity, and consistency. Use it to validate `applyTo` patterns, frontmatter completeness, and instruction coherence before merging.

Refactor related instruction files with `/prompt-refactor`:

```text
/prompt-refactor promptFiles=.github/instructions/coding-standards/*.instructions.md requirements="eliminate overlapping rules and consolidate shared patterns"
```

> [!TIP]
> When creating instruction files, include existing instruction files in the `files` parameter. Prompt Builder uses them as style references and avoids generating rules that conflict with existing guidance.

## Targeting with applyTo

The `applyTo` field uses glob patterns to determine when an instruction file activates. Copilot evaluates the pattern against the file you are editing or referencing in conversation.

Common patterns:

| Pattern           | Matches                                 |
|-------------------|-----------------------------------------|
| `'**/*.py'`       | All Python files in the repository      |
| `'**/*.md'`       | All Markdown files                      |
| `'**/*.test.ts'`  | TypeScript test files only              |
| `'**/src/**'`     | Everything under any `src/` directory   |
| `'**'`            | All files (global scope)                |
| `'**/*.yml'`      | All YAML files                          |
| `'**/Dockerfile'` | All Dockerfiles regardless of directory |

Combine multiple patterns with commas for broader matching:

```yaml
applyTo: '**/*.py, **/*.ipynb'
```

Narrow patterns produce more relevant guidance. Prefer `'**/*.test.ts'` over `'**/*.ts'` when the instructions apply only to tests.

## Instruction Stacking

When you edit a file that matches multiple instruction files, Copilot loads all matching files and merges their guidance. The stacking order follows specificity:

1. **`copilot-instructions.md`** loads first as the global baseline.
2. **Broad `applyTo` patterns** (like `'**'`) load next.
3. **Specific `applyTo` patterns** (like `'**/*.test.py'`) layer on top.

When instructions conflict, the more specific file takes precedence. For example, if a global instruction says "use tabs" but a Python-specific instruction says "use 4-space indentation," the Python rule wins when editing `.py` files.

Practical stacking example:

* `markdown.instructions.md` (`applyTo: '**/*.md'`) sets heading and list style rules
* `writing-style.instructions.md` (`applyTo: '**/*.md'`) adds voice and tone conventions
* Both activate when you edit any Markdown file, and their guidance combines

> [!NOTE]
> Instruction stacking is additive. Avoid placing contradictory rules in files with overlapping `applyTo` patterns. When overlap is unavoidable, the more specific pattern prevails.

## Role Scenarios

**Fabrikam's Tech Lead** ensures consistent test coverage across the team. She creates `.github/instructions/coding-standards/test-coverage.instructions.md` with `applyTo: '**/*.test.ts'` and includes rules for minimum assertion counts, mock isolation patterns, and snapshot testing conventions. Every engineer on the team gets these standards applied automatically when writing tests.

**Contoso's Security Architect** enforces input validation requirements. He adds `.github/instructions/coding-standards/input-validation.instructions.md` with `applyTo: '**/*.py'` targeting the API layer. The file specifies schema validation requirements for all request handlers, parameterized query patterns, and logging conventions for rejected input.

**Northwind Traders' Data Scientist** standardizes notebook conventions. She creates `.github/instructions/coding-standards/notebook-conventions.instructions.md` with `applyTo: '**/*.ipynb'` requiring cell documentation, reproducibility headers, and data source annotations in every notebook.

**Adventure Works' SRE** establishes infrastructure-as-code standards. He authors `.github/instructions/coding-standards/terraform.instructions.md` with `applyTo: '**/*.tf'` enforcing module structure, naming conventions, and state backend patterns for all Terraform configurations.

## Common Patterns

| Customization Goal             | Instruction File Approach                                               |
|--------------------------------|-------------------------------------------------------------------------|
| Enforce a language style guide | Create `{language}.instructions.md` with `applyTo: '**/*.{ext}'`        |
| Standardize commit messages    | Create `commit-message.instructions.md` with `applyTo: '**'`            |
| Apply framework conventions    | Create `{framework}.instructions.md` targeting framework file patterns  |
| Set documentation standards    | Create `writing-style.instructions.md` with `applyTo: '**/*.md'`        |
| Enforce test patterns          | Create `test-conventions.instructions.md` with `applyTo: '**/*.test.*'` |
| Add project-specific context   | Add a `## Project Structure` section to `copilot-instructions.md`       |
| Scope rules to a subdirectory  | Use a path-specific glob like `applyTo: '**/src/api/**'`                |

For full frontmatter schema, field definitions, and validation rules, see [Contributing: Instructions](../contributing/instructions.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
