import { describe, it, expect } from "vitest";
import { optionsToElicitSchema, elicitResultToChoice, presentOptionsWithElicitation, questionToElicitSchema, elicitResultToAnswer, askQuestionWithElicitation, presentWorkflows, questionTimeoutMs } from "../src/elicit.js";
import { afterEach } from "vitest";
import { Bridge } from "../src/bridge.js";
import { WORKFLOWS } from "../src/catalog.js";
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

describe("question elicitation", () => {
  it("questionToElicitSchema builds a free-text answer field", () => {
    const f = questionToElicitSchema("Why?");
    expect(f.message).toBe("Why?");
    const ans = f.requestedSchema.properties.answer as { type: string };
    expect(ans.type).toBe("string");
    expect(f.requestedSchema.required).toEqual(["answer"]);
  });
  it("elicitResultToAnswer returns the string on accept, null otherwise", () => {
    expect(elicitResultToAnswer({ action: "accept", content: { answer: "yes" } })).toBe("yes");
    expect(elicitResultToAnswer({ action: "decline" })).toBeNull();
    expect(elicitResultToAnswer({ action: "accept", content: { answer: 4 } })).toBeNull();
  });
  it("askQuestionWithElicitation: pane answer wins and aborts the elicitation", async () => {
    const bridge = new Bridge();
    let aborted = false;
    const srv = fakeServer({ elicitation: true, respond: (_p, signal) => new Promise((_r, rej) => { signal?.addEventListener("abort", () => { aborted = true; rej(new Error("a")); }); }) });
    const p = askQuestionWithElicitation(srv, bridge, "Q?", 0);
    const id = bridge.state.pendingQuestion!.id;
    bridge.resolveQuestion(id, "typed");
    expect(await p).toBe("typed");
    expect(aborted).toBe(true);
  });
  it("askQuestionWithElicitation: elicitation answer wins and clears the pane", async () => {
    const bridge = new Bridge();
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "accept", content: { answer: "native" } }) });
    expect(await askQuestionWithElicitation(srv, bridge, "Q?", 0)).toBe("native");
    expect(bridge.state.pendingQuestion).toBeNull();
  });
});

describe("questionTimeoutMs", () => {
  const saved = process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS;
  afterEach(() => {
    if (saved === undefined) delete process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS;
    else process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS = saved;
  });
  it("defaults to 0 (no auto-resolve) so the interview blocks until answered", () => {
    delete process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS;
    expect(questionTimeoutMs()).toBe(0);
  });
  it("reads a positive override from the env", () => {
    process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS = "1234";
    expect(questionTimeoutMs()).toBe(1234);
  });
  it("ignores a non-positive or invalid override, falling back to 0", () => {
    process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS = "-5";
    expect(questionTimeoutMs()).toBe(0);
    process.env.RPI_COCKPIT_QUESTION_TIMEOUT_MS = "nope";
    expect(questionTimeoutMs()).toBe(0);
  });
});

describe("presentWorkflows", () => {
  it("returns the chosen workflow's intent when the host accepts a native choice", async () => {
    const srv = fakeServer({ elicitation: true, respond: async () => ({ action: "accept", content: { choice: "build" } }) });
    const build = WORKFLOWS.find((w) => w.id === "build")!;
    expect(await presentWorkflows(srv)).toBe(build.intent);
    expect(srv.elicitCalls()).toBe(1);
  });

  it("returns a chat instruction listing the workflow names when the host lacks elicitation", async () => {
    const srv = fakeServer({ elicitation: false });
    const out = await presentWorkflows(srv);
    expect(out).toContain("does not support inline choices");
    for (const w of WORKFLOWS) expect(out).toContain(w.name);
    expect(srv.elicitCalls()).toBe(0);
  });
});
