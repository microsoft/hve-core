// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { link, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { FixtureApprovalLedger, type ApprovalRequestItem } from "../../../evals/rca-real-world/approval.mts";
import { COMMUNICATION_LIMITS, approvalPolicy, sha256, stableJson } from "../../../evals/rca-real-world/contracts.mts";
import { EvidenceRequestError, type EvidenceToolResult } from "../../../evals/rca-real-world/evidence-tools.mts";
import { RAW_EVIDENCE_OPERATIONS, createRawEvidenceTools, rawEvidenceRequestError } from "../../../evals/rca-real-world/raw-evidence-tools.mts";

const NOW = "2026-11-05T18:00:00.000Z";
async function fixture(context: { after: (callback: () => Promise<void>) => void }, rows: unknown[] = []) {
  const root = await mkdtemp(join(tmpdir(), "hve-raw-jsonl-tests-"));
  context.after(() => rm(root, { force: true, recursive: true }));
  await writeFile(join(root, "incident.json"), '{"onset":100}\n');
  await writeFile(join(root, "metrics.jsonl"), rows.map((row) => JSON.stringify(row)).join("\n") + (rows.length ? "\n" : ""));
  return root;
}
function harness(root: string, name: keyof typeof RAW_EVIDENCE_OPERATIONS, parameters: Record<string, unknown>, approved = true) {
  const request: ApprovalRequestItem = {
    tool: name, operation: RAW_EVIDENCE_OPERATIONS[name], parameters, ...approvalPolicy("raw"),
    evidenceSought: "Inspect exact original fields", target: "case-01", expiresAt: "2026-11-05T18:10:00.000Z",
  };
  const ledger = new FixtureApprovalLedger(approved ? [request] : [], () => new Date(NOW));
  const provider = createRawEvidenceTools({ caseRoot: root, ledger, clock: () => new Date(NOW) });
  const call = (exact = parameters) => provider.tools.find((tool) => tool.name === name)!.handler(exact);
  return { ...provider, ledger, call };
}
async function query(root: string, parameters: Record<string, unknown> = {}) {
  return JSON.parse(await harness(root, "query_jsonl", { path: "metrics.jsonl", ...parameters }).call()) as EvidenceToolResult;
}

test("lists only neutral JSONL metadata and reads bounded bytes without changing source files", async (context) => {
  const root = await fixture(context, [{ "original|metric": 2 }]);
  const original = await readFile(join(root, "metrics.jsonl"));
  const provider = harness(root, "list_files", {});
  const listed = JSON.parse(await provider.call()) as EvidenceToolResult;
  assert.deepEqual((listed.data as { path: string }[]).map((file) => file.path), ["incident.json", "metrics.jsonl"]);
  const read = harness(root, "read_file", { path: "metrics.jsonl", offset: 0, length: 5 });
  const partial = JSON.parse(await read.call());
  assert.equal(partial.data.content, original.subarray(0, 5).toString());
  assert.equal(partial.data.nextOffset, 5);
  assert.equal(partial.sourceComplete, false);
  assert.equal(partial.pageComplete, false);
  assert.equal(partial.truncated, true);
  const eof = JSON.parse(await harness(root, "read_file", { path: "metrics.jsonl", offset: original.length }).call());
  assert.equal(eof.rowCount, 0);
  assert.deepEqual(await readFile(join(root, "metrics.jsonl")), original);
  assert.equal(provider.traces[0]!.resultHash, sha256(await harness(root, "list_files", {}).call()));
});

