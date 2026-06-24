// rpi-cockpit/src/handlers.ts
import type { Bridge } from "./bridge.js";
import type { OptionItem, Phase, ValidationStatus } from "./events.js";

// A decision must not block the agent forever: if the user never responds, fall
// back to the recommended option after a finite timeout. Configurable via env
// (default 30 min). A non-positive/NaN value leaves the default in place.
const DEFAULT_DECISION_TIMEOUT_MS = 1_800_000;
function decisionTimeoutMs(): number {
  const raw = Number(process.env.RPI_COCKPIT_DECISION_TIMEOUT_MS);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_DECISION_TIMEOUT_MS;
}

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
    b.presentOptions(a.prompt, a.options, decisionTimeoutMs()),
};
