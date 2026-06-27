<!-- markdownlint-disable MD013 -->
# Backlog kanban loop view design

## Purpose

The backlog kanban is the third loop view, after the reviewers findings panel and the guided document interview. It is the cockpit composition for the backlog orchestration archetype: the GitHub, ADO, and Jira backlog managers and the discover, triage, sprint-plan, and execute prompts. The representation map ranks it third in the proof order and calls it the most complex workflow, and the one that most needs legibility, because work items moving through states across autonomy tiers is exactly the kind of activity that is opaque in a text log and obvious as a board.

This spec covers the kanban loop view, the beats that drive it, the state and view-model it adds, and how it slots into the existing shell. It builds on [ROADMAP.md](../ROADMAP.md) and the archetype-to-primitive mapping in [docs/representation-map.md](representation-map.md), and it follows the shape already set by [docs/reviewers-findings-design.md](reviewers-findings-design.md) and [docs/doc-interview-design.md](doc-interview-design.md).

## What it represents

From the representation map, the backlog archetype is "work items move through states; autonomy tiers; sprint context," and its cockpit representation is "a kanban board of items and states, plus the action the agent is taking." It draws on two primitives: the timeline or stepper (the ordered states become the board columns) and the list (the work items become the cards). The board adds two pieces of context the map calls out: the sprint or board the work belongs to, and the autonomy tier each item runs under.

| Concept | On the board |
| --- | --- |
| States | Ordered columns, supplied by the agent, because GitHub, ADO, and Jira each name their states differently |
| Work items | Cards in a column, each with an id, a title, an optional kind, and an optional autonomy tier |
| Sprint or board context | The board header, naming what this board is (a sprint, a repo, a project) |
| The action the agent is taking | A current-action line in the header, so the board is never a still picture of state with no sense of what is happening now |

The columns are agent-supplied rather than a fixed set. A GitHub flow might be Triage, Todo, In progress, In review, Done; an ADO sprint might be New, Active, Resolved, Closed. The agent declares its own states when it starts the board, and the board renders exactly those, in order.

## The loop view

The kanban opens in the same pane as the other loop views, routed by the session domain (`backlog`), and is the cockpit's standing surface while a backlog workflow runs. It is built from these parts:

| Part | Content |
| --- | --- |
| Header | The board target (the sprint, repo, or project name), a count of items, and the current agent action when one is set |
| Columns | One column per state, in the order the agent declared, each labeled with its name and item count |
| Cards | One card per work item in its current column: the item id, the title, and small chips for kind and autonomy tier when present |

The board is calm at rest. A card carries only its id, title, and chips; the detail of an item is the agent's to narrate in the chat, not to crowd onto the card. An empty column still renders, so the shape of the workflow stays visible even before items land in a state.

## Protocol additions

The kanban needs four beats, mirroring how the findings panel added `review.start` and `finding.add`. The board is agent-driven: the agent declares the columns, adds items, moves them as work progresses, and sets the action line.

| Beat | Fields | Effect |
| --- | --- | --- |
| `backlog.start` | `target`, `columns` (ordered, at least one) | Switches the domain to `backlog`, sets the board target and columns, and resets items and the action |
| `item.add` | `id`, `title`, `column`, `kind?`, `tier?` | Adds a work item to a column, or replaces the item with the same id if it already exists |
| `item.move` | `id`, `column` | Moves the item to a different column; a no-op if the id is unknown |
| `backlog.action` | `text` (nullable) | Sets or clears the current-action line in the header |

Each `*.start` beat in this protocol is self-sufficient: `backlog.start` sets `view: "loop"` and `domain: "backlog"` on its own, so a cold backlog session lands directly on the board without a prior `session.begin`, exactly as `review.start` and `interview.start` do.

The MCP surface adds one tool per beat: `backlog_start`, `add_item`, `move_item`, and `set_backlog_action`, each a thin wrapper over its beat in the same style as the existing handlers.

## State and view-model

Session state gains a `backlog` value in the domain union and a small set of board fields: the target, the ordered columns, the items (id, title, column, optional kind and tier), and the current action. The reducers follow the existing idioms: `item.add` replaces by id the way `subagent.start` and `artifact.update` already replace by name and path, and `item.move` maps over the items the way `subagent.stop` does.

The view-model projects a board ready to paint: the target, the action, the item count, and the columns in declared order, each carrying its items. Empty columns are kept so the board shows the full workflow shape. This mirrors how the findings view-model groups findings by severity and keeps only non-empty groups, except the board keeps empty columns on purpose, because a column is a state in the workflow, not just a bucket that happened to fill.

## Rendering

The client gains a `#backlog-view` section inside the loop container, alongside `#rpi-view`, `#findings-view`, and `#interview-view`, and the render router shows it when `domain` is `backlog`, hiding the others, exactly as the interview and findings branches already do. A `renderBoard` function paints the header and lays the columns out horizontally, each column a vertical stack of cards. The board scrolls horizontally when there are more columns than fit, so a wide workflow stays usable in a narrow pane.

The cards and chips reuse the cockpit's existing visual language (the same layer, stroke, and accent variables as the findings and tile surfaces) so the board reads as part of the same product, not a bolted-on view.

## Scope

In scope for this view:

* The four beats (`backlog.start`, `item.add`, `item.move`, `backlog.action`) and their MCP tools.
* The `backlog` domain, the board state fields, and the board view-model projection.
* The `#backlog-view` kanban: a header with target, count, and action; agent-declared columns in order; cards with id, title, and kind and tier chips.
* Loop routing so the board shows when the domain is `backlog` and hides otherwise.
* Tests for the reducers, the view-model projection, the MCP tools, and the client rendering and routing.

Deferred:

* Clickable cards that drill into an item, or that link out to the GitHub, ADO, or Jira item. The board reflects state for now; deep links come with the context-badge and launch work.
* Dragging a card between columns from the cockpit. Movement is agent-driven in this cut; user-initiated moves are a steering feature for later.
* Per-board autonomy-tier controls. The tier is shown as a card chip here; making it adjustable from the board is a later steering feature.
* A backlog demo in the standalone preview harness. This view is verified through tests and a synthetic render; a live demo path can come with the broader preview work.

## Non-goals

* The board does not orchestrate the backlog. It reflects what the agent narrates and never moves items itself.
* The board does not replace the issue tracker. It is a legibility surface over the agent's work, not a second source of truth for the backlog.
* No new agent capabilities. The backlog managers ship in HVE Core; the cockpit renders and steers them.
