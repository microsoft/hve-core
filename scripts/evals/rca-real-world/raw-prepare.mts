// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { constants } from "node:fs";
import { copyFile, mkdir, open, readFile, readdir, realpath, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname, join, relative, resolve } from "node:path";
import {
  EVALUATION_CASE_IDS, EVALUATION_RUN_DIRECTORY, TRANSFORMATION_VERSION, RAW_EVIDENCE_FORMAT,
  compareStrings, readJson, resolveInside, sha256, stableJson, writeJson,
  type CaseContract, type EvaluationContract, type Modality,
} from "./contracts.mts";
import { createPinnedParquetReader, downloadAndVerify, extractTruth, hashAndCountLines, writeJsonlRows, PARQUET_READER_IDENTITY, type PreparationResult } from "./prepare.mts";

export const DEFAULT_RAW_SELECTION_SEED = "rcaeval-raw-2026-11-05";
const BASE = "https://huggingface.co";
const DATASET = "phamquiluan/RCAEval";
const REVISION = "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e";

/** A reproducible raw cohort; identities and answer-bearing selection records are scorer-only. */
export interface RawSelection {
  readonly algorithm: "sha256-seeded-ranking-v1";
  readonly seed: string;
  readonly eligibleCases: number;
  readonly populationSha256: string;
  readonly excludedSourcePaths: readonly string[];
  readonly selectedSourcePaths: readonly string[];
}

/** Selects five distinct cases without examining telemetry, outcomes, or modality availability. */
export function selectRawCases(
  rows: readonly Record<string, unknown>[], excluded: readonly string[], seed: string,
): RawSelection {
  if (!seed.trim() || seed.length > 256) throw new Error("Raw selection requires a nonempty seed of at most 256 characters");
  const paths = rows.map((row) => row.case ?? row.case_id);
  if (paths.some((path) => typeof path !== "string" || !/^[A-Za-z0-9_-]+$/.test(path))) {
    throw new Error("Case index has a missing or invalid source case path");
  }
  const names = paths.filter((path): path is string => typeof path === "string");
  if (new Set(names).size !== names.length) throw new Error("Case index contains duplicate source case paths");
  const population = names.filter((path) => !excluded.includes(path)).sort(compareStrings);
  if (population.length < 5) throw new Error("Fewer than five additional source cases are eligible");
  const ranked = [...population].sort((a, b) => compareStrings(sha256(`${seed}\0${a}`), sha256(`${seed}\0${b}`)) || compareStrings(a, b));
  return {
    algorithm: "sha256-seeded-ranking-v1", seed, eligibleCases: population.length,
    populationSha256: sha256(stableJson(population)), excludedSourcePaths: [...excluded].sort(compareStrings),
    selectedSourcePaths: ranked.slice(0, 5),
  };
}

