// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";
import { PassThrough } from "node:stream";
import { boundedCliJsonOutput, boundedCliOutput, parseCliEvents, parseCliResponse, parseCliTurn } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import { parseApprovalRequest } from "../../../evals/rca-real-world/approval.mts";
import { EVALUATION_PROTOCOL, SKILLED_REPORT_HEADINGS, sha256 } from "../../../evals/rca-real-world/contracts.mts";
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

for (const condition of ["with-skill", "without-skill"] as const) {
  test(`accepts more than 1 MiB of streaming wrappers with small useful text: ${condition}`, () => {
    const stream = new PassThrough();
    let stops = 0;
    const capture = boundedCliJsonOutput(stream, () => { stops++; });
    const delta = JSON.stringify({
      type: "assistant.message_delta", id: "x".repeat(300),
      data: { messageId: "response-1", deltaContent: "abcde" },
    }) + "\n";
    for (let index = 0; index < 3249; index++) stream.write(delta);
    const { finding, ...baselineReport } = report;
    const message = JSON.stringify({
      ...identity, messageType: "final", report: condition === "with-skill" ? report : baselineReport,
    });
    const event = JSON.stringify({ type: "assistant.message", data: { phase: "final_answer", content: message } });
    stream.end(event);
    capture.finish();
    assert.ok(Buffer.byteLength(capture.text, "utf8") > 1024 * 1024);
    assert.ok(Buffer.byteLength(capture.text, "utf8") < COMMUNICATION_LIMITS.stdoutBytes);
    assert.equal(capture.exceeded, false);
    assert.equal(capture.protocolError, undefined);
    assert.equal(stops, 0);
    assert.equal(parseCliResponse(parseCliEvents(capture.text), { ...context, condition }).message.messageType, "final");
  });
}

test("streaming text limits count UTF-8 bytes per message, not total commentary or wrapper bytes", () => {
  const stream = new PassThrough();
  let stops = 0;
  const capture = boundedCliJsonOutput(stream, () => { stops++; });
  const delta = (messageId: string, deltaContent: string) => JSON.stringify({
    type: "assistant.message_delta", data: { messageId, deltaContent },
  }) + "\r\n";
  const atLimit = "\u03bb".repeat(COMMUNICATION_LIMITS.messageBytes / 2);
  const encoded = Buffer.from(delta("first", atLimit));
  const unicodeStart = encoded.indexOf(Buffer.from("\u03bb"));
  stream.write(encoded.subarray(0, unicodeStart + 1));
  stream.write(encoded.subarray(unicodeStart + 1));
  stream.write(delta("second", atLimit));
  assert.equal(Boolean(capture.protocolError), false);
  stream.write(delta("second", "x"));
  stream.write(delta("second", "ignored"));
  assert.equal(capture.protocolError?.code, "message-too-large");
  assert.equal(capture.exceeded, false);
  assert.equal(stops, 1);
  assert.throws(() => parseCliResponse(parseCliEvents(capture.text), context), /byte limit/);
  stream.end();
  capture.finish();
  assert.equal(stops, 1);
});

for (const newline of ["\n", ""]) {
  test(`rejects oversized complete public messages independently of deltas (${newline ? "newline" : "EOF"})`, () => {
    const stream = new PassThrough();
    let stops = 0;
    const capture = boundedCliJsonOutput(stream, () => { stops++; });
    stream.end(JSON.stringify({
      type: "assistant.message",
      data: { phase: "final_answer", content: "x".repeat(COMMUNICATION_LIMITS.messageBytes + 1) },
    }) + newline);
    capture.finish();
    assert.equal(capture.protocolError?.code, "message-too-large");
    assert.equal(stops, 1);
  });
}

test("retains a bounded incomplete audit when raw JSONL exceeds 10 MiB without a complete event", () => {
  const stream = new PassThrough();
  let stops = 0;
  const capture = boundedCliJsonOutput(stream, () => { stops++; });
  const atLimit = "x".repeat(COMMUNICATION_LIMITS.stdoutBytes);
  stream.write(atLimit);
  assert.equal(capture.exceeded, false);
  stream.write("x");
  stream.end("ignored after overflow");
  capture.finish();
  assert.equal(capture.exceeded, true);
  assert.equal(capture.text, atLimit);
  assert.equal(stops, 1);
  assert.equal(capture.protocolError, undefined);
});

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

for (const messageType of ["evidence_request", "final", "blocked"] as const) {
  for (const defect of ["syntax", "fields"] as const) {
    test(`classifies one ${messageType} ${defect} rejection without accepting its envelope`, () => {
      const envelope = messageType === "evidence_request"
        ? { ...identity, messageType, approvalRequests: [request] }
        : { ...identity, messageType, report, ...(messageType === "blocked" ? { reason: "Source unavailable." } : {}) };
      const text = defect === "syntax"
        ? `${JSON.stringify(envelope)}]}`
        : JSON.stringify({ ...envelope, unexpected: true });
      assert.throws(() => parseCliResponse([cliMessage(text, "final_answer")], context));
      const parsed = parseCliTurn([cliMessage(text, "final_answer")], context);
      assert.deepEqual(parsed.message, {
        messageType: "format_error", intendedMessageType: messageType,
        errorCode: defect === "syntax" ? "invalid-json" : "invalid-fields",
        errorMessage: defect === "syntax" ? "Machine message contains malformed JSON"
          : `Expected exactly these fields: protocol, messageId, caseId, messageType, ${
            messageType === "evidence_request" ? "approvalRequests" : messageType === "blocked" ? "report, reason" : "report"
          }`,
      });
      assert.deepEqual(parsed.messages, [text]);
      assert.equal(parsed.messageHash, sha256(text));
    });
  }
}

