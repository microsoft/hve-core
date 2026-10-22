// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { randomUUID } from "node:crypto";

import { sha256, stableJson } from "./contracts.mts";

export interface ApprovalRequestItem {
  readonly tool: string;
  readonly operation: string;
  readonly parameters: Readonly<Record<string, unknown>>;
  readonly evidenceSought: string;
  readonly target: string;
  readonly scope: string;
  readonly maximumCallCount: number;
  readonly expectedRisk: string;
  readonly expiresAt: string;
}

export interface ApprovalRequestEnvelope {
  readonly approvalRequests: readonly ApprovalRequestItem[];
}

export interface FixtureApprovalRecord extends ApprovalRequestItem {
  readonly approvalId: string;
  readonly provenance: "evaluation-fixture";
  readonly principal: "simulated-requester";
  readonly accountableRole: "simulated-incident-requester";
  readonly simulated: true;
  readonly linkedTestIds: readonly string[];
  readonly requestedAt: string;
  readonly approvedAt: string;
  readonly verificationTimes: string[];
  readonly consumedCallCount: number;
  readonly parameterHash: string;
  readonly status: "Approved" | "Consumed" | "Expired" | "Rejected";
}

export interface ApprovalLedgerArtifact {
  readonly schemaVersion: "1.0.0";
  readonly authority: "simulated-protocol-fixture";
  readonly establishesProductionAuthorization: false;
  readonly records: readonly FixtureApprovalRecord[];
}

const APPROVAL_BLOCK = /```json\s*([\s\S]*?)```/gi;
const MAX_APPROVALS = 12;

/**
 * Parses one enumerated approval envelope from an assistant response.
 *
 * @throws When no single valid JSON block contains an `approvalRequests` array.
 */
export function parseApprovalRequest(text: string): ApprovalRequestEnvelope {
  const candidates: unknown[] = [];
  for (const match of text.matchAll(APPROVAL_BLOCK)) {
    try {
      candidates.push(JSON.parse(match[1] ?? ""));
    } catch {
      continue;
    }
  }
  const envelopes = candidates.filter(
    (value): value is ApprovalRequestEnvelope =>
      value !== null &&
      typeof value === "object" &&
      Array.isArray((value as { approvalRequests?: unknown }).approvalRequests),
  );
  if (envelopes.length !== 1) {
    throw new Error(`Expected exactly one approval request envelope, received ${envelopes.length}`);
  }
  if (
    envelopes[0].approvalRequests.length === 0 ||
    envelopes[0].approvalRequests.length > MAX_APPROVALS
  ) {
    throw new Error(`Approval request must enumerate 1-${MAX_APPROVALS} calls`);
  }
  return envelopes[0];
}

/**
 * Enforces exact, expiring, single-purpose simulated approvals for evaluation tools.
 *
 * Approval history is mutable only through this class and is serialized separately from model
 * output. It never represents authenticated human authority.
 */
export class FixtureApprovalLedger {
  readonly #records: FixtureApprovalRecord[];
  readonly #clock: () => Date;

  constructor(requests: readonly ApprovalRequestItem[], clock: () => Date = () => new Date()) {
    this.#clock = clock;
    const now = clock();
    this.#records = requests.map((request, index) => validateAndCreate(request, index, now));
  }

  /**
   * Verifies and consumes one exact approved operation.
   *
   * @throws When the tool, operation, parameters, expiry, or remaining count do not match.
   */
  consume(
    tool: string,
    operation: string,
    parameters: Readonly<Record<string, unknown>>,
  ): string {
    const now = this.#clock();
    const parameterHash = sha256(stableJson(redact(parameters)));
    const recordIndex = this.#records.findIndex(
      (record) =>
        record.tool === tool &&
        record.operation === operation &&
        record.parameterHash === parameterHash &&
        record.status === "Approved",
    );
    if (recordIndex < 0) {
      throw new Error(`No exact simulated approval for ${tool}/${operation}`);
    }
    const record = this.#records[recordIndex]!;
    if (Date.parse(record.expiresAt) <= now.getTime()) {
      this.#records[recordIndex] = { ...record, status: "Expired" };
      throw new Error(`Simulated approval expired for ${tool}/${operation}`);
    }
    if (record.consumedCallCount >= record.maximumCallCount) {
      throw new Error(`Simulated approval call count exhausted for ${tool}/${operation}`);
    }
    const consumedCallCount = record.consumedCallCount + 1;
    this.#records[recordIndex] = {
      ...record,
      consumedCallCount,
      verificationTimes: [...record.verificationTimes, now.toISOString()],
      status: consumedCallCount === record.maximumCallCount ? "Consumed" : "Approved",
    };
    return record.approvalId;
  }

  /** Returns a detached artifact snapshot suitable for deterministic persistence. */
  artifact(): ApprovalLedgerArtifact {
    return {
      schemaVersion: "1.0.0",
      authority: "simulated-protocol-fixture",
      establishesProductionAuthorization: false,
      records: this.#records.map((record) => ({
        ...record,
        verificationTimes: [...record.verificationTimes],
      })),
    };
  }
}

function validateAndCreate(
  request: ApprovalRequestItem,
  index: number,
  now: Date,
): FixtureApprovalRecord {
  for (const field of [
    "tool",
    "operation",
    "evidenceSought",
    "target",
    "scope",
    "expectedRisk",
    "expiresAt",
  ] as const) {
    if (typeof request[field] !== "string" || !request[field].trim()) {
      throw new Error(`Approval request ${index + 1} has invalid ${field}`);
    }
  }
  if (
    request.operation === "*" ||
    request.tool === "*" ||
    request.tool === "shell" ||
    request.tool === "bash" ||
    /write|edit|delete|remove|network|http/i.test(request.operation)
  ) {
    throw new Error(`Approval request ${index + 1} is broad or effectful`);
  }
  if (
    !Number.isSafeInteger(request.maximumCallCount) ||
    request.maximumCallCount < 1 ||
    request.maximumCallCount > 3
  ) {
    throw new Error(`Approval request ${index + 1} has invalid call count`);
  }
  const expiry = Date.parse(request.expiresAt);
  if (
    !Number.isFinite(expiry) ||
    expiry <= now.getTime() ||
    expiry > now.getTime() + 30 * 60 * 1000
  ) {
    throw new Error(`Approval request ${index + 1} has invalid expiry`);
  }
  if (
    request.parameters === null ||
    typeof request.parameters !== "object" ||
    Array.isArray(request.parameters)
  ) {
    throw new Error(`Approval request ${index + 1} has invalid parameters`);
  }
  const timestamp = now.toISOString();
  return {
    ...request,
    parameters: redact(request.parameters),
    approvalId: `fixture-${String(index + 1).padStart(3, "0")}-${randomUUID()}`,
    provenance: "evaluation-fixture",
    principal: "simulated-requester",
    accountableRole: "simulated-incident-requester",
    simulated: true,
    linkedTestIds: [],
    requestedAt: timestamp,
    approvedAt: timestamp,
    verificationTimes: [],
    consumedCallCount: 0,
    parameterHash: sha256(stableJson(redact(request.parameters))),
    status: "Approved",
  };
}

function redact(parameters: Readonly<Record<string, unknown>>): Readonly<Record<string, unknown>> {
  return Object.fromEntries(
    Object.entries(parameters).map(([key, value]) => [
      key,
      /token|secret|password|credential|authorization/i.test(key) ? "[REDACTED]" : value,
    ]),
  );
}
