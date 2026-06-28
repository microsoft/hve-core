// rpi-cockpit/tests/state.test.ts
import { describe, it, expect } from "vitest";
import { initialState, applyBeat, enqueueDirective, drainDirectives, setView, startLaunch, setNavigatorOpen, addDecision, answerDecision, reviseDecision, setHostElicits } from "../src/state.js";

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

    it("defaults navigatorOpen to false", () => {
      expect(initialState().navigatorOpen).toBe(false);
    });

    it("setNavigatorOpen toggles the navigator flag", () => {
      expect(setNavigatorOpen(initialState(), true).navigatorOpen).toBe(true);
      expect(setNavigatorOpen(setNavigatorOpen(initialState(), true), false).navigatorOpen).toBe(false);
    });

    it("startLaunch closes the navigator pop-up", () => {
      const open = setNavigatorOpen(initialState(), true);
      expect(startLaunch(open, "build").navigatorOpen).toBe(false);
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

describe("interview domain", () => {
  it("interview.start sets the interview domain, view loop, and docType", () => {
    const s = applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1);
    expect(s.domain).toBe("interview");
    expect(s.view).toBe("loop");
    expect(s.docType).toBe("PRD");
  });
  it("defaults docType null", () => {
    expect(initialState().docType).toBeNull();
  });
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
    expect(s.view).toBe("loop");
  });
  it("finding.add appends a finding", () => {
    let s = applyBeat(initialState(), { type: "review.start", target: "x" }, 1);
    s = applyBeat(s, { type: "finding.add", severity: "high", title: "bug", file: "a.ts", line: 3 }, 2);
    expect(s.findings).toEqual([{ severity: "high", title: "bug", file: "a.ts", line: 3, detail: undefined }]);
  });
});

describe("context.set", () => {
  it("sets all three context fields", () => {
    const s = applyBeat(initialState(), { type: "context.set", instructions: ["no em-dashes", "lint to zero"], skills: ["tdd"], collection: "hve-core" }, 1);
    expect(s.contextInstructions).toEqual(["no em-dashes", "lint to zero"]);
    expect(s.contextSkills).toEqual(["tdd"]);
    expect(s.contextCollection).toBe("hve-core");
  });
  it("defaults the three context fields to empty", () => {
    const s = initialState();
    expect(s.contextInstructions).toEqual([]);
    expect(s.contextSkills).toEqual([]);
    expect(s.contextCollection).toBeNull();
  });
  it("a second context.set replaces, clearing with empty arrays and null", () => {
    let s = applyBeat(initialState(), { type: "context.set", instructions: ["a", "b"], skills: ["x"], collection: "C" }, 1);
    s = applyBeat(s, { type: "context.set", instructions: [], skills: [], collection: null }, 2);
    expect(s.contextInstructions).toEqual([]);
    expect(s.contextSkills).toEqual([]);
    expect(s.contextCollection).toBeNull();
  });
});

describe("appframe.set", () => {
  it("sets appFrameUrl on appframe.set", () => {
    const s = applyBeat(initialState(), { type: "appframe.set", url: "http://localhost:5173" }, 1);
    expect(s.appFrameUrl).toBe("http://localhost:5173");
  });
  it("clears appFrameUrl on appframe.set with null", () => {
    let s = applyBeat(initialState(), { type: "appframe.set", url: "http://localhost:5173" }, 1);
    s = applyBeat(s, { type: "appframe.set", url: null }, 2);
    expect(s.appFrameUrl).toBeNull();
  });
  it("defaults appFrameUrl to null", () => {
    expect(initialState().appFrameUrl).toBeNull();
  });
});

