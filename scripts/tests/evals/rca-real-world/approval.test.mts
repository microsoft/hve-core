// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";

import {
  FixtureApprovalLedger,
  parseApprovalRequest,
  type ApprovalRequestItem,
} from "../../../evals/rca-real-world/approval.mts";

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
