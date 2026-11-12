// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { after, test } from "node:test";

import {
  FixtureApprovalLedger,
  type ApprovalRequestItem,
} from "../../../evals/rca-real-world/approval.mts";
import {
  createEvidenceTools,
  EvidenceRequestError,
  EvidenceWindowLimitError,
  evidenceRequestError,
  validateEvidenceParameters,
  type EvidenceToolResult,
} from "../../../evals/rca-real-world/evidence-tools.mts";
import { sha256, stableJson } from "../../../evals/rca-real-world/contracts.mts";
import { COMMUNICATION_LIMITS } from "../../../evals/rca-real-world/communication.mts";

const NOW = "2026-10-19T20:00:00.000Z";
const roots: string[] = [];
after(async () => {
  await Promise.all(roots.map((root) => rm(root, { recursive: true, force: true })));
});

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
  await mkdir("logs", { recursive: true });
  const root = await mkdtemp(join("logs", "rca-tools-"));
  roots.push(root);
  await writeFile(
    join(root, "incident.json"),
    '{"caseId":"case-01","incidentOnset":"1700000000"}',
    "utf8",
  );
  await writeFile(
    join(root, "source-coverage.json"),
    '{"sources":[{"modality":"metrics","rowCount":2},{"modality":"logs","rowCount":2},{"modality":"traces","rowCount":2}]}',
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
  await assert.rejects(metrics!.handler({}), EvidenceRequestError);
  assert.equal(harness.traces[0]?.status, "query-error");
  assert.equal(harness.traces[0]?.errorCode, "invalid-tool-parameters");
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

test("advertises and enforces exact second and millisecond window boundaries", async () => {
  const root = await caseRoot();
  for (const [tool, operation, startTime, maximumSpan] of [
    ["aggregate_metrics", "aggregate", 1700000000, 3600],
    ["search_logs", "search", 1700000000, 3600],
    ["summarize_traces", "summarize", 1700000000000, 3600000],
  ] as const) {
    const boundary = { startTime, endTime: startTime + maximumSpan };
    const overlong = { startTime, endTime: startTime + maximumSpan + 1 };
    const ledger = new FixtureApprovalLedger([
      approval(tool, operation, boundary), approval(tool, operation, overlong),
    ], () => new Date(NOW));
    const harness = createEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
    const definition = harness.tools.find((item) => item.name === tool)!;
    assert.match(definition.description, /3600 seconds \(3600000 milliseconds\)/);
    assert.match(stableJson(definition.parameters), /3600 seconds \(3600000 milliseconds\)/);
    await definition.handler(boundary);
    assert.equal(harness.traces[0]?.status, "executed");
    await assert.rejects(definition.handler(overlong), EvidenceWindowLimitError);
    assert.equal(harness.traces[1]?.status, "query-error");
    assert.equal(harness.traces[1]?.errorCode, "time-window-too-large");
    assert.equal(harness.traces[1]?.resultHash, undefined);
    assert.equal(ledger.artifact().records[1]?.consumedCallCount, 1);
    assert.equal(evidenceRequestError(tool, boundary), undefined);
    assert.equal(evidenceRequestError(tool, overlong)?.message, harness.traces[1]?.error);
  }
});

test("bounds comparison windows independently before accessing evidence", async () => {
  for (const field of ["baselineEndTime", "postEndTime"] as const) {
    const parameters = {
      baselineStartTime: 1700000000, baselineEndTime: 1700003600,
      postStartTime: 1700003600, postEndTime: 1700007200,
    };
    assert.equal(evidenceRequestError("compare_metrics", parameters), undefined);
    parameters[field] += 1;
    const ledger = new FixtureApprovalLedger([
      approval("compare_metrics", "compare", parameters),
    ], () => new Date(NOW));
    const harness = createEvidenceTools({
      caseRoot: join("logs", "nonexistent-window-limit-fixture"), ledger, clock: () => new Date(NOW),
    });
    const comparison = harness.tools.find((tool) => tool.name === "compare_metrics")!;
    assert.match(comparison.description, /each separate baseline and post-onset window/);
    await assert.rejects(comparison.handler(parameters), EvidenceWindowLimitError);
    assert.equal(harness.traces[0]?.status, "query-error");
    assert.equal(evidenceRequestError("compare_metrics", parameters)?.message, harness.traces[0]?.error);
  }
  assert.equal(evidenceRequestError("read_incident_scope", {}), undefined);
  assert.equal(evidenceRequestError("unknown-tool", {}), undefined);
  assert.equal(evidenceRequestError("aggregate_metrics", {
    startTime: "not-a-time", endTime: 99999,
  })?.code, "invalid-tool-parameters");
});

test("schema and semantic request rejections are identical at validation, execution and audit boundaries", async () => {
  const window = { startTime: 1700000000, endTime: 1700000300 };
  const comparison = {
    baselineStartTime: 1700000000, baselineEndTime: 1700000300,
    postStartTime: 1700000300, postEndTime: 1700000600,
  };
  const cases: readonly (readonly [string, string, Record<string, unknown>, EvidenceRequestError["code"]])[] = [
    ["read_incident_scope", "read", { unknown: true }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { startTime: window.startTime }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, service: "   " }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, metric: "" }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, metric: "x".repeat(257) }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, service: false }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, unknown: true }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, startTime: "not-a-time" }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, startTime: " " }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, endTime: Infinity }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", { ...window, endTime: "1e9999" }, "invalid-time-window"],
    ["aggregate_metrics", "aggregate", { ...window, startTime: window.endTime }, "invalid-time-window"],
    ["aggregate_metrics", "aggregate", { ...window, endTime: window.startTime - 1 }, "invalid-time-window"],
    ["aggregate_metrics", "aggregate", { ...window, endTime: 1700000300000 }, "invalid-time-window"],
    ["compare_metrics", "compare", { ...comparison, baselineEndTime: 1700000000 }, "invalid-time-window"],
    ["compare_metrics", "compare", { ...comparison, postEndTime: 1700000000 }, "invalid-time-window"],
    ["compare_metrics", "compare", {
      ...comparison, postStartTime: 1700000300000, postEndTime: 1700000600000,
    }, "invalid-time-window"],
    ["compare_metrics", "compare", { ...comparison, limit: 51 }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, literal: "\t" }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, cursor: "z".repeat(64) }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, cursor: "0".repeat(64) }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, cursor: "f".repeat(64) }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, limit: 0 }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, limit: 1.5 }, "invalid-tool-parameters"],
    ["search_logs", "search", { ...window, limit: 101 }, "invalid-tool-parameters"],
    ["summarize_traces", "summarize", { ...window, status: " " }, "invalid-tool-parameters"],
    ["summarize_traces", "summarize", { ...window, minimumDuration: -1 }, "invalid-tool-parameters"],
    ["aggregate_metrics", "aggregate", {
      service: " ", endTime: "invalid", startTime: false,
    }, "invalid-tool-parameters"],
  ];
  for (const [name, operation, parameters, code] of cases) {
    const ledger = new FixtureApprovalLedger([approval(name, operation, parameters)], () => new Date(NOW));
    const harness = createEvidenceTools({
      caseRoot: join("logs", "nonexistent-request-validation-fixture"), ledger, clock: () => new Date(NOW),
    });
    const tool = harness.tools.find((candidate) => candidate.name === name)!;
    const expected = evidenceRequestError(name, parameters);
    assert.ok(expected instanceof EvidenceRequestError);
    assert.equal(expected.code, code);
    assert.throws(() => validateEvidenceParameters(tool, parameters), {
      name: expected.name, message: expected.message,
    });
    await assert.rejects(tool.handler(parameters), {
      name: expected.name, message: expected.message,
    });
    assert.equal(harness.traces[0]?.status, "query-error");
    assert.equal(harness.traces[0]?.errorCode, code);
    assert.equal(harness.traces[0]?.error, expected.message);
    assert.equal(harness.traces[0]?.resultHash, undefined);
    assert.equal(ledger.artifact().records[0]?.consumedCallCount, 1);
    await assert.rejects(tool.handler(parameters), /No exact simulated approval/);
    assert.equal(harness.traces[1]?.status, "blocked");
  }
});

