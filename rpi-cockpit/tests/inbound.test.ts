// rpi-cockpit/tests/inbound.test.ts
import { describe, it, expect } from "vitest";
import { Bridge } from "../src/bridge.js";
import { parseInbound, applyInbound } from "../src/inbound.js";

describe("parseInbound", () => {
  it("accepts a decide frame", () => {
    expect(parseInbound({ type: "decide", id: "d1", choiceId: "a" }))
      .toEqual({ type: "decide", id: "d1", choiceId: "a" });
  });

  it("accepts a steer frame", () => {
    const f = parseInbound({ type: "steer", directive: { kind: "note", text: "hello" } });
    expect(f).toEqual({ type: "steer", directive: { kind: "note", text: "hello" } });
  });

  it("accepts a launch frame", () => {
    expect(parseInbound({ type: "launch", workflowId: "build" }))
      .toEqual({ type: "launch", workflowId: "build" });
  });

  it("accepts a navigate frame", () => {
    expect(parseInbound({ type: "navigate", screen: "home" }))
      .toEqual({ type: "navigate", screen: "home" });
    expect(parseInbound({ type: "navigate", screen: "loop" }))
      .toEqual({ type: "navigate", screen: "loop" });
  });

  it("accepts an answer frame", () => {
    expect(parseInbound({ type: "answer", id: "q1", text: "yes" }))
      .toEqual({ type: "answer", id: "q1", text: "yes" });
  });

  it("accepts a navigator frame", () => {
    expect(parseInbound({ type: "navigator", open: true }))
      .toEqual({ type: "navigator", open: true });
    expect(parseInbound({ type: "navigator", open: false }))
      .toEqual({ type: "navigator", open: false });
  });

  it("accepts an intervene frame with and without agentId", () => {
    expect(parseInbound({ type: "intervene", action: "pause", agentId: "a1" }))
      .toEqual({ type: "intervene", action: "pause", agentId: "a1" });
    expect(parseInbound({ type: "intervene", action: "spawn" }))
      .toEqual({ type: "intervene", action: "spawn" });
  });

  it("rejects malformed frames -> null", () => {
    // wrong/missing types
    expect(parseInbound(null)).toBeNull();
    expect(parseInbound("string")).toBeNull();
    expect(parseInbound(42)).toBeNull();
    expect(parseInbound({})).toBeNull();
    expect(parseInbound({ type: "unknown" })).toBeNull();
    // missing fields
    expect(parseInbound({ type: "decide", id: "d1" })).toBeNull();
    expect(parseInbound({ type: "decide", choiceId: "a" })).toBeNull();
    expect(parseInbound({ type: "answer", id: "q1" })).toBeNull();
    expect(parseInbound({ type: "launch" })).toBeNull();
    // wrong types
    expect(parseInbound({ type: "decide", id: 1, choiceId: "a" })).toBeNull();
    expect(parseInbound({ type: "navigator", open: "yes" })).toBeNull();
    expect(parseInbound({ type: "navigate", screen: "elsewhere" })).toBeNull();
    expect(parseInbound({ type: "intervene", action: "delete" })).toBeNull();
    expect(parseInbound({ type: "intervene", action: "pause", agentId: 5 })).toBeNull();
    // bad steer directive
    expect(parseInbound({ type: "steer", directive: { kind: "note", text: "" } })).toBeNull();
    expect(parseInbound({ type: "steer", directive: { kind: "bogus" } })).toBeNull();
  });
});

describe("applyInbound", () => {
  it("steer grows the bridge's directives", () => {
    const bridge = new Bridge();
    applyInbound(bridge, parseInbound({ type: "steer", directive: { kind: "note", text: "focus" } })!);
    expect(bridge.state.directives).toHaveLength(1);
    expect(bridge.state.directives[0]).toMatchObject({ kind: "note", text: "focus" });
  });

  it("navigator {open:true} sets navigatorOpen", () => {
    const bridge = new Bridge();
    applyInbound(bridge, parseInbound({ type: "navigator", open: true })!);
    expect(bridge.state.navigatorOpen).toBe(true);
    applyInbound(bridge, parseInbound({ type: "navigator", open: false })!);
    expect(bridge.state.navigatorOpen).toBe(false);
  });

  it("navigate sets the view", () => {
    const bridge = new Bridge();
    applyInbound(bridge, parseInbound({ type: "navigate", screen: "loop" })!);
    expect(bridge.state.view).toBe("loop");
    applyInbound(bridge, parseInbound({ type: "navigate", screen: "home" })!);
    expect(bridge.state.view).toBe("home");
  });

  it("launch flips the view to loop and sets the active workflow", () => {
    const bridge = new Bridge();
    applyInbound(bridge, parseInbound({ type: "launch", workflowId: "build" })!);
    expect(bridge.state.view).toBe("loop");
    expect(bridge.state.activeWorkflow).toBe("build");
  });

  it("intervene enqueues a note directive mentioning the action", () => {
    const bridge = new Bridge();
    applyInbound(bridge, parseInbound({ type: "intervene", action: "pause", agentId: "a1" })!);
    expect(bridge.state.directives).toHaveLength(1);
    const d = bridge.state.directives[0];
    expect(d.kind).toBe("note");
    if (d.kind === "note") {
      expect(d.text).toContain("pause");
      expect(d.text).toContain("a1");
    }
  });

  it("parseInbound accepts a valid revise frame", () => {
    expect(parseInbound({ type: "revise", id: "d1" })).toEqual({ type: "revise", id: "d1" });
  });
  it("parseInbound rejects a revise frame without a string id", () => {
    expect(parseInbound({ type: "revise" })).toBeNull();
    expect(parseInbound({ type: "revise", id: 3 })).toBeNull();
  });
  it("applyInbound revise calls bridge.revise", () => {
    const b = new Bridge();
    const p = b.presentOptions("x", [{ id: "a", title: "A" }], 0, "d1"); b.resolveDecision("d1", "a"); void p;
    applyInbound(b, { type: "revise", id: "d1" });
    expect(b.state.decisions[0].status).toBe("pending");
  });

  it("parseInbound accepts an open frame with and without a line", () => {
    expect(parseInbound({ type: "open", file: "a.ts", line: 4 })).toEqual({ type: "open", file: "a.ts", line: 4 });
    expect(parseInbound({ type: "open", file: "a.ts" })).toEqual({ type: "open", file: "a.ts" });
  });
  it("parseInbound rejects an open frame with a bad file or line", () => {
    expect(parseInbound({ type: "open" })).toBeNull();
    expect(parseInbound({ type: "open", file: 3 })).toBeNull();
    expect(parseInbound({ type: "open", file: "a.ts", line: "4" })).toBeNull();
  });
  it("applyInbound open enqueues an editor directive", () => {
    const b = new Bridge();
    applyInbound(b, { type: "open", file: "src/x.ts", line: 9 });
    expect(b.state.directives.at(-1)).toMatchObject({ kind: "note" });
    expect((b.state.directives.at(-1) as { text: string }).text).toContain("src/x.ts:9");
  });
});
