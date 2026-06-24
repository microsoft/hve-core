// rpi-cockpit/src/render.ts
import type { SessionState } from "./state.js";
import type { Phase, OptionItem, Directive } from "./events.js";

const ORDER: Phase[] = ["research", "plan", "implement", "review", "discover"];
const LABEL: Record<Phase, string> = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const LEAD: Record<Phase, string> = {
  research: "Gathering context and constraints before committing to a plan.",
  plan: "Turning research into an ordered, reviewable plan.",
  implement: "Executing the plan. Subagents and validation run here; the loop won't advance until checks pass.",
  review: "Verifying the work against the plan and the validation gate.",
  discover: "Surfacing follow-up work uncovered during the cycle.",
};
const EMPTY_LEAD = "Waiting for an RPI session… the cockpit is connected and lights up when the agent calls session_begin.";
const PRESETS: { id: string; title: string }[] = [
  { id: "default", title: "Default" },
  { id: "thorough", title: "Be more thorough" },
  { id: "faster", title: "Move faster" },
  { id: "ask-first", title: "Ask before big changes" },
];

export interface StepVM { phase: Phase; status: "done" | "active" | "pending"; }
export interface SteerMenuVM { label: string; source: "agent" | "preset"; options: { id: string; title: string; detail?: string }[]; }
export interface ViewModel {
  started: boolean;
  task: string;
  host: string;
  phase: Phase | null;
  phaseLabel: string | null;
  phaseNumber: number | null;
  lead: string;
  steps: StepVM[];
  subagents: { name: string; status: string; role?: string }[];
  validations: { check: string; status: string }[];
  decision: SessionState["pendingDecision"];
  steerMenu: SteerMenuVM;
  directives: Directive[];
  log: SessionState["log"];
}

export function toViewModel(s: SessionState): ViewModel {
  const steps: StepVM[] = ORDER.map((phase) => ({
    phase,
    status: s.phase === phase ? "active" : s.phasesDone.includes(phase) ? "done" : "pending",
  }));
  const idx = s.phase ? ORDER.indexOf(s.phase) : -1;
  const steerMenu: SteerMenuVM = s.steerMenu
    ? { label: s.steerMenu.label, source: "agent", options: s.steerMenu.options.map((o: OptionItem) => ({ id: o.id, title: o.title, detail: o.detail })) }
    : { label: "Next-phase approach", source: "preset", options: PRESETS.map((o) => ({ id: o.id, title: o.title })) };
  return {
    started: s.task !== "" || s.phase !== null,
    task: s.task,
    host: s.host,
    phase: s.phase,
    phaseLabel: s.phase ? LABEL[s.phase] : null,
    phaseNumber: s.phase ? idx + 1 : null,
    lead: s.phase ? LEAD[s.phase] : EMPTY_LEAD,
    steps,
    subagents: s.subagents.map((a) => ({ name: a.name, status: a.status, role: a.role })),
    validations: Object.entries(s.validations).map(([check, status]) => ({ check, status })),
    decision: s.pendingDecision,
    steerMenu,
    directives: s.directives,
    log: s.log,
  };
}
