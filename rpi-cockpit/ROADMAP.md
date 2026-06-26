<!-- markdownlint-disable MD013 -->
# RPI Cockpit Roadmap

## Mission

The RPI Cockpit is a host-agnostic visual companion for agentic coding: a beautiful, inviting window into the agent you already have. It makes an agent's work legible (you can see what it is doing), steerable (you can nudge it), and collaborative (it asks the right question at the right moment), and it renders wherever the agent already lives, whether in the Claude Code Preview pane, a VS Code webview, or a standalone browser dashboard.

The single near-term goal is a genuinely high-quality user interface for the experience we already have, not new agent capabilities. The agent is the engine; the Cockpit is the cockpit.

## The bet: one web cockpit, many host panes

The durable product is not any single renderer. It is the beat protocol and view-model: the agent emits small structured "beats" (`phase.enter`, `subagent.start`, `validate`, `present_options`, `screen.show`, and so on); a pure reducer folds them into session state; and `toViewModel(state)` produces exactly what a UI needs to paint. The web cockpit renders that view-model.

MCP is the data and control wire (beats in, decisions out); it does not draw the UI. So the question that drives this project is not "where does MCP run" but "what can each host render?" That maps cleanly to surfaces:

| Surface           | Type          | Primary renderer                    | Server?      |
|-------------------|---------------|-------------------------------------|--------------|
| VS Code (Copilot) | GUI editor    | Web cockpit in a webview pane       | host-managed |
| Claude Code       | Desktop / CLI | Web cockpit in the Preview pane     | host-managed |
| Codex / terminal  | CLI           | Inline snapshot, or browser pop-out | local, opt-in |

The host owns the server. A spike confirmed the cockpit web UI renders fully and interactively in both a VS Code webview and the Claude Code Preview pane, with the host launching and managing the cockpit's local server (Claude Preview assigns the port through the `PORT` environment variable, exactly as a VS Code extension would). So this is not infrastructure you run, it is infrastructure the host runs. One web cockpit, rendered in many host panes; an inline terminal snapshot and a standalone browser pop-out stay as fallbacks where no pane exists.

The cockpit also has to represent more than the RPI loop. HVE Core's full surface (about 65 agents, plus prompts, instructions, and skills) collapses into a handful of workflow archetypes that share a small set of archetype-agnostic primitives: timeline, decision, list, question, screen, app frame, and context. That mapping is worked out in [docs/representation-map.md](docs/representation-map.md), and RPI is the first composition of those primitives rather than the whole UI.

## Current state (v0)

Shipped on `design/rpi-cockpit`:

| Piece                    | What it provides                                                                                                                                                                                         |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Protocol core            | Beat schemas (`events.ts`), a pure reducer (`state.ts`), and the view-model (`render.ts`); MCP tools for every beat, including `present_options`, `offer_approaches`, `check_directives`, and `show_screen`. |
| Browser-cockpit renderer | The standalone web dashboard: structured RPI loop view, blocking decisions, a steer panel, an agent-authored sandboxed screen pane; hardened with per-session token auth, loopback-only bind, and a finite decision timeout. |
| Host-agnostic talk-back  | Directives and decisions are also written to JSONL files, so steering works without a live MCP connection.                                                                                                |
| Cross-host launch        | An idempotent `init` command writes the correct MCP config and narration into Claude Code, Codex, and VS Code.                                                                                            |
| Agent instrumentation    | The HVE Core RPI agents narrate to the Cockpit when its tools are present.                                                                                                                                |

In short, we have the protocol and the web cockpit. The roadmap is mostly about embedding it cleanly in host panes and generalizing what it can show.

## Horizons

### Now (v1): embed the one web cockpit in the host's pane

A spike proved the cockpit we already have renders fully and interactively in both a VS Code webview and the Claude Code Preview pane. So v1 is not a new renderer; it is making that web cockpit embed cleanly, and generalizing what it can show.

* Embed mode: the server reads the host-assigned `PORT`, binds loopback, and trusts the loopback pane without the per-session-token friction (or auto-opens the keyed URL), plus a committed launch config and a preview launcher, so the cockpit loads in a pane with no manual steps.
* App frame primitive: an `app_frame` pane (a trusted localhost iframe) so the cockpit can embed the app under development beside the RPI loop and steer panel. It is the trusted sibling of the sandboxed `screen` pane, which renders untrusted agent HTML. See [docs/representation-map.md](docs/representation-map.md).
* Generalize the beat protocol from the RPI-specific phase enum toward the archetype-agnostic primitives in [docs/representation-map.md](docs/representation-map.md), with RPI as the first composition.

This horizon is done when the cockpit loads in a pane in both VS Code and Claude Code with no manual steps, embeds the app under development in an `app_frame`, and a non-RPI workflow renders through the generic primitives.

### Next: make it a genuinely great UX

With native rendering in place, invest in quality across every renderer:

* A polished Fluent or Liquid-Glass visual language, consistent across surfaces.
* Motion and micro-interactions that make state changes feel alive rather than noisy.
* A calm, glanceable presence, a status surface you read at a glance rather than a wall of logs.
* Accessibility to WCAG 2.2 (HVE Core already treats a11y as first-class).
* Responsive, adaptive layout, so the same view-model degrades gracefully from a wide VS Code panel to a narrow inline widget.

### Later: the parking lot

New capabilities live here, explicitly deferred until the UX is excellent. Two are starred for early promotion because they are too good to wait on:

* Live team-orchestration view (starred): the RPI orchestrator and its subagents as a board you watch and intervene in, with the ability to pause, swap, or spawn an agent mid-run.
* 3D codebase map (starred): a spatial map of the codebase the agent visibly moves through as it researches and edits.

The rest, parked: a session replay or time-machine scrubber, voice steering, drag-to-focus (point the agent at a file or line), rewind-and-branch from a past checkpoint, an AG-UI or A2A protocol layer so any agent framework can drive the Cockpit, and remote or mobile viewing.

## Non-goals

* No new agent capabilities during the v1 and Next phases. The agent ships in HVE Core; the Cockpit only renders and steers it.
* No hosted or cloud service. The Cockpit is local and ephemeral, and it dies with the session.
* The host owns auth and identity. The Cockpit never becomes an identity provider or a long-lived backend.
* Not a model host. It works with whatever model the host already runs.

## Relationship to HVE Core

The Cockpit is a separate companion project that consumes HVE Core's agents, while HVE Core stays deliberately artifacts-only. The Cockpit is a host-managed runtime (a local web server the host launches and renders in its pane), which is exactly the runtime HVE Core's charter excludes, so it stays here. Only the thinnest fallback, an inline terminal snapshot the agent paints through a rendering tool, is artifact-shaped enough to consider upstream later.

## How to influence this roadmap

This is an early, opinionated roadmap and will move with what we learn building the v1 renderers. The ordering above is a bet, not a contract: the "Later" items (especially the two starred ones) can jump forward the moment the UX foundation is solid enough to carry them.