test("queries original columns using exact scalar predicates, safe numeric strings and projection", async (context) => {
  const root = await fixture(context, [
    { time: "100", "cpu|original": 1, service: "cart", nested: { retained: true } },
    { time: "101", "cpu|original": 3, service: "cart", nested: null },
    { time: "102", "cpu|original": 5, service: "other" },
  ]);
  const result = await query(root, {
    filters: JSON.stringify([{ field: "time", op: "gte", value: 101 }, { field: "service", op: "contains", value: "car" }]),
    columns: '["time","cpu|original","nested"]',
  });
  assert.deepEqual(result.data, [{ time: "101", "cpu|original": 3, nested: null }]);
  assert.equal(result.matchedRowCount, 1);
  assert.equal(result.sourceComplete, true);
  assert.deepEqual((await query(root, { filters: '[{"field":"service","op":"eq","value":"missing"}]' })).data, []);
});

test("summary computes numeric and nonnumeric counts from exact fields without creating mappings", async (context) => {
  const root = await fixture(context, [
    { service: "a", original: 1 }, { service: "a", original: "3" },
    { service: "a", original: "unsafe-identifier" }, { service: "a", original: "9007199254740993" },
    { service: "b", original: 10 },
  ]);
  const result = await query(root, { mode: "summary", groupBy: "service", columns: '["original"]' });
  assert.deepEqual(result.data, [
    { group: { field: "service", missing: false, value: "a" }, rows: 4, field: "original", count: 4, numericCount: 2, nonNumericCount: 2, min: 1, max: 3, mean: 2 },
    { group: { field: "service", missing: false, value: "b" }, rows: 1, field: "original", count: 1, numericCount: 1, nonNumericCount: 0, min: 10, max: 10, mean: 10 },
  ]);
});

for (const mode of ["rows", "summary"]) {
  test(`paginates ${mode} with complete scan metadata, no duplicate rows, and immutable case/query binding`, async (context) => {
    const root = await fixture(context, Array.from({ length: 130 }, (_, n) => ({ field: n, value: n * 2 })));
    const exact = { mode, limit: 17, ...(mode === "summary" ? { groupBy: "field", columns: '["value"]' } : {}) };
    const first = await query(root, exact);
    assert.equal(first.rowCount, 17);
    assert.equal(first.matchedRowCount, 130);
    assert.equal(first.pageComplete, false);
    assert.equal(first.sourceComplete, true);
    const data = [...first.data as unknown[]];
    let cursor = first.nextCursor;
    while (cursor) {
      const page = await query(root, { ...exact, cursor });
      data.push(...page.data as unknown[]); cursor = page.nextCursor;
    }
    assert.equal(data.length, 130);
    assert.equal(new Set(data.map((row) => JSON.stringify(row))).size, 130);
    const changed = harness(root, "query_jsonl", { path: "metrics.jsonl", ...exact, limit: 18, cursor: first.nextCursor });
    await assert.rejects(changed.call(), /binding mismatch/);
    assert.equal(changed.traces[0]!.status, "error");
    const other = await fixture(context, [{ field: 1, value: 2 }]);
    await assert.rejects(query(other, { ...exact, cursor: first.nextCursor }), /binding mismatch/);
    await assert.rejects(harness(root, "query_jsonl", { path: "logs.jsonl", ...exact, cursor: first.nextCursor }).call(), /binding mismatch/);
  });
}

test("oversized rows explicitly prevent progress, and projection can recover access", async (context) => {
  const root = await fixture(context, [{ value: 1, payload: "x".repeat(COMMUNICATION_LIMITS.resultBytes) }]);
  const result = await query(root);
  assert.equal(result.nonProgress, true);
  assert.equal(result.empty, false);
  assert.equal(result.rowCount, 0);
  assert.equal(result.nextCursor, undefined);
  assert.ok(result.oversizedRow!.requiredResultBytes > COMMUNICATION_LIMITS.resultBytes);
  assert.deepEqual((await query(root, { columns: '["value"]' })).data, [{ value: 1 }]);
});

