---
title: RPI with HVE Core deck
description: Interactive HTML presentation on why context still matters with frontier coding models and how the HVE Core RPI workflow keeps each phase focused.
ms.date: 2026-09-23
---

## Build and present

Open the committed [single-file presentation](../../docs/slides/rpi-with-hve.html) directly in a
desktop browser, or download it from GitHub and open the downloaded HTML file.
No build is required to present that version.

To rebuild after editing, use Node.js 24 or later. From the repository root:

```bash
cd slides/rpi-with-hve
npm ci
npm run bundle
npm test
```

Open `docs/slides/rpi-with-hve.html` in a desktop browser, not the source `index.html`.
No server, live agent, editor extension or authentication is required.
Dependency restore needs network access; after bundling, the one HTML file can be
copied and presented offline. Source links need a connection when opened.

`npm run build` creates the intermediate folder at `slides/rpi-with-hve/dist/`.
To present `dist/index.html` instead, keep that folder's files and `vendor/` directory together.

Use a landscape desktop display, ideally 1600 by 900 or larger, or browser full screen.
The presentation also fits 1280 by 720. Reading view provides unscaled, scrollable
content on compact or zoomed viewports and can be toggled at any size.

## Story and audience

The deck is an engineer-facing talk of about 15 to 20 minutes in 18 slides:

* Context: frontier models (GPT-6 Astra and Claude Opus 5.5) still act on the context
  they have. The slides cover the running log, bounded tool output, accumulated noise,
  distracting context and one observed workshop session.
* RPI: each phase starts from a durable file. The slides cover agent selection,
  phase contracts, research coverage, plan and critique, fresh chats, review routing
  and RPI Agent participation choices.
* In practice: a six-step scripted walkthrough, the trade-offs of using RPI and a closing call to action.

It does not explain customization file types, compare model benchmarks or reproduce
the earlier 43-slide workshop.

## Content and fidelity

Model, tool and HVE claims describe sources observed on September 23, 2026:
HVE Core commit `33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d`, VS Code 1.139.0 and the
OpenAI, Anthropic, GitHub, VS Code and Claude Code documentation cited in each slide's
Sources dialog. Tool limits are VS Code 1.139.0 defaults, some experiment-based;
other hosts use different limits. The research findings on the noise slide come from
2023 and 2025 studies of earlier models and are labelled as such.

The observed-session slide reconstructs one March 2026 workshop session as a text
diagram. It is an observation, not a benchmark, and contains no workshop screenshots.

The log retention walkthrough and every editor, tool, question and chat panel are HTML
reconstructions with scripted data. The repository, search output, research, plan,
critique, changes and review excerpts are fictional. The presentation does not run
RPI, Copilot or a VS Code workbench. Mode and model pickers, question options and send
glyphs are display-only; only the presenter controls perform local actions.

RPI Agent is optional. The agent-selection slide precedes the phase overview, and
the standalone phase skills are shown alongside it.

## Presenter controls

| Control                           | Behavior                                                 |
|-----------------------------------|----------------------------------------------------------|
| Left / Right, Page Up / Page Down | Previous / next slide                                    |
| Space / Shift+Space               | Next / previous slide                                    |
| Home / End                        | First / last slide                                       |
| Back / Next step, \[ / \]         | Previous / next walkthrough step                         |
| Reset or R                        | Reset only the current walkthrough                       |
| O / S / N / ?                     | Slide index / sources / notes / keyboard help            |
| F                                 | Browser full screen when available                       |
| Escape                            | Close an overlay and return focus                        |
| Tab / Enter                       | Reach and activate controls                              |
| Motion                            | Optional fades; reduced-motion preference takes priority |

Focused controls, editable fields, text selections and modifier shortcuts keep their
normal behavior. Character shortcuts, including Space, run only while the presentation
surface itself has focus. The walkthrough keeps its step when you revisit the slide;
reload restores the slide hash but resets the walkthrough. Nothing advances automatically.
The unused reveal.js cross-window `postMessage` API is disabled.

## Sources, notes and privacy

Every slide has a Sources dialog with dated references and version limits. Anyone
with the bundle can read its notes, examples and references. Keep secrets, customer
data and private transcripts out of it. The deck makes no service calls; source links
open in a separate browser tab when selected.

OneDrive can store and share the file for download. Its web preview is not a website
host for the interactive deck; download the HTML and open the downloaded copy.

## Source layout

| File             | Responsibility                                                          |
|------------------|-------------------------------------------------------------------------|
| `index.html`     | Slide order, stable IDs, headings, static diagrams, excerpts and notes  |
| `deck.json`      | Catalog title, description and source qualification                     |
| `theme.css`      | Presentation type, layouts, diagrams, presenter chrome and reading view |
| `components.css` | Code, Copilot input, question and implementation views                  |
| `content.js`     | Public citations, static examples, walkthrough steps and state helpers  |
| `components.js`  | Reconstructed editor, Copilot input, question and diff rendering        |
| `deck.js`        | Slide and step navigation, dialogs, focus and keyboard behavior         |
| `build.mjs`      | Copy source and reveal.js assets into `dist/` and generate `config.js`  |
| `bundle.mjs`     | Create `docs/slides/rpi-with-hve.html` and check it against source      |
| `deck.test.cjs`  | Source, citation, walkthrough, topic and bundle contracts               |

Run `npm run bundle` after edits, then `npm test`. From the repository root,
`npm run slides:check` verifies that every committed bundle matches its source.
Node tests do not establish rendered quality or interaction correctness; refresh
browser evidence after changing presentation behavior.

This deck was created from the repository-only HVE Slides starter and adapts the
visual direction of the HVE Updates deck. Its files are local copies, not runtime
imports from another deck. The deck uses [reveal.js](https://revealjs.com/) 6.0.2
under the MIT license; the build preserves its upstream license in the bundle.
The source code is licensed under MIT; see `LICENSE`. This README's explanatory prose
is Microsoft content under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
