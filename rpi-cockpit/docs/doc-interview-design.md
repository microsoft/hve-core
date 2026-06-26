<!-- markdownlint-disable MD013 -->
# HVE Cockpit guided doc interview loop view design

## Purpose

The third loop view: a guided document interview for the doc-builder archetype (PRD, decision record, security plan). The agent asks questions one at a time, the user answers free-form, a document grows, and it ends in a backlog handoff. This lands the question primitive (a free-text answer, the free-text sibling of the decision) and reuses the screen primitive for the growing document. It is reached from the Navigator's "Write docs and specs" tile and renders in the loop-view shell. It builds on the elicitation primitive (whose orchestrator it generalizes) and the findings panel (whose composition-routing it follows).

## The question primitive: both surfaces, first wins

Approved interaction. When the agent asks a free-text question, the cockpit shows a pane question card with a text input AND fires a native free-text elicitation (a single string field) into the host chat. Answering either one resolves the question and dismisses the other. Hosts without elicitation fall back to the pane card. A declined or cancelled elicitation does not resolve the question: the pane input and the timeout fallback stay in control. This is the same model as the decision card, with a free-text field instead of a bounded choice.

## Generalizing the elicitation orchestrator

The race in `presentOptionsWithElicitation` (pane promise versus `elicitInput`, first answer wins, cancel the loser, capability fallback, decline ignored) is already generic. This milestone extracts that race into a shared helper used by both the decision and the question, which differ only in three slots:

| Slot | Decision | Question |
|---|---|---|
| Pane mechanism | `bridge.presentOptions` / `resolveDecision` | `bridge.askQuestion` / `resolveQuestion` |
| Elicitation schema | a string property with `oneOf` const/title | a single free-text string property |
| Result mapping | the chosen option id | the free-text answer string |

The decision path keeps its exact behavior; the question path is the free-text instance of the same race. No new concurrency logic, just two parameterizations of the existing one.

## The interview composition

* A new domain `interview`, the third composition beside `rpi` and `review`.
* `interview.start { docType }` sets the domain to `interview`, sets `view: "loop"` (self-sufficient, like `review.start`), and records the document type.
* The agent narrates: `interview.start`, then `ask_question` (blocks until answered), records the answer and paints the document so far with `show_screen`, then the next `ask_question`, and so on, ending in a backlog handoff.
* The interview loop view is a header (the document type), the current question card (a text input) when a question is pending, and the growing document.

## The growing document: reuse the screen primitive

The document is the existing screen primitive (the agent paints HTML or rendered markdown with `show_screen`, isolated in a sandboxed iframe). To avoid disturbing the RPI composition's screen pane, the interview view has its own document area, a sandboxed iframe (`sandbox=""`), into which the client paints the shared `screen` state when the domain is `interview`. One screen state, rendered into the RPI screen pane under domain `rpi` and into the interview document pane under domain `interview`. No new document renderer in v1.

## State and protocol

* `SessionState` gains `docType: string | null` and `pendingQuestion: { id: string; prompt: string } | null`, and the `domain` union gains `"interview"`.
* `interview.start { docType }` is a beat (sets domain, view, docType). The question is NOT a beat: like `present_options`, `ask_question` is a blocking tool that sets `pendingQuestion` and resolves when the user answers.
* `bridge.askQuestion(prompt, timeoutMs)` sets `pendingQuestion` and returns `Promise<string>`; `bridge.resolveQuestion(id, text)` resolves it (from an inbound `answer` frame, the native elicitation, or the timeout).
* Inbound frame `answer { id, text }` (the pane text input) routes to `bridge.resolveQuestion`.
* The view-model projects `domain`, `docType`, and `pendingQuestion`.
* MCP tools: `interview_start` and `ask_question` (the latter drives both surfaces via the shared orchestrator).

## Scope

In scope for v1:

* The question primitive: the shared race helper generalized to free-text, the pane question card and its `answer` frame, the native free-text elicitation, and the timeout fallback.
* The interview domain, composition routing, and the loop view (header, question card, shared screen document pane).
* The `interview_start` and `ask_question` MCP tools.
* The "Write docs and specs" tile already launches the interview intent; no Navigator change.

Deferred to later plans:

* A generic section stepper (progress through the interview) beyond the simple document-type header.
* A dedicated markdown document renderer (v1 reuses the screen primitive).
* Making the backlog handoff an explicit cockpit action rather than agent narration.

## Non-goals

* No change to the decision card, the findings panel, or the RPI composition.
* The cockpit renders what the agent narrates; it does not run the interview logic or write the document itself.
* Secure defaults unchanged: the document iframe is `sandbox=""`, the token gate is untouched, and every rendered field is escaped.

## Security

The question prompt and the rendered answer are escaped through the client's `esc` helper. The free-text answer the user types is sent as an `answer` frame (data, never executed). The document renders only in the sandboxed iframe (`sandbox=""`), the same boundary the screen primitive already uses, so agent-painted document HTML cannot run scripts or reach the page.
