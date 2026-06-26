// rpi-cockpit/tests/state.test.ts
import { describe, it, expect } from "vitest";
import { initialState, applyBeat, enqueueDirective, drainDirectives, setView, startLaunch } from "../src/state.js";

describe("applyBeat", () => {
  it("sets task and host on session.begin", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "refactor auth", host: "claude-code" }, 1);
    expect(s.task).toBe("refactor auth");
    expect(s.host).toBe("claude-code");
  });

  describe("navigation", () => {
    it("defaults the view to home", () => {
      expect(initialState().view).toBe("home");
      expect(initialState().activeWorkflow).toBeNull();
    });

    it("session.begin switches the view to loop", () => {
      const s = applyBeat(initialState(), { type: "session.begin", task: "x", host: "claude-code" }, 1);
      expect(s.view).toBe("loop");
    });

    it("setView returns a state with the requested view", () => {
      expect(setView(initialState(), "loop").view).toBe("loop");
      const back = setView(setView(initialState(), "loop"), "home");
      expect(back.view).toBe("home");
    });

    it("startLaunch sets the active workflow and shows the loop", () => {
      const s = startLaunch(initialState(), "build");
      expect(s.activeWorkflow).toBe("build");
      expect(s.view).toBe("loop");
    });
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

it("sets the screen on screen.show and clears it on screen.clear", () => {
  let s = applyBeat(initialState(), { type: "screen.show", html: "<p>hi</p>", title: "Mockup" }, 1);
  expect(s.screen).toEqual({ html: "<p>hi</p>", title: "Mockup" });
  s = applyBeat(s, { type: "screen.clear" }, 2);
  expect(s.screen).toBeNull();
});

it("leaves the screen untouched on unrelated beats", () => {
  let s = applyBeat(initialState(), { type: "screen.show", html: "<p>hi</p>" }, 1);
  s = applyBeat(s, { type: "validate", check: "lint", status: "ok" }, 2);
  expect(s.screen).toEqual({ html: "<p>hi</p>", title: undefined });
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

describe("review domain", () => {
  it("defaults domain to null with no findings", () => {
    expect(initialState().domain).toBeNull();
    expect(initialState().findings).toEqual([]);
    expect(initialState().reviewTarget).toBeNull();
  });
  it("session.begin sets the rpi domain", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    expect(s.domain).toBe("rpi");
  });
  it("review.start sets the review domain, target, and resets findings", () => {
    let s = applyBeat(initialState(), { type: "finding.add", severity: "low", title: "old" }, 1);
    s = applyBeat(s, { type: "review.start", target: "PR 7" }, 2);
    expect(s.domain).toBe("review");
    expect(s.reviewTarget).toBe("PR 7");
    expect(s.findings).toEqual([]);
  });
  it("finding.add appends a finding", () => {
    let s = applyBeat(initialState(), { type: "review.start", target: "x" }, 1);
    s = applyBeat(s, { type: "finding.add", severity: "high", title: "bug", file: "a.ts", line: 3 }, 2);
    expect(s.findings).toEqual([{ severity: "high", title: "bug", file: "a.ts", line: 3, detail: undefined }]);
  });
});
