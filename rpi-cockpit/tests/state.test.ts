// rpi-cockpit/tests/state.test.ts
import { describe, it, expect } from "vitest";
import { initialState, applyBeat } from "../src/state.js";

describe("applyBeat", () => {
  it("sets task and host on session.begin", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "refactor auth", host: "claude-code" }, 1);
    expect(s.task).toBe("refactor auth");
    expect(s.host).toBe("claude-code");
  });
  it("advances phase and records the previous as done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "plan" }, 2);
    expect(s.phase).toBe("plan");
    expect(s.phasesDone).toEqual(["research"]);
  });
  it("tracks subagent lifecycle", () => {
    let s = applyBeat(initialState(), { type: "subagent.start", name: "Phase Implementor", role: "impl" }, 1);
    expect(s.subagents[0]).toMatchObject({ name: "Phase Implementor", status: "active" });
    s = applyBeat(s, { type: "subagent.stop", name: "Phase Implementor", result: "done" }, 2);
    expect(s.subagents[0]).toMatchObject({ status: "idle", result: "done" });
  });
  it("records validations and artifacts and appends to the log", () => {
    let s = applyBeat(initialState(), { type: "validate", check: "lint", status: "ok" }, 1);
    s = applyBeat(s, { type: "artifact.update", path: "plan.md", summary: "+10" }, 2);
    expect(s.validations.lint).toBe("ok");
    expect(s.artifacts).toEqual([{ path: "plan.md", summary: "+10" }]);
    expect(s.log.length).toBe(2);
  });
});
