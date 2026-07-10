// rpi-cockpit/tests/server.test.ts
import { describe, it, expect, afterEach } from "vitest";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { existsSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import WebSocket from "ws";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

// Unique temp dir per test; Date.now()/pid avoids Math.random (banned in src,
// fine for test fixtures).
function tempDir(tag: string): string {
  const dir = path.join(os.tmpdir(), `rpi-cockpit-test-${tag}-${process.pid}-${Date.now()}`);
  mkdirSync(dir, { recursive: true });
  return dir;
}

// Minimal HTTP GET helper: returns status, headers, and body for an assertion.
function get(
  port: number,
  pathname: string,
  headers: http.OutgoingHttpHeaders = {},
): Promise<{ status: number; headers: http.IncomingHttpHeaders; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { host: "127.0.0.1", port, path: pathname, method: "GET", headers },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (c) => chunks.push(c as Buffer));
        res.on("end", () =>
          resolve({ status: res.statusCode ?? 0, headers: res.headers, body: Buffer.concat(chunks).toString("utf8") }),
        );
      },
    );
    req.on("error", reject);
    req.end();
  });
}

describe("server", () => {
  it("pushes state on connect and round-trips a decision", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    const first = await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    expect(first.type).toBe("state");

    const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }]);
    await new Promise((r) => setTimeout(r, 20));
    const id = bridge.state.decisions.at(-1)!.id;
    ws.send(JSON.stringify({ type: "decide", id, choiceId: "a" }));
    expect(await choice).toBe("a");
    ws.close();
  });

  it("ignores a malformed inbound frame without crashing", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise((r) => ws.on("open", r));
    ws.send("this is not json");
    const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }]);
    await new Promise((r) => setTimeout(r, 20));
    ws.send(JSON.stringify({ type: "decide", id: bridge.state.decisions.at(-1)!.id, choiceId: "a" }));
    expect(await choice).toBe("a");
    ws.close();
  });

  it("includes a view model in the pushed frame", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    const first = await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    expect(first.view.started).toBe(false);
    expect(first.view.steerMenu.source).toBe("preset");
    ws.close();
  });

  it("enqueues a directive from an inbound steer frame", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise((r) => ws.on("open", r));
    ws.send(JSON.stringify({ type: "steer", directive: { kind: "note", text: "focus on errors" } }));
    await new Promise((r) => setTimeout(r, 30));
    expect(bridge.state.directives).toHaveLength(1);
    expect(bridge.state.directives[0]).toMatchObject({ kind: "note", text: "focus on errors" });
    ws.close();
  });

  it("enqueues a directive from an inbound intervene frame", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise((r) => ws.on("open", r));
    ws.send(JSON.stringify({ type: "intervene", action: "pause", agentId: "a1" }));
    await new Promise((r) => setTimeout(r, 30));
    expect(bridge.state.directives).toHaveLength(1);
    const d = bridge.state.directives[0];
    expect(d.kind).toBe("note");
    if (d.kind === "note") {
      expect(d.text).toContain("pause");
      expect(d.text).toContain("a1");
    }
    ws.close();
  });

  it("ignores an intervene frame with an invalid action", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise((r) => ws.on("open", r));
    ws.send(JSON.stringify({ type: "intervene", action: "delete", agentId: "a1" }));
    await new Promise((r) => setTimeout(r, 30));
    expect(bridge.state.directives).toHaveLength(0);
    ws.close();
  });

  describe("auth", () => {
    it("mints a per-session token and a keyed url in the return", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      expect(typeof srv.token).toBe("string");
      expect(srv.token).toMatch(/^[0-9a-f]{64}$/); // randomBytes(32) hex
      expect(srv.url).toBe(`http://127.0.0.1:${srv.port}/?key=${srv.token}`);
    });

    it("HTTP GET / with no key and no cookie -> 403, serves no file", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, "/");
      expect(res.status).toBe(403);
      expect(res.body).not.toContain("client.js"); // did not serve index.html
      expect(res.body.toLowerCase()).toContain("key="); // tells user to open the keyed url
    });

    it("HTTP GET /?key=<token> -> 200 index.html with a hardened Set-Cookie", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, `/?key=${srv.token}`);
      expect(res.status).toBe(200);
      expect(res.body.toLowerCase()).toContain("<!doctype html");
      const setCookie = String(res.headers["set-cookie"] ?? "");
      expect(setCookie).toContain(`rpi-cockpit-key-${srv.port}=${srv.token}`);
      expect(setCookie).toContain("HttpOnly");
      expect(setCookie).toContain("SameSite=Strict");
      expect(setCookie).toContain("Path=/");
    });

    it("HTTP GET /?key=<wrong> -> 403", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, `/?key=deadbeef`);
      expect(res.status).toBe(403);
    });

    it("HTTP GET /client.js with the cookie -> 200", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, "/client.js", { cookie: `rpi-cockpit-key-${srv.port}=${srv.token}` });
      expect(res.status).toBe(200);
      expect(res.body).toContain("WebSocket");
    });

    it("WS connect with no key -> rejected (never opens)", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
      const opened = await new Promise<boolean>((resolve) => {
        ws.on("open", () => resolve(true));
        ws.on("error", () => resolve(false));
        ws.on("close", () => resolve(false));
      });
      expect(opened).toBe(false);
      try { ws.close(); } catch { /* already closed */ }
    });

    it("WS connect with ?key=<token> -> opens and receives initial state", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
      const first = await new Promise<any>((res, rej) => {
        ws.on("message", (d) => res(JSON.parse(String(d))));
        ws.on("error", rej);
      });
      expect(first.type).toBe("state");
      ws.close();
    });

    it("WS connect with a present but WRONG Origin -> rejected", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`, {
        headers: { origin: "http://evil.example" },
      });
      const opened = await new Promise<boolean>((resolve) => {
        ws.on("open", () => resolve(true));
        ws.on("error", () => resolve(false));
        ws.on("close", () => resolve(false));
      });
      expect(opened).toBe(false);
      try { ws.close(); } catch { /* already closed */ }
    });

    it("WS connect with a matching Origin + key -> accepted", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`, {
        headers: { origin: `http://127.0.0.1:${srv.port}` },
      });
      const first = await new Promise<any>((res, rej) => {
        ws.on("message", (d) => res(JSON.parse(String(d))));
        ws.on("error", rej);
      });
      expect(first.type).toBe("state");
      ws.close();
    });

    it("a decide frame over an authorized WS still resolves the decision", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
      await new Promise((r) => ws.on("open", r));
      const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }]);
      await new Promise((r) => setTimeout(r, 20));
      ws.send(JSON.stringify({ type: "decide", id: bridge.state.decisions.at(-1)!.id, choiceId: "a" }));
      expect(await choice).toBe("a");
      ws.close();
    });
  });

  it("a launch frame enqueues a directive and flips the view to loop", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    const settled = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "launch", workflowId: "build" }));
    await settled;
    expect(bridge.state.view).toBe("loop");
    expect(bridge.state.activeWorkflow).toBe("build");
    expect(bridge.state.directives).toHaveLength(1);
    expect(bridge.state.directives[0]).toMatchObject({ kind: "approach", value: "build" });
    ws.close();
  });

  it("an answer frame resolves a pending question", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const p = bridge.askQuestion("Q?", 0);
    const qid = bridge.state.decisions.at(-1)!.id;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    const settled = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "answer", id: qid, text: "answered" }));
    await settled;
    expect(await p).toBe("answered");
    ws.close();
  });

  it("a navigator frame opens and closes the navigator", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    const opened = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "navigator", open: true }));
    await opened;
    expect(bridge.state.navigatorOpen).toBe(true);
    const closed = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "navigator", open: false }));
    await closed;
    expect(bridge.state.navigatorOpen).toBe(false);
    ws.close();
  });

  it("a navigate frame sets the view", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    bridge.navigate("loop");
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    const settled = new Promise<void>((res) => bridge.once("state", () => res()));
    ws.send(JSON.stringify({ type: "navigate", screen: "home" }));
    await settled;
    expect(bridge.state.view).toBe("home");
    ws.close();
  });

  describe("embed mode (trustLoopback)", () => {
    it("HTTP GET / with no key and no cookie -> 200 index.html", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const res = await get(srv.port, "/");
      expect(res.status).toBe(200);
      expect(res.body.toLowerCase()).toContain("<!doctype html");
    });

    it("the keyed path still serves 200 with trustLoopback on", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const res = await get(srv.port, `/?key=${srv.token}`);
      expect(res.status).toBe(200);
      expect(res.body.toLowerCase()).toContain("<!doctype html");
    });

    it("the secure default (no flag) still 403s GET / with no key", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0);
      stop = srv.close;
      const res = await get(srv.port, "/");
      expect(res.status).toBe(403);
    });

    it("WS connect with NO key -> opens and receives initial state", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
      const first = await new Promise<any>((res, rej) => {
        ws.on("message", (d) => res(JSON.parse(String(d))));
        ws.on("error", rej);
      });
      expect(first.type).toBe("state");
      ws.close();
    });

    it("WS connect with a WRONG Origin is still rejected in embed mode", async () => {
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { trustLoopback: true });
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`, {
        headers: { origin: "http://evil.example" },
      });
      const opened = await new Promise<boolean>((resolve) => {
        ws.on("open", () => resolve(true));
        ws.on("error", () => resolve(false));
        ws.on("close", () => resolve(false));
      });
      expect(opened).toBe(false);
      try { ws.close(); } catch { /* already closed */ }
    });
  });

  describe("writeStateSnapshot (producer)", () => {
    it("writes state.json atomically that round-trips the bridge state", async () => {
      const dir = tempDir("snapshot");
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { stateDir: dir, writeStateSnapshot: true });
      stop = async () => { await srv.close(); rmSync(dir, { recursive: true, force: true }); };
      bridge.emitBeat({ type: "session.begin", task: "snap task", host: "claude-code" });
      // Synchronous write happens inside the emit, so the file is already there.
      const statePath = path.join(dir, "state.json");
      expect(existsSync(statePath)).toBe(true);
      const parsed = JSON.parse(readFileSync(statePath, "utf8"));
      expect(parsed.task).toBe("snap task");
      expect(parsed.domain).toBe(bridge.state.domain);
      expect(parsed.task).toBe(bridge.state.task);
      // No half-written temp left behind after a successful rename.
      expect(existsSync(path.join(dir, "state.json.tmp"))).toBe(false);
    });

    it("is OFF by default: no state.json without the flag", async () => {
      const dir = tempDir("nosnap");
      const bridge = new Bridge();
      const srv = await startServer(bridge, 0, { stateDir: dir });
      stop = async () => { await srv.close(); rmSync(dir, { recursive: true, force: true }); };
      bridge.emitBeat({ type: "session.begin", task: "x", host: "h" });
      expect(existsSync(path.join(dir, "state.json"))).toBe(false);
    });
  });

  describe("onInbound (consumer routing)", () => {
    it("hands inbound frames to the callback and does NOT mutate the bridge", async () => {
      const bridge = new Bridge();
      const received: unknown[] = [];
      const srv = await startServer(bridge, 0, { onInbound: (f) => received.push(f) });
      stop = srv.close;
      const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
      await new Promise((r) => ws.on("open", r));
      ws.send(JSON.stringify({ type: "steer", directive: { kind: "note", text: "to inbox" } }));
      await new Promise((r) => setTimeout(r, 40));
      expect(received).toHaveLength(1);
      expect(received[0]).toEqual({ type: "steer", directive: { kind: "note", text: "to inbox" } });
      // The bridge was NOT driven: the directive went to the callback only.
      expect(bridge.state.directives).toHaveLength(0);
      ws.close();
    });
  });
});
