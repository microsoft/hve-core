// rpi-cockpit/src/server.ts
import http from "node:http";
import crypto from "node:crypto";
import os from "node:os";
import { readFile, mkdir, appendFile } from "node:fs/promises";
import { writeFileSync, renameSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer, type WebSocket } from "ws";
import type { Bridge } from "./bridge.js";
import type { SessionState } from "./state.js";
import { toViewModel } from "./render.js";
import type { Directive } from "./events.js";
import { parseInbound, applyInbound, type InboundFrame } from "./inbound.js";

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

export async function startServer(
  bridge: Bridge,
  port = 4399,
  opts?: {
    stateDir?: string;
    trustLoopback?: boolean;
    // Producer-only: when true, atomically rewrite <stateDir>/state.json on every
    // bridge "state" event so the live consumer process can mirror it. Off by
    // default; existing callers and tests are unchanged.
    writeStateSnapshot?: boolean;
    // Consumer-only: when provided, recognized inbound WS frames are handed to
    // this callback (the consumer routes them to inbox.jsonl) instead of driving
    // the local bridge. Off by default; the WS handler drives the bridge as before.
    onInbound?: (f: InboundFrame) => void;
  },
) {
  // Embed mode: when a trusted host (the Claude Preview pane or a VS Code
  // webview) launches and owns this server, it loads the bare root URL, which
  // the token gate would 403. Opting into trustLoopback skips the token check on
  // both the HTTP gate and the WS upgrade so the pane loads with no key. The
  // Origin check below is KEPT in both modes, so a browser still cannot drive a
  // cross-origin connection. Trade-off: embed mode trusts ANY loopback client,
  // which is the host-managed-pane trust boundary — anyone who can already reach
  // 127.0.0.1 on this port is treated as the user. Secure default is unchanged:
  // with the flag off, the per-session token is still required.
  const trustLoopback = opts?.trustLoopback ?? Boolean(process.env.RPI_COCKPIT_TRUST_LOOPBACK);
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
    // HTTP gate: before any file serving, require a valid token (query or cookie),
    // UNLESS embed mode trusts the loopback pane, in which case the bare root and
    // assets are served without a key.
    if (!trustLoopback && !isAuthorized(req.url, req.headers.cookie)) {
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
      // In embed mode the token is waived, but the Origin check is NOT: a browser
      // still must present an Origin matching this server's own host (or none, as
      // non-browser clients do), which defeats cross-origin / DNS-rebinding.
      const tokenOk = trustLoopback || isAuthorized(info.req.url, info.req.headers.cookie);
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
      // Validate once, in one place (shared with the producer's inbox tailer).
      const f = parseInbound(msg);
      if (!f) return;
      // Consumer mode routes the frame elsewhere (to inbox.jsonl); otherwise the
      // frame drives this server's bridge exactly as the inline chain used to.
      if (opts?.onInbound) opts.onInbound(f);
      else applyInbound(bridge, f);
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

  // Producer snapshot: atomically rewrite state.json on every state change so the
  // live consumer process always reads a complete file. Write to a temp path then
  // rename (rename is atomic on the same filesystem). Synchronous so concurrent
  // state events cannot interleave a half-written file. Off by default.
  let onSnapshot: ((state: SessionState) => void) | null = null;
  if (opts?.writeStateSnapshot) {
    const statePath = path.join(stateDir, "state.json");
    const tmpPath = path.join(stateDir, "state.json.tmp");
    onSnapshot = (state: SessionState) => {
      try {
        writeFileSync(tmpPath, JSON.stringify(state));
        renameSync(tmpPath, statePath);
      } catch { /* never throw into the event path */ }
    };
    bridge.on("state", onSnapshot);
    // Seed the file with the current state so a consumer that connects before the
    // first beat still has a snapshot to render.
    onSnapshot(bridge.state);
  }

  return {
    port: addr.port,
    token,
    url,
    stateDir,
    close: () => new Promise<void>((resolve, reject) => {
      bridge.off("state", broadcast);
      bridge.off("directive", onDirective);
      bridge.off("decision", onDecision);
      if (onSnapshot) bridge.off("state", onSnapshot);
      wss.close((err) => {
        if (err) return reject(err);
        httpServer.close((e) => (e ? reject(e) : resolve()));
      });
    }),
  };
}
