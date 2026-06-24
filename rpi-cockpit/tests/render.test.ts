// rpi-cockpit/tests/render.test.ts
import { describe, it, expect } from "vitest";
import { toViewModel } from "../src/render.js";
import { initialState, applyBeat, enqueueDirective } from "../src/state.js";

describe("toViewModel", () => {
  it("marks the current phase active and prior phases done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "implement" }, 2);
    const vm = toViewModel(s);
    expect(vm.steps.find((x) => x.phase === "research")!.status).toBe("done");
    expect(vm.steps.find((x) => x.phase === "implement")!.status).toBe("active");
    expect(vm.steps.find((x) => x.phase === "review")!.status).toBe("pending");
  });
  it("exposes the pending decision", () => {
    const s = { ...initialState(), pendingDecision: { id: "d1", prompt: "pick", options: [{ id: "a", title: "A" }] } };
    expect(toViewModel(s).decision?.id).toBe("d1");
  });
  it("exposes validations as check/status pairs", () => {
    const s = applyBeat(initialState(), { type: "validate", check: "tests", status: "fail" }, 1);
    expect(toViewModel(s).validations).toContainEqual({ check: "tests", status: "fail" });
  });

  it("is not started and shows the waiting lead before a session begins", () => {
    const vm = toViewModel(initialState());
    expect(vm.started).toBe(false);
    expect(vm.phaseNumber).toBeNull();
    expect(vm.lead).toMatch(/Waiting for an RPI session/);
  });

  it("derives phase label, number, and lead from the active phase", () => {
    const s = applyBeat(initialState(), { type: "phase.enter", phase: "implement" }, 1);
    const vm = toViewModel(s);
    expect(vm.started).toBe(true);
    expect(vm.phaseLabel).toBe("Implement");
    expect(vm.phaseNumber).toBe(3);
    expect(vm.lead).toMatch(/Executing the plan/);
  });

  it("falls back to preset steer options when the agent has not offered a menu", () => {
    const vm = toViewModel(initialState());
    expect(vm.steerMenu.source).toBe("preset");
    expect(vm.steerMenu.options.map((o) => o.id)).toEqual(["default", "thorough", "faster", "ask-first"]);
  });

  it("uses the agent-declared menu when offered", () => {
    const s = applyBeat(initialState(), { type: "approaches.offer", label: "Implementor", options: [{ id: "x", title: "X" }] }, 1);
    const vm = toViewModel(s);
    expect(vm.steerMenu.source).toBe("agent");
    expect(vm.steerMenu.options).toEqual([{ id: "x", title: "X", detail: undefined }]);
  });

  it("exposes queued directives", () => {
    const s = enqueueDirective(initialState(), { id: "s1", kind: "note", text: "focus" }, 1);
    expect(toViewModel(s).directives).toHaveLength(1);
  });
});
