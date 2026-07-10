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
function flowVm() {
  let s = applyBeat(initialState(), { type: "flow.open", title: "hve-core pipeline" }, 1);
  s = applyBeat(s, { type: "flownode.add", id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot", status: "passed" }, 2);
  s = applyBeat(s, { type: "flownode.add", id: "impl", kind: "workflow", label: "Implement", sub: "copilot", status: "running" }, 3);
  s = applyBeat(s, { type: "flowedge.add", id: "e1", from: "triage", to: "impl", label: "agent-ready", status: "active" }, 4);
  // anatomy of triage
  s = applyBeat(s, { type: "flownode.add", id: "triage.t", kind: "trigger", label: "issues", scope: "triage" }, 5);
  s = applyBeat(s, { type: "flownode.add", id: "triage.a", kind: "agent", label: "triage agent", scope: "triage" }, 6);
  s = applyBeat(s, { type: "flowedge.add", id: "triage.e", from: "triage.t", to: "triage.a", scope: "triage", kind: "step" }, 7);
  return toViewModel(s);
}

describe("flow client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the flow view and hides the others on the flow domain", () => {
    (win as any).render(flowVm());
    expect((win.document.getElementById("flow-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("memory-view") as any).hidden).toBe(true);
  });

  it("renders orchestration workflow nodes with kind + status classes", () => {
    (win as any).render(flowVm());
    const nodes = win.document.querySelectorAll("#gw-world .gw-node");
    expect(nodes.length).toBe(2); // only orchestration scope at the top level
    expect(win.document.querySelector("#gw-world .gw-k-workflow.gw-s-passed")).not.toBeNull();
    expect(win.document.querySelector("#gw-world .gw-k-workflow.gw-s-running")).not.toBeNull();
    expect((win.document.getElementById("gw-title") as any).textContent).toContain("hve-core pipeline");
  });

  it("renders an SVG bezier path per edge, with the active class on a firing edge", () => {
    (win as any).render(flowVm());
    const paths = win.document.querySelectorAll("#gw-edges path.gw-edge");
    expect(paths.length).toBe(1); // one orchestration edge (triage -> impl)
    expect(win.document.querySelector("#gw-edges path.gw-edge.gw-active")).not.toBeNull();
    // edge label rendered
    expect((win.document.getElementById("gw-edges") as any).textContent).toContain("agent-ready");
  });

  it("drills into a workflow's anatomy on click and back returns to orchestration", () => {
    (win as any).render(flowVm());
    (win.document.querySelector('#gw-world .gw-node[data-kind="workflow"][data-gw="triage"]') as any)
      .dispatchEvent(new win.Event("click", { bubbles: true }));
    // now showing triage anatomy: trigger + agent nodes, no workflow nodes
    expect(win.document.querySelector('#gw-world .gw-k-workflow')).toBeNull();
    expect(win.document.querySelectorAll('#gw-world .gw-node').length).toBe(2);
    expect((win.document.getElementById("gw-back") as any).hidden).toBe(false);
    (win.document.getElementById("gw-back") as any).dispatchEvent(new win.Event("click", { bubbles: true }));
    expect(win.document.querySelectorAll('#gw-world .gw-k-workflow').length).toBe(2);
  });

  it("selects a node and shows it in the inspector", () => {
    (win as any).render(flowVm());
    (win.document.querySelector('#gw-world .gw-node[data-gw="impl"]') as any)
      .dispatchEvent(new win.Event("click", { bubbles: true }));
    const insp = win.document.getElementById("gw-inspector") as any;
    expect(insp.hidden).toBe(false);
    expect(insp.textContent).toContain("Implement");
  });
});
