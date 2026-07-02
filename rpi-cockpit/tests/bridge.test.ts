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
    expect(b.state.decisions[0].options?.length).toBe(2);
    b.resolveDecision(b.state.decisions[0].id, "b");
    await expect(p).resolves.toBe("b");
    expect(b.state.decisions[0].status).toBe("answered");
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

  it("emits a directive event carrying the stamped directive", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("directive", seen);
    b.enqueueDirective({ kind: "note", text: "focus on errors" });
    expect(seen).toHaveBeenCalledOnce();
    const stamped = seen.mock.calls[0][0];
    expect(stamped).toMatchObject({ kind: "note", text: "focus on errors" });
    expect(stamped.id).toMatch(/^s\d+$/);
  });

  it("emits a decision event with {id, choiceId} when a pending decision resolves", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("decision", seen);
    const p = b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B" }]);
    const id = b.state.decisions[0].id;
    b.resolveDecision(id, "b");
    return p.then((choice) => {
      expect(choice).toBe("b");
      expect(seen).toHaveBeenCalledOnce();
      expect(seen.mock.calls[0][0]).toMatchObject({ id, choiceId: "b", prompt: "pick" });
    });
  });

  it("does not emit a decision event when resolving an unknown id", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("decision", seen);
    b.resolveDecision("does-not-exist", "b");
    expect(seen).not.toHaveBeenCalled();
  });

  describe("question primitive", () => {
    it("askQuestion appends a pending text decision and resolveQuestion answers it", async () => {
      const b = new Bridge();
      const p = b.askQuestion("What is the goal?", 0);
      expect(b.state.decisions[0].prompt).toBe("What is the goal?");
      const id = b.state.decisions[0].id;
      b.resolveQuestion(id, "ship it");
      expect(await p).toBe("ship it");
      expect(b.state.decisions[0].status).toBe("answered");
    });
    it("askQuestion times out to an empty answer", async () => {
      const b = new Bridge();
      expect(await b.askQuestion("q", 5)).toBe("");
    });
  });

  describe("navigator", () => {
    it("requestLaunch enqueues an approach directive and shows the loop", () => {
      const b = new Bridge();
      b.requestLaunch("build");
      expect(b.state.view).toBe("loop");
      expect(b.state.activeWorkflow).toBe("build");
      expect(b.state.directives).toHaveLength(1);
      expect(b.state.directives[0].kind).toBe("approach");
      expect(b.state.directives[0]).toMatchObject({ value: "build" });
    });

    it("requestLaunch ignores an unknown workflow id", () => {
      const b = new Bridge();
      b.requestLaunch("nope");
      expect(b.state.directives).toHaveLength(0);
      expect(b.state.view).toBe("home");
    });

    it("navigate sets the view", () => {
      const b = new Bridge();
      b.navigate("loop");
      expect(b.state.view).toBe("loop");
      b.navigate("home");
      expect(b.state.view).toBe("home");
    });

    it("openNavigator then closeNavigator toggles navigatorOpen and emits", () => {
      const b = new Bridge();
      const seen = vi.fn();
      b.on("state", seen);
      b.openNavigator();
      expect(b.state.navigatorOpen).toBe(true);
      b.closeNavigator();
      expect(b.state.navigatorOpen).toBe(false);
      expect(seen).toHaveBeenCalledTimes(2);
    });
  });

  describe("intervene", () => {
    it("enqueues a directive naming the action and agent for a pause", () => {
      const b = new Bridge();
      b.intervene("pause", "a1");
      expect(b.state.directives).toHaveLength(1);
      const d = b.state.directives[0];
      expect(d.kind).toBe("note");
      expect(d).toMatchObject({ kind: "note" });
      if (d.kind === "note") {
        expect(d.text).toContain("pause");
        expect(d.text).toContain("a1");
      }
    });
    it("enqueues a spawn directive with no agent id", () => {
      const b = new Bridge();
      b.intervene("spawn");
      expect(b.state.directives).toHaveLength(1);
      const d = b.state.directives[0];
      if (d.kind === "note") expect(d.text).toContain("spawn");
    });
  });

  it("logs a decision.timeout entry on the auto-resolve fallback", async () => {
    const b = new Bridge();
    await b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 5);
    const timeout = b.state.log.find((l) => l.kind === "decision.timeout");
    expect(timeout).toBeDefined();
    expect(timeout!.detail).toContain("b");
  });

  // ── New tests from task-2 brief ──────────────────────────────────────────

  it("presentOptions appends a pending choice decision and resolves to answered", async () => {
    const b = new Bridge();
    const p = b.presentOptions("Pick?", [{ id: "a", title: "A" }], 0, "d1");
    expect(b.state.decisions[0]).toMatchObject({ id: "d1", kind: "choice", status: "pending" });
    b.resolveDecision("d1", "a");
    await expect(p).resolves.toBe("a");
    expect(b.state.decisions[0]).toMatchObject({ status: "answered", answer: "a" });
  });

  it("askQuestion appends a pending text decision and resolves to answered", async () => {
    const b = new Bridge();
    const p = b.askQuestion("Name?", 0, "q1");
    b.resolveQuestion("q1", "Ada");
    await expect(p).resolves.toBe("Ada");
    expect(b.state.decisions[0]).toMatchObject({ kind: "text", status: "answered", answer: "Ada" });
  });

  it("revise re-opens a decision, supersedes downstream, and enqueues a directive", async () => {
    const b = new Bridge();
    b.resolveDecision("d1", "a"); // no-op guard
    const p1 = b.presentOptions("One?", [{ id: "a", title: "A" }], 0, "d1"); b.resolveDecision("d1", "a"); await p1;
    const p2 = b.askQuestion("Two?", 0, "q2"); b.resolveQuestion("q2", "x"); await p2;
    b.revise("d1");
    expect(b.state.decisions.map((d) => d.status)).toEqual(["pending", "superseded"]);
    expect(b.state.directives.at(-1)?.kind).toBe("note");
    expect((b.state.directives.at(-1) as { text: string }).text).toContain("revise");
  });

  it("presentOptions auto-resolves to the recommended option on timeout", async () => {
    const b = new Bridge();
    const p = b.presentOptions("Pick?", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 20, "d1");
    await expect(p).resolves.toBe("b");
  });

  it("setHostElicits sets the flag", () => {
    const b = new Bridge(); b.setHostElicits(true); expect(b.state.hostElicits).toBe(true);
  });
});
