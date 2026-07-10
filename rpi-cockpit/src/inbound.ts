// rpi-cockpit/src/inbound.ts
// Single source of truth for inbound WebSocket frame validation and dispatch.
// Both the in-process WS handler (server.ts) and the producer's inbox tailer
// (live.ts) parse with parseInbound and apply with applyInbound, so a user
// intent validates and drives the bridge identically across the process boundary.
import type { Bridge } from "./bridge.js";
import { SteerMsg, type InboundDirective } from "./events.js";

export type InboundFrame =
  | { type: "decide"; id: string; choiceId: string }
  | { type: "steer"; directive: InboundDirective }
  | { type: "launch"; workflowId: string }
  | { type: "navigate"; screen: "home" | "loop" }
  | { type: "answer"; id: string; text: string }
  | { type: "navigator"; open: boolean }
  | { type: "intervene"; action: "pause" | "swap" | "spawn"; agentId?: string }
  | { type: "revise"; id: string }
  | { type: "open"; file: string; line?: number };

// Mirror the EXACT validation the WS handler used. Return null on anything
// malformed or unrecognized so the caller can ignore it without crashing.
export function parseInbound(msg: unknown): InboundFrame | null {
  if (!msg || typeof msg !== "object") return null;
  const type = (msg as { type?: unknown }).type;
  if (type === "decide") {
    const m = msg as { id?: unknown; choiceId?: unknown };
    if (typeof m.id === "string" && typeof m.choiceId === "string") {
      return { type: "decide", id: m.id, choiceId: m.choiceId };
    }
    return null;
  }
  if (type === "steer") {
    const parsed = SteerMsg.safeParse(msg);
    if (parsed.success) return { type: "steer", directive: parsed.data.directive };
    return null;
  }
  if (type === "launch") {
    const m = msg as { workflowId?: unknown };
    if (typeof m.workflowId === "string") return { type: "launch", workflowId: m.workflowId };
    return null;
  }
  if (type === "navigate") {
    const m = msg as { screen?: unknown };
    if (m.screen === "home" || m.screen === "loop") return { type: "navigate", screen: m.screen };
    return null;
  }
  if (type === "answer") {
    const m = msg as { id?: unknown; text?: unknown };
    if (typeof m.id === "string" && typeof m.text === "string") {
      return { type: "answer", id: m.id, text: m.text };
    }
    return null;
  }
  if (type === "navigator") {
    const m = msg as { open?: unknown };
    if (typeof m.open === "boolean") return { type: "navigator", open: m.open };
    return null;
  }
  if (type === "intervene") {
    const m = msg as { action?: unknown; agentId?: unknown };
    if ((m.action === "pause" || m.action === "swap" || m.action === "spawn") &&
        (m.agentId === undefined || typeof m.agentId === "string")) {
      return m.agentId === undefined
        ? { type: "intervene", action: m.action }
        : { type: "intervene", action: m.action, agentId: m.agentId };
    }
    return null;
  }
  if (type === "revise") {
    const m = msg as { id?: unknown };
    if (typeof m.id === "string") return { type: "revise", id: m.id };
    return null;
  }
  if (type === "open") {
    const m = msg as { file?: unknown; line?: unknown };
    if (typeof m.file === "string" && (m.line === undefined || typeof m.line === "number")) {
      return m.line === undefined ? { type: "open", file: m.file } : { type: "open", file: m.file, line: m.line };
    }
    return null;
  }
  return null;
}

// Drive the bridge from a validated frame, exactly as the WS handler did.
export function applyInbound(bridge: Bridge, f: InboundFrame): void {
  switch (f.type) {
    case "decide":
      bridge.resolveDecision(f.id, f.choiceId);
      return;
    case "steer":
      bridge.enqueueDirective(f.directive);
      return;
    case "launch":
      bridge.requestLaunch(f.workflowId);
      return;
    case "navigate":
      bridge.navigate(f.screen);
      return;
    case "answer":
      bridge.resolveQuestion(f.id, f.text);
      return;
    case "navigator":
      f.open ? bridge.openNavigator() : bridge.closeNavigator();
      return;
    case "intervene":
      bridge.intervene(f.action, f.agentId);
      return;
    case "revise":
      bridge.revise(f.id);
      return;
    case "open":
      bridge.enqueueDirective({ kind: "note", text: f.line != null ? `open ${f.file}:${f.line} in the editor` : `open ${f.file} in the editor` });
      return;
  }
}
