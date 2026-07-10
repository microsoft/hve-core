// rpi-cockpit/tests/e2e.test.ts
import { describe, it, expect, afterEach } from "vitest";
import WebSocket from "ws";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";
import { buildMcpServer } from "../src/mcp.js";

async function waitFor(pred: () => boolean, timeout = 2000): Promise<void> {
  const start = Date.now();
  while (!pred()) {
    if (Date.now() - start > timeout) throw new Error("waitFor: condition not met in time");
    await new Promise((r) => setTimeout(r, 5));
  }
}

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

describe("end to end", () => {
  it("an MCP beat reaches the browser and a decision round-trips", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const server = buildMcpServer(bridge);
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await server.connect(st);
    const client = new Client({ name: "t", version: "0" });
    await client.connect(ct);

    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/?key=${srv.token}`);
    const states: any[] = [];
    ws.on("message", (d) => states.push(JSON.parse(String(d))));
    await new Promise((r) => ws.on("open", r));

    await client.callTool({ name: "phase_enter", arguments: { phase: "implement" } });
    await waitFor(() => states.at(-1)?.state?.phase === "implement");
    expect(states.at(-1).state.phase).toBe("implement");

    const call = client.callTool({ name: "present_options", arguments: { prompt: "pick", options: [{ id: "a", title: "A" }] } });
    await waitFor(() => bridge.state.decisions.some((d) => d.status === "pending"));
    ws.send(JSON.stringify({ type: "decide", id: bridge.state.decisions.at(-1)!.id, choiceId: "a" }));
    const res: any = await call;
    expect(res.content[0].text).toBe("a");
    ws.close();
  });
});
