// rpi-cockpit/src/state.ts
import type { Beat, Phase, OptionItem, ValidationStatus, Directive, Finding } from "./events.js";

export interface Subagent { name: string; role?: string; status: "active" | "idle"; result?: string; }
export interface BacklogItem { id: string; title: string; column: string; kind?: string; tier?: string; }
export interface Decision { id: string; prompt: string; options: OptionItem[]; }
export interface LogEntry { t: number; kind: string; detail: string; }
export interface SteerMenu { label: string; options: OptionItem[]; }

export interface SessionState {
  task: string;
  host: string;
  domain: "rpi" | "review" | "interview" | "backlog" | null;
  reviewTarget: string | null;
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
  pendingQuestion: { id: string; prompt: string } | null;
  pendingDecision: Decision | null;
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
  log: LogEntry[];
}

export function initialState(): SessionState {
  return { task: "", host: "", domain: null, reviewTarget: null, findings: [], boardTarget: null, boardColumns: [], boardItems: [], boardAction: null, view: "home", navigatorOpen: false, activeWorkflow: null, phase: null, phasesDone: [], subagents: [], validations: {}, artifacts: [], docType: null, pendingQuestion: null, pendingDecision: null, directives: [], steerMenu: null, screen: null, contextInstructions: [], contextSkills: [], contextCollection: null, log: [] };
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
      return { ...s, view: "loop", domain: "interview", docType: beat.docType, pendingQuestion: null, log };
    case "backlog.start":
      return { ...s, view: "loop", domain: "backlog", boardTarget: beat.target, boardColumns: beat.columns, boardItems: [], boardAction: null, log };
    case "item.add": {
      const others = s.boardItems.filter((i) => i.id !== beat.id);
      return { ...s, boardItems: [...others, { id: beat.id, title: beat.title, column: beat.column, kind: beat.kind, tier: beat.tier }], log };
    }
    case "item.move":
      return { ...s, boardItems: s.boardItems.map((i) => i.id === beat.id ? { ...i, column: beat.column } : i), log };
    case "backlog.action":
      return { ...s, boardAction: beat.text, log };
    case "context.set":
      return { ...s, contextInstructions: beat.instructions, contextSkills: beat.skills, contextCollection: beat.collection, log };
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
    case "backlog.start": return `backlog ${beat.target}`;
    case "item.add": return `${beat.id}: ${beat.title}`;
    case "item.move": return `${beat.id} -> ${beat.column}`;
    case "backlog.action": return beat.text ?? "(cleared)";
    case "context.set": return `${beat.instructions.length} instr · ${beat.skills.length} skills${beat.collection ? " · " + beat.collection : ""}`;
  }
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
