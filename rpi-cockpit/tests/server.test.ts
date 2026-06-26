// rpi-cockpit/tests/server.test.ts
import { describe, it, expect, afterEach } from "vitest";
import http from "node:http";
import WebSocket from "ws";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

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
    const id = bridge.state.pendingDecision!.id;
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
    ws.send(JSON.stringify({ type: "decide", id: bridge.state.pendingDecision!.id, choiceId: "a" }));
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
      ws.send(JSON.stringify({ type: "decide", id: bridge.state.pendingDecision!.id, choiceId: "a" }));
      expect(await choice).toBe("a");
      ws.close();
    });
  });
});
