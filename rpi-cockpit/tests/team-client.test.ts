import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");

function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}

function teamVm() {
  let s = applyBeat(initialState(), { type: "team.start", task: "ship", orchestrator: "Lead" }, 1);
  s = applyBeat(s, { type: "agent.add", id: "a1", name: "Worker One", role: "impl", status: "running" }, 2);
  s = applyBeat(s, { type: "agent.add", id: "a2", name: "Worker Two", status: "running" }, 3);
  s = applyBeat(s, { type: "agent.add", id: "a3", name: "Worker Three", status: "queued" }, 4);
  s = applyBeat(s, { type: "agent.update", id: "a1", action: "writing tests" }, 5);
  return toViewModel(s);
}

describe("team client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("paints one .board-col per non-empty status with the right agent-card count", () => {
    (win as any).render(teamVm());
    const cols = win.document.querySelectorAll("#team-board .board-col");
    // running + queued only; blocked/done/failed are empty and dropped
    expect(cols.length).toBe(2);
    expect(cols[0].querySelectorAll(".agent-card").length).toBe(2);
    expect(cols[1].querySelectorAll(".agent-card").length).toBe(1);
  });

  it("renders the orchestrator and the agent count", () => {
    (win as any).render(teamVm());
    expect((win.document.getElementById("team-orch") as any).textContent).toBe("Lead");
    expect((win.document.getElementById("team-count") as any).textContent).toBe("3 agents");
  });

  it("shows team-view and hides the other loop views on the team domain", () => {
    (win as any).render(teamVm());
    expect((win.document.getElementById("team-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(true);
  });

  it("hides team-view on a non-team (rpi) loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("team-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
  });

  it("wires Pause and Swap controls with intervene + agent data, and a spawn button", () => {
    (win as any).render(teamVm());
    const pause = win.document.querySelector('#team-board [data-intervene="pause"]') as any;
    expect(pause).not.toBeNull();
    expect(pause.dataset.intervene).toBe("pause");
    expect(pause.dataset.agent).toBe("a1");
    const swap = win.document.querySelector('#team-board [data-intervene="swap"]') as any;
    expect(swap.dataset.agent).toBe("a1");
    const spawn = win.document.getElementById("team-spawn") as any;
    expect(spawn.dataset.intervene).toBe("spawn");
  });
});