describe("backlog domain", () => {
  it("defaults the board fields", () => {
    const s = initialState();
    expect(s.boardTarget).toBeNull();
    expect(s.boardColumns).toEqual([]);
    expect(s.boardItems).toEqual([]);
    expect(s.boardAction).toBeNull();
  });
  it("backlog.start sets the backlog domain, view loop, columns, and resets items/action", () => {
    let s = applyBeat(initialState(), { type: "item.add", id: "x", title: "stale", column: "Todo" }, 1);
    s = applyBeat(s, { type: "backlog.action", text: "old" }, 2);
    s = applyBeat(s, { type: "backlog.start", target: "Sprint 4", columns: ["Todo", "Doing", "Done"] }, 3);
    expect(s.domain).toBe("backlog");
    expect(s.view).toBe("loop");
    expect(s.boardTarget).toBe("Sprint 4");
    expect(s.boardColumns).toEqual(["Todo", "Doing", "Done"]);
    expect(s.boardItems).toEqual([]);
    expect(s.boardAction).toBeNull();
  });
  it("item.add adds a work item", () => {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "b", columns: ["Todo"] }, 1);
    s = applyBeat(s, { type: "item.add", id: "I1", title: "fix login", column: "Todo", kind: "bug", tier: "T2" }, 2);
    expect(s.boardItems).toEqual([{ id: "I1", title: "fix login", column: "Todo", kind: "bug", tier: "T2" }]);
  });
  it("item.add with an existing id replaces it, keeping the count", () => {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "b", columns: ["Todo", "Done"] }, 1);
    s = applyBeat(s, { type: "item.add", id: "I1", title: "first", column: "Todo" }, 2);
    s = applyBeat(s, { type: "item.add", id: "I1", title: "second", column: "Done", kind: "task" }, 3);
    expect(s.boardItems).toHaveLength(1);
    expect(s.boardItems[0]).toMatchObject({ id: "I1", title: "second", column: "Done", kind: "task" });
  });
  it("item.move changes the column", () => {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "b", columns: ["Todo", "Done"] }, 1);
    s = applyBeat(s, { type: "item.add", id: "I1", title: "t", column: "Todo" }, 2);
    s = applyBeat(s, { type: "item.move", id: "I1", column: "Done" }, 3);
    expect(s.boardItems[0].column).toBe("Done");
  });
  it("item.move with an unknown id is a no-op", () => {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "b", columns: ["Todo", "Done"] }, 1);
    s = applyBeat(s, { type: "item.add", id: "I1", title: "t", column: "Todo" }, 2);
    s = applyBeat(s, { type: "item.move", id: "nope", column: "Done" }, 3);
    expect(s.boardItems).toEqual([{ id: "I1", title: "t", column: "Todo", kind: undefined, tier: undefined }]);
  });
  it("backlog.action sets the text and clears with null", () => {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "b", columns: ["Todo"] }, 1);
    s = applyBeat(s, { type: "backlog.action", text: "triaging" }, 2);
    expect(s.boardAction).toBe("triaging");
    s = applyBeat(s, { type: "backlog.action", text: null }, 3);
    expect(s.boardAction).toBeNull();
  });
});

describe("team domain", () => {
  it("defaults the team fields", () => {
    const s = initialState();
    expect(s.orchestrator).toBeNull();
    expect(s.teamAgents).toEqual([]);
  });
  it("team.start sets the team domain, view loop, orchestrator, and resets the roster", () => {
    let s = applyBeat(initialState(), { type: "agent.add", id: "a1", name: "stale", status: "running" }, 1);
    s = applyBeat(s, { type: "team.start", task: "ship feature", orchestrator: "Lead" }, 2);
    expect(s.domain).toBe("team");
    expect(s.view).toBe("loop");
    expect(s.task).toBe("ship feature");
    expect(s.orchestrator).toBe("Lead");
    expect(s.teamAgents).toEqual([]);
  });
  it("agent.add adds a team agent", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "Worker", role: "impl", status: "running" }, 2);
    expect(s.teamAgents).toEqual([{ id: "a1", name: "Worker", role: "impl", status: "running" }]);
  });
  it("agent.add with an existing id replaces it, keeping the count", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "first", status: "queued" }, 2);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "second", status: "running" }, 3);
    expect(s.teamAgents).toHaveLength(1);
    expect(s.teamAgents[0]).toMatchObject({ id: "a1", name: "second", status: "running" });
  });
  it("agent.update changes status without wiping action", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "W", status: "queued" }, 2);
    s = applyBeat(s, { type: "agent.update", id: "a1", action: "writing tests" }, 3);
    s = applyBeat(s, { type: "agent.update", id: "a1", status: "running" }, 4);
    expect(s.teamAgents[0]).toMatchObject({ status: "running", action: "writing tests" });
  });
  it("agent.update changes action without wiping status", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "W", status: "running" }, 2);
    s = applyBeat(s, { type: "agent.update", id: "a1", action: "refactoring" }, 3);
    expect(s.teamAgents[0]).toMatchObject({ status: "running", action: "refactoring" });
  });
  it("agent.update with an unknown id is a no-op", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "W", status: "running" }, 2);
    s = applyBeat(s, { type: "agent.update", id: "nope", status: "done" }, 3);
    expect(s.teamAgents).toEqual([{ id: "a1", name: "W", role: undefined, status: "running" }]);
  });
  it("agent.remove removes an agent from the roster", () => {
    let s = applyBeat(initialState(), { type: "team.start", task: "t", orchestrator: "L" }, 1);
    s = applyBeat(s, { type: "agent.add", id: "a1", name: "W1", status: "running" }, 2);
    s = applyBeat(s, { type: "agent.add", id: "a2", name: "W2", status: "queued" }, 3);
    s = applyBeat(s, { type: "agent.remove", id: "a1" }, 4);
    expect(s.teamAgents.map((a) => a.id)).toEqual(["a2"]);
  });
});

