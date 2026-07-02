#!/usr/bin/env node
// rpi-cockpit/src/index.ts
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { buildMcpServer, connectStdio } from "./mcp.js";
import { runInit, type InitHost } from "./init.js";
import { resolvePort } from "./port.js";
import { liveStateDir } from "./paths.js";
import { runLiveConsumer, tailInbox } from "./live.js";

// Compute the repo root once. dist/index.js -> rpi-cockpit -> repo root.
const entryPath = fileURLToPath(import.meta.url);
const root = resolve(dirname(entryPath), "..", "..");

// `rpi-cockpit init [--host claude|codex|vscode|all] [--codex-global]` wires the
// MCP server into the host surfaces and regenerates the narration contract.
// This MUST run before the MCP server starts; otherwise behave exactly as before.
if (process.argv[2] === "init") {
  const argv = process.argv.slice(3);
  let host: InitHost = "all";
  let codexGlobal = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--host") {
      const v = argv[++i];
      if (v === "claude" || v === "codex" || v === "vscode" || v === "all") host = v;
    } else if (a.startsWith("--host=")) {
      const v = a.slice("--host=".length);
      if (v === "claude" || v === "codex" || v === "vscode" || v === "all") host = v;
    } else if (a === "--codex-global") {
      codexGlobal = true;
    }
  }

  const contractPath = resolve(root, "rpi-cockpit", "agents", "cockpit-instructions.md");

  const result = runInit({
    root,
    entryPath,
    contractPath,
    host,
    codexGlobal,
    homeDir: homedir(),
  });
  process.stdout.write(result.summary + "\n");
  process.exit(0);
}

// `rpi-cockpit live` is the consumer pane (run by the host's .claude/launch.json):
// it mirrors the producer's state.json and routes user intents back via inbox.jsonl.
// It holds no authoritative state and never connects the MCP transport.
if (process.argv[2] === "live") {
  const stateDir = process.env.RPI_COCKPIT_STATE_DIR ?? liveStateDir(root);
  const port = resolvePort(process.env);
  const srv = await runLiveConsumer({ stateDir, port });
  process.stderr.write(`rpi-cockpit live pane: ${srv.url} (state dir ${stateDir})\n`);
  // Keep the process (and the pane server) alive.
  setInterval(() => {}, 1 << 30);
} else {
  const bridge = new Bridge();
  const port = resolvePort(process.env);
  // The producer and consumer derive the SAME shared dir from the repo root so the
  // file bridge lines up across the two processes a host launches.
  const stateDir = process.env.RPI_COCKPIT_STATE_DIR ?? liveStateDir(root);

  // The UI server is best-effort: if it cannot bind, narration must still work,
  // so the MCP stdio transport connects regardless of the server's outcome.
  try {
    const srv = await startServer(bridge, port, { stateDir, writeStateSnapshot: true });
    // Print the KEYED url: the per-session token must be carried as ?key=… or the
    // HTTP/WS gates reject the connection. Without it the cockpit is unreachable.
    process.stderr.write(`rpi-cockpit: ${srv.url}\n`);
    // Also print the state dir: a host without the MCP connected can still read
    // the user's steering from <state-dir>/directives.jsonl and decisions.jsonl.
    process.stderr.write(`rpi-cockpit: state dir ${srv.stateDir}\n`);
    // Tail the consumer's inbox so live-pane intents reach the agent's bridge.
    // Only when the server bound; if it threw, MCP narration still works below.
    tailInbox(stateDir, bridge);
  } catch (err) {
    const m = err instanceof Error ? err.message : String(err);
    process.stderr.write(`rpi-cockpit: UI server unavailable (${m}); MCP narration still active.\n`);
  }

  await connectStdio(buildMcpServer(bridge));
}
