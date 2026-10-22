// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readFile } from "node:fs/promises";

import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import type { ApprovalLedgerArtifact, FixtureApprovalRecord } from "./approval.mts";
import { sha256, stableJson, writeJson } from "./contracts.mts";
import {
  createEvidenceTools,
  type ApprovalConsumer,
  type EvidenceToolTrace,
  type ToolDefinition,
} from "./evidence-tools.mts";

interface JsonRpcRequest {
  readonly jsonrpc: "2.0";
  readonly id?: string | number;
  readonly method: string;
  readonly params?: Record<string, unknown>;
}

interface JsonRpcResponse {
  readonly jsonrpc: "2.0";
  readonly id: string | number;
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
    const parameterHash = sha256(stableJson(redact(parameters)));
    const index = this.#ledger.records.findIndex(
      (record) =>
        record.tool === tool &&
        record.operation === operation &&
        record.parameterHash === parameterHash &&
        record.status === "Approved",
    );
    if (index < 0) {
      throw new Error(`No exact simulated approval for ${tool}/${operation}`);
    }
    const record = this.#ledger.records[index]!;
    const now = this.#clock();
    if (Date.parse(record.expiresAt) <= now.getTime()) {
      this.#ledger.records[index] = { ...record, status: "Expired" };
      throw new Error(`Simulated approval expired for ${tool}/${operation}`);
    }
    if (record.consumedCallCount >= record.maximumCallCount) {
      throw new Error(`Simulated approval call count exhausted for ${tool}/${operation}`);
    }
    const consumedCallCount = record.consumedCallCount + 1;
    this.#ledger.records[index] = {
      ...record,
      consumedCallCount,
      verificationTimes: [...record.verificationTimes, now.toISOString()],
      status: consumedCallCount === record.maximumCallCount ? "Consumed" : "Approved",
    };
    return record.approvalId;
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
    let response: JsonRpcResponse | undefined;
    try {
      const request = JSON.parse(line) as JsonRpcRequest;
      response = await handleMcpRequest(request, evidence.tools, persist);
    } catch (error) {
      response = failure(
        0,
        -32700,
        error instanceof Error ? error.message : String(error),
      );
    }
    if (response) {
      process.stdout.write(`${JSON.stringify(response)}\n`);
    }
  }
}

function success(id: string | number, result: unknown): JsonRpcResponse {
  return { jsonrpc: "2.0", id, result };
}

function failure(id: string | number, code: number, message: string): JsonRpcResponse {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

function redact(parameters: Readonly<Record<string, unknown>>): Readonly<Record<string, unknown>> {
  return Object.fromEntries(
    Object.entries(parameters).map(([key, value]) => [
      key,
      /token|secret|password|credential|authorization/i.test(key) ? "[REDACTED]" : value,
    ]),
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runServer();
}
