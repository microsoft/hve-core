// rpi-cockpit/src/bridge.ts
import { EventEmitter } from "node:events";
import { initialState, applyBeat, enqueueDirective as reduceEnqueue, drainDirectives as reduceDrain, setView, startLaunch, setNavigatorOpen, type SessionState } from "./state.js";
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
            if (fallback !== undefined) {
              // Log the auto-resolve so a timeout fallback is distinguishable from a
              // real user pick (the durable decisions.jsonl records only the choiceId). (B3)
              this.state = { ...this.state, log: [...this.state.log, { t: Date.now(), kind: "decision.timeout", detail: `auto-resolved to ${fallback}` }] };
              this.emit("state", this.state);
              this.resolveDecision(id, fallback);
            }
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

  askQuestion(prompt: string, timeoutMs = 0): Promise<string> {
    const id = `q${++this.seq}`;
    this.state = { ...this.state, pendingQuestion: { id, prompt } };
    this.emit("state", this.state);
    return new Promise<string>((resolve) => {
      this.pending.set(id, resolve);
      if (timeoutMs > 0) {
        setTimeout(() => { if (this.pending.has(id)) this.resolveQuestion(id, ""); }, timeoutMs);
      }
    });
  }

  resolveQuestion(id: string, text: string): void {
    const resolve = this.pending.get(id);
    if (!resolve) return;
    this.pending.delete(id);
    if (this.state.pendingQuestion?.id === id) {
      this.state = { ...this.state, pendingQuestion: null };
      this.emit("state", this.state);
    }
    resolve(text);
  }
}
