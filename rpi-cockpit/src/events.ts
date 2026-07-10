// rpi-cockpit/src/events.ts
import { z } from "zod";

export const Phase = z.enum(["research", "plan", "implement", "review", "discover"]);
export type Phase = z.infer<typeof Phase>;

export const ValidationStatus = z.enum(["ok", "running", "fail", "pending"]);
export type ValidationStatus = z.infer<typeof ValidationStatus>;

export const AgentStatus = z.enum(["queued", "running", "blocked", "done", "failed"]);
export type AgentStatus = z.infer<typeof AgentStatus>;

export const CodeKind = z.enum(["file", "dir"]);
export type CodeKind = z.infer<typeof CodeKind>;

export const TouchKind = z.enum(["read", "edit"]);
export type TouchKind = z.infer<typeof TouchKind>;

export const OptionItem = z.object({
  id: z.string(),
  title: z.string(),
  detail: z.string().optional(),
  recommended: z.boolean().optional(),
});
export type OptionItem = z.infer<typeof OptionItem>;

export const GalleryItem = z.object({
  id: z.string().optional(),
  label: z.string(),
  group: z.string().optional(),
  url: z.string().optional(),
  html: z.string().optional(),
  caption: z.string().optional(),
});
export type GalleryItem = z.infer<typeof GalleryItem>;

export const Severity = z.enum(["critical", "high", "medium", "low", "info"]);
export type Severity = z.infer<typeof Severity>;

export const Finding = z.object({
  severity: Severity,
  title: z.string(),
  file: z.string().optional(),
  line: z.number().int().optional(),
  detail: z.string().optional(),
});
export type Finding = z.infer<typeof Finding>;

export const Beat = z.discriminatedUnion("type", [
  z.object({ type: z.literal("session.begin"), task: z.string(), host: z.string() }),
  z.object({ type: z.literal("phase.enter"), phase: Phase }),
  z.object({ type: z.literal("subagent.start"), name: z.string(), role: z.string().optional() }),
  z.object({ type: z.literal("subagent.stop"), name: z.string(), result: z.string().optional() }),
  z.object({ type: z.literal("artifact.update"), path: z.string(), summary: z.string().optional() }),
  z.object({ type: z.literal("validate"), check: z.string(), status: ValidationStatus }),
  z.object({ type: z.literal("approaches.offer"), label: z.string(), options: z.array(OptionItem).min(1) }),
  z.object({ type: z.literal("screen.show"), html: z.string(), title: z.string().optional() }),
  z.object({ type: z.literal("screen.clear") }),
  z.object({ type: z.literal("review.start"), target: z.string() }),
  z.object({ type: z.literal("finding.add"), severity: Severity, title: z.string(), file: z.string().optional(), line: z.number().int().optional(), detail: z.string().optional() }),
  z.object({ type: z.literal("interview.start"), docType: z.string() }),
  z.object({ type: z.literal("steps.set"), steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional(), progress: z.object({ done: z.number().int(), total: z.number().int() }).optional() }),
  z.object({ type: z.literal("backlog.start"), target: z.string(), columns: z.array(z.string()).min(1) }),
  z.object({ type: z.literal("item.add"), id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional(), parent: z.string().optional() }),
  z.object({ type: z.literal("item.move"), id: z.string(), column: z.string() }),
  z.object({ type: z.literal("backlog.action"), text: z.string().nullable() }),
  z.object({ type: z.literal("profile.start"), name: z.string(), rows: z.number().int().optional(), columns: z.number().int().optional(), source: z.string().optional() }),
  z.object({ type: z.literal("column.add"), name: z.string(), dtype: z.string(), nullPct: z.number().optional(), distinct: z.number().int().optional(), stat: z.string().optional(), quality: z.enum(["ok", "warn", "risk"]).optional() }),
  z.object({ type: z.literal("context.set"), instructions: z.array(z.string()), skills: z.array(z.string()), collection: z.string().nullable() }),
  z.object({ type: z.literal("appframe.set"), url: z.string().nullable() }),
  z.object({ type: z.literal("team.start"), task: z.string(), orchestrator: z.string() }),
  z.object({ type: z.literal("agent.add"), id: z.string(), name: z.string(), role: z.string().optional(), status: AgentStatus }),
  z.object({ type: z.literal("agent.update"), id: z.string(), status: AgentStatus.optional(), action: z.string().nullable().optional() }),
  z.object({ type: z.literal("agent.remove"), id: z.string() }),
  z.object({ type: z.literal("codemap.set"), nodes: z.array(z.object({ id: z.string(), path: z.string(), kind: CodeKind, group: z.string().optional() })).max(60) }),
  z.object({ type: z.literal("codemap.focus"), id: z.string() }),
  z.object({ type: z.literal("codemap.touch"), id: z.string(), kind: TouchKind }),
  z.object({ type: z.literal("gallery.open"), title: z.string(), size: z.enum(["s", "m", "l"]).optional(), items: z.array(GalleryItem) }),
  z.object({ type: z.literal("gallery.add"), item: GalleryItem }),
  z.object({ type: z.literal("gallery.clear") }),
  z.object({ type: z.literal("promptlab.start"), name: z.string(), prompt: z.string().optional(), round: z.number().int().optional() }),
  z.object({ type: z.literal("case.add"), id: z.string(), scenario: z.string(), output: z.string().optional(), verdict: z.enum(["pending", "running", "pass", "warn", "fail"]).optional(), note: z.string().optional() }),
  z.object({ type: z.literal("memory.open"), title: z.string().optional() }),
  z.object({ type: z.literal("memory.add"), id: z.string(), content: z.string(), category: z.string(), tag: z.enum(["recalled", "added", "updated"]).optional(), title: z.string().optional() }),
  z.object({ type: z.literal("handoff.add"), id: z.string(), from: z.string(), summary: z.string(), action: z.enum(["stored", "merged", "recalled"]).optional() }),
  z.object({ type: z.literal("flow.open"), title: z.string().optional() }),
  z.object({ type: z.literal("flownode.add"), id: z.string(), kind: z.enum(["workflow", "trigger", "guard", "agent", "output", "mcp"]), label: z.string(), scope: z.string().optional(), sub: z.string().optional(), status: z.enum(["idle", "running", "passed", "failed", "skipped", "stale"]).optional() }),
  z.object({ type: z.literal("flowedge.add"), id: z.string(), from: z.string(), to: z.string(), scope: z.string().optional(), label: z.string().optional(), kind: z.enum(["label", "event", "output", "step"]).optional(), status: z.enum(["idle", "active"]).optional() }),
  z.object({ type: z.literal("flow.focus"), workflow: z.string().nullable().optional() }),
]);
export type Beat = z.infer<typeof Beat>;

export const InboundDirective = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("note"), text: z.string().min(1) }),
  z.object({ kind: z.literal("approach"), value: z.string().min(1), label: z.string() }),
]);
export type InboundDirective = z.infer<typeof InboundDirective>;

export const Directive = z.discriminatedUnion("kind", [
  z.object({ id: z.string(), kind: z.literal("note"), text: z.string().min(1) }),
  z.object({ id: z.string(), kind: z.literal("approach"), value: z.string().min(1), label: z.string() }),
]);
export type Directive = z.infer<typeof Directive>;

export const SteerMsg = z.object({ type: z.literal("steer"), directive: InboundDirective });
export type SteerMsg = z.infer<typeof SteerMsg>;
