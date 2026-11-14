// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { randomUUID } from "node:crypto";

import { COMMUNICATION_LIMITS, sha256, stableJson } from "./contracts.mts";

export interface ApprovalRequestItem {
  readonly requestId?: string;
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
  readonly stopReason?: string;
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
const MAX_APPROVALS = COMMUNICATION_LIMITS.approvalsPerBatch;

/** Supplies a fresh host-clock deadline for a model-requested simulated approval batch. */
export function approvalTimingInstruction(now: Date): string {
  const expiry = new Date(now.getTime() + 15 * 60 * 1000).toISOString();
  return `Current host UTC time: ${now.toISOString()}. Use exactly "${expiry}" for every expiresAt in this batch. Do not infer the current time from incident telemetry or extend the deadline. The host rejects expired approvals and deadlines more than 30 minutes ahead.`;
}

/**
 * Parses one enumerated approval envelope from an assistant response.
 *
 * @param allowBlockedStop - Allows no calls only with an explicit, bounded stop reason.
 *   Initial approval requests must leave this false.
 * @throws When no single valid JSON block contains an `approvalRequests` array.
 */
export function parseApprovalRequest(text: string, allowBlockedStop = false): ApprovalRequestEnvelope {
  const candidates: unknown[] = [];
  const trimmed = text.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    try { candidates.push(JSON.parse(trimmed)); }
    catch (error) { throw new Error(`Malformed approval JSON: ${error instanceof Error ? error.message : String(error)}`); }
  }
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
  const envelope = envelopes[0];
  if (envelope.stopReason !== undefined) {
    if (
      !allowBlockedStop ||
      envelope.approvalRequests.length !== 0 ||
      typeof envelope.stopReason !== "string" ||
      envelope.stopReason.trim().length === 0 ||
      envelope.stopReason.length > 2_000
    ) {
      throw new Error("A blocked stop requires no calls and a nonempty stopReason of at most 2000 characters");
    }
    return envelope;
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
    return consumeFixtureApproval(this.#records, tool, operation, parameters, this.#clock());
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

  /** Resolves the host call identity without treating stored approval history as new authority. */
  requestId(approvalId: string): string | undefined {
    return this.#records.find((record) => record.approvalId === approvalId)?.requestId;
  }
}

/**
 * Consumes one exact simulated approval, replacing its record in the supplied mutable array.
 *
 * Expired records transition to Expired before throwing. Successful calls update the count,
 * verification time, and status; no matching approval or an exhausted call count throws.
 * Hashes bind the original parameters, not the redacted display tree.
 */
export function consumeFixtureApproval(
  records: FixtureApprovalRecord[],
  tool: string,
  operation: string,
  parameters: Readonly<Record<string, unknown>>,
  now: Date,
): string {
  const parameterHash = sha256(stableJson(parameters));
  const index = records.findIndex(
    (record) =>
      record.tool === tool &&
      record.operation === operation &&
      record.parameterHash === parameterHash &&
      record.status === "Approved",
  );
  if (index < 0) {
    throw new Error(`No exact simulated approval for ${tool}/${operation}`);
  }
  const record = records[index]!;
  if (Date.parse(record.expiresAt) <= now.getTime()) {
    records[index] = { ...record, status: "Expired" };
    throw new Error(`Simulated approval expired for ${tool}/${operation}`);
  }
  if (record.consumedCallCount >= record.maximumCallCount) {
    throw new Error(`Simulated approval call count exhausted for ${tool}/${operation}`);
  }
  const consumedCallCount = record.consumedCallCount + 1;
  records[index] = {
    ...record,
    consumedCallCount,
    verificationTimes: [...record.verificationTimes, now.toISOString()],
    status: consumedCallCount === record.maximumCallCount ? "Consumed" : "Approved",
  };
  return record.approvalId;
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
    parameters: redactApprovalParameters(request.parameters),
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
    parameterHash: sha256(stableJson(request.parameters)),
    status: "Approved",
  };
}

/** Returns a detached JSON parameter tree with secret-shaped keys masked at every nesting level. */
export function redactApprovalParameters(
  parameters: Readonly<Record<string, unknown>>,
): Readonly<Record<string, unknown>> {
  return Object.fromEntries(
    Object.entries(parameters).map(([key, value]) => [
      key,
      /token|secret|password|credential|authorization/i.test(key)
        ? "[REDACTED]"
        : redactParameterValue(value),
    ]),
  );
}

function redactParameterValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(redactParameterValue);
  }
  if (value !== null && typeof value === "object") {
    return redactApprovalParameters(Object.fromEntries(Object.entries(value)));
  }
  return value;
}
