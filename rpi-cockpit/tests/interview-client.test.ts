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

  it("renders the doc iframe when a screen is present", () => {
    const b = new Bridge();
    b.emitBeat({ type: "interview.start", docType: "PRD" });
    (b.state as any).screen = { html: "<p>Draft content</p>" };
    (win as any).render(toViewModel(b.state));
    const doc = win.document.getElementById("iv-doc") as HTMLIFrameElement;
    expect(doc).not.toBeNull();
    expect((doc as any).srcdoc).toContain("Draft content");
  });

  it("shows rpi-view and hides interview-view on a session.begin (rpi) loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(true);
  });
});

function steppedVm() {
  let s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
  s = applyBeat(s, { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" }, 2);
  return toViewModel(s);
}

describe("interview layout", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("wraps the conversation in .iv-convo with the draft iframe as a sibling", () => {
    (win as any).render(steppedVm()); // existing helper from the stepper tests
    const view = win.document.getElementById("interview-view")!;
    const convo = view.querySelector(".iv-convo")!;
    expect(convo).not.toBeNull();
    expect(convo.querySelector("#iv-steps")).not.toBeNull();
    expect(convo.querySelector(".flow-slot")).not.toBeNull();
    // the draft iframe is a direct child of #interview-view, NOT inside .iv-convo
    const ivDoc = win.document.getElementById("iv-doc")!;
    expect(ivDoc).not.toBeNull();
    expect(ivDoc.parentElement!.id).toBe("interview-view");
    expect(convo.querySelector("#iv-doc")).toBeNull();
  });
});

describe("interview stepper", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("renders done/total and a mini-bar on the active step with progress", () => {
    let s = applyBeat(initialState(), { type: "interview.start", docType: "ADR" }, 1);
    s = applyBeat(s, { type: "steps.set", steps: ["Frame", "Decide", "Govern"], current: 1, progress: { done: 2, total: 4 } }, 2);
    (win as any).render(toViewModel(s));
    const active = win.document.querySelector("#iv-steps .iv-step-active")!;
    expect(active.querySelector(".iv-step-prog")!.textContent).toBe("2/4");
    const bar = active.querySelector(".iv-step-bar > i") as any;
    expect(bar.getAttribute("style")).toContain("width:50%");
  });

  it("renders the interview stepper with done/active/pending pills", () => {
    (win as any).render(steppedVm());
    const steps = win.document.getElementById("iv-steps") as any;
    expect(steps.hidden).toBe(false);
    const pills = win.document.querySelectorAll("#iv-steps .iv-step");
    expect(pills.length).toBe(3);
    expect(win.document.querySelector("#iv-steps .iv-step-done")).not.toBeNull();
    expect(win.document.querySelector("#iv-steps .iv-step-active")!.textContent).toContain("Decide");
    expect(win.document.querySelector("#iv-steps .iv-step-pending")!.textContent).toContain("Govern");
  });

  it("hides the stepper when no program is declared", () => {
    let s = applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("iv-steps") as any).hidden).toBe(true);
  });
});
