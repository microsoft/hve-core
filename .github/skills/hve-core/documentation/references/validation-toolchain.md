---
title: Validation toolchain
description: Validation commands and guidance for documentation audit and validation modes.
---

# Validation toolchain

Use this reference when the validate mode or audit mode needs to run or summarize
validation work.

## Primary commands

- `npm run lint:md` — Markdown linting for repository content.
- `npm run lint:md-links` — Link validation for markdown files.
- `npm run lint:frontmatter` — Frontmatter validation.
- `npm run spell-check` — Spelling checks for docs and related content.
- `npm run format:tables` — Table formatting cleanup.
- `npm run docs:build` — Docusaurus site build.
- `npm run docs:test` — Docusaurus test suite.
- `npm run docs:test:e2e` — Playwright accessibility journeys and full-site axe crawl for the docs site.
- `npm run docs:lint` — Docs lint workflow.
- `npm run docs:typecheck` — Type checking for the docs site.
- `npm run lint:docs-site` — Aggregated docs-site validation.

## How to interpret results

- Treat link and frontmatter issues as correctness issues, not style-only issues.
- Use the logs under `logs/` if the command writes structured output.
- Apply minor, isolated fixes directly when they are in scope.
- Escalate broader failures rather than forcing a speculative rewrite.
