// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readFile } from "node:fs/promises";

import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import {
  consumeFixtureApproval,
  type ApprovalLedgerArtifact,
  type FixtureApprovalRecord,
} from "./approval.mts";
import { writeJson } from "./contracts.mts";
import {
  createEvidenceTools,
  type ApprovalConsumer,
  type EvidenceToolTrace,
  type ToolDefinition,
} from "./evidence-tools.mts";

interface JsonRpcRequest {
  readonly jsonrpc: "2.0";
  readonly id?: string | number | null;
  readonly method: string;
  readonly params?: Record<string, unknown>;
}

interface JsonRpcResponse {
  readonly jsonrpc: "2.0";
  readonly id: string | number | null;
  readonly result?: unknown;
  readonly error?: { readonly code: number; readonly message: string };
}

interface MutableApprovalLedger {
  schemaVersion: "1.0.0";
  authority: "simulated-protocol-fixture";
  establishesProductionAuthorization: false;
  records: FixtureApprovalRecord[];
}

/** Enforces exact approvals loaded from the separate fixture ledger used by a CLI session. */
export class FileApprovalConsumer implements ApprovalConsumer {
  readonly #ledger: MutableApprovalLedger;
  readonly #clock: () => Date;

  constructor(artifact: ApprovalLedgerArtifact, clock: () => Date = () => new Date()) {
    this.#clock = clock;
    this.#ledger = {
      ...artifact,
      records: artifact.records.map((record) => ({
        ...record,
        verificationTimes: [...record.verificationTimes],
      })),
    };
  }

  consume(
    tool: string,
    operation: string,
    parameters: Readonly<Record<string, unknown>>,
  ): string {
    return consumeFixtureApproval(
      this.#ledger.records, tool, operation, parameters, this.#clock(),
    );
  }

  /** Returns the updated fixture ledger for persistence after each MCP call. */
  artifact(): ApprovalLedgerArtifact {
    return {
      ...this.#ledger,
      records: this.#ledger.records.map((record) => ({
        ...record,
        verificationTimes: [...record.verificationTimes],
      })),
    };
  }
}

/**
 * Handles the bounded MCP methods used by Copilot CLI.
 *
 * Unknown methods and tools fail closed. Notifications without IDs return no response.
 */
export async function handleMcpRequest(
  request: JsonRpcRequest,
  tools: readonly ToolDefinition[],
  persist: () => Promise<void>,
): Promise<JsonRpcResponse | undefined> {
  if (request.method === "notifications/initialized" || request.method === "notifications/cancelled") {
    return undefined;
  }
  if (request.id === undefined) {
    return undefined;
  }
  if (request.method === "initialize") {
    return success(request.id, {
      protocolVersion:
        typeof request.params?.protocolVersion === "string"
          ? request.params.protocolVersion
          : "2025-06-18",
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: "hve-rca-evidence", version: "1.0.0" },
    });
  }
  if (request.method === "ping") {
    return success(request.id, {});
  }
  if (request.method === "tools/list") {
    return success(request.id, {
      tools: tools.map((tool) => ({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.parameters,
      })),
    });
  }
  if (request.method === "tools/call") {
    const name = request.params?.name;
    const args = request.params?.arguments;
    if (
      typeof name !== "string" ||
      args === null ||
      typeof args !== "object" ||
      Array.isArray(args)
    ) {
      return failure(request.id, -32602, "Invalid MCP tool call parameters");
    }
    const tool = tools.find((candidate) => candidate.name === name);
    if (!tool) {
      return failure(request.id, -32601, `Unknown RCA evidence tool: ${name}`);
    }
    try {
      const text = await tool.handler(args as Record<string, unknown>);
      await persist();
      return success(request.id, { content: [{ type: "text", text }], isError: false });
    } catch (error) {
      await persist();
      return success(request.id, {
        content: [
          {
            type: "text",
            text: error instanceof Error ? error.message : String(error),
          },
        ],
        isError: true,
      });
    }
  }
  return failure(request.id, -32601, `Unsupported MCP method: ${request.method}`);
}

/**
 * Parses one MCP message, distinguishing invalid JSON, invalid requests, and handler failures.
 *
 * Unknown request IDs use null. Handler errors preserve the request ID; notifications never
 * receive an error response.
 */
export async function handleMcpMessage(
  line: string,
  tools: readonly ToolDefinition[],
  persist: () => Promise<void>,
): Promise<JsonRpcResponse | undefined> {
  let request: unknown;
  try {
    request = JSON.parse(line);
  } catch (error) {
    return failure(null, -32700, error instanceof Error ? error.message : String(error));
  }
  if (request === null || typeof request !== "object" || Array.isArray(request)) {
    return failure(null, -32600, "Invalid JSON-RPC request");
  }
  const id = "id" in request ? request.id : undefined;
  const params = "params" in request ? request.params : undefined;
  const validId = id === undefined || id === null || typeof id === "string" ||
    (typeof id === "number" && Number.isFinite(id));
  if (
    !("jsonrpc" in request) || request.jsonrpc !== "2.0" ||
    !("method" in request) || typeof request.method !== "string" ||
    !validId ||
    (params !== undefined && (
      params === null || typeof params !== "object" ||
      Array.isArray(params)
    ))
  ) {
    return failure(
      validId && id !== undefined ? id : null, -32600, "Invalid JSON-RPC request",
    );
  }
  const parsedRequest: JsonRpcRequest = {
    jsonrpc: "2.0",
    id,
    method: request.method,
    params: params === undefined ? undefined : Object.fromEntries(Object.entries(params)),
  };
  try {
    return await handleMcpRequest(parsedRequest, tools, persist);
  } catch (error) {
    if (parsedRequest.id === undefined) {
      return undefined;
    }
    return failure(
      parsedRequest.id, -32603, error instanceof Error ? error.message : String(error),
    );
  }
}

async function runServer(): Promise<void> {
  const { values } = parseArgs({
    options: {
      "case-root": { type: "string" },
      ledger: { type: "string" },
      trace: { type: "string" },
    },
  });
  if (!values["case-root"] || !values.ledger || !values.trace) {
    throw new Error("MCP server requires --case-root, --ledger, and --trace");
  }
  const ledgerArtifact = JSON.parse(
    await readFile(values.ledger, "utf8"),
  ) as ApprovalLedgerArtifact;
  const approvals = new FileApprovalConsumer(ledgerArtifact);
  const evidence = createEvidenceTools({
    caseRoot: values["case-root"],
    ledger: approvals,
  });
  try {
    const existing = JSON.parse(await readFile(values.trace, "utf8")) as {
      traces?: EvidenceToolTrace[];
    };
    evidence.traces.push(...(existing.traces ?? []));
  } catch (error) {
    if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
      throw error;
    }
  }
  const persist = async () => {
    await writeJson(values.ledger!, approvals.artifact());
    await writeJson(values.trace!, {
      schemaVersion: "1.0.0",
      traces: evidence.traces satisfies readonly EvidenceToolTrace[],
    });
  };
  await persist();

  const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
  for await (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) {
      continue;
    }
    const response = await handleMcpMessage(line, evidence.tools, persist);
    if (response) {
      process.stdout.write(`${JSON.stringify(response)}\n`);
    }
  }
}

function success(id: string | number | null, result: unknown): JsonRpcResponse {
  return { jsonrpc: "2.0", id, result };
}

function failure(id: string | number | null, code: number, message: string): JsonRpcResponse {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runServer();
}
