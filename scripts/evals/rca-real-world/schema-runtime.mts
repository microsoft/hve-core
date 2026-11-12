// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";

import { COMMUNICATION_LIMITS } from "./contracts.mts";
import { checkMessageBytes } from "./communication.mts";

/** Preview headless-runtime transport. Its owner must close it, including after failed requests. */
export interface SchemaRuntime {
  request(method: string, params?: Readonly<Record<string, unknown>>): Promise<unknown>;
  onEvent(handler: (event: Readonly<Record<string, unknown>>) => void): () => void;
  close(): Promise<void>;
}

/** Captures a bounded turn through idle; callers retain partial events if delivery or generation fails. */
export async function sendRuntimeTurn(options: {
  readonly runtime: SchemaRuntime;
  readonly sessionId: string;
  readonly prompt: string;
  readonly responseFormat?: Readonly<Record<string, unknown>>;
  readonly timeoutMs: number;
  readonly events: Readonly<Record<string, unknown>>[];
}): Promise<void> {
  let settle!: () => void;
  let reject!: (error: Error) => void;
  const completion = new Promise<void>((resolve, fail) => { settle = resolve; reject = fail; });
  void completion.catch(() => {});
  let bytes = 0;
  const deltaBytes = new Map<string, number>();
  const off = options.runtime.onEvent((event) => {
    try {
      options.events.push(event);
      bytes += Buffer.byteLength(JSON.stringify(event));
      if (bytes > COMMUNICATION_LIMITS.stdoutBytes) reject(new Error("Turn event limit exceeded"));
      const data = event.data === undefined ? {} : runtimeRecord(event.data);
      checkMessageBytes(event, deltaBytes);
      if (event.type === "tool.execution_start" ||
          (event.type === "assistant.message" && Array.isArray(data.toolRequests) && data.toolRequests.length)) {
        reject(new Error("Tool execution is forbidden in host-mediated evidence mode"));
      }
      if (event.type === "session.error") reject(new Error(`Runtime session error: ${JSON.stringify(data)}`));
      if (event.type === "session.idle") settle();
    } catch (error) {
      reject(error instanceof Error ? error : new Error(String(error)));
    }
  });
  const timer = setTimeout(() => reject(new Error("Model turn timed out")), options.timeoutMs);
  try {
    await Promise.all([
      options.runtime.request("session.send", {
        sessionId: options.sessionId, prompt: options.prompt,
        ...(options.responseFormat ? { responseFormat: options.responseFormat } : {}),
      }),
      completion,
    ]);
  } finally {
    clearTimeout(timer);
    off();
  }
}

/** Rejects unexpected wire shapes rather than trusting preview runtime responses. */
export function runtimeRecord(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Runtime response must be an object");
  }
  return value as Record<string, unknown>;
}

/** Decodes bounded Content-Length frames, including headers and multibyte bodies split across chunks. */
export class RuntimeFrames {
  private buffer = Buffer.alloc(0);
  private bytes = 0;

  push(chunk: Buffer): readonly unknown[] {
    this.bytes += chunk.length;
    if (this.bytes > COMMUNICATION_LIMITS.stdoutBytes) throw new Error("Runtime output limit exceeded");
    this.buffer = Buffer.concat([this.buffer, chunk]);
    const messages: unknown[] = [];
    while (this.buffer.length) {
      const end = this.buffer.indexOf("\r\n\r\n");
      if (end < 0) {
        if (this.buffer.length > 1024) throw new Error("Runtime frame header exceeds limit");
        break;
      }
      const header = this.buffer.subarray(0, end).toString("ascii");
      const match = /^Content-Length: (\d+)$/i.exec(header);
      if (!match) throw new Error("Invalid runtime frame header");
      const length = Number(match[1]);
      if (!Number.isSafeInteger(length) || length < 1 || length > COMMUNICATION_LIMITS.stdoutBytes) {
        throw new Error("Invalid runtime frame length");
      }
      if (this.buffer.length < end + 4 + length) break;
      const body = this.buffer.subarray(end + 4, end + 4 + length).toString("utf8");
      this.buffer = this.buffer.subarray(end + 4 + length);
      messages.push(JSON.parse(body) as unknown);
    }
    return messages;
  }
}

