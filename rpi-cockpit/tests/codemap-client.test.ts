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

function codemapVm() {
  const s = applyBeat(initialState(), { type: "codemap.set", nodes: [
    { id: "n1", path: "src/a.ts", kind: "file" },
    { id: "n2", path: "src/b.ts", kind: "file" },
    { id: "n3", path: "lib/c.ts", kind: "file" },
  ] }, 1);
  return toViewModel(s);
}

describe("codemap client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("builds one .cn per node in #cm-world", () => {
    (win as any).render(codemapVm());
    const nodes = win.document.querySelectorAll("#cm-world .cn");
    expect(nodes.length).toBe(3);
  });

  it("shows codemap-view and hides the other loop views on the codemap domain", () => {
    (win as any).render(codemapVm());
    expect((win.document.getElementById("codemap-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("team-view") as any).hidden).toBe(true);
  });

  it("hides codemap-view on a non-codemap (rpi) loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("codemap-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
  });

  it("adds .focused to the matching .cn on a focus view-model", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [
      { id: "n1", path: "src/a.ts", kind: "file" },
      { id: "n2", path: "src/b.ts", kind: "file" },
    ] }, 1);
    s = applyBeat(s, { type: "codemap.focus", id: "n2" }, 2);
    (win as any).render(toViewModel(s));
    const focused = win.document.querySelectorAll("#cm-world .cn.focused");
    expect(focused.length).toBe(1);
    expect((focused[0] as any).dataset.node).toBe("n2");
  });

  it("adds .read and .edited to the matching .cn on a touch view-model", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [
      { id: "n1", path: "src/a.ts", kind: "file" },
      { id: "n2", path: "src/b.ts", kind: "file" },
    ] }, 1);
    s = applyBeat(s, { type: "codemap.touch", id: "n1", kind: "read" }, 2);
    s = applyBeat(s, { type: "codemap.touch", id: "n2", kind: "edit" }, 3);
    (win as any).render(toViewModel(s));
    const read = win.document.querySelector('#cm-world .cn[data-node="n1"]') as any;
    const edited = win.document.querySelector('#cm-world .cn[data-node="n2"]') as any;
    expect(read.classList.contains("read")).toBe(true);
    expect(edited.classList.contains("edited")).toBe(true);
  });

  it("build-once: a focus-only re-render keeps the same .cn elements (no rebuild)", () => {
    let s = applyBeat(initialState(), { type: "codemap.set", nodes: [
      { id: "n1", path: "src/a.ts", kind: "file" },
      { id: "n2", path: "src/b.ts", kind: "file" },
    ] }, 1);
    (win as any).render(toViewModel(s));
    const before = win.document.querySelectorAll("#cm-world .cn");
    const firstEl = before[0];
    // re-render with the SAME node set but a new focus
    s = applyBeat(s, { type: "codemap.focus", id: "n1" }, 2);
    (win as any).render(toViewModel(s));
    const after = win.document.querySelectorAll("#cm-world .cn");
    expect(after.length).toBe(before.length);
    // the same DOM element object must survive the focus-only re-render
    expect(after[0]).toBe(firstEl);
    expect((after[0] as any).classList.contains("focused")).toBe(true);
  });
});
