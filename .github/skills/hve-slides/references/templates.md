---
description: 'Create new decks safely and adapt reusable fragments without replacing existing presentations.'
---

# Starter and Fragment Guide

## Create a New Deck

The [deck starter](../templates/deck/README.md) is a runnable, neutral reveal.js presentation
with four example slides and a four-step scripted walkthrough. It includes local
navigation, source/notes dialogs, keyboard and focus handling, reduced motion, build/bundle
scripts, a pinned lockfile and Node tests.

From the repository root:

```bash
npm run slides:create -- --slug contributor-tour --title "Contributor tour"
```

The [scaffold script](../scripts/create-deck.mjs) copies a fixed list of template files into
`slides/contributor-tour/`. It sets the package/lockfile name and the title in `deck.json`.
It rejects invalid slugs, existing files/directories and symbolic-link destinations.
It also rejects a symbolic-link `slides/` parent. It never overwrites an existing deck,
executes package commands, installs a browser, starts a server or publishes anything.
The npm alias calls `node .github/skills/hve-slides/scripts/create-deck.mjs`; direct
Node invocation supports the same flags and does not depend on the caller's directory.

If a filesystem error interrupts copying after the new directory is created, the script
reports the partial destination and leaves it for inspection rather than deleting files
that someone else might have added. Correct the cause and inspect that directory before
deciding how to continue; rerunning does not overwrite it.

After creation, restore dependencies when permitted and needed, then build:

```bash
npm ci --prefix slides/contributor-tour
npm run bundle --prefix slides/contributor-tour
npm test --prefix slides/contributor-tour
```

Open `slides/contributor-tour/dist/contributor-tour.html`. The filename follows the
directory name. Generated source includes its own build/bundle modules and needs no
runtime imports from the skill or the HVE Updates deck.

Scaffolding is not completion of the presentation. Replace the title/description/source
note in `deck.json`, the story and notes in `index.html`, and the examples/citations in
`content.js`. Add researched claims and appropriate sources before presenting. The starter
does not inherit HVE history, a snack theme, plugin instructions or an RPI Agent requirement.

## Adapt an Existing Deck

Do not run `create-deck.mjs` over an existing deck or copy the entire starter onto it.
Read the incumbent architecture and adapt only the required fragment, data and styles.

| Fragment | Use |
|----------|-----|
| [split-evidence.html](../templates/fragments/split-evidence.html) | Explanation beside a code or evidence surface |
| [workflow.html](../templates/fragments/workflow.html) | Four connected ordered steps |
| [copilot-request.html](../templates/fragments/copilot-request.html) | Passive reconstructed request composer |
| [question-answer.html](../templates/fragments/question-answer.html) | Scripted question and recorded answer side by side |
| [implementation-diff.html](../templates/fragments/implementation-diff.html) | Checked tasks, changes excerpt and derived diff counts |
| [walkthrough.html](../templates/fragments/walkthrough.html) | Presenter-stepped example with phase/state beside its content |

These are source fragments to copy and adapt, not independent HTML pages or runtime
includes. Insert a selected section inside `.slides`. Give it a unique ID, title and
chapter, replace its citation keys, and author notes for its actual content.

The fragments use the starter's `data-example` and `data-demo` conventions:

* Static keys resolve in `DeckContent.examples`, rendered by `DeckComponents.renderExample`.
* Demo keys resolve in `DeckContent.demos`; each host needs a unique key, and every step's
  phase must be in its demo's phase list.
* `walkthrough.html` reuses the default `example` key. Replace the existing host, or add a
  new data entry/key before inserting it as another walkthrough.
* Component data, not the fragment, owns requests, options, answers, tasks and diff rows.
* The starter styles live in `theme.css` and `components.css`. Copy the required rules
  only when the destination has no suitable owner.

HVE Updates uses different globals and initialization. Adapt a fragment to that existing
data/renderer contract; pasting a starter mount alone will not initialize it there.
Preserve its RPI guidance, current examples and unrelated edits.

## Template Maintenance and Checks

The canonical bundler lives in `templates/deck/bundle.mjs`. New decks copy it. HVE Updates
has a thin wrapper passing its own build function, so there is no second maintained parser.
Keep imported modules free of build side effects. Do not introduce cross-deck browser
imports, automatic template upgrades or an overwrite option to the scaffold script.

The skill's `scripts/` and `tests/` are maintenance tooling, not copied into a new deck.
Run the bounded checks after changing the starter or scaffold script:

```bash
npm run test:slides
npm test --prefix .github/skills/hve-slides/templates/deck
npm test --prefix slides/hve-updates
```

The template package requires its own current dependency installation for its bundle test.
Use the existing deck test when changing the shared bundler. Add safety regressions to the
scaffold-script tests and keep runtime/content tests in the copied `deck.test.cjs`.
Refresh actual browser evidence for changed runtime behavior, as described in
[validation.md](validation.md). A scaffold test does not prove the resulting presentation
looks good or handles focus correctly.

## Source References

* [Node.js filesystem API](https://nodejs.org/api/fs.html): directory creation, file copying
  and symbolic-link inspection.
* [reveal.js installation](https://revealjs.com/installation/): local presentation assets.
