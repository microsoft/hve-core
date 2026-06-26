// rpi-cockpit/src/state.ts
import type { Beat, Phase, OptionItem, ValidationStatus, Directive, Finding } from "./events.js";

export interface Subagent { name: string; role?: string; status: "active" | "idle"; result?: string; }
export interface Decision { id: string; prompt: string; options: OptionItem[]; }
export interface LogEntry { t: number; kind: string; detail: string; }
export interface SteerMenu { label: string; options: OptionItem[]; }

export interface SessionState {
  task: string;
  host: string;
  domain: "rpi" | "review" | null;
  reviewTarget: string | null;
  findings: Finding[];
  view: "home" | "loop";
  activeWorkflow: string | null;
  phase: Phase | null;
  phasesDone: Phase[];
  subagents: Subagent[];
  validations: Record<string, ValidationStatus>;
  artifacts: { path: string; summary?: string }[];
  pendingDecision: Decision | null;
  directives: Directive[];
  steerMenu: SteerMenu | null;
  screen: { html: string; title?: string } | null;
  log: LogEntry[];
}

export function initialState(): SessionState {
  return { task: "", host: "", domain: null, reviewTarget: null, findings: [], view: "home", activeWorkflow: null, phase: null, phasesDone: [], subagents: [], validations: {}, artifacts: [], pendingDecision: null, directives: [], steerMenu: null, screen: null, log: [] };
}

export function applyBeat(s: SessionState, beat: Beat, now: number): SessionState {
  const log = [...s.log, { t: now, kind: beat.type, detail: summarize(beat) }];
  switch (beat.type) {
    case "session.begin":
      return { ...s, task: beat.task, host: beat.host, domain: "rpi" as const, view: "loop", log };
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
      return { ...s, domain: "review", reviewTarget: beat.target, findings: [], log };
    case "finding.add":
      return { ...s, findings: [...s.findings, { severity: beat.severity, title: beat.title, file: beat.file, line: beat.line, detail: beat.detail }], log };
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
  return { ...s, view: "loop", activeWorkflow: workflowId };
}