test("byte-bounded pages preserve every match and expose continuation before the row limit", async (context) => {
  const root = await fixture(context, Array.from({ length: 20 }, (_, n) => ({ n, text: "x".repeat(12_000) })));
  const first = await query(root);
  assert.ok(first.rowCount > 0 && first.rowCount < 20);
  assert.ok(Buffer.byteLength(JSON.stringify(first)) <= COMMUNICATION_LIMITS.resultBytes);
  assert.ok(first.nextCursor);
  assert.equal(first.matchedRowCount, 20);
});

test("absent modalities are unavailable, not fabricated empty evidence", async (context) => {
  const root = await fixture(context, []);
  const result = JSON.parse(await harness(root, "query_jsonl", { path: "logs.jsonl" }).call()) as EvidenceToolResult;
  assert.equal(result.availability, "unavailable");
  assert.equal(result.sourceComplete, false);
  assert.ok(result.availabilityReason);
});

for (const [fields, count] of [[32, 61], [17, 101]] as const) {
  test(`complete envelopes bound many-field pages without losing rows: ${fields} fields`, async (context) => {
    const rows = Array.from({ length: count }, (_, n) => Object.fromEntries(
      Array.from({ length: fields }, (_, field) => [`original_metric_${field}`, n + field / 1000]),
    ));
    const root = await fixture(context, rows);
    const exact = { limit: Math.min(count, 100), columns: JSON.stringify(Object.keys(rows[0]!)) };
    const collected: unknown[] = [];
    let cursor: string | undefined;
    let pages = 0;
    do {
      const text = await harness(root, "query_jsonl", {
        path: "metrics.jsonl", ...exact, ...(cursor ? { cursor } : {}),
      }).call();
      assert.ok(Buffer.byteLength(text, "utf8") <= COMMUNICATION_LIMITS.resultBytes);
      const page = JSON.parse(text);
      assert.ok(page.rowCount > 0);
      assert.equal(page.matchedRowCount, count);
      assert.equal(page.scannedRows, count);
      assert.equal(page.pageComplete, page.nextCursor === undefined);
      collected.push(...page.data);
      cursor = page.nextCursor;
      assert.ok(++pages <= count);
    } while (cursor);
    assert.ok(pages > 1);
    assert.deepEqual(collected, rows);
  });
}

test("full-envelope overhead cannot strand a row that fits standalone serialization", async (context) => {
  const row = Object.fromEntries(Array.from({ length: 1000 }, (_, field) => [
    `field_${field}`, "x".repeat(45),
  ]));
  assert.ok(Buffer.byteLength(stableJson(row)) < COMMUNICATION_LIMITS.resultBytes);
  const root = await fixture(context, [row]);
  const result = await query(root, { limit: 1 });
  assert.equal(result.nonProgress, true);
  assert.equal(result.empty, false);
  assert.equal(result.rowCount, 0);
  assert.equal(result.nextCursor, undefined);
  const full = {
    source: "metrics", rowCount: 1, matchedRowCount: 1, truncated: false, sourceComplete: true,
    empty: false, availability: "available", pageComplete: true, data: [row],
    scannedRows: 1, matchedSourceRows: 1,
  };
  assert.equal(result.oversizedRow!.requiredResultBytes, Buffer.byteLength(stableJson(full)));
  assert.ok(result.oversizedRow!.requiredResultBytes > COMMUNICATION_LIMITS.resultBytes);
  assert.ok(Buffer.byteLength(stableJson(result)) <= COMMUNICATION_LIMITS.resultBytes);
  assert.deepEqual((await query(root, { columns: '["field_0"]' })).data, [{ field_0: row.field_0 }]);
});

