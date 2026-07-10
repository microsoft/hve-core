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
function memVm() {
  let s = applyBeat(initialState(), { type: "memory.open", title: "hve-core" }, 1);
  s = applyBeat(s, { type: "memory.add", id: "e1", title: "output style", content: "Prefers terse output, no preamble.", category: "user", tag: "recalled" }, 2);
  s = applyBeat(s, { type: "memory.add", id: "e2", content: "Ship to the fork, never origin.", category: "project", tag: "added" }, 3);
  s = applyBeat(s, { type: "handoff.add", id: "h1", from: "GitHub Backlog Manager", summary: "Sprint 24 state", action: "stored" }, 4);
  return toViewModel(s);
}

describe("memory client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the memory view and hides the others on the memory domain", () => {
    (win as any).render(memVm());
    expect((win.document.getElementById("memory-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("promptlab-view") as any).hidden).toBe(true);
  });

  it("renders entries grouped by category with tag pills, a handoff card, and the counts", () => {
    (win as any).render(memVm());
    expect(win.document.querySelectorAll("#me-entries .me-group").length).toBe(2);
    expect(win.document.querySelectorAll("#me-entries .me-entry").length).toBe(2);
    expect(win.document.querySelector("#me-entries .me-t-recalled")).not.toBeNull();
    expect(win.document.querySelector("#me-entries .me-t-added")).not.toBeNull();
    expect(win.document.querySelectorAll("#me-handoffs .mh-card").length).toBe(1);
    expect((win.document.getElementById("me-title") as any).textContent).toContain("hve-core");
  });

  it("expands an entry on click to reveal the full content", () => {
    (win as any).render(memVm());
    const head = win.document.querySelector("#me-entries .me-entry .me-head") as any;
    head.dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.querySelector("#me-entries .me-entry") as any).className).toContain("open");
  });
});
