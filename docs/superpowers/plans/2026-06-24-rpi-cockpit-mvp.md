# RPI Cockpit MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-process local bridge that makes one RPI agent session legible (Show) and lets the user answer the agent's blocking decisions graphically (Decide), rendered as a Fluent web cockpit driven over WebSocket and fed by the agent over MCP.

**Architecture:** One Node/TypeScript process is both an MCP stdio server (the agent calls "beat" tools) and an HTTP/WebSocket server (serves the cockpit UI and streams state). A pure state reducer turns beats into a `SessionState`; the `Bridge` holds that state, broadcasts it to browsers, and resolves blocking `present_options` calls when the user clicks. The UI reuses the existing Fluent mockup as its shell.

**Tech Stack:** Node 22, TypeScript (strict, NodeNext ESM), `@modelcontextprotocol/sdk`, `ws`, `zod`; vitest + happy-dom for tests; `tsx` to run.

## Global Constraints

- Node `>=22`; TypeScript `strict: true`; ESM (`"type": "module"`, `module: NodeNext`).
- Runtime deps limited to `@modelcontextprotocol/sdk`, `ws`, `zod`. No web framework, no bundler.
- All packages live under `rpi-cockpit/` at the repo root (self-contained package).
- MVP is single-process and single-session. Persistence/daemon split, Steer, VS Code webview, and Copilot/Codex are out of scope (separate plans).
- Reference harness: Claude Code (registers the MCP server via `.mcp.json`).
- Default port: `4399` (override with `RPI_COCKPIT_PORT`).
- UI shell is copied from `mockups/rpi-cockpit-fluent.html`; light Fluent theme is the default.
- Beat/phase names verbatim: phases are `research | plan | implement | review | discover`.

---

### Task 1: Scaffold the bridge package

**Files:**
- Create: `rpi-cockpit/package.json`
- Create: `rpi-cockpit/tsconfig.json`
- Create: `rpi-cockpit/vitest.config.ts`
- Test: `rpi-cockpit/tests/smoke.test.ts`

**Interfaces:**
- Produces: a runnable package where `npm test` executes vitest.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/smoke.test.ts
import { describe, it, expect } from "vitest";

