---
title: RPI with HVE Core deck
description: An interactive presentation on managing context and carrying evidence through the HVE Core RPI workflow.
ms.date: 2026-09-23
---

## Build and present

Open the [single-file presentation](../../docs/slides/rpi-with-hve.html) in a desktop browser.
If you're viewing it on GitHub, download the HTML file first. That version is ready to open
without a build.

To rebuild after editing, use Node.js 24 or later. Run these commands from the repository root:

```bash
cd slides/rpi-with-hve
npm ci
npm run bundle
npm test
```

Then open `docs/slides/rpi-with-hve.html`, rather than the source `index.html`.
The deck runs locally without a server, agent, editor extension or sign-in.
Installing dependencies needs a connection. Once bundled, the HTML file can be copied
and presented offline; opening an external source link still needs a connection.

`npm run build` creates the intermediate folder at `slides/rpi-with-hve/dist/`.
To present `dist/index.html` instead, keep that folder's files and `vendor/` directory together.

Use a landscape desktop display, ideally 1600 by 900 or larger, or browser full screen.
The presentation also fits 1280 by 720. Reading view provides unscaled, scrollable
content on compact or zoomed viewports and can be toggled at any size.

## Story and audience

The 18-slide talk is for engineers and takes about 15 to 20 minutes:

* The context section covers what an agent receives, incomplete tool results,
  distracting history and an eight-step repo investigation that produces a wrong answer.
  GPT-6 Astra and Claude Opus 5.5 provide the current model examples.
* The RPI section explains what each phase does and records, how to start it,
  when a fresh chat helps and how much input you can retain.
* A six-step log-retention example follows a partial search through a naming decision,
  plan critique, reported completion and a review finding. The closing slides explain
  when RPI is useful and when a direct edit is enough.

Customization file types and model benchmark comparisons are outside this talk's scope.

## Content and fidelity

Product details reflect the September 23, 2026 source snapshot:
HVE Core commit `33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d`, VS Code 1.139.0 and the
OpenAI, Anthropic, GitHub, VS Code and Claude Code documentation cited in each slide's
Sources dialog. Tool limits are specific to VS Code 1.139.0, and some depend on
experiment settings. The context studies are from 2023 and 2025; they do not measure
GPT-6 Astra or Claude Opus 5.5.

The tracking-files walkthrough uses a fictional `sample-repo`. Its question and final
comparison use reconstructed VS Code panels. The middle steps use an original reconstruction
of Agent Debug Logs and its Agent Flow Chart, with selectable event cards, arrows, a purple
Explore subagent group and an event-details pane. It replaces the earlier static workshop
account rather than replaying that session. The main agent delegates to Explore, which searches
one phrase, lists the root and reads only lines 1-40 of a 128-line document. A later section
uses different words for job receipts and release entries, so the search and read miss it.

The Event view shows the selected call or message. Missed context shows presenter evidence
that was not necessarily sent to the agent, including the later unread file section.
Explore's summary drops the investigation's limits. After further exploration, the
compaction example omits tool details from the next model input, without claiming that the
original Chat history or debug logs are erased. The unsupported answer and final comparison distinguish
local planning notes, runtime retry state and committed release inputs. These are scripted
facts, not claims about how HVE Core itself stores those records. Delegation and compaction
do not inevitably cause this failure.

The visual references are the [official Agent Flow Chart documentation](https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view#agent-flow-chart-view),
[VS Code 1.139.0 renderer](https://github.com/microsoft/vscode/blob/1.139.0/src/vs/workbench/contrib/chat/browser/chatDebug/chatDebugFlowLayout.ts)
and [view implementation](https://github.com/microsoft/vscode/blob/1.139.0/src/vs/workbench/contrib/chat/browser/chatDebug/chatDebugFlowChartView.ts).
Colored gutters, rounded cards and grouped subagent events follow those references.
Node text is enlarged for presenting, and each step shows a fitted excerpt rather than
recreating the native pan, zoom and filter controls. No upstream renderer, screenshots,
model names, timings or token counts are bundled into the example. Compaction is labelled
as an illustrative generic event because the pinned contract has no dedicated compaction type.

Both walkthroughs and all editor, tool, question and Chat panels use scripted
data. The repositories, outputs and file excerpts are fictional. In the log-retention implementation
step, completion and passing checks are the agent's claims; the review then finds missing
validation in two modules. This is an example of inadequate verification, not a successful
implementation.

The presentation does not run RPI, Copilot or VS Code. Agent and model pickers, question
options and send icons are display-only. The presenter controls navigate the local deck.
Flow-chart nodes and the Event and Missed context buttons inspect the scripted data locally.

RPI Agent is optional. Its setup slide comes before the phase overview and also shows
the standalone phase skills. File handoffs allow a fresh chat; the deck does not imply
that RPI automatically resets the conversation between phases.

## Editing the copy

Write for someone explaining the work aloud. Prefer specific actions and examples over
slogans, vary sentence length, and keep uncertainty close to the claim it qualifies.
Preserve commands, status values and the RPI Agent's official participation choices.

The editorial pass draws on [Microsoft's voice guidance](https://learn.microsoft.com/style-guide/brand-voice-above-all-simple-human)
and [Google's sentence guidance](https://developers.google.com/tech-writing/one/short-sentences).
[Research on model writing diversity](https://aclanthology.org/2026.acl-long.1803/) supports
checking repetitive expression, while [LLM-judge research](https://arxiv.org/abs/2306.05685)
warns against treating a preference for longer copy as evidence of quality.
[Self-Refine](https://selfrefine.info/) also shows that feedback can improve writing on
some tasks. These are editing considerations, not tests of who wrote the text.

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
normal behavior. Letter, symbol and Space shortcuts run only while the slide area has
focus. Returning to either walkthrough keeps its step; reloading keeps the slide but resets
both walkthroughs. Back, Next step and Reset affect only the current example.
Nothing advances automatically.
The unused reveal.js cross-window `postMessage` API is disabled.

In the flow chart, Tab reaches event nodes, and arrow keys or Home/End move focus among
the displayed nodes. Enter or Space selects a node without advancing the walkthrough.
The event-details region supports keyboard scrolling. Next step resumes the authored
sequence and selects the event for that step.

## Sources, notes and privacy

Open Sources on any slide for its references and version limits. Anyone with the HTML
file can read the notes and examples, so keep secrets, customer data and private transcripts
out of them. The deck makes no service calls. Source links open in a separate tab.

OneDrive can share the file for download, but its preview does not host the interactive
deck. Recipients need to download the HTML and open it in a browser.

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
Tests check source and bundle contracts. After changing copy or behavior, also open the
rebuilt deck and check text wrapping, readability and the affected controls.

This deck was created from the repository-only HVE Slides starter and adapts the
visual direction of the HVE Updates deck. Its files are local copies, not runtime
imports from another deck. The deck uses [reveal.js](https://revealjs.com/) 6.0.2
under the MIT license; the build preserves its upstream license in the bundle.
The source code is licensed under MIT; see `LICENSE`. This README's explanatory prose
is Microsoft content under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
