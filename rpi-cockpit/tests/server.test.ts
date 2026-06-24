// rpi-cockpit/tests/server.test.ts
import { describe, it, expect, afterEach } from "vitest";
import WebSocket from "ws";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

describe("server", () => {
  it("pushes state on connect and round-trips a decision", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
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
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
    await new Promise((r) => ws.on("open", r));
    ws.send("this is not json");
    const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }]);
    await new Promise((r) => setTimeout(r, 20));
    ws.send(JSON.stringify({ type: "decide", id: bridge.state.pendingDecision!.id, choiceId: "a" }));
    expect(await choice).toBe("a");
    ws.close();
  });
});
