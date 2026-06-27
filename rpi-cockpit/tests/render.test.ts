// rpi-cockpit/tests/render.test.ts
import { describe, it, expect } from "vitest";
import { toViewModel } from "../src/render.js";
import { initialState, applyBeat, enqueueDirective, startLaunch } from "../src/state.js";

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

  it("is started for a directly-launched domain with no session.begin", () => {
    // review/interview/backlog set domain without task/phase; started must be true
    // so the Home orient strip does not claim "Nothing running" mid-session. (B1)
    for (const beat of [
      { type: "review.start", target: "x" },
      { type: "interview.start", docType: "PRD" },
      { type: "backlog.start", target: "S", columns: ["Todo"] },
    ] as const) {
      const s = applyBeat(initialState(), beat, 1);
      expect(toViewModel(s).started).toBe(true);
    }
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

  it("surfaces the agent screen, defaulting to null", () => {
    expect(toViewModel(initialState()).screen).toBeNull();
    const s = applyBeat(initialState(), { type: "screen.show", html: "<p>hi</p>", title: "Mockup" }, 1);
    expect(toViewModel(s).screen).toEqual({ html: "<p>hi</p>", title: "Mockup" });
  });

  it("exposes docType and pendingQuestion", () => {
    const s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
    const vm = toViewModel(s);
    expect(vm.domain).toBe("interview");
    expect(vm.docType).toBe("ADR");
    expect(vm.pendingQuestion).toBeNull();
  });

  describe("findings view-model", () => {
    it("exposes the domain and review target", () => {
      let s = applyBeat(initialState(), { type: "review.start", target: "PR 9" }, 1);
      const vm = toViewModel(s);
      expect(vm.domain).toBe("review");
      expect(vm.reviewTarget).toBe("PR 9");
    });
    it("groups findings by severity in critical-first order, only non-empty groups", () => {
      let s = applyBeat(initialState(), { type: "review.start", target: "x" }, 1);
      s = applyBeat(s, { type: "finding.add", severity: "low", title: "L" }, 2);
      s = applyBeat(s, { type: "finding.add", severity: "critical", title: "C" }, 3);
      s = applyBeat(s, { type: "finding.add", severity: "low", title: "L2" }, 4);
      const groups = toViewModel(s).findingGroups;
      expect(groups.map((g) => g.severity)).toEqual(["critical", "low"]);
      expect(groups[0].items.map((i) => i.title)).toEqual(["C"]);
      expect(groups[1].items.map((i) => i.title)).toEqual(["L", "L2"]);
    });
  });

  describe("board view-model", () => {
    it("returns columns in declared order, keeps empty columns, groups items, with count and passthrough", () => {
      let s = applyBeat(initialState(), { type: "backlog.start", target: "Sprint 4", columns: ["Todo", "Doing", "Done"] }, 1);
      s = applyBeat(s, { type: "item.add", id: "I1", title: "a", column: "Todo", kind: "bug", tier: "T1" }, 2);
      s = applyBeat(s, { type: "item.add", id: "I2", title: "b", column: "Done" }, 3);
      s = applyBeat(s, { type: "item.add", id: "I3", title: "c", column: "Todo" }, 4);
      s = applyBeat(s, { type: "backlog.action", text: "triaging" }, 5);
      const { board } = toViewModel(s);
      expect(board.target).toBe("Sprint 4");
      expect(board.action).toBe("triaging");
      expect(board.count).toBe(3);
      expect(board.columns.map((c) => c.name)).toEqual(["Todo", "Doing", "Done"]);
      expect(board.columns[1].items).toEqual([]);
      expect(board.columns[0].items.map((i) => i.id)).toEqual(["I1", "I3"]);
      expect(board.columns[0].items[0]).toEqual({ id: "I1", title: "a", kind: "bug", tier: "T1" });
      expect(board.columns[2].items.map((i) => i.id)).toEqual(["I2"]);
    });
  });

  describe("context view-model", () => {
    it("passes through instructions, skills, and collection", () => {
      const s = applyBeat(initialState(), { type: "context.set", instructions: ["no em-dashes"], skills: ["tdd", "deepsearch"], collection: "hve-core" }, 1);
      const vm = toViewModel(s);
      expect(vm.context.instructions).toEqual(["no em-dashes"]);
      expect(vm.context.skills).toEqual(["tdd", "deepsearch"]);
      expect(vm.context.collection).toBe("hve-core");
    });
    it("defaults to empty lists and null collection", () => {
      const vm = toViewModel(initialState());
      expect(vm.context).toEqual({ instructions: [], skills: [], collection: null });
    });
  });

  describe("navigator fields", () => {
    it("exposes the view and the workflow catalog", () => {
      const vm = toViewModel(initialState());
      expect(vm.view).toBe("home");
      expect(vm.workflows.map((w) => w.id)).toEqual(["build", "review", "plan", "docs", "data", "coach"]);
      expect(vm.workflows[0]).not.toHaveProperty("intent");
    });

    it("carries the active workflow once launched", () => {
      const vm = toViewModel(startLaunch(initialState(), "review"));
      expect(vm.view).toBe("loop");
      expect(vm.activeWorkflow).toBe("review");
    });

    it("exposes navigatorOpen, defaulting to false", () => {
      expect(toViewModel(initialState()).navigatorOpen).toBe(false);
    });
  });
});
