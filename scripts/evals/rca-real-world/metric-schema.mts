// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export const METRIC_TIME_FIELDS = [
  "timestamp", "startTimeMillis", "start_time", "startTime", "time", "ts",
] as const;

export interface MetricIdentity {
  readonly service: string;
  readonly metric: string;
}

/** Maps unchanged source column names to explicit service and metric identities. */
export type MetricColumnMap = Readonly<Record<string, MetricIdentity>>;

/** Recognizes row-oriented metrics, including rows with missing or invalid identity values. */
export function isNarrowMetricRow(row: Readonly<Record<string, unknown>>): boolean {
  return ["metric", "metric_name", "name", "value"].some((key) => Object.hasOwn(row, key));
}

/**
 * Builds identities using the pinned RCAEval schema's terminal metric suffixes.
 *
 * Service names may contain underscores. Unknown numeric columns are rejected rather than
 * splitting an arbitrary name or consulting held-out fault labels.
 */
export function buildMetricColumnMap(
  rows: readonly Readonly<Record<string, unknown>>[],
): MetricColumnMap {
  const columns = new Map<string, MetricIdentity>();
  for (const row of rows) {
    if (isNarrowMetricRow(row)) {
      continue;
    }
    for (const [field, value] of Object.entries(row)) {
      if (METRIC_TIME_FIELDS.some((key) => key === field) || typeof value !== "number") {
        continue;
      }
      const match = /^(.+)_(cpu|mem|latency(?:-50|-90)?|load|error|diskio|socket|workload)$/.exec(field);
      if (!match || match[1]!.trim() !== match[1]) {
        throw new Error(`Unsupported RCAEval metric column: ${field}`);
      }
      columns.set(field, { service: match[1]!, metric: match[2]! });
    }
  }
  return Object.fromEntries(columns);
}

/**
 * Validates persisted metric identities without inferring identities from column names.
 *
 * @throws When the mapping is not an object or an identity is missing or malformed.
 */
export function validateMetricColumnMap(value: unknown): MetricColumnMap {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Metric column mapping must be an object");
  }
  const columns = new Map<string, MetricIdentity>();
  for (const [field, identity] of Object.entries(value)) {
    if (
      !field.trim() ||
      identity === null ||
      typeof identity !== "object" ||
      Array.isArray(identity) ||
      !("service" in identity) ||
      !("metric" in identity) ||
      typeof identity.service !== "string" ||
      typeof identity.metric !== "string" ||
      !identity.service.trim() ||
      !identity.metric.trim() ||
      Object.keys(identity).length !== 2
    ) {
      throw new Error(`Invalid metric column identity: ${field}`);
    }
    columns.set(field, { service: identity.service, metric: identity.metric });
  }
  return Object.fromEntries(columns);
}
