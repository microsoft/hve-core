// rpi-cockpit/tests/handlers.test.ts
import { describe, it, expect, afterEach } from "vitest";
import { Bridge } from "../src/bridge.js";
import { handlers } from "../src/handlers.js";

describe("handlers", () => {
  afterEach(() => {
    delete process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS;
  });
  it("phase_enter advances the bridge", async () => {
    const b = new Bridge();
    const out = await handlers.phase_enter(b, { phase: "implement" });
    expect(b.state.phase).toBe("implement");
    expect(out).toContain("implement");
  });
  it("present_options resolves to the user's choice", async () => {
    const b = new Bridge();
    const p = handlers.present_options(b, { prompt: "pick", options: [{ id: "a", title: "A" }, { id: "b", title: "B" }] });
    b.resolveDecision(b.state.pendingDecision!.id, "a");
    expect(await p).toBe("a");
  });
  it("present_options falls back to the recommended option after a finite timeout", async () => {
    process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS = "5";
    const b = new Bridge();
    // No resolveDecision call: the env-derived finite timeout must unblock the agent.
    const choice = await handlers.present_options(b, {
      prompt: "pick",
      options: [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }],
    });
    expect(choice).toBe("b");
    expect(b.state.pendingDecision).toBeNull();
  });

  it("offer_approaches populates the steer menu", () => {
    const b = new Bridge();
    const out = handlers.offer_approaches(b, { label: "Pick", options: [{ id: "a", title: "A" }] });
    expect(b.state.steerMenu).toMatchObject({ label: "Pick" });
    expect(out).toContain("1");
  });

  it("check_directives returns queued directives then drains", () => {
    const b = new Bridge();
    expect(handlers.check_directives(b)).toBe("no pending directives");
    b.enqueueDirective({ kind: "note", text: "focus on errors" });
    expect(handlers.check_directives(b)).toBe("note: focus on errors");
    expect(handlers.check_directives(b)).toBe("no pending directives");
  });
});
