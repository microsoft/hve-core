// rpi-cockpit/src/init.ts
//
// The `init` command wires the rpi-cockpit MCP server into every host surface
// (Claude Code, VS Code/Copilot, Codex) and regenerates the narration contract
// into the agent instruction files. Every write is idempotent: re-running must
// neither duplicate nor corrupt existing content.
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
} from "node:fs";
import { join, dirname } from "node:path";

export type InitHost = "claude" | "codex" | "vscode" | "all";

export interface InitOptions {
  /** Repository root that receives the project-scoped config files. */
  root: string;
  /** Absolute path to the running dist/index.js (used by the Codex config). */
  entryPath: string;
  /** Path to the canonical narration contract (agents/cockpit-instructions.md). */
  contractPath: string;
  /** Which surfaces to wire. Defaults to "all". */
  host: InitHost;
  /** When true, the Codex config goes to <homeDir>/.codex instead of <root>/.codex. */
  codexGlobal: boolean;
  /** Home directory (os.homedir()) — used only for the global Codex config. */
  homeDir: string;
}

const SERVER_NAME = "rpi-cockpit";
const NARRATION_BEGIN = "<!-- rpi-cockpit:narration:begin -->";
const NARRATION_END = "<!-- rpi-cockpit:narration:end -->";

function ensureDir(filePath: string): void {
  mkdirSync(dirname(filePath), { recursive: true });
}

function readJsonIfExists(filePath: string): Record<string, unknown> {
  if (!existsSync(filePath)) return {};
  const raw = readFileSync(filePath, "utf8").trim();
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>) : {};
  } catch {
    // A corrupt/unparseable file should not crash init; start fresh but keep nothing.
    return {};
  }
}

function writeJson(filePath: string, value: unknown): void {
  ensureDir(filePath);
  writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n");
}

// (1) CLAUDE -> <root>/.mcp.json — read-merge into mcpServers.rpi-cockpit.
function writeClaudeMcp(root: string): string {
  const filePath = join(root, ".mcp.json");
  const doc = readJsonIfExists(filePath);
  const servers =
    doc.mcpServers && typeof doc.mcpServers === "object"
      ? (doc.mcpServers as Record<string, unknown>)
      : {};
  servers[SERVER_NAME] = {
    type: "stdio",
    command: "node",
    args: ["${CLAUDE_PROJECT_DIR}/rpi-cockpit/dist/index.js"],
    env: { RPI_COCKPIT_PORT: "4399" },
  };
  doc.mcpServers = servers;
  writeJson(filePath, doc);
  return filePath;
}

// (2) VSCODE -> <root>/.vscode/mcp.json — read-merge into servers.rpi-cockpit.
function writeVscodeMcp(root: string): string {
  const filePath = join(root, ".vscode", "mcp.json");
  const doc = readJsonIfExists(filePath);
  const servers =
    doc.servers && typeof doc.servers === "object"
      ? (doc.servers as Record<string, unknown>)
      : {};
  servers[SERVER_NAME] = {
    type: "stdio",
    command: "node",
    args: ["${workspaceFolder}/rpi-cockpit/dist/index.js"],
    cwd: "${workspaceFolder}",
  };
  doc.servers = servers;
  writeJson(filePath, doc);
  return filePath;
}

// (3) CODEX -> <root>/.codex/config.toml (or <homeDir>/.codex when codexGlobal).
// Hand-rolled TOML: replace exactly the [mcp_servers.rpi-cockpit] table if present,
// else append it.
function buildCodexTable(entryPath: string, cwd: string): string {
  return [
    `[mcp_servers.${SERVER_NAME}]`,
    `command = "node"`,
    `args = ["${entryPath}"]`,
    `cwd = "${cwd}"`,
    `startup_timeout_sec = 20`,
  ].join("\n");
}

