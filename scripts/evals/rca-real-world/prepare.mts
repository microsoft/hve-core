// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createReadStream } from "node:fs";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join, relative } from "node:path";
import { pathToFileURL } from "node:url";
import { zstdDecompressSync } from "node:zlib";

import {
  TRANSFORMATION_VERSION,
  EVALUATION_CASE_IDS,
  type CaseContract,
  type EvaluationContract,
  type Modality,
  type PreparedCaseManifest,
  type SourceFileContract,
  gitBlobObjectId,
  readJson,
  resolveInside,
  sha256,
  stableJson,
  validateContract,
  writeJson,
} from "./contracts.mts";
import { buildMetricColumnMap, validateMetricColumnMap } from "./metric-schema.mts";

interface HuggingFaceTreeItem {
  readonly type: "file";
  readonly oid: string;
  readonly size: number;
  readonly path: string;
  readonly lfs?: {
    readonly oid: string;
    readonly size: number;
  };
}

interface ParquetModule {
  readonly asyncBufferFromFile: (path: string) => Promise<unknown>;
  readonly parquetReadObjects: (options: {
    readonly file: unknown;
    readonly compressors: Readonly<Record<string, (bytes: Uint8Array) => Uint8Array>>;
  }) => Promise<Record<string, unknown>[]>;
}

export interface PreparationOptions {
  readonly repositoryRoot: string;
  readonly runId: string;
  readonly retrievedAt?: string;
  readonly fetchImpl?: typeof fetch;
  readonly parquetReader?: (path: string) => Promise<readonly Record<string, unknown>[]>;
  readonly parquetReaderIdentity?: string;
}

export interface PreparationResult {
  readonly runRoot: string;
  readonly modelVisibleRoot: string;
  readonly scorerOnlyRoot: string;
  readonly manifestPath: string;
}

export interface PreparedRunCheck {
  readonly runRoot: string;
  readonly sourceRevision: string;
  readonly cases: readonly {
    readonly neutralId: string;
    readonly modalities: readonly { readonly modality: Modality; readonly rowCount: number }[];
  }[];
}

const DATASET_ID = "phamquiluan/RCAEval";
const HUGGING_FACE_BASE = `https://huggingface.co/datasets/${DATASET_ID}`;
const HUGGING_FACE_API = `https://huggingface.co/api/datasets/${DATASET_ID}`;
const RUN_ID_PATTERN = /^[a-z0-9][a-z0-9-]{2,63}$/;
const PARQUET_BUNDLE_URL = "https://esm.sh/hyparquet@1.31.5/node/hyparquet.bundle.mjs";
const PARQUET_BUNDLE_SHA256 = "fdd28364b0dde800dea00979cbd3ddee26a053bb0d15b17820e0f865b9ab8178";
const PARQUET_READER_IDENTITY = `hyparquet@1.31.5:${PARQUET_BUNDLE_SHA256}`;

/**
 * Prepares three neutral RCAEval workspaces and held-out scoring manifests.
 *
 * The run directory must not already exist. Source files are downloaded only below the
 * scorer-only root, verified against the committed contract, transformed into deterministic
 * JSONL stores, and excluded from the model-visible workspaces.
 */
