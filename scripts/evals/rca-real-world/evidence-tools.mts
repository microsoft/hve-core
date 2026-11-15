// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createReadStream } from "node:fs";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createInterface } from "node:readline";

import { resolveInside, sha256, stableJson, type Modality } from "./contracts.mts";
import {
  isNarrowMetricRow,
  METRIC_TIME_FIELDS,
  validateMetricColumnMap,
  type MetricColumnMap,
  type MetricIdentity,
} from "./metric-schema.mts";
import { COMMUNICATION_LIMITS } from "./communication.mts";

export interface EvidenceToolTrace {
  readonly sequence: number;
  readonly tool: string;
  readonly operation: string;
  readonly normalizedParameters: Readonly<Record<string, unknown>>;
  readonly approvalId?: string;
  readonly requestId?: string;
  readonly status: "executed" | "blocked" | "error" | "query-error";
  readonly startedAt: string;
  readonly completedAt: string;
  readonly resultHash?: string;
  readonly error?: string;
  readonly errorCode?: EvidenceRequestError["code"];
}

const MAX_TIME_WINDOW_SECONDS = 3600;
const TIME_WINDOW_CONSTRAINT =
  `Use finite epoch numbers or numeric strings in matching epoch-second or epoch-millisecond units. endTime must be greater than startTime. Each window is at most ${MAX_TIME_WINDOW_SECONDS} seconds (${MAX_TIME_WINDOW_SECONDS * 1000} milliseconds), including each separate baseline and post-onset window. Metrics/logs use epoch seconds; traces use epoch milliseconds.`;

/** A request violates the tool contract; no source was read and correction needs a new exact approval. */
export class EvidenceRequestError extends Error {
  readonly code: "invalid-tool-parameters" | "invalid-time-window" | "time-window-too-large";

  constructor(
    code: EvidenceRequestError["code"],
    message: string,
  ) {
    super(message);
    this.code = code;
    this.name = "EvidenceRequestError";
  }
}

/** An approved query exceeded the advertised time span before reading a source. */
export class EvidenceWindowLimitError extends EvidenceRequestError {
  constructor(maximumSpan: number, unit: string) {
    super("time-window-too-large",
      `Evidence time window exceeds the ${maximumSpan} ${unit} limit. Narrow the window and request a new exact approval.`);
    this.name = "EvidenceWindowLimitError";
  }
}

/** Replays the shared request contract without reading evidence or consuming approvals. */
export function evidenceRequestError(
  tool: string, parameters: Readonly<Record<string, unknown>>,
): EvidenceRequestError | undefined {
  const definition = createEvidenceTools({
    caseRoot: "",
    ledger: { consume: () => { throw new Error("Request validation cannot consume approvals"); } },
  }).tools.find((candidate) => candidate.name === tool);
  if (!definition) return undefined;
  try {
    validateEvidenceParameters(definition, parameters);
  } catch (error) {
    if (!(error instanceof EvidenceRequestError)) throw error;
    return error;
  }
  return undefined;
}

/** Source availability and scan completion are independent of page delivery completeness. */
export interface EvidenceToolResult {
  readonly source: Modality | "incident";
  readonly rowCount: number;
  readonly matchedRowCount: number;
  readonly truncated: boolean;
  readonly sourceComplete: boolean;
  readonly empty: boolean;
  readonly availability: "available" | "unavailable";
  readonly availabilityReason?: string;
  readonly pageComplete: boolean;
  readonly nextCursor?: string;
  readonly nonProgress?: boolean;
  readonly oversizedRow?: {
    readonly matchOffset: number;
    readonly rowBytes: number;
    readonly requiredResultBytes: number;
    readonly reason: string;
  };
  readonly data: unknown;
}

export interface ToolDefinition {
  readonly name: string;
  readonly description: string;
  readonly parameters: Readonly<Record<string, unknown>>;
  readonly handler: (parameters: Record<string, unknown>) => Promise<string>;
}

export interface ApprovalConsumer {
  consume(tool: string, operation: string, parameters: Readonly<Record<string, unknown>>): string;
  requestId?(approvalId: string): string | undefined;
}

