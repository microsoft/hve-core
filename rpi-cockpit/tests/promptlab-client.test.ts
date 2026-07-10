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
function benchVm() {
  let s = applyBeat(initialState(), { type: "promptlab.start", name: "summarizer.prompt", prompt: "You are a summarizer.", round: 2 }, 1);
  s = applyBeat(s, { type: "case.add", id: "c1", scenario: "empty input", output: "(produced nothing)", verdict: "fail", note: "no empty-input guard" }, 2);
  s = applyBeat(s, { type: "case.add", id: "c2", scenario: "long input", output: "ok summary", verdict: "pass" }, 3);
  return toViewModel(s);
}

describe("promptlab client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the promptlab view and hides the others on the promptlab domain", () => {
    (win as any).render(benchVm());
    expect((win.document.getElementById("promptlab-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("gallery-view") as any).hidden).toBe(true);
  });

  it("renders one case per scenario with a verdict pill, the prompt panel, and the summary", () => {
    (win as any).render(benchVm());
    const cases = win.document.querySelectorAll("#pl-cases .pc-case");
    expect(cases.length).toBe(2);
    expect(win.document.querySelector("#pl-cases .pc-v-fail")).not.toBeNull();
    expect(win.document.querySelector("#pl-cases .pc-v-pass")).not.toBeNull();
    expect((win.document.getElementById("pl-name") as any).textContent).toContain("summarizer.prompt");
    expect((win.document.getElementById("pl-prompt") as any).textContent).toContain("You are a summarizer.");
  });

  it("expands a case on click to reveal the full output", () => {
    (win as any).render(benchVm());
    const head = win.document.querySelector("#pl-cases .pc-case .pc-head") as any;
    head.dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.querySelector("#pl-cases .pc-case") as any).className).toContain("open");
  });
});