export async function prepareCases(options: PreparationOptions): Promise<PreparationResult> {
  if (!RUN_ID_PATTERN.test(options.runId)) {
    throw new Error("runId must be 3-64 lower-case letters, digits, or hyphens");
  }

  const contractPath = join(options.repositoryRoot, "evals", "rca-real-world", "cases.json");
  const contract = await readJson<EvaluationContract>(contractPath);
  const orderedCases = validateContract(contract);
  const evaluationsRoot = join(
    options.repositoryRoot,
    ".copilot-tracking",
    "evaluations",
    "rcaeval-three-case",
  );
  const runRoot = resolveInside(evaluationsRoot, options.runId);
  const modelVisibleRoot = resolveInside(runRoot, "inputs/model-visible");
  const scorerOnlyRoot = resolveInside(runRoot, "inputs/scorer-only");

  const ownedParquetReader =
    options.parquetReader === undefined ? await createPinnedParquetReader(options.fetchImpl ?? fetch) : undefined;
  try {
    await stat(runRoot);
    throw new Error(`Run directory already exists: ${options.runId}`);
  } catch (error) {
    if (error instanceof Error && !("code" in error && error.code === "ENOENT")) {
      throw error;
    }
  }

  await mkdir(modelVisibleRoot, { recursive: true });
  await mkdir(scorerOnlyRoot, { recursive: true });

  try {
    const fetchImpl = options.fetchImpl ?? fetch;
    const retrievedAt = options.retrievedAt ?? new Date().toISOString();
    await verifyLicense(contract, fetchImpl);
    const indexPath = await downloadAndVerify(
      fetchImpl,
      contract.source.revision,
      "",
      {
        name: contract.source.caseIndex.path,
        objectId: "0".repeat(40),
        sha256: contract.source.caseIndex.sha256,
        size: contract.source.caseIndex.size,
      },
      scorerOnlyRoot,
      false,
    );
    const parquetReader = options.parquetReader ?? ownedParquetReader!.read;
    const indexRows = await parquetReader(indexPath);
    const sourceIdentities: unknown[] = [];
    const preparedCases: PreparedCaseManifest[] = [];

    for (const caseContract of orderedCases) {
      const result = await prepareCase({
        caseContract,
        contract,
        fetchImpl,
        indexRows,
        modelVisibleRoot,
        parquetReader,
        scorerOnlyRoot,
      });
      sourceIdentities.push(...result.sourceIdentities);
      preparedCases.push(result.prepared);
    }

    const manifest = {
      schemaVersion: "1.0.0",
      runId: options.runId,
      dataset: contract.source.dataset,
      sourceRevision: contract.source.revision,
      sourceLicense: contract.source.license,
      retrievedAt,
      transformationVersion: TRANSFORMATION_VERSION,
      parquetReader: options.parquetReaderIdentity ?? PARQUET_READER_IDENTITY,
      sourceIdentities,
      cases: preparedCases,
    };
    const manifestPath = join(scorerOnlyRoot, "preparation-manifest.json");
    await writeJson(manifestPath, manifest);
    await assertBlindness(modelVisibleRoot, orderedCases);

    return { runRoot, modelVisibleRoot, scorerOnlyRoot, manifestPath };
  } catch (error) {
    await rm(runRoot, { recursive: true, force: true });
    throw error;
  } finally {
    await ownedParquetReader?.dispose();
  }
}

