---
title: HVE Core Documentation Site
description: Docusaurus 3 documentation site for HVE Core
author: Microsoft
ms.date: 2026-02-19
ms.topic: reference
---

## Local Development

```bash
npm install
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

Accessibility is validated by four layers that run in `.github/workflows/docusaurus-tests.yml`:

1. **Static lint** — `eslint-plugin-jsx-a11y` flags accessibility issues in source, end-to-end, and configuration files.
2. **Component assertions** — Jest and `jest-axe` check rendered components against axe rules.
3. **Behavioral journeys** — Playwright exercises keyboard navigation, focus management, reflow, and other interactions in a real browser.
4. **Full-site crawl** — `pa11y-ci` scans built pages against WCAG 2.1 AA.

### Prerequisite

Layers 3 and 4 drive Google Chrome. Playwright uses the `chrome` channel and `pa11y-ci` reaches Chrome over the DevTools Protocol, so a Chrome (or Chromium) install must be present. Provision Playwright's managed Chrome with:

```bash
npm run docusaurus -- --help >/dev/null # ensure dependencies are installed
npx playwright install --with-deps chrome
```

### Local commands

Run each layer from `docs/docusaurus`:

```bash
npm run lint:a11y    # static jsx-a11y lint
npm run typecheck    # TypeScript project typecheck
npm test             # Jest + jest-axe component assertions
npm run test:e2e     # Playwright behavioral journeys
npm run a11y         # build, serve, and crawl with pa11y-ci
```

From the repository root, `npm run lint:docs-site` runs the lint, typecheck, component, end-to-end, and crawl layers in sequence, and `npm run docs:test:e2e:setup` installs the Chrome dependency for Playwright.

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
