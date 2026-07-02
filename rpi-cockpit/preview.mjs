// rpi-cockpit/preview.mjs
// Committed preview / dev harness. The host pane (Claude Preview, VS Code) sets
// PORT and loads the bare root, so we start the server in embed mode
// (trustLoopback: true). With no real agent driving beats, we run a LIVE TOUR:
// a persistent context strip, then a walk through every loop view (RPI build,
// reviewers findings, guided interview, backlog kanban), ending at rest on the
// board. This lets the pane show the whole cockpit live, with no synthetic
// client-side injection. The decision and question cards are shown with a finite
// timeout so they auto-resolve and nothing is left dangling. The live
// agent-driven feed is the real path; this is the dev/preview harness only.
// Requires a prior `npm run build`.
import { Bridge } from "./dist/bridge.js";
import { startServer } from "./dist/server.js";
import { resolvePort } from "./dist/port.js";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b = new Bridge();
const port = resolvePort(process.env);
const srv = await startServer(b, port, { trustLoopback: true });
process.stderr.write(`rpi-cockpit preview at ${srv.url} (live tour)\n`);

const HOLD = 4200; // how long a card or view rests before the tour moves on
const GAP = 1400; // a breath between scenes

// Ambient context first: the strip persists across every view in the tour.
b.emitBeat({
  type: "context.set",
  instructions: ["typescript", "writing-style", "testing"],
  skills: ["systematic-debugging", "subagent-driven-development"],
  collection: "hve-core",
});

setTimeout(() => {
  runTour().catch((e) => process.stderr.write(`preview tour error: ${e?.message ?? e}\n`));
}, 800);

async function runTour() {
  await rpiScene();
  await sleep(GAP);
  await reviewScene();
  await sleep(GAP);
  await interviewScene();
  await sleep(GAP);
  await backlogScene();
  process.stderr.write("rpi-cockpit preview: tour complete, resting on the backlog board\n");
}

async function rpiScene() {
  b.emitBeat({ type: "session.begin", task: "Add token-rotation middleware", host: "claude-code" });
  await sleep(600);
  b.emitBeat({ type: "phase.enter", phase: "research" });
  b.emitBeat({ type: "subagent.start", name: "Researcher Subagent", role: "scanning the codebase" });
  await sleep(900);
  b.emitBeat({ type: "subagent.stop", name: "Researcher Subagent", result: "mapped the auth layer" });
  b.emitBeat({ type: "phase.enter", phase: "plan" });
  await sleep(800);
  b.emitBeat({ type: "phase.enter", phase: "implement" });
  b.emitBeat({ type: "subagent.start", name: "Phase Implementor", role: "applying the change" });
  b.emitBeat({ type: "validate", check: "lint", status: "ok" });
  b.emitBeat({ type: "validate", check: "types", status: "ok" });
  b.emitBeat({ type: "validate", check: "tests", status: "running" });
  await sleep(900);
  // The decision card, shown then auto-resolved to the recommended option.
  await b.presentOptions("Which rotation strategy?", [
    { id: "a", title: "Sliding window", detail: "Refresh the token on each use." },
    { id: "b", title: "Fixed TTL", detail: "Rotate on a timer, simplest to reason about.", recommended: true },
  ], HOLD);
  b.emitBeat({ type: "validate", check: "tests", status: "ok" });
  b.emitBeat({ type: "subagent.stop", name: "Phase Implementor", result: "middleware landed" });
}

async function reviewScene() {
  b.emitBeat({ type: "review.start", target: "PR #128: token-rotation middleware" });
  await sleep(500);
  b.emitBeat({ type: "finding.add", severity: "critical", title: "Refresh token logged in plaintext", file: "src/auth/rotate.ts", line: 42, detail: "The new token is written to the debug log before hashing." });
  b.emitBeat({ type: "finding.add", severity: "high", title: "Missing expiry check on reuse", file: "src/auth/rotate.ts", line: 71 });
  b.emitBeat({ type: "finding.add", severity: "medium", title: "Magic number for the TTL", file: "src/auth/config.ts", line: 18, detail: "Extract 3600 into a named constant." });
  b.emitBeat({ type: "finding.add", severity: "low", title: "Doc comment is stale", file: "src/auth/rotate.ts", line: 5 });
  await sleep(HOLD);
}

async function interviewScene() {
  b.emitBeat({ type: "interview.start", docType: "PRD" });
  await sleep(400);
  b.emitBeat({
    type: "screen.show",
    title: "PRD draft",
    html: "<div style=\"font:13px/1.6 system-ui;color:#ccc;padding:14px\"><h2 style=\"margin:0 0 8px\">PRD: Token rotation</h2><p><b>Problem.</b> Long-lived tokens widen the blast radius of a leak.</p><p><b>Goal.</b> Rotate tokens automatically without logging the user out.</p><p style=\"opacity:.6\">Filling in: primary user goal…</p></div>",
  });
  // The question card, shown then auto-resolved (empty) so it clears.
  await b.askQuestion("What is the primary user goal for token rotation?", HOLD);
  b.clearScreen();
}

async function backlogScene() {
  b.emitBeat({ type: "backlog.start", target: "Sprint 24", columns: ["Triage", "Todo", "In progress", "In review", "Done"] });
  await sleep(400);
  b.emitBeat({ type: "item.add", id: "#312", title: "Login throttle returns 500 on burst", column: "Triage", kind: "bug", tier: "ask" });
  b.emitBeat({ type: "item.add", id: "#298", title: "Add audit log export endpoint", column: "Todo", kind: "feature", tier: "auto" });
  b.emitBeat({ type: "item.add", id: "#305", title: "Upgrade the pg driver to v8", column: "Todo", kind: "chore" });
  b.emitBeat({ type: "item.add", id: "#287", title: "Token rotation middleware", column: "In progress", kind: "feature", tier: "auto" });
  b.emitBeat({ type: "item.add", id: "#270", title: "Fix flaky cache eviction test", column: "Done", kind: "bug" });
  b.emitBeat({ type: "backlog.action", text: "Triaging #312" });
  await sleep(HOLD);
  // Show movement: triage resolves, an item advances.
  b.emitBeat({ type: "item.move", id: "#312", column: "Todo" });
  b.emitBeat({ type: "item.move", id: "#287", column: "In review" });
  b.emitBeat({ type: "backlog.action", text: "Planning the next pull" });
}

// Keep the process (and the server) alive so the pane stays connected.
setInterval(() => {}, 1 << 30);
