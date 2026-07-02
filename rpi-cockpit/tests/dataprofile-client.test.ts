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
function profileVm() {
  let s = applyBeat(initialState(), { type: "profile.start", name: "sales.csv", rows: 100, columns: 2, source: "dw" }, 1);
  s = applyBeat(s, { type: "column.add", name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" }, 2);
  s = applyBeat(s, { type: "column.add", name: "region", dtype: "category", distinct: 5, stat: "top: US 42%", quality: "warn" }, 3);
  return toViewModel(s);
}

describe("dataprofile client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the dataprofile view and hides the others on the dataprofile domain", () => {
    (win as any).render(profileVm());
    expect((win.document.getElementById("dataprofile-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(true);
  });

  it("renders one row per column with a quality dot of the right class", () => {
    (win as any).render(profileVm());
    const rows = win.document.querySelectorAll("#dp-table tbody tr");
    expect(rows.length).toBe(2);
    expect(win.document.querySelector("#dp-table .dp-q-ok")).not.toBeNull();
    expect(win.document.querySelector("#dp-table .dp-q-warn")).not.toBeNull();
    expect((win.document.getElementById("dp-name") as any).textContent).toBe("sales.csv");
  });
});
