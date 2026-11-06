// Copyright (c) Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { constants } from "node:fs";
import { lstat, open, readdir, realpath } from "node:fs/promises";
import { join, relative, resolve } from "node:path";
import { createInterface } from "node:readline";
import { COMMUNICATION_LIMITS, sha256, stableJson } from "./contracts.mts";
import {
  EvidenceRequestError, validateEvidenceParameters,
  type ApprovalConsumer, type EvidenceToolResult, type EvidenceToolTrace, type ToolDefinition,
} from "./evidence-tools.mts";

export const RAW_EVIDENCE_OPERATIONS = { list_files: "list", read_file: "read", query_jsonl: "query" } as const;
const FILE = /^(incident\.json|(metrics|logs|traces)\.jsonl)$/;
const integer = (minimum: number, maximum: number) => ({ type: "integer", minimum, maximum });
const text = (description: string, maximum = 4096) => ({ type: "string", minLength: 1, maxLength: maximum, description });
const schemas: Record<string, ToolDefinition["parameters"]> = {
  list_files: { type: "object", additionalProperties: false, required: [], properties: {} },
  read_file: {
    type: "object", additionalProperties: false, required: ["path"],
    properties: {
      path: text("Exact listed filename, no directories.", 32),
      offset: integer(0, Number.MAX_SAFE_INTEGER), length: integer(1, 8192),
    },
  },
  query_jsonl: {
    type: "object", additionalProperties: false, required: ["path"],
    properties: {
      path: text("Exact listed .jsonl filename.", 32),
      filters: text('JSON array of AND predicates, e.g. [{"field":"timestamp","op":"gte","value":1700000000}]. Operators: eq,ne,contains,gt,gte,lt,lte. Exact original top-level fields; no metric normalization.'),
      columns: text('JSON array of up to 32 original fields to project (rows) or summarize numerically (summary), e.g. ["timestamp","cpu"]. Omit for all fields.', 8192),
      mode: text('rows (default), or summary: count and numeric min/max/mean by original field; computed only for this query.', 16),
      groupBy: text("Optional original field for summary groups. No inferred service/metric identities.", 256),
      limit: integer(1, COMMUNICATION_LIMITS.resultRows),
      cursor: { ...text("Copy the previous nextCursor with otherwise identical parameters.", 81), pattern: "^[0-9a-f]{16}\\.[0-9a-f]{64}$" },
    },
  },
};

interface Filter { field: string; op: string; value: string | number | boolean | null }
interface Query { filters: readonly Filter[]; columns?: readonly string[]; mode: "rows" | "summary" }

function invalid(message: string): never { throw new EvidenceRequestError("invalid-tool-parameters", message); }
function parseQuery(parameters: Readonly<Record<string, unknown>>): Query {
  const mode = parameters.mode ?? "rows";
  if (mode !== "rows" && mode !== "summary") invalid("mode must be rows or summary");
  if (parameters.groupBy !== undefined && mode !== "summary") invalid("groupBy requires summary mode");
  let filters: unknown;
  let columns: unknown;
  try {
    filters = JSON.parse(String(parameters.filters ?? "[]"));
    columns = parameters.columns === undefined ? undefined : JSON.parse(String(parameters.columns));
  } catch { invalid("filters and columns must be valid JSON arrays"); }
  if (!Array.isArray(filters) || filters.length > 12 || filters.some((item: unknown) =>
    !record(item) || Object.keys(item).sort().join(",") !== "field,op,value" ||
    typeof item.field !== "string" || !item.field.length || item.field.length > 256 ||
    !["eq", "ne", "contains", "gt", "gte", "lt", "lte"].includes(String(item.op)) ||
    !(item.value === null || typeof item.value === "string" || typeof item.value === "boolean" ||
      typeof item.value === "number" && Number.isFinite(item.value)) ||
    item.op === "contains" && typeof item.value !== "string" ||
    ["gt", "gte", "lt", "lte"].includes(String(item.op)) && numeric(item.value) === undefined)) {
    invalid("filters must contain at most 12 exact field/op/scalar-value predicates; ranges require finite numbers or safe numeric strings");
  }
  if (columns !== undefined && (!Array.isArray(columns) || !columns.length || columns.length > 32 ||
      columns.some((field: unknown) => typeof field !== "string" || !field.length || field.length > 256) ||
      new Set(columns).size !== columns.length)) invalid("columns must contain 1-32 unique original field names");
  return { mode, filters: filters as Filter[], columns: columns as string[] | undefined };
}

