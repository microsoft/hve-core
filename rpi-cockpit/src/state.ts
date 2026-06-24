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
