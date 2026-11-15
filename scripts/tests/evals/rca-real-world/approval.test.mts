// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";

import {
  FixtureApprovalLedger,
  approvalTimingInstruction,
  parseApprovalRequest,
  redactApprovalParameters,
  type ApprovalRequestItem,
} from "../../../evals/rca-real-world/approval.mts";
import { FileApprovalConsumer } from "../../../evals/rca-real-world/mcp-server.mts";

const now = new Date("2026-10-19T20:00:00.000Z");

function request(overrides: Partial<ApprovalRequestItem> = {}): ApprovalRequestItem {
  return {
    tool: "read_incident_scope",
    operation: "read",
    parameters: {},
    evidenceSought: "Incident scope and source coverage",
    target: "case-01",
    scope: "Current neutral case only",
    maximumCallCount: 1,
    expectedRisk: "Read-only fixture evidence",
    expiresAt: "2026-10-19T20:10:00.000Z",
    ...overrides,
  };
}

test("parses exactly one enumerated approval request", () => {
  const parsed = parseApprovalRequest(
    `Request:\n\`\`\`json\n${JSON.stringify({ approvalRequests: [request()] })}\n\`\`\``,
  );
  assert.equal(parsed.approvalRequests.length, 1);
});

test("allows an explicit blocked stop only after initial scope collection", () => {
  const response = (value: unknown): string => `\`\`\`json\n${JSON.stringify(value)}\n\`\`\``;
  const stop = response({ approvalRequests: [], stopReason: "Required query windows are unavailable." });
  assert.throws(() => parseApprovalRequest(stop), /blocked stop requires/);
  assert.equal(parseApprovalRequest(stop, true).stopReason, "Required query windows are unavailable.");
  assert.throws(() => parseApprovalRequest(response({ approvalRequests: [] }), true), /1-12 calls/);
  for (const stopReason of ["", " ", null, 1, "x".repeat(2_001)]) {
    assert.throws(() => parseApprovalRequest(response({ approvalRequests: [], stopReason }), true), /blocked stop requires/);
  }
  assert.throws(() => parseApprovalRequest(response({
    approvalRequests: [request()], stopReason: "Stopped",
  }), true), /blocked stop requires/);
  assert.throws(() => parseApprovalRequest(response({
    approvalRequests: Array.from({ length: 13 }, () => request()),
  }), true), /1-12 calls/);
});

test("rejects tool-class, effectful, and overlong approvals", () => {
  assert.throws(
    () => new FixtureApprovalLedger([request({ tool: "shell" })], () => now),
    /broad or effectful/,
  );
  assert.throws(
    () => new FixtureApprovalLedger([request({ operation: "write" })], () => now),
    /broad or effectful/,
  );
  assert.throws(
    () => new FixtureApprovalLedger([request({ maximumCallCount: 4 })], () => now),
    /invalid call count/,
  );
});

test("requires exact parameters and consumes approved calls", () => {
  const ledger = new FixtureApprovalLedger(
    [request({ parameters: { service: "checkoutservice" } })],
    () => now,
  );
  assert.throws(
    () => ledger.consume("read_incident_scope", "read", { service: "cartservice" }),
    /No exact simulated approval/,
  );
  assert.match(
    ledger.consume("read_incident_scope", "read", { service: "checkoutservice" }),
    /^fixture-001-/,
  );
  assert.throws(
    () => ledger.consume("read_incident_scope", "read", { service: "checkoutservice" }),
    /No exact simulated approval/,
  );
  assert.equal(ledger.artifact().establishesProductionAuthorization, false);
  assert.equal(ledger.artifact().records[0]?.simulated, true);
  assert.equal(ledger.artifact().records[0]?.status, "Consumed");
});

test("rejects expired approvals", () => {
  let current = now;
  const ledger = new FixtureApprovalLedger([request()], () => current);
  current = new Date("2026-10-19T20:11:00.000Z");
  assert.throws(() => ledger.consume("read_incident_scope", "read", {}), /expired/i);
});

test("provides an exact host-clock expiry and still rejects model-extended deadlines", () => {
  const guidance = approvalTimingInstruction(now);
  assert.match(guidance, /Current host UTC time: 2026-10-19T20:00:00.000Z/);
  assert.match(guidance, /Use exactly "2026-10-19T20:15:00.000Z"/);
  assert.throws(() => new FixtureApprovalLedger([
    request({ expiresAt: "2026-10-19T21:15:00.000Z" }),
  ], () => now), /invalid expiry/);
});