/** Replays the complete parameter contract without file access or approval consumption. */
export function rawEvidenceRequestError(tool: string, parameters: Readonly<Record<string, unknown>>): EvidenceRequestError | undefined {
  if (!Object.hasOwn(schemas, tool)) return undefined;
  try {
    if (!record(parameters)) invalid("Parameters must be an object");
    validateEvidenceParameters({ name: tool, description: "", parameters: schemas[tool]!, handler: async () => "" }, parameters);
    if (tool !== "list_files" && (typeof parameters.path !== "string" || !FILE.test(parameters.path))) invalid("path must be an exact neutral JSONL or incident filename");
    if (tool === "query_jsonl") {
      if (!String(parameters.path).endsWith(".jsonl")) invalid("query_jsonl requires a JSONL file");
      parseQuery(parameters);
    }
    return undefined;
  } catch (error) {
    if (error instanceof EvidenceRequestError) return error;
    throw error;
  }
}

/** Fixed trusted JSONL operations shared by both conditions; never evaluates code, starts processes or normalizes metric identities. */
export function createRawEvidenceTools(options: {
  readonly caseRoot: string; readonly ledger: ApprovalConsumer; readonly clock?: () => Date;
}): { readonly tools: readonly ToolDefinition[]; readonly traces: EvidenceToolTrace[] } {
  const traces: EvidenceToolTrace[] = [];
  const clock = options.clock ?? (() => new Date());
  let calls = 0;
  const tools = Object.entries(RAW_EVIDENCE_OPERATIONS).map(([name, operation]): ToolDefinition => ({
    name, parameters: schemas[name]!,
    description: name === "list_files" ? "List all neutral JSONL files and byte sizes, without schema or metric mappings."
      : name === "read_file" ? "Read up to 8192 UTF-8 bytes for file/field inspection; continue at data.nextOffset. Byte offsets may split UTF-8 characters; at/beyond EOF returns empty content."
      : "Scan JSONL with exact original-field predicates, optional projection, or generic numeric summaries. Numeric strings are supported only within safe integer precision. Full scans have a 30-second deadline. Up to 100 result rows and 64 KiB; paginate with nextCursor and identical parameters. No SQL, Python, shell, inferred identities, or arbitrary code. Summary rows identify original field names, numeric/non-numeric counts, min/max/mean and optional groups.",
    handler: async (parameters) => {
      const startedAt = clock().toISOString();
      let approvalId: string | undefined;
      try {
        calls = Math.max(calls, traces.length) + 1;
        parameters = structuredClone(parameters);
        approvalId = options.ledger.consume(name, operation, parameters);
        if (calls > COMMUNICATION_LIMITS.evidenceCalls) throw new Error("Evidence call limit exceeded");
        const error = rawEvidenceRequestError(name, parameters);
        if (error) throw error;
        const root = resolve(options.caseRoot);
        if (!(await lstat(root)).isDirectory() || (await lstat(root)).isSymbolicLink()) throw new Error("Raw case root must be an ordinary directory");
        const canonical = await realpath(root);
        const files = [];
        for (const filename of (await readdir(root)).sort()) {
          if (!FILE.test(filename)) throw new Error("Raw case contains unsupported files or metric mappings");
          const path = join(root, filename);
          const info = await lstat(path);
          if (!info.isFile() || info.isSymbolicLink() || info.nlink !== 1 || relative(canonical, await realpath(path)) !== filename) throw new Error("Raw case files must be ordinary contained files");
          files.push({ path: filename, bytes: info.size });
        }
        if (!files.some((file) => file.path === "incident.json")) throw new Error("Raw case lacks incident metadata");
        if (name === "query_jsonl") queryPosition(canonical, parameters);
        let result: EvidenceToolResult;
        const file = files.find((item) => item.path === parameters.path);
        if (name === "list_files") result = envelope(files, files.length, files.length);
        else if (!file) result = { ...envelope([], 0, 0), availability: "unavailable", availabilityReason: "Requested source is not provided for this case", sourceComplete: false };
        else if (name === "read_file") {
          const handle = await open(join(root, file.path), constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
          try {
            const buffer = Buffer.alloc(Number(parameters.length ?? 8192));
            const offset = Number(parameters.offset ?? 0);
            const { bytesRead } = await handle.read(buffer, 0, buffer.length, offset);
            const more = offset + bytesRead < file.bytes;
            result = {
              ...envelope({ path: file.path, offset, fileBytes: file.bytes, bytesRead, content: buffer.subarray(0, bytesRead).toString("utf8"),
                ...(more ? { nextOffset: offset + bytesRead } : {}) }, bytesRead ? 1 : 0, bytesRead ? 1 : 0),
              sourceComplete: offset === 0 && bytesRead === file.bytes, truncated: more, pageComplete: !more,
            };
          } finally { await handle.close(); }
        } else result = await queryJsonl(canonical, file.path, parameters);
        const serialized = stableJson(result);
        if (Buffer.byteLength(serialized, "utf8") > COMMUNICATION_LIMITS.resultBytes) throw new Error("Raw evidence result exceeds the shared byte limit");
        traces.push({ sequence: traces.length + 1, tool: name, operation, normalizedParameters: parameters, approvalId,
          requestId: options.ledger.requestId?.(approvalId), status: "executed", startedAt, completedAt: clock().toISOString(), resultHash: sha256(serialized) });
        return serialized;
      } catch (error) {
        traces.push({ sequence: traces.length + 1, tool: name, operation, normalizedParameters: parameters, approvalId,
          requestId: approvalId ? options.ledger.requestId?.(approvalId) : undefined,
          status: !approvalId ? "blocked" : error instanceof EvidenceRequestError ? "query-error" : "error",
          startedAt, completedAt: clock().toISOString(), error: error instanceof Error ? error.message : String(error),
          ...(error instanceof EvidenceRequestError ? { errorCode: error.code } : {}) });
        throw error;
      }
    },
  }));
  return { tools, traces };
}

function record(value: unknown): value is Record<string, unknown> { return value !== null && typeof value === "object" && !Array.isArray(value); }
function numeric(value: unknown): number | undefined {
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  if (typeof value !== "string" || !/^-?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(value)) return undefined;
  const result = Number(value);
  return Number.isFinite(result) && (!Number.isInteger(result) || Number.isSafeInteger(result)) ? result : undefined;
}
function matches(row: Record<string, unknown>, filter: Filter): boolean {
  if (!Object.hasOwn(row, filter.field)) return false;
  const value = row[filter.field];
  if (filter.op === "eq") return value === filter.value;
  if (filter.op === "ne") return value !== filter.value;
  if (filter.op === "contains") return typeof value === "string" && value.includes(String(filter.value));
  const a = numeric(value), b = numeric(filter.value);
  if (a === undefined || b === undefined) return false;
  return filter.op === "gt" ? a > b : filter.op === "gte" ? a >= b : filter.op === "lt" ? a < b : a <= b;
}
function envelope(data: unknown, rows: number, matched: number): EvidenceToolResult {
  return { source: "incident", rowCount: rows, matchedRowCount: matched, truncated: false, sourceComplete: true,
    empty: matched === 0, availability: "available", pageComplete: true, data };
}

function queryPosition(root: string, parameters: Readonly<Record<string, unknown>>): { binding: string; offset: number } {
  const { cursor, ...exact } = parameters;
  const binding = sha256(stableJson({ root, exact }));
  const offset = cursor === undefined ? 0 : Number.parseInt(String(cursor).slice(0, 16), 16);
  if (cursor !== undefined && String(cursor).slice(17) !== binding) throw new Error("Raw cursor case or query binding mismatch");
  return { binding, offset };
}

async function queryJsonl(root: string, filename: string, parameters: Readonly<Record<string, unknown>>): Promise<EvidenceToolResult & {
  readonly scannedRows: number; readonly matchedSourceRows: number;
}> {
  const query = parseQuery(parameters);
  const { binding, offset } = queryPosition(root, parameters);
  const limit = Number(parameters.limit ?? COMMUNICATION_LIMITS.resultRows);
  const data: unknown[] = [];
  let matched = 0, lineNumber = 0, bytes = 0, summaryCells = 0;
  // Retain a bounded prefix plus one overflow candidate; size complete envelopes after the scan.
  const add = (value: unknown, index: number) => {
    if (index < offset || data.length >= limit || bytes > COMMUNICATION_LIMITS.resultBytes) return;
    data.push(value);
    bytes += Buffer.byteLength(stableJson(value), "utf8");
  };
  type Stats = { count: number; numericCount: number; nonNumericCount: number; min: number | null; max: number | null; mean: number | null };
  const groups = new Map<string, { group: unknown; rows: number; stats: Map<string, Stats> }>();
  const handle = await open(join(root, filename), constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
  const stream = handle.createReadStream({ autoClose: false });
  const lines = createInterface({ input: stream, crlfDelay: Infinity });
  const deadline = Date.now() + 30_000;
  try {
    for await (const line of lines) {
      lineNumber++;
      if (Date.now() > deadline) throw new Error("JSONL scan exceeded the 30-second deadline");
      let row: unknown;
      try { row = JSON.parse(line); } catch { throw new Error(`Invalid JSONL at ${filename} line ${lineNumber}`); }
      if (!record(row)) throw new Error(`JSONL row is not an object at ${filename} line ${lineNumber}`);
      if (!query.filters.every((filter) => matches(row, filter))) continue;
      if (query.mode === "rows") {
        add(query.columns ? Object.fromEntries(query.columns.filter((field) => Object.hasOwn(row, field)).map((field) => [field, row[field]])) : row, matched);
      } else {
        const group = parameters.groupBy === undefined ? null
          : { field: parameters.groupBy, missing: !Object.hasOwn(row, String(parameters.groupBy)), value: row[String(parameters.groupBy)] ?? null };
        const key = stableJson(group);
        let entry = groups.get(key);
        if (!entry) {
          if (groups.size >= 1000 || key.length > 4096) throw new Error("JSONL summary exceeds group bounds; narrow filters or groupBy");
          entry = { group, rows: 0, stats: new Map() }; groups.set(key, entry);
        }
        entry.rows++;
        const fields = query.columns ?? Object.keys(row);
        if (fields.length > 1000) throw new Error("JSONL summary exceeds 1000 fields; select columns");
        for (const field of fields) {
          if (!Object.hasOwn(row, field)) continue;
          if (!entry.stats.has(field)) {
            if (entry.stats.size >= 1000 || ++summaryCells > 32_000) throw new Error("JSONL summary exceeds field bounds; select columns or narrow filters");
          }
          const stats = entry.stats.get(field) ?? { count: 0, numericCount: 0, nonNumericCount: 0, min: null, max: null, mean: null };
          stats.count++;
          const value = numeric(row[field]);
          if (value === undefined) stats.nonNumericCount++;
          else {
            stats.numericCount++; stats.min = stats.min === null ? value : Math.min(stats.min, value); stats.max = stats.max === null ? value : Math.max(stats.max, value);
            stats.mean = (stats.mean ?? 0) * ((stats.numericCount - 1) / stats.numericCount) + value / stats.numericCount;
          }
          entry.stats.set(field, stats);
        }
      }
      matched++;
    }
  } finally { lines.close(); stream.destroy(); await handle.close(); }
  let total = matched;
  if (query.mode === "summary") {
    total = 0;
    for (const [, entry] of [...groups].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) {
      if (!entry.stats.size) add({ group: entry.group, rows: entry.rows }, total++);
      for (const [field, stats] of [...entry.stats].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) add({ group: entry.group, rows: entry.rows, field, ...stats }, total++);
    }
  }
  if (offset > total) throw new Error("Raw cursor offset exceeds the query result");
  const build = (count: number): EvidenceToolResult & { scannedRows: number; matchedSourceRows: number } => {
    const more = offset + count < total;
    return {
      ...envelope(data.slice(0, count), count, total), empty: matched === 0, truncated: more, pageComplete: !more,
      source: filename === "metrics.jsonl" ? "metrics" : filename === "logs.jsonl" ? "logs" : "traces",
      scannedRows: lineNumber, matchedSourceRows: matched,
      ...(more && count > 0 ? { nextCursor: `${(offset + count).toString(16).padStart(16, "0")}.${binding}` } : {}),
    };
  };
  let count = data.length;
  let result = build(count);
  while (count > 0 && Buffer.byteLength(stableJson(result), "utf8") > COMMUNICATION_LIMITS.resultBytes) {
    result = build(--count);
  }
  if (count === 0 && data.length > 0) {
    return {
      ...result, nonProgress: true,
      oversizedRow: {
        matchOffset: offset, rowBytes: Buffer.byteLength(stableJson(data[0]), "utf8"),
        requiredResultBytes: Buffer.byteLength(stableJson(build(1)), "utf8"),
        reason: "Select fewer columns to fit this row. No evidence was skipped.",
      },
    };
  }
  return result;
}
