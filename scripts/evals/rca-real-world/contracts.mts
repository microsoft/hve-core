// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

export const CASE_SCHEMA_VERSION = "1.0.0";
export const RESULT_SCHEMA_VERSION = "2.0.0";
export const TRANSFORMATION_VERSION = "2.0.0";
export const EVALUATION_RUN_DIRECTORY = "rcaeval-three-case";
export const EXPECTED_MODEL = "gpt-5.6-sol";
export const EXPECTED_REASONING_EFFORT = "medium";
export const EXPECTED_CONTEXT_TIER = "default";
export const EVALUATION_PROTOCOL = "ad-hoc-v3";
export const COMMUNICATION_LIMITS = {
  modelTurns: 8, evidenceCalls: 24, approvalsPerBatch: 12, resultRows: 100,
  resultBytes: 64 * 1024, batchBytes: 256 * 1024, messageBytes: 256 * 1024,
  promptBytes: 512 * 1024, stdoutBytes: 1024 * 1024, stderrBytes: 64 * 1024,
  turnMs: 240_000, sessionMs: 15 * 60 * 1000, aiCredits: 100,
} as const;
export const EVIDENCE_OPERATIONS: Readonly<Record<string, string>> = {
  read_incident_scope: "read", aggregate_metrics: "aggregate", compare_metrics: "compare",
  search_logs: "search", summarize_traces: "summarize",
};

/** Separates harness debugging from production-model evaluation evidence. */
export type EvaluationProfile = "debug" | "production";

/** Returns the fixed model for a profile; reasoning and context settings are shared. */
export function evaluationModel(profile: EvaluationProfile): string {
  return profile === "debug" ? "gpt-5.6-luna" : EXPECTED_MODEL;
}

/** Parses an exact profile name, rejecting unsupported values rather than silently defaulting. */
export function parseEvaluationProfile(value: string): EvaluationProfile {
  if (value !== "debug" && value !== "production") {
    throw new Error(`Unknown evaluation profile: ${value}; expected debug or production`);
  }
  return value;
}
export const EVALUATION_CASE_IDS = [
  "case-01",
  "case-02",
  "case-03",
  "case-04",
  "case-05",
] as const;

export type Modality = "metrics" | "logs" | "traces";

export interface SourceFileContract {
  readonly name: string;
  readonly objectId: string;
  readonly sha256: string;
  readonly size: number;
}

export interface CaseContract {
  readonly neutralId: string;
  readonly sourcePath: string;
  readonly trialOrder: number;
  readonly modalities: readonly Modality[];
  readonly files: readonly SourceFileContract[];
}

export interface EvaluationContract {
  readonly schemaVersion: string;
  readonly source: {
    readonly dataset: string;
    readonly revision: string;
    readonly license: string;
    readonly sourceUrl: string;
    readonly licenseCard: {
      readonly path: string;
      readonly objectId: string;
    };
    readonly caseIndex: {
      readonly path: string;
      readonly sha256: string;
      readonly size: number;
    };
  };
  readonly cases: readonly CaseContract[];
}

export interface SourceIdentity {
  readonly path: string;
  readonly objectId: string;
  readonly sha256: string;
  readonly size: number;
}

export interface PreparedModality {
  readonly modality: Modality;
  readonly rowCount: number;
  readonly storePath: string;
  readonly sha256: string;
}

export interface PreparedCaseManifest {
  readonly neutralId: string;
  readonly injectionTime: string;
  readonly modalities: readonly PreparedModality[];
  readonly metricColumnsSha256: string;
}

/**
 * Compares primitive strings by UTF-16 code units, independently of locale.
 *
 * @throws A `TypeError` when either operand is not a primitive string.
 */
export function compareStrings(left: unknown, right: unknown): -1 | 0 | 1 {
  if (typeof left !== "string" || typeof right !== "string") {
    throw new TypeError("String comparison requires two primitive strings");
  }
  return left < right ? -1 : left > right ? 1 : 0;
}

/**
 * Produces deterministic JSON for hashing and machine-readable artifacts.
 *
 * Object keys are sorted recursively. Dates, byte arrays, and big integers are converted to
 * stable JSON values. Cycles are rejected by `JSON.stringify`.
 */
export function stableJson(value: unknown): string {
  return `${JSON.stringify(normalizeJson(value), null, 2)}\n`;
}

function normalizeJson(value: unknown): unknown {
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value instanceof Uint8Array) {
    return Buffer.from(value).toString("base64");
  }
  if (Array.isArray(value)) {
    return value.map(normalizeJson);
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => compareStrings(left, right))
      .map(([key, nested]) => [key, normalizeJson(nested)]);
    return Object.fromEntries(entries);
  }
  if (typeof value === "number" && !Number.isFinite(value)) {
    return String(value);
  }
  return value;
}