/** Downloads verified originals, converts every telemetry row to JSONL, and separates labels without metric mappings. */
export async function prepareRawCases(options: {
  readonly repositoryRoot: string;
  readonly runId: string;
  readonly seed?: string;
  readonly fetchImpl?: typeof fetch;
  readonly indexRows?: readonly Record<string, unknown>[];
  readonly indexBytes?: Uint8Array;
  readonly parquetReader?: (path: string) => Promise<readonly Record<string, unknown>[]>;
}): Promise<PreparationResult> {
  if (!/^[a-z0-9][a-z0-9-]{2,63}$/.test(options.runId)) throw new Error("Invalid raw run ID");
  const contract = await readJson<EvaluationContract>(join(options.repositoryRoot, "evals", "rca-real-world", "cases.json"));
  if (contract.source.dataset !== DATASET || contract.source.revision !== REVISION || contract.source.license !== "MIT" ||
      contract.source.licenseCard.path !== "README.md" || contract.source.caseIndex.path !== "cases.parquet") {
    throw new Error("Raw preparation requires the pinned MIT RCAEval source");
  }
  const runRoot = resolveInside(join(options.repositoryRoot, ".copilot-tracking", "evaluations", EVALUATION_RUN_DIRECTORY), options.runId);
  await mkdir(dirname(runRoot), { recursive: true });
  await mkdir(runRoot);
  const modelVisibleRoot = join(runRoot, "inputs", "model-visible");
  const scorerOnlyRoot = join(runRoot, "inputs", "scorer-only");
  await mkdir(modelVisibleRoot, { recursive: true });
  await mkdir(scorerOnlyRoot, { recursive: true });
  const fetchImpl = options.fetchImpl ?? fetch;
  const license = await downloadAndVerify(fetchImpl, REVISION, "", {
    name: "README.md", objectId: contract.source.licenseCard.objectId,
  }, undefined, false);
  if (!/^license:\s*mit\s*$/im.test(Buffer.from(license).toString("utf8"))) {
    throw new Error("Pinned raw dataset license identity mismatch");
  }
  const indexPath = join(scorerOnlyRoot, "cases.parquet");
  const index = options.indexBytes ?? await downloadAndVerify(fetchImpl, REVISION, "", {
    name: "cases.parquet", size: contract.source.caseIndex.size, sha256: contract.source.caseIndex.sha256,
  }, scorerOnlyRoot, false);
  if (index.byteLength !== contract.source.caseIndex.size || sha256(index) !== contract.source.caseIndex.sha256) {
    throw new Error("Pinned raw case index integrity mismatch");
  }
  if (options.indexBytes !== undefined) await writeFile(indexPath, index);
  let owned: Awaited<ReturnType<typeof createPinnedParquetReader>> | undefined;
  let rows = options.indexRows;
  if (!rows) {
    owned = await createPinnedParquetReader(fetchImpl);
    try { rows = await owned.read(indexPath); } finally { await owned.dispose(); }
  }
  const selection = selectRawCases(rows, contract.cases.map((item) => item.sourcePath), options.seed ?? DEFAULT_RAW_SELECTION_SEED);
  const cases: { neutralId: string; injectionTime: string; files: { name: string; sha256: string; size: number }[] }[] = [];
  const sourceCases: CaseContract[] = [];
  for (const [position, neutralId] of EVALUATION_CASE_IDS.entries()) {
    const sourcePath = selection.selectedSourcePaths[position]!;
    if (!/^[A-Za-z0-9_-]+$/.test(sourcePath)) throw new Error("Invalid raw source case path");
    const response = await fetchImpl(`${BASE}/api/datasets/${DATASET}/tree/${REVISION}/${sourcePath}?recursive=true&expand=true`);
    if (!response.ok) throw new Error(`Raw source metadata unavailable: ${neutralId}, HTTP ${response.status}`);
    const treeResponse: unknown = await response.json();
    if (!Array.isArray(treeResponse)) throw new Error(`Invalid raw source metadata: ${neutralId}`);
    const tree: readonly unknown[] = treeResponse;
    const visible = join(modelVisibleRoot, neutralId);
    const originals = join(scorerOnlyRoot, "downloads", neutralId);
    await mkdir(visible);
    await mkdir(originals, { recursive: true });
    const files: CaseContract["files"][number][] = [];
    const modalities: Modality[] = [];
    let injectionTime: string | undefined;
    for (const name of ["inject_time.txt", "metrics.parquet", "logs.parquet", "traces.parquet"] as const) {
      const entries = tree.filter((entry): entry is Record<string, unknown> =>
        entry !== null && typeof entry === "object" && "type" in entry && entry.type === "file" &&
        "path" in entry && entry.path === `${sourcePath}/${name}`);
      if (entries.length > 1) throw new Error(`Duplicate raw source object: ${neutralId}/${name}`);
      const entry = entries[0];
      if (!entry) {
        if (name === "inject_time.txt" || name === "metrics.parquet") throw new Error(`Required raw file missing: ${neutralId}/${name}`);
        continue;
      }
      if (typeof entry.oid !== "string" || !/^[0-9a-f]{40}$/.test(entry.oid) ||
          typeof entry.size !== "number" || !Number.isSafeInteger(entry.size) || entry.size < 0 || entry.size > 512 * 1024 * 1024) {
        throw new Error(`Invalid or oversized raw source object: ${neutralId}/${name}; cohort is not resampled`);
      }
      const lfs = entry.lfs;
      let identity: { readonly sha256: string } | { readonly objectId: string } = { objectId: entry.oid };
      if (lfs !== undefined) {
        if (lfs === null || typeof lfs !== "object" || !("oid" in lfs) ||
            typeof lfs.oid !== "string" || !/^[0-9a-f]{64}$/.test(lfs.oid)) {
          throw new Error(`Raw source identity mismatch: ${neutralId}/${name}`);
        }
        identity = { sha256: lfs.oid };
      }
      const bytes = await downloadAndVerify(fetchImpl, REVISION, sourcePath, {
        name, size: entry.size, ...identity,
      }, originals);
      const digest = sha256(bytes);
      files.push({ name, objectId: entry.oid, size: bytes.byteLength, sha256: digest });
      if (name === "inject_time.txt") {
        injectionTime = Buffer.from(bytes).toString("utf8").trim();
        if (!/^\d{10,16}$/.test(injectionTime)) throw new Error(`Invalid raw incident onset: ${neutralId}`);
      } else {
        await copyFile(join(originals, name), join(visible, name));
        modalities.push(name.slice(0, -8) as Modality);
      }
    }
    if (!injectionTime) throw new Error(`Missing raw incident onset: ${neutralId}`);
    const sourceCase: CaseContract = { neutralId, sourcePath, trialOrder: position + 1, modalities, files };
    const truth = extractTruth(rows, sourceCase);
    await mkdir(join(scorerOnlyRoot, "truth"), { recursive: true });
    await writeJson(join(scorerOnlyRoot, "truth", `${neutralId}.json`), { neutralId, sourcePath, ...truth });
    const visibleFiles = files.filter((file) => file.name.endsWith(".parquet")).map(({ name, size, sha256 }) => ({ name, size, sha256 }));
    await writeJson(join(visible, "incident.json"), {
      schemaVersion: "1.0.0", evidenceTrack: "raw", caseId: neutralId, incidentOnset: injectionTime,
      files: visibleFiles, dataPreparation: "Unchanged source files; no schema mapping, derived evidence, or row conversion.",
    });
    cases.push({ neutralId, injectionTime, files: visibleFiles });
    sourceCases.push(sourceCase);
  }
  await writeJson(join(scorerOnlyRoot, "raw-cases.json"), { ...contract, evidenceTrack: "raw", selection, cases: sourceCases });
  const manifestPath = join(scorerOnlyRoot, "preparation-manifest.json");
  await writeJson(manifestPath, {
    schemaVersion: "1.0.0", evidenceTrack: "raw", runId: options.runId, dataset: DATASET,
    sourceRevision: contract.source.revision, sourceLicense: "MIT", transformationVersion: TRANSFORMATION_VERSION,
    selection, cases,
  });
  await convertRawRun(runRoot, options.parquetReader);
  return { runRoot, modelVisibleRoot, scorerOnlyRoot, manifestPath };
}

