import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";
import { Bridge } from "../src/bridge.js";

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

function interviewVm() {
  const b = new Bridge();
  b.emitBeat({ type: "interview.start", docType: "PRD" });
  void b.askQuestion("What problem?", 0);
  return toViewModel(b.state);
}

describe("interview client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows interview-view and hides rpi-view and findings-view on the interview domain", () => {
    (win as any).render(interviewVm());
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
  });

  it("renders the question prompt in iv-question", () => {
    (win as any).render(interviewVm());
    const q = win.document.getElementById("iv-question");
    expect(q!.textContent).toContain("What problem?");
  });

  it("renders a send button with data-answer attribute", () => {
    (win as any).render(interviewVm());
    const btn = win.document.querySelector("[data-answer]");
    expect(btn).not.toBeNull();
  });

  it("shows rpi-view and hides interview-view on a session.begin (rpi) loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(true);
  });
});
