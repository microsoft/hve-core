---
title: RAI Planner with HVE Core deck
description: An interactive presentation on using the HVE Core RAI Planner and extending it for an organization with HVE Builder.
ms.date: 2026-10-01
---

## Build and present

Open the [single-file presentation](../../docs/slides/rai-planner.html) in a desktop browser.
If you're viewing it on GitHub, download the HTML file first. That version is ready to open
without a build.

To rebuild after editing, use Node.js 24 or later. Run these commands from the repository root:

```bash
cd slides/rai-planner
npm ci
npm run bundle
npm test
```

Then open `docs/slides/rai-planner.html`, rather than the source `index.html`.
The deck runs locally without a server, agent, editor extension or sign-in.
Installing dependencies needs a connection. Once bundled, the HTML file can be copied
and presented offline; opening an external source link still needs a connection.

`npm run build` creates the intermediate folder at `slides/rai-planner/dist/`.
To present `dist/index.html` instead, keep that folder's files and `vendor/` directory together.

Use a landscape desktop display, ideally 1600 by 900 or larger, or browser full screen.
The presentation also fits 1280 by 720. Reading view provides unscaled, scrollable
content on compact or zoomed viewports and can be toggled at any size. On short
viewports, such as 400% zoom, the reading-view controls follow the slide content, and
the skip link moves focus to them.

## Story and audience

The 17-slide talk is for engineers, technical leads and Responsible AI champions who use
or customize HVE Core. It takes about 25 to 30 minutes:

* The overview slides explain what the planner provides and how its prompts, agents,
  skills and instructions load, including how the RAI Reviewer differs.
* The "How it works" slides cover the six phases and their gates, the three entry modes,
  the depth-tier rule, the files an assessment writes and the planner's guardrails.
* An eight-step walkthrough follows a fictional customer support chatbot from the startup
  disclaimer to a backlog handoff and a declined request for compliance sign-off.
* The "Extend it" slides cover the reference content the planner already accepts,
  choosing an artifact by how it loads and the HVE Builder lifecycle.
* A seven-step walkthrough extends the planner for the fictional Woodgrove Bank with a
  skill and an instruction, including a review finding that keeps NIST AI RMF active.

The talk explains the tooling. It doesn't teach Responsible AI practice or replace review
by qualified legal, compliance and Responsible AI reviewers.

## Content and fidelity

Product details reflect the October 1, 2026 snapshot: HVE Core commit
`7e2de1aa135133acc4e9592adffc220cad9bdfdf` and the VS Code customization documentation
cited in each slide's Sources dialog. The RAI Planner agent, its identity instructions and
its skills define current behavior. Some published RAI Planning pages predate the July 2026
consolidation into a single `rai-plan.md` ([PR 2568](https://github.com/microsoft/hve-core/pull/2568))
and still list one file per phase.

VS Code documents prompt files as deprecated for Agent Host sessions; they still work with
the Local agent. The deck therefore shows RAI Planner selected in the Agent dropdown, lists
the `/rai-*` prompt files as an option and uses a skill, not a new prompt file, as the
extension's entry point.

Both walkthroughs are scripted. Several turns in the chatbot walkthrough are adapted from
scenarios in the RAI Planner conformance eval suite; the deck cites those scenarios, not
their run results. The CAUTION disclaimer and framework attribution are excerpts of HVE Core
source. Woodgrove Bank, its policy, its file contents, the review result and the resulting
state are fictional. The indicator buttons on the Phase 2 slide compute the documented
depth-tier rule in the page; they don't run the planner.

## Presenter controls

| Control                           | Behavior                                                 |
|-----------------------------------|----------------------------------------------------------|
| Left / Right, Page Up / Page Down | Previous / next slide, including from a focused button   |
| Space / Shift+Space               | Next / previous slide                                    |
| Home / End                        | First / last slide                                       |
| Back / Next step, \[ / \]         | Previous / next walkthrough step                         |
| Reset or R                        | Reset only the current walkthrough                       |
| O / S / N / ?                     | Slide index / sources / notes / keyboard help            |
| F                                 | Browser full screen when available                       |
| Escape                            | Close an overlay and return focus                        |
| Tab / Enter                       | Reach and activate controls                              |
| Motion                            | Optional fades; reduced-motion preference takes priority |

Left / Right and Page Up / Page Down keep changing slides after you click a presenter
button, link or indicator toggle, because those controls don't use the keys. Editable
fields, open dialogs and modifier shortcuts keep their normal behavior, and so does selected
text unless a button or link has focus. Other shortcuts wait while a control has focus, so
Space and Enter activate it. Letter, symbol and Space shortcuts run only while the slide
area has focus. Returning to a walkthrough or the indicator toggles keeps their state;
reloading keeps the slide but resets them. Nothing advances automatically. The unused
reveal.js cross-window `postMessage` API is disabled.

Each indicator toggle reports its pressed state, and the suggested tier is announced
after a change. In forced-colors mode, the current walkthrough phase, pressed toggles and
the suggested tier keep a visible outline.

The bottom bar keeps the chapter label and slide navigation `--presenter-inset` from the
window edges, clear of viewer overlays such as the Copilot button SharePoint places at
the bottom right. With reading view off, the bar stacks centered rows at 1100 pixels
wide or narrower.

## Sources, notes and privacy

Open Sources on any slide for its references and version limits. Repository citations are
pinned to the snapshot commit. Anyone with the HTML file can read the notes and examples,
so keep secrets, customer data and private transcripts out of them. The deck makes no
service calls. Source links open in a separate tab.

OneDrive can share the file for download, but its preview does not host the interactive
deck. Recipients need to download the HTML and open it in a browser.

## Source layout

| File             | Responsibility                                                               |
|------------------|------------------------------------------------------------------------------|
| `index.html`     | Slide order, stable IDs, headings, static diagrams, excerpts and notes       |
| `deck.json`      | Catalog title, description and source qualification                          |
| `theme.css`      | Presentation type, slide layouts, presenter chrome and reading view          |
| `components.css` | Code, Chat input, chat transcript, review diff and depth-tier explorer       |
| `content.js`     | Public citations, walkthrough steps, indicator data and state helpers        |
| `components.js`  | Rendering for code, Chat input, transcripts, review and the tier explorer    |
| `deck.js`        | Slide and step navigation, dialogs, focus, announcements and keyboard        |
| `build.mjs`      | Copy source and reveal.js assets into `dist/` and generate `config.js`       |
| `bundle.mjs`     | Create `docs/slides/rai-planner.html` and check it against source            |
| `deck.test.cjs`  | Source, citation, walkthrough, depth-tier, runtime and bundle contracts      |

Run `npm run bundle` after edits, then `npm test`. From the repository root,
`npm run slides:check` verifies that every committed bundle matches its source.
Pull request validation also runs these tests when deck files change, and a Dependabot
update to reveal.js needs the same rebuild before it merges.
Tests check source and bundle contracts. After changing copy or behavior, also open the
rebuilt deck and check text wrapping, readability and the affected controls.

This deck was created from the repository-only HVE Slides starter and follows the visual
direction of the other HVE Core decks. Its files are local copies, not runtime imports from
another deck. The deck uses [reveal.js](https://revealjs.com/) 6.0.2 under the MIT license;
the build preserves its upstream license in the bundle. The source code is licensed under
MIT; see `LICENSE`. This README's explanatory prose is Microsoft content under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