interface ConvertedFile {
  readonly name: string; readonly sha256: string; readonly size: number; readonly rowCount: number; readonly sourceSha256: string;
}
const CONVERSION_DESCRIPTION = "Row-preserving Parquet-to-JSONL conversion only; original fields and JSON-compatible values, no metric mapping or derived columns.";

/** Converts only unused raw inputs; original Parquet and held-out truth remain scorer-only and existing evaluated runs cannot change. */
export async function convertRawRun(
  runRoot: string,
  parquetReader?: (path: string) => Promise<readonly Record<string, unknown>[]>,
): Promise<void> {
  try { await stat(join(runRoot, "run-manifest.json")); }
  catch (error) {
    if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error;
    await convertUnusedRawRun(runRoot, parquetReader);
    return;
  }
  throw new Error("Cannot convert inputs of an evaluation that has already started; use a fresh run");
}

async function convertUnusedRawRun(
  runRoot: string, parquetReader?: (path: string) => Promise<readonly Record<string, unknown>[]>,
): Promise<void> {
  const scorer = join(runRoot, "inputs", "scorer-only");
  const manifest = await readJson<Record<string, unknown>>(join(scorer, "preparation-manifest.json"));
  const cohort = await readJson<EvaluationContract & { selection: RawSelection }>(join(scorer, "raw-cases.json"));
  if (manifest.evidenceTrack !== "raw" || cohort.source.revision !== "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e" ||
      cohort.cases.length !== 5 || manifest.evidenceFormat !== undefined) throw new Error("Expected unused original-file raw inputs");
  const owned = parquetReader ? undefined : await createPinnedParquetReader(fetch);
  const read = parquetReader ?? owned!.read;
  const cases: { neutralId: string; injectionTime: string; files: ConvertedFile[] }[] = [];
  try {
    for (const caseId of EVALUATION_CASE_IDS) {
      const source = cohort.cases.find((item) => item.neutralId === caseId);
      if (!source) throw new Error(`Missing raw source contract: ${caseId}`);
      const originals = join(scorer, "downloads", caseId);
      for (const file of source.files) {
        if (!/^(inject_time\.txt|(metrics|logs|traces)\.parquet)$/.test(file.name)) throw new Error("Invalid original raw filename");
        const bytes = await readFile(join(originals, file.name));
        if (bytes.length !== file.size || sha256(bytes) !== file.sha256) throw new Error(`Raw original integrity mismatch: ${caseId}/${file.name}`);
      }
      const injectionTime = (await readFile(join(originals, "inject_time.txt"), "utf8")).trim();
      if (!/^\d{10,16}$/.test(injectionTime)) throw new Error(`Invalid raw onset: ${caseId}`);
      const visible = join(runRoot, "inputs", "model-visible", caseId);
      const files: ConvertedFile[] = [];
      for (const file of source.files.filter((item) => item.name.endsWith(".parquet"))) {
        const name = file.name.replace(/\.parquet$/, ".jsonl");
        const converted = await writeJsonlRows(join(visible, name), await read(join(originals, file.name)));
        files.push({ name, ...converted, sourceSha256: file.sha256 });
        await rm(join(visible, file.name), { force: true });
      }
      await writeJson(join(visible, "incident.json"), {
        schemaVersion: "1.0.0", evidenceTrack: "raw", evidenceFormat: RAW_EVIDENCE_FORMAT,
        caseId, incidentOnset: injectionTime, files, dataPreparation: CONVERSION_DESCRIPTION,
      });
      cases.push({ neutralId: caseId, injectionTime, files });
    }
    await writeJson(join(scorer, "preparation-manifest.json"), {
      ...manifest, evidenceFormat: RAW_EVIDENCE_FORMAT, parquetReader: parquetReader ? "injected-test-reader" : PARQUET_READER_IDENTITY, cases,
    });
    await verifyRawRun(runRoot);
  } finally { await owned?.dispose(); }
}

