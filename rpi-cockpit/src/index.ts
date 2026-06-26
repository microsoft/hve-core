#!/usr/bin/env node
// rpi-cockpit/src/index.ts
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { buildMcpServer, connectStdio } from "./mcp.js";
import { runInit, type InitHost } from "./init.js";

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

  const entryPath = fileURLToPath(import.meta.url);
  // dist/index.js -> rpi-cockpit -> repo root
  const root = resolve(dirname(entryPath), "..", "..");
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

const bridge = new Bridge();
const port = Number(process.env.RPI_COCKPIT_PORT ?? 4399);

// The UI server is best-effort: if it cannot bind, narration must still work,
// so the MCP stdio transport connects regardless of the server's outcome.
try {
  const srv = await startServer(bridge, port);
  // Print the KEYED url: the per-session token must be carried as ?key=… or the
  // HTTP/WS gates reject the connection. Without it the cockpit is unreachable.
  process.stderr.write(`rpi-cockpit: ${srv.url}\n`);
} catch (err) {
  const m = err instanceof Error ? err.message : String(err);
  process.stderr.write(`rpi-cockpit: UI server unavailable (${m}); MCP narration still active.\n`);
}

await connectStdio(buildMcpServer(bridge));
