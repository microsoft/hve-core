// rpi-cockpit/tests/handlers.test.ts
import { describe, it, expect } from "vitest";
import { Bridge } from "../src/bridge.js";
import { handlers } from "../src/handlers.js";

describe("handlers", () => {
  it("phase_enter advances the bridge", async () => {
    const b = new Bridge();
    const out = await handlers.phase_enter(b, { phase: "implement" });
    expect(b.state.phase).toBe("implement");
    expect(out).toContain("implement");
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

  it("show_screen sets the screen on the bridge and clear_screen removes it", () => {
    const b = new Bridge();
    const out = handlers.show_screen(b, { html: "<p>hi</p>", title: "Mockup" });
    expect(b.state.screen).toEqual({ html: "<p>hi</p>", title: "Mockup" });
    expect(typeof out).toBe("string");
    handlers.clear_screen(b);
    expect(b.state.screen).toBeNull();
  });
});
