# RPI Cockpit

A real-time browser dashboard that lets you monitor and steer an RPI (Research-Plan-Implement) agent loop running inside Claude Code.

## Install and build

```bash
cd rpi-cockpit
npm install
npm run build
```

## Running the cockpit in Claude Code / Codex / VS Code

The `init` command wires the cockpit into each host's MCP config and inlines the
narration contract into that host's agent-instructions file. Configs and narration
are written idempotently — re-running `init` updates in place rather than duplicating.

### One-time setup

```bash
# 1. Install + build (the `prepare` script runs `tsc` and produces dist/index.js):
cd rpi-cockpit && npm install

# 2. Wire one host (or all of them):
npx --no-install rpi-cockpit init --host <claude|codex|vscode|all>
# or, equivalently, without relying on the bin link:
node rpi-cockpit/dist/index.js init --host <claude|codex|vscode|all>
```

Run `init` from the **repository root** so the project-scoped configs land in the
right place. The web UI always serves on `http://127.0.0.1:4399` (loopback only);
override the port with `RPI_COCKPIT_PORT`.

### Claude Code

`init --host claude` writes:

- `.mcp.json` — registers `mcpServers.rpi-cockpit` (`type: "stdio"`, launched via
  `node ${CLAUDE_PROJECT_DIR}/rpi-cockpit/dist/index.js`). This file is committed,
  so the cockpit is available to everyone who opens the repo in Claude Code.
- `CLAUDE.md` — the narration contract, inside a
  `<!-- rpi-cockpit:narration:begin -->…<!-- rpi-cockpit:narration:end -->` block.

Open the project in Claude Code; it starts the server automatically. Confirm the
seven tools (`session_begin`, `phase_enter`, `subagent_start`, `subagent_stop`,
`artifact_update`, `validate`, `present_options`) appear, then open
<http://127.0.0.1:4399>.

### Codex

`init --host codex` writes:

- `.codex/config.toml` — the `[mcp_servers.rpi-cockpit]` table. **This config is
  machine-specific** (it uses absolute paths) and is git-ignored, so it is *not*
  committed; each developer generates their own. Pass `--codex-global` to write it
  to `~/.codex/config.toml` instead of the project's `.codex/config.toml`.
- `AGENTS.md` — the narration contract block (committed).

Because Codex configs need absolute paths, the generated table looks like this
(replace `<ABSOLUTE_REPO_PATH>` with your checkout's absolute path):

```toml
[mcp_servers.rpi-cockpit]
command = "node"
args = ["<ABSOLUTE_REPO_PATH>/rpi-cockpit/dist/index.js"]
cwd = "<ABSOLUTE_REPO_PATH>"
startup_timeout_sec = 20
```

Start Codex, confirm the seven `rpi-cockpit` tools are listed, then open
<http://127.0.0.1:4399>.

### VS Code (Copilot)

`init --host vscode` writes:

- `.vscode/mcp.json` — registers `servers.rpi-cockpit` (`type: "stdio"`,
  `${workspaceFolder}/rpi-cockpit/dist/index.js`, `cwd: "${workspaceFolder}"`).
  Committed so the workspace picks it up automatically.
- `.github/copilot-instructions.md` — the narration contract block is appended
  (existing content is preserved; committed).

Reload the VS Code window so Copilot picks up the MCP server, confirm the seven
`rpi-cockpit` tools are available, then open <http://127.0.0.1:4399>.

## Open the dashboard

With the server running, open your browser to:

```
http://127.0.0.1:4399
```

The dashboard updates in real time over WebSocket as the agent calls the cockpit beats.

## Agent instrumentation

See [`agents/cockpit-instructions.md`](agents/cockpit-instructions.md) for the snippet that tells an RPI agent when to call each beat (`session_begin`, `phase_enter`, `subagent_start`, `subagent_stop`, `artifact_update`, `validate`, `present_options`).

Add the contents of that file to your agent's system prompt or CLAUDE.md so it narrates its work through the cockpit.
