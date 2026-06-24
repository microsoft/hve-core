// rpi-cockpit/src/server.ts
import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer, type WebSocket } from "ws";
import type { Bridge } from "./bridge.js";
import type { SessionState } from "./state.js";
import { toViewModel } from "./render.js";
import { SteerMsg } from "./events.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");
const TYPES: Record<string, string> = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

export async function startServer(bridge: Bridge, port = 4399) {
  const httpServer = http.createServer(async (req, res) => {
    const rel = (req.url === "/" || !req.url ? "/index.html" : req.url).split("?")[0];
    const abs = path.join(PUBLIC, rel);
    if (abs !== PUBLIC && !abs.startsWith(PUBLIC + path.sep)) {
      res.writeHead(403); res.end("forbidden"); return;
    }
    try {
      const file = await readFile(abs);
      res.writeHead(200, { "content-type": TYPES[path.extname(abs)] ?? "application/octet-stream" });
      res.end(file);
    } catch {
      res.writeHead(404); res.end("not found");
    }
  });

  const wss = new WebSocketServer({ server: httpServer });
  const send = (ws: WebSocket, state: SessionState) => ws.send(JSON.stringify({ type: "state", state, view: toViewModel(state) }));
  wss.on("connection", (ws) => {
    send(ws, bridge.state);
    ws.on("message", (data) => {
      let msg: unknown;
      try { msg = JSON.parse(String(data)); } catch { return; }
      // Inbound frame types are mutually exclusive — keep the branches symmetric.
      if (msg && typeof msg === "object" && (msg as { type?: string }).type === "decide") {
        const m = msg as { id?: unknown; choiceId?: unknown };
        if (typeof m.id === "string" && typeof m.choiceId === "string") {
          bridge.resolveDecision(m.id, m.choiceId);
        }
      } else if (msg && typeof msg === "object" && (msg as { type?: string }).type === "steer") {
        const parsed = SteerMsg.safeParse(msg);
        if (parsed.success) bridge.enqueueDirective(parsed.data.directive);
      }
    });
  });
  const broadcast = (state: SessionState) => { for (const c of wss.clients) if (c.readyState === 1) send(c, state); };
  bridge.on("state", broadcast);

  // ws re-emits the underlying http server's "listening" and "error" events on
  // the WebSocketServer, so bind outcomes must be observed on wss to be caught.
  const listen = (p: number) =>
    new Promise<void>((resolve, reject) => {
      const onError = (err: NodeJS.ErrnoException) => { wss.off("listening", onListening); reject(err); };
      const onListening = () => { wss.off("error", onError); resolve(); };
      wss.once("error", onError);
      wss.once("listening", onListening);
      httpServer.listen(p, "127.0.0.1");
    });

  try {
    await listen(port);
  } catch (err) {
    if (port !== 0 && (err as NodeJS.ErrnoException).code === "EADDRINUSE") {
      await listen(0); // requested port taken; fall back to an ephemeral one
    } else {
      throw err;
    }
  }
  const addr = httpServer.address();
  if (!addr || typeof addr === "string") throw new Error("server did not bind a TCP port");
  return {
    port: addr.port,
    close: () => new Promise<void>((resolve, reject) => {
      bridge.off("state", broadcast);
      wss.close((err) => {
        if (err) return reject(err);
        httpServer.close((e) => (e ? reject(e) : resolve()));
      });
    }),
  };
}
