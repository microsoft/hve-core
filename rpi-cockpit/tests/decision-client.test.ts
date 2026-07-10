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

describe("decision flow", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("renders the decision flow with answered, pending, and revisit affordances", () => {
    (win as any).render({
      view: "loop", domain: "rpi", navigatorOpen: false, workflows: [],
      context: { instructions: [], skills: [], collection: null }, appFrame: { url: null },
      hostElicits: true,
      decisions: [
        { id: "d1", prompt: "Strategy?", kind: "choice", options: [{ id: "a", title: "Blue-green" }], answer: "a", status: "answered" },
        { id: "q2", prompt: "Window?", kind: "text", status: "pending" },
      ],
      // minimal RPI fields:
      task: "t", host: "h", phase: "implement", phaseLabel: "Implement", phaseNumber: 3, lead: "x",
      steps: [{ phase: "implement", status: "active" }], subagents: [], validations: [],
      steerMenu: { label: "x", source: "preset", options: [] }, directives: [], screen: null, log: [],
      findingGroups: [], board: { target: null, action: null, count: 0, columns: [] },
      team: { orchestrator: null, count: 0, columns: [] }, codemap: { nodes: [], focus: null, touches: {} },
      reviewTarget: null, docType: null,
    });
    const rows = (win as any).document.querySelectorAll("#decision-flow .flow-row");
    expect(rows.length).toBe(2);
    expect((win as any).document.querySelector('#decision-flow .flow-row[data-decision-id="d1"] [data-revise="d1"]')).toBeTruthy();
    const pending = (win as any).document.querySelector('#decision-flow .flow-row[data-decision-id="q2"]');
    expect(pending?.className).toContain("pending");
    // hostElicits true => choice chips are NOT clickable inputs
    expect((win as any).document.querySelector('#decision-flow [data-choice]')).toBeNull();
  });

  it("renders interactive choice chips when hostElicits is false", () => {
    (win as any).render({
      view: "loop", domain: "rpi", navigatorOpen: false, workflows: [],
      context: { instructions: [], skills: [], collection: null }, appFrame: { url: null },
      hostElicits: false,
      decisions: [
        { id: "d1", prompt: "Pick one?", kind: "choice", options: [{ id: "x", title: "Option X" }], status: "pending" },
      ],
      task: "t", host: "h", phase: "implement", phaseLabel: "Implement", phaseNumber: 3, lead: "x",
      steps: [{ phase: "implement", status: "active" }], subagents: [], validations: [],
      steerMenu: { label: "x", source: "preset", options: [] }, directives: [], screen: null, log: [],
      findingGroups: [], board: { target: null, action: null, count: 0, columns: [] },
      team: { orchestrator: null, count: 0, columns: [] }, codemap: { nodes: [], focus: null, touches: {} },
      reviewTarget: null, docType: null,
    });
    expect((win as any).document.querySelector('#decision-flow [data-choice]')).not.toBeNull();
  });
});