function upsertCodexTable(existing: string, table: string): string {
  const header = `[mcp_servers.${SERVER_NAME}]`;
  const headerIdx = existing.indexOf(header);
  if (headerIdx === -1) {
    // Append, separated by a blank line if there's prior content.
    const trimmed = existing.replace(/\s+$/, "");
    return trimmed.length ? `${trimmed}\n\n${table}\n` : `${table}\n`;
  }
  // Replace from the header line up to (but not including) the next table header
  // or end-of-file. Table headers start a line with "[".
  const before = existing.slice(0, headerIdx);
  const rest = existing.slice(headerIdx + header.length);
  const nextHeaderRel = rest.search(/\n\[/);
  const after = nextHeaderRel === -1 ? "" : rest.slice(nextHeaderRel + 1); // drop the leading \n
  const beforeTrimmed = before.replace(/\s+$/, "");
  const prefix = beforeTrimmed.length ? `${beforeTrimmed}\n\n` : "";
  const suffix = after.length ? `\n${after.replace(/^\s+/, "")}` : "\n";
  return `${prefix}${table}${suffix}`;
}

function writeCodexConfig(root: string, homeDir: string, codexGlobal: boolean, entryPath: string): string {
  const base = codexGlobal ? homeDir : root;
  const filePath = join(base, ".codex", "config.toml");
  const existing = existsSync(filePath) ? readFileSync(filePath, "utf8") : "";
  const table = buildCodexTable(entryPath, root);
  const next = upsertCodexTable(existing, table);
  ensureDir(filePath);
  writeFileSync(filePath, next);
  return filePath;
}

// (4) NARRATION -> marker-delimited, inlined contract text into a Markdown surface.
function buildNarrationBlock(contractText: string): string {
  return `${NARRATION_BEGIN}\n${contractText.trim()}\n${NARRATION_END}`;
}

// Everything in `text` except an existing narration block, so we can tell a
// block-only surface (CLAUDE.md, AGENTS.md) from one with its own content.
function stripBlock(text: string): string {
  const b = text.indexOf(NARRATION_BEGIN);
  const e = text.indexOf(NARRATION_END);
  if (b !== -1 && e !== -1 && e > b) return text.slice(0, b) + text.slice(e + NARRATION_END.length);
  return text;
}

// Demote every ATX heading (h1..h5) by one level. Used when the block is
// embedded in a host doc that already has its own H1 title, so the contract's
// `# Cockpit instrumentation` becomes `## …` and does not introduce a second
// top-level heading (markdownlint MD025). h6 is left as-is (no h7).
function demoteHeadings(md: string): string {
  return md.split("\n").map((line) => (/^#{1,5}\s/.test(line) ? "#" + line : line)).join("\n");
}

function writeNarration(filePath: string, contractText: string): string {
  const existing = existsSync(filePath) ? readFileSync(filePath, "utf8") : "";
  // Block-only surfaces keep the H1 (so they satisfy MD041); a surface with its
  // own content gets the headings demoted (so the block nests under its title).
  const embedded = stripBlock(existing).trim().length > 0;
  const block = buildNarrationBlock(embedded ? demoteHeadings(contractText) : contractText);
  let next: string;
  const beginIdx = existing.indexOf(NARRATION_BEGIN);
  const endIdx = existing.indexOf(NARRATION_END);
  if (beginIdx !== -1 && endIdx !== -1 && endIdx > beginIdx) {
    // Replace exactly the existing block (markers included).
    const before = existing.slice(0, beginIdx);
    const after = existing.slice(endIdx + NARRATION_END.length);
    next = `${before}${block}${after}`;
  } else if (existing.trim().length) {
    // Append after existing content, preserving it.
    next = `${existing.replace(/\s+$/, "")}\n\n${block}\n`;
  } else {
    next = `${block}\n`;
  }
  ensureDir(filePath);
  writeFileSync(filePath, next);
  return filePath;
}

export interface InitResult {
  written: string[];
  summary: string;
}

export function runInit(opts: InitOptions): InitResult {
  const { root, entryPath, contractPath, host, codexGlobal, homeDir } = opts;
  const contractText = readFileSync(contractPath, "utf8");
  const written: string[] = [];

  const doClaude = host === "all" || host === "claude";
  const doVscode = host === "all" || host === "vscode";
  const doCodex = host === "all" || host === "codex";

  // Config writers.
  if (doClaude) written.push(writeClaudeMcp(root));
  if (doVscode) written.push(writeVscodeMcp(root));
  if (doCodex) written.push(writeCodexConfig(root, homeDir, codexGlobal, entryPath));

  // Narration surfaces:
  //   claude -> CLAUDE.md ; vscode -> .github/copilot-instructions.md ; codex -> AGENTS.md
  if (doClaude) written.push(writeNarration(join(root, "CLAUDE.md"), contractText));
  if (doCodex) written.push(writeNarration(join(root, "AGENTS.md"), contractText));
  if (doVscode)
    written.push(writeNarration(join(root, ".github", "copilot-instructions.md"), contractText));

  const summary = [
    `rpi-cockpit init (--host ${host}${codexGlobal ? " --codex-global" : ""}) wrote:`,
    ...written.map((f) => `  - ${f}`),
  ].join("\n");

  return { written, summary };
}