/** Enforces the advertised schema and cross-field rules before any evidence source is accessed. */
export function validateEvidenceParameters(tool: ToolDefinition, parameters: Readonly<Record<string, unknown>>): void {
  const properties = tool.parameters.properties as Readonly<Record<string, Readonly<Record<string, unknown>>>>;
  const required = tool.parameters.required as readonly string[];
  if (Object.keys(parameters).some((key) => !Object.hasOwn(properties, key)) ||
      required.some((key) => !Object.hasOwn(parameters, key))) {
    throw new EvidenceRequestError("invalid-tool-parameters", `Invalid required or additional parameters for ${tool.name}`);
  }
  for (const [key, schema] of Object.entries(properties)) {
    if (!Object.hasOwn(parameters, key)) continue;
    const value = parameters[key];
    if (!matchesSchema(value, schema)) {
      throw new EvidenceRequestError("invalid-tool-parameters",
        `Invalid ${tool.name} parameter: ${key}. ${String(schema.description ?? "Follow the advertised parameter schema.")}`);
    }
  }
  const windows = tool.name === "compare_metrics" ? [
    { startTime: parameters.baselineStartTime, endTime: parameters.baselineEndTime },
    { startTime: parameters.postStartTime, endTime: parameters.postEndTime },
  ] : Object.hasOwn(properties, "startTime") ? [parameters] : [];
  const parsedWindows = windows.map((window) => requireTimeWindow(window));
  if (new Set(parsedWindows.map((window) => window.unit)).size > 1) {
    throw new EvidenceRequestError("invalid-time-window",
      "Baseline and post-onset windows must use matching epoch units");
  }
  if (parameters.cursor !== undefined) {
    const offset = Number.parseInt(String(parameters.cursor).slice(0, 16), 16);
    if (!Number.isSafeInteger(offset) || offset < 1) {
      throw new EvidenceRequestError("invalid-tool-parameters",
        "Invalid cursor offset. Copy nextCursor from a previous result without modification.");
    }
  }
}

function matchesSchema(value: unknown, schema: Readonly<Record<string, unknown>>): boolean {
  if (Array.isArray(schema.anyOf)) {
    return schema.anyOf.some((part: Readonly<Record<string, unknown>>) => matchesSchema(value, part));
  }
  if (schema.type === "string") {
    return typeof value === "string" &&
      (typeof schema.minLength !== "number" || value.length >= schema.minLength) &&
      (typeof schema.maxLength !== "number" || value.length <= schema.maxLength) &&
      (typeof schema.pattern !== "string" || new RegExp(schema.pattern).test(value));
  }
  if (schema.type !== "number" && schema.type !== "integer") return false;
  return typeof value === "number" && Number.isFinite(value) &&
    (schema.type !== "integer" || Number.isSafeInteger(value)) &&
    (typeof schema.minimum !== "number" || value >= schema.minimum) &&
    (typeof schema.maximum !== "number" || value <= schema.maximum);
}

const MAX_CALLS = COMMUNICATION_LIMITS.evidenceCalls;
const MAX_RESULT_ROWS = COMMUNICATION_LIMITS.resultRows;
const MAX_RESULT_BYTES = COMMUNICATION_LIMITS.resultBytes;

/**
 * Creates allowlisted read-only evidence operations for one neutral case.
 *
 * Every handler consumes an exact fixture approval before reading evidence and returns coverage,
 * truncation, row-count, and empty-result metadata. Files outside `caseRoot` are unreachable.
 * Continuation cursors survive tool reconstruction for the same absolute case path and exact query.
 */
