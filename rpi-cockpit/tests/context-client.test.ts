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

function contextVm(instructions: string[], skills: string[], collection: string | null) {
  const s = applyBeat(initialState(), { type: "context.set", instructions, skills, collection }, 1);
  return toViewModel(s);
}

describe("context client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the strip and each group with the right chip count when context is full", () => {
    (win as any).render(contextVm(["no em-dashes", "lint to zero"], ["tdd"], "hve-core"));
    expect((win.document.getElementById("context-strip") as any).hidden).toBe(false);

    const instr = win.document.getElementById("ctx-instructions") as any;
    expect(instr.hidden).toBe(false);
    expect(instr.querySelectorAll(".ctx-chip").length).toBe(2);

    const skills = win.document.getElementById("ctx-skills") as any;
    expect(skills.hidden).toBe(false);
    expect(skills.querySelectorAll(".ctx-chip").length).toBe(1);

    const collection = win.document.getElementById("ctx-collection") as any;
    expect(collection.hidden).toBe(false);
    const collChips = collection.querySelectorAll(".ctx-chip");
    expect(collChips.length).toBe(1);
    expect(collChips[0].classList.contains("collection")).toBe(true);
    expect(collChips[0].textContent).toBe("hve-core");
  });

  it("hides the strip and every group when context is all empty", () => {
    (win as any).render(contextVm([], [], null));
    expect((win.document.getElementById("context-strip") as any).hidden).toBe(true);
    expect((win.document.getElementById("ctx-instructions") as any).hidden).toBe(true);
    expect((win.document.getElementById("ctx-skills") as any).hidden).toBe(true);
    expect((win.document.getElementById("ctx-collection") as any).hidden).toBe(true);
  });

  it("hides an empty group while its non-empty siblings stay shown", () => {
    (win as any).render(contextVm(["no em-dashes"], [], "hve-core"));
    expect((win.document.getElementById("context-strip") as any).hidden).toBe(false);
    expect((win.document.getElementById("ctx-instructions") as any).hidden).toBe(false);
    expect((win.document.getElementById("ctx-skills") as any).hidden).toBe(true);
    expect((win.document.getElementById("ctx-collection") as any).hidden).toBe(false);
  });
});
