// rpi-cockpit/preview.mjs
// Committed preview / dev harness. The host pane (Claude Preview, VS Code) sets
// PORT and loads the bare root, so we start the server in embed mode
// (trustLoopback: true). We start on the Navigator HOME (no session yet). The
// workflow launcher now lives in the chat (the present_workflows native card),
// so the standalone pane has no UI launcher; after a short delay we auto-run a
// short, representative RPI session the way a real agent would, so the loop view
// paints. Dev/preview harness only; the live agent-driven feed is a later plan.
// Requires a prior `npm run build`.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";
import { WORKFLOWS } from "./dist/catalog.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
const port = resolvePort(process.env);
const srv = await startServer(b, port, { trustLoopback: true });
// Embed mode serves the bare root without a key. No session is started here, so
// the cockpit opens on the Navigator home.
process.stderr.write(`rpi-cockpit preview at ${srv.url} (home)\n`);

// Start on the home, then auto-run one demo loop so `npm run preview` shows the
// cockpit even without a UI launcher.
setTimeout(() => {
  runSession("build").catch((e) => process.stderr.write(`preview session error: ${e?.message ?? e}\n`));
}, 1200);

async function runSession(workflowId) {
  const wf = WORKFLOWS.find((w) => w.id === workflowId);
  process.stderr.write(`rpi-cockpit preview: launching ${workflowId}\n`);

  b.emitBeat({ type: "session.begin", task: wf ? wf.name : "Workflow", host: "claude-code" });
  await sleep(500);

  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning the codebase" });
  await sleep(800);
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "done" });

  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(600);

  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying the change" });
  b.emitBeat({ type: "validate", check: "lint", status: "ok" });
  b.emitBeat({ type: "validate", check: "types", status: "ok" });
  b.emitBeat({ type: "validate", check: "tests", status: "running" });

  const choice = await b.presentOptions("Which approach?", [
    { id: "a", title: "Minimal patch", detail: "Guard the handler in place." },
    { id: "b", title: "Token middleware", detail: "Reusable middleware layer.", recommended: true },
    { id: "c", title: "Full rewrite", detail: "Policy engine, higher risk." },
  ]);
  process.stderr.write(`rpi-cockpit preview: chose ${choice}\n`);

  b.emitBeat({ type: "validate", check: "tests", status: "ok" });
  b.emitBeat({ type: "subagent.stop", name: "Phase Implementor", result: `implemented option ${choice}` });
}

// Keep the process (and the server) alive so the pane stays connected.
setInterval(() => {}, 1 << 30);
