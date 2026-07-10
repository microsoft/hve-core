// rpi-cockpit/tests/init.test.ts
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runInit } from "../src/init.js";

const here = dirname(fileURLToPath(import.meta.url));
// The canonical narration contract lives in the package's agents dir.
const CONTRACT_PATH = resolve(here, "..", "agents", "cockpit-instructions.md");
const CONTRACT_TEXT = readFileSync(CONTRACT_PATH, "utf8").trim();
// A representative line from the contract that must end up inlined in every surface.
const CONTRACT_NEEDLE = "phase_enter(phase)";

let root: string;
let home: string;
// A fixed absolute entryPath simulating the running dist/index.js.
const ENTRY = "/some/abs/repo/rpi-cockpit/dist/index.js";

function readJson(p: string) {
  return JSON.parse(readFileSync(p, "utf8"));
}

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "rpi-init-root-"));
  home = mkdtempSync(join(tmpdir(), "rpi-init-home-"));
});
afterEach(() => {
  rmSync(root, { recursive: true, force: true });
  rmSync(home, { recursive: true, force: true });
});

function run(host: "claude" | "codex" | "vscode" | "all", codexGlobal = false) {
  return runInit({
    root,
    entryPath: ENTRY,
    contractPath: CONTRACT_PATH,
    host,
    codexGlobal,
    homeDir: home,
  });
}

describe("runInit --host all", () => {
  it("writes .mcp.json with mcpServers.rpi-cockpit (stdio + CLAUDE_PROJECT_DIR + env port)", () => {
    run("all");
    const j = readJson(join(root, ".mcp.json"));
    const s = j.mcpServers["rpi-cockpit"];
    expect(s.type).toBe("stdio");
    expect(s.command).toBe("node");
    expect(s.args).toEqual(["${CLAUDE_PROJECT_DIR}/rpi-cockpit/dist/index.js"]);
    expect(s.env.RPI_COCKPIT_PORT).toBe("4399");
  });

  it("writes .vscode/mcp.json with servers.rpi-cockpit (stdio + workspaceFolder + cwd)", () => {
    run("all");
    const j = readJson(join(root, ".vscode", "mcp.json"));
    const s = j.servers["rpi-cockpit"];
    expect(s.type).toBe("stdio");
    expect(s.command).toBe("node");
    expect(s.args).toEqual(["${workspaceFolder}/rpi-cockpit/dist/index.js"]);
    expect(s.cwd).toBe("${workspaceFolder}");
  });

  it("writes .codex/config.toml with [mcp_servers.rpi-cockpit] (absolute entryPath + cwd + startup_timeout_sec)", () => {
    run("all");
    const toml = readFileSync(join(root, ".codex", "config.toml"), "utf8");
    expect(toml).toContain("[mcp_servers.rpi-cockpit]");
    expect(toml).toContain('command = "node"');
    expect(toml).toContain(`args = ["${ENTRY}"]`);
    expect(toml).toContain(`cwd = "${root}"`);
    expect(toml).toContain("startup_timeout_sec = 20");
  });

  it("writes the narration marker block (with contract text) into CLAUDE.md, AGENTS.md, copilot-instructions.md", () => {
    run("all");
    for (const rel of ["CLAUDE.md", "AGENTS.md", join(".github", "copilot-instructions.md")]) {
      const p = join(root, rel);
      expect(existsSync(p)).toBe(true);
      const txt = readFileSync(p, "utf8");
      expect(txt).toContain("rpi-cockpit:narration");
      expect(txt).toContain(CONTRACT_NEEDLE);
    }
  });
});

describe("runInit --host filters", () => {
  it("claude -> only .mcp.json + CLAUDE.md", () => {
    run("claude");
    expect(existsSync(join(root, ".mcp.json"))).toBe(true);
    expect(existsSync(join(root, "CLAUDE.md"))).toBe(true);
    expect(existsSync(join(root, ".vscode", "mcp.json"))).toBe(false);
    expect(existsSync(join(root, ".codex", "config.toml"))).toBe(false);
    expect(existsSync(join(root, "AGENTS.md"))).toBe(false);
  });

  it("vscode -> only .vscode/mcp.json + copilot-instructions.md", () => {
    run("vscode");
    expect(existsSync(join(root, ".vscode", "mcp.json"))).toBe(true);
    expect(existsSync(join(root, ".github", "copilot-instructions.md"))).toBe(true);
    expect(existsSync(join(root, ".mcp.json"))).toBe(false);
    expect(existsSync(join(root, ".codex", "config.toml"))).toBe(false);
  });

  it("codex -> only .codex/config.toml + AGENTS.md", () => {
    run("codex");
    expect(existsSync(join(root, ".codex", "config.toml"))).toBe(true);
    expect(existsSync(join(root, "AGENTS.md"))).toBe(true);
    expect(existsSync(join(root, ".mcp.json"))).toBe(false);
    expect(existsSync(join(root, ".vscode", "mcp.json"))).toBe(false);
  });

  it("codexGlobal -> writes config.toml under homeDir/.codex, not root/.codex", () => {
    run("codex", true);
    expect(existsSync(join(home, ".codex", "config.toml"))).toBe(true);
    expect(existsSync(join(root, ".codex", "config.toml"))).toBe(false);
  });
});

