---
title: HVE Core Documentation Site
description: Docusaurus 3 documentation site for HVE Core
author: Microsoft
ms.date: 2026-07-16
ms.topic: reference
---

## Local Development

```bash
npm ci
npm start
```

This command starts a local development server and opens a browser window. Most changes are reflected live without restarting the server.

## Build

```bash
npm run build
```

This command generates static content into the `build` directory.

## Deployment

The site deploys automatically via GitHub Actions on push to `main`. See `.github/workflows/deploy-docs.yml`.

## Accessibility conformance harness

Accessibility is validated by three tools across four layers that run in `.github/workflows/docusaurus-tests.yml`:

1. Static lint (`eslint-plugin-jsx-a11y`): flags accessibility issues in source, end-to-end, and configuration files.
2. Component assertions (`jest-axe`): Jest checks rendered components against axe rules.
3. Behavioral end-to-end (Playwright): drives a real browser to exercise keyboard navigation, focus management, and reflow.
4. Full-site crawl (Playwright `@axe-core/playwright`): the `site-crawl` spec scans one representative URL per rendered page template against WCAG 2.x A/AA (plus `wcag22aa` and `best-practice`) at threshold 0.

Layers 3 and 4 both run on Playwright, so the four layers are covered by three tools.

### Browser E2E prerequisite

The Playwright layer drives Google Chrome via the `chrome` channel, so a Chrome (or Chromium) install must be present. Provision Playwright's managed Chrome with:

From the repository root, run the dedicated setup lane after installing both
the root and Docusaurus dependencies with `npm ci`:

```bash
npm run ci:docs:setup:e2e
```

### Local commands

Run each layer from `docs/docusaurus`:

```bash
npm run lint:a11y            # static jsx-a11y lint
npm run lint:label-registry # WCAG 3.2.4 consistent-label registry gate
npm run typecheck           # TypeScript project typecheck
npm test                    # Jest + jest-axe component assertions
npm run ci:test:e2e         # Playwright journeys + full-site axe crawl
```

From the repository root, `npm run validate:docs` runs the local-safe lint,
label-registry, typecheck, and component layers. Run `npm run ci:docs:test:e2e`
separately for the browser-backed E2E layer. See [Validation Commands and
CI-Owned Lanes](../contributing/validation) for package-root setup, browser
prerequisites, and output handling.

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