export function createEvidenceTools(options: {
  readonly caseRoot: string;
  readonly ledger: ApprovalConsumer;
  readonly clock?: () => Date;
}): { readonly tools: readonly ToolDefinition[]; readonly traces: EvidenceToolTrace[] } {
  const traces: EvidenceToolTrace[] = [];
  const clock = options.clock ?? (() => new Date());
  let calls = 0;

  const page = async (
    tool: string,
    source: "logs" | "traces",
    parameters: Record<string, unknown>,
    window: ReturnType<typeof requireTimeWindow>,
    predicate: (row: Record<string, unknown>) => boolean,
    literal?: string,
  ): Promise<EvidenceToolResult> => {
    const limit = requireLimit(parameters.limit);
    const { cursor, ...query } = parameters;
    const scope = sha256(stableJson({ caseRoot: resolve(options.caseRoot), tool, query }));
    // Opaque cursors carry a safe-integer offset and a 192-bit scope checksum, not authorization.
    const cursorAt = (nextOffset: number): string =>
      nextOffset.toString(16).padStart(16, "0") +
      sha256(stableJson({ scope, offset: nextOffset })).slice(0, 48);
    let offset = 0;
    if (cursor !== undefined) {
      if (typeof cursor !== "string" || !/^[0-9a-f]{64}$/.test(cursor)) {
        throw new Error("Invalid cursor or cursor does not match the exact tool/query");
      }
      offset = Number.parseInt(cursor.slice(0, 16), 16);
      if (!Number.isSafeInteger(offset) || offset < 1 || cursorAt(offset) !== cursor) {
        throw new Error("Invalid cursor or cursor does not match the exact tool/query");
      }
    }
    const coverage = await sourceCoverage(options.caseRoot, source);
    if (!coverage.available) return unavailable(source);
    const rows: Record<string, unknown>[] = [];
    let retainedBytes = 0;
    const selected = await selectRows(
      resolveInside(options.caseRoot, `${source}.jsonl`),
      parameters,
      0,
      predicate,
      (row, matchOffset) => {
        if (matchOffset < offset || rows.length >= limit ||
            retainedBytes > MAX_RESULT_BYTES) return;
        rows.push(row);
        retainedBytes += Buffer.byteLength(stableJson(row), "utf8");
      },
    );
    if (offset > selected.matched) throw new Error("Cursor offset exceeds matching evidence");
    const build = (count: number): EvidenceToolResult => {
      const pageRows = rows.slice(0, count);
      const complete = offset + count === selected.matched;
      const groups = new Map<string, number>();
      if (source === "traces") pageRows.forEach((row) => addTraceGroup(groups, row));
      return {
        ...result(source, selected.scanned, selected.matched, !complete,
          source === "logs"
            ? { window, literal: literal ?? null, rows: pageRows }
            : {
              window, groups: renderTraceGroups(groups), representativeRows: pageRows,
              summaryScope: "page",
            },
          coverage.complete),
        pageComplete: complete,
        ...(!complete && count > 0 ? { nextCursor: cursorAt(offset + count) } : {}),
      };
    };
    let count = rows.length;
    let candidate = build(count);
    while (count > 0 && Buffer.byteLength(stableJson(candidate), "utf8") > MAX_RESULT_BYTES) {
      count -= 1;
      candidate = build(count);
    }
    if (count === 0 && rows.length > 0) {
      const requiredResultBytes = Buffer.byteLength(stableJson(build(1)), "utf8");
      return {
        ...candidate,
        nonProgress: true,
        oversizedRow: {
          matchOffset: offset,
          rowBytes: Buffer.byteLength(stableJson(rows[0]), "utf8"),
          requiredResultBytes,
          reason: "A complete row and its page summary exceed the byte limit; narrow the query. No evidence was skipped.",
        },
      };
    }
    return candidate;
  };

  const execute = async (
    tool: string,
    operation: string,
    parameters: Record<string, unknown>,
    action: () => Promise<EvidenceToolResult>,
  ): Promise<string> => {
    const startedAt = clock().toISOString();
    const normalizedParameters = normalizeParameters(parameters);
    let approvalId: string | undefined;
    try {
      calls += 1;
      if (calls > MAX_CALLS) {
        throw new Error(`Evidence call limit exceeded (${MAX_CALLS})`);
      }
      approvalId = options.ledger.consume(tool, operation, normalizedParameters);
      validateEvidenceParameters(tools.find((candidate) => candidate.name === tool)!, normalizedParameters);
      const result = await action();
      const serialized = stableJson(result);
      if (Buffer.byteLength(serialized, "utf8") > MAX_RESULT_BYTES) {
        throw new Error(`Evidence result exceeds ${MAX_RESULT_BYTES} bytes`);
      }
      traces.push({
        sequence: traces.length + 1,
        tool,
        operation,
        normalizedParameters,
        approvalId,
        requestId: options.ledger.requestId?.(approvalId),
        status: "executed",
        startedAt,
        completedAt: clock().toISOString(),
        resultHash: sha256(serialized),
      });
      return serialized;
    } catch (error) {
      traces.push({
        sequence: traces.length + 1,
        tool,
        operation,
        normalizedParameters,
        approvalId,
        requestId: approvalId ? options.ledger.requestId?.(approvalId) : undefined,
        status: approvalId ? error instanceof EvidenceRequestError ? "query-error" : "error" : "blocked",
        startedAt,
        completedAt: clock().toISOString(),
        error: error instanceof Error ? error.message : String(error),
        ...(error instanceof EvidenceRequestError ? { errorCode: error.code } : {}),
      });
      throw error;
    }
  };

  const tools: readonly ToolDefinition[] = [
      {
        name: "read_incident_scope",
        description:
          "Read neutral incident onset, available evidence sources, coverage, and statistical-unit limitations. Read-only and bounded to the current case.",
        parameters: objectSchema({}),
        handler: (parameters) =>
          execute("read_incident_scope", "read", parameters, async () => {
            const incident = JSON.parse(
              await readFile(resolveInside(options.caseRoot, "incident.json"), "utf8"),
            ) as unknown;
            const coverage = JSON.parse(
              await readFile(resolveInside(options.caseRoot, "source-coverage.json"), "utf8"),
            ) as { sources?: readonly { rowCount?: number }[] };
            const rowCount =
              coverage.sources?.reduce((sum, source) => sum + (source.rowCount ?? 0), 0) ?? 0;
            const timeUnits = {
              metricsAndLogs: "epoch seconds",
              traces: "epoch milliseconds",
            };
            return result(
              "incident",
              2,
              2,
              false,
              {
                incident, coverage, timeUnits,
                metricColumns: await readMetricColumns(options.caseRoot),
              },
              rowCount > 0,
            );
          }),
      },
      {
        name: "aggregate_metrics",
        description:
          `Aggregate numeric metric values over a bounded time window with optional exact service and metric filters. Returns units when present and row counts. ${TIME_WINDOW_CONSTRAINT}`,
        parameters: objectSchema(
          {
            startTime: scalarSchema(),
            endTime: scalarSchema(),
            service: filterSchema(128),
            metric: filterSchema(256),
          },
          ["startTime", "endTime"],
        ),
        handler: (parameters) =>
          execute("aggregate_metrics", "aggregate", parameters, async () => {
            const window = requireTimeWindow(parameters);
            const filters = metricFilters(parameters);
            const coverage = await sourceCoverage(options.caseRoot, "metrics");
            if (!coverage.available) return unavailable("metrics");
            const columns = await readMetricColumns(options.caseRoot);
            const rows = await selectRows(
              resolveInside(options.caseRoot, "metrics.jsonl"),
              window,
              Number.MAX_SAFE_INTEGER,
              (row) => metricValues(row, columns, filters).length > 0,
            );
            const aggregates = aggregateNumeric(rows.rows, columns, filters);
            return result(
              "metrics",
              rows.scanned,
              rows.matched,
              false,
              { window, aggregates },
              coverage.complete,
            );
          }),
      },
      {
        name: "compare_metrics",
        description:
          `Compare bounded baseline and post-onset metric windows, ranking field changes with units and row counts. Optional service and metric filters use exact, case-insensitive identities from row fields or the prepared column mapping. ${TIME_WINDOW_CONSTRAINT}`,
        parameters: objectSchema(
          {
            baselineStartTime: scalarSchema(),
            baselineEndTime: scalarSchema(),
            postStartTime: scalarSchema(),
            postEndTime: scalarSchema(),
            service: filterSchema(128),
            metric: filterSchema(256),
            limit: { type: "integer", minimum: 1, maximum: 50 },
          },
          [
            "baselineStartTime",
            "baselineEndTime",
            "postStartTime",
            "postEndTime",
          ],
        ),
        handler: (parameters) =>
          execute("compare_metrics", "compare", parameters, async () => {
            const baselineWindow = requireTimeWindow({
              startTime: parameters.baselineStartTime,
              endTime: parameters.baselineEndTime,
            });
            const postOnsetWindow = requireTimeWindow({
              startTime: parameters.postStartTime,
              endTime: parameters.postEndTime,
            });
            const filters = metricFilters(parameters);
            const coverage = await sourceCoverage(options.caseRoot, "metrics");
            if (!coverage.available) return unavailable("metrics");
            const columns = await readMetricColumns(options.caseRoot);
            const matchesMetric = (row: Record<string, unknown>) =>
              metricValues(row, columns, filters).length > 0;
            const path = resolveInside(options.caseRoot, "metrics.jsonl");
            const baseline = await selectRows(path, {
              startTime: baselineWindow.startTime,
              endTime: baselineWindow.endTime,
            }, Number.MAX_SAFE_INTEGER, matchesMetric);
            const postOnset = await selectRows(path, {
              startTime: postOnsetWindow.startTime,
              endTime: postOnsetWindow.endTime,
            }, Number.MAX_SAFE_INTEGER, matchesMetric);
            const limit =
              parameters.limit === undefined ? 20 : requireNumber(parameters.limit, "limit");
            const comparisons = compareMetricAggregates(
              aggregateNumeric(baseline.rows, columns, filters),
              aggregateNumeric(postOnset.rows, columns, filters),
              limit,
            );
            return result(
              "metrics",
              baseline.scanned + postOnset.scanned,
              baseline.matched + postOnset.matched,
              false,
              {
                baselineWindow,
                postOnsetWindow,
                baselineRowCount: baseline.matched,
                postOnsetRowCount: postOnset.matched,
                comparisons,
              },
              coverage.complete,
            );
          }),
      },
      {
        name: "search_logs",
        description:
          `Retrieve bounded logs in source order, at most 100 complete rows within the byte limit. Continue with nextCursor as cursor and the identical query in a new approved call; unavailable and oversized non-progress results are explicit. ${TIME_WINDOW_CONSTRAINT}`,
        parameters: objectSchema(
          {
            literal: filterSchema(256),
            startTime: scalarSchema(),
            endTime: scalarSchema(),
            service: filterSchema(128),
            limit: { type: "integer", minimum: 1, maximum: MAX_RESULT_ROWS },
            cursor: cursorSchema(),
          },
          ["startTime", "endTime"],
        ),
        handler: (parameters) =>
          execute("search_logs", "search", parameters, async () => {
            const window = requireTimeWindow(parameters);
            const literal =
              parameters.literal === undefined
                ? undefined
                : requireString(parameters.literal, "literal").toLowerCase();
            return page("search_logs", "logs", parameters, window,
              (row) =>
                literal === undefined || stableJson(row).toLowerCase().includes(literal),
              literal,
            );
          }),
      },
      {
        name: "summarize_traces",
        description:
          `Retrieve bounded traces in source order with complete page-local service/status summaries. At most 100 full rows fit the byte limit; continue using nextCursor as cursor with an identical newly approved query. Oversized rows return explicit non-progress. ${TIME_WINDOW_CONSTRAINT}`,
        parameters: objectSchema(
          {
            startTime: scalarSchema(),
            endTime: scalarSchema(),
            service: filterSchema(128),
            status: filterSchema(64),
            minimumDuration: { type: "number", minimum: 0 },
            limit: { type: "integer", minimum: 1, maximum: MAX_RESULT_ROWS },
            cursor: cursorSchema(),
          },
          ["startTime", "endTime"],
        ),
        handler: (parameters) =>
          execute("summarize_traces", "summarize", parameters, async () => {
            const window = requireTimeWindow(parameters);
            return page("summarize_traces", "traces", parameters, window,
              (row) => matchesStatusAndDuration(row, parameters),
            );
          }),
      },
    ];
  return { tools, traces };
}

