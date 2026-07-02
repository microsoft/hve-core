// rpi-cockpit/src/bridge.ts
import { EventEmitter } from "node:events";
import { initialState, applyBeat, enqueueDirective as reduceEnqueue, drainDirectives as reduceDrain, setView, startLaunch, setNavigatorOpen, addDecision, answerDecision, reviseDecision, setHostElicits as reduceSetHostElicits, type SessionState } from "./state.js";
import type { Beat, OptionItem, InboundDirective, Directive } from "./events.js";
import { WORKFLOWS } from "./catalog.js";

export class Bridge extends EventEmitter {
  state: SessionState = initialState();
  private pending = new Map<string, (choiceId: string) => void>();
  private seq = 0;

  emitBeat(beat: Beat): void {
    this.state = applyBeat(this.state, beat, Date.now());
    this.emit("state", this.state);
  }

  enqueueDirective(directive: InboundDirective): void {
    const stamped = { ...directive, id: `s${++this.seq}` } as Directive;
    this.state = reduceEnqueue(this.state, stamped, Date.now());
    this.emit("state", this.state);
    // Granular, additive: lets a file sink durably record the steering directive
    // for hosts that read it off disk rather than via the in-process MCP drain.
    this.emit("directive", stamped);
  }

  requestLaunch(workflowId: string): void {
    const wf = WORKFLOWS.find((w) => w.id === workflowId);
    if (!wf) return;
    this.state = startLaunch(this.state, wf.id);
    // Reuse the directive channel: the agent drains this via check_directives
    // and performs the launch. The cockpit never starts the agent itself.
    this.enqueueDirective({ kind: "approach", value: wf.id, label: wf.intent });
  }

  // Intervention is intent only: enqueue a directive note the orchestrator drains
  // via check_directives and acts on. The cockpit never pauses, swaps, or spawns an
  // agent itself — it has no handle on the running agents. Reuse enqueueDirective so
  // the note rides the same talk-back channel as steer (stamped, logged, file-sunk).
  intervene(action: "pause" | "swap" | "spawn", agentId?: string): void {
    const text = action === "spawn"
      ? "intervene: spawn a new agent"
      : `intervene: ${action} agent ${agentId ?? ""}`.trim();
    this.enqueueDirective({ kind: "note", text });
  }

  navigate(screen: "home" | "loop"): void {
    this.state = setView(this.state, screen);
    this.emit("state", this.state);
  }

  openNavigator(): void {
    this.state = setNavigatorOpen(this.state, true);
    this.emit("state", this.state);
  }

  closeNavigator(): void {
    this.state = setNavigatorOpen(this.state, false);
    this.emit("state", this.state);
  }

  drainDirectives(): Directive[] {
    const { state, drained } = reduceDrain(this.state, Date.now());
    if (drained.length > 0) {
      this.state = state;
      this.emit("state", this.state);
    }
    return drained;
  }

  offerApproaches(label: string, options: OptionItem[]): void {
    this.emitBeat({ type: "approaches.offer", label, options });
  }

  showScreen(html: string, title?: string): void {
    this.emitBeat({ type: "screen.show", html, title });
  }

  clearScreen(): void {
    this.emitBeat({ type: "screen.clear" });
  }

  presentOptions(prompt: string, options: OptionItem[], timeoutMs = 0, id?: string): Promise<string> {
    const did = id ?? `d${++this.seq}`;
    this.state = addDecision(this.state, { id: did, prompt, kind: "choice", options });
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(did, resolve);
      if (timeoutMs > 0) setTimeout(() => {
        if (this.pending.has(did)) {
          // Log the auto-resolve so a timeout fallback is distinguishable from a
          // real user pick (the durable decisions.jsonl records only the choiceId). (B3)
          const fallback = options.find((o) => o.recommended)?.id ?? options[0]?.id;
          if (fallback !== undefined) {
            this.state = { ...this.state, log: [...this.state.log, { t: Date.now(), kind: "decision.timeout", detail: `auto-resolved to ${fallback}` }] };
            this.emit("state", this.state);
            this.resolveDecision(did, fallback);
          }
        }
      }, timeoutMs);
    });
  }

  resolveDecision(id: string, choiceId: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    const prompt = this.state.decisions.find((d) => d.id === id)?.prompt;
    this.state = answerDecision(this.state, id, choiceId);
    this.emit("state", this.state);
    resolve(choiceId);
    // Additive: only emitted on a real resolution (unknown ids returned above).
    this.emit("decision", prompt === undefined ? { id, choiceId } : { id, choiceId, prompt });
  }

  askQuestion(prompt: string, timeoutMs = 0, id?: string): Promise<string> {
    const qid = id ?? `q${++this.seq}`;
    this.state = addDecision(this.state, { id: qid, prompt, kind: "text" });
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(qid, resolve);
      if (timeoutMs > 0) setTimeout(() => { if (this.pending.has(qid)) this.resolveQuestion(qid, ""); }, timeoutMs);
    });
  }

  resolveQuestion(id: string, text: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    this.state = answerDecision(this.state, id, text);
    this.emit("state", this.state);
    resolve(text);
  }

  revise(id: string): void {
    const entry = this.state.decisions.find((d) => d.id === id);
    if (!entry) return;
    this.state = reviseDecision(this.state, id);
    this.emit("state", this.state);
    this.enqueueDirective({ kind: "note", text: `revise decision "${entry.prompt}" (id ${id}): re-ask it and reconsider what follows` });
  }

  setHostElicits(v: boolean): void {
    this.state = reduceSetHostElicits(this.state, v);
    this.emit("state", this.state);
  }
}
