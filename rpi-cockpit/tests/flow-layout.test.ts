import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

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
const layout = (win: any, nodes: any[], edges: any[]) => win.computeFlowLayout(nodes, edges);
const N = (id: string) => ({ id, scope: "orchestration", kind: "workflow", label: id, status: "idle" });
const E = (id: string, from: string, to: string) => ({ id, from, to, scope: "orchestration", kind: "label", status: "idle" });

describe("computeFlowLayout", () => {
  let win: any;
  beforeEach(() => { win = boot(); });

  it("lays a linear chain into increasing columns", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "b", "c")]);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.x).toBeLessThan(pos.c.x);
  });

  it("places fan-out targets in the same later column, different rows", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "a", "c")]);
    expect(pos.b.x).toBe(pos.c.x);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.y).not.toBe(pos.c.y);
  });

  it("tolerates a back edge: forward layering is unchanged and it terminates", () => {
    const pos = layout(win, [N("a"), N("b"), N("c")], [E("e1", "a", "b"), E("e2", "b", "c"), E("e3", "c", "a")]);
    expect(pos.a.x).toBeLessThan(pos.b.x);
    expect(pos.b.x).toBeLessThan(pos.c.x);
  });
});