async function selectRows(
  path: string,
  parameters: Readonly<Record<string, unknown>>,
  resultLimit: number,
  additionalPredicate: (row: Record<string, unknown>) => boolean = () => true,
  onMatch: (row: Record<string, unknown>, matchOffset: number) => void = () => undefined,
): Promise<{
  readonly rows: Record<string, unknown>[];
  readonly scanned: number;
  readonly matched: number;
}> {
  const rows: Record<string, unknown>[] = [];
  let scanned = 0;
  let matched = 0;
  const input = createInterface({ input: createReadStream(path, "utf8"), crlfDelay: Infinity });
  for await (const line of input) {
    if (!line.trim()) {
      continue;
    }
    scanned += 1;
    const row = JSON.parse(line) as Record<string, unknown>;
    if (row === null || typeof row !== "object" || Array.isArray(row)) {
      throw new Error("Evidence JSONL rows must be objects");
    }
    if (!matchesCommonFilters(row, parameters) || !additionalPredicate(row)) {
      continue;
    }
    matched += 1;
    onMatch(row, matched - 1);
    if (rows.length < resultLimit) {
      rows.push(row);
    }
  }
  return { rows, scanned, matched };
}

function matchesCommonFilters(
  row: Readonly<Record<string, unknown>>,
  parameters: Readonly<Record<string, unknown>>,
): boolean {
  if (parameters.service !== undefined) {
    const service = requireString(parameters.service, "service").toLowerCase();
    const rowService = findString(row, [
      "service",
      "service_name",
      "serviceName",
      "container_name",
    ]).toLowerCase();
    if (rowService && !rowService.includes(service)) {
      return false;
    }
  }
  if (parameters.metric !== undefined) {
    const metric = requireString(parameters.metric, "metric").toLowerCase();
    const rowMetric = findString(row, ["metric", "metric_name", "name"]).toLowerCase();
    if (rowMetric && !rowMetric.includes(metric)) {
      return false;
    }
  }
  const timestamp = findTimestamp(row);
  if (parameters.startTime !== undefined && timestamp < comparable(parameters.startTime)) {
    return false;
  }
  if (parameters.endTime !== undefined && timestamp > comparable(parameters.endTime)) {
    return false;
  }
  return true;
}