for (const parameters of [
  { path: "../truth.json" }, { path: "metrics.parquet" }, { path: "incident.json" },
  { path: "metrics.jsonl", filters: "not json" }, { path: "metrics.jsonl", filters: "{}" },
  { path: "metrics.jsonl", filters: '[{"field":"x","op":"execute","value":"code"}]' },
  { path: "metrics.jsonl", filters: '[{"field":"x","op":"gt","value":null}]' },
  { path: "metrics.jsonl", mode: "sql" }, { path: "metrics.jsonl", groupBy: "x" },
  { path: "metrics.jsonl", columns: '["x","x"]' }, { path: "metrics.jsonl", columns: "[]" },
  { path: "metrics.jsonl", limit: 101 }, { path: "metrics.jsonl", cursor: "invalid" },
  { path: "metrics.jsonl", code: "arbitrary code" },
]) {
  test(`invalid query is replayable, consumes exact approval and reads no files: ${JSON.stringify(parameters)}`, async () => {
    const provider = harness("nonexistent-case", "query_jsonl", parameters);
    const expected = rawEvidenceRequestError("query_jsonl", parameters);
    assert.ok(expected instanceof EvidenceRequestError);
    await assert.rejects(provider.call(), EvidenceRequestError);
    assert.equal(provider.traces[0]!.status, "query-error");
    assert.equal(provider.traces[0]!.errorCode, expected.code);
    assert.ok(provider.traces[0]!.approvalId);
  });
}

test("unapproved or changed requests cannot access files", async (context) => {
  const root = await fixture(context, []);
  const provider = harness(root, "read_file", { path: "incident.json" }, false);
  await assert.rejects(provider.call());
  assert.equal(provider.traces[0]!.status, "blocked");
  const changed = harness(root, "read_file", { path: "incident.json" });
  await assert.rejects(changed.call({ path: "metrics.jsonl" }));
  assert.equal(changed.traces[0]!.status, "blocked");
});

test("corrupt JSONL and nonobject rows are explicit technical failures even after a full page", async (context) => {
  const root = await fixture(context, Array.from({ length: 101 }, (_, n) => ({ n })));
  for (const bad of ["invalid json", "null", "[]", "123", ""]) {
    await writeFile(join(root, "metrics.jsonl"), '{"n":0}\n' + bad + "\n");
    const provider = harness(root, "query_jsonl", { path: "metrics.jsonl", limit: 1 });
    await assert.rejects(provider.call(), /JSONL/);
    assert.equal(provider.traces[0]!.status, "error");
  }
});

test("case inventories reject mappings and hard links", async (context) => {
  const root = await fixture(context, []);
  await writeFile(join(root, "metric-columns.json"), "{}");
  await assert.rejects(harness(root, "list_files", {}).call(), /unsupported/);
  await rm(join(root, "metric-columns.json"));
  await link(join(root, "metrics.jsonl"), join(root, "logs.jsonl"));
  await assert.rejects(harness(root, "list_files", {}).call(), /ordinary contained/);
});

test("case directory links cannot reach other evidence", async (context) => {
  const root = await fixture(context, []);
  const target = join(root, "case-link");
  await symlink(root, target, process.platform === "win32" ? "junction" : "dir");
  await assert.rejects(harness(target, "list_files", {}).call(), /ordinary directory/);
});

test("restored traces preserve the 24-call cap across host batches", async (context) => {
  const root = await fixture(context, []);
  const original = harness(root, "list_files", {});
  await original.call();
  const restored = harness(root, "list_files", {});
  restored.traces.push(...Array.from({ length: 24 }, (_, i) => ({ ...original.traces[0]!, sequence: i + 1 })));
  await assert.rejects(restored.call(), /call limit/);
  assert.equal(restored.traces.length, 25);
  assert.equal(restored.traces[24]!.status, "error");
});

test("prototype-like original fields remain ordinary data and missing fields never match", async (context) => {
  const root = await fixture(context, [JSON.parse('{"__proto__":"data","constructor":7,"value":2}')]);
  assert.deepEqual((await query(root, { columns: '["__proto__","constructor"]' })).data, [JSON.parse('{"__proto__":"data","constructor":7}')]);
  assert.equal((await query(root, { filters: '[{"field":"toString","op":"ne","value":null}]' })).matchedRowCount, 0);
});
