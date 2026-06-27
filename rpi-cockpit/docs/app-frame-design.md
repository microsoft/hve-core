<!-- markdownlint-disable MD013 -->
# App frame primitive design

## Purpose

The app frame is the seventh and last representation-map primitive. It embeds the user's app under development, its live localhost preview, in a trusted iframe beside the cockpit. Where the screen pane is the untrusted, sandboxed surface for arbitrary agent-authored HTML, the app frame is its trusted sibling: it shows the real running app so the user can watch their product change as the agent works on it, without leaving the cockpit pane.

This spec covers the app-frame primitive: the beat that sets the framed URL, the state and view-model it adds, where it renders, and, most importantly, the trust model that keeps a trusted iframe safe. It builds on the archetype-to-primitive mapping in [docs/representation-map.md](representation-map.md), which calls the app frame "different in kind: it embeds the user's own app under development (a trusted localhost iframe) beside the cockpit."

## What it represents

The representation map describes the app frame as a trusted localhost iframe of the app under development, beside the untrusted sandboxed screen. It is cross-cutting: you would want to see your app whether the agent is in an RPI build, a review, or a backlog session, so the frame sits beside whichever loop view is showing rather than inside any one of them.

| Concept | In the cockpit |
| --- | --- |
| The app under development | A trusted iframe loading its localhost preview URL |
| Which URL | Supplied by the agent through a tool, and shown in the panel header |
| Presence | A side panel beside the loop content, shown only when a URL is set |

## The trust model

This is the security heart of the primitive, and the reason it gets its own careful design. The screen pane uses `sandbox=""` (no scripts, opaque origin) because it renders arbitrary agent HTML. The app frame is the opposite: it must run the real app, with scripts and the app's own origin, or it is useless. That trust is bounded by three rules.

| Rule | Why |
| --- | --- |
| Loopback URLs only | The framed URL must be `http:` or `https:` with a hostname of `localhost`, `127.0.0.1`, or `[::1]`. A non-loopback URL is rejected at the tool boundary and never reaches the iframe. This stops the agent (or a prompt injection reaching the agent) from embedding an arbitrary external page inside the cockpit, which would be a phishing and exfiltration vector. |
| A bounded sandbox | The iframe uses `sandbox="allow-scripts allow-same-origin allow-forms"`: enough for a real app to run, but no top-level navigation (it cannot navigate the cockpit away), no popups, no pointer-lock. |
| Cross-origin isolation | The app runs on its own port, a different origin from the cockpit. So `allow-same-origin` grants the iframe the app's origin, never the cockpit's: the framed app cannot read the cockpit DOM, and the cockpit's WebSocket token cookie (`HttpOnly`, `SameSite=Strict`, scoped to the cockpit origin) is unreachable from it. |

The loopback check is enforced at the MCP tool boundary, so a bad URL returns an error to the agent and never updates state, and the client repeats the check before assigning the iframe source as defense in depth. The check is a single shared predicate so the server and client agree on exactly what counts as loopback.

## Protocol additions

One beat and one tool, in the declarative style the other primitives use.

| Beat | Fields | Effect |
| --- | --- | --- |
| `appframe.set` | `url` (nullable) | Sets the framed URL, or clears the frame when null |

The MCP tool `set_app_frame` wraps the beat. It validates the URL: a non-null URL that is not a loopback `http(s)` URL is rejected with an explanatory message and no beat is emitted; a null clears the frame. Like the other ambient primitives, `appframe.set` does not change the domain or the view; the panel appears beside wherever the user already is.

## State and view-model

Session state gains a single `appFrameUrl: string | null` field. The reducer for `appframe.set` sets it. The view-model projects `appFrame: { url: string | null }`. The client decides visibility (the panel shows only when the URL is non-null), so the view-model stays a plain projection.

## Rendering

The client adds an `#app-frame` side panel as a flex sibling of the loop content inside `.main`, so the cockpit content and the app sit side by side. The panel has a small header showing the framed URL and a trusted iframe filling the rest. A `renderAppFrame` function runs on every update, before the domain routing, because the panel is cross-cutting chrome rather than loop content: it shows the iframe when a URL is set (and passes the loopback check) and hides the panel otherwise. The iframe carries the bounded `sandbox` described above. On narrow widths the panel stacks below the loop content rather than beside it, consistent with the responsive layout of the rest of the cockpit.

## Scope

In scope:

* The `appframe.set` beat and the `set_app_frame` MCP tool, with loopback-only validation enforced at the tool boundary.
* The `appFrameUrl` state field, the reducer, and the view-model projection.
* The shared `isLoopbackHttpUrl` predicate used by both the server tool and the client guard.
* The `#app-frame` side panel with the bounded `sandbox`, shown beside the loop content when a URL is set and stacked on narrow screens.
* Tests for the reducer, the view-model, the tool (accepting loopback, clearing on null, and rejecting non-loopback / non-http URLs), and the client rendering and visibility.

Deferred:

* A resize handle to drag the split between the cockpit and the app. Fixed proportion for now.
* Reload, device-frame, and responsive-preview controls on the app panel. The frame shows the app as-is for now.
* Letting the user, rather than the agent, set the framed URL from the cockpit. The agent supplies it in this cut.
* Auto-discovering the dev server URL (for example from the preview launcher's port). The agent passes the URL explicitly.

## Non-goals

* The app frame does not run or manage the dev server. It only displays a URL the agent supplies; the user owns the server.
* The app frame is not a general web view. The loopback restriction is deliberate and is not a setting to relax casually; embedding arbitrary external sites in the cockpit is out of scope.
* No new agent capabilities. The app is the user's; the cockpit only frames its local preview.