function matchesStatusAndDuration(
  row: Readonly<Record<string, unknown>>,
  parameters: Readonly<Record<string, unknown>>,
): boolean {
  if (parameters.status !== undefined) {
    const status = requireString(parameters.status, "status").toLowerCase();
    if (
      !findString(row, ["status", "status_code", "statusCode", "http_status_code"])
        .toLowerCase()
        .includes(status)
    ) {
      return false;
    }
  }
  if (parameters.minimumDuration !== undefined) {
    const threshold = requireNumber(parameters.minimumDuration, "minimumDuration");
    const duration = findNumber(row, ["duration", "duration_ms", "latency", "latency_ms"]);
    if (duration === undefined || duration < threshold) {
      return false;
    }
  }
  return true;
}

async function readMetricColumns(caseRoot: string): Promise<MetricColumnMap> {
  const text = await readFile(resolveInside(caseRoot, "metric-columns.json"), "utf8");
  return validateMetricColumnMap(JSON.parse(text));
}

function metricFilters(
  parameters: Readonly<Record<string, unknown>>,
): Partial<MetricIdentity> {
  return {
    service: parameters.service === undefined
      ? undefined : requireString(parameters.service, "service").toLowerCase(),
    metric: parameters.metric === undefined
      ? undefined : requireString(parameters.metric, "metric").toLowerCase(),
  };
}

