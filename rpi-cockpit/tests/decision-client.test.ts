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

const DECISION = { id: "d1", prompt: "Which approach?", options: [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }] };

// present_options is cross-cutting; the card must paint regardless of domain. (A1)
describe("decision card paints in every domain", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  function withDecision(s: ReturnType<typeof initialState>) {
    return toViewModel({ ...s, pendingDecision: DECISION });
  }

  it("paints the card on the RPI domain", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(withDecision(s));
    expect(win.document.querySelector("#decision .decide")).not.toBeNull();
    expect(win.document.querySelector("#decision [data-choice]")).not.toBeNull();
  });

  it("paints the card on the backlog domain", () => {
    const s = applyBeat(initialState(), { type: "backlog.start", target: "Sprint", columns: ["Todo"] }, 1);
    (win as any).render(withDecision(s));
    expect(win.document.querySelector("#decision .decide")).not.toBeNull();
    expect(win.document.querySelector("#decision [data-choice]")).not.toBeNull();
  });

  it("paints the card on the interview domain", () => {
    const s = applyBeat(initialState(), { type: "interview.start", docType: "PRD" }, 1);
    (win as any).render(withDecision(s));
    expect(win.document.querySelector("#decision .decide")).not.toBeNull();
    expect(win.document.querySelector("#decision [data-choice]")).not.toBeNull();
  });

  it("paints the card on the review domain", () => {
    const s = applyBeat(initialState(), { type: "review.start", target: "PR 1" }, 1);
    (win as any).render(withDecision(s));
    expect(win.document.querySelector("#decision .decide")).not.toBeNull();
    expect(win.document.querySelector("#decision [data-choice]")).not.toBeNull();
  });

  it("clears the card when there is no pending decision", () => {
    const s = applyBeat(initialState(), { type: "review.start", target: "PR 1" }, 1);
    (win as any).render(toViewModel(s));
    expect(win.document.querySelector("#decision .decide")).toBeNull();
  });
});
