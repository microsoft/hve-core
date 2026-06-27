// rpi-cockpit/src/render.ts
import type { SessionState } from "./state.js";
import type { Phase, OptionItem, Directive, Severity } from "./events.js";
import { WORKFLOWS } from "./catalog.js";

const ORDER: Phase[] = ["research", "plan", "implement", "review", "discover"];
const LABEL: Record<Phase, string> = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const LEAD: Record<Phase, string> = {
  research: "Gathering context and constraints before committing to a plan.",
  plan: "Turning research into an ordered, reviewable plan.",
  implement: "Executing the plan. Subagents and validation run here; the loop won't advance until checks pass.",
  review: "Verifying the work against the plan and the validation gate.",
  discover: "Surfacing follow-up work uncovered during the cycle.",
};
const SEVERITY_ORDER: Severity[] = ["critical", "high", "medium", "low", "info"];
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
  domain: "rpi" | "review" | "interview" | "backlog" | null;
  reviewTarget: string | null;
  findingGroups: { severity: Severity; items: { title: string; file?: string; line?: number; detail?: string }[] }[];
  board: { target: string | null; action: string | null; count: number; columns: { name: string; items: { id: string; title: string; kind?: string; tier?: string }[] }[] };
  view: "home" | "loop";
  navigatorOpen: boolean;
  workflows: { id: string; name: string; hint: string; description: string }[];
  activeWorkflow: string | null;
  phase: Phase | null;
  phaseLabel: string | null;
  phaseNumber: number | null;
  lead: string;
  steps: StepVM[];
  subagents: { name: string; status: string; role?: string }[];
  validations: { check: string; status: string }[];
  docType: string | null;
  pendingQuestion: { id: string; prompt: string } | null;
  decision: SessionState["pendingDecision"];
  steerMenu: SteerMenuVM;
  directives: Directive[];
  screen: SessionState["screen"];
  context: { instructions: string[]; skills: string[]; collection: string | null };
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
  const findingGroups = SEVERITY_ORDER
    .map((severity) => ({
      severity,
      items: s.findings
        .filter((f) => f.severity === severity)
        .map((f) => ({ title: f.title, file: f.file, line: f.line, detail: f.detail })),
    }))
    .filter((g) => g.items.length > 0);
  const board = {
    target: s.boardTarget,
    action: s.boardAction,
    count: s.boardItems.length,
    columns: s.boardColumns.map((name) => ({
      name,
      items: s.boardItems
        .filter((i) => i.column === name)
        .map((i) => ({ id: i.id, title: i.title, kind: i.kind, tier: i.tier })),
    })),
  };
  return {
    // A directly-launched review/interview/backlog sets domain without session.begin
    // (so task is "" and phase null); treat any active domain as started so the Home
    // orient strip never claims "Nothing running" mid-session. (B1)
    started: s.task !== "" || s.phase !== null || s.domain !== null,
    task: s.task,
    host: s.host,
    domain: s.domain,
    reviewTarget: s.reviewTarget,
    findingGroups,
    board,
    view: s.view,
    navigatorOpen: s.navigatorOpen,
    workflows: WORKFLOWS.map((w) => ({ id: w.id, name: w.name, hint: w.hint, description: w.description })),
    activeWorkflow: s.activeWorkflow,
    phase: s.phase,
    phaseLabel: s.phase ? LABEL[s.phase] : null,
    phaseNumber: s.phase ? idx + 1 : null,
    lead: s.phase ? LEAD[s.phase] : EMPTY_LEAD,
    steps,
    subagents: s.subagents.map((a) => ({ name: a.name, status: a.status, role: a.role })),
    validations: Object.entries(s.validations).map(([check, status]) => ({ check, status })),
    docType: s.docType,
    pendingQuestion: s.pendingQuestion,
    decision: s.pendingDecision,
    steerMenu,
    directives: s.directives,
    screen: s.screen,
    context: { instructions: s.contextInstructions, skills: s.contextSkills, collection: s.contextCollection },
    log: s.log,
  };
}