function metricValues(
  row: Readonly<Record<string, unknown>>,
  columns: MetricColumnMap,
  filters: Partial<MetricIdentity>,
): readonly (readonly [string, number])[] {
  const narrow = isNarrowMetricRow(row);
  const rowIdentity = {
    service: findString(row, ["service", "service_name", "serviceName", "container_name"]),
    metric: findString(row, ["metric", "metric_name", "name"]),
  };
  const values: [string, number][] = [];
  for (const [field, value] of Object.entries(row)) {
    if (
      METRIC_TIME_FIELDS.some((key) => key === field) ||
      [
        "service", "service_name", "serviceName", "container_name", "metric", "metric_name", "name",
      ].includes(field) ||
      typeof value !== "number" ||
      !Number.isFinite(value)
    ) {
      continue;
    }
    const identity = narrow
      ? rowIdentity
      : Object.hasOwn(columns, field) ? columns[field] : undefined;
    if (identity === undefined) {
      throw new Error(`Missing metric column identity: ${field}`);
    }
    if (
      (filters.service !== undefined && identity.service.trim().toLowerCase() !== filters.service) ||
      (filters.metric !== undefined && identity.metric.trim().toLowerCase() !== filters.metric)
    ) {
      continue;
    }
    values.push([field, value]);
  }
  return values;
}

function aggregateNumeric(
  rows: readonly Readonly<Record<string, unknown>>[],
  columns: MetricColumnMap,
  filters: Partial<MetricIdentity>,
): readonly MetricAggregate[] {
  const values = new Map<string, number[]>();
  for (const row of rows) {
    for (const [field, value] of metricValues(row, columns, filters)) {
      const current = values.get(field) ?? [];
      current.push(value);
      values.set(field, current);
    }
  }
  return [...values.entries()].map(([field, fieldValues]) => ({
    field,
    count: fieldValues.length,
    unit: inferMetricUnit(field),
    minimum: Math.min(...fieldValues),
    maximum: Math.max(...fieldValues),
    average: fieldValues.reduce((sum, value) => sum + value, 0) / fieldValues.length,
  }));
}

interface MetricAggregate {
  readonly field: string;
  readonly count: number;
  readonly unit: string;
  readonly minimum: number;
  readonly maximum: number;
  readonly average: number;
}

