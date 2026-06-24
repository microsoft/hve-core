// rpi-cockpit/tests/bridge.test.ts
import { describe, it, expect, vi } from "vitest";
import { Bridge } from "../src/bridge.js";

describe("Bridge", () => {
  it("emits state on a beat", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("state", seen);
    b.emitBeat({ type: "phase.enter", phase: "plan" });
    expect(b.state.phase).toBe("plan");
    expect(seen).toHaveBeenCalledOnce();
  });
  it("blocks presentOptions until resolveDecision is called", async () => {
    const b = new Bridge();
    const p = b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B" }]);
    expect(b.state.pendingDecision?.options.length).toBe(2);
    b.resolveDecision(b.state.pendingDecision!.id, "b");
    await expect(p).resolves.toBe("b");
    expect(b.state.pendingDecision).toBeNull();
  });
  it("falls back to the recommended option on timeout", async () => {
    const b = new Bridge();
    const choice = await b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 5);
    expect(choice).toBe("b");
  });

  it("stamps an id, queues a directive, and emits state", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("state", seen);
    b.enqueueDirective({ kind: "note", text: "focus on errors" });
    expect(b.state.directives).toHaveLength(1);
    expect(b.state.directives[0].id).toMatch(/^s\d+$/);
    expect(seen).toHaveBeenCalledOnce();
  });

  it("drains queued directives and clears them", () => {
    const b = new Bridge();
    b.enqueueDirective({ kind: "approach", value: "faster", label: "Move faster" });
    const drained = b.drainDirectives();
    expect(drained).toHaveLength(1);
    expect(b.state.directives).toHaveLength(0);
    expect(b.drainDirectives()).toHaveLength(0); // idempotent when empty
  });

  it("offerApproaches sets the steer menu", () => {
    const b = new Bridge();
    b.offerApproaches("Pick", [{ id: "a", title: "A" }]);
    expect(b.state.steerMenu).toMatchObject({ label: "Pick" });
  });
});