test("advertises shared string constraints and accepts finite numeric epoch strings", async () => {
  const tools = createEvidenceTools({
    caseRoot: "", ledger: { consume: () => { throw new Error("No execution expected"); } },
  }).tools;
  for (const tool of tools) {
    const properties = tool.parameters.properties as Record<string, Record<string, unknown>>;
    for (const field of ["service", "metric", "literal", "status"]) {
      if (!properties[field]) continue;
      assert.equal(properties[field].minLength, 1);
      assert.equal(properties[field].pattern, "\\S");
    }
    if (properties.cursor) assert.equal(properties.cursor.pattern, "^[0-9a-f]{64}$");
  }
  for (const parameters of [
    { startTime: "1700000000", endTime: "1700000300", service: " service " },
    { startTime: "1.7e9", endTime: 1700000300 },
    { startTime: "-1", endTime: "0" },
  ]) {
    assert.equal(evidenceRequestError("aggregate_metrics", parameters), undefined);
  }
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

/** Issues a new exact fixture approval for each call in one tool instance. */
function approvedQueries(root: string) {
  let ledger = new FixtureApprovalLedger([], () => new Date(NOW));
  const harness = createEvidenceTools({
    caseRoot: root,
    ledger: { consume: (tool, operation, parameters) => ledger.consume(tool, operation, parameters) },
    clock: () => new Date(NOW),
  });
  return {
    harness,
    async run(name: string, parameters: Record<string, unknown>) {
      const operation = name === "search_logs" ? "search"
        : name === "summarize_traces" ? "summarize" : "aggregate";
      ledger = new FixtureApprovalLedger([approval(name, operation, parameters)], () => new Date(NOW));
      const tool = harness.tools.find((candidate) => candidate.name === name)!;
      validateEvidenceParameters(tool, parameters);
      const serialized = await tool.handler(parameters);
      assert.equal(Buffer.byteLength(serialized, "utf8") <= COMMUNICATION_LIMITS.resultBytes, true);
      assert.equal(serialized, stableJson(JSON.parse(serialized)));
      assert.equal(harness.traces.at(-1)?.resultHash, sha256(serialized));
      assert.deepEqual(harness.traces.at(-1)?.normalizedParameters, parameters);
      assert.equal(harness.traces.at(-1)?.status, "executed");
      assert.ok(harness.traces.at(-1)?.approvalId);
      return JSON.parse(serialized) as EvidenceToolResult & {
        data: {
          rows?: Record<string, unknown>[];
          representativeRows?: Record<string, unknown>[];
          groups?: { service: string; status: string; count: number }[];
          summaryScope?: string;
        };
      };
    },
  };
}

test("absent modalities return approved unavailable results and metrics remain usable", async () => {
  const root = await caseRoot();
  await writeFile(join(root, "source-coverage.json"),
    '{"sources":[{"modality":"metrics","complete":true}]}', "utf8");
  await rm(join(root, "logs.jsonl"));
  await rm(join(root, "traces.jsonl"));
  const queries = approvedQueries(root);
  for (const name of ["summarize_traces", "search_logs"]) {
    const result = await queries.run(name, { startTime: 0, endTime: 3 });
    assert.equal(result.availability, "unavailable");
    assert.match(result.availabilityReason!, /absent.*source-coverage/);
    assert.equal(result.sourceComplete, false);
    assert.equal(result.pageComplete, true);
    assert.equal(result.empty, true);
    assert.equal(result.rowCount, 0);
    assert.equal(result.nextCursor, undefined);
  }
  const metrics = await queries.run("aggregate_metrics", { startTime: 0, endTime: 3 });
  assert.equal(metrics.availability, "available");
  assert.equal(metrics.sourceComplete, true);
  assert.equal(metrics.matchedRowCount, 2);
  assert.deepEqual(queries.harness.traces.map((trace) => trace.sequence), [1, 2, 3]);
});

test("unavailable metrics do not require a metric store or mapping", async () => {
  const root = await caseRoot();
  await writeFile(join(root, "source-coverage.json"), '{"sources":[]}', "utf8");
  await rm(join(root, "metric-columns.json"));
  await rm(join(root, "metrics.jsonl"));
  const result = await approvedQueries(root).run("aggregate_metrics", { startTime: 0, endTime: 3 });
  assert.equal(result.availability, "unavailable");
});

test("missing required coverage is an error even when evidence stores exist", async () => {
  const root = await caseRoot();
  await rm(join(root, "source-coverage.json"));
  const queries = approvedQueries(root);
  await assert.rejects(queries.run("search_logs", { startTime: 0, endTime: 3 }), /ENOENT/);
  assert.equal(queries.harness.traces.at(-1)?.status, "error");
});

test("malformed coverage, advertised missing stores, invalid JSONL and IO failures remain errors", async () => {
  const root = await caseRoot();
  const queries = approvedQueries(root);
  const parameters = { startTime: 0, endTime: 3 };
  for (const text of ["{", '{"sources":null}', '{"sources":[{}]}']) {
    await writeFile(join(root, "source-coverage.json"), text, "utf8");
    await assert.rejects(queries.run("search_logs", parameters));
    assert.equal(queries.harness.traces.at(-1)?.status, "error");
  }
  await writeFile(join(root, "source-coverage.json"), '{"sources":[{"modality":"logs"}]}', "utf8");
  await rm(join(root, "logs.jsonl"));
  await assert.rejects(queries.run("search_logs", parameters), /ENOENT/);
  await mkdir(join(root, "logs.jsonl"));
  await assert.rejects(queries.run("search_logs", parameters), /EISDIR|EPERM|EACCES/);
  await rm(join(root, "logs.jsonl"), { recursive: true });
  for (const text of ["{bad\n", "null\n", "[]\n", '{"timestamp":1}\n{bad\n']) {
    await writeFile(join(root, "logs.jsonl"), text, "utf8");
    await assert.rejects(queries.run("search_logs", parameters));
  }
});

test("available empty evidence and incomplete coverage have independent completion metadata", async () => {
  const root = await caseRoot();
  await writeFile(join(root, "logs.jsonl"), "", "utf8");
  const queries = approvedQueries(root);
  const parameters = { startTime: 0, endTime: 3 };
  const empty = await queries.run("search_logs", parameters);
  assert.equal(empty.empty, true);
  assert.equal(empty.sourceComplete, true);
  assert.equal(empty.pageComplete, true);
  assert.equal(empty.availability, "available");
  await writeFile(join(root, "source-coverage.json"),
    '{"sources":[{"modality":"logs","complete":false,"truncated":true}]}', "utf8");
  const partial = await queries.run("search_logs", parameters);
  assert.equal(partial.sourceComplete, false);
  assert.equal(partial.pageComplete, true);
  assert.equal(partial.availability, "available");
});

test("byte-aware pages preserve every complete UTF8 row in source order for logs and traces", async () => {
  const root = await caseRoot();
  const rows = Array.from({ length: 9 }, (_, id) => ({
    timestamp: 1, id, service: `service|${id}`, status: "error|value",
    message: "界🦊".repeat(1_600),
  }));
  for (const [name, store] of [
    ["search_logs", "logs.jsonl"], ["summarize_traces", "traces.jsonl"],
  ] as const) {
    await writeFile(join(root, store), rows.map((row) => JSON.stringify(row)).join("\n") + "\n", "utf8");
    const queries = approvedQueries(root);
    const query = { startTime: 0, endTime: 3, limit: 6 };
    const delivered: Record<string, unknown>[] = [];
    let cursor: string | undefined;
    do {
      const page = await queries.run(name, { ...query, ...(cursor ? { cursor } : {}) });
      const pageRows = page.data.rows ?? page.data.representativeRows!;
      assert.ok(pageRows.length > 0 && pageRows.length < query.limit);
      assert.equal(page.rowCount, rows.length);
      assert.equal(page.matchedRowCount, rows.length);
      assert.equal(page.sourceComplete, true);
      assert.equal(page.truncated, !page.pageComplete);
      if (name === "summarize_traces") {
        assert.equal(page.data.summaryScope, "page");
        assert.deepEqual(page.data.groups, pageRows.map((row) => ({
          service: row.service, status: row.status, count: 1,
        })));
      }
      delivered.push(...pageRows);
      cursor = page.nextCursor;
      assert.equal(cursor === undefined, page.pageComplete);
    } while (cursor);
    assert.deepEqual(delivered, rows);
  }
});

test("row limits and cursors require identical newly approved calls", async () => {
  const root = await caseRoot();
  const queries = approvedQueries(root);
  const parameters = { startTime: 0, endTime: 3, limit: 1 };
  const first = await queries.run("search_logs", parameters);
  assert.equal(first.data.rows?.length, 1);
  assert.equal(first.pageComplete, false);
  assert.equal(first.sourceComplete, true);
  const cursor = first.nextCursor!;
  const tool = queries.harness.tools.find((candidate) => candidate.name === "search_logs")!;
  await assert.rejects(tool.handler({ ...parameters, cursor }), /No exact simulated approval/);
  assert.equal(queries.harness.traces.at(-1)?.status, "blocked");
  for (const changed of [
    { ...parameters, cursor, limit: 2 },
    { ...parameters, cursor, endTime: 4 },
    { ...parameters, cursor, literal: "started" },
    { ...parameters, cursor: "0".repeat(64) },
    { ...parameters, cursor: cursor.slice(0, -1) + (cursor.endsWith("f") ? "e" : "f") },
  ]) {
    await assert.rejects(queries.run("search_logs", changed), /Invalid cursor/);
  }
  await assert.rejects(queries.run("summarize_traces", { ...parameters, cursor }), /Invalid cursor/);
  const second = await queries.run("search_logs", { ...parameters, cursor });
  assert.equal(second.data.rows?.[0]?.message, "deadline exceeded");
  assert.equal(second.nextCursor, undefined);
  assert.equal(second.pageComplete, true);
  const replay = await queries.run("search_logs", { ...parameters, cursor });
  assert.deepEqual(replay, second);
  await assert.rejects(queries.run("search_logs", { ...parameters, limit: 101 }),
    /Invalid search_logs parameter/);
});

test("byte-limited continuations survive tool reconstruction but reject changed case, tool or query", async () => {
  const root = await caseRoot();
  const otherRoot = await caseRoot();
  const rows = Array.from({ length: 9 }, (_, id) => ({
    timestamp: 1, id, service: `service-${id}`, status: "error",
    message: "界🦊".repeat(1_600),
  }));
  const query = { startTime: 0, endTime: 3, limit: 6 };
  for (const [name, store] of [
    ["search_logs", "logs.jsonl"], ["summarize_traces", "traces.jsonl"],
  ] as const) {
    await writeFile(join(root, store), rows.map((row) => JSON.stringify(row)).join("\n"), "utf8");
    const first = await approvedQueries(root).run(name, query);
    assert.ok(first.nextCursor);
    const repeatedFirst = await approvedQueries(root).run(name, query);
    assert.deepEqual(repeatedFirst, first);
    const continuation = { ...query, cursor: first.nextCursor };
    await assert.rejects(approvedQueries(otherRoot).run(name, continuation), /Invalid cursor/);
    await assert.rejects(approvedQueries(root).run(
      name === "search_logs" ? "summarize_traces" : "search_logs", continuation,
    ), /Invalid cursor/);
    await assert.rejects(approvedQueries(root).run(name, { ...continuation, limit: 5 }), /Invalid cursor/);
    await assert.rejects(approvedQueries(root).run(name, {
      ...continuation, cursor: "ffffffffffffffff" + first.nextCursor.slice(16),
    }), /Invalid cursor/);
    const delivered = [...(first.data.rows ?? first.data.representativeRows!)];
    let cursor: string | undefined = first.nextCursor;
    while (cursor) {
      const page = await approvedQueries(root).run(name, { ...query, cursor });
      assert.equal(page.sourceComplete, true);
      assert.equal(page.pageComplete, page.nextCursor === undefined);
      delivered.push(...(page.data.rows ?? page.data.representativeRows!));
      cursor = page.nextCursor;
    }
    assert.deepEqual(delivered, rows);
  }
});

test("48-byte envelope overflow splits full rows rather than rejecting delivery", async () => {
  const root = await caseRoot();
  const queries = approvedQueries(root);
  const query = { startTime: 0, endTime: 3, limit: 2 };
  const rows = [{ timestamp: 1, message: "" }, { timestamp: 2, message: "" }];
  const baseline = await queries.run("search_logs", query);
  const envelope = {
    ...baseline,
    rowCount: 2, matchedRowCount: 2, empty: false,
    data: { window: { startTime: 0, endTime: 3, unit: "epoch seconds" }, literal: null, rows },
  };
  const excess = COMMUNICATION_LIMITS.resultBytes + 48 - Buffer.byteLength(stableJson(envelope));
  rows[0]!.message = "a".repeat(Math.floor(excess / 2));
  rows[1]!.message = "b".repeat(excess - rows[0]!.message.length);
  assert.equal(Buffer.byteLength(stableJson(envelope)), COMMUNICATION_LIMITS.resultBytes + 48);
  await writeFile(join(root, "logs.jsonl"), rows.map((row) => JSON.stringify(row)).join("\n"), "utf8");
  const first = await queries.run("search_logs", query);
  assert.deepEqual(first.data.rows, [rows[0]]);
  const second = await queries.run("search_logs", { ...query, cursor: first.nextCursor });
  assert.deepEqual(second.data.rows, [rows[1]]);
});

test("oversized rows explicitly stop without skips or a repeating continuation", async () => {
  const root = await caseRoot();
  const rows = [
    { timestamp: 1, message: "small" },
    { timestamp: 1, message: "界".repeat(COMMUNICATION_LIMITS.resultBytes) },
    { timestamp: 1, message: "last" },
  ];
  await writeFile(join(root, "logs.jsonl"), rows.map((row) => JSON.stringify(row)).join("\n"), "utf8");
  const queries = approvedQueries(root);
  const query = { startTime: 0, endTime: 3, limit: 100 };
  const first = await queries.run("search_logs", query);
  assert.deepEqual(first.data.rows, [rows[0]]);
  const stopped = await queries.run("search_logs", { ...query, cursor: first.nextCursor });
  assert.deepEqual(stopped.data.rows, []);
  assert.equal(stopped.empty, false);
  assert.equal(stopped.nonProgress, true);
  assert.equal(stopped.pageComplete, false);
  assert.equal(stopped.nextCursor, undefined);
  assert.equal(stopped.oversizedRow?.matchOffset, 1);
  assert.equal(stopped.oversizedRow?.rowBytes, Buffer.byteLength(stableJson(rows[1])));
  assert.ok(stopped.oversizedRow!.requiredResultBytes > COMMUNICATION_LIMITS.resultBytes);
  assert.match(stopped.oversizedRow!.reason, /narrow.*No evidence was skipped/);
  const recovered = await queries.run("search_logs", { ...query, literal: "last" });
  assert.deepEqual(recovered.data.rows, [rows[2]]);
});

test("trace summary overhead can make a single otherwise fitting row undeliverable", async () => {
  const root = await caseRoot();
  const row = { timestamp: 1, service: "s".repeat(40_000), status: "error" };
  assert.ok(Buffer.byteLength(stableJson(row)) < COMMUNICATION_LIMITS.resultBytes);
  await writeFile(join(root, "traces.jsonl"), JSON.stringify(row) + "\n", "utf8");
  const stopped = await approvedQueries(root).run("summarize_traces", { startTime: 0, endTime: 3 });
  assert.equal(stopped.nonProgress, true);
  assert.equal(stopped.nextCursor, undefined);
  assert.deepEqual(stopped.data.groups, []);
  assert.deepEqual(stopped.data.representativeRows, []);
  assert.match(stopped.oversizedRow!.reason, /page summary/);
});
