---
title: HVE Core updates deck
description: Interactive HTML presentation of HVE Core changes from April to September 2026.
ms.date: 2026-09-11
---

## Build and present

Use Node.js 24 or later. From the repository root:

```bash
cd slides/hve-updates
npm ci
npm run build
npm test
```

Open `slides/hve-updates/dist/index.html` in a desktop browser.
Open the generated file, not the source `index.html`.
No server, live agent, editor extension or authentication is required.
Dependency restore needs network access; after building, the entire `dist/`
folder can be copied and presented offline. Keep its files and `vendor/`
directory together. Source links need a connection when opened.

Use a landscape desktop display, ideally 1600 by 900 or larger, or browser
full screen. The presentation also fits 1280 by 720. Compact screens keep
navigation available but are not the intended projected format.

## Create or update decks

Use the repository-only [HVE Slides skill](../../.github/skills/hve-slides/SKILL.md)
to update this presentation or create another HVE-related deck under `slides/`.
It covers source research, slide writing, visual examples, editing, validation
and local sharing. It is not included in the HVE Core plugin.

```text
/hve-slides deck=slides/hve-updates mode=update
/hve-slides mode=create topic="HVE Core security planning"
```

## Share as one HTML file

From `slides/hve-updates/`, run:

```bash
npm ci
npm run bundle
```

If dependencies are already restored, only `npm run bundle` is needed.
It rebuilds the deck and writes **`dist/hve-updates.html`** with all CSS,
JavaScript, SVG content and reveal.js assets embedded. The full reveal.js
license is retained in an inert template inside the HTML. No new build
dependency is required.

The source build uses the repository's canonical bundler under
`.github/skills/hve-slides/templates/deck/`. Keep the checkout available when rebuilding;
`bundle.mjs` in this deck is a thin wrapper around that implementation. The generated
HTML remains independent of the repository and skill files.

Share that one file. Recipients can download it and open it directly in a
desktop browser, without extracting a folder, installing Node.js or starting
a server. Slides, walkthroughs, notes, source dialogs and keyboard controls
are preserved. External citation links need a connection only when opened.

OneDrive can store and share the file for download. Its web preview is not
a website host for the interactive deck; download the HTML and open the
downloaded copy in the browser. Organization policies may restrict HTML
downloads or scripts. All presenter notes remain included, so review the
content before sharing.

The bundler supports this deck's local stylesheets and ordered deferred
scripts. It fails with an error if new markup or CSS introduces a resource
that has not been embedded, rather than producing an incomplete one-file
deck. It does not download external resources. Re-run `npm run bundle`
after source edits to refresh the shared file.

## Presenter controls

| Control | Behavior |
|---------|----------|
| Left / Right, Page Up / Page Down | Previous / next slide |
| Space / Shift+Space | Next / previous slide |
| Home / End | First / last slide |
| Slides button or O | Slide index with chapter labels |
| Back / Next step in a walkthrough | Move one demonstration step |
| \[ / \] | Previous / next demonstration step |
| Reset button or R | Reset only the current demonstration |
| Sources or S | Current slide citations and all references |
| Notes or N | Presenter notes for the current slide |
| Keys or ? | Keyboard reference |
| Full screen or F | Browser full screen, if supported |
| Motion button | Optional slide fades, off by default |
| Mermaid source / Diagram preview | Toggle the plan's diagram and its matching source |
| Escape | Close a dialog and restore focus; exit browser full screen |
| Tab / Enter | Reach and activate visible controls |

Slide navigation and demonstration steps are deliberately separate.
When a button, link or other interactive control has focus, normal keyboard
activation takes priority over slide shortcuts. Use visible navigation or
move focus away from the control to resume shortcuts.

Demo steps persist while revisiting slides in the same page session.
Reload restores the slide hash but resets all demonstrations to their first
step. All sequences have finite boundaries. Nothing autoplays.
The operating system's reduced-motion preference overrides the Motion
button and disables transitions.

## Content and fidelity

The deck contains 26 slides, with separate RPI and HVE Builder sections and
presenter-stepped demonstrations: 15 RPI steps, nine HVE Builder steps and
five VS Code source-install steps. Snack Mission Control and Snack Evidence
are invented examples, not HVE Core features or installed artifacts.

