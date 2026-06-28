// rpi-cockpit/tests/render.test.ts
import { describe, it, expect } from "vitest";
import { toViewModel } from "../src/render.js";
import { initialState, applyBeat, enqueueDirective, startLaunch, addDecision, answerDecision, setHostElicits } from "../src/state.js";

describe("toViewModel", () => {
  it("marks the current phase active and prior phases done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "implement" }, 2);
    const vm = toViewModel(s);
    expect(vm.steps.find((x) => x.phase === "research")!.status).toBe("done");
    expect(vm.steps.find((x) => x.phase === "implement")!.status).toBe("active");
    expect(vm.steps.find((x) => x.phase === "review")!.status).toBe("pending");
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

  it("exposes docType", () => {
    const s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
    const vm = toViewModel(s);
    expect(vm.domain).toBe("interview");
    expect(vm.docType).toBe("ADR");
  });

  it("projects the decisions flow and hostElicits, and drops the legacy single-decision fields", () => {
    let s = initialState();
    s = setHostElicits(s, true);
    s = answerDecision(addDecision(s, { id: "d1", prompt: "Pick?", kind: "choice", options: [{ id: "a", title: "A" }] }), "d1", "a");
    s = addDecision(s, { id: "q2", prompt: "Name?", kind: "text" });
    const vm = toViewModel(s);
    expect(vm.hostElicits).toBe(true);
    expect(vm.decisions).toHaveLength(2);
    expect(vm.decisions[0]).toMatchObject({ id: "d1", kind: "choice", status: "answered", answer: "a" });
    expect(vm.decisions[1]).toMatchObject({ id: "q2", kind: "text", status: "pending" });
    expect("decision" in vm).toBe(false);
    expect("pendingQuestion" in vm).toBe(false);
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
      expect(board.columns[0].items[0]).toEqual({ id: "I1", title: "a", kind: "bug", tier: "T1", depth: 0 });
      expect(board.columns[2].items.map((i) => i.id)).toEqual(["I2"]);
    });
  });

  describe("team view-model", () => {
    it("groups agents by status in fixed order, drops empty status columns, count = total", () => {
      let s = applyBeat(initialState(), { type: "team.start", task: "ship", orchestrator: "Lead" }, 1);
      s = applyBeat(s, { type: "agent.add", id: "a1", name: "Q", status: "queued" }, 2);
      s = applyBeat(s, { type: "agent.add", id: "a2", name: "R1", role: "impl", status: "running" }, 3);
      s = applyBeat(s, { type: "agent.add", id: "a3", name: "R2", status: "running" }, 4);
      s = applyBeat(s, { type: "agent.update", id: "a2", action: "writing tests" }, 5);
      const { team } = toViewModel(s);
      expect(team.orchestrator).toBe("Lead");
      expect(team.count).toBe(3);
      // running comes before queued; blocked/done/failed are empty and dropped
      expect(team.columns.map((c) => c.status)).toEqual(["running", "queued"]);
      expect(team.columns[0].label).toBe("Running");
      expect(team.columns[0].agents.map((a) => a.id)).toEqual(["a2", "a3"]);
      expect(team.columns[0].agents[0]).toEqual({ id: "a2", name: "R1", role: "impl", action: "writing tests" });
      expect(team.columns[1].agents.map((a) => a.id)).toEqual(["a1"]);
    });
    it("defaults to a null orchestrator, zero count, and no columns", () => {
      const { team } = toViewModel(initialState());
      expect(team).toEqual({ orchestrator: null, count: 0, columns: [] });
    });
  });

  describe("codemap view-model", () => {
    it("passes through nodes, focus, and touches", () => {
      let s = applyBeat(initialState(), { type: "codemap.set", nodes: [
        { id: "n1", path: "src/a.ts", kind: "file" },
        { id: "n2", path: "src/b.ts", kind: "file" },
      ] }, 1);
      s = applyBeat(s, { type: "codemap.focus", id: "n1" }, 2);
      s = applyBeat(s, { type: "codemap.touch", id: "n2", kind: "edit" }, 3);
      const vm = toViewModel(s);
      expect(vm.domain).toBe("codemap");
      expect(vm.codemap.nodes.map((n) => n.id)).toEqual(["n1", "n2"]);
      expect(vm.codemap.focus).toBe("n1");
      expect(vm.codemap.touches).toEqual({ n2: "edit" });
    });
    it("derives the group from the path top segment when group is absent", () => {
      const s = applyBeat(initialState(), { type: "codemap.set", nodes: [
        { id: "n1", path: "src/a.ts", kind: "file" },
        { id: "n2", path: "README.md", kind: "file" },
      ] }, 1);
      const vm = toViewModel(s);
      expect(vm.codemap.nodes[0].group).toBe("src");
      expect(vm.codemap.nodes[1].group).toBe("(root)");
    });
    it("keeps an explicit group over the derived one", () => {
      const s = applyBeat(initialState(), { type: "codemap.set", nodes: [
        { id: "n1", path: "src/a.ts", kind: "file", group: "core" },
      ] }, 1);
      expect(toViewModel(s).codemap.nodes[0].group).toBe("core");
    });
    it("defaults to empty nodes, null focus, empty touches", () => {
      expect(toViewModel(initialState()).codemap).toEqual({ nodes: [], focus: null, touches: {} });
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

  describe("app frame view-model", () => {
    it("passes through the app frame url", () => {
      const s = applyBeat(initialState(), { type: "appframe.set", url: "http://localhost:5173" }, 1);
      expect(toViewModel(s).appFrame.url).toBe("http://localhost:5173");
    });
    it("defaults the app frame url to null", () => {
      expect(toViewModel(initialState()).appFrame).toEqual({ url: null });
    });
  });

  describe("backlog hierarchy projection", () => {
    function build(items: { id: string; title: string; column: string; parent?: string }[]) {
      let s = applyBeat(initialState(), { type: "backlog.start", target: "S", columns: ["Plan", "Done"] }, 1);
      items.forEach((it, n) => { s = applyBeat(s, { type: "item.add", ...it }, n + 2); });
      return toViewModel(s);
    }
    const plan = (vm: any) => vm.board.columns.find((c: any) => c.name === "Plan").items;
    const done = (vm: any) => vm.board.columns.find((c: any) => c.name === "Done").items;

    it("nests a same-column chain with increasing depth, parent-first", () => {
      const vm = build([
        { id: "E", title: "Epic", column: "Plan" },
        { id: "F", title: "Feature", column: "Plan", parent: "E" },
        { id: "S", title: "Story", column: "Plan", parent: "F" },
      ]);
      expect(plan(vm).map((i: any) => [i.id, i.depth])).toEqual([["E", 0], ["F", 1], ["S", 2]]);
      expect(plan(vm).every((i: any) => i.parentRef === undefined)).toBe(true);
    });

    it("shows a parentRef when the parent is in a different column", () => {
      const vm = build([
        { id: "E", title: "Epic", column: "Plan" },
        { id: "S", title: "Story", column: "Done", parent: "E" },
      ]);
      expect(done(vm)).toEqual([{ id: "S", title: "Story", kind: undefined, tier: undefined, depth: 0, parentRef: "Epic" }]);
    });

    it("falls back to the raw parent id when the parent is not on the board", () => {
      const vm = build([{ id: "S", title: "Orphan", column: "Plan", parent: "ghost" }]);
      expect(plan(vm)[0]).toMatchObject({ id: "S", depth: 0, parentRef: "ghost" });
    });

    it("keeps parentless items in insertion order at depth 0", () => {
      const vm = build([
        { id: "A", title: "A", column: "Plan" },
        { id: "B", title: "B", column: "Plan" },
      ]);
      expect(plan(vm).map((i: any) => [i.id, i.depth])).toEqual([["A", 0], ["B", 0]]);
    });
  });

  it("projects the data profile dataset and columns", () => {
    let s = applyBeat(initialState(), { type: "profile.start", name: "sales.csv", rows: 100, columns: 3, source: "warehouse" }, 1);
    s = applyBeat(s, { type: "column.add", name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" }, 2);
    const vm = toViewModel(s);
    expect(vm.domain).toBe("dataprofile");
    expect(vm.dataProfile.dataset).toEqual({ name: "sales.csv", rows: 100, cols: 3, source: "warehouse" });
    expect(vm.dataProfile.columns).toEqual([{ name: "id", dtype: "int", nullPct: 0, distinct: 100, stat: undefined, quality: "ok" }]);
    expect(toViewModel(initialState()).dataProfile.dataset).toBeNull();
  });

  it("attaches progress to the active step only", () => {
    const s = applyBeat(initialState(), { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, progress: { done: 2, total: 3 } }, 1);
    const steps = toViewModel(s).interviewSteps!.steps;
    expect(steps[1]).toEqual({ name: "Decide", status: "active", progress: { done: 2, total: 3 } });
    expect((steps[0] as any).progress).toBeUndefined();
    expect((steps[2] as any).progress).toBeUndefined();
  });

  it("projects interview steps with done/active/pending derived from current", () => {
    const s = applyBeat(initialState(), { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" }, 1);
    const vm = toViewModel(s);
    expect(vm.interviewSteps).toEqual({ label: "ADR", steps: [
      { name: "Frame", status: "done" },
      { name: "Decide", status: "active" },
      { name: "Govern", status: "pending" },
    ] });
    expect(toViewModel(initialState()).interviewSteps).toBeNull();
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
