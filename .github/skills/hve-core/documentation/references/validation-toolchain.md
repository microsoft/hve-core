---
title: Validation toolchain
description: Validation commands and guidance for documentation audit and validation modes.
---

# Validation toolchain

Use this reference when the validate mode or audit mode needs to run or summarize
validation work.

## Command ownership

| Command                     | Owner | Behavior                                                        |
|-----------------------------|-------|-----------------------------------------------------------------|
| `npm run validate:docs`     | local | Docs lint, label validation, type checking, and component tests |
| `npm run lint:md`           | local | Markdown linting for repository content                         |
| `npm run lint:md-links`     | local | Markdown link validation                                        |
| `npm run lint:frontmatter`  | local | Frontmatter validation                                          |
| `npm run spell-check`       | local | Spelling checks for docs and related content                    |
| `npm run lint:tables`       | local | Non-mutating Markdown table check                               |
| `npm run format:tables`     | fixer | Mutating Markdown table cleanup                                 |
| `npm run docs:build`        | local | Docusaurus site build                                           |
| `npm run docs:test`         | local | Docusaurus component tests                                      |
| `npm run docs:lint`         | local | Documentation accessibility lint                                |
| `npm run docs:typecheck`    | local | Documentation TypeScript checks                                 |
| `npm run ci:docs:test:e2e`  | CI    | Playwright accessibility journeys and full-site axe crawl       |
| `npm run ci:docs:setup:e2e` | CI    | Playwright-managed Chrome setup for named local reproduction    |

Audit and validate modes use local commands by default. A task that specifically asks to reproduce documentation E2E may invoke `ci:docs:test:e2e`; that request does not imply browser setup.

## How to interpret results

* Treat link and frontmatter issues as correctness issues, not style-only issues.
* Use the logs under `logs/` if the command writes structured output.
* Apply minor, isolated fixes directly when they are in scope.
* Record checks as `Passed`, `Failed`, `Pending CI`, `Skipped`, `Deferred`, or `Unavailable`. A CI-owned check that did not run is never `Passed`.
* Escalate broader failures rather than forcing a speculative rewrite or provisioning a specialized prerequisite automatically.