Editor and chat panels are HTML reconstructions enlarged for presenting.
The excerpts follow current artifact templates; their data and results
are scripted. The presentation does not run RPI, HVE Builder, Copilot CLI
or a VS Code workbench.

The RPI example includes a Copilot-style request composer, an Agent Flow
Chart with tool and optional subagent calls, Research and Plan question
cards followed by completed answers, a plan diagram, and an implementation
view with completed tasks, a changes excerpt and an inline +/- diff above
the composer. The diagram preview and Mermaid source use the same declared
nodes and edges; this is a constrained presentation rendering, not a
general-purpose Mermaid interpreter.

Mode/model pickers, question options and send glyphs are display-only.
Slide 9 shows the four RPI participation choices in a Copilot-style question
card, with the planning-only option selected as an example. It does not
change the session mode. Use the presenter step controls to advance the
walkthroughs. The diagram/source toggle works locally. All subagent calls
shown in the flow chart are fictional.

The RPI usage slides include a **Switch the agent dropdown to RPI Agent**
cue. Click its **RPI Agent** button to see the dropdown below the VS Code
Chat input. A dedicated **Switch Chat to RPI Agent** slide introduces this
setup before the phase-skill overview. The walkthrough starts with the app
request, and its composer examples highlight the selected agent. This describes the
coordinated workflow; standalone phase skills still work without the
RPI Agent. The local dropdown example does not change your real Chat agent.

The installation example starts with the top of the Chat panel and its
**Open Customizations** gear. Click the gear to open the reconstructed
Agent Customizations editor with **Plugins** selected, then click
**Install from Source** to reveal the top quick-input box with
`microsoft/hve-core` prefilled. The example input is read-only: Enter
advances to the trust checkpoint, and Escape or its close button returns
to the Plugins page. These controls only navigate the local walkthrough;
they do not install a plugin, grant trust or change VS Code.
The header and customization window follow the supplied visual references,
with Featured collapsed and unrelated counts omitted to keep the slide
readable. Displayed installed counts are illustrative, not your inventory.

Historical milestones cite commits and merged pull requests. April is a
repository snapshot. HVE Builder was introduced in merged history on
July 11, 2026, in PR #2438. Some Pacific commit dates differ from UTC merge
dates. The current HVE source baseline is
`3e29a0b2422bd13c39a087c635638e6722859e73` on September 10, 2026.

Plugin instructions were researched on September 10, 2026, against official
documentation and source, with VS Code 1.137.0 and Copilot CLI v1.0.83 as
the latest releases observed. CLI-to-VS Code discovery depends on the
same accessible home/environment and enabled, policy-allowed plugins.
"VS Code only" describes the default separate install flow. Manually
shared paths and future integrations may behave differently.
This deck does not install plugins.

## Sources, notes and privacy

Every slide has a Sources dialog with HVE references, release dates and
version limits. The visual references include official VS Code sources.
The styles and diagrams are original reconstructions.

Anyone with the bundle can read its notes, examples and references.
Keep secrets, customer data and private transcripts out of it. Source links
open in a separate browser tab when selected. The deck makes no service calls.

Present from the HTML bundle. Printing does not preserve interactive
controls. A separate synchronized presenter window is not provided.

## Source layout

| File | Responsibility |
|------|----------------|
| `index.html` | Slide narrative, static diagrams, artifact excerpts and notes |
| `theme.css` | Original presentation and reconstructed UI styling |
| `components.css` | Copilot, debug, diagram and diff component styling |
| `content.js` | Public citations, walkthrough data, declared graphs and pure state helpers |
| `components.js` | Reusable original UI reconstructions and source/diagram toggle |
| `deck.js` | Slide controls, demo rendering, focus, dialogs and keyboard behavior |
| `build.mjs` | Copy source and reveal.js assets into the portable local folder |
| `bundle.mjs` | Call the shared template bundler to create `dist/hve-updates.html` |
| `deck.test.cjs` | Built-in Node tests for transitions, content and bundle contracts |

Run `npm run build` or `npm run bundle` after edits, then `npm test`.
The tests check the generated folder and rebuild the one-file output.
Browser layout and interaction evidence must be refreshed
when changing presentation behavior; Node tests do not substitute for it.

The deck uses [reveal.js](https://revealjs.com/) 6.0.2 under the MIT license.
The build preserves its upstream license in `dist/vendor/reveal-LICENSE.txt`.
No font, image, editor or runtime service is downloaded by the presentation.