describe("scaffold", () => {
  it("runs vitest", () => {
    expect(1 + 1).toBe(2);
  });
});
```

- [ ] **Step 2: Create package files**

```json
// rpi-cockpit/package.json
{
  "name": "rpi-cockpit",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": { "rpi-cockpit": "dist/index.js" },
  "scripts": {
    "test": "vitest run",
    "dev": "tsx src/index.ts",
    "build": "tsc"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.12.0",
    "ws": "^8.18.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/ws": "^8.5.12",
    "happy-dom": "^15.7.4",
    "tsx": "^4.19.0",
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

```json
// rpi-cockpit/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

```ts
// rpi-cockpit/vitest.config.ts
import { defineConfig } from "vitest/config";
export default defineConfig({ test: { environment: "node" } });
```

- [ ] **Step 3: Install and run**

Run: `cd rpi-cockpit && npm install && npm test`
Expected: PASS, 1 test.

- [ ] **Step 4: Commit**

```bash
git add rpi-cockpit/package.json rpi-cockpit/tsconfig.json rpi-cockpit/vitest.config.ts rpi-cockpit/tests/smoke.test.ts rpi-cockpit/package-lock.json
git commit -m "feat(cockpit): scaffold bridge package"
```

---

### Task 2: Beat and decision schemas

**Files:**
- Create: `rpi-cockpit/src/events.ts`
- Test: `rpi-cockpit/tests/events.test.ts`

**Interfaces:**
- Produces: `Phase`, `Beat` (zod + type), `OptionItem` (zod + type). `Beat` is a discriminated union on `type`.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/events.test.ts
import { describe, it, expect } from "vitest";
import { Beat, OptionItem } from "../src/events.js";

describe("events", () => {
  it("parses a valid phase.enter beat", () => {
    const b = Beat.parse({ type: "phase.enter", phase: "implement" });
    expect(b).toEqual({ type: "phase.enter", phase: "implement" });
  });
  it("rejects an unknown phase", () => {
    expect(() => Beat.parse({ type: "phase.enter", phase: "nope" })).toThrow();
  });
  it("parses an option item", () => {
    expect(OptionItem.parse({ id: "b", title: "Token middleware", recommended: true }).id).toBe("b");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/events.test.ts`
Expected: FAIL ("Cannot find module ../src/events.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/events.ts
import { z } from "zod";

export const Phase = z.enum(["research", "plan", "implement", "review", "discover"]);
export type Phase = z.infer<typeof Phase>;

export const ValidationStatus = z.enum(["ok", "running", "fail", "pending"]);
export type ValidationStatus = z.infer<typeof ValidationStatus>;

export const OptionItem = z.object({
  id: z.string(),
  title: z.string(),
  detail: z.string().optional(),
  recommended: z.boolean().optional(),
});
export type OptionItem = z.infer<typeof OptionItem>;

export const Beat = z.discriminatedUnion("type", [
  z.object({ type: z.literal("session.begin"), task: z.string(), host: z.string() }),
  z.object({ type: z.literal("phase.enter"), phase: Phase }),
  z.object({ type: z.literal("subagent.start"), name: z.string(), role: z.string().optional() }),
  z.object({ type: z.literal("subagent.stop"), name: z.string(), result: z.string().optional() }),
  z.object({ type: z.literal("artifact.update"), path: z.string(), summary: z.string().optional() }),
  z.object({ type: z.literal("validate"), check: z.string(), status: ValidationStatus }),
]);
export type Beat = z.infer<typeof Beat>;
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/events.test.ts`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/tests/events.test.ts
git commit -m "feat(cockpit): add beat and decision schemas"
```

---

### Task 3: Session state reducer

**Files:**
- Create: `rpi-cockpit/src/state.ts`
- Test: `rpi-cockpit/tests/state.test.ts`

**Interfaces:**
- Consumes: `Beat`, `Phase`, `OptionItem` from `events.ts`.
- Produces: `SessionState`, `Subagent`, `Decision`, `initialState(): SessionState`, `applyBeat(s: SessionState, beat: Beat, now: number): SessionState` (pure — returns a new state).

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/state.test.ts
import { describe, it, expect } from "vitest";
import { initialState, applyBeat } from "../src/state.js";

describe("applyBeat", () => {
  it("sets task and host on session.begin", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "refactor auth", host: "claude-code" }, 1);
    expect(s.task).toBe("refactor auth");
    expect(s.host).toBe("claude-code");
  });
  it("advances phase and records the previous as done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "plan" }, 2);
    expect(s.phase).toBe("plan");
    expect(s.phasesDone).toEqual(["research"]);
  });
  it("tracks subagent lifecycle", () => {
    let s = applyBeat(initialState(), { type: "subagent.start", name: "Phase Implementor", role: "impl" }, 1);
    expect(s.subagents[0]).toMatchObject({ name: "Phase Implementor", status: "active" });
    s = applyBeat(s, { type: "subagent.stop", name: "Phase Implementor", result: "done" }, 2);
    expect(s.subagents[0]).toMatchObject({ status: "idle", result: "done" });
  });
  it("records validations and artifacts and appends to the log", () => {
    let s = applyBeat(initialState(), { type: "validate", check: "lint", status: "ok" }, 1);
    s = applyBeat(s, { type: "artifact.update", path: "plan.md", summary: "+10" }, 2);
    expect(s.validations.lint).toBe("ok");
    expect(s.artifacts).toEqual([{ path: "plan.md", summary: "+10" }]);
    expect(s.log.length).toBe(2);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/state.test.ts`
Expected: FAIL ("Cannot find module ../src/state.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/state.ts
import type { Beat, Phase, OptionItem, ValidationStatus } from "./events.js";

export interface Subagent { name: string; role?: string; status: "active" | "idle"; result?: string; }
export interface Decision { id: string; prompt: string; options: OptionItem[]; }
export interface LogEntry { t: number; kind: string; detail: string; }

export interface SessionState {
  task: string;
  host: string;
  phase: Phase | null;
  phasesDone: Phase[];
  subagents: Subagent[];
  validations: Record<string, ValidationStatus>;
  artifacts: { path: string; summary?: string }[];
  pendingDecision: Decision | null;
  log: LogEntry[];
}

export function initialState(): SessionState {
  return { task: "", host: "", phase: null, phasesDone: [], subagents: [], validations: {}, artifacts: [], pendingDecision: null, log: [] };
}

export function applyBeat(s: SessionState, beat: Beat, now: number): SessionState {
  const log = [...s.log, { t: now, kind: beat.type, detail: summarize(beat) }];
  switch (beat.type) {
    case "session.begin":
      return { ...s, task: beat.task, host: beat.host, log };
    case "phase.enter": {
      const phasesDone = s.phase && s.phase !== beat.phase && !s.phasesDone.includes(s.phase)
        ? [...s.phasesDone, s.phase] : s.phasesDone;
      return { ...s, phase: beat.phase, phasesDone, log };
    }
    case "subagent.start": {
      const others = s.subagents.filter((a) => a.name !== beat.name);
      return { ...s, subagents: [...others, { name: beat.name, role: beat.role, status: "active" }], log };
    }
    case "subagent.stop":
      return { ...s, subagents: s.subagents.map((a) => a.name === beat.name ? { ...a, status: "idle", result: beat.result } : a), log };
    case "artifact.update": {
      const others = s.artifacts.filter((x) => x.path !== beat.path);
      return { ...s, artifacts: [...others, { path: beat.path, summary: beat.summary }], log };
    }
    case "validate":
      return { ...s, validations: { ...s.validations, [beat.check]: beat.status }, log };
  }
}

function summarize(beat: Beat): string {
  switch (beat.type) {
    case "session.begin": return beat.task;
    case "phase.enter": return beat.phase;
    case "subagent.start": return beat.name;
    case "subagent.stop": return `${beat.name}: ${beat.result ?? "done"}`;
    case "artifact.update": return `${beat.path} ${beat.summary ?? ""}`.trim();
    case "validate": return `${beat.check}=${beat.status}`;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/state.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/state.ts rpi-cockpit/tests/state.test.ts
git commit -m "feat(cockpit): add session state reducer"
```

---

### Task 4: Bridge with the decision handshake

**Files:**
- Create: `rpi-cockpit/src/bridge.ts`
- Test: `rpi-cockpit/tests/bridge.test.ts`

**Interfaces:**
- Consumes: `applyBeat`, `initialState`, `SessionState` from `state.ts`; `Beat`, `OptionItem` from `events.ts`.
- Produces: `class Bridge extends EventEmitter` with `state: SessionState`, `emitBeat(beat: Beat): void`, `presentOptions(prompt: string, options: OptionItem[], timeoutMs?: number): Promise<string>` (resolves with the chosen option id), `resolveDecision(id: string, choiceId: string): void`, and a `"state"` event emitting the new `SessionState`.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/bridge.test.ts
import { describe, it, expect, vi } from "vitest";
import { Bridge } from "../src/bridge.js";

describe("Bridge", () => {
  it("emits state on a beat", () => {
    const b = new Bridge();
    const seen = vi.fn();
    b.on("state", seen);
    b.emitBeat({ type: "phase.enter", phase: "plan" });
    expect(b.state.phase).toBe("plan");
    expect(seen).toHaveBeenCalledOnce();
  });
  it("blocks presentOptions until resolveDecision is called", async () => {
    const b = new Bridge();
    const p = b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B" }]);
    expect(b.state.pendingDecision?.options.length).toBe(2);
    b.resolveDecision(b.state.pendingDecision!.id, "b");
    await expect(p).resolves.toBe("b");
    expect(b.state.pendingDecision).toBeNull();
  });
  it("falls back to the recommended option on timeout", async () => {
    const b = new Bridge();
    const choice = await b.presentOptions("pick", [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }], 5);
    expect(choice).toBe("b");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/bridge.test.ts`
Expected: FAIL ("Cannot find module ../src/bridge.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/bridge.ts
import { EventEmitter } from "node:events";
import { initialState, applyBeat, type SessionState } from "./state.js";
import type { Beat, OptionItem } from "./events.js";

export class Bridge extends EventEmitter {
  state: SessionState = initialState();
  private pending = new Map<string, (choiceId: string) => void>();
  private seq = 0;

  emitBeat(beat: Beat): void {
    this.state = applyBeat(this.state, beat, Date.now());
    this.emit("state", this.state);
  }

  presentOptions(prompt: string, options: OptionItem[], timeoutMs = 0): Promise<string> {
    const id = `d${++this.seq}`;
    this.state = { ...this.state, pendingDecision: { id, prompt, options } };
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(id, resolve);
      if (timeoutMs > 0) {
        setTimeout(() => {
          if (this.pending.has(id)) {
            const fallback = options.find((o) => o.recommended)?.id ?? options[0].id;
            this.resolveDecision(id, fallback);
          }
        }, timeoutMs);
      }
    });
  }

  resolveDecision(id: string, choiceId: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    if (this.state.pendingDecision?.id === id) {
      this.state = { ...this.state, pendingDecision: null };
      this.emit("state", this.state);
    }
    resolve(choiceId);
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/bridge.test.ts`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/bridge.ts rpi-cockpit/tests/bridge.test.ts
git commit -m "feat(cockpit): add bridge with decision handshake"
```

---

### Task 5: Beat tool handlers

**Files:**
- Create: `rpi-cockpit/src/handlers.ts`
- Test: `rpi-cockpit/tests/handlers.test.ts`

**Interfaces:**
- Consumes: `Bridge`, `OptionItem`.
- Produces: `handlers`, an object mapping tool name → `(bridge, args) => string | Promise<string>`. Tools: `session_begin`, `phase_enter`, `subagent_start`, `subagent_stop`, `artifact_update`, `validate`, `present_options`. `present_options` returns the chosen option id.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/handlers.test.ts
import { describe, it, expect } from "vitest";
import { Bridge } from "../src/bridge.js";
import { handlers } from "../src/handlers.js";

describe("handlers", () => {
  it("phase_enter advances the bridge", async () => {
    const b = new Bridge();
    const out = await handlers.phase_enter(b, { phase: "implement" });
    expect(b.state.phase).toBe("implement");
    expect(out).toContain("implement");
  });
  it("present_options resolves to the user's choice", async () => {
    const b = new Bridge();
    const p = handlers.present_options(b, { prompt: "pick", options: [{ id: "a", title: "A" }, { id: "b", title: "B" }] });
    b.resolveDecision(b.state.pendingDecision!.id, "a");
    expect(await p).toBe("a");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/handlers.test.ts`
Expected: FAIL ("Cannot find module ../src/handlers.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/handlers.ts
import type { Bridge } from "./bridge.js";
import type { OptionItem, Phase, ValidationStatus } from "./events.js";

export const handlers = {
  session_begin: (b: Bridge, a: { task: string; host: string }) => {
    b.emitBeat({ type: "session.begin", task: a.task, host: a.host });
    return "session started";
  },
  phase_enter: (b: Bridge, a: { phase: Phase }) => {
    b.emitBeat({ type: "phase.enter", phase: a.phase });
    return `entered ${a.phase}`;
  },
  subagent_start: (b: Bridge, a: { name: string; role?: string }) => {
    b.emitBeat({ type: "subagent.start", name: a.name, role: a.role });
    return `${a.name} started`;
  },
  subagent_stop: (b: Bridge, a: { name: string; result?: string }) => {
    b.emitBeat({ type: "subagent.stop", name: a.name, result: a.result });
    return `${a.name} stopped`;
  },
  artifact_update: (b: Bridge, a: { path: string; summary?: string }) => {
    b.emitBeat({ type: "artifact.update", path: a.path, summary: a.summary });
    return `${a.path} updated`;
  },
  validate: (b: Bridge, a: { check: string; status: ValidationStatus }) => {
    b.emitBeat({ type: "validate", check: a.check, status: a.status });
    return `${a.check}=${a.status}`;
  },
  present_options: (b: Bridge, a: { prompt: string; options: OptionItem[] }) =>
    b.presentOptions(a.prompt, a.options),
};
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/handlers.test.ts`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/tests/handlers.test.ts
git commit -m "feat(cockpit): add beat tool handlers"
```

---

### Task 6: HTTP + WebSocket server

**Files:**
- Create: `rpi-cockpit/src/server.ts`
- Test: `rpi-cockpit/tests/server.test.ts`

**Interfaces:**
- Consumes: `Bridge`.
- Produces: `startServer(bridge: Bridge, port?: number): Promise<{ port: number; close(): Promise<void> }>`. Serves files from `rpi-cockpit/public/`, sends `{type:"state",state}` on connect and on every bridge `"state"` event, and on receiving `{type:"decide",id,choiceId}` calls `bridge.resolveDecision`.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/server.test.ts
import { describe, it, expect, afterEach } from "vitest";
import WebSocket from "ws";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";

let stop: (() => Promise<void>) | null = null;
afterEach(async () => { if (stop) await stop(); stop = null; });

describe("server", () => {
  it("pushes state on connect and round-trips a decision", async () => {
    const bridge = new Bridge();
    const srv = await startServer(bridge, 0);
    stop = srv.close;
    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
    const first = await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
    expect(first.type).toBe("state");

    const choice = bridge.presentOptions("pick", [{ id: "a", title: "A" }]);
    await new Promise((r) => setTimeout(r, 20));
    const id = bridge.state.pendingDecision!.id;
    ws.send(JSON.stringify({ type: "decide", id, choiceId: "a" }));
    expect(await choice).toBe("a");
    ws.close();
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/server.test.ts`
Expected: FAIL ("Cannot find module ../src/server.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/server.ts
import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer, type WebSocket } from "ws";
import type { Bridge } from "./bridge.js";
import type { SessionState } from "./state.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");
const TYPES: Record<string, string> = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

export async function startServer(bridge: Bridge, port = 4399) {
  const httpServer = http.createServer(async (req, res) => {
    const rel = (req.url === "/" || !req.url ? "/index.html" : req.url).split("?")[0];
    try {
      const file = await readFile(path.join(PUBLIC, rel));
      res.writeHead(200, { "content-type": TYPES[path.extname(rel)] ?? "application/octet-stream" });
      res.end(file);
    } catch {
      res.writeHead(404); res.end("not found");
    }
  });

  const wss = new WebSocketServer({ server: httpServer });
  const send = (ws: WebSocket, state: SessionState) => ws.send(JSON.stringify({ type: "state", state }));
  wss.on("connection", (ws) => {
    send(ws, bridge.state);
    ws.on("message", (data) => {
      const msg = JSON.parse(String(data));
      if (msg.type === "decide") bridge.resolveDecision(msg.id, msg.choiceId);
    });
  });
  const broadcast = (state: SessionState) => { for (const c of wss.clients) if (c.readyState === 1) send(c, state); };
  bridge.on("state", broadcast);

  await new Promise<void>((resolve) => httpServer.listen(port, resolve));
  const actual = (httpServer.address() as { port: number }).port;
  return {
    port: actual,
    close: () => new Promise<void>((resolve) => { bridge.off("state", broadcast); wss.close(); httpServer.close(() => resolve()); }),
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/server.test.ts`
Expected: PASS, 1 test.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/server.ts rpi-cockpit/tests/server.test.ts
git commit -m "feat(cockpit): add http and websocket server"
```

---

### Task 7: MCP face and entry point

**Files:**
- Create: `rpi-cockpit/src/mcp.ts`
- Create: `rpi-cockpit/src/index.ts`
- Test: `rpi-cockpit/tests/mcp.test.ts`

**Interfaces:**
- Consumes: `Bridge`, `handlers`, the MCP SDK.
- Produces: `buildMcpServer(bridge: Bridge): McpServer` registering one tool per handler with zod input schemas; `connectStdio(server): Promise<void>`. `index.ts` is the executable entry: makes a `Bridge`, starts the server, connects MCP over stdio.

- [ ] **Step 1: Write the failing test** (drives a tool through the SDK's in-memory transport)

```ts
// rpi-cockpit/tests/mcp.test.ts
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { Bridge } from "../src/bridge.js";
import { buildMcpServer } from "../src/mcp.js";

describe("mcp face", () => {
  it("phase_enter tool advances the bridge", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "phase_enter", arguments: { phase: "review" } });
    expect(bridge.state.phase).toBe("review");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/mcp.test.ts`
Expected: FAIL ("Cannot find module ../src/mcp.js").

- [ ] **Step 3: Implement**

```ts
// rpi-cockpit/src/mcp.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Phase, ValidationStatus, OptionItem } from "./events.js";
import { handlers } from "./handlers.js";
import type { Bridge } from "./bridge.js";

const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });

export function buildMcpServer(bridge: Bridge): McpServer {
  const server = new McpServer({ name: "rpi-cockpit", version: "0.1.0" });

  server.registerTool("session_begin", { description: "Open the cockpit session.", inputSchema: { task: z.string(), host: z.string() } },
    async (a) => text(handlers.session_begin(bridge, a)));
  server.registerTool("phase_enter", { description: "Enter an RPI phase.", inputSchema: { phase: Phase } },
    async (a) => text(handlers.phase_enter(bridge, a)));
  server.registerTool("subagent_start", { description: "Mark a subagent active.", inputSchema: { name: z.string(), role: z.string().optional() } },
    async (a) => text(handlers.subagent_start(bridge, a)));
  server.registerTool("subagent_stop", { description: "Mark a subagent idle.", inputSchema: { name: z.string(), result: z.string().optional() } },
    async (a) => text(handlers.subagent_stop(bridge, a)));
  server.registerTool("artifact_update", { description: "Record a tracking artifact.", inputSchema: { path: z.string(), summary: z.string().optional() } },
    async (a) => text(handlers.artifact_update(bridge, a)));
  server.registerTool("validate", { description: "Report a validation check.", inputSchema: { check: z.string(), status: ValidationStatus } },
    async (a) => text(handlers.validate(bridge, a)));
  server.registerTool("present_options", { description: "Ask the user to choose; blocks until they pick.", inputSchema: { prompt: z.string(), options: z.array(OptionItem) } },
    async (a) => text(await handlers.present_options(bridge, a)));

  return server;
}

export async function connectStdio(server: McpServer): Promise<void> {
  await server.connect(new StdioServerTransport());
}
```

```ts
// rpi-cockpit/src/index.ts
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { buildMcpServer, connectStdio } from "./mcp.js";

const bridge = new Bridge();
const port = Number(process.env.RPI_COCKPIT_PORT ?? 4399);
await startServer(bridge, port);
process.stderr.write(`rpi-cockpit: http://127.0.0.1:${port}\n`);
await connectStdio(buildMcpServer(bridge));
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/mcp.test.ts`
Expected: PASS, 1 test. (If the SDK import path differs for your installed version, check `node_modules/@modelcontextprotocol/sdk/dist/esm` and adjust the subpath; re-run until green.)

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/mcp.ts rpi-cockpit/src/index.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): add mcp face and entry point"
```

---

### Task 8: Cockpit UI render

**Files:**
- Create: `rpi-cockpit/public/index.html` (copy of `mockups/rpi-cockpit-fluent.html`)
- Create: `rpi-cockpit/public/client.js`
- Create: `rpi-cockpit/src/render.ts` (pure state → view-model, shared by client)
- Test: `rpi-cockpit/tests/render.test.ts`

**Interfaces:**
- Consumes: `SessionState`.
- Produces: `toViewModel(state: SessionState): ViewModel` — a pure mapping the browser uses to update the DOM (steps with status, subagents, validations, pending decision). `client.js` connects to the WS, calls `toViewModel`, updates the existing mockup DOM, and posts `{type:"decide"}` on button click.

- [ ] **Step 1: Write the failing test**

```ts
// rpi-cockpit/tests/render.test.ts
import { describe, it, expect } from "vitest";
import { toViewModel } from "../src/render.js";
import { initialState, applyBeat } from "../src/state.js";

describe("toViewModel", () => {
  it("marks the current phase active and prior phases done", () => {
    let s = applyBeat(initialState(), { type: "phase.enter", phase: "research" }, 1);
    s = applyBeat(s, { type: "phase.enter", phase: "implement" }, 2);
    const vm = toViewModel(s);
    expect(vm.steps.find((x) => x.phase === "research")!.status).toBe("done");
    expect(vm.steps.find((x) => x.phase === "implement")!.status).toBe("active");
    expect(vm.steps.find((x) => x.phase === "review")!.status).toBe("pending");
  });
  it("exposes the pending decision", () => {
    const s = { ...initialState(), pendingDecision: { id: "d1", prompt: "pick", options: [{ id: "a", title: "A" }] } };
    expect(toViewModel(s).decision?.id).toBe("d1");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd rpi-cockpit && npx vitest run tests/render.test.ts`
Expected: FAIL ("Cannot find module ../src/render.js").

- [ ] **Step 3: Implement the pure mapping**

```ts
// rpi-cockpit/src/render.ts
import type { SessionState } from "./state.js";
import type { Phase } from "./events.js";

const ORDER: Phase[] = ["research", "plan", "implement", "review", "discover"];
export interface StepVM { phase: Phase; status: "done" | "active" | "pending"; }
export interface ViewModel {
  task: string;
  steps: StepVM[];
  subagents: { name: string; status: string; role?: string }[];
  validations: { check: string; status: string }[];
  decision: SessionState["pendingDecision"];
  log: SessionState["log"];
}

export function toViewModel(s: SessionState): ViewModel {
  const steps: StepVM[] = ORDER.map((phase) => ({
    phase,
    status: s.phase === phase ? "active" : s.phasesDone.includes(phase) ? "done" : "pending",
  }));
  return {
    task: s.task,
    steps,
    subagents: s.subagents.map((a) => ({ name: a.name, status: a.status, role: a.role })),
    validations: Object.entries(s.validations).map(([check, status]) => ({ check, status })),
    decision: s.pendingDecision,
    log: s.log,
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd rpi-cockpit && npx vitest run tests/render.test.ts`
Expected: PASS, 2 tests.

- [ ] **Step 5: Create the browser shell and client**

Copy the mockup, then make the dynamic regions addressable and wire the socket.

```bash
cp mockups/rpi-cockpit-fluent.html rpi-cockpit/public/index.html
```

Add `<script type="module" src="client.js"></script>` before `</body>` in `rpi-cockpit/public/index.html`, and give the dynamic containers stable ids: `id="steps"` on the stepper region, `id="subagents"` on the live-subagents card, `id="decision"` on the decide card, `id="stream"` on the activity stream (the activity list already uses `.stream`).

```js
// rpi-cockpit/public/client.js
const ORDER = ["research", "plan", "implement", "review", "discover"];
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const ws = new WebSocket(`ws://${location.host}`);
let current = null;

ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.type === "state") { current = msg.state; render(msg.state); }
};

function render(s) {
  const steps = document.getElementById("steps");
  if (steps) steps.innerHTML = ORDER.map((p, i) => {
    const status = s.phase === p ? "active" : s.phasesDone.includes(p) ? "done" : "pending";
    return `<div class="step ${status}"><div class="ring">${status === "done" ? "✓" : i + 1}</div>
      <div><div class="lbl">${i + 1} · ${LABEL[p]}</div></div></div>`;
  }).join("");

  const subs = document.getElementById("subagents");
  if (subs) subs.innerHTML = s.subagents.map((a) =>
    `<div class="sub-card"><div class="av">${initials(a.name)}</div>
      <div style="flex:1"><div class="nm">${a.name}</div><div class="meta">${a.role ?? ""}</div></div>
      <span class="tagidle">${a.status}</span></div>`).join("") || "";

  const dec = document.getElementById("decision");
  if (dec) dec.innerHTML = s.pendingDecision ? decisionHtml(s.pendingDecision) : "";

  const stream = document.querySelector(".stream");
  if (stream) stream.innerHTML = s.log.slice(-12).map((l) =>
    `<div class="evt"><span class="ts">${new Date(l.t).toLocaleTimeString().slice(0, 5)}</span>
      <span><span class="k">${l.kind}</span> <span class="txt">${escapeHtml(l.detail)}</span></span></div>`).join("");
}

function decisionHtml(d) {
  const opts = d.options.map((o) =>
    `<div class="opt ${o.recommended ? "rec" : ""}">${o.recommended ? '<span class="badge">RECOMMENDED</span>' : ""}
      <h4>${escapeHtml(o.title)}</h4><p>${escapeHtml(o.detail ?? "")}</p></div>`).join("");
  const btns = d.options.map((o) =>
    `<button class="btn ${o.recommended ? "primary" : ""}" data-choice="${o.id}">Choose ${escapeHtml(o.title)}</button>`).join("");
  setTimeout(() => document.querySelectorAll("#decision [data-choice]").forEach((b) =>
    b.addEventListener("click", () => ws.send(JSON.stringify({ type: "decide", id: d.id, choiceId: b.dataset.choice })))), 0);
  return `<div class="decide"><div class="decide-head"><span class="t">${escapeHtml(d.prompt)}</span>
    <span class="s">present_options · awaiting your pick</span></div>
    <div class="decide-body"><div class="opts">${opts}</div><div class="btns">${btns}</div></div></div>`;
}

const initials = (n) => n.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
const escapeHtml = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
```

- [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/render.ts rpi-cockpit/tests/render.test.ts rpi-cockpit/public/
git commit -m "feat(cockpit): add ui render and websocket client"
```

---

### Task 9: Agent instrumentation, Claude Code registration, and end-to-end smoke

**Files:**
- Create: `rpi-cockpit/agents/cockpit-instructions.md`
- Create: `rpi-cockpit/.mcp.json.example`
- Create: `rpi-cockpit/README.md`
- Test: `rpi-cockpit/tests/e2e.test.ts`

**Interfaces:**
- Consumes: everything above.
- Produces: a documented way for an RPI agent to drive the cockpit, and an end-to-end test proving a beat sent over MCP reaches a WebSocket client and a decision round-trips.

- [ ] **Step 1: Write the failing end-to-end test**

```ts
// rpi-cockpit/tests/e2e.test.ts
import { describe, it, expect, afterEach } from "vitest";
import WebSocket from "ws";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { Bridge } from "../src/bridge.js";
import { startServer } from "../src/server.js";
import { buildMcpServer } from "../src/mcp.js";

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

    const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
    const states: any[] = [];
    ws.on("message", (d) => states.push(JSON.parse(String(d))));
    await new Promise((r) => ws.on("open", r));

    await client.callTool({ name: "phase_enter", arguments: { phase: "implement" } });
    await new Promise((r) => setTimeout(r, 30));
    expect(states.at(-1).state.phase).toBe("implement");

    const call = client.callTool({ name: "present_options", arguments: { prompt: "pick", options: [{ id: "a", title: "A" }] } });
    await new Promise((r) => setTimeout(r, 30));
    ws.send(JSON.stringify({ type: "decide", id: bridge.state.pendingDecision!.id, choiceId: "a" }));
    const res: any = await call;
    expect(res.content[0].text).toBe("a");
    ws.close();
  });
});
```

- [ ] **Step 2: Run to verify it fails, then passes**

Run: `cd rpi-cockpit && npx vitest run tests/e2e.test.ts`
Expected: PASS once all prior tasks are in place (it composes them). If it fails, the failure points at the integration seam to fix.

- [ ] **Step 3: Write the instrumentation snippet and registration**

```markdown
<!-- rpi-cockpit/agents/cockpit-instructions.md -->
# Cockpit instrumentation

When the `rpi-cockpit` MCP tools are available, narrate the RPI loop by calling them:

- At session start: `session_begin(task, host)`.
- On entering each phase: `phase_enter(phase)` where phase is research|plan|implement|review|discover.
- Around each subagent: `subagent_start(name, role)` before, `subagent_stop(name, result)` after.
- After writing a tracking file: `artifact_update(path, summary)`.
- On each validation check: `validate(check, status)` (status ok|running|fail|pending).
- When you would ask the user to choose between approaches, call `present_options(prompt, options[])`
  instead of asking in chat. It BLOCKS until the user picks in the cockpit and returns the chosen `id`.
  Act on the returned id.

These calls are narration only; they never change what you decide or do.
```

```json
// rpi-cockpit/.mcp.json.example  (copy to the project root .mcp.json to register with Claude Code)
{
  "mcpServers": {
    "rpi-cockpit": {
      "command": "node",
      "args": ["rpi-cockpit/dist/index.js"]
    }
  }
}
```

Write `rpi-cockpit/README.md` documenting: `npm install`, `npm run build`, copy `.mcp.json.example` to `.mcp.json`, open `http://127.0.0.1:4399`, and reference `agents/cockpit-instructions.md`.

- [ ] **Step 4: Full build and suite**

Run: `cd rpi-cockpit && npm run build && npm test`
Expected: build emits `dist/`, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md rpi-cockpit/.mcp.json.example rpi-cockpit/README.md rpi-cockpit/tests/e2e.test.ts
git commit -m "feat(cockpit): add instrumentation, registration, and e2e smoke"
```

---

## Self-Review

**Spec coverage:**
- Show → Tasks 3 (state), 8 (UI render: stepper, subagents, validations, activity stream). ✓
- Decide → Tasks 4 (handshake), 5/7 (`present_options` tool), 8 (decision card + buttons). ✓
- MCP agent face / beats → Tasks 5, 7. ✓
- Browser face (HTTP/WS) → Task 6. ✓
- Canonical state in the bridge → Tasks 3, 4. ✓
- Packaging / registration → Task 9 (`.mcp.json.example`, README). ✓
- Fluent identity → Task 8 reuses the mockup shell (light default). ✓
- Steer, persistent daemon, VS Code webview, Copilot/Codex, multi-session → intentionally **out of scope** (Global Constraints), deferred to later plans. ✓
- Failure modes (timeout fallback) → Task 4 `timeoutMs`. The polling fallback for hosts that won't hold a call, the artifact-tail safety net, and the "no MCP → read-only" mode are deferred with Steer/daemon (noted here so they are not forgotten).

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every run step shows the command and expected result.

**Type consistency:** `Beat`/`Phase`/`OptionItem` (events.ts) flow into `applyBeat` (state.ts) → `Bridge` (bridge.ts) → `handlers` (handlers.ts) → `buildMcpServer` (mcp.ts); `SessionState` → `toViewModel` (render.ts) → `client.js`. Tool names match between `handlers`, `mcp.ts`, and the tests (`phase_enter`, `present_options`, …). `present_options` returns the chosen `id` consistently across bridge, handler, tool, and both integration tests.

**One known external-dependency risk:** exact `@modelcontextprotocol/sdk` import subpaths and `registerTool` signature can vary by version. Tasks 7 and 9 include a "run and adjust the subpath" note; the TDD run-steps catch any drift immediately.
