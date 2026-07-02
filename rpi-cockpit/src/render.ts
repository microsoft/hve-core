// rpi-cockpit/src/render.ts
import type { SessionState, BacklogItem } from "./state.js";
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
const AGENT_STATUS_ORDER = ["running", "blocked", "queued", "done", "failed"] as const;
const AGENT_STATUS_LABEL: Record<string, string> = { running: "Running", blocked: "Blocked", queued: "Queued", done: "Done", failed: "Failed" };
const EMPTY_LEAD = "Waiting for an RPI session… the cockpit is connected and lights up when the agent calls session_begin.";
const PRESETS: { id: string; title: string }[] = [
  { id: "default", title: "Default" },
  { id: "thorough", title: "Be more thorough" },
  { id: "faster", title: "Move faster" },
  { id: "ask-first", title: "Ask before big changes" },
];

function orderColumnItems(
  columnItems: BacklogItem[],
  byId: Map<string, BacklogItem>,
  inColumn: Set<string>,
): { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] {
  const childrenOf = new Map<string, BacklogItem[]>();
  const roots: BacklogItem[] = [];
  for (const i of columnItems) {
    const sameColParent = i.parent && inColumn.has(i.parent) ? i.parent : null;
    if (sameColParent) {
      const arr = childrenOf.get(sameColParent) ?? [];
      arr.push(i);
      childrenOf.set(sameColParent, arr);
    } else {
      roots.push(i);
    }
  }
  const out: { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] = [];
  const seen = new Set<string>();
  const visit = (i: BacklogItem, depth: number): void => {
    if (seen.has(i.id)) return;
    seen.add(i.id);
    const crossColumn = i.parent !== undefined && !inColumn.has(i.parent);
    out.push({
      id: i.id, title: i.title, kind: i.kind, tier: i.tier, depth,
      parentRef: crossColumn ? (byId.get(i.parent as string)?.title ?? (i.parent as string)) : undefined,
    });
    for (const c of childrenOf.get(i.id) ?? []) visit(c, depth + 1);
  };
  for (const r of roots) visit(r, 0);
  for (const i of columnItems) if (!seen.has(i.id)) visit(i, 0); // defensive: cycles/orphans never silently drop
  return out;
}

