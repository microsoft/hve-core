// rpi-cockpit/src/server.ts
import http from "node:http";
import crypto from "node:crypto";
import os from "node:os";
import { readFile, mkdir, appendFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer, type WebSocket } from "ws";
import type { Bridge } from "./bridge.js";
import type { SessionState } from "./state.js";
import { toViewModel } from "./render.js";
import { SteerMsg } from "./events.js";
import type { Directive } from "./events.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");
const TYPES: Record<string, string> = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

// Constant-time token comparison. Guard length first: timingSafeEqual throws on
// unequal-length buffers, and an early length check is itself not secret-leaking.
function tokenMatches(candidate: string | null | undefined, token: string): boolean {
  if (typeof candidate !== "string") return false;
  const a = Buffer.from(candidate);
  const b = Buffer.from(token);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

// Pull a value from a Cookie header. Cookies are name=value pairs joined by "; ".
function readCookie(cookieHeader: string | undefined, name: string): string | null {
  if (!cookieHeader) return null;
  for (const part of cookieHeader.split(";")) {
    const eq = part.indexOf("=");
    if (eq === -1) continue;
    if (part.slice(0, eq).trim() === name) return part.slice(eq + 1).trim();
  }
  return null;
}

export async function startServer(bridge: Bridge, port = 4399, opts?: { stateDir?: string }) {
  // Per-session token: minted in-memory each run, never persisted. Fail closed —
  // it is always present, so every HTTP request and WS upgrade is gated.
  const token = crypto.randomBytes(32).toString("hex");
  // Cookie name is port-scoped so multiple cockpits on one host don't collide.
  let cookieName = `rpi-cockpit-key-${port}`;

  // Authorized if the request carries the token as ?key=<token> OR as the cookie.
  const isAuthorized = (url: string | undefined, cookieHeader: string | undefined): boolean => {
    const keyFromQuery = url ? new URL(url, "http://localhost").searchParams.get("key") : null;
    if (tokenMatches(keyFromQuery, token)) return true;
    return tokenMatches(readCookie(cookieHeader, cookieName), token);
  };

  const httpServer = http.createServer(async (req, res) => {
    // HTTP gate: before any file serving, require a valid token (query or cookie).
    if (!isAuthorized(req.url, req.headers.cookie)) {
      res.writeHead(403, { "content-type": "text/html" });
      res.end("<!doctype html><meta charset=utf-8><title>RPI Cockpit</title>" +
        "<p>Unauthorized. Open the full cockpit URL including <code>?key=…</code> printed on startup.</p>");
      return;
    }

    // On a valid ?key=, mirror the token into a hardened cookie so subsequent
    // asset and WS requests authenticate without the query string.
    const keyFromQuery = req.url ? new URL(req.url, "http://localhost").searchParams.get("key") : null;
    if (tokenMatches(keyFromQuery, token)) {
      res.setHeader("Set-Cookie", `${cookieName}=${token}; HttpOnly; SameSite=Strict; Path=/`);
    }

    // Strip the query first, then map the bare root to index.html. (A ?key= on
    // "/" means req.url is "/?key=…", which is not literally "/".)
    const pathname = (req.url ?? "/").split("?")[0];
    const rel = pathname === "/" ? "/index.html" : pathname;
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

  // WS gate: reject unauthorized upgrades BEFORE the handshake completes.
  // Authorized = valid token (query or cookie) AND an acceptable Origin. The
  // Origin check defeats cross-origin-localhost / DNS-rebinding from a browser:
  // a non-browser client (e.g. tests) sends no Origin and is allowed; a browser
  // must present Origin exactly matching this server's own host.
  const wss = new WebSocketServer({
    server: httpServer,
    verifyClient: (info, cb) => {
      const tokenOk = isAuthorized(info.req.url, info.req.headers.cookie);
      const origin = info.req.headers.origin;
      const originOk = !origin || origin === "http://" + info.req.headers.host;
      if (tokenOk && originOk) cb(true);
      else cb(false, 401);
    },
  });
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
  // The bound port may differ from the requested one (ephemeral fallback); scope
  // the cookie name to whatever port we actually bound so it always matches.
  cookieName = `rpi-cockpit-key-${addr.port}`;
  const url = "http://127.0.0.1:" + addr.port + "/?key=" + token;

  // File sink: durable, append-only record the agent can read WITHOUT the MCP
  // server connected. Resolve against the bound port so the default is stable.
  const stateDir = opts?.stateDir
    ?? process.env.RPI_COCKPIT_STATE_DIR
    ?? path.join(os.tmpdir(), "rpi-cockpit", String(addr.port));
  // Best-effort create; if it fails the appends below just no-op on their own.
  await mkdir(stateDir, { recursive: true }).catch(() => {});
  // Append one JSON record per line. Never let an fs error escape into the
  // event path — swallow and continue so narration is unaffected.
  const append = (file: string, record: unknown): void => {
    appendFile(path.join(stateDir, file), JSON.stringify(record) + "\n").catch(() => {});
  };
  const onDirective = (d: Directive) => append("directives.jsonl", { ...d, ts: Date.now() });
  const onDecision = (x: { id: string; choiceId: string; prompt?: string }) =>
    append("decisions.jsonl", { ...x, ts: Date.now() });
  bridge.on("directive", onDirective);
  bridge.on("decision", onDecision);

  return {
    port: addr.port,
    token,
    url,
    stateDir,
    close: () => new Promise<void>((resolve, reject) => {
      bridge.off("state", broadcast);
      bridge.off("directive", onDirective);
      bridge.off("decision", onDecision);
      wss.close((err) => {
        if (err) return reject(err);
        httpServer.close((e) => (e ? reject(e) : resolve()));
      });
    }),
  };
}
