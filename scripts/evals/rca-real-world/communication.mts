// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { COMMUNICATION_LIMITS, EVALUATION_PROTOCOL, sha256, stableJson } from "./contracts.mts";
import { parseApprovalRequest, type ApprovalRequestItem } from "./approval.mts";
import type { EvaluationCondition } from "./conditions.mts";

export { COMMUNICATION_LIMITS, EVIDENCE_OPERATIONS } from "./contracts.mts";

/** Machine diagnostics are independent of Markdown layout and wording. Null explicitly abstains. */
export interface DiagnosticReport {
  readonly candidate: {
    readonly target: string | null;
    readonly mechanism: string | null;
    readonly confidence: string;
  };
  readonly finding?: {
    readonly status: "not-established" | "ready-for-human-sign-off";
    readonly target: string | null;
    readonly mechanism: string | null;
  };
  readonly authority: { readonly simulated: true; readonly productionAuthorization: false };
  readonly limitations: readonly string[];
  readonly narrative: string;
}

/** Host-supplied identity binds a response to one case and one invocation, not an assistant message. */
export interface MessageContext {
  readonly messageId: string;
  readonly caseId: string;
  readonly condition: EvaluationCondition;
}

/** Correlates accepted model messages and exact calls, including a terminal protocol or execution failure. */
export interface CommunicationAudit {
  readonly protocol: typeof EVALUATION_PROTOCOL;
  readonly turns: readonly {
    readonly messageId: string;
    readonly messageType: ModelMessage["messageType"];
    readonly messageIndex: number;
    readonly messageHash: string;
    readonly requestIds: readonly string[];
  }[];
  readonly outcome: "final" | "blocked" | "protocol-error" | "execution-error";
  readonly errorCode?: string;
  readonly reason?: string;
}

/** Protocol violations are technical failures, never successful abstentions. */
export class CommunicationError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = "CommunicationError";
    this.code = code;
  }
}

export type ModelMessage =
  | { readonly messageType: "evidence_request"; readonly approvalRequests: readonly ApprovalRequestItem[] }
  | { readonly messageType: "final" | "blocked"; readonly report: DiagnosticReport; readonly reason?: string };

/** Accepts exact raw JSON or JSON fences. Non-JSON prose is not reinterpreted as a request. */
export function jsonDocuments(text: string): readonly unknown[] {
  const trimmed = text.trim();
  const blocks = [...text.matchAll(/(?:^|\r?\n)[ \t]*```(?:json)?[ \t]*\r?\n([\s\S]*?)\r?\n[ \t]*```(?=[ \t]*(?:\r?\n|$))/gi)];
  const raw = trimmed.startsWith("{") && trimmed.endsWith("}") ? [trimmed] : [];
  return (raw.length ? raw : blocks.map((match) => match[1]!)).map((value) => {
    try { return JSON.parse(value) as unknown; }
    catch { throw new CommunicationError("invalid-json", "Machine message contains malformed JSON"); }
  });
}

