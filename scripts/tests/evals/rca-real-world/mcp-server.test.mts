// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { test } from "node:test";

import { writeJson } from "../../../evals/rca-real-world/contracts.mts";

test("serves only bounded MCP tools and blocks unapproved calls", async () => {
  const root = await mkdtemp(join(tmpdir(), "rca-mcp-"));
  await writeJson(join(root, "metric-columns.json"), {
    service_cpu: { service: "service", metric: "cpu" },
  });
  const ledgerPath = join(root, "ledger.json");
  const tracePath = join(root, "trace.json");
  await writeFile(join(root, "incident.json"), '{"caseId":"case-01"}', "utf8");
  await writeFile(join(root, "source-coverage.json"), '{"sources":[]}', "utf8");
  await writeFile(join(root, "metrics.jsonl"), '{"time":"1","service_cpu":1}\n', "utf8");
  await writeJson(ledgerPath, {
    schemaVersion: "1.0.0",
    authority: "simulated-protocol-fixture",
    establishesProductionAuthorization: false,
    records: [],
  });

  const child = spawn(
    process.execPath,
    [
      resolve("scripts/evals/rca-real-world/mcp-server.mts"),
      "--case-root",
      root,
      "--ledger",
      ledgerPath,
      "--trace",
      tracePath,
    ],
    { windowsHide: true },
  );
  const responses: unknown[] = [];
  const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
  const completed = new Promise<void>((resolveCompleted, reject) => {
    child.once("error", reject);
    child.stderr.once("data", (chunk) => reject(new Error(String(chunk))));
    lines.on("line", (line) => {
      responses.push(JSON.parse(line));
      if (responses.length === 3) {
        child.stdin.end();
        resolveCompleted();
      }
    });
  });
  child.stdin.write(
    `${JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: { protocolVersion: "2025-06-18" },
    })}\n`,
  );
  child.stdin.write(
    `${JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} })}\n`,
  );
  child.stdin.write(
    `${JSON.stringify({
      jsonrpc: "2.0",
      id: 3,
      method: "tools/call",
      params: { name: "read_incident_scope", arguments: {} },
    })}\n`,
  );
  await completed;

  const initialize = responses[0] as { result: { serverInfo: { name: string } } };
  const tools = responses[1] as { result: { tools: readonly { name: string }[] } };
  const blocked = responses[2] as {
    result: { isError: boolean; content: readonly { text: string }[] };
  };
  assert.equal(initialize.result.serverInfo.name, "hve-rca-evidence");
  assert.deepEqual(
    tools.result.tools.map((tool) => tool.name),
    [
      "read_incident_scope",
      "aggregate_metrics",
      "compare_metrics",
      "search_logs",
      "summarize_traces",
    ],
  );
  assert.equal(blocked.result.isError, true);
  assert.match(blocked.result.content[0]?.text ?? "", /No exact simulated approval/);
});