/** Verifies an existing prepared run without downloading source data or loading the Parquet reader. */
export async function verifyPreparedRun(
  repositoryRoot: string,
  runId: string,
): Promise<PreparedRunCheck> {
  if (!RUN_ID_PATTERN.test(runId)) {
    throw new Error("runId must be 3-64 lower-case letters, digits, or hyphens");
  }
  const runRoot = join(
    repositoryRoot,
    ".copilot-tracking",
    "evaluations",
    "rcaeval-three-case",
    runId,
  );
  const manifest = await readJson<{
    sourceRevision: string;
    transformationVersion: string;
    cases: readonly PreparedCaseManifest[];
  }>(join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"));
  if (
    manifest.sourceRevision !== "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e" ||
    manifest.transformationVersion !== TRANSFORMATION_VERSION ||
    manifest.cases.length !== EVALUATION_CASE_IDS.length
  ) {
    throw new Error("Prepared run does not match the pinned evaluation contract");
  }
  for (const preparedCase of manifest.cases) {
    const mapping = await readFile(resolveInside(
      join(runRoot, "inputs", "model-visible", preparedCase.neutralId),
      "metric-columns.json",
    ), "utf8");
    validateMetricColumnMap(JSON.parse(mapping));
    if (sha256(mapping) !== preparedCase.metricColumnsSha256) {
      throw new Error(`Metric column mapping integrity mismatch: ${preparedCase.neutralId}`);
    }
    for (const modality of preparedCase.modalities) {
      const storePath = resolveInside(
        join(runRoot, "inputs", "model-visible", preparedCase.neutralId),
        modality.storePath,
      );
      const actual = await hashAndCountLines(storePath);
      if (actual.sha256 !== modality.sha256 || actual.rowCount !== modality.rowCount) {
        throw new Error(
          `Prepared store integrity mismatch: ${preparedCase.neutralId}/${modality.modality}`,
        );
      }
    }
  }
  return {
    runRoot,
    sourceRevision: manifest.sourceRevision,
    cases: manifest.cases.map((item) => ({
      neutralId: item.neutralId,
      modalities: item.modalities.map(({ modality, rowCount }) => ({ modality, rowCount })),
    })),
  };
}

async function prepareCase(options: {
  readonly caseContract: CaseContract;
  readonly contract: EvaluationContract;
  readonly fetchImpl: typeof fetch;
  readonly indexRows: readonly Record<string, unknown>[];
  readonly modelVisibleRoot: string;
  readonly parquetReader: (path: string) => Promise<readonly Record<string, unknown>[]>;
  readonly scorerOnlyRoot: string;
}): Promise<{
  readonly sourceIdentities: readonly unknown[];
  readonly prepared: PreparedCaseManifest;
}> {
  const { caseContract } = options;
  const tree = await fetchTree(options.fetchImpl, options.contract.source.revision, caseContract);
  const rawCaseRoot = resolveInside(options.scorerOnlyRoot, `downloads/${caseContract.neutralId}`);
  const visibleCaseRoot = resolveInside(options.modelVisibleRoot, caseContract.neutralId);
  await mkdir(rawCaseRoot, { recursive: true });
  await mkdir(visibleCaseRoot, { recursive: true });

  const sourceIdentities: unknown[] = [];
  const downloaded = new Map<string, string>();
  for (const expected of caseContract.files) {
    const remote = tree.find((item) => basename(item.path) === expected.name);
    if (!remote) {
      throw new Error(`Missing source file ${caseContract.neutralId}/${expected.name}`);
    }
    const actualHash = remote.lfs?.oid;
    if (
      remote.oid !== expected.objectId ||
      remote.size !== expected.size ||
      (actualHash !== undefined && actualHash !== expected.sha256)
    ) {
      throw new Error(`Source identity drift for ${caseContract.neutralId}/${expected.name}`);
    }
    const path = await downloadAndVerify(
      options.fetchImpl,
      options.contract.source.revision,
      caseContract.sourcePath,
      expected,
      rawCaseRoot,
    );
    downloaded.set(expected.name, path);
    sourceIdentities.push({
      neutralId: caseContract.neutralId,
      sourcePath: `${caseContract.sourcePath}/${expected.name}`,
      objectId: remote.oid,
      sha256: expected.sha256,
      size: expected.size,
    });
  }

  const injectionTime = (await readFile(requireDownloaded(downloaded, "inject_time.txt"), "utf8")).trim();
  if (!/^\d{10,16}$/.test(injectionTime)) {
    throw new Error(`Invalid injection time for ${caseContract.neutralId}`);
  }

  const modalities = [];
  let metricColumnsSha256: string | undefined;
  for (const modality of caseContract.modalities) {
    const sourcePath = requireDownloaded(downloaded, `${modality}.parquet`);
    const rows = await options.parquetReader(sourcePath);
    if (rows.length === 0) {
      throw new Error(`Empty ${modality} evidence for ${caseContract.neutralId}`);
    }
    if (modality === "metrics") {
      const mapping = stableJson(buildMetricColumnMap(rows));
      await writeFile(join(visibleCaseRoot, "metric-columns.json"), mapping, "utf8");
      metricColumnsSha256 = sha256(mapping);
    }
    const storeName = `${modality}.jsonl`;
    const storePath = resolveInside(visibleCaseRoot, storeName);
    const content = rows.map((row) => JSON.stringify(normalizeRow(row))).join("\n") + "\n";
    await writeFile(storePath, content, "utf8");
    modalities.push({
      modality,
      rowCount: rows.length,
      storePath: storeName,
      sha256: sha256(content),
    });
  }

  const truth = extractTruth(options.indexRows, caseContract);
  await mkdir(resolveInside(options.scorerOnlyRoot, "truth"), { recursive: true });
  await writeJson(resolveInside(options.scorerOnlyRoot, `truth/${caseContract.neutralId}.json`), {
    neutralId: caseContract.neutralId,
    sourcePath: caseContract.sourcePath,
    ...truth,
  });

  if (metricColumnsSha256 === undefined) {
    throw new Error(`Missing metric column mapping: ${caseContract.neutralId}`);
  }
  const prepared = {
    neutralId: caseContract.neutralId, injectionTime, modalities, metricColumnsSha256,
  };
  await writeJson(join(visibleCaseRoot, "incident.json"), {
    schemaVersion: "1.0.0",
    caseId: caseContract.neutralId,
    incidentOnset: injectionTime,
    availableSources: modalities.map(({ modality, rowCount }) => ({ modality, rowCount })),
    statisticalUnitNote:
      "Rows are dependent time-series observations from one injected incident, not independent cohort units.",
  });
  await writeJson(join(visibleCaseRoot, "source-coverage.json"), {
    caseId: caseContract.neutralId,
    sources: modalities.map(({ modality, rowCount, sha256: digest }) => ({
      modality,
      rowCount,
      contentSha256: digest,
      complete: true,
      truncated: false,
    })),
  });

  return { sourceIdentities, prepared };
}

async function verifyLicense(contract: EvaluationContract, fetchImpl: typeof fetch): Promise<void> {
  const url = `${HUGGING_FACE_BASE}/resolve/${contract.source.revision}/${contract.source.licenseCard.path}`;
  const response = await fetchImpl(url);
  if (!response.ok) {
    throw new Error(`Unable to retrieve source license card: HTTP ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (gitBlobObjectId(bytes) !== contract.source.licenseCard.objectId) {
    throw new Error("Pinned dataset card object identity changed");
  }
  const text = Buffer.from(bytes).toString("utf8");
  if (!/^license:\s*mit\s*$/im.test(text)) {
    throw new Error("Pinned dataset card does not declare the MIT license");
  }
}

async function fetchTree(
  fetchImpl: typeof fetch,
  revision: string,
  caseContract: CaseContract,
): Promise<readonly HuggingFaceTreeItem[]> {
  const url = `${HUGGING_FACE_API}/tree/${revision}/${caseContract.sourcePath}?recursive=true&expand=true`;
  const response = await fetchImpl(url);
  if (!response.ok) {
    throw new Error(`Unable to retrieve ${caseContract.neutralId} source metadata: HTTP ${response.status}`);
  }
  const value = (await response.json()) as unknown;
  if (
    !Array.isArray(value) ||
    value.some(
      (item) =>
        item === null ||
        typeof item !== "object" ||
        (item as { type?: unknown }).type !== "file" ||
        typeof (item as { oid?: unknown }).oid !== "string",
    )
  ) {
    throw new Error(`Malformed source metadata for ${caseContract.neutralId}`);
  }
  return value as HuggingFaceTreeItem[];
}

async function downloadAndVerify(
  fetchImpl: typeof fetch,
  revision: string,
  sourcePath: string,
  expected: SourceFileContract,
  outputRoot: string,
  includeSourcePath = true,
): Promise<string> {
  const remotePath = includeSourcePath ? `${sourcePath}/${expected.name}` : expected.name;
  const response = await fetchImpl(`${HUGGING_FACE_BASE}/resolve/${revision}/${remotePath}?download=true`);
  if (!response.ok) {
    throw new Error(`Unable to download ${remotePath}: HTTP ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength !== expected.size || sha256(bytes) !== expected.sha256) {
    throw new Error(`Downloaded content mismatch for ${remotePath}`);
  }
  const outputPath = resolveInside(outputRoot, expected.name);
  await writeFile(outputPath, bytes);
  return outputPath;
}

async function createPinnedParquetReader(fetchImpl: typeof fetch): Promise<{
  readonly read: (path: string) => Promise<readonly Record<string, unknown>[]>;
  readonly dispose: () => Promise<void>;
}> {
  const response = await fetchImpl(PARQUET_BUNDLE_URL);
  if (!response.ok) {
    throw new Error(`Unable to retrieve pinned Parquet reader: HTTP ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (sha256(bytes) !== PARQUET_BUNDLE_SHA256) {
    throw new Error("Pinned Parquet reader bundle failed SHA-256 verification");
  }
  const directory = await mkdtemp(join(tmpdir(), "hve-rca-parquet-"));
  const bundlePath = join(directory, "hyparquet-1.31.5.mjs");
  await writeFile(bundlePath, bytes);
  const parquet = (await import(pathToFileURL(bundlePath).href)) as ParquetModule;
  return {
    read: async (path) => {
      const file = await parquet.asyncBufferFromFile(path);
      return parquet.parquetReadObjects({
        file,
        compressors: {
          ZSTD: (compressed) => new Uint8Array(zstdDecompressSync(compressed)),
        },
      });
    },
    dispose: () => rm(directory, { recursive: true, force: true }),
  };
}

function extractTruth(
  indexRows: readonly Record<string, unknown>[],
  caseContract: CaseContract,
): {
  readonly rootCauseService: string;
  readonly fault: string;
  readonly compatibleMechanism: string;
  readonly indexRecord: Record<string, unknown>;
} {
  const record = indexRows.find((row) =>
    Object.values(row).some((value) => value === caseContract.sourcePath),
  );
  if (!record) {
    throw new Error(`Selected case is absent from the pinned case index: ${caseContract.neutralId}`);
  }
  const rootCauseService = firstString(record, [
    "root_cause_service",
    "rootCauseService",
    "service",
  ]);
  const fault = firstString(record, ["fault", "root_cause", "rootCause", "failure_type"]);
  if (!rootCauseService || !fault) {
    throw new Error(`Case index lacks held-out labels for ${caseContract.neutralId}`);
  }
  return {
    rootCauseService,
    fault,
    compatibleMechanism: mechanismFor(fault),
    indexRecord: record,
  };
}

function firstString(record: Record<string, unknown>, names: readonly string[]): string | undefined {
  for (const name of names) {
    const value = record[name];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return undefined;
}

function mechanismFor(fault: string): string {
  const normalized = fault.toLowerCase();
  if (normalized.includes("cpu")) {
    return "Abnormal CPU consumption or saturation in the held-out service.";
  }
  if (normalized.includes("delay") || normalized.includes("latency")) {
    return "Injected processing or request delay in the held-out service.";
  }
  if (normalized.includes("loss")) {
    return "Injected network packet loss affecting the held-out service.";
  }
  return `A code-level condition compatible with the held-out ${fault} fault.`;
}

async function hashAndCountLines(path: string): Promise<{ sha256: string; rowCount: number }> {
  const hash = createHash("sha256");
  let rowCount = 0;
  let trailing = "";
  for await (const chunk of createReadStream(path)) {
    hash.update(chunk);
    const text = trailing + chunk.toString("utf8");
    const lines = text.split("\n");
    trailing = lines.pop() ?? "";
    rowCount += lines.filter((line) => line.length > 0).length;
  }
  if (trailing.length > 0) {
    rowCount += 1;
  }
  return { sha256: hash.digest("hex"), rowCount };
}

function normalizeRow(row: Record<string, unknown>): Record<string, unknown> {
  return JSON.parse(stableJson(row)) as Record<string, unknown>;
}

function requireDownloaded(downloaded: ReadonlyMap<string, string>, name: string): string {
  const path = downloaded.get(name);
  if (!path) {
    throw new Error(`Required downloaded file is unavailable: ${name}`);
  }
  return path;
}

/**
 * Checks answer-bearing model-visible metadata without treating genuine telemetry service names
 * as leakage.
 */
export async function assertBlindness(
  modelVisibleRoot: string,
  cases: readonly CaseContract[],
): Promise<void> {
  const forbidden = [
    ...cases.map((item) => item.sourcePath.toLowerCase()),
    "root_cause_service",
    "rootcauseservice",
    "root_cause.txt",
    "expected_answer",
  ];
  for (const item of cases) {
    const caseRoot = resolveInside(modelVisibleRoot, item.neutralId);
    for (const name of ["incident.json", "source-coverage.json", "metric-columns.json"]) {
      const path = resolveInside(caseRoot, name);
      const text = (await readFile(path, "utf8")).toLowerCase();
      const relativePath = relative(modelVisibleRoot, path).toLowerCase();
      for (const token of forbidden) {
        if (relativePath.includes(token) || text.includes(token)) {
          throw new Error(`Ground-truth leakage detected in ${relativePath}`);
        }
      }
    }
  }
}
