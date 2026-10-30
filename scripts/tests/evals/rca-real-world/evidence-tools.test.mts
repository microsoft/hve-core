// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import {
  FixtureApprovalLedger,
  type ApprovalRequestItem,
} from "../../../evals/rca-real-world/approval.mts";
import {
  createEvidenceTools,
  type EvidenceToolResult,
} from "../../../evals/rca-real-world/evidence-tools.mts";

const NOW = "2026-10-19T20:00:00.000Z";

function approval(
  tool: string,
  operation: string,
  parameters: Readonly<Record<string, unknown>>,
): ApprovalRequestItem {
  return {
    tool,
    operation,
    parameters,
    evidenceSought: "Bounded test evidence",
    target: "case-01",
    scope: "Current neutral case only",
    maximumCallCount: 1,
    expectedRisk: "Read-only fixture evidence",
    expiresAt: "2026-10-19T20:10:00.000Z",
  };
}

async function caseRoot(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "rca-tools-"));
  await writeFile(
    join(root, "incident.json"),
    '{"caseId":"case-01","incidentOnset":"1700000000"}',
    "utf8",
  );
  await writeFile(
    join(root, "source-coverage.json"),
    '{"sources":[{"modality":"metrics","rowCount":2}]}',
    "utf8",
  );
  await writeFile(join(root, "metric-columns.json"), "{}\n", "utf8");
  await writeFile(
    join(root, "metrics.jsonl"),
    [
      '{"timestamp":1,"service":"checkoutservice","metric":"latency","value":10}',
      '{"timestamp":2,"service":"checkoutservice","metric":"latency","value":20}',
    ].join("\n") + "\n",
    "utf8",
  );
  await writeFile(
    join(root, "logs.jsonl"),
    [
      '{"timestamp":1,"service":"checkoutservice","message":"started"}',
      '{"timestamp":2,"service":"checkoutservice","message":"deadline exceeded"}',
    ].join("\n") + "\n",
    "utf8",
  );
  await writeFile(
    join(root, "traces.jsonl"),
    [
      '{"timestamp":1,"service":"checkoutservice","status":"ok","duration_ms":10}',
      '{"timestamp":2,"service":"checkoutservice","status":"error","duration_ms":200}',
    ].join("\n") + "\n",
    "utf8",
  );
  return root;
}