export interface StepVM { phase: Phase; status: "done" | "active" | "pending"; }
export interface SteerMenuVM { label: string; source: "agent" | "preset"; options: { id: string; title: string; detail?: string }[]; }
export interface ViewModel {
  started: boolean;
  task: string;
  host: string;
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | "gallery" | "promptlab" | "memory" | "flow" | null;
  reviewTarget: string | null;
  findingGroups: { severity: Severity; items: { title: string; file?: string; line?: number; detail?: string }[] }[];
  board: { target: string | null; action: string | null; count: number; columns: { name: string; items: { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] }[] };
  team: { orchestrator: string | null; count: number; columns: { status: string; label: string; agents: { id: string; name: string; role?: string; action?: string | null }[] }[] };
  codemap: { nodes: { id: string; path: string; kind: string; group: string }[]; focus: string | null; touches: Record<string, string> };
  dataProfile: { dataset: { name: string; rows?: number; cols?: number; source?: string } | null; columns: { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: string }[] };
  gallery: { title: string | null; size: "s" | "m" | "l"; items: { id: string; label: string; group: string | null; kind: "url" | "html" | "empty"; src: string | null; caption: string | null }[] };
  promptlab: { name: string | null; round: number; prompt: string | null; summary: { pass: number; warn: number; fail: number; pending: number; running: number; total: number }; cases: { id: string; scenario: string; output: string | null; verdict: string; note: string | null }[] };
  memory: { title: string | null; counts: { recalled: number; added: number; updated: number; total: number }; entries: { id: string; title: string | null; content: string; category: string; tag: string }[]; handoffs: { id: string; from: string; summary: string; action: string }[] };
  flow: { title: string | null; focus: string | null; nodes: { id: string; scope: string; kind: string; label: string; sub: string | null; status: string }[]; edges: { id: string; from: string; to: string; scope: string; label: string | null; kind: string; status: string }[] };
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
  interviewSteps: { label?: string; steps: { name: string; status: "done" | "active" | "pending"; progress?: { done: number; total: number } }[] } | null;
  decisions: { id: string; prompt: string; kind: string; options?: { id: string; title: string; detail?: string; recommended?: boolean }[]; answer?: string; status: string }[];
  hostElicits: boolean;
  steerMenu: SteerMenuVM;
  directives: Directive[];
  screen: SessionState["screen"];
  context: { instructions: string[]; skills: string[]; collection: string | null };
  appFrame: { url: string | null };
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
  const byId = new Map(s.boardItems.map((i) => [i.id, i]));
  const board = {
    target: s.boardTarget,
    action: s.boardAction,
    count: s.boardItems.length,
    columns: s.boardColumns.map((name) => {
      const columnItems = s.boardItems.filter((i) => i.column === name);
      const inColumn = new Set(columnItems.map((i) => i.id));
      return { name, items: orderColumnItems(columnItems, byId, inColumn) };
    }),
  };
  const team = {
    orchestrator: s.orchestrator,
    count: s.teamAgents.length,
    columns: AGENT_STATUS_ORDER
      .map((status) => ({
        status,
        label: AGENT_STATUS_LABEL[status],
        agents: s.teamAgents
          .filter((a) => a.status === status)
          .map((a) => ({ id: a.id, name: a.name, role: a.role, action: a.action })),
      }))
      .filter((c) => c.agents.length > 0),
  };
  const codemap = {
    nodes: s.codemapNodes.map((n) => ({
      id: n.id,
      path: n.path,
      kind: n.kind,
      group: n.group || (n.path.split("/").length > 1 ? n.path.split("/")[0] : "(root)"),
    })),
    focus: s.codemapFocus,
    touches: s.codemapTouches,
  };
  const ist = s.interviewSteps;
  const interviewSteps = ist
    ? { label: ist.label, steps: ist.names.map((name, i) => {
        const status = (i < ist.current ? "done" : i === ist.current ? "active" : "pending") as "done" | "active" | "pending";
        return status === "active" && ist.progress ? { name, status, progress: ist.progress } : { name, status };
      }) }
    : null;
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
    team,
    codemap,
    dataProfile: { dataset: s.profileDataset, columns: s.profileColumns },
    gallery: {
      title: s.galleryTitle,
      size: s.gallerySize,
      items: s.galleryItems.map((it) => ({
        id: it.id,
        label: it.label,
        group: it.group ?? null,
        kind: it.url ? "url" : it.html ? "html" : "empty",
        src: it.url ?? it.html ?? null,
        caption: it.caption ?? null,
      })),
    },
    promptlab: {
      name: s.promptName,
      round: s.promptRound,
      prompt: s.promptArtifact,
      summary: s.promptCases.reduce(
        (a, c) => { a[c.verdict]++; a.total++; return a; },
        { pass: 0, warn: 0, fail: 0, pending: 0, running: 0, total: 0 },
      ),
      cases: s.promptCases.map((c) => ({ id: c.id, scenario: c.scenario, output: c.output ?? null, verdict: c.verdict, note: c.note ?? null })),
    },
    memory: {
      title: s.memoryTitle,
      counts: s.memoryEntries.reduce(
        (a, e) => { a[e.tag]++; a.total++; return a; },
        { recalled: 0, added: 0, updated: 0, total: 0 },
      ),
      entries: s.memoryEntries.map((e) => ({ id: e.id, title: e.title ?? null, content: e.content, category: e.category, tag: e.tag })),
      handoffs: s.memoryHandoffs.map((h) => ({ id: h.id, from: h.from, summary: h.summary, action: h.action })),
    },
    flow: {
      title: s.flowTitle,
      focus: s.flowFocus,
      nodes: s.flowNodes.map((n) => ({ id: n.id, scope: n.scope, kind: n.kind, label: n.label, sub: n.sub ?? null, status: n.status })),
      edges: s.flowEdges.map((e) => ({ id: e.id, from: e.from, to: e.to, scope: e.scope, label: e.label ?? null, kind: e.kind, status: e.status })),
    },
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
    interviewSteps,
    decisions: s.decisions.map((d) => ({ id: d.id, prompt: d.prompt, kind: d.kind, options: d.options, answer: d.answer, status: d.status })),
    hostElicits: s.hostElicits,
    steerMenu,
    directives: s.directives,
    screen: s.screen,
    context: { instructions: s.contextInstructions, skills: s.contextSkills, collection: s.contextCollection },
    appFrame: { url: s.appFrameUrl },
    log: s.log,
  };
}