function compareMetricAggregates(
  baselineValue: unknown,
  postOnsetValue: unknown,
  limit: number,
): readonly unknown[] {
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 50) {
    throw new Error("limit must be an integer from 1 through 50");
  }
  const baseline = baselineValue as readonly MetricAggregate[];
  const postOnset = postOnsetValue as readonly MetricAggregate[];
  const baselineByField = new Map(baseline.map((item) => [item.field, item]));
  return postOnset
    .filter((item) => baselineByField.has(item.field))
    .map((item) => {
      const before = baselineByField.get(item.field)!;
      const absoluteChange = item.average - before.average;
      const relativeChange =
        before.average === 0 ? null : absoluteChange / Math.abs(before.average);
      return {
        field: item.field,
        unit: item.unit,
        baselineAverage: before.average,
        postOnsetAverage: item.average,
        absoluteChange,
        relativeChange,
        baselineCount: before.count,
        postOnsetCount: item.count,
      };
    })
    .sort((left, right) => {
      const leftRank =
        left.relativeChange === null
          ? Math.abs(left.absoluteChange)
          : Math.abs(left.relativeChange);
      const rightRank =
        right.relativeChange === null
          ? Math.abs(right.absoluteChange)
          : Math.abs(right.relativeChange);
      return rightRank - leftRank;
    })
    .slice(0, limit);
}

function addTraceGroup(groups: Map<string, number>, row: Readonly<Record<string, unknown>>): void {
  const service =
    findString(row, ["service", "service_name", "serviceName", "container_name"]) || "unknown";
  const status =
    findString(row, ["status", "status_code", "statusCode", "http_status_code"]) || "unknown";
  const key = JSON.stringify([service, status]);
  groups.set(key, (groups.get(key) ?? 0) + 1);
}

function renderTraceGroups(groups: ReadonlyMap<string, number>): unknown {
  return [...groups.entries()].map(([key, count]) => {
    const [service, status] = JSON.parse(key) as [string, string];
    return { service, status, count };
  });
}

function result(
  source: EvidenceToolResult["source"],
  rowCount: number,
  matchedRowCount: number,
  truncated: boolean,
  data: unknown,
  sourceComplete: boolean,
): EvidenceToolResult {
  return {
    source,
    rowCount,
    matchedRowCount,
    truncated,
    sourceComplete,
    empty: matchedRowCount === 0,
    availability: "available",
    pageComplete: !truncated,
    data,
  };
}

/**
 * Requires prepared coverage and readable advertised stores; absent modalities alone are unavailable.
 */
async function sourceCoverage(caseRoot: string, source: Modality): Promise<{
  available: boolean;
  complete: boolean;
}> {
  const text = await readFile(resolveInside(caseRoot, "source-coverage.json"), "utf8");
  const coverage = JSON.parse(text) as { sources?: unknown };
  if (!coverage || !Array.isArray(coverage.sources) ||
      coverage.sources.some((item: unknown) =>
        !item || typeof item !== "object" ||
        !["metrics", "logs", "traces"].includes((item as { modality: string }).modality))) {
    throw new Error("Invalid source coverage");
  }
  const entry = coverage.sources.find((item: { modality: string }) => item.modality === source);
  if (entry && ((entry.complete !== undefined && typeof entry.complete !== "boolean") ||
      (entry.truncated !== undefined && typeof entry.truncated !== "boolean"))) {
    throw new Error("Invalid source coverage completeness");
  }
  return {
    available: entry !== undefined,
    complete: entry !== undefined && entry.complete !== false && entry.truncated !== true,
  };
}

function unavailable(source: Modality): EvidenceToolResult {
  return {
    ...result(source, 0, 0, false, {}, false),
    availability: "unavailable",
    availabilityReason: "Source modality is absent from source-coverage.json",
  };
}

function normalizeParameters(
  parameters: Readonly<Record<string, unknown>>,
): Readonly<Record<string, unknown>> {
  return JSON.parse(stableJson(parameters)) as Record<string, unknown>;
}

function requireString(value: unknown, name: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`${name} must be a non-empty string`);
  }
  return value.trim();
}

function requireNumber(value: unknown, name: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`${name} must be a finite number`);
  }
  return value;
}