/** Verifies converted identities and row counts; extra files, mappings and escaping links fail closed. */
export async function verifyRawRun(runRoot: string): Promise<void> {
  const canonicalRunRoot = await realpath(runRoot);
  const visibleRoot = resolve(runRoot, "inputs", "model-visible");
  const canonicalVisibleRoot = await realpath(visibleRoot);
  if (relative(canonicalRunRoot, canonicalVisibleRoot) !== join("inputs", "model-visible")) {
    throw new Error("Raw model-visible root escapes the run");
  }
  const manifest = await readJson<{
    evidenceTrack: string; evidenceFormat: string; sourceRevision: string; transformationVersion: string; selection: RawSelection;
    cases: readonly { neutralId: string; injectionTime: string; files: readonly ConvertedFile[] }[];
  }>(join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"));
  if (manifest.evidenceTrack !== "raw" || manifest.sourceRevision !== "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e" ||
      manifest.transformationVersion !== TRANSFORMATION_VERSION || manifest.evidenceFormat !== RAW_EVIDENCE_FORMAT ||
      manifest.cases.length !== 5 || new Set(manifest.cases.map((item) => item.neutralId)).size !== 5) {
    throw new Error("Invalid pinned raw preparation manifest");
  }
  const cohort = await readJson<EvaluationContract & { selection: RawSelection }>(join(runRoot, "inputs", "scorer-only", "raw-cases.json"));
  if (cohort.source.revision !== manifest.sourceRevision ||
      stableJson(cohort.selection) !== stableJson(manifest.selection) ||
      stableJson(cohort.cases.map((item) => item.sourcePath)) !== stableJson(manifest.selection.selectedSourcePaths) ||
      sha256(await readFile(join(runRoot, "inputs", "scorer-only", "cases.parquet"))) !== cohort.source.caseIndex.sha256) {
    throw new Error("Raw cohort selection or pinned index integrity mismatch");
  }
  for (const caseId of EVALUATION_CASE_IDS) {
    const item = manifest.cases.find((entry) => entry.neutralId === caseId);
    if (!item || !item.files.length) throw new Error(`Missing raw case: ${caseId}`);
    const directory = resolve(runRoot, "inputs", "model-visible", caseId);
    if (relative(canonicalVisibleRoot, await realpath(directory)) !== caseId) throw new Error("Raw case directory escapes its identity");
    const expected = [...item.files.map((file) => file.name), "incident.json"].sort(compareStrings);
    const actual = (await readdir(directory)).sort(compareStrings);
    if (stableJson(expected) !== stableJson(actual)) throw new Error(`Unexpected model-visible raw inventory: ${caseId}`);
    const sourceCase = cohort.cases.find((entry) => entry.neutralId === caseId);
    if (!sourceCase || stableJson(sourceCase.files.filter((file) => file.name.endsWith(".parquet")).map(({ name, sha256 }) => ({ name: name.replace(/\.parquet$/, ".jsonl"), sourceSha256: sha256 }))) !== stableJson(item.files.map(({ name, sourceSha256 }) => ({ name, sourceSha256 })))) {
      throw new Error(`Raw cohort file identities disagree: ${caseId}`);
    }
    for (const file of item.files) {
      if (!/^(metrics|logs|traces)\.jsonl$/.test(file.name)) throw new Error(`Invalid raw evidence name: ${caseId}`);
      const path = resolveInside(directory, file.name);
      if (relative(directory, await realpath(path)) !== basename(path) || !(await stat(path)).isFile()) throw new Error("Raw evidence must be a contained regular file");
      const measured = await hashAndCountLines(path);
      if ((await stat(path)).size !== file.size || measured.sha256 !== file.sha256 ||
          measured.rowCount !== file.rowCount || file.rowCount < 1) throw new Error(`Raw evidence integrity mismatch: ${caseId}/${file.name}`);
    }
    const incidentPath = join(directory, "incident.json");
    const incidentHandle = await open(incidentPath, constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
    let incident: string;
    try {
      if (relative(directory, await realpath(incidentPath)) !== "incident.json" || !(await incidentHandle.stat()).isFile()) {
        throw new Error("Raw incident metadata must be a contained regular file");
      }
      incident = await incidentHandle.readFile("utf8");
    } finally {
      await incidentHandle.close();
    }
    const expectedIncident = {
      schemaVersion: "1.0.0", evidenceTrack: "raw", evidenceFormat: RAW_EVIDENCE_FORMAT, caseId, incidentOnset: item.injectionTime,
      files: item.files, dataPreparation: CONVERSION_DESCRIPTION,
    };
    if (stableJson(JSON.parse(incident)) !== stableJson(expectedIncident)) throw new Error(`Raw incident metadata integrity mismatch: ${caseId}`);
    if (/root_cause_service|rootCauseService|expected_answer|sourcePath|selectedSourcePaths/.test(incident)) {
      throw new Error(`Answer-bearing raw metadata: ${caseId}`);
    }
  }
}
