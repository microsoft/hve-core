// src/elicit.ts
// The decision/question primitive's elicitation path. Pure mappers turn the
// cockpit's OptionItem list into an MCP elicitation form and turn the client's
// ElicitResult back into an option id. The orchestrator (Task 2) races the
// in-pane card against the native elicitation card.
import type { OptionItem } from "./events.js";
import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";
import type { Bridge } from "./bridge.js";

// A decision must not block the agent forever: fall back to the recommended
// option after a finite timeout. Configurable via env (default 30 min).
const DEFAULT_DECISION_TIMEOUT_MS = 1_800_000;
export function decisionTimeoutMs(): number {
  const raw = Number(process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_DECISION_TIMEOUT_MS;
}

export interface ElicitFormParams {
  message: string;
  requestedSchema: { type: "object"; properties: Record<string, unknown>; required?: string[] };
}

// Form mode with a single required string property whose oneOf carries the
// options as const/title pairs (the canonical SDK shape for a labelled choice),
// defaulting to the recommended option.
export function optionsToElicitSchema(prompt: string, options: OptionItem[]): ElicitFormParams {
  const fallback = options.find((o) => o.recommended) ?? options[0];
  if (!fallback) throw new Error("optionsToElicitSchema: options must not be empty");
  return {
    message: prompt,
    requestedSchema: {
      type: "object",
      properties: {
        choice: {
          type: "string",
          title: "Choose an option",
          oneOf: options.map((o) => ({ const: o.id, title: o.title })),
          default: fallback.id,
        },
      },
      required: ["choice"],
    },
  };
}

// Only an accepted result with a known option id counts as a choice. Decline,
// cancel, missing content, and unknown ids all return null (no decision).
export function elicitResultToChoice(result: ElicitResult, options: OptionItem[]): string | null {
  if (result.action !== "accept" || !result.content) return null;
  const choice = result.content.choice;
  if (typeof choice !== "string") return null;
  return options.some((o) => o.id === choice) ? choice : null;
}

// Minimal server surface the orchestrator needs; the real McpServer's underlying
// Server satisfies it (adapted in mcp.ts).
export interface ElicitCapableServer {
  getClientCapabilities(): { elicitation?: unknown } | undefined;
  elicitInput(params: ElicitFormParams, options?: { signal?: AbortSignal }): Promise<ElicitResult>;
}

// Show the in-pane card always (rung 2). If the host supports elicitation, also
// send a native card (rung 1) and race them: the first real answer wins and the
// loser is dismissed. A declined or cancelled elicitation is ignored so the pane
// card and the timeout fallback stay in control.
export async function presentOptionsWithElicitation(
  server: ElicitCapableServer,
  bridge: Bridge,
  prompt: string,
  options: OptionItem[],
  timeoutMs: number,
): Promise<string> {
  const webPromise = bridge.presentOptions(prompt, options, timeoutMs);
  const canElicit = server.getClientCapabilities()?.elicitation !== undefined;
  if (!canElicit) return webPromise;

  const decisionId = bridge.state.pendingDecision?.id ?? null;
  const ac = new AbortController();
  return await new Promise<string>((resolve) => {
    let settled = false;
    void webPromise.then((choice) => {
      if (settled) return;
      settled = true;
      ac.abort(); // dismiss the native card
      resolve(choice);
    });
    void server
      .elicitInput(optionsToElicitSchema(prompt, options), { signal: ac.signal })
      .then((result) => {
        if (settled) return;
        const choice = elicitResultToChoice(result, options);
        if (choice === null) return; // decline / cancel / invalid: let the pane card win
        settled = true;
        if (decisionId) bridge.resolveDecision(decisionId, choice); // clears the pane card and resolves webPromise
        resolve(choice);
      })
      .catch(() => { /* aborted or transport error: the pane card and timeout remain */ });
  });
}