function requireLimit(value: unknown): number {
  if (value === undefined) {
    return 20;
  }
  if (!Number.isSafeInteger(value) || (value as number) < 1 || (value as number) > MAX_RESULT_ROWS) {
    throw new Error(`limit must be an integer from 1 through ${MAX_RESULT_ROWS}`);
  }
  return value as number;
}

function findString(row: Readonly<Record<string, unknown>>, keys: readonly string[]): string {
  for (const key of keys) {
    if (typeof row[key] === "string") {
      return row[key];
    }
  }
  return "";
}

function findNumber(
  row: Readonly<Record<string, unknown>>,
  keys: readonly string[],
): number | undefined {
  for (const key of keys) {
    const value = row[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === "string" && value.trim() && Number.isFinite(Number(value))) {
      return Number(value);
    }
  }
  return undefined;
}

function findTimestamp(row: Readonly<Record<string, unknown>>): number {
  for (const key of METRIC_TIME_FIELDS) {
    if (row[key] !== undefined) {
      return comparable(row[key]);
    }
  }
  return Number.NEGATIVE_INFINITY;
}

function comparable(value: unknown): number {
  const parsed = timeValue(value);
  if (parsed !== undefined) return parsed;
  throw new Error(`Invalid time value: ${String(value)}`);
}

function timeValue(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
      return numeric;
    }
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return undefined;
}

function objectSchema(
  properties: Readonly<Record<string, unknown>>,
  required: readonly string[] = [],
): Readonly<Record<string, unknown>> {
  return { type: "object", additionalProperties: false, properties, required };
}

function scalarSchema(): Readonly<Record<string, unknown>> {
  return { description: TIME_WINDOW_CONSTRAINT, anyOf: [
    { type: "number" },
    {
      type: "string", minLength: 1, maxLength: 64,
      pattern: "^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$",
    },
  ] };
}

function filterSchema(maxLength: number): Readonly<Record<string, unknown>> {
  return {
    type: "string", minLength: 1, maxLength, pattern: "\\S",
    description: "Use a non-empty string containing at least one non-whitespace character.",
  };
}

function cursorSchema(): Readonly<Record<string, unknown>> {
  return {
    type: "string", minLength: 64, maxLength: 64, pattern: "^[0-9a-f]{64}$",
    description: "Copy nextCursor unchanged from the same tool, case and exact query. The first 16 hex digits encode a positive safe-integer offset; the rest bind the cursor to its query.",
  };
}

function inferMetricUnit(field: string): string {
  const normalized = field.toLowerCase();
  if (normalized.endsWith("_cpu")) {
    return "percent";
  }
  if (normalized.endsWith("_mem") || normalized.includes("memory")) {
    return "bytes";
  }
  if (normalized.includes("latency")) {
    return "seconds";
  }
  if (normalized.includes("duration")) {
    return "source-defined duration unit";
  }
  if (normalized.endsWith("_load") || normalized.endsWith("_error")) {
    return "count";
  }
  return "source-defined";
}

function requireTimeWindow(parameters: Readonly<Record<string, unknown>>): {
  readonly startTime: number;
  readonly endTime: number;
  readonly unit: "epoch seconds" | "epoch milliseconds";
} {
  const startTime = Number(parameters.startTime);
  const endTime = Number(parameters.endTime);
  if (!Number.isFinite(startTime) || !Number.isFinite(endTime)) {
    throw new EvidenceRequestError("invalid-time-window", "Time values must be finite epoch numbers or numeric strings");
  }
  if (endTime <= startTime) {
    throw new EvidenceRequestError("invalid-time-window", "endTime must be greater than startTime");
  }
  if ((startTime > 100_000_000_000) !== (endTime > 100_000_000_000)) {
    throw new EvidenceRequestError("invalid-time-window", "startTime and endTime must use matching epoch units");
  }
  const unit = startTime > 100_000_000_000 ? "epoch milliseconds" : "epoch seconds";
  const error = windowSpanError(startTime, endTime);
  if (error) throw error;
  return { startTime, endTime, unit };
}

function windowSpanError(startTime: number, endTime: number): EvidenceWindowLimitError | undefined {
  const milliseconds = startTime > 100_000_000_000;
  const maximumSpan = MAX_TIME_WINDOW_SECONDS * (milliseconds ? 1000 : 1);
  if (endTime - startTime > maximumSpan) {
    return new EvidenceWindowLimitError(maximumSpan, milliseconds ? "millisecond" : "second");
  }
  return undefined;
}
