// rpi-cockpit/src/state.ts
import type { Beat, Phase, OptionItem, ValidationStatus, Directive, Finding, AgentStatus, CodeKind } from "./events.js";

export interface Subagent { name: string; role?: string; status: "active" | "idle"; result?: string; }
export interface TeamAgent { id: string; name: string; role?: string; status: AgentStatus; action?: string | null; }
export interface BacklogItem { id: string; title: string; column: string; kind?: string; tier?: string; parent?: string; }
export interface ProfileColumn { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk"; }
export interface CodeNode { id: string; path: string; kind: CodeKind; group?: string; }
export interface Decision { id: string; prompt: string; options: OptionItem[]; }
export type DecisionKind = "choice" | "text";
export type DecisionStatus = "pending" | "answered" | "superseded";
export interface DecisionEntry { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[]; answer?: string; status: DecisionStatus; }
export interface LogEntry { t: number; kind: string; detail: string; }
export interface SteerMenu { label: string; options: OptionItem[]; }

export interface SessionState {
  task: string;
  host: string;
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | null;
  reviewTarget: string | null;
  orchestrator: string | null;
  teamAgents: TeamAgent[];
  findings: Finding[];
  boardTarget: string | null;
  boardColumns: string[];
  boardItems: BacklogItem[];
  boardAction: string | null;
  view: "home" | "loop";
  navigatorOpen: boolean;
  activeWorkflow: string | null;
  phase: Phase | null;
  phasesDone: Phase[];
  subagents: Subagent[];
  validations: Record<string, ValidationStatus>;
  artifacts: { path: string; summary?: string }[];
  docType: string | null;
  interviewSteps: { label?: string; names: string[]; current: number; progress?: { done: number; total: number } } | null;
  decisions: DecisionEntry[];
  hostElicits: boolean;
  directives: Directive[];
  steerMenu: SteerMenu | null;
  // Single shared screen slot: the RPI screen pane (#screen) and the interview
  // document pane (#iv-doc) both read this one field. A screen.show or clear_screen
  // is not domain-scoped, so the agent should clear_screen when switching contexts
  // (e.g. leaving an interview) or a stale document leaks into the next pane. (B6/M1)
  screen: { html: string; title?: string } | null;
  contextInstructions: string[];
  contextSkills: string[];
  contextCollection: string | null;
  appFrameUrl: string | null;
  codemapNodes: CodeNode[];
  codemapFocus: string | null;
  codemapTouches: Record<string, "read" | "edit">;
  profileDataset: { name: string; rows?: number; cols?: number; source?: string } | null;
  profileColumns: ProfileColumn[];
  log: LogEntry[];
}

export function initialState(): SessionState {
  return { task: "", host: "", domain: null, reviewTarget: null, orchestrator: null, teamAgents: [], findings: [], boardTarget: null, boardColumns: [], boardItems: [], boardAction: null, view: "home", navigatorOpen: false, activeWorkflow: null, phase: null, phasesDone: [], subagents: [], validations: {}, artifacts: [], docType: null, interviewSteps: null, decisions: [], hostElicits: false, directives: [], steerMenu: null, screen: null, contextInstructions: [], contextSkills: [], contextCollection: null, appFrameUrl: null, codemapNodes: [], codemapFocus: null, codemapTouches: {}, profileDataset: null, profileColumns: [], log: [] };
}

export function applyBeat(s: SessionState, beat: Beat, now: number): SessionState {
  const log = [...s.log, { t: now, kind: beat.type, detail: summarize(beat) }];
  switch (beat.type) {
    case "session.begin":
      return { ...s, task: beat.task, host: beat.host, domain: "rpi", view: "loop", log };
    case "phase.enter": {
      const phasesDone = s.phase && s.phase !== beat.phase && !s.phasesDone.includes(s.phase)
        ? [...s.phasesDone, s.phase] : s.phasesDone;
      return { ...s, phase: beat.phase, phasesDone, steerMenu: null, log };
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
    case "approaches.offer":
      return { ...s, steerMenu: { label: beat.label, options: beat.options }, log };
    case "screen.show":
      return { ...s, screen: { html: beat.html, title: beat.title }, log };
    case "screen.clear":
      return { ...s, screen: null, log };
    case "review.start":
      return { ...s, view: "loop", domain: "review", reviewTarget: beat.target, findings: [], log };
    case "finding.add":
      return { ...s, findings: [...s.findings, { severity: beat.severity, title: beat.title, file: beat.file, line: beat.line, detail: beat.detail }], log };
    case "interview.start":
      return { ...s, view: "loop", domain: "interview", docType: beat.docType, interviewSteps: null, log };
    case "steps.set": {
      const current = Math.max(0, Math.min(beat.current, beat.steps.length - 1));
      return { ...s, interviewSteps: { label: beat.label, names: beat.steps, current, progress: beat.progress }, log };
    }
    case "backlog.start":
      return { ...s, view: "loop", domain: "backlog", boardTarget: beat.target, boardColumns: beat.columns, boardItems: [], boardAction: null, log };
    case "item.add": {
      const others = s.boardItems.filter((i) => i.id !== beat.id);
      return { ...s, boardItems: [...others, { id: beat.id, title: beat.title, column: beat.column, kind: beat.kind, tier: beat.tier, parent: beat.parent }], log };
    }
    case "item.move":
      return { ...s, boardItems: s.boardItems.map((i) => i.id === beat.id ? { ...i, column: beat.column } : i), log };
    case "backlog.action":
      return { ...s, boardAction: beat.text, log };
    case "profile.start":
      return { ...s, view: "loop", domain: "dataprofile", profileDataset: { name: beat.name, rows: beat.rows, cols: beat.columns, source: beat.source }, profileColumns: [], log };
    case "column.add": {
      const col = { name: beat.name, dtype: beat.dtype, nullPct: beat.nullPct, distinct: beat.distinct, stat: beat.stat, quality: beat.quality };
      const exists = s.profileColumns.some((c) => c.name === beat.name);
      return { ...s, profileColumns: exists ? s.profileColumns.map((c) => (c.name === beat.name ? col : c)) : [...s.profileColumns, col], log };
    }
    case "context.set":
      return { ...s, contextInstructions: beat.instructions, contextSkills: beat.skills, contextCollection: beat.collection, log };
    case "appframe.set":
      return { ...s, appFrameUrl: beat.url, log };
    case "team.start":
      return { ...s, view: "loop", domain: "team", task: beat.task, orchestrator: beat.orchestrator, teamAgents: [], log };
    case "agent.add":
      return { ...s, teamAgents: [...s.teamAgents.filter((x) => x.id !== beat.id), { id: beat.id, name: beat.name, role: beat.role, status: beat.status }], log };
    case "agent.update":
      return { ...s, teamAgents: s.teamAgents.map((a) => a.id === beat.id ? { ...a, ...(beat.status !== undefined ? { status: beat.status } : {}), ...(beat.action !== undefined ? { action: beat.action } : {}) } : a), log };
    case "agent.remove":
      return { ...s, teamAgents: s.teamAgents.filter((a) => a.id !== beat.id), log };
    case "codemap.set":
      return { ...s, view: "loop", domain: "codemap", codemapNodes: beat.nodes, codemapFocus: null, codemapTouches: {}, log };
    case "codemap.focus": {
      const exists = s.codemapNodes.some((n) => n.id === beat.id);
      return exists ? { ...s, codemapFocus: beat.id, log } : { ...s, log };
    }
    case "codemap.touch": {
      const exists = s.codemapNodes.some((n) => n.id === beat.id);
      if (!exists) return { ...s, log };
      const cur = s.codemapTouches[beat.id];
      const next = (cur === "edit" || beat.kind === "edit") ? "edit" : "read";
      return { ...s, codemapTouches: { ...s.codemapTouches, [beat.id]: next }, log };
    }
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
    case "approaches.offer": return beat.label;
    case "screen.show": return beat.title ?? "screen";
    case "screen.clear": return "cleared";
    case "review.start": return `review ${beat.target}`;
    case "finding.add": return `${beat.severity}: ${beat.title}`;
    case "interview.start": return `interview ${beat.docType}`;
    case "steps.set": return beat.label ?? "steps";
    case "backlog.start": return `backlog ${beat.target}`;
    case "item.add": return `${beat.id}: ${beat.title}`;
    case "item.move": return `${beat.id} -> ${beat.column}`;
    case "backlog.action": return beat.text ?? "(cleared)";
    case "profile.start": return beat.name;
    case "column.add": return beat.name;
    case "context.set": return `${beat.instructions.length} instr · ${beat.skills.length} skills${beat.collection ? " · " + beat.collection : ""}`;
    case "appframe.set": return beat.url ? `app frame ${beat.url}` : "app frame cleared";
    case "team.start": return `team ${beat.orchestrator}`;
    case "agent.add": return `${beat.name} (${beat.status})`;
    case "agent.update": return `${beat.id}${beat.status ? " " + beat.status : ""}`;
    case "agent.remove": return beat.id;
    case "codemap.set": return `${beat.nodes.length} nodes`;
    case "codemap.focus": return beat.id;
    case "codemap.touch": return `${beat.kind} ${beat.id}`;
  }
}

export function addDecision(s: SessionState, e: { id: string; prompt: string; kind: DecisionKind; options?: OptionItem[] }): SessionState {
  const idx = s.decisions.findIndex((d) => d.id === e.id);
  const entry: DecisionEntry = { id: e.id, prompt: e.prompt, kind: e.kind, options: e.options, status: "pending" };
  if (idx !== -1) return { ...s, decisions: s.decisions.map((d, j) => (j === idx ? entry : d)) };
  return { ...s, decisions: [...s.decisions, entry] };
}

export function answerDecision(s: SessionState, id: string, answer: string): SessionState {
  return { ...s, decisions: s.decisions.map((d) => (d.id === id ? { ...d, answer, status: "answered" } : d)) };
}

export function reviseDecision(s: SessionState, id: string): SessionState {
  const idx = s.decisions.findIndex((d) => d.id === id);
  if (idx === -1) return s;
  return {
    ...s,
    decisions: s.decisions.map((d, j) => {
      if (j === idx) return { ...d, answer: undefined, status: "pending" };
      if (j > idx && d.status === "answered") return { ...d, status: "superseded" };
      return d;
    }),
  };
}

export function setHostElicits(s: SessionState, v: boolean): SessionState {
  return { ...s, hostElicits: v };
}

export function enqueueDirective(s: SessionState, directive: Directive, now: number): SessionState {
  return {
    ...s,
    directives: [...s.directives, directive],
    log: [...s.log, { t: now, kind: "directive.queued", detail: summarizeDirective(directive) }],
  };
}

export function drainDirectives(s: SessionState, now: number): { state: SessionState; drained: Directive[] } {
  if (s.directives.length === 0) return { state: s, drained: [] };
  const log = [...s.log, ...s.directives.map((d) => ({ t: now, kind: "directive.consumed", detail: summarizeDirective(d) }))];
  return { state: { ...s, directives: [], log }, drained: s.directives };
}

function summarizeDirective(d: Directive): string {
  return d.kind === "note" ? `note: ${d.text}` : `approach: ${d.label}`;
}

export function setView(s: SessionState, view: "home" | "loop"): SessionState {
  return { ...s, view };
}

export function startLaunch(s: SessionState, workflowId: string): SessionState {
  return { ...s, view: "loop", navigatorOpen: false, activeWorkflow: workflowId };
}

export function setNavigatorOpen(s: SessionState, open: boolean): SessionState {
  return { ...s, navigatorOpen: open };
}
