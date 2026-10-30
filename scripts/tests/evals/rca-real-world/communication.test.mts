// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";
import { PassThrough } from "node:stream";
import { boundedCliOutput, parseCliEvents, parseCliResponse } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import { parseApprovalRequest } from "../../../evals/rca-real-world/approval.mts";
import { EVALUATION_PROTOCOL } from "../../../evals/rca-real-world/contracts.mts";
import {
  COMMUNICATION_LIMITS, messageInstruction, parseModelMessages, validateDiagnosticReport,
  type DiagnosticReport,
} from "../../../evals/rca-real-world/communication.mts";

const context = { messageId: "run/with-skill/case-01/trial-1/turn-1", caseId: "case-01", condition: "with-skill" as const };
const request = {
  tool: "read_incident_scope", operation: "read", parameters: {},
  evidenceSought: "Source coverage", target: "case-01", scope: "current neutral case only",
  maximumCallCount: 1, expectedRisk: "read-only bounded fixture evidence", expiresAt: "2026-10-29T17:00:00Z",
};
const identity = { protocol: EVALUATION_PROTOCOL, messageId: context.messageId, caseId: context.caseId };
const approval = JSON.stringify({ ...identity, messageType: "evidence_request", approvalRequests: [request] });
const report: DiagnosticReport = {
  candidate: { target: null, mechanism: null, confidence: "None; evidence unavailable." },
  finding: { status: "not-established", target: null, mechanism: null },
  authority: { simulated: true, productionAuthorization: false },
  limitations: ["Evidence unavailable."], narrative: "An answer without diagnostic Markdown fields.",
};

for (const fenced of [false, true]) {
  test(`recognizes ${fenced ? "fenced" : "raw"} requests before closing commentary`, () => {
    const text = fenced ? `\`\`\`json\n${approval}\n\`\`\`` : approval;
    const result = parseModelMessages(["Opening commentary.", text, "Blocked pending evidence."], context);
    assert.equal(result.message.messageType, "evidence_request");
    assert.equal(result.messageIndex, 1);
    assert.equal(result.messageHash.length, 64);
  });
}

test("approval parser accepts raw and fenced envelopes without changing their calls", () => {
  const raw = JSON.stringify({ approvalRequests: [request] });
  assert.deepEqual(parseApprovalRequest(raw), parseApprovalRequest(`\`\`\`json\n${raw}\n\`\`\``));
});

test("does not mistake commentary about protocol field names for another authoritative envelope", () => {
  const parsed = parseModelMessages([
    'I will use "messageType": to identify the request.', approval,
    'The "approvalRequests": field describes the evidence calls above.',
  ], context);
  assert.equal(parsed.messageIndex, 1);
});

test("preserves JSON code fences inside a structured narrative", () => {
  const narrative = 'Example:\n```json\n{"evidence":"untrusted data"}\n```\nDone.';
  const envelope = JSON.stringify({ ...identity, messageType: "final", report: { ...report, narrative } });
  for (const text of [envelope, `\`\`\`json\n${envelope}\n\`\`\``]) {
    const parsed = parseModelMessages([text], context).message;
    assert.ok(parsed.messageType !== "evidence_request");
    assert.equal(parsed.report.narrative, narrative);
  }
});

for (const limit of [COMMUNICATION_LIMITS.stdoutBytes, COMMUNICATION_LIMITS.stderrBytes]) {
  test(`bounds native stream capture at exactly ${limit} UTF-8 bytes`, () => {
    const stream = new PassThrough();
    let stops = 0;
    const capture = boundedCliOutput(stream, limit, () => { stops++; });
    const text = "\u03bb".repeat(limit / 2);
    const bytes = Buffer.from(text);
    stream.write(bytes.subarray(0, 1));
    stream.write(bytes.subarray(1));
    assert.equal(capture.text, text);
    assert.equal(Buffer.byteLength(capture.text, "utf8"), limit);
    assert.equal(capture.exceeded, false);
    stream.write("x");
    stream.write("ignored after failure");
    assert.equal(capture.exceeded, true);
    assert.equal(capture.text, text);
    assert.equal(stops, 1);
    stream.end();
  });
}

test("rejects multiple authoritative messages rather than choosing or merging them", () => {
  const final = JSON.stringify({ ...identity, messageType: "final", report });
  assert.throws(() => parseModelMessages([approval, final], context), /received 2/);
  assert.throws(() => parseModelMessages([approval, approval], context), /received 2/);
});

test("does not mistake prose, missing envelopes or malformed JSON for a successful final answer", () => {
  for (const messages of [[], ["Blocked pending evidence."], ['{"protocol":'], [`\`\`\`json\n{"protocol":\n\`\`\``]]) {
    assert.throws(() => parseModelMessages(messages, context));
  }
});

for (const change of [{ protocol: "ad-hoc-v1" }, { messageId: "wrong-turn" }, { caseId: "case-02" }]) {
  test(`rejects changed message identity: ${Object.keys(change)[0]}`, () => {
    assert.throws(() => parseModelMessages([JSON.stringify({
      ...JSON.parse(approval), ...change,
    })], context), /identity/);
  });
}

test("rejects malformed or broad calls before execution", () => {
  for (const invalid of [null, {}, { ...request, maximumCallCount: 2 }, { ...request, parameters: [] }, { ...request, surprise: true }]) {
    assert.throws(() => parseModelMessages([JSON.stringify({
      ...identity, messageType: "evidence_request", approvalRequests: [invalid],
    })], context));
  }
  assert.throws(() => parseModelMessages([JSON.stringify({
    ...identity, messageType: "evidence_request", approvalRequests: [],
  })], context), /1-12/);
});