test("blocks tool execution before exact approval", async () => {
  const root = await caseRoot();
  const ledger = new FixtureApprovalLedger(
    [approval("read_incident_scope", "read", {})],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const metrics = harness.tools.find((tool) => tool.name === "aggregate_metrics");
  await assert.rejects(metrics!.handler({}), /No exact simulated approval/);
  assert.equal(harness.traces[0]?.status, "blocked");
});

test("returns timestamp units without prescribing observation windows", async () => {
  const root = await caseRoot();
  const ledger = new FixtureApprovalLedger(
    [approval("read_incident_scope", "read", {})],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const scope = harness.tools.find((tool) => tool.name === "read_incident_scope");
  const result = JSON.parse(await scope!.handler({})) as {
    data: {
      timeUnits: { metricsAndLogs: string; traces: string };
      queryGuidance?: unknown;
    };
  };
  assert.deepEqual(result.data.timeUnits, {
    metricsAndLogs: "epoch seconds", traces: "epoch milliseconds",
  });
  assert.equal(result.data.queryGuidance, undefined);
});

test("rejects an approved evidence call without a bounded time window", async () => {
  const root = await caseRoot();
  const ledger = new FixtureApprovalLedger(
    [approval("aggregate_metrics", "aggregate", {})],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const metrics = harness.tools.find((tool) => tool.name === "aggregate_metrics");
  await assert.rejects(metrics!.handler({}), /Invalid time value/);
  assert.equal(harness.traces[0]?.status, "error");
});

test("returns metric aggregates and explicit source metadata", async () => {
  const root = await caseRoot();
  const parameters = {
    startTime: 1,
    endTime: 3,
    service: "checkoutservice",
    metric: "latency",
  };
  const ledger = new FixtureApprovalLedger(
    [approval("aggregate_metrics", "aggregate", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "aggregate_metrics");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    rowCount: number;
    matchedRowCount: number;
    truncated: boolean;
    sourceComplete: boolean;
    data: { aggregates: readonly { average: number }[] };
  };
  assert.equal(result.rowCount, 2);
  assert.equal(result.matchedRowCount, 2);
  assert.equal(result.truncated, false);
  assert.equal(result.sourceComplete, true);
  assert.equal(result.data.aggregates[0]?.average, 15);
  assert.equal(harness.traces[0]?.status, "executed");
  assert.match(harness.traces[0]?.resultHash ?? "", /^[0-9a-f]{64}$/);
});

test("aggregates the RCAEval wide metric schema by field name and unit", async () => {
  const root = await caseRoot();
  await writeFile(join(root, "metric-columns.json"), JSON.stringify({
    adservice_cpu: { service: "adservice", metric: "cpu" },
    checkoutservice_cpu: { service: "checkoutservice", metric: "cpu" },
  }), "utf8");
  await writeFile(
    join(root, "metrics.jsonl"),
    [
      '{"time":"1","adservice_cpu":90,"checkoutservice_cpu":10}',
      '{"time":"2","adservice_cpu":100,"checkoutservice_cpu":20}',
    ].join("\n") + "\n",
    "utf8",
  );
  const parameters = {
    startTime: 1,
    endTime: 3,
    service: "adservice",
    metric: "cpu",
  };
  const ledger = new FixtureApprovalLedger(
    [approval("aggregate_metrics", "aggregate", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "aggregate_metrics");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    data: { aggregates: readonly { field: string; average: number; unit: string }[] };
  };
  assert.deepEqual(result.data.aggregates, [
    { average: 95, count: 2, field: "adservice_cpu", maximum: 100, minimum: 90, unit: "percent" },
  ]);
});

/** Executes one exactly approved metric fixture query without model access. */
async function metricQuery(
  root: string,
  parameters: Readonly<Record<string, unknown>>,
  comparison = false,
): Promise<EvidenceToolResult & {
  data: {
    aggregates?: readonly { field: string; count: number; average: number }[];
    comparisons?: readonly { field: string }[];
    baselineRowCount?: number;
    postOnsetRowCount?: number;
  };
}> {
  const name = comparison ? "compare_metrics" : "aggregate_metrics";
  const ledger = new FixtureApprovalLedger(
    [approval(name, comparison ? "compare" : "aggregate", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === name);
  assert.ok(tool);
  return JSON.parse(await tool.handler({ ...parameters }));
}

test("matches mapped identities exactly without inferring them from column names", async (context) => {
  const root = await caseRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "metric-columns.json"), JSON.stringify({
    cpu_user_db: { service: "user", metric: "cpu" },
    a: { service: "user-db", metric: "cpu" },
    b: { service: "user", metric: "cpu_time" },
  }), "utf8");
  await writeFile(join(root, "metrics.jsonl"), JSON.stringify({
    time: 1, cpu_user_db: 10, a: 900, b: 800,
  }) + "\n", "utf8");
  const result = await metricQuery(root, {
    startTime: 0, endTime: 2, service: " USER ", metric: " CPU ",
  });
  assert.equal(result.matchedRowCount, 1);
  assert.deepEqual(result.data.aggregates?.map(({ field, average }) => ({ field, average })), [
    { field: "cpu_user_db", average: 10 },
  ]);
  const timeMetric = await metricQuery(root, {
    startTime: 0, endTime: 2, service: "user", metric: "cpu_time",
  });
  assert.equal(timeMetric.data.aggregates?.[0]?.field, "b");
  const serviceOnly = await metricQuery(root, { startTime: 0, endTime: 2, service: "user-db" });
  assert.equal(serviceOnly.data.aggregates?.[0]?.field, "a");
});

test("reports no matching rows when no mapped column matches, including comparisons", async (context) => {
  const root = await caseRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "metric-columns.json"), JSON.stringify({
    user_cpu: { service: "user", metric: "cpu" },
  }), "utf8");
  await writeFile(join(root, "metrics.jsonl"),
    '{"time":1,"user_cpu":10}\n{"time":3,"user_cpu":20}\n', "utf8");
  const aggregate = await metricQuery(root, {
    startTime: 0, endTime: 4, metric: "cp",
  });
  assert.equal(aggregate.rowCount, 2);
  assert.equal(aggregate.matchedRowCount, 0);
  assert.equal(aggregate.empty, true);
  assert.deepEqual(aggregate.data.aggregates, []);
  const comparison = await metricQuery(root, {
    baselineStartTime: 0, baselineEndTime: 2,
    postStartTime: 2, postEndTime: 4, service: "use",
  }, true);
  assert.equal(comparison.matchedRowCount, 0);
  assert.equal(comparison.empty, true);
  assert.equal(comparison.data.baselineRowCount, 0);
  assert.equal(comparison.data.postOnsetRowCount, 0);
  assert.deepEqual(comparison.data.comparisons, []);
});

test("filters mixed narrow and wide rows independently and excludes missing requested identities", async (context) => {
  const root = await caseRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "metric-columns.json"), JSON.stringify({
    user_cpu: { service: "user", metric: "cpu" },
  }), "utf8");
  await writeFile(join(root, "metrics.jsonl"), [
    { time: 1, user_cpu: 10 },
    { time: 2, service: "user", metric: "cpu", value: 20 },
    { time: 3, service: "user-db", metric: "cpu", value: 900 },
    { time: 4, metric: "cpu", value: 800 },
    { time: 5, service: "user", value: 700 },
    { time: 6, service: "user", metric: "cpu_time", value: 600 },
  ].map((row) => JSON.stringify(row)).join("\n") + "\n", "utf8");
  const result = await metricQuery(root, {
    startTime: 0, endTime: 7, service: "user", metric: "cpu",
  });
  assert.equal(result.matchedRowCount, 2);
  assert.deepEqual(result.data.aggregates?.map(({ field, average }) => ({ field, average })), [
    { field: "user_cpu", average: 10 },
    { field: "value", average: 20 },
  ]);
});

test("fails closed on absent, malformed, or incomplete metric mappings", async (context) => {
  const root = await caseRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  const parameters = { startTime: 0, endTime: 2 };
  await rm(join(root, "metric-columns.json"));
  await assert.rejects(metricQuery(root, parameters), /ENOENT/);
  await writeFile(join(root, "metric-columns.json"), '{"user_cpu":{}}', "utf8");
  await assert.rejects(metricQuery(root, parameters), /Invalid metric column identity/);
  await writeFile(join(root, "metric-columns.json"), "{}", "utf8");
  await writeFile(join(root, "metrics.jsonl"), '{"time":1,"user_cpu":10}\n', "utf8");
  await assert.rejects(metricQuery(root, parameters), /Missing metric column identity/);
  await assert.rejects(metricQuery(root, { ...parameters, metric: "" }), /non-empty string/);
});

test("ranks compact baseline-to-post metric changes", async () => {
  const root = await caseRoot();
  await writeFile(join(root, "metric-columns.json"), JSON.stringify({
    adservice_cpu: { service: "adservice", metric: "cpu" },
    cartservice_cpu: { service: "cartservice", metric: "cpu" },
  }), "utf8");
  await writeFile(
    join(root, "metrics.jsonl"),
    [
      '{"time":"1","adservice_cpu":10,"cartservice_cpu":20}',
      '{"time":"1.2","adservice_cpu":10,"cartservice_cpu":20}',
      '{"time":"2","adservice_cpu":80,"cartservice_cpu":22}',
      '{"time":"2.2","adservice_cpu":100,"cartservice_cpu":18}',
    ].join("\n") + "\n",
    "utf8",
  );
  const parameters = {
    baselineStartTime: 1,
    baselineEndTime: 1.5,
    postStartTime: 2,
    postEndTime: 2.5,
    limit: 2,
  };
  const ledger = new FixtureApprovalLedger(
    [approval("compare_metrics", "compare", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "compare_metrics");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    data: {
      comparisons: readonly {
        field: string;
        baselineAverage: number;
        postOnsetAverage: number;
      }[];
    };
  };
  assert.deepEqual(result.data.comparisons[0], {
    absoluteChange: 80,
    baselineAverage: 10,
    baselineCount: 2,
    field: "adservice_cpu",
    postOnsetAverage: 90,
    postOnsetCount: 2,
    relativeChange: 8,
    unit: "percent",
  });
});

test("searches escaped log literals with fixed limits", async () => {
  const root = await caseRoot();
  const parameters = {
    literal: "deadline exceeded",
    startTime: 1,
    endTime: 3,
    limit: 1,
  };
  const ledger = new FixtureApprovalLedger(
    [approval("search_logs", "search", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "search_logs");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    matchedRowCount: number;
    data: { rows: readonly { message: string }[] };
  };
  assert.equal(result.matchedRowCount, 1);
  assert.equal(result.data.rows[0]?.message, "deadline exceeded");
});

test("summarizes traces by bounded status and duration", async () => {
  const root = await caseRoot();
  const parameters = {
    startTime: 1,
    endTime: 3,
    status: "error",
    minimumDuration: 100,
    limit: 10,
  };
  const ledger = new FixtureApprovalLedger(
    [approval("summarize_traces", "summarize", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "summarize_traces");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    matchedRowCount: number;
    data: { groups: readonly { status: string; count: number }[] };
  };
  assert.equal(result.matchedRowCount, 1);
  assert.deepEqual(result.data.groups, [
    { service: "checkoutservice", status: "error", count: 1 },
  ]);
});

test("supports RCAEval trace field names and numeric strings", async () => {
  const root = await caseRoot();
  await writeFile(
    join(root, "traces.jsonl"),
    '{"startTimeMillis":"1705665791001","serviceName":"checkoutservice","statusCode":"2","duration":"200"}\n',
    "utf8",
  );
  const parameters = {
    startTime: 1705665791000,
    endTime: 1705665791002,
    service: "checkoutservice",
    status: "2",
    minimumDuration: 100,
    limit: 10,
  };
  const ledger = new FixtureApprovalLedger(
    [approval("summarize_traces", "summarize", parameters)],
    () => new Date(NOW),
  );
  const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const tool = harness.tools.find((candidate) => candidate.name === "summarize_traces");
  const result = JSON.parse(await tool!.handler(parameters)) as {
    matchedRowCount: number;
    data: { groups: readonly { service: string; status: string; count: number }[] };
  };
  assert.equal(result.matchedRowCount, 1);
  assert.deepEqual(result.data.groups, [
    { service: "checkoutservice", status: "2", count: 1 },
  ]);
});
