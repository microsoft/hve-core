// rpi-cockpit/tests/filesink.test.ts
import { describe, it, expect, afterEach } from "vitest";
import { readFile } from "node:fs/promises";
import { mkdtemp } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

// Read a JSONL file and parse each non-empty line into an object.
async function readJsonl(file: string): Promise<any[]> {
  const text = await readFile(file, "utf8");
  return text.split("\n").filter((l) => l.trim().length > 0).map((l) => JSON.parse(l));
}

// Poll until a predicate holds (the fs append is async + best-effort).
async function until(pred: () => Promise<boolean>, ms = 500): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < ms) {
    if (await pred()) return;
    await new Promise((r) => setTimeout(r, 10));
  }
}

describe("file sink", () => {
  it("returns the resolved stateDir from startServer", async () => {
    const dir = await mkdtemp(path.join(os.tmpdir(), "rpi-sink-"));
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0, { stateDir: dir });
    stop = srv.close;
    expect(srv.stateDir).toBe(dir);
  });

  it("defaults the stateDir under os.tmpdir()/rpi-cockpit/<port> with no opt or env", async () => {
    const prev = process.env.RPI_COCKPIT_STATE_DIR;
    delete process.env.RPI_COCKPIT_STATE_DIR;
    try {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      expect(srv.stateDir).toBe(path.join(os.tmpdir(), "rpi-cockpit", String(srv.port)));
    } finally {
      if (prev !== undefined) process.env.RPI_COCKPIT_STATE_DIR = prev;
    }
  });

  it("appends one JSON line with a numeric ts to directives.jsonl on enqueue", async () => {
    const dir = await mkdtemp(path.join(os.tmpdir(), "rpi-sink-"));
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0, { stateDir: dir });
    stop = srv.close;

    bridge.enqueueDirective({ kind: "note", text: "focus on errors" });

    const file = path.join(dir, "directives.jsonl");
    await until(async () => {
      try { return (await readJsonl(file)).length === 1; } catch { return false; }
    });
    const rows = await readJsonl(file);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ kind: "note", text: "focus on errors" });
    expect(rows[0].id).toMatch(/^s\d+$/);
    expect(typeof rows[0].ts).toBe("number");
  });

  it("appends the {id, choiceId} line to decisions.jsonl on a resolved decision", async () => {
    const dir = await mkdtemp(path.join(os.tmpdir(), "rpi-sink-"));
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0, { stateDir: dir });
    stop = srv.close;

    const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B" }]);
    const id = bridge.state.pendingDecision!.id;
    bridge.resolveDecision(id, "b");
    expect(await choice).toBe("b");

    const file = path.join(dir, "decisions.jsonl");
    await until(async () => {
      try { return (await readJsonl(file)).length === 1; } catch { return false; }
    });
    const rows = await readJsonl(file);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ id, choiceId: "b" });
    expect(typeof rows[0].ts).toBe("number");
  });

  it("removes the sink listeners on close (a post-close enqueue does not append)", async () => {
    const dir = await mkdtemp(path.join(os.tmpdir(), "rpi-sink-"));
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0, { stateDir: dir });

    // First enqueue lands while the server is up.
    bridge.enqueueDirective({ kind: "note", text: "before close" });
    const file = path.join(dir, "directives.jsonl");
    await until(async () => {
      try { return (await readJsonl(file)).length === 1; } catch { return false; }
    });

    await srv.close();
    stop = null;

    // After close, the sink listener must be gone — no second line appears.
    bridge.enqueueDirective({ kind: "note", text: "after close" });
    await new Promise((r) => setTimeout(r, 60));
    const rows = await readJsonl(file);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ text: "before close" });
  });
});
