import { describe, it, expect } from "vitest";
import { optionsToElicitSchema, elicitResultToChoice, presentOptionsWithElicitation } from "../src/elicit.js";
import { Bridge } from "../src/bridge.js";
import type { OptionItem } from "../src/events.js";
import type { ElicitResult } from "@modelcontextprotocol/sdk/types.js";

const OPTS: OptionItem[] = [
  { id: "a", title: "Minimal patch" },
  { id: "b", title: "Token middleware", recommended: true },
  { id: "c", title: "Full rewrite" },
];

describe("optionsToElicitSchema", () => {
  it("builds a form with the prompt as the message and a single required choice", () => {
    const f = optionsToElicitSchema("Which approach?", OPTS);
    expect(f.message).toBe("Which approach?");
    expect(f.requestedSchema.type).toBe("object");
    expect(f.requestedSchema.required).toEqual(["choice"]);
  });

  it("maps options to oneOf const/title pairs and defaults to the recommended option", () => {
    const choice = optionsToElicitSchema("p", OPTS).requestedSchema.properties.choice as {
      oneOf: { const: string; title: string }[];
      default: string;
    };
    expect(choice.oneOf).toEqual([
      { const: "a", title: "Minimal patch" },
      { const: "b", title: "Token middleware" },
      { const: "c", title: "Full rewrite" },
    ]);
    expect(choice.default).toBe("b");
  });

  it("defaults to the first option when none is recommended", () => {
    const choice = optionsToElicitSchema("p", [{ id: "x", title: "X" }, { id: "y", title: "Y" }])
      .requestedSchema.properties.choice as { default: string };
    expect(choice.default).toBe("x");
  });
});

describe("elicitResultToChoice", () => {
  it("returns the chosen id on accept with a valid choice", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "b" } }, OPTS)).toBe("b");
  });
  it("returns null when the choice is not a string", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: 42 } }, OPTS)).toBeNull();
  });
  it("returns null on decline", () => {
    expect(elicitResultToChoice({ action: "decline" }, OPTS)).toBeNull();
  });
  it("returns null on cancel", () => {
    expect(elicitResultToChoice({ action: "cancel" }, OPTS)).toBeNull();
  });
  it("returns null when the choice is not a known option id", () => {
    expect(elicitResultToChoice({ action: "accept", content: { choice: "zzz" } }, OPTS)).toBeNull();
  });
  it("returns null when content is missing", () => {
    expect(elicitResultToChoice({ action: "accept" }, OPTS)).toBeNull();
  });
});

function fakeServer(opts: {
  elicitation: boolean;
  respond?: (params: any, signal?: AbortSignal) => Promise<ElicitResult>;
}) {
  let elicitCalls = 0;
  return {
    elicitCalls: () => elicitCalls,
    getClientCapabilities: () => (opts.elicitation ? { elicitation: {} } : {}),
    elicitInput: (params: any, o?: { signal?: AbortSignal }) => {
      elicitCalls += 1;
      return (opts.respond ?? (() => new Promise<ElicitResult>(() => {})))(params, o?.signal);
    },
  };
}

describe("presentOptionsWithElicitation", () => {
  const OPTS = [
    { id: "a", title: "Minimal" },
    { id: "b", title: "Middleware", recommended: true },
    { id: "c", title: "Rewrite" },
  ];

  it("with no elicitation capability, resolves only via the pane card", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: false });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    // The pane card is shown; resolve it like the web decide frame would.
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "a");
    expect(await p).toBe("a");
    expect(srv.elicitCalls()).toBe(0);
  });

  it("when the elicitation accepts first, resolves with the elicited choice and clears the pane card", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "accept", content: { choice: "c" } }) });
    const choice = await presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    expect(choice).toBe("c");
    expect(bridge.state.pendingDecision).toBeNull();
  });

  it("when the pane card answers first, resolves with the web choice and aborts the elicitation", async () => {
    const bridge = new Bridge();
    let aborted = false;
    const srv = fakeServer({
      elicitation: true,
      respond: (_p, signal) =>
        new Promise<ElicitResult>((_res, rej) => {
          signal?.addEventListener("abort", () => { aborted = true; rej(new Error("aborted")); });
        }),
    });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "b");
    expect(await p).toBe("b");
    expect(aborted).toBe(true);
  });

  it("a declined elicitation does not resolve the decision; the pane card still can", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "decline" }) });
    const p = presentOptionsWithElicitation(srv, bridge, "Which?", OPTS, 0);
    await new Promise((r) => setTimeout(r, 10)); // let the declined elicitation settle
    expect(bridge.state.pendingDecision).not.toBeNull();
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "a");
    expect(await p).toBe("a");
  });
});
