// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildMetricColumnMap,
  validateMetricColumnMap,
} from "../../../evals/rca-real-world/metric-schema.mts";

test("maps pinned metric suffixes without splitting service underscores", () => {
  assert.deepEqual(buildMetricColumnMap([
    { time: 1, user_db_cpu: 10, "user_db_latency-90": 0.2 },
    { time: 2, user_db_cpu: 20, "user_db_latency-90": 0.3, user_mem: 100 },
    { timestamp: 3, service: "user", metric: "cpu", value: 5 },
  ]), {
    user_db_cpu: { service: "user_db", metric: "cpu" },
    "user_db_latency-90": { service: "user_db", metric: "latency-90" },
    user_mem: { service: "user", metric: "mem" },
  });
});

test("rejects unknown wide column boundaries instead of guessing", () => {
  for (const field of ["unstructured", "user_cpu_percent", "_cpu", " user_cpu"]) {
    assert.throws(() => buildMetricColumnMap([{ time: 1, [field]: 10 }]), /Unsupported RCAEval/);
  }
});

test("validates explicit mappings independently of source column spelling", () => {
  assert.deepEqual(validateMetricColumnMap({
    opaque_column: { service: "user_db", metric: "cpu_time" },
  }), { opaque_column: { service: "user_db", metric: "cpu_time" } });
  for (const value of [
    null, [], "mapping", { field: null }, { field: {} },
    { field: { service: "user", metric: "" } },
    { field: { service: 1, metric: "cpu" } },
    { field: { service: "user", metric: "cpu", extra: true } },
  ]) {
    assert.throws(() => validateMetricColumnMap(value), /[Mm]etric column/);
  }
});