test("structured abstention and blocked outcomes do not depend on narrative headings or wording", () => {
  const final = parseModelMessages([JSON.stringify({ ...identity, messageType: "final", report })], context);
  assert.equal(final.message.messageType, "final");
  const blocked = parseModelMessages([JSON.stringify({
    ...identity, messageType: "blocked", reason: "Source inaccessible.", report,
  })], context);
  assert.equal(blocked.message.messageType, "blocked");
  assert.throws(() => parseModelMessages([JSON.stringify({
    ...identity, messageType: "blocked", reason: "Pending", report: {
      ...report, candidate: { ...report.candidate, target: "service-a" },
    },
  })], context), /explicitly abstain/);
});

test("requires explicit diagnostic fields and separate skilled finding authority", () => {
  for (const invalid of [
    { ...report, candidate: {} }, { ...report, finding: undefined },
    { ...report, authority: { simulated: true, productionAuthorization: true } },
    { ...report, finding: { ...report.finding, target: "unverified-service" } },
  ]) assert.throws(() => validateDiagnosticReport(invalid, "with-skill"));
  const { finding, ...baseline } = report;
  assert.deepEqual(validateDiagnosticReport(baseline, "without-skill"), baseline);
  assert.throws(() => validateDiagnosticReport(report, "without-skill"));
});

test("enforces UTF-8 bytes, not character counts, without clipping input", () => {
  const text = JSON.stringify({
    ...identity, messageType: "final",
    report: { ...report, narrative: "\u00e9".repeat(COMMUNICATION_LIMITS.messageBytes / 2) },
  });
  assert.ok(text.length < COMMUNICATION_LIMITS.messageBytes);
  assert.throws(() => parseModelMessages([text], context), /byte limit/);
});

const cliMessage = (content: string, phase: unknown) => ({ type: "assistant.message", data: { content, phase } });

for (const fenced of [false, true]) {
  test(`CLI handoff accepts one ${fenced ? "fenced" : "raw"} final-answer envelope after commentary`, () => {
    const text = fenced ? `\`\`\`json\n${approval}\n\`\`\`` : approval;
    const parsed = parseCliResponse([
      cliMessage("Requesting bounded evidence.", "commentary"), cliMessage(text, "final_answer"),
    ], context);
    assert.equal(parsed.message.messageType, "evidence_request");
    assert.equal(parsed.messageIndex, 1);
    assert.deepEqual(parsed.messages, ["Requesting bounded evidence.", text]);
    assert.equal(parsed.messageHash, parseModelMessages([text], context).messageHash);
  });
}

for (const phase of [undefined, null, "analysis", 1]) {
  test(`CLI handoff rejects missing or unsupported phase ${String(phase)}`, () => {
    assert.throws(() => parseCliResponse([cliMessage(approval, phase)], context), /known CLI phase/);
  });
}

test("CLI handoff rejects a request in commentary even with a plain final answer", () => {
  for (const events of [
    [cliMessage(approval, "commentary")],
    [cliMessage(approval, "commentary"), cliMessage("Waiting for evidence.", "final_answer")],
  ]) assert.throws(() => parseCliResponse(events, context), /final answer, not commentary/);
});

test("CLI handoff rejects commentary after the final answer and multiple final answers", () => {
  assert.throws(() => parseCliResponse([
    cliMessage(approval, "final_answer"), cliMessage("Waiting.", "commentary"),
  ], context), /cannot follow/);
  assert.throws(() => parseCliResponse([
    cliMessage("Preceding final.", "final_answer"), cliMessage(approval, "final_answer"),
  ], context), /exactly one CLI final answer/);
});

test("replays commentary request followed by a malformed blocked final without selecting or repairing either", () => {
  const { finding, ...missingFinding } = report;
  const blocker = JSON.stringify({
    ...identity, messageType: "blocked", reason: "Requested evidence has not returned.", report: missingFinding,
  });
  const capture = [
    { type: "assistant.turn_start", data: {} },
    { type: "assistant.message", data: { content: "", toolRequests: [{ name: "skill" }], phase: "commentary" } },
    { type: "tool.execution_complete", data: { success: true } },
    cliMessage(approval, "commentary"),
    cliMessage(blocker, "final_answer"),
    { type: "assistant.turn_end", data: {} },
    { type: "result", data: {} },
  ].map((event) => JSON.stringify(event)).join("\n");
  assert.throws(() => parseCliResponse(parseCliEvents(capture), context), /received 2/);
  assert.throws(() => parseCliResponse([cliMessage(blocker, "final_answer")], context), /finding/);
  const corrected = JSON.stringify({
    ...identity, messageType: "blocked", reason: "Source inaccessible.", report,
  });
  assert.equal(parseCliResponse([cliMessage(corrected, "final_answer")], context).message.messageType, "blocked");
  assert.throws(() => parseCliResponse([
    cliMessage(approval, "commentary"), cliMessage(corrected, "final_answer"),
  ], context), /received 2/);
});

test("transport instructions distinguish a request handoff from final and blocked reports", () => {
  const skilled = messageInstruction(context);
  assert.match(skilled, /phase final_answer/);
  assert.match(skilled, /never as commentary/);
  assert.match(skilled, /End the invocation immediately/);
  assert.match(skilled, /host cannot execute evidence calls until this CLI process returns/);
  assert.match(skilled, /Both final and blocked reports MUST include structured report.finding/);
  assert.match(skilled, /Do not produce the skill's completion sections while handing off/);
  const baseline = messageInstruction({ ...context, condition: "without-skill" });
  assert.match(baseline, /Both final and blocked reports MUST omit report.finding/);
  assert.doesNotMatch(baseline, /Keep all activated-skill sections/);
});
