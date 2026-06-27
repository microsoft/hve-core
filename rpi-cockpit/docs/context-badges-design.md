<!-- markdownlint-disable MD013 -->
# Context badges primitive design

## Purpose

Context badges are the last of the representation-map primitives still unbuilt, alongside the deferred app frame. They answer a legibility question the loop views cannot: under what context is the agent working right now? HVE Core ships around 70 instructions (coding standards), 13 skill packs (reusable tools), and 13 collections, and which of these is active shapes everything the agent does. The badges make that ambient context visible without the user having to read it out of a log.

This spec covers the context-badges primitive: the beat that sets the context, the state and view-model it adds, and the persistent strip that renders it across every loop view. It builds on the archetype-to-primitive mapping in [docs/representation-map.md](representation-map.md), which lists context badges as a primitive every archetype benefits from, and it follows the protocol shape already set by the other primitives.

## What it represents

The representation map describes context badges as "the active instructions, skills, and collection, for legibility," and maps the non-agent features onto them: instructions are "context badges: which coding standards are active for this work," and skills are "context badges: which reusable tool the agent just used." Collections are install context. The primitive surfaces three kinds of ambient context.

| Context | Source in HVE Core | On the strip |
| --- | --- | --- |
| Instructions | The active coding standards and rules for this work | A labeled group of instruction chips |
| Skills | The reusable skill packs in play | A labeled group of skill chips |
| Collection | The collection this work belongs to | A single collection chip |

Unlike the loop views, context badges are not tied to one archetype. The same instructions, skills, and collection can be active whether the agent is running RPI, a review, an interview, or a backlog board, so the badges live in the shell and persist across whichever loop view is showing.

## The strip

The badges render as a thin, calm strip directly under the top bar, above the main content, so they are visible in every loop view and on the home. It is built from these parts:

| Part | Content |
| --- | --- |
| Instructions group | A small "Instructions" label and one chip per active instruction |
| Skills group | A small "Skills" label and one chip per active skill |
| Collection group | A small "Collection" label and one chip for the collection |

The strip is calm and secondary: small chips, muted styling, no interaction in this cut. A group with nothing in it is omitted, and when no context is set at all the strip is hidden entirely, so it never adds visual noise before the agent has declared any context. The strip reuses the cockpit's existing chip and layer styling so it reads as part of the same product.

## Protocol additions

The primitive needs one beat and one MCP tool, in the declarative style the other primitives use: the agent sends the full current context, and the cockpit reflects it.

| Beat | Fields | Effect |
| --- | --- | --- |
| `context.set` | `instructions` (list), `skills` (list), `collection` (nullable) | Replaces the active context with exactly what is passed |

The MCP tool `set_context` wraps the beat. The semantics are replace, not merge: a call sets the whole context to what it carries, so the agent passes everything currently active each time it changes. This keeps the model simple and matches how `offer_approaches` and the other declarative tools already work. Because the badges are ambient rather than part of any loop, `context.set` does not touch the domain or the view; it only updates the context, and the strip shows wherever the user already is.

## State and view-model

Session state gains three fields: the active instructions, the active skills, and the collection. The reducer for `context.set` replaces all three. The view-model projects a `context` object with the same three fields, ready for the strip to paint. The client decides visibility (it hides the strip when all three are empty), so the view-model stays a plain projection with no presentation logic.

## Rendering

The client adds a `#context-strip` element under the top bar and a `renderContext` function that paints the three groups and toggles the strip's visibility. Because the strip is shell chrome rather than loop content, the client renders it on every update, before the domain routing that picks a loop view, so it is correct in all four loop views and on the home. Empty groups are skipped and the whole strip is hidden when there is no context.

## Scope

In scope:

* The `context.set` beat and the `set_context` MCP tool, with replace semantics.
* The context state fields, the reducer, and the view-model projection.
* The persistent `#context-strip` with instruction, skill, and collection chips, shown across every view and hidden when empty.
* Tests for the reducer, the view-model projection, the MCP tool, and the client rendering and visibility.

Deferred:

* Clickable badges that drill into an instruction, skill, or collection to explain it. The badges are read-only legibility for now; explaining them is part of the later help and discovery work.
* Memory as an ambient status indicator, which the representation map mentions for the meta-and-utility archetype. That is a separate ambient signal from these three context kinds.
* Accrual semantics for skills (a running list of skills as they are used). This cut is declarative replace; an accruing recent-skills view can come later if it proves more legible.

## Non-goals

* The badges do not change the active context. They reflect what the agent declares and never set instructions, skills, or the collection themselves.
* The badges are not a settings surface. They are legibility, not control.
* No new agent capabilities. The instructions, skills, and collections ship in HVE Core; the cockpit only renders which are active.