/** Recognizes all public messages; exactly one authoritative envelope is required per invocation. */
export function parseModelMessages(
  messages: readonly string[], context: MessageContext,
): { readonly message: ModelMessage; readonly messageIndex: number; readonly messageHash: string } {
  const envelopes: { value: Record<string, unknown>; index: number }[] = [];
  for (const [index, text] of messages.entries()) {
    if (Buffer.byteLength(text, "utf8") > COMMUNICATION_LIMITS.messageBytes) {
      throw new CommunicationError("message-too-large", "Public assistant message exceeds the shared byte limit");
    }
    const marked = /"(?:protocol|messageType|approvalRequests)"\s*:/.test(text);
    if (!marked) continue;
    const documents = jsonDocuments(text);
    if (documents.length === 0 && !text.trim().startsWith("{") &&
        !/(?:^|\r?\n)[ \t]*```(?:json)?[ \t]*\r?\n/i.test(text)) continue;
    const candidates = documents.filter(isRecord).filter(
      (value) => "protocol" in value || "messageType" in value || "approvalRequests" in value,
    );
    if (candidates.length === 0) {
      throw new CommunicationError("missing-envelope", "Protocol-marked text has no complete JSON envelope");
    }
    for (const value of candidates) envelopes.push({ value, index });
  }
  if (envelopes.length === 0) {
    throw new CommunicationError("missing-envelope", "No authoritative machine envelope was returned");
  }
  if (envelopes.length !== 1) {
    throw new CommunicationError("ambiguous-envelope", `Expected one authoritative machine envelope, received ${envelopes.length}`);
  }
  const { value, index } = envelopes[0]!;
  if (value.protocol !== EVALUATION_PROTOCOL || value.messageId !== context.messageId || value.caseId !== context.caseId) {
    throw new CommunicationError("context-mismatch", "Message protocol, case or invocation identity does not match the host");
  }
  const baseKeys = ["protocol", "messageId", "caseId", "messageType"];
  let message: ModelMessage;
  if (value.messageType === "evidence_request") {
    exactKeys(value, [...baseKeys, "approvalRequests"]);
    let request: ReturnType<typeof parseApprovalRequest>;
    try { request = parseApprovalRequest(JSON.stringify({ approvalRequests: value.approvalRequests })); }
    catch (error) {
      throw new CommunicationError("invalid-request", error instanceof Error ? error.message : String(error));
    }
    for (const item of request.approvalRequests) {
      if (!isRecord(item)) throw new CommunicationError("invalid-request", "Each evidence call must be an object");
      exactKeys(item, ["tool", "operation", "parameters", "evidenceSought", "target", "scope", "maximumCallCount", "expectedRisk", "expiresAt"]);
      for (const key of ["tool", "operation", "evidenceSought", "target", "scope", "expectedRisk", "expiresAt"]) {
        nonempty(item[key], key);
      }
      if (!isRecord(item.parameters) || item.maximumCallCount !== 1) {
        throw new CommunicationError("invalid-request", "Each evidence call requires an object of parameters and exactly one execution");
      }
    }
    message = { messageType: "evidence_request", approvalRequests: request.approvalRequests };
  } else if (value.messageType === "final" || value.messageType === "blocked") {
    exactKeys(value, [...baseKeys, "report", ...(value.messageType === "blocked" ? ["reason"] : [])]);
    if (value.messageType === "blocked") nonempty(value.reason, "blocked reason");
    const report = validateDiagnosticReport(value.report, context.condition);
    if (value.messageType === "blocked" && (
      report.candidate.target !== null || report.finding?.status === "ready-for-human-sign-off"
    )) {
      throw new CommunicationError("invalid-report", "A blocked message must explicitly abstain");
    }
    message = {
      messageType: value.messageType, report,
      ...(value.messageType === "blocked" ? { reason: value.reason as string } : {}),
    };
  } else {
    throw new CommunicationError("unknown-message-type", "Unknown machine message type");
  }
  return { message, messageIndex: index, messageHash: sha256(stableJson(value)) };
}

/** Rejects omitted, contradictory or condition-inappropriate diagnostic fields without prose fallback. */
export function validateDiagnosticReport(value: unknown, condition: EvaluationCondition): DiagnosticReport {
  if (!isRecord(value)) throw new CommunicationError("invalid-report", "Diagnostic report must be an object");
  exactKeys(value, ["candidate", "authority", "limitations", "narrative", ...(condition === "with-skill" ? ["finding"] : [])]);
  if (!isRecord(value.candidate)) throw new CommunicationError("invalid-report", "Missing candidate object");
  exactKeys(value.candidate, ["target", "mechanism", "confidence"]);
  nullableText(value.candidate.target, "candidate target");
  nullableText(value.candidate.mechanism, "candidate mechanism");
  nonempty(value.candidate.confidence, "candidate confidence");
  if (!isRecord(value.authority) || value.authority.simulated !== true || value.authority.productionAuthorization !== false) {
    throw new CommunicationError("invalid-authority", "Diagnostic authority must explicitly retain the simulated boundary");
  }
  exactKeys(value.authority, ["simulated", "productionAuthorization"]);
  if (!Array.isArray(value.limitations) || value.limitations.some((item) => typeof item !== "string" || !item.trim())) {
    throw new CommunicationError("invalid-report", "Limitations must be an explicit array of nonempty strings");
  }
  nonempty(value.narrative, "report narrative");
  let finding: DiagnosticReport["finding"];
  if (condition === "with-skill") {
    if (!isRecord(value.finding)) throw new CommunicationError("invalid-report", "Skilled report requires a separate finding");
    exactKeys(value.finding, ["status", "target", "mechanism"]);
    nullableText(value.finding.target, "finding target");
    nullableText(value.finding.mechanism, "finding mechanism");
    if (value.finding.status === "not-established") {
      if (value.finding.target !== null || value.finding.mechanism !== null) {
        throw new CommunicationError("invalid-report", "An unestablished finding cannot assert diagnostic attribution");
      }
    } else if (value.finding.status !== "ready-for-human-sign-off" ||
        value.finding.target === null || value.finding.mechanism === null) {
      throw new CommunicationError("invalid-report", "Finding requires an explicit status and supported diagnostic fields");
    }
    finding = {
      status: value.finding.status === "not-established" ? "not-established" : "ready-for-human-sign-off",
      target: value.finding.target, mechanism: value.finding.mechanism,
    };
  }
  return {
    candidate: {
      target: value.candidate.target, mechanism: value.candidate.mechanism,
      confidence: value.candidate.confidence,
    },
    authority: { simulated: true, productionAuthorization: false },
    limitations: value.limitations as string[],
    narrative: value.narrative,
    ...(finding ? { finding } : {}),
  };
}

/** Builds only transport instructions; it supplies no evidence-retrieval sequence or diagnostic method. */
export function messageInstruction(context: MessageContext): string {
  return [
    `Communication protocol ${EVALUATION_PROTOCOL}. Return exactly one authoritative JSON envelope as your CLI final answer (phase final_answer), never as commentary. Plain JSON and a json code fence are equivalent. Optional commentary must precede the final answer and contain no machine envelope. Do not emit a second envelope or any message after the final answer.`,
    `Copy these identity fields exactly: ${JSON.stringify({ protocol: EVALUATION_PROTOCOL, messageId: context.messageId, caseId: context.caseId })}.`,
    `For evidence use messageType "evidence_request" and approvalRequests, with no report. For completion use messageType "final" and report, with no approvalRequests. For an evidence blocker use messageType "blocked", a nonempty reason, and report with candidate.target null.`,
    `An evidence_request is the complete final answer for this invocation, not the end of the investigation. End the invocation immediately after returning it. The host cannot execute evidence calls until this CLI process returns. It will validate and simulate approval, execute the exact calls, and resume this session with their results. Do not wait, emit a blocked report, or conclude that requested evidence is unavailable merely because results have not arrived in this invocation.`,
    `The report has exactly: candidate {target: canonical identifier or null for abstention, mechanism: string or null, confidence: nonempty string including reason}, authority {simulated:true, productionAuthorization:false}, limitations: string[], narrative: your complete human-readable answer${context.condition === "with-skill" ? ', finding {status:"not-established" or "ready-for-human-sign-off", target:canonical identifier or null, mechanism:string or null}; an unestablished finding must use null for target and mechanism. Keep all activated-skill sections in narrative' : ""}.`,
    ...(context.condition === "with-skill" ? [
      `Both final and blocked reports MUST include structured report.finding; the narrative alone does not supply it. For blocked use finding {"status":"not-established","target":null,"mechanism":null}. Do not produce the skill's completion sections while handing off an evidence_request; return those sections inside report.narrative only when the investigation ends with final or blocked.`,
    ] : [
      "Both final and blocked reports MUST omit report.finding; it is a skilled-only field.",
    ]),
    `Each model message is bounded to ${COMMUNICATION_LIMITS.messageBytes} UTF-8 bytes. Missing or ambiguous envelopes, missing diagnostic fields and contradictory authority fail explicitly; prose is not an implicit final answer.`,
  ].join("\n");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function exactKeys(value: Record<string, unknown>, keys: readonly string[]): void {
  if (Object.keys(value).length !== keys.length || keys.some((key) => !Object.hasOwn(value, key))) {
    throw new CommunicationError("invalid-fields", `Expected exactly these fields: ${keys.join(", ")}`);
  }
}

function nonempty(value: unknown, label: string): asserts value is string {
  if (typeof value !== "string" || !value.trim()) throw new CommunicationError("invalid-report", `Missing ${label}`);
}

function nullableText(value: unknown, label: string): asserts value is string | null {
  if (value !== null) nonempty(value, label);
}
