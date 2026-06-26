import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { initialState, startLaunch } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");

function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  const sent: any[] = [];
  // Stub the WebSocket so client.js can construct one; capture sent frames.
  (win as any).WebSocket = class {
    readyState = 1; onopen: any; onclose: any; onerror: any; onmessage: any;
    constructor() { /* no-op */ }
    send(s: string) { sent.push(JSON.parse(s)); }
    close() {}
  };
  // Execute the client module body in the window context.
  // Strip ES module import lines (happy-dom eval doesn't resolve bare specifiers).
  win.eval(js.replace(/^import .*$/gm, ""));
  return { win, sent };
}

describe("navigator client", () => {
  let env: ReturnType<typeof boot>;
  beforeEach(() => { env = boot(); });

  it("shows the home and renders the six tiles", () => {
    const view = toViewModel(initialState());
    (env.win as any).render(view);
    const doc = env.win.document;
    expect((doc.getElementById("home") as any).hidden).toBe(false);
    expect((doc.getElementById("loop") as any).hidden).toBe(true);
    expect(doc.querySelectorAll("#workflows [data-launch]").length).toBe(6);
  });

  it("shows the loop screen when the view is loop", () => {
    const view = toViewModel(startLaunch(initialState(), "build"));
    (env.win as any).render(view);
    expect((env.win.document.getElementById("home") as any).hidden).toBe(true);
    expect((env.win.document.getElementById("loop") as any).hidden).toBe(false);
  });

  it("sends a launch frame when a tile is clicked", () => {
    (env.win as any).render(toViewModel(initialState()));
    const tile = env.win.document.querySelector('#workflows [data-launch="review"]') as any;
    tile.click();
    expect(env.sent).toContainEqual({ type: "launch", workflowId: "review" });
  });
});