describe("codemap domain", () => {
  it("defaults the codemap fields", () => {
    const s = initialState();
    expect(s.codemapNodes).toEqual([]);
    expect(s.codemapFocus).toBeNull();
    expect(s.codemapTouches).toEqual({});
  });
  it("codemap.set sets the codemap domain, view loop, nodes, and resets focus/touches", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "src/a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.focus", id: "n1" }, 2);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "edit" }, 3);
    s = applyBeat(s, { type: "codemap.set", nodes: [{ id: "n2", path: "src/b.ts", kind: "file" }] }, 4);
    expect(s.domain).toBe("codemap");
    expect(s.view).toBe("loop");
    expect(s.codemapNodes).toEqual([{ id: "n2", path: "src/b.ts", kind: "file" }]);
    expect(s.codemapFocus).toBeNull();
    expect(s.codemapTouches).toEqual({});
  });
  it("codemap.focus sets the focus to a known node", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.focus", id: "n1" }, 2);
    expect(s.codemapFocus).toBe("n1");
  });
  it("codemap.focus on an unknown id is a no-op", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.focus", id: "nope" }, 2);
    expect(s.codemapFocus).toBeNull();
  });
  it("codemap.touch sets read", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "read" }, 2);
    expect(s.codemapTouches.n1).toBe("read");
  });
  it("codemap.touch edit overrides an existing read", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "read" }, 2);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "edit" }, 3);
    expect(s.codemapTouches.n1).toBe("edit");
  });
  it("codemap.touch read does NOT downgrade an existing edit", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "edit" }, 2);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "read" }, 3);
    expect(s.codemapTouches.n1).toBe("edit");
  });
  it("codemap.touch on an unknown id is a no-op", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [{ id: "n1", path: "a.ts", kind: "file" }] }, 1);
    s = applyBeat(s, { type: "codemap.touch", id: "nope", kind: "read" }, 2);
    expect(s.codemapTouches).toEqual({});
  });
});

describe("decision flow", () => {
  const opts = [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }];

  it("addDecision appends a pending choice entry", () => {
    const s = addDecision(initialState(), { id: "d1", prompt: "Pick?", kind: "choice", options: opts });
    expect(s.decisions).toHaveLength(1);
    expect(s.decisions[0]).toMatchObject({ id: "d1", prompt: "Pick?", kind: "choice", status: "pending" });
    expect(s.decisions[0].options).toEqual(opts);
  });

  it("addDecision with an existing id re-opens it in place (clears the answer)", () => {
    let s = addDecision(initialState(), { id: "d1", prompt: "Pick?", kind: "choice", options: opts });
    s = answerDecision(s, "d1", "a");
    s = addDecision(s, { id: "d1", prompt: "Pick again?", kind: "choice", options: opts });
    expect(s.decisions).toHaveLength(1);
    expect(s.decisions[0]).toMatchObject({ id: "d1", prompt: "Pick again?", status: "pending" });
    expect(s.decisions[0].answer).toBeUndefined();
  });

  it("answerDecision marks the entry answered with the answer", () => {
    let s = addDecision(initialState(), { id: "q1", prompt: "Name?", kind: "text" });
    s = answerDecision(s, "q1", "Ada");
    expect(s.decisions[0]).toMatchObject({ status: "answered", answer: "Ada" });
  });

  it("reviseDecision re-opens the target and supersedes later answered entries", () => {
    let s = initialState();
    for (const id of ["d1", "d2", "d3"]) s = answerDecision(addDecision(s, { id, prompt: id, kind: "text" }), id, id + "ans");
    s = reviseDecision(s, "d1");
    expect(s.decisions.map((d) => d.status)).toEqual(["pending", "superseded", "superseded"]);
    expect(s.decisions[0].answer).toBeUndefined();
    expect(s.decisions[1].answer).toBe("d2ans"); // kept visible
  });

  it("reviseDecision on an unknown id is a no-op", () => {
    const s = answerDecision(addDecision(initialState(), { id: "d1", prompt: "x", kind: "text" }), "d1", "y");
    expect(reviseDecision(s, "nope")).toEqual(s);
  });

  it("setHostElicits toggles the flag", () => {
    expect(setHostElicits(initialState(), true).hostElicits).toBe(true);
  });
});
