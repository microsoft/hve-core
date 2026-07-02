// Agent gallery producer: renders every one of the 65 HVE Core agents through
// the real cockpit client.js in happy-dom, then opens the gallery surface so
// the live cockpit shows all agents grouped by category as html gallery items.
//
// Run: node tools/agent-gallery.mjs
// Prints: agent gallery: http://...  and keeps the server alive.
import { Bridge } from "../dist/bridge.js";
import { startServer } from "../dist/server.js";
import { handlers } from "../dist/handlers.js";
import { liveStateDir } from "../dist/paths.js";
import { initialState, applyBeat } from "../dist/state.js";
import { toViewModel } from "../dist/render.js";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import { Buffer } from "node:buffer";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const cockpitDir = path.join(root, "rpi-cockpit");

const html = readFileSync(path.join(cockpitDir, "public/index.html"), "utf8");
const js = readFileSync(path.join(cockpitDir, "public/client.js"), "utf8");
const CSS = html.match(/<style>([\s\S]*?)<\/style>/)[1];

function capture(beats, mutate) {
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  win.WebSocket = class { readyState = 1; send() {} close() {} addEventListener() {} removeEventListener() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  let s = initialState();
  let t = 1;
  for (const b of beats) s = applyBeat(s, b, t++);
  if (mutate) s = mutate(s);
  win.render(toViewModel(s));
  const body = win.document.body.innerHTML;
  win.close?.();
  return body;
}

// ---- surface builders: each returns { beats, mutate? } ------------------------
const opt = (id, title, detail) => ({ id, title, ...(detail ? { detail } : {}) });

function rpi({ task, host, phases = [], subs = [], vals = [], arts = [], steer, decisions }) {
  const beats = [{ type: "session.begin", task, host }];
  for (const p of phases) beats.push({ type: "phase.enter", phase: p });
  for (const a of arts) beats.push({ type: "artifact.update", path: a.path, summary: a.summary });
  for (const su of subs) beats.push({ type: "subagent.start", name: su.name, role: su.role });
  for (const v of vals) beats.push({ type: "validate", check: v.check, status: v.status });
  if (steer) beats.push({ type: "approaches.offer", label: steer.label, options: steer.options });
  return { beats, mutate: decisions ? (s) => ({ ...s, decisions, hostElicits: false }) : undefined };
}

function review({ task, host, target, findings = [], subs = [] }) {
  const beats = [{ type: "session.begin", task, host }, { type: "review.start", target }];
  for (const su of subs) beats.push({ type: "subagent.start", name: su.name, role: su.role });
  for (const f of findings) beats.push({ type: "finding.add", severity: f.sev, title: f.title, file: f.file, line: f.line, detail: f.detail });
  return { beats };
}

function interview({ task, host, docType, steps, q, draft }) {
  const beats = [{ type: "session.begin", task, host }, { type: "interview.start", docType }];
  if (steps) beats.push({ type: "steps.set", steps: steps.names, current: steps.current, label: steps.label, progress: steps.progress });
  if (draft) beats.push({ type: "screen.show", html: draft, title: `${docType} draft` });
  const mutate = q ? (s) => ({ ...s, hostElicits: false, decisions: q }) : undefined;
  return { beats, mutate };
}

function backlog({ task, host, target, columns, items = [], action }) {
  const beats = [{ type: "session.begin", task, host }, { type: "backlog.start", target, columns }];
  for (const it of items) beats.push({ type: "item.add", id: it.id, title: it.title, column: it.col, kind: it.kind, tier: it.tier, parent: it.parent });
  if (action) beats.push({ type: "backlog.action", text: action });
  return { beats };
}

function team({ task, host, agents = [] }) {
  const beats = [{ type: "session.begin", task, host }, { type: "team.start", task, orchestrator: host }];
  for (const a of agents) beats.push({ type: "agent.add", id: a.id, name: a.name, role: a.role, status: a.status });
  return { beats };
}

function dataprofile({ task, host, ds, columns = [] }) {
  const beats = [{ type: "session.begin", task, host }, { type: "profile.start", name: ds.name, rows: ds.rows, columns: ds.cols, source: ds.source }];
  for (const c of columns) beats.push({ type: "column.add", name: c.name, dtype: c.dtype, nullPct: c.nullPct, distinct: c.distinct, stat: c.stat, quality: c.quality });
  return { beats };
}

function screen({ task, host, body, title }) {
  return { beats: [{ type: "session.begin", task, host }, { type: "screen.show", html: body, title }] };
}

function flow({ task, host, title, nodes = [], edges = [], focus }) {
  const beats = [{ type: "session.begin", task, host }, { type: "flow.open", title }];
  for (const n of nodes) beats.push({ type: "flownode.add", id: n.id, kind: n.kind, label: n.label, scope: n.scope, sub: n.sub, status: n.status });
  for (const e of edges) beats.push({ type: "flowedge.add", id: e.id, from: e.from, to: e.to, scope: e.scope, kind: e.kind, label: e.label, status: e.status });
  if (focus) beats.push({ type: "flow.focus", workflow: focus });
  return { beats };
}

function memory({ task, host, title, entries = [], handoffs = [] }) {
  const beats = [{ type: "session.begin", task, host }, { type: "memory.open", title }];
  for (const e of entries) beats.push({ type: "memory.add", id: e.id, content: e.content, category: e.category, tag: e.tag, title: e.title });
  for (const h of handoffs) beats.push({ type: "handoff.add", id: h.id, from: h.from, summary: h.summary, action: h.action });
  return { beats };
}

function promptlab({ task, host, name, prompt, round, cases = [] }) {
  const beats = [{ type: "session.begin", task, host }, { type: "promptlab.start", name, prompt, round }];
  for (const c of cases) beats.push({ type: "case.add", id: c.id, scenario: c.scenario, output: c.output, verdict: c.verdict, note: c.note });
  return { beats };
}

function ctx({ task, host, instructions, skills, collection, note }) {
  return { beats: [
    { type: "session.begin", task, host },
    { type: "context.set", instructions, skills, collection },
    { type: "screen.show", html: note, title: host },
  ] };
}

function appframe({ task, host, phases = [], subs = [], review: rev }) {
  const beats = [{ type: "session.begin", task, host }];
  for (const p of phases) beats.push({ type: "phase.enter", phase: p });
  for (const su of subs) beats.push({ type: "subagent.start", name: su.name, role: su.role });
  if (rev) {
    beats.push({ type: "review.start", target: rev.target });
    for (const f of rev.findings) beats.push({ type: "finding.add", severity: f.sev, title: f.title, file: f.file, line: f.line });
  }
  beats.push({ type: "appframe.set", url: "http://localhost:8501/" });
  return { beats, appMock: true };
}

const DASH_MOCK = `<!doctype html><meta charset=utf8><body style="margin:0;font-family:system-ui;background:#0f1117;color:#e6e6e6">
<div style="padding:14px 18px;border-bottom:1px solid #2a2f3a;font-weight:600">Sales Explorer <span style="color:#6c7280;font-weight:400">streamlit</span></div>
<div style="display:flex;gap:14px;padding:16px">
<div style="flex:1;background:#161922;border:1px solid #2a2f3a;border-radius:8px;padding:14px"><div style="color:#8b93a7;font-size:12px">Revenue</div><div style="font-size:26px;font-weight:700">$1.28M</div><div style="color:#41d18b;font-size:12px">+12.4%</div></div>
<div style="flex:1;background:#161922;border:1px solid #2a2f3a;border-radius:8px;padding:14px"><div style="color:#8b93a7;font-size:12px">Orders</div><div style="font-size:26px;font-weight:700">38,201</div><div style="color:#41d18b;font-size:12px">+4.1%</div></div></div>
<div style="margin:0 16px;background:#161922;border:1px solid #2a2f3a;border-radius:8px;padding:14px;height:120px;display:flex;align-items:flex-end;gap:6px">
<div style="flex:1;background:#3b82f6;height:40%"></div><div style="flex:1;background:#3b82f6;height:62%"></div><div style="flex:1;background:#3b82f6;height:48%"></div><div style="flex:1;background:#3b82f6;height:78%"></div><div style="flex:1;background:#3b82f6;height:90%"></div><div style="flex:1;background:#3b82f6;height:70%"></div></div></body>`;
const DASH_DATAURL = "data:text/html;base64," + Buffer.from(DASH_MOCK).toString("base64");

function decodeEntities(s) {
  return s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&#x27;/gi, "'").replace(/&amp;/g, "&");
}
function inlineSrcdoc(inner) {
  return inner.replace(/srcdoc="([^"]*)"/g, (_m, val) => {
    const raw = decodeEntities(val);
    if (!raw.trim()) return `src="data:text/html;base64,${Buffer.from('<!doctype html><body style="margin:0;background:#1e1e1e">', "utf8").toString("base64")}"`;
    const full = /^\s*<(!doctype|html|body)/i.test(raw)
      ? raw
      : `<!doctype html><meta charset=utf8><body style="margin:0;background:#1e1e1e;color:#e0e0e0;font-family:'Segoe UI',system-ui,sans-serif">${raw}`;
    return `src="data:text/html;base64,${Buffer.from(full, "utf8").toString("base64")}"`;
  });
}

