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

function appFrameVm(url: string | null) {
  const s = applyBeat(initialState(), { type: "appframe.set", url }, 1);
  return toViewModel(s);
}

describe("app frame client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the panel, sets the iframe src, and shows the url for a loopback URL", () => {
    (win as any).render(appFrameVm("http://localhost:5173"));
    const panel = win.document.getElementById("app-frame") as any;
    const iframe = win.document.getElementById("af-iframe") as any;
    expect(panel.hidden).toBe(false);
    expect(iframe.getAttribute("src")).toBe("http://localhost:5173");
    expect((win.document.getElementById("af-url") as any).textContent).toBe("http://localhost:5173");
  });

  it("hides the panel and clears the iframe src when the url is null", () => {
    (win as any).render(appFrameVm("http://localhost:5173"));
    (win as any).render(appFrameVm(null));
    const panel = win.document.getElementById("app-frame") as any;
    const iframe = win.document.getElementById("af-iframe") as any;
    expect(panel.hidden).toBe(true);
    expect(iframe.getAttribute("src")).toBeNull();
  });

  it("keeps the panel hidden and sets no src for a NON-loopback URL (client guard)", () => {
    (win as any).render(appFrameVm("http://evil.com"));
    const panel = win.document.getElementById("app-frame") as any;
    const iframe = win.document.getElementById("af-iframe") as any;
    expect(panel.hidden).toBe(true);
    expect(iframe.getAttribute("src")).toBeNull();
  });

  it("locks the iframe sandbox to exactly the bounded value", () => {
    const iframe = win.document.getElementById("af-iframe") as any;
    expect(iframe.getAttribute("sandbox")).toBe("allow-scripts allow-same-origin allow-forms");
  });
});