/** Returns a lower-case SHA-256 digest for bytes or UTF-8 text. */
export function sha256(value: Uint8Array | string): string {
  return createHash("sha256").update(value).digest("hex");
}

/** Returns the Git blob object ID for exact file bytes. */
export function gitBlobObjectId(value: Uint8Array): string {
  const header = Buffer.from(`blob ${value.byteLength}\0`, "utf8");
  return createHash("sha1").update(header).update(value).digest("hex");
}

/** Writes deterministic JSON without creating parent directories. */
export async function writeJson(path: string, value: unknown): Promise<void> {
  await writeFile(path, stableJson(value), "utf8");
}

/** Reads and parses a UTF-8 JSON file. */
export async function readJson<T>(path: string): Promise<T> {
  return JSON.parse(await readFile(path, "utf8")) as T;
}

/**
 * Resolves a path below an allowed root.
 *
 * @throws When `candidate` resolves to the root itself or escapes the root.
 */
export function resolveInside(root: string, candidate: string): string {
  const resolvedRoot = resolve(root);
  const resolvedCandidate = resolve(resolvedRoot, candidate);
  const relation = relative(resolvedRoot, resolvedCandidate);
  if (
    relation === "" ||
    relation === ".." ||
    relation.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`) ||
    isAbsolute(relation)
  ) {
    throw new Error(`Path must resolve below the allowed root: ${candidate}`);
  }
  return resolvedCandidate;
}

/**
 * Validates the committed case contract and returns cases in trial order.
 *
 * @throws When required provenance, neutral IDs, ordering, modalities, or source-file identities
 * are malformed.
 */
export function validateContract(contract: EvaluationContract): readonly CaseContract[] {
  if (contract.schemaVersion !== CASE_SCHEMA_VERSION) {
    throw new Error(`Unsupported case schema: ${contract.schemaVersion}`);
  }
  if (!/^[0-9a-f]{40}$/.test(contract.source.revision)) {
    throw new Error("Dataset revision must be a 40-character commit hash");
  }
  if (contract.source.license !== "MIT") {
    throw new Error(`Expected MIT source license, received ${contract.source.license}`);
  }
  if (!/^[0-9a-f]{64}$/.test(contract.source.caseIndex.sha256)) {
    throw new Error("Case index must declare a SHA-256 digest");
  }
  if (contract.cases.length !== EVALUATION_CASE_IDS.length) {
    throw new Error(
      `Expected exactly ${EVALUATION_CASE_IDS.length} cases, received ${contract.cases.length}`,
    );
  }

  const ordered = [...contract.cases].sort((left, right) => left.trialOrder - right.trialOrder);
  for (const [index, item] of ordered.entries()) {
    if (item.neutralId !== EVALUATION_CASE_IDS[index] || item.trialOrder !== index + 1) {
      throw new Error(`Unexpected case mapping at trial order ${index + 1}`);
    }
    if (!/^[a-z0-9][a-z0-9_-]+$/.test(item.sourcePath)) {
      throw new Error(`Invalid source path for ${item.neutralId}`);
    }
    if (item.modalities.length === 0 || new Set(item.modalities).size !== item.modalities.length) {
      throw new Error(`Invalid modalities for ${item.neutralId}`);
    }
    const expectedNames = new Set([
      "inject_time.txt",
      ...item.modalities.map((modality) => `${modality}.parquet`),
    ]);
    const actualNames = new Set(item.files.map((file) => file.name));
    if (
      expectedNames.size !== actualNames.size ||
      [...expectedNames].some((name) => !actualNames.has(name))
    ) {
      throw new Error(`Source file set does not match modalities for ${item.neutralId}`);
    }
    for (const file of item.files) {
      if (
        !/^[0-9a-f]{40}$/.test(file.objectId) ||
        !/^[0-9a-f]{64}$/.test(file.sha256) ||
        !Number.isSafeInteger(file.size) ||
        file.size < 1
      ) {
        throw new Error(`Invalid source identity for ${item.neutralId}/${file.name}`);
      }
    }
  }
  return ordered;
}

/** Returns the fixed round-robin schedule through `rounds` trial rounds. */
export function createSchedule(rounds = 3): readonly { caseId: string; trial: number }[] {
  if (!Number.isSafeInteger(rounds) || rounds < 1 || rounds > 3) {
    throw new RangeError(`rounds must be an integer from 1 through 3, received ${rounds}`);
  }
  const schedule: { caseId: string; trial: number }[] = [];
  for (let trial = 1; trial <= rounds; trial += 1) {
    for (const caseId of EVALUATION_CASE_IDS) {
      schedule.push({ caseId, trial });
    }
  }
  return schedule;
}
