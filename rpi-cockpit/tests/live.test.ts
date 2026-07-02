// rpi-cockpit/tests/live.test.ts
import { describe, it, expect, afterEach } from "vitest";
import os from "node:os";
import path from "node:path";
import { mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import WebSocket from "ws";
import { Bridge } from "../src/bridge.js";
import { initialState } from "../src/state.js";
import { runLiveConsumer, tailInbox } from "../src/live.js";

// Cleanup registry: live servers to close and dirs to remove after each test.
const closers: (() => Promise<void> | void)[] = [];
const dirs: string[] = [];
afterEach(async () => {
  for (const c of closers.splice(0)) await c();
  for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true });
});

function tempDir(tag: string): string {
  const dir = path.join(os.tmpdir(), `rpi-cockpit-live-${tag}-${process.pid}-${Date.now()}-${dirs.length}`);
  mkdirSync(dir, { recursive: true });
  dirs.push(dir);
  return dir;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

describe("runLiveConsumer", () => {
  it("renders the state.json snapshot to a connecting client and reflects updates", async () => {
    const dir = tempDir("render");
    const st = { ...initialState(), task: "from file", host: "host-a", domain: "rpi" as const, view: "loop" as const };
    writeFileSync(path.join(dir, "state.json"), JSON.stringify(st));

    const srv = await runLiveConsumer({ stateDir: dir, port: 0 });
    closers.push(srv.close);

    const ws = new WebSocket(`${srv.url.replace("http", "ws")}`);
    const first = await new Promise<any>((res, rej) => {
      ws.on("message", (d) => res(JSON.parse(String(d))));
      ws.on("error", rej);
    });
    expect(first.type).toBe("state");
    expect(first.view.task).toBe("from file");
    expect(first.view.view).toBe("loop");

    // Update the file; the polling watch (150ms) should pick it up and broadcast.
    const next = new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    writeFileSync(path.join(dir, "state.json"), JSON.stringify({ ...st, task: "updated task" }));
    await sleep(350);
    const updated = await next;
    expect(updated.view.task).toBe("updated task");
    ws.close();
  });

  it("routes an inbound WS frame to inbox.jsonl instead of a local bridge", async () => {
    const dir = tempDir("route");
    const srv = await runLiveConsumer({ stateDir: dir, port: 0 });
    closers.push(srv.close);

    const ws = new WebSocket(`${srv.url.replace("http", "ws")}`);
    await new Promise((r) => ws.on("open", r));
    ws.send(JSON.stringify({ type: "steer", directive: { kind: "note", text: "to producer" } }));
    await sleep(60);
    ws.close();

    const inbox = readFileSync(path.join(dir, "inbox.jsonl"), "utf8").trim().split("\n");
    expect(inbox).toHaveLength(1);
    expect(JSON.parse(inbox[0])).toEqual({ type: "steer", directive: { kind: "note", text: "to producer" } });
  });
});

describe("tailInbox (producer)", () => {
  it("does not replay inbox lines that predate the tail (seek-to-end on startup)", async () => {
    const dir = tempDir("tail");
    const bridge = new Bridge();
    // A line present before tailing starts is from a prior session: a producer
    // (re)start must NOT re-apply it, or every historical intent would replay.
    writeFileSync(
      path.join(dir, "inbox.jsonl"),
      JSON.stringify({ type: "steer", directive: { kind: "note", text: "old" } }) + "\n",
    );
    const t = tailInbox(dir, bridge);
    closers.push(() => t.stop());
    await sleep(60);
    expect(bridge.state.directives).toHaveLength(0);
  });

  it("applies lines appended after tailing begins", async () => {
    const dir = tempDir("tail2");
    const bridge = new Bridge();
    writeFileSync(path.join(dir, "inbox.jsonl"), "");
    const t = tailInbox(dir, bridge);
    closers.push(() => t.stop());
    await sleep(60);
    expect(bridge.state.directives).toHaveLength(0);
    // Append a frame; the polling watch (150ms) should apply it.
    const { appendFileSync } = await import("node:fs");
    appendFileSync(
      path.join(dir, "inbox.jsonl"),
      JSON.stringify({ type: "navigator", open: true }) + "\n",
    );
    await sleep(350);
    expect(bridge.state.navigatorOpen).toBe(true);
  });
});
