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

function boardVm(action: string | null = null) {
  let s = applyBeat(initialState(), { type: "backlog.start", target: "Sprint 4", columns: ["Todo", "Doing", "Done"] }, 1);
  s = applyBeat(s, { type: "item.add", id: "I1", title: "fix login", column: "Todo", kind: "bug", tier: "T1" }, 2);
  s = applyBeat(s, { type: "item.add", id: "I2", title: "ship it", column: "Done" }, 3);
  s = applyBeat(s, { type: "item.add", id: "I3", title: "second todo", column: "Todo" }, 4);
  if (action !== null) s = applyBeat(s, { type: "backlog.action", text: action }, 5);
  return toViewModel(s);
}

function hierarchyVm() {
  let s = applyBeat(initialState(), { type: "backlog.start", target: "S", columns: ["Plan", "Done"] }, 1);
  s = applyBeat(s, { type: "item.add", id: "E", title: "Epic", column: "Plan" }, 2);
  s = applyBeat(s, { type: "item.add", id: "F", title: "Feature", column: "Plan", parent: "E" }, 3);
  s = applyBeat(s, { type: "item.add", id: "S", title: "Story", column: "Done", parent: "E" }, 4);
  return toViewModel(s);
}

describe("backlog client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("paints one .board-col per column with the right card count and ids", () => {
    (win as any).render(boardVm());
    const cols = win.document.querySelectorAll("#board .board-col");
    expect(cols.length).toBe(3);
    const firstCards = cols[0].querySelectorAll(".bcard");
    expect(firstCards.length).toBe(2);
    const ids = Array.from(firstCards).map((c: any) => c.querySelector(".bcard-id")!.textContent);
    expect(ids).toEqual(["I1", "I3"]);
    // The empty Doing column keeps rendering with no cards.
    expect(cols[1].querySelectorAll(".bcard").length).toBe(0);
    expect(cols[2].querySelectorAll(".bcard").length).toBe(1);
  });

  it("shows backlog-view and hides the other loop views on the backlog domain", () => {
    (win as any).render(boardVm());
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("interview-view") as any).hidden).toBe(true);
  });

  it("shows the action chip only when board.action is set", () => {
    (win as any).render(boardVm());
    expect((win.document.getElementById("board-action") as any).hidden).toBe(true);
    (win as any).render(boardVm("triaging"));
    const chip = win.document.getElementById("board-action") as any;
    expect(chip.hidden).toBe(false);
    expect(chip.textContent).toBe("triaging");
  });

  it("hides backlog-view on a non-backlog (rpi) loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
  });

  it("indents a same-column child and shows a reference for a cross-column child", () => {
    (win as any).render(hierarchyVm());
    const planCards = win.document.querySelectorAll('#board .board-col[aria-label="Plan"] .bcard');
    const feature = Array.from(planCards).find((c: any) => c.querySelector(".bcard-id")!.textContent === "F") as any;
    expect(feature.getAttribute("style")).toContain("margin-left:16px");
    expect(feature.querySelector(".bcard-parent")).toBeNull(); // same-column: nesting, no ref
    const doneCard = win.document.querySelector('#board .board-col[aria-label="Done"] .bcard') as any;
    expect(doneCard.querySelector(".bcard-parent")!.textContent).toContain("Epic");
    const epic = Array.from(planCards).find((c: any) => c.querySelector(".bcard-id")!.textContent === "E") as any;
    expect(epic.getAttribute("style")).toBeNull(); // root: no indent
  });
});