test("redacts nested secret-shaped keys without changing the input parameter tree", () => {
  const parameters = {
    authorization: "fixture-auth",
    filter: {
      service: "checkoutservice",
      password: "fixture-password",
      items: [{ token: "fixture-token", limit: 3 }, [{ secret: "fixture-secret" }], null],
    },
  };
  assert.deepEqual(redactApprovalParameters(parameters), {
    authorization: "[REDACTED]",
    filter: {
      service: "checkoutservice",
      password: "[REDACTED]",
      items: [{ token: "[REDACTED]", limit: 3 }, [{ secret: "[REDACTED]" }], null],
    },
  });
  assert.equal(parameters.filter.password, "fixture-password");
});

for (const storage of ["memory", "file"] as const) {
  test(`${storage} approval consumer enforces exact calls and identical count transitions`, () => {
    let current = now;
    const parameters = {
      filters: [{ service: "checkoutservice", credentials: { token: "fixture-token" } }],
    };
    const ledger = new FixtureApprovalLedger([
      request({ parameters, maximumCallCount: 2 }),
    ], () => current);
    const consumer = storage === "memory" ? ledger : new FileApprovalConsumer(ledger.artifact(), () => current);
    const initial = consumer.artifact();
    const approved = initial.records[0]!;
    assert.deepEqual(approved.parameters, redactApprovalParameters(parameters));
    assert.throws(() => consumer.consume("other-tool", "read", parameters), /No exact simulated approval/);
    assert.throws(() => consumer.consume("read_incident_scope", "other-operation", parameters), /No exact simulated approval/);
    assert.throws(
      () => consumer.consume("read_incident_scope", "read", { filters: [{ service: "cartservice" }] }),
      /No exact simulated approval/,
    );
    const changedSecret = structuredClone(parameters);
    changedSecret.filters[0]!.credentials.token = "different-fixture-token";
    assert.throws(
      () => consumer.consume("read_incident_scope", "read", changedSecret),
      /No exact simulated approval/,
    );
    assert.equal(consumer.consume("read_incident_scope", "read", parameters), approved.approvalId);
    assert.equal(consumer.artifact().records[0]?.status, "Approved");
    current = new Date(now.getTime() + 1000);
    consumer.consume("read_incident_scope", "read", parameters);
    const consumed = consumer.artifact().records[0]!;
    assert.equal(consumed.consumedCallCount, 2);
    assert.equal(consumed.status, "Consumed");
    assert.deepEqual(consumed.verificationTimes, [now.toISOString(), current.toISOString()]);
    assert.throws(() => consumer.consume("read_incident_scope", "read", parameters), /No exact simulated approval/);
    assert.equal(approved.consumedCallCount, 0);
    assert.deepEqual(approved.verificationTimes, []);
  });

  test(`${storage} approval consumer expires at the exact deadline without consuming a call`, () => {
    let current = now;
    const ledger = new FixtureApprovalLedger([request()], () => current);
    const consumer = storage === "memory" ? ledger : new FileApprovalConsumer(ledger.artifact(), () => current);
    current = new Date("2026-10-19T20:10:00.000Z");
    assert.throws(() => consumer.consume("read_incident_scope", "read", {}), /expired/i);
    assert.equal(consumer.artifact().records[0]?.status, "Expired");
    assert.equal(consumer.artifact().records[0]?.consumedCallCount, 0);
    assert.deepEqual(consumer.artifact().records[0]?.verificationTimes, []);
  });
}

test("file approval consumer refuses exhausted or rejected persisted records", () => {
  const ledger = new FixtureApprovalLedger([request()], () => now).artifact();
  const exhausted = new FileApprovalConsumer({
    ...ledger,
    records: ledger.records.map((record) => ({ ...record, consumedCallCount: record.maximumCallCount })),
  }, () => now);
  assert.throws(() => exhausted.consume("read_incident_scope", "read", {}), /call count exhausted/);
  const rejected = new FileApprovalConsumer({
    ...ledger,
    records: ledger.records.map((record) => ({ ...record, status: "Rejected" })),
  }, () => now);
  assert.throws(() => rejected.consume("read_incident_scope", "read", {}), /No exact simulated approval/);
});
