<!-- markdownlint-disable MD013 -->
# HVE Cockpit elicitation decision primitive design

## Purpose

The decision and question primitive should render as each host's native choice card (rung 1 of the rendering ladder) in addition to the in-pane cockpit decision card (rung 2), so a single decision is answerable both natively inline in the host chat and in the cockpit pane, portably across Claude Code, VS Code, and Codex. This realizes the deferred item from [navigator-design.md](navigator-design.md): the decision and question primitive is an MCP elicitation. It changes how `present_options` surfaces a choice; it does not change the agent's role (the agent still calls a blocking tool and acts on the result).

## The approved model: both surfaces, first answer wins

When the agent calls `present_options(prompt, options)`:

1. The in-pane web decision card is shown, exactly as today (rung 2).
2. If the connected host declares the `elicitation` capability, a native elicitation (an `elicitation/create` form with an enum of the options) is also sent to the host (rung 1, the native inline choice card).
3. Whichever surface the user answers first resolves the decision; the other is dismissed:
   * Web card answered first: cancel the in-flight elicitation so the host card disappears.
   * Elicitation answered first: resolve the pane decision so the pane card clears.
4. Fallback: a host without the `elicitation` capability gets the pane card only, which is exactly today's behavior (no regression). The existing finite timeout fallback to the recommended option still applies and dismisses both surfaces.

A declined or cancelled elicitation does not resolve the decision: the pane card and the timeout remain in play, so dismissing the native card never forces a choice.

## Mechanism, grounded in the installed SDK

The installed `@modelcontextprotocol/sdk` exposes, on the `McpServer`'s underlying `Server` (reachable as `server.server`):

* `getClientCapabilities(): ClientCapabilities | undefined` for the capability gate (`getClientCapabilities()?.elicitation`).
* `elicitInput(params, { signal }): Promise<ElicitResult>` to send the native card and await the answer, with an `AbortSignal` for cancellation.
* An `elicitation/complete` notification helper to dismiss an outstanding card.

Design points:

| Concern | Approach |
|---|---|
| Capability gate | Call `elicitInput` only when `server.server.getClientCapabilities()?.elicitation` is present; otherwise the pane card is the only surface. |
| Schema | Form mode. `message` is the prompt. `requestedSchema` is an object with one required string property (`choice`) whose `enum` is the option ids and whose titles carry the option titles. The recommended option is named in the message. |
| Result mapping | On an accept action, map the returned `choice` value back to the option id. Decline and cancel actions do not resolve the decision. |
| Race and cancel | `present_options` races the web-decide promise (`bridge.presentOptions`) against the `elicitInput` promise. The loser is cancelled: abort `elicitInput` (its `AbortSignal`, plus the `elicitation/complete` notification if needed) when the web card wins; call `bridge.resolveDecision` when the elicitation wins. |
| Wiring | The `present_options` path needs the server's `elicitInput`. Thread a single `sendElicitation` capability into the `present_options` registration as a closure over `server` in `buildMcpServer`, keeping the other handlers pure. |

## Scope

In scope for v1:

* `present_options` drives both surfaces with first-answer-wins, the capability fallback, and cancel-the-loser, on the installed SDK.
* The existing decision timeout fallback to the recommended option is preserved and dismisses both surfaces.
* Secure defaults unchanged: the pane card UX, the token gate, and the iframe sandbox are untouched.
* Tests: capability present (both fired; web wins cancels the elicitation; elicitation wins clears the pane); capability absent (pane only, `elicitInput` not called); a declined or cancelled elicitation does not resolve the decision.

Deferred to later plans:

* A free-form question variant of the primitive (text answer, not a bounded option set).
* `offer_approaches` (the non-blocking steer menu) staying web-only for now.
* URL-mode elicitation (for secrets or OAuth), which the cockpit does not need.

## Non-goals

* No change to the in-pane decision card look or behavior.
* No secrets through elicitation: options are not sensitive, and form mode is for non-sensitive input only.
* The cockpit does not start or drive the agent; `present_options` remains a blocking tool the agent chooses to call.

## To confirm during the build

* The exact `ElicitResult` shape (the action values and how the accepted content is keyed by the schema property), mapped back to the option id, verified against the installed type definitions.
* Whether aborting `elicitInput` alone dismisses the host card or whether the `elicitation/complete` notification is required. The tests will use a mock client that declares the elicitation capability and answers (or declines) an `elicitation/create` request.
