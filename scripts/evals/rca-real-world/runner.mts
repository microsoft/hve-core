// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { execFile } from "node:child_process";
import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join, relative } from "node:path";
import { promisify } from "node:util";

import {
  EXPECTED_CONTEXT_TIER,
  EVALUATION_CASE_IDS,
  EXPECTED_MODEL,
  EXPECTED_REASONING_EFFORT,
  TRANSFORMATION_VERSION,
  type PreparedCaseManifest,
  compareStrings,
  createSchedule,
  readJson,
  sha256,
  stableJson,
  writeJson,
} from "./contracts.mts";
import { runCliTrial, type CliInvoker } from "./cli-orchestrator.mts";
import {
  evaluateRoundOne,
  scorePersistedTrial,
  type TrialResult,
} from "./scoring.mts";

const execFileAsync = promisify(execFile);
const SOURCE_REVISION = "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e";

export interface RunRoundOptions {
  readonly repositoryRoot: string;
  readonly runRoot?: string;
  readonly runId: string;
  readonly round: 1 | 2 | 3;
  readonly cliInvoker?: CliInvoker;
  readonly clock?: () => Date;
}

export interface EvaluationSummary {
  readonly schemaVersion: "1.0.0";
  readonly runId: string;
  readonly sourceRevision: string;
  readonly model: string;
  readonly reasoningEffort: string;
  readonly contextTier: string;
  readonly trialOrder: readonly { caseId: string; trial: number }[];
  readonly trials: readonly TrialResult[];
  readonly roundOneCheckpoint?: {
    readonly decision: "continue" | "pause";
    readonly reasons: readonly string[];
  };
  readonly limitations: readonly string[];
}

/**
 * Executes one approved trial round and updates aggregate machine-readable evidence.
 *
 * Round two requires a continuing round-one checkpoint. Round three additionally requires all
 * round-two results. Existing session directories are never replaced or retried.
 */