/** Starts only the installed CLI, with no tool execution or unconstrained fallback on transport errors. */
export function startSchemaRuntime(options: {
  readonly cwd: string;
  readonly env: NodeJS.ProcessEnv;
}): SchemaRuntime {
  const child: ChildProcessWithoutNullStreams = spawn("copilot", [
    "--headless", "--stdio", "--no-auto-update", "--disable-client-telemetry",
    "--no-custom-instructions", "--disable-builtin-mcps",
    "--max-ai-credits", String(COMMUNICATION_LIMITS.aiCredits),
  ], { ...options, windowsHide: true, stdio: ["pipe", "pipe", "pipe"] });
  const frames = new RuntimeFrames();
  const handlers = new Set<(event: Readonly<Record<string, unknown>>) => void>();
  const pending = new Map<number, {
    resolve: (value: unknown) => void; reject: (error: Error) => void; timer: NodeJS.Timeout;
  }>();
  let nextId = 0;
  let failure: Error | undefined;
  let stderrBytes = 0;
  let closed = false;
  const exited = new Promise<void>((resolve) => child.once("close", () => resolve()));
  const fail = (error: Error): void => {
    failure ??= error;
    for (const request of pending.values()) {
      clearTimeout(request.timer);
      request.reject(error);
    }
    pending.clear();
    for (const handler of handlers) handler({ type: "session.error", data: { message: error.message } });
  };
  const write = (value: unknown): void => {
    const body = JSON.stringify(value);
    child.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
  };
  child.on("error", fail);
  child.stdin.on("error", fail);
  child.once("exit", (code, signal) => {
    if (!closed) fail(new Error(`Runtime exited unexpectedly: ${code ?? signal}`));
  });
  child.stderr.on("data", (chunk: Buffer) => {
    stderrBytes += chunk.length;
    if (stderrBytes > COMMUNICATION_LIMITS.stderrBytes) {
      fail(new Error("Runtime stderr limit exceeded"));
      child.kill();
    }
  });
  child.stdout.on("data", (chunk: Buffer) => {
    try {
      for (const value of frames.push(chunk)) {
        const message = runtimeRecord(value);
        if (message.method !== undefined && message.id !== undefined) {
          write({
            jsonrpc: "2.0", id: message.id,
            error: { code: -32601, message: "Client callbacks and tool execution are disabled" },
          });
          fail(new Error("Runtime attempted a disabled client callback"));
        } else if (message.method !== undefined) {
          const params = runtimeRecord(message.params);
          const event = runtimeRecord(params.event ?? params);
          for (const handler of handlers) handler(event);
        } else if (typeof message.id === "number") {
          const request = pending.get(message.id);
          if (!request) continue;
          pending.delete(message.id);
          clearTimeout(request.timer);
          if (message.error !== undefined) request.reject(new Error(JSON.stringify(message.error)));
          else request.resolve(message.result);
        } else throw new Error("Unrecognized runtime message");
      }
    } catch (error) {
      fail(error instanceof Error ? error : new Error(String(error)));
      child.kill();
    }
  });
  return {
    request: (method, params = {}) => {
      if (closed || failure) return Promise.reject(failure ?? new Error("Runtime is closed"));
      const id = ++nextId;
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          pending.delete(id);
          const error = new Error(`Runtime request timed out: ${method}`);
          reject(error);
          fail(error);
        }, 30_000);
        pending.set(id, { resolve, reject, timer });
        write({ jsonrpc: "2.0", id, method, params });
      });
    },
    onEvent: (handler) => {
      handlers.add(handler);
      return () => { handlers.delete(handler); };
    },
    close: async () => {
      if (closed) return exited;
      closed = true;
      fail(new Error("Runtime closed"));
      handlers.clear();
      child.stdin.end();
      child.kill();
      let timer: NodeJS.Timeout | undefined;
      try {
        await Promise.race([
          exited,
          new Promise<never>((_, reject) => {
            timer = setTimeout(() => reject(new Error("Runtime cleanup timed out")), 5000);
          }),
        ]);
      } finally {
        clearTimeout(timer);
      }
    },
  };
}
