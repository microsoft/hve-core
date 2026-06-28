<!-- markdownlint-disable MD013 -->
# Cockpit polish design (three deferred items)

## Purpose

The per-agent walkthrough closed every real surface gap and deferred three small refinements. This design picks them up as one cohesive polish pass: a responsive side-by-side interview layout, structured per-step sub-progress in the interview stepper, and an intent-based open-in-editor affordance on findings. Each is independent and small; together they round out the interview and findings surfaces.

## 1. Responsive side-by-side interview layout

Today the interview view stacks the conversation (docType header, the `#iv-steps` stepper, the `.flow-slot` decision flow) above the growing draft (`#iv-doc`). On a wide pane the draft sits far below the conversation; a side-by-side reading (conversation left, draft right) is more natural. On a narrow pane (the cockpit is often a roughly 40-percent side pane) two columns would be cramped, so the change is responsive, not unconditional.

The conversation children are wrapped in a new `.iv-convo` container, making `#interview-view` a parent of exactly two blocks: `.iv-convo` and `#iv-doc`. By default `#interview-view` is a vertical stack (the current behavior, unchanged). A CSS media query keyed on the pane iframe's own width (the breakpoint is `min-width: 980px`) turns `#interview-view` into a flex row: `.iv-convo` takes a flexible left column, `#iv-doc` a flexible right column, each scrolls independently, and the draft fills the row height instead of its fixed `min-height` block. `renderInterview` is unchanged; it still writes the same element ids. This is markup (the one wrapping div) plus CSS only.

## 2. Per-step sub-progress in the stepper

A coaching or assessment step often has internal progress (a comprehension check scored 2 of 3, ideas vetted 2 of 5). The stepper shows only the step name. `set_steps` gains an optional fourth argument, `progress`, an object `{ done: number; total: number }` that applies to the active step.

* Beat: the `steps.set` beat gains `progress?: { done: number; total: number }`.
* State: `interviewSteps` gains `progress?: { done: number; total: number }` (a single value that pairs with whatever step is currently `current`).
* Tool: `set_steps(steps, current, label?, progress?)` passes it through. No new tool; the count stays 33.
* View-model: the projected active step (and only the active step) carries `progress?`; done and pending steps never show it.
* Client: when the active pill has `progress`, it renders a small `done/total` count and a thin mini-bar after the step name. When absent, the pill is exactly as it is today.

`progress` is reset implicitly on each `set_steps` call (the whole field is replaced), so advancing a step without a `progress` argument clears the previous step's sub-progress. `interview.start` already nulls `interviewSteps`, so it clears `progress` too.

## 3. Intent-based open-in-editor on findings

Each finding shows its `file:line` as a copy-to-clipboard button. This adds a second, small open control (a `↗` button) next to it; copy and open are both useful and both remain. The sandboxed pane cannot reach the host editor directly, so opening is expressed as an intent the agent performs, exactly like the decide and revise frames.

* A new inbound frame `{ type: "open"; file: string; line?: number }` is added to `parseInbound` (rejecting a non-string file or a non-number line) and `applyInbound`.
* `applyInbound` for `open` enqueues a directive on the bridge: a `note` directive reading `open <file>:<line> in the editor` (or just `<file>` when no line), which the agent drains through `check_directives` and acts on by opening or reading that file. No bridge state changes beyond the existing directive queue.
* Client: `renderFindings` renders, next to the existing `.finding-loc` copy button, a `.finding-open` button carrying `data-file` and `data-line`; the delegated click handler sends `{ type: "open", file, line }`. Both values are escaped in the attributes.
* Agent contract: a line noting that an `open <file>:<line>` directive from `check_directives` means the user clicked a finding's open control and wants that file opened.

This is an intent ("ask the agent to open the file"), not a direct IDE jump.

## Architecture and isolation

The three changes touch separable seams:

* Layout (item 1): `public/index.html` (the `.iv-convo` wrap and its media query) only. No JS, no state.
* Stepper sub-progress (item 2): the `steps.set` beat (`events.ts`), `interviewSteps` state (`state.ts`), the projection (`render.ts`), the `set_steps` tool (`mcp.ts` / `handlers.ts`), and `renderInterview` (`client.js`).
* Open intent (item 3): `inbound.ts` (the frame), `renderFindings` plus the click handler (`client.js`), and the contract. No state or view-model change.

No existing view's behavior changes when these features are unused: the layout is identical below the breakpoint, the stepper pill is identical without `progress`, and findings are identical aside from the added open button.

## Testing

* Layout: a structural test that `#interview-view` contains an `.iv-convo` wrapping the stepper and the flow slot, with `#iv-doc` as a sibling (happy-dom has no layout engine, so the responsive behavior itself is verified live with `preview_resize` at a wide and a narrow width).
* Sub-progress: state stores `progress`; the view-model attaches `progress` to the active step and not to done/pending steps; the client renders the count and mini-bar on the active pill and nothing when `progress` is absent.
* Open intent: `parseInbound` accepts a valid `open` frame and rejects a missing or non-string file and a non-number line; `applyInbound` enqueues the directive; the client renders a `.finding-open` button with `data-file` / `data-line` and the click sends the frame.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the three items above and their tests, on `design/rpi-cockpit`, to become a follow-up PR into the fork.

Deferred / non-goals:

* A draggable splitter between the conversation and the draft (the responsive split is fixed-ratio).
* Multi-value or per-step (rather than per-active-step) sub-progress: one `progress` pairs with the current step; a full per-step map is unnecessary.
* A direct editor jump from the pane (no host editor bridge exists); the open control is an intent only.
* Generalizing the open intent to other views: findings is the only surface with a file location today.
