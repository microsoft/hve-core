// rpi-cockpit/src/bridge.ts
import { EventEmitter } from "node:events";
import { initialState, applyBeat, enqueueDirective as reduceEnqueue, drainDirectives as reduceDrain, type SessionState } from "./state.js";
import type { Beat, OptionItem, InboundDirective, Directive } from "./events.js";

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

  presentOptions(prompt: string, options: OptionItem[], timeoutMs = 0): Promise<string> {
    const id = `d${++this.seq}`;
    this.state = { ...this.state, pendingDecision: { id, prompt, options } };
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(id, resolve);
      if (timeoutMs > 0) {
        setTimeout(() => {
          if (this.pending.has(id)) {
            const fallback = options.find((o) => o.recommended)?.id ?? options[0]?.id;
            if (fallback !== undefined) this.resolveDecision(id, fallback);
          }
        }, timeoutMs);
      }
    });
  }

  resolveDecision(id: string, choiceId: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    // Capture the prompt before we clear the pending decision so the granular
    // "decision" event can carry it for the durable file sink.
    const prompt = this.state.pendingDecision?.id === id ? this.state.pendingDecision.prompt : undefined;
    if (this.state.pendingDecision?.id === id) {
      this.state = { ...this.state, pendingDecision: null };
      this.emit("state", this.state);
    }
    resolve(choiceId);
    // Additive: only emitted on a real resolution (unknown ids returned above).
    this.emit("decision", prompt === undefined ? { id, choiceId } : { id, choiceId, prompt });
  }
}
