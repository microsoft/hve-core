---
title: HVE Core Documentation Site
description: Docusaurus 3 documentation site for HVE Core
author: Microsoft
ms.date: 2026-09-12
ms.topic: reference
keywords:
  - docusaurus
  - documentation site
  - build
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

## Bundled slide presentations

The Topics menu links to `/hve-core/slides/`, which lists the HTML bundles in
`docs/slides/`. A presentation opens at `/hve-core/slides/<deck-name>.html`;
the download link saves the same self-contained file.

Each deck is listed with its generated title and description, sorted by title.
These come from `slides/<deck-name>/deck.json`, not the filename. The bundler embeds
them as inert JSON in the HTML, so a site-only build needs no separate catalog edits
or deck dependencies. Missing or invalid generated metadata fails the site build
with a rebuild instruction.

To add another deck, run from the repository root:

```bash
npm run slides:create -- --slug hve-full --title "HVE Core overview"
```

Set its `description` in `slides/hve-full/deck.json`, restore that deck's dependencies,
and run the build commands below. The new deck will appear automatically; changing
its title later does not change the filename-derived URL. Do not edit the generated
HTML or a site page to add or rename an entry.

Deck source remains under `slides/<deck-name>/`. From the repository root,
regenerate the committed bundles before building the site:

```bash
npm run slides:build
npm run slides:check
npm run docs:build
```

The source-to-bundle check refreshes only ignored intermediate assets and rejects
stale, missing, or orphaned HTML. CodeQL runs this check separately before analyzing
authored source; only generated `docs/slides/*.html` is excluded from scanning to avoid
duplicate findings in embedded third-party code. This is not an upstream dependency fix.

Site `build`, `start`, and `deploy` commands run `slides:sync` first. That copies only deck
HTML into the ignored `static/slides/` staging directory, removes stale staged
decks, and leaves the originals unchanged. The catalog reads the same source
directory. Ordinary HTML anchors use Docusaurus's configured base URL without
client-side routing, so the presentation's own JavaScript and CSS take effect.
The site build consumes committed bundles rather than rebuilding deck source.

After changing, adding, or deleting a bundle during local development, restart
`npm start` to refresh staging and the catalog. Commit bundles with their source
changes, not the generated staging files or the site's `build/` output.

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