test("format recovery does not reinterpret ambiguous intent, multiple public messages, identity, phase, or authority errors", () => {
  const malformed = `${approval}]}`;
  assert.throws(() => parseCliTurn([
    cliMessage("Collecting evidence.", "commentary"), cliMessage(malformed, "final_answer"),
  ], context), { code: "invalid-json" });
  assert.throws(() => parseCliTurn([cliMessage(malformed, "commentary")], context), { code: "invalid-json" });
  for (const otherType of ['"final"', '"unknown"', "null", "0"]) {
    const ambiguous = approval.replace(
      '"messageType":"evidence_request"', `"messageType":${otherType},"messageType":"evidence_request"`,
    ) + "]}";
    assert.throws(() => parseCliTurn([cliMessage(ambiguous, "final_answer")], context), { code: "invalid-json" });
  }
  const stale = JSON.stringify({ ...identity, messageId: "stale", messageType: "final", report, unexpected: true });
  assert.throws(() => parseCliTurn([cliMessage(stale, "final_answer")], context), { code: "context-mismatch" });
  const unauthorized = JSON.stringify({
    ...identity, messageType: "final", report: { ...report, authority: { simulated: false, productionAuthorization: true } },
  });
  assert.throws(() => parseCliTurn([cliMessage(unauthorized, "final_answer")], context), { code: "invalid-authority" });
});

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
  for (const heading of SKILLED_REPORT_HEADINGS) assert.ok(!baseline.includes(heading));
  assert.doesNotMatch(baseline, /Set A|Set B|eight numbered narrative headings/);
});

for (const condition of ["with-skill", "without-skill"] as const) {
  for (const messageId of [context.messageId, 'invocation "quoted"\\path\nnext-line']) {
    test(`published JSON examples pass production parsers: ${condition}, ${JSON.stringify(messageId)}`, () => {
      const exampleContext = { ...context, condition, messageId };
      const guidance = messageInstruction(exampleContext);
      const examples = [...guidance.matchAll(/```json\n([\s\S]*?)\n```/g)].map((match) => match[1]!);
      assert.equal(examples.length, 3);
      assert.deepEqual(examples.map((text) => JSON.parse(text).messageType), ["evidence_request", "final", "blocked"]);
      for (const text of examples) {
        const value = JSON.parse(text);
        assert.equal(value.messageId, messageId);
        assert.equal(value.caseId, context.caseId);
        assert.equal(value.protocol, EVALUATION_PROTOCOL);
        for (const answer of [text, `\`\`\`json\n${text}\n\`\`\``]) {
          const parsed = parseModelMessages([answer], exampleContext).message;
          const cliParsed = parseCliResponse([cliMessage(answer, "final_answer")], exampleContext).message;
          assert.deepEqual(cliParsed, parsed);
          if (parsed.messageType === "evidence_request") {
            assert.equal(parsed.approvalRequests.length, 1);
            assert.equal(parsed.approvalRequests[0]!.maximumCallCount, 1);
            assert.equal(parsed.approvalRequests[0]!.target, context.caseId);
            assert.equal(parsed.approvalRequests[0]!.scope, "current neutral case only");
            assert.equal(parsed.approvalRequests[0]!.expectedRisk, "read-only bounded fixture evidence");
          } else {
            assert.equal(Object.hasOwn(parsed.report, "finding"), condition === "with-skill");
            if (condition === "with-skill") {
              const narrative = parsed.report.narrative;
              const headings = [...narrative.matchAll(/^### (.+)$/gm)].map((match) => match[1]);
              assert.deepEqual(headings, SKILLED_REPORT_HEADINGS);
              assert.ok(narrative.indexOf("Set A - Evidence-supported finding") >
                narrative.indexOf(SKILLED_REPORT_HEADINGS[0]));
              assert.ok(narrative.indexOf("Set B - Leading unverified hypothesis") >
                narrative.indexOf("Set A - Evidence-supported finding"));
              assert.ok(narrative.indexOf("Set B - Leading unverified hypothesis") <
                narrative.indexOf(SKILLED_REPORT_HEADINGS[1]));
            } else {
              for (const heading of SKILLED_REPORT_HEADINGS) assert.ok(!parsed.report.narrative.includes(heading));
            }
            if (parsed.messageType === "blocked") {
              assert.equal(parsed.report.candidate.target, null);
              assert.ok(parsed.reason);
            }
          }
        }
        const malformed = `${text}}`;
        for (const parse of [
          () => parseModelMessages([malformed], exampleContext),
          () => parseCliResponse([cliMessage(malformed, "final_answer")], exampleContext),
        ]) {
          assert.throws(parse, (error: unknown) =>
            error instanceof Error && "code" in error && error.code === "invalid-json");
        }
      }
    });
  }
}