export async function runRound(options: RunRoundOptions): Promise<EvaluationSummary> {
  const runRoot =
    options.runRoot ??
    join(
      options.repositoryRoot,
      ".copilot-tracking",
      "evaluations",
      "rcaeval-three-case",
      options.runId,
    );
  const prepared = await assertPrepared(runRoot);
  const currentFingerprint = await createInputFingerprint(options.repositoryRoot, runRoot);
  const manifestPath = join(runRoot, "run-manifest.json");
  if (options.round === 1) {
    try {
      await stat(manifestPath);
      throw new Error(`Run manifest already exists for ${options.runId}; retries are not allowed`);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
    await writeJson(manifestPath, {
      schemaVersion: "1.0.0",
      runId: options.runId,
      sourceRevision: SOURCE_REVISION,
      model: EXPECTED_MODEL,
      reasoningEffort: EXPECTED_REASONING_EFFORT,
      contextTier: EXPECTED_CONTEXT_TIER,
      inputFingerprint: currentFingerprint,
      repositoryCommit: await gitCommit(options.repositoryRoot),
      nodeVersion: process.version,
      readerBundleIdentity: prepared.parquetReader ?? "Unavailable",
      packageLockSha256: sha256(await readFile(join(options.repositoryRoot, "package-lock.json"))),
      startedAt: (options.clock ?? (() => new Date()))().toISOString(),
      retries: "none",
    });
  } else {
    const manifest = await readJson<{ inputFingerprint: string }>(manifestPath);
    if (manifest.inputFingerprint !== currentFingerprint) {
      throw new Error("Evaluation inputs changed after round one");
    }
    const checkpoint = await readJson<{ decision: string }>(
      join(runRoot, "round-one-checkpoint.json"),
    );
    if (checkpoint.decision !== "continue") {
      throw new Error("Round-one checkpoint does not authorize continuation");
    }
    if (options.round === 3) {
      await requireResults(runRoot, 2);
    }
  }

  const scorerPath = join(import.meta.dirname, "scoring.mts");
  const roundItems = createSchedule(options.round).filter((item) => item.trial === options.round);
  for (const item of roundItems) {
    const sessionPath = join(
      runRoot,
      "sessions",
      item.caseId,
      `trial-${item.trial}`,
      "session-artifact.json",
    );
    try {
      await stat(sessionPath);
      throw new Error(`Session already exists and will not be retried: ${item.caseId} trial ${item.trial}`);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
    await runCliTrial({
      repositoryRoot: options.repositoryRoot,
      runRoot,
      runId: options.runId,
      caseId: item.caseId,
      trial: item.trial,
      cliInvoker: options.cliInvoker,
      clock: options.clock,
    });
    await scorePersistedTrial({
      runRoot,
      caseId: item.caseId,
      trial: item.trial,
      scorerPath,
    });
  }

  const results = await readAllResults(runRoot);
  let roundOneCheckpoint: EvaluationSummary["roundOneCheckpoint"];
  if (options.round === 1) {
    const firstRound = results.filter((result) => result.trial === 1);
    roundOneCheckpoint = evaluateRoundOne(firstRound);
    await writeJson(join(runRoot, "round-one-checkpoint.json"), {
      schemaVersion: "1.0.0",
      evaluatedAt: (options.clock ?? (() => new Date()))().toISOString(),
      ...roundOneCheckpoint,
      trialResultHashes: Object.fromEntries(
        firstRound.map((result) => [
          result.caseId,
          result.hashes.resultSha256,
        ]),
      ),
    });
  } else {
    roundOneCheckpoint = await readJson<EvaluationSummary["roundOneCheckpoint"]>(
      join(runRoot, "round-one-checkpoint.json"),
    );
  }

  const summary: EvaluationSummary = {
    schemaVersion: "1.0.0",
    runId: options.runId,
    sourceRevision: SOURCE_REVISION,
    model: EXPECTED_MODEL,
    reasoningEffort: EXPECTED_REASONING_EFFORT,
    contextTier: EXPECTED_CONTEXT_TIER,
    trialOrder: createSchedule(3),
    trials: results,
    roundOneCheckpoint,
    limitations: [
      "The cases are controlled fault injections, not organic production incidents.",
      `${EVALUATION_CASE_IDS.length} selected cases and the scheduled sessions do not establish a general RCA accuracy rate.`,
      "Approvals are simulated evaluation fixtures and do not establish production authority.",
      "Diagnostic compatibility, unsupported claims, CR-16 satisfaction, and issue closure require human review.",
    ],
  };
  await writeJson(join(runRoot, "evaluation-summary.json"), summary);
  return summary;
}

async function assertPrepared(runRoot: string): Promise<{
  readonly parquetReader?: string;
}> {
  const manifest = await readJson<{
    sourceRevision?: string;
    transformationVersion?: string;
    cases?: readonly PreparedCaseManifest[];
    parquetReader?: string;
  }>(join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"));
  if (
    manifest.sourceRevision !== SOURCE_REVISION ||
    manifest.transformationVersion !== TRANSFORMATION_VERSION ||
    manifest.cases?.length !== EVALUATION_CASE_IDS.length
  ) {
    throw new Error("Prepared input manifest is missing or does not match the pinned source");
  }
  for (const caseId of EVALUATION_CASE_IDS) {
    const preparedCase = manifest.cases.find((item) => item.neutralId === caseId);
    const mapping = await readFile(join(runRoot, "inputs", "model-visible", caseId, "metric-columns.json"));
    if (!preparedCase || sha256(mapping) !== preparedCase.metricColumnsSha256) {
      throw new Error(`Metric column mapping integrity mismatch: ${caseId}`);
    }
  }
  return { parquetReader: manifest.parquetReader };
}

async function requireResults(runRoot: string, trial: number): Promise<void> {
  for (const caseId of EVALUATION_CASE_IDS) {
    await stat(join(runRoot, "sessions", caseId, `trial-${trial}`, "trial-result.json"));
  }
}

async function readAllResults(runRoot: string): Promise<readonly TrialResult[]> {
  const results: TrialResult[] = [];
  for (const item of createSchedule(3)) {
    const path = join(runRoot, "sessions", item.caseId, `trial-${item.trial}`, "trial-result.json");
    try {
      results.push(await readJson<TrialResult>(path));
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
  }
  return results;
}

/** Computes the immutable evaluation input fingerprint for run continuation checks. */
export async function createInputFingerprint(
  repositoryRoot: string,
  runRoot: string,
): Promise<string> {
  const roots = [
    join(repositoryRoot, "evals", "rca-real-world"),
    join(repositoryRoot, "scripts", "evals", "rca-real-world"),
    join(repositoryRoot, ".github", "skills", "root-cause-analysis"),
  ];
  const files: { path: string; sha256: string }[] = [];
  for (const root of roots) {
    for (const path of await listFiles(root)) {
      files.push({
        path: relative(repositoryRoot, path).replaceAll("\\", "/"),
        sha256: sha256(await readFile(path)),
      });
    }
  }
  for (const path of [
    join(repositoryRoot, "package-lock.json"),
    join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"),
  ]) {
    files.push({
      path: basename(path),
      sha256: sha256(await readFile(path)),
    });
  }
  for (const caseId of EVALUATION_CASE_IDS) {
    const path = `inputs/model-visible/${caseId}/metric-columns.json`;
    files.push({
      path,
      sha256: sha256(await readFile(join(runRoot, ...path.split("/")))),
    });
  }
  files.sort((left, right) => compareStrings(left.path, right.path));
  return sha256(stableJson(files));
}

async function listFiles(root: string): Promise<readonly string[]> {
  const entries = await readdir(root, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listFiles(path)));
    } else if (entry.isFile()) {
      files.push(path);
    }
  }
  return files;
}

async function gitCommit(repositoryRoot: string): Promise<string> {
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: repositoryRoot });
  return stdout.trim();
}