describe("runInit preservation", () => {
  it("preserves an unrelated pre-existing mcpServers entry in .mcp.json", () => {
    writeFileSync(
      join(root, ".mcp.json"),
      JSON.stringify({ mcpServers: { other: { command: "x" } }, topLevelKey: 1 }, null, 2),
    );
    run("claude");
    const j = readJson(join(root, ".mcp.json"));
    expect(j.mcpServers.other).toEqual({ command: "x" });
    expect(j.topLevelKey).toBe(1);
    expect(j.mcpServers["rpi-cockpit"].type).toBe("stdio");
  });

  it("preserves pre-existing .vscode/mcp.json servers and inputs", () => {
    mkdirSync(join(root, ".vscode"), { recursive: true });
    writeFileSync(
      join(root, ".vscode", "mcp.json"),
      JSON.stringify({ servers: { keep: { command: "y" } }, inputs: [{ id: "tok" }] }, null, 2),
    );
    run("vscode");
    const j = readJson(join(root, ".vscode", "mcp.json"));
    expect(j.servers.keep).toEqual({ command: "y" });
    expect(j.inputs).toEqual([{ id: "tok" }]);
    expect(j.servers["rpi-cockpit"].type).toBe("stdio");
  });

  it("preserves pre-existing copilot-instructions.md content (never clobbers)", () => {
    mkdirSync(join(root, ".github"), { recursive: true });
    const existing = "# Existing Copilot guidance\n\nKeep me intact.\n";
    writeFileSync(join(root, ".github", "copilot-instructions.md"), existing);
    run("vscode");
    const txt = readFileSync(join(root, ".github", "copilot-instructions.md"), "utf8");
    expect(txt).toContain("Keep me intact.");
    expect(txt).toContain("rpi-cockpit:narration");
    expect(txt).toContain(CONTRACT_NEEDLE);
    // Embedded under the host doc's own H1: the contract's heading is demoted so
    // it does not introduce a second top-level heading (MD025).
    expect(txt).toContain("## Cockpit instrumentation");
    expect(txt).not.toMatch(/^# Cockpit instrumentation$/m);
  });
});

describe("runInit idempotency", () => {
  it("running twice yields identical files (no duplicate blocks/tables)", () => {
    run("all");
    const snapshot: Record<string, string> = {};
    const files = [
      join(root, ".mcp.json"),
      join(root, ".vscode", "mcp.json"),
      join(root, ".codex", "config.toml"),
      join(root, "CLAUDE.md"),
      join(root, "AGENTS.md"),
      join(root, ".github", "copilot-instructions.md"),
    ];
    for (const f of files) snapshot[f] = readFileSync(f, "utf8");

    run("all");
    for (const f of files) {
      expect(readFileSync(f, "utf8")).toBe(snapshot[f]);
    }

    // Belt-and-suspenders: exactly one narration block and one codex table.
    const claude = readFileSync(join(root, "CLAUDE.md"), "utf8");
    const beginCount = (claude.match(/rpi-cockpit:narration:begin/g) || []).length;
    expect(beginCount).toBe(1);
    const toml = readFileSync(join(root, ".codex", "config.toml"), "utf8");
    const tableCount = (toml.match(/\[mcp_servers\.rpi-cockpit\]/g) || []).length;
    expect(tableCount).toBe(1);
  });

  it("does not duplicate the mcpServers.rpi-cockpit entry across runs", () => {
    run("claude");
    run("claude");
    const j = readJson(join(root, ".mcp.json"));
    expect(Object.keys(j.mcpServers)).toEqual(["rpi-cockpit"]);
  });
});

describe("runInit contract", () => {
  it("inlines the FULL contract text (no @-includes)", () => {
    run("claude");
    const txt = readFileSync(join(root, "CLAUDE.md"), "utf8");
    expect(txt).toContain(CONTRACT_TEXT);
    expect(txt).not.toContain("@agents/cockpit-instructions.md");
  });
});