// ---- the 65 agents, by category ----------------------------------------------
const CATS = [
  { cat: "build-loop (RPI loop)", agents: [
    [1, "RPI Agent", rpi({ task: "Ship the auth refactor", host: "RPI Agent", phases: ["research", "plan", "implement"], subs: [{ name: "Phase Implementor", role: "auth module" }], vals: [{ check: "types", status: "ok" }, { check: "tests", status: "running" }], steer: { label: "Next-phase approach", options: [opt("a", "Finish implement"), opt("b", "Jump to review")] } })],
    [2, "Task Researcher", rpi({ task: "Map the payments subsystem", host: "Task Researcher", phases: ["research"], arts: [{ path: ".omc/research/payments.md", summary: "12 modules, 3 external gateways" }], subs: [{ name: "Researcher Subagent", role: "trace Stripe calls" }] })],
    [3, "Task Planner", rpi({ task: "Plan the migration to Postgres 16", host: "Task Planner", phases: ["research", "plan"], arts: [{ path: ".omc/plans/pg16.md", summary: "7 tasks, 2 reversible gates" }] })],
    [4, "Task Implementor", rpi({ task: "Implement rate limiting", host: "Task Implementor", phases: ["research", "plan", "implement"], subs: [{ name: "Phase Implementor", role: "token bucket" }, { name: "Phase Implementor", role: "redis store" }], vals: [{ check: "lint", status: "ok" }, { check: "unit", status: "ok" }, { check: "integration", status: "running" }] })],
    [5, "Task Reviewer", rpi({ task: "Review the implemented changes", host: "Task Reviewer", phases: ["research", "plan", "implement", "review"], vals: [{ check: "diff scope", status: "ok" }, { check: "tests pass", status: "ok" }, { check: "no regressions", status: "ok" }] })],
    [6, "Task Challenger", rpi({ task: "Pressure-test the auth design", host: "Task Challenger", phases: ["plan"], decisions: [
      { id: "d1", prompt: "What: which session strategy?", kind: "choice", status: "answered", options: [opt("jwt", "Stateless JWT"), opt("srv", "Server sessions")], answer: "jwt" },
      { id: "d2", prompt: "Why: what forces statelessness?", kind: "text", status: "answered", answer: "Horizontal scale across 6 nodes, no sticky routing." },
      { id: "d3", prompt: "How: token rotation cadence?", kind: "choice", status: "pending", options: [opt("15m", "Every 15 min", "tighter blast radius"), opt("1h", "Hourly", "fewer refreshes")] },
    ] })],
    [7, "Phase Implementor", rpi({ task: "Implement the cache layer (phase 2/4)", host: "Phase Implementor", phases: ["implement"], subs: [{ name: "Phase Implementor", role: "LRU eviction" }], vals: [{ check: "unit", status: "ok" }, { check: "bench", status: "running" }] })],
    [8, "Plan Validator", rpi({ task: "Validate the plan before execution", host: "Plan Validator", phases: ["plan"], vals: [{ check: "goal coverage", status: "ok" }, { check: "task ordering", status: "ok" }, { check: "missing rollback gate", status: "fail" }] })],
    [9, "Implementation Validator", rpi({ task: "Validate the implementation", host: "Implementation Validator", phases: ["implement"], vals: [{ check: "matches plan", status: "ok" }, { check: "tests adequate", status: "fail" }, { check: "no scope creep", status: "ok" }] })],
    [10, "RPI Validator", rpi({ task: "Validate the full RPI cycle", host: "RPI Validator", phases: ["research", "plan", "implement", "review"], vals: [{ check: "research grounded", status: "ok" }, { check: "plan honored", status: "ok" }, { check: "goal achieved", status: "fail" }] })],
    [11, "Researcher Subagent", rpi({ task: "Trace the event bus wiring", host: "Researcher Subagent", phases: ["research"], subs: [{ name: "Researcher Subagent", role: "follow publish/subscribe" }], arts: [{ path: ".omc/research/eventbus.md", summary: "4 publishers, 9 subscribers" }] })],
    [12, "Network ISA-95 Planner", rpi({ task: "Plan the OT/IT network segmentation", host: "Network ISA-95 Planner", phases: ["research", "plan"], arts: [{ path: ".omc/plans/isa95.md", summary: "5 levels, 3 DMZ conduits" }] })],
  ] },
  { cat: "review (findings panel)", agents: [
    [13, "Code Review Full", review({ task: "Full review of feat/checkout", host: "Code Review Full", target: "branch: feat/checkout", subs: [{ name: "Security Reviewer", role: "injection + authz" }, { name: "Accessibility Reviewer", role: "WCAG 2.2" }, { name: "Report Generator", role: "synthesize" }], findings: [{ sev: "high", title: "Unvalidated redirect after checkout", file: "checkout.ts", line: 88, detail: "next param is not allow-listed." }, { sev: "medium", title: "N+1 query on order items", file: "orders.ts", line: 142 }, { sev: "low", title: "Magic number 3600", file: "cart.ts", line: 51 }] })],
    [14, "Code Review Functional", review({ task: "Functional review", host: "Code Review Functional", target: "branch: feat/auth", findings: [{ sev: "high", title: "Missing null check on token", file: "auth.ts", line: 42, detail: "verifyJwt can return null." }, { sev: "low", title: "Dead branch after early return", file: "auth.ts", line: 73 }] })],
    [15, "Code Review Standards", review({ task: "Standards + conventions review", host: "Code Review Standards", target: "branch: feat/auth", findings: [{ sev: "medium", title: "Naming: useFoo is not a hook", file: "util.ts", line: 12 }, { sev: "info", title: "Prefer const over let", file: "util.ts", line: 30 }] })],
    [16, "Code Review Accessibility", review({ task: "Accessibility review", host: "Code Review Accessibility", target: "PR #214", findings: [{ sev: "high", title: "Icon button has no accessible name", file: "Toolbar.tsx", line: 64 }, { sev: "medium", title: "Contrast 3.1:1 below 4.5:1", file: "theme.css", line: 22 }] })],
    [17, "PR Review", review({ task: "Review PR #214", host: "PR Review", target: "PR #214: add SSO", findings: [{ sev: "critical", title: "Secret committed in config", file: ".env.example", line: 4, detail: "Looks like a live client secret." }, { sev: "medium", title: "No test for SSO failure path", file: "sso.test.ts", line: 1 }] })],
    [18, "PR Walkthrough", screen({ task: "Orient a reviewer on PR #214", host: "PR Walkthrough", title: "PR #214 walkthrough", body: `<div style="font-family:system-ui;color:#ddd;padding:14px;line-height:1.6"><h3 style="margin:0 0 8px">PR #214: SSO orientation</h3><p><b>The shape:</b> adds an OIDC provider behind the existing AuthGateway, so callers are unchanged.</p><p><b>Design fork taken:</b> tokens are exchanged server-side (not implicit flow) to keep secrets off the client.</p><p><b>Implicit bet:</b> the IdP honors refresh tokens; if not, sessions silently expire at 1h.</p><p><b>Where to look first:</b> <code>sso.ts:exchange()</code> then <code>AuthGateway.adopt()</code>.</p></div>` })],
    [19, "Dependency Reviewer", review({ task: "Review dependency changes", host: "Dependency Reviewer", target: "package.json diff", findings: [{ sev: "high", title: "lodash 4.17.19 has prototype pollution CVE", file: "package.json", line: 18 }, { sev: "info", title: "3 transitive deps deduped", file: "package-lock.json", line: 1 }] })],
    [20, "Security Reviewer", review({ task: "Security audit of the API", host: "Security Reviewer", target: "scope: /api/*", subs: [{ name: "Finding Deep Verifier", role: "confirm SSRF" }, { name: "Report Generator", role: "severity rollup" }], findings: [{ sev: "critical", title: "SSRF via webhook URL", file: "webhooks.ts", line: 31, detail: "User-supplied URL fetched server-side without allow-list." }, { sev: "high", title: "JWT alg not pinned", file: "auth.ts", line: 12 }] })],
    [21, "Accessibility Reviewer", review({ task: "Audit the design system", host: "Accessibility Reviewer", target: "scope: components/", subs: [{ name: "Codebase Profiler", role: "enumerate components" }, { name: "Report Generator", role: "WCAG rollup" }], findings: [{ sev: "high", title: "Modal does not trap focus", file: "Modal.tsx", line: 40 }, { sev: "medium", title: "Live region missing for toasts", file: "Toast.tsx", line: 18 }] })],
    [22, "RAI Reviewer", review({ task: "Responsible-AI review", host: "RAI Reviewer", target: "feature: summarizer", subs: [{ name: "Finding Deep Verifier", role: "check fairness claim" }, { name: "Report Generator", role: "RAI rollup" }], findings: [{ sev: "high", title: "No content-safety filter on output", file: "summarize.ts", line: 55 }, { sev: "medium", title: "PII may pass into prompt", file: "summarize.ts", line: 22 }] })],
    [23, "Codebase Profiler", review({ task: "Profile the codebase for review", host: "Codebase Profiler", target: "repo: hve-core", subs: [{ name: "Codebase Profiler", role: "map hot files + churn" }], findings: [{ sev: "info", title: "Top churn: render.ts (42 commits)", file: "render.ts", line: 1 }] })],
    [24, "Finding Deep Verifier", review({ task: "Deep-verify candidate findings", host: "Finding Deep Verifier", target: "queue: 6 findings", subs: [{ name: "Finding Deep Verifier", role: "reproduce SSRF locally" }], findings: [{ sev: "critical", title: "CONFIRMED: SSRF reproduces", file: "webhooks.ts", line: 31 }] })],
    [25, "Report Generator", review({ task: "Generate the review report", host: "Report Generator", target: "8 confirmed findings", subs: [{ name: "Report Generator", role: "group by severity + write summary" }], findings: [{ sev: "info", title: "Report ready: 1 critical, 3 high, 4 medium", file: "REVIEW.md", line: 1 }] })],
  ] },
  { cat: "doc-builder (interview view)", agents: [
    [26, "PRD Builder", interview({ task: "Author the Cockpit PRD", host: "PRD Builder", docType: "PRD", q: [{ id: "q1", prompt: "Who is the primary user of this product?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:14px;line-height:1.6"><h3 style="margin:0 0 6px">PRD: HVE Cockpit</h3><p><b>Problem.</b> Agentic coding sessions are opaque: a reviewer or operator cannot see what phase the loop is in, which subagents are running, or what decisions were made, and cannot steer mid-run.</p><p><b>Goal.</b> Make every session legible and steerable through a host-agnostic web GUI driven by an MCP bridge.</p><p><b>Primary users.</b> The driving engineer; a reviewing teammate; an orchestrator running a fleet of subagents.</p><p><b>Success metrics.</b> Time-to-understand a run under 10s; mid-run steer accepted without restart; zero new agent dependencies.</p><h4 style="margin:12px 0 4px">Functional requirements</h4><ul style="margin:0;padding-left:18px"><li>One legible surface per kind of work (loop, review, interview, backlog, team, codemap, dataprofile).</li><li>Decisions are navigable and revisitable; questions answered inline.</li><li>Non-blocking narration; blocking only for explicit options/questions.</li><li>Live cross-process bridge so the GUI follows a separate agent process.</li></ul><h4 style="margin:12px 0 4px">Non-goals</h4><ul style="margin:0;padding-left:18px"><li>Not a replacement for the terminal transcript.</li><li>Not a host-specific plugin; the bridge is the only contract.</li></ul><h4 style="margin:12px 0 4px">Open questions</h4><p>Session replay/time-machine scrubber; rewind-and-branch; remote/mobile viewing.</p><p style="color:#8a8a8a">Draft continues as the interview proceeds…</p></div>` })],
    [27, "BRD Builder", interview({ task: "Author the BRD", host: "BRD Builder", docType: "BRD", q: [{ id: "q1", prompt: "What business outcome defines success?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>BRD: Cockpit</h3><p><b>Objective.</b> Reduce time-to-trust in agent runs.</p><p><b>Scope.</b> …</p></div>` })],
    [28, "ADR Creator", interview({ task: "Record the bridge-architecture ADR", host: "ADR Creator", docType: "ADR", steps: { names: ["Frame", "Decide", "Govern"], current: 1, label: "Decide" }, q: [{ id: "q1", prompt: "What is the decision and its main alternative?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>ADR 014: Cross-process bridge</h3><p><b>Context.</b> Host and cockpit are separate processes.</p><p><b>Decision.</b> Snapshot file + inbox tail.</p></div>` })],
    [29, "Product Manager Advisor", interview({ task: "Shape the roadmap", host: "Product Manager Advisor", docType: "Roadmap", q: [{ id: "q1", prompt: "Which outcome matters most next quarter?", kind: "choice", status: "pending", options: [opt("trust", "Trust + legibility"), opt("scale", "Multi-session scale")] }] })],
    [30, "System Architecture Reviewer", interview({ task: "Review the system architecture", host: "System Architecture Reviewer", docType: "Arch review", q: [{ id: "q1", prompt: "What is the hardest scaling constraint today?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>Architecture review</h3><p><b>Strengths.</b> Pure reducer, clean beats.</p><p><b>Risks.</b> Single snapshot writer.</p></div>` })],
    [31, "Meeting Analyst", interview({ task: "Extract requirements from the kickoff", host: "Meeting Analyst", docType: "Requirements", draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>Extracted requirements</h3><ul><li>Host-agnostic GUI</li><li>Steerable mid-run</li><li>No new agent deps</li></ul></div>` })],
    [32, "Security Planner", interview({ task: "Plan the security program", host: "Security Planner", docType: "Security plan", steps: { names: ["Assets", "Threats", "Controls", "Validate"], current: 1, label: "Threats" }, q: [{ id: "q1", prompt: "What is the most sensitive asset in scope?", kind: "text", status: "pending" }] })],
    [33, "SSSC Planner", interview({ task: "Plan secure software supply chain", host: "SSSC Planner", docType: "SSSC plan", steps: { names: ["Source", "Build", "Deps", "Artifacts", "Deploy", "Monitor"], current: 2, label: "Deps" }, q: [{ id: "q1", prompt: "Are dependencies pinned and provenance-checked?", kind: "choice", status: "pending", options: [opt("y", "Yes, fully"), opt("p", "Partially"), opt("n", "No")] }] })],
    [34, "RAI Planner", interview({ task: "Plan responsible-AI controls", host: "RAI Planner", docType: "RAI plan", steps: { names: ["Map", "Measure", "Mitigate", "Govern"], current: 2, label: "Mitigate" }, q: [{ id: "q1", prompt: "Which harm category is highest risk here?", kind: "text", status: "pending" }] })],
    [35, "Accessibility Planner", interview({ task: "Plan the accessibility program", host: "Accessibility Planner", docType: "A11y plan", steps: { names: ["Audit", "Prioritize", "Remediate", "Verify"], current: 1, label: "Prioritize" }, q: [{ id: "q1", prompt: "What is the target conformance level?", kind: "choice", status: "pending", options: [opt("aa", "WCAG 2.2 AA"), opt("aaa", "AAA")] }] })],
    [36, "BRD Quality Reviewer", review({ task: "Review BRD quality", host: "BRD Quality Reviewer", target: "doc: BRD-cockpit", findings: [{ sev: "medium", title: "Success metric is not measurable", file: "BRD.md", line: 14 }, { sev: "low", title: "Stakeholder list incomplete", file: "BRD.md", line: 8 }] })],
    [37, "PRD Quality Reviewer", review({ task: "Review PRD quality", host: "PRD Quality Reviewer", target: "doc: PRD-cockpit", findings: [{ sev: "high", title: "No non-goals section", file: "PRD.md", line: 1 }, { sev: "medium", title: "Acceptance criteria ambiguous", file: "PRD.md", line: 33 }] })],
    [38, "RAI Skill Assessor", review({ task: "Assess RAI skill coverage", host: "RAI Skill Assessor", target: "skill: rai-planner", findings: [{ sev: "medium", title: "Missing measurement rubric for bias", file: "rai.md", line: 20 }, { sev: "info", title: "Governance step present", file: "rai.md", line: 40 }] })],
  ] },
  { cat: "backlog (kanban view)", agents: [
    [39, "GitHub Backlog Manager", backlog({ task: "Groom Sprint 24", host: "GitHub Backlog Manager", target: "Sprint 24", columns: ["Triage", "Todo", "Doing", "Done"], items: [{ id: "B1", title: "Fix login redirect", col: "Todo", kind: "bug", tier: "T1" }, { id: "B2", title: "Add SSO", col: "Doing", kind: "feature" }, { id: "B3", title: "Upgrade Node 20", col: "Done", kind: "chore" }, { id: "B4", title: "Flaky checkout test", col: "Triage", kind: "bug" }], action: "Triaging 6 new issues" })],
    [40, "ADO Backlog Manager", backlog({ task: "Plan the ADO iteration", host: "ADO Backlog Manager", target: "Iteration 12", columns: ["New", "Active", "Resolved", "Closed"], items: [{ id: "W1", title: "Telemetry pipeline", col: "Active", kind: "feature" }, { id: "W2", title: "Auth bug", col: "New", kind: "bug", tier: "Sev2" }, { id: "W3", title: "Docs refresh", col: "Closed", kind: "task" }], action: "Assigning to iteration" })],
    [41, "Jira Backlog Manager", backlog({ task: "Refine the Jira sprint", host: "Jira Backlog Manager", target: "SCRUM Sprint 8", columns: ["Backlog", "Selected", "In Progress", "Done"], items: [{ id: "J1", title: "Checkout API", col: "In Progress", kind: "story", tier: "5pt" }, { id: "J2", title: "Cart bug", col: "Selected", kind: "bug" }, { id: "J3", title: "Release notes", col: "Done", kind: "task" }], action: "Estimating story points" })],
    [42, "AzDO PRD to WIT", backlog({ task: "Decompose PRD into work items", host: "AzDO PRD to WIT", target: "PRD: Cockpit", columns: ["Epics", "Features", "Stories", "Tasks"], items: [
      { id: "E1", title: "Cockpit GUI", col: "Epics", kind: "epic" },
      { id: "F1", title: "Loop views", col: "Features", kind: "feature", parent: "E1" },
      { id: "S1", title: "RPI view", col: "Stories", kind: "story", parent: "F1" },
      { id: "T1", title: "Phase rail", col: "Tasks", kind: "task", parent: "S1" },
      { id: "T2", title: "Validation gate", col: "Tasks", kind: "task", parent: "S1" },
    ], action: "Generating WIT tree from PRD" })],
    [43, "Jira PRD to WIT", backlog({ task: "Decompose PRD into Jira hierarchy", host: "Jira PRD to WIT", target: "PRD: Cockpit", columns: ["Epics", "Stories", "Subtasks"], items: [
      { id: "E1", title: "Backlog board", col: "Epics", kind: "epic" },
      { id: "S1", title: "Kanban columns", col: "Stories", kind: "story", parent: "E1" },
      { id: "S2", title: "Parent/child indent", col: "Stories", kind: "story", parent: "E1" },
      { id: "U1", title: "Indent depth calc", col: "Subtasks", kind: "subtask", parent: "S2" },
    ], action: "Mapping requirements to issues" })],
  ] },
  { cat: "data-science (mixed surfaces)", agents: [
    [44, "Evaluation Dataset Creator", interview({ task: "Curate an eval dataset", host: "Evaluation Dataset Creator", docType: "Eval set", q: [{ id: "q1", prompt: "What capability are we measuring?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>Eval set: summarization</h3><p>120 examples · 3 difficulty tiers · gold + rubric</p></div>` })],
    [45, "DS Gen Data Spec", dataprofile({ task: "Profile sales.csv", host: "DS Gen Data Spec", ds: { name: "sales.csv", rows: 38201, cols: 4, source: "warehouse" }, columns: [
      { name: "id", dtype: "int", nullPct: 0, distinct: 38201, stat: "1–38201", quality: "ok" },
      { name: "region", dtype: "category", nullPct: 0, distinct: 5, stat: "top: US 42%", quality: "ok" },
      { name: "revenue", dtype: "float", nullPct: 2.1, distinct: 31044, stat: "μ 33.6 σ 14.2", quality: "warn" },
      { name: "promo_code", dtype: "string", nullPct: 61.0, distinct: 88, stat: "61% null", quality: "risk" },
    ] })],
    [46, "DS Gen Jupyter Notebook", screen({ task: "Generate an analysis notebook", host: "DS Gen Jupyter Notebook", title: "sales_analysis.ipynb", body: `<div style="font-family:ui-monospace,monospace;color:#ddd;padding:12px;font-size:12px"><div style="background:#0d1b2a;border-left:3px solid #3b82f6;padding:8px;margin-bottom:8px"><b>[1]</b> import pandas as pd; df = pd.read_csv("sales.csv")</div><div style="background:#0d1b2a;border-left:3px solid #3b82f6;padding:8px;margin-bottom:8px"><b>[2]</b> df.groupby("region").revenue.sum()</div><div style="background:#11261a;border-left:3px solid #41d18b;padding:8px"><b>out:</b> US 540320 · EU 318900 · APAC 221440</div></div>` })],
    [47, "DS Gen Streamlit Dashboard", appframe({ task: "Build the sales dashboard", host: "DS Gen Streamlit Dashboard", phases: ["implement"], subs: [{ name: "Phase Implementor", role: "wire charts" }] })],
    [48, "DS Test Streamlit Dashboard", appframe({ task: "Test the live dashboard", host: "DS Test Streamlit Dashboard", review: { target: "app: sales dashboard", findings: [{ sev: "high", title: "KPI card crashes on empty filter", file: "app.py", line: 64 }, { sev: "medium", title: "Chart has no alt text", file: "app.py", line: 92 }] } })],
  ] },
  { cat: "coach (interview view)", agents: [
    [49, "DT Coach", interview({ task: "Facilitate a design-thinking sprint", host: "DT Coach", docType: "DT session", steps: { names: ["Empathize", "Define", "Ideate", "Prototype", "Test"], current: 2, label: "Ideate" }, q: [{ id: "q1", prompt: "What unmet user need are we framing?", kind: "text", status: "pending" }] })],
    [50, "DT Learning Tutor", interview({ task: "Teach the RPI loop", host: "DT Learning Tutor", docType: "Lesson", steps: { names: ["Concept", "Example", "Practice", "Check"], current: 2, label: "Practice", progress: { done: 2, total: 5 } }, q: [{ id: "q1", prompt: "Which phase produces the plan artifact?", kind: "choice", status: "pending", options: [opt("r", "Research"), opt("p", "Plan"), opt("i", "Implement")] }] })],
    [51, "Agile Coach", interview({ task: "Turn goals into user stories", host: "Agile Coach", docType: "Stories", draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>User stories</h3><ul><li>As a reviewer, I see findings grouped by severity…</li><li>As an orchestrator, I steer a running agent…</li></ul></div>` })],
    [52, "Experiment Designer", interview({ task: "Design an A/B experiment", host: "Experiment Designer", docType: "Experiment", steps: { names: ["Hypothesis", "Vet", "Plan"], current: 0, label: "Hypothesis" }, q: [{ id: "q1", prompt: "State the hypothesis and the metric it moves.", kind: "text", status: "pending" }] })],
    [53, "UX UI Designer", interview({ task: "Design the onboarding flow", host: "UX UI Designer", docType: "UX spec", q: [{ id: "q1", prompt: "What job is the user hiring this flow to do?", kind: "text", status: "pending" }], draft: `<div style="font-family:system-ui;color:#ddd;padding:12px"><h3>Onboarding · JTBD</h3><p>When I first open the cockpit, I want to understand the run at a glance…</p></div>` })],
  ] },
  { cat: "orchestrator (team view)", agents: [
    [54, "Documentation", team({ task: "Docs audit + refresh", host: "Documentation", agents: [{ id: "a1", name: "Phase Implementor", role: "rewrite README", status: "running" }, { id: "a2", name: "Researcher Subagent", role: "find drift", status: "done" }, { id: "a3", name: "Report Generator", role: "changelog", status: "queued" }] })],
    [55, "Prompt Builder", team({ task: "Build + harden a prompt", host: "Prompt Builder", agents: [{ id: "a1", name: "Prompt Tester", role: "stress cases", status: "running" }, { id: "a2", name: "Prompt Evaluator", role: "score outputs", status: "blocked" }, { id: "a3", name: "Prompt Updater", role: "apply fixes", status: "queued" }] })],
    [56, "PowerPoint Builder", screen({ task: "Build the quarterly deck", host: "PowerPoint Builder", title: "Q3 review.pptx", body: `<div style="font-family:system-ui;color:#222;padding:0"><div style="background:#fff;border:1px solid #ccc;margin:8px;padding:18px;border-radius:4px"><div style="font-size:20px;font-weight:700;color:#1a1a1a">Q3 Review</div><div style="color:#666;margin-top:4px">Cockpit adoption + roadmap</div></div><div style="display:flex;gap:8px;margin:0 8px"><div style="flex:1;background:#fff;border:1px solid #ccc;padding:10px;border-radius:4px;font-size:11px;color:#333">Slide 2 · Metrics</div><div style="flex:1;background:#fff;border:1px solid #ccc;padding:10px;border-radius:4px;font-size:11px;color:#333">Slide 3 · Roadmap</div></div></div>` })],
  ] },
  { cat: "meta-utility (mixed)", agents: [
    [57, "Memory", memory({ task: "Recall + maintain project memory", host: "Memory", title: "hve-core",
      entries: [
        { id: "u1", title: "Output style", content: "Terse output; act when there is enough information rather than narrating options.", category: "user", tag: "recalled" },
        { id: "u2", title: "Markdown house style", content: "No em-dashes, asterisk bullets; lint to zero before committing.", category: "user", tag: "recalled" },
        { id: "p1", title: "Push target", content: "Cockpit work goes to the fork, never the upstream, one PR per feature.", category: "project", tag: "recalled" },
        { id: "p2", title: "Memory surface shipped", content: "Built the memory view (category-grouped entries + handoff strip) this session.", category: "project", tag: "added" },
        { id: "f1", title: "Verify, do not assume", content: "Confirm outcomes with evidence before claiming completion.", category: "feedback", tag: "updated" },
        { id: "r1", title: "Design spec", content: "rpi-cockpit/docs/memory-view-design.md", category: "reference", tag: "added" },
      ],
      handoffs: [
        { id: "h1", from: "GitHub Backlog Manager", summary: "Sprint board state + the action it was taking", action: "stored" },
        { id: "h2", from: "RPI Agent", summary: "The auth-refactor plan + which phase it parked at", action: "merged" },
      ] })],
    [58, "GitHub Agentic Workflows Agent", flow({ task: "Create + debug a gh-aw workflow", host: "GitHub Agentic Workflows Agent", title: "hve-core gh-aw pipeline",
      nodes: [
        { id: "triage", kind: "workflow", label: "Issue Triage", sub: "copilot · on issues", status: "passed" },
        { id: "implement", kind: "workflow", label: "Issue Implement", sub: "copilot · on agent-ready", status: "running" },
        { id: "review", kind: "workflow", label: "PR Review", sub: "claude · on PR" },
        { id: "deps", kind: "workflow", label: "Dependency PR Review", sub: "claude · on PR" },
        { id: "docs", kind: "workflow", label: "Doc Update Check", sub: "copilot · on push main" },
      ],
      edges: [
        { id: "e1", from: "triage", to: "implement", kind: "label", label: "agent-ready", status: "active" },
        { id: "e2", from: "implement", to: "review", kind: "event", label: "opens PR" },
        { id: "e3", from: "implement", to: "deps", kind: "event", label: "opens PR" },
        { id: "e4", from: "review", to: "docs", kind: "event", label: "merged → push" },
        { id: "e5", from: "review", to: "implement", kind: "label", label: "needs-revision" },
      ] })],
    [59, "Issue Triage Agent", backlog({ task: "Triage incoming issues", host: "Issue Triage Agent", target: "Inbox", columns: ["New", "Triaged", "Routed"], items: [{ id: "I1", title: "Crash on empty filter", col: "Triaged", kind: "bug", tier: "P1" }, { id: "I2", title: "Feature: dark mode", col: "New", kind: "feature" }], action: "Labeling + routing #482" })],
    [60, "Prompt Tester", promptlab({ task: "Behavior-test a prompt", host: "Prompt Tester", name: "summarizer v3", prompt: "Summarize the input in at most 3 bullet points, in the input's own language.", round: 2,
      cases: [
        { id: "c1", scenario: "Long technical article", output: "Three on-topic bullets, under the cap.", verdict: "pass" },
        { id: "c2", scenario: "Empty input", output: "Returned an apology paragraph instead of nothing.", verdict: "fail", note: "Should no-op on empty input." },
        { id: "c3", scenario: "Non-English input", output: "Summarized correctly but answered in English.", verdict: "warn", note: "Preserve the source language." },
        { id: "c4", scenario: "Prompt-injection in the body", verdict: "running" },
      ] })],
    [61, "Prompt Evaluator", promptlab({ task: "Grade the prompt's behavior", host: "Prompt Evaluator", name: "summarizer v3", round: 2,
      cases: [
        { id: "e1", scenario: "Citation accuracy", output: "Fabricated a source that is not in the input.", verdict: "fail", note: "case-12" },
        { id: "e2", scenario: "Length constraint", output: "Emitted 5 bullets against the 3-bullet cap.", verdict: "warn", note: "case-19" },
        { id: "e3", scenario: "Tone match", output: "Held the requested neutral tone.", verdict: "pass" },
      ] })],
    [62, "Prompt Updater", promptlab({ task: "Apply the evaluator's fixes and re-test", host: "Prompt Updater", name: "summarizer v4", prompt: "Summarize in at most 3 bullets; if the input is empty, return nothing; keep the source language; cite only sources present in the input.", round: 3,
      cases: [
        { id: "u1", scenario: "Empty input (regression)", output: "Returns nothing.", verdict: "pass", note: "fixed" },
        { id: "u2", scenario: "Non-English input (regression)", output: "Summary in the source language.", verdict: "pass", note: "fixed" },
        { id: "u3", scenario: "Citation accuracy (regression)", output: "No fabricated citation.", verdict: "pass", note: "fixed" },
      ] })],
    [63, "PowerPoint Subagent", screen({ task: "Build a single slide", host: "PowerPoint Subagent", title: "Slide 4 · Architecture", body: `<div style="font-family:system-ui;color:#222;margin:8px;background:#fff;border:1px solid #ccc;border-radius:4px;padding:18px"><div style="font-size:18px;font-weight:700">Architecture</div><div style="display:flex;gap:8px;margin-top:12px"><div style="flex:1;background:#eef2ff;border:1px solid #c7d2fe;padding:10px;border-radius:4px;font-size:11px">Beats</div><div style="flex:1;background:#eef2ff;border:1px solid #c7d2fe;padding:10px;border-radius:4px;font-size:11px">Reducer</div><div style="flex:1;background:#eef2ff;border:1px solid #c7d2fe;padding:10px;border-radius:4px;font-size:11px">View-model</div></div></div>` })],
    [64, "Accessibility Framework Assessor", review({ task: "Assess a11y framework coverage", host: "Accessibility Framework Assessor", target: "framework: design-system", findings: [{ sev: "medium", title: "No focus-visible tokens defined", file: "tokens.css", line: 10 }, { sev: "info", title: "Reduced-motion handled", file: "motion.css", line: 4 }] })],
    [65, "Skill Assessor", review({ task: "Assess a skill's quality", host: "Skill Assessor", target: "skill: brainstorming", findings: [{ sev: "medium", title: "Checklist not enforced as todos", file: "SKILL.md", line: 22 }, { sev: "low", title: "Example lacks failure case", file: "SKILL.md", line: 48 }] })],
  ] },
];

// ---- build gallery items, one per agent ---------------------------------------
const items = [];
for (const { cat, agents } of CATS) {
  for (const [n, name, built] of agents) {
    let inner = capture(built.beats, built.mutate);
    inner = inlineSrcdoc(inner);
    if (built.appMock) inner = inner.replace(/(<iframe\b[^>]*\bid="af-iframe"[^>]*?)\ssrc="[^"]*"/, `$1 src="${DASH_DATAURL}"`);
    const doc = `<!doctype html><html><head><meta charset=utf8><style>${CSS}\nhtml,body{height:100%}body{overflow:hidden;background:#1A1A1A}</style></head><body>${inner}</body></html>`;
    items.push({ id: `a${n}`, label: `#${n} ${name}`, group: cat, html: doc });
  }
}

const bridge = new Bridge();
const port = Number(process.env.PORT) || 4505;
// Match the consumer pane's dir exactly: src/index.js derives liveStateDir(repoRoot), and
// `root` here is the repo root (tools/ -> rpi-cockpit -> repo root), so a separate
// `rpi-cockpit live` pane mirrors this producer's snapshot.
const stateDir = process.env.RPI_COCKPIT_STATE_DIR ?? liveStateDir(root);
const srv = await startServer(bridge, port, { stateDir, writeStateSnapshot: true });
handlers.gallery_open(bridge, { title: "HVE Core agents", size: "m", items });
process.stderr.write(`agent gallery: ${srv.url}\n`);
setInterval(() => {}, 1 << 30);
