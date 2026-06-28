// rpi-cockpit/src/handlers.ts
import type { Bridge } from "./bridge.js";
import type { AgentStatus, CodeKind, OptionItem, Phase, Severity, TouchKind, ValidationStatus } from "./events.js";
import { isLoopbackHttpUrl } from "./url.js";

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
  review_start: (b: Bridge, a: { target: string }) => {
    b.emitBeat({ type: "review.start", target: a.target });
    return `review started: ${a.target}`;
  },
  add_finding: (b: Bridge, a: { severity: Severity; title: string; file?: string; line?: number; detail?: string }) => {
    b.emitBeat({ type: "finding.add", severity: a.severity, title: a.title, file: a.file, line: a.line, detail: a.detail });
    return `finding added: ${a.severity}`;
  },
  interview_start: (b: Bridge, a: { docType: string }) => {
    b.emitBeat({ type: "interview.start", docType: a.docType });
    return `interview started: ${a.docType}`;
  },
  set_steps: (b: Bridge, a: { steps: string[]; current: number; label?: string }) => {
    b.emitBeat({ type: "steps.set", steps: a.steps, current: a.current, label: a.label });
    return `steps set: ${a.steps.length}`;
  },
  backlog_start: (b: Bridge, a: { target: string; columns: string[] }) => {
    b.emitBeat({ type: "backlog.start", target: a.target, columns: a.columns });
    return `backlog started: ${a.target}`;
  },
  add_item: (b: Bridge, a: { id: string; title: string; column: string; kind?: string; tier?: string; parent?: string }) => {
    b.emitBeat({ type: "item.add", id: a.id, title: a.title, column: a.column, kind: a.kind, tier: a.tier, parent: a.parent });
    return `item added: ${a.id}`;
  },
  move_item: (b: Bridge, a: { id: string; column: string }) => {
    b.emitBeat({ type: "item.move", id: a.id, column: a.column });
    return `item moved: ${a.id}`;
  },
  set_backlog_action: (b: Bridge, a: { text: string | null }) => {
    b.emitBeat({ type: "backlog.action", text: a.text });
    return a.text ? `action: ${a.text}` : "action cleared";
  },
  dataset_profile: (b: Bridge, a: { name: string; rows?: number; columns?: number; source?: string }) => {
    b.emitBeat({ type: "profile.start", name: a.name, rows: a.rows, columns: a.columns, source: a.source });
    return `profile started: ${a.name}`;
  },
  add_column: (b: Bridge, a: { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk" }) => {
    b.emitBeat({ type: "column.add", name: a.name, dtype: a.dtype, nullPct: a.nullPct, distinct: a.distinct, stat: a.stat, quality: a.quality });
    return `column added: ${a.name}`;
  },
  team_start: (b: Bridge, a: { task: string; orchestrator: string }) => {
    b.emitBeat({ type: "team.start", task: a.task, orchestrator: a.orchestrator });
    return `team started: ${a.orchestrator}`;
  },
  add_agent: (b: Bridge, a: { id: string; name: string; role?: string; status: AgentStatus }) => {
    b.emitBeat({ type: "agent.add", id: a.id, name: a.name, role: a.role, status: a.status });
    return `agent added: ${a.name}`;
  },
  update_agent: (b: Bridge, a: { id: string; status?: AgentStatus; action?: string | null }) => {
    b.emitBeat({ type: "agent.update", id: a.id, status: a.status, action: a.action });
    return `agent updated: ${a.id}`;
  },
  remove_agent: (b: Bridge, a: { id: string }) => {
    b.emitBeat({ type: "agent.remove", id: a.id });
    return `agent removed: ${a.id}`;
  },
  codemap_set: (b: Bridge, a: { nodes: { id: string; path: string; kind: CodeKind; group?: string }[] }) => {
    b.emitBeat({ type: "codemap.set", nodes: a.nodes });
    return `codemap set: ${a.nodes.length} nodes`;
  },
  codemap_focus: (b: Bridge, a: { id: string }) => {
    b.emitBeat({ type: "codemap.focus", id: a.id });
    return `focus ${a.id}`;
  },
  codemap_touch: (b: Bridge, a: { id: string; kind: TouchKind }) => {
    b.emitBeat({ type: "codemap.touch", id: a.id, kind: a.kind });
    return `${a.kind} ${a.id}`;
  },
  set_context: (b: Bridge, a: { instructions?: string[]; skills?: string[]; collection?: string | null }) => {
    b.emitBeat({ type: "context.set", instructions: a.instructions ?? [], skills: a.skills ?? [], collection: a.collection ?? null });
    return "context updated";
  },
  set_app_frame: (b: Bridge, a: { url: string | null }) => {
    if (a.url !== null && !isLoopbackHttpUrl(a.url)) {
      return "rejected: the app frame URL must be a loopback http(s) URL (localhost, 127.0.0.1, or [::1])";
    }
    b.emitBeat({ type: "appframe.set", url: a.url });
    return a.url ? `app frame set: ${a.url}` : "app frame cleared";
  },
  offer_approaches: (b: Bridge, a: { label: string; options: OptionItem[] }) => {
    b.offerApproaches(a.label, a.options);
    return `offered ${a.options.length} approaches`;
  },
  check_directives: (b: Bridge) => {
    const drained = b.drainDirectives();
    if (drained.length === 0) return "no pending directives";
    return drained.map((d) => (d.kind === "note" ? `note: ${d.text}` : `approach: ${d.label}`)).join("\n");
  },
  show_screen: (b: Bridge, a: { html: string; title?: string }) => {
    b.showScreen(a.html, a.title);
    return a.title ? `screen shown: ${a.title}` : "screen shown";
  },
  clear_screen: (b: Bridge) => {
    b.clearScreen();
    return "screen cleared";
  },
  open_navigator: (b: Bridge) => {
    b.openNavigator();
    return "navigator opened";
  },
};
