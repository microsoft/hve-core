// rpi-cockpit/tests/state.test.ts
import { describe, it, expect } from "vitest";
import { initialState, applyBeat, enqueueDirective, drainDirectives } from "../src/state.js";

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

it("offers a steer menu and clears it on the next phase", () => {
  let s = applyBeat(initialState(), { type: "approaches.offer", label: "Pick", options: [{ id: "a", title: "A" }] }, 1);
  expect(s.steerMenu).toMatchObject({ label: "Pick" });
  s = applyBeat(s, { type: "phase.enter", phase: "review" }, 2);
  expect(s.steerMenu).toBeNull();
});

it("queues a directive and logs it", () => {
  const s = enqueueDirective(initialState(), { id: "s1", kind: "note", text: "focus on errors" }, 7);
  expect(s.directives).toHaveLength(1);
  expect(s.log.at(-1)).toMatchObject({ kind: "directive.queued" });
});

it("drains directives, clearing the queue and logging each", () => {
  const queued = enqueueDirective(initialState(), { id: "s1", kind: "approach", value: "faster", label: "Move faster" }, 7);
  const { state, drained } = drainDirectives(queued, 8);
  expect(drained).toHaveLength(1);
  expect(state.directives).toHaveLength(0);
  expect(state.log.at(-1)).toMatchObject({ kind: "directive.consumed" });
});

it("drains to empty when there is nothing queued", () => {
  const { state, drained } = drainDirectives(initialState(), 8);
  expect(drained).toHaveLength(0);
  expect(state.log).toHaveLength(0);
});
