// rpi-cockpit/src/live.ts
// The file-backed cross-process bridge. The producer (MCP server) writes
// state.json and tails inbox.jsonl; the consumer (`dist/index.js live`) mirrors
// state.json into a holder bridge and appends user intents to inbox.jsonl.
import fs from "node:fs";
import { mkdirSync, appendFileSync, readFileSync, readSync, openSync, closeSync, fstatSync, statSync } from "node:fs";
import { join } from "node:path";
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { initialState, type SessionState } from "./state.js";
import { parseInbound, applyInbound, type InboundFrame } from "./inbound.js";

// Consumer: serve the cockpit UI in embed mode, mirror state.json into a holder
// bridge, and route inbound frames to inbox.jsonl for the producer to apply.
export async function runLiveConsumer(
  opts: { stateDir: string; port: number },
): Promise<{ port: number; url: string; close: () => Promise<void> }> {
  const { stateDir, port } = opts;
  mkdirSync(stateDir, { recursive: true });

  // A holder bridge: not authoritative. It only carries the latest snapshot to
  // connected pane clients via the server's broadcast on "state".
  const bridge = new Bridge();
  const stateFile = join(stateDir, "state.json");
  const inboxFile = join(stateDir, "inbox.jsonl");

  // Route every inbound frame to inbox.jsonl instead of mutating the holder.
  const appendInbox = (f: InboundFrame): void => {
    try { appendFileSync(inboxFile, JSON.stringify(f) + "\n"); } catch { /* best-effort */ }
  };

  const srv = await startServer(bridge, port, {
    trustLoopback: true,
    stateDir,
    onInbound: appendInbox,
  });

  // Load the snapshot off disk and broadcast it to pane clients. Guard the read
  // and parse so a missing or half-written file is simply skipped.
  const load = (): void => {
    try {
      // Merge over initialState so a snapshot written by an older producer (missing
      // fields a newer view-model reads, e.g. galleryItems) is backfilled, not a crash.
      const parsed = JSON.parse(readFileSync(stateFile, "utf8")) as Partial<SessionState>;
      const st = { ...initialState(), ...parsed } as SessionState;
      bridge.state = st;
      bridge.emit("state", st);
    } catch { /* no snapshot yet, or mid-write; try again on the next tick */ }
  };
  load();
  // Polling watch for cross-platform reliability (fs.watch misses on some hosts).
  fs.watchFile(stateFile, { interval: 150 }, load);

  return {
    port: srv.port,
    url: srv.url,
    close: async () => {
      fs.unwatchFile(stateFile, load);
      await srv.close();
    },
  };
}

// Producer: tail inbox.jsonl from a byte offset, applying each complete line to
// the agent's authoritative bridge. A partial trailing line is buffered until the
// rest of it is appended.
export function tailInbox(stateDir: string, bridge: Bridge): { stop: () => void } {
  const inboxFile = join(stateDir, "inbox.jsonl");
  // Seek to the end on startup: a producer (re)start must not replay intents the
  // user steered in an earlier session. Only frames appended after we begin
  // tailing are applied. inbox.jsonl is strictly append-only, so the current
  // size is exactly "everything so far".
  let offset = ((): number => { try { return statSync(inboxFile).size; } catch { return 0; } })();
  let buffer = "";

  const check = (): void => {
    try {
      const fd = openSync(inboxFile, "r");
      try {
        const size = fstatSync(fd).size;
        if (size <= offset) {
          // File truncated/replaced shorter than our offset: reset to re-read.
          if (size < offset) { offset = 0; buffer = ""; }
          else return;
        }
        const len = size - offset;
        const buf = Buffer.alloc(len);
        const read = readSync(fd, buf, 0, len, offset);
        offset += read;
        buffer += buf.toString("utf8", 0, read);
      } finally {
        closeSync(fd);
      }
    } catch { return; } // file not present yet, or transient fs error

    // Split into complete lines; keep the trailing partial for next time.
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (line.trim() === "") continue;
      let parsed: unknown;
      try { parsed = JSON.parse(line); } catch { continue; }
      const f = parseInbound(parsed);
      if (f) applyInbound(bridge, f);
    }
  };

  check();
  fs.watchFile(inboxFile, { interval: 150 }, check);

  return { stop: () => fs.unwatchFile(inboxFile, check) };
}
