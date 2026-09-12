---
description: 'Presentation design and honest interactive examples for HVE Core HTML decks.'
---
<!-- cspell:words Bartosz Ciechanowski Menlo Consolas -->

# Design and Examples

## Visual Direction

For updates, follow the current deck and the user's reference images. For new decks, use
the HVE updates style as a starting point: near-black canvas, layered charcoal workbench
surfaces, light text, restrained blue accents and semantic addition/deletion colors.
Read the actual CSS tokens before choosing values. Do not transplant a screenshot's
low-contrast secondary text unchanged onto a projected slide.

The established visual references offer specific lessons:

* [Linear](https://linear.app/) suggests restrained product framing and precise hierarchy.
* [Raycast](https://www.raycast.com/) suggests a distinct opening or chapter accent, not
  continuous decoration behind dense technical content.
* [Resend](https://resend.com/) suggests occasional editorial type contrast.
* [Vercel Geist](https://vercel.com/geist/introduction) suggests consistent materials,
  alignment and spacing.
* [Bartosz Ciechanowski's explanations](https://ciechanow.ski/bicycle/) suggest interactions
  that make a causal relationship visible.

These are visual references, not assets to copy or universal quality rankings. Preserve
original composition and the deck's own purpose. A slide deck should not become a scrolling
marketing page.

## Layout and Type

For adaptable HTML/CSS and component-data examples, use
[style-recipes.md](style-recipes.md). Keep the existing deck's tokens and component owners
when applying those patterns to an update.

Use discrete slides with a clear heading and one main example, comparison or diagram.
Choose the layout by the relationship: chronology, ordered flow, source/preview, evidence
comparison or question/answer. Avoid making every section an equal-sized card grid.

Align repeated elements with layout primitives rather than manual offsets. Connect ordered
phases visibly, keep historical and current flows distinct, and align command/citation rows.
Separate headings from their examples more than labels from their values. Give the bottom
controls and notes sufficient clearance.

The reference deck uses a 1600 by 900 design canvas. Treat these as presentation design
targets, not host limits: at a 1280 by 720 viewport, main text should render at least 18 CSS
pixels, code at least 16, and minor labels/controls at least 12. Prefer larger text where the
venue requires it. Split or shorten content before shrinking it; never hide required
information merely to pass an overflow probe.

Use a readable system sans-serif and a real monospace fallback such as Menlo, Monaco or
Consolas. Apply monospace to code and identifiers, not every technical sentence. Occasional
serif emphasis may distinguish chapter slides, but source panels should retain their
workbench character. Use color alongside text, signs, borders or shape; color alone must
not convey a finding, phase, choice or diff.

## VS Code Reconstructions

Read current official source and the user's screenshots before changing recognizable UI.
Enlarge the relevant component instead of embedding a tiny full-desktop screenshot.
Keep a visible "Reconstructed" or "Scripted example" label. Reuse the deck's component
renderer and icon family rather than adding unrelated mockup styles.

| Subject | Useful representation | Fidelity boundary |
|---------|-----------------------|-------------------|
| User request | Copilot composer with context chips, text, agent/model row and send glyph | No real message submission or model change |
| User question | Numbered option rows, selected state, custom-answer line and footer | Show an answer state separately after the scripted response |
| Research | Agent Debug Logs / Agent Flow Chart with typed nodes and directional edges | Fictional tool/subagent trace; do not fabricate live timings or tokens |
| Plan | Current task structure and before/after diagram with source/preview parity | A fixed SVG preview is not a general Mermaid engine |
| Implementation | Checked tasks, changes excerpt and readable inline or side-by-side diff | Compute visible addition/deletion counts from the depicted changes |
| Installation | Chat gear, customization categories, Plugins page and top source input | Local presentation controls do not install or grant trust |

When teaching coordinated RPI in VS Code, include a dedicated agent-selection slide before
the phase overview and concise "Switch the agent dropdown to RPI Agent" reminders where
the user starts a phase. Keep the wrapper optional: standalone phase skills remain usable.
Do not put this guidance on unrelated HVE topics or imply HVE Builder requires RPI Agent.

Depict review controls only in the state where the host supports them. For example,
current Agent Host edits and older pending-edit Keep/Undo behavior differ. Verify the
relevant client version rather than combining attractive controls from incompatible states.

## Presenter-Controlled Demonstrations

Use a finite authored state sequence for explanatory walkthroughs. Show current workflow
phase/state beside the conversation or artifact. A memorable fictional project can connect
the story, but examples must remain technically faithful and labelled.

Keep real local controls distinct from decorative client chrome:

* Slide next/back and demo next/back/reset perform separate actions.
* Preserve step state on slide revisits, define reload behavior, and clamp both endpoints.
* Reset affects only its own example. No automatic typing or unattended agent loop.
* Make local source/preview toggles or install-walkthrough buttons work as labelled.
  Render other fictional controls passively rather than as dead focusable buttons.
* Do not take slide shortcuts while focus belongs to a button, link, input or dialog.
  Escape closes the local overlay and restores useful focus.
* Keep source and diagram, diff and counts, question and answer, and plan and changes evidence
  consistent through one shared data model where practical.

State the demonstration's execution level: browser-local behavior, connected service,
recorded playback or illustrative simulation. Do not silently replace a failed live run with
a scripted success. Prefer the illustrative browser-local route unless real execution is
requested and separately authorized.

## Motion, Access and Privacy

Keep optional motion off by default for the reference style, and honor reduced-motion
preferences. Any transition must settle into a state the presenter can discuss. Avoid
automatic playback and continuous movement. Provide visible keyboard focus, semantic headings,
descriptive control names and a keyboard-accessible exit from overlays.

Use the current [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [keyboard-trap guidance](https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html)
as criteria, not a blanket conformance claim. The usual contrast targets are 4.5:1 for
normal text and 3:1 for qualifying large text. Projection and actual assistive-technology
use need their own evidence.

All notes, embedded code, captions and data ship to recipients. A hidden dialog is not
private storage. Source links may open separately; the presentation itself should not make
unnecessary remote requests.

## Official UI Sources

* [VS Code source](https://github.com/microsoft/vscode): inspect the current relevant release
  and component, including theme defaults, Chat input, question carousel and plugin actions.
* [Agent debugging](https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view):
  distinguish the Agent Flow Chart from the raw Chat Debug view.
* [Review code edits](https://code.visualstudio.com/docs/agents/run/review-code-edits):
  client and session-type differences.
